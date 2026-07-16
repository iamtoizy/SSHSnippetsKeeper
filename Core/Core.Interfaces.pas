unit Core.Interfaces;

interface

uses
    Snippet,
    Tag,
    Category,
    User,
    System.Classes,
    ArrayHelper,
    MacroInputTypes,
    Winapi.Windows;

type
    // Domain Models настроек
    TWindowsNode = record
        Name: string;
        WinClass: string;
    end;

    TWindowHelperNode = record
        ActivationDelay: Integer;
        SetFocusDelay: Integer;
        KeyPressInterval: Integer;
    end;

    TAllowedApplicationsItem = record
        ExeName: string;
        Enabled: Boolean;
    end;

    TAIParams = record
        Temperature: Single;
        MaxOutputTokens: Integer;
        Content: string;
        ReasoningEffort: string;
    end;

    TAIItem = record
        Name: string;
        APIKey: string;
        Folder: string;
        Model: string;
        Agent: string;
        Params: TAIParams;
    end;

    TAIHub = record
        Name: string;
        URL: string;
        Comment: string;
        Items: TArrayRecord<TAIItem>;
    end;

    TAppSettings = record // Можно переименовать в TAppSettings, чтобы отвязаться от слова JSON
        AllowedWindows: TArrayRecord<TWindowsNode>;
        WindowHelper: TWindowHelperNode;
        AllowedApplications: TArrayRecord<TAllowedApplicationsItem>;
        AISettings: TArrayRecord<TAIHub>;
    end;

    // Интерфейс менеджера
    ISettingsManager = interface
        ['{A1B2C3D4-E5F6-47A8-9B0C-1D2E3F4A5B6C}']
        function GetSettings: TAppSettings;
        procedure SetSettings(const Value: TAppSettings);
        function GetBashAutocomplete: TStringList;

        procedure Load;
        procedure Save;

        property Data: TAppSettings read GetSettings write SetSettings;
        property BashAutocomplete: TStringList read GetBashAutocomplete;
    end;

    // Репозитории
    ISnippetRepository = interface
        ['{DD06967A-A691-4AE5-B0E0-44595ABC6A34}']
        function Add(const Snippet: TSnippetDTO): Integer;
        procedure Update(const Snippet: TSnippetDTO);
        procedure Delete(SnippetID: Integer);
        procedure UpdateTags(SnippetID: Integer; const TagIDs: TArray<Integer>);
        function GetById(SnippetID: Integer): TSnippetDTO;
        function GetAll(UserID: Integer = 0): TArray<TSnippetDTO>;
        function GetSnippetByCategory(const CategoryID, UserID: Integer): TArray<TSnippetDTO>;
        function GetSnippetsByTag(const TagID: Integer): TArray<TSnippetDTO>;
        function GetTopSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;
        function GetRecentSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;
        function SearchByMaskFTS(const Mask: string; UserID: Integer = 0): TArray<TSnippetDTO>;
        function SearchByMaskSimple(const Mask: string; UserID: Integer = 0): TArray<TSnippetDTO>;
    end;

    ICategoryRepository = interface
        ['{BC294608-2FA0-4AE5-B163-7EA9F05435A8}']
        function GetAll(UserID: Integer = 0): TArray<TCategoryDTO>;
        function GetByID(ID: Integer): TCategoryDTO;
        function GetSnippetsByCategory(const CategoryID: Integer): TArray<TSnippetDTO>;
        procedure MoveCategory(ID, NewParentID, Position: Integer);
        procedure DeleteCategory(ID: Integer);
        function AddCategory(const Name: string; ParentID, UserID: Integer): Integer;
        procedure UpdateName(ID: Integer; const NewName: string);
        function GetUserID(ID: Integer): Integer;
        function ExistsInParent(const Name: string; ParentID, UserID: Integer): Boolean;
    end;

    ITagRepository = interface
        ['{F0C84D2F-4DD9-4863-BD73-AE91BDF65E6F}']
        function Add(const Tag: TTagDTO): Integer;
        procedure Update(const Tag: TTagDTO);
        procedure Delete(ID: Integer);

        function GetByID(ID: Integer): TTagDTO;
        function GetByName(const Name: string): TArray<TTagDTO>;
        function GetAll: TArray<TTagDTO>;

        function GetSnippetTags(SnippetID: Integer): TArray<TTagDTO>;
        procedure DeleteUnusedTags;

        function GetOrCreateTag(const TagName: string): Integer;
        procedure LinkTagToSnippet(SnippetID, TagID: Integer);
        procedure UnlinkTagFromSnippet(SnippetID, TagID: Integer);
        procedure ClearTagsForSnippet(SnippetID: Integer);

        procedure LinkTagsToSnippetBatch(SnippetID: Integer; const TagIDs: TArray<Integer>);
        function ExistsByName(const Name: string): Boolean;
    end;

    IUserRepository = interface
        ['{D4565779-919A-4287-B0A3-16273737BDC0}']
        function Add(const User: TUserDTO): Integer;
        procedure Update(const User: TUserDTO);
        procedure Delete(Id: Integer);
        function GetByID(Id: Integer): TUserDTO;
        function GetAll: TArray<TUserDTO>;
        function GetByName(const Name: string): TArray<TUserDTO>;
        function TryGetByID(ID: Integer; out User: TUserDTO): Boolean;
    end;

    // Сервисы
    ISnippetService = interface
        ['{A445FA2B-005B-4CEF-937C-C9A8413D46E6}']
        function CreateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<Integer>): Integer;
        procedure UpdateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<Integer>);
        procedure DeleteSnippet(const SnippetID: Integer);
        function GetSnippetByID(SnippetID: Integer): TSnippetDTO;
        function GetAllSnippets(UserID: Integer = 0): TArray<TSnippetDTO>;
        function GetSnippetsByCategory(CategoryID, UserID: Integer): TArray<TSnippetDTO>;
        function GetSnippetsByTag(TagID: Integer): TArray<TSnippetDTO>;
        function GetTopSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;
        function GetRecentSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;
        function SearchSnippets(const Query: string; UseFTS: Boolean; UserID: Integer = 0): TArray<TSnippetDTO>;
        function SearchSnippetsSimple(const Query: string; UserID: Integer): TArray<TSnippetDTO>;
        function SearchSnippetsFTS(const Query: string; UserID: Integer): TArray<TSnippetDTO>;
    end;

    ICategoryService = interface
        ['{21AA54F0-34CD-4D9F-B8EF-E755D067E682}']
        function GetAllCategories(UserID: Integer): TArray<TCategoryDTO>;
        function GetCategoryByID(ID: Integer): TCategoryDTO;
        function CreateCategory(const Category: TCategoryDTO): Integer;
        procedure RenameCategory(ID: Integer; const NewName: string);
        procedure DeleteCategory(ID: Integer);
        procedure MoveCategory(ID, NewParentID, Position: Integer);
    end;

    ITagService = interface
        ['{83E06A1E-D877-48B0-A0AC-B51140A4101A}']
        function GetAllTags: TArray<TTagDTO>;
        function GetSnippetTags(SnippetID: Integer): TArray<TTagDTO>;
        function CreateTag(const Name, Color: string): Integer;
        procedure RenameTag(ID: Integer; const NewName: string);
        procedure DeleteTag(ID: Integer);
    end;

    IUserService = interface
        ['{8CEF8F08-07F0-47EA-BCF9-450F87204747}']
        function GetAllUsers: TArray<TUserDTO>;
        function GetUserByID(UserID: Integer): TUserDTO;
        function AddUser(const User: TUserDTO): Integer;
        procedure UpdateUser(const User: TUserDTO);
        procedure DeleteUser(UserID: Integer);
    end;

    IDatabaseManager = interface
        ['{819F7354-9343-4C93-9F93-72782A021008}']
        procedure OpenDatabase(const Filename: string);
        procedure CreateDatabase(const Filename: string);
        procedure CloseDatabase;
        function IsConnected: Boolean;
        function GetConnectionString: string;
    end;

    IUIErrorHandler = interface
        ['{0A3EC5A3-E39D-41C5-8661-42F22294031C}']
        procedure ShowError(const Message: string);
        procedure ShowInfo(const Message: string);
        procedure ShowWarning(const Message: string);
        function AskConfirmation(const Message: string): Boolean;
        function AskWarning(const Message: string): Boolean;
    end;

    TPasswordPreset = (
        // Базовые
        wpStrictAlphaNumeric, // Только a-z, A-Z, 0-9
        wpPinCode,            // Только цифры (для пин-кодов и простых локов)
        wpHexToken,           // Шестнадцатеричный токен (a-f, 0-9) - для WPA, ключей шифрования

        // Инфраструктурные
        wpBashSafe,           // Безопасно для терминала (без $, !, `, кавычек, слешей)
        wpDockerEnvSafe,      // Безопасно для .env (без #, =, пробелов, кавычек, не с дефиса)
        wpUrlSafe,            // Безопасно для URL (без &, ?, =, %, /, +, пробелов)

        // Специфичные для БД / Систем
        wpBitrixDb,           // Буквы, цифры, и строго определенные знаки (!?()@#$-+=_)
        wpOracleSafe,         // Специфика Oracle: ДОЛЖЕН начинаться с буквы, только _ $ #
        wpActiveDirectory,    // Строго удовлетворяет сложности AD (мин 1 заглавная, 1 строчная, 1 цифра, 1 спец)

        // Человекочитаемые
        wpNoLookAlikes,       // Без похожих символов: (I, l, 1, O, 0) - чтобы диктовать по телефону / читать с экрана

        // НОВЫЕ ШАБЛОНЫ
        wpMacAddress,         // MAC-адрес (XX:XX:XX:XX:XX:XX)
        wpUUIDv4,             // UUID v4
        wpBase64Key,          // Base64 Ключ
        wpWebStandard,        // Стандартный пароль для сайтов (A-Z, a-z, 0-9, !@#$%*?)
        wpCustom              // Кастомный режим (KeePass-like)
    );

    // Настройки для кастомного режима
    TCustomPasswordSettings = record
        UseLower: Boolean;
        UseUpper: Boolean;
        UseNumbers: Boolean;
        UseSymbols: Boolean;
        IncludeChars: string; // Символы, которые ОБЯЗАТЕЛЬНО должны быть в пароле
        ExcludeChars: string; // Символы, которых точно НЕ ДОЛЖНО быть
    end;

    // DTO для истории генераций
    TPasswordHistoryItem = record
        Password: string;
        PresetName: string;
        Entropy: Double;
        CreatedAt: TDateTime;
    end;
    IPasswordService = interface
        ['{C5F1AD9B-21B6-4B42-9267-6C2FF69DA6B6}']
        // Генерирует пароль по выбранному шаблону. Принимает флаг UniqueChars
        function GeneratePassword(Preset: TPasswordPreset; Length: Integer; UniqueChars: Boolean): string;
        function GetPresetDescription(Preset: TPasswordPreset): string;
        function GetPoolSize(Preset: TPasswordPreset): Integer;
        // Расчет размера пула для кастомного режима
        function GetCustomPoolSize(const Settings: TCustomPasswordSettings): Integer;
        function CalculateEntropy(Length, PoolSize: Integer): Double;
        // Методы для истории
        procedure AddToHistory(const Password: string; Preset: TPasswordPreset; PassLen: Integer);
        function GetHistory: TArray<TPasswordHistoryItem>;
        procedure ClearHistory;
        // Генерация по кастомным правилам
        function GenerateCustomPassword(const Settings: TCustomPasswordSettings; Length: Integer; UniqueChars: Boolean): string;
        // Перегруженный метод для истории, чтобы он принимал строку описания напрямую
        procedure AddToHistoryCustom(const Password, CustomDescription: string; PassLen: Integer; Entropy: Double);
    end;

    TWindowHelperInfo = record
        Handle: HWND;
        Parent: HWND;
        ClassName: string;
        ParentClassName: string;
        WindowText: string;
    end;

    IWindowHelper = interface(ITextExecutor)
        ['{9A6E6337-0CD6-4F38-948C-C2AFB36471F2}']
        function GetWindowUnderCursor: Boolean;
        procedure TypeTextIntoWindow(const Text: string);
        procedure TypeTextIntoWindowWithContext(const Text: string; Context: TMacroContext);
        procedure SetTargetWindow(Handle: HWND);
        function GetWindowInfo: TWindowHelperInfo;
    end;

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
        // Фабрика для фоновых потоков. Возвращает готовый сервис и ссылку на коннект для его очистки.
        function CreateIsolatedSnippetService(out ABackgroundConnection: TComponent): ISnippetService;

        property DatabaseManager: IDatabaseManager read GetDatabaseManager;
        property SnippetService: ISnippetService read GetSnippetService;
        property CategoryService: ICategoryService read GetCategoryService;
        property TagService: ITagService read GetTagService;
        property UserService: IUserService read GetUserService;
        property PasswordService: IPasswordService read GetPasswordService;
        property SettingsManager: ISettingsManager read GetSettingsManager;
        property WindowHelper: IWindowHelper read GetWindowHelper;
    end;

implementation

end.

