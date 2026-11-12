unit WindowHelper;

interface

uses
    Core.Interfaces.Settings, Core.Interfaces.Automation,
    MacroEngine,
    MacroInputTypes,
    MacroThread,
    System.Generics.Collections,
    Winapi.Windows
    ;

type
    TWindowHelper = class(TObject, IWindowHelper, ITextExecutor)
    private
        FWindowHelperInfo: TWindowHelperInfo;
        FMacroEngine: TMacroEngine;
        FMacroThread: TMacroThread;
        // Потоки, не успевшие завершиться за дедлайн: оторваны от этого
        // объекта (Executor = nil) и добираются по мере завершения
        FAbandoned: TList<TMacroThread>;
        FSettingsManager: ISettingsManager;
        FActiveSettings: TAppSettings;

        procedure Reset;
        procedure SendUnicodeChar(CharCode: Word);
        procedure ActivateTargetWindow;
        procedure StopActiveThread;
        // AWait = False: только уже завершившиеся; True: подождать остальных
        procedure ReapAbandoned(AWait: Boolean);
        function HasLiveAbandonedThread: Boolean;
        procedure AbortMacro(Context: TMacroContext);
        function WaitForTargetFocus(Context: TMacroContext): Boolean;
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
        function EndsTypingWithEnter(const Text: string): Boolean;
        function GetTypingSnapshot(out Paused, SleepRemainingMs, TypedChars, TotalChars, KeyDelayMs: Integer): Boolean;
        procedure Shutdown;
        function EstimateTypingMs(const Text: string): Integer;
        function FindUnknownCommands(const Text: string): TArray<string>;

        // ITextExecutor
        procedure TypeRawText(const Text: string; Context: TMacroContext);
        procedure PressEnter(Context: TMacroContext);
        procedure PressKey(Key: Word; Modifiers: Word; Context: TMacroContext);
    private
        function KeyIntervalMs(Context: TMacroContext): Integer;
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
    FAbandoned := TList<TMacroThread>.Create;
end;

destructor TWindowHelper.Destroy;
begin
    // WaitFor безопасен из главного потока: он обрабатывает очередь
    // Synchronize, поэтому дедлока с OnTypingFinished не возникает.
    // FreeOnTerminate = False: дескриптор жив до нашего Thread.Free
    StopActiveThread;

    // Последний шанс для отставших потоков: их Executor указывает сюда,
    // поэтому ждём завершения, пока объект ещё жив
    ReapAbandoned(True);
    FAbandoned.Free;

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

function TWindowHelper.IsTypingBusy: Boolean;
begin
    // Указатель живёт до reap-а в StopActiveThread, занятость определяет флаг.
    // Отставшие потоки тоже печатают: без них новый макрос стартовал бы
    // параллельно со старым
    Result := (Assigned(FMacroThread) and not FMacroThread.IsFinished) or
        HasLiveAbandonedThread;
end;

function TWindowHelper.EndsTypingWithEnter(const Text: string): Boolean;
begin
    Result := FMacroEngine.EndsTypingWithEnter(Text);
end;

function TWindowHelper.GetTypingSnapshot(out Paused, SleepRemainingMs, TypedChars, TotalChars, KeyDelayMs: Integer): Boolean;
begin
    Paused := 0;
    SleepRemainingMs := 0;
    TypedChars := 0;
    TotalChars := 0;
    KeyDelayMs := 0;
    // FMacroThread принадлежит главному потоку: снимок снимаем отсюда;
    // отставшие (abandoned) потоки прогресс не отдают - их не ждём
    if (not Assigned(FMacroThread)) or FMacroThread.IsFinished then
        Exit(False);
    Result := FMacroThread.GetContextSnapshot(Paused, SleepRemainingMs, TypedChars, TotalChars, KeyDelayMs);
end;

function TWindowHelper.HasLiveAbandonedThread: Boolean;
var
    Thread: TMacroThread;
