unit MainFormUI;

interface

uses
    BaseFormUI,
    CategoryTreeController,
    Common.AppVersion,
    Common.CmdLine,
    Core.Entities.Chain,
    Core.Entities.SavedQuery,
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
    SecurityScanController,
    SynHighlighterFactory,
    SyncController,
    TagListController,
    UI.AppStatusBar,
    System.Actions,
    System.Classes,
    System.DateUtils,
    System.Generics.Collections,
    System.ImageList,
    System.Notification,
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
    Vcl.Graphics,
    Vcl.ImageCollection,
    Vcl.ImgList,
    Vcl.Menus,
    Vcl.StdCtrls,
    EditEx,
    Vcl.Themes,
    Vcl.VirtualImageList,
    Winapi.Messages,
    Winapi.Windows,
    // Подцепляем последним:
    ListViewEx
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
        nDuplicateSnippet: TMenuItem;
        nDeleteSnippet: TMenuItem;
        pSearchType: TPanel;
        rbText: TRadioButton;
        rbFTS: TRadioButton;
        N3: TMenuItem;
        nSearch: TMenuItem;
        nTools: TMenuItem;
        nPasswordGenerator: TMenuItem;
        tmrSearchTimer: TTimer;
        tmrBackup: TTimer;
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
        nTerminalManager: TMenuItem;
        ActionList: TActionList;
        actAddSnippet: TAction;
        actEditSnippet: TAction;
        actDuplicateSnippet: TAction;
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
        actTerminalManager: TAction;
        actSecurityReport: TAction;
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
        actSavedQueryCreate: TAction;
        actSavedQueryCreateFromSearch: TAction;
        actSavedQueryDelete: TAction;
        puFavMove: TMenuItem;
        actSnippetHistory: TAction;
        tmrAutoSync: TTimer;
        procedure actAddCategoryExecute(Sender: TObject);
        procedure actAddSnippetExecute(Sender: TObject);
        procedure actAddTagExecute(Sender: TObject);
        procedure actArchiveBuilderExecute(Sender: TObject);
        procedure actTerminalManagerExecute(Sender: TObject);
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
        procedure actDuplicateSnippetExecute(Sender: TObject);
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
        procedure actSavedQueryCreateExecute(Sender: TObject);
        procedure actSavedQueryCreateFromSearchExecute(Sender: TObject);
        procedure actSavedQueryDeleteExecute(Sender: TObject);
        procedure actSecurityReportExecute(Sender: TObject);
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
        procedure lvSnippetsAdvancedCustomDrawItem(Sender: TCustomListView; Item: TListItem;
            State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
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
        procedure lvTagsAdvancedCustomDrawItem(Sender: TCustomListView; Item: TListItem;
            State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
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
        procedure ListSplitterMoved(Sender: TObject);
        procedure FormResize(Sender: TObject);
        procedure tmrAutoSyncTimer(Sender: TObject);
        procedure tmrSearchTimerTimer(Sender: TObject);
        procedure tmrBackupTimer(Sender: TObject);
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
        FCloseAfterTypingStop: Boolean;
        tmrCloseAfterTyping: TTimer;
        FNoSyncMode: Boolean;
        FCmdProcessed: Boolean;
        FPurgedStaleDrafts: Boolean;
        FBackupRunning: Boolean;
        FCmdParams: TCmdLineParams;
        FHotkeyMgr: TGlobalHotkeyManager;
        FSync: TSyncController;
        FStatus: TAppStatusBar;
        FSearch: TMainSearchController;
        FSecurityScan: TSecurityScanController;
        FUsersCache: TArray<TUserDTO>;
        FAllTagsCache: TArray<TTagDTO>;
        FCategoryTree: TCategoryTreeController;
        FTags: TTagListController;
        FLangMenu: TLanguageMenuController;

        procedure MarkDataChanged;
        procedure tmrCloseAfterTypingTimer(Sender: TObject);
        function GetSyncEngine: TSyncController;
        function GetSearchEngine: TMainSearchController;
        function GetSecurityScan: TSecurityScanController;
        procedure FillSnippetListView(const Snippets: TArray<TSnippetDTO>);
        procedure UpdateSnippetLastRunRow(SnippetID: Integer);
        procedure SizeSnippetListColumns;
        procedure StretchSnippetTitleColumn;
        procedure EnsureSnippetColumns;
        function GetSelectedSnippetID: Integer;
        procedure SelectSnippetByID(SnippetID: Integer);
        procedure FreeSnippetListData;
        function ExtractSnippetByListItem(Item: TListItem): TSnippetDTO;
        procedure FillUserInterfaceFromSnippet(const Snippet: TSnippetDTO);
        function FormatSnippetLanguageText(const ALanguage: string; ALocked: Boolean): string;

        // Do-методы
        procedure DoAddSnippet;
        procedure DoEditSnippet;
        procedure DoDeleteSnippet;
        procedure DoDuplicateSnippet;
        procedure DoShowSnippetHistory;
        procedure DoToggleFavorite;
        procedure DoMoveFavorite(Direction: TFavoriteMoveDirection);
        procedure DoRunFavoriteSlot(Index: Integer);
        procedure DoRunSequence;
        procedure DoExportSnippets;
        procedure DoAddTagToSnippets;
        procedure DoRemoveTagFromSnippets;
        procedure DoMoveToCategory;
        procedure DeleteSnippetDraft(ASnippetID: Integer);
        procedure PurgeStaleDrafts;
        function GetSelectedSnippets: TArray<TSnippetDTO>;
        procedure ReloadSnippetListKeepingSelection;

        // UI Helpers
        procedure SetUserFilter(UserID: Integer);
        procedure LoadUsersToComboBox;
        procedure ProcessCommandLineParams;
        function OpenDatabaseFile(const AFileName: string): Boolean;
        procedure MaybeOfferDbEncryption;
        function EnableDbEncryptionNow(AInitial: Boolean = False): Boolean;
        function ResolveDbOpenKey(const AFileName: string): string;
        function PromptImportDbKey(var AKey: string): Boolean;
        procedure OfferDbKeyExport(const AKey: string);
        function OpenDbKeyMaterial: string;
        procedure RunAutoBackupInBackground;
        procedure StartAutoBackupThread(const ADbFile: string;
            AIntervalSeconds, AKeep: Integer; const ADbKey: string = '');
        procedure SelectWorkspaceByName(const AName: string);
        procedure UpdateMenuState;
        procedure UpdateFavoriteMenuState;
        procedure UpdateChainMenuState;
        procedure UpdateSavedQueryMenuState;
        function GetSelectedChainID: Integer;
        function ShowChainEditor(ChainID: Integer; InitialSnippetID: Integer = 0): Integer;
        procedure SaveCurrentSearchAsSavedQuery;
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
        // Клик по тосту фоновой проверки секретов - открыть отчёт аудита
        procedure SecurityToastNotification(Sender: TObject; ANotification: TNotification);
        // Синхронизация Markdown
        procedure PerformSync(IsAsync: Boolean; ShowToastOnDone: Boolean = False);
        function ListViewHelpOffset(LV: TListView): Integer;
    protected
        procedure WMActivate(var Msg: TWMActivate); message WM_ACTIVATE;
        procedure DoInitialize; override;
        procedure DoShownOnScreen; override;
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
    Common.DbCrypto,
    Common.DraftStore,
    Common.Helpers,
    Common.Settings,
    Core.MarkdownExporter,
    Core.MarkdownImporter,
    CronGenFormUI,
    Data.Database.Migrations,
    Data.Database.Security,
    Data.Database,
    DbConvertProgressUI,
    EpochConverterFormUI,
    HistoryFormUI,
    HotkeyService,
    InputFormUI,
    Core.LocalAIService,
    MacroInputTypes,
    NetworkFormUI,
    PassphraseFormUI,
    PasswordGenFormUI,
    ProcessProfile,
    QuickSearchFormUI,
    SequenceOrderDialogUI,
    SettingsFormUI,
    SecurityReportFormUI,
    SnippetRunner,
    SnippetViewData,
    System.Math,
    System.IOUtils,
    System.NetEncoding,
    System.UITypes,
    TagEditorFormUI,
    TagSelectDialogUI,
    TerminalManagerFormUI,
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

            // Новая база сразу шифруется DPAPI: уведомляем, что ключ
            // привязан к машине и тип шифрования меняется в настройках
            if EnableDbEncryptionNow(True) then
                MessagesHandler.ShowInfo(
                    TUIStateLoader.GetMessage('DB.EncryptedOnCreateNotice'));

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

procedure TMainForm.actDuplicateSnippetExecute(Sender: TObject);
begin
    DoDuplicateSnippet;
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

procedure TMainForm.actSecurityReportExecute(Sender: TObject);
begin
    if not AppContext.DatabaseManager.IsConnected then
    begin
        MessagesHandler.ShowError(TUIStateLoader.GetMessage('DB.NoConnectionError'));
        Exit;
    end;
    TSecurityReportForm.Execute(Self, AppContext);
end;

// Клик по тосту фоновой проверки секретов: открываем отчёт аудита.
// База могла быть закрыта после показа тоста - тогда молча игнорируем
procedure TMainForm.SecurityToastNotification(Sender: TObject; ANotification: TNotification);
begin
    if (ANotification.Name = SECURITY_TOAST_NAME) and
        AppContext.DatabaseManager.IsConnected then
        actSecurityReportExecute(Self);
end;

procedure TMainForm.actOpenDatabaseExecute(Sender: TObject);
begin
    OpenDialog.InitialDir := GetDefaultDataDir;
    OpenDialog.FileName := 'snippets.sqlite';
    if OpenDialog.Execute(Handle) then
        OpenDatabaseFile(OpenDialog.FileName);
end;

function TMainForm.OpenDatabaseFile(const AFileName: string): Boolean;
var
    Key: string;
    Plain, Resolved, Adopted: Boolean;
    Setts: TAppSettings;
    P: TDbSecurityProfile;
begin
    Result := False;
    try
        Setts := AppContext.SettingsManager.Data;
        // Фактическое состояние файла важнее флага настроек: флаг един
        // на приложение и мог остаться от другой базы. Незашифрованный
        // файл открываем без ключа, зашифрованный - с сохранённым
        // ключом (даже если флаг уже указывал на другую базу). Если
        // ключа в памяти нет (passphrase не сохранена), запрашиваем
        // его до первой попытки: открытие без ключа даёт лишь
        // бессмысленную ошибку "not a database"
        Plain := DbFileIsPlain(AFileName);
        Resolved := False;
        Adopted := False;
        Key := '';
        if Plain then
            (AppContext.DatabaseManager as TAppDatabase).EncryptionKey := ''
        else
        begin
            // Ключ ищем сначала в профиле этой базы; при его отсутствии -
            // в глобальном слоте (настройки могли остаться от другой
            // базы). Подошедший базе глобальный ключ закрепляем в её
            // профиле после открытия
            Key := DbStoredKeyMaterial(GetDbProfile(Setts, AFileName));
            if Key = '' then
            begin
                Key := DbStoredKeyMaterial(Setts.Db);
                Adopted := Key <> '';
            end;
            if Key = '' then
            begin
                // Без DLL mc-движка диалог бесполезен: чистое сообщение
                // про отсутствие библиотеки вместо сырой ошибки SQLite
                if not DbEngineDllAvailable then
                    raise Exception.Create(TUIStateLoader.GetMessage(
                        'DB.EncryptionEngineMissing', [DbEngineDllPath]));
                Key := ResolveDbOpenKey(AFileName);
                if Key = '' then
                    Exit; // Отмена диалога - не ошибка: выходим беззвучно
                Resolved := True;
            end;
            (AppContext.DatabaseManager as TAppDatabase).EncryptionKey := Key;
        end;
        try
            AppContext.DatabaseManager.OpenDatabase(AFileName);
            // Флаг настроек молча подводим к факту открытого файла:
            // предупреждать не о чем - после синхронизации настройки
            // снова соответствуют реальности
            if DbEncryptionEnabled(Setts.Db) <> (not Plain) then
            begin
                Setts.Db.DbDefined := True;
                if Plain then
                    Setts.Db.Encryption := DB_ENCRYPTION_NONE
                else
                    Setts.Db.Encryption := DB_ENCRYPTION_AES256;
                AppContext.SettingsManager.Data := Setts;
                AppContext.SettingsManager.Save;
            end;
        except
            on E: Exception do
            begin
                // Незашифрованная база без ключа открыться не смогла -
                // причина не в шифровании, не маскируем её диалогами
                if Plain then
                    raise;
                // Зашифрованная база не открылась сохранённым ключом:
                // перенесена с другой машины или ключ неизвестен
                // (passphrase). В passphrase-режиме спрашиваем парольную
                // фразу, в DPAPI-режиме предлагаем импорт ключа.
                // Без DLL mc-движка диалог бесполезен: чистое сообщение
                // про отсутствие библиотеки вместо сырой ошибки SQLite
                if not DbEngineDllAvailable then
                    raise Exception.Create(TUIStateLoader.GetMessage(
                        'DB.EncryptionEngineMissing', [DbEngineDllPath]));
                Key := ResolveDbOpenKey(AFileName);
                if Key = '' then
                    Exit; // Отмена диалога - не ошибка: выходим беззвучно
                Resolved := True;
                (AppContext.DatabaseManager as TAppDatabase).EncryptionKey := Key;
                AppContext.DatabaseManager.OpenDatabase(AFileName);
            end;
        end;
        // Диалоговый ключ закрепляем в профиле базы, чтобы она
        // открывалась без диалогов при следующем запуске (passphrase -
        // только по галке запоминания). Подошедший базе ключ глобального
        // слота переносим в её профиль as-is. Флаг шифрования подводим
        // к факту - файл зашифрован, даже если в настройках было выключено
        if Resolved or Adopted then
        begin
            Setts := AppContext.SettingsManager.Data;
            if Resolved then
                PinDbKeyTo(Setts, AFileName, Key, False)
            else
            begin
                P := GetDbProfile(Setts, AFileName);
                P.KeyMode := Setts.Db.KeyMode;
                P.Salt := Setts.Db.Salt;
                P.RememberKey := Setts.Db.RememberKey;
                // Passphrase без запоминания ключ на диск не пишет:
                // чужой сохранённый блоб не превращаем в постоянный
                if (P.KeyMode = DB_KEYMODE_PASSPHRASE) and
                    (not P.RememberKey) then
                    P.Key := ''
                else
                    P.Key := Setts.Db.Key;
                SaveDbProfile(Setts, P);
            end;
            AppContext.SettingsManager.Data := Setts;
            AppContext.SettingsManager.Save;
        end;
        TStateMgr.Instance.OpenDatabase;

        PurgeStaleDrafts;

        // Предложение шифрования на первом запуске: до старта потока
        // автобэкапа, чтобы он не держал файл во время конверсии
        MaybeOfferDbEncryption;

        // Автобэкап БД (включённость/интервал/ротация - в настройках):
        // фоновый поток на отдельном соединении, UI не блокируется.
        // Сбой бэкапа не мешает работе с БД - сообщаем и продолжаем
        RunAutoBackupInBackground;

        // Фоновая проверка секретов: первый скан с задержкой 10 секунд
        // (тост об открытии базы должен уйти из центра уведомлений),
        // затем периодика по настройкам
        GetSecurityScan.Start;

        LoadUsersToComboBox;  // Сначала загружаем выпадающий список
        cbUserChange(cbUser); // Вызываем OnChange, что инициирует ReloadUI с правильным ID

        // Возвращаем фокус дереву, чтобы на восстановленном выделении
        // был виден пунктирный прямоугольник
        if tvCategories.CanFocus then
            tvCategories.SetFocus;

        ShowSimpleToast(TUIStateLoader.GetMessage('DB.OpenedSuccess'));

        // Авто-синхронизация при старте
        if AppContext.SettingsManager.Data.SyncOnStart and (not FNoSyncMode) then
        begin
            PerformSync(True, True); // Асинхронно, чтобы не тормозить показ формы
        end;

        Result := True;
    except
        on E: Exception do
            MessagesHandler.ShowError(TUIStateLoader.GetMessage('DB.OpenError', [E.Message]));
    end;
end;

// Первый запуск с открытой базой: предлагаем включить шифрование (DPAPI
// этой машины). Спрашиваем один раз - флаг FirstRunPromptDone пишется
// сразу после вопроса, независимо от ответа
procedure TMainForm.MaybeOfferDbEncryption;
var
    Setts: TAppSettings;
    Confirmed: Boolean;
begin
    Setts := AppContext.SettingsManager.Data;
    // Без DLL mc-движка предложение бессмысленно; при появлении
    // библиотеки вопрос покажется при следующем запуске
    if Setts.Db.FirstRunPromptDone or DbEncryptionEnabled(Setts.Db) or
        (not DbEngineDllAvailable) then
        Exit;

    Confirmed := MessagesHandler.AskWarning(
        TUIStateLoader.GetMessage('DB.FirstRunEncryptAsk'),
        TUIStateLoader.GetMessage('Common.Warning'));

    Setts.Db.FirstRunPromptDone := True;
    AppContext.SettingsManager.Data := Setts;
    AppContext.SettingsManager.Save;

    if Confirmed then
        EnableDbEncryptionNow;
end;

// Включение шифрования немедленно (согласие в диалоге первого запуска):
// автобэкап -> закрытие БД -> PRAGMA rekey -> настройки -> переоткрытие.
// При сбое возвращаем рабочее состояние: файл остался с прежним ключом
function TMainForm.EnableDbEncryptionNow(AInitial: Boolean): Boolean;
var
    DbFile, BackupFile, ErrMsg: string;
    Setts: TAppSettings;
    NewKey: string;
    RawKey: TBytes;
    DbApp: TAppDatabase;
    P: TDbSecurityProfile;
begin
    Result := False;
    DbFile := AppContext.DatabaseManager.DatabaseFile;
    if (not AppContext.DatabaseManager.IsConnected) or
        DbFile.IsEmpty or SameText(DbFile, ':memory:') then
        Exit;

    // Конверсия требует PRAGMA rekey mc-движка: на статическом FireDAC
    // она невозможна
    if not DbEngineDllAvailable then
    begin
        MessagesHandler.ShowError(
            TUIStateLoader.GetMessage('Settings.DbEngineMissing'));
        Exit;
    end;

    // Сверяем с фактическим файлом, а не с флагом настроек: если файл
    // уже зашифрован - только подводим флаг к реальности
    if not DbFileIsPlain(DbFile) then
    begin
        Setts := AppContext.SettingsManager.Data;
        Setts.Db.DbDefined := True;
        Setts.Db.Encryption := DB_ENCRYPTION_AES256;
        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;
        Exit(True);
    end;

    Setts := AppContext.SettingsManager.Data;

    // Новая база получает собственный свежий ключ: сохранённый ключ
    // другой базы из настроек не переиспользуем
    if AInitial then
        NewKey := ''
    else
        NewKey := DbKeyMaterial(Setts.Db);
    if NewKey = '' then
    begin
        RawKey := DbGenerateMasterKey;
        try
            NewKey := TNetEncoding.Base64.EncodeBytesToString(RawKey);
        finally
            WipeSecretBytes(RawKey);
        end;
    end;

    try
        if AInitial then
            // Резервная копия новой пустой базы не нужна
            BackupFile := ''
        else
            BackupFile := CreateAutoBackupStandalone(DbFile,
                Setts.Backup.IntervalSeconds, Setts.Backup.Keep, True,
                DbKeyMaterial(Setts.Db));
        AppContext.DatabaseManager.CloseDatabase;
        if not ConvertDbWithProgress(
            TUIStateLoader.GetMessage('Settings.DbConversionTitle'),
            TUIStateLoader.GetMessage('Settings.DbConversionInProgress'),
            DbFile, '', NewKey, AppContext, ErrMsg) then
            raise Exception.Create(ErrMsg);
        Setts.Db.DbDefined := True;
        Setts.Db.Encryption := DB_ENCRYPTION_AES256;
        Setts.Db.KeyMode := DB_KEYMODE_DPAPI;
        Setts.Db.RememberKey := True;
        Setts.Db.Salt := '';
        Setts.Db.Key := NewKey;
        // Профиль этой базы получает собственную копию ключа: глобальный
        // слот позже может уйти к другой базе
        P := GetDbProfile(Setts, DbFile);
        P.KeyMode := Setts.Db.KeyMode;
        P.RememberKey := Setts.Db.RememberKey;
        P.Salt := Setts.Db.Salt;
        P.Key := Setts.Db.Key;
        SaveDbProfile(Setts, P);
        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;
        DbApp := AppContext.DatabaseManager as TAppDatabase;
        DbApp.EncryptionKey := NewKey;
        AppContext.DatabaseManager.OpenDatabase(DbFile);
        TStateMgr.Instance.OpenDatabase;
        // Копия снята до конверсии открытой базы - она в открытом виде
        if BackupFile <> '' then
            MessagesHandler.ShowInfo(TUIStateLoader.GetMessage(
                'Settings.DbBackupUnencrypted', [BackupFile]));
        // При создании базы факт шифрования сообщает отдельное
        // уведомление о привязке ключа к машине
        if not AInitial then
            ShowSimpleToast(TUIStateLoader.GetMessage('DB.EncryptionEnabled'));
        Result := True;
    except
        on E: Exception do
        begin
            MessagesHandler.ShowError(TUIStateLoader.GetMessage(
                'DB.EncryptionEnableFailed', [E.Message]));
            try
                DbApp := AppContext.DatabaseManager as TAppDatabase;
                DbApp.EncryptionKey := '';
                AppContext.DatabaseManager.OpenDatabase(DbFile);
                TStateMgr.Instance.OpenDatabase;
            except
            end;
        end;
    end;
    // Ключ создан заново: предлагаем сохранить его в файл сразу, пока
    // он не утерян (и при первом запуске, и при включении из настроек)
    if Result then
        OfferDbKeyExport(NewKey);
end;

// Предложение сохранить ключ базы в зашифрованный JSON сразу после
// включения шифрования: без файла ключ теряется при переносе базы на
// другую машину. Отказ безопасен - ключ остаётся в настройках машины
procedure TMainForm.OfferDbKeyExport(const AKey: string);
var
    Pass1, KeyJson, OutFile: string;
    RawKey: TBytes;
    SaveDlg: TSaveDialog;
begin
    if AKey = '' then
        Exit;
    if not MessagesHandler.AskWarning(
        TUIStateLoader.GetMessage('Settings.DbExportOfferAsk'),
        TUIStateLoader.GetMessage('Common.Warning')) then
        Exit;

    Pass1 := '';
    if not ShowPasswordConfirmForm(
        TUIStateLoader.GetMessage('Settings.DbExportPassphrase'),
        TUIStateLoader.GetMessage('Settings.DbExportPassphraseConfirm'),
        TUIStateLoader.GetMessage('Settings.DbPassphraseMismatch'),
        AppContext, Pass1) then
        Exit;

    RawKey := TNetEncoding.Base64.DecodeStringToBytes(AKey);
    try
        KeyJson := DbExportKeyToJson(Pass1, RawKey);
    finally
        WipeSecretBytes(RawKey);
    end;

    OutFile := '';
    SaveDlg := TSaveDialog.Create(Self);
    try
        SaveDlg.Title := TUIStateLoader.GetMessage('Settings.DbExportTitle');
        SaveDlg.Filter := 'JSON (*.json)|*.json';
        SaveDlg.DefaultExt := 'json';
        SaveDlg.FileName := Format('snippets-db-key-%s.json',
            [FormatDateTime('yyyy-mm-dd_hh-nn-ss', Now)]);
        SaveDlg.Options := SaveDlg.Options + [ofOverwritePrompt];
        if SaveDlg.Execute(Handle) then
        try
            TFile.WriteAllText(SaveDlg.FileName, KeyJson, TEncoding.UTF8);
            OutFile := SaveDlg.FileName;
        except
            on E: Exception do
                MessagesHandler.ShowError(TUIStateLoader.GetMessage(
                    'Settings.DbExportFailed', [E.Message]));
        end;
    finally
        SaveDlg.Free;
    end;

    if OutFile <> '' then
        MessagesHandler.ShowInfo(TUIStateLoader.GetMessage(
            'Settings.DbExportDone', [OutFile]));
end;

// Зашифрованная база не открылась сохранённым ключом. Passphrase-режим:
// до 3 попыток парольной фразы (ключ выводится из соли профиля базы,
// при его отсутствии - из соли глобального слота), затем импорт ключа.
// DPAPI-режим: база перенесена с другой машины - импорт ключа
function TMainForm.ResolveDbOpenKey(const AFileName: string): string;
var
    Db: TDbSecuritySettings;
    P: TDbSecurityProfile;
    Pass, Key, SaltB64: string;
    Salt: TBytes;
    Attempt: Integer;
begin
    Result := '';
    Db := AppContext.SettingsManager.Data.Db;
    P := GetDbProfile(AppContext.SettingsManager.Data, AFileName);

    // Соль для деривации берём из профиля базы; когда профиля ещё нет -
    // из глобального слота (настройки могли остаться от другой базы).
    // Обе соли пусты: выводить фразу не из чего - сразу предлагаем
    // импорт ключа вместо тихого отказа
    SaltB64 := '';
    if (P.KeyMode = DB_KEYMODE_PASSPHRASE) and (P.Salt <> '') then
        SaltB64 := P.Salt
    else if (Db.KeyMode = DB_KEYMODE_PASSPHRASE) and (Db.Salt <> '') then
        SaltB64 := Db.Salt;

    if SaltB64 <> '' then
    begin
        for Attempt := 1 to 3 do
        begin
            Pass := '';
            if not ShowInputForm(TUIStateLoader.GetMessage('DB.PassphrasePrompt'),
                '', mitPassword, AppContext, Pass) then
                Exit;
            if Pass = '' then
                Exit;
            Salt := TNetEncoding.Base64.DecodeStringToBytes(SaltB64);
            Key := TNetEncoding.Base64.EncodeBytesToString(
                DbDeriveKey(Pass, Salt, DB_PBKDF2_ITERATIONS));
            try
                (AppContext.DatabaseManager as TAppDatabase).EncryptionKey := Key;
                AppContext.DatabaseManager.OpenDatabase(AFileName);
                Result := Key;
                Exit;
            except
                on E: Exception do
                    MessagesHandler.ShowWarning(
                        TUIStateLoader.GetMessage('DB.PassphraseWrong'));
            end;
        end;
    end;

    if not MessagesHandler.AskWarning(
        TUIStateLoader.GetMessage('DB.OpenKeyImportAsk'),
        TUIStateLoader.GetMessage('Common.Warning')) then
        Exit;
    PromptImportDbKey(Result);
end;

// Диалог импорта ключа: файл JSON + парольная фраза файла.
// Импортированный ключ не сохраняется в настройки здесь - решение
// принимает вызывающий код после успешного открытия базы
function TMainForm.PromptImportDbKey(var AKey: string): Boolean;
var
    InFile, KeyJson, Pass: string;
    RawKey: TBytes;
    OpenDlg: TOpenDialog;
begin
    Result := False;
    AKey := '';
    InFile := '';
    OpenDlg := TOpenDialog.Create(Self);
    try
        OpenDlg.Title := TUIStateLoader.GetMessage('DB.KeyImportTitle');
        OpenDlg.Filter := 'JSON (*.json)|*.json';
        OpenDlg.Options := OpenDlg.Options + [ofFileMustExist];
        if OpenDlg.Execute(Handle) then
            InFile := OpenDlg.FileName;
    finally
        OpenDlg.Free;
    end;
    if InFile = '' then
        Exit;

    Pass := '';
    if not ShowInputForm(TUIStateLoader.GetMessage('DB.KeyImportPassphrase'),
        '', mitPassword, AppContext, Pass) then
        Exit;
    if Pass = '' then
        Exit;

    try
        KeyJson := TFile.ReadAllText(InFile, TEncoding.UTF8);
        RawKey := DbImportKeyFromJson(KeyJson, Pass);
        try
            AKey := TNetEncoding.Base64.EncodeBytesToString(RawKey);
        finally
            WipeSecretBytes(RawKey);
        end;
    except
        on E: Exception do
        begin
            MessagesHandler.ShowError(TUIStateLoader.GetMessage(
                'DB.KeyImportFailed', [E.Message]));
            Exit;
        end;
    end;
    Result := AKey <> '';
end;

// Фактический ключ текущего соединения: у открытой зашифрованной базы
// берём ключ соединения - он мог быть введён диалогом и в настройках
// отсутствовать (passphrase без запоминания). Запасные варианты -
// профиль открытой базы, затем глобальный слот. Открытая база без
// шифрования ключа не имеет вовсе: чужой ключ не подставляем
function TMainForm.OpenDbKeyMaterial: string;
var
    DbFile: string;
    DbApp: TAppDatabase;
begin
    Result := '';
    if AppContext.DatabaseManager.IsConnected then
    begin
        DbFile := AppContext.DatabaseManager.DatabaseFile;
        // Незашифрованный файл ключа не имеет, даже если настройки
        // говорят об обратном
        if DbFileIsPlain(DbFile) then
            Exit;
        DbApp := AppContext.DatabaseManager as TAppDatabase;
        Result := DbApp.EncryptionKey;
        if Result <> '' then
            Exit;
        // Ключ сессии неизвестен (passphrase не сохранена) - пробуем
        // профиль этой базы
        Result := DbKeyMaterial(GetDbProfile(
            AppContext.SettingsManager.Data, DbFile));
        if Result <> '' then
            Exit;
    end;
    Result := DbKeyMaterial(AppContext.SettingsManager.Data.Db);
end;

// Автобэкап БД после открытия: фоновый поток + отдельное короткоживущее
// соединение (VACUUM INTO), основное соединение и UI не блокируются.
// Свежая копия (интервал из настроек) - тихий пропуск без тоста
procedure TMainForm.RunAutoBackupInBackground;
var
    DbFile: string;
    IntervalSeconds, Keep: Integer;
begin
    if (not AppContext.SettingsManager.Data.Backup.Enabled) or FBackupRunning then
        Exit;

    DbFile := AppContext.DatabaseManager.DatabaseFile;
    if DbFile = '' then
        Exit;

    IntervalSeconds := AppContext.SettingsManager.Data.Backup.IntervalSeconds;
    Keep := AppContext.SettingsManager.Data.Backup.Keep;

    // Ключ читается в главном потоке до старта фонового: доступ к настройкам
    // из потока не потокобезопасен
    StartAutoBackupThread(DbFile, IntervalSeconds, Keep, OpenDbKeyMaterial);
end;

// Общий стартер фонового автобэкапа (открытие БД и таймер): отдельное
// короткоживущее соединение + VACUUM INTO, UI не блокируется.
// FBackupRunning сериализует запуски - двух параллельных копий не бывает
procedure TMainForm.StartAutoBackupThread(const ADbFile: string;
    AIntervalSeconds, AKeep: Integer; const ADbKey: string);
begin
    FBackupRunning := True;

    TThread.CreateAnonymousThread(
        procedure
        var
            BackupFile, ErrorMsg: string;
        begin
            BackupFile := '';
            ErrorMsg := '';
            try
                BackupFile := Data.Database.Migrations.CreateAutoBackupStandalone(
                    ADbFile, AIntervalSeconds, AKeep, False, ADbKey);
            except
                on E: Exception do
                    ErrorMsg := E.Message;
            end;

            TThread.Synchronize(nil,
                procedure
                begin
                    // Флаг сбрасывается всегда - даже при тихом пропуске
                    FBackupRunning := False;

                    // Приложение может завершаться, пока поток ещё работает:
                    // тост в уничтоженное окно недопустим
                    if Application.Terminated then
                        Exit;

                    if ErrorMsg <> '' then
                        MessagesHandler.ShowError(TUIStateLoader.GetMessage(
                            'DB.AutoBackupFailed', [ErrorMsg]))
                    else if BackupFile <> '' then
                        ShowSimpleToast(TUIStateLoader.GetMessage(
                            'DB.AutoBackupCreated', [BackupFile]));
                end);
        end).Start;
end;

// Периодическая проверка автобэкапа во время долгой работы приложения:
// тик раз в минуту только проверяет страж интервала; сама копия создаётся
// в фоне, если свежайшая старше настроенного интервала
procedure TMainForm.tmrBackupTimer(Sender: TObject);
var
    DbFile: string;
    IntervalSeconds, Keep: Integer;
begin
    if FBackupRunning then
        Exit;

    if not AppContext.SettingsManager.Data.Backup.Enabled then
        Exit;

    DbFile := AppContext.DatabaseManager.DatabaseFile;
    if DbFile = '' then
        Exit;

    IntervalSeconds := AppContext.SettingsManager.Data.Backup.IntervalSeconds;
    Keep := AppContext.SettingsManager.Data.Backup.Keep;

    // Страж не истёк - тик пропускается без тостов и соединений
    if not Data.Database.Migrations.AutoBackupDue(DbFile, IntervalSeconds) then
        Exit;

    StartAutoBackupThread(DbFile, IntervalSeconds, Keep, OpenDbKeyMaterial);
end;

procedure TMainForm.ProcessCommandLineParams;
var
    DbFile: string;
begin
    if FCmdProcessed then
        Exit;
    FCmdProcessed := True;

    if FCmdParams.DbPath <> '' then
    begin
        DbFile := ExpandFileName(FCmdParams.DbPath);

        // FireDAC при Connected := True молча СОЗДАЁТ несуществующий SQLite-файл,
        // поэтому путь из параметра проверяем явно
        if not FileExists(DbFile) then
        begin
            MessagesHandler.ShowError(TUIStateLoader.GetMessage('CmdLine.DbFileNotFound', [DbFile]));
            Exit;
        end;

        if not OpenDatabaseFile(DbFile) then
            Exit;
    end;

    if FCmdParams.UserName <> '' then
        SelectWorkspaceByName(FCmdParams.UserName);
end;

procedure TMainForm.SelectWorkspaceByName(const AName: string);
var
    I, Idx: Integer;
begin
    Idx := -1;
    for I := 0 to cbUser.Items.Count - 1 do
        if SameText(cbUser.Items[I], AName) then
        begin
            Idx := I;
            Break;
        end;

    if Idx >= 0 then
    begin
        cbUser.ItemIndex := Idx;
        cbUserChange(cbUser);
    end
    else
        MessagesHandler.ShowInfo(TUIStateLoader.GetMessage('CmdLine.UserNotFound', [AName]));
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
        if TSettingsForm.ExecuteModal(Self, AppContext) = mrOk then
            // Настройки могли затронуть список сниппетов (видимость колонок) -
            // пересобираем колонки и строки с сохранением выделения
            ReloadSnippetListKeepingSelection;
    finally
        if Assigned(FHotkeyMgr) then FHotkeyMgr.StartListening;
    end;
end;

procedure TMainForm.actTerminalManagerExecute(Sender: TObject);
begin
    TTerminalManagerForm.ExecuteModal(Self, AppContext);
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
    // Версия в заголовке: по ней тестер указывает сборку в баг-репорте
    Caption := Caption + ' ' + GetAppVersionShort;

//    Winapi.Windows.DebugBreak;

    SetProp(Self.Handle, PChar(UNIQUE_APP_STR), 1);

    FUserID := 1;
    FIgnoreCategoryChange := False;
    FPurgedStaleDrafts := False;

    FHotItemIndex := -1;
    FFilterUserID := 0;

    // Опрос остановки печати для отложенного закрытия (см. FormCloseQuery)
    tmrCloseAfterTyping := TTimer.Create(Self);
    tmrCloseAfterTyping.Interval := 100;
    tmrCloseAfterTyping.Enabled := False;
    tmrCloseAfterTyping.OnTimer := tmrCloseAfterTypingTimer;

    lvTags.OwnerData := False;
    lvSnippets.OwnerData := False;
    // Item.Data у lvSnippets - объекты TSnippetViewData, у lvTags - Integer-ID
    lvSnippets.OwnsItemData := True;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
    // Убираем тосты и очищаем кэш WinRT-уведомлений, пока COM-окружение
    // живо: финализационное освобождение словаря тостов в RTL падает AV
    ShutdownToasts;

    // VCL не вызывает OnDeletion при уничтожении самого списка,
    // поэтому данные строк освобождаем явно, пока список ещё существует
    FreeSnippetListData;

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
    if Assigned(FSecurityScan) then
        FSecurityScan.Stop;
    FreeAndNil(FSecurityScan);
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

    // Закрытие посреди печати сниппета - как у цепочек: мягко отменяем
    // печать (CancelTyping ждёт поток с прокачкой CheckSynchronize, так что
    // OnTypingFinished успевает освободить панель Stop через Release) и
    // откладываем закрытие до фактической остановки. Без этого Application
    // завершается, MacroThread пропускает OnTypingFinished и панель утекает
    if AppContext.WindowHelper.IsTypingBusy then
    begin
        AppContext.WindowHelper.CancelTyping;
        FCloseAfterTypingStop := True;
        tmrCloseAfterTyping.Enabled := True;
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

                // Отчёт сканера работает по всей базе - пункт нужен только с подключённой БД
                actSecurityReport.Visible := True;

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

                // Без подключённой БД сканировать нечего - пункт отчёта скрыт
                actSecurityReport.Visible := False;

                // Жестко отключаем все зависимые от контента действия (главное меню и попапы)
                actAddCategory.Enabled := False;
                actDeleteCategory.Enabled := False;
                actEditCategory.Enabled := False;

                actAddSnippet.Enabled := False;
                actEditSnippet.Enabled := False;
                actDeleteSnippet.Enabled := False;
                actDuplicateSnippet.Enabled := False;
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

                // Очищаем списки (данные строк освобождаем вручную:
                // TListItems.Clear не вызывает OnDeletion)
                FreeSnippetListData;
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
    actDeleteSnippet.Enabled := (lvSnippets.Selected <> nil);
    actDuplicateSnippet.Enabled := SingleSelection;
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

    // --- УМНЫЕ ПАПКИ ---
    UpdateSavedQueryMenuState;

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

procedure TMainForm.UpdateSavedQueryMenuState;
var
    Node: TTreeNode;
    NodeValue, SavedQueryID: Integer;
begin
    Node := tvCategories.Selected;
    NodeValue := 0;
    if Node <> nil then
        NodeValue := Integer(IntPtr(Node.Data));

    // «Создать умную папку» доступна только на корневом узле умных папок
    actSavedQueryCreate.Visible := (Node <> nil) and
        (NodeValue = SAVED_QUERIES_ROOT_NODE_ID);
    actSavedQueryDelete.Visible := TryGetSavedQueryID(NodeValue, SavedQueryID);

    // «Сохранить поиск» активна, пока в строке поиска есть текст
    actSavedQueryCreateFromSearch.Enabled :=
        AppContext.DatabaseManager.IsConnected and (Trim(ebSearch.Text) <> '');
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

procedure TMainForm.SaveCurrentSearchAsSavedQuery;
var
    NewID: Integer;
    QueryName: string;
begin
    if Trim(ebSearch.Text) = '' then
    begin
        AppContext.MessagesHandler.ShowError(
            TUIStateLoader.GetMessage('SavedQueries.Error.EmptyQuery'));
        Exit;
    end;

    QueryName := '';
    if not AppContext.MessagesHandler.AskInput(
        TUIStateLoader.GetMessage('SavedQueries.SaveTitle'),
        TUIStateLoader.GetMessage('SavedQueries.NamePrompt'),
        QueryName
    ) then Exit;

    try
        NewID := AppContext.SavedQueryService.CreateSavedQuery(
            FCategoryTree.GetSelectedCategoryUserID, QueryName, ebSearch.Text);
        ReloadUI(EncodeSavedQueryNodeID(NewID));
        FStatus.Flash(TUIStateLoader.GetMessage('SavedQueries.CreatedMsg', [
            AppContext.SavedQueryService.GetSavedQueryByID(NewID).Name]));
        MarkDataChanged;
    except
        on E: Exception do
            AppContext.MessagesHandler.ShowError(E.Message);
    end;
end;

procedure TMainForm.actSavedQueryCreateExecute(Sender: TObject);
begin
    SaveCurrentSearchAsSavedQuery;
end;

procedure TMainForm.actSavedQueryCreateFromSearchExecute(Sender: TObject);
begin
    SaveCurrentSearchAsSavedQuery;
end;

procedure TMainForm.actSavedQueryDeleteExecute(Sender: TObject);
var
    Node: TTreeNode;
    SavedQueryID: Integer;
    SavedQuery: TSavedQueryDTO;
begin
    Node := tvCategories.Selected;
    if (Node = nil) or not TryGetSavedQueryID(Integer(IntPtr(Node.Data)), SavedQueryID) then
        Exit;

    SavedQuery := AppContext.SavedQueryService.GetSavedQueryByID(SavedQueryID);
    if SavedQuery.ID = 0 then
        Exit;

    if AppContext.MessagesHandler.AskConfirmation(
        TUIStateLoader.GetMessage('SavedQueries.DeleteConfirm', [SavedQuery.Name]),
        TUIStateLoader.GetMessage('Common.Confirmation'),
        MB_YESNO or MB_ICONQUESTION
    ) then begin
        try
            AppContext.SavedQueryService.DeleteSavedQuery(SavedQueryID);
            ReloadUI(SAVED_QUERIES_ROOT_NODE_ID);
            FStatus.Flash(TUIStateLoader.GetMessage('SavedQueries.DeletedMsg', [SavedQuery.Name]));
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
                AppContext.ChainService.GetAllChains(FFilterUserID),
                AppContext.SavedQueryService.GetAllSavedQueries(FFilterUserID),
                FFilterUserID,
                PreserveCategoryID);
        finally
            FCategoryTree.AfterRebuild;
        end;
        RefreshCurrentSnippetList;

        // После перезагрузки список тегов мог быть перерисован:
        // восстанавливаем выделение, соответствующее активному фильтру
        if Length(FTags.FilterTagIDs) > 0 then
            FTags.SyncFilterSelection;
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
    CatID, ChainID, I, ActiveSnippetID, SavedQueryID: Integer;
    Snippets: TArray<TSnippetDTO>;
    Steps: TArray<TChainStepDTO>;
begin
    ActiveSnippetID := GetSelectedSnippetID;

    Node := tvCategories.Selected;
    if Node = nil then
    begin
        FreeSnippetListData;
        lvSnippets.Items.Clear;
        Exit;
    end;

    if AppContext.DatabaseManager.IsConnected = False then
        Exit;

    // Активный фильтр по тегам имеет приоритет над выбранной категорией:
    // список остаётся отфильтрованным до ручного сброса фильтра
    if Length(FTags.FilterTagIDs) > 0 then
    begin
        FillSnippetListView(AppContext.SnippetService.GetSnippetsByTags(
            FTags.FilterTagIDs, AppContext.SettingsManager.Data.TagsMatchAll));
        SelectSnippetByID(ActiveSnippetID);
        Exit;
    end;

    // Умная папка: выполняем сохранённый запрос (до ветки цепочек -
    // диапазоны ID узлов не пересекаются, но порядок проверок явный)
    if TryGetSavedQueryID(Integer(IntPtr(Node.Data)), SavedQueryID) then
    begin
        Snippets := AppContext.SnippetService.SearchSnippets(
            AppContext.SavedQueryService.GetSavedQueryByID(SavedQueryID).QueryText,
            rbFTS.Checked, FFilterUserID);
        FillSnippetListView(Snippets);
        Exit;
    end;

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

procedure TMainForm.tmrCloseAfterTypingTimer(Sender: TObject);
begin
    // Отставший (detached) поток держит IsTypingBusy до своего финала -
    // ждём его, чтобы повторный Close пошёл по чистому WindowHelper
    if AppContext.WindowHelper.IsTypingBusy then
        Exit;

    tmrCloseAfterTyping.Enabled := False;
    if FCloseAfterTypingStop then
    begin
        FCloseAfterTypingStop := False;
        Close;
    end;
end;

procedure TMainForm.tvCategoriesChange(Sender: TObject; Node: TTreeNode);
begin
    if FIgnoreCategoryChange then
        Exit;
    if Node = nil then
        Exit;

    FCategoryTree.SaveSelection;
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
    FCmdParams := TCmdLineParams.Parse;
    FNoSyncMode := FCmdParams.NoSync;

    if FCmdParams.Minimized then
        WindowState := wsMinimized;

    KeyPreview := True;
    OnKeyDown := FormKeyDown;

    lvTags.OnMouseDown := lvTagsMouseDown;
    // Активный фильтр должен оставаться видимым, когда фокус уходит из списка тегов
    lvTags.HideSelection := False;
    lvTags.OnAdvancedCustomDrawItem := lvTagsAdvancedCustomDrawItem;

    // Выбранный сниппет тоже должен оставаться видимым без фокуса
    lvSnippets.HideSelection := False;
    lvSnippets.OnAdvancedCustomDrawItem := lvSnippetsAdvancedCustomDrawItem;
    TChainRunner.OnStarted := ChainStarted;
    TChainRunner.OnFinished := ChainFinished;

    FStatus := TAppStatusBar.Create(sbBottom);
    FStatus.Layout;
    FStatus.SetDatabase('');

    // Клик по тосту фоновой проверки секретов маршрутизируется сюда
    SetToastNotificationHandler(SecurityToastNotification);

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
            begin
                FreeSnippetListData;
                lvSnippets.Items.Clear;
            end;
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
    RegisterHelp(lvSnippets, hipTopRight, 'Help.MainForm.lvSnippets', hkCustomForm, 0, ListViewHelpOffset(lvSnippets));
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

    GProfileManager.SyncFromApplications(AppContext.SettingsManager.Data.AllowedApplications.Items);

    TStateMgr.Instance.FirstRun;

    GWinMonitor.StartMonitoring;
end;

{ Высота строки заголовков ListView в координатах 96 DPI - сдвиг кнопки
  справки вниз, ниже заголовков колонок, чтобы не наезжала на них
  (паттерн TerminalManagerForm/ChainEditorForm/TagSelectDialog/SequenceOrderDialog) }
function TMainForm.ListViewHelpOffset(LV: TListView): Integer;
var
    HeaderWnd: HWND;
    R: TRect;
begin
    Result := 2;
    HeaderWnd := FindWindowEx(LV.Handle, 0, 'SysHeader32', nil);
    if (HeaderWnd = 0) or not GetWindowRect(HeaderWnd, R) then
        Exit;
    Result := Max(1, MulDiv(R.Bottom - R.Top, 96, LV.CurrentPPI)) + 2;
end;

procedure TMainForm.DoShownOnScreen;
begin
    inherited;

    ProcessCommandLineParams;
end;

procedure TMainForm.ApplyLanguage;
begin
    inherited;
    actChainCreate.Caption := TUIStateLoader.GetMessage('Chains.Menu.Create');
    actChainCreateFromSnippet.Caption := TUIStateLoader.GetMessage('Chains.Menu.CreateFromSnippet');
    actChainRun.Caption := TUIStateLoader.GetMessage('Chains.Menu.Run');
    actChainEdit.Caption := TUIStateLoader.GetMessage('Chains.Menu.Edit');
    actChainDelete.Caption := TUIStateLoader.GetMessage('Chains.Menu.Delete');
    actSavedQueryCreate.Caption := TUIStateLoader.GetMessage('SavedQueries.Menu.Create');
    actSavedQueryCreateFromSearch.Caption := TUIStateLoader.GetMessage('SavedQueries.Menu.CreateFromSearch');
    actSavedQueryDelete.Caption := TUIStateLoader.GetMessage('SavedQueries.Menu.Delete');
    actRunSequence.Caption := TUIStateLoader.GetMessage('MultiSelect.Menu.RunSequence');
    actExportSnippets.Caption := TUIStateLoader.GetMessage('MultiSelect.Menu.Export');
    actAddTagToSnippets.Caption := TUIStateLoader.GetMessage('MultiSelect.Menu.AddTag');
    actRemoveTagFromSnippets.Caption := TUIStateLoader.GetMessage('MultiSelect.Menu.RemoveTag');
    actMoveToCategory.Caption := TUIStateLoader.GetMessage('MultiSelect.Menu.MoveToCategory');
    // Заголовки колонок lvSnippets могли смениться - пересчитываем ширины
    SizeSnippetListColumns;
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
            Snippet.Language := Language;
            Snippet.LanguageLocked := LanguageLocked;
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
begin
    Item := lvSnippets.Selected;
    if not Assigned(Item) then
        Exit;

    // CategoryID и UserID берём из самого сниппета: при активном фильтре по тегам
    // (и в цепочках) список может содержать сниппеты из другой категории/пространства
    Snippet := ExtractSnippetByListItem(Item);

    if TAddEditSnippetForm.ExecuteEdit(Self, AppContext, Snippet) then
    begin
        if tvCategories.Selected <> nil then
            ReloadUI(Integer(IntPtr(tvCategories.Selected.Data)))
        else
            ReloadUI(PRESERVE_CATEGORY_EMPTY_ID);

        // Обновляем панель сниппета; при активном фильтре RefreshCurrentSnippetList
        // уже восстановил выделение в отфильтрованном списке
        lvSnippetsClick(lvSnippets);

        // Правка содержимого и перевод в trusted меняют статус находок:
        // флаг подсветки должен отреагировать сразу, не дожидаясь периодики
        GetSecurityScan.RescanSnippet(Snippet.ID);

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
        // Восстановление версии меняет содержимое: статус находок пересчитываем
        GetSecurityScan.RescanSnippet(Snippet.ID);
        FStatus.Flash(TUIStateLoader.GetMessage('History.RestoreDone'));
    end;
end;

procedure TMainForm.DoDeleteSnippet;
var
    Snippets: TArray<TSnippetDTO>;
    I: Integer;
    SelectedCatID: Integer;
    ConfirmMsg: string;
begin
    Snippets := GetSelectedSnippets;
    if Length(Snippets) = 0 then
        Exit;

    // Одиночное удаление подтверждаем заголовком сниппета, пакетное - количеством
    if Length(Snippets) = 1 then
        ConfirmMsg := TUIStateLoader.GetMessage('Snippet.DeleteConfirm', [Snippets[0].Title])
    else
        ConfirmMsg := TUIStateLoader.GetMessage('Snippet.DeleteConfirmMulti', [Length(Snippets)]);

    if not MessagesHandler.AskConfirmation(
        ConfirmMsg,
        TUIStateLoader.GetMessage('Common.Confirmation'),
        MB_YESNO or MB_ICONQUESTION or MB_DEFBUTTON2
    ) then
        Exit;

    try
        for I := 0 to High(Snippets) do
        begin
            AppContext.SnippetService.DeleteSnippet(Snippets[I].ID);
            DeleteSnippetDraft(Snippets[I].ID);
            // Удаленный сниппет не может иметь находок: флаг снимаем сразу
            GetSecurityScan.RescanSnippet(Snippets[I].ID);
        end;

        if tvCategories.Selected <> nil then
            SelectedCatID := Integer(IntPtr(tvCategories.Selected.Data))
        else
            SelectedCatID := PRESERVE_CATEGORY_EMPTY_ID;

        ReloadUI(SelectedCatID);
        if Length(Snippets) = 1 then
            FStatus.Flash(TUIStateLoader.GetMessage('Snippet.DeletedMsg'))
        else
            FStatus.Flash(TUIStateLoader.GetMessage('Snippet.DeletedMsgMulti', [Length(Snippets)]));
        MarkDataChanged;
    except
        on E: Exception do
            MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('Snippet.DeleteError', [E.Message])
            );
    end;
