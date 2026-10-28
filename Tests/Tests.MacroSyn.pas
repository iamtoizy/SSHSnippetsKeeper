unit Tests.MacroSyn;

interface

uses
    DUnitX.TestFramework,
    MacroEngine,
    SynEditTypes,
    SynEditHighlighter,
    System.RegularExpressions,
    MacroSyn
    ;

type
    TTokenInfo = record
        Text: string;
        Kind: Integer;
    end;

    [TestFixture]
    TMacroSynTests = class(TObject)
    private
        function Tokenize(const Line: string): TArray<TTokenInfo>;
    public
        [Test]
        procedure Tokenize_MacroWithArgs;
        [Test]
        procedure Tokenize_PlainTextAndMixed;
        [Test]
        procedure Tokenize_EmptyAndUnclosed;
    end;

    [TestFixture]
    TMacroBodySynTests = class(TObject)
    public
        [Test]
        procedure Body_DirectiveAndArgs;
        [Test]
        procedure Body_ContinuationLine_StaysArg;
    end;

    [TestFixture]
    TMacroSchemeRegexTests = class(TObject)
    public
        [Test]
        procedure Scheme_Matches_KnownDirectives;
        [Test]
        procedure Scheme_Ignores_LanguageBraces;
        [Test]
        procedure Registry_MatchesEngineKnowledge;
    end;

implementation

uses
    System.Generics.Collections,
    System.SysUtils
    ;

{ TMacroSynTests }

function TMacroSynTests.Tokenize(const Line: string): TArray<TTokenInfo>;
var
    Syn: TMacroSyn;
    List: TList<TTokenInfo>;
    Info: TTokenInfo;
begin
    Syn := TMacroSyn.Create(nil);
    try
        List := TList<TTokenInfo>.Create;
        try
            Syn.SetLine(Line, 1);
            while not Syn.GetEol do
            begin
                Info.Text := Syn.GetToken;
                Info.Kind := Syn.GetTokenKind;
                List.Add(Info);
                Syn.Next;
            end;
            Result := List.ToArray;
        finally
            List.Free;
        end;
    finally
        Syn.Free;
    end;
end;

procedure TMacroSynTests.Tokenize_MacroWithArgs;
var
    Tokens: TArray<TTokenInfo>;
begin
    Tokens := Tokenize('{INPUT[SELECT:1|2] name}abc');

    Assert.AreEqual(5, Integer(Length(Tokens)));
    Assert.AreEqual('{', Tokens[0].Text);
    Assert.AreEqual(Ord(mtkBrace), Tokens[0].Kind);
    Assert.AreEqual('INPUT', Tokens[1].Text);
    Assert.AreEqual(Ord(mtkKey), Tokens[1].Kind);
    Assert.AreEqual('[SELECT:1|2] name', Tokens[2].Text);
    Assert.AreEqual(Ord(mtkArg), Tokens[2].Kind);
    Assert.AreEqual('}', Tokens[3].Text);
    Assert.AreEqual(Ord(mtkBrace), Tokens[3].Kind);
    Assert.AreEqual('abc', Tokens[4].Text);
    Assert.AreEqual(Ord(mtkText), Tokens[4].Kind);
end;

procedure TMacroSynTests.Tokenize_PlainTextAndMixed;
var
    Tokens: TArray<TTokenInfo>;
begin
    Tokens := Tokenize('ssh user@host');
    Assert.AreEqual(1, Integer(Length(Tokens)));
    Assert.AreEqual('ssh user@host', Tokens[0].Text);
    Assert.AreEqual(Ord(mtkText), Tokens[0].Kind);

    Tokens := Tokenize('echo {SLEEP 500} done');
    Assert.AreEqual(6, Integer(Length(Tokens)));
    Assert.AreEqual('echo ', Tokens[0].Text);
    Assert.AreEqual('{', Tokens[1].Text);
    Assert.AreEqual('SLEEP', Tokens[2].Text);
    Assert.AreEqual(' 500', Tokens[3].Text);
    Assert.AreEqual('}', Tokens[4].Text);
    Assert.AreEqual(' done', Tokens[5].Text);
    Assert.AreEqual(Ord(mtkText), Tokens[5].Kind);
end;

procedure TMacroSynTests.Tokenize_EmptyAndUnclosed;
var
    Tokens: TArray<TTokenInfo>;
