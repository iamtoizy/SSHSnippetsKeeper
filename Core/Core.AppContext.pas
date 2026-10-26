unit Core.AppContext;

interface

uses
    CategoryRepository,
    CategoryService,
    ChainRepository,
    ChainService,
    Core.Interfaces.App,
    Core.Interfaces.Automation,
    Core.Interfaces.Data,
    Core.Interfaces.Passwords,
    Core.Interfaces.Services,
    Core.Interfaces.Settings,
    Core.Interfaces.Tools,
    Core.Interfaces.UI,
    EpochService,
    FireDAC.Comp.Client,
    HotkeyService,
    PasswordService,
    SecurityScanner,
    SnippetHistoryRepository,
    SnippetHistoryService,
    SnippetRepository,
    SnippetService,
    System.Classes,
    System.SysUtils,
    TagRepository,
    TagService,
    UserRepository,
    UserService
    ;

type
    TAppContext = class(TInterfacedObject, IAppContext)
    private
        FDatabaseManager: IDatabaseManager;
        FSnippetService: ISnippetService;
        FCategoryService: ICategoryService;
        FTagService: ITagService;
        FUserService: IUserService;
        FPasswordService: IPasswordService;
        FSettingsManager: ISettingsManager;
        FWindowHelper: IWindowHelper;
        FMessagesHandler: IUIMessagesHandler;
        FEpochService: IEpochService;
        FHotkeyService: IHotkeyService;
        FLocalAIService: ILocalAIService;
        FSecurityScanner: ISecurityScanner;
        FHistoryService: ISnippetHistoryService;
        FChainService: IChainService;
        FDBConnection: TFDConnection;

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
        // Основной конструктор (для UI-потока)
        constructor Create(
            DatabaseManager: IDatabaseManager;
            DBConnection: TFDConnection;
            SettingsManager: ISettingsManager;
            WindowHelper: IWindowHelper;
            MessagesHandler: IUIMessagesHandler;
            LocalAIFactory: TFunc<ILocalAIService> = nil
        );

        // Второй конструктор: Для безопасных фоновых задач (TTask)
        constructor CreateBackground(DBConnection: TFDConnection; BaseContext: IAppContext);

        property DatabaseManager: IDatabaseManager read GetDatabaseManager;
        property SnippetService: ISnippetService read GetSnippetService;
        property CategoryService: ICategoryService read GetCategoryService;
        property TagService: ITagService read GetTagService;
        property UserService: IUserService read GetUserService;
        property PasswordService: IPasswordService read GetPasswordService;
        property SettingsManager: ISettingsManager read GetSettingsManager;
        property WindowHelper: IWindowHelper read GetWindowHelper;
        property MessagesHandler: IUIMessagesHandler read GetMessagesHandler;
        property EpochService: IEpochService read GetEpochService;
        property HotkeyService: IHotkeyService read GetHotkeyService;
        property LocalAIService: ILocalAIService read GetLocalAIService;
        property SecurityScanner: ISecurityScanner read GetSecurityScanner;
        property HistoryService: ISnippetHistoryService read GetHistoryService;
        property ChainService: IChainService read GetChainService;
        property DBConnection: TFDConnection read GetDBConnection;

        function CreateIsolatedSnippetService(out BackgroundConnection: TComponent): ISnippetService;

        // Новая фабрика для полной изоляции при синхронизации
        function CreateIsolatedContext(out BackgroundConnection: TComponent): IAppContext;
    end;

implementation

uses
    Core.LocalAIService
    ;

{ TAppContext }

constructor TAppContext.Create(
    DatabaseManager: IDatabaseManager;
    DBConnection: TFDConnection;
    SettingsManager: ISettingsManager;
    WindowHelper: IWindowHelper;
    MessagesHandler: IUIMessagesHandler;
    LocalAIFactory: TFunc<ILocalAIService>
);
var
    SnippetRepo: ISnippetRepository;
    CategoryRepo: ICategoryRepository;
    TagRepo: ITagRepository;
    UserRepo: IUserRepository;
    HistoryRepo: ISnippetHistoryRepository;
