unit BundleExchange;

interface

uses
    Core.Entities.Category,
    Core.Entities.Snippet,
    Core.Interfaces.App,
    System.Classes,
    System.DateUtils,
    System.IOUtils,
    System.JSON,
    System.SysUtils
    ;

type
    TBundleImportResult = record
        Imported: Integer;
        Skipped: Integer;
        CreatedCategories: Integer;
    end;

    TBundleExchange = class
    public
        const FORMAT_ID = 'ssk-bundle';
        const FORMAT_VERSION = 1;
    private
        class function BuildCategoryPath(const AppContext: IAppContext;
            CategoryID: Integer): string;
    public
        class function ExportBundle(const AppContext: IAppContext;
            const AFileName: string;
            const ASnippets: TArray<TSnippetDTO>): Integer;
        class function ImportBundle(const AppContext: IAppContext;
            const AFileName: string;
            AUserID: Integer): TBundleImportResult;
    end;

implementation

uses
    Common.Localization,
    System.Generics.Collections
    ;

{ TBundleExchange }

class function TBundleExchange.BuildCategoryPath(const AppContext: IAppContext;
    CategoryID: Integer): string;
var
    Parts: TStringList;
    Cat: TCategoryDTO;
    Depth, I: Integer;
begin
    Result := '';
    if CategoryID <= 0 then
        Exit;

    Parts := TStringList.Create;
    try
        Depth := 0;
        while (CategoryID > 0) and (Depth < 32) do
        begin
            Cat := AppContext.CategoryService.GetCategoryByID(CategoryID);
            if Cat.ID <= 0 then
                Break;
            Parts.Insert(0, Cat.Name);
            CategoryID := Cat.ParentID;
            Inc(Depth);
        end;
        for I := 0 to Parts.Count - 1 do
        begin
            if Result <> '' then
                Result := Result + '/';
            Result := Result + Parts[I];
        end;
    finally
        Parts.Free;
    end;
end;

class function TBundleExchange.ExportBundle(const AppContext: IAppContext;
    const AFileName: string; const ASnippets: TArray<TSnippetDTO>): Integer;
var
    Root: TJSONObject;
    SnipsArr, CatsArr, TagsArr: TJSONArray;
    Cats: TStringList;
    I, J: Integer;
    SnipObj: TJSONObject;
    Path: string;
begin
    Result := Length(ASnippets);
    Root := TJSONObject.Create;
    try
        // Массивы сразу передаются под владение Root: исключение в цикле
        // (например, ошибка БД в BuildCategoryPath) не оставит их висеть
        SnipsArr := TJSONArray.Create;
        Root.AddPair('snippets', SnipsArr);
        CatsArr := TJSONArray.Create;
        Root.AddPair('categories', CatsArr);

        Cats := TStringList.Create;
        try
            Cats.Sorted := True;
            Cats.Duplicates := dupIgnore;
            for I := 0 to High(ASnippets) do
            begin
                Path := BuildCategoryPath(AppContext, ASnippets[I].CategoryID);
                if Path <> '' then
                    Cats.Add(Path);
                SnipObj := TJSONObject.Create;
                SnipsArr.AddElement(SnipObj);
                SnipObj.AddPair('title', ASnippets[I].Title);
                SnipObj.AddPair('content', ASnippets[I].Content);
                SnipObj.AddPair('comment', ASnippets[I].Comment);
                SnipObj.AddPair('language', ASnippets[I].Language);
                SnipObj.AddPair('languageLocked', TJSONBool.Create(ASnippets[I].LanguageLocked));
                SnipObj.AddPair('securityCheckIgnored', TJSONBool.Create(ASnippets[I].IsSecurityCheckIgnored));
                SnipObj.AddPair('createdAt', TJSONNumber.Create(ASnippets[I].CreatedAt));
                SnipObj.AddPair('updatedAt', TJSONNumber.Create(ASnippets[I].UpdatedAt));
                SnipObj.AddPair('category', Path);
                TagsArr := TJSONArray.Create;
                SnipObj.AddPair('tags', TagsArr);
                for J := 0 to High(ASnippets[I].Tags) do
                    TagsArr.Add(ASnippets[I].Tags[J].Name);
            end;
            for I := 0 to Cats.Count - 1 do
                CatsArr.Add(Cats[I]);

            Root.AddPair('format', FORMAT_ID);
            Root.AddPair('version', TJSONNumber.Create(FORMAT_VERSION));
            Root.AddPair('generator', 'SSHSnippetsKeeper');
            Root.AddPair('exportedAt', TJSONNumber.Create(DateTimeToUnix(Now)));
            TFile.WriteAllText(AFileName, Root.ToString, TEncoding.UTF8);
        finally
            Cats.Free;
        end;
    finally
        Root.Free;
    end;
