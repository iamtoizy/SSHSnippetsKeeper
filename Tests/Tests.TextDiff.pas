unit Tests.TextDiff;

interface

uses
    DUnitX.TestFramework,
    Core.TextDiff
    ;

type
    [TestFixture]
    TTextDiffTests = class(TObject)
    private
        function Kinds(const Diff: TArray<TDiffLine>): string;
        function CountKind(const Diff: TArray<TDiffLine>; Kind: TDiffLineKind): Integer;
    public
        [Test]
        procedure IdenticalTexts_AllEqual;
        [Test]
        procedure ChangedMiddleLine_DeleteThenInsert;
        [Test]
        procedure InsertedMiddleLine_SingleInsert;
        [Test]
        procedure RemovedMiddleLine_SingleDelete;
        [Test]
        procedure CRLFAndTrailingNewline_TreatedAsPlainLines;
        [Test]
        procedure EmptyOldText_AllInserts;
        [Test]
        procedure ToUnified_TrimsEqualContext;
        [Test]
        procedure LargeDisjointTexts_FullReplace;
    end;

implementation

uses
    System.SysUtils
    ;

{ TTextDiffTests }

function TTextDiffTests.Kinds(const Diff: TArray<TDiffLine>): string;
var
    I: Integer;
begin
    Result := '';
    for I := 0 to High(Diff) do
    begin
        if I > 0 then
            Result := Result + ',';
        case Diff[I].Kind of
            dlEqual: Result := Result + '=';
            dlDelete: Result := Result + '-';
            dlInsert: Result := Result + '+';
        end;
    end;
end;

function TTextDiffTests.CountKind(const Diff: TArray<TDiffLine>; Kind: TDiffLineKind): Integer;
var
    Line: TDiffLine;
begin
    Result := 0;
    for Line in Diff do
        if Line.Kind = Kind then
            Inc(Result);
end;

procedure TTextDiffTests.IdenticalTexts_AllEqual;
var
    Diff: TArray<TDiffLine>;
begin
    Diff := TTextDiff.Compute('a'#10'b'#10'c', 'a'#10'b'#10'c');
    Assert.AreEqual(3, Integer(Length(Diff)));
    Assert.AreEqual('=,=,=', Kinds(Diff));
    Assert.AreEqual('b', Diff[1].Text);
    Assert.AreEqual(2, Diff[1].OldNo);
    Assert.AreEqual(2, Diff[1].NewNo);
end;

procedure TTextDiffTests.ChangedMiddleLine_DeleteThenInsert;
var
    Diff: TArray<TDiffLine>;
begin
    Diff := TTextDiff.Compute('a'#10'b'#10'c', 'a'#10'x'#10'c');
    Assert.AreEqual('=,-,+,=', Kinds(Diff));
    Assert.AreEqual('b', Diff[1].Text);
    Assert.AreEqual(2, Diff[1].OldNo);
    Assert.AreEqual(0, Diff[1].NewNo);
    Assert.AreEqual('x', Diff[2].Text);
    Assert.AreEqual(0, Diff[2].OldNo);
    Assert.AreEqual(2, Diff[2].NewNo);
end;

procedure TTextDiffTests.InsertedMiddleLine_SingleInsert;
var
    Diff: TArray<TDiffLine>;
begin
    Diff := TTextDiff.Compute('a'#10'c', 'a'#10'b'#10'c');
    Assert.AreEqual('=,+,=', Kinds(Diff));
    Assert.AreEqual('b', Diff[1].Text);
    Assert.AreEqual(0, Diff[1].OldNo);
    Assert.AreEqual(2, Diff[1].NewNo);
end;

procedure TTextDiffTests.RemovedMiddleLine_SingleDelete;
var
    Diff: TArray<TDiffLine>;
begin
    Diff := TTextDiff.Compute('a'#10'b'#10'c', 'a'#10'c');
    Assert.AreEqual('=,-,=', Kinds(Diff));
    Assert.AreEqual('b', Diff[0 + 1].Text);
    Assert.AreEqual(2, Diff[1].OldNo);
    Assert.AreEqual(0, Diff[1].NewNo);
end;

procedure TTextDiffTests.CRLFAndTrailingNewline_TreatedAsPlainLines;
var
    Diff: TArray<TDiffLine>;
begin
    Diff := TTextDiff.Compute('a'#13#10'b'#13#10, 'a'#10'b');
    Assert.AreEqual(2, Integer(Length(Diff)));
    Assert.AreEqual('=,=', Kinds(Diff));
end;

procedure TTextDiffTests.EmptyOldText_AllInserts;
var
    Diff: TArray<TDiffLine>;
begin
    Diff := TTextDiff.Compute('', 'x');
    Assert.AreEqual(1, Integer(Length(Diff)));
    Assert.AreEqual('+', Kinds(Diff));
    Assert.AreEqual('x', Diff[0].Text);
    Assert.AreEqual(0, Diff[0].OldNo);
    Assert.AreEqual(1, Diff[0].NewNo);
end;

procedure TTextDiffTests.ToUnified_TrimsEqualContext;
var
    OldText, NewText: string;
    I: Integer;
    Unified: TArray<TDiffLine>;
begin
    for I := 1 to 10 do
        OldText := OldText + 'L' + I.ToString + #10;
    for I := 1 to 10 do
        if I = 5 then
            NewText := NewText + 'X5' + #10
        else
            NewText := NewText + 'L' + I.ToString + #10;

    Unified := TTextDiff.ToUnified(OldText, NewText, 2);

    Assert.AreEqual(6, Integer(Length(Unified)));
    Assert.AreEqual('L3', Unified[0].Text);
    Assert.AreEqual('L4', Unified[1].Text);
    Assert.AreEqual('L5', Unified[2].Text);
    Assert.AreEqual('X5', Unified[3].Text);
    Assert.AreEqual('L6', Unified[4].Text);
    Assert.AreEqual('L7', Unified[5].Text);
end;

procedure TTextDiffTests.LargeDisjointTexts_FullReplace;
var
    OldText, NewText: string;
    I: Integer;
    Diff: TArray<TDiffLine>;
begin
    for I := 1 to 1500 do
        OldText := OldText + 'old' + I.ToString + #10;
    for I := 1 to 1500 do
        NewText := NewText + 'new' + I.ToString + #10;

    Diff := TTextDiff.Compute(OldText, NewText);

    Assert.AreEqual(3000, Integer(Length(Diff)));
    Assert.AreEqual(1500, CountKind(Diff, dlDelete));
    Assert.AreEqual(1500, CountKind(Diff, dlInsert));
end;

end.
