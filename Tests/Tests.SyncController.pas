unit Tests.SyncController;

interface

uses
    DUnitX.TestFramework,
    Core.Interfaces.App,
    Core.Interfaces.Automation,
    Core.Interfaces.Data,
    Core.Interfaces.Passwords,
    Core.Interfaces.Services,
    Core.Interfaces.Settings,
    Core.Interfaces.Tools,
    Core.Interfaces.UI,
    FireDAC.Comp.Client,
    SecurityScanner,
    SyncController,
    System.Classes,
    System.SysUtils,
    UI.AppStatusBar,
    Vcl.ActnList,
    Vcl.ComCtrls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Winapi.Windows
    ;

type
    TSyncTestSettings = class(TInterfacedObject, ISettingsManager)
    private
        function GetSettings: TAppSettings;
        procedure SetSettings(const Value: TAppSettings);
        function GetCurrentLanguage: string;
        procedure SetCurrentLanguage(const Value: string);
    public
        Data: TAppSettings;
        constructor Create;
        destructor Destroy; override;
        procedure Load;
        procedure Save;
    end;

    TSyncTestMessages = class(TInterfacedObject, IUIMessagesHandler)
    public
        LastMessage: string;
        procedure ShowError(const Message: string);
        procedure ShowInfo(const Message: string);
        procedure ShowWarning(const Message: string);
        function AskConfirmation(const Message, Title: string; Flags: Cardinal = MB_YESNO or MB_ICONQUESTION): Boolean;
        function AskWarning(const Message, Title: string): Boolean;
        function AskInput(const Title, Prompt: string; var Value: string): Boolean;
    end;

    TSyncTestDatabaseManager = class(TInterfacedObject, IDatabaseManager)
    public
        Connected: Boolean;
        ConnectionString: string;
        DbFile: string;
        procedure OpenDatabase(const Filename: string);
        procedure CreateDatabase(const Filename: string);
        procedure CloseDatabase;
        function IsConnected: Boolean;
        function GetConnectionString: string;
        function DatabaseFile: string;
        function CreateImportSnapshot: string;
    end;

    TSyncTestContext = class(TInterfacedObject, IAppContext)
    private
        FConn: TFDConnection;
        FDbFile: string;
        FDatabaseManager: IDatabaseManager;
        FSettingsManager: ISettingsManager;
        FMessagesHandler: IUIMessagesHandler;
        FSnippetService: ISnippetService;
        FCategoryService: ICategoryService;
        FTagService: ITagService;
        FUserService: IUserService;
        FHistoryService: ISnippetHistoryService;
        function GetDatabaseManager: IDatabaseManager;
        function GetSnippetService: ISnippetService;
        function GetCategoryService: ICategoryService;
        function GetTagService: ITagService;
        function GetUserService: IUserService;
        function GetPasswordService: IPasswordService;
        function GetSettingsManager: ISettingsManager;
        function GetWindowHelper: IWindowHelper;
        function GetMessagesHandler: IUIMessagesHandler;
        function GetEpochService: IEpochService;
        function GetHotkeyService: IHotkeyService;
        function GetLocalAIService: ILocalAIService;
        function GetSecurityScanner: ISecurityScanner;
        function GetHistoryService: ISnippetHistoryService;
        function GetChainService: IChainService;
        function GetSavedQueryService: ISavedQueryService;
        function GetDBConnection: TFDConnection;
    public
        constructor Create(AConn: TFDConnection; const ADbFile: string; ADatabaseManager: IDatabaseManager; ASettings: ISettingsManager; AMessages: IUIMessagesHandler);
        function CreateIsolatedSnippetService(out BackgroundConnection: TComponent): ISnippetService;
        function CreateIsolatedContext(out BackgroundConnection: TComponent): IAppContext;
    end;

    [TestFixture]
    TSyncControllerTests = class(TObject)
    private
        FTempDir: string;
        FDbFile: string;
        FConn: TFDConnection;
        FDbMgr: TSyncTestDatabaseManager;
        FSettings: TSyncTestSettings;
        FMessages: TSyncTestMessages;
        FContext: IAppContext;
        FHostForm: TForm;
        FStatusBar: TStatusBar;
        FAppStatus: TAppStatusBar;
        FSyncAction: TCustomAction;
        FTimer: TTimer;
        FController: TSyncController;
        FReloadCalls: Integer;
        FLastPreserve: Integer;
        function SchemaPath(const AFilename: string): string;
        procedure ExecSchema(AConn: TFDConnection);
        procedure SeedOneSnippet(const ATitle, AContent: string);
        procedure SeedBulkSnippets(ACount: Integer);
        procedure CreateController(APreserveCat: Integer);
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test]
        procedure MarkDataChanged_DebounceTimerAndDirty;
        [Test]
        procedure HandleAutoSyncTick_GatesByDirtyAndConnection;
        [Test]
        procedure PerformSync_Disconnected_NoOp;
        [Test]
        procedure PerformSync_SyncMode_ExportsVaultAndReloads;
        [Test]
        procedure PerformSync_Async_GuardBlocksReentrancy;
        [Test]
        procedure PerformSync_Async_ChangesDuringSync_KeepDirty;
    end;

