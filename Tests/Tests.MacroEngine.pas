unit Tests.MacroEngine;

interface

uses
    DUnitX.TestFramework,
    MacroCounters,
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
        procedure Input_DateTimeType_Parsed;
        [Test]
        procedure Input_DateType_Parsed;
        [Test]
        procedure Input_TimeType_Parsed;
        [Test]
        procedure Sleep_InvalidArg_TokenMarkedInvalid;
        [Test]
        procedure Input_BadDefault_TokenMarkedInvalid;
        [Test]
        procedure Value_BadRandomArg_TokenMarkedInvalid;
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
        procedure Value_COUNTER_StartStep;
        [Test]
        procedure Value_COUNTER_Pad;
        [Test]
        procedure Value_COUNTER_Current_UsesRunValue;
        [Test]
        procedure Value_COUNTER_BadParams_TokenMarkedInvalid;
        [Test]
        procedure Value_ENV_Resolves;
        [Test]
        procedure Value_ENV_Missing_Empty;
        [Test]
        procedure Value_CLIPBOARD_ParsedAsTextAction;
        [Test]
        procedure Value_UnknownDirective_Reports;
        [Test]
        procedure SendKeyEx_Modifiers_Parsed;
        [Test]
        procedure SendKeyEx_CtrlAltDel;
        [Test]
        procedure SendKeyEx_ShiftT;
        [Test]
        procedure SendKeyEx_PlainChar_StillText;
        [Test]
        procedure SendKeyEx_ModifiedChar_AlphaNum;
        [Test]
        procedure SendKeyEx_ModifiedChar_NonAlphaNum_Fails;
        [Test]
        procedure SendKeyEx_BadParts_Fail;
        [Test]
        procedure SendKey_Modifiers_BecomesSendKeyAction;
        [Test]
        procedure ClearLine_ExecutesCtrlCAndCtrlU;
        [Test]
        procedure KeyDelay_SetsContextField;
        [Test]
        procedure KeyDelay_MidMacro_AppliesToRest;
        [Test]
        procedure KeyDelay_Invalid_Reports;
        [Test]
        procedure Positions_TextOnly_SingleToken;
        [Test]
        procedure Positions_MixedTextAndMacros;
        [Test]
        procedure Positions_MacroAtStartAndEnd;
        [Test]
        procedure Positions_SendKeyPlainChar_KeepsMacroRange;
        [Test]
        procedure DryRun_Text_PlainLines;
        [Test]
        procedure DryRun_MacroRawSlice;
        [Test]
        procedure DryRun_InputAndConfirm;
        [Test]
        procedure DryRun_Unknown_Warning;
        [Test]
        procedure DryRun_Invalid_Warning;
        [Test]
        procedure DryRun_Counter_NotConsumed;
        [Test]
        procedure DryRun_SendKey_Detail;
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
        procedure PressKey(Key: Word; Modifiers: Word; Context: TMacroContext);
    end;

procedure TRecorderExecutor.TypeRawText(const AText: string; Context: TMacroContext);
begin
    Recorded := Recorded + AText;
end;

procedure TRecorderExecutor.PressEnter(Context: TMacroContext);
begin
    Recorded := Recorded + #10;
end;

procedure TRecorderExecutor.PressKey(Key: Word; Modifiers: Word; Context: TMacroContext);
begin
    Recorded := Recorded + '[' + IntToStr(Key) + ':' + IntToStr(Modifiers) + ']';
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

procedure TMacroEngineTests.Input_DateTimeType_Parsed;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    InputAction: TInputAction;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{INPUT[DATETIME:2026-10-25 14:30]When}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TInputAction);

        InputAction := Actions[0] as TInputAction;
        Assert.IsTrue(InputAction.GetInputType = mitDateTime);
        Assert.AreEqual('2026-10-25 14:30', InputAction.GetDefaultValue);
        Assert.AreEqual('When', InputAction.GetPrompt);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Input_DateType_Parsed;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    InputAction: TInputAction;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{INPUT[DATE:2026-01-31]When}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TInputAction);

        InputAction := Actions[0] as TInputAction;
        Assert.IsTrue(InputAction.GetInputType = mitDate);
        Assert.AreEqual('2026-01-31', InputAction.GetDefaultValue);
        Assert.AreEqual('When', InputAction.GetPrompt);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Input_TimeType_Parsed;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    InputAction: TInputAction;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{INPUT[TIME:12:00]At}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TInputAction);

        InputAction := Actions[0] as TInputAction;
        Assert.IsTrue(InputAction.GetInputType = mitTime);
        Assert.AreEqual('12:00', InputAction.GetDefaultValue);
        Assert.AreEqual('At', InputAction.GetPrompt);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Sleep_InvalidArg_TokenMarkedInvalid;
