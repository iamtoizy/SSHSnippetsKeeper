unit MainFormUI;

interface

uses
    BaseFormUI,
    CategoryTreeController,
    Core.Entities.Chain,
    Core.Entities.Snippet,
    Core.Entities.Tag,
    Core.Entities.User,
    Core.Interfaces.App,
    Core.Interfaces.Data,
    Core.Interfaces.Passwords,
    Core.Interfaces.Services,
    Core.Interfaces.Settings,
    Core.Interfaces.Tools,
    Core.Interfaces.UI,
    GlobalHotkeyManager,
    LanguageMenuController,
    SearchController,
    SyncController,
    TagListController,
    UI.AppStatusBar,
    System.Actions,
    System.Classes,
    System.DateUtils,
    System.Generics.Collections,
    System.ImageList,
    System.IOUtils,
    System.SysUtils,
    System.Threading,
    System.Types,
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
        pnlTop: TPanel;
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
        pChainActions: TPanel;
        lblChainName: TLabel;
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
        pmCategories: TPopupMenu;
        pmSnippets: TPopupMenu;
        pmTags: TPopupMenu;
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
        actRunSnippet: TAction;
        actDryRunSnippet: TAction;
        actRunSequence: TAction;
        actExportSnippets: TAction;
        actAddTagToSnippets: TAction;
        actRemoveTagFromSnippets: TAction;
        actMoveToCategory: TAction;
        actClearTagFilter: TAction;
        actToggleFavorite: TAction;
        actFavMoveTop: TAction;
        actFavMoveUp: TAction;
        actFavMoveDown: TAction;
        actFavMoveEnd: TAction;
        actFavSlot1: TAction;
        actFavSlot2: TAction;
        actFavSlot3: TAction;
        actFavSlot4: TAction;
        actFavSlot5: TAction;
        actFavSlot6: TAction;
        actFavSlot7: TAction;
        actFavSlot8: TAction;
        actFavSlot9: TAction;
        actFavSlot0: TAction;
        actChainCreate: TAction;
        actChainRun: TAction;
        actChainEdit: TAction;
        actChainDelete: TAction;
        actChainCreateFromSnippet: TAction;
        puFavMove: TMenuItem;
        actSnippetHistory: TAction;
        tmrAutoSync: TTimer;
        procedure actAddCategoryExecute(Sender: TObject);
        procedure actAddSnippetExecute(Sender: TObject);
        procedure actAddTagExecute(Sender: TObject);
        procedure actArchiveBuilderExecute(Sender: TObject);
        procedure actChainCreateExecute(Sender: TObject);
        procedure actChainCreateFromSnippetExecute(Sender: TObject);
        procedure actChainDeleteExecute(Sender: TObject);
        procedure actChainEditExecute(Sender: TObject);
        procedure actChainRunExecute(Sender: TObject);
        procedure actChmodCalculatorExecute(Sender: TObject);
        procedure actClearTagFilterExecute(Sender: TObject);
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
        procedure actRunSnippetExecute(Sender: TObject);
        procedure actDryRunSnippetExecute(Sender: TObject);
        procedure actRunSequenceExecute(Sender: TObject);
        procedure actExportSnippetsExecute(Sender: TObject);
        procedure actAddTagToSnippetsExecute(Sender: TObject);
        procedure actRemoveTagFromSnippetsExecute(Sender: TObject);
        procedure actMoveToCategoryExecute(Sender: TObject);
        procedure actSearchExecute(Sender: TObject);
        procedure actSnippetHistoryExecute(Sender: TObject);
        procedure actSettingsExecute(Sender: TObject);
        procedure actToggleFavoriteExecute(Sender: TObject);
        procedure actFavMoveTopExecute(Sender: TObject);
        procedure actFavMoveUpExecute(Sender: TObject);
        procedure actFavMoveDownExecute(Sender: TObject);
        procedure actFavMoveEndExecute(Sender: TObject);
        procedure actFavSlotExecute(Sender: TObject);
        procedure lvSnippetsDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
        procedure lvSnippetsDragDrop(Sender, Source: TObject; X, Y: Integer);
        procedure bManageWorkspacesClick(Sender: TObject);
        procedure cbUserChange(Sender: TObject);
        procedure tvCategoriesChange(Sender: TObject; Node: TTreeNode);
        procedure lvSnippetsClick(Sender: TObject);
        procedure lvSnippetsContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
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
        procedure tvCategoriesEditing(Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean);
        procedure tvCategoriesKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure tvCategoriesContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
        procedure lvSnippetsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
        procedure lvTagsClick(Sender: TObject);
        procedure lvTagsContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
        procedure lvTagsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure nTagEditorClick(Sender: TObject);
        procedure lvTagsEdited(Sender: TObject; Item: TListItem; var S: string);
        procedure nExitClick(Sender: TObject);
        procedure nTerminalsClick(Sender: TObject);
        procedure rbTextClick(Sender: TObject);
        procedure sbBottomMouseDown(Sender: TObject; Button: TMouseButton; Shift:
            TShiftState; X, Y: Integer);
        procedure sbBottomResize(Sender: TObject);
        procedure tmrAutoSyncTimer(Sender: TObject);
        procedure tmrSearchTimerTimer(Sender: TObject);
        procedure tvCategoriesClick(Sender: TObject);
        procedure tvCategoriesEndDrag(Sender, Target: TObject; X, Y: Integer);
        procedure tvCategoriesDblClick(Sender: TObject);
        procedure tvCategoriesExpanded(Sender: TObject; Node: TTreeNode);
        procedure tvCategoriesCollapsed(Sender: TObject; Node: TTreeNode);
        procedure puCatCollapseAllClick(Sender: TObject);
        procedure puCatExpandAllClick(Sender: TObject);
    private
        FHotItemIndex: Integer;
        FUserID: Integer;
        FFilterUserID: Integer;
        FIgnoreCategoryChange: Boolean;
        FCloseAfterChainStop: Boolean;
        FHotkeyMgr: TGlobalHotkeyManager;
        FSync: TSyncController;
        FStatus: TAppStatusBar;
        FSearch: TMainSearchController;
        FUsersCache: TArray<TUserDTO>;
        FAllTagsCache: TArray<TTagDTO>;
        FCategoryTree: TCategoryTreeController;
        FTags: TTagListController;
        FLangMenu: TLanguageMenuController;

        procedure MarkDataChanged;
        function GetSyncEngine: TSyncController;
        function GetSearchEngine: TMainSearchController;
        procedure FillSnippetListView(const Snippets: TArray<TSnippetDTO>);
        function ExtractSnippetByListItem(Item: TListItem): TSnippetDTO;
        procedure FillUserInterfaceFromSnippet(const Snippet: TSnippetDTO);

        // Do-методы
        procedure DoAddSnippet;
        procedure DoEditSnippet;
        procedure DoDeleteSnippet;
        procedure DoShowSnippetHistory;
        procedure DoToggleFavorite;
        procedure DoMoveFavorite(Direction: TFavoriteMoveDirection);
        procedure DoRunFavoriteSlot(Index: Integer);
        procedure DoRunSequence;
        procedure DoExportSnippets;
        procedure DoAddTagToSnippets;
        procedure DoRemoveTagFromSnippets;
        procedure DoMoveToCategory;
        function GetSelectedSnippets: TArray<TSnippetDTO>;
        procedure ReloadSnippetListKeepingSelection;

        // UI Helpers
        procedure SetUserFilter(UserID: Integer);
        procedure LoadUsersToComboBox;
        procedure UpdateMenuState;
        procedure UpdateFavoriteMenuState;
        procedure UpdateChainMenuState;
        function GetSelectedChainID: Integer;
        function ShowChainEditor(ChainID: Integer; InitialSnippetID: Integer = 0): Integer;
        procedure RefreshCurrentSnippetList;
        procedure ChainStarted;
        procedure ChainFinished;
        procedure ReloadUI(PreserveCategoryID: Integer);
        procedure RefreshCaches;
        procedure CloseDatabase;
        procedure UpdateSnippetCount;
        function CurrentDbFileName: string;
        //
        procedure PerformSearchAsync(const Mask: string);
        procedure DisplaySearchResults(const Results: TArray<TSnippetDTO>);
        procedure LanguageMenuItemClick(Sender: TObject);
        // Синхронизация Markdown
        procedure PerformSync(IsAsync: Boolean; ShowToastOnDone: Boolean = False);
    protected
        procedure WMActivate(var Msg: TWMActivate); message WM_ACTIVATE;
        procedure DoInitialize; override;
    public
        procedure UpdateUI(const State: TBaseFormState); override;
        procedure ApplyLanguage; override;
    end;

