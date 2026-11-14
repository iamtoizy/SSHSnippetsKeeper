unit Tests.CompletionEngine;

interface

uses
    DUnitX.TestFramework,
    System.Classes,
    System.IOUtils,
    System.SysUtils
    ;

type
    [TestFixture]
    TCompletionEngineTests = class(TObject)
    private
        FTempDir: string;
        function WriteJson(const AJson: string): string;
        procedure Cleanup;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test]
        procedure Load_UnifiedFile_SectionsSplit;
        [Test]
        procedure Load_LegacyFormat_MapsToBash;
        [Test]
        procedure SetLanguage_FillProposals_PerSection;
        [Test]
        procedure FillProposals_TreeContext;
        [Test]
        procedure FillProposals_UnknownContext_Fails;
        [Test]
        procedure ExportKeywords_ActiveSection;
        [Test]
        procedure SaveToJsonFile_Roundtrip;
    end;

implementation

uses
    Core.CompletionEngine,
    Common.SnippetLanguages,
    System.JSON
    ;

{ TCompletionEngineTests }

procedure TCompletionEngineTests.Setup;
begin
    FTempDir := TPath.Combine(TPath.GetTempPath, 'SSKTests_' + TGUID.NewGuid.ToString);
    TDirectory.CreateDirectory(FTempDir);
end;

procedure TCompletionEngineTests.TearDown;
begin
    Cleanup;
end;

procedure TCompletionEngineTests.Cleanup;
begin
    if TDirectory.Exists(FTempDir) then
        TDirectory.Delete(FTempDir, True);
end;

function TCompletionEngineTests.WriteJson(const AJson: string): string;
begin
    Result := TPath.Combine(FTempDir, 'autocomplete.json');
    TFile.WriteAllText(Result, AJson, TEncoding.UTF8);
end;

procedure TCompletionEngineTests.Load_UnifiedFile_SectionsSplit;
var
    Engine: TCompletionEngine;
    Path: string;
begin
    Path := WriteJson(
        '{"version":2,' +
        '"bash":{"completion":{"commands":["ls","grep"]}},' +
        '"bat":{"completion":{"commands":["dir","copy"]}},' +
        '"powershell":{"completion":{"commands":["Get-ChildItem"]}}}');

    Engine := TCompletionEngine.Create;
    try
        Engine.LoadFromJsonFile(Path);

        Assert.IsTrue(Engine.SectionExists('bash'));
        Assert.IsTrue(Engine.SectionExists('bat'));
        Assert.IsTrue(Engine.SectionExists('powershell'));
        Assert.AreEqual(2, Engine.GetSectionCommands('bash').Count);
        // Список команд хранится отсортированным: порядок не проверяем
        Assert.IsTrue(Engine.GetSectionCommands('bat').IndexOf('dir') >= 0);
        Assert.IsTrue(Engine.GetSectionCommands('bat').IndexOf('copy') >= 0);
        Assert.IsTrue(Engine.GetSectionCommands('powershell').IndexOf('Get-ChildItem') >= 0);
    finally
        Engine.Free;
    end;
end;

procedure TCompletionEngineTests.Load_LegacyFormat_MapsToBash;
var
    Engine: TCompletionEngine;
    Path: string;
begin
    Path := WriteJson(
        '{"version":1,"language":"bash","completion":{"commands":["ls","grep"]}}');

    Engine := TCompletionEngine.Create;
    try
        Engine.LoadFromJsonFile(Path);

        Assert.IsTrue(Engine.SectionExists('bash'));
        Assert.IsFalse(Engine.SectionExists('bat'));
        Assert.AreEqual(2, Engine.GetSectionCommands('bash').Count);
    finally
        Engine.Free;
    end;
end;

procedure TCompletionEngineTests.SetLanguage_FillProposals_PerSection;
var
    Engine: TCompletionEngine;
    Path: string;
    Items, Inserts: TStringList;
    CanExecute: Boolean;
begin
    Path := WriteJson(
        '{"version":2,' +
        '"bash":{"completion":{"commands":["ls","grep"]}},' +
        '"bat":{"completion":{"commands":["dir","copy"]}}}');

    Engine := TCompletionEngine.Create;
    Items := TStringList.Create;
    Inserts := TStringList.Create;
    try
        Engine.LoadFromJsonFile(Path);

        Engine.SetLanguage(SNIPPET_LANG_BASH);
        CanExecute := True;
        Engine.FillProposals('', Items, Inserts, CanExecute);
        Assert.IsTrue(CanExecute);
        Assert.AreEqual(2, Items.Count);
        Assert.IsTrue(Items.IndexOf('ls') >= 0);

        Engine.SetLanguage(SNIPPET_LANG_BAT);
        CanExecute := True;
        Engine.FillProposals('', Items, Inserts, CanExecute);
        Assert.IsTrue(CanExecute);
        Assert.AreEqual(2, Items.Count);
        Assert.IsTrue(Items.IndexOf('dir') >= 0);

        Engine.SetLanguage('CMD');
        CanExecute := True;
        Engine.FillProposals('', Items, Inserts, CanExecute);
        Assert.IsTrue(Items.IndexOf('copy') >= 0);

        Engine.SetLanguage('python');
        CanExecute := True;
        Engine.FillProposals('', Items, Inserts, CanExecute);
        Assert.IsTrue(Items.IndexOf('ls') >= 0);
    finally
        Items.Free;
        Inserts.Free;
        Engine.Free;
    end;
end;

