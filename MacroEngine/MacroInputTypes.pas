unit MacroInputTypes;

interface

uses
    System.SysUtils
    ;

type
    TMacroTokenKind = (tkText, tkSleep, tkEnter, tkInput, tkSendKey, tkValue, tkClearLine, tkKeyDelay, tkUnknown);
    TMacroInputType = (mitString, mitNumber, mitHex, mitFloat, mitPassword, mitDate, mitConfirm, mitSelect);
    TMacroParamDescriptor = record
        Name: string;
        InputType: TMacroInputType;
        DefaultValue: string;
    end;
    TInputCallback = reference to function(const Prompt: string): string;
    TConfirmCallback = reference to function(const Prompt: string): Boolean;
    TBatchInputCallback = reference to function(const Params: TArray<TMacroParamDescriptor>; out Values: TArray<string>): Boolean;
    TRecordRunCallback = reference to procedure(SnippetID, UserID: Integer);

    ITextExecutor = interface;

    TMacroContext = class
    public
        Executor: ITextExecutor;
        OnInput: TInputCallback;
        OnConfirm: TConfirmCallback;
        OnBatchInput: TBatchInputCallback;
        OnRecordRun: TRecordRunCallback;
        OnFocusLost: TProc;
        OnTypingFinished: TProc;
        Canceled: Integer;
        CurrentInputType: TMacroInputType;
        CurrentDefaultValue: string;
        UserCanceled: Boolean;
        SnippetID: Integer;
        UserID: Integer;
        // Прогресс печати: 32-битные поля под Interlocked, читаются панелью Stop
        ProgressTotal: Integer;
        TypedChars: Integer;
        SleepRemainingMs: Integer;
        // Пауза между символами (мс), 0 = как в настройках.
        // Печать идет в одном потоке, поэтому обычное поле без Interlocked
        KeyDelayMs: Integer;
    end;

    ITextExecutor = interface
        ['{65C96380-78F5-4B0B-9D15-65C99E3C4D4A}']
        procedure TypeRawText(const Text: string; Context: TMacroContext);
        procedure PressEnter(Context: TMacroContext);
        procedure PressKey(Key: Word; Modifiers: Word; Context: TMacroContext);
    end;

    IScriptAction = interface
        ['{5D2A9360-8082-4C7F-9A70-257CCB52AA1B}']
        procedure Execute;
        function ProgressUnits: Integer;
    end;

    TScriptAction = class(TInterfacedObject, IScriptAction)
    protected
        FContext: TMacroContext;
    public
        constructor Create(Context: TMacroContext);
        procedure Execute; virtual; abstract;
        function ProgressUnits: Integer; virtual;
    end;

    TTypeTextAction = class(TScriptAction)
    private
        FText: string;
    public
        constructor Create(Context: TMacroContext; const AText: string);
        procedure Execute; override;
        function ProgressUnits: Integer; override;
    end;

    TSleepAction = class(TScriptAction)
    private
        FMilliseconds: Cardinal;
    public
        constructor Create(Context: TMacroContext; AMS: Cardinal);
        procedure Execute; override;
    end;

    TEnterAction = class(TScriptAction)
    public
        constructor Create(Context: TMacroContext);
        procedure Execute; override;
        function ProgressUnits: Integer; override;
    end;

    TSendKeyAction = class(TScriptAction)
    private
        FKey: Word;
        FModifiers: Word;
    public
        constructor Create(Context: TMacroContext; AKey: Word; AModifiers: Word = 0);
        procedure Execute; override;
        function ProgressUnits: Integer; override;
    end;

    TClearLineAction = class(TScriptAction)
    private
        procedure SleepStop(AMS: Integer);
    public
        constructor Create(Context: TMacroContext);
        procedure Execute; override;
        function ProgressUnits: Integer; override;
    end;

    TSetKeyDelayAction = class(TScriptAction)
    private
        FDelayMs: Integer;
    public
        constructor Create(Context: TMacroContext; ADelayMs: Integer);
        procedure Execute; override;
    end;

implementation

uses
    Winapi.Windows,
    System.SyncObjs,
    System.Classes
    ;

{ TScriptAction }

constructor TScriptAction.Create(Context: TMacroContext);
begin
    inherited Create;
    FContext := Context;