var
    MainForm: TMainForm;

implementation

{$R *.dfm}

uses
    AddEditSnippetFormUI,
    UI.Services.AppStateManager,
    ArchiveBuilderFormUI,
    ArrayHelper,
    ChainEditorFormUI,
    ChainRunnerController,
    CategorySelectDialogUI,
    Core.Entities.Category,
    ChmodFormUI,
    Common.Consts,
    Common.Helpers,
    Core.MarkdownExporter,
    Core.MarkdownImporter,
    CronGenFormUI,
    EpochConverterFormUI,
    HistoryFormUI,
    HotkeyService,
    Core.LocalAIService,
    MacroInputTypes,
    NetworkFormUI,
    PasswordGenFormUI,
    QuickSearchFormUI,
    SequenceOrderDialogUI,
    SettingsFormUI,
    SnippetRunner,
    SnippetViewData,
    System.Math,
    System.UITypes,
    TagEditorFormUI,
    TagSelectDialogUI,
    UI.Helpers,
    UI.HoverHelpManager,
    Common.Localization,
    Vcl.FileCtrl,
    Winapi.CommCtrl,
    WindowMonitor,
    WorkspaceManagerFormUI
    ;

procedure TMainForm.actAddCategoryExecute(Sender: TObject);
begin
    FCategoryTree.AddCategory;
end;

procedure TMainForm.actAddSnippetExecute(Sender: TObject);
begin
    DoAddSnippet;
end;

procedure TMainForm.actAddTagExecute(Sender: TObject);
begin
    FTags.AddTag;
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
    FCategoryTree.DeleteCategory;
end;

procedure TMainForm.actDeleteSnippetExecute(Sender: TObject);
begin
    DoDeleteSnippet;
end;

procedure TMainForm.actDeleteTagExecute(Sender: TObject);
begin
    FTags.DeleteTag;
end;

procedure TMainForm.actEditCategoryExecute(Sender: TObject);
begin
    FCategoryTree.StartRename;
end;

procedure TMainForm.actEditSnippetExecute(Sender: TObject);
begin
    DoEditSnippet;
end;

procedure TMainForm.actEditTagExecute(Sender: TObject);
begin
    FTags.StartRename;
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
                PerformSync(True, True); // Асинхронно, чтобы не тормозить показ формы
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

procedure TMainForm.actSnippetHistoryExecute(Sender: TObject);
begin
    DoShowSnippetHistory;
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
    FFilterUserID := 0;

    lvTags.OwnerData := False;
    lvSnippets.OwnerData := False;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
    FreeAndNil(FLangMenu);
    FreeAndNil(FTags);
    FreeAndNil(FCategoryTree);
    if Assigned(FSearch) then
        FSearch.CancelPending;
    GWinMonitor.StopMonitoring;
    RemoveProp(Self.Handle, PChar(UNIQUE_APP_STR));
    if Assigned(FSync) then
        FSync.WaitForCompletion;
    FreeAndNil(FSync);
    FreeAndNil(FSearch);
    FreeAndNil(FStatus);
    FHotkeyMgr.Free;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
    if TChainRunner.IsChainRunning then
    begin
        TChainRunner.RequestStop;
        FCloseAfterChainStop := True;
        CanClose := False;
        Exit;
    end;

    if Assigned(AppContext.DatabaseManager) and AppContext.DatabaseManager.IsConnected
        and GetSyncEngine.Dirty
        and (not AppContext.SettingsManager.Data.SyncOnExit) then
    begin
        if not MessagesHandler.AskWarning(
            TUIStateLoader.GetMessage('Common.UnsyncedDataWarning'),
            TUIStateLoader.GetMessage('Common.Warning')) then
        begin
            CanClose := False;
            Exit;
        end;
    end;

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

                FStatus.SetDatabase(CurrentDbFileName);
                FStatus.SetDirty(False);
                FStatus.SetEvent('');
                UpdateSnippetCount;

                // ВАЖНО: При открытии БД сниппет еще не выбран, фильтр по тегам сбрасывается
                FTags.ResetFilterState;
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

                // Жестко отключаем все зависимые от контента действия (главное меню и попапы)
                actAddCategory.Enabled := False;
                actDeleteCategory.Enabled := False;
                actEditCategory.Enabled := False;

                actAddSnippet.Enabled := False;
                actEditSnippet.Enabled := False;
                actDeleteSnippet.Enabled := False;
                actRunSnippet.Enabled := False;
                actDryRunSnippet.Enabled := False;

                actAddTag.Enabled := False;
                actEditTag.Enabled := False;
                actDeleteTag.Enabled := False;
                actClearTagFilter.Enabled := False;

                actToggleFavorite.Enabled := False;
                actFavMoveTop.Enabled := False;
                actFavMoveUp.Enabled := False;
                actFavMoveDown.Enabled := False;
                actFavMoveEnd.Enabled := False;
                actFavSlot1.Enabled := False;
                actFavSlot2.Enabled := False;
                actFavSlot3.Enabled := False;
                actFavSlot4.Enabled := False;
                actFavSlot5.Enabled := False;
                actFavSlot6.Enabled := False;
                actFavSlot7.Enabled := False;
                actFavSlot8.Enabled := False;
                actFavSlot9.Enabled := False;
                actFavSlot0.Enabled := False;

                // Очищаем списки
                lvSnippets.Items.Clear;
                lvTags.Items.Clear;
                tvCategories.Items.BeginUpdate;
                try
                    tvCategories.Items.Clear;
                finally
                    tvCategories.Items.EndUpdate;
                end;

                FStatus.SetDatabase('');
                FStatus.SetDirty(False);
                FStatus.SetEvent('');
                FStatus.SetSnippetCount(0, 0);

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

                // Сбрасываем теги. При активном фильтре выделение тегов сохраняем,
                // чтобы пользователь видел выбранную комбинацию тегов
                if Assigned(lvTags) and Assigned(AppContext.TagService) and (Length(FTags.FilterTagIDs) = 0) then
                    TUIHelpers.FillTagListWithSelection(lvTags, AppContext.TagService.GetAllTags, []);
            end;
    end;
end;

procedure TMainForm.UpdateMenuState;
var
    Node: TTreeNode;
    IsVirtual, IsWorkspace, SingleSelection: Boolean;
