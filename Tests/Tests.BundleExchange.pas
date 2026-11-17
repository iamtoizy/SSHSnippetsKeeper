unit Tests.BundleExchange;

interface

uses
    DUnitX.TestFramework,
    Core.Interfaces.App,
    FireDAC.Comp.Client,
    Tests.MarkdownImporter
    ;

type
    TBundleExchangeTests = class(TObject)
    private
        FConn: TFDConnection;
        FDbManager: TTestDatabaseManager;
        FContext: IAppContext;
        FTempDir: string;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test]
        procedure Export_WritesValidBundle;

        [Test]
        procedure RoundTrip_ImportRestoresSnippetWithTagsAndCategory;

        [Test]
        procedure InvalidFormat_Raises;
    end;

implementation

uses
    BundleExchange,
    Core.Entities.Category,
    Core.Entities.Snippet,
    Core.Entities.Tag,
    FireDAC.Comp.Script,
    System.Classes,
    System.IOUtils,
    System.JSON,
    System.SysUtils
    ;

function DbManagerHeld(AMgr: TTestDatabaseManager): Boolean;
begin
    Result := (AMgr <> nil) and (AMgr.RefCount > 0);
end;

function ResolveSchemaPath(const AFilename: string): string;
var
    Dir: string;
begin
    Dir := TPath.GetDirectoryName(ParamStr(0));
    repeat
        Result := TPath.Combine(Dir, TPath.Combine('Database', 'Schema', AFilename));
        if TFile.Exists(Result) then
            Exit;
        Dir := TPath.GetDirectoryName(Dir);
    until Dir = '';
    raise Exception.Create('Schema file not found: ' + Result);
end;

procedure ApplySchema(AConn: TFDConnection);
var
    Script: TFDScript;
begin
    Script := TFDScript.Create(nil);
    try
        Script.Connection := AConn;
        Script.SQLScripts.Add.SQL.Text :=
            TFile.ReadAllText(ResolveSchemaPath('000_schema_init.sql'),
                TEncoding.UTF8);
        Script.ExecuteAll;
    finally
        Script.Free;
    end;
end;

{ TBundleExchangeTests }

procedure TBundleExchangeTests.Setup;
begin
    FTempDir := TPath.Combine(TPath.GetTempPath,
        'ssk_bun_' + TGUID.NewGuid.ToString);
    TDirectory.CreateDirectory(FTempDir);

    FConn := TFDConnection.Create(nil);
    FConn.Params.Add('DriverID=SQLite');
    FConn.Params.Add('Database=:memory:');
    FConn.Connected := True;
    FConn.ExecSQL('PRAGMA foreign_keys = ON');
    ApplySchema(FConn);
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''user1'')');
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (2, ''user2'')');

    FDbManager := TTestDatabaseManager.Create;
    FContext := TTestAppContext.Create(FConn, FDbManager);
end;

procedure TBundleExchangeTests.TearDown;
var
    Held: Boolean;
begin
    Held := DbManagerHeld(FDbManager);
    FContext := nil;
    if Held then
        FDbManager := nil
    else
        FreeAndNil(FDbManager);
    FreeAndNil(FConn);
    if TDirectory.Exists(FTempDir) then
        TDirectory.Delete(FTempDir, True);
end;

procedure TBundleExchangeTests.Export_WritesValidBundle;
var
    Snip: TSnippetDTO;
    Tags: TArray<TTagDTO>;
    FileName, Json: string;
    Parsed: TJSONValue;
    SnipsArr: TJSONArray;
