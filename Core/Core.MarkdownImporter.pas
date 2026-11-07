unit Core.MarkdownImporter;

interface

uses
    Common.Consts,
    Common.Localization,
    Common.SnippetLanguages,
    Core.Entities.Category,
    Core.Entities.Snippet,
    Core.Entities.Tag,
    Core.Entities.User,
    Core.Interfaces.App,
    Core.Interfaces.Services,
    FireDAC.Comp.Client,
    System.Classes,
    System.DateUtils,
    System.Generics.Collections,
    System.IOUtils,
    System.SysUtils
    ;

const
    MIN_IMPORT_UNIX_TS = 946684800;
    MAX_IMPORT_UNIX_TS = 4102444800;

    // Порог по абсолютному числу новых сниппетов для снапшота БД
    IMPORT_SNAPSHOT_NEW_LIMIT = 50;

type
    // Авария импорта: БД недоступна или транзакцию открыть не удалось.
    // Отсутствие исключения = импорт прошел успешно
    EMarkdownImportError = class(Exception);

    // Временная структура парсинга одного .md файла
    TParsedMarkdown = record
        ID: Integer;
        Title: string;
        Comment: string;
        Content: string;
        Tags: TArray<string>;
        Language: string;
        CreatedAt: Int64;
        UpdatedAt: Int64;
        HasKeeperMarker: Boolean;
    end;

    // Действие плана импорта для одного .md файла
    TMarkdownImportAction = (iaCreate, iaUpdate, iaSkipStale, iaSkipNoMarker);

    // Элемент плана, построенного в фазе A (только чтение БД)
    TMarkdownImportPlanItem = record
        FilePath: string;
        Parsed: TParsedMarkdown;
        Action: TMarkdownImportAction;
        ExistingID: Integer;
    end;

    // Итог импорта. Created/Updated инкрементируются в фазе B по факту
    // успешных записей; скип-счетчики заполняются в фазе A
    TMarkdownImportResult = record
        TotalFiles: Integer;
        Created: Integer;
        Updated: Integer;
        SkippedStale: Integer;
        SkippedNoMarker: Integer;
        SkippedOther: Integer;
        SnapshotFile: string;
    end;

    TMarkdownImporter = class
    private
        class function ParseMarkdownFile(const FilePath: string; out Parsed: TParsedMarkdown): Boolean;
        class function ExtractTagsFromYaml(const TagsStr: string): TArray<string>;

        // Дата обновления файла: из YAML, а при ее отсутствии - mtime файла (UTC)
        class function EffectiveUpdatedAt(const Parsed: TParsedMarkdown; const FilePath: string): Int64;
        // Снапшот БД нужен: много новых записей, >20% базы или первый синк
        class function SnapshotRequired(ANewCount, ATotalSnippets: Integer): Boolean;
        // Владелец, которого задаёт путь файла (только чтение, без создания)
        class function PathOwnerUserID(const BaseDir, FilePath: string;
            UserCache: TDictionary<string, Integer>): Integer;

        // Разрешает путь к категории: создает юзера и дерево категорий на основе папок на диске
        class function ResolveCategoryAndUserFromPath(
            const AppContext: IAppContext;
            const BaseDir, FilePath: string;
            UserCache: TDictionary<string, Integer>;
            CatCache: TDictionary<string, Integer>;
            out OutUserID, OutCategoryID: Integer): Boolean;
    public
        // Главный метод: сканирует папку и импортирует/обновляет все .md файлы в БД.
        // Фаза A строит план (чтение), затем по порогу риска берется снапшот БД,
        // фаза B применяет план в одной транзакции. Сбой транзакции/подключения -
        // исключение EMarkdownImportError, частичной записи не остается
        class function ImportFromDirectory(const AppContext: IAppContext; const BaseDir: string): TMarkdownImportResult;
    end;

implementation

{ TMarkdownImporter }

class function TMarkdownImporter.ExtractTagsFromYaml(const TagsStr: string): TArray<string>;
var
    CleanStr, TagName, T: string;
    Parts: TArray<string>;
    ResultList: TList<string>;
    I: Integer;
