unit Core.Interfaces.Data;

interface

uses
    Core.Entities.Category,
    Core.Entities.Snippet,
    Core.Entities.Tag,
    Core.Entities.User
    ;

type
    IDatabaseManager = interface
        ['{819F7354-9343-4C93-9F93-72782A021008}']
        procedure OpenDatabase(const Filename: string);
        procedure CreateDatabase(const Filename: string);
        procedure CloseDatabase;
        function IsConnected: Boolean;
        function GetConnectionString: string;
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
        function GetSnippetsByTags(const TagIDs: TArray<Integer>; MatchAll: Boolean = False): TArray<TSnippetDTO>;
        function GetTopSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;
        function GetRecentSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;
        function SearchByMaskFTS(const Mask: string; UserID: Integer = 0): TArray<TSnippetDTO>;
        function SearchByMaskSimple(const Mask: string; UserID: Integer = 0): TArray<TSnippetDTO>;
        procedure RecordRun(SnippetID, UserID: Integer);
        function GetFavorites(UserID: Integer): TArray<TSnippetDTO>;
        function GetFavoriteOrder(UserID: Integer): TArray<Integer>;
        function IsFavorite(SnippetID, UserID: Integer): Boolean;
        procedure AddFavorite(SnippetID, UserID: Integer);
        procedure RemoveFavorite(SnippetID, UserID: Integer);
        procedure MoveFavorite(SnippetID, UserID, NewPosition: Integer);
        function GetLastRunSnippetID(UserID: Integer): Integer;
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

implementation

end.