begin
    for Thread in FAbandoned do
        if WaitForSingleObject(Thread.Handle, 0) = WAIT_TIMEOUT then
            Exit(True);
    Result := False;
end;

procedure TWindowHelper.ReapAbandoned(AWait: Boolean);
var
    I: Integer;
    Thread: TMacroThread;
    LDeadline: DWORD;
begin
    I := 0;
    while I < FAbandoned.Count do
    begin
        Thread := FAbandoned[I];

        if AWait then
        begin
            LDeadline := GetTickCount + 3000;
            while WaitForSingleObject(Thread.Handle, 100) = WAIT_TIMEOUT do
            begin
                CheckSynchronize;
                if GetTickCount >= LDeadline then
                begin
                    // Не успел и здесь: связи уже разорваны, поток
                    // завершится сам и утечёт - лучше утечка, чем вызов
                    // Executor на освобождённой памяти
                    Thread.Detach;
                    Break;
                end;
            end;
        end;

        if WaitForSingleObject(Thread.Handle, 0) = WAIT_OBJECT_0 then
        begin
            FAbandoned.Delete(I);
            Thread.Free;
            Continue;
        end;

        Inc(I);
    end;
end;

procedure TWindowHelper.StopActiveThread;
var
    Thread: TMacroThread;
    LDeadline: DWORD;
begin
    // Единственный владелец жизненного цикла потока - этот метод: pointer
    // забираем сразу, Cancel+WaitFor+Free. При FreeOnTerminate=False
    // дескриптор остаётся валидным, гонки с самоосвобождением нет
    // Завершившиеся отставшие потоки предыдущих отмен забираем здесь же
    ReapAbandoned(False);

    Thread := FMacroThread;
    if Thread = nil then
        Exit;

    FMacroThread := nil;
    Thread.Cancel;
    LDeadline := GetTickCount + 3000;
    while WaitForSingleObject(Thread.Handle, 100) = WAIT_TIMEOUT do
    begin
        CheckSynchronize;
        if GetTickCount >= LDeadline then
        begin
            // Поток не успел: отрываем его от этого объекта (Executor и
            // коллбэки = nil, Canceled взведён) и оставляем доживать в списке.
            // Раньше он просто бросался и мог вызвать Executor после
            // разрушения TWindowHelper, а IsTypingBusy считал печать свободной
            Thread.Detach;
            FAbandoned.Add(Thread);
            {$IFDEF DEBUG}
            OutputDebugString('[WinHelper] StopActiveThread: worker did not finish in 3s, detached (executor severed)');
            {$ENDIF}
            Exit;
        end;
    end;
    Thread.Free;
end;

procedure TWindowHelper.Shutdown;
begin
    // Остановка макропотока до завершения Application.Run: VCL и очередь
    // Synchronize ещё живы, поэтому CheckSynchronize в StopActiveThread
    // корректно обрабатывает коллбэки потока (OnTypingFinished и др.).
    // Финализация Core.Shutdown остаётся страховкой: к этому моменту
    // FMacroThread уже nil и деструктор не трогает поток.
    StopActiveThread;
end;

// Финальное прерывание: целевое окно закрыто, продолжать некуда.
// Взводим Canceled, чтобы поток завершился между действиями, и зовём
// OnFocusLost - тот показывает предупреждение в главном потоке
procedure TWindowHelper.AbortMacro(Context: TMacroContext);
begin
    if Context = nil then
        Exit;

    TInterlocked.Exchange(Context.Canceled, 1);
    if Assigned(Context.OnFocusLost) then
        Context.OnFocusLost();
end;

