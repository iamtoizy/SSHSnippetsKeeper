unit SyncController;

interface

uses
    Common.Localization,
    Common.Helpers,
    Core.Interfaces.App,
    Core.Interfaces.Settings,
    Core.MarkdownExporter,
    Core.MarkdownImporter,
    System.Classes,
    System.IOUtils,
    System.SysUtils,
    System.Threading,
    UI.AppStatusBar,
    Vcl.ActnList,
    Vcl.ExtCtrls
    ;

type
    // Контроллер синхронизации базы данных с Markdown-хранилищем
    TSyncController = class
    private
        FAppContext: IAppContext;
        FSyncAction: TCustomAction;
        FStatusBar: TAppStatusBar;
        FAutoSyncTimer: TTimer;
        FIsDbDirty: Boolean;
        FShowToastOnDone: Boolean;
        FPreserveCategoryID: Integer;
        FOnReloadUI: TProc<Integer>;
        FSyncInProgress: Integer;
        FPendingUIEvents: Integer;
        FChangesDuringSync: Boolean;
        function ResolveSyncPath: string;
        procedure QueueToUI(const AProc: TProc);
    public
        constructor Create(AppContext: IAppContext; SyncAction: TCustomAction; StatusBar: TAppStatusBar; AutoSyncTimer: TTimer; PreserveCategoryID: Integer; OnReloadUI: TProc<Integer>);

        // Фиксирует факт изменения данных и перезапускает debounce-таймер
        procedure MarkDataChanged;
        // Обработка тика авто-синхронизации
        procedure HandleAutoSyncTick;
        // Глушит таймер (при закрытии базы/программы)
        procedure StopTimer;

        procedure PerformSync(IsAsync: Boolean; ShowToastOnDone: Boolean = False);

        procedure WaitForCompletion;

        property Dirty: Boolean read FIsDbDirty;
    end;

implementation

uses
    System.SyncObjs,
    Winapi.Windows
    ;

{ TSyncController }

constructor TSyncController.Create(AppContext: IAppContext; SyncAction: TCustomAction; StatusBar: TAppStatusBar; AutoSyncTimer: TTimer; PreserveCategoryID: Integer; OnReloadUI: TProc<Integer>);
begin
    inherited Create;
    FAppContext := AppContext;
    FSyncAction := SyncAction;
    FStatusBar := StatusBar;
    FAutoSyncTimer := AutoSyncTimer;
    FPreserveCategoryID := PreserveCategoryID;
    FOnReloadUI := OnReloadUI;
    FSyncInProgress := 0;
    FPendingUIEvents := 0;
    FChangesDuringSync := False;
end;

procedure TSyncController.QueueToUI(const AProc: TProc);
begin
    TInterlocked.Increment(FPendingUIEvents);
    TThread.Queue(nil,
        procedure
        begin
            try
                AProc();
            finally
                TInterlocked.Decrement(FPendingUIEvents);
            end;
        end);
end;

procedure TSyncController.WaitForCompletion;
var
    StartTick: Cardinal;
begin
    StartTick := GetTickCount;
    while (FSyncInProgress <> 0) or (FPendingUIEvents > 0) do
    begin
        if (GetTickCount - StartTick) > 10000 then Break;
        Sleep(10);
        CheckSynchronize(10);
    end;
end;

procedure TSyncController.MarkDataChanged;
begin
    // Включаем флаг
    FIsDbDirty := True;

    if FSyncInProgress <> 0 then
        FChangesDuringSync := True;

    // Перезапускаем таймер (эффект Debounce).
    // Если метод вызывается часто (пользователь активно работает),
    // таймер всё время сбрасывается и сработает только через 5 сек после ПОСЛЕДНЕГО изменения.
    FAutoSyncTimer.Enabled := False;

    if FAppContext.SettingsManager.Data.SyncOnExit then
        FAutoSyncTimer.Enabled := True;
end;

procedure TSyncController.HandleAutoSyncTick;
begin
    FAutoSyncTimer.Enabled := False; // Выключаем таймер

    // Если были изменения - запускаем фоновую синхронизацию!
    // Флаг Dirty сбрасывается в PerformSync после успешного завершения
    if FIsDbDirty and FAppContext.DatabaseManager.IsConnected then
        PerformSync(True); // True = Асинхронно (в фоне, UI не виснет)
end;

procedure TSyncController.StopTimer;
begin
    FAutoSyncTimer.Enabled := False;
end;

