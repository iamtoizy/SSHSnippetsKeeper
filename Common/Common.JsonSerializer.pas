unit Common.JsonSerializer;

// Собственный RTTI-сериализатор настроек (замена ThirdParty\JSONSerializer.pas).
// Поведение зафиксировано в docs\JsonSerializer.SPEC.md; реализация написана
// по SPEC, не по исходнику DSON. Поддерживаются только типы, используемые
// проектом: records, TArray<T>, TArrayRecord<T>, скаляры, string.

interface

uses
    System.SysUtils,
    System.Rtti,
    System.TypInfo,
    System.JSON
    ;

type
    // Исключение сериализатора: структурные несоответствия (SPEC §5) и
    // несовместимые скалярные конверсии (оборачивает EJSONException)
    EJsonSerializerException = class(Exception);

    // Внутренние классы объявлены в interface-секции: generic-методы
    // TJsonSerializer (interface) не могут ссылаться на implementation-символы
    TJsonWriter = class
    public
        function WriteValue(const AValue: TValue): TJSONValue;
        function WriteObjectValue(const AValue: TValue): TJSONObject;
    end;

    TJsonReader = class
    public
        function ReadValue(const ATypeInfo: PTypeInfo; const AJson: TJSONValue): TValue;
        function ReadFloatValue(const ATypeInfo: PTypeInfo; const AJson: TJSONValue): TValue;
        function ReadDynArrayValue(const ARttiType: TRttiType; const AJson: TJSONValue): TValue;
        function ReadRecordValue(const ATypeInfo: PTypeInfo; const AJson: TJSONValue): TValue;
        function ReadObjectValue(const ATypeInfo: PTypeInfo; const AJson: TJSONValue): TValue;
        procedure FillRecordMembers(const ARec: TValue; const AObj: TJSONObject);
    end;

    TJsonSerializer = record
    public
        // SPEC §4: невалидный JSON -> Default(T) без исключения;
        // отсутствующие члены не присваиваются; null-члены пропускаются;
        // неизвестные члены игнорируются
        class function FromJson<T>(const AJson: string): T; static;

        // SPEC §2-3: AFormat=True -> TJSONValue.Format (indent 4),
        // False -> компактная строка
        class function ToJson<T>(const AValue: T; const AFormat: Boolean = True): string; static;
    end;

implementation

uses
    System.Classes,
    System.Generics.Collections
    ;

const
    SNotAnObject = 'Json value is not an object';
    SNotAnArray = 'Json value is not an array';
    SUnsupportedType = 'Not supported type %s, type kind: %s';

{ TJsonWriter }

function TJsonWriter.WriteValue(const AValue: TValue): TJSONValue;
var
    RttiType: TRttiType;
    Ctx: TRttiContext;
    Kind: TTypeKind;
    I: Integer;
    Arr: TJSONArray;
    El: TJSONValue;
    EnumKindName: string;
begin
    Result := nil;
    if AValue.IsEmpty then
        Exit;

    Ctx := TRttiContext.Create;
    RttiType := Ctx.GetType(AValue.TypeInfo);
    Kind := RttiType.TypeKind;
    case Kind of
        tkInteger:
            Result := TJSONNumber.Create(AValue.AsInteger);
        tkInt64:
            Result := TJSONNumber.Create(AValue.AsInt64);
        tkEnumeration:
            if AValue.TypeInfo = TypeInfo(Boolean) then
                Result := TJSONBool.Create(AValue.AsBoolean)
            else
                Result := TJSONString.Create(GetEnumName(AValue.TypeInfo, AValue.AsOrdinal));
        tkFloat:
            Result := TJSONNumber.Create(AValue.AsExtended);
        tkString, tkLString, tkWString, tkUString:
            Result := TJSONString.Create(AValue.AsString);
        tkClass, tkRecord:
            Result := WriteObjectValue(AValue);
        tkDynArray, tkArray:
            begin
                Arr := TJSONArray.Create;
                try
                    for I := 0 to AValue.GetArrayLength - 1 do
                    begin
                        El := WriteValue(AValue.GetArrayElement(I));
                        if El <> nil then
                            Arr.AddElement(El);
                    end;
                except
                    Arr.Free;
                    raise;
                end;
                Result := Arr;
            end;
        tkSet:
            Result := TJSONString.Create(SetToString(AValue.TypeInfo, AValue.GetReferenceToRawData, True));
    else
        EnumKindName := GetEnumName(TypeInfo(TTypeKind), Ord(Kind));
        raise EJsonSerializerException.CreateFmt(SUnsupportedType, [RttiType.Name, EnumKindName]);
    end;
