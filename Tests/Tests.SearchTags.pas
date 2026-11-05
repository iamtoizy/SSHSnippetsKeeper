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
        function AddSnippet(const Title, Content: string; UserID: Integer = 1;
            const Language: string = ''): Integer;
        procedure AddTag(SnippetID: Integer; const TagName: string);
        procedure SetDates(SnippetID: Integer; CreatedAt, UpdatedAt: Int64);
        procedure AddFavorite(SnippetID: Integer; UserID: Integer);
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
        [Test]
        procedure LanguageLocked_RoundTrip;
        [Test]
        procedure Advanced_LangFilter_SimpleAndFTS;
        [Test]
        procedure Advanced_ContentFilter_NotTitle;
        [Test]
        procedure Advanced_ContentPhrase;
        [Test]
        procedure Advanced_TitlePhrase_Simple;
        [Test]
        procedure AdvancedFTS_BarePhrase;
        [Test]
        procedure AdvancedFTS_ExcludedPhrase;
        [Test]
        procedure Advanced_DateFilters;
        [Test]
        procedure Advanced_ExcludeFavorites;
    end;

implementation

uses
    System.SysUtils,
    System.DateUtils,
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
    ExecScript(['000_schema_init.sql']);
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

function TSearchTagsTests.AddSnippet(const Title, Content: string; UserID: Integer;
    const Language: string): Integer;
begin
    FConn.ExecSQL('INSERT INTO snippets (user_id, title, content) VALUES (?, ?, ?)',
        [UserID, Title, Content]);
    Result := FConn.ExecSQLScalar('SELECT last_insert_rowid()');
    if Language <> '' then
        FConn.ExecSQL('UPDATE snippets SET language = ? WHERE id = ?', [Language, Result]);
end;

procedure TSearchTagsTests.AddTag(SnippetID: Integer; const TagName: string);
begin
    FConn.ExecSQL('INSERT OR IGNORE INTO tags (name) VALUES (?)', [TagName]);
    FConn.ExecSQL('INSERT INTO snippet_tags (snippet_id, tag_id) VALUES (?, ?)',
        [SnippetID, FConn.ExecSQLScalar('SELECT id FROM tags WHERE name = ?', [TagName])]);
end;

procedure TSearchTagsTests.SetDates(SnippetID: Integer; CreatedAt, UpdatedAt: Int64);
begin
    FConn.ExecSQL('UPDATE snippets SET created_at = ?, updated_at = ? WHERE id = ?',
        [CreatedAt, UpdatedAt, SnippetID]);
end;

procedure TSearchTagsTests.AddFavorite(SnippetID: Integer; UserID: Integer);
begin
    FConn.ExecSQL('INSERT OR IGNORE INTO snippet_favorites (user_id, snippet_id) VALUES (?, ?)',
        [UserID, SnippetID]);
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

procedure TSearchTagsTests.LanguageLocked_RoundTrip;
var
    Snippet, Loaded: TSnippetDTO;
    ID: Integer;
begin
    FConn.ExecSQL('INSERT OR IGNORE INTO snippet_categories (id, user_id, name) VALUES (1, 1, ''General'')');

    Snippet := Default(TSnippetDTO);
    Snippet.UserID := 1;
    Snippet.CategoryID := 1;
    Snippet.Title := 'locked language';
    Snippet.Content := 'Get-Service | Where-Object { $_.Status -eq ''Running'' }';
    Snippet.Language := 'powershell';
    Snippet.LanguageLocked := True;
    Snippet.CreatedAt := 1700000000;

    ID := FRepo.Add(Snippet);
    try
        Loaded := FRepo.GetById(ID);
        Assert.AreEqual('powershell', Loaded.Language);
        Assert.IsTrue(Loaded.LanguageLocked);

        Loaded.Language := 'bat';
        Loaded.LanguageLocked := False;
        FRepo.Update(Loaded);

        Loaded := FRepo.GetById(ID);
        Assert.AreEqual('bat', Loaded.Language);
        Assert.IsFalse(Loaded.LanguageLocked);
    finally
        FConn.ExecSQL('DELETE FROM snippets WHERE id = ?', [ID]);
    end;
end;

procedure TSearchTagsTests.Advanced_LangFilter_SimpleAndFTS;
var
    Found: TArray<TSnippetDTO>;
begin
    AddSnippet('ps helper', 'Get-Service check', 1, 'powershell');
    AddSnippet('bash helper', 'ls -la', 1, 'bash');
    AddSnippet('bat helper', 'dir /w', 1, 'batch');

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('lang:powershell'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('ps helper', Found[0].Title);

    // Несколько lang: - достаточно любого
    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('lang:powershell lang:batch'), False, 1);
    Assert.AreEqual(2, Integer(Length(Found)));

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('lang:zzz'), False, 1);
    Assert.AreEqual(0, Integer(Length(Found)));

    // FTS-режим: язык + полнотекстовое слово
    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('lang:powershell service'), True, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('ps helper', Found[0].Title);
