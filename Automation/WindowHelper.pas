unit WindowHelper;

interface

uses
    Core.Interfaces.Settings, Core.Interfaces.Automation,
    MacroEngine,
    MacroInputTypes,
    MacroThread,
    Winapi.Windows
    ;

type
    TWindowHelper = class(TObject, IWindowHelper, ITextExecutor)
    private
        FWindowHelperInfo: TWindowHelperInfo;
        FMacroEngine: TMacroEngine;
        FMacroThread: TMacroThread;
        FSettingsManager: ISettingsManager;
        FActiveSettings: TAppSettings;

        procedure Reset;
        procedure SendUnicodeChar(CharCode: Word);
        procedure ActivateTargetWindow;
        procedure OnMacroTerminate(Sender: TObject);
        procedure StopActiveThread;
        procedure AbortMacro(Context: TMacroContext);
        class function IsMacroCanceled(Context: TMacroContext): Boolean; static;

        // Явная реализация IUnknown для отключения reference counting
        function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
        function _AddRef: Integer; stdcall;
        function _Release: Integer; stdcall;
    public
        constructor Create(SettingsManager: ISettingsManager);
        destructor Destroy; override;

        function GetWindowUnderCursor: Boolean;
        procedure TypeTextIntoWindow(const Text: string);
        procedure TypeTextIntoWindowWithContext(const Text: string; Context: TMacroContext);
        procedure SetTargetWindow(Handle: HWND);
        function GetWindowInfo: TWindowHelperInfo;
        function IsTypingBusy: Boolean;
        procedure CancelTyping;
        function EstimateTypingMs(const Text: string): Integer;
        function FindUnknownCommands(const Text: string): TArray<string>;

        // ITextExecutor
        procedure TypeRawText(const Text: string; Context: TMacroContext);
        procedure PressEnter(Context: TMacroContext);
        procedure PressKey(Key: Word; Context: TMacroContext);

        property Window: TWindowHelperInfo read FWindowHelperInfo;
        property MacroEngine: TMacroEngine read FMacroEngine;
    end;

implementation

uses
    Common.Helpers,
    System.Classes,
    System.SyncObjs,
    System.SysUtils
    ;

{ TWindowHelper }

constructor TWindowHelper.Create(SettingsManager: ISettingsManager);
begin
    FSettingsManager := SettingsManager;
    // PressEnter/PressKey/TypeRawText читают задержки из FActiveSettings и
    // могут вызваться до первого TypeTextIntoWindowWithContext
    FActiveSettings := FSettingsManager.Data;
    FMacroEngine := TMacroEngine.Create;
end;

destructor TWindowHelper.Destroy;
begin
    // TThread.WaitFor безопасен из главного потока: он обрабатывает
    // очередь Synchronize, поэтому дедлока с OnTerminate не возникает.
    // FreeOnTerminate = True: после WaitFor объект уже самоосвободился.
    StopActiveThread;

    FMacroEngine.Free;
    inherited;
end;

procedure TWindowHelper.Reset;
begin
    FWindowHelperInfo.Handle := 0;
    FWindowHelperInfo.Parent := 0;
    FWindowHelperInfo.ClassName := '';
    FWindowHelperInfo.ParentClassName := '';
    FWindowHelperInfo.WindowText := '';
end;

function TWindowHelper.GetWindowInfo: TWindowHelperInfo;
begin
    Result := FWindowHelperInfo;
end;

function TWindowHelper.GetWindowUnderCursor: Boolean;
var
    CursorPos: TPoint;
    TargetWnd: HWND;
    Buffer: array [0 .. 255] of Char;
begin
    Reset;

    if not GetCursorPos(CursorPos) then
        Exit(False);

    TargetWnd := WindowFromPoint(CursorPos);
    if TargetWnd = 0 then
        Exit(False);

    FWindowHelperInfo.Handle := TargetWnd;

    if GetClassName(TargetWnd, Buffer, Length(Buffer)) > 0 then
        FWindowHelperInfo.ClassName := string(Buffer);

    if GetWindowText(TargetWnd, Buffer, Length(Buffer)) > 0 then
        FWindowHelperInfo.WindowText := string(Buffer);

    FWindowHelperInfo.Parent := GetAncestor(TargetWnd, GA_PARENT);

    if (FWindowHelperInfo.Parent <> 0) and (GetClassName(FWindowHelperInfo.Parent, Buffer, Length(Buffer)) > 0) then
        FWindowHelperInfo.ParentClassName := string(Buffer);

    Result := True;
end;

procedure TWindowHelper.OnMacroTerminate(Sender: TObject);
begin
    // Обнуляем указатель только если это тот самый поток, который мы отслеживали
    if Sender = FMacroThread then
        FMacroThread := nil;
end;

function TWindowHelper.IsTypingBusy: Boolean;
begin
    Result := Assigned(FMacroThread);
end;

procedure TWindowHelper.StopActiveThread;
begin
    // Ссылку не обнуляем до фактического завершения: иначе новый поток
    // стартует параллельно со старым, а Destroy пропустит ожидание
    if Assigned(FMacroThread) then
    begin
        FMacroThread.Cancel;
        FMacroThread.WaitFor;
        FMacroThread := nil;
    end;
