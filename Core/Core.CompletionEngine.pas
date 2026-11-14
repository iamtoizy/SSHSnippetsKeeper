unit Core.CompletionEngine;

interface

uses
    System.Classes,
    System.Generics.Collections,
    System.IOUtils,
    System.JSON,
    System.SysUtils
    ;

type
    // Узел дерева команд
    TCommandNode = class
    private
        FName: string;
        FInsertText: string;
        FSubCommands: TObjectDictionary<string, TCommandNode>;
    public
        constructor Create(const Name: string; const InsertText: string = '');
        destructor Destroy; override;

        function Add(const AName: string; AInsertText: string = ''): TCommandNode;

        property Name: string read FName;
        property InsertText: string read FInsertText;
        property SubCommands: TObjectDictionary<string, TCommandNode> read FSubCommands;
    end;

    // Данные одной языковой секции файла автодополнения
    TCompletionSection = class
    private
        FCommands: TStringList;
        FTree: TCommandNode;
    public
        constructor Create;
        destructor Destroy; override;

        property Commands: TStringList read FCommands;
        property Tree: TCommandNode read FTree;
    end;

    // Движок автодополнения: единый JSON-файл с секциями bash/bat/powershell.
    // Формат секции: { "completion": { "commands": [...], "tree": {...} } };
    // поддерживается и старый одноязычный формат (completion в корне = bash).
    TCompletionEngine = class
    private
        FSections: TObjectDictionary<string, TCompletionSection>;
        FActiveSection: string;
        FFilePath: string;
        FLastModified: TDateTime;
        function GetSection(const AName: string): TCompletionSection;
        procedure CollectKeywords(Node: TCommandNode; List: TStringList);
    public
        constructor Create;
        destructor Destroy; override;

        procedure LoadFromJsonFile(const FilePath: string);
        procedure SaveToJsonFile(const FilePath: string);

        // Переключение активной языковой секции (bash/bat/powershell);
        // неизвестный язык выбирает секцию bash (как fallback-подсветка)
        procedure SetLanguage(const ALanguage: string);
        function SectionExists(const ALanguage: string): Boolean;
        function GetSectionTree(const ALanguage: string): TCommandNode;
        function GetSectionCommands(const ALanguage: string): TStrings;

        // Работа с секциями для менеджера автодополнения.
        // TreeJson: { "имя": { "insert": "...", "children": {...} } }
        function SectionTreeToJson(const ALanguage: string): TJSONObject;
        procedure ReplaceSectionTree(const ALanguage: string; TreeJson: TJSONObject);
        // CompletionJson: { "completion": { "commands": [...], "tree": {...} } }
        procedure ReplaceSectionCompletion(const ALanguage: string; CompletionJson: TJSONObject);

        // Метод для отслеживания изменений файла на диске
        function CheckForUpdates: Boolean;

        procedure FillProposals(const LineText: string; ItemList, InsertList: TStrings; var CanExecute: Boolean);
        procedure ExportKeywords(TargetList: TStringList);

        property ActiveSection: string read FActiveSection;
    end;

implementation

uses
    Common.SnippetLanguages
    ;

// Безопасная рекурсивная процедура чтения узлов (без inline var)
procedure ParseJsonNode(ParentNode: TCommandNode; JsonObject: TJSONObject);
var
    I: Integer;
    Pair: TJSONPair;
    CmdName: string;
    CmdObj: TJSONObject;
    ChildNode: TCommandNode;
    InsertVal, ChildrenVal: TJSONValue;
begin
    for I := 0 to JsonObject.Count - 1 do
    begin
        Pair := JsonObject.Pairs[I];
        CmdName := Pair.JsonString.Value;

        // Убеждаемся, что значение - это объект
        if Pair.JsonValue is TJSONObject then
        begin
            CmdObj := TJSONObject(Pair.JsonValue);

            // 1. Пытаемся получить текст вставки
            InsertVal := CmdObj.GetValue('insert');
            if Assigned(InsertVal) then
                ChildNode := ParentNode.Add(CmdName, InsertVal.Value)
            else
                ChildNode := ParentNode.Add(CmdName, CmdName + ' ');

            // 2. Рекурсивно читаем вложенные команды
            ChildrenVal := CmdObj.GetValue('children');
            if Assigned(ChildrenVal) and (ChildrenVal is TJSONObject) then
                ParseJsonNode(ChildNode, TJSONObject(ChildrenVal));
        end;
    end;
