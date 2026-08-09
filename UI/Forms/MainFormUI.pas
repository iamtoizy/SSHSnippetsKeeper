unit MainFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces,
    GlobalHotkeyManager,
    Snippet,
    System.Actions,
    System.Classes,
    System.DateUtils,
    System.Generics.Collections,
    System.ImageList,
    System.IOUtils,
    System.SysUtils,
    System.Threading,
    Vcl.ActnList,
    Vcl.BaseImageCollection,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.Dialogs,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.ImageCollection,
    Vcl.ImgList,
    Vcl.Menus,
    Vcl.StdCtrls,
    Vcl.VirtualImageList,
    Winapi.Messages,
    Winapi.Windows
    ;

type
    TSnippetField = (sfContent, sfComment);

    TMainForm = class(TBaseForm)
        MainMenu: TMainMenu;
        nFile: TMenuItem;
        nOpenDatabase: TMenuItem;
        nCreateDatabase: TMenuItem;
        OpenDialog: TOpenDialog;
        SaveDialog: TSaveDialog;
        pLeft: TPanel;
        splLeft: TSplitter;
        tvCategories: TTreeView;
        sbBottom: TStatusBar;
        nTerminals: TMenuItem;
        nSnippets: TMenuItem;
        nAddSnippet: TMenuItem;
        nEditSnippet: TMenuItem;
        nCloseDatabase: TMenuItem;
        pTop: TPanel;
        ebSearch: TEdit;
        Splitter2: TSplitter;
        nTags: TMenuItem;
        nAddTag: TMenuItem;
        nDeleteTag: TMenuItem;
        nEditTag: TMenuItem;
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
        nTools: TMenuItem;
        nPasswordGenerator: TMenuItem;
        tmrSearchTimer: TTimer;
        nDataManagament: TMenuItem;
        nExit: TMenuItem;
        pmLanguage: TPopupMenu;
        nCronGenerator: TMenuItem;
        nEpochConverter: TMenuItem;
        nNetworkCalculator: TMenuItem;
        nChmodCalculator: TMenuItem;
        nArchiveBuilder: TMenuItem;
        ActionList: TActionList;
        actAddSnippet: TAction;
        actEditSnippet: TAction;
        actDeleteSnippet: TAction;
        actCreateDatabase: TAction;
        actOpenDatabase: TAction;
        actCloseDatabase: TAction;
        actAddCategory: TAction;
        actDeleteCategory: TAction;
        actEditCategory: TAction;
        actAddTag: TAction;
        actEditTag: TAction;
        actDeleteTag: TAction;
        actSearch: TAction;
        actPasswordGenerator: TAction;
        actCronGenerator: TAction;
        actEpochConverter: TAction;
        actNetworkCalculator: TAction;
        actChmodCalculator: TAction;
        actArchiveBuilder: TAction;
        nSettings: TMenuItem;
        N1: TMenuItem;
        actSettings: TAction;
        nSyncDatabase: TMenuItem;
        actSyncDatabase: TAction;
    tmrAutoSync: TTimer;
        procedure actAddCategoryExecute(Sender: TObject);
        procedure actAddSnippetExecute(Sender: TObject);
        procedure actAddTagExecute(Sender: TObject);
        procedure actArchiveBuilderExecute(Sender: TObject);
        procedure actChmodCalculatorExecute(Sender: TObject);
        procedure actCloseDatabaseExecute(Sender: TObject);
        procedure actCreateDatabaseExecute(Sender: TObject);
        procedure actCronGeneratorExecute(Sender: TObject);
        procedure actDeleteCategoryExecute(Sender: TObject);
        procedure actDeleteSnippetExecute(Sender: TObject);
        procedure actDeleteTagExecute(Sender: TObject);
        procedure actEditCategoryExecute(Sender: TObject);
        procedure actEditSnippetExecute(Sender: TObject);
        procedure actEditTagExecute(Sender: TObject);
        procedure actEpochConverterExecute(Sender: TObject);
        procedure actSyncDatabaseExecute(Sender: TObject);
        procedure actNetworkCalculatorExecute(Sender: TObject);
        procedure actOpenDatabaseExecute(Sender: TObject);
        procedure actPasswordGeneratorExecute(Sender: TObject);
        procedure actSearchExecute(Sender: TObject);
        procedure actSettingsExecute(Sender: TObject);
        procedure bManageWorkspacesClick(Sender: TObject);
        procedure cbUserChange(Sender: TObject);
        procedure tvCategoriesChange(Sender: TObject; Node: TTreeNode);
        procedure lvSnippetsClick(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure lvSnippetsDblClick(Sender: TObject);
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
        procedure lvTagsClick(Sender: TObject);
        procedure nTagEditorClick(Sender: TObject);
        procedure lvTagsDblClick(Sender: TObject);
        procedure lvTagsEdited(Sender: TObject; Item: TListItem; var S: string);
        procedure nExitClick(Sender: TObject);
        procedure rbTextClick(Sender: TObject);
        procedure sbBottomMouseDown(Sender: TObject; Button: TMouseButton; Shift:
            TShiftState; X, Y: Integer);
        procedure sbBottomResize(Sender: TObject);
        procedure tmrAutoSyncTimer(Sender: TObject);
        procedure tmrSearchTimerTimer(Sender: TObject);
        procedure tvCategoriesClick(Sender: TObject);
        procedure tvCategoriesEndDrag(Sender, Target: TObject; X, Y: Integer);
    private
        FHotItemIndex: Integer;
        FFilterByTagID: Integer;
        FCurrentSnippetID: Integer;
        FUserID: Integer;
        FFilterUserID: Integer;
        FIgnoreCategoryChange: Boolean;
        FHotkeyMgr: TGlobalHotkeyManager;
        FSearchTask: ITask;
        FIsDbDirty: Boolean;  // Флаг: "Были ли реальные изменения в БД?"

        procedure MarkDataChanged;
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
        function GetWorkspaceUserID(Node: TTreeNode): Integer;
        procedure CloseDatabase;
        //
        procedure PerformSearchAsync(const Mask: string);
        procedure DisplaySearchResults(const Results: TArray<TSnippetDTO>);
        procedure LoadAvailableLanguages;
        procedure LanguageMenuItemClick(Sender: TObject);
        // Синхронизация Markdown
        procedure PerformSync(IsAsync: Boolean);
        function GetCurrentDbSyncPath: string;
    protected
        procedure WMActivate(var Msg: TWMActivate); message WM_ACTIVATE;
        procedure DoInitialize; override;
    public
        procedure UpdateUI(const State: TBaseFormState); override;
    end;

var
    MainForm: TMainForm;

implementation

{$R *.dfm}

uses
    AddEditSnippetUI,
    AppStateManager,
    ArchiveBuilderFormUI,
    ArrayHelper,
    Category,
    ChmodFormUI,
    CommonConsts,
    CommonHelpers,
    Core.MarkdownExporter,
    Core.MarkdownImporter,
    CronGenFormUI,
    EpochConverterFormUI,
    HotkeyService,
    MacroInputTypes,
    NetworkFormUI,
    PasswordGenFormUI,
    QuickSearchFormUI,
    SettingsFormUI,
    SnippetRunner,
    SnippetViewData,
    System.Math,
    System.Types,
    System.UITypes,
    Tag,
    TagEditorUI,
    UI.Helpers,
    UI.HoverHelpManager,
    UI.StateLoader,
    User,
    Vcl.FileCtrl,
    Winapi.CommCtrl,
    WindowMonitor,
    WorkspaceManagerUI
    ;

const
    PRESERVE_CATEGORY_EMPTY_ID = -999;
    LANG_PANEL_INDEX = 1;

procedure TMainForm.actAddCategoryExecute(Sender: TObject);
begin
    DoAddCategory;
end;

procedure TMainForm.actAddSnippetExecute(Sender: TObject);
begin
    DoAddSnippet;
end;

procedure TMainForm.actAddTagExecute(Sender: TObject);
begin
    DoAddTag;
end;

procedure TMainForm.actArchiveBuilderExecute(Sender: TObject);
begin
    TArchiveBuilderForm.ExecuteGlobal(Self, AppContext);
end;

procedure TMainForm.actChmodCalculatorExecute(Sender: TObject);
begin
    TChmodForm.ExecuteGlobal(Self, AppContext);
end;

procedure TMainForm.actCloseDatabaseExecute(Sender: TObject);
begin
    CloseDatabase;
end;

procedure TMainForm.actCreateDatabaseExecute(Sender: TObject);
begin
    SaveDialog.InitialDir := GetDefaultDataDir;
    SaveDialog.FileName := 'snippets.sqlite';
    if SaveDialog.Execute(Handle) then
    begin
        try
            AppContext.DatabaseManager.CreateDatabase(SaveDialog.FileName);
            TStateMgr.Instance.CreateDatabase;

            LoadUsersToComboBox;  // Сначала выпадающий список
            cbUserChange(cbUser); // Применяем и перерисовываем дерево (ReloadUI)

            ShowSimpleToast(TUIStateLoader.GetMessage('DB.CreatedSuccess'));
        except
            on E: Exception do
                MessagesHandler.ShowError(TUIStateLoader.GetMessage('DB.CreateError', [E.Message]));
        end;
    end;
end;

procedure TMainForm.actCronGeneratorExecute(Sender: TObject);
begin
    TCronGenForm.ExecuteGlobal(Application, AppContext);
end;

procedure TMainForm.actDeleteCategoryExecute(Sender: TObject);
begin
    DoDeleteCategory;
end;

procedure TMainForm.actDeleteSnippetExecute(Sender: TObject);
begin
    DoDeleteSnippet;
end;

procedure TMainForm.actDeleteTagExecute(Sender: TObject);
begin
    DoDeleteTag;
end;

procedure TMainForm.actEditCategoryExecute(Sender: TObject);
begin
    DoRenameCategory;
end;

procedure TMainForm.actEditSnippetExecute(Sender: TObject);
begin
    DoEditSnippet;
end;

procedure TMainForm.actEditTagExecute(Sender: TObject);
begin
    DoRenameTag;
end;

procedure TMainForm.actEpochConverterExecute(Sender: TObject);
begin
    TEpochConverterForm.ExecuteGlobal(Self, AppContext);
end;

procedure TMainForm.actSyncDatabaseExecute(Sender: TObject);
begin
    PerformSync(True);
end;

procedure TMainForm.actNetworkCalculatorExecute(Sender: TObject);
begin
    TNetworkForm.ExecuteGlobal(Self, AppContext);
end;

procedure TMainForm.actOpenDatabaseExecute(Sender: TObject);
begin
    OpenDialog.InitialDir := GetDefaultDataDir;
    OpenDialog.FileName := 'snippets.sqlite';
    if OpenDialog.Execute(Handle) then
    begin
        try
            AppContext.DatabaseManager.OpenDatabase(OpenDialog.FileName);
            TStateMgr.Instance.OpenDatabase;

            LoadUsersToComboBox;  // Сначала загружаем выпадающий список
            cbUserChange(cbUser); // Вызываем OnChange, что инициирует ReloadUI с правильным ID

            ShowSimpleToast(TUIStateLoader.GetMessage('DB.OpenedSuccess'));

            // Авто-синхронизация при старте
            if AppContext.SettingsManager.Data.SyncOnStart then
            begin
                PerformSync(True); // Асинхронно, чтобы не тормозить показ формы
            end;
        except
            on E: Exception do
                MessagesHandler.ShowError(TUIStateLoader.GetMessage('DB.OpenError', [E.Message]));
        end;
    end;
end;

procedure TMainForm.actPasswordGeneratorExecute(Sender: TObject);
begin
    TPasswordGenForm.ExecuteGlobal(Application, AppContext.PasswordService, AppContext);
end;

procedure TMainForm.actSearchExecute(Sender: TObject);
begin
    if AppContext.DatabaseManager.IsConnected then
        ebSearch.SetFocus;
end;

procedure TMainForm.actSettingsExecute(Sender: TObject);
begin
    if Assigned(FHotkeyMgr) then
        FHotkeyMgr.StopListening;
    try
        TSettingsForm.ExecuteModal(Self, AppContext);
    finally
        if Assigned(FHotkeyMgr) then FHotkeyMgr.StartListening;
    end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
//    Winapi.Windows.DebugBreak;

    SetProp(Self.Handle, PChar(UNIQUE_APP_STR), 1);

    FUserID := 1;
    FIgnoreCategoryChange := False;

    FHotItemIndex := -1;
    FFilterByTagID := 0;
    FCurrentSnippetID := 0;
    FFilterUserID := 0;

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
        bfsDBConnected, bfsDBOpen:
            begin
                nCloseDatabase.Enabled := True;
                nSyncDatabase.Enabled := True;
                nSearch.Enabled := True;
                cbUser.Enabled := True;
                ebSearch.Enabled := True;
                bManageWorkspaces.Enabled := True;
                rbText.Enabled := True;
                rbFTS.Enabled := True;
                tvCategories.Enabled := True;
                lvSnippets.Enabled := True;

                // ВАЖНО: При открытии БД сниппет еще не выбран.
                UpdateUI(bfsSnippetDeselected);
            end;

        bfsDBDisconnected:
            begin
                nCloseDatabase.Enabled := False;
                nSyncDatabase.Enabled := False;
                nSearch.Enabled := False;
                cbUser.Enabled := False;
                ebSearch.Enabled := False;
                bManageWorkspaces.Enabled := False;
                rbText.Enabled := False;
                rbFTS.Enabled := False;
                tvCategories.Enabled := False;
                lvSnippets.Enabled := False;

                // Жестко отключаем все зависимые от контента меню
                nAddCategory.Enabled := False;
                nDeleteCategory.Enabled := False;
                nEditCategory.Enabled := False;

                nAddSnippet.Enabled := False;
                nEditSnippet.Enabled := False;
                nDeleteSnippet.Enabled := False;

                nAddTag.Enabled := False;
                nEditTag.Enabled := False;
                nDeleteTag.Enabled := False;

                // Очищаем списки
                lvSnippets.Items.Clear;
                lvTags.Items.Clear;
                tvCategories.Items.BeginUpdate;
                try
                    tvCategories.Items.Clear;
                finally
                    tvCategories.Items.EndUpdate;
                end;

                UpdateUI(bfsSnippetDeselected);
            end;

        // Сниппет выбран
        bfsSnippetSelected:
            begin
                UpdateMenuState; // Включит пункты "Изменить/Удалить сниппет"
            end;

        // Сниппет НЕ выбран
        bfsSnippetDeselected:
            begin
                UpdateMenuState; // Отключит пункты "Изменить/Удалить сниппет"

                // Сбрасываем теги
                if Assigned(lvTags) and Assigned(AppContext.TagService) then
                    TUIHelpers.FillTagListWithSelection(lvTags, AppContext.TagService.GetAllTags, []);
            end;
    end;
end;

procedure TMainForm.UpdateMenuState;
var
    Node: TTreeNode;
    IsVirtual, IsWorkspace: Boolean;
begin
    // Если база данных закрыта, элементы меню контролирует UpdateUI(bfsDBDisconnected)
    if (not Assigned(AppContext.DatabaseManager)) or (not AppContext.DatabaseManager.IsConnected) then
        Exit;

    Node := tvCategories.Selected;
    IsVirtual := IsVirtualCategory(Node);
    IsWorkspace := IsWorkspaceNode(Node);

    // --- КАТЕГОРИИ ---
    // Добавлять категории можно и в категорию, и в корень пространства (но не в вирт. папки)
    nAddCategory.Enabled := (Node <> nil) and not IsVirtual;
    // Удалять и редактировать пространство через это меню нельзя (для этого есть WorkspaceManager)
    nDeleteCategory.Enabled := (Node <> nil) and not IsVirtual and not IsWorkspace;
    nEditCategory.Enabled := (Node <> nil) and not IsVirtual and not IsWorkspace;

    // --- СНИППЕТЫ ---
    // Сниппеты можно добавлять только в конкретные категории
    actAddSnippet.Enabled := (Node <> nil) and not IsVirtual and not IsWorkspace;
    actDeleteSnippet.Enabled := (lvSnippets.Selected <> nil);
    actEditSnippet.Enabled := (lvSnippets.Selected <> nil);

    // --- ТЕГИ ---
    nAddTag.Enabled := True; // Создать новый тег можно всегда
    nDeleteTag.Enabled := (lvTags.Selected <> nil);
    nEditTag.Enabled := (lvTags.Selected <> nil);
end;

procedure TMainForm.ReloadUI(PreserveCategoryID: Integer);
var
    Cats: TArray<TCategoryDTO>;
    Users: TArray<TUserDTO>;
begin
    FIgnoreCategoryChange := True;
    try
        // Получаем данные через сервисы
        Cats := AppContext.CategoryService.GetAllCategories(FFilterUserID);
        Users := AppContext.UserService.GetAllUsers;

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

    if AppContext.DatabaseManager.IsConnected = False then
        Exit;

    CatID := Integer(IntPtr(Node.Data));

    if IsVirtualCategory(Node) then
    begin
        case CatID of
            -1:
                Snippets := AppContext.SnippetService.GetTopSnippets(FUserID, 10);
            -2:
                Snippets := AppContext.SnippetService.GetRecentSnippets(FUserID, 10);
        else
            Snippets := [];
        end;
    end
    else if IsWorkspaceNode(Node) then
        Snippets := []
    else
    begin
        if FFilterUserID > 0 then
            Snippets := AppContext.SnippetService.GetSnippetsByCategory(CatID, FFilterUserID)
        else
            Snippets := AppContext.SnippetService.GetSnippetsByCategory(CatID, GetSelectedCategoryUserID);
    end;

    FillSnippetListView(Snippets);
end;

function TMainForm.GetCurrentDbSyncPath: string;
var
    BaseDir, ConnStr, DbPath, DbName: string;
    Strings: TStringList;
begin
    BaseDir := Trim(AppContext.SettingsManager.Data.SyncDirectory);
    if BaseDir.IsEmpty then
        BaseDir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'SnippetsVault');

    // Пытаемся вытащить имя базы из строки подключения FireDAC
    ConnStr := AppContext.DatabaseManager.GetConnectionString;
    Strings := TStringList.Create;
    try
        Strings.Text := ConnStr;
        DbPath := Strings.Values['Database'];
    finally
        Strings.Free;
    end;

    // Если нашли - берем имя файла без расширения (например, "snippets" или "work")
    if DbPath <> '' then
        DbName := TPath.GetFileNameWithoutExtension(DbPath)
    else
        DbName := 'DefaultDB';

    // Формируем безопасный изолированный путь!
    Result := TPath.Combine(BaseDir, DbName);
