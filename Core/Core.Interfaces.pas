unit Core.Interfaces;

interface

uses
    Snippet,
    Tag,
    Category,
    User
    ;

type
    // Репозитории
    ISnippetRepository = interface
        ['{DD06967A-A691-4AE5-B0E0-44595ABC6A34}']
        function Add(const Snippet: TSnippetDTO): NativeInt;
        procedure Update(const Snippet: TSnippetDTO);
        procedure Delete(SnippetID: NativeInt);
        procedure UpdateTags(SnippetID: NativeInt; const TagIDs: TArray<NativeInt>);
        function GetById(SnippetID: NativeInt): TSnippetDTO;
        function GetAll(UserID: NativeInt = 0): TArray<TSnippetDTO>;
        function GetSnippetByCategory(const CategoryID, UserID: NativeInt): TArray<TSnippetDTO>;
        function GetSnippetsByTag(const TagID: NativeInt): TArray<TSnippetDTO>;
        function GetTopSnippets(UserID: NativeInt; Count: NativeInt): TArray<TSnippetDTO>;
        function GetRecentSnippets(UserID: NativeInt; Count: NativeInt): TArray<TSnippetDTO>;
        function SearchByMaskFTS(const Mask: string; UserID: NativeInt = 0): TArray<TSnippetDTO>;
        function SearchByMaskSimple(const Mask: string; UserID: NativeInt = 0): TArray<TSnippetDTO>;
    end;

    ICategoryRepository = interface
        ['{BC294608-2FA0-4AE5-B163-7EA9F05435A8}']
        function GetAll(UserID: NativeInt = 0): TArray<TCategoryDTO>;
        function GetByID(ID: NativeInt): TCategoryDTO;
        function GetSnippetsByCategory(const CategoryID: NativeInt): TArray<TSnippetDTO>;
        procedure MoveCategory(ID, NewParentID, Position: NativeInt);
        procedure DeleteCategory(ID: NativeInt);
        function AddCategory(const Name: string; ParentID, UserID: NativeInt): NativeInt;
        procedure UpdateName(ID: NativeInt; const NewName: string);
        function GetUserID(ID: NativeInt): NativeInt;
        function ExistsInParent(const Name: string; ParentID, UserID: NativeInt): Boolean;
    end;

    ITagRepository = interface
        ['{F0C84D2F-4DD9-4863-BD73-AE91BDF65E6F}']
        function Add(const Tag: TTagDTO): NativeInt;
        procedure Update(const Tag: TTagDTO);
        procedure Delete(ID: NativeInt);

        function GetByID(ID: NativeInt): TTagDTO;
        function GetByName(const Name: string): TArray<TTagDTO>;
        function GetAll: TArray<TTagDTO>;

        function GetSnippetTags(SnippetID: NativeInt): TArray<TTagDTO>;
        procedure DeleteUnusedTags;

        function GetOrCreateTag(const TagName: string): NativeInt;
        procedure LinkTagToSnippet(SnippetID, TagID: NativeInt);
        procedure UnlinkTagFromSnippet(SnippetID, TagID: NativeInt);
        procedure ClearTagsForSnippet(SnippetID: NativeInt);

        procedure LinkTagsToSnippetBatch(SnippetID: NativeInt; const TagIDs: TArray<NativeInt>);
        function ExistsByName(const Name: string): Boolean;
    end;

    IUserRepository = interface
        ['{D4565779-919A-4287-B0A3-16273737BDC0}']
        function Add(const User: TUserDTO): NativeInt;
        procedure Update(const User: TUserDTO);
        procedure Delete(Id: NativeInt);
        function GetByID(Id: NativeInt): TUserDTO;
        function GetAll: TArray<TUserDTO>;
        function GetByName(const Name: string): TArray<TUserDTO>;
        function TryGetByID(ID: NativeInt; out User: TUserDTO): Boolean;
    end;

    // Сервисы
    ISnippetService = interface
        ['{A445FA2B-005B-4CEF-937C-C9A8413D46E6}']
        function CreateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<NativeInt>): NativeInt;
        procedure UpdateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<NativeInt>);
        procedure DeleteSnippet(const SnippetID: NativeInt);
        function GetSnippetByID(SnippetID: NativeInt): TSnippetDTO;
        function GetAllSnippets(UserID: NativeInt = 0): TArray<TSnippetDTO>;
        function GetSnippetsByCategory(CategoryID, UserID: NativeInt): TArray<TSnippetDTO>;
        function GetSnippetsByTag(TagID: NativeInt): TArray<TSnippetDTO>;
        function GetTopSnippets(UserID: NativeInt; Count: NativeInt): TArray<TSnippetDTO>;
        function GetRecentSnippets(UserID: NativeInt; Count: NativeInt): TArray<TSnippetDTO>;
        function SearchSnippets(const Query: string; UseFTS: Boolean; UserID: NativeInt = 0): TArray<TSnippetDTO>;
        function SearchSnippetsSimple(const Query: string; UserID: NativeInt): TArray<TSnippetDTO>;
        function SearchSnippetsFTS(const Query: string; UserID: NativeInt): TArray<TSnippetDTO>;
    end;

    ICategoryService = interface
        ['{21AA54F0-34CD-4D9F-B8EF-E755D067E682}']
        function GetAllCategories(UserID: NativeInt): TArray<TCategoryDTO>;
        function GetCategoryByID(ID: NativeInt): TCategoryDTO;
        function CreateCategory(const Category: TCategoryDTO): NativeInt;
        procedure RenameCategory(ID: NativeInt; const NewName: string);
        procedure DeleteCategory(ID: NativeInt);
        procedure MoveCategory(ID, NewParentID, Position: NativeInt);
    end;

    ITagService = interface
        ['{83E06A1E-D877-48B0-A0AC-B51140A4101A}']
        function GetAllTags: TArray<TTagDTO>;
        function GetSnippetTags(SnippetID: NativeInt): TArray<TTagDTO>;
        function CreateTag(const Name, Color: string): NativeInt;
        procedure RenameTag(ID: NativeInt; const NewName: string);
        procedure DeleteTag(ID: NativeInt);
    end;

    IUserService = interface
        ['{8CEF8F08-07F0-47EA-BCF9-450F87204747}']
        function GetAllUsers: TArray<TUserDTO>;
        function GetUserByID(UserID: NativeInt): TUserDTO;
        function AddUser(const User: TUserDTO): NativeInt;
        procedure UpdateUser(const User: TUserDTO);
        procedure DeleteUser(UserID: NativeInt);
    end;

    IDatabaseManager = interface
        ['{819F7354-9343-4C93-9F93-72782A021008}']
        procedure OpenDatabase(const Filename: string);
        procedure CreateDatabase(const Filename: string);
        procedure CloseDatabase;
        function IsConnected: Boolean;
    end;

    IUIErrorHandler = interface
        ['{0A3EC5A3-E39D-41C5-8661-42F22294031C}']
        procedure ShowError(const Message: string);
        procedure ShowInfo(const Message: string);
        procedure ShowWarning(const Message: string);
        function AskConfirmation(const Message: string): Boolean;
        function AskWarning(const Message: string): Boolean;
    end;

implementation

end.

