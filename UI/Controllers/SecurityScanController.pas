unit SecurityScanController;

// Контроллер периодической фоновой проверки всех сниппетов сканером
// безопасности. Первый после открытия базы скан тихо строит набор
// проблемных (не доверенных) ID, дальнейшие сканы по интервалу из
// настроек сообщают тостом только о дельте новых находок. Набор ID
// используется MainForm для подсветки строк списка.

interface

uses
    Common.Helpers,
    Core.Interfaces.App,
    SecurityReport,
    SecurityScanDelta,
    System.Classes,
    System.Generics.Collections,
    System.SysUtils,
    System.Threading,
    UI.AppStatusBar,
    Vcl.ExtCtrls
    ;

const
    // Имя тоста: MainForm фильтрует по нему клики в OnReceiveLocalNotification
    SECURITY_TOAST_NAME = 'SecurityFindings';
    // Задержка первого скана после открытия базы: тост об успешном
    // открытии успевает уйти из центра уведомлений, и уведомление
    // сканера о находках не слипается с ним
    SECURITY_FIRST_SCAN_DELAY_MS = 10000;

type
    TSecurityScanController = class
    private
        FAppContext: IAppContext;
        FStatusBar: TAppStatusBar;
        FTimer: TTimer;
        FStartTimer: TTimer;
        FRunning: Integer;
        FSession: Integer;
        FLastScanTick: Cardinal;
        FHasBaseline: Boolean;
        FFlaggedIDs: TDictionary<Integer, Boolean>;
        FOnFindingsChanged: TProc;
        function IntervalMs: Cardinal;
        procedure HandleTick(Sender: TObject);
        procedure HandleStartTimer(Sender: TObject);
        procedure RunScan;
        procedure ApplyFindings(const Findings: TArray<TSecurityFinding>; ShowToast: Boolean);
    public
        constructor Create(AppContext: IAppContext; StatusBar: TAppStatusBar; OnFindingsChanged: TProc);
        destructor Destroy; override;

        // Открытие базы: тихий первый скан + запуск периодики
        procedure Start;
        // Закрытие базы/программы: остановка и сброс подсветки
        procedure Stop;

        // Точечный рескан одного сниппета после сохранения/удаления:
        // флаг снимается сразу при исправлении, trusted или удалении
        procedure RescanSnippet(SnippetID: Integer);

        // Есть ли у сниппета текущие находки (для подсветки строки)
        function IsFlagged(SnippetID: Integer): Boolean;
    end;

implementation

uses
    Common.Localization,
    Core.Entities.Snippet,
    Core.Interfaces.Services,
    SecurityScanner,
    System.SyncObjs,
    Winapi.Windows
    ;

{ TSecurityScanController }

constructor TSecurityScanController.Create(AppContext: IAppContext; StatusBar: TAppStatusBar; OnFindingsChanged: TProc);
begin
    inherited Create;
    FAppContext := AppContext;
    FStatusBar := StatusBar;
    FOnFindingsChanged := OnFindingsChanged;
    FFlaggedIDs := TDictionary<Integer, Boolean>.Create;
    FRunning := 0;
    FSession := 0;
    FLastScanTick := 0;
    FHasBaseline := False;

    // Собственный таймер: раз в минуту проверяет, истек ли интервал
    // периодики. Реальный скан троттлится настройкой, а не частотой тика
    FTimer := TTimer.Create(nil);
    FTimer.Interval := 60000;
    FTimer.OnTimer := HandleTick;
    FTimer.Enabled := False;

    // Одноразовый таймер отложенного старта первого скана сессии
    FStartTimer := TTimer.Create(nil);
    FStartTimer.Interval := SECURITY_FIRST_SCAN_DELAY_MS;
    FStartTimer.OnTimer := HandleStartTimer;
    FStartTimer.Enabled := False;
end;

