unit MacroCounters;

interface

uses
    Common.AppState, System.Generics.Collections, System.Generics.Defaults,
    System.SysUtils
    ;

const
    MAX_COUNTER_PAD = 18;
    DEFAULT_COUNTER_START = 1;
    DEFAULT_COUNTER_STEP = 1;

type
    TCounterParams = record
        StartValue: Int64;
        Step: Int64;
        Pad: Integer;
        CurrentOnly: Boolean;
        Volatile: Boolean;
    end;

    TCounterEntry = record
        SnippetID: Integer;
        Current: Int64;
    end;

    TCounterRunState = record
        HasValue: Boolean;
        Value: Int64;
    end;

    TMacroCounterStore = class
    private
        FAppState: TAppStateStore;
        FOwnsAppState: Boolean;
        FFilePath: string;
        FLock: TObject;
        FValues: TDictionary<Integer, Int64>;
        FLoaded: Boolean;
        constructor Create(const AAppState: TAppStateStore; AOwnsAppState: Boolean); overload;
        procedure EnsureLoaded;
        procedure LoadLocked;
        procedure SaveLocked;
    public
        constructor Create; overload;
        constructor Create(const AFilePath: string); overload;
        destructor Destroy; override;
        function Take(ASnippetID: Integer; const AParams: TCounterParams): Int64;
        function Peek(ASnippetID: Integer; const AParams: TCounterParams): Int64;
        function NextValue(ASnippetID: Integer; const AParams: TCounterParams): Int64;
        procedure Reset(ASnippetID: Integer);
        procedure ResetAll;
        function Snapshot: TArray<TCounterEntry>;
        property FilePath: string read FFilePath;
    end;

function Counters: TMacroCounterStore;
function DefaultCounterParams: TCounterParams;
function TryParseCounterParams(const AArg: string; out AParams: TCounterParams): Boolean;
function IsCounterParamsValid(const AArg: string): Boolean;
function FormatCounterValue(AValue: Int64; APad: Integer): string;
function EvaluateCounter(ASnippetID: Integer; const AArg: string; var ARunState: TCounterRunState): string;
function EvaluateCounterPeek(ASnippetID: Integer; const AArg: string; var ARunState: TCounterRunState): string;

implementation

uses
    System.JSON, System.Math
    ;

var
    GCounters: TMacroCounterStore;

function Counters: TMacroCounterStore;
begin
    Result := GCounters;
end;

function DefaultCounterParams: TCounterParams;
begin
    Result := Default(TCounterParams);
    Result.StartValue := DEFAULT_COUNTER_START;
    Result.Step := DEFAULT_COUNTER_STEP;
    Result.Pad := 0;
end;

function AddSaturating(AValue, ADelta: Int64): Int64;
begin
    if ADelta >= 0 then
    begin
        if AValue > High(Int64) - ADelta then
            Exit(High(Int64));
    end
    else
    begin
        if AValue < Low(Int64) - ADelta then
            Exit(Low(Int64));
    end;
    Result := AValue + ADelta;
end;

function TryParseCounterParams(const AArg: string; out AParams: TCounterParams): Boolean;
var
    Parts: TArray<string>;
    Raw, Part, Name, ValueText: string;
    EqPos: Integer;
    Value: Int64;
begin
    AParams := DefaultCounterParams;

    if Trim(AArg) = '' then
        Exit(True);

    Parts := AArg.Split([';']);
    for Raw in Parts do
    begin
        Part := Trim(Raw);
        if Part = '' then
            Continue;

        if SameText(Part, 'volatile') then
        begin
            AParams.Volatile := True;
            Continue;
        end;

        if SameText(Part, 'current') then
        begin
            AParams.CurrentOnly := True;
            Continue;
        end;

        EqPos := Pos('=', Part);
        if EqPos <= 1 then
            Exit(False);

        Name := LowerCase(Trim(Copy(Part, 1, EqPos - 1)));
        ValueText := Trim(Copy(Part, EqPos + 1, MaxInt));

        if not TryStrToInt64(ValueText, Value) then
            Exit(False);

        if Name = 'start' then
            AParams.StartValue := Value
        else if Name = 'step' then
        begin
            if Value = 0 then
                Exit(False);
            AParams.Step := Value;
        end
        else if Name = 'pad' then
        begin
            if (Value < 1) or (Value > MAX_COUNTER_PAD) then
                Exit(False);
            AParams.Pad := Integer(Value);
        end
        else
            Exit(False);
    end;

    Result := True;
