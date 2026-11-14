unit CompletionManagerFormUI;

interface

uses
    BaseFormUI,
    Core.CompletionEngine,
    System.Classes,
    System.Generics.Collections,
    System.JSON,
    System.SysUtils,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.StdCtrls
    ;

type
    TCompletionManagerForm = class(TBaseForm)
        pcMain: TPageControl;
        tsBash: TTabSheet;
        tsBat: TTabSheet;
        tsPowerShell: TTabSheet;
        pBashCmds: TPanel;
        tvBash: TTreeView;
        lvBashCmds: TListView;
        pBatCmds: TPanel;
        tvBat: TTreeView;
        lvBatCmds: TListView;
        pPSCmds: TPanel;
        tvPS: TTreeView;
        lvPSCmds: TListView;
        pEdit: TPanel;
        gbTree: TGroupBox;
        pTreeBtns: TPanel;
        edTreeFilter: TEdit;
        btnAdd: TButton;
        btnAddChild: TButton;
        btnDelete: TButton;
        pTreeRow: TPanel;
        edName: TEdit;
        edInsert: TEdit;
        btnApply: TButton;
        gbCommands: TGroupBox;
        edCmdFilter: TEdit;
        pCmdRow: TPanel;
        edCommand: TEdit;
        btnCmdAdd: TButton;
        btnCmdDelete: TButton;
        pBottom: TPanel;
        btnImport: TButton;
        btnExport: TButton;
        btnSave: TButton;
        btnClose: TButton;
        procedure FormCreate(Sender: TObject);
        procedure FormDestroy(Sender: TObject);
        procedure pcMainChange(Sender: TObject);
        procedure edTreeFilterChange(Sender: TObject);
        procedure edCmdFilterChange(Sender: TObject);
        procedure btnAddClick(Sender: TObject);
        procedure btnAddChildClick(Sender: TObject);
        procedure btnDeleteClick(Sender: TObject);
        procedure btnApplyClick(Sender: TObject);
        procedure btnCmdAddClick(Sender: TObject);
        procedure btnCmdDeleteClick(Sender: TObject);
        procedure btnImportClick(Sender: TObject);
        procedure btnExportClick(Sender: TObject);
        procedure btnSaveClick(Sender: TObject);
        procedure btnCloseClick(Sender: TObject);
        procedure tvChange(Sender: TObject; Node: TTreeNode);
        procedure lvSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure tvDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
        procedure tvDragDrop(Sender, Source: TObject; X, Y: Integer);
    protected
        procedure DoInitialize; override;
    private
        FEngine: TCompletionEngine;
        FFilePath: string;
        // Тексты вставки узлов всех вкладок; TTreeNode.Data хранит индекс
        // строки в этом списке (список за сессию только дополняется)
        FNodeInserts: TStringList;
        // Защита от взаимной рекурсии кросс-выделения дерево <-> список
        FSyncing: Boolean;

        function TabTree(ATabIndex: Integer): TTreeView;
        function TabCommandList(ATabIndex: Integer): TListView;
        function ActiveTree: TTreeView;
        function ActiveLangId: string;
        procedure LoadTabTree(ATabIndex: Integer);
        procedure LoadCommandNode(tv: TTreeView; AParentNode: TTreeNode; CmdNode: TCommandNode);
        procedure LoadCommandList(ATabIndex: Integer);
        function AddNodeFromCommand(tv: TTreeView; const AName, AInsertText: string; AParent: TTreeNode): TTreeNode;
        function FindSibling(tv: TTreeView; const AName: string; AParent: TTreeNode; ASkip: TTreeNode): TTreeNode;
        function NodeToChildrenJson(Node: TTreeNode): TJSONObject;
        function TreeToChildrenJson(tv: TTreeView): TJSONObject;
        function NameMatchesSubtree(CmdNode: TCommandNode; const AFilter: string): Boolean;
        procedure AddFiltered(tv: TTreeView; AParentNode: TTreeNode; CmdNode: TCommandNode; const AFilter: string);
        procedure ApplyFilter;
        procedure SyncEditor(Tree: TTreeView);
        procedure SyncSelectionToEditor;
        procedure SyncCommandsList(Tree: TTreeView);
    end;

