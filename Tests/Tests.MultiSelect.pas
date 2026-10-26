unit Tests.MultiSelect;

interface

uses
    DUnitX.TestFramework,
    FireDAC.Comp.Client,
    TagRepository,
    SnippetRepository,
    CategoryRepository,
    UserRepository,
    Core.Entities.Snippet,
    Core.Entities.Tag,
    Core.Entities.Category
    ;

type
    [TestFixture]
    TMultiSelectTests = class(TObject)
    private
        FConn: TFDConnection;
        FTempDir: string;
        function SchemaPath(const Filename: string): string;
        procedure ExecScript(const Filenames: array of string);
        function AddSnippetRaw(const Title: string; UserID: Integer = 1; CategoryID: Integer = 0): Integer;
        function AddCategoryRaw(const Name: string; UserID: Integer = 1): Integer;
        function AddTagRaw(const Name: string): Integer;
        function MakeSnippetDTO(ID: Integer; const Title: string): TSnippetDTO;
        function TempDir: string;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;
        [Test]
        procedure LinkTagToSnippet_IsIdempotent;
        [Test]
        procedure LinkTagToSnippet_AppliesToEachSnippet;
        [Test]
        procedure UpdateTags_ReplacesSet;
        [Test]
        procedure MoveSnippet_KeepsTags_AndChangesCategory;
        [Test]
        procedure MoveSnippet_CrossWorkspace_UserAndFavoriteTransfer;
        [Test]
        procedure UnlinkTagFromSnippet_RemovesLink;
        [Test]
        procedure Export_WritesOneFilePerSnippet;
        [Test]
        procedure Export_DuplicateTitles_GetSuffixes;
        [Test]
        procedure Export_ExistingFile_NotOverwritten;
    end;

implementation

uses
    System.SysUtils,
    System.IOUtils,
    Core.Interfaces.Services,
    SnippetService,
    Core.MarkdownExporter,
    FireDAC.Comp.Script,
    FireDAC.Comp.ScriptCommands,
    FireDAC.Phys.SQLite,
    FireDAC.Phys.SQLiteWrapper.Stat,
    FireDAC.Stan.Def,
    FireDAC.Stan.Async,
    FireDAC.Stan.ExprFuncs,
    FireDAC.Stan.Error,
    FireDAC.ConsoleUI.Wait,
    FireDAC.Phys.SQLiteWrapper
    ;

function TMultiSelectTests.SchemaPath(const Filename: string): string;
var
    Dir: string;
begin
    Dir := TPath.GetDirectoryName(ParamStr(0));
    repeat
        Result := TPath.Combine(Dir, TPath.Combine('Database', 'Schema', Filename));
        if TFile.Exists(Result) then
            Exit;
        Dir := TPath.GetDirectoryName(Dir);
    until Dir = '';
    raise Exception.Create('Schema file not found: ' + Result);
end;

procedure TMultiSelectTests.ExecScript(const Filenames: array of string);
var
    Script: TFDScript;
    SQL, Path: string;
    I: Integer;
begin
    SQL := '';
    for I := Low(Filenames) to High(Filenames) do
    begin
        Path := SchemaPath(Filenames[I]);
        if SQL <> '' then
            SQL := SQL + sLineBreak;
        SQL := SQL + TFile.ReadAllText(Path, TEncoding.UTF8);
    end;
    Script := TFDScript.Create(nil);
    try
        Script.Connection := FConn;
        Script.SQLScripts.Add.SQL.Text := SQL;
        Script.ExecuteAll;
    finally
        Script.Free;
    end;
end;

procedure TMultiSelectTests.Setup;
begin
    FConn := TFDConnection.Create(nil);
    FConn.Params.Add('DriverID=SQLite');
    FConn.Params.Add('Database=:memory:');
    FConn.Connected := True;
    FConn.ExecSQL('PRAGMA foreign_keys = ON');
    ExecScript(['000_schema_init.sql', '100_migrations.sql']);
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'')');
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (2, ''Second User'')');
    FTempDir := '';
end;