begin
    SetLength(Tags, 1);
    Tags[0] := Default(TTagDTO);
    Tags[0].ID := 7;
    Tags[0].Name := 'linux';

    Snip := Default(TSnippetDTO);
    Snip.Title := 'Test Snippet';
    Snip.Content := 'echo hi';
    Snip.Comment := 'note';
    Snip.Language := 'bash';
    Snip.CreatedAt := 1600000000;
    Snip.Tags := Tags;

    FileName := TPath.Combine(FTempDir, 'bundle.ssk.json');
    Assert.AreEqual<Integer>(1,
        TBundleExchange.ExportBundle(FContext, FileName, [Snip]));
    Assert.IsTrue(TFile.Exists(FileName));

    Json := TFile.ReadAllText(FileName, TEncoding.UTF8);
    Parsed := TJSONObject.ParseJSONValue(Json);
    try
        Assert.IsNotNull(Parsed);
        Assert.AreEqual('ssk-bundle',
            TJSONObject(Parsed).GetValue<string>('format'));
        Assert.IsTrue(TJSONObject(Parsed).TryGetValue<TJSONArray>('snippets', SnipsArr));
        Assert.AreEqual<Integer>(1, SnipsArr.Count);
        Assert.AreEqual('Test Snippet',
            TJSONObject(SnipsArr.Items[0]).GetValue<string>('title'));
        Assert.AreEqual('linux',
            TJSONObject(SnipsArr.Items[0]).GetValue<TJSONArray>('tags').Items[0].Value);
    finally
        Parsed.Free;
    end;
end;

procedure TBundleExchangeTests.RoundTrip_ImportRestoresSnippetWithTagsAndCategory;
var
    Snip: TSnippetDTO;
    NewCat: TCategoryDTO;
    Tags: TArray<TTagDTO>;
    CatID, TagID: Integer;
    FileName: string;
    Res: TBundleImportResult;
    SnippetTags: TArray<TTagDTO>;
    ImportedSnippets: TArray<TSnippetDTO>;
begin
    NewCat := Default(TCategoryDTO);
    NewCat.UserID := 1;
    NewCat.Name := 'Work';
    CatID := FContext.CategoryService.CreateCategory(NewCat);
    Assert.IsTrue(CatID > 0);

    TagID := FContext.TagService.GetOrCreateTag('linux');
    SetLength(Tags, 1);
    Tags[0] := Default(TTagDTO);
    Tags[0].ID := TagID;
    Tags[0].Name := 'linux';

    Snip := Default(TSnippetDTO);
    Snip.Title := 'Shared Script';
    Snip.Content := 'df -h';
    Snip.Comment := 'disk usage';
    Snip.Language := 'bash';
    Snip.CategoryID := CatID;
    Snip.CreatedAt := 1600000000;
    Snip.Tags := Tags;

    FileName := TPath.Combine(FTempDir, 'share.ssk.json');
    TBundleExchange.ExportBundle(FContext, FileName, [Snip]);

    Res := TBundleExchange.ImportBundle(FContext, FileName, 2);
    Assert.AreEqual<Integer>(1, Res.Imported);
    Assert.AreEqual<Integer>(0, Res.Skipped);
    Assert.AreEqual<Integer>(1, Res.CreatedCategories);

    ImportedSnippets := FContext.SnippetService.GetAllSnippets(2);
    Assert.AreEqual<Integer>(1, Length(ImportedSnippets));
    Assert.AreEqual('Shared Script', ImportedSnippets[0].Title);
    Assert.AreEqual('df -h', ImportedSnippets[0].Content);
    Assert.AreEqual('Work',
        FContext.CategoryService.GetCategoryByID(
            ImportedSnippets[0].CategoryID).Name);
    Assert.AreEqual('bash', ImportedSnippets[0].Language);

    SnippetTags := FContext.TagService.GetSnippetTags(ImportedSnippets[0].ID);
    Assert.AreEqual<Integer>(1, Length(SnippetTags));
    Assert.AreEqual('linux', SnippetTags[0].Name);

    Res := TBundleExchange.ImportBundle(FContext, FileName, 2);
    Assert.AreEqual<Integer>(0, Res.Imported);
    Assert.AreEqual<Integer>(1, Res.Skipped);
end;

procedure TBundleExchangeTests.InvalidFormat_Raises;
var
    FileName: string;
begin
    FileName := TPath.Combine(FTempDir, 'bad.ssk.json');
    TFile.WriteAllText(FileName, '{"format":"other","snippets":[]}', TEncoding.UTF8);
    Assert.WillRaise(
        procedure
        begin
            TBundleExchange.ImportBundle(FContext, FileName, 2);
        end,
        Exception);
end;

end.