end;

function TScriptAction.ProgressUnits: Integer;
begin
    Result := 0;
end;

{ TTypeTextAction }

constructor TTypeTextAction.Create(Context: TMacroContext; const AText: string);
begin
    inherited Create(Context);
    FText := AText;
end;

procedure TTypeTextAction.Execute;
begin
    if Assigned(FContext.Executor) then
        FContext.Executor.TypeRawText(FText, FContext);
end;

function TTypeTextAction.ProgressUnits: Integer;
begin
    Result := Length(FText);
end;

{ TSleepAction }

constructor TSleepAction.Create(Context: TMacroContext; AMS: Cardinal);
begin
    inherited Create(Context);
    FMilliseconds := AMS;
end;

procedure TSleepAction.Execute;
var
    StartTick: Cardinal;
    Loops: Integer;
    Remaining: Int64;
begin
    StartTick := GetTickCount;
    Loops := 0;

    while GetTickCount - StartTick < FMilliseconds do
    begin
        // Проверяем оба флага: пользовательскую отмену И системное завершение потока
        if Assigned(FContext) and
           (TInterlocked.CompareExchange(FContext.Canceled, 0, 0) <> 0) then
            Break;

        if TThread.CurrentThread.CheckTerminated then
            Break;

        Sleep(5);

        Inc(Loops);
        if Assigned(FContext) and (Loops mod 20 = 0) then
        begin
            Remaining := Int64(FMilliseconds) - Int64(GetTickCount - StartTick);
            if Remaining < 0 then
                Remaining := 0;
            TInterlocked.Exchange(FContext.SleepRemainingMs, Integer(Remaining));
        end;
    end;

    if Assigned(FContext) then
        TInterlocked.Exchange(FContext.SleepRemainingMs, 0);
end;

{ TEnterAction }

constructor TEnterAction.Create(Context: TMacroContext);
begin
    inherited Create(Context);
end;

procedure TEnterAction.Execute;
begin
    if Assigned(FContext.Executor) then
        FContext.Executor.PressEnter(FContext);
end;

function TEnterAction.ProgressUnits: Integer;
begin
    Result := 1;
end;

{ TSendKeyAction }

constructor TSendKeyAction.Create(Context: TMacroContext; AKey: Word; AModifiers: Word);
begin
    inherited Create(Context);
    FKey := AKey;
    FModifiers := AModifiers;
end;

procedure TSendKeyAction.Execute;
begin
    if Assigned(FContext.Executor) then
        FContext.Executor.PressKey(FKey, FModifiers, FContext);
end;

function TSendKeyAction.ProgressUnits: Integer;
begin
    Result := 1;
end;

{ TClearLineAction }

constructor TClearLineAction.Create(Context: TMacroContext);
begin
    inherited Create(Context);
end;

procedure TClearLineAction.SleepStop(AMS: Integer);
var
    StartTick: Cardinal;
begin
    StartTick := GetTickCount;
    while GetTickCount - StartTick < Cardinal(AMS) do
    begin
        // Пауза короткая, поэтому проверяем только флаг отмены:
        // CheckTerminated недоступен в чужих (не TThread) потоках
        if Assigned(FContext) and
           (TInterlocked.CompareExchange(FContext.Canceled, 0, 0) <> 0) then
            Break;

        Sleep(5);
    end;
end;

// Ctrl+C (прервать команду) - пауза - Ctrl+U (очистить строку)
procedure TClearLineAction.Execute;
begin
    if not Assigned(FContext.Executor) then
        Exit;

    FContext.Executor.PressKey(Ord('C'), MOD_CONTROL, FContext);
    SleepStop(150);
    FContext.Executor.PressKey(Ord('U'), MOD_CONTROL, FContext);
end;

function TClearLineAction.ProgressUnits: Integer;
begin
    Result := 2;
end;

{ TSetKeyDelayAction }

constructor TSetKeyDelayAction.Create(Context: TMacroContext; ADelayMs: Integer);
begin
    inherited Create(Context);
    FDelayMs := ADelayMs;
end;

procedure TSetKeyDelayAction.Execute;
begin
    FContext.KeyDelayMs := FDelayMs;
end;

end.