end;

class function TBundleExchange.ImportBundle(const AppContext: IAppContext;
    const AFileName: string; AUserID: Integer): TBundleImportResult;
var
    Raw: string;
    Parsed: TJSONValue;
    Obj: TJSONObject;
    SnipsArr, TagsArr: TJSONArray;
    I, J, Ver, CatIdx: Integer;
    SnipObj: TJSONObject;
    Snip: TSnippetDTO;
    TagIDs: TList<Integer>;
    TagID: Integer;
    CatMap, ExistingKeys: TStringList;
    ExistingCats: TArray<TCategoryDTO>;
    Existing: TArray<TSnippetDTO>;
    Key: string;
    Res: TBundleImportResult;

    function EnsureCategory(const APath: string): Integer;
    var
        Segments: TStringList;
        SoFar, Seg: string;
        NewCat: TCategoryDTO;
        CatID: Integer;
        K: Integer;
    begin
        Result := 0;
        if Trim(APath) = '' then
            Exit;

        CatIdx := CatMap.IndexOf(APath);
        if CatIdx >= 0 then
        begin
            Result := Integer(CatMap.Objects[CatIdx]);
            Exit;
        end;

        Segments := TStringList.Create;
        try
            Segments.StrictDelimiter := True;
            Segments.Delimiter := '/';
            Segments.DelimitedText := APath;
            SoFar := '';
            for K := 0 to Segments.Count - 1 do
            begin
                Seg := Trim(Segments[K]);
                if Seg = '' then
                    Continue;
                if SoFar = '' then
                    SoFar := Seg
                else
                    SoFar := SoFar + '/' + Seg;
                CatIdx := CatMap.IndexOf(SoFar);
                if CatIdx >= 0 then
                    Result := Integer(CatMap.Objects[CatIdx])
                else
                begin
                    NewCat := Default(TCategoryDTO);
                    NewCat.UserID := AUserID;
                    NewCat.Name := Seg;
                    NewCat.ParentID := Result;
                    CatID := AppContext.CategoryService.CreateCategory(NewCat);
                    if CatID > 0 then
                    begin
                        Inc(Res.CreatedCategories);
                        CatMap.AddObject(SoFar, TObject(CatID));
                        Result := CatID;
                    end
                    else
                        Result := 0;
                end;
            end;
        finally
            Segments.Free;
        end;
    end;

