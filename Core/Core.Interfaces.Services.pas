unit Core.Interfaces.Services;

interface

uses
    Core.Entities.Category,
    Core.Entities.Chain,
    Core.Entities.Snippet,
    Core.Entities.Tag,
    Core.Entities.User,
    Core.Interfaces.Settings,
    System.Classes
    ;

type
    // Направление перемещения внутри избранного
    TFavoriteMoveDirection = (fmTop, fmUp, fmDown, fmEnd);

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
        function GetSnippetsByTags(const TagIDs: TArray<Integer>; MatchAll: Boolean = False): TArray<TSnippetDTO>;
        function GetTopSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;
        function GetRecentSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;
        function SearchSnippets(const Query: string; UseFTS: Boolean; UserID: Integer = 0): TArray<TSnippetDTO>;
        procedure RecordRun(SnippetID, UserID: Integer);
        function GetFavorites(UserID: Integer): TArray<TSnippetDTO>;
        function IsFavorite(SnippetID, UserID: Integer): Boolean;
        procedure AddFavorite(SnippetID, UserID: Integer);
        procedure RemoveFavorite(SnippetID, UserID: Integer);
        procedure MoveFavorite(SnippetID, UserID: Integer; Direction: TFavoriteMoveDirection);
        procedure MoveFavoriteToPosition(SnippetID, UserID, NewPosition: Integer);
        function GetLastRunSnippetID(UserID: Integer): Integer;
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
        function CreateTag(const Name: string): Integer;
        procedure RenameTag(ID: Integer; const NewName: string);
        procedure DeleteTag(ID: Integer);
        // Создание тега при его отсутствии
        function GetOrCreateTag(const Name: string): Integer;
    end;

    ISnippetHistoryService = interface
        ['{E84A2C61-9B3D-4A57-8F12-6C90D4E7B2A5}']
        function GetVersions(SnippetID: Integer; Limit: Integer = 0): TArray<TSnippetVersionDTO>;
        function GetVersion(VersionID: Integer): TSnippetVersionDTO;
        function GetVersionCount(SnippetID: Integer): Integer;
        procedure RestoreVersion(SnippetID, VersionID: Integer);
        procedure Prune(SnippetID: Integer);
        procedure SetSuppressed(Suppressed: Boolean);
    end;

    IUserService = interface
        ['{8CEF8F08-07F0-47EA-BCF9-450F87204747}']
        function GetAllUsers: TArray<TUserDTO>;
        function GetUserByID(UserID: Integer): TUserDTO;
        function AddUser(const User: TUserDTO): Integer;
        procedure UpdateUser(const User: TUserDTO);
        procedure DeleteUser(UserID: Integer);
    end;

    IChainService = interface
        ['{C91D4E07-6B2F-4D58-9E3A-F07D82C4A619}']
        function GetAllChains(UserID: Integer): TArray<TChainDTO>;
        function GetChainByID(ID: Integer): TChainDTO;
        function CreateChain(UserID: Integer; const Name: string): Integer;
        procedure RenameChain(ID: Integer; const NewName: string);
        procedure DeleteChain(ID: Integer);
        function GetSteps(ChainID: Integer): TArray<TChainStepDTO>;
        procedure SaveSteps(ChainID: Integer; const Steps: TArray<TChainStepDTO>);
    end;

    // Описывает одно настраиваемое действие
    TActionHotkeyInfo = record
        ActionName: string;         // Уникальное имя (например, 'actSaveSnippet')
        DisplayName: string;        // Текст для UI ('Сохранить сниппет')
        Category: string;           // Группа ('Редактор сниппетов')
        DefaultShortCut: TShortCut; // Дефолтный шорткат (например, Ctrl+S)
        CurrentShortCut: TShortCut; // Текущий шорткат
    end;

    // Интерфейс сервиса горячих клавиш
    IHotkeyService = interface
        ['{7E54069A-5120-4B86-AC03-156435B99686}']
        function GetAllActions: TArray<TActionHotkeyInfo>;
        function GetActionShortCut(const ActionName: string): TShortCut;
        procedure SetActionShortCut(const ActionName: string; NewShortCut: TShortCut);

        // Проверка на конфликты
        function IsShortCutInUse(const ActionID: string; ShortCut: TShortCut; out ConflictingActionName: string): Boolean;

        // Синхронизация с настройками и формами
        procedure ApplySettingsToForm(const Form: TComponent);
        procedure LoadFromSettings(const CustomShortCuts: TArray<TCustomShortCut>);
        function SaveToSettings: TArray<TCustomShortCut>;
    end;

implementation

end.