end;

function GetInstancePointer(const AValue: TValue): Pointer;
begin
    Result := nil;
    if AValue.Kind = tkRecord then
        Result := AValue.GetReferenceToRawData
    else if AValue.Kind = tkClass then
        Result := AValue.AsObject;
end;

function TJsonWriter.WriteObjectValue(const AValue: TValue): TJSONObject;

    procedure AddMember(const AMember: TRttiMember);
    var
        Instance: Pointer;
        MemberValue: TValue;
        Jv: TJSONValue;
    begin
        Instance := GetInstancePointer(AValue);
        if Instance = nil then
            Exit;
        if AMember.Visibility in [mvPublic, mvPublished] then
        begin
            if AMember is TRttiProperty then
            begin
                if not TRttiProperty(AMember).IsReadable then
                    Exit;
                MemberValue := TRttiProperty(AMember).GetValue(Instance);
            end
            else
                MemberValue := TRttiField(AMember).GetValue(Instance);
            Jv := WriteValue(MemberValue);
            if Jv <> nil then
                Result.AddPair(AMember.Name, Jv);
        end;
    end;

var
    Ctx: TRttiContext;
    RttiType: TRttiType;
    Member: TRttiMember;
begin
    Result := TJSONObject.Create;
    try
        Ctx := TRttiContext.Create;
        RttiType := Ctx.GetType(AValue.TypeInfo);
        for Member in RttiType.GetDeclaredProperties do
            AddMember(Member);
        for Member in RttiType.GetDeclaredFields do
            AddMember(Member);
    except
        Result.Free;
        raise;
    end;
end;

{ TJsonReader }

function TJsonReader.ReadValue(const ATypeInfo: PTypeInfo; const AJson: TJSONValue): TValue;
var
    Ctx: TRttiContext;
    RttiType: TRttiType;
begin
    Result := Default(TValue);

    if (AJson = nil) or (AJson is TJSONNull) then
        Exit;

    Ctx := TRttiContext.Create;
    RttiType := Ctx.GetType(ATypeInfo);

    case RttiType.TypeKind of
        tkInteger:
            Result := AJson.GetValue<Integer>;
        tkInt64:
            Result := AJson.GetValue<Int64>;
        tkEnumeration:
            if ATypeInfo = TypeInfo(Boolean) then
                Result := AJson.GetValue<Boolean>
            else
                Result := TValue.FromOrdinal(ATypeInfo, GetEnumValue(ATypeInfo, AJson.GetValue<string>));
        tkFloat:
            Result := ReadFloatValue(ATypeInfo, AJson);
        tkString, tkLString, tkWString, tkUString:
            Result := AJson.GetValue<string>;
        tkClass:
            Result := ReadObjectValue(ATypeInfo, AJson);
        tkDynArray:
            Result := ReadDynArrayValue(RttiType, AJson);
        tkRecord:
            Result := ReadRecordValue(ATypeInfo, AJson);
        tkSet:
            begin
                TValue.Make(nil, ATypeInfo, Result);
                StringToSet(ATypeInfo, AJson.GetValue<string>, Result.GetReferenceToRawData);
            end;
    else
        raise EJsonSerializerException.CreateFmt(SUnsupportedType, [RttiType.Name, GetEnumName(TypeInfo(TTypeKind), Ord(RttiType.TypeKind))]);
    end;
end;

function TJsonReader.ReadFloatValue(const ATypeInfo: PTypeInfo; const AJson: TJSONValue): TValue;
var
    Ctx: TRttiContext;
    FloatType: TRttiFloatType;
begin
    Result := Default(TValue);
    Ctx := TRttiContext.Create;
    FloatType := Ctx.GetType(ATypeInfo) as TRttiFloatType;
    case FloatType.FloatType of
        ftSingle: Result := AJson.GetValue<Single>;
        ftDouble: Result := AJson.GetValue<Double>;
        ftExtended: Result := AJson.GetValue<Extended>;
        ftComp: Result := TValue.From<Comp>(AJson.GetValue<Currency>);
        ftCurr: Result := AJson.GetValue<Currency>;
    end;
end;

function TJsonReader.ReadDynArrayValue(const ARttiType: TRttiType; const AJson: TJSONValue): TValue;
var
    Arr: TJSONArray;
    ElementType: TRttiType;
    Values: TArray<TValue>;
    I: Integer;