begin
    ResultList := TList<string>.Create;
    try
        // Превращаем '["tag1", "tag2"]' в простую строку 'tag1, tag2'
        CleanStr := TagsStr.Replace('[', '').Replace(']', '').Replace('"', '').Replace('''', '');
        Parts := CleanStr.Split([',']);

        for TagName in Parts do
        begin
            T := Trim(TagName);

            for I := Length(T) downto 1 do
                if T[I] < #32 then
                    Delete(T, I, 1);

            if (T = '') or (Length(T) > MAX_TAG_NAME_LENGTH) then
                Continue;

            if ResultList.Count >= MAX_SNIPPET_TAGS then
                Break;

            ResultList.Add(T);
        end;
        Result := ResultList.ToArray;
    finally
        ResultList.Free;
    end;
end;

class function TMarkdownImporter.ParseMarkdownFile(const FilePath: string; out Parsed: TParsedMarkdown): Boolean;
var
    Lines: TArray<string>;
    Line, Key, Value, LowerLine, FenceTag: string;
    InCodeBlock: Boolean;
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

                    if Key = 'id' then
                    begin
                        Parsed.ID := StrToIntDef(Value, 0);
                        if Parsed.ID < 0 then
                            Parsed.ID := 0;
                    end
                    else if Key = 'title' then Parsed.Title := Value
                    else if Key = 'generator' then Parsed.HasKeeperMarker := SameText(Value, 'SSHSnippetsKeeper')
                    else if Key = 'tags' then Parsed.Tags := ExtractTagsFromYaml(Value)
                    else if Key = 'language' then Parsed.Language := Value
                    else if Key = 'created_at' then
                    begin
                        Parsed.CreatedAt := StrToInt64Def(Value, DateTimeToUnix(Now));
                        if (Parsed.CreatedAt < MIN_IMPORT_UNIX_TS) or (Parsed.CreatedAt > MAX_IMPORT_UNIX_TS) then
                            Parsed.CreatedAt := DateTimeToUnix(Now);
                    end
                    else if Key = 'updated_at' then
                    begin
                        Parsed.UpdatedAt := StrToInt64Def(Value, DateTimeToUnix(Now));
                        if (Parsed.UpdatedAt < MIN_IMPORT_UNIX_TS) or (Parsed.UpdatedAt > MAX_IMPORT_UNIX_TS) then
                            Parsed.UpdatedAt := DateTimeToUnix(Now);
                    end;
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
        FenceTag := '';

        for I := StartBodyIdx to High(Lines) do
        begin
            Line := Lines[I];
            LowerLine := Trim(Line);

            if LowerLine.StartsWith('```') then
            begin
                // Тег ограждения ('```bash') - запасной источник языка
                if (not InCodeBlock) and (FenceTag = '') then
                    FenceTag := Trim(Copy(LowerLine, 4));
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

        // Язык: YAML или тег ограждения; неизвестные значения -> 'bash'
        if Parsed.Language = '' then
            Parsed.Language := FenceTag;
        Parsed.Language := NormalizeSnippetLanguage(Parsed.Language);

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
    RelPath, AbsBase, AbsDir: string;
    PathParts: TArray<string>;
    UserName, CatName, CatCacheKey: string;
    I, ParentCatID, CurrentCatID: Integer;
    NewUser: TUserDTO;
    NewCat: TCategoryDTO;
begin
    Result := False;
    OutUserID := 0;
    OutCategoryID := 0;

    AbsBase := IncludeTrailingPathDelimiter(TPath.GetFullPath(BaseDir));
    AbsDir := TPath.GetFullPath(TPath.GetDirectoryName(FilePath));

    if not AbsDir.StartsWith(AbsBase, True) then Exit;
    if SameText(AbsDir, ExcludeTrailingPathDelimiter(AbsBase)) then Exit;

    RelPath := AbsDir.Substring(Length(AbsBase));
    PathParts := RelPath.Split([TPath.DirectorySeparatorChar], TStringSplitOptions.ExcludeEmpty);
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

class function TMarkdownImporter.EffectiveUpdatedAt(const Parsed: TParsedMarkdown; const FilePath: string): Int64;
var
    Stamp: Int64;
begin
    if Parsed.UpdatedAt <> 0 then
        Exit(Parsed.UpdatedAt);

    // Ключа updated_at в YAML нет - ориентируемся на mtime файла (UTC)
    Stamp := DateTimeToUnix(TFile.GetLastWriteTimeUtc(FilePath));
    if (Stamp < MIN_IMPORT_UNIX_TS) or (Stamp > MAX_IMPORT_UNIX_TS) then
        Stamp := DateTimeToUnix(Now);
    Result := Stamp;
end;

class function TMarkdownImporter.SnapshotRequired(ANewCount, ATotalSnippets: Integer): Boolean;
begin
    // Риск массовой порчи: более 50 новых записей, более 20% базы
    // (5 * New > Total) или первый синк в пустую базу
    Result := (ANewCount > 0) and
        ((ANewCount > IMPORT_SNAPSHOT_NEW_LIMIT) or (5 * ANewCount > ATotalSnippets));
end;

class function TMarkdownImporter.PathOwnerUserID(const BaseDir, FilePath: string;
    UserCache: TDictionary<string, Integer>): Integer;
var
    RelPath, AbsBase, AbsDir: string;
    PathParts: TArray<string>;
begin
    Result := 0;

    AbsBase := IncludeTrailingPathDelimiter(TPath.GetFullPath(BaseDir));
    AbsDir := TPath.GetFullPath(TPath.GetDirectoryName(FilePath));

    if not AbsDir.StartsWith(AbsBase, True) then Exit;
    if SameText(AbsDir, ExcludeTrailingPathDelimiter(AbsBase)) then Exit;

    RelPath := AbsDir.Substring(Length(AbsBase));
    PathParts := RelPath.Split([TPath.DirectorySeparatorChar], TStringSplitOptions.ExcludeEmpty);
    if Length(PathParts) = 0 then Exit;

    // Пользователь может быть ещё не создан: тогда владельца нет
    if not UserCache.TryGetValue(PathParts[0].ToLower, Result) then
        Result := 0;
end;

class function TMarkdownImporter.ImportFromDirectory(const AppContext: IAppContext; const BaseDir: string): TMarkdownImportResult;
var
    FilePath: string;
    Parsed: TParsedMarkdown;
    UserID, CategoryID: Integer;
    Snippet, ExistingSnippet: TSnippetDTO;
    TagIDs: TList<Integer>;
    TagName: string;
    TagID: Integer;
    DBConn: TFDConnection;
    Item: TMarkdownImportPlanItem;
    Plan: TList<TMarkdownImportPlanItem>;
    NewCount: Integer;

    UserCache: TDictionary<string, Integer>;
    CatCache: TDictionary<string, Integer>;
    Cat: TCategoryDTO;
    User: TUserDTO;
    FileList: TList<string>;

    {$WARN SYMBOL_PLATFORM OFF}
    procedure CollectFiles(const ADir: string);
    var
        SubDirs, Found: TArray<string>;
        D, F: string;
        DirName: string;
        Attrs: TFileAttributes;
    begin
        SubDirs := TDirectory.GetDirectories(ADir, '*', TSearchOption.soTopDirectoryOnly);
        for D in SubDirs do
        begin
            DirName := ExtractFileName(ExcludeTrailingPathDelimiter(D));

            if DirName.StartsWith('.') or SameText(DirName, 'SSHSnippetsKeeper_Trash') then
                Continue;

            // TFile.GetAttributes для каталогов всегда падает (FileExists
            // игнорирует директории) - нужен именно TDirectory.GetAttributes
            try
                Attrs := TDirectory.GetAttributes(D);
            except
                Continue;
            end;

            if (TFileAttribute.faHidden in Attrs)
                or (TFileAttribute.faReparsePoint in Attrs)
                or (TFileAttribute.faSymLink in Attrs) then
                Continue;

            CollectFiles(D);
        end;

        Found := TDirectory.GetFiles(ADir, '*.md', TSearchOption.soTopDirectoryOnly);
        for F in Found do
            FileList.Add(F);
    end;
    {$WARN SYMBOL_PLATFORM ON}

begin
    Result := Default(TMarkdownImportResult);

    if not TDirectory.Exists(BaseDir) then Exit;

    DBConn := AppContext.DBConnection;

    // СЛОЙ 1: без рабочего подключения импорт невозможен - аварийное
    // завершение вместо тихого пропуска всего хранилища
    if not Assigned(DBConn) then
        raise EMarkdownImportError.Create(TUIStateLoader.GetMessage('Common.ImportNoConnection'));

    Plan := TList<TMarkdownImportPlanItem>.Create;
    UserCache := TDictionary<string, Integer>.Create;
    CatCache := TDictionary<string, Integer>.Create;
    FileList := TList<string>.Create;
    try
        AppContext.HistoryService.SetSuppressed(True);
        try
            // ================= ФАЗА A: скан и классификация (только чтение БД) =================
            for User in AppContext.UserService.GetAllUsers do
                UserCache.Add(User.Name.ToLower, User.ID);

            for Cat in AppContext.CategoryService.GetAllCategories(0) do
                CatCache.Add(Format('%d_%d_%s', [Cat.UserID, Cat.ParentID, Cat.Name.ToLower]), Cat.ID);

            CollectFiles(TPath.GetFullPath(BaseDir));
            Result.TotalFiles := FileList.Count;

            for FilePath in FileList do
            begin
                if not ParseMarkdownFile(FilePath, Parsed) then
                begin
                    Inc(Result.SkippedOther);
                    Continue;
                end;

                // Единая дата файла для сравнения и записи (mtime-фоллбэк)
                Parsed.UpdatedAt := EffectiveUpdatedAt(Parsed, FilePath);

                ExistingSnippet := Default(TSnippetDTO);
                if Parsed.ID > 0 then
                begin
                    ExistingSnippet := AppContext.SnippetService.GetSnippetByID(Parsed.ID);

                    // id в YAML - подсказка, а не право на запись: файл,
                    // скопированный из другого хранилища или подброшенный,
                    // не должен переписывать сниппет чужого пространства.
                    // Владелец берётся из пути и только читается
                    if (ExistingSnippet.ID > 0) and
                       (ExistingSnippet.UserID <> PathOwnerUserID(BaseDir, FilePath, UserCache)) then
                        ExistingSnippet := Default(TSnippetDTO);
                end;

                Item.FilePath := FilePath;
                Item.Parsed := Parsed;
                Item.ExistingID := ExistingSnippet.ID;

                if (ExistingSnippet.ID > 0) and (not Parsed.HasKeeperMarker) then
                begin
                    // Файл без нашего маркера не имеет права перетирать существующий сниппет
                    Item.Action := iaSkipNoMarker;
                    Inc(Result.SkippedNoMarker);
                end
                else if ExistingSnippet.ID > 0 then
                begin
                    // СЛОЙ 2: обновляем только если файл новее записи в БД
                    if Parsed.UpdatedAt > ExistingSnippet.UpdatedAt then
                        Item.Action := iaUpdate
                    else
                    begin
                        Item.Action := iaSkipStale;
                        Inc(Result.SkippedStale);
                    end;
                end
                else
                    Item.Action := iaCreate;

                Plan.Add(Item);
            end;

            // ================= СЛОЙ 3: снапшот БД по порогу риска =================
            NewCount := 0;
            for Item in Plan do
                if Item.Action = iaCreate then
                    Inc(NewCount);

            if SnapshotRequired(NewCount, Integer(DBConn.ExecSQLScalar('SELECT COUNT(*) FROM snippets'))) then
                Result.SnapshotFile := AppContext.DatabaseManager.CreateImportSnapshot;

            // ================= ФАЗА B: применение плана в одной транзакции =================
            // СЛОЙ 1: неудача открытия транзакции - аварийное завершение,
            // а не тихая запись мимо транзакции
            try
                DBConn.StartTransaction;
            except
                on E: Exception do
                    raise EMarkdownImportError.Create(
                        TUIStateLoader.GetMessage('Common.ImportTransactionStartError', [E.Message]));
            end;

            try
                for Item in Plan do
                begin
                    if Item.Action in [iaSkipStale, iaSkipNoMarker] then
                        Continue;

                    // Создание юзеров/категорий отложено сюда: фаза A не пишет в БД
                    if not ResolveCategoryAndUserFromPath(AppContext, BaseDir, Item.FilePath, UserCache, CatCache, UserID, CategoryID) then
                    begin
                        Inc(Result.SkippedOther);
                        Continue;
                    end;

                    TagIDs := TList<Integer>.Create;
                    try
                        for TagName in Item.Parsed.Tags do
                        begin
                            TagID := AppContext.TagService.GetOrCreateTag(TagName);
                            if (TagID > 0) and not TagIDs.Contains(TagID) then TagIDs.Add(TagID);
                        end;

                        Snippet := Default(TSnippetDTO);
                        Snippet.UserID := UserID;
                        Snippet.CategoryID := CategoryID;
                        Snippet.Title := Item.Parsed.Title;
                        Snippet.Comment := Item.Parsed.Comment;
                        Snippet.Content := Item.Parsed.Content;
                        Snippet.Language := Item.Parsed.Language;
                        Snippet.CreatedAt := Item.Parsed.CreatedAt;
                        Snippet.UpdatedAt := Item.Parsed.UpdatedAt;

                        if Item.Action = iaUpdate then
                        begin
                            Snippet.ID := Item.ExistingID;
                            AppContext.SnippetService.UpdateSnippet(Snippet, TagIDs.ToArray);
                            Inc(Result.Updated);
                        end
                        else
                        begin
                            AppContext.SnippetService.CreateSnippet(Snippet, TagIDs.ToArray);
                            Inc(Result.Created);
                        end;
                    finally
                        TagIDs.Free;
                    end;
                end;

                DBConn.Commit;
            except
                if DBConn.InTransaction then
                    DBConn.Rollback;
                raise;
            end;
        finally
            AppContext.HistoryService.SetSuppressed(False);
        end;
    finally
        Plan.Free;
        FileList.Free;
        UserCache.Free;
        CatCache.Free;
    end;
end;

end.