var
    CompletionManagerForm: TCompletionManagerForm;

implementation

{$R *.dfm}

uses
    Common.Helpers,
    Common.Localization,
    Common.SnippetLanguages,
    System.IOUtils,
    System.StrUtils,
    System.UITypes,
    Vcl.Dialogs,
    Vcl.Forms
    ;

const
    // Индекс вкладки -> идентификатор секции в autocomplete.json
    COMPLETION_TAB_LANGS: array[0..2] of string = (
        SNIPPET_LANG_BASH, SNIPPET_LANG_BAT, SNIPPET_LANG_POWERSHELL);

// Имена узлов словаря, отсортированные без учёта регистра
function SortedNodeNames(Dict: TObjectDictionary<string, TCommandNode>): TArray<string>;
var
    Pair: TPair<string, TCommandNode>;
    I, J: Integer;
    Swap: string;
begin
    SetLength(Result, Dict.Count);
    I := 0;
    for Pair in Dict do
    begin
        Result[I] := Pair.Value.Name;
        Inc(I);
    end;

    // Сортировка вставками: секции относительно небольшие
    for I := 1 to High(Result) do
    begin
        Swap := Result[I];
        J := I;
        while (J > 0) and (CompareText(Result[J - 1], Swap) > 0) do
        begin
            Result[J] := Result[J - 1];
            Dec(J);
        end;
        Result[J] := Swap;
    end;
end;

function TCompletionManagerForm.TabTree(ATabIndex: Integer): TTreeView;
begin
    if ATabIndex = 1 then
        Result := tvBat
    else if ATabIndex = 2 then
        Result := tvPS
    else
        Result := tvBash;
end;

function TCompletionManagerForm.ActiveTree: TTreeView;
begin
    Result := TabTree(pcMain.ActivePageIndex);
end;

function TCompletionManagerForm.TabCommandList(ATabIndex: Integer): TListView;
begin
    if ATabIndex = 1 then
        Result := lvBatCmds
    else if ATabIndex = 2 then
        Result := lvPSCmds
    else
        Result := lvBashCmds;
end;

function TCompletionManagerForm.ActiveLangId: string;
begin
    Result := COMPLETION_TAB_LANGS[pcMain.ActivePageIndex];
end;

procedure TCompletionManagerForm.FormCreate(Sender: TObject);
begin
    FNodeInserts := TStringList.Create;
end;

procedure TCompletionManagerForm.FormDestroy(Sender: TObject);
begin
    FEngine.Free;
    FNodeInserts.Free;
end;

procedure TCompletionManagerForm.DoInitialize;
begin
    inherited;

    FFilePath := ResolvePath('autocomplete.json');
    FEngine := TCompletionEngine.Create;
    FEngine.LoadFromJsonFile(FFilePath);

    LoadTabTree(0);
    LoadTabTree(1);
    LoadTabTree(2);
    LoadCommandList(0);
    LoadCommandList(1);
    LoadCommandList(2);
end;

procedure TCompletionManagerForm.LoadTabTree(ATabIndex: Integer);
var
    tv: TTreeView;
    Tree: TCommandNode;
begin
    tv := TabTree(ATabIndex);
    tv.Items.Clear;

    Tree := FEngine.GetSectionTree(COMPLETION_TAB_LANGS[ATabIndex]);
    if Tree = nil then
        Exit;

    LoadCommandNode(tv, nil, Tree);
end;

procedure TCompletionManagerForm.LoadCommandNode(tv: TTreeView; AParentNode: TTreeNode; CmdNode: TCommandNode);
var
    Names: TArray<string>;
    I: Integer;
    Child: TCommandNode;
    TreeNode: TTreeNode;
