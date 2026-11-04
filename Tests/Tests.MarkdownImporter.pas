unit Tests.MarkdownImporter;

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
    Core.MarkdownImporter,
    FireDAC.Comp.Client,
    SecurityScanner,
    System.Classes,
    Winapi.Windows
    ;

type
    // Заглушка настроек: импортеру нужен только дефолтный TAppSettings
    TTestSettings = class(TInterfacedObject, ISettingsManager)
    private
        FData: TAppSettings;
        FBash: TStringList;
        function GetSettings: TAppSettings;
        procedure SetSettings(const Value: TAppSettings);
        function GetCurrentLanguage: string;
        procedure SetCurrentLanguage(const Value: string);
        function GetBashAutocomplete: TStringList;
    public
        constructor Create;
        destructor Destroy; override;
        procedure Load;
        procedure Save;
    end;

    // Заглушка UI-сообщений: копит последний текст вместо показа диалогов
    TTestMessages = class(TInterfacedObject, IUIMessagesHandler)
    public
        LastMessage: string;
        procedure ShowError(const Message: string);
        procedure ShowInfo(const Message: string);
        procedure ShowWarning(const Message: string);
        function AskConfirmation(const Message, Title: string; Flags: Cardinal = MB_YESNO or MB_ICONQUESTION): Boolean;
        function AskWarning(const Message, Title: string): Boolean;
        function AskInput(const Title, Prompt: string; var Value: string): Boolean;
    end;

    // Заглушка менеджера БД: считает вызовы снапшота и возвращает заданный путь
    TTestDatabaseManager = class(TInterfacedObject, IDatabaseManager)
    public
        SnapshotResult: string;
        SnapshotCalls: Integer;
        procedure OpenDatabase(const Filename: string);
        procedure CreateDatabase(const Filename: string);
        procedure CloseDatabase;
        function IsConnected: Boolean;
        function GetConnectionString: string;
        function CreateImportSnapshot: string;
    end;

    // Контекст над in-memory SQLite: реальные репозитории и сервисы
    TTestAppContext = class(TInterfacedObject, IAppContext)
    private
        FConn: TFDConnection;
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
        function GetDBConnection: TFDConnection;
    public
        constructor Create(AConn: TFDConnection; ADatabaseManager: IDatabaseManager);
        // Имитация потерянного подключения для теста слоя 1
        procedure DropConnection;
        function CreateIsolatedSnippetService(out BackgroundConnection: TComponent): ISnippetService;
        function CreateIsolatedContext(out BackgroundConnection: TComponent): IAppContext;
    end;

    [TestFixture]
    TMarkdownImporterTests = class(TObject)
    private
        FConn: TFDConnection;
        FDbManager: TTestDatabaseManager;
        FContext: IAppContext;
        FTempDir: string;
        function VaultDir: string;
        function SchemaPath(const AFilename: string): string;
        procedure ExecSchema(AConn: TFDConnection);
        function WriteFile(const ARelPath, AContent: string): string;
        function SeedSnippet(const AContent: string; AUpdatedAt: Int64): Integer;
        function MdFile(AID: Integer; AUpdatedAt: Int64; const ATitle, ABody: string; AWithMarker: Boolean = True): string;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        // Слой 1
        [Test]
        procedure NoConnection_RaisesImportError;
        [Test]
        procedure LockedDB_AbortsAndLeavesNoPartialData;

        // Слой 2
        [Test]
        procedure NewerFile_UpdatesSnippet;
        [Test]
        procedure OlderFile_SkipsUpdate;
        [Test]
        procedure SameTimestamp_SkipsUpdate;
        [Test]
        procedure NoUpdatedAt_UsesFileMtime;
        [Test]
        procedure NewSnippet_CreatedDespiteOldDate;
        [Test]
        procedure NoMarker_DoesNotOverwrite;

        // Слой 3
        [Test]
        procedure FirstSync_TakesSnapshot;
        [Test]
        procedure UpdateOnly_NoSnapshot;
        [Test]
        procedure ManyNew_TakesSnapshot;
        [Test]
        procedure FewNew_NoSnapshot;
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
    FireDAC.Phys.SQLiteWrapper.Stat,
    FireDAC.Stan.Async,
    FireDAC.Stan.Def,
    FireDAC.Stan.Error,
    SnippetHistoryRepository,
    SnippetHistoryService,
    SnippetRepository,
    SnippetService,
    System.DateUtils,
    System.IOUtils,
    System.SysUtils,
    TagRepository,
    TagService,
    UserRepository,
    UserService
    ;

