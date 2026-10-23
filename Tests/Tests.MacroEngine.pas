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
        [Test]
        procedure Input_SelectType_Parsed;
        [Test]
        procedure InputDescriptors_CollectsNonConfirmInputs;
        [Test]
        procedure PreCollect_Batch_CollectsAll;
        [Test]
        procedure PreCollect_Batch_Cancel;
        [Test]
        procedure PreCollect_BatchSingle_FallsBackToSequential;
        [Test]
        procedure PreCollect_Sequential_NoBatchCallback;
        [Test]
        procedure Value_UUID_Format;
        [Test]
        procedure Value_DATETIME_DefaultFormat;
        [Test]
        procedure Value_DATETIME_CustomFormat;
        [Test]
        procedure Value_RANDOM_LengthAndCharset;
        [Test]
        procedure Value_RANDOM_DefaultLength;
        [Test]
        procedure Value_COUNTER_PerSnippet;
        [Test]
        procedure Value_ENV_Resolves;
        [Test]
        procedure Value_ENV_Missing_Empty;
        [Test]
        procedure Value_CLIPBOARD_ParsedAsTextAction;
        [Test]
        procedure Value_UnknownDirective_Reports;
    end;

implementation

uses
    System.Diagnostics,
    System.SysUtils,
    Winapi.Windows
    ;

type
    TRecorderExecutor = class(TInterfacedObject, ITextExecutor)
    public
        Recorded: string;
        procedure TypeRawText(const AText: string; Context: TMacroContext);
        procedure PressEnter(Context: TMacroContext);
        procedure PressKey(Key: Word; Context: TMacroContext);
    end;

procedure TRecorderExecutor.TypeRawText(const AText: string; Context: TMacroContext);
begin
    Recorded := Recorded + AText;
end;

procedure TRecorderExecutor.PressEnter(Context: TMacroContext);
begin
    Recorded := Recorded + #10;
end;

procedure TRecorderExecutor.PressKey(Key: Word; Context: TMacroContext);
begin
    Recorded := Recorded + '[' + IntToStr(Key) + ']';
end;

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

procedure TMacroEngineTests.Input_SelectType_Parsed;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    InputAction: TInputAction;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{INPUT[SELECT:prod|stage|dev]Env}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TInputAction);

        InputAction := Actions[0] as TInputAction;
        Assert.IsTrue(InputAction.GetInputType = mitSelect);
        Assert.AreEqual('prod|stage|dev', InputAction.GetDefaultValue);
        Assert.AreEqual('Env', InputAction.GetPrompt);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.InputDescriptors_CollectsNonConfirmInputs;
var
    Engine: TMacroEngine;
    Descs: TArray<TMacroParamDescriptor>;