end;

function IsCounterParamsValid(const AArg: string): Boolean;
var
    Params: TCounterParams;
begin
    Result := TryParseCounterParams(AArg, Params);
end;

function FormatCounterValue(AValue: Int64; APad: Integer): string;
begin
    Result := IntToStr(AValue);
    if APad > Length(Result) then
        Result := StringOfChar('0', APad - Length(Result)) + Result;
end;

function EvaluateCounter(ASnippetID: Integer; const AArg: string; var ARunState: TCounterRunState): string;
var
    Params: TCounterParams;
    Value: Int64;
begin
    if not TryParseCounterParams(AArg, Params) then
        Exit('');

    if Params.CurrentOnly then
    begin
        if ARunState.HasValue then
            Value := ARunState.Value
        else
            Value := Counters.Peek(ASnippetID, Params);
    end
    else
    begin
        Value := Counters.Take(ASnippetID, Params);
        ARunState.Value := Value;
        ARunState.HasValue := True;
    end;

    Result := FormatCounterValue(Value, Params.Pad);
end;

// Превью EvaluateCounter для сухого прогона: та же цепочка значений прогона
// (state), но Take-счётчик читается через NextValue без потребления
function EvaluateCounterPeek(ASnippetID: Integer; const AArg: string; var ARunState: TCounterRunState): string;
var
    Params: TCounterParams;
    Value: Int64;
begin
    if not TryParseCounterParams(AArg, Params) then
        Exit('');

    if Params.CurrentOnly then
    begin
        if ARunState.HasValue then
            Value := ARunState.Value
        else
            Value := Counters.Peek(ASnippetID, Params);
    end
    else
    begin
        // Как Take: первое значение из хранилища, далее цепочка от state,
        // потому что после каждого Take хранилище равно последнему выданному
        if ARunState.HasValue then
            Value := AddSaturating(ARunState.Value, Params.Step)
        else
            Value := Counters.NextValue(ASnippetID, Params);
        ARunState.Value := Value;
        ARunState.HasValue := True;
    end;

    Result := FormatCounterValue(Value, Params.Pad);
end;

{ TMacroCounterStore }

constructor TMacroCounterStore.Create;
begin
    Create(AppState, False);
end;

constructor TMacroCounterStore.Create(const AFilePath: string);
begin
    Create(TAppStateStore.Create(AFilePath), True);
end;

constructor TMacroCounterStore.Create(const AAppState: TAppStateStore; AOwnsAppState: Boolean);
begin
    inherited Create;
    FAppState := AAppState;
    FOwnsAppState := AOwnsAppState;
    FFilePath := FAppState.FilePath;
    FValues := TDictionary<Integer, Int64>.Create;
    FLock := TObject.Create;
    FLoaded := False;
end;

destructor TMacroCounterStore.Destroy;
begin
    if FOwnsAppState then
        FAppState.Free;
    FValues.Free;
    FLock.Free;
    inherited;
end;

procedure TMacroCounterStore.EnsureLoaded;
begin
    if FLoaded then
        Exit;
    LoadLocked;
    FLoaded := True;
end;

procedure TMacroCounterStore.LoadLocked;
var
    Section, Item: TJSONValue;
    CounterObj: TJSONObject;
    Id: Integer;
    Value: Int64;