var
    GDriverLink: TFDPhysSQLiteDriverLink;

// True, если заглушку менеджера БД сейчас удерживает контекст через
// интерфейс. Проверять нужно ДО освобождения контекста: его деструктор
// может стать последним _Release и уничтожить объект
function DbManagerHeld(AMgr: TTestDatabaseManager): Boolean;
begin
    Result := (AMgr <> nil) and (AMgr.RefCount > 0);
end;

{ TTestSettings }

constructor TTestSettings.Create;
begin
    inherited Create;
    FData := Default(TAppSettings);
    FBash := TStringList.Create;
end;

destructor TTestSettings.Destroy;
begin
    FBash.Free;
    inherited;
end;

function TTestSettings.GetSettings: TAppSettings;
begin
    Result := FData;
end;

procedure TTestSettings.SetSettings(const Value: TAppSettings);
begin
    FData := Value;
end;

function TTestSettings.GetCurrentLanguage: string;
begin
    Result := FData.CurrentLanguage;
end;

procedure TTestSettings.SetCurrentLanguage(const Value: string);
begin
    FData.CurrentLanguage := Value;
end;

function TTestSettings.GetBashAutocomplete: TStringList;
begin
    Result := FBash;
end;

procedure TTestSettings.Load;
begin
end;

procedure TTestSettings.Save;
begin
end;

{ TTestMessages }

procedure TTestMessages.ShowError(const Message: string);
begin
    LastMessage := Message;
end;

procedure TTestMessages.ShowInfo(const Message: string);
begin
    LastMessage := Message;
end;

procedure TTestMessages.ShowWarning(const Message: string);
begin
    LastMessage := Message;
end;

function TTestMessages.AskConfirmation(const Message, Title: string;
    Flags: Cardinal): Boolean;
begin
    Result := True;
end;

function TTestMessages.AskWarning(const Message, Title: string): Boolean;
begin
    Result := True;
end;

function TTestMessages.AskInput(const Title, Prompt: string; var Value: string): Boolean;
begin
    Result := False;
end;

{ TTestDatabaseManager }

procedure TTestDatabaseManager.OpenDatabase(const Filename: string);
begin
end;

procedure TTestDatabaseManager.CreateDatabase(const Filename: string);
begin
end;

procedure TTestDatabaseManager.CloseDatabase;
begin
end;

function TTestDatabaseManager.IsConnected: Boolean;
begin
    Result := True;
end;

function TTestDatabaseManager.GetConnectionString: string;
begin
    Result := '';
end;

function TTestDatabaseManager.CreateImportSnapshot: string;
begin
    Inc(SnapshotCalls);
    Result := SnapshotResult;
end;

{ TTestAppContext }

constructor TTestAppContext.Create(AConn: TFDConnection; ADatabaseManager: IDatabaseManager);
var
    SnippetRepo: ISnippetRepository;
    CategoryRepo: ICategoryRepository;
    TagRepo: ITagRepository;
    UserRepo: IUserRepository;
    HistoryRepo: ISnippetHistoryRepository;
begin
    inherited Create;
    FConn := AConn;
    FDatabaseManager := ADatabaseManager;
    FSettingsManager := TTestSettings.Create;
    FMessagesHandler := TTestMessages.Create;

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

procedure TTestAppContext.DropConnection;
begin
    FConn := nil;
end;

function TTestAppContext.CreateIsolatedSnippetService(out BackgroundConnection: TComponent): ISnippetService;
begin
    Result := nil;
    BackgroundConnection := nil;
end;

function TTestAppContext.CreateIsolatedContext(out BackgroundConnection: TComponent): IAppContext;
begin
    Result := nil;
    BackgroundConnection := nil;
end;

function TTestAppContext.GetDatabaseManager: IDatabaseManager;
begin
    Result := FDatabaseManager;
end;

function TTestAppContext.GetSnippetService: ISnippetService;
begin
    Result := FSnippetService;
end;

function TTestAppContext.GetCategoryService: ICategoryService;
begin
    Result := FCategoryService;
end;

function TTestAppContext.GetTagService: ITagService;
begin
    Result := FTagService;
end;

function TTestAppContext.GetUserService: IUserService;
begin
    Result := FUserService;
end;