procedure TMultiSelectTests.TearDown;
begin
    if FTempDir <> '' then
    try
        TDirectory.Delete(FTempDir, True);
    except
        on E: Exception do ;
    end;
    FreeAndNil(FConn);
end;

function TMultiSelectTests.AddSnippetRaw(const Title: string; UserID: Integer; CategoryID: Integer): Integer;
begin
    if CategoryID > 0 then
        FConn.ExecSQL('INSERT INTO snippets (user_id, category_id, title, content) VALUES (?, ?, ?, ?)',
            [UserID, CategoryID, Title, 'echo ' + Title])
    else
        FConn.ExecSQL('INSERT INTO snippets (user_id, title, content) VALUES (?, ?, ?)',
            [UserID, Title, 'echo ' + Title]);
    Result := FConn.ExecSQLScalar('SELECT last_insert_rowid()');
end;

function TMultiSelectTests.AddCategoryRaw(const Name: string; UserID: Integer): Integer;
begin
    FConn.ExecSQL('INSERT INTO snippet_categories (user_id, name, parent_id, sort_order) VALUES (?, ?, NULL, 0)',
        [UserID, Name]);
    Result := FConn.ExecSQLScalar('SELECT last_insert_rowid()');
end;

function TMultiSelectTests.AddTagRaw(const Name: string): Integer;
begin
    FConn.ExecSQL('INSERT INTO tags (name) VALUES (?)', [Name]);
    Result := FConn.ExecSQLScalar('SELECT last_insert_rowid()');
end;

function TMultiSelectTests.MakeSnippetDTO(ID: Integer; const Title: string): TSnippetDTO;
begin
    Result := Default(TSnippetDTO);
    Result.ID := ID;
    Result.UserID := 1;
    Result.Title := Title;
    Result.Content := 'echo hello';
    Result.Comment := 'note';
    Result.CreatedAt := 1700000000;
    Result.UpdatedAt := 1700000001;
end;

function TMultiSelectTests.TempDir: string;
begin
    if FTempDir = '' then
        FTempDir := TPath.Combine(TPath.GetTempPath, 'ssk_multiselect_' + TGUID.NewGuid.ToString);
    Result := FTempDir;
end;

procedure TMultiSelectTests.LinkTagToSnippet_IsIdempotent;
var
    Repo: TTagRepository;
    Tag: TTagDTO;
    SnipID, TagID: Integer;
begin
    SnipID := AddSnippetRaw('deploy');
    Tag := Default(TTagDTO);
    Tag.Name := 'prod';
    Repo := TTagRepository.Create(FConn);
    try
        TagID := Repo.Add(Tag);
        Repo.LinkTagToSnippet(SnipID, TagID);
        Repo.LinkTagToSnippet(SnipID, TagID);
        Assert.AreEqual(1, Integer(Length(Repo.GetSnippetTags(SnipID))));
    finally
        Repo.Free;
    end;
end;

procedure TMultiSelectTests.LinkTagToSnippet_AppliesToEachSnippet;
var
    Repo: TTagRepository;
    Snip1, Snip2, TagID: Integer;
begin
    Snip1 := AddSnippetRaw('one');
    Snip2 := AddSnippetRaw('two');
    TagID := AddTagRaw('bulk');
    Repo := TTagRepository.Create(FConn);
    try
        Repo.LinkTagToSnippet(Snip1, TagID);
        Repo.LinkTagToSnippet(Snip2, TagID);
        Assert.AreEqual(1, Integer(Length(Repo.GetSnippetTags(Snip1))));
        Assert.AreEqual(1, Integer(Length(Repo.GetSnippetTags(Snip2))));
        Assert.AreEqual('bulk', Repo.GetSnippetTags(Snip1)[0].Name);
    finally
        Repo.Free;
    end;
end;

procedure TMultiSelectTests.UpdateTags_ReplacesSet;
var
    TagRepo: TTagRepository;
    SnipRepo: TSnippetRepository;
    SnipID, T1, T2, T3: Integer;
