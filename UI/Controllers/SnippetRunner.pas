unit SnippetRunner;

interface

uses
    Core.Entities.Snippet,
    Core.Interfaces.App,
    Core.Interfaces.Automation,
    Core.Interfaces.Services,
    Core.Interfaces.UI,
    MacroInputTypes,
    Winapi.Windows,
    WindowMonitor
    ;

type
    TSnippetRunner = class
    private
        FUserID: Integer;
        FAppContext: IAppContext;
        function SelectTargetWindow(out TargetWindow: TWindowMonitorInfo): Boolean;
        function BuildMacroContext(SnippetID: Integer; TargetHWND: HWND): TMacroContext;
        function ValidateBeforeType(const Snippet: TSnippetDTO): Boolean;
        procedure TypeIntoWindow(const Snippet: TSnippetDTO; TargetHWND: HWND);
        procedure DoExecuteInWindow(const Snippet: TSnippetDTO; TargetHWND: HWND; RequireConfirmation: Boolean);
    public
        class var IsExecuting: Boolean;
        constructor Create(UserID: Integer; AppContext: IAppContext);
        function PickTargetWindow(out TargetHWND: HWND): Boolean;
        procedure ExecuteSnippet(const Snippet: TSnippetDTO; RequireConfirmation: Boolean = True);
        procedure ExecuteSnippetInWindow(const Snippet: TSnippetDTO; TargetHWND: HWND; RequireConfirmation: Boolean = False);
    end;

implementation

uses
    ChooseTerminalWindowUI,
    Common.Localization,
    InputFormUI,
    System.SysUtils,
    Vcl.Controls
    ;

{ TSnippetRunner }

constructor TSnippetRunner.Create(UserID: Integer; AppContext: IAppContext);
begin
    FUserID := UserID;
    FAppContext := AppContext;
end;

function TSnippetRunner.SelectTargetWindow(out TargetWindow: TWindowMonitorInfo): Boolean;
begin
    Result := False;
    if not GWinMonitor.CanAutoType then
    begin
        MessageBeep(MB_ICONHAND);
        FAppContext.MessagesHandler.ShowInfo(
            TUIStateLoader.GetMessage('Terminal.HistoryEmpty')
        );
        Exit;
    end;

    if GWinMonitor.AllowedWindowCount = 1 then
    begin
        TargetWindow := GWinMonitor.GetLastAllowedWindow;
        Result := True;
    end
    else
    begin
        with TChooseTerminalWindow.Create(nil) do
        try
            Initialize(FAppContext);
            if ShowModal = mrOk then
            begin
                TargetWindow := SelectedWindow;
                Result := True;
            end;
        finally
            Free;
        end;
    end;
end;

function TSnippetRunner.BuildMacroContext(SnippetID: Integer; TargetHWND: HWND): TMacroContext;
var
    Context: TMacroContext;
    AppContext: IAppContext;
    SnippetService: ISnippetService;
begin
    Context := TMacroContext.Create;
    // Коллбэки ниже живут дольше этого объекта: TMacroThread выполняет макрос
    // асинхронно, а TSnippetRunner освобождается сразу после ExecuteSnippet.
    // Захватывать Self (FAppContext) в замыкания нельзя - после Free это
    // висячий указатель. Фиксируем интерфейсы в локальных переменных:
    // подсчёт ссылок удержит их, пока живы замыкания.
    AppContext := FAppContext;
    SnippetService := FAppContext.SnippetService;
    Context.Executor := FAppContext.WindowHelper;
    Context.UserCanceled := False;
    Context.SnippetID := SnippetID;
    Context.UserID := FUserID;
    Context.OnRecordRun :=
        procedure(SnippetID, AUserID: Integer)
        begin
            SnippetService.RecordRun(SnippetID, AUserID);
        end;

    // Коллбэк для ввода
    Context.OnInput :=
        function(const Prompt: string): string
        begin
            Result := ''; // Здесь Result - это возвращаемая строка для OnInput

            // Обращаемся к переменной Context из внешней области видимости
            if ShowInputForm(Prompt, Context.CurrentDefaultValue, Context.CurrentInputType, AppContext, Result) then
                Context.UserCanceled := False
            else
            begin
                Context.UserCanceled := True;
                Exit('');
            end;
        end;

    // Коллбэк для подтверждения
    Context.OnConfirm :=
        function(const Prompt: string): Boolean
        begin
            // Здесь Result - это возвращаемое значение (Boolean) для OnConfirm
            Result := MessageBox(0, PChar(Prompt), PChar(TUIStateLoader.GetMessage('Common.Confirmation')), MB_YESNO or MB_ICONQUESTION or MB_TOPMOST or MB_DEFBUTTON2) = IDYES;
            if not Result then
                Context.UserCanceled := True;
        end;

    // Возвращаем готовый контекст из метода BuildMacroContext
    Result := Context;
