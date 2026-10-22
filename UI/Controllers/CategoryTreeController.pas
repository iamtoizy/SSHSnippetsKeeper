unit CategoryTreeController;

interface

uses
    Core.Entities.Category,
    Core.Entities.User,
    Core.Interfaces.App,
    Core.Interfaces.Services,
    Core.Interfaces.Settings,
    Core.Interfaces.UI,
    System.SysUtils,
    System.Types,
    UI.AppStatusBar,
    Vcl.ComCtrls,
    Vcl.Controls,
    Winapi.Messages,
    Winapi.Windows
    ;

const
    // Спец-значение для ReloadUI: не сохранять/не восстанавливать выбранную категорию
    PRESERVE_CATEGORY_EMPTY_ID = -999;

type
    // Логика дерева категорий: предикаты узлов, разрешение workspace,
    // CRUD категорий, инлайн-переименование, drag&drop.
    // Форма владеет TTreeView и DFM-обработчиками и делегирует сюда.
    TCategoryTreeController = class
    private
        FTree: TTreeView;
        FStatusBar: TAppStatusBar;
        FContext: IAppContext;
        FOnReloadUI: TProc<Integer>;
        FOnDataChanged: TProc;
        FFilterUserID: Integer;
        FDefaultUserID: Integer;
    public
        constructor Create(ATree: TTreeView; AStatusBar: TAppStatusBar; AContext: IAppContext;
            const AOnReloadUI: TProc<Integer>; const AOnDataChanged: TProc);

        function IsVirtualCategory(Node: TTreeNode): Boolean;
        function IsWorkspaceNode(Node: TTreeNode): Boolean;
        function CanEditNode(Node: TTreeNode): Boolean;
        function IsDescendant(Parent, Node: TTreeNode): Boolean;
        function GetWorkspaceUserID(Node: TTreeNode): Integer;
        function GetSelectedCategoryUserID: Integer;

        procedure AddCategory;
        procedure DeleteCategory;
        procedure StartRename;
        procedure HandleEdited(Node: TTreeNode; var S: string);
        procedure HandleDragDrop(Source: TObject; X, Y: Integer);
        procedure HandleDragOver(Source: TObject; X, Y: Integer; var Accept: Boolean);
        procedure HandleMouseDown(Button: TMouseButton; X, Y: Integer);
        procedure HandleEndDrag;

        // Жесткий фильтр по пользователю (>0) перекрывает определение workspace
        property FilterUserID: Integer read FFilterUserID write FFilterUserID;
        // Пользователь по умолчанию, когда workspace определить не удалось
        property DefaultUserID: Integer read FDefaultUserID write FDefaultUserID;
    end;

implementation

uses
    ChainRunnerController,
    Common.Localization,
    System.Math
    ;

{ TCategoryTreeController }

constructor TCategoryTreeController.Create(ATree: TTreeView; AStatusBar: TAppStatusBar;
    AContext: IAppContext; const AOnReloadUI: TProc<Integer>; const AOnDataChanged: TProc);
begin
    inherited Create;
    FTree := ATree;
    FStatusBar := AStatusBar;
    FContext := AContext;
    FOnReloadUI := AOnReloadUI;
    FOnDataChanged := AOnDataChanged;
    FFilterUserID := 0;
    FDefaultUserID := 0;
end;

function TCategoryTreeController.IsVirtualCategory(Node: TTreeNode): Boolean;
begin
    Result := Assigned(Node) and (Integer(IntPtr(Node.Data)) < 0);
end;

function TCategoryTreeController.IsWorkspaceNode(Node: TTreeNode): Boolean;
begin
    Result := Assigned(Node) and (Node.Data = nil) and not IsVirtualCategory(Node);
end;

function TCategoryTreeController.CanEditNode(Node: TTreeNode): Boolean;
var
    ChainID: Integer;
begin
    if (Node = nil) or IsWorkspaceNode(Node) then
        Exit(False);
    if IsVirtualCategory(Node) then
        Exit(TChainRunner.TryGetChainID(Integer(IntPtr(Node.Data)), ChainID));
    Result := True;
end;

function TCategoryTreeController.IsDescendant(Parent, Node: TTreeNode): Boolean;
begin
    Result := False;
    while Node <> nil do
    begin
        if Node = Parent then
            Exit(True);
        Node := Node.Parent;
    end;
end;

function TCategoryTreeController.GetWorkspaceUserID(Node: TTreeNode): Integer;
var
    RootNode: TTreeNode;
    User: TUserDTO;
    Cat: TCategoryDTO;
