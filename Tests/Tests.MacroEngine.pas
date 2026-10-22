unit Tests.MacroEngine;

interface

uses
    DUnitX.TestFramework,
    MacroEngine,
    MacroInputTypes,
    MacroActions
    ;

type
    [TestFixture]
    TMacroEngineTests = class(TObject)
    private
        function MakeContext: TMacroContext;
    public
        [Test]
        procedure PlainText_SingleTextAction;
        [Test]
        procedure Mixed_ProducesThreeActions;
        [Test]
        procedure Sleep_ParsedAsSleepAction;
        [Test]
        procedure Sleep_Negative_ClampedToZero;
        [Test]
        procedure MacroName_LeadingSpace_Trimmed;
        [Test]
        procedure Input_WithParams_ParsedAsInputAction;
        [Test]
        procedure Input_SplitsOnFirstBracket;
        [Test]
        procedure UnknownMacro_SkipsCommandAndReports;
        [Test]
        procedure SendKey_Name_ParsedToVirtualKey;
        [Test]
        procedure SendKey_SingleChar_ParsedAsText;
        [Test]
        procedure SendKey_Number_ParsedToVirtualKey;
        [Test]
        procedure SendKey_Invalid_Fails;
        [Test]
        procedure SendKey_Char_BecomesTextAction;
        [Test]
        procedure SendKey_Name_BecomesSendKeyAction;
        [Test]
        procedure SendKey_Unknown_SkipsCommandAndReports;
        [Test]
        procedure ProgressUnits_SumsActions;
        [Test]
        procedure Cache_ReusesParsedTokens;
    end;

implementation

uses
    System.Diagnostics,
    System.SysUtils
    ;

{ TMacroEngineTests }

function TMacroEngineTests.MakeContext: TMacroContext;
begin
    Result := TMacroContext.Create;
end;

procedure TMacroEngineTests.PlainText_SingleTextAction;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('hello world', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TTypeTextAction);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Mixed_ProducesThreeActions;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('a{ENTER}b', Ctx);
        Assert.AreEqual(3, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TTypeTextAction);
        Assert.IsTrue(Actions[1] is TEnterAction);
        Assert.IsTrue(Actions[2] is TTypeTextAction);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Sleep_ParsedAsSleepAction;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{SLEEP 100}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TSleepAction);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Input_WithParams_ParsedAsInputAction;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{INPUT [NUMBER:5]Enter value}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TInputAction);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Sleep_Negative_ClampedToZero;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    SW: TStopwatch;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{SLEEP -5}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TSleepAction);

        SW := TStopwatch.StartNew;
        Actions[0].Execute;
        SW.Stop;
        Assert.IsTrue(SW.ElapsedMilliseconds < 5000,
            'Negative SLEEP must be clamped, not wrapped to ~49 days');
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.MacroName_LeadingSpace_Trimmed;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{ SLEEP 10}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TSleepAction);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Input_SplitsOnFirstBracket;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    InputAction: TInputAction;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{INPUT[STRING:a]b]c}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TInputAction);

        InputAction := Actions[0] as TInputAction;
        Assert.AreEqual('a', InputAction.GetDefaultValue);
        Assert.AreEqual('b]c', InputAction.GetPrompt);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.UnknownMacro_SkipsCommandAndReports;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Unknown: TArray<string>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('a{UNKNOWN_CMD}b', Ctx);
        Assert.AreEqual(2, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TTypeTextAction);
        Assert.IsTrue(Actions[1] is TTypeTextAction);

        Unknown := Engine.ValidateCommands('a{UNKNOWN_CMD}b');
        Assert.AreEqual(1, Integer(Length(Unknown)));
        Assert.AreEqual('{UNKNOWN_CMD}', Unknown[0]);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.SendKey_Name_ParsedToVirtualKey;
var
    Key: Integer;
    Text: string;
begin
    Assert.IsTrue(TryParseSendKey('ENTER', Key, Text));
    Assert.AreEqual(13, Integer(Key));
    Assert.AreEqual('', Text);
end;

procedure TMacroEngineTests.SendKey_SingleChar_ParsedAsText;
var
    Key: Integer;
    Text: string;
begin
    Assert.IsTrue(TryParseSendKey('x', Key, Text));
    Assert.AreEqual('x', Text);
    Assert.AreEqual(0, Integer(Key));
end;

procedure TMacroEngineTests.SendKey_Number_ParsedToVirtualKey;
var
    Key: Integer;
    Text: string;
begin
    Assert.IsTrue(TryParseSendKey('13', Key, Text));
    Assert.AreEqual(13, Integer(Key));
    Assert.AreEqual('', Text);
end;

procedure TMacroEngineTests.SendKey_Invalid_Fails;
var
    Key: Integer;
    Text: string;
begin
    Assert.IsFalse(TryParseSendKey('ABRA', Key, Text));
    Assert.IsFalse(TryParseSendKey('', Key, Text));
end;

procedure TMacroEngineTests.SendKey_Char_BecomesTextAction;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{SENDKEY x}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TTypeTextAction);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.SendKey_Name_BecomesSendKeyAction;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{SENDKEY ENTER}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TSendKeyAction);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.SendKey_Unknown_SkipsCommandAndReports;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Unknown: TArray<string>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{SENDKEY ABRA}', Ctx);
        Assert.AreEqual(0, Integer(Length(Actions)));

        Unknown := Engine.ValidateCommands('{SENDKEY ABRA}');
        Assert.AreEqual(1, Integer(Length(Unknown)));
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.ProgressUnits_SumsActions;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Total, I: Integer;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('ab{ENTER}{SLEEP 50}{SENDKEY x}', Ctx);
        Assert.AreEqual(4, Integer(Length(Actions)));

        Total := 0;
        for I := 0 to High(Actions) do
            Inc(Total, Actions[I].ProgressUnits);
        Assert.AreEqual(4, Total);
    finally
        Ctx.Free;
        Engine.Free;
    end;

    Ctx := MakeContext;
    Engine := TMacroEngine.Create;
    try
        Actions := Engine.Parse('{INPUT Name}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.AreEqual(0, (Actions[0] as TInputAction).ProgressUnits);

        (Actions[0] as TInputAction).SetPreCollectedValue('xyz');
        Assert.AreEqual(3, (Actions[0] as TInputAction).ProgressUnits);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Cache_ReusesParsedTokens;
var
    Engine: TMacroEngine;
    Ctx1, Ctx2: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    Engine := TMacroEngine.Create;
    Ctx1 := MakeContext;
    Ctx2 := MakeContext;
    try
        Actions := Engine.Parse('x{ENTER}y', Ctx1);
        Assert.AreEqual(3, Integer(Length(Actions)));
        Actions := Engine.Parse('x{ENTER}y', Ctx2);
        Assert.AreEqual(3, Integer(Length(Actions)));
    finally
        Ctx1.Free;
        Ctx2.Free;
        Engine.Free;
    end;
end;

end.