begin
    Result := Default(TValue);

    if not (AJson is TJSONArray) then
        raise EJsonSerializerException.Create(SNotAnArray);

    Arr := TJSONArray(AJson);
    ElementType := TRttiDynamicArrayType(ARttiType).ElementType;
    SetLength(Values, Arr.Count);
    for I := 0 to Arr.Count - 1 do
        Values[I] := ReadValue(ElementType.Handle, Arr.Items[I]);
    Result := TValue.FromArray(ARttiType.Handle, Values);
end;

function TJsonReader.ReadRecordValue(const ATypeInfo: PTypeInfo; const AJson: TJSONValue): TValue;
var
    Rec: TValue;
begin
    Result := Default(TValue);

    if not (AJson is TJSONObject) then
        raise EJsonSerializerException.Create(SNotAnObject);

    TValue.Make(nil, ATypeInfo, Rec);
    FillRecordMembers(Rec, TJSONObject(AJson));
    Result := Rec;
end;

function TJsonReader.ReadObjectValue(const ATypeInfo: PTypeInfo; const AJson: TJSONValue): TValue;
var
    Ctx: TRttiContext;
    Inst: TRttiType;
    Instance: TObject;
begin
    Result := Default(TValue);

    if not (AJson is TJSONObject) then
        raise EJsonSerializerException.Create(SNotAnObject);

    Ctx := TRttiContext.Create;
    Inst := Ctx.GetType(ATypeInfo);
    Instance := Inst.AsInstance.MetaclassType.Create;
    try
        FillRecordMembers(Instance, TJSONObject(AJson));
        Result := Instance;
    except
        Instance.Free;
        raise;
    end;
end;

procedure TJsonReader.FillRecordMembers(const ARec: TValue; const AObj: TJSONObject);
var
    Ctx: TRttiContext;
    RttiType: TRttiType;
    Member: TRttiMember;
    MemberType: TRttiType;
    Jv: TJSONValue;
    NewValue: TValue;
    Instance: Pointer;
begin
    Ctx := TRttiContext.Create;
    RttiType := Ctx.GetType(ARec.TypeInfo);
    Instance := GetInstancePointer(ARec);
    if Instance = nil then
        Exit;

    for Member in RttiType.GetDeclaredProperties do
    begin
        if Member.Visibility in [mvPublic, mvPublished] then
        begin
            Jv := AObj.GetValue(Member.Name);
            MemberType := TRttiProperty(Member).PropertyType;
            if (MemberType <> nil) and (Jv <> nil) and not (Jv is TJSONNull) then
                if Member is TRttiProperty then
                    if TRttiProperty(Member).IsWritable then
                    begin
                        NewValue := ReadValue(MemberType.Handle, Jv);
                        TRttiProperty(Member).SetValue(Instance, NewValue);
                    end;
        end;
    end;

    for Member in RttiType.GetDeclaredFields do
    begin
        if Member.Visibility in [mvPublic, mvPublished] then
        begin
            Jv := AObj.GetValue(Member.Name);
            MemberType := TRttiField(Member).FieldType;
            if (MemberType <> nil) and (Jv <> nil) and not (Jv is TJSONNull) then
            begin
                NewValue := ReadValue(MemberType.Handle, Jv);
                TRttiField(Member).SetValue(Instance, NewValue);
            end;
        end;
    end;
end;

{ TJsonSerializer }

class function TJsonSerializer.FromJson<T>(const AJson: string): T;
var
    Reader: TJsonReader;
    Jv: TJSONValue;
    V: TValue;
begin
    Result := Default(T);

    Jv := TJSONObject.ParseJSONValue(AJson);
    if Jv = nil then
        Exit;

    Reader := TJsonReader.Create;
    try
        V := Reader.ReadValue(TypeInfo(T), Jv);
        Result := V.AsType<T>;
    finally
        Reader.Free;
        Jv.Free;
    end;
end;

class function TJsonSerializer.ToJson<T>(const AValue: T; const AFormat: Boolean): string;
var
    Writer: TJsonWriter;
    Jv: TJSONValue;
begin
    Result := '';

    Writer := TJsonWriter.Create;
    try
        Jv := Writer.WriteValue(TValue.From<T>(AValue));
        try
            if Jv <> nil then
                if AFormat then
                    Result := Jv.Format
                else
                    Result := Jv.ToJSON;
        finally
            Jv.Free;
        end;
    finally
        Writer.Free;
    end;
end;

end.