end;

function TMainForm.GetSelectedCategoryUserID: Integer;
begin
    Result := GetWorkspaceUserID(tvCategories.Selected);
end;

function TMainForm.GetWorkspaceUserID(Node: TTreeNode): Integer;
var
    RootNode: TTreeNode;
    User: TUserDTO;
    Cat: TCategoryDTO;
begin
    // 1. Если включен жесткий фильтр по пользователю
    if FFilterUserID > 0 then
        Exit(FFilterUserID);

    if Node = nil then
        Exit(FUserID); // Дефолт

    // 2. Если это конкретная категория, просто берем её UserID из БД
    if not IsVirtualCategory(Node) and (Node.Data <> nil) then
    begin
        Cat := AppContext.CategoryService.GetCategoryByID(Integer(IntPtr(Node.Data)));
        if Cat.ID > 0 then
            Exit(Cat.UserID);
    end;

    // 3. Если это корень (Workspace), просто ищем его в закэшированном списке 1 раз
    RootNode := Node;
    while RootNode.Parent <> nil do
        RootNode := RootNode.Parent;

    if IsWorkspaceNode(RootNode) then
    begin
        for User in AppContext.UserService.GetAllUsers do
            if SameText(User.Name, RootNode.Text) then
                Exit(User.ID);
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
        MessagesHandler.ShowError(TUIStateLoader.GetMessage('Category.SelectPrompt'));
        Exit;
    end;

    if IsVirtualCategory(Node) then
    begin
        MessagesHandler.ShowError(TUIStateLoader.GetMessage('Category.VirtualFolderError'));
        Exit;
    end;

    if IsWorkspaceNode(Node) then
        ParentID := 0
    else
        ParentID := Integer(IntPtr(Node.Data));

    TargetUserID := GetWorkspaceUserID(Node);
    NewCatName := Trim(
        InputBox(
            TUIStateLoader.GetMessage('Category.NewDefaultName'),
            TUIStateLoader.GetMessage('Category.NewNamePrompt'),
            TUIStateLoader.GetMessage('Category.NewDefaultName')
        )
    );

    if NewCatName = '' then
        Exit;

    try
        NewCat := Default(TCategoryDTO);
        NewCat.Name := NewCatName;
        NewCat.ParentID := ParentID;
        NewCat.UserID := TargetUserID;

        NewCatID := AppContext.CategoryService.CreateCategory(NewCat);
        ReloadUI(NewCatID);

        Node := tvCategories.Selected;
        if (Node <> nil) and (Integer(IntPtr(Node.Data)) = NewCatID) then
            Node.EditText;

        sbBottom.Panels[0].Text := TUIStateLoader.GetMessage('Category.CreatedMsg', [NewCatName]);

        MarkDataChanged;
    except
        on E: Exception do
            MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('Category.CreateError', [E.Message])
            );
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

    Cat := AppContext.CategoryService.GetCategoryByID(Integer(IntPtr(Node.Data)));

    if MessagesHandler.AskConfirmation(
        TUIStateLoader.GetMessage('Category.DeleteWithChildrenConfirm', [Cat.Name]),
        TUIStateLoader.GetMessage('Common.Confirmation'),
        MB_YESNO or MB_ICONQUESTION
    ) then begin
        try
            AppContext.CategoryService.DeleteCategory(Cat.ID);
            ReloadUI(PRESERVE_CATEGORY_EMPTY_ID);
            sbBottom.Panels[0].Text := TUIStateLoader.GetMessage('Category.DeleteMsg', [Cat.Name]);
            MarkDataChanged;
        except
            on E: Exception do
                MessagesHandler.ShowError(
                    TUIStateLoader.GetMessage('Category.DeleteError', [E.Message])
                );
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
        MessagesHandler.ShowError(
            TUIStateLoader.GetMessage('Workspace.RenameError')
        )
    else if not IsVirtualCategory(Node) then
    begin
        Node.EditText;
    end;
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
        Cat := AppContext.CategoryService.GetCategoryByID(Integer(IntPtr(Node.Data)));
        AppContext.CategoryService.RenameCategory(Cat.ID, S);
        MarkDataChanged;
    except
        on E: Exception do
        begin
            MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('Category.RenameError', [E.Message])
            );
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
            AppContext.CategoryService.MoveCategory(SourceID, NewParentID, Position);
            ReloadUI(SourceID);
        except
            on E: Exception do
                MessagesHandler.ShowError(
                    TUIStateLoader.GetMessage('Category.MoveError', [E.Message])
                );
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

