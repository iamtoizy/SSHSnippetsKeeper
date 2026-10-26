unit Tests.MacroCounters;

interface

uses
    DUnitX.TestFramework,
    MacroCounters,
    System.IOUtils,
    System.SysUtils
    ;

type
    [TestFixture]
    TMacroCountersTests = class(TObject)
    private
        function FreshPath: string;
        function MakeParams(AStart, AStep: Int64; APad: Integer;
            ACurrentOnly, AVolatile: Boolean): TCounterParams;
    public
        [Test]
        procedure Parse_Empty_Defaults;
        [Test]
        procedure Parse_FullParams;
        [Test]
        procedure Parse_Flags;
        [Test]
        procedure Parse_CaseInsensitive;
        [Test]
        procedure Parse_InvalidForms;
        [Test]
        procedure Take_StartsAndIncrements;
        [Test]
        procedure Take_CustomStartStep;
        [Test]
        procedure Peek_DoesNotConsume;
        [Test]
        procedure Peek_Empty_ReturnsStart;
        [Test]
        procedure NextValue_DoesNotConsume;
        [Test]
        procedure NextValue_MatchesTakeSequence;
        [Test]
        procedure EvaluateCounterPeek_MatchesRunSemantics;
        [Test]
        procedure Volatile_NotPersisted;
        [Test]
        procedure Persistence_Roundtrip;
        [Test]
        procedure Isolation_PerSnippet;
        [Test]
        procedure Reset_RemovesOne;
        [Test]
        procedure ResetAll_ClearsAll;
        [Test]
        procedure Snapshot_Sorted;
    end;

implementation

{ TMacroCountersTests }

function TMacroCountersTests.FreshPath: string;
begin
    Result := TPath.Combine(TPath.GetTempPath, 'ssk_test_counters.json');
    if TFile.Exists(Result) then
        TFile.Delete(Result);
end;

function TMacroCountersTests.MakeParams(AStart, AStep: Int64; APad: Integer;
    ACurrentOnly, AVolatile: Boolean): TCounterParams;
begin
    Result := DefaultCounterParams;
    Result.StartValue := AStart;
    Result.Step := AStep;
    Result.Pad := APad;
    Result.CurrentOnly := ACurrentOnly;
    Result.Volatile := AVolatile;
end;

procedure TMacroCountersTests.Parse_Empty_Defaults;
var
    P: TCounterParams;
begin
    Assert.IsTrue(TryParseCounterParams('', P));
    Assert.AreEqual(Int64(1), P.StartValue);
    Assert.AreEqual(Int64(1), P.Step);
    Assert.AreEqual(0, P.Pad);
    Assert.IsFalse(P.CurrentOnly);
    Assert.IsFalse(P.Volatile);
end;

procedure TMacroCountersTests.Parse_FullParams;
var
    P: TCounterParams;
begin
    Assert.IsTrue(TryParseCounterParams('start=7;step=-2;pad=5', P));
    Assert.AreEqual(Int64(7), P.StartValue);
    Assert.AreEqual(Int64(-2), P.Step);
    Assert.AreEqual(5, P.Pad);
    Assert.IsFalse(P.CurrentOnly);
    Assert.IsFalse(P.Volatile);
end;

procedure TMacroCountersTests.Parse_Flags;
var
    P: TCounterParams;
begin
    Assert.IsTrue(TryParseCounterParams('VOLATILE;Current', P));
    Assert.IsTrue(P.Volatile);
    Assert.IsTrue(P.CurrentOnly);
    Assert.AreEqual(Int64(1), P.StartValue);
end;

procedure TMacroCountersTests.Parse_CaseInsensitive;
var
    P: TCounterParams;
begin
    Assert.IsTrue(TryParseCounterParams('START=3; Pad = 2 ', P));
    Assert.AreEqual(Int64(3), P.StartValue);
    Assert.AreEqual(2, P.Pad);
end;

procedure TMacroCountersTests.Parse_InvalidForms;
var
    P: TCounterParams;
begin
    Assert.IsFalse(TryParseCounterParams('foo=1', P));
    Assert.IsFalse(TryParseCounterParams('start', P));
    Assert.IsFalse(TryParseCounterParams('start=', P));
    Assert.IsFalse(TryParseCounterParams('start=x', P));
    Assert.IsFalse(TryParseCounterParams('step=0', P));
    Assert.IsFalse(TryParseCounterParams('pad=0', P));
    Assert.IsFalse(TryParseCounterParams('pad=19', P));
    Assert.IsFalse(TryParseCounterParams('start=1;zzz', P));
    Assert.IsFalse(TryParseCounterParams('=', P));
    Assert.IsTrue(IsCounterParamsValid('volatile'));
    Assert.IsTrue(IsCounterParamsValid('current;pad=2'));
    Assert.IsFalse(IsCounterParamsValid('nonsense'));
end;