implementation

uses
    CategoryRepository,
    CategoryService,
    Core.Entities.Category,
    Core.Entities.Snippet,
    FireDAC.Comp.Script,
    FireDAC.Comp.ScriptCommands,
    FireDAC.ConsoleUI.Wait,
    FireDAC.Phys.SQLite,
    FireDAC.Stan.Async,
    FireDAC.Stan.Def,
    FireDAC.Stan.Error,
    SnippetHistoryRepository,
    SnippetHistoryService,
    SnippetRepository,
    SnippetService,
    System.IOUtils,
    TagRepository,
    TagService,
    UserRepository,
    UserService
    ;

{ TSyncTestSettings }

constructor TSyncTestSettings.Create;
begin
    inherited Create;
end;

destructor TSyncTestSettings.Destroy;
begin
    inherited;
end;

function TSyncTestSettings.GetSettings: TAppSettings;
begin
    Result := Data;
end;

procedure TSyncTestSettings.SetSettings(const Value: TAppSettings);
begin
    Data := Value;
end;

function TSyncTestSettings.GetCurrentLanguage: string;
begin
    Result := Data.CurrentLanguage;
end;

procedure TSyncTestSettings.SetCurrentLanguage(const Value: string);
begin
    Data.CurrentLanguage := Value;
end;

procedure TSyncTestSettings.Load;
begin
end;

procedure TSyncTestSettings.Save;
begin
end;

{ TSyncTestMessages }

procedure TSyncTestMessages.ShowError(const Message: string);
begin
    LastMessage := Message;
end;

procedure TSyncTestMessages.ShowInfo(const Message: string);
begin
    LastMessage := Message;
end;

procedure TSyncTestMessages.ShowWarning(const Message: string);
begin
    LastMessage := Message;
end;

function TSyncTestMessages.AskConfirmation(const Message, Title: string;
    Flags: Cardinal): Boolean;
begin
    Result := True;
end;

function TSyncTestMessages.AskWarning(const Message, Title: string): Boolean;
begin
    Result := True;
end;

function TSyncTestMessages.AskInput(const Title, Prompt: string; var Value: string): Boolean;
begin
    Result := False;
end;

{ TSyncTestDatabaseManager }

procedure TSyncTestDatabaseManager.OpenDatabase(const Filename: string);
begin
end;

procedure TSyncTestDatabaseManager.CreateDatabase(const Filename: string);
begin
end;

procedure TSyncTestDatabaseManager.CloseDatabase;
begin
end;

function TSyncTestDatabaseManager.IsConnected: Boolean;
begin
    Result := Connected;
