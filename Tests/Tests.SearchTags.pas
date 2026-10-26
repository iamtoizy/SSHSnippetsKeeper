unit Tests.SearchTags;

interface

uses
    DUnitX.TestFramework,
    FireDAC.Comp.Client,
    SnippetRepository
    ;

type
    [TestFixture]
    TSearchTagsTests = class(TObject)
    private
        FConn: TFDConnection;
        FRepo: TSnippetRepository;
        function SchemaPath(const Filename: string): string;
        procedure ExecScript(const Filenames: array of string);
        function AddSnippet(const Title, Content: string; UserID: Integer = 1): Integer;
        procedure AddTag(SnippetID: Integer; const TagName: string);
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;
        [Test]
        procedure SimpleMask_FindsByTitle;
        [Test]
        procedure SimpleMask_FindsByTag;
        [Test]
        procedure SimpleMask_NoMatch_ReturnsEmpty;
        [Test]
        procedure SimpleMask_RespectsUserID;
        [Test]
        procedure AdvancedText_BareWord_FindsByTag;
        [Test]
        procedure AdvancedText_BareWord_StillFindsTitle;
        [Test]
        procedure AdvancedText_Exclusion_ByTag;
        [Test]
        procedure AdvancedText_TagFilter_Unchanged;
        [Test]
        procedure AdvancedFTS_BareWord_FindsByTag;
    end;

implementation

uses
    System.SysUtils,
    System.IOUtils,
    FireDAC.Comp.Script,
    FireDAC.Comp.ScriptCommands,
    FireDAC.Phys.SQLite,
    FireDAC.Phys.SQLiteWrapper.Stat,
    FireDAC.Stan.Def,
    FireDAC.Stan.Async,
    FireDAC.Stan.ExprFuncs,
    FireDAC.ConsoleUI.Wait,
    Common.QueryLanguage,
    Core.Entities.Snippet
    ;

var
    GDriverLink: TFDPhysSQLiteDriverLink;

function TSearchTagsTests.SchemaPath(const Filename: string): string;
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

procedure TSearchTagsTests.ExecScript(const Filenames: array of string);
var
    Script: TFDScript;
    SQL, Path: string;
    I: Integer;
    TableCount: Integer;
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
        TableCount := FConn.ExecSQLScalar('SELECT COUNT(*) FROM sqlite_master WHERE type = ''table''');
        if TableCount < 5 then
            raise Exception.Create(Format('Schema script did not apply: tables=%d', [TableCount]));
    finally
        Script.Free;
    end;
end;

procedure TSearchTagsTests.Setup;
begin
    FConn := TFDConnection.Create(nil);
    FConn.Params.Add('DriverID=SQLite');
    FConn.Params.Add('Database=:memory:');
    FConn.Connected := True;
    FConn.ExecSQL('PRAGMA foreign_keys = ON');
    ExecScript(['000_schema_init.sql', '100_migrations.sql']);
    if FConn.ExecSQLScalar('SELECT COUNT(*) FROM sqlite_master WHERE name = ''snippet_fts''') < 1 then
        raise Exception.Create('snippet_fts missing after schema');
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'')');
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (2, ''Second User'')');
    FRepo := TSnippetRepository.Create(FConn);
end;

procedure TSearchTagsTests.TearDown;
begin
    FreeAndNil(FRepo);
    FreeAndNil(FConn);
end;

function TSearchTagsTests.AddSnippet(const Title, Content: string; UserID: Integer): Integer;
begin
    FConn.ExecSQL('INSERT INTO snippets (user_id, title, content) VALUES (?, ?, ?)',
        [UserID, Title, Content]);
    Result := FConn.ExecSQLScalar('SELECT last_insert_rowid()');
end;