begin
    // Если база данных закрыта, элементы меню контролирует UpdateUI(bfsDBDisconnected)
    if (not Assigned(AppContext.DatabaseManager)) or (not AppContext.DatabaseManager.IsConnected) then
        Exit;

    Node := tvCategories.Selected;
    IsVirtual := FCategoryTree.IsVirtualCategory(Node);
    IsWorkspace := FCategoryTree.IsWorkspaceNode(Node);

    // --- КАТЕГОРИИ ---
    // Добавлять категории можно и в категорию, и в корень пространства (но не в вирт. папки)
    actAddCategory.Enabled := (Node <> nil) and not IsVirtual;
    // Удалять и редактировать пространство через это меню нельзя (для этого есть WorkspaceManager)
    actDeleteCategory.Enabled := (Node <> nil) and not IsVirtual and not IsWorkspace;
    actEditCategory.Enabled := (Node <> nil) and not IsVirtual and not IsWorkspace;

    // --- СНИППЕТЫ ---
    // Сниппеты можно добавлять только в конкретные категории
    actAddSnippet.Enabled := (Node <> nil) and not IsVirtual and not IsWorkspace;
    SingleSelection := (lvSnippets.Selected <> nil) and (lvSnippets.SelCount = 1);
    actDeleteSnippet.Enabled := SingleSelection;
    actEditSnippet.Enabled := SingleSelection;
    actRunSnippet.Enabled := SingleSelection;
    actDryRunSnippet.Enabled := SingleSelection;
    actSnippetHistory.Enabled := SingleSelection;
    actChainCreateFromSnippet.Enabled := SingleSelection;
    actRunSequence.Enabled := (lvSnippets.SelCount >= 2);
    actExportSnippets.Enabled := (lvSnippets.Selected <> nil);
    actAddTagToSnippets.Enabled := (lvSnippets.Selected <> nil);
    actRemoveTagFromSnippets.Enabled := (lvSnippets.Selected <> nil);
    actMoveToCategory.Enabled := (lvSnippets.Selected <> nil);

    // --- ИЗБРАННОЕ ---
    UpdateFavoriteMenuState;

    // --- ЦЕПОЧКИ ---
    UpdateChainMenuState;

    // --- ТЕГИ ---
    actAddTag.Enabled := True; // Создать новый тег можно всегда
    actDeleteTag.Enabled := (lvTags.Selected <> nil);
    actEditTag.Enabled := (lvTags.Selected <> nil);
    // Пункт активен, пока висит фильтр по тегам
    actClearTagFilter.Enabled := Length(FTags.FilterTagIDs) > 0;
end;

procedure TMainForm.UpdateFavoriteMenuState;
var
    HasSelection, IsFav, InFavoritesView: Boolean;
    Node: TTreeNode;
begin
    HasSelection := (lvSnippets.Selected <> nil) and Assigned(lvSnippets.Selected.Data);
    IsFav := HasSelection and TSnippetViewData(lvSnippets.Selected.Data).IsFavorite;

    Node := tvCategories.Selected;
    InFavoritesView := (Node <> nil) and FCategoryTree.IsVirtualCategory(Node) and
        (Integer(IntPtr(Node.Data)) = -3);

    // В обычных списках - только добавить/убрать; в избранном - только убрать
    actToggleFavorite.Visible := (not InFavoritesView) or IsFav;
    actToggleFavorite.Enabled := HasSelection and (lvSnippets.SelCount = 1);

    // Перестановка и перетаскивание имеют смысл только внутри избранного
    puFavMove.Visible := InFavoritesView;
    actFavMoveTop.Enabled := IsFav and (lvSnippets.SelCount = 1);
    actFavMoveUp.Enabled := IsFav and (lvSnippets.SelCount = 1);
    actFavMoveDown.Enabled := IsFav and (lvSnippets.SelCount = 1);
    actFavMoveEnd.Enabled := IsFav and (lvSnippets.SelCount = 1);

    if IsFav then
        actToggleFavorite.Caption := TUIStateLoader.GetMessage('Actions.MainForm.Favorites.ToggleRemove')
    else
        actToggleFavorite.Caption := TUIStateLoader.GetMessage('Actions.MainForm.Favorites.ToggleAdd');

    actFavSlot1.Enabled := True;
    actFavSlot2.Enabled := True;
    actFavSlot3.Enabled := True;
    actFavSlot4.Enabled := True;
    actFavSlot5.Enabled := True;
    actFavSlot6.Enabled := True;
    actFavSlot7.Enabled := True;
    actFavSlot8.Enabled := True;
    actFavSlot9.Enabled := True;
    actFavSlot0.Enabled := True;
end;

procedure TMainForm.UpdateChainMenuState;
var
    Node: TTreeNode;
    NodeValue, ChainID: Integer;
    IsChainNode, ChainBusy: Boolean;
begin
    Node := tvCategories.Selected;
    NodeValue := 0;
    if Node <> nil then
        NodeValue := Integer(IntPtr(Node.Data));

    actChainCreate.Visible := (Node <> nil) and FCategoryTree.IsVirtualCategory(Node) and
        (NodeValue = CHAINS_ROOT_NODE_ID);

    IsChainNode := TChainRunner.TryGetChainID(NodeValue, ChainID);
    actChainRun.Visible := IsChainNode;
    actChainEdit.Visible := IsChainNode;
    actChainDelete.Visible := IsChainNode;

    ChainBusy := TChainRunner.IsChainRunning;
    actChainRun.Enabled := not ChainBusy;
    actChainEdit.Enabled := not ChainBusy;
    actChainDelete.Enabled := not ChainBusy;

    pChainActions.Visible := IsChainNode;
    if IsChainNode then
        lblChainName.Caption := TUIStateLoader.GetMessage('Chains.Panel.Caption',
            [AppContext.ChainService.GetChainByID(ChainID).Name,
            Length(AppContext.ChainService.GetSteps(ChainID))]);
end;

function TMainForm.GetSelectedChainID: Integer;
var
    Node: TTreeNode;
begin
    Result := 0;
    Node := tvCategories.Selected;
    if Node = nil then
        Exit;
    TChainRunner.TryGetChainID(Integer(IntPtr(Node.Data)), Result);
end;

function TMainForm.ShowChainEditor(ChainID: Integer; InitialSnippetID: Integer): Integer;
var
    Editor: TChainEditorForm;
    DefaultUserID: Integer;
begin
    Result := 0;

    DefaultUserID := FCategoryTree.GetWorkspaceUserID(tvCategories.Selected);

    Editor := TChainEditorForm.Create(nil);
    try
        Editor.Initialize(AppContext);
        Editor.Setup(ChainID, InitialSnippetID, DefaultUserID);
        if Editor.ShowModal = mrOk then
            Result := Editor.ChainID;
    finally
        Editor.Free;
    end;
end;

procedure TMainForm.actChainCreateExecute(Sender: TObject);
var
    NewChainID: Integer;
begin
    NewChainID := ShowChainEditor(0);
    if NewChainID > 0 then
    begin
        ReloadUI(TChainRunner.EncodeChainNodeID(NewChainID));
        FStatus.Flash(TUIStateLoader.GetMessage('Chains.CreatedMsg', [
            AppContext.ChainService.GetChainByID(NewChainID).Name]));
        MarkDataChanged;
    end;
end;

procedure TMainForm.actChainCreateFromSnippetExecute(Sender: TObject);
var
    Item: TListItem;
    Snippet: TSnippetDTO;
    NewChainID: Integer;
begin
    if TChainRunner.IsChainRunning then
        Exit;

    Item := lvSnippets.Selected;
    if Item = nil then
        Exit;

    Snippet := ExtractSnippetByListItem(Item);
    NewChainID := ShowChainEditor(0, Snippet.ID);
    if NewChainID > 0 then
    begin
        ReloadUI(TChainRunner.EncodeChainNodeID(NewChainID));
        FStatus.Flash(TUIStateLoader.GetMessage('Chains.CreatedMsg', [
            AppContext.ChainService.GetChainByID(NewChainID).Name]));
        MarkDataChanged;
    end;
end;

procedure TMainForm.actChainRunExecute(Sender: TObject);
var
    ChainID: Integer;
begin
    ChainID := GetSelectedChainID;
    if ChainID > 0 then
        TChainRunner.ExecuteChain(AppContext, ChainID);
end;

procedure TMainForm.actChainEditExecute(Sender: TObject);
var
    ChainID, EditedChainID: Integer;
