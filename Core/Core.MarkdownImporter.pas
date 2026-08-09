unit Core.MarkdownImporter;

interface

uses
    Category,
    Core.Interfaces,
    Snippet,
    System.Classes,
    System.DateUtils,
    System.Generics.Collections,
    System.IOUtils,
    System.SysUtils,
    Tag,
    User
    ;

type
    // Временная структура парсинга одного .md файла
    TParsedMarkdown = record
        ID: Integer;
        Title: string;
        Comment: string;
        Content: string;
        Tags: TArray<string>;
        CreatedAt: Int64;
        UpdatedAt: Int64;
    end;

    TMarkdownImporter = class
    private
        class function ParseMarkdownFile(const FilePath: string; out Parsed: TParsedMarkdown): Boolean;
        class function ExtractTagsFromYaml(const TagsStr: string): TArray<string>;

        // Разрешает путь к категории: создает юзера и дерево категорий на основе папок на диске
        class function ResolveCategoryAndUserFromPath(
            const AppContext: IAppContext;
            const BaseDir, FilePath: string;
            UserCache: TDictionary<string, Integer>;
            CatCache: TDictionary<string, Integer>;
            out OutUserID, OutCategoryID: Integer): Boolean;
    public
        // Главный метод: сканирует папку и импортирует/обновляет все .md файлы в БД
        class procedure ImportFromDirectory(const AppContext: IAppContext; const BaseDir: string);
    end;

implementation

{ TMarkdownImporter }

class function TMarkdownImporter.ExtractTagsFromYaml(const TagsStr: string): TArray<string>;
var
    CleanStr, TagName: string;
    Parts: TArray<string>;
    ResultList: TList<string>;