procedure TSearchTagsTests.AddTag(SnippetID: Integer; const TagName: string);
begin
    FConn.ExecSQL('INSERT OR IGNORE INTO tags (name) VALUES (?)', [TagName]);
    FConn.ExecSQL('INSERT INTO snippet_tags (snippet_id, tag_id) VALUES (?, ?)',
        [SnippetID, FConn.ExecSQLScalar('SELECT id FROM tags WHERE name = ?', [TagName])]);
end;

procedure TSearchTagsTests.SimpleMask_FindsByTitle;
begin
    AddSnippet('nginx restart', 'systemctl restart nginx');
    Assert.AreEqual(1, Integer(Length(FRepo.SearchByMaskSimple('nginx', 1))));
end;

procedure TSearchTagsTests.SimpleMask_FindsByTag;
var
    ID: Integer;
begin
    ID := AddSnippet('run script', './deploy.sh');
    AddTag(ID, 'deploy-prod');
    Assert.AreEqual(1, Integer(Length(FRepo.SearchByMaskSimple('deploy', 1))));
    Assert.AreEqual(0, Integer(Length(FRepo.SearchByMaskSimple('zzz-nope', 1))));
end;

procedure TSearchTagsTests.SimpleMask_NoMatch_ReturnsEmpty;
begin
    AddSnippet('nginx restart', 'systemctl restart nginx');
    Assert.AreEqual(0, Integer(Length(FRepo.SearchByMaskSimple('apache', 1))));
end;

procedure TSearchTagsTests.SimpleMask_RespectsUserID;
var
    ID1, ID2: Integer;
begin
    ID1 := AddSnippet('user one snippet', 'echo one', 1);
    AddTag(ID1, 'shared-tag');
    ID2 := AddSnippet('user two snippet', 'echo two', 2);
    AddTag(ID2, 'shared-tag');
    Assert.AreEqual(1, Integer(Length(FRepo.SearchByMaskSimple('shared-tag', 1))));
    Assert.AreEqual('user one snippet', FRepo.SearchByMaskSimple('shared-tag', 1)[0].Title);
    Assert.AreEqual(1, Integer(Length(FRepo.SearchByMaskSimple('shared-tag', 2))));
    Assert.AreEqual('user two snippet', FRepo.SearchByMaskSimple('shared-tag', 2)[0].Title);
end;

procedure TSearchTagsTests.AdvancedText_BareWord_FindsByTag;
var
    ID: Integer;
    Found: TArray<TSnippetDTO>;
begin
    ID := AddSnippet('run script', './deploy.sh');
    AddTag(ID, 'deploy-prod');
    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('deploy'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('run script', Found[0].Title);
end;

procedure TSearchTagsTests.AdvancedText_BareWord_StillFindsTitle;
var
    Found: TArray<TSnippetDTO>;
begin
    AddSnippet('nginx restart', 'systemctl restart nginx');
    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('nginx'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
end;

procedure TSearchTagsTests.AdvancedText_Exclusion_ByTag;
var
    DockerID: Integer;
    Found: TArray<TSnippetDTO>;
begin
    DockerID := AddSnippet('docker ps', 'docker ps -a');
    AddTag(DockerID, 'docker');
    AddSnippet('plain script', 'echo hello');
    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('-docker'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('plain script', Found[0].Title);
end;

procedure TSearchTagsTests.AdvancedText_TagFilter_Unchanged;
var
    ID: Integer;
    Found: TArray<TSnippetDTO>;
begin
    ID := AddSnippet('run script', './deploy.sh');
    AddTag(ID, 'deploy-prod');
    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('tag:deploy'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('run script', Found[0].Title);
end;

procedure TSearchTagsTests.AdvancedFTS_BareWord_FindsByTag;
var
    ID: Integer;
    Found: TArray<TSnippetDTO>;
begin
    ID := AddSnippet('run script', './deploy.sh');
    AddTag(ID, 'deploy-prod');
    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('deploy'), True, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('run script', Found[0].Title);
end;

initialization
    GDriverLink := TFDPhysSQLiteDriverLink.Create(nil);

finalization
    GDriverLink.Free;

end.