begin
    inherited Create;

    FDatabaseManager := DatabaseManager;
    FDBConnection := DBConnection;
    FSettingsManager := SettingsManager;
    FWindowHelper := WindowHelper;
    FMessagesHandler := MessagesHandler;

    FHotkeyService := THotkeyService.Create;
    // Накладываем настройки юзера из JSON поверх дефолтной карты
    FHotkeyService.LoadFromSettings(FSettingsManager.Data.CustomShortCuts);

    // Создаем репозитории
    SnippetRepo := TSnippetRepository.Create(DBConnection);
    CategoryRepo := TCategoryRepository.Create(DBConnection);
    TagRepo := TTagRepository.Create(DBConnection);
    UserRepo := TUserRepository.Create(DBConnection);

    // Создаем сервисы и внедряем в них репозитории
    FSnippetService := TSnippetService.Create(SnippetRepo, CategoryRepo, TagRepo, UserRepo);
    FCategoryService := TCategoryService.Create(CategoryRepo);
    FTagService := TTagService.Create(TagRepo);
    FUserService := TUserService.Create(UserRepo);

    HistoryRepo := TSnippetHistoryRepository.Create(DBConnection);
    FHistoryService := TSnippetHistoryService.Create(HistoryRepo, FSnippetService);

    FChainService := TChainService.Create(TChainRepository.Create(DBConnection), FSnippetService);

    // Локальные сервисы, создающиеся в AppContext
    FPasswordService := TPasswordService.Create;
    FEpochService := TEpochService.Create;
    FSecurityScanner := TSecurityScanner.Create;

    // Создаем сервис ИИ
    if Assigned(LocalAIFactory) then
        FLocalAIService := LocalAIFactory()
    else
        FLocalAIService := TLocalAIService.Create(nil);
end;

// ============================================================================
// СПЕЦИАЛЬНЫЙ КОНСТРУКТОР ДЛЯ ФОНОВЫХ ПОТОКОВ (СИНХРОНИЗАЦИИ)
// ============================================================================
constructor TAppContext.CreateBackground(DBConnection: TFDConnection; BaseContext: IAppContext);
var
    SnippetRepo: ISnippetRepository;
    CategoryRepo: ICategoryRepository;
    TagRepo: ITagRepository;
    UserRepo: IUserRepository;
    HistoryRepo: ISnippetHistoryRepository;
begin
    inherited Create;

    // 1. Берем безопасные глобальные синглтоны из базового (главного) контекста
    FDatabaseManager := BaseContext.DatabaseManager;
    FDBConnection := DBConnection;
    FSettingsManager := BaseContext.SettingsManager;
    FMessagesHandler := BaseContext.MessagesHandler;
    FSecurityScanner := BaseContext.SecurityScanner;

    // ВАЖНО: Оставляем nil, чтобы деструктор их не трогал и не сломал UI!
    FWindowHelper := nil;
    FHotkeyService := nil;

    // 2. Создаем ИЗОЛИРОВАННЫЕ репозитории с нашим фоновым коннектом
    SnippetRepo := TSnippetRepository.Create(DBConnection);
    CategoryRepo := TCategoryRepository.Create(DBConnection);
    TagRepo := TTagRepository.Create(DBConnection);
    UserRepo := TUserRepository.Create(DBConnection);

    // 3. Создаем ИЗОЛИРОВАННЫЕ сервисы
    FSnippetService := TSnippetService.Create(SnippetRepo, CategoryRepo, TagRepo, UserRepo);
    FCategoryService := TCategoryService.Create(CategoryRepo);
    FTagService := TTagService.Create(TagRepo);
    FUserService := TUserService.Create(UserRepo);

    HistoryRepo := TSnippetHistoryRepository.Create(DBConnection);
    FHistoryService := TSnippetHistoryService.Create(HistoryRepo, FSnippetService);

    FChainService := TChainService.Create(TChainRepository.Create(DBConnection), FSnippetService);

    FPasswordService := TPasswordService.Create;
    FEpochService := TEpochService.Create;

    // В фоновом контексте пробрасываем тот же сервис или оставляем nil,
    // если фоновые задачи не работают с ИИ напрямую
    FLocalAIService := BaseContext.LocalAIService;
