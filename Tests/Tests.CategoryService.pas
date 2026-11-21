unit Tests.CategoryService;

interface

uses
    DUnitX.TestFramework,
    Core.Entities.Category,
    Core.Entities.Snippet,
    Core.Entities.Tag,
    Core.Interfaces.App,
    FireDAC.Comp.Client,
    Tests.MarkdownImporter;

type
    TCategoryServiceTests = class(TObject)
    private
        FConn: TFDConnection;
        FDbManager: TTestDatabaseManager;
        FContext: IAppContext;
        FTempDir: string;
        function MakeCategory(AUserID: Integer; const AName: string;
            AParentID: Integer = 0): TCategoryDTO;
        function MakeSnippet(const ATitle, AContent: string): TSnippetDTO;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test]
        procedure MoveCategory_IntoOwnDescendant_Raises;

        [Test]
        procedure MoveCategory_DirectChildOfItself_Raises;

        [Test]
        procedure MoveCategory_LegalMove_Succeeds;

        [Test]
        procedure CreateCategory_DuplicateInParent_Raises;

        [Test]
        procedure CreateCategory_DuplicateCaseInsensitive_Raises;

        [Test]
        procedure RenameCategory_DuplicateInParent_Raises;

        [Test]
        procedure RenameCategory_SameNameOtherCase_Allowed;

        [Test]
        procedure RenameTag_ToExistingName_Raises;

        [Test]
        procedure RenameTag_ToOtherCaseOfSelf_Allowed;

        [Test]
        procedure RenameTag_CaseRename_KeepsSnippetLinks;

        [Test]
        procedure ImportBundle_SnippetWithoutCategory_Skipped;

        [Test]
        procedure ImportBundle_ExistingCategoryOtherCase_MatchesNocase;

        [Test]
        procedure ImportBundle_UpdatedAt_FallbackToCreatedAt;
    end;

implementation

uses
    BundleExchange,
    Common.Localization,
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

function TranslationPath: string;
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

{ TCategoryServiceTests }

procedure TCategoryServiceTests.Setup;
begin
    // Тексты исключений сервисов берутся из локализации
    TUIStateLoader.LoadLanguageFile(TranslationPath);

    FTempDir := TPath.Combine(TPath.GetTempPath,
        'ssk_catsvc_' + TGUID.NewGuid.ToString);
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

procedure TCategoryServiceTests.TearDown;
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

function TCategoryServiceTests.MakeCategory(AUserID: Integer; const AName: string;
    AParentID: Integer): TCategoryDTO;
begin
    Result := Default(TCategoryDTO);
    Result.UserID := AUserID;
    Result.Name := AName;
    Result.ParentID := AParentID;
end;

function TCategoryServiceTests.MakeSnippet(const ATitle, AContent: string): TSnippetDTO;
begin
    Result := Default(TSnippetDTO);
    Result.Title := ATitle;
    Result.Content := AContent;
    Result.Language := 'bash';
    Result.CreatedAt := 1600000000;
end;

procedure TCategoryServiceTests.MoveCategory_IntoOwnDescendant_Raises;
var
    ParentID, ChildID: Integer;
begin
    ParentID := FContext.CategoryService.CreateCategory(MakeCategory(1, 'Root'));
    ChildID := FContext.CategoryService.CreateCategory(
        MakeCategory(1, 'Child', ParentID));

    Assert.WillRaise(
        procedure
        begin
            FContext.CategoryService.MoveCategory(ParentID, ChildID, 0);
        end,
        Exception);
end;

procedure TCategoryServiceTests.MoveCategory_DirectChildOfItself_Raises;
var
    ParentID: Integer;
begin
    ParentID := FContext.CategoryService.CreateCategory(MakeCategory(1, 'Root'));

    Assert.WillRaise(
        procedure
        begin
            FContext.CategoryService.MoveCategory(ParentID, ParentID, 0);
        end,
        Exception);
end;

procedure TCategoryServiceTests.MoveCategory_LegalMove_Succeeds;
var
    ParentID, ChildID, SiblingID: Integer;
begin
    ParentID := FContext.CategoryService.CreateCategory(MakeCategory(1, 'Root'));
    ChildID := FContext.CategoryService.CreateCategory(
        MakeCategory(1, 'Child', ParentID));
    SiblingID := FContext.CategoryService.CreateCategory(MakeCategory(1, 'Sibling'));

    FContext.CategoryService.MoveCategory(ChildID, SiblingID, 0);

    Assert.AreEqual(SiblingID,
        FContext.CategoryService.GetCategoryByID(ChildID).ParentID);
end;

procedure TCategoryServiceTests.CreateCategory_DuplicateInParent_Raises;
begin
    FContext.CategoryService.CreateCategory(MakeCategory(1, 'Work'));

    Assert.WillRaise(
        procedure
        begin
            FContext.CategoryService.CreateCategory(MakeCategory(1, 'Work'));
        end,
        Exception);
end;

procedure TCategoryServiceTests.CreateCategory_DuplicateCaseInsensitive_Raises;
begin
    FContext.CategoryService.CreateCategory(MakeCategory(1, 'Work'));

    Assert.WillRaise(
        procedure
        begin
            FContext.CategoryService.CreateCategory(MakeCategory(1, 'WORK'));
        end,
        Exception);
end;

procedure TCategoryServiceTests.RenameCategory_DuplicateInParent_Raises;
var
    CatID: Integer;