end;

procedure TWindowHelper.AbortMacro(Context: TMacroContext);
begin
    if Context = nil then
        Exit;

    TInterlocked.Exchange(Context.Canceled, 1);
    if Assigned(Context.OnFocusLost) then
        Context.OnFocusLost();
end;

class function TWindowHelper.IsMacroCanceled(Context: TMacroContext): Boolean;
begin
    Result := (Context = nil) or
        (TInterlocked.CompareExchange(Context.Canceled, 0, 0) <> 0) or
        TThread.CurrentThread.CheckTerminated;
end;

procedure TWindowHelper.CancelTyping;
begin
    StopActiveThread;
end;

function TWindowHelper.EstimateTypingMs(const Text: string): Integer;
var
    Tokens: TArray<TMacroToken>;
    Token: TMacroToken;
    Ms: Integer;
begin
    Ms := 0;
    Tokens := FMacroEngine.GetTokens(Text);
    for Token in Tokens do
        case Token.Kind of
            tkText:
                Inc(Ms, Length(Token.Text) * FActiveSettings.WindowHelper.KeyPressInterval +
                    FActiveSettings.WindowHelper.ActivationDelay +
                    FActiveSettings.WindowHelper.SetFocusDelay);
            tkSleep:
                Inc(Ms, Token.Value);
            tkEnter, tkSendKey:
                Inc(Ms, FActiveSettings.WindowHelper.KeyPressInterval);
        end;
    Result := Ms;
end;

function TWindowHelper.FindUnknownCommands(const Text: string): TArray<string>;
begin
    Result := FMacroEngine.ValidateCommands(Text);
end;

procedure TWindowHelper.SendUnicodeChar(CharCode: Word);
var
    Inputs: array [0 .. 1] of TInput;
begin
    ZeroMemory(@Inputs, SizeOf(Inputs));

    Inputs[0].Itype := INPUT_KEYBOARD;
    Inputs[0].ki.wVk := 0;
    Inputs[0].ki.wScan := CharCode;
    Inputs[0].ki.dwFlags := KEYEVENTF_UNICODE;

    Inputs[1].Itype := INPUT_KEYBOARD;
    Inputs[1].ki.wVk := 0;
    Inputs[1].ki.wScan := CharCode;
    Inputs[1].ki.dwFlags := KEYEVENTF_UNICODE or KEYEVENTF_KEYUP;

    SendInput(2, Inputs[0], SizeOf(TInput));
end;

procedure TWindowHelper.PressEnter(Context: TMacroContext);
var
    Inputs: array [0 .. 1] of TInput;
begin
    if IsMacroCanceled(Context) then
        Exit;

    ZeroMemory(@Inputs, SizeOf(Inputs));

    Inputs[0].Itype := INPUT_KEYBOARD;
    Inputs[0].ki.wVk := VK_RETURN;

    Inputs[1].Itype := INPUT_KEYBOARD;
    Inputs[1].ki.wVk := VK_RETURN;
    Inputs[1].ki.dwFlags := KEYEVENTF_KEYUP;

    SendInput(Length(Inputs), Inputs[0], SizeOf(TInput));

    Sleep(FActiveSettings.WindowHelper.KeyPressInterval);
end;

procedure TWindowHelper.PressKey(Key: Word; Context: TMacroContext);
var
    Inputs: array [0 .. 1] of TInput;
begin
    if IsMacroCanceled(Context) then
        Exit;

    ZeroMemory(@Inputs, SizeOf(Inputs));

    Inputs[0].Itype := INPUT_KEYBOARD;
    Inputs[0].ki.wVk := Key;

    Inputs[1].Itype := INPUT_KEYBOARD;
    Inputs[1].ki.wVk := Key;
    Inputs[1].ki.dwFlags := KEYEVENTF_KEYUP;

    SendInput(Length(Inputs), Inputs[0], SizeOf(TInput));

    Sleep(FActiveSettings.WindowHelper.KeyPressInterval);
end;

function TWindowHelper.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
    if GetInterface(IID, Obj) then
        Result := 0
    else
        Result := E_NOINTERFACE;
end;

procedure TWindowHelper.TypeRawText(const Text: string; Context: TMacroContext);
var
    I: Integer;