end;

// ============================================================================
// ФАБРИКА ДЛЯ ФОНОВОЙ СИНХРОНИЗАЦИИ
// ============================================================================
function TAppContext.CreateIsolatedContext(out BackgroundConnection: TComponent): IAppContext;
var
    BgConnection: TFDConnection;
begin
    // 1. Создаем изолированное подключение к БД
    BgConnection := TFDConnection.Create(nil);
    BgConnection.Params.Text := FDatabaseManager.GetConnectionString;
    BgConnection.Connected := True;

    // Применяем настройки SQLite для многопоточности в фоне
    BgConnection.ExecSQL('PRAGMA foreign_keys = ON;');
    BgConnection.ExecSQL('PRAGMA journal_mode = WAL;');
    BgConnection.ExecSQL('PRAGMA busy_timeout = 5000;');

    // 2. Создаем чистый контекст через фоновый конструктор
    Result := TAppContext.CreateBackground(BgConnection, Self);

    // 3. Отдаем коннект наружу (его освободит блок finally в MainFormUI)
    BackgroundConnection := BgConnection;
end;

function TAppContext.CreateIsolatedSnippetService(out BackgroundConnection: TComponent): ISnippetService;
var
    BgConnection: TFDConnection;
    BgSnippetRepo: ISnippetRepository;
    BgCategoryRepo: ICategoryRepository;
    BgTagRepo: ITagRepository;
    BgUserRepo: IUserRepository;
begin
    BgConnection := TFDConnection.Create(nil);
    BgConnection.Params.Text := FDatabaseManager.GetConnectionString;
    BgConnection.Connected := True;

    BgSnippetRepo := TSnippetRepository.Create(BgConnection);
    BgCategoryRepo := TCategoryRepository.Create(BgConnection);
    BgTagRepo := TTagRepository.Create(BgConnection);
    BgUserRepo := TUserRepository.Create(BgConnection);
    Result := TSnippetService.Create(BgSnippetRepo, BgCategoryRepo, BgTagRepo, BgUserRepo);

    BackgroundConnection := BgConnection;
end;

function TAppContext.GetCategoryService: ICategoryService;
begin
    Result := FCategoryService;
end;

function TAppContext.GetDatabaseManager: IDatabaseManager;
begin
    Result := FDatabaseManager;
end;

function TAppContext.GetEpochService: IEpochService;
begin
    Result := FEpochService;
end;

function TAppContext.GetMessagesHandler: IUIMessagesHandler;
begin
    Result := FMessagesHandler;
end;

function TAppContext.GetHotkeyService: IHotkeyService;
begin
    Result := FHotkeyService;
end;

function TAppContext.GetLocalAIService: ILocalAIService;
begin
    Result := FLocalAIService;
end;

function TAppContext.GetPasswordService: IPasswordService;
begin
    Result := FPasswordService;
end;

function TAppContext.GetSettingsManager: ISettingsManager;
begin
    Result := FSettingsManager;
end;

function TAppContext.GetSnippetService: ISnippetService;
begin
    Result := FSnippetService;
end;

function TAppContext.GetTagService: ITagService;
begin
    Result := FTagService;
end;

function TAppContext.GetUserService: IUserService;
begin
    Result := FUserService;
end;

function TAppContext.GetWindowHelper: IWindowHelper;
begin
    Result := FWindowHelper;
end;

function TAppContext.GetSecurityScanner: ISecurityScanner;
begin
    Result := FSecurityScanner;
end;

function TAppContext.GetHistoryService: ISnippetHistoryService;
begin
    Result := FHistoryService;
end;

function TAppContext.GetChainService: IChainService;
begin
    Result := FChainService;
end;

function TAppContext.GetDBConnection: TFDConnection;
begin
    Result := FDBConnection;
end;

end.
