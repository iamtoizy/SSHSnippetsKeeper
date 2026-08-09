unit Core.MarkdownExporter;

interface

uses
    Core.Interfaces,
    Category,
    User,
    System.SysUtils,
    System.Classes,
    System.IOUtils,
    System.Generics.Collections,
    System.Generics.Defaults;

type
    TMarkdownExporter = class
    private
        const MAX_FILENAME_LENGTH = 80;
        class function SanitizeFileName(const Name: string): string;

        // ВАЖНО: Теперь передаем закэшированные словари вместо AppContext
        class function BuildCategoryPath(
            CatDict: TDictionary<Integer, TCategoryDTO>;
            UserDict: TDictionary<Integer, TUserDTO>;
            UserID, CategoryID: Integer): string;
    public
        class procedure ExportDatabase(const AppContext: IAppContext; const BaseDir: string);
    end;

implementation

uses
    Tag,
    Snippet
    ;

class function TMarkdownExporter.SanitizeFileName(const Name: string): string;
// ... (остается БЕЗ изменений, как было раньше) ...
var
    InvalidChars: TArray<Char>;
    C: Char;
    Res: string;
begin
    Res := Trim(Name);
    InvalidChars := TPath.GetInvalidFileNameChars;
    for C in InvalidChars do Res := Res.Replace(C, '_');
    while (Res.Length > 0) and ((Res[Res.Length] = '.') or (Res[Res.Length] = ' ')) do Delete(Res, Res.Length, 1);
    if Res.Length > MAX_FILENAME_LENGTH then Res := Trim(Res.Substring(0, MAX_FILENAME_LENGTH));
    if Res = '' then Res := 'Untitled_Snippet';
    if SameText(Res, 'CON') or SameText(Res, 'PRN') or SameText(Res, 'AUX') or
       SameText(Res, 'NUL') or SameText(Res, 'COM1') or SameText(Res, 'LPT1') then Res := Res + '_';
    Result := Res;
end;

class function TMarkdownExporter.BuildCategoryPath(
    CatDict: TDictionary<Integer, TCategoryDTO>;
    UserDict: TDictionary<Integer, TUserDTO>;
    UserID, CategoryID: Integer): string;
var
    Cat: TCategoryDTO;
    User: TUserDTO;
    PathParts: TList<string>;
    CurrentCatID: Integer;
begin
    PathParts := TList<string>.Create;
    try
        CurrentCatID := CategoryID;
        while CurrentCatID > 0 do
        begin
            // ЧИТАЕМ ИЗ ОПЕРАТИВНОЙ ПАМЯТИ (0 SQL запросов!)
            if not CatDict.TryGetValue(CurrentCatID, Cat) then Break;

            PathParts.Add(SanitizeFileName(Cat.Name));
            CurrentCatID := Cat.ParentID;
        end;

        // ЧИТАЕМ ИЗ ОПЕРАТИВНОЙ ПАМЯТИ
        if UserDict.TryGetValue(UserID, User) then
            PathParts.Add(SanitizeFileName(User.Name))
        else
            PathParts.Add('Unknown_Workspace');

        PathParts.Reverse;
        Result := string.Join(TPath.DirectorySeparatorChar, PathParts.ToArray);
    finally
        PathParts.Free;
    end;
end;

class procedure TMarkdownExporter.ExportDatabase(const AppContext: IAppContext; const BaseDir: string);
var
    Snippets: TArray<TSnippetDTO>;
    Snippet: TSnippetDTO;
    Tags: TArray<TTagDTO>;
    Tag: TTagDTO;
    Cat: TCategoryDTO;
    User: TUserDTO;
    CatPath, FullDir, BaseFileName, FinalFileName, FileContent, TagsList: string;
    Counter: Integer;
    GeneratedFiles: TDictionary<string, Boolean>;
    CatDict: TDictionary<Integer, TCategoryDTO>;
    UserDict: TDictionary<Integer, TUserDTO>;
    ExistingFiles, AllDirs: TArray<string>;
    OldFile, Dir: string;
