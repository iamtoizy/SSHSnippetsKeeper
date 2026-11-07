unit UI.Services.LocalizationDiagnostics;

interface

uses
    System.SysUtils
    ;

type
    // Показ отчёта о промахах локализации. Строки собирает Common.Localization
    // (без UI и без блокировок), а показывает этот класс - строго из главного
    // потока, по таймеру, с защитой от кражи фокуса у терминала
    TLocalizationDiagnostics = class
    public
        // Тост и агрегированное окно. По умолчанию только в DEBUG: в Release
        // остаётся строка в логе, чтобы не мешать работе и не показывать
        // непереведённый текст. Включается и в Release присвоением True
        class var ShowAggregatedDialog: Boolean;

        // Создаёт таймер опроса. Вызывается из главного потока после
        // Application.Initialize
        class procedure Initialize;
        class procedure Shutdown;

        // Забирает накопленные промахи и показывает отчёт. Вызывается
        // таймером; публичный, чтобы дёрнуть вручную из точки останова
        class procedure ProcessPending;
    end;

implementation

uses
    ChainRunnerController,
    Common.Helpers,
    Common.Localization,
    SnippetRunner,
    System.Classes,
    System.Generics.Collections,
    System.Math,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Winapi.Windows
    ;

type
    // TNotifyEvent - это method pointer, а не анонимный метод, поэтому
    // событие таймера принимает маленький объект-насос
    TLocalizationTimerPump = class
    public
        procedure OnTimer(Sender: TObject);
    end;

const
    PROCESS_INTERVAL_MS = 2500;
    MAX_DIALOG_ITEMS = 10;

    // Тексты отчёта намеренно не берутся из языкового файла: отчёт нужен
    // ровно тогда, когда файл локализации устарел или сломан, и обращение
    // к GetMessage добавило бы к списку промахов сам отчёт
    TITLE_TEXT = 'Проблемы локализации';
    TOAST_TEXT = 'Не найдено строк локализации: %d. Подробности в SSHSnippetsKeeper.log';
    BODY_TEXT  = 'В языковом файле не найдено строк: %d.' + sLineBreak + sLineBreak +
                 'Первые из них:';
    ITEM_TEXT  = '• %s — %s (x%d)';
    MORE_TEXT  = '… и ещё %d';

var
    FInitialized: Boolean = False;
    FTimer: TTimer = nil;
    FPump: TLocalizationTimerPump = nil;
    // Ключи, о которых уже сообщили в этой сессии: повторные промахи
    // не должны превращаться в поток уведомлений
    FReportedKeys: TDictionary<string, Boolean> = nil;

function IssueSignature(const AIssue: TLocalizationIssue): string;
begin
    Result := IntToStr(Ord(AIssue.Kind)) + '|' + AIssue.Key;
end;

// Есть ли открытая модальная форма: окно отчёта поверх диалога ввода
// макроса сломало бы сценарий (и порядок закрытия форм)
function HasModalForm: Boolean;
var
    I: Integer;
begin
    Result := False;
    if not Assigned(Screen) then
        Exit;

    for I := 0 to Screen.FormCount - 1 do
        if fsModal in Screen.Forms[I].FormState then
            Exit(True);
end;

// Наше приложение сейчас активно: окно отчёта не отбирает фокус у чужого
// процесса (терминала, браузера)
function IsOwnWindowForeground: Boolean;
var
    Wnd: HWND;
    Pid: DWORD;
begin
    Result := False;

    Wnd := GetForegroundWindow;
    if Wnd = 0 then
        Exit;

    Pid := 0;
    GetWindowThreadProcessId(Wnd, @Pid);
    Result := Pid = GetCurrentProcessId;
end;

// Макрос или цепочка печатают в чужое окно: появление любого окна поверх
// терминала ставит печать на паузу (WaitForTargetFocus), поэтому отчёт
// откладывается до завершения
function IsQuietContext: Boolean;
begin
    Result := TSnippetRunner.IsExecuting or
        TChainRunner.IsChainRunning or
        HasModalForm;
end;