procedure TMainForm.DoInitialize;
begin
    // Строим меню языков в StatusBar
    LoadAvailableLanguages;

    // Регистрация подсказок
    RegisterHelp(tvCategories, hipTopRight, 'Help.MainForm.tvCategories', hkCustomForm);
    RegisterHelp(lvSnippets, hipTopRight, 'Help.MainForm.lvSnippets', hkCustomForm);
    RegisterHelp(lvTags, hipTopRight, 'Help.MainForm.lvTags', hkCustomForm);
    RegisterHelp(ebSearch, hipTopRight, 'Help.MainForm.ebSearch', hkCustomForm);

    FHotkeyMgr := TGlobalHotkeyManager.Create(
        AppContext
    );
    FHotkeyMgr.StartListening;

    for var Item in AppContext.SettingsManager.Data.AllowedApplications do
        if Item.Enabled then
            WinMonitor.AddAllowedProcess(Item.ExeName.ToLower);

    TStateMgr.Instance.FirstRun;

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
        UpdateUI(bfsSnippetDeselected);
        Exit;
    end;
    FillUserInterfaceFromSnippet(ExtractSnippetByListItem(Item));
    UpdateUI(bfsSnippetSelected);
end;

procedure TMainForm.DoAddSnippet;
var
    Node: TTreeNode;
    CategoryID, TargetUserID: Integer;