end;

function TSnippetRunner.ValidateBeforeType(const Snippet: TSnippetDTO): Boolean;
var
    WarningReason: string;
begin
    Result := False;

    if Trim(Snippet.Content).IsEmpty then
    begin
        FAppContext.MessagesHandler.ShowInfo(
            TUIStateLoader.GetMessage('Snippet.NoContentError')
        );
        Exit;
    end;

    // Анализ безопасности
    if not Snippet.IsSecurityCheckIgnored then
    begin
        if FAppContext.SecurityScanner.HasSensitiveData(Snippet.Content, WarningReason) then
        begin
            // Если пользователь нажал "Нет" - прерываем.
            if not FAppContext.MessagesHandler.AskWarning(
                TUIStateLoader.GetMessage('Security.SensitiveDataFound', [WarningReason]),
                TUIStateLoader.GetMessage('Common.Warning')
            ) then Exit;
        end;
    end;

    Result := True;
end;

procedure TSnippetRunner.TypeIntoWindow(const Snippet: TSnippetDTO; TargetHWND: HWND);
var
    Context: TMacroContext;
begin
    // Блокируем смену фокуса для нашего процесса (ASFW_ANY = 2)
    // Это не позволит MainForm "выпрыгнуть" вперед при переключении
    LockSetForegroundWindow(LSFW_LOCK);
    try
        Context := BuildMacroContext(Snippet.ID, TargetHWND);
        SetForegroundWindow(TargetHWND);
        var TickEnd := GetTickCount + 100;
        while (GetForegroundWindow <> TargetHWND) and (GetTickCount < TickEnd) do
            Sleep(5);
        FAppContext.WindowHelper.SetTargetWindow(TargetHWND);
        FAppContext.WindowHelper.TypeTextIntoWindowWithContext(Snippet.Content, Context);
    finally
        LockSetForegroundWindow(LSFW_UNLOCK);
    end;
end;

function TSnippetRunner.PickTargetWindow(out TargetHWND: HWND): Boolean;
var
    TargetWindow: TWindowMonitorInfo;
begin
    Result := SelectTargetWindow(TargetWindow);
    if Result then
        TargetHWND := TargetWindow.HWND;
end;

procedure TSnippetRunner.ExecuteSnippet(const Snippet: TSnippetDTO; RequireConfirmation: Boolean = True);
var
    TargetWindow: TWindowMonitorInfo;
begin
    // Защита от повторного входа: диалоги ниже прокачивают очередь сообщений,
    // так что второй вызов возможен, пока предыдущий макрос ещё печатается
    if IsExecuting then
    begin
        {$IFDEF DEBUG}
        OutputDebugString('[SnippetRunner] ExecuteSnippet re-entry blocked');
        {$ENDIF}
        Exit;
    end;

    IsExecuting := True;
    try
        if not ValidateBeforeType(Snippet) then
            Exit;

        // Выбор окна
        if not SelectTargetWindow(TargetWindow) then
            Exit;

        DoExecuteInWindow(Snippet, TargetWindow.HWND, RequireConfirmation);
    finally
        IsExecuting := False;
    end;
end;

procedure TSnippetRunner.ExecuteSnippetInWindow(const Snippet: TSnippetDTO; TargetHWND: HWND; RequireConfirmation: Boolean = False);
begin
    // Защита от повторного входа: см. ExecuteSnippet
    if IsExecuting then
    begin
        {$IFDEF DEBUG}
        OutputDebugString('[SnippetRunner] ExecuteSnippetInWindow re-entry blocked');
        {$ENDIF}
        Exit;
    end;

    IsExecuting := True;
    try
        DoExecuteInWindow(Snippet, TargetHWND, RequireConfirmation);
    finally
        IsExecuting := False;
    end;
end;

procedure TSnippetRunner.DoExecuteInWindow(const Snippet: TSnippetDTO; TargetHWND: HWND; RequireConfirmation: Boolean);
var
    Title: string;
    Len: Integer;
begin
    if not ValidateBeforeType(Snippet) then
        Exit;

    if not IsWindow(TargetHWND) then
    begin
        FAppContext.MessagesHandler.ShowInfo(
            TUIStateLoader.GetMessage('Terminal.WindowNoLongerExists')
        );
        Exit;
    end;

    if RequireConfirmation then
    begin
        SetLength(Title, 512);
        Len := GetWindowText(TargetHWND, PChar(Title), 512);
        SetLength(Title, Len);

        if not FAppContext.MessagesHandler.AskConfirmation(
            TUIStateLoader.GetMessage('Terminal.ConfirmTarget', [Title]),
            TUIStateLoader.GetMessage('Common.Confirmation'),
            MB_YESNO or MB_ICONQUESTION
        ) then Exit;
    end;

    TypeIntoWindow(Snippet, TargetHWND);
end;

end.

