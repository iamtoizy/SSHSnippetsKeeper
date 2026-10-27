unit Core.MarkdownExporter;

interface

uses
    Core.Entities.Category,
    Core.Entities.Snippet,
    Core.Entities.Tag,
    Core.Entities.User,
    Core.Interfaces.App,
    Core.Interfaces.Services,
    System.Classes,
    System.Generics.Collections,
    System.Generics.Defaults,
    System.IOUtils,
    System.SysUtils
    ;

type
    TMarkdownExporter = class
    private
        const
            MAX_FILENAME_LENGTH = 80;
            SYNC_MARKER = 'generator: SSHSnippetsKeeper';

        class function SanitizeFileName(const Name: string): string;

        // Передаем закэшированные словари вместо AppContext
        class function BuildCategoryPath(
            CatDict: TDictionary<Integer, TCategoryDTO>;
            UserDict: TDictionary<Integer, TUserDTO>;
            UserID, CategoryID: Integer): string;

        class function BuildSnippetMarkdown(
            const Snippet: TSnippetDTO;
            const Tags: TArray<TTagDTO>): string;
    public
        class procedure ExportDatabase(const AppContext: IAppContext; const BaseDir: string);

        class function ExportSnippets(
            const AppContext: IAppContext;
            const BaseDir: string;
            const Snippets: TArray<TSnippetDTO>): Integer; overload;

        class function ExportSnippets(
            const BaseDir: string;
            const Snippets: TArray<TSnippetDTO>;
            const GetTags: TFunc<Integer, TArray<TTagDTO>>): Integer; overload;
    end;

implementation

uses
    Common.Localization,
    Common.SnippetLanguages
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
            // ЧИТАЕМ ИЗ ОПЕРАТИВНОЙ ПАМЯТИ (0 SQL запросов)
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

class function TMarkdownExporter.BuildSnippetMarkdown(
    const Snippet: TSnippetDTO;
    const Tags: TArray<TTagDTO>): string;
var
    Tag: TTagDTO;
    TagsList: string;
    TagSB: TStringBuilder;
begin
    TagSB := TStringBuilder.Create;
    try
        for Tag in Tags do
            TagSB.Append('"').Append(Tag.Name).Append('", ');
        TagsList := TagSB.ToString;
        if TagsList.EndsWith(', ') then
            Delete(TagsList, TagsList.Length - 1, 2);
    finally
        TagSB.Free;
    end;

    Result :=
        '---' + sLineBreak +
        'id: ' + Snippet.ID.ToString + sLineBreak +
        'title: "' + Snippet.Title.Replace('"', '\"') + '"' + sLineBreak +
        SYNC_MARKER + sLineBreak +
        'tags: [' + TagsList + ']' + sLineBreak +
        'language: ' + FenceTagForSnippetLanguage(Snippet.Language) + sLineBreak +
        'created_at: ' + Snippet.CreatedAt.ToString + sLineBreak +
        'updated_at: ' + Snippet.UpdatedAt.ToString + sLineBreak +
        '---' + sLineBreak + sLineBreak +
        '# ' + Snippet.Title + sLineBreak + sLineBreak;

    if Trim(Snippet.Comment) <> '' then
        Result := Result + Snippet.Comment + sLineBreak + sLineBreak;

    Result := Result + '```' + FenceTagForSnippetLanguage(Snippet.Language) + sLineBreak +
        Snippet.Content + sLineBreak + '```' + sLineBreak;
end;

class procedure TMarkdownExporter.ExportDatabase(const AppContext: IAppContext; const BaseDir: string);
var
    Snippets: TArray<TSnippetDTO>;
    Snippet: TSnippetDTO;
    Tags: TArray<TTagDTO>;
    Cat: TCategoryDTO;
    User: TUserDTO;
    CatPath, FullDir, BaseFileName, FinalFileName, FileContent: string;
    Counter: Integer;
    BaseAbs: string;
    GeneratedFiles: TDictionary<string, Boolean>;
    CatDict: TDictionary<Integer, TCategoryDTO>;
    UserDict: TDictionary<Integer, TUserDTO>;
    ExistingFiles, AllDirs: TArray<string>;
    OldFile, Dir: string;
    QuarantineDir: string;
    QuarantineIdx: Integer;

    function QuarantinePath(const SrcFile: string): string;
    begin
        Inc(QuarantineIdx);
        Result := TPath.Combine(QuarantineDir,
            Format('%s_%d_%s', [FormatDateTime('yyyymmdd_hhnnss', Now), QuarantineIdx, ExtractFileName(SrcFile)]));
    end;