begin
    Node := tvCategories.Selected;

    if (Node = nil) or IsVirtualCategory(Node) or IsWorkspaceNode(Node) then
    begin
        MessagesHandler.ShowError(
            TUIStateLoader.GetMessage('Snippet.SelectPrompt')
        );
        Exit;
    end;

    CategoryID := Integer(IntPtr(Node.Data));
    TargetUserID := GetWorkspaceUserID(Node);

    if TargetUserID <= 0 then
    begin
        MessagesHandler.ShowInfo(
            TUIStateLoader.GetMessage('Snippet.WorkspaceUndefined', [TargetUserID])
        );
        Exit;
    end;

    if TAddEditSnippetForm.ExecuteAdd(Self, AppContext, CategoryID, TargetUserID) then
    begin
        MarkDataChanged;
        ReloadUI(CategoryID);
    end;
end;

procedure TMainForm.DoEditSnippet;
var
    Item: TListItem;
    Snippet: TSnippetDTO;
    Node: TTreeNode;
begin
    Item := lvSnippets.Selected;
    if not Assigned(Item) then
        Exit;

    Snippet := ExtractSnippetByListItem(Item);
    Node := tvCategories.Selected;

    if (Node <> nil) and not IsVirtualCategory(Node) and (Node.Data <> nil) then
        Snippet.CategoryID := Integer(IntPtr(Node.Data))
    else
        Snippet.CategoryID := Snippet.CategoryID;


    if TAddEditSnippetForm.ExecuteEdit(Self, AppContext, Snippet) then
    begin
        if tvCategories.Selected <> nil then
            ReloadUI(Integer(IntPtr(tvCategories.Selected.Data)))
        else
            ReloadUI(PRESERVE_CATEGORY_EMPTY_ID);

        MarkDataChanged;
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

    if MessagesHandler.AskConfirmation(
        TUIStateLoader.GetMessage('Snippet.DeleteConfirm', [Snippet.Title]),
        TUIStateLoader.GetMessage('Common.Confirmation'),
        MB_YESNO or MB_ICONQUESTION or MB_DEFBUTTON2
    ) then begin
        try
            AppContext.SnippetService.DeleteSnippet(Snippet.ID);

            if tvCategories.Selected <> nil then
                SelectedCatID := Integer(IntPtr(tvCategories.Selected.Data))
            else
                SelectedCatID := PRESERVE_CATEGORY_EMPTY_ID;

            ReloadUI(SelectedCatID);
            sbBottom.Panels[0].Text := TUIStateLoader.GetMessage('Snippet.DeletedMsg');
            MarkDataChanged;
        except
            on E: Exception do
                MessagesHandler.ShowError(
                    TUIStateLoader.GetMessage('Snippet.DeleteError', [E.Message])
                );
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
            Comment := TUIStateLoader.GetMessage('Snippet.NoComment')
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

    Runner := TSnippetRunner.Create(FUserID, AppContext);
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
    if not InputQuery(
        TUIStateLoader.GetMessage('Tag.NewDefaultName'),
        TUIStateLoader.GetMessage('Tag.NewPrompt'),
        NewName
    ) then Exit;

    NewName := Trim(NewName);
    if NewName = '' then
        Exit;

    try
        NewID := AppContext.TagService.CreateTag(NewName, '');

        with lvTags.Items.Add do
        begin
            Caption := NewName;
            Data := Pointer(NewID);
            StateIndex := 0;
            Selected := True;
            MakeVisible(False);
        end;
        sbBottom.Panels[0].Text:= TUIStateLoader.GetMessage('Tag.AddedMsg', [NewName]);
        MarkDataChanged;
    except
        on E: Exception do
            MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('Tag.AddError', [E.Message])
            );
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

    TagID := Integer(IntPtr(Item.Data));
    if MessagesHandler.AskConfirmation(
        TUIStateLoader.GetMessage('Tag.DeleteConfirm', [Item.Caption]),
        TUIStateLoader.GetMessage('Common.Confirmation'),
        MB_YESNO or MB_ICONQUESTION or MB_DEFBUTTON2
    ) then Exit;

    try
        AppContext.TagService.DeleteTag(TagID);
        Item.Delete;

        if FFilterByTagID = TagID then
            ClearTagFilter;

        if FCurrentSnippetID > 0 then
            TUIHelpers.FillTagListWithSelection(
                lvTags,
                AppContext.TagService.GetAllTags,
                AppContext.TagService.GetSnippetTags(FCurrentSnippetID)
            );

        sbBottom.Panels[0].Text := TUIStateLoader.GetMessage('Tag.DeletedMsg');
        MarkDataChanged;
    except
        on E: Exception do
            MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('Tag.DeleteError', [E.Message])
            );
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
        AppContext.TagService.RenameTag(TagID, S);
        sbBottom.Panels[0].Text := TUIStateLoader.GetMessage('Tag.RenamedMsg', [OldName, S]);
        MarkDataChanged;
    except
        on E: Exception do
        begin
            MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('Tag.RenameError', [E.Message])
            );
            S := OldName;
        end;
    end;