procedure TMacroCountersTests.Take_StartsAndIncrements;
var
    Store: TMacroCounterStore;
    Path: string;
begin
    Path := FreshPath;
    Store := TMacroCounterStore.Create(Path);
    try
        Assert.AreEqual(Int64(1), Store.Take(1, DefaultCounterParams));
        Assert.AreEqual(Int64(2), Store.Take(1, DefaultCounterParams));
        Assert.AreEqual(Int64(3), Store.Take(1, DefaultCounterParams));
    finally
        Store.Free;
    end;
    if TFile.Exists(Path) then TFile.Delete(Path);
end;

procedure TMacroCountersTests.Take_CustomStartStep;
var
    Store: TMacroCounterStore;
    Path: string;
begin
    Path := FreshPath;
    Store := TMacroCounterStore.Create(Path);
    try
        Assert.AreEqual(Int64(100), Store.Take(1, MakeParams(100, 2, 0, False, False)));
        Assert.AreEqual(Int64(102), Store.Take(1, MakeParams(100, 2, 0, False, False)));
        Assert.AreEqual(Int64(10), Store.Take(2, MakeParams(10, -3, 0, False, False)));
        Assert.AreEqual(Int64(7), Store.Take(2, MakeParams(10, -3, 0, False, False)));
    finally
        Store.Free;
    end;
    if TFile.Exists(Path) then TFile.Delete(Path);
end;

procedure TMacroCountersTests.Peek_DoesNotConsume;
var
    Store: TMacroCounterStore;
    Path: string;
begin
    Path := FreshPath;
    Store := TMacroCounterStore.Create(Path);
    try
        Assert.AreEqual(Int64(1), Store.Take(1, DefaultCounterParams));
        Assert.AreEqual(Int64(1), Store.Peek(1, DefaultCounterParams));
        Assert.AreEqual(Int64(1), Store.Peek(1, DefaultCounterParams));
        Assert.AreEqual(Int64(2), Store.Take(1, DefaultCounterParams));
    finally
        Store.Free;
    end;
    if TFile.Exists(Path) then TFile.Delete(Path);
end;

procedure TMacroCountersTests.Peek_Empty_ReturnsStart;
var
    Store: TMacroCounterStore;
    Path: string;
begin
    Path := FreshPath;
    Store := TMacroCounterStore.Create(Path);
    try
        Assert.AreEqual(Int64(42), Store.Peek(5, MakeParams(42, 1, 0, False, False)));
    finally
        Store.Free;
    end;
    if TFile.Exists(Path) then TFile.Delete(Path);
end;

procedure TMacroCountersTests.NextValue_DoesNotConsume;
var
    Store: TMacroCounterStore;
    Path: string;
begin
    Path := FreshPath;
    Store := TMacroCounterStore.Create(Path);
    try
        Assert.AreEqual(Int64(1), Store.NextValue(1, DefaultCounterParams));
        Assert.AreEqual(Int64(1), Store.NextValue(1, DefaultCounterParams));
        Assert.AreEqual(Int64(1), Store.Take(1, DefaultCounterParams));
        Assert.AreEqual(Int64(2), Store.NextValue(1, DefaultCounterParams));
        Assert.AreEqual(Int64(2), Store.Take(1, DefaultCounterParams));
    finally
        Store.Free;
    end;
    if TFile.Exists(Path) then TFile.Delete(Path);
end;

procedure TMacroCountersTests.NextValue_MatchesTakeSequence;
var
    Store: TMacroCounterStore;
    Path: string;
begin
    Path := FreshPath;
    Store := TMacroCounterStore.Create(Path);
    try
        Assert.AreEqual(Int64(100), Store.Take(1, MakeParams(100, 2, 0, False, False)));
        Assert.AreEqual(Int64(102), Store.NextValue(1, MakeParams(100, 2, 0, False, False)));
        Assert.AreEqual(Int64(102), Store.NextValue(1, MakeParams(100, 2, 0, False, False)));
        Assert.AreEqual(Int64(102), Store.Take(1, MakeParams(100, 2, 0, False, False)));
    finally
        Store.Free;
    end;
    if TFile.Exists(Path) then TFile.Delete(Path);
end;

procedure TMacroCountersTests.EvaluateCounterPeek_MatchesRunSemantics;
var
    RunState: TCounterRunState;
begin
    Counters.ResetAll;
    RunState := Default(TCounterRunState);

    // Пустой счётчик: превью первого значения
    Assert.AreEqual('1', EvaluateCounterPeek(1, '', RunState));

    // Цепочка внутри прогона: state+step, как три Take подряд
    Assert.AreEqual('2', EvaluateCounterPeek(1, '', RunState));
    Assert.AreEqual('003', EvaluateCounterPeek(1, 'pad=3', RunState));

    // Превью ничего не потребило: реальный запуск выдаёт 1
    RunState := Default(TCounterRunState);
    Assert.AreEqual('1', EvaluateCounter(1, '', RunState));

    // current: как Peek, без потребления
    RunState := Default(TCounterRunState);
    Assert.AreEqual('1', EvaluateCounter(1, 'current', RunState));
    Assert.AreEqual('1', EvaluateCounterPeek(1, 'current', RunState));

    Counters.Reset(1);
