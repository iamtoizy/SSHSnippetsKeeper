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
    FireDAC.Comp.Client;

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

        function GetDatabaseManager: IDatabaseManager;
        function GetSnippetService: ISnippetService;
        function GetCategoryService: ICategoryService;
        function GetTagService: ITagService;
        function GetUserService: IUserService;
        function GetPasswordService: IPasswordService;
        function GetSettingsManager: ISettingsManager;
    public
        // ¬ конструктор передаем уже готовые сервисы
        constructor Create(
            DatabaseManager: IDatabaseManager;
            DBConnection: TFDConnection;
            SettingsManager: ISettingsManager
        );
        property DatabaseManager: IDatabaseManager read GetDatabaseManager;
        property SnippetService: ISnippetService read GetSnippetService;
        property CategoryService: ICategoryService read GetCategoryService;
        property TagService: ITagService read GetTagService;
        property UserService: IUserService read GetUserService;
        property PasswordService: IPasswordService read GetPasswordService;
        property SettingsManager: ISettingsManager read GetSettingsManager;
    end;

implementation

{ TAppContext }

constructor TAppContext.Create(
    DatabaseManager: IDatabaseManager;
    DBConnection: TFDConnection;
    SettingsManager: ISettingsManager
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

    // 1. —оздаем репозитории
    SnippetRepo := TSnippetRepository.Create(DBConnection);
    CategoryRepo := TCategoryRepository.Create(DBConnection);
    TagRepo := TTagRepository.Create(DBConnection);
    UserRepo := TUserRepository.Create(DBConnection);

    // 2. —оздаем сервисы и ¬Ќ≈ƒ–я≈ћ в них репозитории
    FSnippetService := TSnippetService.Create(SnippetRepo, CategoryRepo, TagRepo, UserRepo);

    FCategoryService := TCategoryService.Create(CategoryRepo);
    FTagService := TTagService.Create(TagRepo);
    FUserService := TUserService.Create(UserRepo);

    FPasswordService := TPasswordService.Create;
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

end.
