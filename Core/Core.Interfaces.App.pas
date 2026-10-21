unit Core.Interfaces.App;

interface

uses
    Core.Interfaces.Automation,
    Core.Interfaces.Data,
    Core.Interfaces.Passwords,
    Core.Interfaces.Services,
    Core.Interfaces.Settings,
    Core.Interfaces.Tools,
    Core.Interfaces.UI,
    FireDAC.Comp.Client,
    SecurityScanner,
    System.Classes
    ;

type
    // Контейнер всех глобальных сервисов приложения
    IAppContext = interface
        ['{05B6A3A0-F265-4DF3-85A1-BF260B30957F}']
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

        // Фабрика для фоновых потоков. Возвращает готовый сервис и ссылку на коннект для его очистки.
        function CreateIsolatedSnippetService(out BackgroundConnection: TComponent): ISnippetService;
        // Создает полностью независимую копию контекста со своим подключением к БД
        function CreateIsolatedContext(out BackgroundConnection: TComponent): IAppContext;

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
    end;

implementation

end.