// Пауза печати: чужое окно в фокусе. Ждём без таймаута, пока пользователь
// сам вернётся в целевое окно - перехватывать фокус у него нельзя.
// True - можно печатать дальше; False - прерывание: цель закрыта (тогда
// AbortMacro уже взвёл Canceled и уведомил) либо подана отмена (без
// уведомления). Сон обязателен: StopActiveThread ждёт поток не дольше 3 c
function TWindowHelper.WaitForTargetFocus(Context: TMacroContext): Boolean;
begin
    if Context <> nil then
        TInterlocked.Exchange(Context.Paused, 1);
    try
        while True do
        begin
            if not IsWindow(FWindowHelperInfo.Handle) then
            begin
                AbortMacro(Context);
                Exit(False);
            end;

            if GetForegroundWindow = FWindowHelperInfo.Handle then
                Exit(True);

            if IsMacroCanceled(Context) then
                Exit(False);

            Sleep(80);
        end;
    finally
        if Context <> nil then
            TInterlocked.Exchange(Context.Paused, 0);
    end;
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

function TWindowHelper.KeyIntervalMs(Context: TMacroContext): Integer;
begin
    // Сниппет может переопределять скорость печати ({KEYDELAY N} и поле в редакторе)
    if (Context <> nil) and (Context.KeyDelayMs > 0) then
        Result := Context.KeyDelayMs
    else
        Result := FActiveSettings.WindowHelper.KeyPressInterval;
end;

procedure TWindowHelper.PressEnter(Context: TMacroContext);
var
    Inputs: array [0 .. 1] of TInput;
begin
    if IsMacroCanceled(Context) then
        Exit;

    // Клавиши не должны уйти в чужое окно: как и текст, встаём на паузу
    if (FWindowHelperInfo.Handle <> 0) and
        (GetForegroundWindow <> FWindowHelperInfo.Handle) and
        (not WaitForTargetFocus(Context)) then
        Exit;

    ZeroMemory(@Inputs, SizeOf(Inputs));

    Inputs[0].Itype := INPUT_KEYBOARD;
    Inputs[0].ki.wVk := VK_RETURN;

    Inputs[1].Itype := INPUT_KEYBOARD;
    Inputs[1].ki.wVk := VK_RETURN;
    Inputs[1].ki.dwFlags := KEYEVENTF_KEYUP;

    SendInput(Length(Inputs), Inputs[0], SizeOf(TInput));

    if Context <> nil then
        TInterlocked.Increment(Context.TypedChars);

    Sleep(KeyIntervalMs(Context));
end;

procedure TWindowHelper.PressKey(Key: Word; Modifiers: Word; Context: TMacroContext);
var
    Inputs: array [0 .. 7] of TInput;
    Count: Integer;

    procedure AddKey(AVk: Word; AUp: Boolean);
    begin
        Inputs[Count].Itype := INPUT_KEYBOARD;
        Inputs[Count].ki.wVk := AVk;
        if AUp then
            Inputs[Count].ki.dwFlags := KEYEVENTF_KEYUP;
        Inc(Count);
    end;

