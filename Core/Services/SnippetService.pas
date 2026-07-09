unit SnippetService;

interface

uses
    System.SysUtils,
    Snippet,
    Tag,
    SnippetRepository,
    CategoryRepository,
    TagRepository;

type
    TSnippetService = class
    private
        FSnippetRepo: TSnippetRepository;
        FCategoryRepo: TCategoryRepository;
        FTagRepo: TTagRepository; // Оставлен для обратной совместимости сигнатуры конструктора
    public
        constructor Create(ASnippetRepo: TSnippetRepository; ACategoryRepo: TCategoryRepository; ATagRepo: TTagRepository);

        function CreateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<NativeInt>): NativeInt;
        procedure UpdateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<NativeInt>);
        procedure DeleteSnippet(const SnippetID: NativeInt);

        // Методы для UI
        function GetSnippetByID(SnippetID: NativeInt): TSnippetDTO;
        function GetAllSnippets: TArray<TSnippetDTO>;
        function GetSnippetsByCategory(CategoryID, UserID: NativeInt): TArray<TSnippetDTO>;
        function GetSnippetsByTag(TagID: NativeInt): TArray<TSnippetDTO>;
        function GetTopSnippets(UserID: NativeInt; Count: Integer): TArray<TSnippetDTO>;
        function GetRecentSnippets(UserID: NativeInt; Count: Integer): TArray<TSnippetDTO>;
        function SearchSnippetsSimple(const Query: string): TArray<TSnippetDTO>;
        function SearchSnippetsFTS(const Query: string): TArray<TSnippetDTO>;
    end;

implementation

{ TSnippetService }

constructor TSnippetService.Create(ASnippetRepo: TSnippetRepository; ACategoryRepo: TCategoryRepository; ATagRepo: TTagRepository);
begin
    FSnippetRepo := ASnippetRepo;
    FCategoryRepo := ACategoryRepo;
    FTagRepo := ATagRepo;
end;

function TSnippetService.CreateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<NativeInt>): NativeInt;
var
    CatUserID: NativeInt;
begin
    if Snippet.UserID <= 0 then raise Exception.Create('Некорректный UserID');
    if Snippet.CategoryID <= 0 then raise Exception.Create('Некорректный CategoryID');

    // Проверка прав доступа (Бизнес-правило)
    CatUserID := FCategoryRepo.GetUserID(Snippet.CategoryID);
    if CatUserID = -1 then raise Exception.Create('Категория не найдена');
    if CatUserID <> Snippet.UserID then raise Exception.Create('Ошибка доступа: Категория принадлежит другому пользователю');

    Result := FSnippetRepo.Add(Snippet);
    if Length(TagIDs) > 0 then
        FSnippetRepo.UpdateTags(Result, TagIDs); // Используем готовый метод репозитория
end;

procedure TSnippetService.UpdateSnippet(const Snippet: TSnippetDTO; const TagIDs: TArray<NativeInt>);
var
    CatUserID: NativeInt;
begin
    if Snippet.ID <= 0 then raise Exception.Create('Некорректный ID сниппета');

    CatUserID := FCategoryRepo.GetUserID(Snippet.CategoryID);
    if CatUserID <> Snippet.UserID then raise Exception.Create('Ошибка доступа: Вы не можете переместить сниппет в чужую категорию');

    FSnippetRepo.Update(Snippet);
    FSnippetRepo.UpdateTags(Snippet.ID, TagIDs); // Полная перепривязка тегов
end;

procedure TSnippetService.DeleteSnippet(const SnippetID: NativeInt);
begin
    if SnippetID <= 0 then raise Exception.Create('Некорректный ID для удаления');

    // Каскадное удаление (snippet_tags и т.д.) уже настроено в БД через триггеры/ON DELETE CASCADE
    // Поэтому предварительная ручная очистка тегов больше не требуется.
    FSnippetRepo.Delete(SnippetID);
end;

function TSnippetService.GetSnippetByID(SnippetID: NativeInt): TSnippetDTO;
begin
    if SnippetID <= 0 then raise Exception.Create('Некорректный ID сниппета');
    Result := FSnippetRepo.GetById(SnippetID); // В репозитории называется GetById
end;

function TSnippetService.GetAllSnippets: TArray<TSnippetDTO>;
begin
    Result := FSnippetRepo.GetAll;
end;

function TSnippetService.GetSnippetsByCategory(CategoryID, UserID: NativeInt): TArray<TSnippetDTO>;
begin
    if CategoryID <= 0 then raise Exception.Create('Некорректный ID категории');
    Result := FSnippetRepo.GetSnippetByCategory(CategoryID, UserID);
end;

function TSnippetService.GetSnippetsByTag(TagID: NativeInt): TArray<TSnippetDTO>;
begin
    if TagID <= 0 then raise Exception.Create('Некорректный ID тега');
    Result := FSnippetRepo.GetSnippetsByTag(TagID);
end;

function TSnippetService.GetTopSnippets(UserID: NativeInt; Count: Integer): TArray<TSnippetDTO>;
begin
    if Count <= 0 then Count := 10;
    Result := FSnippetRepo.GetTopSnippets(UserID, Count);
end;

function TSnippetService.GetRecentSnippets(UserID: NativeInt; Count: Integer): TArray<TSnippetDTO>;
begin
    if Count <= 0 then Count := 10;
    Result := FSnippetRepo.GetRecentSnippets(UserID, Count);
end;

function TSnippetService.SearchSnippetsSimple(const Query: string): TArray<TSnippetDTO>;
begin
    if Trim(Query) = '' then Exit(GetAllSnippets);
    Result := FSnippetRepo.SearchByMaskSimple(Query);
end;

function TSnippetService.SearchSnippetsFTS(const Query: string): TArray<TSnippetDTO>;
begin
    if Trim(Query) = '' then Exit(GetAllSnippets);
    Result := FSnippetRepo.SearchByMaskFTS(Query);
end;

end.
