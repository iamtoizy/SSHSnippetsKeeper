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
    Core.Interfaces
    ;

type
    TSnippetRunner = class
    private
        FUserID: NativeInt;
        FErrorHandler: IUIErrorHandler;
        function SelectTargetWindow(out TargetWindow: TWindowMonitorInfo): Boolean;
        function BuildMacroContext(SnippetID: NativeInt; TargetHWND: HWND): TMacroContext;
    public
        constructor Create(UserID: NativeInt);
        procedure ExecuteSnippet(const Snippet: TSnippetDTO);
    end;

implementation

uses
    WindowHelper,
    ChooseTerminalWindowUI,
    InputFormUI
    ;

{ Реализация TSnippetRunner }

constructor TSnippetRunner.Create(UserID: NativeInt);
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

function TSnippetRunner.BuildMacroContext(SnippetID: NativeInt; TargetHWND: HWND): TMacroContext;
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

procedure TSnippetRunner.ExecuteSnippet(const Snippet: TSnippetDTO);
var
    TargetWindow: TWindowMonitorInfo;
    Context: TMacroContext;
begin
    if Trim(Snippet.Content).IsEmpty then
    begin
        FErrorHandler.ShowInfo('Текст сниппета пуст.');
        Exit;
    end;

    if not SelectTargetWindow(TargetWindow) then
        Exit;

    if not IsWindow(TargetWindow.HWND) then
    begin
        FErrorHandler.ShowInfo('Выбранное окно больше не существует.');
        Exit;
    end;

    if MessageBox(0, PChar(Format('Ввести сниппет в окно: "%s"?', [TargetWindow.WindowTitle])), 'Подтверждение', MB_YESNO or MB_ICONQUESTION or MB_TOPMOST) <> IDYES then
        Exit;

    Context := BuildMacroContext(Snippet.ID, TargetWindow.HWND);
    WinHelper.SetTargetWindow(TargetWindow.HWND);
    WinHelper.TypeTextIntoWindowWithContext(Snippet.Content, Context);
end;

end.

