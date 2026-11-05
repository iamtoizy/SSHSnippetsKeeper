unit Tests.SnippetDuplicate;

interface

uses
    DUnitX.TestFramework,
    FireDAC.Comp.Client,
    Core.Entities.Snippet,
    Core.Entities.Tag,
    Core.Interfaces.Services
    ;

type
    [TestFixture]
    TSnippetDuplicateTests = class(TObject)
    private
        FConn: TFDConnection;
        FTempDir: string;
        function SchemaPath(const Filename: string): string;
        function TranslationPath: string;
        procedure ExecScript(const Filenames: array of string);
        function AddCategoryRaw(const Name: string; UserID: Integer = 1): Integer;
        function AddTagRaw(const Name: string): Integer;
        function MakeSnippetDTO(const Title: string; CategoryID: Integer): TSnippetDTO;
        function MakeService: ISnippetService;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;
        [Test]
        procedure Duplicate_CopiesAllFields_AndSuffixesTitle;
        [Test]
        procedure Duplicate_CopiesTags;
        [Test]
        procedure Duplicate_IsIndependentFromOriginal;
        [Test]
        procedure Duplicate_InvalidId_Raises;
        [Test]
        procedure Duplicate_MissingSnippet_Raises;
    end;

implementation

uses
    System.SysUtils,
    System.DateUtils,
    System.IOUtils,
    Common.Localization,
    SnippetService,
    SnippetRepository,
    CategoryRepository,
    TagRepository,
    UserRepository,
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

function TSnippetDuplicateTests.SchemaPath(const Filename: string): string;
var
    Dir: string;
begin
    Dir := TPath.GetDirectoryName(ParamStr(0));
    repeat
        Result := TPath.Combine(Dir, TPath.Combine('Database', TPath.Combine('Schema', Filename)));
        if TFile.Exists(Result) then
            Exit;
        Dir := TPath.GetDirectoryName(Dir);
    until Dir = '';
    raise Exception.Create('Schema file not found: ' + Result);
end;

function TSnippetDuplicateTests.TranslationPath: string;
var
    Dir: string;
begin
    Dir := TPath.GetDirectoryName(ParamStr(0));
    repeat
        Result := TPath.Combine(Dir,
            TPath.Combine('Assets', TPath.Combine('ExeData', TPath.Combine('Translation', 'ui-texts.ru.json'))));
        if TFile.Exists(Result) then
            Exit;
        Dir := TPath.GetDirectoryName(Dir);
    until Dir = '';
    raise Exception.Create('Translation file not found: ' + Result);
end;

procedure TSnippetDuplicateTests.ExecScript(const Filenames: array of string);
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

procedure TSnippetDuplicateTests.Setup;
begin
    // Суффикс заголовка дубликата берется из локализации
    TUIStateLoader.LoadLanguageFile(TranslationPath);

    FConn := TFDConnection.Create(nil);
    FConn.Params.Add('DriverID=SQLite');
    FConn.Params.Add('Database=:memory:');
    FConn.Connected := True;
    FConn.ExecSQL('PRAGMA foreign_keys = ON');
    ExecScript(['000_schema_init.sql']);
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'')');
    FTempDir := '';
end;

procedure TSnippetDuplicateTests.TearDown;
begin
    if FTempDir <> '' then
    try
        TDirectory.Delete(FTempDir, True);
    except
        on E: Exception do ;
    end;
    FreeAndNil(FConn);
end;

function TSnippetDuplicateTests.AddCategoryRaw(const Name: string; UserID: Integer): Integer;
begin
    FConn.ExecSQL('INSERT INTO snippet_categories (user_id, name, parent_id, sort_order) VALUES (?, ?, NULL, 0)',
        [UserID, Name]);
    Result := FConn.ExecSQLScalar('SELECT last_insert_rowid()');
end;

function TSnippetDuplicateTests.AddTagRaw(const Name: string): Integer;
begin
    FConn.ExecSQL('INSERT INTO tags (name) VALUES (?)', [Name]);
    Result := FConn.ExecSQLScalar('SELECT last_insert_rowid()');
end;

function TSnippetDuplicateTests.MakeSnippetDTO(const Title: string; CategoryID: Integer): TSnippetDTO;
begin
    Result := Default(TSnippetDTO);
    Result.UserID := 1;
    Result.Title := Title;
    Result.Content := 'echo hello';
    Result.Comment := 'note';
    Result.CategoryID := CategoryID;
    Result.Language := 'bash';
    Result.LanguageLocked := True;
    Result.IsSecurityCheckIgnored := True;
    Result.CreatedAt := 1700000000;
    Result.UpdatedAt := 1700000001;
end;