begin
    FLoaded := True;
    Section := FAppState.ReadSection('counters');
    if Section = nil then
        Exit;

    try
        if not (Section is TJSONArray) then
            Exit;
        for Item in TJSONArray(Section) do
        begin
            if not (Item is TJSONObject) then
                Continue;
            CounterObj := TJSONObject(Item);
            if not CounterObj.TryGetValue<Integer>('snippetId', Id) then
                Continue;
            if not CounterObj.TryGetValue<Int64>('current', Value) then
                Continue;
            FValues.AddOrSetValue(Id, Value);
        end;
    finally
        Section.Free;
    end;
end;

procedure TMacroCounterStore.SaveLocked;
var
    Arr: TJSONArray;
    CounterObj: TJSONObject;
    Pair: TPair<Integer, Int64>;
begin
    Arr := TJSONArray.Create;
    for Pair in FValues do
    begin
        CounterObj := TJSONObject.Create;
        CounterObj.AddPair('snippetId', TJSONNumber.Create(Pair.Key));
        CounterObj.AddPair('current', TJSONNumber.Create(Pair.Value));
        Arr.AddElement(CounterObj);
    end;
    FAppState.WriteSection('counters', Arr);
end;

function TMacroCounterStore.Take(ASnippetID: Integer; const AParams: TCounterParams): Int64;
var
    Current: Int64;
begin
    TMonitor.Enter(FLock);
    try
        EnsureLoaded;
        if FValues.TryGetValue(ASnippetID, Current) then
            Current := AddSaturating(Current, AParams.Step)
        else
            Current := AParams.StartValue;
        FValues.AddOrSetValue(ASnippetID, Current);
        if not AParams.Volatile then
            SaveLocked;
        Result := Current;
    finally
        TMonitor.Exit(FLock);
    end;
end;

function TMacroCounterStore.Peek(ASnippetID: Integer; const AParams: TCounterParams): Int64;
begin
    TMonitor.Enter(FLock);
    try
        EnsureLoaded;
        if not FValues.TryGetValue(ASnippetID, Result) then
            Result := AParams.StartValue;
    finally
        TMonitor.Exit(FLock);
    end;
end;

// Take-вычисление без записи: current+step (или start), хранилище не меняет
function TMacroCounterStore.NextValue(ASnippetID: Integer; const AParams: TCounterParams): Int64;
var
    Current: Int64;
begin
    TMonitor.Enter(FLock);
    try
        EnsureLoaded;
        if FValues.TryGetValue(ASnippetID, Current) then
            Result := AddSaturating(Current, AParams.Step)
        else
            Result := AParams.StartValue;
    finally
        TMonitor.Exit(FLock);
    end;
end;

procedure TMacroCounterStore.Reset(ASnippetID: Integer);
begin
    TMonitor.Enter(FLock);
    try
        EnsureLoaded;
        FValues.Remove(ASnippetID);
        SaveLocked;
    finally
        TMonitor.Exit(FLock);
    end;
end;

procedure TMacroCounterStore.ResetAll;
begin
    TMonitor.Enter(FLock);
    try
        EnsureLoaded;
        FValues.Clear;
        SaveLocked;
    finally
        TMonitor.Exit(FLock);
    end;
end;

function TMacroCounterStore.Snapshot: TArray<TCounterEntry>;
var
    Pair: TPair<Integer, Int64>;
    Entry: TCounterEntry;
    Idx: Integer;
begin
    TMonitor.Enter(FLock);
    try
        EnsureLoaded;
        SetLength(Result, FValues.Count);
        Idx := 0;
        for Pair in FValues do
        begin
            Entry.SnippetID := Pair.Key;
            Entry.Current := Pair.Value;
            Result[Idx] := Entry;
            Inc(Idx);
        end;
    finally
        TMonitor.Exit(FLock);
    end;
    TArray.Sort<TCounterEntry>(Result, TComparer<TCounterEntry>.Construct(
        function(const Left, Right: TCounterEntry): Integer
        begin
            Result := CompareValue(Left.SnippetID, Right.SnippetID);
        end));
end;

initialization
    GCounters := TMacroCounterStore.Create;

finalization
    FreeAndNil(GCounters);

end.