function TTestAppContext.GetPasswordService: IPasswordService;
begin
    Result := nil;
end;

function TTestAppContext.GetSettingsManager: ISettingsManager;
begin
    Result := FSettingsManager;
end;

function TTestAppContext.GetWindowHelper: IWindowHelper;
begin
    Result := nil;
end;

function TTestAppContext.GetMessagesHandler: IUIMessagesHandler;
begin
    Result := FMessagesHandler;
end;

function TTestAppContext.GetEpochService: IEpochService;
begin
    Result := nil;
end;

function TTestAppContext.GetHotkeyService: IHotkeyService;
begin
    Result := nil;
end;

function TTestAppContext.GetLocalAIService: ILocalAIService;
begin
    Result := nil;
end;

function TTestAppContext.GetSecurityScanner: ISecurityScanner;
begin
    Result := nil;
end;

function TTestAppContext.GetHistoryService: ISnippetHistoryService;
begin
    Result := FHistoryService;
end;

function TTestAppContext.GetChainService: IChainService;
begin
    Result := nil;
end;

function TTestAppContext.GetDBConnection: TFDConnection;
begin
    Result := FConn;
end;

{ TMarkdownImporterTests }

function TMarkdownImporterTests.SchemaPath(const AFilename: string): string;
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

procedure TMarkdownImporterTests.ExecSchema(AConn: TFDConnection);
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

procedure TMarkdownImporterTests.Setup;
begin
    FTempDir := TPath.Combine(TPath.GetTempPath, 'ssk_imp_' + TGuid.NewGuid.ToString);
    TDirectory.CreateDirectory(TPath.Combine(FTempDir, 'vault'));

    FConn := TFDConnection.Create(nil);
    FConn.Params.Add('DriverID=SQLite');
    FConn.Params.Add('Database=:memory:');
    FConn.Connected := True;
    FConn.ExecSQL('PRAGMA foreign_keys = ON');
    ExecSchema(FConn);
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'')');

    FDbManager := TTestDatabaseManager.Create;
    FContext := TTestAppContext.Create(FConn, FDbManager);
end;

procedure TMarkdownImporterTests.TearDown;
var
    Held: Boolean;
begin
    Held := DbManagerHeld(FDbManager);
    FContext := nil;
    if Held then
        FDbManager := nil
    else
        FreeAndNil(FDbManager);
    FreeAndNil(FConn);
    if TDirectory.Exists(FTempDir) then
        TDirectory.Delete(FTempDir, True);
end;

function TMarkdownImporterTests.VaultDir: string;
begin
    Result := TPath.Combine(FTempDir, 'vault');
end;

function TMarkdownImporterTests.WriteFile(const ARelPath, AContent: string): string;
begin
    Result := TPath.Combine(FTempDir, ARelPath);
    TDirectory.CreateDirectory(TPath.GetDirectoryName(Result));
    TFile.WriteAllText(Result, AContent, TEncoding.UTF8);
end;

function TMarkdownImporterTests.MdFile(AID: Integer; AUpdatedAt: Int64;
    const ATitle, ABody: string; AWithMarker: Boolean): string;
var
    SL: TStringList;
begin
    SL := TStringList.Create;
    try
        SL.Add('---');
        if AID > 0 then
            SL.Add('id: ' + AID.ToString);
        SL.Add('title: ' + ATitle);
        if AWithMarker then
            SL.Add('generator: SSHSnippetsKeeper');
        SL.Add('tags: ["ssh"]');
        SL.Add('language: bash');
        SL.Add('created_at: 1600000000');
        if AUpdatedAt >= 0 then
            SL.Add('updated_at: ' + AUpdatedAt.ToString);
        SL.Add('---');
        SL.Add('');
        SL.Add('# ' + ATitle);
        SL.Add('');
        SL.Add(ABody);
        SL.Add('');
        SL.Add('```bash');
        SL.Add('echo hello');
        SL.Add('```');
        Result := SL.Text;
    finally
        SL.Free;
    end;
end;

function TMarkdownImporterTests.SeedSnippet(const AContent: string; AUpdatedAt: Int64): Integer;
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
    Snip.Title := 'Seed';
    Snip.Comment := 'seed comment';
    Snip.Content := AContent;
    Snip.Language := 'bash';
    Snip.CreatedAt := 1600000000;
    Snip.UpdatedAt := AUpdatedAt;
    Result := FContext.SnippetService.CreateSnippet(Snip, []);