end;

function TSyncTestDatabaseManager.GetConnectionString: string;
begin
    Result := ConnectionString;
end;

function TSyncTestDatabaseManager.DatabaseFile: string;
begin
    Result := DbFile;
end;

function TSyncTestDatabaseManager.CreateImportSnapshot: string;
begin
    Result := '';
end;

{ TSyncTestContext }

constructor TSyncTestContext.Create(AConn: TFDConnection; const ADbFile: string;
    ADatabaseManager: IDatabaseManager; ASettings: ISettingsManager; AMessages: IUIMessagesHandler);
var
    SnippetRepo: ISnippetRepository;
    CategoryRepo: ICategoryRepository;
    TagRepo: ITagRepository;
    UserRepo: IUserRepository;
    HistoryRepo: ISnippetHistoryRepository;
begin
    inherited Create;
    FConn := AConn;
    FDbFile := ADbFile;
    FDatabaseManager := ADatabaseManager;
    FSettingsManager := ASettings;
    FMessagesHandler := AMessages;

    SnippetRepo := TSnippetRepository.Create(AConn);
    CategoryRepo := TCategoryRepository.Create(AConn);
    TagRepo := TTagRepository.Create(AConn);
    UserRepo := TUserRepository.Create(AConn);

    FSnippetService := TSnippetService.Create(SnippetRepo, CategoryRepo, TagRepo, UserRepo);
    FCategoryService := TCategoryService.Create(CategoryRepo);
    FTagService := TTagService.Create(TagRepo);
    FUserService := TUserService.Create(UserRepo);

    HistoryRepo := TSnippetHistoryRepository.Create(AConn);
    FHistoryService := TSnippetHistoryService.Create(HistoryRepo, FSnippetService);
end;

function TSyncTestContext.CreateIsolatedSnippetService(out BackgroundConnection: TComponent): ISnippetService;
begin
    Result := nil;
    BackgroundConnection := nil;
end;

function TSyncTestContext.CreateIsolatedContext(out BackgroundConnection: TComponent): IAppContext;
var
    NewConn: TFDConnection;
begin
    NewConn := TFDConnection.Create(nil);
    NewConn.Params.Text := FDatabaseManager.GetConnectionString;
    NewConn.Connected := True;
    NewConn.ExecSQL('PRAGMA foreign_keys = ON;');
    NewConn.ExecSQL('PRAGMA journal_mode = WAL;');
    NewConn.ExecSQL('PRAGMA busy_timeout = 5000;');
    BackgroundConnection := NewConn;
    Result := TSyncTestContext.Create(NewConn, FDbFile, FDatabaseManager, FSettingsManager, FMessagesHandler);
end;

function TSyncTestContext.GetDatabaseManager: IDatabaseManager;
begin
    Result := FDatabaseManager;
end;

function TSyncTestContext.GetSnippetService: ISnippetService;
begin
    Result := FSnippetService;
end;

function TSyncTestContext.GetCategoryService: ICategoryService;
begin
    Result := FCategoryService;
end;

function TSyncTestContext.GetTagService: ITagService;
begin
    Result := FTagService;
end;

function TSyncTestContext.GetUserService: IUserService;
begin
    Result := FUserService;
end;

function TSyncTestContext.GetPasswordService: IPasswordService;
begin
    Result := nil;
end;

function TSyncTestContext.GetSettingsManager: ISettingsManager;
begin
    Result := FSettingsManager;
end;

function TSyncTestContext.GetWindowHelper: IWindowHelper;
begin
    Result := nil;
end;

function TSyncTestContext.GetMessagesHandler: IUIMessagesHandler;
begin
    Result := FMessagesHandler;
end;

function TSyncTestContext.GetEpochService: IEpochService;
begin
    Result := nil;
end;

function TSyncTestContext.GetHotkeyService: IHotkeyService;
begin
    Result := nil;