begin
    SnipID := AddSnippetRaw('multi');
    T1 := AddTagRaw('a1');
    T2 := AddTagRaw('b2');
    T3 := AddTagRaw('c3');
    TagRepo := TTagRepository.Create(FConn);
    SnipRepo := TSnippetRepository.Create(FConn);
    try
        TagRepo.LinkTagToSnippet(SnipID, T1);
        TagRepo.LinkTagToSnippet(SnipID, T2);
        SnipRepo.UpdateTags(SnipID, [T2, T3]);
        Assert.AreEqual(2, Integer(Length(TagRepo.GetSnippetTags(SnipID))));
        Assert.AreEqual('b2', TagRepo.GetSnippetTags(SnipID)[0].Name);
        Assert.AreEqual('c3', TagRepo.GetSnippetTags(SnipID)[1].Name);
    finally
        SnipRepo.Free;
        TagRepo.Free;
    end;
end;

procedure TMultiSelectTests.MoveSnippet_KeepsTags_AndChangesCategory;
var
    Svc: ISnippetService;
    TagRepo: TTagRepository;
    Snip: TSnippetDTO;
    Cat1, Cat2, SnipID, T1: Integer;
begin
    Cat1 := AddCategoryRaw('Source');
    Cat2 := AddCategoryRaw('Target');
    SnipID := AddSnippetRaw('movable', 1, Cat1);
    T1 := AddTagRaw('keepme');
    FConn.ExecSQL('INSERT INTO snippet_tags (snippet_id, tag_id) VALUES (?, ?)', [SnipID, T1]);

    Svc := TSnippetService.Create(
        TSnippetRepository.Create(FConn),
        TCategoryRepository.Create(FConn),
        TTagRepository.Create(FConn),
        TUserRepository.Create(FConn));

    Snip := Svc.GetSnippetByID(SnipID);
    Assert.AreEqual(Cat1, Snip.CategoryID);

    Snip.CategoryID := Cat2;
    Svc.UpdateSnippet(Snip, [T1]);

    Snip := Svc.GetSnippetByID(SnipID);
    Assert.AreEqual(Cat2, Snip.CategoryID);

    TagRepo := TTagRepository.Create(FConn);
    try
        Assert.AreEqual(1, Integer(Length(TagRepo.GetSnippetTags(SnipID))));
        Assert.AreEqual('keepme', TagRepo.GetSnippetTags(SnipID)[0].Name);
    finally
        TagRepo.Free;
    end;
end;

procedure TMultiSelectTests.MoveSnippet_CrossWorkspace_UserAndFavoriteTransfer;
var
    Svc: ISnippetService;
    SnipRepo: TSnippetRepository;
    TagRepo: TTagRepository;
    Snip: TSnippetDTO;
    Cat2, SnipID, T1: Integer;
begin
    Cat2 := AddCategoryRaw('TargetW2', 2);
    SnipID := AddSnippetRaw('traveler', 1);
    T1 := AddTagRaw('movetag');
    FConn.ExecSQL('INSERT INTO snippet_tags (snippet_id, tag_id) VALUES (?, ?)', [SnipID, T1]);
    FConn.ExecSQL('INSERT INTO snippet_favorites (user_id, snippet_id, sort_order) VALUES (1, ?, 0)', [SnipID]);

    Svc := TSnippetService.Create(
        TSnippetRepository.Create(FConn),
        TCategoryRepository.Create(FConn),
        TTagRepository.Create(FConn),
        TUserRepository.Create(FConn));

    Svc.MoveSnippet(SnipID, Cat2);

    Snip := Svc.GetSnippetByID(SnipID);
    Assert.AreEqual(2, Snip.UserID);
    Assert.AreEqual(Cat2, Snip.CategoryID);

    SnipRepo := TSnippetRepository.Create(FConn);
    try
        Assert.IsTrue(SnipRepo.IsFavorite(SnipID, 2));
        Assert.IsFalse(SnipRepo.IsFavorite(SnipID, 1));
    finally
        SnipRepo.Free;
    end;

    TagRepo := TTagRepository.Create(FConn);
    try
        Assert.AreEqual(1, Integer(Length(TagRepo.GetSnippetTags(SnipID))));
    finally
        TagRepo.Free;
    end;