begin
    ChainID := GetSelectedChainID;
    if ChainID = 0 then
        Exit;

    EditedChainID := ShowChainEditor(ChainID);    if EditedChainID > 0 then
    begin
        ReloadUI(TChainRunner.EncodeChainNodeID(EditedChainID));
        MarkDataChanged;
    end;
end;

procedure TMainForm.actChainDeleteExecute(Sender: TObject);
var
    ChainID: Integer;
    Chain: TChainDTO;
begin
    ChainID := GetSelectedChainID;
    if ChainID = 0 then
        Exit;

    Chain := AppContext.ChainService.GetChainByID(ChainID);
    if Chain.ID = 0 then
        Exit;

    if AppContext.MessagesHandler.AskConfirmation(
        TUIStateLoader.GetMessage('Chains.DeleteConfirm', [Chain.Name]),
        TUIStateLoader.GetMessage('Common.Confirmation'),
        MB_YESNO or MB_ICONQUESTION
    ) then begin
        try
            AppContext.ChainService.DeleteChain(ChainID);
            ReloadUI(CHAINS_ROOT_NODE_ID);
            FStatus.Flash(TUIStateLoader.GetMessage('Chains.DeletedMsg', [Chain.Name]));
            MarkDataChanged;
        except
            on E: Exception do
                AppContext.MessagesHandler.ShowError(E.Message);
        end;
    end;
end;

procedure TMainForm.tvCategoriesDblClick(Sender: TObject);
begin
    if GetSelectedChainID > 0 then
        actChainEditExecute(Sender);
end;

procedure TMainForm.tvCategoriesExpanded(Sender: TObject; Node: TTreeNode);
begin
    FCategoryTree.HandleNodeExpanded(Node);
end;

procedure TMainForm.tvCategoriesCollapsed(Sender: TObject; Node: TTreeNode);
begin
    FCategoryTree.HandleNodeCollapsed(Node);
end;

procedure TMainForm.puCatCollapseAllClick(Sender: TObject);
begin
    FCategoryTree.CollapseAll;
end;

procedure TMainForm.puCatExpandAllClick(Sender: TObject);
begin
    FCategoryTree.ExpandAll;
end;

procedure TMainForm.actClearTagFilterExecute(Sender: TObject);
begin
    FTags.ClearFilter;
end;

procedure TMainForm.ReloadUI(PreserveCategoryID: Integer);
var
    Cats: TArray<TCategoryDTO>;
begin
    FIgnoreCategoryChange := True;
    try
        // Получаем данные через сервисы
        RefreshCaches;
        Cats := AppContext.CategoryService.GetAllCategories(FFilterUserID);

        // Используем UIHelper
        FCategoryTree.BeforeRebuild;
        try
            TUIHelpers.BuildCategoryTree(tvCategories, Cats, FUsersCache,
                AppContext.ChainService.GetAllChains(FFilterUserID), FFilterUserID,
                PreserveCategoryID);
        finally
            FCategoryTree.AfterRebuild;
        end;
        RefreshCurrentSnippetList;
    finally
        FIgnoreCategoryChange := False;
    end;
    UpdateMenuState;
end;

procedure TMainForm.RefreshCaches;
begin
    if Assigned(AppContext.UserService) then
        FUsersCache := AppContext.UserService.GetAllUsers
    else
        FUsersCache := [];

    if Assigned(AppContext.TagService) then
        FAllTagsCache := AppContext.TagService.GetAllTags
    else
        FAllTagsCache := [];
end;

procedure TMainForm.RefreshCurrentSnippetList;
var
    Node: TTreeNode;
    CatID, ChainID, I: Integer;
    Snippets: TArray<TSnippetDTO>;
    Steps: TArray<TChainStepDTO>;
begin
    Node := tvCategories.Selected;
    if Node = nil then
    begin
        lvSnippets.Items.Clear;
        Exit;
    end;

    if AppContext.DatabaseManager.IsConnected = False then
        Exit;

    if TChainRunner.TryGetChainID(Integer(IntPtr(Node.Data)), ChainID) then
    begin
        Steps := AppContext.ChainService.GetSteps(ChainID);
        SetLength(Snippets, Length(Steps));
        for I := 0 to High(Steps) do
            Snippets[I] := AppContext.SnippetService.GetSnippetByID(Steps[I].SnippetID);
        FillSnippetListView(Snippets);
        for I := 0 to lvSnippets.Items.Count - 1 do
            lvSnippets.Items[I].Caption := IntToStr(I + 1) + '. ' + lvSnippets.Items[I].Caption;
        Exit;
    end;

    CatID := Integer(IntPtr(Node.Data));

    if FCategoryTree.IsVirtualCategory(Node) then
    begin
        case CatID of
            -1:
                Snippets := AppContext.SnippetService.GetTopSnippets(FUserID, 10);
            -2:
                Snippets := AppContext.SnippetService.GetRecentSnippets(FUserID, 10);
            -3:
                Snippets := AppContext.SnippetService.GetFavorites(FFilterUserID);
        else
            Snippets := [];
        end;
    end
    else if FCategoryTree.IsWorkspaceNode(Node) then
        Snippets := []
    else
    begin
        if FFilterUserID > 0 then
            Snippets := AppContext.SnippetService.GetSnippetsByCategory(CatID, FFilterUserID)
        else
            Snippets := AppContext.SnippetService.GetSnippetsByCategory(CatID, FCategoryTree.GetSelectedCategoryUserID);
    end;

    FillSnippetListView(Snippets);
end;

procedure TMainForm.ChainStarted;
begin
    UpdateMenuState;
end;

procedure TMainForm.ChainFinished;
begin
    if FCloseAfterChainStop then
    begin
        FCloseAfterChainStop := False;
        Close;
    end;
    UpdateMenuState;
end;

procedure TMainForm.tvCategoriesChange(Sender: TObject; Node: TTreeNode);
begin
    if FIgnoreCategoryChange then
        Exit;
    if Node = nil then
        Exit;

    FTags.ResetFilterState;
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

procedure TMainForm.tvCategoriesEdited(Sender: TObject; Node: TTreeNode; var S: string);
begin
    FCategoryTree.HandleEdited(Node, S);
end;

procedure TMainForm.tvCategoriesEditing(Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean);
begin
    AllowEdit := FCategoryTree.CanEditNode(Node);
end;

procedure TMainForm.tvCategoriesKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if (Key = VK_F2) and (Shift = []) then
        FCategoryTree.StartRename;
end;

procedure TMainForm.tvCategoriesContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var
    Node: TTreeNode;
begin
    // Дерево выделяет узел правым кликом само (до WM_CONTEXTMENU), поэтому
    // ветка ниже обычно пропускается; в любом случае состояние действий
    // надо актуализировать перед показом попапа
    Node := tvCategories.GetNodeAt(MousePos.X, MousePos.Y);
    if (Node <> nil) and (Node <> tvCategories.Selected) then
        tvCategories.Selected := Node
    else
        UpdateMenuState;
end;

procedure TMainForm.tvCategoriesDragDrop(Sender, Source: TObject; X, Y: Integer);
begin
    FCategoryTree.HandleDragDrop(Source, X, Y);
end;

procedure TMainForm.tvCategoriesDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
    FCategoryTree.HandleDragOver(Source, X, Y, Accept);
end;

procedure TMainForm.tvCategoriesMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
    FCategoryTree.HandleMouseDown(Button, X, Y);
end;

procedure TMainForm.tvCategoriesEndDrag(Sender, Target: TObject; X, Y: Integer);
begin
    FCategoryTree.HandleEndDrag;
end;

