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
        procedure FillProposals_GitCommitContext_BuiltinFlags;
        [Test]
        procedure FillProposals_CustomProvider_MergeAndDedup;
        [Test]
        procedure ExportKeywords_ActiveSection;
        [Test]
        procedure SaveToJsonFile_Roundtrip;
        [Test]
        procedure Import_SelectedMerge_SubtreeAndCommands;
        [Test]
        procedure Import_ReplaceMode_ReplacesSelectedOnly;
        [Test]
        procedure Import_NothingSelected_Noop;
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

procedure TCompletionEngineTests.FillProposals_GitCommitContext_BuiltinFlags;
var
    Engine: TCompletionEngine;
    Path: string;
    Items, Inserts: TStringList;
    CanExecute: Boolean;
begin
    // В дереве есть только git без детей: git-флаги дают встроенные
    // провайдеры второго уровня
    Path := WriteJson(
        '{"version":2,"bash":{"completion":{"commands":["ls"],' +
        '"tree":{"git":{"insert":"git "}}}}}');

    Engine := TCompletionEngine.Create;
    Items := TStringList.Create;
    Inserts := TStringList.Create;
    try
        Engine.LoadFromJsonFile(Path);
        Engine.SetLanguage(SNIPPET_LANG_BASH);

        CanExecute := True;
        Engine.FillProposals('git commit ', Items, Inserts, CanExecute);
        Assert.IsTrue(CanExecute);
        Assert.IsTrue(Items.IndexOf('--amend') >= 0);
        Assert.IsTrue(Items.IndexOf('-m') >= 0);
        Assert.AreEqual('--amend ', Inserts[Items.IndexOf('--amend')]);

        // Частичное слово в контексте commit: провайдер тоже срабатывает
        Items.Clear;
        CanExecute := True;
        Engine.FillProposals('git commit --am', Items, Inserts, CanExecute);
        Assert.IsTrue(CanExecute);
        Assert.IsTrue(Items.IndexOf('--amend') >= 0);
    finally
        Inserts.Free;
        Items.Free;
        Engine.Free;
    end;
end;

procedure TCompletionEngineTests.FillProposals_CustomProvider_MergeAndDedup;
var
    Engine: TCompletionEngine;
    Path: string;
    Items, Inserts: TStringList;
    CanExecute: Boolean;
begin
    Path := WriteJson(
        '{"version":2,"bash":{"completion":{"commands":["ls"],' +
        '"tree":{"docker":{"insert":"docker ","children":' +
        '{"ps":{"insert":"docker ps"},"compose":{"insert":"docker compose"}}}}}}}');

    Engine := TCompletionEngine.Create;
    Items := TStringList.Create;
    Inserts := TStringList.Create;
    try
        Engine.LoadFromJsonFile(Path);
        Engine.SetLanguage(SNIPPET_LANG_BASH);

        Engine.RegisterContextProvider('bash', ['docker'],
            procedure(AItems, AInserts: TStrings)
            begin
                AItems.Add('ps');
                AInserts.Add('docker ps');
                AItems.Add('extra');
                AInserts.Add('docker extra');
            end);

        // Дерево даёт ps/compose, провайдер - ps (дубликат) и extra;
        // порядок итерации словаря не гарантирован, проверяем состав
        CanExecute := True;
        Engine.FillProposals('docker ', Items, Inserts, CanExecute);
        Assert.IsTrue(CanExecute);
        Assert.AreEqual(3, Items.Count);
        Assert.IsTrue(Items.IndexOf('ps') >= 0);
        Assert.IsTrue(Items.IndexOf('compose') >= 0);
        Assert.IsTrue(Items.IndexOf('extra') >= 0);

        // Неизвестный дереву контекст: предложения даёт только провайдер
        Engine.RegisterContextProvider('bash', ['mytool', 'sub'],
            procedure(AItems, AInserts: TStrings)
            begin
                AItems.Add('alpha');
                AInserts.Add('mytool sub alpha');
            end);

        Items.Clear;
        CanExecute := True;
        Engine.FillProposals('mytool sub ', Items, Inserts, CanExecute);
        Assert.IsTrue(CanExecute);
        Assert.AreEqual(1, Items.Count);
        Assert.AreEqual('alpha', Items[0]);
    finally
        Inserts.Free;
        Items.Free;
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

procedure TCompletionEngineTests.Import_SelectedMerge_SubtreeAndCommands;
var
    Engine: TCompletionEngine;
    Path, ImportJson: string;
    ImportObj: TJSONObject;
    Tree: TCommandNode;
    Imported: Integer;