procedure TLocalizationTimerPump.OnTimer(Sender: TObject);
begin
    TLocalizationDiagnostics.ProcessPending;
end;

{ TLocalizationDiagnostics }

class procedure TLocalizationDiagnostics.Initialize;
begin
    if FInitialized then
        Exit;

    // Таймеру и диалогам нужен главный поток с очередью сообщений
    if TThread.CurrentThread.ThreadID <> MainThreadID then
        Exit;

    FReportedKeys := TDictionary<string, Boolean>.Create;

    FTimer := TTimer.Create(nil);
    FPump := TLocalizationTimerPump.Create;
    FTimer.Interval := PROCESS_INTERVAL_MS;
    FTimer.OnTimer := FPump.OnTimer;
    FTimer.Enabled := True;

    FInitialized := True;
end;

class procedure TLocalizationDiagnostics.Shutdown;
begin
    if Assigned(FTimer) then
        FreeAndNil(FTimer);
    FreeAndNil(FPump);
    FreeAndNil(FReportedKeys);
    FInitialized := False;
end;

class procedure TLocalizationDiagnostics.ProcessPending;
var
    Issues: TArray<TLocalizationIssue>;
    NewIssues: TList<TLocalizationIssue>;
    I: Integer;
    Body: string;
begin
    if not FInitialized then
        Exit;

    // Отчёт показывает только главный поток: TThread.Queue/Synchronize здесь
    // не нужны, а из рабочего потока любой диалог - путь к дедлоку
    if TThread.CurrentThread.ThreadID <> MainThreadID then
        Exit;

    // Консольный режим (/migrate, /backup, /checkdb и тесты): VCL может быть
    // не инициализирован, выводить некуда - только лог
    if IsConsole then
        Exit;

    if (Application = nil) or Application.Terminated then
        Exit;

    if not TUIStateLoader.HasPendingLocalizationIssues then
        Exit;

    // Пока идёт печать в терминал, промахи остаются в очереди
    if IsQuietContext then
        Exit;

    Issues := TUIStateLoader.TakePendingLocalizationIssues;
    if Length(Issues) = 0 then
        Exit;

    NewIssues := TList<TLocalizationIssue>.Create;
    try
        for I := 0 to High(Issues) do
        begin
            if FReportedKeys.ContainsKey(IssueSignature(Issues[I])) then
                Continue;

            FReportedKeys.Add(IssueSignature(Issues[I]), True);
            NewIssues.Add(Issues[I]);

            LogMsg(Format('LOCALIZATION: %s: "%s" (x%d)',
                [TUIStateLoader.LocalizationIssueKindName(Issues[I].Kind),
                 Issues[I].Key, Issues[I].Count]));
        end;

        if NewIssues.Count = 0 then
            Exit;

        if not ShowAggregatedDialog then
            Exit;

        ShowSimpleToast(Format(TOAST_TEXT, [NewIssues.Count]));

        // Окно только когда наше приложение и так на переднем плане:
        // иначе это ровно та кража фокуса, из-за которой макрос встаёт
        if not IsOwnWindowForeground then
            Exit;

        Body := Format(BODY_TEXT, [NewIssues.Count]);
        for I := 0 to Min(NewIssues.Count, MAX_DIALOG_ITEMS) - 1 do
            Body := Body + sLineBreak + Format(ITEM_TEXT,
                [NewIssues[I].Key,
                 TUIStateLoader.LocalizationIssueKindName(NewIssues[I].Kind),
                 NewIssues[I].Count]);

        if NewIssues.Count > MAX_DIALOG_ITEMS then
            Body := Body + sLineBreak + Format(MORE_TEXT, [NewIssues.Count - MAX_DIALOG_ITEMS]);

        MessageBox(Application.Handle, PChar(Body), PChar(TITLE_TEXT),
            MB_OK or MB_ICONWARNING);
    finally
        NewIssues.Free;
    end;
end;

initialization
    {$IFDEF DEBUG}
    TLocalizationDiagnostics.ShowAggregatedDialog := True;
    {$ELSE}
    TLocalizationDiagnostics.ShowAggregatedDialog := False;
    {$ENDIF}

end.