end;

procedure TMainForm.MarkDataChanged;
begin
    // Включаем флаг
    FIsDbDirty := True;

    // Перезапускаем таймер (эффект Debounce)
    // Если метод вызывается часто (пользователь активно работает),
    // таймер всё время сбрасывается и сработает только через 5 сек после ПОСЛЕДНЕГО изменения.
    tmrAutoSync.Enabled := False;

    if AppContext.SettingsManager.Data.SyncOnExit then
        tmrAutoSync.Enabled := True;
end;

procedure TMainForm.lvTagsDblClick(Sender: TObject);
var
    Item: TListItem;
begin
    Item := lvTags.Selected;
    if Item = nil then
        Exit;

    if FFilterByTagID = Integer(IntPtr(Item.Data)) then
        ClearTagFilter
    else
        ApplyTagFilter(Integer(IntPtr(Item.Data)), Item.Caption);
end;

procedure TMainForm.ApplyTagFilter(TagID: Integer; const TagName: string);
begin
    FFilterByTagID := TagID;
    FillSnippetListView(AppContext.SnippetService.GetSnippetsByTag(TagID));
    sbBottom.Panels[0].Text := TUIStateLoader.GetMessage('Tag.FilterPrefix', [TagName]);
end;

procedure TMainForm.ClearTagFilter;
begin
    FFilterByTagID := 0;
    if tvCategories.Selected <> nil then
        tvCategoriesChange(tvCategories, tvCategories.Selected)
    else
        lvSnippets.Items.Clear;
    sbBottom.Panels[0].Text := TUIStateLoader.GetMessage('Tag.FilterReset');