begin
    Names := SortedNodeNames(CmdNode.SubCommands);
    for I := 0 to High(Names) do
        if CmdNode.SubCommands.TryGetValue(LowerCase(Names[I]), Child) then
        begin
            TreeNode := AddNodeFromCommand(tv, Child.Name, Child.InsertText, AParentNode);
            LoadCommandNode(tv, TreeNode, Child);
        end;
end;

// Список базовых команд секции с учётом фильтра; в Item.Data хранится
// индекс в полном списке движка (сортированный TStringList), поэтому
// удаление по выбранному элементу корректно даже при активном фильтре
procedure TCompletionManagerForm.LoadCommandList(ATabIndex: Integer);
var
    lv: TListView;
    Cmds: TStrings;
    FilterText: string;
    I: Integer;
    Item: TListItem;
begin
    lv := TabCommandList(ATabIndex);
    lv.Items.BeginUpdate;
    try
        lv.Items.Clear;
        Cmds := FEngine.GetSectionCommands(COMPLETION_TAB_LANGS[ATabIndex]);
        if Cmds = nil then
            Exit;
        FilterText := Trim(edCmdFilter.Text);
        for I := 0 to Cmds.Count - 1 do
            if (FilterText = '') or ContainsText(Cmds[I], FilterText) then
            begin
                Item := lv.Items.Add;
                Item.Caption := Cmds[I];
                Item.Data := Pointer(I);
            end;
    finally
        lv.Items.EndUpdate;
    end;
end;

function TCompletionManagerForm.AddNodeFromCommand(tv: TTreeView; const AName, AInsertText: string; AParent: TTreeNode): TTreeNode;
begin
    Result := tv.Items.AddChild(AParent, AName);
    Result.Data := Pointer(FNodeInserts.Add(AInsertText));
end;

// Ищет среди "братьев" узел с тем же именем (без учёта регистра)
function TCompletionManagerForm.FindSibling(tv: TTreeView; const AName: string; AParent: TTreeNode; ASkip: TTreeNode): TTreeNode;
var
    I: Integer;
    Node: TTreeNode;
begin
    Result := nil;
    for I := 0 to tv.Items.Count - 1 do
    begin
        Node := tv.Items[I];
        if (Node = ASkip) then
            Continue;
        if ((AParent = nil) and (Node.Level = 0)) or
           ((AParent <> nil) and (Node.Parent = AParent)) then
            if CompareText(Node.Text, AName) = 0 then
            begin
                Result := Node;
                Break;
            end;
    end;
end;

// Сериализует узел дерева UI в формат {"insert": "...", "children": {...}}
function TCompletionManagerForm.NodeToChildrenJson(Node: TTreeNode): TJSONObject;
var
    I: Integer;
    Children: TJSONObject;
begin
    Result := TJSONObject.Create;
    Result.AddPair('insert', FNodeInserts[Integer(Node.Data)]);

    if Node.HasChildren then
    begin
        Children := TJSONObject.Create;
        for I := 0 to Node.Count - 1 do
            Children.AddPair(Node.Item[I].Text, NodeToChildrenJson(Node.Item[I]));
        Result.AddPair('children', Children);
    end;
end;

// Корневые узлы вкладки в формат секции tree
function TCompletionManagerForm.TreeToChildrenJson(tv: TTreeView): TJSONObject;
var
    I: Integer;
    Node: TTreeNode;
begin
    Result := TJSONObject.Create;
    for I := 0 to tv.Items.Count - 1 do
    begin
        Node := tv.Items[I];
        if Node.Level = 0 then
            Result.AddPair(Node.Text, NodeToChildrenJson(Node));
    end;
end;

// Совпадает ли узел или кто-то из его потомков с фильтром
function TCompletionManagerForm.NameMatchesSubtree(CmdNode: TCommandNode; const AFilter: string): Boolean;
var
    Child: TCommandNode;
begin
    if ContainsText(CmdNode.Name, AFilter) then
    begin
        Result := True;
        Exit;
    end;

    Result := False;
    for Child in CmdNode.SubCommands.Values do
        if NameMatchesSubtree(Child, AFilter) then
        begin
            Result := True;
            Break;
        end;