end;

procedure TMainForm.DeleteSnippetDraft(ASnippetID: Integer);
var
    Store: TDraftStore;
begin
    if (not Assigned(AppContext.DatabaseManager)) or (not AppContext.DatabaseManager.IsConnected) then
        Exit;
    Store := TDraftStore.Create(ResolvePath('Drafts', True),
        TDraftStore.DbScopeFor(AppContext.DatabaseManager.DatabaseFile));
    try
        Store.DeleteDraft(IntToStr(ASnippetID));
    finally
        Store.Free;
    end;
end;

procedure TMainForm.PurgeStaleDrafts;
var
    Store: TDraftStore;
    All: TArray<TSnippetDTO>;
    LiveIDs: TArray<Int64>;
    I: Integer;
begin
    if FPurgedStaleDrafts then
        Exit;
    if (not Assigned(AppContext.DatabaseManager)) or (not AppContext.DatabaseManager.IsConnected) then
        Exit;
    if not Assigned(AppContext.SnippetService) then
        Exit;
    FPurgedStaleDrafts := True;
    try
    Store := TDraftStore.Create(ResolvePath('Drafts', True),
        TDraftStore.DbScopeFor(AppContext.DatabaseManager.DatabaseFile));
    try
        All := AppContext.SnippetService.GetAllSnippets;
            SetLength(LiveIDs, Length(All));
            for I := 0 to High(All) do
                LiveIDs[I] := All[I].ID;
            Store.PurgeStale(DateTimeToUnix(Now, False) - 14 * 86400, LiveIDs);
        finally
            Store.Free;
        end;
    except
    end;