destructor TSecurityScanController.Destroy;
begin
    FTimer.Free;
    FStartTimer.Free;
    FFlaggedIDs.Free;
    inherited Destroy;
end;

function TSecurityScanController.IntervalMs: Cardinal;
var
    Minutes: Integer;
begin
    Minutes := FAppContext.SettingsManager.Data.SecurityBackgroundScanIntervalMinutes;
    if Minutes <= 0 then
        Minutes := 30;
    Result := Cardinal(Minutes) * 60000;
end;

procedure TSecurityScanController.HandleTick(Sender: TObject);
begin
    if not FAppContext.SettingsManager.Data.SecurityBackgroundScanEnabled then
        Exit;

    // Первый скан сессии всегда выполняет отложенный таймер старта
    if FStartTimer.Enabled then
        Exit;

    if not FAppContext.DatabaseManager.IsConnected then
        Exit;

    if (FLastScanTick <> 0) and (GetTickCount - FLastScanTick < IntervalMs) then
        Exit;

    RunScan;
end;

// Отложенный первый скан: тост об открытии базы успел уйти,
// можно уведомлять о находках без слипания уведомлений
procedure TSecurityScanController.HandleStartTimer(Sender: TObject);
begin
    FStartTimer.Enabled := False;

    // База могла быть закрыта за время задержки
    if not FAppContext.DatabaseManager.IsConnected then
        Exit;

    RunScan;
end;

procedure TSecurityScanController.Start;
begin
    // Новая сессия сканирования: результаты сканов прошлой базы,
    // еще висящие в очереди, отбрасываются
    Inc(FSession);
    FHasBaseline := False;
    FLastScanTick := 0;
    FTimer.Enabled := True;

    if FAppContext.DatabaseManager.IsConnected then
        FStartTimer.Enabled := True;
end;

procedure TSecurityScanController.Stop;
begin
    FTimer.Enabled := False;
    FStartTimer.Enabled := False;
    Inc(FSession);
    FHasBaseline := False;
    FLastScanTick := 0;

    if FFlaggedIDs.Count > 0 then
    begin
        FFlaggedIDs.Clear;
        if Assigned(FOnFindingsChanged) then
            FOnFindingsChanged();
    end;
end;

procedure TSecurityScanController.RunScan;
var
    Strict: Boolean;
    Session: Integer;
begin
    if TInterlocked.CompareExchange(FRunning, 1, 0) <> 0 then
        Exit;

    // Троттлинг отсчитывается от старта скана: медленный скан не сдвигает
    // периодику и не может привести к наложению следующих
    FLastScanTick := GetTickCount;
    Strict := FAppContext.SettingsManager.Data.SecurityScanStrict;
    Session := FSession;

    TTask.Run(
        procedure
        var
            BgConnection: TComponent;
            BgService: ISnippetService;
            BgScanner: ISecurityScanner;
            Snippets: TArray<TSnippetDTO>;
            Findings: TArray<TSecurityFinding>;
        begin
            try
                try
                    // Изолированное подключение: скан не трогает соединение UI
                    BgService := FAppContext.CreateIsolatedSnippetService(BgConnection);
                    try
                        // Сканер без состояния, создается локально в потоке;
                        // режим берется из настройки (терпимый/строгий)
                        BgScanner := TSecurityScanner.Create(TSecurityScanner.ScanModeFromSetting(Strict));

                        Snippets := BgService.GetAllSnippets(0);
                        Findings := FilterSecurityReport(BuildSecurityReport(BgScanner, Snippets), False);

                        TThread.Queue(nil,
                            procedure
                            begin
                                // Сессия могла смениться (закрытие базы,
                                // переоткрытие) - устаревший результат не
                                // должен трогать флаги и тосты
                                if Session = FSession then
                                    ApplyFindings(Findings, FHasBaseline);
                            end);
                    finally
                        if Assigned(BgConnection) then
                            BgConnection.Free;
                    end;
                except
                    on E: Exception do
                        LogException('TSecurityScanController.RunScan', E);
                end;
            finally
                TInterlocked.Exchange(FRunning, 0);
            end;
        end);