var
    Engine: TMacroEngine;
    Tokens: TArray<TMacroToken>;
begin
    Engine := TMacroEngine.Create;
    try
        Tokens := Engine.GetTokens('{SLEEP 500}');
        Assert.AreEqual(1, Integer(Length(Tokens)));
        Assert.IsFalse(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{SLEEP abc}');
        Assert.IsTrue(Tokens[0].Kind = tkSleep);
        Assert.IsTrue(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{SLEEP -5}');
        Assert.IsTrue(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{SLEEP}');
        Assert.IsTrue(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{SLEEP 99999999}');
        Assert.IsTrue(Tokens[0].Invalid);
    finally
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Input_BadDefault_TokenMarkedInvalid;
var
    Engine: TMacroEngine;
    Tokens: TArray<TMacroToken>;
begin
    Engine := TMacroEngine.Create;
    try
        Tokens := Engine.GetTokens('{INPUT[NUMBER:100] N}');
        Assert.IsFalse(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{INPUT[NUMBER:abc] N}');
        Assert.IsTrue(Tokens[0].Kind = tkInput);
        Assert.IsTrue(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{INPUT[DATE:2026-13-01] D}');
        Assert.IsTrue(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{INPUT[DATETIME:2026-10-25_14:30] D}');
        Assert.IsFalse(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{INPUT[TIME:25:00] T}');
        Assert.IsTrue(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{INPUT[SELECT:] Env}');
        Assert.IsTrue(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{INPUT[SELECT:prod|stage] Env}');
        Assert.IsFalse(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{INPUT Name}');
        Assert.IsFalse(Tokens[0].Invalid);
    finally
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_BadRandomArg_TokenMarkedInvalid;
var
    Engine: TMacroEngine;
    Tokens: TArray<TMacroToken>;
begin
    Engine := TMacroEngine.Create;
    try
        Tokens := Engine.GetTokens('{RANDOM}');
        Assert.IsFalse(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{RANDOM:12}');
        Assert.IsFalse(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{RANDOM:abc}');
        Assert.IsTrue(Tokens[0].Kind = tkValue);
        Assert.IsTrue(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{RANDOM:0}');
        Assert.IsTrue(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{RANDOM:99999}');
        Assert.IsTrue(Tokens[0].Invalid);
    finally
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
    Counters.ResetAll;
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

procedure TMacroEngineTests.Value_COUNTER_StartStep;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Rec: TRecorderExecutor;
begin
    Counters.ResetAll;
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    Rec := TRecorderExecutor.Create;
    try
        Ctx.SnippetID := 8;
        Ctx.Executor := Rec;
        Actions := Engine.Parse('{COUNTER:start=100;step=2}', Ctx);
        Actions[0].Execute;
        Actions := Engine.Parse('{COUNTER:start=100;step=2}', Ctx);
        Actions[0].Execute;
        Assert.AreEqual('100102', Rec.Recorded);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_COUNTER_Pad;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Rec: TRecorderExecutor;
begin
    Counters.ResetAll;
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    Rec := TRecorderExecutor.Create;
    try
        Ctx.SnippetID := 8;
        Ctx.Executor := Rec;
        Actions := Engine.Parse('{COUNTER:pad=3}', Ctx);
        Actions[0].Execute;
        Actions := Engine.Parse('{COUNTER:pad=3}', Ctx);
        Actions[0].Execute;
        Assert.AreEqual('001002', Rec.Recorded);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_COUNTER_Current_UsesRunValue;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Rec: TRecorderExecutor;
begin
    Counters.ResetAll;
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    Rec := TRecorderExecutor.Create;
    try
        Ctx.SnippetID := 9;
        Ctx.Executor := Rec;
        Actions := Engine.Parse('{COUNTER:step=5}{COUNTER:current}', Ctx);
        Actions[0].Execute;
        Actions[1].Execute;
        Assert.AreEqual('11', Rec.Recorded);

        Rec.Recorded := '';
        Actions := Engine.Parse('{COUNTER:current}', Ctx);
        Actions[0].Execute;
        Assert.AreEqual('1', Rec.Recorded);

        Rec.Recorded := '';
        Actions := Engine.Parse('{COUNTER}', Ctx);
        Actions[0].Execute;
        Assert.AreEqual('2', Rec.Recorded);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Value_COUNTER_BadParams_TokenMarkedInvalid;
var
    Engine: TMacroEngine;
    Tokens: TArray<TMacroToken>;
begin
    Engine := TMacroEngine.Create;
    try
        Tokens := Engine.GetTokens('{COUNTER}');
        Assert.IsFalse(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{COUNTER:start=5;step=2;pad=3}');
        Assert.IsFalse(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{COUNTER:current;volatile}');
        Assert.IsFalse(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{COUNTER:step=0}');
        Assert.IsTrue(Tokens[0].Kind = tkValue);
        Assert.IsTrue(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{COUNTER:pad=0}');
        Assert.IsTrue(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{COUNTER:pad=99}');
        Assert.IsTrue(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{COUNTER:foo=1}');
        Assert.IsTrue(Tokens[0].Invalid);

        Tokens := Engine.GetTokens('{COUNTER:start}');
        Assert.IsTrue(Tokens[0].Invalid);
    finally
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

procedure TMacroEngineTests.SendKeyEx_Modifiers_Parsed;
var
    Key, Modifiers: Integer;
    Text: string;
begin
    Assert.IsTrue(TryParseSendKeyEx('CTRL+C', Key, Modifiers, Text));
    Assert.AreEqual(67, Key);
    Assert.AreEqual(Integer(MOD_CONTROL), Modifiers);
    Assert.AreEqual('', Text);

    Assert.IsTrue(TryParseSendKeyEx('c', Key, Modifiers, Text));
    Assert.AreEqual('c', Text);
    Assert.AreEqual(0, Modifiers);

    Assert.IsFalse(TryParseSendKey('CTRL+C', Key, Text));
end;

procedure TMacroEngineTests.SendKeyEx_CtrlAltDel;
var
    Key, Modifiers: Integer;
    Text: string;
begin
    Assert.IsTrue(TryParseSendKeyEx('CTRL+ALT+DEL', Key, Modifiers, Text));
    Assert.AreEqual(46, Key);
    Assert.AreEqual(Integer(MOD_CONTROL or MOD_ALT), Modifiers);
end;

procedure TMacroEngineTests.SendKeyEx_ShiftT;
var
    Key, Modifiers: Integer;
    Text: string;
begin
    Assert.IsTrue(TryParseSendKeyEx('SHIFT+T', Key, Modifiers, Text));
    Assert.AreEqual(84, Key);
    Assert.AreEqual(Integer(MOD_SHIFT), Modifiers);
end;

procedure TMacroEngineTests.SendKeyEx_PlainChar_StillText;
var
    Key, Modifiers: Integer;
    Text: string;
begin
    Assert.IsTrue(TryParseSendKeyEx('ENTER', Key, Modifiers, Text));
    Assert.AreEqual(13, Key);
    Assert.AreEqual(0, Modifiers);
    Assert.AreEqual('', Text);
end;

procedure TMacroEngineTests.SendKeyEx_ModifiedChar_AlphaNum;
var
    Key, Modifiers: Integer;
    Text: string;
begin
    Assert.IsTrue(TryParseSendKeyEx('CTRL+a', Key, Modifiers, Text));
    Assert.AreEqual(65, Key);
    Assert.AreEqual(Integer(MOD_CONTROL), Modifiers);
    Assert.AreEqual('', Text);
end;

procedure TMacroEngineTests.SendKeyEx_ModifiedChar_NonAlphaNum_Fails;
var
    Key, Modifiers: Integer;
    Text: string;
begin
    Assert.IsFalse(TryParseSendKeyEx('CTRL+!', Key, Modifiers, Text));
end;

procedure TMacroEngineTests.SendKeyEx_BadParts_Fail;
var
    Key, Modifiers: Integer;
    Text: string;
begin
    Assert.IsFalse(TryParseSendKeyEx('FOO+C', Key, Modifiers, Text));
    Assert.IsFalse(TryParseSendKeyEx('CTRL+', Key, Modifiers, Text));
    Assert.IsFalse(TryParseSendKeyEx('', Key, Modifiers, Text));
end;

procedure TMacroEngineTests.SendKey_Modifiers_BecomesSendKeyAction;
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
        Actions := Engine.Parse('{SENDKEY CTRL+C}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TSendKeyAction);

        Actions[0].Execute;
        Assert.AreEqual('[67:2]', Rec.Recorded);

        Actions := Engine.Parse('{SENDKEY CTRL+ENTER}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Actions[0].Execute;
        Assert.AreEqual('[67:2][13:2]', Rec.Recorded);

        Unknown := Engine.ValidateCommands('{SENDKEY CTRL+!}');
        Assert.AreEqual(1, Integer(Length(Unknown)));
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.ClearLine_ExecutesCtrlCAndCtrlU;
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
        Actions := Engine.Parse('pre{CLEAR_LINE}', Ctx);
        Assert.AreEqual(2, Integer(Length(Actions)));
        Assert.IsTrue(Actions[1] is TClearLineAction);
        Assert.AreEqual(2, Actions[1].ProgressUnits);

        Actions[1].Execute;
        Assert.AreEqual('[67:2][85:2]', Rec.Recorded);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.KeyDelay_SetsContextField;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Unknown: TArray<string>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('{KEYDELAY 50}', Ctx);
        Assert.AreEqual(1, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TSetKeyDelayAction);

        Actions[0].Execute;
        Assert.AreEqual(50, Ctx.KeyDelayMs);

        Actions := Engine.Parse('{KEYDELAY 0}', Ctx);
        Actions[0].Execute;
        Assert.AreEqual(0, Ctx.KeyDelayMs);

        Unknown := Engine.ValidateCommands('{KEYDELAY -5}x{KEYDELAY abc}');
        Assert.AreEqual(2, Integer(Length(Unknown)));
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.KeyDelay_MidMacro_AppliesToRest;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('a{KEYDELAY 30}b', Ctx);
        Assert.AreEqual(3, Integer(Length(Actions)));
        Assert.IsTrue(Actions[0] is TTypeTextAction);
        Assert.IsTrue(Actions[1] is TSetKeyDelayAction);
        Assert.IsTrue(Actions[2] is TTypeTextAction);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.KeyDelay_Invalid_Reports;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Actions: TArray<IScriptAction>;
    Unknown: TArray<string>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Actions := Engine.Parse('x{KEYDELAY abc}y', Ctx);
        Assert.AreEqual(2, Integer(Length(Actions)));

        Unknown := Engine.ValidateCommands('x{KEYDELAY abc}y');
        Assert.AreEqual(1, Integer(Length(Unknown)));
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Positions_TextOnly_SingleToken;
var
    Engine: TMacroEngine;
    Tokens: TArray<TMacroToken>;
begin
    Engine := TMacroEngine.Create;
    try
        Tokens := Engine.GetTokens('just text');
        Assert.AreEqual(1, Integer(Length(Tokens)));
        Assert.AreEqual(tkText, Tokens[0].Kind);
        Assert.AreEqual(1, Tokens[0].StartOffset);
        Assert.AreEqual(9, Tokens[0].Length);

        Assert.AreEqual(0, Integer(Length(Engine.GetTokens(''))));
    finally
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Positions_MixedTextAndMacros;
var
    Engine: TMacroEngine;
    Tokens: TArray<TMacroToken>;
    Text: string;
begin
    Text := 'ab{ENTER}c{SLEEP 100}d';
    Engine := TMacroEngine.Create;
    try
        Tokens := Engine.GetTokens(Text);
        Assert.AreEqual(5, Integer(Length(Tokens)));

        Assert.AreEqual(tkText, Tokens[0].Kind);
        Assert.AreEqual('ab', Copy(Text, Tokens[0].StartOffset, Tokens[0].Length));

        Assert.AreEqual(tkEnter, Tokens[1].Kind);
        Assert.AreEqual(3, Tokens[1].StartOffset);
        Assert.AreEqual(7, Tokens[1].Length);

        Assert.AreEqual(tkText, Tokens[2].Kind);
        Assert.AreEqual(10, Tokens[2].StartOffset);
        Assert.AreEqual(1, Tokens[2].Length);

        Assert.AreEqual(tkSleep, Tokens[3].Kind);
        Assert.AreEqual(11, Tokens[3].StartOffset);
        Assert.AreEqual(11, Tokens[3].Length);

        Assert.AreEqual(tkText, Tokens[4].Kind);
        Assert.AreEqual(22, Tokens[4].StartOffset);
        Assert.AreEqual(1, Tokens[4].Length);
    finally
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Positions_MacroAtStartAndEnd;
var
    Engine: TMacroEngine;
    Tokens: TArray<TMacroToken>;
begin
    Engine := TMacroEngine.Create;
    try
        Tokens := Engine.GetTokens('{ENTER}{SLEEP 5}');
        Assert.AreEqual(2, Integer(Length(Tokens)));

        Assert.AreEqual(tkEnter, Tokens[0].Kind);
        Assert.AreEqual(1, Tokens[0].StartOffset);
        Assert.AreEqual(7, Tokens[0].Length);

        Assert.AreEqual(tkSleep, Tokens[1].Kind);
        Assert.AreEqual(8, Tokens[1].StartOffset);
        Assert.AreEqual(9, Tokens[1].Length);
    finally
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.Positions_SendKeyPlainChar_KeepsMacroRange;
var
    Engine: TMacroEngine;
    Tokens: TArray<TMacroToken>;
begin
    Engine := TMacroEngine.Create;
    try
        Tokens := Engine.GetTokens('x{SENDKEY y}');
        Assert.AreEqual(2, Integer(Length(Tokens)));

        Assert.AreEqual(tkText, Tokens[0].Kind);
        Assert.AreEqual(1, Tokens[0].StartOffset);
        Assert.AreEqual(1, Tokens[0].Length);

        Assert.AreEqual(tkText, Tokens[1].Kind);
        Assert.AreEqual(2, Tokens[1].StartOffset);
        Assert.AreEqual(11, Tokens[1].Length);
    finally
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.DryRun_Text_PlainLines;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Lines: TArray<TTranscriptLine>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Lines := Engine.DryRunTranscript('hello world', Ctx);
        Assert.AreEqual(1, Integer(Length(Lines)));
        Assert.IsTrue(Lines[0].Kind = tlText);
        Assert.AreEqual('hello world', Lines[0].Detail);
        Assert.AreEqual('', Lines[0].Warning);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.DryRun_MacroRawSlice;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Lines: TArray<TTranscriptLine>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Lines := Engine.DryRunTranscript('ab{SLEEP 100}c{KEYDELAY 5}', Ctx);
        Assert.AreEqual(4, Integer(Length(Lines)));

        Assert.IsTrue(Lines[0].Kind = tlText);
        Assert.AreEqual('ab', Lines[0].Macro);

        Assert.IsTrue(Lines[1].Kind = tlSleep);
        Assert.AreEqual('{SLEEP 100}', Lines[1].Macro);
        Assert.AreEqual('100', Lines[1].Detail);
        Assert.AreEqual('', Lines[1].Warning);

        Assert.IsTrue(Lines[3].Kind = tlKeyDelay);
        Assert.AreEqual('{KEYDELAY 5}', Lines[3].Macro);
        Assert.AreEqual('5', Lines[3].Detail);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.DryRun_InputAndConfirm;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Lines: TArray<TTranscriptLine>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Lines := Engine.DryRunTranscript('{INPUT[NUMBER:5]Size}{INPUT[Confirm]Proceed}', Ctx);
        Assert.AreEqual(2, Integer(Length(Lines)));

        Assert.IsTrue(Lines[0].Kind = tlInput);
        Assert.AreEqual('Size', Lines[0].Name);
        Assert.IsTrue(Lines[0].InputType = mitNumber);
        Assert.AreEqual('5', Lines[0].Detail);

        Assert.IsTrue(Lines[1].Kind = tlConfirm);
        Assert.AreEqual('Proceed', Lines[1].Name);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.DryRun_Unknown_Warning;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Lines: TArray<TTranscriptLine>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Lines := Engine.DryRunTranscript('a{UNKNOWN_CMD}b', Ctx);
        Assert.AreEqual(3, Integer(Length(Lines)));
        Assert.IsTrue(Lines[1].Kind = tlWarning);
        Assert.AreEqual(DRY_RUN_WARN_UNKNOWN, Lines[1].Warning);
        Assert.AreEqual('{UNKNOWN_CMD}', Lines[1].Macro);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.DryRun_Invalid_Warning;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Lines: TArray<TTranscriptLine>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Lines := Engine.DryRunTranscript('{SLEEP abc}', Ctx);
        Assert.AreEqual(1, Integer(Length(Lines)));
        Assert.IsTrue(Lines[0].Kind = tlSleep);
        Assert.AreEqual(DRY_RUN_WARN_INVALID, Lines[0].Warning);

        Lines := Engine.DryRunTranscript('{RANDOM:abc}', Ctx);
        Assert.AreEqual(DRY_RUN_WARN_INVALID, Lines[0].Warning);

        Lines := Engine.DryRunTranscript('{COUNTER:step=0}', Ctx);
        Assert.AreEqual(DRY_RUN_WARN_INVALID, Lines[0].Warning);

        Lines := Engine.DryRunTranscript('{INPUT[NUMBER:oops] N}', Ctx);
        Assert.AreEqual(DRY_RUN_WARN_INVALID, Lines[0].Warning);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.DryRun_Counter_NotConsumed;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Lines: TArray<TTranscriptLine>;
    Rec: TRecorderExecutor;
    Actions: TArray<IScriptAction>;
begin
    Counters.ResetAll;
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    Rec := TRecorderExecutor.Create;
    try
        Ctx.SnippetID := 21;
        Ctx.Executor := Rec;

        // Превью дважды: оба раза next-значение, счётчик не двигается
        Lines := Engine.DryRunTranscript('{COUNTER:start=100;step=2}', Ctx);
        Assert.AreEqual(1, Integer(Length(Lines)));
        Assert.IsTrue(Lines[0].Kind = tlValue);
        Assert.AreEqual('COUNTER', Lines[0].Name);
        Assert.AreEqual('100', Lines[0].Detail);

        Lines := Engine.DryRunTranscript('{COUNTER:start=100;step=2}', Ctx);
        Assert.AreEqual('100', Lines[0].Detail);

        // Реальный запуск потребляет счётчик
        Actions := Engine.Parse('{COUNTER:start=100;step=2}', Ctx);
        Actions[0].Execute;
        Assert.AreEqual('100', Rec.Recorded);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

procedure TMacroEngineTests.DryRun_SendKey_Detail;
var
    Engine: TMacroEngine;
    Ctx: TMacroContext;
    Lines: TArray<TTranscriptLine>;
begin
    Engine := TMacroEngine.Create;
    Ctx := MakeContext;
    try
        Lines := Engine.DryRunTranscript('{SENDKEY CTRL+ENTER}', Ctx);
        Assert.AreEqual(1, Integer(Length(Lines)));
        Assert.IsTrue(Lines[0].Kind = tlSendKey);
        Assert.AreEqual('Ctrl+Enter', Lines[0].Detail);
        Assert.AreEqual('{SENDKEY CTRL+ENTER}', Lines[0].Macro);
    finally
        Ctx.Free;
        Engine.Free;
    end;
end;

end.