end;

procedure TMainForm.ebSearchChange(Sender: TObject);
begin
    tmrSearchTimer.Enabled := False;
    tmrSearchTimer.Enabled := True;
end;

procedure TMainForm.CloseDatabase;
begin
    if Assigned(AppContext.DatabaseManager) and AppContext.DatabaseManager.IsConnected then
    begin
        // Авто-синхронизация при закрытии
        // Если мы закрываем программу, а таймер еще тикает (прошло меньше 5 сек с последней правки)
        if FIsDbDirty and AppContext.SettingsManager.Data.SyncOnExit then
        begin
            tmrAutoSync.Enabled := False; // Глушим таймер
            // Важно! Вызываем СИНХРОННО (False). Программа "зависнет" на секунду,
            // но гарантированно допишет все файлы на жесткий диск перед закрытием.
            PerformSync(False);
        end;

        AppContext.DatabaseManager.CloseDatabase;
        TStateMgr.Instance.CloseDatabase;
        UpdateUI(bfsDBDisconnected);
    end;
end;

procedure TMainForm.cbUserChange(Sender: TObject);
begin
    if cbUser.ItemIndex >= 0 then
        SetUserFilter(Integer(IntPtr(cbUser.Items.Objects[cbUser.ItemIndex])));
end;

procedure TMainForm.SetUserFilter(UserID: Integer);
begin
    FFilterUserID := UserID;

    // 1. Сначала перестраиваем дерево категорий (слева) для нового пространства
    ReloadUI(PRESERVE_CATEGORY_EMPTY_ID);

    // 2. Если есть активный поиск, прогоняем его заново для нового пространства
    if Trim(ebSearch.Text) <> '' then
    begin
        PerformSearchAsync(ebSearch.Text);
    end;
end;

procedure TMainForm.LanguageMenuItemClick(Sender: TObject);
var
    MI: TMenuItem;
    LangCode: string;
    I, SelectedSnippetID, SelectedTagID: Integer;
    LocForm: ILocalizable;
    SelectedCatID: Integer;
begin
    MI := Sender as TMenuItem;
    LangCode := MI.Hint;
    MI.Checked := True;

    // Обновляем надпись в StatusBar
    sbBottom.Panels[LANG_PANEL_INDEX].Text := '🌐 ' + UpperCase(LangCode);

    // Сохраняем выбор в настройки
    AppContext.SettingsManager.CurrentLanguage := LangCode;
    AppContext.SettingsManager.Save;

    // Загружаем новый JSON-файл в память
    TUIStateLoader.LoadLanguageFile(ResolvePath('Translation\ui-texts.' + LangCode + '.json'));

    // Переводим все открытые окна
    for I := 0 to Screen.FormCount - 1 do
    begin
        if Supports(Screen.Forms[I], ILocalizable, LocForm) then
            LocForm.ApplyLanguage;
    end;

    // Сохранение текущего состояния
    SelectedCatID := PRESERVE_CATEGORY_EMPTY_ID;
    SelectedSnippetID := 0;
    SelectedTagID := 0;

    if tvCategories.Selected <> nil then
        SelectedCatID := Integer(IntPtr(tvCategories.Selected.Data));

    if lvSnippets.Selected <> nil then
        SelectedSnippetID := ExtractSnippetByListItem(lvSnippets.Selected).ID;

    if lvTags.Selected <> nil then
        SelectedTagID := Integer(IntPtr(lvTags.Selected.Data));

    // Только если база данных подключена
    if AppContext.DatabaseManager.IsConnected then
    begin
        // Блокируем перерисовку всех списков для мгновенного визуального обновления
        tvCategories.Items.BeginUpdate;
        lvSnippets.Items.BeginUpdate;
        lvTags.Items.BeginUpdate;
        try
            // Перезагрузка иерархии
            ReloadUI(SelectedCatID);

            // Восстановление выделения сниппета
            if SelectedSnippetID > 0 then
            begin
                for I := 0 to lvSnippets.Items.Count - 1 do
                begin
                    if TSnippetViewData(lvSnippets.Items[I].Data).ID = SelectedSnippetID then
                    begin
                        lvSnippets.Selected := lvSnippets.Items[I];
                        lvSnippets.ItemFocused := lvSnippets.Items[I];
                        lvSnippets.Items[I].MakeVisible(False);

                        // Имитируем клик. Это обновит нижнюю панель и ПЕРЕСТРОИТ lvTags.
                        lvSnippetsClick(lvSnippets);
                        Break;
                    end;
                end;
            end;

            // Восстановление выделения тега.
            // (Обязательно делать это после lvSnippetsClick, так как теги пересоздались)
            if SelectedTagID > 0 then
            begin
                for I := 0 to lvTags.Items.Count - 1 do
                begin
                    if Integer(IntPtr(lvTags.Items[I].Data)) = SelectedTagID then
                    begin
                        lvTags.Selected := lvTags.Items[I];
                        lvTags.ItemFocused := lvTags.Items[I];
                        lvTags.Items[I].MakeVisible(False);
                        Break;
                    end;
                end;
            end;

        finally
            // Возвращаем отрисовку
            tvCategories.Items.EndUpdate;
            lvSnippets.Items.EndUpdate;
            lvTags.Items.EndUpdate;
        end;
    end;