procedure TMainForm.DoInitialize;
begin
    KeyPreview := True;
    OnKeyDown := FormKeyDown;

    lvTags.OnMouseDown := lvTagsMouseDown;
    TChainRunner.OnStarted := ChainStarted;
    TChainRunner.OnFinished := ChainFinished;

    FStatus := TAppStatusBar.Create(sbBottom);
    FStatus.Layout;
    FStatus.SetDatabase('');

    // Контроллеры областей формы: дерево категорий, теги, меню языков
    FCategoryTree := TCategoryTreeController.Create(tvCategories, FStatus, AppContext,
        procedure(PreserveCategoryID: Integer)
        begin
            ReloadUI(PreserveCategoryID);
        end,
        procedure
        begin
            MarkDataChanged;
        end);
    FCategoryTree.DefaultUserID := FUserID;

    FTags := TTagListController.Create(lvTags, FStatus, AppContext,
        procedure
        begin
            if tvCategories.Selected <> nil then
                tvCategoriesChange(tvCategories, tvCategories.Selected)
            else
                lvSnippets.Items.Clear;
        end,
        procedure
        begin
            UpdateMenuState;
        end,
        procedure
        begin
            MarkDataChanged;
        end,
        procedure(Results: TArray<TSnippetDTO>)
        begin
            FillSnippetListView(Results);
        end);

    FLangMenu := TLanguageMenuController.Create(pmLanguage, FStatus, AppContext, LanguageMenuItemClick);

    // Строим меню языков в StatusBar
    FLangMenu.BuildMenu;

    // Регистрация подсказок
    RegisterHelp(tvCategories, hipTopRight, 'Help.MainForm.tvCategories', hkCustomForm);
    RegisterHelp(lvSnippets, hipTopRight, 'Help.MainForm.lvSnippets', hkCustomForm);
    RegisterHelp(lvTags, hipTopRight, 'Help.MainForm.lvTags', hkCustomForm);
    RegisterHelp(ebSearch, hipTopRight, 'Help.MainForm.ebSearch', hkCustomForm);

    ApplyLanguage;

    FHotkeyMgr := TGlobalHotkeyManager.Create(
        AppContext
    );
    FHotkeyMgr.StartListening;

    for var Item in AppContext.SettingsManager.Data.AllowedApplications do
        if Item.Enabled then
            GWinMonitor.AddAllowedProcess(Item.ExeName.ToLower);

    TStateMgr.Instance.FirstRun;

    GWinMonitor.StartMonitoring;
end;

procedure TMainForm.ApplyLanguage;
begin
    inherited;
    actChainCreate.Caption := TUIStateLoader.GetMessage('Chains.Menu.Create');
    actChainCreateFromSnippet.Caption := TUIStateLoader.GetMessage('Chains.Menu.CreateFromSnippet');
    actChainRun.Caption := TUIStateLoader.GetMessage('Chains.Menu.Run');
    actChainEdit.Caption := TUIStateLoader.GetMessage('Chains.Menu.Edit');
    actChainDelete.Caption := TUIStateLoader.GetMessage('Chains.Menu.Delete');
    actRunSequence.Caption := TUIStateLoader.GetMessage('MultiSelect.Menu.RunSequence');
    actExportSnippets.Caption := TUIStateLoader.GetMessage('MultiSelect.Menu.Export');
    actAddTagToSnippets.Caption := TUIStateLoader.GetMessage('MultiSelect.Menu.AddTag');
    actRemoveTagFromSnippets.Caption := TUIStateLoader.GetMessage('MultiSelect.Menu.RemoveTag');
    actMoveToCategory.Caption := TUIStateLoader.GetMessage('MultiSelect.Menu.MoveToCategory');
end;

procedure TMainForm.lvSnippetsClick(Sender: TObject);
var
    Item: TListItem;
    Snippet: TSnippetDTO;
begin
    UpdateSnippetCount;
    Item := lvSnippets.Selected;
    if not Assigned(Item) then
    begin
        UpdateUI(bfsSnippetDeselected);
        Exit;
    end;

    Snippet := Default(TSnippetDTO);
    if Assigned(Item.Data) then
        with TSnippetViewData(Item.Data) do
        begin
            Snippet.ID := ID;
            Snippet.UserID := UserID;
            Snippet.CategoryID := CategoryID;
            Snippet.Title := Title;
            Snippet.Content := Content;
            Snippet.Comment := Comment;
        end;

    FillUserInterfaceFromSnippet(Snippet);
    UpdateUI(bfsSnippetSelected);
end;

procedure TMainForm.lvSnippetsContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var
    Item: TListItem;
begin
    // Нативный ListView выделяет пункт правым кликом ДО WM_CONTEXTMENU,
    // поэтому условие ниже обычно не срабатывает. Прогонять клик-логику
    // (заполнение панели + UpdateMenuState) нужно ВСЕГДА, иначе попап
    // покажет Enabled-состояние с предыдущего события
    Item := lvSnippets.GetItemAt(MousePos.X, MousePos.Y);
    if (Item <> nil) and (not Item.Selected) then
    begin
        lvSnippets.Selected := Item;
        Item.Focused := True;
        Item.MakeVisible(False);
    end;
    lvSnippetsClick(lvSnippets);
end;

procedure TMainForm.DoAddSnippet;
var
    Node: TTreeNode;
    CategoryID, TargetUserID: Integer;
begin
    Node := tvCategories.Selected;

    if (Node = nil) or FCategoryTree.IsVirtualCategory(Node) or FCategoryTree.IsWorkspaceNode(Node) then
    begin
        MessagesHandler.ShowError(
            TUIStateLoader.GetMessage('Snippet.SelectPrompt')
        );
        Exit;
    end;

    CategoryID := Integer(IntPtr(Node.Data));
    TargetUserID := FCategoryTree.GetWorkspaceUserID(Node);

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

    if (Node <> nil) and not FCategoryTree.IsVirtualCategory(Node) and (Node.Data <> nil) then
        Snippet.CategoryID := Integer(IntPtr(Node.Data));

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

procedure TMainForm.DoShowSnippetHistory;
var
    Item: TListItem;
    Snippet: TSnippetDTO;
    Ver: TSnippetVersionDTO;
    SelectedCatID: Integer;
begin
    Item := lvSnippets.Selected;
    if Item = nil then
        Exit;

    Snippet := ExtractSnippetByListItem(Item);

    Ver := Default(TSnippetVersionDTO);
    if THistoryForm.Execute(Self, AppContext, Snippet.ID, Ver) then
    begin
        if tvCategories.Selected <> nil then
            SelectedCatID := Integer(IntPtr(tvCategories.Selected.Data))
        else
            SelectedCatID := PRESERVE_CATEGORY_EMPTY_ID;

        ReloadUI(SelectedCatID);
        MarkDataChanged;
        FStatus.Flash(TUIStateLoader.GetMessage('History.RestoreDone'));
    end;
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
            FStatus.Flash(TUIStateLoader.GetMessage('Snippet.DeletedMsg'));
            MarkDataChanged;
        except
            on E: Exception do
                MessagesHandler.ShowError(
                    TUIStateLoader.GetMessage('Snippet.DeleteError', [E.Message])
                );
        end;
    end;
end;

procedure TMainForm.ReloadSnippetListKeepingSelection;
var
    SelID, I: Integer;
begin
    SelID := 0;
    if (lvSnippets.Selected <> nil) and Assigned(lvSnippets.Selected.Data) then
        SelID := TSnippetViewData(lvSnippets.Selected.Data).ID;

    if Trim(ebSearch.Text) <> '' then
        PerformSearchAsync(ebSearch.Text)
    else
        RefreshCurrentSnippetList;

    if SelID > 0 then
        for I := 0 to lvSnippets.Items.Count - 1 do
            if Assigned(lvSnippets.Items[I].Data) and
               (TSnippetViewData(lvSnippets.Items[I].Data).ID = SelID) then
            begin
                lvSnippets.Selected := lvSnippets.Items[I];
                lvSnippets.ItemFocused := lvSnippets.Items[I];
                Break;
            end;

    UpdateMenuState;
    UpdateSnippetCount;