end;

// Добавляет в UI-дерево только узлы, совпадающие с фильтром
// (или имеющие совпадающих потомков)
procedure TCompletionManagerForm.AddFiltered(tv: TTreeView; AParentNode: TTreeNode; CmdNode: TCommandNode; const AFilter: string);
var
    Names: TArray<string>;
    I: Integer;
    Child: TCommandNode;
    TreeNode: TTreeNode;
begin
    Names := SortedNodeNames(CmdNode.SubCommands);
    for I := 0 to High(Names) do
        if CmdNode.SubCommands.TryGetValue(LowerCase(Names[I]), Child) then
            if NameMatchesSubtree(Child, AFilter) then
            begin
                TreeNode := AddNodeFromCommand(tv, Child.Name, Child.InsertText, AParentNode);
                AddFiltered(tv, TreeNode, Child, AFilter);
            end;
end;

// Пустой фильтр = полное дерево; непустой = перестроение
// из движка с показом только совпадающих ветвей
procedure TCompletionManagerForm.ApplyFilter;
var
    tv: TTreeView;
    FilterText: string;
    TreeRoot: TCommandNode;
begin
    tv := ActiveTree;
    FilterText := Trim(edTreeFilter.Text);
    TreeRoot := FEngine.GetSectionTree(ActiveLangId);

    tv.Items.Clear;
    if TreeRoot = nil then
        Exit;

    if FilterText = '' then
        LoadCommandNode(tv, nil, TreeRoot)
    else
        AddFiltered(tv, nil, TreeRoot, FilterText);
end;

procedure TCompletionManagerForm.SyncEditor(Tree: TTreeView);
var
    Node: TTreeNode;
begin
    Node := Tree.Selected;
    if Node <> nil then
    begin
        edName.Text := Node.Text;
        edInsert.Text := FNodeInserts[Integer(Node.Data)];
    end
    else
    begin
        edName.Text := '';
        edInsert.Text := '';
    end;
end;

procedure TCompletionManagerForm.SyncSelectionToEditor;
begin
    SyncEditor(ActiveTree);
end;

// Кросс-выделение: выбранный узел дерева -> элемент списка команд.
// Список команд - корневой уровень, поэтому для вложенного узла
// подсвечивается его корневая команда (верхний родитель)
procedure TCompletionManagerForm.SyncCommandsList(Tree: TTreeView);
var
    lv: TListView;
    Item: TListItem;
    Node: TTreeNode;
    I: Integer;
begin
    if FSyncing then
        Exit;

    Node := Tree.Selected;
    if Node = nil then
        Exit;
    while Node.Level > 0 do
        Node := Node.Parent;

    lv := TabCommandList(pcMain.ActivePageIndex);
    Item := nil;
    for I := 0 to lv.Items.Count - 1 do
        if SameText(lv.Items[I].Caption, Node.Text) then
        begin
            Item := lv.Items[I];
            Break;
        end;
    if Item = nil then
        Exit;

    FSyncing := True;
    try
        lv.Selected := Item;
        Item.Focused := True;
        Item.MakeVisible(False);
    finally
        FSyncing := False;
    end;
end;

procedure TCompletionManagerForm.tvChange(Sender: TObject; Node: TTreeNode);
begin
    SyncEditor(Sender as TTreeView);
    SyncCommandsList(Sender as TTreeView);
end;

// Кросс-выделение: выбранный элемент списка -> узел дерева (по имени);
// прокручиваем дерево к найденному узлу
procedure TCompletionManagerForm.lvSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
var
    tv: TTreeView;
    Node: TTreeNode;
    I: Integer;
