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
        procedure Input_WithParams_ParsedAsInputAction;
        [Test]
        procedure UnknownMacro_BecomesPlainText;
        [Test]
        procedure Cache_ReusesParsedTokens;
    end;

implementation

uses
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

procedure TMacroEngineTests.UnknownMacro_BecomesPlainText;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{UNKNOWN_CMD}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TTypeTextAction);
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