end;

procedure TSearchTagsTests.Advanced_ContentFilter_NotTitle;
var
    Found: TArray<TSnippetDTO>;
begin
    // Слово только в заголовке - content: не должно находить
    AddSnippet('systemctl helper', 'nothing here', 1);
    AddSnippet('plain', 'systemctl restart nginx', 1);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('content:systemctl'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('plain', Found[0].Title);

    // Для сравнения: голое слово ищет и по заголовку
    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('systemctl'), False, 1);
    Assert.AreEqual(2, Integer(Length(Found)));

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('content:systemctl'), True, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('plain', Found[0].Title);
end;

procedure TSearchTagsTests.Advanced_ContentPhrase;
var
    Found: TArray<TSnippetDTO>;
begin
    AddSnippet('compose up', 'docker compose up -d', 1);
    AddSnippet('compose down', 'docker compose down', 1);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('content:"compose up"'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('compose up', Found[0].Title);
end;

procedure TSearchTagsTests.Advanced_TitlePhrase_Simple;
var
    Found: TArray<TSnippetDTO>;
begin
    AddSnippet('nginx config backup', 'echo one', 1);
    AddSnippet('config nginx backup', 'echo two', 1);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('title:"nginx config"'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('nginx config backup', Found[0].Title);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('"config backup"'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('nginx config backup', Found[0].Title);
end;

procedure TSearchTagsTests.AdvancedFTS_BarePhrase;
var
    ID: Integer;
    Found: TArray<TSnippetDTO>;
begin
    ID := AddSnippet('run script', './deploy.sh');
    AddTag(ID, 'deploy-prod');

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('"run script"'), True, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('run script', Found[0].Title);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('"script run"'), True, 1);
    Assert.AreEqual(0, Integer(Length(Found)));
end;

procedure TSearchTagsTests.AdvancedFTS_ExcludedPhrase;
var
    Found: TArray<TSnippetDTO>;
begin
    AddSnippet('docker ps listing', 'docker ps -a', 1);
    AddSnippet('plain script', 'echo hello', 1);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('"docker ps"'), True, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('docker ps listing', Found[0].Title);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('-"docker ps"'), True, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('plain script', Found[0].Title);
end;

procedure TSearchTagsTests.Advanced_DateFilters;
var
    IDA, IDB: Integer;
    Found: TArray<TSnippetDTO>;
begin
    // Даты задаются локальным epoch - тест не зависит от часового пояса
    IDA := AddSnippet('old snippet', 'echo old');
    IDB := AddSnippet('new snippet', 'echo new');
    SetDates(IDA,
        DateTimeToUnix(EncodeDate(2024, 3, 15), False),
        DateTimeToUnix(EncodeDate(2024, 3, 16), False));
    SetDates(IDB,
        DateTimeToUnix(EncodeDate(2025, 7, 2), False),
        DateTimeToUnix(EncodeDate(2025, 7, 3), False));

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('created:2024-03-15'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('old snippet', Found[0].Title);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('created:>=2025-01-01'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('new snippet', Found[0].Title);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('created:<2025-01-01'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('old snippet', Found[0].Title);

    // Целый месяц по updated_at
    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('updated:2025-07'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('new snippet', Found[0].Title);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('created:2024-03-20'), False, 1);
    Assert.AreEqual(0, Integer(Length(Found)));
end;

procedure TSearchTagsTests.Advanced_ExcludeFavorites;
var
    FavID, PlainID, OtherID: Integer;
    Found: TArray<TSnippetDTO>;
begin
    // Оба сниппета пользователя 1 содержат "fav" в тексте: если бы -fav
    // исключал слово, а не работал флагом, остались бы 0 строк
    FavID := AddSnippet('my fav command', 'echo favorite', 1);
    PlainID := AddSnippet('plain script', 'echo my fav', 1);
    OtherID := AddSnippet('other script', 'echo other', 2);
    AddFavorite(FavID, 1);
    AddFavorite(OtherID, 2);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('fav'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('my fav command', Found[0].Title);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('-fav'), False, 1);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('plain script', Found[0].Title);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('fav'), False, 2);
    Assert.AreEqual(1, Integer(Length(Found)));
    Assert.AreEqual('other script', Found[0].Title);

    Found := FRepo.SearchAdvanced(TQueryLanguageParser.Parse('-fav'), False, 2);
    Assert.AreEqual(0, Integer(Length(Found)));
end;

end.