begin
    if FWindowHelperInfo.Handle = 0 then
        Exit;

    // Активируем цель только если фокус ушёл: повторный SetForegroundWindow
    // на каждый блок зря тормозит печать и дёргает оконный менеджер
    if GetForegroundWindow <> FWindowHelperInfo.Handle then
    begin
        SetForegroundWindow(FWindowHelperInfo.Handle);
        Sleep(FActiveSettings.WindowHelper.ActivationDelay);

        ActivateTargetWindow;
        Sleep(FActiveSettings.WindowHelper.SetFocusDelay);

        if GetForegroundWindow <> FWindowHelperInfo.Handle then
        begin
            AbortMacro(Context);
            Exit;
        end;
    end;

    for I := 1 to Length(Text) do
    begin
        if IsMacroCanceled(Context) then
            Exit;

        // Чужое окно в фокусе - печатать нельзя, уйдёт не туда
        if GetForegroundWindow <> FWindowHelperInfo.Handle then
        begin
            AbortMacro(Context);
            Exit;
        end;

        if (Text[I] = #13) or (Text[I] = #10) then
            PressEnter(Context)
        else
            SendUnicodeChar(Ord(Text[I]));

        Sleep(FActiveSettings.WindowHelper.KeyPressInterval);
    end;
end;

procedure TWindowHelper.TypeTextIntoWindowWithContext(const Text: string; Context: TMacroContext);
var
    Actions: TArray<IScriptAction>;
begin
    FActiveSettings := FSettingsManager.Data;
    {$IFDEF DEBUG}
    OutputDebugString(PChar(Format('[WinHelper] TypeTextIntoWindowWithContext: TextLength=%d', [Length(Text)])));
    {$ENDIF}

    if Text = '' then
    begin
        {$IFDEF DEBUG}
        OutputDebugString('[WinHelper] ERROR: Text is EMPTY');
        {$ENDIF}
        Context.Free;  // Освобождаем контекст
        Exit;
    end;

    try
        StopActiveThread;

        Context.Executor := Self;
        Actions := FMacroEngine.Parse(Text, Context);

        {$IFDEF DEBUG}
        OutputDebugString(PChar(Format('[WinHelper] Parsed %d actions', [Length(Actions)])));
        // Собираем все InputQuery ДО запуска потока
        OutputDebugString('[WinHelper] Pre-collecting inputs...');
        {$ENDIF}

        FMacroEngine.PreCollectInputs(Actions, Context);

        // Если пользователь отменил ввод - прерываем
        if Context.UserCanceled then
        begin
            {$IFDEF DEBUG}
            OutputDebugString('[WinHelper] User cancelled input, macro will NOT start');
            {$ENDIF}
            Context.Free;  // Освобождаем контекст
            Exit;
        end;

        {$IFDEF DEBUG}
        OutputDebugString('[WinHelper] Pre-collection completed successfully');
        {$ENDIF}

        // Создаём и запускаем поток только если ввод не был отменён.
        // Поток стартует подвешенным: OnTerminate привязывается до запуска,
        // иначе поток может завершиться до привязки и FMacroThread зависнет
        FMacroThread := TMacroThread.Create(Actions, Context, Context.OnRecordRun, True);
        FMacroThread.OnTerminate := OnMacroTerminate;
        FMacroThread.Start;

        {$IFDEF DEBUG}
        OutputDebugString('[WinHelper] Thread started');
        {$ENDIF}
    except
        Context.Free; // Гарантированно освобождаем при сбое парсинга
        raise;
    end;
end;

procedure TWindowHelper.TypeTextIntoWindow(const Text: string);
var
    Context: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    FActiveSettings := FSettingsManager.Data;
    StopActiveThread;

    Context := TMacroContext.Create;
    Context.Executor := Self;

    Actions := FMacroEngine.Parse(Text, Context);

    // Поток стартует подвешенным: OnTerminate привязывается до запуска
    FMacroThread := TMacroThread.Create(Actions, Context, Context.OnRecordRun, True);
    FMacroThread.OnTerminate := OnMacroTerminate;
    FMacroThread.Start;
end;

function TWindowHelper._AddRef: Integer;
begin
    Result := -1; // Возвращаем -1, чтобы отключить reference counting
end;

function TWindowHelper._Release: Integer;
begin
    Result := -1; // Возвращаем -1, чтобы отключить reference counting
end;

procedure TWindowHelper.ActivateTargetWindow;
var
    TargetThread: DWORD;
    CurrentThread: DWORD;
begin
    CurrentThread := GetCurrentThreadId;

    TargetThread := GetWindowThreadProcessId(FWindowHelperInfo.Handle, nil);

    AttachThreadInput(CurrentThread, TargetThread, True);

    try
        SetForegroundWindow(FWindowHelperInfo.Handle);
        Winapi.Windows.SetFocus(FWindowHelperInfo.Handle);
    finally
        AttachThreadInput(CurrentThread, TargetThread, False);
    end;
end;

procedure TWindowHelper.SetTargetWindow(Handle: HWND);
var
    Buffer: array[0..255] of Char;
begin
    Reset;
    FWindowHelperInfo.Handle := Handle;

    if Handle <> 0 then
    begin
        if GetClassName(Handle, Buffer, Length(Buffer)) > 0 then
            FWindowHelperInfo.ClassName := string(Buffer);

        if GetWindowText(Handle, Buffer, Length(Buffer)) > 0 then
            FWindowHelperInfo.WindowText := string(Buffer);

        FWindowHelperInfo.Parent := GetAncestor(Handle, GA_PARENT);

        if (FWindowHelperInfo.Parent <> 0) and (GetClassName(FWindowHelperInfo.Parent, Buffer, Length(Buffer)) > 0) then
            FWindowHelperInfo.ParentClassName := string(Buffer);
    end;
end;

end.
