unit MainFormUI;

interface

uses
    Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
    System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
    Vcl.Menus, System.IOUtils, Vcl.ComCtrls, Vcl.ExtCtrls,
    System.DateUtils, System.Math, BaseFormUI, System.Generics.Collections,
    Snippet, System.ImageList, Vcl.ImgList, Vcl.StdCtrls, MacroEngine,
    HintTextEdit, HintTextMemo, Vcl.VirtualImageList, Vcl.BaseImageCollection, Vcl.ImageCollection;

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
        procedure bManageWorkspacesClick(Sender: TObject);
        procedure cbUserChange(Sender: TObject);
        procedure nOpenDatabaseClick(Sender: TObject);
        procedure NCreateDatabaseClick(Sender: TObject);
        procedure tvCategoriesChange(Sender: TObject; Node: TTreeNode);
        procedure lvSnippetsClick(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure lvSnippetsDblClick(Sender: TObject);
        procedure mCommentKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure nAddSnippetClick(Sender: TObject);
        procedure nEditSnippetClick(Sender: TObject);
        procedure ebSearchChange(Sender: TObject);
        procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
        procedure lvSnippetsDeletion(Sender: TObject; Item: TListItem);
        procedure mSnippetKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
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
        procedure lvTagsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure nAddCategoryClick(Sender: TObject);
        procedure nAddTagClick(Sender: TObject);
        procedure nCloseDatabaseClick(Sender: TObject);
        procedure nDeleteCategoryClick(Sender: TObject);
        procedure nDeleteSnippetClick(Sender: TObject);
        procedure nDeleteTagClick(Sender: TObject);
        procedure nEditCategoryClick(Sender: TObject);
        procedure nRenameTagClick(Sender: TObject);
        procedure tvCategoriesClick(Sender: TObject);
        procedure tvCategoriesEndDrag(Sender, Target: TObject; X, Y: Integer);
    private
        { Private declarations }
        FSnippetText: string;
        FSnippetComment: string;
        FSnippet: TSnippetDTO;
        FMacroEngine: TMacroEngine;
        FHotItemIndex: NativeInt;
        FFilterByTagID: NativeInt;
        FCurrentSnippetID: NativeInt;
        FUserID: NativeInt;
        FCategoryID: NativeInt;
        FFilterUserID: NativeInt;
        FIgnoreCategoryChange: Boolean;

        procedure ApplyTagFilter(ATagID: NativeInt; const ATagName: string);
        procedure ClearTagFilter;
        procedure FillSnippetListView(const Snippets: TArray<TSnippetDTO>);
        function ExtractSnippetByListItem(Item: TListItem): TSnippetDTO;
        procedure FillUserInterfaceFromSnippet(const Snippet: TSnippetDTO);
        procedure SaveSnippetField(const Field: TSnippetField; const Fieldname, NewValue, OldValue: string);
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
        procedure SetUserFilter(UserID: NativeInt);
        function IsVirtualCategory(Node: TTreeNode): Boolean;
        function IsWorkspaceNode(Node: TTreeNode): Boolean;
        procedure LoadUsersToComboBox;
        procedure UpdateMenuState;
        function GetSelectedCategoryUserID: NativeInt;
        procedure RefreshCurrentSnippetList;
        procedure ReloadUI(PreserveCategoryID: NativeInt);
        procedure ClearRightPanel;
        function GetWorkspaceUserID(Node: TTreeNode): NativeInt;
    public
        { Public declarations }
        procedure UpdateUI(const State: TBaseFormState); override;
    end;

var
    MainForm: TMainForm;

implementation

{$R *.dfm}

uses
    System.UITypes, Winapi.CommCtrl, System.Win.Notification, System.Notification,
    Vcl.Themes, Vcl.GraphUtil, System.Types, ArrayHelper, Settings, DataModule,
    TagEditorUI, UserRepository, User, TagRepository, Tag, CategoryRepository,
    Category, WindowHelper, AddEditSnippetUI, AppStateManager, UIHelpers,
    SnippetViewData, MacroActions, WindowMonitor, ProcessProfile,
    ChooseTerminalWindowUI, MacroInputTypes, InputFormUI, WorkspaceManagerUI, CommonHelpers, CommonConsts;

{ ======================== FORM LIFECYCLE ======================== }

procedure TMainForm.FormCreate(Sender: TObject);
begin
    // Вешаем невидимую "бирку" на Handle главной формы, чтобы вторая копия могла нас найти
    SetProp(Self.Handle, PChar(UNIQUE_APP_STR), 1);

    FUserID := 1;
    FIgnoreCategoryChange := False;
    TStateMgr.Instance.FirstRun;
    Settings.LoadSettingsFromJson;

    FSnippetText := '';
    FSnippetComment := '';
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

    with ProfileManager.AddProfile('xshell.exe') do
    begin
        TitleIncludeRegex := '.*';
        TitleExcludeRegex := '.*(Options|Settings|About|Настройки).*';
    end;
    with ProfileManager.AddProfile('putty.exe') do
    begin
        TitleIncludeRegex := '.*';
        TitleExcludeRegex := '.*(Change Settings|Event Log).*';
    end;

    for var Item in Settings.SettingsRecord.AllowedApplications do
        if Item.Enabled then
            WinMonitor.AddAllowedProcess(Item.ExeName.ToLower);

    WinMonitor.StartMonitoring;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
    FMacroEngine.Free;
    WinMonitor.StopMonitoring;
    // Удаляем свойство из памяти Windows
    RemoveProp(Self.Handle, PChar(UNIQUE_APP_STR));
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
    DataModuleCommon.CloseDatabase;
    CanClose := True;
end;

{ ======================== UI STATE & UPDATES ======================== }

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
                cbUser.Enabled := True;
                ebSearch.Enabled := True;
                bManageWorkspaces.Enabled := True;
                UpdateMenuState;
            end;
        bfsDBDisconnected:
            begin
                nCloseDatabase.Enabled := False;
                nAddSnippet.Enabled := False;
                nEditSnippet.Enabled := False;
                nDeleteSnippet.Enabled := False;
                mSnippet.ReadOnly := True;
                mSnippet.Text := '';
                mComment.ReadOnly := True;
                mComment.Text := '';
                lvSnippets.Items.Clear;
                lvTags.Items.Clear;
                tvCategories.Items.Clear;
                nAddTag.Enabled := False;
                nDeleteTag.Enabled := False;
                nRenameTag.Enabled := False;
                nAddCategory.Enabled := False;
                nDeleteCategory.Enabled := False;
                nEditCategory.Enabled := False;
                cbUser.Enabled := False;
                ebSearch.Enabled := False;
                bManageWorkspaces.Enabled := False;
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

    // Добавлять категорию можно в реальные категории И в workspace-узлы (в корень)
    nAddCategory.Enabled := (Node <> nil) and not IsVirtual;

    // Удалять и редактировать можно только реальные категории
    nDeleteCategory.Enabled := (Node <> nil) and not IsVirtual and not IsWorkspace;
    nEditCategory.Enabled := (Node <> nil) and not IsVirtual and not IsWorkspace;

    // Добавлять сниппеты можно только в реальные категории
    nAddSnippet.Enabled := (Node <> nil) and not IsVirtual and not IsWorkspace;

    // Удалять и редактировать сниппеты можно из любых списков
    nDeleteSnippet.Enabled := (lvSnippets.Selected <> nil);
    nEditSnippet.Enabled := (lvSnippets.Selected <> nil);
end;

procedure TMainForm.ClearRightPanel;
begin
    mSnippet.Text := '';
    mComment.Text := '';
    FSnippetText := '';
    FSnippetComment := '';
    FCurrentSnippetID := 0;
    TUIHelpers.BuildTagListWithSelection(lvTags, 0);
end;

procedure TMainForm.ReloadUI(PreserveCategoryID: NativeInt);
begin
    FIgnoreCategoryChange := True;
    try
        TUIHelpers.BuildCategoryTree(tvCategories, FFilterUserID, PreserveCategoryID);
        RefreshCurrentSnippetList;
    finally
        FIgnoreCategoryChange := False;
    end;
    UpdateMenuState;
end;

procedure TMainForm.RefreshCurrentSnippetList;
var
    Node: TTreeNode;
    CatID: NativeInt;
    Snippets: TArray<TSnippetDTO>;
begin
    Node := tvCategories.Selected;
    if Node = nil then
    begin
        lvSnippets.Items.Clear;
        Exit;
    end;

    CatID := NativeInt(Node.Data);

    if IsVirtualCategory(Node) then
    begin
        case CatID of
            -1: Snippets := DataModuleCommon.SnippetRepository.GetTopSnippets(FUserID, 10);
            -2: Snippets := DataModuleCommon.SnippetRepository.GetRecentSnippets(FUserID, 10);
        else
            Snippets := [];
        end;
    end
    else if IsWorkspaceNode(Node) then
        Snippets := []
    else
    begin
        if FFilterUserID > 0 then
            Snippets := DataModuleCommon.SnippetRepository.GetSnippetByCategory(CatID, FFilterUserID)
        else
            Snippets := DataModuleCommon.SnippetRepository.GetSnippetByCategory(CatID, GetSelectedCategoryUserID);
    end;

    FillSnippetListView(Snippets);
end;

function TMainForm.GetSelectedCategoryUserID: NativeInt;
begin
    Result := GetWorkspaceUserID(tvCategories.Selected);
end;

function TMainForm.GetWorkspaceUserID(Node: TTreeNode): NativeInt;
var
    WorkspaceName: string;
    Users: TArray<TUserDTO>;
    User: TUserDTO;
    Cat: TCategoryDTO;
    CatID: NativeInt;
    ParentNode: TTreeNode;
begin
    Result := 0;

    // 1. Если выбран конкретный workspace в фильтре
    if FFilterUserID > 0 then
    begin
        OutputDebugString(PChar(Format('GetWorkspaceUserID: Using FFilterUserID=%d', [FFilterUserID])));
        Exit(FFilterUserID);
    end;

    // 2. Если выбран узел workspace в дереве
    if IsWorkspaceNode(Node) then
    begin
        WorkspaceName := Node.Text;
        OutputDebugString(PChar(Format('GetWorkspaceUserID: Looking for workspace "%s"', [WorkspaceName])));

        Users := DataModuleCommon.UserRepository.GetAll;
        for User in Users do
        begin
            if SameText(User.Name, WorkspaceName) then
            begin
                OutputDebugString(PChar(Format('GetWorkspaceUserID: Found workspace ID=%d', [User.ID])));
                Exit(User.ID);
            end;
        end;

        OutputDebugString(PChar(Format('GetWorkspaceUserID: Workspace "%s" not found in DB', [WorkspaceName])));
    end;

    // 3. Если выбрана реальная категория
    if (Node <> nil) and not IsVirtualCategory(Node) and (Node.Data <> nil) then
    begin
        CatID := NativeInt(Node.Data);
        OutputDebugString(PChar(Format('GetWorkspaceUserID: Checking category ID=%d', [CatID])));

        Cat := DataModuleCommon.CategoryRepository.GetByID(CatID);

        if Cat.ID > 0 then
        begin
            OutputDebugString(PChar(Format('GetWorkspaceUserID: Category found, UserID=%d', [Cat.UserID])));
            Exit(Cat.UserID);
        end
        else
        begin
            OutputDebugString(PChar(Format('GetWorkspaceUserID: Category ID=%d not found in DB', [CatID])));
        end;
    end;

    // 4. Если выбран дочерний узел, попробуем найти родителя-workspace
    if Node <> nil then
    begin
        OutputDebugString('GetWorkspaceUserID: Searching for parent workspace');
        ParentNode := Node.Parent;

        while ParentNode <> nil do
        begin
            if IsWorkspaceNode(ParentNode) then
            begin
                WorkspaceName := ParentNode.Text;
                OutputDebugString(PChar(Format('GetWorkspaceUserID: Found parent workspace "%s"', [WorkspaceName])));

                Users := DataModuleCommon.UserRepository.GetAll;
                for User in Users do
                begin
                    if SameText(User.Name, WorkspaceName) then
                    begin
                        OutputDebugString(PChar(Format('GetWorkspaceUserID: Parent workspace ID=%d', [User.ID])));
                        Exit(User.ID);
                    end;
                end;
            end;
            ParentNode := ParentNode.Parent;
        end;

        OutputDebugString('GetWorkspaceUserID: No parent workspace found');
    end;

    // 5. Fallback: текущий пользователь
    OutputDebugString(PChar(Format('GetWorkspaceUserID: Fallback to FUserID=%d', [FUserID])));
    Result := FUserID;
end;

{ ======================== TREEVIEW CATEGORIES ======================== }

procedure TMainForm.tvCategoriesChange(Sender: TObject; Node: TTreeNode);
begin
    if FIgnoreCategoryChange then Exit;
    if Node = nil then Exit;

    FFilterByTagID := 0;
    RefreshCurrentSnippetList;
    ClearRightPanel;
    UpdateMenuState;
end;

procedure TMainForm.tvCategoriesClick(Sender: TObject);
begin
    UpdateMenuState;
end;

procedure TMainForm.DoAddCategory;
var
    Node: TTreeNode;
    ParentID, TargetUserID, NewCatID: NativeInt;
    NewCatName: string;
begin
    Node := tvCategories.Selected;

    if Node = nil then
    begin
        ShowMessage('Сначала выбери пространство или категорию.');
        Exit;
    end;

    if IsVirtualCategory(Node) then
    begin
        ShowMessage('Нельзя добавлять категории в виртуальные папки.');
        Exit;
    end;

    // Определяем ParentID
    if IsWorkspaceNode(Node) then
        ParentID := 0 // Добавляем в корень workspace
    else
        ParentID := NativeInt(Node.Data); // Добавляем как подкатегорию

    // Определяем UserID для новой категории
    TargetUserID := GetWorkspaceUserID(Node);

    NewCatName := Trim(InputBox('Новая категория', 'Введите имя:', 'Новая категория'));
    if NewCatName = '' then Exit;

    if DataModuleCommon.CategoryRepository.ExistsInParent(NewCatName, ParentID, TargetUserID) then
    begin
        ShowMessage('Категория "' + NewCatName + '" уже существует в этой папке.');
        Exit;
    end;

    try
        NewCatID := DataModuleCommon.CategoryRepository.AddCategory(NewCatName, ParentID, TargetUserID);
        ReloadUI(NewCatID);

        Node := tvCategories.Selected;
        if (Node <> nil) and (NativeInt(Node.Data) = NewCatID) then
            Node.EditText;

        sbBottom.SimpleText := Format('Категория "%s" создана.', [NewCatName]);
    except
        on E: Exception do ShowMessage('Ошибка создания категории: ' + E.Message);
    end;
end;

procedure TMainForm.DoDeleteCategory;
var
    Node: TTreeNode;
    Cat: TCategoryDTO;
begin
    Node := tvCategories.Selected;
    if (Node = nil) or IsVirtualCategory(Node) then Exit;

    Cat := DataModuleCommon.CategoryRepository.GetByID(NativeInt(Node.Data));

    if MessageBox(Handle, PChar(Format('Удалить категорию "%s" и все её вложенные элементы?', [Cat.Name])),
        'Подтверждение', MB_YESNO or MB_ICONQUESTION) = IDYES then
    begin
        try
            DataModuleCommon.CategoryRepository.DeleteCategory(Cat.ID);
            ReloadUI(-999);
            ClearRightPanel;
            sbBottom.SimpleText := Format('Категория "%s" удалена.', [Cat.Name]);
        except
            on E: Exception do ShowMessage('Ошибка удаления категории: ' + E.Message);
        end;
    end;
end;

procedure TMainForm.DoRenameCategory;
var
    Node: TTreeNode;
begin
    Node := tvCategories.Selected;
    if Node = nil then Exit;
    if IsWorkspaceNode(Node) then
        ShowMessage('Для переименования пространства используй кнопку "Управление пространствами".')
    else if not IsVirtualCategory(Node) then
        Node.EditText;
end;

procedure TMainForm.tvCategoriesEdited(Sender: TObject; Node: TTreeNode; var S: string);
var
    Cat: TCategoryDTO;
    OldName: string;
begin
    if IsVirtualCategory(Node) or IsWorkspaceNode(Node) then begin S := Node.Text; Exit; end;

    OldName := Node.Text;
    S := Trim(S);
    if (S = '') or (S = OldName) then begin S := OldName; Exit; end;

    Cat := DataModuleCommon.CategoryRepository.GetByID(NativeInt(Node.Data));
    if DataModuleCommon.CategoryRepository.ExistsInParent(S, Cat.ParentID, Cat.UserID) then
    begin
        ShowMessage('Категория "' + S + '" уже существует в этом разделе.');
        S := OldName;
        Exit;
    end;

    try
        DataModuleCommon.CategoryRepository.UpdateName(Cat.ID, S);
    except
        on E: Exception do begin ShowMessage('Ошибка переименования: ' + E.Message); S := OldName; end;
    end;
end;

procedure TMainForm.tvCategoriesDragDrop(Sender, Source: TObject; X, Y: Integer);
var
    TargetNode, SourceNode: TTreeNode;
    NewParentID, SourceID, Position: NativeInt;
    HitTest: THitTests;
begin
    if (Source = tvCategories) and (tvCategories.Selected <> nil) then
    begin
        SourceNode := tvCategories.Selected;
        SourceID := NativeInt(SourceNode.Data);
        if SourceID < 0 then Exit;

        HitTest := tvCategories.GetHitTestInfoAt(X, Y);
        TargetNode := tvCategories.GetNodeAt(X, Y);
        if IsVirtualCategory(TargetNode) or IsWorkspaceNode(TargetNode) then Exit;

        if (htOnItem in HitTest) and (TargetNode <> nil) then
        begin
            NewParentID := NativeInt(TargetNode.Data);
            Position := -1;
        end
        else if TargetNode <> nil then
        begin
            if Y < TargetNode.DisplayRect(False).Top then
            begin
                if TargetNode.Parent <> nil then NewParentID := NativeInt(TargetNode.Parent.Data) else NewParentID := 0;
                Position := TargetNode.Index;
            end
            else
            begin
                if TargetNode.Parent <> nil then NewParentID := NativeInt(TargetNode.Parent.Data) else NewParentID := 0;
                Position := TargetNode.Index + 1;
            end;
        end
        else
        begin
            NewParentID := 0;
            Position := -1;
        end;

        if (NewParentID < 0) or (SourceID = NewParentID) or IsDescendant(SourceNode, TargetNode) then Exit;

        try
            DataModuleCommon.CategoryRepository.MoveCategory(SourceID, NewParentID, Position);
            ReloadUI(SourceID);
        except
            on E: Exception do ShowMessage('Ошибка перемещения: ' + E.Message);
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
        if IsVirtualCategory(TargetNode) or IsVirtualCategory(SourceNode) or IsWorkspaceNode(TargetNode) then Exit;
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
        if IsVirtualCategory(Node) or IsWorkspaceNode(Node) then Exit;
        if (Node <> nil) and (Node.Selected) then
            tvCategories.BeginDrag(False, 5);
    end;
end;

procedure TMainForm.tvCategoriesEndDrag(Sender, Target: TObject; X, Y: Integer);
begin
    tvCategories.Cursor := crDefault;
end;

function TMainForm.IsDescendant(Parent, Node: TTreeNode): Boolean;
begin
    Result := False;
    while Node <> nil do
    begin
        if Node = Parent then Exit(True);
        Node := Node.Parent;
    end;
end;

{ ======================== LISTVIEW SNIPPETS ======================== }

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
    FSnippetText := ExtractSnippetByListItem(Item).Content;
    FSnippetComment := ExtractSnippetByListItem(Item).Comment;
    UpdateUI(bfsDBConnected);
end;

procedure TMainForm.DoAddSnippet;
var
    Node: TTreeNode;
    CategoryID, TargetUserID: NativeInt;
begin
    Node := tvCategories.Selected;

    var s: string;
    if Node <> nil then
        s := Node.Text
    else
        s := 'nil';

    {IFDEF DEBUG}
    OutputDebugString(PChar(Format('DoAddSnippet: Node=%s, IsVirtual=%s, IsWorkspace=%s',
        [s,
         BoolToStr(IsVirtualCategory(Node), True),
         BoolToStr(IsWorkspaceNode(Node), True)]))
    );
    {ENDIF}

    if (Node = nil) or IsVirtualCategory(Node) or IsWorkspaceNode(Node) then
    begin
        ShowMessage('Выбери конкретную категорию для добавления сниппета.');
        Exit;
    end;

    CategoryID := NativeInt(Node.Data);
    {IFDEF DEBUG}
    OutputDebugString(PChar(Format('DoAddSnippet: CategoryID=%d', [CategoryID])));
    {ENDIF}

    TargetUserID := GetWorkspaceUserID(Node);
    {IFDEF DEBUG}
    OutputDebugString(PChar(Format('DoAddSnippet: TargetUserID=%d', [TargetUserID])));
    {ENDIF}

    // Проверка: удалось ли определить UserID
    if TargetUserID <= 0 then
    begin
        ShowMessage(Format('Не удалось определить пространство для сниппета (UserID=%d). ' +
                           'Попробуйте выбрать конкретное пространство в фильтре.',
                           [TargetUserID])
        );
        Exit;
    end;

    AddEditSnippet := TAddEditSnippet.Create(Application);
    try
        TUIHelpers.BuildTagList(AddEditSnippet.lvAllTags);
        AddEditSnippet.CategoryID := CategoryID;
        AddEditSnippet.UserID := TargetUserID;

        {IFDEF DEBUG}
        OutputDebugString(
            PChar(Format('DoAddSnippet: Opening form with CategoryID=%d, UserID=%d',
            [CategoryID, TargetUserID]))
        );
        {ENDIF}

        if AddEditSnippet.ShowModal = mrOk then
            ReloadUI(CategoryID);
    finally
        AddEditSnippet.Free;
    end;
end;

procedure TMainForm.DoEditSnippet;
var
    Item: TListItem;
    Snippet: TSnippetDTO;
    Node: TTreeNode;
    CategoryID: NativeInt;
begin
    Item := lvSnippets.Selected;
    if not Assigned(Item) then Exit;

    Snippet := ExtractSnippetByListItem(Item);
    Node := tvCategories.Selected;

    if (Node <> nil) and not IsVirtualCategory(Node) and (Node.Data <> nil) then
        CategoryID := NativeInt(Node.Data)
    else
        CategoryID := Snippet.CategoryID;

    AddEditSnippet := TAddEditSnippet.Create(Application);
    try
        TUIHelpers.BuildTagList(AddEditSnippet.lvAllTags);
        AddEditSnippet.Snippet := Snippet;
        AddEditSnippet.CategoryID := CategoryID;
        AddEditSnippet.UserID := Snippet.UserID;

        if AddEditSnippet.ShowModal = mrOk then
        begin
            if tvCategories.Selected <> nil then
                ReloadUI(NativeInt(tvCategories.Selected.Data))
            else
                ReloadUI(-999);
        end;
    finally
        AddEditSnippet.Free;
    end;
end;

procedure TMainForm.DoDeleteSnippet;
var
    Item: TListItem;
    Snippet: TSnippetDTO;
    SelectedCatID: NativeInt;
begin
    Item := lvSnippets.Selected;
    if Item = nil then Exit;

    Snippet := ExtractSnippetByListItem(Item);

    if MessageBox(Handle, PChar(Format('Удалить сниппет "%s"?', [Snippet.Title])),
        'Подтверждение', MB_YESNO or MB_ICONQUESTION) = IDYES then
    begin
        try
            DataModuleCommon.SnippetRepository.Delete(Snippet.ID);
            if tvCategories.Selected <> nil then
                SelectedCatID := NativeInt(tvCategories.Selected.Data)
            else
                SelectedCatID := -999;

            ClearRightPanel;
            ReloadUI(SelectedCatID);
            sbBottom.SimpleText := 'Сниппет удалён.';
        except
            on E: Exception do ShowMessage('Ошибка удаления: ' + E.Message);
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
    I: NativeInt;
begin
    ZeroMemory(@HitTest, SizeOf(HitTest));
    HitTest.pt := Point(X, Y);
    ListView_SubItemHitTest(lvSnippets.Handle, @HitTest);
    if HitTest.iItem >= 0 then Exit;

    for I := 0 to lvSnippets.Items.Count - 1 do
    begin
        TileRect.Left := 0;
        SendMessage(lvSnippets.Handle, LVM_GETITEMRECT, I, LPARAM(@TileRect));
        if PtInRect(TileRect, Point(X, Y)) then
        begin
            lvSnippets.Selected := lvSnippets.Items[I];
            lvSnippets.SetFocus;
            if Assigned(lvSnippets.OnClick) then lvSnippets.OnClick(Sender);
            Exit;
        end;
    end;
end;

procedure TMainForm.lvSnippetsDblClick(Sender: TObject);
var
    Item: TListItem;
    Snippet: TSnippetDTO;
    Context: TMacroContext;
    TargetWindow: TWindowMonitorInfo;
begin
    Item := lvSnippets.Selected;
    if Item = nil then Exit;

    if not WinMonitor.CanAutoType then
    begin
        MessageBeep(MB_ICONHAND);
        ShowMessage('Не найдено разрешённых окон терминала в истории.');
        Exit;
    end;

    if WinMonitor.AllowedWindowCount = 1 then
        TargetWindow := WinMonitor.GetLastAllowedWindow
    else
    begin
        with TChooseTerminalWindow.Create(Self) do
        try
            if ShowModal <> mrOk then Exit;
            TargetWindow := SelectedWindow;
        finally
            Free;
        end;
    end;

    if not IsWindow(TargetWindow.HWND) then
    begin
        MessageBeep(MB_ICONHAND);
        ShowMessage('Выбранное окно больше не существует.');
        Exit;
    end;

    Snippet := ExtractSnippetByListItem(Item);
    if Trim(Snippet.Content).IsEmpty then
    begin
        MessageBox(Handle, 'Текст сниппета пуст.', 'Внимание!', MB_OK or MB_ICONWARNING or MB_TOPMOST);
        Exit;
    end;

    if MessageBox(Handle, PChar(Format('Ввести сниппет в окно:' + sLineBreak + '"%s" (%s)?', [TargetWindow.WindowTitle, TargetWindow.ExeName])),
        'Подтверждение', MB_YESNO or MB_ICONQUESTION or MB_TOPMOST) <> IDYES then Exit;

    Context := TMacroContext.Create;
    Context.Executor := WinHelper;
    Context.UserCancelled := False;
    Context.SnippetID := Snippet.ID;
    Context.UserID := FUserID;
    Context.OnInput := function(const Prompt: string): string
        begin
            Result := '';
            if ShowInputForm(Prompt, Context.CurrentDefaultValue, Context.CurrentInputType, Result) then
                Context.UserCancelled := False
            else
            begin
                Context.UserCancelled := True;
                Exit('');
            end;
        end;
    Context.OnConfirm := function(const Prompt: string): Boolean
        begin
            Result := MessageBox(IfThen(IsWindow(TargetWindow.HWND), TargetWindow.HWND, Application.Handle),
                PChar(Prompt), 'Подтверждение', MB_YESNO or MB_ICONQUESTION or MB_TOPMOST) = IDYES;
            if not Result then Context.UserCancelled := True;
        end;

    WinHelper.SetTargetWindow(TargetWindow.HWND);
    WinHelper.TypeTextIntoWindowWithContext(Snippet.Content, Context);
end;

{ ======================== TAGS & SEARCH ======================== }

procedure TMainForm.DoAddTag;
var
    NewName: string;
    TagDTO: TTagDTO;
begin
    if not InputQuery('Новый тег', 'Введите имя тега:', NewName) then Exit;
    NewName := Trim(NewName);
    if NewName = '' then Exit;

    try
        TagDTO.ID := 0;
        TagDTO.Name := NewName;
        DataModuleCommon.TagRepository.Add(TagDTO);
        with lvTags.Items.Add do
        begin
            Caption := NewName;
            Data := Pointer(NativeUInt(TagDTO.ID));
            StateIndex := 0;
            Selected := True;
            MakeVisible(False);
        end;
        sbBottom.SimpleText := Format('Тег "%s" добавлен.', [NewName]);
    except
        on E: Exception do ShowMessage('Ошибка добавления тега: ' + E.Message);
    end;
end;

procedure TMainForm.DoDeleteTag;
var
    Item: TListItem;
    TagID: NativeInt;
begin
    Item := lvTags.Selected;
    if Item = nil then Exit;

    TagID := NativeInt(NativeUInt(Item.Data));
    if MessageBox(Handle, PChar(Format('Удалить тег "%s"?', [Item.Caption])), 'Подтверждение', MB_YESNO or MB_ICONQUESTION) <> IDYES then Exit;

    try
        DataModuleCommon.TagRepository.Delete(TagID);
        Item.Delete;
        if FFilterByTagID = TagID then ClearTagFilter;
        if FCurrentSnippetID > 0 then TUIHelpers.BuildTagListWithSelection(lvTags, FCurrentSnippetID);
        sbBottom.SimpleText := 'Тег удалён.';
    except
        on E: Exception do ShowMessage('Ошибка удаления тега: ' + E.Message);
    end;
end;

procedure TMainForm.DoRenameTag;
begin
    if lvTags.Selected <> nil then lvTags.Selected.EditCaption;
end;

procedure TMainForm.lvTagsEdited(Sender: TObject; Item: TListItem; var S: string);
var
    TagDTO: TTagDTO;
    OldName: string;
begin
    OldName := Item.Caption;
    S := Trim(S);
    if (S = '') or (S = OldName) then begin S := OldName; Exit; end;

    try
        TagDTO.ID := NativeInt(NativeUInt(Item.Data));
        TagDTO.Name := S;
        DataModuleCommon.TagRepository.Update(TagDTO);
        sbBottom.SimpleText := Format('Тег переименован: "%s" → "%s"', [OldName, S]);
    except
        on E: Exception do begin ShowMessage('Ошибка переименования тега: ' + E.Message); S := OldName; end;
    end;
end;

procedure TMainForm.lvTagsDblClick(Sender: TObject);
var
    Item: TListItem;
begin
    Item := lvTags.Selected;
    if Item = nil then Exit;
    if FFilterByTagID = NativeInt(NativeUInt(Item.Data)) then ClearTagFilter
    else ApplyTagFilter(NativeInt(NativeUInt(Item.Data)), Item.Caption);
end;

procedure TMainForm.ApplyTagFilter(ATagID: NativeInt; const ATagName: string);
begin
    FFilterByTagID := ATagID;
    FillSnippetListView(DataModuleCommon.SnippetRepository.GetSnippetsByTag(ATagID));
    sbBottom.SimpleText := Format('Фильтр по тегу: "%s"', [ATagName]);
end;

procedure TMainForm.ClearTagFilter;
begin
    FFilterByTagID := 0;
    if tvCategories.Selected <> nil then tvCategoriesChange(tvCategories, tvCategories.Selected)
    else lvSnippets.Items.Clear;
    sbBottom.SimpleText := 'Фильтр сброшен.';
end;

procedure TMainForm.ebSearchChange(Sender: TObject);
begin
    if Length(ebSearch.Text) < 3 then
        FillSnippetListView(DataModuleCommon.SnippetRepository.GetAll)
    else
        FillSnippetListView(DataModuleCommon.SnippetRepository.SearchByMaskSimple(ebSearch.Text));
end;

{ ======================== SNIPPET FIELDS SAVE ======================== }

procedure TMainForm.SaveSnippetField(const Field: TSnippetField; const Fieldname, NewValue, OldValue: string);
var
    Item: TListItem;
    Snippet: TSnippetDTO;
begin
    if NewValue = OldValue then Exit;
    if MessageBox(Handle, PChar('Сохранить изменения в поле "' + Fieldname + '"?'), 'Сохранение', MB_YESNO) <> IDYES then Exit;

    Item := lvSnippets.Selected;
    if not Assigned(Item) then Exit;

    Snippet := ExtractSnippetByListItem(Item);
    case Field of
        sfContent: Snippet.Content := NewValue;
        sfComment: Snippet.Comment := NewValue;
    end;

    try
        DataModuleCommon.SnippetRepository.Update(Snippet);
        sbBottom.SimpleText := Fieldname + ' сохранён.';
    except
        on E: Exception do ShowMessage('Ошибка сохранения: ' + E.Message);
    end;
end;

procedure TMainForm.mSnippetKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if (ssCtrl in Shift) and (Key = Ord('S')) then
    begin
        SaveSnippetField(sfContent, 'Содержимое', mSnippet.Text, FSnippetText);
        Key := 0;
    end;
end;

procedure TMainForm.mCommentKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if (ssCtrl in Shift) and (Key = Ord('S')) then
    begin
        SaveSnippetField(sfComment, 'Комментарий', mComment.Text, FSnippetComment);
        Key := 0;
    end;
end;

{ ======================== DATABASE & WORKSPACES ======================== }

procedure TMainForm.nOpenDatabaseClick(Sender: TObject);
begin
    OpenDialog.FileName := System.IOUtils.TPath.GetDirectoryName(Application.ExeName) + '\snippets.sqlite';
    if OpenDialog.Execute(Handle) then
    begin
        try
            DataModuleCommon.OpenDatabase(OpenDialog.FileName);
            ReloadUI(-999);
            LoadUsersToComboBox;
            ShowSimpleToast('Менеджер сниппетов', 'База данных SQLite открыта.');
        except
            on E: Exception do ShowMessage('Ошибка открытия базы данных: ' + E.Message);
        end;
    end;
end;

procedure TMainForm.NCreateDatabaseClick(Sender: TObject);
begin
    SaveDialog.FileName := System.IOUtils.TPath.GetDirectoryName(Application.ExeName) + '\snippets.sqlite';
    if SaveDialog.Execute(Handle) then
    begin
        try
            DataModuleCommon.CreateDatabase(SaveDialog.FileName);
            ReloadUI(-999);
            LoadUsersToComboBox;
        except
            on E: Exception do ShowMessage('Ошибка создания базы данных: ' + E.Message);
        end;
    end;
end;

procedure TMainForm.nCloseDatabaseClick(Sender: TObject);
begin
    DataModuleCommon.CloseDatabase;
end;

procedure TMainForm.cbUserChange(Sender: TObject);
begin
    if cbUser.ItemIndex >= 0 then
        SetUserFilter(NativeInt(cbUser.Items.Objects[cbUser.ItemIndex]));
end;

procedure TMainForm.SetUserFilter(UserID: NativeInt);
begin
    FFilterUserID := UserID;
    ReloadUI(-999);
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
        Users := DataModuleCommon.UserRepository.GetAll;
        for User in Users do
            cbUser.Items.AddObject(User.Name, TObject(NativeInt(User.ID)));
        cbUser.ItemIndex := 0;
    finally
        cbUser.Items.EndUpdate;
    end;
end;

procedure TMainForm.bManageWorkspacesClick(Sender: TObject);
begin
    with TWorkspaceManagerForm.Create(Self) do
    try
        if ShowModal = mrOk then LoadUsersToComboBox;
    finally
        Free;
    end;
end;

{ ======================== HELPERS ======================== }

function TMainForm.ExtractSnippetByListItem(Item: TListItem): TSnippetDTO;
begin
    if not Assigned(Item) then Exit(Default(TSnippetDTO));
    Result := DataModuleCommon.SnippetRepository.GetByID(TSnippetViewData(Item.Data).ID);
end;

procedure TMainForm.FillUserInterfaceFromSnippet(const Snippet: TSnippetDTO);
var
    User: TUserDTO;
begin
    FCurrentSnippetID := Snippet.ID;
    if DataModuleCommon.UserRepository.TryGetByID(Snippet.UserID, User) then
        sbBottom.SimpleText := Format('[%d] %s (ID: %d) CID: %d', [Snippet.ID, User.Name, Snippet.UserID, Snippet.CategoryID]);
    mSnippet.Text := Snippet.Content;
    mComment.Text := Snippet.Comment;
    TUIHelpers.BuildTagListWithSelection(lvTags, Snippet.ID);
end;

function TMainForm.IsVirtualCategory(Node: TTreeNode): Boolean;
begin
    Result := Assigned(Node) and (NativeInt(Node.Data) < 0);
end;

function TMainForm.IsWorkspaceNode(Node: TTreeNode): Boolean;
begin
    Result := Assigned(Node) and (Node.Data = nil) and not IsVirtualCategory(Node);
end;

{ ======================== MENU HANDLERS ======================== }

procedure TMainForm.nAddSnippetClick(Sender: TObject); begin DoAddSnippet; end;
procedure TMainForm.nEditSnippetClick(Sender: TObject); begin DoEditSnippet; end;
procedure TMainForm.nDeleteSnippetClick(Sender: TObject); begin DoDeleteSnippet; end;
procedure TMainForm.nAddCategoryClick(Sender: TObject); begin DoAddCategory; end;
procedure TMainForm.nDeleteCategoryClick(Sender: TObject); begin DoDeleteCategory; end;
procedure TMainForm.nEditCategoryClick(Sender: TObject); begin DoRenameCategory; end;
procedure TMainForm.nAddTagClick(Sender: TObject); begin DoAddTag; end;
procedure TMainForm.nDeleteTagClick(Sender: TObject); begin DoDeleteTag; end;
procedure TMainForm.nRenameTagClick(Sender: TObject); begin DoRenameTag; end;

procedure TMainForm.nTagEditorClick(Sender: TObject);
begin
    with TTagEditorForm.Create(Self) do
    try
        TUIHelpers.BuildTagList(lvTags);
        ShowModal;
    finally
        Free;
    end;
end;

procedure TMainForm.lvTagsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    case Key of
        VK_INSERT: begin DoAddTag; Key := 0; end;
        VK_DELETE: begin DoDeleteTag; Key := 0; end;
        VK_F2: begin DoRenameTag; Key := 0; end;
    end;
end;

end.