end;

procedure TMainForm.DoToggleFavorite;
var
    Item: TListItem;
    ViewData: TSnippetViewData;
begin
    Item := lvSnippets.Selected;
    if (Item = nil) or (not Assigned(Item.Data)) then
        Exit;

    ViewData := TSnippetViewData(Item.Data);

    if ViewData.IsFavorite then
        AppContext.SnippetService.RemoveFavorite(ViewData.ID, ViewData.UserID)
    else
        AppContext.SnippetService.AddFavorite(ViewData.ID, ViewData.UserID);

    ReloadSnippetListKeepingSelection;
end;

procedure TMainForm.DoMoveFavorite(Direction: TFavoriteMoveDirection);
var
    Item: TListItem;
    ViewData: TSnippetViewData;
    ScopeUserID: Integer;
begin
    Item := lvSnippets.Selected;
    if (Item = nil) or (not Assigned(Item.Data)) then
        Exit;

    ViewData := TSnippetViewData(Item.Data);
    if not ViewData.IsFavorite then
        Exit;

    // Область перестановки совпадает с областью отображаемого списка
    if FFilterUserID > 0 then
        ScopeUserID := FFilterUserID
    else
        ScopeUserID := 0;

    AppContext.SnippetService.MoveFavorite(ViewData.ID, ScopeUserID, Direction);
    ReloadSnippetListKeepingSelection;
end;

procedure TMainForm.DoRunFavoriteSlot(Index: Integer);
var
    ScopeUserID: Integer;
    Favorites: TArray<TSnippetDTO>;
    Runner: TSnippetRunner;
begin
    if (not Assigned(AppContext.DatabaseManager)) or (not AppContext.DatabaseManager.IsConnected) then
        Exit;

    ScopeUserID := FFilterUserID;
    Favorites := AppContext.SnippetService.GetFavorites(ScopeUserID);

    if Index >= Length(Favorites) then
        Exit;

    Runner := TSnippetRunner.Create(Favorites[Index].UserID, AppContext);
    try
        Runner.ExecuteSnippet(Favorites[Index]);
    finally
        Runner.Free;
    end;
end;

procedure TMainForm.FillSnippetListView(const Snippets: TArray<TSnippetDTO>);
var
    Item: TListItem;
    Snippet: TSnippetDTO;
    ViewData: TSnippetViewData;
    FavList: TArray<TSnippetDTO>;
    FavPos: TDictionary<Integer, Integer>;
    I, Pos: Integer;
    Prefix: string;
    IsFav: Boolean;
begin
    FavPos := nil;
    if Assigned(AppContext.DatabaseManager) and AppContext.DatabaseManager.IsConnected then
    begin
        FavList := AppContext.SnippetService.GetFavorites(FFilterUserID);

        FavPos := TDictionary<Integer, Integer>.Create;
        for I := 0 to High(FavList) do
            if not FavPos.ContainsKey(FavList[I].ID) then
                FavPos.Add(FavList[I].ID, I);
    end;

    lvSnippets.Items.BeginUpdate;
    try
        lvSnippets.Items.Clear;
        for Snippet in Snippets do
        begin
            Item := lvSnippets.Items.Add;

            Prefix := '';
            Pos := -1;
            // TryGetValue объявлен с out-параметром: при неудаче Pos обнуляется,
            // поэтому признак избранности берём строго из результата функции
            if Assigned(FavPos) then
                IsFav := FavPos.TryGetValue(Snippet.ID, Pos)
            else
                IsFav := False;

            if IsFav then
            begin
                if Pos <= 9 then
                    Prefix := #9733 + IntToStr((Pos + 1) mod 10) + ' '
                else
                    Prefix := #9733 + ' ';
            end;

            Item.Caption := Prefix + Snippet.Title;
            Item.SubItems.Add(DateTimeToStr(UnixToDateTime(Snippet.CreatedAt, False)));
            Item.StateIndex := 0;

            if (Snippet.UpdatedAt > 0) then
                Item.SubItems.Add(DateTimeToStr(UnixToDateTime(Snippet.UpdatedAt, False)))
            else
                Item.SubItems.Add('');

            ViewData := TSnippetViewData.Create;
            ViewData.ID := Snippet.ID;
            ViewData.UserID := Snippet.UserID;
            ViewData.CategoryID := Snippet.CategoryID;
            ViewData.Title := Snippet.Title;
            ViewData.Content := Snippet.Content;
            ViewData.Comment := Snippet.Comment;
            ViewData.IsFavorite := IsFav;
            if (Pos >= 0) and (Pos <= 9) then
                ViewData.FavoriteSlot := Pos
            else
                ViewData.FavoriteSlot := -1;
            Item.Data := ViewData;
        end;
    finally
        lvSnippets.Items.EndUpdate;
        FreeAndNil(FavPos);
    end;
    UpdateSnippetCount;
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
    begin
        // Перетаскивание избранного внутри списка
        if (Button = mbLeft) and (not (ssDouble in Shift)) and
           Assigned(lvSnippets.Items[HitTest.iItem].Data) and
           TSnippetViewData(lvSnippets.Items[HitTest.iItem].Data).IsFavorite then
            lvSnippets.BeginDrag(False, 8);
        Exit;
    end;

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
begin
    actRunSnippetExecute(Sender);
end;

procedure TMainForm.actRunSnippetExecute(Sender: TObject);
var
    Item: TListItem;
    Runner: TSnippetRunner;
begin
    if TChainRunner.IsChainRunning then
        Exit;

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

procedure TMainForm.actDryRunSnippetExecute(Sender: TObject);
var
    Item: TListItem;
    Runner: TSnippetRunner;
begin
    if TChainRunner.IsChainRunning then
        Exit;

    Item := lvSnippets.Selected;
    if Item = nil then
        Exit;

    Runner := TSnippetRunner.Create(FUserID, AppContext);
    try
        Runner.DryRunSnippet(ExtractSnippetByListItem(Item));
    finally
        Runner.Free;
    end;
end;

procedure TMainForm.actRunSequenceExecute(Sender: TObject);
begin
    DoRunSequence;
end;

procedure TMainForm.actExportSnippetsExecute(Sender: TObject);
begin
    DoExportSnippets;
end;

procedure TMainForm.actAddTagToSnippetsExecute(Sender: TObject);
begin
    DoAddTagToSnippets;
end;

procedure TMainForm.actMoveToCategoryExecute(Sender: TObject);
begin
    DoMoveToCategory;
end;

procedure TMainForm.actRemoveTagFromSnippetsExecute(Sender: TObject);
begin
    DoRemoveTagFromSnippets;
end;

function TMainForm.GetSelectedSnippets: TArray<TSnippetDTO>;
var
    I: Integer;
    List: TList<TSnippetDTO>;
begin
    List := TList<TSnippetDTO>.Create;
    try
        for I := 0 to lvSnippets.Items.Count - 1 do
            if lvSnippets.Items[I].Selected then
                List.Add(ExtractSnippetByListItem(lvSnippets.Items[I]));
        Result := List.ToArray;
    finally
        List.Free;
    end;
end;

procedure TMainForm.DoRunSequence;
var
    Snippets, Ordered: TArray<TSnippetDTO>;
begin
    Snippets := GetSelectedSnippets;
    if Length(Snippets) < 2 then
        Exit;

    if TSequenceOrderForm.Execute(Self, AppContext, Snippets, Ordered) then
        TChainRunner.ExecuteSnippetSequence(AppContext, Ordered);
end;

procedure TMainForm.DoExportSnippets;
var
    Snippets: TArray<TSnippetDTO>;
    Dir: string;
    Count: Integer;