end;

procedure TMainForm.LoadAvailableLanguages;
var
    Files: TArray<string>;
    FileName, LangCode, TranslationsDir, CurrentLang: string;
    MI: TMenuItem;
begin
    TranslationsDir := ResolvePath('Translation', True);
    if not TDirectory.Exists(TranslationsDir) then Exit;

    Files := TDirectory.GetFiles(TranslationsDir, 'ui-texts.*.json');
    
    pmLanguage.Items.Clear;

    if Assigned(AppContext) then
        CurrentLang := AppContext.SettingsManager.Data.CurrentLanguage
    else
        CurrentLang := 'ru';

    for FileName in Files do
    begin
        // Извлекаем код языка: ui-texts.en.json -> en
        LangCode := ExtractFileName(FileName);
        LangCode := StringReplace(LangCode, 'ui-texts.', '', [rfIgnoreCase]);
        LangCode := StringReplace(LangCode, '.json', '', [rfIgnoreCase]);

        // Создаем пункт меню
        MI := TMenuItem.Create(pmLanguage);
        MI.Caption := UpperCase(LangCode); // 'RU', 'EN'
        MI.Hint := LangCode;
        MI.RadioItem := True;
        MI.GroupIndex := 1;
        MI.OnClick := LanguageMenuItemClick;

        pmLanguage.Items.Add(MI);

        // Отмечаем галочкой текущий язык без вызова MI.Click (избегаем рекурсии)
        if SameText(LangCode, CurrentLang) then
        begin
            MI.Checked := True;
            sbBottom.Panels[LANG_PANEL_INDEX].Text := '🌐 ' + UpperCase(LangCode);
        end;
    end;
end;

procedure TMainForm.LoadUsersToComboBox;
var
    Users: TArray<TUserDTO>;
    User: TUserDTO;
begin
    cbUser.Items.BeginUpdate;
    try
        cbUser.Clear;
        cbUser.Items.AddObject(TUIStateLoader.GetMessage('Workspace.AllSpaces'), TObject(0));
        Users := AppContext.UserService.GetAllUsers;
        for User in Users do
            cbUser.Items.AddObject(User.Name, TObject(Integer(User.ID)));
        cbUser.ItemIndex := 0;
    finally
        cbUser.Items.EndUpdate;
    end;
end;

procedure TMainForm.bManageWorkspacesClick(Sender: TObject);
begin
    if TWorkspaceManagerForm.ExecuteModal(Self, AppContext) = mrOk then
    begin
        LoadUsersToComboBox;  // Перезагружает список пространств и ставит ItemIndex := 0.
        cbUserChange(cbUser); // Явно вызываем OnChange. Он обновит FFilterUserID и вызовет ReloadUI.
    end;
end;

function TMainForm.ExtractSnippetByListItem(Item: TListItem): TSnippetDTO;
begin
    if not Assigned(Item) or not Assigned(Item.Data) then
        Exit(Default(TSnippetDTO));
    Result := AppContext.SnippetService.GetSnippetByID(TSnippetViewData(Item.Data).ID);
end;

procedure TMainForm.FillUserInterfaceFromSnippet(const Snippet: TSnippetDTO);
var
    User: TUserDTO;
    AllTags, SnippetTags: TArray<TTagDTO>;
begin
    FCurrentSnippetID := Snippet.ID;

    // Получаем пользователя
    User := AppContext.UserService.GetUserByID(Snippet.UserID);
    if User.ID > 0 then
        sbBottom.Panels[0].Text := Format('[%d] %s (ID: %d) CID: %d', [Snippet.ID, User.Name, Snippet.UserID, Snippet.CategoryID]);

    // Отрисовка тегов через TUIHelpers
    AllTags := AppContext.TagService.GetAllTags;
    SnippetTags := AppContext.TagService.GetSnippetTags(Snippet.ID);
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

procedure TMainForm.lvTagsClick(Sender: TObject);
begin
    UpdateMenuState;
end;

procedure TMainForm.nExitClick(Sender: TObject);
begin
    MainForm.Close;
end;

procedure TMainForm.nTagEditorClick(Sender: TObject);
begin
    TTagEditorForm.ExecuteGlobal(Application, AppContext);
end;

procedure TMainForm.PerformSearchAsync(const Mask: string);
var
    TaskUserID: Integer;
    IsFTS: Boolean;
    SearchStr: string;
