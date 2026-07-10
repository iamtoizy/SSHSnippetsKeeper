unit UITreeViewSearchHelper;

interface

uses
    Vcl.ComCtrls,
    System.Generics.Collections,
    System.Masks;

type
    TTreeSearchHelper = class
    private
        FTreeView: TTreeView;
        FAllNodes: TList<TTreeNode>;
        FMatchedIndices: TList<Integer>;
        FLastMask: string;
        procedure CollectAllNodes(ANode: TTreeNode);
        procedure BuildMatchList(const Mask: string);
        function GetCurrentHighlightIndex: Integer;
    public
        constructor Create(TreeView: TTreeView);
        destructor Destroy; override;

        // Ищет первое совпадение с маской (>=3 симв.). При новой маске сбрасывает и выделяет первый узел.
        function FindFirst(const Mask: string): Boolean;

        // Переход к следующему совпадению после текущего выделенного (циклический).
        function FindNext: Boolean;

        // Сброс поиска и выделения.
        procedure ClearSearch;
    end;

implementation

uses
    System.SysUtils;

{ TTreeSearchHelper }

constructor TTreeSearchHelper.Create(TreeView: TTreeView);
begin
    inherited Create;
    FTreeView := TreeView;
    FAllNodes := TList<TTreeNode>.Create;
    FMatchedIndices := TList<Integer>.Create;
end;

destructor TTreeSearchHelper.Destroy;
begin
    FAllNodes.Free;
    FMatchedIndices.Free;
    inherited;
end;

procedure TTreeSearchHelper.CollectAllNodes(ANode: TTreeNode);
var
    Child: TTreeNode;
begin
    if ANode = nil then
        Exit;
    FAllNodes.Add(ANode);
    Child := ANode.GetFirstChild;
    while Child <> nil do
    begin
        CollectAllNodes(Child);
        Child := ANode.GetNextChild(Child);
    end;
end;

procedure TTreeSearchHelper.BuildMatchList(const Mask: string);
var
    ProcessedMask: string;
    i: Integer;
    RootNode: TTreeNode;
    NodeTextUpper: string;
begin
    // Если маска слишком короткая, не ищем (очистка уже в FindFirst)
    if Mask.Length < 3 then
        Exit;

    ProcessedMask := Mask;

    // Если пользователь не использовал спецсимволы маски - ищем как подстроку
    if (Pos('*', ProcessedMask) = 0) and (Pos('?', ProcessedMask) = 0) then
    begin
        if (ProcessedMask <> '') and (ProcessedMask[1] <> '*') then
            ProcessedMask := '*' + ProcessedMask;
        if (ProcessedMask <> '') and (ProcessedMask[Length(ProcessedMask)] <> '*') then
            ProcessedMask := ProcessedMask + '*';
    end;

    // Приводим маску к верхнему регистру для регистронезависимого сравнения
    ProcessedMask := UpperCase(ProcessedMask);

    FLastMask := ProcessedMask; // храним в том виде, в котором реально ищем
    FAllNodes.Clear;
    FMatchedIndices.Clear;

    // Собираем все узлы дерева
    RootNode := FTreeView.Items.GetFirstNode;
    while RootNode <> nil do
    begin
        CollectAllNodes(RootNode);
        RootNode := RootNode.GetNextSibling;
    end;

    // Фильтруем, сравнивая UpperCase текста с UpperCase маски
    for i := 0 to FAllNodes.Count - 1 do
    begin
        NodeTextUpper := UpperCase(FAllNodes[i].Text);
        if MatchesMask(NodeTextUpper, ProcessedMask) then
            FMatchedIndices.Add(i);
    end;
end;

function TTreeSearchHelper.GetCurrentHighlightIndex: Integer;
var
    SelNode: TTreeNode;
begin
    SelNode := FTreeView.Selected;
    if SelNode = nil then
        Exit(-1);
    Result := FAllNodes.IndexOf(SelNode);
    // может вернуть -1, если узел не из дерева (теоретически)
end;

function TTreeSearchHelper.FindFirst(const Mask: string): Boolean;
var
    NewIndex: Integer;
    Node: TTreeNode;
begin
    if FTreeView = nil then
        Exit(False);

    if Length(Mask) < 3 then
    begin
        ClearSearch;
        Exit(False);
    end;

    // При смене маски перестраиваем список совпадений
    if Mask <> FLastMask then
    begin
        BuildMatchList(Mask);
        // Выделяем первый совпавший узел (если есть)
        if FMatchedIndices.Count > 0 then
        begin
            NewIndex := FMatchedIndices[0];
            Node := FAllNodes[NewIndex];
            if Node <> nil then
            begin
                FTreeView.Selected := Node;
                Node.MakeVisible;
                Exit(True);
            end;
        end
        else
            FTreeView.Selected := nil;
        Exit(False);
    end
    else
    begin
        // Маска та же - ничего не делаем (ждём Enter)
        Result := FMatchedIndices.Count > 0;
    end;
end;

function TTreeSearchHelper.FindNext: Boolean;
var
    CurrentIdx, i, NextIdx: Integer;
    Node: TTreeNode;
begin
    if (FTreeView = nil) or (FMatchedIndices.Count = 0) then
        Exit(False);

    CurrentIdx := GetCurrentHighlightIndex;

    // Ищем первый индекс в FMatchedIndices, больший CurrentIdx
    NextIdx := -1;
    for i := 0 to FMatchedIndices.Count - 1 do
    begin
        if FMatchedIndices[i] > CurrentIdx then
        begin
            NextIdx := FMatchedIndices[i];
            Break;
        end;
    end;

    // Если не нашли после текущего - зацикливаемся: берём самый первый
    if NextIdx = -1 then
        NextIdx := FMatchedIndices[0];

    Node := FAllNodes[NextIdx];
    if Node <> nil then
    begin
        FTreeView.Selected := Node;
        Node.MakeVisible;
        Exit(True);
    end;

    Result := False;
end;

procedure TTreeSearchHelper.ClearSearch;
begin
    FAllNodes.Clear;
    FMatchedIndices.Clear;
    FLastMask := '';
    if (FTreeView <> nil) and (FTreeView.Selected <> nil) then
        FTreeView.Selected := nil;
end;

end.