function TSnippetDuplicateTests.MakeService: ISnippetService;
begin
    Result := TSnippetService.Create(
        TSnippetRepository.Create(FConn),
        TCategoryRepository.Create(FConn),
        TTagRepository.Create(FConn),
        TUserRepository.Create(FConn));
end;

procedure TSnippetDuplicateTests.Duplicate_CopiesAllFields_AndSuffixesTitle;
var
    Svc: ISnippetService;
    CatID, SnipID, NewID: Integer;
    Src, CopySnip: TSnippetDTO;
begin
    CatID := AddCategoryRaw('work');
    Svc := MakeService;
    SnipID := Svc.CreateSnippet(MakeSnippetDTO('deploy', CatID), []);

    NewID := Svc.DuplicateSnippet(SnipID);
    Assert.AreNotEqual(SnipID, NewID);

    Src := Svc.GetSnippetByID(SnipID);
    CopySnip := Svc.GetSnippetByID(NewID);

    Assert.AreEqual('deploy (копия)', CopySnip.Title);
    Assert.AreEqual(Src.Content, CopySnip.Content);
    Assert.AreEqual(Src.Comment, CopySnip.Comment);
    Assert.AreEqual(CatID, CopySnip.CategoryID);
    Assert.AreEqual(1, CopySnip.UserID);
    Assert.AreEqual('bash', CopySnip.Language);
    Assert.IsTrue(CopySnip.LanguageLocked);
    Assert.IsTrue(CopySnip.IsSecurityCheckIgnored);
    Assert.IsTrue(CopySnip.CreatedAt >= Src.CreatedAt);
    Assert.AreEqual(CopySnip.CreatedAt, CopySnip.UpdatedAt);

    // Оригинал не изменился
    Assert.AreEqual('deploy', Src.Title);
    Assert.AreEqual(Int64(1700000000), Src.CreatedAt);
    Assert.AreEqual(Int64(1700000001), Src.UpdatedAt);
end;

procedure TSnippetDuplicateTests.Duplicate_CopiesTags;
var
    Svc: ISnippetService;
    TagRepo: TTagRepository;
    CatID, SnipID, NewID, T1, T2: Integer;
    Tags: TArray<TTagDTO>;
begin
    CatID := AddCategoryRaw('w');
    Svc := MakeService;
    SnipID := Svc.CreateSnippet(MakeSnippetDTO('tagged', CatID), []);

    T1 := AddTagRaw('prod');
    T2 := AddTagRaw('stage');
    TagRepo := TTagRepository.Create(FConn);
    try
        TagRepo.LinkTagToSnippet(SnipID, T1);
        TagRepo.LinkTagToSnippet(SnipID, T2);

        NewID := Svc.DuplicateSnippet(SnipID);

        Tags := TagRepo.GetSnippetTags(NewID);
        Assert.AreEqual(2, Integer(Length(Tags)));
        Assert.AreEqual('prod', Tags[0].Name);
        Assert.AreEqual('stage', Tags[1].Name);

        // У оригинала теги остались на месте
        Assert.AreEqual(2, Integer(Length(TagRepo.GetSnippetTags(SnipID))));
    finally
        TagRepo.Free;
    end;
end;

procedure TSnippetDuplicateTests.Duplicate_IsIndependentFromOriginal;
var
    Svc: ISnippetService;
    CatID, SnipID, NewID: Integer;
    Snip: TSnippetDTO;
begin
    CatID := AddCategoryRaw('w');
    Svc := MakeService;
    SnipID := Svc.CreateSnippet(MakeSnippetDTO('base', CatID), []);
    NewID := Svc.DuplicateSnippet(SnipID);

    Snip := Svc.GetSnippetByID(SnipID);
    Snip.Content := 'modified';
    Svc.UpdateSnippet(Snip, []);

    Assert.AreEqual('modified', Svc.GetSnippetByID(SnipID).Content);
    Assert.AreEqual('echo hello', Svc.GetSnippetByID(NewID).Content);

    Svc.DeleteSnippet(SnipID);
    Assert.AreNotEqual(0, Svc.GetSnippetByID(NewID).ID);
end;

procedure TSnippetDuplicateTests.Duplicate_InvalidId_Raises;
var
    Svc: ISnippetService;
begin
    Svc := MakeService;
    Assert.WillRaise(
        procedure
        begin
            Svc.DuplicateSnippet(0);
        end,
        ESnippetValidationException);
end;

procedure TSnippetDuplicateTests.Duplicate_MissingSnippet_Raises;
var
    Svc: ISnippetService;
begin
    Svc := MakeService;
    Assert.WillRaise(
        procedure
        begin
            Svc.DuplicateSnippet(99999);
        end,
        ESnippetValidationException);
end;

end.