end;

function TSyncTestContext.GetLocalAIService: ILocalAIService;
begin
    Result := nil;
end;

function TSyncTestContext.GetSecurityScanner: ISecurityScanner;
begin
    Result := nil;
end;

function TSyncTestContext.GetHistoryService: ISnippetHistoryService;
begin
    Result := FHistoryService;
end;

function TSyncTestContext.GetChainService: IChainService;
begin
    Result := nil;
end;

function TSyncTestContext.GetSavedQueryService: ISavedQueryService;
begin
    Result := nil;
end;

function TSyncTestContext.GetDBConnection: TFDConnection;
begin
    Result := FConn;
end;

{ TSyncControllerTests }

function TSyncControllerTests.SchemaPath(const AFilename: string): string;
var
    Dir: string;
begin
    Dir := TPath.GetDirectoryName(ParamStr(0));
    repeat
        Result := TPath.Combine(Dir, TPath.Combine('Database', 'Schema', AFilename));
        if TFile.Exists(Result) then
            Exit;
        Dir := TPath.GetDirectoryName(Dir);
    until Dir = '';
    raise Exception.Create('Schema file not found: ' + Result);
end;

procedure TSyncControllerTests.ExecSchema(AConn: TFDConnection);
var
    Script: TFDScript;
begin
    Script := TFDScript.Create(nil);
    try
        Script.Connection := AConn;
        Script.SQLScripts.Add.SQL.Text :=
            TFile.ReadAllText(SchemaPath('000_schema_init.sql'), TEncoding.UTF8);
        Script.ExecuteAll;
    finally
        Script.Free;
    end;
end;

procedure TSyncControllerTests.SeedOneSnippet(const ATitle, AContent: string);
var
    Cat: TCategoryDTO;
    Snip: TSnippetDTO;
    CatID: Integer;
begin
    Cat := Default(TCategoryDTO);
    Cat.Name := 'scripts';
    Cat.ParentID := 0;
    Cat.UserID := 1;
    CatID := FContext.CategoryService.CreateCategory(Cat);

    Snip := Default(TSnippetDTO);
    Snip.UserID := 1;
    Snip.CategoryID := CatID;
    Snip.Title := ATitle;
    Snip.Content := AContent;
    Snip.Language := 'bash';
    Snip.CreatedAt := 1600000000;
    Snip.UpdatedAt := 1700000000;
    FContext.SnippetService.CreateSnippet(Snip, []);
end;

procedure TSyncControllerTests.SeedBulkSnippets(ACount: Integer);
var
    Cat: TCategoryDTO;
    Snip: TSnippetDTO;
    CatID, I: Integer;
begin
    Cat := Default(TCategoryDTO);
    Cat.Name := 'bulk';
    Cat.ParentID := 0;
    Cat.UserID := 1;
    CatID := FContext.CategoryService.CreateCategory(Cat);

    for I := 1 to ACount do
    begin
        Snip := Default(TSnippetDTO);
        Snip.UserID := 1;
        Snip.CategoryID := CatID;
        Snip.Title := 'Bulk ' + I.ToString;
        Snip.Content := 'bulk content ' + I.ToString;
        Snip.Language := 'bash';
        Snip.CreatedAt := 1600000000;
        Snip.UpdatedAt := 1700000000;
        FContext.SnippetService.CreateSnippet(Snip, []);
    end;
end;

procedure TSyncControllerTests.CreateController(APreserveCat: Integer);
begin
    FController := TSyncController.Create(FContext, FSyncAction, FAppStatus, FTimer, APreserveCat,
        procedure(CatID: Integer)
        begin
            Inc(FReloadCalls);
            FLastPreserve := CatID;
        end);
end;

procedure TSyncControllerTests.Setup;
var
    I: Integer;
