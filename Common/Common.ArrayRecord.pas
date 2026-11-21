unit Common.ArrayRecord;

// Спецификация: docs\ArrayHelper.SPEC.md
// Clean-room замена ThirdParty\ArrayHelper.pas (используемая часть -
// TArrayRecord<T>). Поведение зафиксировано эмпирической пробой и
// golden-фикстурами docs\ArrayHelper.FIXTURES.txt.
// Важно: RTTI-форма записи - ровно один public field Items: TArray<T>.
// Свойство Count в RTTI записи не экспортируется; добавление новых
// public-полей ломает JSON-сериализацию настроек (Tests.JsonSerializer).

interface

uses
    System.SysUtils,
    System.Generics.Defaults
    ;

type
    TArrayRecord<T> = record
    public type
        TEnumerator = record
        private
            FItems: TArray<T>;
            FIndex: Integer;
            function GetCurrent: T;
        public
            constructor Create(const AItems: TArray<T>);
            function MoveNext: Boolean;
            property Current: T read GetCurrent;
        end;
    public
        Items: TArray<T>;

        constructor Create(ACapacity: Integer); overload;
        constructor Create(const AValues: array of T); overload;

        function GetCount: Integer;
        procedure SetCount(const Value: Integer);
        function GetItemAt(Index: Integer): T;
        procedure SetItemAt(Index: Integer; Value: T);

        procedure Clear;
        function Add(const Value: T): Integer;
        procedure Delete(Index: Integer);
        procedure Insert(Index: Integer; Value: T);
        function Remove(const AItem: T): Boolean;
        function AddIfNotContains(const AItem: T): Boolean;
        function IndexOf(const Item: T): Integer;
        function Contains(const Item: T): Boolean;
        function GetEnumerator: TEnumerator;

        property Count: Integer read GetCount write SetCount;
        property ItemAt[Index: Integer]: T read GetItemAt write SetItemAt; default;
    end;

implementation

constructor TArrayRecord<T>.TEnumerator.Create(const AItems: TArray<T>);
begin
    FItems := AItems;
    FIndex := -1;
end;

function TArrayRecord<T>.TEnumerator.GetCurrent: T;
begin
    Result := FItems[FIndex];
end;

function TArrayRecord<T>.TEnumerator.MoveNext: Boolean;
begin
    Result := FIndex < High(FItems);
    if Result then
        Inc(FIndex);
end;

constructor TArrayRecord<T>.Create(ACapacity: Integer);
begin
    SetLength(Items, ACapacity);
end;

constructor TArrayRecord<T>.Create(const AValues: array of T);
var
    I: Integer;
begin
    SetLength(Items, Length(AValues));
    for I := 0 to High(AValues) do
        Items[I] := AValues[I];
end;

procedure TArrayRecord<T>.Clear;
begin
    Items := nil;
end;

function TArrayRecord<T>.Add(const Value: T): Integer;
begin
    Result := Length(Items);
    Insert(Result, Value);
end;

procedure TArrayRecord<T>.Delete(Index: Integer);
var
    I: Integer;
begin
    if (Index < 0) or (Index >= Length(Items)) then
        raise EArgumentOutOfRangeException.Create('Argument out of range');
    for I := Index + 1 to High(Items) do
        Items[I - 1] := Items[I];
    SetLength(Items, Length(Items) - 1);
end;

procedure TArrayRecord<T>.Insert(Index: Integer; Value: T);
var
    I: Integer;
    OldLen: Integer;
begin
    OldLen := Length(Items);
    if (Index < 0) or (Index > OldLen) then
        raise EArgumentOutOfRangeException.Create('Argument out of range');
    SetLength(Items, OldLen + 1);
    for I := OldLen - 1 downto Index do
        Items[I + 1] := Items[I];
    Items[Index] := Value;
end;

function TArrayRecord<T>.Remove(const AItem: T): Boolean;
var
    Idx: Integer;
begin
    Idx := IndexOf(AItem);
    if Idx >= 0 then
    begin
        Delete(Idx);
        Result := True;
    end
    else
        Result := False;
end;

function TArrayRecord<T>.AddIfNotContains(const AItem: T): Boolean;
begin
    if Contains(AItem) then
        Result := False
    else
    begin
        Add(AItem);
        Result := True;
    end;
end;

function TArrayRecord<T>.IndexOf(const Item: T): Integer;
var
    Comparer: IEqualityComparer<T>;
    I: Integer;
begin
    Comparer := TEqualityComparer<T>.Default;
    for I := 0 to High(Items) do
        if Comparer.Equals(Items[I], Item) then
            Exit(I);
    Result := -1;
end;

function TArrayRecord<T>.Contains(const Item: T): Boolean;
begin
    Result := IndexOf(Item) >= 0;
end;

function TArrayRecord<T>.GetEnumerator: TEnumerator;
begin
    Result := TEnumerator.Create(Items);
end;

function TArrayRecord<T>.GetCount: Integer;
begin
    Result := Length(Items);
end;

procedure TArrayRecord<T>.SetCount(const Value: Integer);
begin
    SetLength(Items, Value);
end;

function TArrayRecord<T>.GetItemAt(Index: Integer): T;
begin
    Result := Items[Index];
end;

procedure TArrayRecord<T>.SetItemAt(Index: Integer; Value: T);
begin
    Items[Index] := Value;
end;

end.