end;

procedure TMainForm.DoDuplicateSnippet;
var
    Item: TListItem;
    Snippet: TSnippetDTO;
    SelectedCatID: Integer;
begin
    Item := lvSnippets.Selected;
    if Item = nil then
        Exit;

    Snippet := ExtractSnippetByListItem(Item);

    try
        AppContext.SnippetService.DuplicateSnippet(Snippet.ID);

        if tvCategories.Selected <> nil then
            SelectedCatID := Integer(IntPtr(tvCategories.Selected.Data))
        else
            SelectedCatID := PRESERVE_CATEGORY_EMPTY_ID;

        ReloadUI(SelectedCatID);
        FStatus.Flash(TUIStateLoader.GetMessage('Snippet.DuplicatedMsg'));
        MarkDataChanged;
    except
        on E: Exception do
            MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('Snippet.DuplicateError', [E.Message])
            );
    end;
end;

procedure TMainForm.ReloadSnippetListKeepingSelection;
var
    SelID: Integer;
begin
    SelID := GetSelectedSnippetID;

    if Trim(ebSearch.Text) <> '' then
        PerformSearchAsync(ebSearch.Text)
    else
        RefreshCurrentSnippetList;

    SelectSnippetByID(SelID);

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
    LastRuns: TDictionary<Integer, Int64>;
    IDs: TArray<Integer>;
    LastRun: Int64;
    I, Pos: Integer;
    Prefix: string;
    IsFav: Boolean;
    Mask: Integer;
    ShowLang, ShowRun, ShowUpdated: Boolean;