function TSyncController.ResolveSyncPath: string;
var
    BaseDir, ConnStr, DbPath, DbName: string;
    Strings: TStringList;
begin
    BaseDir := Trim(FAppContext.SettingsManager.Data.SyncDirectory);
    if BaseDir.IsEmpty then
        BaseDir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'SnippetsVault');

    // Пытаемся вытащить имя базы из строки подключения FireDAC
    ConnStr := FAppContext.DatabaseManager.GetConnectionString;
    Strings := TStringList.Create;
    try
        Strings.Text := ConnStr;
        DbPath := Strings.Values['Database'];
    finally
        Strings.Free;
    end;

    // Если нашли - берем имя файла без расширения (например, "snippets" или "work")
    if DbPath <> '' then
        DbName := TPath.GetFileNameWithoutExtension(DbPath)
    else
        DbName := 'DefaultDB';

    // Формируем безопасный изолированный путь!
    Result := TPath.Combine(BaseDir, DbName);
end;

procedure TSyncController.PerformSync(IsAsync: Boolean; ShowToastOnDone: Boolean);
var
    SyncDir: string;
    DoSyncLogic: TProc;
begin
    if not FAppContext.DatabaseManager.IsConnected then Exit;

    if IsAsync then
    begin
        if TInterlocked.CompareExchange(FSyncInProgress, 1, 0) <> 0 then Exit;
    end
    else
    begin
        WaitForCompletion;
        FSyncInProgress := 1;
    end;

    SyncDir := ResolveSyncPath;

    if not TDirectory.Exists(SyncDir) then
    begin
        try
            System.SysUtils.ForceDirectories(SyncDir);
        except
            on E: Exception do
            begin
                if IsAsync then
                    TInterlocked.Exchange(FSyncInProgress, 0);
                FAppContext.MessagesHandler.ShowError(TUIStateLoader.GetMessage('Common.SyncFolderCreationError', [E.Message]));
                Exit;
            end;
        end;
    end;

    FShowToastOnDone := ShowToastOnDone;
    FSyncAction.Enabled := False;
    FStatusBar.SetEvent(TUIStateLoader.GetMessage('Common.SyncingStorage'));

    DoSyncLogic := procedure
    var
        BgConnection: TComponent;
        BgContext: IAppContext;
    begin
        try
            // ВАЖНО: Если мы в фоне, создаем изолированное подключение!
            // Если мы закрываем программу (IsAsync = False), можно безопасно использовать основной AppContext
            if IsAsync then
                BgContext := FAppContext.CreateIsolatedContext(BgConnection)
            else
                BgContext := FAppContext;

            try
                // Передаем BgContext вместо AppContext.
                // Теперь чтение/запись в БД идет в параллельном потоке SQLite и не трогает UI!
                TMarkdownImporter.ImportFromDirectory(BgContext, SyncDir);
                TMarkdownExporter.ExportDatabase(BgContext, SyncDir);

                QueueToUI(procedure
                begin
                    FOnReloadUI(FPreserveCategoryID);
                    FIsDbDirty := FChangesDuringSync;
                    FChangesDuringSync := False;
                    FStatusBar.SetDirty(FIsDbDirty);
                    if FShowToastOnDone then
                        FStatusBar.Flash(TUIStateLoader.GetMessage('Common.SyncCompleted'))
                    else
                        FStatusBar.SetEvent('');
                end);
            finally
                // Обязательно освобождаем фоновое подключение (DataModule), чтобы не было утечек памяти
                if IsAsync and Assigned(BgConnection) then
                    BgConnection.Free;
            end;
        except
            on E: Exception do
            begin
                var ErrMsg := TUIStateLoader.GetMessage('Common.SyncError', [E.Message]);
                QueueToUI(procedure
                begin
                    FAppContext.MessagesHandler.ShowError(ErrMsg);
                    FStatusBar.SetEvent(ErrMsg);
                    FChangesDuringSync := False;
                end);
            end;
        end;

        QueueToUI(procedure
        begin
            FSyncAction.Enabled := True;
        end);

        TInterlocked.Exchange(FSyncInProgress, 0);
    end;

    if IsAsync then
        TTask.Run(DoSyncLogic)  // Идеально плавный фоновый процесс
    else
    begin
        FStatusBar.ForceUpdate;
        DoSyncLogic();          // Синхронный вызов при выходе
        TInterlocked.Exchange(FSyncInProgress, 0);
        WaitForCompletion;
    end;
end;

end.