begin
    // Текущие данные: git с поддеревом commit, docker - не трогаем;
    // импорт: git с новым insert для commit и ребенком push + плоские команды
    Path := WriteJson(
        '{"version":2,"bash":{"completion":{"commands":["ls"],' +
        '"tree":{"git":{"insert":"git ","children":{"commit":{"insert":"git commit"}}},' +
        '"docker":{"insert":"docker ","children":{"ps":{"insert":"docker ps"}}}}}}}');

    ImportJson :=
        '{"commands":["git","ls"],' +
        '"tree":{"git":{"insert":"git ","children":' +
        '{"commit":{"insert":"git commit -m "},"push":{"insert":"git push "}}},' +
        '"kubectl":{"insert":"kubectl "}}}';

    Engine := TCompletionEngine.Create;
    try
        Engine.LoadFromJsonFile(Path);
        ImportObj := TJSONObject.ParseJSONValue(ImportJson) as TJSONObject;
        try
            Imported := Engine.ImportSectionCompletion('bash', ImportObj, ['git'], False);
        finally
            ImportObj.Free;
        end;

        Assert.AreEqual(1, Imported);

        // Merge: insert импорта выиграл, новый ребенок добавлен
        Tree := Engine.GetSectionTree('bash');
        Assert.IsTrue(Tree.SubCommands.ContainsKey('git'));
        Assert.AreEqual('git commit -m ', Tree.SubCommands['git'].SubCommands['commit'].InsertText);
        Assert.IsTrue(Tree.SubCommands['git'].SubCommands.ContainsKey('push'));
        // Не выбранный корень kubectl не импортирован, docker не тронут
        Assert.IsFalse(Tree.SubCommands.ContainsKey('kubectl'));
        Assert.IsTrue(Tree.SubCommands.ContainsKey('docker'));
        // Плоская команда git добавлена, ls не задублирована
        Assert.AreEqual(2, Engine.GetSectionCommands('bash').Count);
        Assert.IsTrue(Engine.GetSectionCommands('bash').IndexOf('git') >= 0);
        Assert.IsTrue(Engine.GetSectionCommands('bash').IndexOf('ls') >= 0);
    finally
        Engine.Free;
    end;
end;

procedure TCompletionEngineTests.Import_ReplaceMode_ReplacesSelectedOnly;
var
    Engine: TCompletionEngine;
    Path, ImportJson: string;
    ImportObj: TJSONObject;
    Tree: TCommandNode;
    Imported: Integer;
begin
    // Текущие данные: git{commit}, docker{ps}; импорт: git{push}, docker{image};
    // выбран только git в режиме замены
    Path := WriteJson(
        '{"version":2,"bash":{"completion":{"commands":["ls","git"],' +
        '"tree":{"git":{"insert":"git ","children":{"commit":{"insert":"git commit"}}},' +
        '"docker":{"insert":"docker ","children":{"ps":{"insert":"docker ps"}}}}}}}');

    ImportJson :=
        '{"commands":["git","kubectl"],' +
        '"tree":{"git":{"insert":"git ","children":{"push":{"insert":"git push "}}},' +
        '"docker":{"insert":"docker ","children":{"image":{"insert":"docker image "}}}}}';

    Engine := TCompletionEngine.Create;
    try
        Engine.LoadFromJsonFile(Path);
        ImportObj := TJSONObject.ParseJSONValue(ImportJson) as TJSONObject;
        try
            Imported := Engine.ImportSectionCompletion('bash', ImportObj, ['git'], True);
        finally
            ImportObj.Free;
        end;

        Assert.AreEqual(1, Imported);

        // git заменен целиком: только push
        Tree := Engine.GetSectionTree('bash');
        Assert.IsTrue(Tree.SubCommands.ContainsKey('git'));
        Assert.IsFalse(Tree.SubCommands['git'].SubCommands.ContainsKey('commit'));
        Assert.IsTrue(Tree.SubCommands['git'].SubCommands.ContainsKey('push'));
        // docker не выбран - остался прежним, image из импорта не попал
        Assert.IsTrue(Tree.SubCommands.ContainsKey('docker'));
        Assert.IsTrue(Tree.SubCommands['docker'].SubCommands.ContainsKey('ps'));
        Assert.IsFalse(Tree.SubCommands['docker'].SubCommands.ContainsKey('image'));
        // Плоская команда kubectl (не выбрана) не добавлена, git не задублирована
        Assert.AreEqual(-1, Engine.GetSectionCommands('bash').IndexOf('kubectl'));
        Assert.AreEqual(2, Engine.GetSectionCommands('bash').Count);
    finally
        Engine.Free;
    end;
end;

procedure TCompletionEngineTests.Import_NothingSelected_Noop;
var
    Engine: TCompletionEngine;
    Path, ImportJson: string;
    ImportObj: TJSONObject;
begin
    Path := WriteJson(
        '{"version":2,"bash":{"completion":{"commands":["ls"]}}}');

    ImportJson := '{"commands":["git"],"tree":{"git":{"insert":"git "}}}';

    Engine := TCompletionEngine.Create;
    try
        Engine.LoadFromJsonFile(Path);

        ImportObj := TJSONObject.ParseJSONValue(ImportJson) as TJSONObject;
        try
            // Пустой список выбора
            Assert.AreEqual(0, Engine.ImportSectionCompletion('bash', ImportObj, [], False));
            // Выбранное имя отсутствует в импорте
            Assert.AreEqual(0, Engine.ImportSectionCompletion('bash', ImportObj, ['docker'], False));
        finally
            ImportObj.Free;
        end;

        // Nil-JSON
        Assert.AreEqual(0, Engine.ImportSectionCompletion('bash', nil, ['git'], False));

        // Секция не изменилась
        Assert.AreEqual(1, Engine.GetSectionCommands('bash').Count);
        Assert.IsFalse(Engine.GetSectionTree('bash').SubCommands.ContainsKey('git'));
    finally
        Engine.Free;
    end;
end;

end.