end;

// ---------------------------------------------------------------------------
// Слой 1: харденинг транзакции
// ---------------------------------------------------------------------------

procedure TMarkdownImporterTests.NoConnection_RaisesImportError;
var
    Ctx: IAppContext;
begin
    WriteFile(TPath.Combine('vault', 'user1', 'scripts', 'a.md'),
        MdFile(0, 1800000000, 'A', 'content A'));

    Ctx := TTestAppContext.Create(nil, FDbManager);
    try
        Assert.WillRaise(
            procedure
            begin
                TMarkdownImporter.ImportFromDirectory(Ctx, VaultDir);
            end,
            EMarkdownImportError);
    finally
        Ctx := nil;
    end;
end;

procedure TMarkdownImporterTests.LockedDB_AbortsAndLeavesNoPartialData;
var
    VaultDirLocked, DbFile: string;
    ConnA, ConnB: TFDConnection;
    Ctx: IAppContext;
    LocalMgr: TTestDatabaseManager;
    Held: Boolean;
begin
    VaultDirLocked := TPath.Combine(FTempDir, 'vault_locked');
    WriteFile(TPath.Combine('vault_locked', 'user1', 'scripts', 'a.md'),
        MdFile(0, 1800000000, 'A', 'content A'));

    DbFile := TPath.Combine(FTempDir, 'locked.sqlite');

    ConnA := TFDConnection.Create(nil);
    ConnB := nil;
    LocalMgr := nil;
    try
        ConnA.Params.Add('DriverID=SQLite');
        ConnA.Params.Add('Database=' + DbFile);
        ConnA.Params.Add('SharedCache=False');
        ConnA.Params.Add('JournalMode=WAL');
        ConnA.Params.Add('LockingMode=Normal');
        ConnA.Connected := True;
        ExecSchema(ConnA);
        ConnA.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'')');

        // Активный писатель в другом соединении блокирует запись
        ConnA.StartTransaction;
        ConnA.ExecSQL('INSERT INTO users (name) VALUES (''Blocker'')');

        ConnB := TFDConnection.Create(nil);
        ConnB.Params.Add('DriverID=SQLite');
        ConnB.Params.Add('Database=' + DbFile);
        ConnB.Params.Add('SharedCache=False');
        ConnB.Params.Add('JournalMode=WAL');
        ConnB.Params.Add('LockingMode=Normal');
        ConnB.Connected := True;

        LocalMgr := TTestDatabaseManager.Create;
        Ctx := TTestAppContext.Create(ConnB, LocalMgr);

        // Импорт обязан упасть с исключением, не оставив частичной записи
        Assert.WillRaise(
            procedure
            begin
                TMarkdownImporter.ImportFromDirectory(Ctx, VaultDirLocked);
            end);

        Ctx := nil;

        Assert.AreEqual(0, Integer(ConnA.ExecSQLScalar(
            'SELECT COUNT(*) FROM users WHERE name = ''user1''')));
        Assert.AreEqual(0, Integer(ConnA.ExecSQLScalar('SELECT COUNT(*) FROM snippets')));
    finally
        Held := DbManagerHeld(LocalMgr);
        if ConnA.InTransaction then
            ConnA.Rollback;
        Ctx := nil;
        if Held then
            LocalMgr := nil
        else
            LocalMgr.Free;
        ConnB.Free;
        ConnA.Free;
    end;
end;

// ---------------------------------------------------------------------------
// Слой 2: сравнение UpdatedAt
// ---------------------------------------------------------------------------

procedure TMarkdownImporterTests.NewerFile_UpdatesSnippet;
var
    SnipID: Integer;
    Res: TMarkdownImportResult;
begin
    SnipID := SeedSnippet('db content', 1700000000);
    WriteFile(TPath.Combine('vault', 'user1', 'scripts', 'note.md'),
        MdFile(SnipID, 1800000000, 'Note', 'new content'));

    Res := TMarkdownImporter.ImportFromDirectory(FContext, VaultDir);

    Assert.AreEqual(1, Res.TotalFiles);
    Assert.AreEqual(1, Res.Updated);
    Assert.AreEqual(0, Res.Created);
    // Тело md-файла попадает в comment, ограждение кода - в content
    Assert.AreEqual('new content', string(FConn.ExecSQLScalar(
        'SELECT comment FROM snippets WHERE id = ?', [SnipID])));
    Assert.AreEqual(Int64(1800000000), Int64(FConn.ExecSQLScalar(
        'SELECT updated_at FROM snippets WHERE id = ?', [SnipID])));