end;

{ TCommandNode }

constructor TCommandNode.Create(const Name, InsertText: string);
begin
    FName := Name;
    if InsertText <> '' then
        FInsertText := InsertText
    else
        FInsertText := Name;

    FSubCommands := TObjectDictionary<string, TCommandNode>.Create([doOwnsValues]);
end;

destructor TCommandNode.Destroy;
begin
    FSubCommands.Free;
    inherited;
end;

function TCommandNode.Add(const AName: string; AInsertText: string = ''): TCommandNode;
begin
    Result := TCommandNode.Create(AName, AInsertText);
    FSubCommands.Add(LowerCase(AName), Result);
end;

{ TCompletionSection }

constructor TCompletionSection.Create;
begin
    FCommands := TStringList.Create;
    FCommands.Sorted := True;
    FCommands.Duplicates := dupIgnore;
    FTree := TCommandNode.Create('root');
end;

destructor TCompletionSection.Destroy;
begin
    FCommands.Free;
    FTree.Free;
    inherited;
end;

{ TCompletionEngine }

constructor TCompletionEngine.Create;
begin
    FSections := TObjectDictionary<string, TCompletionSection>.Create([doOwnsValues]);
    FActiveSection := SNIPPET_LANG_BASH;
end;

destructor TCompletionEngine.Destroy;
begin
    FSections.Free;
    inherited;
end;

function TCompletionEngine.GetSection(const AName: string): TCompletionSection;
begin
    if not FSections.TryGetValue(AName, Result) then
    begin
        Result := TCompletionSection.Create;
        FSections.Add(AName, Result);
    end;
end;

// Читает одну секцию из JSON-объекта
procedure ParseSection(CompletionObj: TJSONObject; Section: TCompletionSection);
var
    TreeVal, CommandsArr: TJSONValue;
    I: Integer;
begin
    Section.Commands.BeginUpdate;
    try
        Section.Commands.Clear;
        CommandsArr := CompletionObj.FindValue('commands');
        if CommandsArr is TJSONArray then
            for I := 0 to TJSONArray(CommandsArr).Count - 1 do
                if Trim(TJSONArray(CommandsArr).Items[I].Value) <> '' then
                    Section.Commands.Add(Trim(TJSONArray(CommandsArr).Items[I].Value));
    finally
        Section.Commands.EndUpdate;
    end;

    TreeVal := CompletionObj.FindValue('tree');
    Section.Tree.SubCommands.Clear;
    if TreeVal is TJSONObject then
        ParseJsonNode(Section.Tree, TJSONObject(TreeVal));
end;

procedure TCompletionEngine.LoadFromJsonFile(const FilePath: string);
var
    JsonText: string;
    JsonRoot: TJSONObject;
    SectionObj: TJSONValue;
    Section: TCompletionSection;
    I: Integer;
begin
    if not TFile.Exists(FilePath) then
        Exit;

    // Запоминаем путь и время последнего изменения файла
    FFilePath := FilePath;
    FLastModified := TFile.GetLastWriteTime(FilePath);

    JsonText := TFile.ReadAllText(FilePath, TEncoding.UTF8);
    JsonRoot := TJSONObject.ParseJSONValue(JsonText) as TJSONObject;

    if Assigned(JsonRoot) then
    try
        FSections.Clear;

        for I := 0 to JsonRoot.Count - 1 do
        begin
            SectionObj := JsonRoot.Pairs[I].JsonValue;
            if not (SectionObj is TJSONObject) then
                Continue;

            if not (TJSONObject(SectionObj).FindValue('completion') is TJSONObject) then
                Continue;

            Section := GetSection(LowerCase(JsonRoot.Pairs[I].JsonString.Value));
            ParseSection(TJSONObject(SectionObj).GetValue('completion') as TJSONObject, Section);
        end;

        // Старый одноязычный формат: completion лежит в корне файла
        if FSections.Count = 0 then
        begin
            if JsonRoot.FindValue('completion') is TJSONObject then
            begin
                Section := GetSection(SNIPPET_LANG_BASH);
                ParseSection(JsonRoot.GetValue('completion') as TJSONObject, Section);
            end;
        end;
    finally
        JsonRoot.Free;
    end;
