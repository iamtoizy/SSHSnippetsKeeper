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
    UI.Interfaces,
    Core.Interfaces,
    SecurityScanner
    ;

type
    TSnippetRunner = class
    private
        FUserID: Integer;
        FErrorHandler: IUIErrorHandler;
        function SelectTargetWindow(out TargetWindow: TWindowMonitorInfo): Boolean;
        function BuildMacroContext(SnippetID: Integer; TargetHWND: HWND): TMacroContext;
    public
        class var IsExecuting: Boolean;
        constructor Create(UserID: Integer);
        procedure ExecuteSnippet(const Snippet: TSnippetDTO; RequireConfirmation: Boolean = True);
    end;

implementation

uses
    WindowHelper,
    ChooseTerminalWindowUI,
    InputFormUI
    ;

{ Реализация TSnippetRunner }

constructor TSnippetRunner.Create(UserID: Integer);
begin
    FUserID := UserID;
    FErrorHandler := TVCLErrorHandler.Create;
end;

function TSnippetRunner.SelectTargetWindow(out TargetWindow: TWindowMonitorInfo): Boolean;
begin
    Result := False;
    if not WinMonitor.CanAutoType then
    begin
        MessageBeep(MB_ICONHAND);
        FErrorHandler.ShowInfo('Не найдено разрешённых окон терминала в истории.');
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
    Context.Executor := WinHelper;
    Context.UserCancelled := False;
    Context.SnippetID := SnippetID;
    Context.UserID := FUserID;

    // Коллбэк для ввода
    Context.OnInput :=
        function(const Prompt: string): string
        begin
            Result := ''; // Здесь Result - это возвращаемая строка для OnInput

            // Обращаемся к переменной Context из внешней области видимости
            if ShowInputForm(Prompt, Context.CurrentDefaultValue, Context.CurrentInputType, Result) then
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
        FErrorHandler.ShowInfo('Текст сниппета пуст.');
        Exit;
    end;

    // --- 1. АНАЛИЗ БЕЗОПАСНОСТИ ---
    if not Snippet.IsSecurityCheckIgnored then
    begin
        Security := TSecurityScanner.Create;
        if Security.HasSensitiveData(Snippet.Content, WarningReason) then
        begin
            WarningMsg :=
                'Обнаружены потенциально чувствительные данные:' + sLineBreak +
                '• ' + WarningReason + sLineBreak + sLineBreak +
                'Необходимо проверить текст сниппета перед его отправкой в терминал.' + sLineBreak + sLineBreak +
                'Берёшь ответственность на себя и хочешь продолжить отправку?';

            // Если пользователь нажал "Нет" - прерываем.
            if not FErrorHandler.AskWarning(WarningMsg) then
                Exit;
        end;
    end;

    // --- 2. ВЫБОР ОКНА И ПОДТВЕРЖДЕНИЕ ---
    if not SelectTargetWindow(TargetWindow) then
        Exit;

    if not IsWindow(TargetWindow.HWND) then
    begin
        FErrorHandler.ShowInfo('Выбранное окно больше не существует.');
        Exit;
    end;

    if RequireConfirmation then
    begin
        // Используем наш обычный диалог подтверждения
        if not FErrorHandler.AskConfirmation(Format('Ввести сниппет в окно: "%s"?', [TargetWindow.WindowTitle])) then
            Exit;
    end;

    // --- 3. ВЫПОЛНЕНИЕ МАКРОСА ---
    IsExecuting := True;

    // Блокируем смену фокуса для нашего процесса (ASFW_ANY = 2)
    // Это не позволит MainForm "выпрыгнуть" вперед при переключении
    try
        LockSetForegroundWindow(2);
        try
            Context := BuildMacroContext(Snippet.ID, TargetWindow.HWND);
            SetForegroundWindow(TargetWindow.HWND);
            Sleep(50);
            WinHelper.SetTargetWindow(TargetWindow.HWND);
            WinHelper.TypeTextIntoWindowWithContext(Snippet.Content, Context);
        finally
        end;
    finally
        IsExecuting := False;
    end;
end;

end.