end;

procedure TMarkdownImporterTests.OlderFile_SkipsUpdate;
var
    SnipID: Integer;
    Res: TMarkdownImportResult;
begin
    SnipID := SeedSnippet('db content', 1700000000);
    WriteFile(TPath.Combine('vault', 'user1', 'scripts', 'note.md'),
        MdFile(SnipID, 1600000000, 'Note', 'new content'));

    Res := TMarkdownImporter.ImportFromDirectory(FContext, VaultDir);

    Assert.AreEqual(1, Res.SkippedStale);
    Assert.AreEqual(0, Res.Updated);
    Assert.AreEqual('db content', string(FConn.ExecSQLScalar(
        'SELECT content FROM snippets WHERE id = ?', [SnipID])));
    Assert.AreEqual(Int64(1700000000), Int64(FConn.ExecSQLScalar(
        'SELECT updated_at FROM snippets WHERE id = ?', [SnipID])));
end;

procedure TMarkdownImporterTests.SameTimestamp_SkipsUpdate;
var
    SnipID: Integer;
    Res: TMarkdownImportResult;
begin
    SnipID := SeedSnippet('db content', 1700000000);
    WriteFile(TPath.Combine('vault', 'user1', 'scripts', 'note.md'),
        MdFile(SnipID, 1700000000, 'Note', 'new content'));

    Res := TMarkdownImporter.ImportFromDirectory(FContext, VaultDir);

    Assert.AreEqual(1, Res.SkippedStale);
    Assert.AreEqual(0, Res.Updated);
    Assert.AreEqual('db content', string(FConn.ExecSQLScalar(
        'SELECT content FROM snippets WHERE id = ?', [SnipID])));
end;

procedure TMarkdownImporterTests.NoUpdatedAt_UsesFileMtime;
var
    SnipID: Integer;
    FilePath: string;
    Res: TMarkdownImportResult;
begin
    SnipID := SeedSnippet('db content', 1700000000);
    FilePath := WriteFile(TPath.Combine('vault', 'user1', 'scripts', 'nomd.md'),
        MdFile(SnipID, -1, 'NoUpd', 'file content'));

    // mtime старее записи в БД - скип
    TFile.SetLastWriteTimeUtc(FilePath, UnixToDateTime(1600000000));
    Res := TMarkdownImporter.ImportFromDirectory(FContext, VaultDir);
    Assert.AreEqual(1, Res.SkippedStale);
    Assert.AreEqual(0, Res.Updated);
    Assert.AreEqual('db content', string(FConn.ExecSQLScalar(
        'SELECT content FROM snippets WHERE id = ?', [SnipID])));

    // mtime новее записи в БД - обновление
    TFile.SetLastWriteTimeUtc(FilePath, UnixToDateTime(1900000000));
    Res := TMarkdownImporter.ImportFromDirectory(FContext, VaultDir);
    Assert.AreEqual(1, Res.Updated);
    Assert.AreEqual('file content', string(FConn.ExecSQLScalar(
        'SELECT comment FROM snippets WHERE id = ?', [SnipID])));
    Assert.AreEqual(Int64(1900000000), Int64(FConn.ExecSQLScalar(
        'SELECT updated_at FROM snippets WHERE id = ?', [SnipID])));
end;

procedure TMarkdownImporterTests.NewSnippet_CreatedDespiteOldDate;
var
    Res: TMarkdownImportResult;
begin
    WriteFile(TPath.Combine('vault', 'user1', 'scripts', 'new.md'),
        MdFile(0, 1600000000, 'New', 'new content'));

    Res := TMarkdownImporter.ImportFromDirectory(FContext, VaultDir);

    Assert.AreEqual(1, Res.TotalFiles);
    Assert.AreEqual(1, Res.Created);
    Assert.AreEqual(0, Res.SkippedStale);
    Assert.AreEqual('new content', string(FConn.ExecSQLScalar(
        'SELECT comment FROM snippets WHERE title = ''New''')));
    Assert.AreEqual(Int64(1600000000), Int64(FConn.ExecSQLScalar(
        'SELECT updated_at FROM snippets WHERE title = ''New''')));
end;

procedure TMarkdownImporterTests.NoMarker_DoesNotOverwrite;
var
    SnipID: Integer;
    Res: TMarkdownImportResult;