begin
    // 1. Если включен жесткий фильтр по пользователю
    if FFilterUserID > 0 then
        Exit(FFilterUserID);

    if Node = nil then
        Exit(FDefaultUserID); // Дефолт

    // 2. Если это конкретная категория, просто берем её UserID из БД
    if not IsVirtualCategory(Node) and (Node.Data <> nil) then
    begin
        Cat := FContext.CategoryService.GetCategoryByID(Integer(IntPtr(Node.Data)));
        if Cat.ID > 0 then
            Exit(Cat.UserID);
    end;

    // 3. Если это корень (Workspace), просто ищем его в списке пользователей
    RootNode := Node;
    while RootNode.Parent <> nil do
        RootNode := RootNode.Parent;

    if IsWorkspaceNode(RootNode) then
    begin
        for User in FContext.UserService.GetAllUsers do
            if SameText(User.Name, RootNode.Text) then
                Exit(User.ID);
    end;

    Result := FDefaultUserID;
end;

function TCategoryTreeController.GetSelectedCategoryUserID: Integer;
begin
    Result := GetWorkspaceUserID(FTree.Selected);
end;

procedure TCategoryTreeController.AddCategory;
var
    Node: TTreeNode;
    ParentID, TargetUserID, NewCatID: Integer;
    NewCatName: string;
    NewCat: TCategoryDTO;
begin
    Node := FTree.Selected;

    if Node = nil then
    begin
        FContext.MessagesHandler.ShowError(TUIStateLoader.GetMessage('Category.SelectPrompt'));
        Exit;
    end;

    if IsVirtualCategory(Node) then
    begin
        FContext.MessagesHandler.ShowError(TUIStateLoader.GetMessage('Category.VirtualFolderError'));
        Exit;
    end;

    if IsWorkspaceNode(Node) then
        ParentID := 0
    else
        ParentID := Integer(IntPtr(Node.Data));

    TargetUserID := GetWorkspaceUserID(Node);
    NewCatName := TUIStateLoader.GetMessage('Category.NewDefaultName');
    FContext.MessagesHandler.AskInput(
        TUIStateLoader.GetMessage('Category.NewDefaultName'),
        TUIStateLoader.GetMessage('Category.NewNamePrompt'),
        NewCatName);
    NewCatName := Trim(NewCatName);

    if NewCatName = '' then
        Exit;

    try
        NewCat := Default(TCategoryDTO);
        NewCat.Name := NewCatName;
        NewCat.ParentID := ParentID;
        NewCat.UserID := TargetUserID;

        NewCatID := FContext.CategoryService.CreateCategory(NewCat);
        if Assigned(FOnReloadUI) then
            FOnReloadUI(NewCatID);

        Node := FTree.Selected;
        if (Node <> nil) and (Integer(IntPtr(Node.Data)) = NewCatID) then
            Node.EditText;

        FStatusBar.Flash(TUIStateLoader.GetMessage('Category.CreatedMsg', [NewCatName]));

        if Assigned(FOnDataChanged) then
            FOnDataChanged();
    except
        on E: Exception do
            FContext.MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('Category.CreateError', [E.Message])
            );
    end;
end;

procedure TCategoryTreeController.DeleteCategory;
var
    Node: TTreeNode;
    Cat: TCategoryDTO;
begin
    Node := FTree.Selected;
    if (Node = nil) or IsVirtualCategory(Node) then
        Exit;

    Cat := FContext.CategoryService.GetCategoryByID(Integer(IntPtr(Node.Data)));

    if FContext.MessagesHandler.AskConfirmation(
        TUIStateLoader.GetMessage('Category.DeleteWithChildrenConfirm', [Cat.Name]),
        TUIStateLoader.GetMessage('Common.Confirmation'),
        MB_YESNO or MB_ICONQUESTION
    ) then begin
        try
            FContext.CategoryService.DeleteCategory(Cat.ID);
            if Assigned(FOnReloadUI) then
                FOnReloadUI(PRESERVE_CATEGORY_EMPTY_ID);
            FStatusBar.Flash(TUIStateLoader.GetMessage('Category.DeleteMsg', [Cat.Name]));
            if Assigned(FOnDataChanged) then
                FOnDataChanged();
        except
            on E: Exception do
                FContext.MessagesHandler.ShowError(
                    TUIStateLoader.GetMessage('Category.DeleteError', [E.Message])
                );
        end;
    end;
end;

procedure TCategoryTreeController.StartRename;
var
    Node: TTreeNode;
begin
    Node := FTree.Selected;
    if Node = nil then
        Exit;

    if IsWorkspaceNode(Node) then
        FContext.MessagesHandler.ShowError(
            TUIStateLoader.GetMessage('Workspace.RenameError')
        )
    else if CanEditNode(Node) then
    begin
        Node.EditText;
    end;
end;

procedure TCategoryTreeController.HandleEdited(Node: TTreeNode; var S: string);
var
    Cat: TCategoryDTO;
    OldName: string;
    ChainID: Integer;
    Twin: TTreeNode;
    NodeValue: Integer;