begin
    Engine := TMacroEngine.Create;
    try
        Descs := Engine.InputDescriptors(
            'a{INPUT[STRING:one]First}{INPUT[CONFIRM]Proceed}b{INPUT[NUMBER:5]Second}');
        Assert.AreEqual(2, Integer(Length(Descs)));
        Assert.AreEqual('First', Descs[0].Name);
        Assert.IsTrue(Descs[0].InputType = mitString);
        Assert.AreEqual('one', Descs[0].DefaultValue);
        Assert.AreEqual('Second', Descs[1].Name);
        Assert.IsTrue(Descs[1].InputType = mitNumber);
        Assert.AreEqual('5', Descs[1].DefaultValue);
    finally
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.PreCollect_Batch_CollectsAll;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    ReceivedNames: string;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Ctx.OnBatchInput := function(const Params: TArray<TMacroParamDescriptor>; out Values: TArray<string>): Boolean
        begin
            ReceivedNames := Params[0].Name + '|' + Params[1].Name;
            SetLength(Values, 2);
            Values[0] := 'v1';
            Values[1] := 'v2long';
            Result := True;
        end;

        Actions := Engine.Parse('{INPUT[STRING:def1]P1}{INPUT[NUMBER:5]P2}', Ctx);
        Engine.PreCollectInputs(Actions, Ctx);

        Assert.IsFalse(Ctx.UserCanceled);
        Assert.AreEqual('P1|P2', ReceivedNames);
        Assert.AreEqual(2, (Actions[0] as TInputAction).ProgressUnits);
        Assert.AreEqual(6, (Actions[1] as TInputAction).ProgressUnits);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.PreCollect_Batch_Cancel;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Ctx.OnBatchInput := function(const Params: TArray<TMacroParamDescriptor>; out Values: TArray<string>): Boolean
        begin
            Result := False;
        end;

        Actions := Engine.Parse('{INPUT[STRING:]P1}{INPUT[STRING:]P2}', Ctx);
        Engine.PreCollectInputs(Actions, Ctx);

        Assert.IsTrue(Ctx.UserCanceled);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.PreCollect_BatchSingle_FallsBackToSequential;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    BatchCalls, InputCalls: Integer;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    BatchCalls := 0;
    InputCalls := 0;
    try
        Ctx.OnBatchInput := function(const Params: TArray<TMacroParamDescriptor>; out Values: TArray<string>): Boolean
        begin
            Inc(BatchCalls);
            Result := True;
        end;
        Ctx.OnInput := function(const Prompt: string): string
        begin
            Inc(InputCalls);
            Result := 'x';
        end;

        Actions := Engine.Parse('{INPUT[STRING:]Solo}', Ctx);
        Engine.PreCollectInputs(Actions, Ctx);

        Assert.IsFalse(Ctx.UserCanceled);
        Assert.AreEqual(0, BatchCalls);
        Assert.AreEqual(1, InputCalls);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.PreCollect_Sequential_NoBatchCallback;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Prompts: string;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Ctx.OnInput := function(const Prompt: string): string
        begin
            Prompts := Prompts + Prompt + ';';
            if Prompt = 'P1' then
                Result := 'abcdef'
            else
                Result := 'xyz';
        end;

        Actions := Engine.Parse('{INPUT[STRING:]P1}{INPUT[STRING:]P2}', Ctx);
        Engine.PreCollectInputs(Actions, Ctx);

        Assert.IsFalse(Ctx.UserCanceled);
        Assert.AreEqual('P1;P2;', Prompts);
        Assert.AreEqual(6, (Actions[0] as TInputAction).ProgressUnits);
        Assert.AreEqual(3, (Actions[1] as TInputAction).ProgressUnits);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_UUID_Format;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Rec: TRecorderExecutor;
    S: string;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    Rec := TRecorderExecutor.Create;
    try
        Ctx.Executor := Rec;
        Actions := Engine.Parse('a{UUID}b', Ctx);
        Assert.AreEqual(3, Integer(Length(Actions)));
        Assert.IsTrue(Actions[1] is TTypeTextAction);

        Actions[1].Execute;
        S := Rec.Recorded;
        Assert.AreEqual(36, Integer(Length(S)));
        Assert.AreEqual('-', Copy(S, 9, 1));
        Assert.AreEqual('-', Copy(S, 14, 1));
        Assert.AreEqual('-', Copy(S, 19, 1));
        Assert.AreEqual('-', Copy(S, 24, 1));
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_DATETIME_DefaultFormat;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Rec: TRecorderExecutor;
    S: string;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    Rec := TRecorderExecutor.Create;
    try
        Ctx.Executor := Rec;
        Actions := Engine.Parse('{DATETIME}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Actions[0].Execute;

        S := Rec.Recorded;
        Assert.AreEqual(19, Integer(Length(S)));
        Assert.AreEqual(FormatDateTime('yyyy', Now), Copy(S, 1, 4));
        Assert.AreEqual('-', Copy(S, 5, 1));
        Assert.AreEqual(' ', Copy(S, 11, 1));
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_DATETIME_CustomFormat;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Rec: TRecorderExecutor;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    Rec := TRecorderExecutor.Create;
    try
        Ctx.Executor := Rec;
        Actions := Engine.Parse('{DATETIME:yyyy}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Actions[0].Execute;
        Assert.AreEqual(FormatDateTime('yyyy', Now), Rec.Recorded);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_RANDOM_LengthAndCharset;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Rec: TRecorderExecutor;
    S: string;
    I: Integer;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    Rec := TRecorderExecutor.Create;
    try
        Ctx.Executor := Rec;
        Actions := Engine.Parse('{RANDOM:8}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Actions[0].Execute;

        S := Rec.Recorded;
        Assert.AreEqual(8, Integer(Length(S)));
        for I := 1 to Length(S) do
            Assert.IsTrue(Pos(S[I], RANDOM_CHARSET) > 0);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_RANDOM_DefaultLength;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Rec: TRecorderExecutor;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    Rec := TRecorderExecutor.Create;
    try
        Ctx.Executor := Rec;
        Actions := Engine.Parse('{RANDOM}', Ctx);
        Actions[0].Execute;
        Assert.AreEqual(DEFAULT_RANDOM_LENGTH, Integer(Length(Rec.Recorded)));
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_COUNTER_PerSnippet;
var
    Engine: TMacroEngine;
    Ctx, Ctx2: TMacroContext;
    Actions: TArray<IScriptAction>;
    Rec, Rec2: TRecorderExecutor;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    Rec := TRecorderExecutor.Create;
    try
        Ctx.SnippetID := 5;
        Ctx.Executor := Rec;

        Actions := Engine.Parse('{COUNTER}', Ctx);
        Actions[0].Execute;
        Actions := Engine.Parse('{COUNTER}', Ctx);
        Actions[0].Execute;
        Assert.AreEqual('12', Rec.Recorded);

        Ctx2 := MakeContext;
        Rec2 := TRecorderExecutor.Create;
        try
            Ctx2.SnippetID := 6;
            Ctx2.Executor := Rec2;
            Actions := Engine.Parse('{COUNTER}', Ctx2);
            Actions[0].Execute;
            Assert.AreEqual('1', Rec2.Recorded);
        finally
            Ctx2.Free;
        end;
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_ENV_Resolves;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Rec: TRecorderExecutor;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    Rec := TRecorderExecutor.Create;
    try
        Ctx.Executor := Rec;
        SetEnvironmentVariable('SSK_TEST_VAR', 'hello42');
        try
            Actions := Engine.Parse('{ENV:SSK_TEST_VAR}', Ctx);
            Assert.AreEqual(1, Integer(Length(Actions)));
            Actions[0].Execute;
            Assert.AreEqual('hello42', Rec.Recorded);
        finally
            SetEnvironmentVariable('SSK_TEST_VAR', nil);
        end;
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_ENV_Missing_Empty;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Rec: TRecorderExecutor;
    Unknown: TArray<string>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    Rec := TRecorderExecutor.Create;
    try
        Ctx.Executor := Rec;
        Actions := Engine.Parse('{ENV:SSK_DEFINITELY_MISSING_VAR}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Actions[0].Execute;
        Assert.AreEqual('', Rec.Recorded);

        Unknown := Engine.ValidateCommands('a{ENV}b');
        Assert.AreEqual(1, Integer(Length(Unknown)));
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_CLIPBOARD_ParsedAsTextAction;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{CLIPBOARD}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TTypeTextAction);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_UnknownDirective_Reports;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Unknown: TArray<string>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('x{UUIDX}y', Ctx);
        Assert.AreEqual(2, Integer(Length(Actions)));

        Unknown := Engine.ValidateCommands('x{UUIDX}y');
        Assert.AreEqual(1, Integer(Length(Unknown)));
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

end.