begin
    if FSyncing or (not Selected) or (Item = nil) then
        Exit;

    tv := ActiveTree;
    Node := nil;
    for I := 0 to tv.Items.Count - 1 do
        if (tv.Items[I].Level = 0) and SameText(tv.Items[I].Text, Item.Caption) then
        begin
            Node := tv.Items[I];
            Break;
        end;

    if Node = nil then
        Exit;

    FSyncing := True;
    try
        tv.Selected := Node;
        Node.Focused := True;
        Node.MakeVisible;
    finally
        FSyncing := False;
    end;
    SyncEditor(tv);
end;

procedure TCompletionManagerForm.pcMainChange(Sender: TObject);
begin
    ApplyFilter;
    LoadCommandList(pcMain.ActivePageIndex);
    SyncSelectionToEditor;
end;

procedure TCompletionManagerForm.edTreeFilterChange(Sender: TObject);
begin
    ApplyFilter;
end;

procedure TCompletionManagerForm.edCmdFilterChange(Sender: TObject);
begin
    LoadCommandList(pcMain.ActivePageIndex);
end;

procedure TCompletionManagerForm.btnAddClick(Sender: TObject);
var
    tv: TTreeView;
    Node: TTreeNode;
    Name: string;
begin
    tv := ActiveTree;
    Name := Trim(edName.Text);

    if Name = '' then
    begin
        if not MessagesHandler.AskInput(
            TUIStateLoader.GetMessage('CompletionManager.InputNameTitle'),
            TUIStateLoader.GetMessage('CompletionManager.InputNamePrompt'),
            Name) then
            Exit;
        Name := Trim(Name);
    end;

    if Name = '' then
        Exit;

    if FindSibling(tv, Name, nil, nil) <> nil then
    begin
        MessagesHandler.ShowWarning(TUIStateLoader.GetMessage('CompletionManager.DuplicateName'));
        Exit;
    end;

    Node := AddNodeFromCommand(tv, Name, Name + ' ', nil);
    Node.Selected := True;
    Node.MakeVisible;
    SyncSelectionToEditor;
end;

procedure TCompletionManagerForm.btnAddChildClick(Sender: TObject);
var
    tv: TTreeView;
    Parent, Node: TTreeNode;
    Name: string;
begin
    tv := ActiveTree;
    Parent := tv.Selected;
    if Parent = nil then
    begin
        MessagesHandler.ShowWarning(TUIStateLoader.GetMessage('CompletionManager.SelectNodeFirst'));
        Exit;
    end;

    Name := Trim(edName.Text);
    if Name = '' then
    begin
        if not MessagesHandler.AskInput(
            TUIStateLoader.GetMessage('CompletionManager.InputNameTitle'),
            TUIStateLoader.GetMessage('CompletionManager.InputNamePrompt'),
            Name) then
            Exit;
        Name := Trim(Name);
    end;

    if Name = '' then
        Exit;

    if FindSibling(tv, Name, Parent, nil) <> nil then
    begin
        MessagesHandler.ShowWarning(TUIStateLoader.GetMessage('CompletionManager.DuplicateName'));
        Exit;
    end;

    Node := AddNodeFromCommand(tv, Name, Name + ' ', Parent);
    Parent.Expand(True);
    Node.Selected := True;
    Node.MakeVisible;
    SyncSelectionToEditor;
end;

procedure TCompletionManagerForm.btnDeleteClick(Sender: TObject);
var
    Node: TTreeNode;
begin
    Node := ActiveTree.Selected;
    if Node = nil then
    begin
        MessagesHandler.ShowWarning(TUIStateLoader.GetMessage('CompletionManager.SelectNodeFirst'));
        Exit;
    end;

    if not MessagesHandler.AskWarning(
        TUIStateLoader.GetMessage('CompletionManager.DeleteConfirm', [Node.Text]),
        TUIStateLoader.GetMessage('CompletionManager.DeleteConfirmTitle')) then
        Exit;

    Node.Delete;
    SyncSelectionToEditor;
end;

procedure TCompletionManagerForm.btnApplyClick(Sender: TObject);
var
    tv: TTreeView;
    Node, Dup: TTreeNode;
    Name: string;