begin
    // Колонки пересобираем до заполнения строк: состав SubItems зависит от маски
    EnsureSnippetColumns;

    Mask := AppContext.SettingsManager.Data.UISettings.SnippetListColumns and 7;
    ShowLang := (Mask and 1) <> 0;
    ShowRun := (Mask and 2) <> 0;
    ShowUpdated := (Mask and 4) <> 0;

    FavPos := nil;
    LastRuns := nil;
    if Assigned(AppContext.DatabaseManager) and AppContext.DatabaseManager.IsConnected then
    begin
        FavList := AppContext.SnippetService.GetFavorites(FFilterUserID);

        FavPos := TDictionary<Integer, Integer>.Create;
        for I := 0 to High(FavList) do
            if not FavPos.ContainsKey(FavList[I].ID) then
                FavPos.Add(FavList[I].ID, I);

        // Время последнего запуска одним батч-запросом (snippet_stats.last_exec_at)
        if ShowRun then
        begin
            SetLength(IDs, Length(Snippets));
            for I := 0 to High(Snippets) do
                IDs[I] := Snippets[I].ID;
            LastRuns := AppContext.SnippetService.GetLastRunBatch(IDs);
        end;
    end;

    lvSnippets.Items.BeginUpdate;
    try
        // TListItems.Clear не вызывает OnDeletion, поэтому старые данные
        // строк освобождаем до перезаполнения списка
        FreeSnippetListData;
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

            if ShowLang then
                Item.SubItems.Add(TSynHighlighterFactory.DisplayName(Snippet.Language));

            if ShowRun then
            begin
                if (LastRuns <> nil) and LastRuns.TryGetValue(Snippet.ID, LastRun) then
                    Item.SubItems.Add(DateTimeToStr(UnixToDateTime(LastRun, False)))
                else
                    Item.SubItems.Add('');
            end;

            // Сниппет ни разу не редактировали (updated_at в БД NULL) - показываем дату создания
            if ShowUpdated then
            begin
                if Snippet.UpdatedAt > 0 then
                    Item.SubItems.Add(DateTimeToStr(UnixToDateTime(Snippet.UpdatedAt, False)))
                else
                    Item.SubItems.Add(DateTimeToStr(UnixToDateTime(Snippet.CreatedAt, False)));
            end;

            Item.StateIndex := 0;

            ViewData := TSnippetViewData.Create;
            ViewData.ID := Snippet.ID;
            ViewData.UserID := Snippet.UserID;
            ViewData.CategoryID := Snippet.CategoryID;
            ViewData.Title := Snippet.Title;
            ViewData.Content := Snippet.Content;
            ViewData.Comment := Snippet.Comment;
            ViewData.Language := Snippet.Language;
            ViewData.LanguageLocked := Snippet.LanguageLocked;
            ViewData.UpdatedAt := Snippet.UpdatedAt;
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
        FreeAndNil(LastRuns);
    end;
    SizeSnippetListColumns;
    UpdateSnippetCount;
