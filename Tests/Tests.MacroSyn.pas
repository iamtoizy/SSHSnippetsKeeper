unit Tests.MacroSyn;

interface

uses
    DUnitX.TestFramework,
    SynEditTypes,
    SynEditHighlighter,
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

end.