begin
    if IsMacroCanceled(Context) then
        Exit;

    // Клавиши не должны уйти в чужое окно: как и текст, встаём на паузу
    if (FWindowHelperInfo.Handle <> 0) and
        (GetForegroundWindow <> FWindowHelperInfo.Handle) and
        (not WaitForTargetFocus(Context)) then
        Exit;

    ZeroMemory(@Inputs, SizeOf(Inputs));
    Count := 0;

    // Модификаторы вниз
    if (MOD_CONTROL and Modifiers) <> 0 then
        AddKey(VK_CONTROL, False);
    if (MOD_ALT and Modifiers) <> 0 then
        AddKey(VK_MENU, False);
    if (MOD_SHIFT and Modifiers) <> 0 then
        AddKey(VK_SHIFT, False);

    // Основная клавиша вниз-вверх
    AddKey(Key, False);
    AddKey(Key, True);

    // Модификаторы вверх в обратном порядке
    if (MOD_SHIFT and Modifiers) <> 0 then
        AddKey(VK_SHIFT, True);
    if (MOD_ALT and Modifiers) <> 0 then
        AddKey(VK_MENU, True);
    if (MOD_CONTROL and Modifiers) <> 0 then
        AddKey(VK_CONTROL, True);

    SendInput(Count, Inputs[0], SizeOf(TInput));

    if Context <> nil then
        TInterlocked.Increment(Context.TypedChars);

    Sleep(KeyIntervalMs(Context));
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

        // Активация не удалась - пауза: ждём возврата фокуса без таймаута
        if not WaitForTargetFocus(Context) then
            Exit;
    end;

    for I := 1 to Length(Text) do
    begin
        if IsMacroCanceled(Context) then
            Exit;

        // Чужое окно в фокусе - пауза: печатать нельзя, уйдёт не туда
        if (GetForegroundWindow <> FWindowHelperInfo.Handle) and
            (not WaitForTargetFocus(Context)) then
            Exit;

        if (Text[I] = #13) or (Text[I] = #10) then
            PressEnter(Context)
        else
        begin
            SendUnicodeChar(Ord(Text[I]));
            if Context <> nil then
                TInterlocked.Increment(Context.TypedChars);
        end;

        Sleep(KeyIntervalMs(Context));
    end;
end;

procedure TWindowHelper.TypeTextIntoWindowWithContext(const Text: string; Context: TMacroContext);
var
    Actions: TArray<IScriptAction>;
    I, TotalUnits: Integer;
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

        // Диалоги INPUT вернули фокус нашему приложению: переактивируем цель
        // здесь, в главном потоке, пока процесс ещё имеет право менять
        // foreground (последний ввод был в модальной форме). Из рабочего
        // потока тот же вызов система может игнорировать, и печать встала бы
        // на паузу до ручного клика по терминалу. Без INPUT-макросов блок
        // пропускается: фокус уже в цели (SetForegroundWindow в TSnippetRunner)
        if (FWindowHelperInfo.Handle <> 0) and
            (GetForegroundWindow <> FWindowHelperInfo.Handle) then
        begin
            SetForegroundWindow(FWindowHelperInfo.Handle);
            Sleep(FActiveSettings.WindowHelper.ActivationDelay);

            ActivateTargetWindow;
            Sleep(FActiveSettings.WindowHelper.SetFocusDelay);
        end;

        // Общий объём печати для прогресса Stop-панели: после PreCollect
        // известны и собранные значения INPUT
        TotalUnits := 0;
        for I := 0 to High(Actions) do
            Inc(TotalUnits, Actions[I].ProgressUnits);
        TInterlocked.Exchange(Context.ProgressTotal, TotalUnits);

        // Создаём и запускаем поток только если ввод не был отменён.
        // Поток стартует подвешенным: привязка OnTerminate не нужна,
        // жизненным циклом владеет StopActiveThread
        FMacroThread := TMacroThread.Create(Actions, Context, Context.OnRecordRun, True);
        FMacroThread.Start;

        {$IFDEF DEBUG}
        OutputDebugString('[WinHelper] Thread started');
        {$ENDIF}
    except
        FreeAndNil(FMacroThread);
        Context.Free; // Гарантированно освобождаем при сбое парсинга
        raise;
    end;
end;

procedure TWindowHelper.TypeTextIntoWindow(const Text: string);
var
    Context: TMacroContext;
    Actions: TArray<IScriptAction>;
    I, TotalUnits: Integer;
begin
    FActiveSettings := FSettingsManager.Data;
    StopActiveThread;

    Context := TMacroContext.Create;
    Context.Executor := Self;

    try
        Actions := FMacroEngine.Parse(Text, Context);

        TotalUnits := 0;
        for I := 0 to High(Actions) do
            Inc(TotalUnits, Actions[I].ProgressUnits);
        TInterlocked.Exchange(Context.ProgressTotal, TotalUnits);

        FMacroThread := TMacroThread.Create(Actions, Context, Context.OnRecordRun, True);
        FMacroThread.Start;
    except
        FreeAndNil(FMacroThread);
        Context.Free; // Гарантированно освобождаем при сбое парсинга
        raise;
    end;
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