end;

procedure TSecurityScanController.ApplyFindings(const Findings: TArray<TSecurityFinding>; ShowToast: Boolean);
var
    I: Integer;
    CurrentIDs: TArray<Integer>;
    NewIDs: TArray<Integer>;
    NewCount: Integer;
    Msg: string;
begin
    SetLength(CurrentIDs, Length(Findings));
    for I := 0 to High(Findings) do
        CurrentIDs[I] := Findings[I].SnippetID;

    // Дельта считается только когда база уже построена: первый скан
    // становится тихой отправной точкой
    if FHasBaseline then
        NewIDs := ComputeNewIDs(CurrentIDs, FFlaggedIDs.Keys.ToArray)
    else
        SetLength(NewIDs, 0);

    FFlaggedIDs.Clear;
    for I := 0 to High(CurrentIDs) do
        FFlaggedIDs.AddOrSetValue(CurrentIDs[I], True);
    FHasBaseline := True;

    // Подсветка обновляется всегда: она отражает все текущие находки
    // и переживает рестарт программы
    if Assigned(FOnFindingsChanged) then
        FOnFindingsChanged();

    if ShowToast then
    begin
        // Периодический скан: сообщаем только дельту новых находок
        NewCount := Length(NewIDs);
        if NewCount = 0 then
            Exit;

        Msg := TUIStateLoader.GetMessage(
            ScanFindingsMessageKey(NewCount, FAppContext.SettingsManager.Data.CurrentLanguage),
            [NewCount, Length(CurrentIDs)]);
    end
    else
    begin
        // Первый скан сессии: сообщаем общий объём проблемных сниппетов,
        // чтобы юзер сразу видел, есть ли проблемы в базе. Чистая база
        // молчит, чтобы не создавать шум при каждом открытии
        if Length(CurrentIDs) = 0 then
            Exit;

        Msg := TUIStateLoader.GetMessage('Settings.ScanFindingsBaseline',
            [Length(CurrentIDs)]);
    end;

    ShowSimpleToast(Msg, '', SECURITY_TOAST_NAME);
    if not SimpleToastSupported then
        FStatusBar.Flash(Msg);
end;

procedure TSecurityScanController.RescanSnippet(SnippetID: Integer);
var
    Snippet: TSnippetDTO;
    ContentReason, CommentReason: string;
    Flagged, HadFlag: Boolean;
begin
    // До первого скана сессии флаги не имеют смысла
    if not FHasBaseline then
        Exit;

    HadFlag := FFlaggedIDs.ContainsKey(SnippetID);

    if not FAppContext.DatabaseManager.IsConnected then
        Exit;

    // Рескан одиночного сниппета дешевый: делаем синхронно на UI-потоке
    Snippet := FAppContext.SnippetService.GetSnippetByID(SnippetID);
    if Snippet.ID = 0 then
        Flagged := False // сниппет удален
    else if Snippet.IsSecurityCheckIgnored then
        Flagged := False // доверенный: пользователь взял риск на себя
    else
        Flagged := FAppContext.SecurityScanner.HasSensitiveData(Snippet.Content, ContentReason) or
            FAppContext.SecurityScanner.HasSensitiveData(Snippet.Comment, CommentReason);

    if Flagged then
        FFlaggedIDs.AddOrSetValue(SnippetID, True)
    else if HadFlag then
        FFlaggedIDs.Remove(SnippetID);

    if (Flagged <> HadFlag) and Assigned(FOnFindingsChanged) then
        FOnFindingsChanged();
end;

function TSecurityScanController.IsFlagged(SnippetID: Integer): Boolean;
begin
    Result := FFlaggedIDs.ContainsKey(SnippetID);
end;

end.