begin
    CatID := FContext.CategoryService.CreateCategory(MakeCategory(1, 'Alpha'));
    FContext.CategoryService.CreateCategory(MakeCategory(1, 'Beta'));

    Assert.WillRaise(
        procedure
        begin
            FContext.CategoryService.RenameCategory(CatID, 'Beta');
        end,
        Exception);
    Assert.AreEqual('Alpha',
        FContext.CategoryService.GetCategoryByID(CatID).Name);
end;

procedure TCategoryServiceTests.RenameCategory_SameNameOtherCase_Allowed;
var
    CatID: Integer;
begin
    CatID := FContext.CategoryService.CreateCategory(MakeCategory(1, 'Alpha'));

    FContext.CategoryService.RenameCategory(CatID, 'ALPHA');

    Assert.AreEqual('ALPHA',
        FContext.CategoryService.GetCategoryByID(CatID).Name);
end;

procedure TCategoryServiceTests.RenameTag_ToExistingName_Raises;
var
    TagID: Integer;
begin
    TagID := FContext.TagService.CreateTag('linux');
    FContext.TagService.CreateTag('docker');

    Assert.WillRaise(
        procedure
        begin
            FContext.TagService.RenameTag(TagID, 'docker');
        end,
        Exception);
end;

procedure TCategoryServiceTests.RenameTag_ToOtherCaseOfSelf_Allowed;
var
    TagID: Integer;
begin
    TagID := FContext.TagService.CreateTag('linux');

    FContext.TagService.RenameTag(TagID, 'LINUX');

    Assert.AreEqual('LINUX',
        FContext.TagService.GetAllTags[0].Name);
end;

procedure TCategoryServiceTests.RenameTag_CaseRename_KeepsSnippetLinks;
var
    Snip: TSnippetDTO;
    SnipID, TagID, CatID: Integer;
    Tags: TArray<TTagDTO>;
    SnippetTags: TArray<TTagDTO>;
begin
    CatID := FContext.CategoryService.CreateCategory(MakeCategory(1, 'Root'));
    TagID := FContext.TagService.CreateTag('linux');

    Snip := MakeSnippet('T1', 'c1');
    Snip.UserID := 1;
    Snip.CategoryID := CatID;
    SetLength(Tags, 1);
    Tags[0] := Default(TTagDTO);
    Tags[0].ID := TagID;
    Tags[0].Name := 'linux';
    Snip.Tags := Tags;
    SnipID := FContext.SnippetService.CreateSnippet(Snip, [TagID]);

    FContext.TagService.RenameTag(TagID, 'LINUX');

    SnippetTags := FContext.TagService.GetSnippetTags(SnipID);
    Assert.AreEqual<Integer>(1, Length(SnippetTags));
    Assert.AreEqual('LINUX', SnippetTags[0].Name);
end;

procedure TCategoryServiceTests.ImportBundle_SnippetWithoutCategory_Skipped;
var
    FileName, Json: string;
    Res: TBundleImportResult;
begin
    Json :=
        '{"format":"ssk-bundle","version":1,"snippets":[' +
        '{"title":"NoCat","content":"ls -la"},' +
        '{"title":"WithCat","content":"ls -l","category":"Imported"}]}';
    FileName := TPath.Combine(FTempDir, 'nocat.ssk.json');
    TFile.WriteAllText(FileName, Json, TEncoding.UTF8);

    Res := TBundleExchange.ImportBundle(FContext, FileName, 2);

    Assert.AreEqual<Integer>(1, Res.Imported);
    Assert.AreEqual<Integer>(1, Res.Skipped);
end;

procedure TCategoryServiceTests.ImportBundle_ExistingCategoryOtherCase_MatchesNocase;
var
    FileName: string;
    Res: TBundleImportResult;
    Imported: TArray<TSnippetDTO>;
begin
    FContext.CategoryService.CreateCategory(MakeCategory(2, 'Shared'));

    FileName := TPath.Combine(FTempDir, 'catcase.ssk.json');
    TFile.WriteAllText(FileName,
        '{"format":"ssk-bundle","version":1,"snippets":[' +
        '{"title":"Cased","content":"echo 1","category":"SHARED"}]}',
        TEncoding.UTF8);

    Res := TBundleExchange.ImportBundle(FContext, FileName, 2);

    Assert.AreEqual<Integer>(1, Res.Imported);
    Imported := FContext.SnippetService.GetAllSnippets(2);
    Assert.AreEqual<Integer>(1, Length(Imported));
    Assert.AreEqual('Shared',
        FContext.CategoryService.GetCategoryByID(Imported[0].CategoryID).Name);
end;

procedure TCategoryServiceTests.ImportBundle_UpdatedAt_FallbackToCreatedAt;
var
    FileName: string;
    Res: TBundleImportResult;
    Imported: TArray<TSnippetDTO>;
begin
    FileName := TPath.Combine(FTempDir, 'upd.ssk.json');
    TFile.WriteAllText(FileName,
        '{"format":"ssk-bundle","version":1,"snippets":[' +
        '{"title":"Dates","content":"echo 1","category":"C","createdAt":1600000000}]}',
        TEncoding.UTF8);

    Res := TBundleExchange.ImportBundle(FContext, FileName, 2);

    Assert.AreEqual<Integer>(1, Res.Imported);
    Imported := FContext.SnippetService.GetAllSnippets(2);
    Assert.AreEqual<Integer>(1, Length(Imported));
    Assert.AreEqual<Int64>(1600000000, Imported[0].CreatedAt);
    Assert.AreEqual<Int64>(1600000000, Imported[0].UpdatedAt);
end;

end.