begin
    Result := Default(TBundleImportResult);
    if not TFile.Exists(AFileName) then
        raise Exception.Create(TUIStateLoader.GetMessage('Bundle.FileNotFound',
            [AFileName]));

    Raw := TFile.ReadAllText(AFileName, TEncoding.UTF8);
    Parsed := TJSONObject.ParseJSONValue(Raw);
    if not (Parsed is TJSONObject) then
        raise Exception.Create(TUIStateLoader.GetMessage('Bundle.InvalidJSON'));
    try
        Obj := TJSONObject(Parsed);
        if Obj.GetValue<string>('format', '') <> FORMAT_ID then
            raise Exception.Create(TUIStateLoader.GetMessage('Bundle.InvalidFormat'));
        Ver := Obj.GetValue<Integer>('version', 0);
        if Ver > FORMAT_VERSION then
            raise Exception.Create(TUIStateLoader.GetMessage('Bundle.VersionTooNew',
                [Ver, FORMAT_VERSION]));
        if not Obj.TryGetValue<TJSONArray>('snippets', SnipsArr) then
            raise Exception.Create(TUIStateLoader.GetMessage('Bundle.InvalidFormat'));

        Res := Default(TBundleImportResult);
        CatMap := TStringList.Create;
        TagIDs := TList<Integer>.Create;
        ExistingKeys := TStringList.Create;
        try
            // Индекс в БД регистронезависимый (COLLATE NOCASE):
            // иначе 'work' из бандла при существующей 'Work' даёт сбой UNIQUE
            CatMap.CaseSensitive := False;
            CatMap.Sorted := True;
            CatMap.Duplicates := dupError;
            ExistingCats := AppContext.CategoryService.GetAllCategories(AUserID);
            for I := 0 to High(ExistingCats) do
                CatMap.AddObject(BuildCategoryPath(AppContext, ExistingCats[I].ID),
                    TObject(ExistingCats[I].ID));

            ExistingKeys.Sorted := True;
            Existing := AppContext.SnippetService.GetAllSnippets(AUserID);
            for I := 0 to High(Existing) do
            begin
                Key := Existing[I].Title + #1 + Existing[I].Content;
                if ExistingKeys.IndexOf(Key) < 0 then
                    ExistingKeys.Add(Key);
            end;

            for I := 0 to SnipsArr.Count - 1 do
            begin
                if not (SnipsArr.Items[I] is TJSONObject) then
                    Continue;
                SnipObj := TJSONObject(SnipsArr.Items[I]);
                Snip := Default(TSnippetDTO);
                Snip.Title := SnipObj.GetValue<string>('title', '');
                Snip.Content := SnipObj.GetValue<string>('content', '');
                if Snip.Title.Trim.IsEmpty and Snip.Content.Trim.IsEmpty then
                    Continue;

                Key := Snip.Title + #1 + Snip.Content;
                if ExistingKeys.IndexOf(Key) >= 0 then
                begin
                    Inc(Res.Skipped);
                    Continue;
                end;

                Snip.UserID := AUserID;
                Snip.CategoryID := EnsureCategory(
                    SnipObj.GetValue<string>('category', ''));
                // Категория обязательна (FK + валидация сервиса): сниппет без неё
                // не может быть создан - пропускаем, чтобы не обрывать весь импорт
                if Snip.CategoryID <= 0 then
                begin
                    Inc(Res.Skipped);
                    Continue;
                end;
                Snip.Comment := SnipObj.GetValue<string>('comment', '');
                Snip.Language := SnipObj.GetValue<string>('language', '');
                Snip.LanguageLocked := SnipObj.GetValue<Boolean>('languageLocked', False);
                // Флаг игнорирования проверки безопасности не доверяем из внешнего
                // файла: импортированный сниппет обязан пройти скан заново.
                Snip.IsSecurityCheckIgnored := False;
                Snip.CreatedAt := SnipObj.GetValue<Int64>('createdAt', 0);
                if Snip.CreatedAt <= 0 then
                    Snip.CreatedAt := DateTimeToUnix(Now);
                // updatedAt не отбрасываем: экспорт его сохраняет, репозиторий
                // пишет NULL только при <= 0, а пустая дата сбивает сортировку
                Snip.UpdatedAt := SnipObj.GetValue<Int64>('updatedAt', 0);
                if Snip.UpdatedAt <= 0 then
                    Snip.UpdatedAt := Snip.CreatedAt;

                TagIDs.Clear;
                TagsArr := nil;
                SnipObj.TryGetValue<TJSONArray>('tags', TagsArr);
                if TagsArr <> nil then
                    for J := 0 to TagsArr.Count - 1 do
                        if TagsArr.Items[J] is TJSONString then
                        begin
                            TagID := AppContext.TagService.GetOrCreateTag(
                                TJSONString(TagsArr.Items[J]).Value);
                            if TagID > 0 then
                                TagIDs.Add(TagID);
                        end;

                AppContext.SnippetService.CreateSnippet(Snip, TagIDs.ToArray);
                Inc(Res.Imported);
                if ExistingKeys.IndexOf(Key) < 0 then
                    ExistingKeys.Add(Key);
            end;
            Result := Res;
        finally
            ExistingKeys.Free;
            TagIDs.Free;
            CatMap.Free;
        end;
    finally
        Parsed.Free;
    end;
end;

end.