begin
    FTempDir := TPath.Combine(TPath.GetTempPath, 'ssk_sync_' + TGUID.NewGuid.ToString);
    TDirectory.CreateDirectory(FTempDir);
    FDbFile := TPath.Combine(FTempDir, 'work.sqlite');

    FConn := TFDConnection.Create(nil);
    FConn.Params.Add('DriverID=SQLite');
    FConn.Params.Add('Database=' + FDbFile);
    FConn.Params.Add('SharedCache=False');
    FConn.Params.Add('JournalMode=WAL');
    FConn.Params.Add('LockingMode=Normal');
    FConn.Connected := True;
    ExecSchema(FConn);
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''user1'')');

    FDbMgr := TSyncTestDatabaseManager.Create;
    FDbMgr.Connected := True;
    FDbMgr.DbFile := FDbFile;
    FDbMgr.ConnectionString :=
        'DriverID=SQLite' + sLineBreak +
        'Database=' + FDbFile + sLineBreak +
        'SharedCache=False' + sLineBreak +
        'JournalMode=WAL' + sLineBreak +
        'LockingMode=Normal' + sLineBreak;

    FSettings := TSyncTestSettings.Create;
    FSettings.Data := Default(TAppSettings);
    FSettings.Data.SyncDirectory := FTempDir;
    FSettings.Data.SyncOnExit := True;

    FMessages := TSyncTestMessages.Create;
    FContext := TSyncTestContext.Create(FConn, FDbFile, FDbMgr, FSettings, FMessages);

    FHostForm := TForm.CreateNew(nil);
    FStatusBar := TStatusBar.Create(FHostForm);
    FStatusBar.Parent := FHostForm;
    for I := 0 to 4 do
        FStatusBar.Panels.Add;
    FAppStatus := TAppStatusBar.Create(FStatusBar);

    FSyncAction := TCustomAction.Create(nil);
    FTimer := TTimer.Create(nil);
    FTimer.Enabled := False;

    FReloadCalls := 0;
    FLastPreserve := -1;
end;

procedure TSyncControllerTests.TearDown;
var
    Held: Boolean;
begin
    if FController <> nil then
    begin
        FController.WaitForCompletion;
        FreeAndNil(FController);
    end;

    Held := (FDbMgr <> nil) and (FDbMgr.RefCount > 0);
    FContext := nil;
    if Held then
        FDbMgr := nil
    else
        FreeAndNil(FDbMgr);

    FSettings := nil;
    FMessages := nil;
    FreeAndNil(FConn);
    FreeAndNil(FAppStatus);
    FreeAndNil(FStatusBar);
    FreeAndNil(FHostForm);
    FreeAndNil(FSyncAction);
    FreeAndNil(FTimer);

    if TDirectory.Exists(FTempDir) then
        TDirectory.Delete(FTempDir, True);
end;

procedure TSyncControllerTests.MarkDataChanged_DebounceTimerAndDirty;
begin
    CreateController(0);

    FController.MarkDataChanged;
    Assert.IsTrue(FController.Dirty);
    Assert.IsTrue(FTimer.Enabled);

    FController.StopTimer;
    Assert.IsFalse(FTimer.Enabled);

    FSettings.Data.SyncOnExit := False;
    FController.MarkDataChanged;
    Assert.IsFalse(FTimer.Enabled);
    Assert.IsTrue(FController.Dirty);
end;

procedure TSyncControllerTests.HandleAutoSyncTick_GatesByDirtyAndConnection;
begin
    CreateController(0);

    // РќРµ dirty: С‚РёРє РіР°СЃРёС‚ С‚Р°Р№РјРµСЂ, СЃРёРЅРє РЅРµ Р·Р°РїСѓСЃРєР°РµС‚СЃСЏ
    FController.HandleAutoSyncTick;
    Assert.IsFalse(FTimer.Enabled);
    Assert.AreEqual(0, FReloadCalls);

    // Dirty, РЅРѕ Р±Р°Р·Р° Р·Р°РєСЂС‹С‚Р°: СЃРёРЅРє РЅРµ Р·Р°РїСѓСЃРєР°РµС‚СЃСЏ
    FController.MarkDataChanged;
    FDbMgr.Connected := False;
    FController.HandleAutoSyncTick;
    Assert.AreEqual(0, FReloadCalls);