begin
    SnipID := SeedSnippet('db content', 1700000000);
    WriteFile(TPath.Combine('vault', 'user1', 'scripts', 'foreign.md'),
        MdFile(SnipID, 1800000000, 'Foreign', 'hijack content', False));

    Res := TMarkdownImporter.ImportFromDirectory(FContext, VaultDir);

    Assert.AreEqual(1, Res.SkippedNoMarker);
    Assert.AreEqual(0, Res.Updated);
    Assert.AreEqual('db content', string(FConn.ExecSQLScalar(
        'SELECT content FROM snippets WHERE id = ?', [SnipID])));
end;

// ---------------------------------------------------------------------------
// Слой 3: снапшот по порогу
// ---------------------------------------------------------------------------

procedure TMarkdownImporterTests.FirstSync_TakesSnapshot;
var
    Res: TMarkdownImportResult;
begin
    FDbManager.SnapshotResult := 'C:\fake\pre_import.bak';
    WriteFile(TPath.Combine('vault', 'user1', 'scripts', 'a.md'),
        MdFile(0, 1800000000, 'A', 'content A'));

    Res := TMarkdownImporter.ImportFromDirectory(FContext, VaultDir);

    Assert.AreEqual(1, FDbManager.SnapshotCalls);
    Assert.AreEqual('C:\fake\pre_import.bak', Res.SnapshotFile);
    Assert.AreEqual(1, Res.Created);
end;

procedure TMarkdownImporterTests.UpdateOnly_NoSnapshot;
var
    SnipID: Integer;
    Res: TMarkdownImportResult;
begin
    SnipID := SeedSnippet('db content', 1700000000);
    WriteFile(TPath.Combine('vault', 'user1', 'scripts', 'note.md'),
        MdFile(SnipID, 1800000000, 'Note', 'new content'));

    Res := TMarkdownImporter.ImportFromDirectory(FContext, VaultDir);

    Assert.AreEqual(1, Res.Updated);
    Assert.AreEqual(0, FDbManager.SnapshotCalls);
    Assert.AreEqual('', Res.SnapshotFile);
end;

procedure TMarkdownImporterTests.ManyNew_TakesSnapshot;
var
    I: Integer;
    Res: TMarkdownImportResult;
begin
    for I := 1 to 51 do
        WriteFile(TPath.Combine('vault', 'user1', 'scripts', 'f' + I.ToString + '.md'),
            MdFile(0, 1800000000, 'F' + I.ToString, 'content ' + I.ToString));

    Res := TMarkdownImporter.ImportFromDirectory(FContext, VaultDir);

    Assert.AreEqual(51, Res.Created);
    Assert.AreEqual(1, FDbManager.SnapshotCalls);
end;

procedure TMarkdownImporterTests.FewNew_NoSnapshot;
var
    Cat: TCategoryDTO;
    Snip: TSnippetDTO;
    CatID, I: Integer;
    Res: TMarkdownImportResult;
begin
    // База из 100 сниппетов: 3 новых = 15% и меньше лимита - снапшот не нужен
    Cat := Default(TCategoryDTO);
    Cat.Name := 'bulk';
    Cat.ParentID := 0;
    Cat.UserID := 1;
    CatID := FContext.CategoryService.CreateCategory(Cat);

    for I := 1 to 100 do
    begin
        Snip := Default(TSnippetDTO);
        Snip.UserID := 1;
        Snip.CategoryID := CatID;
        Snip.Title := 'Bulk ' + I.ToString;
        Snip.Content := 'bulk content';
        Snip.Language := 'bash';
        Snip.CreatedAt := 1600000000;
        Snip.UpdatedAt := 1700000000;
        FContext.SnippetService.CreateSnippet(Snip, []);
    end;

    for I := 1 to 3 do
        WriteFile(TPath.Combine('vault', 'user1', 'scripts', 'n' + I.ToString + '.md'),
            MdFile(0, 1800000000, 'N' + I.ToString, 'content ' + I.ToString));

    Res := TMarkdownImporter.ImportFromDirectory(FContext, VaultDir);

    Assert.AreEqual(3, Res.Created);
    Assert.AreEqual(0, FDbManager.SnapshotCalls);
end;

initialization
    GDriverLink := TFDPhysSQLiteDriverLink.Create(nil);

finalization
    GDriverLink.Free;

end.