end;

procedure TMainForm.UpdateSnippetLastRunRow(SnippetID: Integer);
var
    I, Mask, RunIdx: Integer;
begin
    Mask := AppContext.SettingsManager.Data.UISettings.SnippetListColumns and 7;

    // Колонка «Последний запуск» может быть скрыта в настройках
    if (Mask and 2) = 0 then
        Exit;

    // Точечное обновление делает коллбэк TSnippetRunner: OnRecordRun срабатывает
    // в главном потоке (Synchronize в TMacroThread). Дата идет после «Языка»,
    // если та видима
    if (Mask and 1) <> 0 then
        RunIdx := 1
    else
        RunIdx := 0;

    for I := 0 to lvSnippets.Items.Count - 1 do
        if Assigned(lvSnippets.Items[I].Data) and
            (TSnippetViewData(lvSnippets.Items[I].Data).ID = SnippetID) then
        begin
            lvSnippets.Items[I].SubItems[RunIdx] := DateTimeToStr(Now);
            Break;
        end;
    // Свежий штамп времени мог стать шире колонки - пересчитываем ширины
    SizeSnippetListColumns;
end;

procedure TMainForm.SizeSnippetListColumns;
const
    CELL_TEXT_PAD = 12; // запас на внутренние отступы ячейки и заголовка