begin
    Snippets := GetSelectedSnippets;
    if Length(Snippets) = 0 then
        Exit;

    Dir := '';
    if not SelectDirectory(TUIStateLoader.GetMessage('MultiSelect.Export.FilePickerTitle'), '', Dir) then
        Exit;

    try
        Count := TMarkdownExporter.ExportSnippets(AppContext, Dir, Snippets);
    except
        on E: Exception do
        begin
            MessagesHandler.ShowError(TUIStateLoader.GetMessage('MultiSelect.Export.Error', [E.Message]));
            Exit;
        end;
    end;

    FStatus.Flash(TUIStateLoader.GetMessage('MultiSelect.Export.DoneMsg', [Count]));
end;

procedure TMainForm.DoAddTagToSnippets;
var
    Snippets: TArray<TSnippetDTO>;
    TagName: string;
    TagID: Integer;
    Added, Skipped, I: Integer;
    Existing: TArray<TTagDTO>;
    Tag: TTagDTO;
    HasTag: Boolean;
begin
    Snippets := GetSelectedSnippets;
    if Length(Snippets) = 0 then
        Exit;

    if not TTagSelectForm.Execute(Self, AppContext, TagName) then
        Exit;

    TagID := AppContext.TagService.GetOrCreateTag(TagName);
    if TagID <= 0 then
        Exit;

    Added := 0;
    Skipped := 0;
    for I := 0 to High(Snippets) do
    begin
        HasTag := False;
        Existing := AppContext.TagService.GetSnippetTags(Snippets[I].ID);
        for Tag in Existing do
            if Tag.ID = TagID then
            begin
                HasTag := True;
                Break;
            end;

        if HasTag or (Length(Existing) >= MAX_SNIPPET_TAGS) then
            Inc(Skipped)
        else
        begin
            AppContext.TagService.LinkTagToSnippet(Snippets[I].ID, TagID);
            Inc(Added);
        end;
    end;

    RefreshCaches;
    lvSnippetsClick(lvSnippets);
    FStatus.Flash(TUIStateLoader.GetMessage('MultiSelect.AddTag.DoneMsg', [TagName, Added, Skipped]));
end;

procedure TMainForm.DoRemoveTagFromSnippets;
var
    Snippets: TArray<TSnippetDTO>;
    IDs, TagIDs: TArray<Integer>;
    TagID, Removed, Absent, I: Integer;
    Existing: TArray<TTagDTO>;
    Tag: TTagDTO;
    HasTag: Boolean;
begin
    Snippets := GetSelectedSnippets;
    if Length(Snippets) = 0 then
        Exit;

    SetLength(IDs, Length(Snippets));
    for I := 0 to High(Snippets) do
        IDs[I] := Snippets[I].ID;

    if not TTagSelectForm.ExecuteForSnippets(Self, AppContext, IDs, TagIDs) then
        Exit;

    if Length(TagIDs) = 0 then
        Exit;

    Removed := 0;
    Absent := 0;
    for I := 0 to High(Snippets) do
    begin
        Existing := AppContext.TagService.GetSnippetTags(Snippets[I].ID);
        for TagID in TagIDs do
        begin
            HasTag := False;
            for Tag in Existing do
                if Tag.ID = TagID then
                begin
                    HasTag := True;
                    Break;
                end;

            if HasTag then
            begin
                AppContext.TagService.UnlinkTagFromSnippet(Snippets[I].ID, TagID);
                Inc(Removed);
            end
            else
                Inc(Absent);
        end;
    end;

    RefreshCaches;
    lvSnippetsClick(lvSnippets);
    FStatus.Flash(TUIStateLoader.GetMessage('MultiSelect.RemoveTag.DoneMsg', [Removed, Absent]));
end;

procedure TMainForm.DoMoveToCategory;
var
    Snippets: TArray<TSnippetDTO>;
    CategoryID, Moved, Skipped, I, K: Integer;
    Cat: TCategoryDTO;
    Tags: TArray<TTagDTO>;
    TagIDs: TArray<Integer>;
    PreferredUserID: Integer;
begin
    Snippets := GetSelectedSnippets;
    if Length(Snippets) = 0 then
        Exit;

    PreferredUserID := 0;
    if Length(Snippets) > 0 then
        PreferredUserID := Snippets[0].UserID;

    if not TCategorySelectForm.Execute(Self, AppContext, PreferredUserID, CategoryID) then
        Exit;

    Cat := AppContext.CategoryService.GetCategoryByID(CategoryID);
    if Cat.ID = 0 then
        Exit;

    Moved := 0;
    Skipped := 0;
    for I := 0 to High(Snippets) do
    begin
        if Snippets[I].CategoryID = Cat.ID then
        begin
            Inc(Skipped);
            Continue;
        end;

        if Snippets[I].UserID = Cat.UserID then
        begin
            Tags := AppContext.TagService.GetSnippetTags(Snippets[I].ID);
            SetLength(TagIDs, Length(Tags));
            for K := 0 to High(Tags) do
                TagIDs[K] := Tags[K].ID;

            Snippets[I].CategoryID := Cat.ID;
            AppContext.SnippetService.UpdateSnippet(Snippets[I], TagIDs);
        end
        else
            AppContext.SnippetService.MoveSnippet(Snippets[I].ID, Cat.ID);

        Inc(Moved);
    end;

    if Moved > 0 then
    begin
        if tvCategories.Selected <> nil then
            ReloadUI(Integer(IntPtr(tvCategories.Selected.Data)))
        else
            ReloadUI(PRESERVE_CATEGORY_EMPTY_ID);
        MarkDataChanged;
    end;

    FStatus.Flash(TUIStateLoader.GetMessage('MultiSelect.Move.DoneMsg', [Moved, Skipped]));
end;

procedure TMainForm.actToggleFavoriteExecute(Sender: TObject);
begin
    DoToggleFavorite;
end;

procedure TMainForm.actFavMoveTopExecute(Sender: TObject);
begin
    DoMoveFavorite(fmTop);
end;

procedure TMainForm.actFavMoveUpExecute(Sender: TObject);
begin
    DoMoveFavorite(fmUp);
end;

procedure TMainForm.actFavMoveDownExecute(Sender: TObject);
begin
    DoMoveFavorite(fmDown);
end;

procedure TMainForm.actFavMoveEndExecute(Sender: TObject);
begin
    DoMoveFavorite(fmEnd);
end;

procedure TMainForm.actFavSlotExecute(Sender: TObject);
begin
    if Sender is TAction then
        DoRunFavoriteSlot(TAction(Sender).Tag);
end;

procedure TMainForm.lvSnippetsDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
var
    Item, Selected: TListItem;
begin
    Accept := False;

    if (Source <> lvSnippets) or (lvSnippets.Selected = nil) then
        Exit;
    if (not Assigned(AppContext.DatabaseManager)) or (not AppContext.DatabaseManager.IsConnected) then
        Exit;

    Selected := lvSnippets.Selected;
    if (not Assigned(Selected.Data)) or (not TSnippetViewData(Selected.Data).IsFavorite) then
        Exit;

    Item := lvSnippets.GetItemAt(X, Y);
    if (Item = nil) or (Item = Selected) or (not Assigned(Item.Data)) then
        Exit;

    Accept := TSnippetViewData(Item.Data).IsFavorite;
end;

procedure TMainForm.lvSnippetsDragDrop(Sender, Source: TObject; X, Y: Integer);
var
    Item, Selected: TListItem;
    SrcData, DstData: TSnippetViewData;
    FavList: TArray<TSnippetDTO>;
    ScopeUserID, SrcIdx, DstIdx, NewPos: Integer;