end;

procedure TMultiSelectTests.UnlinkTagFromSnippet_RemovesLink;
var
    TagRepo: TTagRepository;
    SnipID, T1: Integer;
begin
    SnipID := AddSnippetRaw('untag');
    T1 := AddTagRaw('temp');

    TagRepo := TTagRepository.Create(FConn);
    try
        TagRepo.LinkTagToSnippet(SnipID, T1);
        TagRepo.LinkTagToSnippet(SnipID, T1);
        Assert.AreEqual(1, Integer(Length(TagRepo.GetSnippetTags(SnipID))));

        TagRepo.UnlinkTagFromSnippet(SnipID, T1);
        Assert.AreEqual(0, Integer(Length(TagRepo.GetSnippetTags(SnipID))));
        TagRepo.UnlinkTagFromSnippet(SnipID, T1);
        Assert.AreEqual(0, Integer(Length(TagRepo.GetSnippetTags(SnipID))));
    finally
        TagRepo.Free;
    end;
end;

procedure TMultiSelectTests.Export_WritesOneFilePerSnippet;
var
    A, B: TSnippetDTO;
    Arr: TArray<TSnippetDTO>;
    GetTags: TFunc<Integer, TArray<TTagDTO>>;
    Files: TArray<string>;
    Text: string;
begin
    A := MakeSnippetDTO(101, 'Alpha script');
    B := MakeSnippetDTO(102, 'Beta script');
    Arr := TArray<TSnippetDTO>.Create(A, B);

    GetTags := function(SnippetID: Integer): TArray<TTagDTO>
    begin
        Result := nil;
    end;

    TMarkdownExporter.ExportSnippets(TempDir, Arr, GetTags);

    Files := TDirectory.GetFiles(TempDir, '*.md');
    Assert.AreEqual(2, Integer(Length(Files)));
    Text := TFile.ReadAllText(TPath.Combine(TempDir, 'Alpha script.md'), TEncoding.UTF8);
    Assert.Contains(Text, 'id: 101');
    Assert.Contains(Text, 'title: "Alpha script"');
    Assert.Contains(Text, 'generator: SSHSnippetsKeeper');
    Assert.Contains(Text, '```bash');
    Assert.Contains(Text, 'echo hello');
end;

procedure TMultiSelectTests.Export_DuplicateTitles_GetSuffixes;
var
    A, B: TSnippetDTO;
    Arr: TArray<TSnippetDTO>;
    GetTags: TFunc<Integer, TArray<TTagDTO>>;
begin
    A := MakeSnippetDTO(201, 'Dup');
    B := MakeSnippetDTO(202, 'Dup');
    Arr := TArray<TSnippetDTO>.Create(A, B);

    GetTags := function(SnippetID: Integer): TArray<TTagDTO>
    begin
        Result := nil;
    end;

    TMarkdownExporter.ExportSnippets(TempDir, Arr, GetTags);

    Assert.IsTrue(TFile.Exists(TPath.Combine(TempDir, 'Dup.md')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(TempDir, 'Dup (1).md')));
end;

procedure TMultiSelectTests.Export_ExistingFile_NotOverwritten;
var
    A: TSnippetDTO;
    Arr: TArray<TSnippetDTO>;
    GetTags: TFunc<Integer, TArray<TTagDTO>>;
begin
    TDirectory.CreateDirectory(TempDir);
    TFile.WriteAllText(TPath.Combine(TempDir, 'Take.md'), 'old content', TEncoding.UTF8);

    A := MakeSnippetDTO(301, 'Take');
    Arr := TArray<TSnippetDTO>.Create(A);

    GetTags := function(SnippetID: Integer): TArray<TTagDTO>
    begin
        Result := nil;
    end;

    TMarkdownExporter.ExportSnippets(TempDir, Arr, GetTags);

    Assert.AreEqual('old content', TFile.ReadAllText(TPath.Combine(TempDir, 'Take.md')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(TempDir, 'Take (1).md')));
end;

end.