var
    I, J: Integer;
    W, MaxW: Integer;
    S: string;
begin
    if not lvSnippets.HandleAllocated then
        Exit;

    // Фиксированные колонки (язык, даты) подстраиваются под самую широкую
    // ячейку либо заголовок, «Название» забирает весь остаток ширины списка.
    // ClientWidth уже исключает вертикальный скроллбар, если он показан
    lvSnippets.Items.BeginUpdate;
    try
        for I := 1 to lvSnippets.Columns.Count - 1 do
        begin
            MaxW := ListView_GetStringWidth(lvSnippets.Handle, PChar(lvSnippets.Columns[I].Caption));
            for J := 0 to lvSnippets.Items.Count - 1 do
            begin
                if I - 1 < lvSnippets.Items[J].SubItems.Count then
                    S := lvSnippets.Items[J].SubItems[I - 1]
                else
                    S := '';
                if S <> '' then
                begin
                    W := ListView_GetStringWidth(lvSnippets.Handle, PChar(S));
                    if W > MaxW then
                        MaxW := W;
                end;
            end;
            lvSnippets.Columns[I].Width := MaxW + CELL_TEXT_PAD;
        end;

        // «Название» забирает весь остаток ширины списка
        StretchSnippetTitleColumn;
    finally
        lvSnippets.Items.EndUpdate;
    end;