end;

procedure SerializeNode(Node: TCommandNode; JsonObject: TJSONObject);
var
    Child: TCommandNode;
    ChildObj: TJSONObject;
begin
    for Child in Node.SubCommands.Values do
    begin
        ChildObj := TJSONObject.Create;
        ChildObj.AddPair('insert', Child.InsertText);
        if Child.SubCommands.Count > 0 then
        begin
            var Children := TJSONObject.Create;
            SerializeNode(Child, Children);
            ChildObj.AddPair('children', Children);
        end;
        JsonObject.AddPair(Child.Name, ChildObj);
    end;
end;

procedure TCompletionEngine.SaveToJsonFile(const FilePath: string);
var
    JsonRoot, SectionObj, CompletionObj, TreeObj: TJSONObject;
    CommandsArr: TJSONArray;
    SectionPair: TPair<string, TCompletionSection>;
    Cmd: string;
begin
    JsonRoot := TJSONObject.Create;
    try
        JsonRoot.AddPair('version', TJSONNumber.Create(2));

        for SectionPair in FSections do
        begin
            SectionObj := TJSONObject.Create;
            CompletionObj := TJSONObject.Create;

            CommandsArr := TJSONArray.Create;
            for Cmd in SectionPair.Value.Commands do
                CommandsArr.Add(Cmd);
            CompletionObj.AddPair('commands', CommandsArr);

            TreeObj := TJSONObject.Create;
            SerializeNode(SectionPair.Value.Tree, TreeObj);
            CompletionObj.AddPair('tree', TreeObj);

            SectionObj.AddPair('completion', CompletionObj);
            JsonRoot.AddPair(SectionPair.Key, SectionObj);
        end;

        TFile.WriteAllText(FilePath, JsonRoot.ToJSON, TEncoding.UTF8);
    finally
        JsonRoot.Free;
    end;
end;

procedure TCompletionEngine.SetLanguage(const ALanguage: string);
var
    Id: string;
begin
    Id := NormalizeSnippetLanguage(ALanguage);
    if Id = '' then
        Id := SNIPPET_LANG_BASH;
    FActiveSection := Id;
end;

function TCompletionEngine.SectionExists(const ALanguage: string): Boolean;
var
    Section: TCompletionSection;
begin
    Result := FSections.TryGetValue(NormalizeSnippetLanguage(ALanguage), Section) and
        ((Section.Commands.Count > 0) or (Section.Tree.SubCommands.Count > 0));
end;

function TCompletionEngine.GetSectionTree(const ALanguage: string): TCommandNode;
var
    Section: TCompletionSection;
begin
    if FSections.TryGetValue(NormalizeSnippetLanguage(ALanguage), Section) then
        Result := Section.Tree
    else
        Result := nil;
end;

function TCompletionEngine.GetSectionCommands(const ALanguage: string): TStrings;
var
    Section: TCompletionSection;
begin
    if FSections.TryGetValue(NormalizeSnippetLanguage(ALanguage), Section) then
        Result := Section.Commands
    else
        Result := nil;
end;

// Рекурсивная сериализация children-узла; вызывающий владеет результатом
function TCompletionEngine.SectionTreeToJson(const ALanguage: string): TJSONObject;
var
    Section: TCompletionSection;
begin
    Result := TJSONObject.Create;
    if FSections.TryGetValue(NormalizeSnippetLanguage(ALanguage), Section) then
        SerializeNode(Section.Tree, Result);
end;

procedure TCompletionEngine.ReplaceSectionTree(const ALanguage: string; TreeJson: TJSONObject);
var
    Section: TCompletionSection;
