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
        function SearchSnippetsSimple(const Query: string; UserID: Integer): TArray<TSnippetDTO>;
        function SearchSnippetsFTS(const Query: string; UserID: Integer): TArray<TSnippetDTO>;
    public
        constructor Create(
            ASnippetRepo: ISnippetRepository;
            ACategoryRepo: ICategoryRepository;
            ATagRepo: ITagRepository;
            AUserRepo: IUserRepository);

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

{ TSnippetService }

constructor TSnippetService.Create(
    ASnippetRepo: ISnippetRepository;
    ACategoryRepo: ICategoryRepository;
    ATagRepo: ITagRepository;
    AUserRepo: IUserRepository);
begin
    inherited Create;
    FSnippetRepo := ASnippetRepo;
    FCategoryRepo := ACategoryRepo;
    FTagRepo := ATagRepo;
    FUserRepo := AUserRepo;
end;

function TSnippetService.CreateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<Integer>): Integer;
var
    CatUserID: Integer;
begin
    if Snippet.UserID <= 0 then raise ESnippetValidationException.Create('Некорректный UserID');
    if Snippet.CategoryID <= 0 then raise ESnippetValidationException.Create('Некорректный CategoryID');

    CatUserID := FCategoryRepo.GetUserID(Snippet.CategoryID);
    if CatUserID = -1 then raise ESnippetValidationException.Create('Категория не найдена');

    if CatUserID <> Snippet.UserID then
        raise EAccessDeniedException.Create('Ошибка доступа: Категория принадлежит другому пользователю');

    Result := FSnippetRepo.Add(Snippet);
    if Length(TagIDs) > 0 then
        FSnippetRepo.UpdateTags(Result, TagIDs);
end;

procedure TSnippetService.UpdateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<Integer>);
var
    CatUserID: Integer;
begin
    if Snippet.ID <= 0 then raise ESnippetValidationException.Create('Некорректный ID сниппета');

    CatUserID := FCategoryRepo.GetUserID(Snippet.CategoryID);
    if CatUserID <> Snippet.UserID then
        raise EAccessDeniedException.Create('Ошибка доступа: Вы не можете переместить сниппет в чужую категорию');

    FSnippetRepo.Update(Snippet);
    FSnippetRepo.UpdateTags(Snippet.ID, TagIDs);
end;

procedure TSnippetService.DeleteSnippet(const SnippetID: Integer);
begin
    if SnippetID <= 0 then raise ESnippetValidationException.Create('Некорректный ID для удаления');
    FSnippetRepo.Delete(SnippetID);
end;

function TSnippetService.GetSnippetByID(SnippetID: Integer): TSnippetDTO;
begin
    if SnippetID <= 0 then raise ESnippetValidationException.Create('Некорректный ID сниппета');
    Result := FSnippetRepo.GetById(SnippetID);
end;

function TSnippetService.GetAllSnippets(UserID: Integer = 0): TArray<TSnippetDTO>;
begin
    Result := FSnippetRepo.GetAll(UserID);
end;

function TSnippetService.GetSnippetsByCategory(CategoryID, UserID: Integer): TArray<TSnippetDTO>;
begin
    if CategoryID <= 0 then raise ESnippetValidationException.Create('Некорректный ID категории');
    Result := FSnippetRepo.GetSnippetByCategory(CategoryID, UserID);
end;

function TSnippetService.GetSnippetsByTag(TagID: Integer): TArray<TSnippetDTO>;
begin
    if TagID <= 0 then raise ESnippetValidationException.Create('Некорректный ID тега');
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

function TSnippetService.SearchSnippetsSimple(const Query: string; UserID: Integer): TArray<TSnippetDTO>;
begin
    if Trim(Query) = '' then Exit(GetAllSnippets(UserID));
    Result := FSnippetRepo.SearchByMaskSimple(Query, UserID);
end;

function TSnippetService.SearchSnippetsFTS(const Query: string; UserID: Integer): TArray<TSnippetDTO>;
begin
    if Trim(Query) = '' then Exit(GetAllSnippets(UserID));
    Result := FSnippetRepo.SearchByMaskFTS(Query, UserID);
end;

function TSnippetService.SearchSnippets(const Query: string; UseFTS: Boolean; UserID: Integer = 0): TArray<TSnippetDTO>;
var
    CleanQuery: string;
begin
    CleanQuery := Trim(Query);

    if Length(CleanQuery) < 3 then
        Exit(GetAllSnippets(UserID));

    if UseFTS then
        Result := FSnippetRepo.SearchByMaskFTS(CleanQuery, UserID)
    else
        Result := FSnippetRepo.SearchByMaskSimple(CleanQuery, UserID);
end;

end.