begin
    Selected := lvSnippets.Selected;
    if Selected = nil then
        Exit;

    Item := lvSnippets.GetItemAt(X, Y);
    if (Item = nil) or (Item = Selected) then
        Exit;

    SrcData := TSnippetViewData(Selected.Data);
    DstData := TSnippetViewData(Item.Data);
    if (SrcData = nil) or (DstData = nil) then
        Exit;
    if (not SrcData.IsFavorite) or (not DstData.IsFavorite) then
        Exit;

    if FFilterUserID > 0 then
        ScopeUserID := FFilterUserID
    else
        ScopeUserID := 0;

    FavList := AppContext.SnippetService.GetFavorites(ScopeUserID);

    SrcIdx := -1;
    DstIdx := -1;
    for var I := 0 to High(FavList) do
    begin
        if FavList[I].ID = SrcData.ID then SrcIdx := I;
        if FavList[I].ID = DstData.ID then DstIdx := I;
    end;

    if (SrcIdx < 0) or (DstIdx < 0) then
        Exit;

    // После удаления источника вставка по индексу цели даёт:
    // перетаскивание вверх -> выше цели, вниз -> ниже цели
    NewPos := DstIdx;

    AppContext.SnippetService.MoveFavoriteToPosition(SrcData.ID, ScopeUserID, NewPos);
    ReloadSnippetListKeepingSelection;
end;

procedure TMainForm.lvTagsEdited(Sender: TObject; Item: TListItem; var S: string);
begin
    FTags.HandleEdited(Item, S);
end;

procedure TMainForm.MarkDataChanged;
begin
    GetSyncEngine.MarkDataChanged;
    FStatus.SetDirty(True);
end;

function TMainForm.GetSyncEngine: TSyncController;
begin
    if not Assigned(FSync) then
        FSync := TSyncController.Create(AppContext, actSyncDatabase, FStatus, tmrAutoSync,
            PRESERVE_CATEGORY_EMPTY_ID,
            procedure(PreserveCategoryID: Integer)
            begin
                ReloadUI(PreserveCategoryID);
            end);
    Result := FSync;
end;

function TMainForm.GetSearchEngine: TMainSearchController;
begin
    if not Assigned(FSearch) then
        FSearch := TMainSearchController.Create(AppContext, ebSearch,
            function: Boolean
            begin
                Result := rbFTS.Checked;
            end,
            procedure(Results: TArray<TSnippetDTO>)
            begin
                DisplaySearchResults(Results);
            end,
            procedure
            begin
                RefreshCurrentSnippetList;
            end);
    Result := FSearch;
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
        GetSyncEngine.WaitForCompletion;

        // Авто-синхронизация при закрытии
        // Если мы закрываем программу, а таймер еще тикает (прошло меньше 5 сек с последней правки)
        if GetSyncEngine.Dirty and AppContext.SettingsManager.Data.SyncOnExit then
        begin
            GetSyncEngine.StopTimer; // Глушим таймер
            // Важно! Вызываем СИНХРОННО (False). Программа "зависнет" на секунду,
            // но гарантированно допишет все файлы на жесткий диск перед закрытием.
            GetSyncEngine.PerformSync(False);
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
    FCategoryTree.FilterUserID := UserID;
    GetSearchEngine.SetUserFilter(UserID);

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
    SelectedCatID: Integer;
begin
    MI := Sender as TMenuItem;
    LangCode := MI.Hint;
    MI.Checked := True;

    // Сохраняем выбор, загружаем языковой файл и переводим все открытые окна
    FLangMenu.SelectLanguage(LangCode);

    // Сохранение текущего состояния
    SelectedCatID := PRESERVE_CATEGORY_EMPTY_ID;
    SelectedSnippetID := 0;
    SelectedTagID := 0;

    if tvCategories.Selected <> nil then
        SelectedCatID := Integer(IntPtr(tvCategories.Selected.Data));

    if (lvSnippets.Selected <> nil) and Assigned(lvSnippets.Selected.Data) then
        SelectedSnippetID := TSnippetViewData(lvSnippets.Selected.Data).ID;

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
    TWorkspaceManagerForm.ExecuteModal(Self, AppContext);
    LoadUsersToComboBox;  // Перезагружает список пространств и ставит ItemIndex := 0.
    cbUserChange(cbUser); // Явно вызываем OnChange. Он обновит FFilterUserID и вызовет ReloadUI.
end;

function TMainForm.ExtractSnippetByListItem(Item: TListItem): TSnippetDTO;
begin
    if not Assigned(Item) or not Assigned(Item.Data) then
        Exit(Default(TSnippetDTO));
    Result := AppContext.SnippetService.GetSnippetByID(TSnippetViewData(Item.Data).ID);
end;

procedure TMainForm.UpdateSnippetCount;
begin
    FStatus.SetSnippetCount(lvSnippets.Items.Count, lvSnippets.SelCount);
end;

function TMainForm.CurrentDbFileName: string;
var
    ConnParts: TStringList;
begin
    Result := '';
    if (not Assigned(AppContext.DatabaseManager)) or (not AppContext.DatabaseManager.IsConnected) then
        Exit;
    ConnParts := TStringList.Create;
    try
        ConnParts.Text := AppContext.DatabaseManager.GetConnectionString;
        Result := ExtractFileName(ConnParts.Values['Database']);
    finally
        ConnParts.Free;
    end;
end;

procedure TMainForm.FillUserInterfaceFromSnippet(const Snippet: TSnippetDTO);
var
    SnippetTags: TArray<TTagDTO>;
begin
    FTags.CurrentSnippetID := Snippet.ID;

    // Отрисовка тегов через TUIHelpers.
    // При активном фильтре по тегам список не перерисовываем:
    // выделение фильтра должно оставаться видимым до его сброса пользователем
    if Length(FTags.FilterTagIDs) = 0 then
    begin
        SnippetTags := AppContext.TagService.GetSnippetTags(Snippet.ID);
        TUIHelpers.FillTagListWithSelection(lvTags, FAllTagsCache, SnippetTags);
    end;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if (Key = VK_ESCAPE) and (Length(FTags.FilterTagIDs) > 0) and not lvTags.IsEditing then
    begin
        FTags.ClearFilter;
        Key := 0;
    end;
end;

procedure TMainForm.lvTagsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
    FTags.HandleMouseDown(Button, X, Y);
end;

procedure TMainForm.lvTagsClick(Sender: TObject);
begin
    FTags.HandleClick;
end;

procedure TMainForm.lvTagsContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var
    Item: TListItem;
    I: Integer;
begin
    // Если кликнули по невыделенному тегу - выделяем только его (мультивыделение
    // сохраняем, если точка попала в один из уже выбранных). Фильтр при этом
    // не применяем, в отличие от левого клика
    Item := lvTags.GetItemAt(MousePos.X, MousePos.Y);
    if (Item <> nil) and (not Item.Selected) then
    begin
        for I := 0 to lvTags.Items.Count - 1 do
            lvTags.Items[I].Selected := False;
        Item.Selected := True;
        Item.Focused := True;
    end;
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

procedure TMainForm.nTerminalsClick(Sender: TObject);
begin
    // Тело (тест локального ИИ) перенесено в UI\Services\UI.Services.LocalAISmokeTest.pas
end;

procedure TMainForm.PerformSearchAsync(const Mask: string);
begin
    GetSearchEngine.SearchAsync(Mask);
end;

procedure TMainForm.PerformSync(IsAsync: Boolean; ShowToastOnDone: Boolean);
begin
    GetSyncEngine.PerformSync(IsAsync, ShowToastOnDone);
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
            end
            else if I = TAppStatusBar.SB_PANEL_DIRTY then
            begin
                if FStatus.Dirty then
                    actSyncDatabase.Execute;
            end;

            Break; // Нашли нужную панель - выходим из цикла
        end;
    end;
end;

procedure TMainForm.sbBottomResize(Sender: TObject);
begin
    FStatus.Layout;
end;

procedure TMainForm.tmrAutoSyncTimer(Sender: TObject);
begin
    GetSyncEngine.HandleAutoSyncTick;
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

