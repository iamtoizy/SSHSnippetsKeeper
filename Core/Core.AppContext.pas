unit Core.AppContext;

interface

uses
    Core.Interfaces,
    SnippetRepository,
    CategoryRepository,
    TagRepository,
    UserRepository,
    SnippetService,
    CategoryService,
    TagService,
    UserService,
    PasswordService,
    FireDAC.Comp.Client,
    System.Classes;

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

        function GetDatabaseManager: IDatabaseManager;
        function GetSnippetService: ISnippetService;
        function GetCategoryService: ICategoryService;
        function GetTagService: ITagService;
        function GetUserService: IUserService;
        function GetPasswordService: IPasswordService;
        function GetSettingsManager: ISettingsManager;
        function GetWindowHelper: IWindowHelper;
    public
        // В конструктор передаем уже готовые сервисы
        constructor Create(
            DatabaseManager: IDatabaseManager;
            DBConnection: TFDConnection;
            SettingsManager: ISettingsManager;
            WindowHelper: IWindowHelper
        );
        destructor Destroy; override;
        property DatabaseManager: IDatabaseManager read GetDatabaseManager;
        property SnippetService: ISnippetService read GetSnippetService;
        property CategoryService: ICategoryService read GetCategoryService;
        property TagService: ITagService read GetTagService;
        property UserService: IUserService read GetUserService;
        property PasswordService: IPasswordService read GetPasswordService;
        property SettingsManager: ISettingsManager read GetSettingsManager;
        property WindowHelper: IWindowHelper read GetWindowHelper;

        function CreateIsolatedSnippetService(out BackgroundConnection: TComponent): ISnippetService;
    end;

implementation

{ TAppContext }

constructor TAppContext.Create(
    DatabaseManager: IDatabaseManager;
    DBConnection: TFDConnection;
    SettingsManager: ISettingsManager;
    WindowHelper: IWindowHelper
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

    // 1. Создаем репозитории
    SnippetRepo := TSnippetRepository.Create(DBConnection);
    CategoryRepo := TCategoryRepository.Create(DBConnection);
    TagRepo := TTagRepository.Create(DBConnection);
    UserRepo := TUserRepository.Create(DBConnection);

    // 2. Создаем сервисы и ВНЕДРЯЕМ в них репозитории
    FSnippetService := TSnippetService.Create(SnippetRepo, CategoryRepo, TagRepo, UserRepo);

    FCategoryService := TCategoryService.Create(CategoryRepo);
    FTagService := TTagService.Create(TagRepo);
    FUserService := TUserService.Create(UserRepo);

    FPasswordService := TPasswordService.Create;
end;

function TAppContext.CreateIsolatedSnippetService(out BackgroundConnection: TComponent): ISnippetService;
var
    BgConnection: TFDConnection;
    BgSnippetRepo: ISnippetRepository;
    BgCategoryRepo: ICategoryRepository;
    BgTagRepo: ITagRepository;
    BgUserRepo: IUserRepository;
begin
    // 1. Создаем изолированный коннект
    BgConnection := TFDConnection.Create(nil);

    // Копируем параметры из основного подключения (предполагается, что у тебя есть доступ к FDatabaseManager)
    BgConnection.Params.Text := FDatabaseManager.GetConnectionString;
    BgConnection.Connected := True;

    // 2. Собираем матрешку зависимостей (Внедрение зависимостей)
    BgSnippetRepo := TSnippetRepository.Create(BgConnection);
    BgCategoryRepo := TCategoryRepository.Create(BgConnection);
    BgTagRepo := TTagRepository.Create(BgConnection);
    BgUserRepo := TUserRepository.Create(BgConnection);
    Result := TSnippetService.Create(BgSnippetRepo, BgCategoryRepo, BgTagRepo, BgUserRepo);

    // 3. Отдаем коннект наружу под видом базового TComponent,
    // чтобы TTask в форме мог вызвать ему .Free после завершения
    BackgroundConnection := BgConnection;
end;

destructor TAppContext.Destroy;
var
    ObjToFree: TObject;
begin
    if Assigned(FWindowHelper) then
    begin
        // Прячем ссылку на объект в обычную (не интерфейсную) переменную
        ObjToFree := FWindowHelper as TObject;

        // Обнуляем интерфейс. Компилятор безопасно вызовет _Release,
        // пока объект еще жив (метод вернет -1, всё отлично)
        FWindowHelper := nil;

        // Теперь безопасно стираем объект из памяти
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