begin
    if not Assigned(TreeJson) then
        Exit;
    Section := GetSection(NormalizeSnippetLanguage(ALanguage));
    Section.Tree.SubCommands.Clear;
    ParseJsonNode(Section.Tree, TreeJson);
end;

procedure TCompletionEngine.ReplaceSectionCompletion(const ALanguage: string; CompletionJson: TJSONObject);
var
    Section: TCompletionSection;
begin
    if not Assigned(CompletionJson) then
        Exit;
    Section := GetSection(NormalizeSnippetLanguage(ALanguage));
    ParseSection(CompletionJson, Section);
end;

function TCompletionEngine.CheckForUpdates: Boolean;
var
    CurrentModified: TDateTime;
begin
    Result := False;
    if FFilePath = '' then
        Exit;
    if not TFile.Exists(FFilePath) then
        Exit;

    // Сравниваем время на диске с тем, что в памяти
    CurrentModified := TFile.GetLastWriteTime(FFilePath);

    if CurrentModified > FLastModified then
    begin
        // Файл изменился. Загружаем его заново.
        LoadFromJsonFile(FFilePath);
        Result := True;
    end;
end;

procedure TCompletionEngine.FillProposals(const LineText: string; ItemList, InsertList: TStrings; var CanExecute: Boolean);
var
    Tokens: TArray<string>;
    IsNewWord: Boolean;
    ContextTokens: TList<string>;
    Section: TCompletionSection;
    CurrentNode, NextNode: TCommandNode;
    Token: string;
    NodePair: TPair<string, TCommandNode>;
    I: Integer;
begin
    ItemList.Clear;
    InsertList.Clear;

    if not FSections.TryGetValue(FActiveSection, Section) then
    begin
        CanExecute := False;
        Exit;
    end;

    IsNewWord := (LineText = '') or (LineText[Length(LineText)] = ' ');
    Tokens := LineText.Split([' '], TStringSplitOptions.ExcludeEmpty);

    ContextTokens := TList<string>.Create;
    try
        for I := 0 to Length(Tokens) - 1 do
            ContextTokens.Add(LowerCase(Tokens[I]));

        if (not IsNewWord) and (ContextTokens.Count > 0) then
            ContextTokens.Delete(ContextTokens.Count - 1);

        CurrentNode := Section.Tree;
        for Token in ContextTokens do
        begin
            if CurrentNode.SubCommands.TryGetValue(Token, NextNode) then
                CurrentNode := NextNode
            else
            begin
                CanExecute := False;
                Exit;
            end;
        end;

        if CurrentNode = Section.Tree then
        begin
            for I := 0 to Section.Commands.Count - 1 do
            begin
                ItemList.Add(Section.Commands[I]);
                InsertList.Add(Section.Commands[I] + ' ');
            end;
        end;

        for NodePair in CurrentNode.SubCommands do
        begin
            ItemList.Add(NodePair.Value.Name);
            InsertList.Add(NodePair.Value.InsertText);
        end;

        if ItemList.Count = 0 then
            CanExecute := False;

    finally
        ContextTokens.Free;
    end;
end;

procedure TCompletionEngine.CollectKeywords(Node: TCommandNode; List: TStringList);
var
    Child: TCommandNode;
begin
    if (Node.Name <> 'root') and (Pos('-', Node.Name) <> 1) then
    begin
        if List.IndexOf(Node.Name) = -1 then
            List.Add(Node.Name);
    end;

    for Child in Node.SubCommands.Values do
        CollectKeywords(Child, List);
end;

procedure TCompletionEngine.ExportKeywords(TargetList: TStringList);
var
    Section: TCompletionSection;
    I: Integer;
begin
    if FSections.TryGetValue(FActiveSection, Section) then
    begin
        for I := 0 to Section.Commands.Count - 1 do
            if (Section.Commands[I] <> '') and (Pos('-', Section.Commands[I]) <> 1) and
               (TargetList.IndexOf(Section.Commands[I]) = -1) then
                TargetList.Add(Section.Commands[I]);

        CollectKeywords(Section.Tree, TargetList);
    end;
end;

end.