procedure TCompletionEngineTests.FillProposals_TreeContext;
var
    Engine: TCompletionEngine;
    Path: string;
    Items, Inserts: TStringList;
    CanExecute: Boolean;
begin
    Path := WriteJson(
        '{"version":2,' +
        '"bash":{"completion":{"commands":["ls"],' +
        '"tree":{"docker":{"insert":"docker ","children":' +
        '{"ps":{"insert":"docker ps"},"compose":{"insert":"docker compose"}}}}}}}');

    Engine := TCompletionEngine.Create;
    Items := TStringList.Create;
    Inserts := TStringList.Create;
    try
        Engine.LoadFromJsonFile(Path);

        Engine.SetLanguage(SNIPPET_LANG_BASH);
        CanExecute := True;
        Engine.FillProposals('docker ', Items, Inserts, CanExecute);
        Assert.IsTrue(CanExecute);
        Assert.AreEqual(2, Items.Count);
        Assert.IsTrue(Items.IndexOf('ps') >= 0);
        Assert.AreEqual('docker ps', Inserts[Items.IndexOf('ps')]);
    finally
        Items.Free;
        Inserts.Free;
        Engine.Free;
    end;
end;

procedure TCompletionEngineTests.FillProposals_UnknownContext_Fails;
var
    Engine: TCompletionEngine;
    Path: string;
    Items, Inserts: TStringList;
    CanExecute: Boolean;
begin
    Path := WriteJson(
        '{"version":2,"bash":{"completion":{"commands":["ls"]}}}');

    Engine := TCompletionEngine.Create;
    Items := TStringList.Create;
    Inserts := TStringList.Create;
    try
        Engine.LoadFromJsonFile(Path);
        Engine.SetLanguage(SNIPPET_LANG_BASH);

        CanExecute := True;
        Engine.FillProposals('unknowncmd ', Items, Inserts, CanExecute);
        Assert.IsFalse(CanExecute);
        Assert.AreEqual(0, Items.Count);
    finally
        Items.Free;
        Inserts.Free;
        Engine.Free;
    end;
end;

procedure TCompletionEngineTests.ExportKeywords_ActiveSection;
var
    Engine: TCompletionEngine;
    Path: string;
    Keywords: TStringList;
begin
    Path := WriteJson(
        '{"version":2,' +
        '"bash":{"completion":{"commands":["ls","grep","--help"],' +
        '"tree":{"docker":{"insert":"docker "}}}},' +
        '"bat":{"completion":{"commands":["dir"]}}}');

    Engine := TCompletionEngine.Create;
    Keywords := TStringList.Create;
    try
        Engine.LoadFromJsonFile(Path);
        Engine.SetLanguage(SNIPPET_LANG_BASH);
        Engine.ExportKeywords(Keywords);

        Assert.IsTrue(Keywords.IndexOf('ls') >= 0);
        Assert.IsTrue(Keywords.IndexOf('grep') >= 0);
        Assert.IsTrue(Keywords.IndexOf('docker') >= 0);
        Assert.AreEqual(-1, Keywords.IndexOf('--help'));
        Assert.AreEqual(-1, Keywords.IndexOf('dir'));
    finally
        Keywords.Free;
        Engine.Free;
    end;
end;

procedure TCompletionEngineTests.SaveToJsonFile_Roundtrip;
var
    Engine, Reloaded: TCompletionEngine;
    SourcePath, SavedPath: string;
    Items, Inserts: TStringList;
    CanExecute: Boolean;
    Tree: TCommandNode;
begin
    SourcePath := WriteJson(
        '{"version":2,' +
        '"bash":{"completion":{"commands":["ls","grep"]}},' +
        '"bat":{"completion":{"commands":["dir"],' +
        '"tree":{"mkdir":{"insert":"mkdir "}}}}}');

    SavedPath := TPath.Combine(FTempDir, 'saved.json');

    Engine := TCompletionEngine.Create;
    try
        Engine.LoadFromJsonFile(SourcePath);
        Engine.SaveToJsonFile(SavedPath);
    finally
        Engine.Free;
    end;

    Reloaded := TCompletionEngine.Create;
    Items := TStringList.Create;
    Inserts := TStringList.Create;
    try
        Reloaded.LoadFromJsonFile(SavedPath);

        Assert.AreEqual(2, Reloaded.GetSectionCommands('bash').Count);
        Assert.AreEqual(1, Reloaded.GetSectionCommands('bat').Count);

        Tree := Reloaded.GetSectionTree('bat');
        Assert.IsNotNull(Tree);
        Assert.IsTrue(Tree.SubCommands.ContainsKey('mkdir'));

        Reloaded.SetLanguage(SNIPPET_LANG_BAT);
        // Частичное слово: контекст - корень, предложения = команды + корневые
        // узлы дерева (dir, mkdir); фильтрацию делает SynCompletionProposal
        CanExecute := True;
        Reloaded.FillProposals('mkdi', Items, Inserts, CanExecute);
        Assert.IsTrue(CanExecute);
        Assert.AreEqual(2, Items.Count);
        Assert.IsTrue(Items.IndexOf('mkdir') >= 0);
        // Полное слово без детей и команд: предложений нет
        CanExecute := True;
        Reloaded.FillProposals('mkdir ', Items, Inserts, CanExecute);
        Assert.IsFalse(CanExecute);
        Assert.AreEqual(0, Items.Count);
    finally
        Items.Free;
        Inserts.Free;
        Reloaded.Free;
    end;
end;

end.
