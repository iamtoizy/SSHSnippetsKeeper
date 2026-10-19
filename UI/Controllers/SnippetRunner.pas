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
    public
        class var IsExecuting: Boolean;
        constructor Create(UserID: Integer; AppContext: IAppContext);
        procedure ExecuteSnippet(const Snippet: TSnippetDTO; RequireConfirmation: Boolean = True);
    end;

implementation

uses
    ChooseTerminalWindowUI,
    Common.Localization,
    InputFormUI,
    SecurityScanner,
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

procedure TSnippetRunner.ExecuteSnippet(const Snippet: TSnippetDTO; RequireConfirmation: Boolean = True);
var
    TargetWindow: TWindowMonitorInfo;
    Context: TMacroContext;
    Security: ISecurityScanner;
    WarningReason: string;
    WarningMsg: string;
begin
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
        Security := TSecurityScanner.Create;
        if Security.HasSensitiveData(Snippet.Content, WarningReason) then
        begin
            WarningMsg :=
                TUIStateLoader.GetMessage('Snippet.SensitiveDataFound', [WarningReason]);

            // Если пользователь нажал "Нет" - прерываем.
            if not FAppContext.MessagesHandler.AskWarning(
                WarningMsg,
                TUIStateLoader.GetMessage('Common.Warning')
            ) then Exit;
        end;
    end;

    // Выбор окна и подтверждение
    if not SelectTargetWindow(TargetWindow) then
        Exit;

    if not IsWindow(TargetWindow.HWND) then
    begin
        FAppContext.MessagesHandler.ShowInfo(
            TUIStateLoader.GetMessage('Terminal.WindowNoLongerExists')
        );
        Exit;
    end;

    if RequireConfirmation then
    begin
        // Используем наш обычный диалог подтверждения
        if not FAppContext.MessagesHandler.AskConfirmation(
            TUIStateLoader.GetMessage('Terminal.ConfirmTarget', [TargetWindow.WindowTitle]),
            TUIStateLoader.GetMessage('Common.Confirmation'),
            MB_YESNO or MB_ICONQUESTION
        ) then Exit;
    end;

    // Выполнение макроса
    IsExecuting := True;

    // Блокируем смену фокуса для нашего процесса (ASFW_ANY = 2)
    // Это не позволит MainForm "выпрыгнуть" вперед при переключении
    try
        LockSetForegroundWindow(LSFW_LOCK);
        try
            Context := BuildMacroContext(Snippet.ID, TargetWindow.HWND);
            SetForegroundWindow(TargetWindow.HWND);
            var TickEnd := GetTickCount + 100;
            while (GetForegroundWindow <> TargetWindow.HWND) and (GetTickCount < TickEnd) do
                Sleep(5);
            FAppContext.WindowHelper.SetTargetWindow(TargetWindow.HWND);
            FAppContext.WindowHelper.TypeTextIntoWindowWithContext(Snippet.Content, Context);
        finally
        end;
    finally
        LockSetForegroundWindow(LSFW_UNLOCK);
        IsExecuting := False;
    end;
end;

end.