begin
    if not TDirectory.Exists(BaseDir) then TDirectory.CreateDirectory(BaseDir);

    BaseAbs := IncludeTrailingPathDelimiter(TPath.GetFullPath(BaseDir));
    QuarantineDir := TPath.Combine(ExtractFileDir(ExcludeTrailingPathDelimiter(BaseDir)), 'SSHSnippetsKeeper_Trash');
    QuarantineIdx := 0;

    GeneratedFiles := TDictionary<string, Boolean>.Create;
    CatDict := TDictionary<Integer, TCategoryDTO>.Create;
    UserDict := TDictionary<Integer, TUserDTO>.Create;
    try
        // === ПРЕДЗАГРУЗКА КЭША (Всего 2 SQL запроса на всю базу) ===
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
            FullDir := TPath.GetFullPath(TPath.Combine(BaseAbs, CatPath));

            if not FullDir.StartsWith(BaseAbs, True) then
                raise Exception.Create(TUIStateLoader.GetMessage('Common.PathEscapeBlocked'));

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
            FileContent := BuildSnippetMarkdown(Snippet, Tags);
            TFile.WriteAllText(FinalFileName, FileContent, TEncoding.UTF8);
        end;

        // БЛОК ОЧИСТКИ
        ExistingFiles := TDirectory.GetFiles(BaseDir, '*.md', TSearchOption.soAllDirectories);
        for OldFile in ExistingFiles do
        begin
            if OldFile.Contains(TPath.DirectorySeparatorChar + '.git' + TPath.DirectorySeparatorChar) then Continue;
            if not GeneratedFiles.ContainsKey(LowerCase(OldFile)) then
            begin
                try
                    if not TDirectory.Exists(QuarantineDir) then TDirectory.CreateDirectory(QuarantineDir);
                    TFile.Move(OldFile, QuarantinePath(OldFile));
                except
                    on E: Exception do ;
                end;
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
            except on E: Exception do raise Exception.Create(TUIStateLoader.GetMessage('Markdown.DeleteFolderError', [ExtractFileName(Dir)])); end;
        end;

    finally
        GeneratedFiles.Free;
        CatDict.Free;
        UserDict.Free;
    end;
end;

class function TMarkdownExporter.ExportSnippets(
    const AppContext: IAppContext;
    const BaseDir: string;
    const Snippets: TArray<TSnippetDTO>): Integer;
begin
    Result := ExportSnippets(BaseDir, Snippets,
        function(SnippetID: Integer): TArray<TTagDTO>
        begin
            Result := AppContext.TagService.GetSnippetTags(SnippetID);
        end);
end;

class function TMarkdownExporter.ExportSnippets(
    const BaseDir: string;
    const Snippets: TArray<TSnippetDTO>;
    const GetTags: TFunc<Integer, TArray<TTagDTO>>): Integer;
var
    Snippet: TSnippetDTO;
    Tags: TArray<TTagDTO>;
    BaseFileName, FinalFileName, FileContent: string;
    Counter, Written: Integer;
    BaseAbs: string;
    ExistingFiles: TArray<string>;
    Taken: TDictionary<string, Boolean>;
    OldFile: string;
begin
    Result := 0;
    if Length(Snippets) = 0 then
        Exit;

    if not TDirectory.Exists(BaseDir) then
        TDirectory.CreateDirectory(BaseDir);

    BaseAbs := IncludeTrailingPathDelimiter(TPath.GetFullPath(BaseDir));
    Taken := TDictionary<string, Boolean>.Create;
    try
        ExistingFiles := TDirectory.GetFiles(BaseAbs, '*.md', TSearchOption.soTopDirectoryOnly);
        for OldFile in ExistingFiles do
            Taken.AddOrSetValue(LowerCase(OldFile), True);

        Written := 0;
        for Snippet in Snippets do
        begin
            if Snippet.ID = 0 then
                Continue;

            BaseFileName := SanitizeFileName(Snippet.Title);
            FinalFileName := TPath.Combine(BaseAbs, BaseFileName + '.md');
            Counter := 1;
            while Taken.ContainsKey(LowerCase(FinalFileName)) do
            begin
                FinalFileName := TPath.Combine(BaseAbs, Format('%s (%d).md', [BaseFileName, Counter]));
                Inc(Counter);
            end;
            Taken.AddOrSetValue(LowerCase(FinalFileName), True);

            Tags := GetTags(Snippet.ID);
            FileContent := BuildSnippetMarkdown(Snippet, Tags);
            TFile.WriteAllText(FinalFileName, FileContent, TEncoding.UTF8);
            Inc(Written);
        end;

        Result := Written;
    finally
        Taken.Free;
    end;
end;

end.
