unit WindowHelper;

interface

uses
    Winapi.Windows,
    System.SysUtils,
    MacroEngine,
    MacroThread,
    MacroInputTypes,
    Core.Interfaces
    ;

type
    TWindowHelper = class(TObject, IWindowHelper, ITextExecutor)
    private
        FWindowHelperInfo: TWindowHelperInfo;
        FMacroEngine: TMacroEngine;
        FMacroThread: TMacroThread;
        FSettingsManager: ISettingsManager;

        procedure Reset;
        procedure SendUnicodeChar(CharCode: Word);
        procedure ActivateTargetWindow;
        procedure OnMacroTerminate(Sender: TObject);

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

        // ITextExecutor
        procedure TypeRawText(const Text: string);
        procedure PressEnter;
        procedure PressKey(Key: Word);

        property Window: TWindowHelperInfo read FWindowHelperInfo;
        property MacroEngine: TMacroEngine read FMacroEngine;
    end;

implementation

uses
    System.Classes;

{ TWindowHelper }

constructor TWindowHelper.Create(SettingsManager: ISettingsManager);
begin
//    inherited;
    FSettingsManager := SettingsManager;
    FMacroEngine := TMacroEngine.Create;
end;

destructor TWindowHelper.Destroy;
var
    WaitResult: DWORD;
begin
    if Assigned(FMacroThread) then
    begin
        FMacroThread.Cancel;

        // Ждём завершения потока
        WaitResult := WaitForSingleObject(FMacroThread.Handle, 2000);

        if WaitResult = WAIT_OBJECT_0 then
        begin
            // Поток завершился нормально - FreeOnTerminate уже уничтожил объект
            // Просто обнуляем указатель
            FMacroThread := nil;
        end
        else
        begin
            // Поток НЕ завершился за 2 секунды
            // Принудительно завершаем и уничтожаем
            {$IFDEF DEBUG}
            OutputDebugString('[WindowHelper] WARNING: Macro thread did not terminate in 2s, forcing cleanup');
            {$ENDIF}

            // TerminateThread - опасная операция, но в деструкторе это единственный вариант
            // Поток завис и не реагирует на Cancel
            TerminateThread(FMacroThread.Handle, 1);

            // После TerminateThread поток мёртв, но объект TMacroThread ещё жив
            // (FreeOnTerminate не сработал, потому что поток не завершился нормально)
            // Уничтожаем объект вручную
            FMacroThread.Free;
            FMacroThread := nil;
        end;
    end;

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

procedure TWindowHelper.PressEnter;
var
    Inputs: array [0 .. 1] of TInput;
begin
    ZeroMemory(@Inputs, SizeOf(Inputs));

    Inputs[0].Itype := INPUT_KEYBOARD;
    Inputs[0].ki.wVk := VK_RETURN;

    Inputs[1].Itype := INPUT_KEYBOARD;
    Inputs[1].ki.wVk := VK_RETURN;
    Inputs[1].ki.dwFlags := KEYEVENTF_KEYUP;

    SendInput(Length(Inputs), Inputs[0], SizeOf(TInput));

    Sleep(FSettingsManager.Data.WindowHelper.KeyPressInterval);
end;

procedure TWindowHelper.PressKey(Key: Word);
var
    Inputs: array [0 .. 1] of TInput;
begin
    ZeroMemory(@Inputs, SizeOf(Inputs));

    Inputs[0].Itype := INPUT_KEYBOARD;
    Inputs[0].ki.wVk := Key;

    Inputs[1].Itype := INPUT_KEYBOARD;
    Inputs[1].ki.wVk := Key;
    Inputs[1].ki.dwFlags := KEYEVENTF_KEYUP;

    SendInput(Length(Inputs), Inputs[0], SizeOf(TInput));

    Sleep(FSettingsManager.Data.WindowHelper.KeyPressInterval);
end;

function TWindowHelper.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
    if GetInterface(IID, Obj) then
        Result := 0
    else
        Result := E_NOINTERFACE;
end;

procedure TWindowHelper.TypeRawText(const Text: string);
var
    I: Integer;
begin
    if FWindowHelperInfo.Handle = 0 then
        Exit;

    SetForegroundWindow(FWindowHelperInfo.Handle);
    Sleep(FSettingsManager.Data.WindowHelper.ActivationDelay);

    ActivateTargetWindow; // либо вообще SetForegroundWindow(FWindow.Handle);
    Sleep(FSettingsManager.Data.WindowHelper.SetFocusDelay);

    for I := 1 to Length(Text) do
    begin
        if (Text[I] = #13) or (Text[I] = #10) then
            PressEnter
        else
            SendUnicodeChar(Ord(Text[I]));

        Sleep(FSettingsManager.Data.WindowHelper.KeyPressInterval);
    end;
end;

procedure TWindowHelper.TypeTextIntoWindowWithContext(const Text: string; Context: TMacroContext);
var
    Actions: TArray<IScriptAction>;
begin
    {$IFDEF DEBUG}
    OutputDebugString(PChar(Format('[WinHelper] TypeTextIntoWindowWithContext: Text="%s"', [Text])));
    {$ENDIF}

    if Text = '' then
    begin
        {$IFDEF DEBUG}
        OutputDebugString('[WinHelper] ERROR: Text is EMPTY');
        {$ENDIF}
        Context.Free;  // Освобождаем контекст
        Exit;
    end;

    if Assigned(FMacroThread) then
    begin
        FMacroThread.Cancel;
        FMacroThread := nil;
    end;

    Context.Executor := Self;
    Actions := FMacroEngine.Parse(Text, Context);

    {$IFDEF DEBUG}
    OutputDebugString(PChar(Format('[WinHelper] Parsed %d actions', [Length(Actions)])));
    // Собираем все InputQuery ДО запуска потока
    OutputDebugString('[WinHelper] Pre-collecting inputs...');
    {$ENDIF}

    FMacroEngine.PreCollectInputs(Actions, Context);

    // Если пользователь отменил ввод - прерываем
    if Context.UserCancelled then
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

    // Создаём и запускаем поток только если ввод не был отменён
    FMacroThread := TMacroThread.Create(Actions, Context);
    FMacroThread.OnTerminate := OnMacroTerminate;

    {$IFDEF DEBUG}
    OutputDebugString('[WinHelper] Thread started');
    {$ENDIF}
end;

procedure TWindowHelper.TypeTextIntoWindow(const Text: string);
var
    Context: TMacroContext;
    Actions: TArray<IScriptAction>;
begin
    if Assigned(FMacroThread) then
    begin
        FMacroThread.Cancel;
        FMacroThread := nil;
    end;

    Context := TMacroContext.Create;
    Context.Executor := Self;

    Actions := FMacroEngine.Parse(Text, Context);

    FMacroThread := TMacroThread.Create(Actions, Context);
    FMacroThread.OnTerminate := OnMacroTerminate;
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