end;

procedure TSyncControllerTests.PerformSync_Disconnected_NoOp;
begin
    CreateController(0);
    FDbMgr.Connected := False;

    FController.PerformSync(False);

    Assert.AreEqual(0, FReloadCalls);
    Assert.IsFalse(TDirectory.Exists(TPath.Combine(FTempDir, 'work')));
end;

procedure TSyncControllerTests.PerformSync_SyncMode_ExportsVaultAndReloads;
var
    ExportFile: string;
begin
    CreateController(77);
    SeedOneSnippet('Backup Server', 'tar -czf /tmp/b.tar.gz /etc');
    FController.MarkDataChanged;

    FController.PerformSync(False);

    Assert.AreEqual(1, FReloadCalls);
    Assert.AreEqual(77, FLastPreserve);
    Assert.IsTrue(FSyncAction.Enabled);

    ExportFile := TPath.Combine(TPath.Combine(TPath.Combine(TPath.Combine(FTempDir, 'work'), 'user1'), 'scripts'), 'Backup Server.md');
    Assert.IsTrue(TFile.Exists(ExportFile));
    Assert.IsTrue(TFile.ReadAllText(ExportFile, TEncoding.UTF8).Contains('generator: SSHSnippetsKeeper'));
    Assert.IsTrue(TFile.ReadAllText(ExportFile, TEncoding.UTF8).Contains('Backup Server'));

    Assert.IsFalse(FController.Dirty);
    Assert.IsFalse(FAppStatus.Dirty);
end;

procedure TSyncControllerTests.PerformSync_Async_GuardBlocksReentrancy;
begin
    CreateController(0);
    SeedBulkSnippets(120);

    FController.PerformSync(True);
    FController.PerformSync(True);
    FController.WaitForCompletion;

    // Р’С‚РѕСЂРѕР№ РІС‹Р·РѕРІ РІС‹С€РµР» РїРѕ CompareExchange-РіР°СЂРґСѓ: СЌРєСЃРїРѕСЂС‚ РѕРґРёРЅ
    Assert.IsTrue(FReloadCalls = 1, 'ReloadCalls=' + IntToStr(FReloadCalls) +
        ', LastMessage=' + FMessages.LastMessage);
    Assert.IsTrue(FSyncAction.Enabled);

    // РџРѕСЃР»Рµ Р·Р°РІРµСЂС€РµРЅРёСЏ РіР°СЂРґ СЃР±СЂРѕС€РµРЅ: РЅРѕРІС‹Р№ СЃРёРЅРє РїСЂРѕС…РѕРґРёС‚
    FController.PerformSync(True);
    FController.WaitForCompletion;
    Assert.AreEqual(2, FReloadCalls);
end;

procedure TSyncControllerTests.PerformSync_Async_ChangesDuringSync_KeepDirty;
begin
    CreateController(0);
    SeedBulkSnippets(120);

    FController.MarkDataChanged;
    FController.PerformSync(True);
    // РР·РјРµРЅРµРЅРёРµ РІРѕ РІСЂРµРјСЏ С„РѕРЅРѕРІРѕР№ СЃРёРЅС…СЂРѕРЅРёР·Р°С†РёРё РЅРµ РґРѕР»Р¶РЅРѕ РїРѕС‚РµСЂСЏС‚СЊ С„Р»Р°Рі
    FController.MarkDataChanged;
    FController.WaitForCompletion;
    Assert.IsTrue(FController.Dirty);

    FController.PerformSync(False);
    Assert.IsFalse(FController.Dirty);
end;

end.