begin
    ResultList := TList<string>.Create;
    try
        // Превращаем '["tag1", "tag2"]' в простую строку 'tag1, tag2'
        CleanStr := TagsStr.Replace('[', '').Replace(']', '').Replace('"', '').Replace('''', '');
        Parts := CleanStr.Split([',']);

        for TagName in Parts do
        begin
            if Trim(TagName) <> '' then
                ResultList.Add(Trim(TagName));
        end;
        Result := ResultList.ToArray;
    finally
        ResultList.Free;
    end;
end;

class function TMarkdownImporter.ParseMarkdownFile(const FilePath: string; out Parsed: TParsedMarkdown): Boolean;
var
    Lines: TArray<string>;
    Line, Key, Value, LowerLine: string;
    InFrontmatter, InCodeBlock: Boolean;
    YamlLines, BodyLines, CodeLines: TList<string>;
    I, FirstDashIdx, SecondDashIdx: Integer;
begin
    Result := False;
    Parsed := Default(TParsedMarkdown);

    if not TFile.Exists(FilePath) then Exit;

    Lines := TFile.ReadAllLines(FilePath, TEncoding.UTF8);
    if Length(Lines) = 0 then Exit;

    YamlLines := TList<string>.Create;
    BodyLines := TList<string>.Create;
    CodeLines := TList<string>.Create;
    try
        // ---------------------------------------------------------------------
        // 1. Извлекаем YAML Frontmatter (между первыми двумя '---')
        // ---------------------------------------------------------------------
        FirstDashIdx := -1;
        SecondDashIdx := -1;

        for I := 0 to High(Lines) do
        begin
            if Trim(Lines[I]) = '---' then
            begin
                if FirstDashIdx = -1 then
                    FirstDashIdx := I
                else if SecondDashIdx = -1 then
                begin
                    SecondDashIdx := I;
                    Break;
                end;
            end;
        end;

        if (FirstDashIdx <> -1) and (SecondDashIdx > FirstDashIdx) then
        begin
            for I := FirstDashIdx + 1 to SecondDashIdx - 1 do
                YamlLines.Add(Lines[I]);

            // Парсим ключи YAML
            for Line in YamlLines do
            begin
                var ColonIdx := Line.IndexOf(':');
                if ColonIdx > 0 then
                begin
                    Key := Trim(Line.Substring(0, ColonIdx)).ToLower;
                    Value := Trim(Line.Substring(ColonIdx + 1));
                    // Очищаем значение от кавычек
                    if (Value.StartsWith('"') and Value.EndsWith('"')) or
                       (Value.StartsWith('''') and Value.EndsWith('''')) then
                        Value := Value.Substring(1, Value.Length - 2);

                    if Key = 'id' then Parsed.ID := StrToIntDef(Value, 0)
                    else if Key = 'title' then Parsed.Title := Value
                    else if Key = 'tags' then Parsed.Tags := ExtractTagsFromYaml(Value)
                    else if Key = 'created_at' then Parsed.CreatedAt := StrToInt64Def(Value, DateTimeToUnix(Now))
                    else if Key = 'updated_at' then Parsed.UpdatedAt := StrToInt64Def(Value, DateTimeToUnix(Now));
                end;
            end;
        end;

        // ---------------------------------------------------------------------
        // 2. Парсим Тело (Комментарий и Блок Кода)
        // ---------------------------------------------------------------------
        var StartBodyIdx := 0;
        if SecondDashIdx <> -1 then
            StartBodyIdx := SecondDashIdx + 1;

        InCodeBlock := False;

        for I := StartBodyIdx to High(Lines) do
        begin
            Line := Lines[I];
            LowerLine := Trim(Line);

            if LowerLine.StartsWith('```') then
            begin
                InCodeBlock := not InCodeBlock;
                Continue; // Пропускаем сами строки с маркдауновскими ```
            end;

            if InCodeBlock then
                CodeLines.Add(Line)
            else
            begin
                // Игнорируем заголовок первого уровня `# Title`, если он совпадает с Title
                if LowerLine.StartsWith('# ') then Continue;
                BodyLines.Add(Line);
            end;
        end;

        Parsed.Comment := Trim(string.Join(sLineBreak, BodyLines.ToArray));
        Parsed.Content := string.Join(sLineBreak, CodeLines.ToArray);

        // Фоллбэк для заголовка: если в YAML не было title, берем имя файла
        if Parsed.Title = '' then
            Parsed.Title := TPath.GetFileNameWithoutExtension(FilePath);

        Result := True;
    finally
        YamlLines.Free;
        BodyLines.Free;
        CodeLines.Free;
    end;
end;

class function TMarkdownImporter.ResolveCategoryAndUserFromPath(
    const AppContext: IAppContext;
    const BaseDir, FilePath: string;
    UserCache: TDictionary<string, Integer>;
    CatCache: TDictionary<string, Integer>;
    out OutUserID, OutCategoryID: Integer): Boolean;
var
    RelPath, FolderPath: string;
    PathParts: TArray<string>;
    UserName, CatName, CatCacheKey: string;
    I, ParentCatID, CurrentCatID: Integer;
    NewUser: TUserDTO;
    NewCat: TCategoryDTO;
begin
    Result := False;
    OutUserID := 0;
    OutCategoryID := 0;

    FolderPath := TPath.GetDirectoryName(FilePath);
    RelPath := ExtractRelativePath(IncludeTrailingPathDelimiter(BaseDir), FolderPath);

    if (RelPath = '') or (RelPath = '.') then Exit;
    PathParts := RelPath.Split([TPath.DirectorySeparatorChar]);
    if Length(PathParts) = 0 then Exit;

    UserName := PathParts[0].ToLower; // Сравниваем в нижнем регистре для надежности

    // ИЩЕМ В КЭШЕ
    if not UserCache.TryGetValue(UserName, OutUserID) then
    begin
        // Если нет - создаем в БД и добавляем в кэш
        NewUser := Default(TUserDTO);
        NewUser.Name := PathParts[0]; // Оригинальный регистр
        OutUserID := AppContext.UserService.AddUser(NewUser);
        UserCache.Add(UserName, OutUserID);
    end;

    ParentCatID := 0;
    for I := 1 to High(PathParts) do
    begin
        CatName := PathParts[I];

        // Уникальный ключ для категории: "ИДЮзера_ИДРодителя_ИмяКатегории"
        CatCacheKey := Format('%d_%d_%s', [OutUserID, ParentCatID, CatName.ToLower]);

        // ИЩЕМ В КЭШЕ
        if not CatCache.TryGetValue(CatCacheKey, CurrentCatID) then
        begin
            NewCat := Default(TCategoryDTO);
            NewCat.Name := CatName;
            NewCat.ParentID := ParentCatID;
            NewCat.UserID := OutUserID;

            CurrentCatID := AppContext.CategoryService.CreateCategory(NewCat);
            CatCache.Add(CatCacheKey, CurrentCatID);
        end;

        ParentCatID := CurrentCatID;
    end;

    OutCategoryID := ParentCatID;
    Result := (OutUserID > 0) and (OutCategoryID > 0);
end;

class procedure TMarkdownImporter.ImportFromDirectory(const AppContext: IAppContext; const BaseDir: string);
var
    Files: TArray<string>;
    FilePath: string;
    Parsed: TParsedMarkdown;
    UserID, CategoryID: Integer;
    Snippet, ExistingSnippet: TSnippetDTO;
    TagIDs: TList<Integer>;
    TagName: string;
    TagID: Integer;

    UserCache: TDictionary<string, Integer>;
    CatCache: TDictionary<string, Integer>;
    Cat: TCategoryDTO;
    User: TUserDTO;
begin
    if not TDirectory.Exists(BaseDir) then Exit;

    UserCache := TDictionary<string, Integer>.Create;
    CatCache := TDictionary<string, Integer>.Create;
    try
        // === ПРЕДЗАГРУЗКА КЭША ===
        for User in AppContext.UserService.GetAllUsers do
            UserCache.Add(User.Name.ToLower, User.ID);

        for Cat in AppContext.CategoryService.GetAllCategories(0) do
            CatCache.Add(Format('%d_%d_%s', [Cat.UserID, Cat.ParentID, Cat.Name.ToLower]), Cat.ID);
        // =========================

        Files := TDirectory.GetFiles(BaseDir, '*.md', TSearchOption.soAllDirectories);

        for FilePath in Files do
        begin
            if not ParseMarkdownFile(FilePath, Parsed) then Continue;

            // Передаем кэш внутрь
            if not ResolveCategoryAndUserFromPath(AppContext, BaseDir, FilePath, UserCache, CatCache, UserID, CategoryID) then Continue;

            TagIDs := TList<Integer>.Create;
            try
                for TagName in Parsed.Tags do
                begin
                    TagID := AppContext.TagService.GetOrCreateTag(TagName);
                    if (TagID > 0) and not TagIDs.Contains(TagID) then TagIDs.Add(TagID);
                end;

                Snippet := Default(TSnippetDTO);
                Snippet.UserID := UserID;
                Snippet.CategoryID := CategoryID;
                Snippet.Title := Parsed.Title;
                Snippet.Comment := Parsed.Comment;
                Snippet.Content := Parsed.Content;
                Snippet.CreatedAt := Parsed.CreatedAt;
                Snippet.UpdatedAt := Parsed.UpdatedAt;

                ExistingSnippet := Default(TSnippetDTO);
                if Parsed.ID > 0 then
                    ExistingSnippet := AppContext.SnippetService.GetSnippetByID(Parsed.ID);

                if ExistingSnippet.ID > 0 then
                begin
                    Snippet.ID := ExistingSnippet.ID;
                    AppContext.SnippetService.UpdateSnippet(Snippet, TagIDs.ToArray);
                end
                else
                    AppContext.SnippetService.CreateSnippet(Snippet, TagIDs.ToArray);
            finally
                TagIDs.Free;
            end;
        end;
    finally
        UserCache.Free;
        CatCache.Free;
    end;
end;

end.