begin
    tv := ActiveTree;
    Node := tv.Selected;
    if Node = nil then
    begin
        MessagesHandler.ShowWarning(TUIStateLoader.GetMessage('CompletionManager.SelectNodeFirst'));
        Exit;
    end;

    Name := Trim(edName.Text);
    if Name = '' then
    begin
        MessagesHandler.ShowWarning(TUIStateLoader.GetMessage('CompletionManager.EmptyName'));
        Exit;
    end;

    Dup := FindSibling(tv, Name, Node.Parent, Node);
    if Dup <> nil then
    begin
        MessagesHandler.ShowWarning(TUIStateLoader.GetMessage('CompletionManager.DuplicateName'));
        Exit;
    end;

    FNodeInserts[Integer(Node.Data)] := edInsert.Text;
    Node.Text := Name;
end;

procedure TCompletionManagerForm.btnCmdAddClick(Sender: TObject);
var
    Cmds: TStrings;
    Cmd: string;
begin
    Cmd := Trim(edCommand.Text);
    if Cmd = '' then
    begin
        MessagesHandler.ShowWarning(TUIStateLoader.GetMessage('CompletionManager.EmptyName'));
        Exit;
    end;

    Cmds := FEngine.GetSectionCommands(ActiveLangId);
    if Cmds = nil then
        Exit;

    if Cmds.IndexOf(Cmd) >= 0 then
    begin
        MessagesHandler.ShowWarning(TUIStateLoader.GetMessage('CompletionManager.DuplicateName'));
        Exit;
    end;

    // Список движка отсортирован и запрещает дубликаты
    Cmds.Add(Cmd);
    LoadCommandList(pcMain.ActivePageIndex);
end;

procedure TCompletionManagerForm.btnCmdDeleteClick(Sender: TObject);
var
    lv: TListView;
    Cmds: TStrings;
    Item: TListItem;
    Idx: Integer;
begin
    lv := TabCommandList(pcMain.ActivePageIndex);
    Item := lv.Selected;
    if Item = nil then
    begin
        MessagesHandler.ShowWarning(TUIStateLoader.GetMessage('CompletionManager.CmdSelectFirst'));
        Exit;
    end;

    Cmds := FEngine.GetSectionCommands(ActiveLangId);
    if Cmds = nil then
        Exit;

    // Индекс в полном списке движка хранится в Item.Data
    Idx := Integer(Item.Data);
    if (Idx < 0) or (Idx >= Cmds.Count) then
        Exit;

    Cmds.Delete(Idx);
    LoadCommandList(pcMain.ActivePageIndex);
end;

procedure TCompletionManagerForm.btnImportClick(Sender: TObject);
var
    OpenDlg: TOpenDialog;
    JsonText: string;
    Root, CompletionObj: TJSONObject;
    I: Integer;
    Pair: TJSONPair;
begin
    Root := nil;
    OpenDlg := TOpenDialog.Create(nil);
    try
        OpenDlg.Filter := 'JSON|*.json';
        OpenDlg.FileName := 'autocomplete-' + ActiveLangId + '.json';
        if not OpenDlg.Execute then
            Exit;

        try
            JsonText := TFile.ReadAllText(OpenDlg.FileName, TEncoding.UTF8);
            Root := TJSONObject.ParseJSONValue(JsonText) as TJSONObject;
            if not Assigned(Root) then
                raise Exception.Create('json');

            // Формат экспорта: {"completion": {...}}; также принимаем обёртку
            // вида {"bash": {"completion": {...}}}
            CompletionObj := nil;
            if Root.FindValue('completion') is TJSONObject then
                CompletionObj := TJSONObject(Root.GetValue('completion'))
            else
                for I := 0 to Root.Count - 1 do
                begin
                    Pair := Root.Pairs[I];
                    if (Pair.JsonValue is TJSONObject) and
                       (TJSONObject(Pair.JsonValue).FindValue('completion') is TJSONObject) then
                    begin
                        CompletionObj := TJSONObject(TJSONObject(Pair.JsonValue).GetValue('completion'));
                        Break;
                    end;
                end;

            if not Assigned(CompletionObj) then
                raise Exception.Create('structure');

            FEngine.ReplaceSectionCompletion(ActiveLangId, CompletionObj);
            LoadTabTree(pcMain.ActivePageIndex);
            LoadCommandList(pcMain.ActivePageIndex);
            ApplyFilter;
            ShowSimpleToast(TUIStateLoader.GetMessage('CompletionManager.ImportedToast'));
        except
            on E: Exception do
                MessagesHandler.ShowError(
                    TUIStateLoader.GetMessage('CompletionManager.ImportErrorFormat', [E.Message]));
        end;
    finally
        Root.Free;
        OpenDlg.Free;
    end;
