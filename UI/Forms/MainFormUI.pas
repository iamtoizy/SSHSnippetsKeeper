unit MainFormUI;

interface

uses
    Winapi.Windows,
    Winapi.Messages,
    System.SysUtils,
    System.Classes,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.Dialogs,
    Vcl.Menus,
    System.IOUtils,
    Vcl.ComCtrls,
    Vcl.ExtCtrls,
    System.DateUtils,
    System.Math,
    BaseFormUI,
    System.Generics.Collections,
    Snippet,
    System.ImageList,
    Vcl.ImgList,
    Vcl.StdCtrls,
    MacroEngine,
    HintTextEdit,
    HintTextMemo,
    Vcl.VirtualImageList,
    Vcl.BaseImageCollection,
    Vcl.ImageCollection,
    Core.Interfaces,
    UI.Interfaces,
    PasswordService,
    GlobalHotkeyManager,
    Settings,
    WindowHelper,
    Core.AppContext,
    System.Threading
    ;

type
    TSnippetField = (sfContent, sfComment);

    TMainForm = class(TBaseForm)
        MainMenu: TMainMenu;
        File1: TMenuItem;
        nOpenDatabase: TMenuItem;
        NCreateDatabase: TMenuItem;
        OpenDialog: TOpenDialog;
        SaveDialog: TSaveDialog;
        pLeft: TPanel;
        splLeft: TSplitter;
        tvCategories: TTreeView;
        pBottom: TPanel;
        mComment: TMemo;
        sbBottom: TStatusBar;
        nTerminals: TMenuItem;
        N1: TMenuItem;
        nAddSnippet: TMenuItem;
        nEditSnippet: TMenuItem;
        nCloseDatabase: TMenuItem;
        pTop: TPanel;
        ebSearch: TEdit;
        Splitter1: TSplitter;
        mSnippet: TMemo;
        Splitter2: TSplitter;
        N2: TMenuItem;
        nAddTag: TMenuItem;
        nDeleteTag: TMenuItem;
        nRenameTag: TMenuItem;
        icTags: TImageCollection;
        vilTags: TVirtualImageList;
        icSnippets: TImageCollection;
        vilSnippets: TVirtualImageList;
        cbUser: TComboBox;
        spSearch: TSplitter;
        pCenter: TPanel;
        splRight: TSplitter;
        lvSnippets: TListView;
        pRight: TPanel;
        lvTags: TListView;
        icCategory: TImageCollection;
        vilCategory: TVirtualImageList;
        bManageWorkspaces: TButton;
        nCategories: TMenuItem;
        nAddCategory: TMenuItem;
        nDeleteCategory: TMenuItem;
        nEditCategory: TMenuItem;
        nDeleteSnippet: TMenuItem;
        pSearchType: TPanel;
        rbText: TRadioButton;
        rbFTS: TRadioButton;
        N3: TMenuItem;
        nSearch: TMenuItem;
        N4: TMenuItem;
        nPasswordGenerator: TMenuItem;
        procedure bManageWorkspacesClick(Sender: TObject);
        procedure cbUserChange(Sender: TObject);
        procedure nOpenDatabaseClick(Sender: TObject);
        procedure NCreateDatabaseClick(Sender: TObject);
        procedure tvCategoriesChange(Sender: TObject; Node: TTreeNode);
        procedure lvSnippetsClick(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure lvSnippetsDblClick(Sender: TObject);
        procedure nAddSnippetClick(Sender: TObject);
        procedure nEditSnippetClick(Sender: TObject);
        procedure ebSearchChange(Sender: TObject);
        procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
        procedure lvSnippetsDeletion(Sender: TObject; Item: TListItem);
        procedure lvSnippetsInfoTip(Sender: TObject; Item: TListItem; var InfoTip: string);
        procedure FormDestroy(Sender: TObject);
        procedure tvCategoriesMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
        procedure tvCategoriesDragDrop(Sender, Source: TObject; X, Y: Integer);
        procedure tvCategoriesDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
        procedure tvCategoriesEdited(Sender: TObject; Node: TTreeNode; var S: string);
        procedure lvSnippetsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
        procedure nTagEditorClick(Sender: TObject);
        procedure lvTagsDblClick(Sender: TObject);
        procedure lvTagsEdited(Sender: TObject; Item: TListItem; var S: string);
        procedure nAddCategoryClick(Sender: TObject);
        procedure nAddTagClick(Sender: TObject);
        procedure nCloseDatabaseClick(Sender: TObject);
        procedure nDeleteCategoryClick(Sender: TObject);
        procedure nDeleteSnippetClick(Sender: TObject);
        procedure nDeleteTagClick(Sender: TObject);
        procedure nEditCategoryClick(Sender: TObject);
        procedure nPasswordGeneratorClick(Sender: TObject);
        procedure nRenameTagClick(Sender: TObject);
        procedure nSearchClick(Sender: TObject);
        procedure rbTextClick(Sender: TObject);
        procedure tvCategoriesClick(Sender: TObject);
        procedure tvCategoriesEndDrag(Sender, Target: TObject; X, Y: Integer);
    private
        { Private declarations }
        FHotItemIndex: Integer;
        FFilterByTagID: Integer;
        FCurrentSnippetID: Integer;
        FUserID: Integer;
        FFilterUserID: Integer;
        FIgnoreCategoryChange: Boolean;
        FErrorHandler: IUIErrorHandler;
        FAppContext: IAppContext;
        FSettingsManager: ISettingsManager;
        FWindowHelper: IWindowHelper;
        FDBManager: IDatabaseManager;
        FHotkeyMgr: TGlobalHotkeyManager;
        FSnippetService: ISnippetService;
        FCategoryService: ICategoryService;
        FTagService: ITagService;
        FUserService: IUserService;
        FPasswordService: IPasswordService;
        FSearchTask: ITask;
        procedure ApplyTagFilter(TagID: Integer; const TagName: string);
        procedure ClearTagFilter;
        procedure FillSnippetListView(const Snippets: TArray<TSnippetDTO>);
        function ExtractSnippetByListItem(Item: TListItem): TSnippetDTO;
        procedure FillUserInterfaceFromSnippet(const Snippet: TSnippetDTO);
        function IsDescendant(Parent, Node: TTreeNode): Boolean;

        // Do-методы
        procedure DoAddSnippet;
        procedure DoEditSnippet;
        procedure DoDeleteSnippet;
        procedure DoAddTag;
        procedure DoDeleteTag;
        procedure DoRenameTag;
        procedure DoAddCategory;
        procedure DoDeleteCategory;
        procedure DoRenameCategory;

        // UI Helpers
        procedure SetUserFilter(UserID: Integer);
        function IsVirtualCategory(Node: TTreeNode): Boolean;
        function IsWorkspaceNode(Node: TTreeNode): Boolean;
        procedure LoadUsersToComboBox;
        procedure UpdateMenuState;
        function GetSelectedCategoryUserID: Integer;
        procedure RefreshCurrentSnippetList;
        procedure ReloadUI(PreserveCategoryID: Integer);
        procedure ClearRightPanel;
        function GetWorkspaceUserID(Node: TTreeNode): Integer;
        procedure CloseDatabase;
        //
        procedure PerformSearchAsync(const Mask: string);
        procedure DisplaySearchResults(const Results: TArray<TSnippetDTO>);
    protected
        procedure WMActivate(var Msg: TWMActivate); message WM_ACTIVATE;
    public
        { Public declarations }
        procedure UpdateUI(const State: TBaseFormState); override;
        procedure Initialize(AppContext: IAppContext);
    end;

var
    MainForm: TMainForm;

implementation

{$R *.dfm}

uses
    System.UITypes,
    Winapi.CommCtrl,
    System.Types,
    ArrayHelper,
    TagEditorUI,
    User,
    Tag,
    Category,
    AddEditSnippetUI,
    AppStateManager,
    UIHelpers,
    SnippetViewData,
    WindowMonitor,
    ChooseTerminalWindowUI,
    MacroInputTypes,
    InputFormUI,
    WorkspaceManagerUI,
    CommonHelpers,
    CommonConsts,
    SnippetRunner,
    QuickSearchFormUI,
    PasswordGenFormUI,
    FireDAC.Comp.Client;

const
    PRESERVE_CATEGORY_EMPTY_ID = -999;

procedure TMainForm.FormCreate(Sender: TObject);
begin
    SetProp(Self.Handle, PChar(UNIQUE_APP_STR), 1);

    FErrorHandler := TVCLErrorHandler.Create;

    FUserID := 1;
    FIgnoreCategoryChange := False;
    TStateMgr.Instance.FirstRun;

    FHotItemIndex := -1;
    FFilterByTagID := 0;
    FCurrentSnippetID := 0;
    FFilterUserID := 0;

    ebSearch.EnableHintText := True;
    ebSearch.HintText := 'Введи что-нибудь для поиска по базе данных...';
    mSnippet.EnableHintText := True;
    mSnippet.HintText := 'Текст сниппета будет здесь.';
    mComment.EnableHintText := True;
    mComment.HintText := 'Здесь будет комментарий к сниппету.';

    lvTags.OwnerData := False;
    lvSnippets.OwnerData := False;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
    WinMonitor.StopMonitoring;
    RemoveProp(Self.Handle, PChar(UNIQUE_APP_STR));
    FHotkeyMgr.Free;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
    CloseDatabase;
    CanClose := True;
end;

procedure TMainForm.UpdateUI(const State: TBaseFormState);
begin
    case State of
        bfsDBConnected:
            begin
                nCloseDatabase.Enabled := True;
                mSnippet.ReadOnly := False;
                mComment.ReadOnly := False;
                nAddTag.Enabled := True;
                nDeleteTag.Enabled := True;
                nRenameTag.Enabled := True;
                nSearch.Enabled := True;
                cbUser.Enabled := True;
                ebSearch.Enabled := True;
                bManageWorkspaces.Enabled := True;
                rbText.Enabled := True;
                rbFTS.Enabled := True;
                UpdateMenuState;
            end;
        bfsDBOpen:
            begin
                nCloseDatabase.Enabled := True;
                mSnippet.ReadOnly := False;
                mComment.ReadOnly := False;
                nAddTag.Enabled := True;
                nDeleteTag.Enabled := True;
                nRenameTag.Enabled := True;
                nSearch.Enabled := True;
                cbUser.Enabled := True;
                ebSearch.Enabled := True;
                bManageWorkspaces.Enabled := True;
                rbText.Enabled := True;
                rbFTS.Enabled := True;
                UpdateMenuState;
            end;
        bfsDBDisconnected:
            begin
                nCloseDatabase.Enabled := False;
                nAddSnippet.Enabled := False;
                nEditSnippet.Enabled := False;
                nDeleteSnippet.Enabled := False;
                mSnippet.ReadOnly := False;
                mSnippet.Text := '';
                mComment.ReadOnly := False;
                mComment.Text := '';
                lvSnippets.Items.Clear;
                lvTags.Items.Clear;
                tvCategories.Items.Clear;
                nAddTag.Enabled := False;
                nDeleteTag.Enabled := False;
                nRenameTag.Enabled := False;
                nSearch.Enabled := False;
                nAddCategory.Enabled := False;
                nDeleteCategory.Enabled := False;
                nEditCategory.Enabled := False;
                cbUser.Enabled := False;
                ebSearch.Enabled := False;
                bManageWorkspaces.Enabled := False;
                rbText.Enabled := False;
                rbFTS.Enabled := False;
            end;
    end;
end;

procedure TMainForm.UpdateMenuState;
var
    Node: TTreeNode;
    IsVirtual, IsWorkspace: Boolean;
begin
    Node := tvCategories.Selected;
    IsVirtual := IsVirtualCategory(Node);
    IsWorkspace := IsWorkspaceNode(Node);

    nAddCategory.Enabled := (Node <> nil) and not IsVirtual;
    nDeleteCategory.Enabled := (Node <> nil) and not IsVirtual and not IsWorkspace;
    nEditCategory.Enabled := (Node <> nil) and not IsVirtual and not IsWorkspace;
    nAddSnippet.Enabled := (Node <> nil) and not IsVirtual and not IsWorkspace;
    nDeleteSnippet.Enabled := (lvSnippets.Selected <> nil);
    nEditSnippet.Enabled := (lvSnippets.Selected <> nil);
end;

procedure TMainForm.ClearRightPanel;
var
    AllTags: TArray<TTagDTO>;
begin
    mSnippet.Text := '';
    mComment.Text := '';
    FCurrentSnippetID := 0;

    AllTags := FTagService.GetAllTags;
    TUIHelpers.FillTagListWithSelection(lvTags, AllTags, []);
end;

procedure TMainForm.ReloadUI(PreserveCategoryID: Integer);
var
    Cats: TArray<TCategoryDTO>;
    Users: TArray<TUserDTO>;
begin
    FIgnoreCategoryChange := True;
    try
        // Получаем данные через сервисы
        Cats := FCategoryService.GetAllCategories(FFilterUserID);
        Users := FUserService.GetAllUsers;

        // Используем UIHelper
        TUIHelpers.BuildCategoryTree(tvCategories, Cats, Users, FFilterUserID, PreserveCategoryID);
        RefreshCurrentSnippetList;
    finally
        FIgnoreCategoryChange := False;
    end;
    UpdateMenuState;
end;

procedure TMainForm.RefreshCurrentSnippetList;
var
    Node: TTreeNode;
    CatID: Integer;
    Snippets: TArray<TSnippetDTO>;
begin
    Node := tvCategories.Selected;
    if Node = nil then
    begin
        lvSnippets.Items.Clear;
        Exit;
    end;

    if FDBManager.IsConnected = False then
        Exit;

    CatID := Integer(IntPtr(Node.Data));

    if IsVirtualCategory(Node) then
    begin
        case CatID of
            -1:
                Snippets := FSnippetService.GetTopSnippets(FUserID, 10);
            -2:
                Snippets := FSnippetService.GetRecentSnippets(FUserID, 10);
        else
            Snippets := [];
        end;
    end
    else if IsWorkspaceNode(Node) then
        Snippets := []
    else
    begin
        if FFilterUserID > 0 then
            Snippets := FSnippetService.GetSnippetsByCategory(CatID, FFilterUserID)
        else
            Snippets := FSnippetService.GetSnippetsByCategory(CatID, GetSelectedCategoryUserID);
    end;

    FillSnippetListView(Snippets);
end;

function TMainForm.GetSelectedCategoryUserID: Integer;
begin
    Result := GetWorkspaceUserID(tvCategories.Selected);
end;

function TMainForm.GetWorkspaceUserID(Node: TTreeNode): Integer;
var
    WorkspaceName: string;
    Users: TArray<TUserDTO>;
    User: TUserDTO;
    Cat: TCategoryDTO;
    CatID: Integer;
    ParentNode: TTreeNode;
begin
    if FFilterUserID > 0 then
        Exit(FFilterUserID);

    if IsWorkspaceNode(Node) then
    begin
        WorkspaceName := Node.Text;
        Users := FUserService.GetAllUsers;
        for User in Users do
            if SameText(User.Name, WorkspaceName) then
                Exit(User.ID);
    end;

    if (Node <> nil) and not IsVirtualCategory(Node) and (Node.Data <> nil) then
    begin
        CatID := Integer(IntPtr(Node.Data));
        Cat := FCategoryService.GetCategoryByID(CatID);
        if Cat.ID > 0 then
            Exit(Cat.UserID);
    end;

    if Node <> nil then
    begin
        ParentNode := Node.Parent;
        while ParentNode <> nil do
        begin
            if IsWorkspaceNode(ParentNode) then
            begin
                WorkspaceName := ParentNode.Text;
                Users := FUserService.GetAllUsers;
                for User in Users do
                    if SameText(User.Name, WorkspaceName) then
                        Exit(User.ID);
            end;
            ParentNode := ParentNode.Parent;
        end;
    end;

    Result := FUserID;
end;

procedure TMainForm.tvCategoriesChange(Sender: TObject; Node: TTreeNode);
begin
    if FIgnoreCategoryChange then
        Exit;
    if Node = nil then
        Exit;

    FFilterByTagID := 0;
    RefreshCurrentSnippetList;
    ClearRightPanel;
    UpdateMenuState;
end;

procedure TMainForm.tvCategoriesClick(Sender: TObject);
begin
    UpdateMenuState;
end;

procedure TMainForm.DisplaySearchResults(const Results: TArray<TSnippetDTO>);
begin
    FillSnippetListView(Results);
end;

procedure TMainForm.DoAddCategory;
var
    Node: TTreeNode;
    ParentID, TargetUserID, NewCatID: Integer;
    NewCatName: string;
    NewCat: TCategoryDTO;
begin
    Node := tvCategories.Selected;

    if Node = nil then
    begin
        FErrorHandler.ShowError('Сначала выбери пространство или категорию.');
        Exit;
    end;

    if IsVirtualCategory(Node) then
    begin
        FErrorHandler.ShowError('Нельзя добавлять категории в виртуальные папки.');
        Exit;
    end;

    if IsWorkspaceNode(Node) then
        ParentID := 0
    else
        ParentID := Integer(IntPtr(Node.Data));

    TargetUserID := GetWorkspaceUserID(Node);
    NewCatName := Trim(InputBox('Новая категория', 'Введите имя:', 'Новая категория'));

    if NewCatName = '' then
        Exit;

    try
        NewCat := Default(TCategoryDTO);
        NewCat.Name := NewCatName;
        NewCat.ParentID := ParentID;
        NewCat.UserID := TargetUserID;

        NewCatID := FCategoryService.CreateCategory(NewCat);
        ReloadUI(NewCatID);

        Node := tvCategories.Selected;
        if (Node <> nil) and (Integer(IntPtr(Node.Data)) = NewCatID) then
            Node.EditText;

        sbBottom.SimpleText := Format('Категория "%s" создана.', [NewCatName]);
    except
        on E: Exception do
            FErrorHandler.ShowError('Ошибка создания категории: ' + E.Message);
    end;
end;

procedure TMainForm.DoDeleteCategory;
var
    Node: TTreeNode;
    Cat: TCategoryDTO;
begin
    Node := tvCategories.Selected;
    if (Node = nil) or IsVirtualCategory(Node) then
        Exit;

    Cat := FCategoryService.GetCategoryByID(Integer(IntPtr(Node.Data)));

    if MessageBox(Handle, PChar(Format('Удалить категорию "%s" и все её вложенные элементы?', [Cat.Name])), 'Подтверждение', MB_YESNO or MB_ICONQUESTION) = IDYES then
    begin
        try
            FCategoryService.DeleteCategory(Cat.ID);
            ReloadUI(PRESERVE_CATEGORY_EMPTY_ID);
            ClearRightPanel;
            sbBottom.SimpleText := Format('Категория "%s" удалена.', [Cat.Name]);
        except
            on E: Exception do
                FErrorHandler.ShowError('Ошибка удаления категории: ' + E.Message);
        end;
    end;
end;

procedure TMainForm.DoRenameCategory;
var
    Node: TTreeNode;
begin
    Node := tvCategories.Selected;
    if Node = nil then
        Exit;

    if IsWorkspaceNode(Node) then
        FErrorHandler.ShowError('Для переименования пространства используй кнопку "Управление пространствами".')
    else if not IsVirtualCategory(Node) then
        Node.EditText;
end;

procedure TMainForm.tvCategoriesEdited(Sender: TObject; Node: TTreeNode; var S: string);
var
    Cat: TCategoryDTO;
    OldName: string;
begin
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
        Cat := FCategoryService.GetCategoryByID(Integer(IntPtr(Node.Data)));
        FCategoryService.RenameCategory(Cat.ID, S);
    except
        on E: Exception do
        begin
            FErrorHandler.ShowError('Ошибка переименования: ' + E.Message);
            S := OldName;
        end;
    end;
end;

procedure TMainForm.tvCategoriesDragDrop(Sender, Source: TObject; X, Y: Integer);
var
    TargetNode, SourceNode: TTreeNode;
    NewParentID, SourceID, Position: Integer;
    HitTest: THitTests;
begin
    if (Source = tvCategories) and (tvCategories.Selected <> nil) then
    begin
        SourceNode := tvCategories.Selected;
        SourceID := Integer(IntPtr(SourceNode.Data));
        if SourceID < 0 then
            Exit;

        HitTest := tvCategories.GetHitTestInfoAt(X, Y);
        TargetNode := tvCategories.GetNodeAt(X, Y);
        if IsVirtualCategory(TargetNode) or IsWorkspaceNode(TargetNode) then
            Exit;

        if (htOnItem in HitTest) and (TargetNode <> nil) then
        begin
            NewParentID := Integer(TargetNode.Data);
            Position := -1;
        end
        else if TargetNode <> nil then
        begin
            if Y < TargetNode.DisplayRect(False).Top then
            begin
                if TargetNode.Parent <> nil then
                    NewParentID := Integer(TargetNode.Parent.Data)
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
            FCategoryService.MoveCategory(SourceID, NewParentID, Position);
            ReloadUI(SourceID);
        except
            on E: Exception do
                FErrorHandler.ShowError('Ошибка перемещения: ' + E.Message);
        end;
    end;
end;

procedure TMainForm.tvCategoriesDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
var
    TargetNode, SourceNode: TTreeNode;
begin
    Accept := False;
    TargetNode := tvCategories.GetNodeAt(X, Y);
    if (Source = tvCategories) and (tvCategories.Selected <> nil) then
    begin
        SourceNode := tvCategories.Selected;
        if IsVirtualCategory(TargetNode) or IsVirtualCategory(SourceNode) or IsWorkspaceNode(TargetNode) then
            Exit;
        if TargetNode <> nil then
            Accept := not IsDescendant(SourceNode, TargetNode)
        else
            Accept := True;
    end;
    tvCategories.Cursor := IfThen(IsVirtualCategory(TargetNode) or IsWorkspaceNode(TargetNode), crNo, crDefault);
end;

procedure TMainForm.tvCategoriesMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
    Node: TTreeNode;
begin
    if Button = mbLeft then
    begin
        Node := tvCategories.GetNodeAt(X, Y);
        if IsVirtualCategory(Node) or IsWorkspaceNode(Node) then
            Exit;
        if (Node <> nil) and (Node.Selected) then
            tvCategories.BeginDrag(False, 5);
    end;
end;

procedure TMainForm.tvCategoriesEndDrag(Sender, Target: TObject; X, Y: Integer);
begin
    tvCategories.Cursor := crDefault;
end;

procedure TMainForm.Initialize(AppContext: IAppContext);
begin
    FAppContext := AppContext;
    FDBManager := AppContext.DatabaseManager;
    FSnippetService := AppContext.SnippetService;
    FCategoryService := AppContext.CategoryService;
    FTagService := AppContext.TagService;
    FUserService := AppContext.UserService;
    FPasswordService := AppContext.PasswordService;
    FSettingsManager := AppContext.SettingsManager;
    FWindowHelper := AppContext.WindowHelper;

    FHotkeyMgr := TGlobalHotkeyManager.Create(
        AppContext
    );
    FHotkeyMgr.StartListening;

    for var Item in FSettingsManager.Data.AllowedApplications do
        if Item.Enabled then
            WinMonitor.AddAllowedProcess(Item.ExeName.ToLower);

    WinMonitor.StartMonitoring;
end;

function TMainForm.IsDescendant(Parent, Node: TTreeNode): Boolean;
begin
    Result := False;
    while Node <> nil do
    begin
        if Node = Parent then
            Exit(True);
        Node := Node.Parent;
    end;
end;

procedure TMainForm.lvSnippetsClick(Sender: TObject);
var
    Item: TListItem;
begin
    Item := lvSnippets.Selected;
    if not Assigned(Item) then
    begin
        ClearRightPanel;
        UpdateUI(bfsDBConnected);
        Exit;
    end;
    FillUserInterfaceFromSnippet(ExtractSnippetByListItem(Item));
    UpdateUI(bfsDBConnected);
end;

procedure TMainForm.DoAddSnippet;
var
    Node: TTreeNode;
    CategoryID, TargetUserID: Integer;
begin
    Node := tvCategories.Selected;

    if (Node = nil) or IsVirtualCategory(Node) or IsWorkspaceNode(Node) then
    begin
        FErrorHandler.ShowError('Выбери конкретную категорию для добавления сниппета.');
        Exit;
    end;

    CategoryID := Integer(IntPtr(Node.Data));
    TargetUserID := GetWorkspaceUserID(Node);

    if TargetUserID <= 0 then
    begin
        FErrorHandler.ShowInfo(Format('Не удалось определить пространство для сниппета (UserID=%d). Попробуй выбрать конкретное пространство в фильтре.', [TargetUserID]));
        Exit;
    end;

    AddEditSnippetForm := TAddEditSnippet.Create(Application, FAppContext);
    try
        AddEditSnippetForm.CategoryID := CategoryID;
        AddEditSnippetForm.UserID := TargetUserID;

        var NewSnippet := Default(TSnippetDTO);
        AddEditSnippetForm.Prepare(False, NewSnippet, CategoryID, TargetUserID);

        if AddEditSnippetForm.ShowModal = mrOk then
            ReloadUI(CategoryID);
    finally
        AddEditSnippetForm.Free;
    end;
end;

procedure TMainForm.DoEditSnippet;
var
    Item: TListItem;
    Snippet: TSnippetDTO;
    Node: TTreeNode;
    CategoryID: Integer;
begin
    Item := lvSnippets.Selected;
    if not Assigned(Item) then
        Exit;

    Snippet := ExtractSnippetByListItem(Item);
    Node := tvCategories.Selected;

    if (Node <> nil) and not IsVirtualCategory(Node) and (Node.Data <> nil) then
        CategoryID := Integer(IntPtr(Node.Data))
    else
        CategoryID := Snippet.CategoryID;


    AddEditSnippetForm := TAddEditSnippet.Create(MainForm, FAppContext);
    try
        AddEditSnippetForm.Snippet := Snippet;
        AddEditSnippetForm.CategoryID := CategoryID;
        AddEditSnippetForm.UserID := Snippet.UserID;

        AddEditSnippetForm.Prepare(True, Snippet, CategoryID, Snippet.UserID);

        if AddEditSnippetForm.ShowModal = mrOk then
        begin
            if tvCategories.Selected <> nil then
                ReloadUI(Integer(tvCategories.Selected.Data))
            else
                ReloadUI(PRESERVE_CATEGORY_EMPTY_ID);
        end;
    finally
        AddEditSnippetForm.Free;
    end;

    ebSearch.OnChange(ebSearch);
end;

procedure TMainForm.DoDeleteSnippet;
var
    Item: TListItem;
    Snippet: TSnippetDTO;
    SelectedCatID: Integer;
begin
    Item := lvSnippets.Selected;
    if Item = nil then
        Exit;

    Snippet := ExtractSnippetByListItem(Item);

    // TODO: Вынести в IUIErrorHandler
    if MessageBox(Handle, PChar(Format('Удалить сниппет "%s"?', [Snippet.Title])), 'Подтверждение', MB_YESNO or MB_ICONQUESTION) = IDYES then
    begin
        try
            FSnippetService.DeleteSnippet(Snippet.ID);

            if tvCategories.Selected <> nil then
                SelectedCatID := Integer(tvCategories.Selected.Data)
            else
                SelectedCatID := PRESERVE_CATEGORY_EMPTY_ID;

            ClearRightPanel;
            ReloadUI(SelectedCatID);
            sbBottom.SimpleText := 'Сниппет удалён.';
        except
            on E: Exception do
                FErrorHandler.ShowError('Ошибка удаления: ' + E.Message);
        end;
    end;
end;

procedure TMainForm.FillSnippetListView(const Snippets: TArray<TSnippetDTO>);
var
    Item: TListItem;
    Snippet: TSnippetDTO;
    ViewData: TSnippetViewData;
begin
    lvSnippets.Items.BeginUpdate;
    try
        lvSnippets.Items.Clear;
        for Snippet in Snippets do
        begin
            Item := lvSnippets.Items.Add;
            Item.Caption := Snippet.Title;
            Item.SubItems.Add(DateTimeToStr(UnixToDateTime(Snippet.CreatedAt)));
            Item.StateIndex := 0;

            if (Snippet.UpdatedAt > 0) then
                Item.SubItems.Add(DateTimeToStr(UnixToDateTime(Snippet.UpdatedAt)))
            else
                Item.SubItems.Add('');

            ViewData := TSnippetViewData.Create;
            ViewData.ID := Snippet.ID;
            ViewData.Title := Snippet.Title;
            ViewData.Content := Snippet.Content;
            ViewData.Comment := Snippet.Comment;
            Item.Data := ViewData;
        end;
    finally
        lvSnippets.Items.EndUpdate;
    end;
end;

procedure TMainForm.lvSnippetsDeletion(Sender: TObject; Item: TListItem);
begin
    if Assigned(Item.Data) then
        TSnippetViewData(Item.Data).Free;
end;

procedure TMainForm.lvSnippetsInfoTip(Sender: TObject; Item: TListItem; var InfoTip: string);
var
    Data: TSnippetViewData;
    Comment: string;
begin
    if Assigned(Item) and Assigned(Item.Data) then
    begin
        Data := TSnippetViewData(Item.Data);
        if (Data.Comment = '') then
            Comment := 'Без комментария'
        else
            Comment := Data.Comment;
        InfoTip := Format('[%s] %s'#13#10'%s', [Data.ID.ToString, Data.Title, Comment]);
    end;
end;

procedure TMainForm.lvSnippetsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
    HitTest: TLVHitTestInfo;
    TileRect: TRect;
    I: Integer;
begin
    ZeroMemory(@HitTest, SizeOf(HitTest));
    HitTest.pt := Point(X, Y);
    ListView_SubItemHitTest(lvSnippets.Handle, @HitTest);
    if HitTest.iItem >= 0 then
        Exit;

    for I := 0 to lvSnippets.Items.Count - 1 do
    begin
        TileRect.Left := 0;
        SendMessage(lvSnippets.Handle, LVM_GETITEMRECT, I, LPARAM(@TileRect));
        if PtInRect(TileRect, Point(X, Y)) then
        begin
            lvSnippets.Selected := lvSnippets.Items[I];
            lvSnippets.SetFocus;
            if Assigned(lvSnippets.OnClick) then
                lvSnippets.OnClick(Sender);
            Exit;
        end;
    end;
end;

procedure TMainForm.lvSnippetsDblClick(Sender: TObject);
var
    Item: TListItem;
    Runner: TSnippetRunner;
begin
    Item := lvSnippets.Selected;
    if Item = nil then
        Exit;

    Runner := TSnippetRunner.Create(FUserID, FWindowHelper);
    try
        Runner.ExecuteSnippet(ExtractSnippetByListItem(Item));
    finally
        Runner.Free;
    end;
end;

procedure TMainForm.DoAddTag;
var
    NewName: string;
    NewID: Integer;
begin
    if not InputQuery('Новый тег', 'Введите имя тега:', NewName) then
        Exit;
    NewName := Trim(NewName);
    if NewName = '' then
        Exit;

    try
        NewID := FTagService.CreateTag(NewName, '');

        with lvTags.Items.Add do
        begin
            Caption := NewName;
            Data := Pointer(NewID);
            StateIndex := 0;
            Selected := True;
            MakeVisible(False);
        end;
        sbBottom.SimpleText := Format('Тег "%s" добавлен.', [NewName]);
    except
        on E: Exception do
            FErrorHandler.ShowError('Ошибка добавления тега: ' + E.Message);
    end;
end;

procedure TMainForm.DoDeleteTag;
var
    Item: TListItem;
    TagID: Integer;
begin
    Item := lvTags.Selected;
    if Item = nil then
        Exit;

    TagID := Integer(Item.Data);
    if MessageBox(Handle, PChar(Format('Удалить тег "%s"?', [Item.Caption])), 'Подтверждение', MB_YESNO or MB_ICONQUESTION) <> IDYES then
        Exit;

    try
        FTagService.DeleteTag(TagID);
        Item.Delete;

        if FFilterByTagID = TagID then
            ClearTagFilter;

        if FCurrentSnippetID > 0 then
            TUIHelpers.FillTagListWithSelection(lvTags, FTagService.GetAllTags, FTagService.GetSnippetTags(FCurrentSnippetID));

        sbBottom.SimpleText := 'Тег удалён.';
    except
        on E: Exception do
            FErrorHandler.ShowError('Ошибка удаления тега: ' + E.Message);
    end;
end;

procedure TMainForm.DoRenameTag;
begin
    if lvTags.Selected <> nil then
        lvTags.Selected.EditCaption;
end;

procedure TMainForm.lvTagsEdited(Sender: TObject; Item: TListItem; var S: string);
var
    TagID: Integer;
    OldName: string;
begin
    OldName := Item.Caption;
    S := Trim(S);
    if (S = '') or (S = OldName) then
    begin
        S := OldName;
        Exit;
    end;

    try
        TagID := Integer(Item.Data);
        FTagService.RenameTag(TagID, S);
        sbBottom.SimpleText := Format('Тег переименован: "%s" → "%s"', [OldName, S]);
    except
        on E: Exception do
        begin
            FErrorHandler.ShowError('Ошибка переименования тега: ' + E.Message);
            S := OldName;
        end;
    end;
end;

procedure TMainForm.lvTagsDblClick(Sender: TObject);
var
    Item: TListItem;
begin
    Item := lvTags.Selected;
    if Item = nil then
        Exit;

    if FFilterByTagID = Integer(Item.Data) then
        ClearTagFilter
    else
        ApplyTagFilter(Integer(Item.Data), Item.Caption);
end;

procedure TMainForm.ApplyTagFilter(TagID: Integer; const TagName: string);
begin
    FFilterByTagID := TagID;
    FillSnippetListView(FSnippetService.GetSnippetsByTag(TagID));
    sbBottom.SimpleText := Format('Фильтр по тегу: "%s"', [TagName]);
end;

procedure TMainForm.ClearTagFilter;
begin
    FFilterByTagID := 0;
    if tvCategories.Selected <> nil then
        tvCategoriesChange(tvCategories, tvCategories.Selected)
    else
        lvSnippets.Items.Clear;
    sbBottom.SimpleText := 'Фильтр сброшен.';
end;

procedure TMainForm.ebSearchChange(Sender: TObject);
begin
    PerformSearchAsync(ebSearch.Text);
end;

procedure TMainForm.nOpenDatabaseClick(Sender: TObject);
begin
    OpenDialog.FileName := System.IOUtils.TPath.GetDirectoryName(Application.ExeName) + '\snippets.sqlite';
    if OpenDialog.Execute(Handle) then
    begin
        try
            FDBManager.OpenDatabase(OpenDialog.FileName);
            TStateMgr.Instance.OpenDatabase;
            ReloadUI(PRESERVE_CATEGORY_EMPTY_ID);
            LoadUsersToComboBox;
            ShowSimpleToast('Менеджер сниппетов', 'База данных SQLite открыта.');
        except
            on E: Exception do
                FErrorHandler.ShowError('Ошибка открытия базы данных: ' + E.Message);
        end;
    end;
end;

procedure TMainForm.NCreateDatabaseClick(Sender: TObject);
begin
    SaveDialog.FileName := System.IOUtils.TPath.GetDirectoryName(Application.ExeName) + '\snippets.sqlite';
    if SaveDialog.Execute(Handle) then
    begin
        Application.RestoreTopMosts;
        try
            FDBManager.CreateDatabase(SaveDialog.FileName);
            TStateMgr.Instance.CreateDatabase;
            ReloadUI(PRESERVE_CATEGORY_EMPTY_ID);
            LoadUsersToComboBox;
            ShowSimpleToast('Менеджер сниппетов', 'База данных SQLite создана.');
        except
            on E: Exception do
                FErrorHandler.ShowError('Ошибка создания базы данных: ' + E.Message);
        end;
    end;
end;

procedure TMainForm.nCloseDatabaseClick(Sender: TObject);
begin
    CloseDatabase;
end;

procedure TMainForm.CloseDatabase;
begin
    if Assigned(FDBManager) then
    begin
        FDBManager.CloseDatabase;
        TStateMgr.Instance.CloseDatabase;
        UpdateUI(bfsDBDisconnected);
    end;
end;

procedure TMainForm.cbUserChange(Sender: TObject);
begin
    if cbUser.ItemIndex >= 0 then
        SetUserFilter(Integer(cbUser.Items.Objects[cbUser.ItemIndex]));
end;

procedure TMainForm.SetUserFilter(UserID: Integer);
begin
    FFilterUserID := UserID;
    ReloadUI(PRESERVE_CATEGORY_EMPTY_ID);
end;

procedure TMainForm.LoadUsersToComboBox;
var
    Users: TArray<TUserDTO>;
    User: TUserDTO;
begin
    cbUser.Items.BeginUpdate;
    try
        cbUser.Clear;
        cbUser.Items.AddObject('Все пространства', TObject(0));
        Users := FUserService.GetAllUsers;
        for User in Users do
            cbUser.Items.AddObject(User.Name, TObject(Integer(User.ID)));
        cbUser.ItemIndex := 0;
    finally
        cbUser.Items.EndUpdate;
    end;
end;

procedure TMainForm.bManageWorkspacesClick(Sender: TObject);
begin
    with TWorkspaceManagerForm.Create(Self, FUserService) do
    try
        if ShowModal = mrOk then
            LoadUsersToComboBox;
    finally
        Free;
    end;
end;

function TMainForm.ExtractSnippetByListItem(Item: TListItem): TSnippetDTO;
begin
    if not Assigned(Item) then
        Exit(Default(TSnippetDTO));
    Result := FSnippetService.GetSnippetByID(TSnippetViewData(Item.Data).ID);
end;

procedure TMainForm.FillUserInterfaceFromSnippet(const Snippet: TSnippetDTO);
var
    User: TUserDTO;
    AllTags, SnippetTags: TArray<TTagDTO>;
begin
    FCurrentSnippetID := Snippet.ID;

    // Получаем пользователя
    User := FUserService.GetUserByID(Snippet.UserID);
    if User.ID > 0 then
        sbBottom.SimpleText := Format('[%d] %s (ID: %d) CID: %d', [Snippet.ID, User.Name, Snippet.UserID, Snippet.CategoryID]);

    mSnippet.Text := Snippet.Content;
    mComment.Text := Snippet.Comment;

    // Отрисовка тегов через TUIHelpers
    AllTags := FTagService.GetAllTags;
    SnippetTags := FTagService.GetSnippetTags(Snippet.ID);
    TUIHelpers.FillTagListWithSelection(lvTags, AllTags, SnippetTags);
end;

function TMainForm.IsVirtualCategory(Node: TTreeNode): Boolean;
begin
    Result := Assigned(Node) and (Integer(IntPtr(Node.Data)) < 0);
end;

function TMainForm.IsWorkspaceNode(Node: TTreeNode): Boolean;
begin
    Result := Assigned(Node) and (Node.Data = nil) and not IsVirtualCategory(Node);
end;

procedure TMainForm.nAddSnippetClick(Sender: TObject);
begin
    DoAddSnippet;
end;

procedure TMainForm.nEditSnippetClick(Sender: TObject);
begin
    DoEditSnippet;
end;

procedure TMainForm.nDeleteSnippetClick(Sender: TObject);
begin
    DoDeleteSnippet;
end;

procedure TMainForm.nAddCategoryClick(Sender: TObject);
begin
    DoAddCategory;
end;

procedure TMainForm.nDeleteCategoryClick(Sender: TObject);
begin
    DoDeleteCategory;
end;

procedure TMainForm.nEditCategoryClick(Sender: TObject);
begin
    DoRenameCategory;
end;

procedure TMainForm.nAddTagClick(Sender: TObject);
begin
    DoAddTag;
end;

procedure TMainForm.nDeleteTagClick(Sender: TObject);
begin
    DoDeleteTag;
end;

procedure TMainForm.nPasswordGeneratorClick(Sender: TObject);
begin
    TPasswordGenForm.ExecuteGlobal(Application, FPasswordService);
end;

procedure TMainForm.nRenameTagClick(Sender: TObject);
begin
    DoRenameTag;
end;

procedure TMainForm.nSearchClick(Sender: TObject);
begin
    if FDBManager.IsConnected then
        ebSearch.SetFocus;
end;

procedure TMainForm.nTagEditorClick(Sender: TObject);
begin
    with TTagEditorForm.Create(Self, FTagService) do
    try
        ShowModal;
    finally
        Free;
    end;
end;

procedure TMainForm.PerformSearchAsync(const Mask: string);
var
    TaskUserID: Integer;
    IsFTS: Boolean;
    SearchStr: string;
begin
    SearchStr := Trim(Mask);

    // Отменяем старую задачу в любом случае (даже если в строке 1 символ)
    if Assigned(FSearchTask) then
        FSearchTask.Cancel;

    // Если строка пустая - возвращаем пользователю обычный список его категории
    if SearchStr.IsEmpty then
    begin
        RefreshCurrentSnippetList; // Восстанавливаем список
        Exit;
    end;

    // Ждем минимум 3 символа для старта тяжелого запроса
    if SearchStr.Length < 3 then
        Exit;

    // Захватываем параметры UI для передачи в фон
    TaskUserID := FFilterUserID;
    IsFTS := rbFTS.Checked;

    FSearchTask := TTask.Run(
        procedure
        var
            BgConnection: TComponent;
            BgService: ISnippetService;
            Results: TArray<TSnippetDTO>;
        begin
            try
                // Создаем изолированный сервис
                BgService := FAppContext.CreateIsolatedSnippetService(BgConnection);
                try
                    // Проверяем, не успел ли пользователь ввести новую букву
                    if TTask.CurrentTask.Status = TTaskStatus.Canceled then Exit;

                    // Выполняем поиск
                    Results := BgService.SearchSnippets(SearchStr, IsFTS, TaskUserID);

                    if TTask.CurrentTask.Status = TTaskStatus.Canceled then Exit;

                    // Синхронизируем с главным потоком
                    TThread.Queue(nil,
                        procedure
                        begin
                            DisplaySearchResults(Results);
                        end
                    );
                finally
                    // Обязательно освобождаем коннект БД
                    if Assigned(BgConnection) then
                        BgConnection.Free;
                end;
            except
                on E: Exception do
                begin
                    // ЕСЛИ В ФОНЕ ПРОИЗОШЛА ОШИБКА БД, МЫ ДОЛЖНЫ ЭТО УВИДЕТЬ!
                    var ErrMsg := E.Message;
                    TThread.Queue(nil,
                        procedure
                        begin
                            FErrorHandler.ShowError('Ошибка фонового поиска: ' + ErrMsg);
                        end
                    );
                end;
            end;
        end
    );
end;

procedure TMainForm.rbTextClick(Sender: TObject);
begin
    ebSearchChange(Sender);
end;

procedure TMainForm.WMActivate(var Msg: TWMActivate);
begin
    // Если MainForm пытается стать активной во время выполнения макроса,
    // блокируем стандартную обработку активации. Это предотвращает
    // появление окна поверх терминала.
    if (Msg.Active = WA_ACTIVE) and (TSnippetRunner.IsExecuting) then
        Exit; // Игнорируем inherited

    // Прежняя логика: игнорируем активацию, если форма быстрого поиска ещё видима
    if (Msg.Active = WA_ACTIVE) and (QuickSearchForm <> nil) and (QuickSearchForm.Visible) then
         Exit; // Игнорируем inherited

    inherited;
end;

end.

