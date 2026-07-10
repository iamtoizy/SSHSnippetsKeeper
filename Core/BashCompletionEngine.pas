unit BashCompletionEngine;

interface

uses
    System.SysUtils,
    System.Classes,
    System.Generics.Collections,
    System.IOUtils;

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

    // Главный движок автодополнения
    TBashCompletionEngine = class
    private
        FRoot: TCommandNode;
        FBasicCommands: TStringList;
        FFilePath: string;
        FLastModified: TDateTime;
        procedure CollectKeywords(Node: TCommandNode; List: TStringList);
    public
        constructor Create(BasicCommands: TStringList);
        destructor Destroy; override;

        procedure LoadFromJsonFile(const FilePath: string);
        // Метод для отслеживания изменений файла на диске
        function CheckForUpdates: Boolean;

        procedure FillProposals(const LineText: string; ItemList, InsertList: TStrings; var CanExecute: Boolean);
        procedure ExportKeywords(TargetList: TStringList);
    end;

implementation

uses
    System.JSON
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

{ TBashCompletionEngine }

constructor TBashCompletionEngine.Create(BasicCommands: TStringList);
begin
    FBasicCommands := BasicCommands;
    FRoot := TCommandNode.Create('root');
end;

destructor TBashCompletionEngine.Destroy;
begin
    FRoot.Free;
    inherited;
end;

procedure TBashCompletionEngine.LoadFromJsonFile(const FilePath: string);
var
    JsonText: string;
    JsonRoot: TJSONObject;
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
        FRoot.SubCommands.Clear; // Очищаем старое дерево
        ParseJsonNode(FRoot, JsonRoot);
    finally
        JsonRoot.Free;
    end;
end;

function TBashCompletionEngine.CheckForUpdates: Boolean;
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

procedure TBashCompletionEngine.FillProposals(const LineText: string; ItemList, InsertList: TStrings; var CanExecute: Boolean);
var
    Tokens: TArray<string>;
    IsNewWord: Boolean;
    ContextTokens: TList<string>;
    CurrentNode, NextNode: TCommandNode;
    Token: string;
    NodePair: TPair<string, TCommandNode>;
    I: Integer;
begin
    ItemList.Clear;
    InsertList.Clear;

    IsNewWord := (LineText = '') or (LineText[Length(LineText)] = ' ');
    Tokens := LineText.Split([' '], TStringSplitOptions.ExcludeEmpty);

    ContextTokens := TList<string>.Create;
    try
        for I := 0 to Length(Tokens) - 1 do
            ContextTokens.Add(LowerCase(Tokens[I]));

        if (not IsNewWord) and (ContextTokens.Count > 0) then
            ContextTokens.Delete(ContextTokens.Count - 1);

        CurrentNode := FRoot;
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

        if (CurrentNode = FRoot) and Assigned(FBasicCommands) then
        begin
            for I := 0 to FBasicCommands.Count - 1 do
            begin
                ItemList.Add(FBasicCommands[I]);
                InsertList.Add(FBasicCommands[I]);
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

procedure TBashCompletionEngine.CollectKeywords(Node: TCommandNode; List: TStringList);
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

procedure TBashCompletionEngine.ExportKeywords(TargetList: TStringList);
begin
    CollectKeywords(FRoot, TargetList);
end;

end.

