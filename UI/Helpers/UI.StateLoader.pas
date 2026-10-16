unit UI.StateLoader;

interface

uses
    System.Classes,
    Vcl.Forms
    ;

type
    TUIStateLoader = class
    public
        // �������� ����� � ������ (���������� 1 ��� ��� ������ ����������)
        class procedure LoadLanguageFile(const JsonFilePath: string);

        // ���������� ������� � ����� � � �����������
        class procedure ApplyTranslations(Form: TCustomForm);

        // ��������� ������ ���������� ������ �� ����� (��� ������, ��������)
        class function GetMessage(const MessageKey: string): string; overload;
        class function GetMessage(const MessageKey: string; const Args: array of const): string; overload;

        class procedure GetHelpTexts(const BasePath: string; out Title, MainText, ExpText: string);
    end;

implementation

uses
    System.IOUtils,
    System.JSON,
    System.SysUtils,
    System.TypInfo,
    Vcl.ComCtrls,
    Vcl.Dialogs;

var
    // ���������� ��� ��������� ����� � ����������� ������
    GCachedLanguageData: TJSONObject = nil;

class procedure TUIStateLoader.LoadLanguageFile(const JsonFilePath: string);
var
    JsonText: string;
    ParsedValue: TJSONValue;
begin
    if not TFile.Exists(JsonFilePath) then
        Exit;

    if Assigned(GCachedLanguageData) then
        FreeAndNil(GCachedLanguageData);

    // 1. ������ ����
    JsonText := TFile.ReadAllText(JsonFilePath, TEncoding.UTF8);

    // 2. ������� ��������� BOM-������ � ������ ������� �� �����
    JsonText := JsonText.Replace(#$FEFF, '').Trim;

    // 3. ������� ���������� � ������� TJSONValue
    ParsedValue := TJSONObject.ParseJSONValue(JsonText);

    // ���� �������� nil, ������ � ����� ������ JSON ���� �������������� ������
    if not Assigned(ParsedValue) then
        raise Exception.Create('JSON syntax error! Please check the contents of ' + JsonFilePath + ' using jsonlint.com.');

    // 4. ���������, ��� ������ ����� - ��� ������ ������ { ... }
    if not (ParsedValue is TJSONObject) then
    begin
        ParsedValue.Free;
        raise Exception.Create('JSON parsed successfully, but the root element is not an object { }!');
    end;

    // 5. �� �������, ��������
    GCachedLanguageData := TJSONObject(ParsedValue);
end;

class procedure TUIStateLoader.ApplyTranslations(Form: TCustomForm);
var
    FormObj, CompObj: TJSONObject;
    PropPair, CompPropPair: TJSONPair;
    Comp: TComponent;
    ClassKey: string;

    // ���������� ������� ��� ��������� ������� �� ��������� ���� (�������� "EditLabel.Caption")
    procedure SetNestedPropValue(AObject: TObject; const Path: string; const Value: string);
    var
        Tokens: TArray<string>;
        I: Integer;
        CurrentObj: TObject;
        PropInfo: PPropInfo;
    begin
        if not Assigned(AObject) then Exit;

        Tokens := Path.Split(['.']);
        CurrentObj := AObject;

        // ���������� �� ������ �������� (��������, ������� ����� ������ EditLabel)
        for I := 0 to High(Tokens) - 1 do
        begin
            if not IsPublishedProp(CurrentObj, Tokens[I]) then Exit;
            // �������� ������ �� ��������� ������
            CurrentObj := GetObjectProp(CurrentObj, Tokens[I]);
            if not Assigned(CurrentObj) then Exit;
        end;

        // ��������� �������� � ���������� �������� (��������, Caption)
        if IsPublishedProp(CurrentObj, Tokens[High(Tokens)]) then
        begin
            // �������� ���� ��������: ������ ������ �������� �������� � ����� � �.�.
            PropInfo := GetPropInfo(CurrentObj, Tokens[High(Tokens)]);
            if Assigned(PropInfo) and (PropInfo^.PropType^.Kind in [tkString, tkLString, tkWString, tkUString]) then
                SetPropValue(CurrentObj, Tokens[High(Tokens)], Value);
        end;
    end;

begin
    if not Assigned(GCachedLanguageData) then
        Exit;

    // ����������� ��� ������ (��������, 'TAddEditSnippetForm' -> 'AddEditSnippetForm')
    ClassKey := Form.ClassName;
    if ClassKey.StartsWith('T') then
        ClassKey := ClassKey.Substring(1);

    // ���� ���� � ������ ����� ����� (��������, "MainForm")
    // ���� ������� �� ����� ������ (�������!), ���� �� ����� - �� ����� ����������
    if GCachedLanguageData.TryGetValue<TJSONObject>(ClassKey, FormObj) or
       GCachedLanguageData.TryGetValue<TJSONObject>(Form.Name, FormObj) or
       GCachedLanguageData.TryGetValue<TJSONObject>(Form.ClassName, FormObj) then
    begin
        // ���������� ������ �� �����, ������� ���� � JSON
        for PropPair in FormObj do
        begin
            // �������� �: �������� �������� ������� -> ��� �������� ����� ����� (��������, Caption)
            if PropPair.JsonValue is TJSONString then
            begin
                SetNestedPropValue(Form, PropPair.JsonString.Value, PropPair.JsonValue.Value);
            end
            // �������� �: �������� �������� �������� -> ��� ��������� ���������� ����������
            else if PropPair.JsonValue is TJSONObject then
            begin
                CompObj := TJSONObject(PropPair.JsonValue);
                Comp := Form.FindComponent(PropPair.JsonString.Value); // ������� ����� ���������� �� �����
                {$IFDEF DEBUG}
                if not Assigned(Comp) then
                begin
                    raise Exception.Create('��������� �� ������ �� �����: ' + PropPair.JsonString.Value);
                end;
                {$ENDIF}

                if Assigned(Comp) then
                begin
                    // ��������� ������� TListView ����� tag
                    if (Comp is TListView) and (CompObj.GetValue('Columns') is TJSONObject) then
                    begin
                        var ColObj := TJSONObject(CompObj.GetValue('Columns'));
                        var LV := TListView(Comp);
                        for var ColPair in ColObj do
                        begin
                            var ColTag: Integer;
                            if TryStrToInt(ColPair.JsonString.Value, ColTag) then
                                for var I := 0 to LV.Columns.Count - 1 do
                                    if LV.Columns[I].Tag = ColTag then
                                    begin
                                        LV.Columns[I].Caption := ColPair.JsonValue.Value;
                                        Break;
                                    end;
                        end;
                    end;
                    // ---------------------------------------------
                    // ��������� ����������� �������� � ����������
                    for CompPropPair in CompObj do
                    begin
                        if CompPropPair.JsonString.Value <> 'Columns' then // ���������� ���� �������
                        begin
                            // ���������� ����� ������� ��� ���������� ��������
                            SetNestedPropValue(Comp, CompPropPair.JsonString.Value, CompPropPair.JsonValue.Value);
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

class procedure TUIStateLoader.GetHelpTexts(const BasePath: string; out Title, MainText, ExpText: string);
var
    MessagesVal, CurrentVal: TJSONValue;
    CurrentObj: TJSONObject;
    Tokens: TArray<string>;
    I: Integer;

    // ��������� ������� ��� ����������� ���������� ����� � ������ ��������� \n
    function ExtractStr(Obj: TJSONObject; const PropName, DefaultVal: string): string;
    var
        Val: TJSONValue;
    begin
        Val := Obj.GetValue(PropName);
        if Assigned(Val) and (Val is TJSONString) then
            Result := StringReplace(Val.Value, '\n', #13#10, [rfReplaceAll])
        else
            Result := DefaultVal;
    end;

begin
    // ������ ���������� �������� �� ���������
    Title := 'Help';
    MainText := 'Help text not found.';
    ExpText := '';

    if not Assigned(GCachedLanguageData) then Exit;

    // 1. ������ � ������ "Messages"
    MessagesVal := GCachedLanguageData.GetValue('Messages');
    if not (MessagesVal is TJSONObject) then Exit;

    CurrentObj := TJSONObject(MessagesVal);
    Tokens := BasePath.Split(['.']);

    // 2. ���������� �� ������ �� ������ ����� (������ ���� ���� �� High(Tokens))
    for I := 0 to High(Tokens) do
    begin
        CurrentVal := CurrentObj.GetValue(Tokens[I]);

        if not Assigned(CurrentVal) then
        begin
{$IFDEF DEBUG}
            raise Exception.Create('ERROR: Cannot find key "' + Tokens[I] + '"!' + sLineBreak +
                        'Current object contents:' + sLineBreak +
                        CurrentObj.ToString);
{$ENDIF}
            Exit;
        end;

        if not (CurrentVal is TJSONObject) then
        begin
{$IFDEF DEBUG}
            raise Exception.Create('ERROR: Key "' + Tokens[I] + '" found, but it is NOT an object (possibly already a string?)');
{$ENDIF}
            Exit;
        end;

        CurrentObj := TJSONObject(CurrentVal);
    end;

    Title    := ExtractStr(CurrentObj, 'Title', Title);
    MainText := ExtractStr(CurrentObj, 'Main', MainText);
    ExpText  := ExtractStr(CurrentObj, 'Expanded', ExpText);
end;

class function TUIStateLoader.GetMessage(const MessageKey: string; const Args: array of const): string;
var
    Mask: string;
begin
    // 1. �������� ����� ��� ����� ������
    Mask := GetMessage(MessageKey);

    // 2. ������: ���� ����� ��� � JSON, ����� ���������� ������, �� ������� �������������
    // (����� Format ��� �� ��������� �� ������������ ����������)
    if Mask.StartsWith('[ERROR:') then
    begin
        Result := Mask;
        Exit;
    end;

    // 3. �������� ���������� ���������
    try
        Result := Format(Mask, Args);
    except
        on E: Exception do
            // ���� ���������� ������ (��������, ������� %d ������ %s)
            Result := '[FORMAT ERROR: ' + MessageKey + ']';
    end;
end;

class function TUIStateLoader.GetMessage(const MessageKey: string): string;
const
    ERR_KEY_NOT_FOUND     = '[ERROR: Key "%s" not found]';
    ERR_INVALID_STRUCTURE = '[ERROR: Invalid JSON structure at token "%s" in key "%s"]';
    ERR_NOT_A_STRING      = '[ERROR: Value for key "%s" is not a string]';
var
    MessagesVal, CurrentVal: TJSONValue;
    CurrentObj: TJSONObject;
    Tokens: TArray<string>;
    I: Integer;
    ErrText: string;
begin
    // �� ��������� �������, ��� ����� ������ ���
    Result := Format(ERR_KEY_NOT_FOUND, [MessageKey]);

    if not Assigned(GCachedLanguageData) then
    begin
        Result := '[ERROR: Language data not initialized]';
        Exit;
    end;

    // 1. ������ � �������� ���� "Messages"
    MessagesVal := GCachedLanguageData.GetValue('Messages');
    if not (MessagesVal is TJSONObject) then
    begin
        Result := '[ERROR: Root node "Messages" is missing or not an object]';
        Exit;
    end;

    CurrentObj := TJSONObject(MessagesVal);

    // 2. ��������� ���� �� ������ �������
    Tokens := MessageKey.Split(['.']);
    if Length(Tokens) = 0 then
        Exit;

    // 3. ����������� ���������� �� ������ �������� �� �������������� ����
    for I := 0 to High(Tokens) - 1 do
    begin
        CurrentVal := CurrentObj.GetValue(Tokens[I]);

        if Assigned(CurrentVal) and (CurrentVal is TJSONString) then
        begin
            // ������: �� ����� ������ (����� ���� ������ �� �����), � ��� ��������� ������!
            Result := Format('[ERROR: Token "%s" in key "%s" is a string, expected an object]', [Tokens[I], MessageKey]);
            Exit;
        end;

        if Assigned(CurrentVal) and (CurrentVal is TJSONObject) then
            CurrentObj := TJSONObject(CurrentVal)
        else
        begin
            // ������: ������ ������ ������ ��� � ���� �������
            ErrText := Format(ERR_INVALID_STRUCTURE, [Tokens[I], MessageKey]);
            Result := ErrText;
            if TThread.CurrentThread.ThreadID <> MainThreadID then
                TThread.Synchronize(nil,
                    procedure
                    begin
                        ShowMessage(ErrText);
                    end)
            else
                ShowMessage(ErrText);
            Exit;
        end;
    end;

    // 4. �� ����� �� �������� �������. ��������� �� ���� �������� ��������
    CurrentVal := CurrentObj.GetValue(Tokens[High(Tokens)]);

    if Assigned(CurrentVal) then
    begin
        // ���� ����� ���� � �� �����, �������������� Result ���������� ���������
        if CurrentVal is TJSONString then
        begin
            Result := CurrentVal.Value;
            Result := StringReplace(Result, '\n', #13#10, [rfReplaceAll]);
        end
        else
            Result := CurrentVal.ToString;
    end
    else
    begin
        Result := Format(ERR_KEY_NOT_FOUND, [MessageKey]);
    end;
    // ���� CurrentVal = nil, �� ������ �� ������, � ����� �����������,
    // ��������� Result � ������� ������.
end;

initialization

finalization
    // �������������� ������� ������ ��� ���������� ������ ���������
    if Assigned(GCachedLanguageData) then
        GCachedLanguageData.Free;

end.

