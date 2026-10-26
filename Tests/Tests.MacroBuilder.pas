unit Tests.MacroBuilder;

interface

uses
    DUnitX.TestFramework,
    MacroEngine,
    MacroInputTypes,
    MacroBuilder
    ;

type
    [TestFixture]
    TMacroBuilderTests = class(TObject)
    private
        function TokensSignature(const Text: string): string;
    public
        [Test]
        procedure StepToMacro_AllKinds;
        [Test]
        procedure StepsFromTokens_AllKinds;
        [Test]
        procedure RoundTrip_KeepsTokenSemantics;
        [Test]
        procedure RoundTrip_ComplexSnippet;
        [Test]
        procedure UnknownToken_BecomesPlainText;
    end;

implementation

uses
    System.SysUtils
    ;

{ TMacroBuilderTests }

function TMacroBuilderTests.TokensSignature(const Text: string): string;
var
    Engine: TMacroEngine;
    Tokens: TArray<TMacroToken>;
    Token: TMacroToken;
    Sb: TStringBuilder;
begin
    Engine := TMacroEngine.Create;
    try
        Tokens := Engine.GetTokens(Text);
        Sb := TStringBuilder.Create;
        try
            for Token in Tokens do
            begin
                Sb.Append(Ord(Token.Kind));
                Sb.Append(':');
                Sb.Append(Token.Text);
                Sb.Append(':');
                Sb.Append(Token.Value);
                Sb.Append(':');
                Sb.Append(Token.KeyModifiers);
                Sb.Append(':');
                Sb.Append(Ord(Token.InputType));
                Sb.Append(':');
                Sb.Append(Token.DefaultValue);
                Sb.Append('|');
            end;
            Result := Sb.ToString;
        finally
            Sb.Free;
        end;
    finally
        Engine.Free;
    end;
end;

procedure TMacroBuilderTests.StepToMacro_AllKinds;
var
    Step: TMacroStep;
begin
    Step := Default(TMacroStep);
    Step.Kind := mskText;
    Step.Text := 'ssh ';
    Assert.AreEqual('ssh ', StepToMacro(Step));

    Step.Kind := mskSleep;
    Step.Num := 500;
    Assert.AreEqual('{SLEEP 500}', StepToMacro(Step));

    Step.Kind := mskEnter;
    Assert.AreEqual('{ENTER}', StepToMacro(Step));

    Step.Kind := mskKey;
    Step.Text := 'CTRL+C';
    Assert.AreEqual('{SENDKEY CTRL+C}', StepToMacro(Step));

    Step.Kind := mskInput;
    Step.Text := 'Host';
    Step.InputType := mitString;
    Step.Default := '';
    Assert.AreEqual('{INPUT Host}', StepToMacro(Step));

    Step.InputType := mitNumber;
    Step.Default := '100';
    Assert.AreEqual('{INPUT[NUMBER:100] Host}', StepToMacro(Step));

    Step.InputType := mitDate;
    Step.Default := '2026-01-31';
    Assert.AreEqual('{INPUT[DATE:2026-01-31] Host}', StepToMacro(Step));

    Step.InputType := mitTime;
    Step.Default := '12:00';
    Assert.AreEqual('{INPUT[TIME:12:00] Host}', StepToMacro(Step));

    Step.InputType := mitSelect;
    Step.Default := 'prod|stage';
    Assert.AreEqual('{INPUT[SELECT:prod|stage] Host}', StepToMacro(Step));

    Step.InputType := mitConfirm;
    Step.Default := '';
    Assert.AreEqual('{INPUT[CONFIRM] Host}', StepToMacro(Step));

    Step := Default(TMacroStep);
    Step.Kind := mskValue;
    Step.ValueKind := 'UUID';
    Assert.AreEqual('{UUID}', StepToMacro(Step));

    Step.ValueKind := 'DATETIME';
    Step.Text := 'yyyy';
    Assert.AreEqual('{DATETIME:yyyy}', StepToMacro(Step));

    Step := Default(TMacroStep);
    Step.Kind := mskClearLine;
    Assert.AreEqual('{CLEAR_LINE}', StepToMacro(Step));

    Step.Kind := mskKeyDelay;
    Step.Num := 200;
    Assert.AreEqual('{KEYDELAY 200}', StepToMacro(Step));
end;

procedure TMacroBuilderTests.StepsFromTokens_AllKinds;
var
    Steps: TArray<TMacroStep>;
begin
    Steps := StepsFromMacroText('pre{SLEEP 100}{ENTER}{SENDKEY CTRL+C}{INPUT[SELECT:a|b] Env}{UUID}{CLEAR_LINE}{KEYDELAY 50}post');

    Assert.AreEqual(9, Integer(Length(Steps)));
    Assert.IsTrue(Steps[0].Kind = mskText);
    Assert.AreEqual('pre', Steps[0].Text);
    Assert.IsTrue(Steps[1].Kind = mskSleep);
    Assert.AreEqual(100, Steps[1].Num);
    Assert.IsTrue(Steps[2].Kind = mskEnter);
    Assert.IsTrue(Steps[3].Kind = mskKey);
    Assert.AreEqual('CTRL+C', Steps[3].Text);
    Assert.IsTrue(Steps[4].Kind = mskInput);
    Assert.AreEqual('Env', Steps[4].Text);
    Assert.IsTrue(Steps[4].InputType = mitSelect);
    Assert.AreEqual('a|b', Steps[4].Default);
    Assert.IsTrue(Steps[5].Kind = mskValue);
    Assert.AreEqual('UUID', Steps[5].ValueKind);
    Assert.IsTrue(Steps[6].Kind = mskClearLine);
    Assert.IsTrue(Steps[7].Kind = mskKeyDelay);
    Assert.AreEqual(50, Steps[7].Num);
    Assert.IsTrue(Steps[8].Kind = mskText);
    Assert.AreEqual('post', Steps[8].Text);
end;

procedure TMacroBuilderTests.RoundTrip_KeepsTokenSemantics;
var
    Source, Rebuilt: string;
begin
    Source := '{SLEEP 250}cmd{ENTER}{SENDKEY ALT+F4}{INPUT[STRING:def] Name}{ENV:HOME}{KEYDELAY 100}';
    Rebuilt := StepsToMacro(StepsFromMacroText(Source));

    Assert.AreEqual(TokensSignature(Source), TokensSignature(Rebuilt));
end;

procedure TMacroBuilderTests.RoundTrip_ComplexSnippet;
var
    Source, Rebuilt: string;
begin
    Source := 'ssh {INPUT[STRING:user@host] Where}'#10'{SLEEP 800}'#10 +
        'sudo systemctl restart nginx {INPUT[SELECT:prod|stage|dev] Env}'#10 +
        '{INPUT[CONFIRM] Proceed?}{CLEAR_LINE}{DATETIME:yyyy-MM-dd}{RANDOM:12}{COUNTER}';

    Rebuilt := StepsToMacro(StepsFromMacroText(Source));

    Assert.AreEqual(TokensSignature(Source), TokensSignature(Rebuilt));
end;

procedure TMacroBuilderTests.UnknownToken_BecomesPlainText;
var
    Steps: TArray<TMacroStep>;
begin
    Steps := StepsFromMacroText('a{UNKNOWN_CMD}b');
    Assert.AreEqual(3, Integer(Length(Steps)));
    Assert.IsTrue(Steps[1].Kind = mskText);
    Assert.AreEqual('{UNKNOWN_CMD}', Steps[1].Text);

    Assert.AreEqual(TokensSignature('a{UNKNOWN_CMD}b'), TokensSignature(StepsToMacro(Steps)));
end;

end.
