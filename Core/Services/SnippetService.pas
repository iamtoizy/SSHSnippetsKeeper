unit SnippetService;

interface

uses
    System.SysUtils,
    Snippet,
    Core.Interfaces;

type
    // Доменные исключения
    ESnippetValidationException = class(Exception);
    EAccessDeniedException = class(Exception);

    TSnippetService = class(TInterfacedObject, ISnippetService)
    private
        const TOP_SNIPPETS_COUNT = 20;
        const RECENT_SNIPPETS_COUNT = 20;
    private
        FSnippetRepo: ISnippetRepository;
        FCategoryRepo: ICategoryRepository;
        FTagRepo: ITagRepository;
        FUserRepo: IUserRepository;
    public
        constructor Create(
            SnippetRepo: ISnippetRepository;
            CategoryRepo: ICategoryRepository;
            TagRepo: ITagRepository;
            UserRepo: IUserRepository
        );

        function CreateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<Integer>): Integer;
        procedure UpdateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<Integer>);
        procedure DeleteSnippet(const SnippetID: Integer);

        // Методы для UI
        function GetSnippetByID(SnippetID: Integer): TSnippetDTO;
        function GetAllSnippets(UserID: Integer = 0): TArray<TSnippetDTO>;
        function GetSnippetsByCategory(CategoryID, UserID: Integer): TArray<TSnippetDTO>;
        function GetSnippetsByTag(TagID: Integer): TArray<TSnippetDTO>;
        function GetTopSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;
        function GetRecentSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;

        // Обновленный метод поиска с учетом пространства
        function SearchSnippets(const Query: string; UseFTS: Boolean; UserID: Integer = 0): TArray<TSnippetDTO>;
    end;

implementation

uses
    UI.StateLoader
    ;

{ TSnippetService }

constructor TSnippetService.Create(
    SnippetRepo: ISnippetRepository;
    CategoryRepo: ICategoryRepository;
    TagRepo: ITagRepository;
    UserRepo: IUserRepository
);
begin
    inherited Create;
    FSnippetRepo := SnippetRepo;
    FCategoryRepo := CategoryRepo;
    FTagRepo := TagRepo;
    FUserRepo := UserRepo;
end;

function TSnippetService.CreateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<Integer>): Integer;
var
    CatUserID: Integer;
begin
    if Snippet.UserID <= 0 then
        raise ESnippetValidationException.Create(
            TUIStateLoader.GetMessage('User.InvalidIdError')
        );
    if Snippet.CategoryID <= 0 then
        raise ESnippetValidationException.Create(
            TUIStateLoader.GetMessage('Category.InvalidIdError')
        );

    CatUserID := FCategoryRepo.GetUserID(Snippet.CategoryID);
    if CatUserID = -1 then raise ESnippetValidationException.Create(
        TUIStateLoader.GetMessage('Category.CategoryNotFound')
    );

    if CatUserID <> Snippet.UserID then
        raise EAccessDeniedException.Create(
            TUIStateLoader.GetMessage('Category.AccessDenied')
        );

    Result := FSnippetRepo.Add(Snippet);
    if Length(TagIDs) > 0 then
        FSnippetRepo.UpdateTags(Result, TagIDs);
end;

procedure TSnippetService.UpdateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<Integer>);
var
    CatUserID: Integer;
begin
    if Snippet.ID <= 0 then raise ESnippetValidationException.Create(
        TUIStateLoader.GetMessage('Snippet.InvalidIdError')
    );

    CatUserID := FCategoryRepo.GetUserID(Snippet.CategoryID);
    if CatUserID <> Snippet.UserID then
        raise EAccessDeniedException.Create(
            TUIStateLoader.GetMessage('Category.AccessDenied')
        );

    FSnippetRepo.Update(Snippet);
    FSnippetRepo.UpdateTags(Snippet.ID, TagIDs);
end;

procedure TSnippetService.DeleteSnippet(const SnippetID: Integer);
begin
    if SnippetID <= 0 then raise ESnippetValidationException.Create(
        TUIStateLoader.GetMessage('Snippet.InvalidIdError')
    );
    FSnippetRepo.Delete(SnippetID);
end;

function TSnippetService.GetSnippetByID(SnippetID: Integer): TSnippetDTO;
begin
    if SnippetID <= 0 then raise ESnippetValidationException.Create(
        TUIStateLoader.GetMessage('Snippet.InvalidIdError')
    );
    Result := FSnippetRepo.GetById(SnippetID);
end;

function TSnippetService.GetAllSnippets(UserID: Integer = 0): TArray<TSnippetDTO>;
begin
    Result := FSnippetRepo.GetAll(UserID);
end;

function TSnippetService.GetSnippetsByCategory(CategoryID, UserID: Integer): TArray<TSnippetDTO>;
begin
    if CategoryID <= 0 then raise ESnippetValidationException.Create(
        TUIStateLoader.GetMessage('Category.InvalidIdError')
    );
    Result := FSnippetRepo.GetSnippetByCategory(CategoryID, UserID);
end;

function TSnippetService.GetSnippetsByTag(TagID: Integer): TArray<TSnippetDTO>;
begin
    if TagID <= 0 then raise ESnippetValidationException.Create(
        TUIStateLoader.GetMessage('Tag.InvalidIdError')
    );
    Result := FSnippetRepo.GetSnippetsByTag(TagID);
end;

function TSnippetService.GetTopSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;
begin
    if Count <= 0 then Count := TOP_SNIPPETS_COUNT;
    Result := FSnippetRepo.GetTopSnippets(UserID, Count);
end;

function TSnippetService.GetRecentSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;
begin
    if Count <= 0 then Count := RECENT_SNIPPETS_COUNT;
    Result := FSnippetRepo.GetRecentSnippets(UserID, Count);
end;

function TSnippetService.SearchSnippets(const Query: string; UseFTS: Boolean; UserID: Integer = 0): TArray<TSnippetDTO>;
var
    CleanQuery: string;
begin
    CleanQuery := Trim(Query);
    Result := [];

    if Length(CleanQuery) < 3 then
    begin
//        Exit(GetAllSnippets(UserID));
        Exit(Result);
    end;

    if UseFTS then
        Result := FSnippetRepo.SearchByMaskFTS(CleanQuery, UserID)
    else
        Result := FSnippetRepo.SearchByMaskSimple(CleanQuery, UserID);
end;

end.
