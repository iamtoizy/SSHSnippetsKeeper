unit Core.AppContext;

interface

uses
    CategoryRepository,
    CategoryService,
    Core.Interfaces,
    EpochService,
    FireDAC.Comp.Client,
    HotkeyService,
    PasswordService,
    SnippetRepository,
    SnippetService,
    System.Classes,
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

        function GetDatabaseManager: IDatabaseManager;
        function GetSnippetService: ISnippetService;
        function GetCategoryService: ICategoryService;
        function GetTagService: ITagService;
        function GetUserService: IUserService;
        function GetPasswordService: IPasswordService;
        function GetSettingsManager: ISettingsManager;
        function GetWindowHelper: IWindowHelper;
        function GetErrorHandler: IUIMessagesHandler;
        function GetEpochService: IEpochService;
        function GetHotkeyService: IHotkeyService;
    public
        // Основной конструктор (для UI-потока)
        constructor Create(
            DatabaseManager: IDatabaseManager;
            DBConnection: TFDConnection;
            SettingsManager: ISettingsManager;
            WindowHelper: IWindowHelper;
            MessagesHandler: IUIMessagesHandler
        );

        // ВТОРОЙ КОНСТРУКТОР: Для безопасных фоновых задач (TTask)
        constructor CreateBackground(DBConnection: TFDConnection; BaseContext: IAppContext);

        destructor Destroy; override;
        property DatabaseManager: IDatabaseManager read GetDatabaseManager;
        property SnippetService: ISnippetService read GetSnippetService;
        property CategoryService: ICategoryService read GetCategoryService;
        property TagService: ITagService read GetTagService;
        property UserService: IUserService read GetUserService;
        property PasswordService: IPasswordService read GetPasswordService;
        property SettingsManager: ISettingsManager read GetSettingsManager;
        property WindowHelper: IWindowHelper read GetWindowHelper;
        property MessagesHandler: IUIMessagesHandler read GetErrorHandler;
        property EpochService: IEpochService read GetEpochService;
        property HotkeyService: IHotkeyService read GetHotkeyService;

        function CreateIsolatedSnippetService(out BackgroundConnection: TComponent): ISnippetService;

        // Новая фабрика для полной изоляции при синхронизации
        function CreateIsolatedContext(out BackgroundConnection: TComponent): IAppContext;
    end;

implementation

{ TAppContext }

constructor TAppContext.Create(
    DatabaseManager: IDatabaseManager;
    DBConnection: TFDConnection;
    SettingsManager: ISettingsManager;
    WindowHelper: IWindowHelper;
    MessagesHandler: IUIMessagesHandler
);
var
    SnippetRepo: ISnippetRepository;
    CategoryRepo: ICategoryRepository;
    TagRepo: ITagRepository;
    UserRepo: IUserRepository;
begin
    inherited Create;

    FDatabaseManager := DatabaseManager;
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

    // Локальные сервисы, создающиеся в AppContext
    FPasswordService := TPasswordService.Create;
    FEpochService := TEpochService.Create;
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
begin
    inherited Create;

    // 1. Берем безопасные глобальные синглтоны из базового (главного) контекста
    FDatabaseManager := BaseContext.DatabaseManager;
    FSettingsManager := BaseContext.SettingsManager;
    FMessagesHandler := BaseContext.MessagesHandler;

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

    FPasswordService := TPasswordService.Create;
    FEpochService := TEpochService.Create;
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

destructor TAppContext.Destroy;
var
    ObjToFree: TObject;
begin
    // Защита: если контекст фоновый, FWindowHelper = nil,
    // и объект главного потока не будет уничтожен
    if Assigned(FWindowHelper) then
    begin
        ObjToFree := FWindowHelper as TObject;
        FWindowHelper := nil;
        ObjToFree.Free;
    end;

    inherited Destroy;
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

function TAppContext.GetErrorHandler: IUIMessagesHandler;
begin
    Result := FMessagesHandler;
end;

function TAppContext.GetHotkeyService: IHotkeyService;
begin
    Result := FHotkeyService;
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

end.