begin
    if not TDirectory.Exists(BaseDir) then TDirectory.CreateDirectory(BaseDir);

    GeneratedFiles := TDictionary<string, Boolean>.Create;
    CatDict := TDictionary<Integer, TCategoryDTO>.Create;
    UserDict := TDictionary<Integer, TUserDTO>.Create;
    try
        // === ПРЕДЗАГРУЗКА КЭША (Всего 2 SQL запроса на всю базу!) ===
        for Cat in AppContext.CategoryService.GetAllCategories(0) do
            CatDict.Add(Cat.ID, Cat);

        for User in AppContext.UserService.GetAllUsers do
            UserDict.Add(User.ID, User);
        // ==============================================================

        Snippets := AppContext.SnippetService.GetAllSnippets(0);

        for Snippet in Snippets do
        begin
            // Передаем кэш внутрь
            CatPath := BuildCategoryPath(CatDict, UserDict, Snippet.UserID, Snippet.CategoryID);
            FullDir := TPath.Combine(BaseDir, CatPath);
            ForceDirectories(FullDir);

            BaseFileName := SanitizeFileName(Snippet.Title);
            FinalFileName := TPath.Combine(FullDir, BaseFileName + '.md');
            Counter := 1;

            while GeneratedFiles.ContainsKey(LowerCase(FinalFileName)) do
            begin
                FinalFileName := TPath.Combine(FullDir, Format('%s (%d).md', [BaseFileName, Counter]));
                Inc(Counter);
            end;

            GeneratedFiles.Add(LowerCase(FinalFileName), True);

            Tags := AppContext.TagService.GetSnippetTags(Snippet.ID);
            TagsList := '';
            for Tag in Tags do TagsList := TagsList + '"' + Tag.Name + '", ';
            if TagsList.EndsWith(', ') then Delete(TagsList, TagsList.Length - 1, 2);

            FileContent :=
                '---' + sLineBreak +
                'id: ' + Snippet.ID.ToString + sLineBreak +
                'title: "' + Snippet.Title.Replace('"', '\"') + '"' + sLineBreak +
                'tags: [' + TagsList + ']' + sLineBreak +
                'created_at: ' + Snippet.CreatedAt.ToString + sLineBreak +
                'updated_at: ' + Snippet.UpdatedAt.ToString + sLineBreak +
                '---' + sLineBreak + sLineBreak +
                '# ' + Snippet.Title + sLineBreak + sLineBreak;

            if Trim(Snippet.Comment) <> '' then
                FileContent := FileContent + Snippet.Comment + sLineBreak + sLineBreak;

            FileContent := FileContent + '```bash' + sLineBreak + Snippet.Content + sLineBreak + '```' + sLineBreak;
            TFile.WriteAllText(FinalFileName, FileContent, TEncoding.UTF8);
        end;

        // БЛОК ОЧИСТКИ (Остается без изменений)
        ExistingFiles := TDirectory.GetFiles(BaseDir, '*.md', TSearchOption.soAllDirectories);
        for OldFile in ExistingFiles do
        begin
            if not GeneratedFiles.ContainsKey(LowerCase(OldFile)) then
            begin
                try TFile.Delete(OldFile);
                except on E: Exception do raise Exception.CreateFmt('Не удалось удалить файл: "%s"', [ExtractFileName(OldFile)]); end;
            end;
        end;

        AllDirs := TDirectory.GetDirectories(BaseDir, '*', TSearchOption.soAllDirectories);
        TArray.Sort<string>(AllDirs, TComparer<string>.Construct(
            function(const Left, Right: string): Integer begin Result := Length(Right) - Length(Left); end));

        for Dir in AllDirs do
        begin
            if Dir.Contains(TPath.DirectorySeparatorChar + '.git') or Dir.EndsWith(TPath.DirectorySeparatorChar + '.git') then Continue;
            try
                if TDirectory.IsEmpty(Dir) then TDirectory.Delete(Dir);
            except on E: Exception do raise Exception.CreateFmt('Не удалось удалить папку: "%s"', [ExtractFileName(Dir)]); end;
        end;

    finally
        GeneratedFiles.Free;
        CatDict.Free;
        UserDict.Free;
    end;
end;

end.