begin
    SearchStr := Trim(Mask);

    if Assigned(FSearchTask) then
        FSearchTask.Cancel;

    if SearchStr.IsEmpty then
    begin
        RefreshCurrentSnippetList;
        Exit;
    end;

    if SearchStr.Length < 3 then
        Exit;

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
                BgService := AppContext.CreateIsolatedSnippetService(BgConnection);
                try
                    if TTask.CurrentTask.Status = TTaskStatus.Canceled then Exit;

                    // Вызываем сервис, передавая правильный TaskUserID
                    Results := BgService.SearchSnippets(SearchStr, IsFTS, TaskUserID);

                    if TTask.CurrentTask.Status = TTaskStatus.Canceled then Exit;

                    TThread.Queue(nil,
                        procedure
                        begin
                            if SameText(Trim(ebSearch.Text), SearchStr) then
                                DisplaySearchResults(Results);
                        end
                    );
                finally
                    if Assigned(BgConnection) then
                        BgConnection.Free;
                end;
            except
                // ... обработка ошибок (без изменений) ...
            end;
        end
    );
end;

procedure TMainForm.PerformSync(IsAsync: Boolean);
var
    SyncDir: string;
    DoSyncLogic: TProc;
begin
    if not AppContext.DatabaseManager.IsConnected then Exit;

    SyncDir := GetCurrentDbSyncPath;

    if not TDirectory.Exists(SyncDir) then
    begin
        try
            System.SysUtils.ForceDirectories(SyncDir);
        except
            on E: Exception do
            begin
                MessagesHandler.ShowError(TUIStateLoader.GetMessage('Common.SyncFolderCreationError', [E.Message]));
                Exit;
            end;
        end;
    end;

    actSyncDatabase.Enabled := False;
    sbBottom.Panels[0].Text := TUIStateLoader.GetMessage('Common.SyncingStorage');

    DoSyncLogic := procedure
    var
        BgConnection: TComponent;
        BgContext: IAppContext;
    begin
        try
            // ВАЖНО: Если мы в фоне, создаем изолированное подключение!
            // Если мы закрываем программу (IsAsync = False), можно безопасно использовать основной AppContext
            if IsAsync then
                BgContext := AppContext.CreateIsolatedContext(BgConnection)
            else
                BgContext := AppContext;

            try
                // Передаем BgContext вместо AppContext.
                // Теперь чтение/запись в БД идет в параллельном потоке SQLite и не трогает UI!
                TMarkdownImporter.ImportFromDirectory(BgContext, SyncDir);
                TMarkdownExporter.ExportDatabase(BgContext, SyncDir);

                TThread.Queue(nil, procedure
                begin
                    ReloadUI(PRESERVE_CATEGORY_EMPTY_ID);
                    sbBottom.Panels[0].Text := TUIStateLoader.GetMessage('Common.SyncCompleted');
                end);
            finally
                // Обязательно освобождаем фоновое подключение (DataModule), чтобы не было утечек памяти
                if IsAsync and Assigned(BgConnection) then
                    BgConnection.Free;
            end;
        except
            on E: Exception do
            begin
                var ErrMsg := E.Message;
                TThread.Queue(nil, procedure
                begin
                    MessagesHandler.ShowError(TUIStateLoader.GetMessage('Common.SyncError', [ErrMsg]));
                    sbBottom.Panels[0].Text := '';
                end);
            end;
        end;

        TThread.Queue(nil, procedure
        begin
            actSyncDatabase.Enabled := True;
        end);
    end;

    if IsAsync then
        TTask.Run(DoSyncLogic)  // Идеально плавный фоновый процесс
    else
    begin
        Application.ProcessMessages;
        DoSyncLogic();          // Синхронный вызов при выходе
    end;
end;

procedure TMainForm.rbTextClick(Sender: TObject);
begin
    ebSearchChange(Sender);
end;

procedure TMainForm.sbBottomMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
    I: Integer;
    R: TRect;
    Pt: TPoint;
begin
    // Реагируем только на клик левой кнопкой мыши
    if Button <> mbLeft then
        Exit;

    // Проходим по всем панелям StatusBar
    for I := 0 to sbBottom.Panels.Count - 1 do
    begin
        // Запрашиваем у Windows границы (Rect) панели с индексом I
        SendMessage(sbBottom.Handle, SB_GETRECT, I, NativeInt(@R));

        // Проверяем, попали ли координаты клика (X, Y) внутрь прямоугольника этой панели
        if PtInRect(R, Point(X, Y)) then
        begin
            // Если кликнули по панели с языком (LANG_PANEL_INDEX)
            if I = LANG_PANEL_INDEX then
            begin
                // Переводим верхний левый угол панели в экранные координаты
                Pt := sbBottom.ClientToScreen(Point(R.Left, R.Top));

                // Показываем всплывающее меню со списками языков
                pmLanguage.Popup(Pt.X, Pt.Y);
            end;

            Break; // Нашли нужную панель - выходим из цикла
        end;
    end;
end;

procedure TMainForm.sbBottomResize(Sender: TObject);
begin
    sbBottom.Panels[0].Width := sbBottom.ClientWidth - sbBottom.Panels[1].Width;
end;

procedure TMainForm.tmrAutoSyncTimer(Sender: TObject);
begin
    tmrAutoSync.Enabled := False; // Выключаем таймер

    // Если были изменения - запускаем фоновую синхронизацию!
    if FIsDbDirty and AppContext.DatabaseManager.IsConnected then
    begin
        PerformSync(True); // True = Асинхронно (в фоне, UI не виснет)
        FIsDbDirty := False; // Сбрасываем флаг после успешного старта синхронизации
    end;
end;

procedure TMainForm.tmrSearchTimerTimer(Sender: TObject);
begin
    tmrSearchTimer.Enabled := False; // Останавливаем таймер
    PerformSearchAsync(ebSearch.Text); // Запускаем тяжелый поиск 1 раз
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