end;

procedure TMainForm.StretchSnippetTitleColumn;
const
    // Ширина «Названия», когда места нет вовсе (фиксированные колонки сами
    // не влезают) - дальше уже честная горизонтальная прокрутка
    MIN_TITLE_WIDTH = 100;
    // Жесткий минимум «Названия» без горизонтальной прокрутки: при остатке
    // ниже колонка сжимается до остатка. Типичный случай - появилась
    // вертикальная полоса и остаток стал на ее ширину меньше
    COMPACT_TITLE_WIDTH = 50;
var
    I, FixedWidth, AvailWidth, Remaining: Integer;
    R: TRect;
begin
    if not lvSnippets.HandleAllocated then
        Exit;

    // Пересчет видимости скроллбаров у ListView бывает отложен: вертикальная
    // полоса может появиться позже WM_SIZE (например, при уменьшении высоты
    // окна). Форсируем пересчет - шлем контролу его же WM_SIZE с фактической
    // клиентской областью; после этого состояние полос гарантированно финальное
    Winapi.Windows.GetClientRect(lvSnippets.Handle, R);
    lvSnippets.Perform(WM_SIZE, SIZE_RESTORED,
        MakeLParam(Word(R.Right - R.Left), Word(R.Bottom - R.Top)));

    // Дешевая O(1)-подгонка после ресайза окна или сплиттера: фиксированные
    // колонки не пересчитываем, «Название» забирает весь остаток ширины списка
    FixedWidth := 0;
    for I := 1 to lvSnippets.Columns.Count - 1 do
        Inc(FixedWidth, lvSnippets.Columns[I].Width);

    // Клиентскую область после форс-пересчета берем напрямую из ОС: она уже
    // сужена на ширину вертикальной полосы, если та видима
    Winapi.Windows.GetClientRect(lvSnippets.Handle, R);
    AvailWidth := R.Right - R.Left;

    Remaining := AvailWidth - FixedWidth;
    if Remaining >= COMPACT_TITLE_WIDTH then
        lvSnippets.Columns[0].Width := Remaining
    else
        lvSnippets.Columns[0].Width := MIN_TITLE_WIDTH;
end;

procedure TMainForm.EnsureSnippetColumns;
const
    MASK_LANGUAGE = 1;
    MASK_LASTRUN = 2;
    MASK_UPDATED = 4;
var
    Mask, Count, I: Integer;
    ExpectedTags: array[0..3] of Integer;
    Match: Boolean;
    Col: TListColumn;
begin
    Mask := AppContext.SettingsManager.Data.UISettings.SnippetListColumns and 7;

    // Порядок колонок: Название (Tag 1, видна всегда), Язык (Tag 3),
    // Последний запуск (Tag 2), Последнее изменение (Tag 4)
    ExpectedTags[0] := 1;
    Count := 1;
    if (Mask and MASK_LANGUAGE) <> 0 then
    begin
        ExpectedTags[Count] := 3;
        Inc(Count);
    end;
    if (Mask and MASK_LASTRUN) <> 0 then
    begin
        ExpectedTags[Count] := 2;
        Inc(Count);
    end;
    if (Mask and MASK_UPDATED) <> 0 then
    begin
        ExpectedTags[Count] := 4;
        Inc(Count);
    end;

    Match := lvSnippets.Columns.Count = Count;
    if Match then
        for I := 0 to Count - 1 do
            if lvSnippets.Columns[I].Tag <> ExpectedTags[I] then
            begin
                Match := False;
                Break;
            end;

    if Match then
        Exit;

    lvSnippets.Columns.Clear;
    for I := 0 to Count - 1 do
    begin
        Col := lvSnippets.Columns.Add;
        Col.Tag := ExpectedTags[I];
        case ExpectedTags[I] of
            3: Col.Width := 110;
            2, 4: Col.Width := 140;
        else
            Col.Width := 230; // «Название»
        end;
    end;
    // Заголовки-плейсхолдеры заменяем на локализованные подписи
    TUIStateLoader.ApplyTranslations(Self);
end;

procedure TMainForm.ListSplitterMoved(Sender: TObject);
begin
    StretchSnippetTitleColumn;
end;

procedure TMainForm.lvSnippetsDeletion(Sender: TObject; Item: TListItem);
begin
    if Assigned(Item.Data) then
        TSnippetViewData(Item.Data).Free;
end;