end;

procedure TMacroCountersTests.Volatile_NotPersisted;
var
    Store: TMacroCounterStore;
    Path: string;
begin
    Path := FreshPath;
    Store := TMacroCounterStore.Create(Path);
    try
        Assert.AreEqual(Int64(1), Store.Take(1, DefaultCounterParams));
        Assert.AreEqual(Int64(2), Store.Take(1, MakeParams(1, 1, 0, False, True)));
    finally
        Store.Free;
    end;

    Store := TMacroCounterStore.Create(Path);
    try
        Assert.AreEqual(Int64(1), Store.Peek(1, DefaultCounterParams));
        Assert.AreEqual(Int64(2), Store.Take(1, DefaultCounterParams));
    finally
        Store.Free;
    end;
    if TFile.Exists(Path) then TFile.Delete(Path);
end;

procedure TMacroCountersTests.Persistence_Roundtrip;
var
    Store: TMacroCounterStore;
    Path: string;
begin
    Path := FreshPath;
    Store := TMacroCounterStore.Create(Path);
    try
        Store.Take(1, DefaultCounterParams);
        Store.Take(2, MakeParams(10, 5, 0, False, False));
    finally
        Store.Free;
    end;

    Store := TMacroCounterStore.Create(Path);
    try
        Assert.AreEqual(Int64(1), Store.Peek(1, DefaultCounterParams));
        Assert.AreEqual(Int64(10), Store.Peek(2, MakeParams(10, 5, 0, False, False)));
        Assert.AreEqual(Int64(2), Store.Take(1, DefaultCounterParams));
    finally
        Store.Free;
    end;
    if TFile.Exists(Path) then TFile.Delete(Path);
end;

procedure TMacroCountersTests.Isolation_PerSnippet;
var
    Store: TMacroCounterStore;
    Path: string;
begin
    Path := FreshPath;
    Store := TMacroCounterStore.Create(Path);
    try
        Assert.AreEqual(Int64(1), Store.Take(1, DefaultCounterParams));
        Assert.AreEqual(Int64(1), Store.Take(2, DefaultCounterParams));
        Assert.AreEqual(Int64(2), Store.Take(1, DefaultCounterParams));
    finally
        Store.Free;
    end;
    if TFile.Exists(Path) then TFile.Delete(Path);
end;

procedure TMacroCountersTests.Reset_RemovesOne;
var
    Store: TMacroCounterStore;
    Path: string;
begin
    Path := FreshPath;
    Store := TMacroCounterStore.Create(Path);
    try
        Store.Take(1, DefaultCounterParams);
        Store.Take(2, DefaultCounterParams);
        Store.Reset(1);
    finally
        Store.Free;
    end;

    Store := TMacroCounterStore.Create(Path);
    try
        Assert.AreEqual(Int64(1), Store.Peek(1, DefaultCounterParams));
        Assert.AreEqual(Int64(1), Store.Peek(2, DefaultCounterParams));
    finally
        Store.Free;
    end;
    if TFile.Exists(Path) then TFile.Delete(Path);
end;

procedure TMacroCountersTests.ResetAll_ClearsAll;
var
    Store: TMacroCounterStore;
    Path: string;
    Entries: TArray<TCounterEntry>;
begin
    Path := FreshPath;
    Store := TMacroCounterStore.Create(Path);
    try
        Store.Take(1, DefaultCounterParams);
        Store.Take(2, DefaultCounterParams);
        Store.ResetAll;
        Entries := Store.Snapshot;
    finally
        Store.Free;
    end;
    Assert.AreEqual(0, Integer(Length(Entries)));
    if TFile.Exists(Path) then TFile.Delete(Path);
end;

procedure TMacroCountersTests.Snapshot_Sorted;
var
    Store: TMacroCounterStore;
    Path: string;
    Entries: TArray<TCounterEntry>;
begin
    Path := FreshPath;
    Store := TMacroCounterStore.Create(Path);
    try
        Store.Take(3, DefaultCounterParams);
        Store.Take(1, DefaultCounterParams);
        Store.Take(2, DefaultCounterParams);
        Entries := Store.Snapshot;
    finally
        Store.Free;
    end;
    Assert.AreEqual(3, Integer(Length(Entries)));
    Assert.AreEqual(1, Entries[0].SnippetID);
    Assert.AreEqual(2, Entries[1].SnippetID);
    Assert.AreEqual(3, Entries[2].SnippetID);
    Assert.AreEqual(Int64(1), Entries[0].Current);
    if TFile.Exists(Path) then TFile.Delete(Path);
end;

end.