begin
    Tokens := Tokenize('');
    Assert.AreEqual(0, Integer(Length(Tokens)));

    Tokens := Tokenize('{}');
    Assert.AreEqual(2, Integer(Length(Tokens)));
    Assert.AreEqual('{', Tokens[0].Text);
    Assert.AreEqual('}', Tokens[1].Text);

    // Незакрытая скобка: имя и хвост раскрашиваются как макрос, перенос строки сбрасывает
    Tokens := Tokenize('a{FOO no close');
    Assert.AreEqual(4, Integer(Length(Tokens)));
    Assert.AreEqual('a', Tokens[0].Text);
    Assert.AreEqual('{', Tokens[1].Text);
    Assert.AreEqual('FOO', Tokens[2].Text);
    Assert.AreEqual(' no close', Tokens[3].Text);
end;

{ TMacroBodySynTests }

procedure TMacroBodySynTests.Body_DirectiveAndArgs;
var
    Syn: TMacroBodySyn;
begin
    Syn := TMacroBodySyn.Create(nil);
    try
        // На вход TSynMultiSyn подает тело макроса без '{' и '}'
        Syn.SetLine('INPUT[SELECT:1|2] name', 1);

        Assert.IsFalse(Syn.GetEol);
        Assert.AreEqual('INPUT', Syn.GetToken);
        Assert.AreEqual(Ord(mbtKey), Integer(Syn.GetTokenKind));

        Syn.Next;
        Assert.AreEqual('[SELECT:1|2] name', Syn.GetToken);
        Assert.AreEqual(Ord(mbtArg), Integer(Syn.GetTokenKind));

        Syn.Next;
        Assert.IsTrue(Syn.GetEol);
    finally
        Syn.Free;
    end;
end;

procedure TMacroBodySynTests.Body_ContinuationLine_StaysArg;
var
    Syn: TMacroBodySyn;
begin
    Syn := TMacroBodySyn.Create(nil);
    try
        Syn.SetLine('INPUT line1', 1);
        Syn.Next; // Key
        Syn.Next; // Arg

        // Эмуляция переноса строки внутри макроса: состояние (аргументы)
        // переносится через Range, поэтому на новой строке сразу Arg
        Syn.SetLine('continuation', 2);

        Assert.AreEqual('continuation', Syn.GetToken);
        Assert.AreEqual(Ord(mbtArg), Integer(Syn.GetTokenKind));
    finally
        Syn.Free;
    end;
end;

{ TMacroSchemeRegexTests }

procedure TMacroSchemeRegexTests.Scheme_Matches_KnownDirectives;
const
    POSITIVES: TArray<string> = [
        '{INPUT name}', '{INPUT[SELECT:1|2] name}', '{SLEEP 500}',
        '{ENTER}', '{SENDKEY CTRL+C}', '{SENDKEYEX CTRL+ALT+DEL}',
        '{KEYDELAY 50}', '{CLEARLINE}', '{UUID}', '{COUNTER}',
        '{COUNTER:start=5;step=2;pad=3}', '{DATETIME:yyyy-MM-dd}',
        '{ENV:HOME}', '{CLIPBOARD}'
    ];
var
    S: string;
begin
    for S in POSITIVES do
        Assert.IsTrue(TRegEx.IsMatch(S, BuildMacroStartExpr),
            S + '  EXPR=[' + BuildMacroStartExpr + ']');
end;

procedure TMacroSchemeRegexTests.Scheme_Ignores_LanguageBraces;
const
    NEGATIVES: TArray<string> = [
        '{ $_.CPU -gt 10 }', '@{ Name = 1 }', '${HOME}',
        '${USER} on ${HOST}', 'switch ($x) { Default { 1 } }',
        'foreach { Write-Host Test }', 'foo() { printf bar }',
        '{a..b}', '{"Key": 1}', '{ lowercase }'
    ];
var
    S: string;
begin
    for S in NEGATIVES do
        Assert.IsFalse(TRegEx.IsMatch(S, BuildMacroStartExpr), S);
end;

procedure TMacroSchemeRegexTests.Registry_MatchesEngineKnowledge;
begin
    // Голый VALUE и неизвестные имена движку не известны - красных
    // карточек для них быть не должно
    Assert.IsFalse(TRegEx.IsMatch('{VALUE}', BuildMacroStartExpr));
    Assert.IsFalse(TRegEx.IsMatch('{VALUE_UUID}', BuildMacroStartExpr));
    Assert.IsFalse(TRegEx.IsMatch('{FOO}', BuildMacroStartExpr));
    Assert.IsFalse(TRegEx.IsMatch('{INPUTX}', BuildMacroStartExpr));

    Assert.IsTrue(IsKnownMacroName('SENDKEYEX'));
    Assert.IsTrue(IsKnownMacroName('COUNTER'));
    Assert.IsTrue(IsKnownMacroName('CLIPBOARD'));
    Assert.IsFalse(IsKnownMacroName('VALUE'));
    Assert.IsFalse(IsKnownMacroName('VALUE_UUID'));
end;

end.