procedure TMainForm.lvSnippetsAdvancedCustomDrawItem(Sender: TCustomListView; Item: TListItem;
    State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
var
    R, SubR: TRect;
    BgColor, FgColor: TColor;
    Images: TCustomImageList;
    I, X: Integer;
begin
    // Единый рендерер для всех строк, не только выделенных. Штатная ветка
    // comctl в этом окружении рисует текст без заливки фона и со своим
    // отступом (~+2px против наших +4px), поэтому любой проход дефолтной
    // ветки поверх пикселей ручной ветки дает наложение текста ("кашу").
    // Триггером была смена выделения: правый клик, popup-меню, hover
    // TRACKSELECT, модальные диалоги. DefaultDraw всегда False - дефолтная
    // ветка больше не участвует вообще, каждый проход заливает строку целиком.
    if Stage <> cdPrePaint then
        Exit;

    R := Item.DisplayRect(drBounds);
    if (R.Right <= R.Left) or (R.Bottom <= R.Top) then
    begin
        DefaultDraw := False;
        Exit;
    end;

    DefaultDraw := False;

    if Item.Selected then
    begin
        if TStyleManager.IsCustomStyleActive then
        begin
            BgColor := TStyleManager.ActiveStyle.GetSystemColor(clHighlight);
            FgColor := TStyleManager.ActiveStyle.GetSystemColor(clHighlightText);
        end
        else
        begin
            BgColor := clHighlight;
            FgColor := clHighlightText;
        end;
    end
    else
    begin
        // Фон и текст невыделенных строк - как их рисует VCL-хук ListView
        // (TListViewStyleHook.UpdateBrushColor: клиент = scListView)
        if TStyleManager.IsCustomStyleActive then
        begin
            BgColor := TStyleManager.ActiveStyle.GetStyleColor(scListView);
            FgColor := TStyleManager.ActiveStyle.GetSystemColor(clWindowText);
        end
        else
        begin
            BgColor := clWindow;
            FgColor := clWindowText;
        end;
    end;

    // Проблемный сниппет (текущие находки фоновой проверки секретов):
    // подмешиваем красный к фону строки. Выделенную строку не трогаем -
    // она уже подсвечена системой, и флаг снова будет виден после снятия
    // выделения. Подсветка сохраняется при рестарте: флаги восстанавливает
    // тихий первый скан сессии
    if (not Item.Selected) and Assigned(Item.Data) and Assigned(FSecurityScan)
        and FSecurityScan.IsFlagged(TSnippetViewData(Item.Data).ID) then
        BgColor := RGB(
            GetRValue(BgColor) + ((255 - GetRValue(BgColor)) * 15) div 100,
            GetGValue(BgColor) - (GetGValue(BgColor) * 15) div 100,
            GetBValue(BgColor) - (GetBValue(BgColor) * 15) div 100);

    Sender.Canvas.Brush.Color := BgColor;
    Sender.Canvas.Brush.Style := bsSolid;
    Sender.Canvas.FillRect(R);

    // Иконка строки (если она когда-нибудь появится у сниппета)
    Images := TListView(Sender).SmallImages;
    X := R.Left;
    if (Item.ImageIndex >= 0) and (Images <> nil) then
    begin
        Images.Draw(Sender.Canvas, R.Left + 2,
            R.Top + (R.Height - Images.Height) div 2, Item.ImageIndex);
        Inc(X, Images.Width + 4);
    end
    else
        Inc(X, 4);

    Sender.Canvas.Brush.Style := bsClear;
    Sender.Canvas.Font := TListView(Sender).Font;
    Sender.Canvas.Font.Color := FgColor;

    // Рисуем по колонкам: в отчёте заголовок не должен вылезать в соседнюю
    // колонку, а значения SubItems обязаны остаться видимыми на выделенной
    // строке (иначе «Последний запуск» исчезает на выделении без фокуса)
    SubR := R;
    SubR.Left := X;
    if TListView(Sender).Columns.Count > 0 then
        SubR.Right := R.Left + TListView(Sender).Columns[0].Width
    else
        SubR.Right := R.Right;
    DrawText(Sender.Canvas.Handle, PChar(Item.Caption), Length(Item.Caption), SubR,
        DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX);

    // Смещение субитема I в report-mode - сумма ширин колонок 0..I
    // (левая граница его собственной колонки), накапливаем по циклу
    X := R.Left;
    for I := 0 to Item.SubItems.Count - 1 do
    begin
        if I + 1 >= TListView(Sender).Columns.Count then
            Break;
        Inc(X, TListView(Sender).Columns[I].Width);
        SubR := R;
        SubR.Left := X + 4;
        SubR.Right := X + TListView(Sender).Columns[I + 1].Width;
        DrawText(Sender.Canvas.Handle, PChar(Item.SubItems[I]), Length(Item.SubItems[I]), SubR,
            DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX);
    end;
end;

procedure TMainForm.FreeSnippetListData;
var
    I: Integer;
begin
    for I := 0 to lvSnippets.Items.Count - 1 do
        if Assigned(lvSnippets.Items[I].Data) then
        begin
            TSnippetViewData(lvSnippets.Items[I].Data).Free;
            // Обнуляем, чтобы возможный OnDeletion не освободил указатель повторно
            lvSnippets.Items[I].Data := nil;
        end;
end;

function TMainForm.GetSelectedSnippetID: Integer;
begin
    Result := 0;
    if (lvSnippets.Selected <> nil) and Assigned(lvSnippets.Selected.Data) then
        Result := TSnippetViewData(lvSnippets.Selected.Data).ID;
end;

procedure TMainForm.SelectSnippetByID(SnippetID: Integer);
var
    I: Integer;
begin
    if SnippetID <= 0 then
        Exit;

    for I := 0 to lvSnippets.Items.Count - 1 do
        if Assigned(lvSnippets.Items[I].Data) and
            (TSnippetViewData(lvSnippets.Items[I].Data).ID = SnippetID) then
        begin
            lvSnippets.Selected := lvSnippets.Items[I];
            lvSnippets.ItemFocused := lvSnippets.Items[I];
            lvSnippets.Items[I].MakeVisible(False);
            Break;
        end;
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
        InfoTip := Format('[%s] %s'#13#10'%s'#13#10'%s', [Data.ID.ToString, Data.Title,
            FormatSnippetLanguageText(Data.Language, Data.LanguageLocked), Comment]);
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
    Runner.OnRunRecorded := UpdateSnippetLastRunRow;
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
    Runner.OnRunRecorded := UpdateSnippetLastRunRow;
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
    if FNoSyncMode then
        Exit;

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

function TMainForm.GetSecurityScan: TSecurityScanController;
begin
    if not Assigned(FSecurityScan) then
        FSecurityScan := TSecurityScanController.Create(AppContext, FStatus,
            procedure
            begin
                // Флаги читаются при отрисовке строк: инвалидация
                // перерисовывает список с новой подсветкой
                lvSnippets.Invalidate;
            end);
    Result := FSecurityScan;
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
        // Останавливаем периодику и снимаем подсветку проблемных строк
        GetSecurityScan.Stop;

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

function TMainForm.FormatSnippetLanguageText(const ALanguage: string; ALocked: Boolean): string;
begin
    // Подпись используется только в InfoTip списка сниппетов:
    // краткие варианты («· вручную» / «· авто») были у лейбла и удалены вместе с ним
    if ALocked then
        Result := TUIStateLoader.GetMessage('Snippet.LanguageManualHint', [TSynHighlighterFactory.DisplayName(ALanguage)])
    else
        Result := TUIStateLoader.GetMessage('Snippet.LanguageAutoHint', [TSynHighlighterFactory.DisplayName(ALanguage)]);
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

procedure TMainForm.lvTagsAdvancedCustomDrawItem(Sender: TCustomListView; Item: TListItem;
    State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
var
    R: TRect;
    BgColor, FgColor: TColor;
    StateImages: TCustomImageList;
begin
    // Единый рендерер для всех строк (тот же артефакт "каши", что и в
    // lvSnippets): дефолтная ветка comctl рисует текст без заливки фона
    // поверх пикселей ручной ветки при любой смене выделения. DefaultDraw
    // всегда False - каждый проход заливает строку целиком.
    if Stage <> cdPrePaint then
        Exit;

    R := Item.DisplayRect(drBounds);
    if (R.Right <= R.Left) or (R.Bottom <= R.Top) then
    begin
        DefaultDraw := False;
        Exit;
    end;

    DefaultDraw := False;

    if Item.Selected then
    begin
        if TStyleManager.IsCustomStyleActive then
        begin
            BgColor := TStyleManager.ActiveStyle.GetSystemColor(clHighlight);
            FgColor := TStyleManager.ActiveStyle.GetSystemColor(clHighlightText);
        end
        else
        begin
            BgColor := clHighlight;
            FgColor := clHighlightText;
        end;
    end
    else
    begin
        if TStyleManager.IsCustomStyleActive then
        begin
            BgColor := TStyleManager.ActiveStyle.GetStyleColor(scListView);
            FgColor := TStyleManager.ActiveStyle.GetSystemColor(clWindowText);
        end
        else
        begin
            BgColor := clWindow;
            FgColor := clWindowText;
        end;
    end;

    Sender.Canvas.Brush.Color := BgColor;
    Sender.Canvas.Brush.Style := bsSolid;
    Sender.Canvas.FillRect(R);

    // Иконка состояния (тег привязан к сниппету или нет)
    StateImages := TListView(Sender).StateImages;
    if (Item.StateIndex >= 0) and (StateImages <> nil) then
    begin
        StateImages.Draw(Sender.Canvas, R.Left + 2,
            R.Top + (R.Height - StateImages.Height) div 2, Item.StateIndex);
        Inc(R.Left, StateImages.Width + 4);
    end
    else
        Inc(R.Left, 4);

    Sender.Canvas.Brush.Style := bsClear;
    Sender.Canvas.Font := TListView(Sender).Font;
    Sender.Canvas.Font.Color := FgColor;
    DrawText(Sender.Canvas.Handle, PChar(Item.Caption), Length(Item.Caption), R,
        DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX);
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
    // Тело (тест локального ИИ) удалено как мёртвый код
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
    // OnResize статус-бара стреляет ДО ресайза pCenter (alClient выравнивается
    // после него), ширина списка здесь еще старая - только перестраиваем панели
    FStatus.Layout;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
    // Растяжка перед замерами сама форсирует пересчет скроллбаров lvSnippets,
    // поэтому не зависит от того, завершен ли реалайн детей и успела ли
    // появиться вертикальная полоса прокрутки
    StretchSnippetTitleColumn;
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

