unit SnippetRunner;

interface

uses
    System.SysUtils,
    Vcl.Forms,
    Vcl.Controls,
    Vcl.Dialogs,
    Winapi.Windows,
    Snippet,
    WindowMonitor,
    MacroEngine,
    MacroInputTypes,
    Core.Interfaces,
    SecurityScanner
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
    InputFormUI,
    UI.StateLoader
    ;

{ Реализация TSnippetRunner }

constructor TSnippetRunner.Create(UserID: Integer; AppContext: IAppContext);
begin
    FUserID := UserID;
    FAppContext := AppContext;
end;

function TSnippetRunner.SelectTargetWindow(out TargetWindow: TWindowMonitorInfo): Boolean;
begin
    Result := False;
    if not WinMonitor.CanAutoType then
    begin
        MessageBeep(MB_ICONHAND);
        FAppContext.ErrorHandler.ShowInfo(
            TUIStateLoader.GetMessage('Terminal.HistoryEmpty')
        );
        Exit;
    end;

    if WinMonitor.AllowedWindowCount = 1 then
    begin
        TargetWindow := WinMonitor.GetLastAllowedWindow;
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
begin
    Context := TMacroContext.Create;
    Context.Executor := FAppContext.WindowHelper;
    Context.UserCancelled := False;
    Context.SnippetID := SnippetID;
    Context.UserID := FUserID;

    // Коллбэк для ввода
    Context.OnInput :=
        function(const Prompt: string): string
        begin
            Result := ''; // Здесь Result - это возвращаемая строка для OnInput

            // Обращаемся к переменной Context из внешней области видимости
            if ShowInputForm(Prompt, Context.CurrentDefaultValue, Context.CurrentInputType, FAppContext, Result) then
                Context.UserCancelled := False
            else
            begin
                Context.UserCancelled := True;
                Exit('');
            end;
        end;

    // Коллбэк для подтверждения
    Context.OnConfirm :=
        function(const Prompt: string): Boolean
        begin
            // Здесь Result - это возвращаемое значение (Boolean) для OnConfirm
            Result := MessageBox(TargetHWND, PChar(Prompt), 'Подтверждение', MB_YESNO or MB_ICONQUESTION or MB_TOPMOST) = IDYES;
            if not Result then
                Context.UserCancelled := True;
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
        FAppContext.ErrorHandler.ShowInfo(
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
            if not FAppContext.ErrorHandler.AskWarning(
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
        FAppContext.ErrorHandler.ShowInfo(
            TUIStateLoader.GetMessage('Terminal.WindowNoLongerExists')
        );
        Exit;
    end;

    if RequireConfirmation then
    begin
        // Используем наш обычный диалог подтверждения
        if not FAppContext.ErrorHandler.AskConfirmation(
            TUIStateLoader.GetMessage('', [TargetWindow.WindowTitle]),
            TUIStateLoader.GetMessage('Common.Warning', [TargetWindow.WindowTitle]),
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
            Sleep(50);
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

