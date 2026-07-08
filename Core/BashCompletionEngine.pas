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
        constructor Create(const AName: string; const AInsertText: string = '');
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
        procedure CollectKeywords(ANode: TCommandNode; AList: TStringList);
    public
        constructor Create(ABasicCommands: TStringList);
        destructor Destroy; override;

        procedure LoadFromJsonFile(const AFilePath: string);
    // Метод для отслеживания изменений файла на диске
        function CheckForUpdates: Boolean;

        procedure FillProposals(const ALineText: string; ItemList, InsertList: TStrings; var CanExecute: Boolean);
        procedure ExportKeywords(ATargetList: TStringList);
    end;

implementation

uses
    System.JSON
    ;

// Безопасная рекурсивная процедура чтения узлов (без inline var)
procedure ParseJsonNode(AParentNode: TCommandNode; AJsonObject: TJSONObject);
var
    I: Integer;
    Pair: TJSONPair;
    CmdName: string;
    CmdObj: TJSONObject;
    ChildNode: TCommandNode;
    InsertVal, ChildrenVal: TJSONValue;
begin
    for I := 0 to AJsonObject.Count - 1 do
    begin
        Pair := AJsonObject.Pairs[I];
        CmdName := Pair.JsonString.Value;

    // Убеждаемся, что значение - это объект
        if Pair.JsonValue is TJSONObject then
        begin
            CmdObj := TJSONObject(Pair.JsonValue);

      // 1. Пытаемся получить текст вставки
            InsertVal := CmdObj.GetValue('insert');
            if Assigned(InsertVal) then
                ChildNode := AParentNode.Add(CmdName, InsertVal.Value)
            else
                ChildNode := AParentNode.Add(CmdName, CmdName + ' ');

      // 2. Рекурсивно читаем вложенные команды
            ChildrenVal := CmdObj.GetValue('children');
            if Assigned(ChildrenVal) and (ChildrenVal is TJSONObject) then
                ParseJsonNode(ChildNode, TJSONObject(ChildrenVal));
        end;
    end;
end;

{ TCommandNode }

constructor TCommandNode.Create(const AName, AInsertText: string);
begin
    FName := AName;
    if AInsertText <> '' then
        FInsertText := AInsertText
    else
        FInsertText := AName;

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

constructor TBashCompletionEngine.Create(ABasicCommands: TStringList);
begin
    FBasicCommands := ABasicCommands;
    FRoot := TCommandNode.Create('root');
end;

destructor TBashCompletionEngine.Destroy;
begin
    FRoot.Free;
    inherited;
end;

procedure TBashCompletionEngine.LoadFromJsonFile(const AFilePath: string);
var
    JsonText: string;
    JsonRoot: TJSONObject;
begin
    if not TFile.Exists(AFilePath) then
        Exit;

  // Запоминаем путь и время последнего изменения файла
    FFilePath := AFilePath;
    FLastModified := TFile.GetLastWriteTime(AFilePath);

    JsonText := TFile.ReadAllText(AFilePath, TEncoding.UTF8);
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

procedure TBashCompletionEngine.FillProposals(const ALineText: string; ItemList, InsertList: TStrings; var CanExecute: Boolean);
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

    IsNewWord := (ALineText = '') or (ALineText[Length(ALineText)] = ' ');
    Tokens := ALineText.Split([' '], TStringSplitOptions.ExcludeEmpty);

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

procedure TBashCompletionEngine.CollectKeywords(ANode: TCommandNode; AList: TStringList);
var
    Child: TCommandNode;
begin
    if (ANode.Name <> 'root') and (Pos('-', ANode.Name) <> 1) then
    begin
        if AList.IndexOf(ANode.Name) = -1 then
            AList.Add(ANode.Name);
    end;

    for Child in ANode.SubCommands.Values do
        CollectKeywords(Child, AList);
end;

procedure TBashCompletionEngine.ExportKeywords(ATargetList: TStringList);
begin
    CollectKeywords(FRoot, ATargetList);
end;

end.