begin
    NodeValue := Integer(IntPtr(Node.Data));

    if TChainRunner.TryGetChainID(NodeValue, ChainID) then
    begin
        OldName := Node.Text;
        S := Trim(S);
        if (S = '') or (S = OldName) then
        begin
            S := OldName;
            Exit;
        end;

        try
            FContext.ChainService.RenameChain(ChainID, S);
            for Twin in FTree.Items do
                if (Twin <> Node) and (Integer(IntPtr(Twin.Data)) = NodeValue) then
                    Twin.Text := S;
            if Assigned(FOnDataChanged) then
                FOnDataChanged();
        except
            on E: Exception do
            begin
                FContext.MessagesHandler.ShowError(
                    TUIStateLoader.GetMessage('Chains.RenameError', [E.Message])
                );
                S := OldName;
            end;
        end;
        Exit;
    end;

    if IsVirtualCategory(Node) or IsWorkspaceNode(Node) then
    begin
        S := Node.Text;
        Exit;
    end;

    OldName := Node.Text;
    S := Trim(S);
    if (S = '') or (S = OldName) then
    begin
        S := OldName;
        Exit;
    end;

    try
        Cat := FContext.CategoryService.GetCategoryByID(Integer(IntPtr(Node.Data)));
        FContext.CategoryService.RenameCategory(Cat.ID, S);
        if Assigned(FOnDataChanged) then
            FOnDataChanged();
    except
        on E: Exception do
        begin
            FContext.MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('Category.RenameError', [E.Message])
            );
            S := OldName;
        end;
    end;
end;

procedure TCategoryTreeController.HandleDragDrop(Source: TObject; X, Y: Integer);
var
    TargetNode, SourceNode: TTreeNode;
    NewParentID, SourceID, Position: Integer;
    HitTest: THitTests;
begin
    if (Source = FTree) and (FTree.Selected <> nil) then
    begin
        SourceNode := FTree.Selected;
        SourceID := Integer(IntPtr(SourceNode.Data));
        if SourceID < 0 then
            Exit;

        HitTest := FTree.GetHitTestInfoAt(X, Y);
        TargetNode := FTree.GetNodeAt(X, Y);
        if IsVirtualCategory(TargetNode) or IsWorkspaceNode(TargetNode) then
            Exit;

        if (htOnItem in HitTest) and (TargetNode <> nil) then
        begin
            NewParentID := Integer(IntPtr(TargetNode.Data));
            Position := -1;
        end
        else if TargetNode <> nil then
        begin
            if Y < TargetNode.DisplayRect(False).Top then
            begin
                if TargetNode.Parent <> nil then
                    NewParentID := Integer(IntPtr(TargetNode.Parent.Data))
                else
                    NewParentID := 0;
                Position := TargetNode.Index;
            end
            else
            begin
                if TargetNode.Parent <> nil then
                    NewParentID := Integer(IntPtr(TargetNode.Parent.Data))
                else
                    NewParentID := 0;
                Position := TargetNode.Index + 1;
            end;
        end
        else
        begin
            NewParentID := 0;
            Position := -1;
        end;

        if (NewParentID < 0) or (SourceID = NewParentID) or IsDescendant(SourceNode, TargetNode) then
            Exit;

        try
            FContext.CategoryService.MoveCategory(SourceID, NewParentID, Position);
            if Assigned(FOnReloadUI) then
                FOnReloadUI(SourceID);
        except
            on E: Exception do
                FContext.MessagesHandler.ShowError(
                    TUIStateLoader.GetMessage('Category.MoveError', [E.Message])
                );
        end;
    end;
end;

procedure TCategoryTreeController.HandleDragOver(Source: TObject; X, Y: Integer; var Accept: Boolean);
var
    TargetNode, SourceNode: TTreeNode;
begin
    Accept := False;
    TargetNode := FTree.GetNodeAt(X, Y);
    if (Source = FTree) and (FTree.Selected <> nil) then
    begin
        SourceNode := FTree.Selected;
        if IsVirtualCategory(TargetNode) or IsVirtualCategory(SourceNode) or IsWorkspaceNode(TargetNode) then
            Exit;
        if TargetNode <> nil then
            Accept := not IsDescendant(SourceNode, TargetNode)
        else
            Accept := True;
    end;
    FTree.Cursor := IfThen(IsVirtualCategory(TargetNode) or IsWorkspaceNode(TargetNode), crNo, crDefault);
end;

procedure TCategoryTreeController.HandleMouseDown(Button: TMouseButton; X, Y: Integer);
var
    Node: TTreeNode;
begin
    if Button = mbLeft then
    begin
        Node := FTree.GetNodeAt(X, Y);
        if IsVirtualCategory(Node) or IsWorkspaceNode(Node) then
            Exit;
        if (Node <> nil) and (Node.Selected) then
            FTree.BeginDrag(False, 5);
    end;
end;

procedure TCategoryTreeController.HandleEndDrag;
begin
    FTree.Cursor := crDefault;
end;

end.