end;

procedure TCompletionManagerForm.btnExportClick(Sender: TObject);
var
    SaveDlg: TSaveDialog;
    Root, CompletionObj: TJSONObject;
    CommandsArr: TJSONArray;
    Cmds: TStrings;
    I: Integer;
begin
    SaveDlg := TSaveDialog.Create(nil);
    try
        SaveDlg.Filter := 'JSON|*.json';
        SaveDlg.FileName := 'autocomplete-' + ActiveLangId + '.json';
        if not SaveDlg.Execute then
            Exit;

        Root := TJSONObject.Create;
        try
            CompletionObj := TJSONObject.Create;
            CommandsArr := TJSONArray.Create;

            Cmds := FEngine.GetSectionCommands(ActiveLangId);
            if Cmds <> nil then
                for I := 0 to Cmds.Count - 1 do
                    CommandsArr.Add(Cmds[I]);
            CompletionObj.AddPair('commands', CommandsArr);
            CompletionObj.AddPair('tree', FEngine.SectionTreeToJson(ActiveLangId));

            Root.AddPair('completion', CompletionObj);
            TFile.WriteAllText(SaveDlg.FileName, Root.ToJSON, TEncoding.UTF8);
        finally
            Root.Free;
        end;

        ShowSimpleToast(TUIStateLoader.GetMessage('CompletionManager.ExportedToast'));
    except
        on E: Exception do
            MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('CompletionManager.ExportErrorFormat', [E.Message]));
    end;
end;

procedure TCompletionManagerForm.btnSaveClick(Sender: TObject);
var
    I: Integer;
begin
    try
        for I := 0 to High(COMPLETION_TAB_LANGS) do
            FEngine.ReplaceSectionTree(COMPLETION_TAB_LANGS[I], TreeToChildrenJson(TabTree(I)));
        FEngine.SaveToJsonFile(FFilePath);
        ShowSimpleToast(TUIStateLoader.GetMessage('CompletionManager.SavedToast'));
    except
        on E: Exception do
            MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('CompletionManager.SaveErrorFormat', [E.Message]));
    end;
end;

procedure TCompletionManagerForm.btnCloseClick(Sender: TObject);
begin
    ModalResult := mrCancel;
end;

procedure TCompletionManagerForm.tvDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);begin
    Accept := (Source = Sender) and ((Sender as TTreeView).Selected <> nil);
end;

procedure TCompletionManagerForm.tvDragDrop(Sender, Source: TObject; X, Y: Integer);
var
    tv: TTreeView;
    Sel, Target, Chain: TTreeNode;
begin
    tv := Sender as TTreeView;
    Sel := tv.Selected;
    Target := tv.DropTarget;
    if (Sel = nil) or (Sel = Target) then
        Exit;

    if Target = nil then
    begin
        // Перенос на корневой уровень
        Sel.MoveTo(nil, naAdd);
        Exit;
    end;

    // Нельзя переносить узел в его собственного потомка
    Chain := Target;
    while Chain <> nil do
    begin
        if Chain = Sel then
            Exit;
        Chain := Chain.Parent;
    end;

    Sel.MoveTo(Target, naAdd);
    Target.Expand(False);
end;

end.
