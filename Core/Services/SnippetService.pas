unit SnippetService;

interface

uses
    Core.Interfaces.Data, Core.Interfaces.Services,
    Core.Entities.Snippet,
    System.SysUtils
    ;

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
        function GetSnippetsByTags(const TagIDs: TArray<Integer>; MatchAll: Boolean = False): TArray<TSnippetDTO>;
        function GetTopSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;
        function GetRecentSnippets(UserID: Integer; Count: Integer): TArray<TSnippetDTO>;

        // Обновленный метод поиска с учетом пространства
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

implementation

uses
    Common.Localization,
    Common.QueryLanguage
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

function TSnippetService.GetSnippetsByTags(const TagIDs: TArray<Integer>; MatchAll: Boolean): TArray<TSnippetDTO>;
begin
    Result := FSnippetRepo.GetSnippetsByTags(TagIDs, MatchAll);
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
    Parsed: TStructuredQuery;
begin
    CleanQuery := Trim(Query);
    Result := [];

    if Length(CleanQuery) < 3 then
        Exit(Result);

    Parsed := TQueryLanguageParser.Parse(CleanQuery);
    if Parsed.IsEmpty then
        Exit(Result);

    if Parsed.HasStructuredFilters then
        Result := FSnippetRepo.SearchAdvanced(Parsed, UseFTS, UserID)
    else if UseFTS then
        Result := FSnippetRepo.SearchByMaskFTS(CleanQuery, UserID)
    else
        Result := FSnippetRepo.SearchByMaskSimple(CleanQuery, UserID);
end;

procedure TSnippetService.RecordRun(SnippetID, UserID: Integer);
begin
    FSnippetRepo.RecordRun(SnippetID, UserID);
end;

function TSnippetService.GetFavorites(UserID: Integer): TArray<TSnippetDTO>;
begin
    Result := FSnippetRepo.GetFavorites(UserID);
end;

function TSnippetService.IsFavorite(SnippetID, UserID: Integer): Boolean;
begin
    Result := FSnippetRepo.IsFavorite(SnippetID, UserID);
end;

procedure TSnippetService.AddFavorite(SnippetID, UserID: Integer);
begin
    if SnippetID <= 0 then raise ESnippetValidationException.Create(
        TUIStateLoader.GetMessage('Snippet.InvalidIdError')
    );
    FSnippetRepo.AddFavorite(SnippetID, UserID);
end;

procedure TSnippetService.RemoveFavorite(SnippetID, UserID: Integer);
begin
    if SnippetID <= 0 then raise ESnippetValidationException.Create(
        TUIStateLoader.GetMessage('Snippet.InvalidIdError')
    );
    FSnippetRepo.RemoveFavorite(SnippetID, UserID);
end;

procedure TSnippetService.MoveFavorite(SnippetID, UserID: Integer; Direction: TFavoriteMoveDirection);
var
    Order: TArray<Integer>;
    I, Idx, NewPos: Integer;
begin
    if SnippetID <= 0 then raise ESnippetValidationException.Create(
        TUIStateLoader.GetMessage('Snippet.InvalidIdError')
    );

    Order := FSnippetRepo.GetFavoriteOrder(UserID);

    Idx := -1;
    for I := 0 to High(Order) do
        if Order[I] = SnippetID then
        begin
            Idx := I;
            Break;
        end;

    if Idx < 0 then
        Exit;

    case Direction of
        fmTop:  NewPos := 0;
        fmUp:   NewPos := Idx - 1;
        fmDown: NewPos := Idx + 1;
        fmEnd:  NewPos := High(Order);
    else
        NewPos := Idx;
    end;

    FSnippetRepo.MoveFavorite(SnippetID, UserID, NewPos);
end;

function TSnippetService.GetLastRunSnippetID(UserID: Integer): Integer;
begin
    Result := FSnippetRepo.GetLastRunSnippetID(UserID);
end;

procedure TSnippetService.MoveFavoriteToPosition(SnippetID, UserID, NewPosition: Integer);
begin
    if SnippetID <= 0 then raise ESnippetValidationException.Create(
        TUIStateLoader.GetMessage('Snippet.InvalidIdError')
    );
    FSnippetRepo.MoveFavorite(SnippetID, UserID, NewPosition);
end;

end.
