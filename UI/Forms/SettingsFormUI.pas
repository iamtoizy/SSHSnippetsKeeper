unit SettingsFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    Core.Interfaces.Services,
    Core.Interfaces.Settings,
    Core.Interfaces.UI,
    System.Classes,
    System.Generics.Collections,
    System.SysUtils,
    System.Variants,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.Dialogs,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.Graphics,
    Vcl.Mask,
    Vcl.Samples.Spin,
    Vcl.StdCtrls,
    EditEx,
    Winapi.Messages,
    Winapi.Windows
    ;

type
    THotkeyViewData = class
        ActionID: string;
    end;

    TSettingsForm = class(TBaseForm)
        pcSettings: TPageControl;
        tsHotkeys: TTabSheet;
        pBottom: TPanel;
        bSave: TButton;
        bCancel: TButton;
        gbGlobalHotkeys: TGroupBox;
        hkQuickSearch: THotKey;
        chkEnableQuickSearch: TCheckBox;
        hkPassGen: THotKey;
        chkEnablePassGen: TCheckBox;
        hkRepeatLast: THotKey;
        chkEnableRepeatLast: TCheckBox;
        hkFavSlots: THotKey;
        chkEnableFavSlots: TCheckBox;
        gbAppHotkeys: TGroupBox;
        ebSearchHotkeys: TEdit;
        lvHotkeys: TListView;
        pEditor: TPanel;
        hkEditor: THotKey;
        bApplyShortcut: TButton;
        bResetShortcut: TButton;
        bResetAll: TButton;
        lbAction: TLabel;
        ebAction: TEdit;
        lbActionID: TLabel;
        ebActionID: TEdit;
        tsLocalSync: TTabSheet;
        ledMarkdownPath: TLabeledEdit;
        bSelectVaultPath: TButton;
        cbSyncOnStart: TCheckBox;
        cbSyncOnExit: TCheckBox;
        cbAutoExport: TCheckBox;
        lbAutoExportInterval: TLabel;
        cbAutoExportInterval: TComboBox;
        cbTagsMatchAll: TCheckBox;
        cbSecurityStrict: TCheckBox;
        tsSecurity: TTabSheet;
        gbSecurityScan: TGroupBox;
        cbSecurityBackground: TCheckBox;
        lbSecurityInterval: TLabel;
        cbSecurityInterval: TComboBox;
        lbVCLStyle: TLabel;
        cbVCLStyle: TComboBox;
        gbSnippetColumns: TGroupBox;
        cbColLanguage: TCheckBox;
        cbColLastRun: TCheckBox;
        cbColUpdated: TCheckBox;
        gbBackup: TGroupBox;
        lbBackupInterval: TLabel;
        lbBackupKeep: TLabel;
        lbBackupLast: TLabel;
        chkBackupEnabled: TCheckBox;
        cbBackupInterval: TComboBox;
        seBackupKeep: TSpinEdit;
        bBackupCreateNow: TButton;
        gbDbSecurity: TGroupBox;
        chkDbEncrypt: TCheckBox;
        lbDbMode: TLabel;
        cbDbMode: TComboBox;
        bDbApply: TButton;
        bDbExport: TButton;
        bDbImport: TButton;
        cbDbSaveKey: TComboBox;
        bDbHelp: TButton;
        lbDbState: TLabel;
        tsApplications: TTabSheet;
        lvApplications: TListView;
        pApplicationsButtons: TPanel;
        bAppAdd: TButton;
        bAppRename: TButton;
        bAppDelete: TButton;
        bAppPick: TButton;
        bAppProfile: TButton;
        tsCounters: TTabSheet;
        lvCounters: TListView;
        pCountersButtons: TPanel;
        bCounterReset: TButton;
        bCounterResetAll: TButton;

        procedure bSaveClick(Sender: TObject);
        procedure bCancelClick(Sender: TObject);
        procedure lvHotkeysSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure bApplyShortcutClick(Sender: TObject);
        procedure bResetShortcutClick(Sender: TObject);
        procedure bResetAllClick(Sender: TObject);
        procedure bSelectVaultPathClick(Sender: TObject);
        procedure ebSearchHotkeysChange(Sender: TObject);
        procedure FormShow(Sender: TObject);
        procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
        procedure lvHotkeysDeletion(Sender: TObject; Item: TListItem);
        procedure lvHotkeysCompare(Sender: TObject; Item1, Item2: TListItem; Data: Integer; var Compare: Integer);
        procedure bAppAddClick(Sender: TObject);
        procedure bAppRenameClick(Sender: TObject);
        procedure bAppDeleteClick(Sender: TObject);
        procedure bAppPickClick(Sender: TObject);
        procedure bAppProfileClick(Sender: TObject);
        procedure lvApplicationsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure lvApplicationsDblClick(Sender: TObject);
        procedure cbVCLStyleChange(Sender: TObject);
        procedure lvCountersSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure bCounterResetClick(Sender: TObject);
        procedure bCounterResetAllClick(Sender: TObject);
        procedure bBackupCreateNowClick(Sender: TObject);
        procedure bCompletionManagerClick(Sender: TObject);
        procedure bDbApplyClick(Sender: TObject);
        procedure bDbExportClick(Sender: TObject);
        procedure bDbImportClick(Sender: TObject);
        procedure cbDbSaveKeySelect(Sender: TObject);
        procedure bDbHelpClick(Sender: TObject);
        procedure chkDbEncryptClick(Sender: TObject);
        procedure cbDbModeSelect(Sender: TObject);
        procedure bDbProfilesClick(Sender: TObject);
    private
        FLocalActions: TDictionary<string, TActionHotkeyInfo>;
        FHotkeyData: TObjectList<THotkeyViewData>;
        FAppProfiles: TDictionary<string, TAllowedApplicationsItem>;
        FSnapshottedUI: string;
        FFirstShowDone: Boolean;
        FStyleSavedPage: TTabSheet;
        FStyleSavedFocus: TWinControl;
        FSavedQuickSearch: THotkeyConfig;
        FSavedPasswordGen: THotkeyConfig;
        FSavedRepeatLast: THotkeyConfig;
        FSavedFavoriteSlots: THotkeyConfig;
        FBackupBusy: Boolean;
        FDbBusy: Boolean;
        FPendingRememberKey: Boolean;
        procedure LoadSettingsToUI;
        procedure PopulateHotkeysList(const FilterText: string = '');
        procedure PopulateApplicationsList;
        procedure PopulateCountersList;
        procedure FillBackupIntervalCombo;
        procedure FillDbModeCombo;
        procedure LoadDbSecurityToUI;
        procedure UpdateDbStateLabel;
        procedure FillDbSaveKeyCombo;
        procedure UpdateDbSaveKeyCombo;
        function DbCurrentKeyMaterial: string;
        procedure OfferDbKeyExport(const AKey: string);
        procedure ExportDbKeyToFile(const AKey: string);
        function PromptDbPassphrase(const APromptMsg: string): string;
        procedure FillSecurityIntervalCombo;
        procedure UpdateBackupLastCopyLabel;
        function IntervalToIndex(ASeconds: Integer): Integer;
        function IndexToInterval(AIndex: Integer): Integer;
        function ScanIntervalToIndex(AMinutes: Integer): Integer;
        function IndexToScanInterval(AIndex: Integer): Integer;
        procedure FillAutoExportIntervalCombo;
        function AutoExportIntervalToIndex(AMinutes: Integer): Integer;
        function IndexToAutoExportInterval(AIndex: Integer): Integer;
        function TryNormalizeAppName(var AName: string; const AIgnoreExisting: string): Boolean;
        function GetAppProfile(const AExeName: string): TAllowedApplicationsItem;
        procedure UpdateProfileButtonState;
        function BuildUISnapshot: string;
        procedure CaptureSnapshot;
        function IsUIChanged: Boolean;
        function ResolveHotkey(HotKeyCtrl: THotKey; Enabled: Boolean; const Saved: THotkeyConfig): THotkeyConfig;
    protected
        procedure DoInitialize; override;
        procedure DoStyleRecreated; override;
    public
        constructor Create(AOwner: TComponent); override;
        destructor Destroy; override;
    end;

implementation

{$R *.dfm}

uses
    AppEnumerator,
    AppPickerFormUI,
    CompletionManagerFormUI,
    Common.Helpers,
    HotkeyService,
    InputFormUI,
    DbConvertProgressUI,
    DbProfilesFormUI,
    PassphraseFormUI,
    MacroCounters,
    MacroInputTypes,
    System.IOUtils,
    Common.Localization,
    Data.Database.Migrations,
    Data.Database.Security,
    SynThemeAdapter,
    Vcl.FileCtrl,
    Vcl.Menus,
    Common.VCLStyleService,
    Common.DbCrypto,
    Common.Settings,
    Data.Database,
    ProcessProfile,
    WindowMonitor,
    WindowProfileDialogUI,
    System.NetEncoding
    ;

constructor TSettingsForm.Create(AOwner: TComponent);
begin
    inherited Create(AOwner);
    FLocalActions := TDictionary<string, TActionHotkeyInfo>.Create;
    FHotkeyData := TObjectList<THotkeyViewData>.Create;
    FAppProfiles := TDictionary<string, TAllowedApplicationsItem>.Create;
end;

destructor TSettingsForm.Destroy;
begin
    FHotkeyData.Free;
    FLocalActions.Free;
    FAppProfiles.Free;
    inherited Destroy;
end;

procedure TSettingsForm.DoInitialize;
begin
    hkEditor.HotKey := 0;
    pEditor.Enabled := False;
    LoadSettingsToUI;
    PopulateCountersList;
end;

procedure TSettingsForm.LoadSettingsToUI;
var
    Setts: TAppSettings;
    Actions: TArray<TActionHotkeyInfo>;
    Info: TActionHotkeyInfo;
    I: Integer;
begin
    Setts := AppContext.SettingsManager.Data;

    Win32HotkeyToVCL(Setts.Hotkeys.QuickSearch, hkQuickSearch);
    chkEnableQuickSearch.Checked := Setts.Hotkeys.QuickSearch.Enabled;
    FSavedQuickSearch := Setts.Hotkeys.QuickSearch;

    Win32HotkeyToVCL(Setts.Hotkeys.PasswordGen, hkPassGen);
    chkEnablePassGen.Checked := Setts.Hotkeys.PasswordGen.Enabled;
    FSavedPasswordGen := Setts.Hotkeys.PasswordGen;

    Win32HotkeyToVCL(Setts.Hotkeys.RepeatLast, hkRepeatLast);
    chkEnableRepeatLast.Checked := Setts.Hotkeys.RepeatLast.Enabled;
    FSavedRepeatLast := Setts.Hotkeys.RepeatLast;

    Win32HotkeyToVCL(Setts.Hotkeys.FavoriteSlots, hkFavSlots);
    chkEnableFavSlots.Checked := Setts.Hotkeys.FavoriteSlots.Enabled;
    FSavedFavoriteSlots := Setts.Hotkeys.FavoriteSlots;

    // --- Блок синхронизации Markdown ---
    if Setts.SyncDirectory.IsEmpty then
        // По умолчанию: папка 'SnippetsVault' рядом с EXE программы
        ledMarkdownPath.Text := TPath.Combine(ExtractFilePath(ParamStr(0)), 'SnippetsVault')
    else
        ledMarkdownPath.Text := Setts.SyncDirectory;

    cbSyncOnStart.Checked := Setts.SyncOnStart;
    cbSyncOnExit.Checked := Setts.SyncOnExit;

    // --- Периодический экспорт в Vault ---
    FillAutoExportIntervalCombo;
    cbAutoExport.Checked := Setts.AutoExportEnabled;
    cbAutoExportInterval.ItemIndex := AutoExportIntervalToIndex(Setts.AutoExportIntervalMinutes);
    // --------------------------------------

    cbTagsMatchAll.Checked := Setts.TagsMatchAll;
    cbSecurityStrict.Checked := Setts.SecurityScanStrict;

    // Видимость колонок списка сниппетов (битовая маска)
    cbColLanguage.Checked := (Setts.UISettings.SnippetListColumns and 1) <> 0;
    cbColLastRun.Checked := (Setts.UISettings.SnippetListColumns and 2) <> 0;
    cbColUpdated.Checked := (Setts.UISettings.SnippetListColumns and 4) <> 0;

    // --- Резервное копирование БД ---
    FillBackupIntervalCombo;
    chkBackupEnabled.Checked := Setts.Backup.Enabled;
    cbBackupInterval.ItemIndex := IntervalToIndex(Setts.Backup.IntervalSeconds);
    seBackupKeep.Value := Setts.Backup.Keep;
    UpdateBackupLastCopyLabel;
    // --------------------------------

    // --- Шифрование БД ---
    LoadDbSecurityToUI;
    // ---------------------

    // --- Проверка секретов ---
    FillSecurityIntervalCombo;
    cbSecurityBackground.Checked := Setts.SecurityBackgroundScanEnabled;
    cbSecurityInterval.ItemIndex := ScanIntervalToIndex(Setts.SecurityBackgroundScanIntervalMinutes);
    // -------------------------

    TVCLStyleService.FillStyleList(cbVCLStyle.Items);
    cbVCLStyle.ItemIndex := cbVCLStyle.Items.IndexOf(Setts.UISettings.VCLStyle);
    if cbVCLStyle.ItemIndex < 0 then
        cbVCLStyle.ItemIndex := 0;

    PopulateApplicationsList;

    FLocalActions.Clear;
    Actions := AppContext.HotkeyService.GetAllActions;
    for Info in Actions do
        FLocalActions.Add(Info.ActionName, Info);

    PopulateHotkeysList;

    for I := 0 to lvHotkeys.Columns.Count - 1 do
        lvHotkeys.Columns[I].Width := -2;

    for I := 0 to lvApplications.Columns.Count - 1 do
        lvApplications.Columns[I].Width := -2;
end;

procedure TSettingsForm.PopulateHotkeysList(const FilterText: string = '');
var
    Info: TActionHotkeyInfo;
    Item: TListItem;
    CatText, NameText, SearchQuery: string;
    ViewData: THotkeyViewData;
begin
    SearchQuery := FilterText.Trim.ToLower;

    lvHotkeys.Items.BeginUpdate;
    try
        lvHotkeys.Items.Clear;
        FHotkeyData.Clear;

        for Info in FLocalActions.Values do
        begin
            CatText := TUIStateLoader.GetMessage(Info.Category);
            NameText := TUIStateLoader.GetMessage(Info.DisplayName);

            if (SearchQuery <> '') then
            begin
                if (not CatText.ToLower.Contains(SearchQuery)) and (not NameText.ToLower.Contains(SearchQuery)) then
                    Continue;
            end;

            Item := lvHotkeys.Items.Add;
            Item.Caption := CatText;
            Item.SubItems.Add(NameText);
            Item.SubItems.Add(Vcl.Menus.ShortCutToText(Info.CurrentShortCut));

            ViewData := THotkeyViewData.Create;
            ViewData.ActionID := Info.ActionName;
            FHotkeyData.Add(ViewData);
            Item.Data := ViewData;
        end;

        lvHotkeys.AlphaSort;
    finally
        lvHotkeys.Items.EndUpdate;
    end;
end;

procedure TSettingsForm.lvHotkeysCompare(Sender: TObject; Item1, Item2: TListItem; Data: Integer; var Compare: Integer);
begin
    Compare := CompareText(Item1.Caption, Item2.Caption);
    if Compare = 0 then
        Compare := CompareText(Item1.SubItems[0], Item2.SubItems[0]);
end;

procedure TSettingsForm.lvHotkeysDeletion(Sender: TObject; Item: TListItem);
begin
    Item.Data := nil;
end;

procedure TSettingsForm.ebSearchHotkeysChange(Sender: TObject);
begin
    if csRecreating in ebSearchHotkeys.ControlState then
        Exit;
    PopulateHotkeysList(ebSearchHotkeys.Text);
end;

procedure TSettingsForm.lvHotkeysSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
var
    ActionID: string;
begin
    if not Selected then
    begin
        pEditor.Enabled := False;
        Exit;
    end;

    ActionID := THotkeyViewData(Item.Data).ActionID;

    ebActionID.Text := ActionID;
    ebAction.Text := Item.SubItems[0];

    hkEditor.HotKey := FLocalActions[ActionID].CurrentShortCut;
    pEditor.Enabled := True;
end;

procedure TSettingsForm.bApplyShortcutClick(Sender: TObject);
var
    ActionID, ConflictName: string;
    Item: TListItem;
    Info: TActionHotkeyInfo;
begin
    Item := lvHotkeys.Selected;
    if Item = nil then
        Exit;

    ActionID := THotkeyViewData(Item.Data).ActionID;

    if THotkeyService.ShortCutInUseIn(ActionID, hkEditor.HotKey, FLocalActions.Values.ToArray, ConflictName) then
    begin
        if ConflictName <> FLocalActions[ActionID].DisplayName then
        begin
            MessagesHandler.ShowWarning(
                TUIStateLoader.GetMessage('Common.HotkeyConflict', [ConflictName])
            );
            Exit;
        end;
    end;

    Info := FLocalActions[ActionID];
    Info.CurrentShortCut := hkEditor.HotKey;
    FLocalActions[ActionID] := Info;

    Item.SubItems[1] := Vcl.Menus.ShortCutToText(hkEditor.HotKey);
    lvHotkeys.Columns[2].Width := -2; // Растягиваем колонку
end;

procedure TSettingsForm.bResetShortcutClick(Sender: TObject);
var
    ActionID: string;
begin
    if lvHotkeys.Selected = nil then
        Exit;
    ActionID := THotkeyViewData(lvHotkeys.Selected.Data).ActionID;

    hkEditor.HotKey := FLocalActions[ActionID].DefaultShortCut;
    bApplyShortcutClick(nil);
end;

procedure TSettingsForm.bResetAllClick(Sender: TObject);
var
    Key: string;
    Info: TActionHotkeyInfo;
begin
    if not MessagesHandler.AskConfirmation(
        TUIStateLoader.GetMessage('Settings.ResetAllHotkeysConfirm'),
        TUIStateLoader.GetMessage('Common.Confirmation')
    ) then Exit;

    for Key in FLocalActions.Keys do
    begin
        Info := FLocalActions[Key];
        Info.CurrentShortCut := Info.DefaultShortCut;
        FLocalActions[Key] := Info;
    end;

    PopulateHotkeysList(ebSearchHotkeys.Text);

    if lvHotkeys.Selected <> nil then
        lvHotkeysSelectItem(Self, lvHotkeys.Selected, True);
end;

procedure TSettingsForm.PopulateCountersList;
var
    Entries: TArray<TCounterEntry>;
    Entry: TCounterEntry;
    Item: TListItem;
begin
    lvCounters.Items.BeginUpdate;
    try
        lvCounters.Items.Clear;
        Entries := Counters.Snapshot;
        for Entry in Entries do
        begin
            Item := lvCounters.Items.Add;
            Item.Caption := IntToStr(Entry.SnippetID);
            Item.SubItems.Add(IntToStr(Entry.Current));
        end;
    finally
        lvCounters.Items.EndUpdate;
    end;
    bCounterReset.Enabled := lvCounters.Selected <> nil;
    bCounterResetAll.Enabled := lvCounters.Items.Count > 0;
end;

procedure TSettingsForm.lvCountersSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
    bCounterReset.Enabled := Selected;
end;

procedure TSettingsForm.bCounterResetClick(Sender: TObject);
var
    ID: Integer;
begin
    if lvCounters.Selected = nil then
        Exit;
    ID := StrToIntDef(lvCounters.Selected.Caption, 0);

    if not MessagesHandler.AskConfirmation(
        TUIStateLoader.GetMessage('Settings.CountersResetConfirm', [lvCounters.Selected.Caption]),
        TUIStateLoader.GetMessage('Common.Confirmation')
    ) then Exit;

    Counters.Reset(ID);
    PopulateCountersList;
end;

procedure TSettingsForm.bCounterResetAllClick(Sender: TObject);
begin
    if not MessagesHandler.AskConfirmation(
        TUIStateLoader.GetMessage('Settings.CountersResetAllConfirm'),
        TUIStateLoader.GetMessage('Common.Confirmation')
    ) then Exit;

    Counters.ResetAll;
    PopulateCountersList;
end;

// =============================================================================
// РЕЗЕРВНОЕ КОПИРОВАНИЕ БД
// =============================================================================

const
    // Пункты комбобокса интервалов: значения в секундах и суффиксы ключей
    // локализации Settings.BackupInterval<суффикс>
    BACKUP_INTERVAL_SECONDS: array [0..5] of Integer =
        (3600, 21600, 43200, 86400, 259200, 604800);
    BACKUP_INTERVAL_KEYS: array [0..5] of string =
        ('1h', '6h', '12h', '24h', '3d', '7d');

procedure TSettingsForm.FillBackupIntervalCombo;
var
    I: Integer;
begin
    cbBackupInterval.Items.BeginUpdate;
    try
        cbBackupInterval.Items.Clear;
        for I := Low(BACKUP_INTERVAL_SECONDS) to High(BACKUP_INTERVAL_SECONDS) do
            cbBackupInterval.Items.Add(TUIStateLoader.GetMessage(
                'Settings.BackupInterval' + BACKUP_INTERVAL_KEYS[I]));
    finally
        cbBackupInterval.Items.EndUpdate;
    end;
end;

function TSettingsForm.IntervalToIndex(ASeconds: Integer): Integer;
var
    I: Integer;
begin
    Result := 3; // Неизвестное значение - дефолт (сутки)
    for I := Low(BACKUP_INTERVAL_SECONDS) to High(BACKUP_INTERVAL_SECONDS) do
        if BACKUP_INTERVAL_SECONDS[I] = ASeconds then
            Exit(I);
end;

function TSettingsForm.IndexToInterval(AIndex: Integer): Integer;
begin
    if (AIndex < Low(BACKUP_INTERVAL_SECONDS)) or
        (AIndex > High(BACKUP_INTERVAL_SECONDS)) then
        Result := 86400
    else
        Result := BACKUP_INTERVAL_SECONDS[AIndex];
end;

const
    // Пункты комбобокса периодики фоновой проверки: значения в минутах
    // и суффиксы ключей локализации Settings.ScanInterval<суффикс>
    SECURITY_SCAN_INTERVAL_MINUTES: array [0..5] of Integer =
        (10, 30, 60, 180, 720, 1440);
    SECURITY_SCAN_INTERVAL_KEYS: array [0..5] of string =
        ('10m', '30m', '1h', '3h', '12h', '24h');

procedure TSettingsForm.FillSecurityIntervalCombo;
var
    I: Integer;
begin
    cbSecurityInterval.Items.BeginUpdate;
    try
        cbSecurityInterval.Items.Clear;
        for I := Low(SECURITY_SCAN_INTERVAL_MINUTES) to High(SECURITY_SCAN_INTERVAL_MINUTES) do
            cbSecurityInterval.Items.Add(TUIStateLoader.GetMessage(
                'Settings.ScanInterval' + SECURITY_SCAN_INTERVAL_KEYS[I]));
    finally
        cbSecurityInterval.Items.EndUpdate;
    end;
end;

function TSettingsForm.ScanIntervalToIndex(AMinutes: Integer): Integer;
var
    I: Integer;
begin
    Result := 1; // Неизвестное значение - дефолт (30 минут)
    for I := Low(SECURITY_SCAN_INTERVAL_MINUTES) to High(SECURITY_SCAN_INTERVAL_MINUTES) do
        if SECURITY_SCAN_INTERVAL_MINUTES[I] = AMinutes then
            Exit(I);
end;

function TSettingsForm.IndexToScanInterval(AIndex: Integer): Integer;
begin
    if (AIndex < Low(SECURITY_SCAN_INTERVAL_MINUTES)) or
        (AIndex > High(SECURITY_SCAN_INTERVAL_MINUTES)) then
        Result := 30
    else
        Result := SECURITY_SCAN_INTERVAL_MINUTES[AIndex];
end;

const
    // Пункты комбобокса периодики экспорта в Vault: значения в минутах
    // и суффиксы ключей локализации Settings.AutoExportInterval<суффикс>
    AUTOEXPORT_INTERVAL_MINUTES: array [0..5] of Integer =
        (1, 2, 5, 10, 15, 30);
    AUTOEXPORT_INTERVAL_KEYS: array [0..5] of string =
        ('1m', '2m', '5m', '10m', '15m', '30m');

procedure TSettingsForm.FillAutoExportIntervalCombo;
var
    I: Integer;
begin
    cbAutoExportInterval.Items.BeginUpdate;
    try
        cbAutoExportInterval.Items.Clear;
        for I := Low(AUTOEXPORT_INTERVAL_MINUTES) to High(AUTOEXPORT_INTERVAL_MINUTES) do
            cbAutoExportInterval.Items.Add(TUIStateLoader.GetMessage(
                'Settings.AutoExportInterval' + AUTOEXPORT_INTERVAL_KEYS[I]));
    finally
        cbAutoExportInterval.Items.EndUpdate;
    end;
end;

function TSettingsForm.AutoExportIntervalToIndex(AMinutes: Integer): Integer;
var
    I: Integer;
begin
    Result := 2; // Неизвестное значение - дефолт (5 минут)
    for I := Low(AUTOEXPORT_INTERVAL_MINUTES) to High(AUTOEXPORT_INTERVAL_MINUTES) do
        if AUTOEXPORT_INTERVAL_MINUTES[I] = AMinutes then
            Exit(I);
end;

function TSettingsForm.IndexToAutoExportInterval(AIndex: Integer): Integer;
begin
    if (AIndex < Low(AUTOEXPORT_INTERVAL_MINUTES)) or
        (AIndex > High(AUTOEXPORT_INTERVAL_MINUTES)) then
        Result := 5
    else
        Result := AUTOEXPORT_INTERVAL_MINUTES[AIndex];
end;

procedure TSettingsForm.UpdateBackupLastCopyLabel;
var
    DbFile, Latest: string;
    Stamp: TDateTime;
begin
    DbFile := AppContext.DatabaseManager.DatabaseFile;
    Latest := Data.Database.Migrations.FindLatestAutoBackup(DbFile, Stamp);

    if Latest = '' then
        lbBackupLast.Caption := TUIStateLoader.GetMessage('Settings.BackupLastCopyNone')
    else
        lbBackupLast.Caption := TUIStateLoader.GetMessage('Settings.BackupLastCopy',
            [FormatDateTime('dd.mm.yyyy hh:nn', Stamp)]);
end;

// «Создать копию сейчас»: интервал игнорируется (AForce), ротация
// применяется; значения берутся прямо с формы, сохранение не обязательно.
// Копирование в фоновом потоке на отдельном соединении - UI не виснет
procedure TSettingsForm.bBackupCreateNowClick(Sender: TObject);
var
    DbFile, DbKey: string;
    IntervalSeconds, Keep: Integer;
begin
    if FBackupBusy then
        Exit;

    DbFile := AppContext.DatabaseManager.DatabaseFile;
    if DbFile = '' then
    begin
        MessagesHandler.ShowWarning(
            TUIStateLoader.GetMessage('Settings.BackupNoDatabase'));
        Exit;
    end;

    IntervalSeconds := IndexToInterval(cbBackupInterval.ItemIndex);
    Keep := seBackupKeep.Value;

    // Ключ читается в главном потоке до старта фонового: доступ к настройкам
    // из потока не потокобезопасен. Берём фактический ключ соединения -
    // у passphrase-базы без запоминания его в настройках нет
    DbKey := DbCurrentKeyMaterial;

    // Кнопка и закрытие формы блокируются: Synchronize должен попасть
    // в живую форму
    FBackupBusy := True;
    bBackupCreateNow.Enabled := False;
    bSave.Enabled := False;
    bCancel.Enabled := False;
    lbBackupLast.Caption := TUIStateLoader.GetMessage('Settings.BackupInProgress');

    TThread.CreateAnonymousThread(
        procedure
        var
            BackupFile, ErrorMsg: string;
        begin
            BackupFile := '';
            ErrorMsg := '';
            try
                BackupFile := Data.Database.Migrations.CreateAutoBackupStandalone(
                    DbFile, IntervalSeconds, Keep, True, DbKey);
            except
                on E: Exception do
                    ErrorMsg := E.Message;
            end;

            TThread.Synchronize(nil,
                procedure
                begin
                    FBackupBusy := False;
                    bBackupCreateNow.Enabled := True;
                    bSave.Enabled := True;
                    bCancel.Enabled := True;

                    if ErrorMsg <> '' then
                        MessagesHandler.ShowError(TUIStateLoader.GetMessage(
                            'DB.BackupFailed', [DbFile, ErrorMsg]))
                    else if BackupFile <> '' then
                        ShowSimpleToast(TUIStateLoader.GetMessage(
                            'DB.BackupCreated', [BackupFile]));

                    UpdateBackupLastCopyLabel;
                end);
        end).Start;
end;

// Менеджер автодополнения: единый файл секций bash/bat/powershell.
// Модальный диалог: правки применяются только по явному «Сохранить»
procedure TSettingsForm.bCompletionManagerClick(Sender: TObject);
begin
    TCompletionManagerForm.ExecuteModal(Self, AppContext);
end;

procedure TSettingsForm.FillDbModeCombo;
begin
    cbDbMode.Items.BeginUpdate;
    try
        cbDbMode.Items.Clear;
        cbDbMode.Items.Add(TUIStateLoader.GetMessage('Settings.DbModeDpapi'));
        cbDbMode.Items.Add(TUIStateLoader.GetMessage('Settings.DbModePassphrase'));
    finally
        cbDbMode.Items.EndUpdate;
    end;
end;

procedure TSettingsForm.LoadDbSecurityToUI;
var
    Db: TDbSecuritySettings;
    Profile: TDbSecurityProfile;
begin
    Db := AppContext.SettingsManager.Data.Db;
    FillDbModeCombo;
    FillDbSaveKeyCombo;
    // Подключённая база показывается по факту файла и профилю: заголовок
    // незашифрованного файла важнее глобального флага, а у зашифрованной
    // базы глобальный слот мог остаться от другой базы
    if AppContext.DatabaseManager.IsConnected then
    begin
        chkDbEncrypt.Checked :=
            not DbFileIsPlain(AppContext.DatabaseManager.DatabaseFile);
        if chkDbEncrypt.Checked then
        begin
            Profile := GetDbProfile(AppContext.SettingsManager.Data,
                AppContext.DatabaseManager.DatabaseFile);
            if Profile.KeyMode = DB_KEYMODE_PASSPHRASE then
                cbDbMode.ItemIndex := 1
            else
                cbDbMode.ItemIndex := 0;
        end
        else if Db.KeyMode = DB_KEYMODE_PASSPHRASE then
            cbDbMode.ItemIndex := 1
        else
            cbDbMode.ItemIndex := 0;
    end
    else
    begin
        if Db.KeyMode = DB_KEYMODE_PASSPHRASE then
            cbDbMode.ItemIndex := 1
        else
            cbDbMode.ItemIndex := 0;
        chkDbEncrypt.Checked := DbEncryptionEnabled(Db);
    end;
    cbDbMode.Enabled := chkDbEncrypt.Checked;

    // Без DLL mc-движка шифрование недоступно: блок деактивируем целиком
    if not DbEngineDllAvailable then
    begin
        chkDbEncrypt.Enabled := False;
        cbDbMode.Enabled := False;
        bDbApply.Enabled := False;
        bDbExport.Enabled := False;
        bDbImport.Enabled := False;
        cbDbSaveKey.Enabled := False;
        lbDbState.Caption := TUIStateLoader.GetMessage('Settings.DbEngineMissing');
        Exit;
    end;

    // Применить/импортировать без открытой базы нельзя: обе операции
    // конвертируют файл. Экспорт доступен - работает по ключу из настроек
    if not AppContext.DatabaseManager.IsConnected then
    begin
        bDbApply.Enabled := False;
        bDbImport.Enabled := False;
    end;

    UpdateDbSaveKeyCombo;
    UpdateDbStateLabel;
end;

procedure TSettingsForm.UpdateDbStateLabel;
var
    MsgKey: string;
begin
    // Открытая база - по своему факту и профилю: глобальный флаг мог
    // остаться от другой базы
    if AppContext.DatabaseManager.IsConnected and
        (not DbFileIsPlain(AppContext.DatabaseManager.DatabaseFile)) then
    begin
        if GetDbProfile(AppContext.SettingsManager.Data,
            AppContext.DatabaseManager.DatabaseFile).KeyMode =
            DB_KEYMODE_PASSPHRASE then
            MsgKey := 'Settings.DbStateOnPassphrase'
        else
            MsgKey := 'Settings.DbStateOn';
    end
    else if not DbEncryptionEnabled(AppContext.SettingsManager.Data.Db) then
        MsgKey := 'Settings.DbStateOff'
    else if AppContext.SettingsManager.Data.Db.KeyMode = DB_KEYMODE_PASSPHRASE then
        MsgKey := 'Settings.DbStateOnPassphrase'
    else
        MsgKey := 'Settings.DbStateOn';
    lbDbState.Caption := TUIStateLoader.GetMessage(MsgKey);
end;

// Пункты комбо хранения ключа (заполняется рядом с режимом ключа)
procedure TSettingsForm.FillDbSaveKeyCombo;
begin
    cbDbSaveKey.Items.BeginUpdate;
    try
        cbDbSaveKey.Items.Clear;
        cbDbSaveKey.Items.Add(TUIStateLoader.GetMessage('Settings.DbSaveKeyDontStore'));
        cbDbSaveKey.Items.Add(TUIStateLoader.GetMessage('Settings.DbSaveKeyStore'));
    finally
        cbDbSaveKey.Items.EndUpdate;
    end;
end;

// Комбо отражает выбранный режим passphrase: DPAPI хранит ключ всегда
// (без него базу не открыть), для фразы выбор эквивалентен галке
// запоминания. Если passphrase ещё не применён (файл незашифрован или
// профиль другого режима) - показывается отложенное предпочтение для
// будущего ключа; без открытой базы пункт выключен
procedure TSettingsForm.UpdateDbSaveKeyCombo;
var
    Profile: TDbSecurityProfile;
    PassphraseMode: Boolean;
begin
    if not AppContext.DatabaseManager.IsConnected then
    begin
        cbDbSaveKey.Enabled := False;
        cbDbSaveKey.ItemIndex := -1;
        Exit;
    end;
    PassphraseMode := chkDbEncrypt.Checked and (cbDbMode.ItemIndex = 1);
    if not PassphraseMode then
    begin
        // DPAPI хранит ключ всегда: показать «Сохранять» в отключённом
        // пункте, выбор здесь не участвует
        cbDbSaveKey.Enabled := False;
        cbDbSaveKey.ItemIndex := 1;
        Exit;
    end;
    Profile := GetDbProfile(AppContext.SettingsManager.Data,
        AppContext.DatabaseManager.DatabaseFile);
    cbDbSaveKey.Enabled := True;
    if DbFileIsPlain(AppContext.DatabaseManager.DatabaseFile) or
        (Profile.KeyMode <> DB_KEYMODE_PASSPHRASE) then
        // Режим ещё не применён: показываем отложенный выбор
        cbDbSaveKey.ItemIndex := Ord(FPendingRememberKey)
    else
        cbDbSaveKey.ItemIndex := Ord(Profile.RememberKey and
            (DbStoredKeyMaterial(Profile) <> ''));
end;

procedure TSettingsForm.cbDbSaveKeySelect(Sender: TObject);
var
    DbFile: string;
    Setts: TAppSettings;
    Profile: TDbSecurityProfile;
    CurrentKey: string;
begin
    if FDbBusy or (not DbEngineDllAvailable) then
    begin
        UpdateDbSaveKeyCombo;
        Exit;
    end;

    DbFile := AppContext.DatabaseManager.DatabaseFile;
    if (not AppContext.DatabaseManager.IsConnected) or
        DbFile.IsEmpty or SameText(DbFile, ':memory:') then
    begin
        MessagesHandler.ShowWarning(
            TUIStateLoader.GetMessage('Settings.DbNotOpen'));
        UpdateDbSaveKeyCombo;
        Exit;
    end;
    Setts := AppContext.SettingsManager.Data;
    Profile := GetDbProfile(Setts, DbFile);
    // Режим passphrase ещё не применён (файл незашифрован или профиль
    // другого режима): выбор - отложенное предпочтение, «Применить»
    // возьмёт его при конверсии
    if DbFileIsPlain(DbFile) or
        (Profile.KeyMode <> DB_KEYMODE_PASSPHRASE) then
    begin
        FPendingRememberKey := cbDbSaveKey.ItemIndex = 1;
        Exit;
    end;

    if cbDbSaveKey.ItemIndex = 1 then
    begin
        // «Сохранять»: закрепляем фактический ключ открытой базы
        // в её профиле
        CurrentKey := DbCurrentKeyMaterial;
        if CurrentKey = '' then
        begin
            MessagesHandler.ShowWarning(
                TUIStateLoader.GetMessage('Settings.DbNotOpen'));
            UpdateDbSaveKeyCombo;
            Exit;
        end;
        PinDbKeyTo(Setts, DbFile, CurrentKey, True);
        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;
        UpdateDbSaveKeyCombo;
        UpdateDbStateLabel;
        MessagesHandler.ShowInfo(
            TUIStateLoader.GetMessage('Settings.DbRememberNowDone'));
    end
    else
    begin
        // «Не сохранять»: ключ удаляется из профиля, при следующем
        // открытии база запросит парольную фразу
        Profile.RememberKey := False;
        Profile.Key := '';
        SaveDbProfile(Setts, Profile);
        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;
        UpdateDbSaveKeyCombo;
        UpdateDbStateLabel;
        MessagesHandler.ShowInfo(
            TUIStateLoader.GetMessage('Settings.DbSaveKeyOff'));
    end;
end;

// Справка по шифрованию: принципы DPAPI и парольной фразы, хранение
// ключа и нюансы работы с несколькими базами
procedure TSettingsForm.bDbHelpClick(Sender: TObject);
begin
    MessagesHandler.ShowInfo(
        TUIStateLoader.GetMessage('Settings.DbHelp'));
end;

procedure TSettingsForm.chkDbEncryptClick(Sender: TObject);
begin
    cbDbMode.Enabled := chkDbEncrypt.Checked;
    // Вход в ещё не применённый passphrase-режим: стартовое предпочтение
    // для будущего ключа - хранить (как это делает DPAPI)
    if chkDbEncrypt.Checked and (cbDbMode.ItemIndex = 1) then
        FPendingRememberKey := True;
    UpdateDbSaveKeyCombo;
end;

procedure TSettingsForm.cbDbModeSelect(Sender: TObject);
begin
    if chkDbEncrypt.Checked and (cbDbMode.ItemIndex = 1) then
        FPendingRememberKey := True;
    UpdateDbSaveKeyCombo;
end;

function TSettingsForm.DbCurrentKeyMaterial: string;
var
    DbApp: TAppDatabase;
begin
    Result := '';
    if AppContext.DatabaseManager.IsConnected then
    begin
        DbApp := AppContext.DatabaseManager as TAppDatabase;
        // Незашифрованный файл ключа не имеет, даже если настройки
        // говорят об обратном: устаревший ключ другой базы не подставляем
        if not DbFileIsPlain(AppContext.DatabaseManager.DatabaseFile) then
            Result := DbApp.EncryptionKey;
        if Result <> '' then
            Exit;
    end;
    // Профиль открытой базы первичен: глобальный слот - наследие
    // старых установок, где он мог остаться от другой базы
    if AppContext.DatabaseManager.IsConnected then
    begin
        Result := DbStoredKeyMaterial(GetDbProfile(
            AppContext.SettingsManager.Data,
            AppContext.DatabaseManager.DatabaseFile));
        if Result <> '' then
            Exit;
    end;
    Result := DbKeyMaterial(AppContext.SettingsManager.Data.Db);
end;

function TSettingsForm.PromptDbPassphrase(const APromptMsg: string): string;
var
    Value: string;
begin
    Result := '';
    Value := '';
    if ShowInputForm(TUIStateLoader.GetMessage(APromptMsg), '',
        mitPassword, AppContext, Value) then
        Result := Value;
end;

// Применение шифрования к открытой БД немедленно (не через bSave):
// конверсия файла требует закрытых соединений и не может ждать
// сохранения формы. Порядок: подтверждение -> автобэкап -> закрытие БД
// -> PRAGMA rekey -> настройки -> переоткрытие с новым ключом
procedure TSettingsForm.bDbApplyClick(Sender: TObject);
var
    DbFile, BackupFile: string;
    Setts: TAppSettings;
    PrevDb: TDbSecuritySettings;
    Profile: TDbSecurityProfile;
    OldKey, NewKey, ReopenKey, ErrMsg, SelMode, SaltB64: string;
    RawKey, Salt: TBytes;
    Pass1: string;
    TurningOn, Success, Confirmed, RememberAns, Plain, ModeChange: Boolean;
    DbApp: TAppDatabase;
begin
    if FDbBusy or (not DbEngineDllAvailable) then
        Exit;

    DbFile := AppContext.DatabaseManager.DatabaseFile;
    if (not AppContext.DatabaseManager.IsConnected) or
        DbFile.IsEmpty or SameText(DbFile, ':memory:') then
    begin
        MessagesHandler.ShowWarning(
            TUIStateLoader.GetMessage('Settings.DbNotOpen'));
        Exit;
    end;

    Setts := AppContext.SettingsManager.Data;
    TurningOn := chkDbEncrypt.Checked;
    SelMode := DB_KEYMODE_DPAPI;
    if cbDbMode.ItemIndex = 1 then
        SelMode := DB_KEYMODE_PASSPHRASE;
    // Требуемое состояние сверяем с фактическим файлом, а не с флагом
    // настроек: флаг един на приложение и мог остаться от другой базы.
    Plain := DbFileIsPlain(DbFile);
    // Смена типа ключа на зашифрованном файле - полноценная конверсия
    // по общему пути ниже; при совпадении режимов - только подводим
    // флаг настроек к реальности
    ModeChange := TurningOn and (not Plain) and
        (Setts.Db.KeyMode <> SelMode);
    if (TurningOn = (not Plain)) and (not ModeChange) then
    begin
        if TurningOn then
        begin
            Setts.Db.DbDefined := True;
            Setts.Db.Encryption := DB_ENCRYPTION_AES256;
        end
        else
            Setts.Db.Encryption := DB_ENCRYPTION_NONE;
        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;
        UpdateDbStateLabel;
        Exit;
    end;

    if ModeChange then
        Confirmed := MessagesHandler.AskWarning(
            TUIStateLoader.GetMessage('Settings.DbApplyConfirmMode'),
            TUIStateLoader.GetMessage('Common.Warning'))
    else if TurningOn then
        Confirmed := MessagesHandler.AskWarning(
            TUIStateLoader.GetMessage('Settings.DbApplyConfirmOn'),
            TUIStateLoader.GetMessage('Common.Warning'))
    else
        Confirmed := MessagesHandler.AskWarning(
            TUIStateLoader.GetMessage('Settings.DbApplyConfirmOff'),
            TUIStateLoader.GetMessage('Common.Warning'));
    if not Confirmed then
        Exit;

    // Фактический ключ открытого файла: в passphrase-режиме без
    // RememberKey его нет в настройках, берём из открытого соединения
    OldKey := DbCurrentKeyMaterial;
    NewKey := '';
    SaltB64 := '';
    RememberAns := True;
    if TurningOn then
    begin
        if SelMode = DB_KEYMODE_PASSPHRASE then
        begin
            Pass1 := '';
            if not ShowPasswordConfirmForm(
                TUIStateLoader.GetMessage('Settings.DbPassphrasePrompt'),
                TUIStateLoader.GetMessage('Settings.DbPassphraseConfirm'),
                TUIStateLoader.GetMessage('Settings.DbPassphraseMismatch'),
                AppContext, Pass1) then
                Exit;
            RememberAns := cbDbSaveKey.ItemIndex = 1;
            Salt := DbGenerateSalt;
            RawKey := DbDeriveKey(Pass1, Salt, DB_PBKDF2_ITERATIONS);
            try
                NewKey := TNetEncoding.Base64.EncodeBytesToString(RawKey);
            finally
                WipeSecretBytes(RawKey);
            end;
            SaltB64 := TNetEncoding.Base64.EncodeBytesToString(Salt);
        end
        else
        begin
            // Ключ мог быть создан ранее (включение после выключения не
            // затирает ключ) - переиспользуем, иначе генерируем новый;
            // профиль базы первичен, глобальный слот - наследие
            NewKey := DbStoredKeyMaterial(GetDbProfile(Setts, DbFile));
            if NewKey = '' then
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
        end;
    end;

    // Тип ключа меняется без смены материала (запомненная фраза ->
    // DPAPI): файл уже зашифрован этим ключом, конверсия не нужна -
    // достаточно перевести настройки на DPAPI-хранение
    if ModeChange and (SelMode = DB_KEYMODE_DPAPI) and
        (NewKey <> '') and (NewKey = OldKey) then
    begin
        Setts.Db.DbDefined := True;
        Setts.Db.KeyMode := DB_KEYMODE_DPAPI;
        Setts.Db.Salt := '';
        Setts.Db.RememberKey := True;
        Setts.Db.Key := NewKey;
        // Профиль открытой базы переводим на DPAPI-хранение тем же
        // ключом: материал ключа не меняется, конверсия не нужна
        Profile := GetDbProfile(Setts, DbFile);
        Profile.KeyMode := DB_KEYMODE_DPAPI;
        Profile.Salt := '';
        Profile.RememberKey := True;
        Profile.Key := NewKey;
        SaveDbProfile(Setts, Profile);
        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;
        chkDbEncrypt.Checked := True;
        UpdateDbStateLabel;
        UpdateDbSaveKeyCombo;
        MessagesHandler.ShowInfo(
            TUIStateLoader.GetMessage('Settings.DbModeChanged'));
        Exit;
    end;

    PrevDb := Setts.Db;

    FDbBusy := True;
    chkDbEncrypt.Enabled := False;
    cbDbMode.Enabled := False;
    bDbApply.Enabled := False;
    bDbExport.Enabled := False;
    bDbImport.Enabled := False;
    cbDbSaveKey.Enabled := False;
    bSave.Enabled := False;
    bCancel.Enabled := False;
    lbDbState.Caption := TUIStateLoader.GetMessage('Settings.DbApplyInProgress');
    try
        // Резервная копия в текущем состоянии (со старым ключом):
        // CreateAutoBackupStandalone открывает своё короткоживущее
        // соединение и принудительно создаёт копию с ротацией
        BackupFile := CreateAutoBackupStandalone(DbFile,
            Setts.Backup.IntervalSeconds, Setts.Backup.Keep, True,
            OldKey);

        // Файл должен быть свободен: закрываем соединение приложения
        // (фоновый автобэкап короткоживущий и держит файл доли секунды)
        AppContext.DatabaseManager.CloseDatabase;

        Success := ConvertDbWithProgress(
            TUIStateLoader.GetMessage('Settings.DbConversionTitle'),
            TUIStateLoader.GetMessage('Settings.DbConversionInProgress'),
            DbFile, OldKey, NewKey, AppContext, ErrMsg);

        if Success then
        begin
            // В памяти ключ хранится открытым base64, Save пишет под DPAPI.
            // При снятии шифрования ключ сохраняется в настройках: им всё
            // ещё зашифрованы прежние бэкапы auto_*.bak, и повторное
            // включение переиспользует тот же ключ
            Setts.Db.DbDefined := True;
            Setts.Db.KeyMode := DB_KEYMODE_DPAPI;
            Setts.Db.RememberKey := True;
            Setts.Db.Salt := '';
            Setts.Db.Key := PrevDb.Key;
            Setts.Db.Encryption := DB_ENCRYPTION_NONE;
            if TurningOn then
            begin
                Setts.Db.Encryption := DB_ENCRYPTION_AES256;
                Setts.Db.Key := NewKey;
                Setts.Db.KeyMode := SelMode;
                Setts.Db.Salt := SaltB64;
                Setts.Db.RememberKey := RememberAns;
                // Профиль открытой базы получает собственную копию ключа:
                // глобальный слот позже может уйти к другой базе
                Profile := GetDbProfile(Setts, DbFile);
                Profile.KeyMode := SelMode;
                Profile.Salt := SaltB64;
                Profile.RememberKey := RememberAns;
                Profile.Key := NewKey;
                // «Не запоминать» действует и в памяти: иначе переоткрытие
                // в той же сессии возьмёт ключ из профиля без запроса фразы
                if not RememberAns then
                    Profile.Key := '';
                SaveDbProfile(Setts, Profile);
            end
            else
                // Шифрование снято: профиль этой базы больше не нужен
                DeleteDbProfile(Setts, DbFile);
            AppContext.SettingsManager.Data := Setts;
            AppContext.SettingsManager.Save;
            // «Не запоминать» должно действовать и в памяти: иначе
            // переоткрытие в той же сессии возьмёт ключ из настроек
            // и пройдёт без запроса парольной фразы
            ClearUnrememberedDbKey(Setts);
            AppContext.SettingsManager.Data := Setts;
        end;

        // Переоткрытие в фактическом состоянии файла: при сбое конверсии
        // файл остался с прежним ключом
        if Success then
        begin
            if TurningOn then
                ReopenKey := NewKey
            else
                ReopenKey := '';
        end
        else
            ReopenKey := OldKey;

        try
            DbApp := AppContext.DatabaseManager as TAppDatabase;
            DbApp.EncryptionKey := ReopenKey;
            AppContext.DatabaseManager.OpenDatabase(DbFile);
        except
            on E: Exception do
                MessagesHandler.ShowError(TUIStateLoader.GetMessage(
                    'DB.OpenError', [E.Message]));
        end;

        if Success then
        begin
            if TurningOn then
            begin
                lbDbState.Caption := TUIStateLoader.GetMessage('Settings.DbApplyDoneOn');
                // Копия снята до конверсии: при первом включении шифрования
                // она остаётся в открытом виде (при смене типа ключа копия
                // зашифрована прежним ключом)
                if Plain and (BackupFile <> '') then
                    MessagesHandler.ShowInfo(TUIStateLoader.GetMessage(
                        'Settings.DbBackupUnencrypted', [BackupFile]));
            end
            else
                lbDbState.Caption := TUIStateLoader.GetMessage('Settings.DbApplyDoneOff');
            if ModeChange then
                MessagesHandler.ShowInfo(
                    TUIStateLoader.GetMessage('Settings.DbModeChanged'));
            UpdateDbStateLabel;
        end
        else
        begin
            MessagesHandler.ShowError(TUIStateLoader.GetMessage(
                'Settings.DbApplyFailed', [ErrMsg]));
            UpdateDbStateLabel;
            chkDbEncrypt.Checked := not DbFileIsPlain(DbFile);
        end;
    finally
        FDbBusy := False;
        chkDbEncrypt.Enabled := True;
        cbDbMode.Enabled := chkDbEncrypt.Checked;
        bDbApply.Enabled := AppContext.DatabaseManager.IsConnected;
        bDbExport.Enabled := True;
        bDbImport.Enabled := AppContext.DatabaseManager.IsConnected;
        UpdateDbSaveKeyCombo;
        bSave.Enabled := True;
        bCancel.Enabled := True;
    end;

    // Ключ создан заново: предлагаем сохранить его в файл сразу, пока
    // он не утерян
    if Success and TurningOn then
        OfferDbKeyExport(NewKey);
end;

procedure TSettingsForm.bDbExportClick(Sender: TObject);
var
    Key: string;
begin
    if FDbBusy or (not DbEngineDllAvailable) then
        Exit;

    Key := DbCurrentKeyMaterial;
    if Key = '' then
    begin
        MessagesHandler.ShowWarning(
            TUIStateLoader.GetMessage('Settings.DbExportNoKey'));
        Exit;
    end;

    ExportDbKeyToFile(Key);
end;

// Экспорт ключа в зашифрованный JSON: общий хвост ручного экспорта
// (bDbExportClick) и предложения сохранить ключ после включения
// шифрования (OfferDbKeyExport)
procedure TSettingsForm.ExportDbKeyToFile(const AKey: string);
var
    Pass1, KeyJson, OutFile: string;
    RawKey: TBytes;
    SaveDlg: TSaveDialog;
begin
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

// Предложение сохранить ключ базы в зашифрованный JSON сразу после
// включения шифрования: без файла ключ теряется при переносе базы на
// другую машину. Отказ безопасен - ключ остаётся в настройках машины
procedure TSettingsForm.OfferDbKeyExport(const AKey: string);
begin
    if AKey = '' then
        Exit;
    if not MessagesHandler.AskWarning(
        TUIStateLoader.GetMessage('Settings.DbExportOfferAsk'),
        TUIStateLoader.GetMessage('Common.Warning')) then
        Exit;
    ExportDbKeyToFile(AKey);
end;

procedure TSettingsForm.bDbImportClick(Sender: TObject);
var
    DbFile, BackupFile, KeyJson, Pass1, NewKey, OldKey, ReopenKey, ErrMsg, InFile: string;
    RawKey: TBytes;
    Setts: TAppSettings;
    Profile: TDbSecurityProfile;
    Confirmed, Success: Boolean;
    OpenDlg: TOpenDialog;
    DbApp: TAppDatabase;
begin
    if FDbBusy or (not DbEngineDllAvailable) then
        Exit;

    DbFile := AppContext.DatabaseManager.DatabaseFile;
    if (not AppContext.DatabaseManager.IsConnected) or
        DbFile.IsEmpty or SameText(DbFile, ':memory:') then
    begin
        MessagesHandler.ShowWarning(
            TUIStateLoader.GetMessage('Settings.DbNotOpen'));
        Exit;
    end;

    InFile := '';
    OpenDlg := TOpenDialog.Create(Self);
    try
        OpenDlg.Title := TUIStateLoader.GetMessage('Settings.DbImportTitle');
        OpenDlg.Filter := 'JSON (*.json)|*.json';
        OpenDlg.Options := OpenDlg.Options + [ofFileMustExist];
        if OpenDlg.Execute(Handle) then
            InFile := OpenDlg.FileName;
    finally
        OpenDlg.Free;
    end;
    if InFile = '' then
        Exit;

    Pass1 := PromptDbPassphrase('Settings.DbImportPassphrase');
    if Pass1 = '' then
        Exit;

    NewKey := '';
    try
        KeyJson := TFile.ReadAllText(InFile, TEncoding.UTF8);
        RawKey := DbImportKeyFromJson(KeyJson, Pass1);
        try
            NewKey := TNetEncoding.Base64.EncodeBytesToString(RawKey);
        finally
            WipeSecretBytes(RawKey);
        end;
    except
        on E: Exception do
        begin
            MessagesHandler.ShowError(TUIStateLoader.GetMessage(
                'Settings.DbImportFailed', [E.Message]));
            Exit;
        end;
    end;

    OldKey := DbCurrentKeyMaterial;
    if OldKey = NewKey then
    begin
        // Импортированный ключ совпадает с фактическим: достаточно
        // закрепить его в настройках (файл уже открыт этим ключом)
        Setts := AppContext.SettingsManager.Data;
        Setts.Db.DbDefined := True;
        Setts.Db.Encryption := DB_ENCRYPTION_AES256;
        Setts.Db.KeyMode := DB_KEYMODE_DPAPI;
        Setts.Db.Salt := '';
        Setts.Db.RememberKey := True;
        Setts.Db.Key := NewKey;
        // Профиль открытой базы получает импортированный ключ:
        // глобальный слот позже может уйти к другой базе
        Profile := GetDbProfile(Setts, DbFile);
        Profile.KeyMode := DB_KEYMODE_DPAPI;
        Profile.Salt := '';
        Profile.RememberKey := True;
        Profile.Key := NewKey;
        SaveDbProfile(Setts, Profile);
        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;
        chkDbEncrypt.Checked := True;
        cbDbMode.ItemIndex := 0;
        cbDbMode.Enabled := True;
        UpdateDbSaveKeyCombo;
        UpdateDbStateLabel;
        MessagesHandler.ShowInfo(
            TUIStateLoader.GetMessage('Settings.DbImportDone'));
        Exit;
    end;

    Confirmed := MessagesHandler.AskWarning(
        TUIStateLoader.GetMessage('Settings.DbImportApplyConfirm'),
        TUIStateLoader.GetMessage('Common.Warning'));
    if not Confirmed then
        Exit;

    FDbBusy := True;
    chkDbEncrypt.Enabled := False;
    cbDbMode.Enabled := False;
    bDbApply.Enabled := False;
    bDbExport.Enabled := False;
    bDbImport.Enabled := False;
    cbDbSaveKey.Enabled := False;
    bSave.Enabled := False;
    bCancel.Enabled := False;
    lbDbState.Caption := TUIStateLoader.GetMessage('Settings.DbApplyInProgress');
    try
        BackupFile := CreateAutoBackupStandalone(DbFile,
            AppContext.SettingsManager.Data.Backup.IntervalSeconds,
            AppContext.SettingsManager.Data.Backup.Keep, True, OldKey);

        AppContext.DatabaseManager.CloseDatabase;

        Success := ConvertDbWithProgress(
            TUIStateLoader.GetMessage('Settings.DbConversionTitle'),
            TUIStateLoader.GetMessage('Settings.DbConversionInProgress'),
            DbFile, OldKey, NewKey, AppContext, ErrMsg);

        if Success then
        begin
            Setts := AppContext.SettingsManager.Data;
            Setts.Db.DbDefined := True;
            Setts.Db.Encryption := DB_ENCRYPTION_AES256;
            Setts.Db.KeyMode := DB_KEYMODE_DPAPI;
            Setts.Db.Salt := '';
            Setts.Db.RememberKey := True;
            Setts.Db.Key := NewKey;
            // Профиль открытой базы получает импортированный ключ:
            // глобальный слот позже может уйти к другой базе
            Profile := GetDbProfile(Setts, DbFile);
            Profile.KeyMode := DB_KEYMODE_DPAPI;
            Profile.Salt := '';
            Profile.RememberKey := True;
            Profile.Key := NewKey;
            SaveDbProfile(Setts, Profile);
            AppContext.SettingsManager.Data := Setts;
            AppContext.SettingsManager.Save;
        end;

        // Переоткрытие в фактическом состоянии файла: при сбое конверсии
        // файл остался с прежним ключом
        if Success then
            ReopenKey := NewKey
        else
            ReopenKey := OldKey;

        try
            DbApp := AppContext.DatabaseManager as TAppDatabase;
            DbApp.EncryptionKey := ReopenKey;
            AppContext.DatabaseManager.OpenDatabase(DbFile);
        except
            on E: Exception do
                MessagesHandler.ShowError(TUIStateLoader.GetMessage(
                    'DB.OpenError', [E.Message]));
        end;

        if Success then
        begin
            chkDbEncrypt.Checked := True;
            cbDbMode.ItemIndex := 0;
            // Импорт на незашифрованную базу: копия снята в открытом виде
            if (OldKey = '') and (BackupFile <> '') then
                MessagesHandler.ShowInfo(TUIStateLoader.GetMessage(
                    'Settings.DbBackupUnencrypted', [BackupFile]))
            else
                MessagesHandler.ShowInfo(
                    TUIStateLoader.GetMessage('Settings.DbImportDone'));
        end
        else
            MessagesHandler.ShowError(TUIStateLoader.GetMessage(
                'Settings.DbApplyFailed', [ErrMsg]));
        UpdateDbStateLabel;
    finally
        FDbBusy := False;
        chkDbEncrypt.Enabled := True;
        cbDbMode.Enabled := chkDbEncrypt.Checked;
        bDbApply.Enabled := AppContext.DatabaseManager.IsConnected;
        bDbExport.Enabled := True;
        bDbImport.Enabled := AppContext.DatabaseManager.IsConnected;
        UpdateDbSaveKeyCombo;
        bSave.Enabled := True;
        bCancel.Enabled := True;
    end;
end;

// Список профилей баз: сохранённые ключи по файлам, удаление
// отдельных профилей и чистка записей о несуществующих базах
procedure TSettingsForm.bDbProfilesClick(Sender: TObject);
begin
    if FDbBusy then
        Exit;
    ShowDbProfilesForm(AppContext);
    LoadDbSecurityToUI;
end;

procedure TSettingsForm.PopulateApplicationsList;
var
    Item: TListItem;
    App: TAllowedApplicationsItem;
begin
    lvApplications.Items.BeginUpdate;
    try
        lvApplications.Items.Clear;
        FAppProfiles.Clear;

        for App in AppContext.SettingsManager.Data.AllowedApplications do
        begin
            Item := lvApplications.Items.Add;
            Item.Caption := App.ExeName;
            Item.Checked := App.Enabled;
            FAppProfiles.AddOrSetValue(App.ExeName.ToLower, App);
        end;
    finally
        lvApplications.Items.EndUpdate;
    end;

    UpdateProfileButtonState;
end;

procedure TSettingsForm.UpdateProfileButtonState;
begin
    bAppProfile.Visible := lvApplications.Selected <> nil;
end;

procedure TSettingsForm.lvApplicationsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
    UpdateProfileButtonState;
end;

procedure TSettingsForm.lvApplicationsDblClick(Sender: TObject);
begin
    if lvApplications.Selected <> nil then
        bAppProfileClick(Sender);
end;

function TSettingsForm.GetAppProfile(const AExeName: string): TAllowedApplicationsItem;
begin
    if not FAppProfiles.TryGetValue(AExeName.ToLower, Result) then
    begin
        Result.ExeName := AExeName;
        Result.Enabled := True;
        Result.TitleIncludeRegex := '';
        Result.TitleExcludeRegex := '';
        Result.WindowClasses := nil;
    end;
end;

function TSettingsForm.TryNormalizeAppName(var AName: string; const AIgnoreExisting: string): Boolean;
var
    Item: TListItem;
begin
    AName := ExtractFileName(Trim(AName));

    if AName.IsEmpty then
    begin
        MessagesHandler.ShowWarning(
            TUIStateLoader.GetMessage('Settings.ApplicationsInvalidName')
        );
        Exit(False);
    end;

    if not AName.ToLower.EndsWith('.exe') then
        AName := AName + '.exe';

    for Item in lvApplications.Items do
        if (Item.Caption <> AIgnoreExisting) and SameText(Item.Caption, AName) then
        begin
            MessagesHandler.ShowWarning(
                TUIStateLoader.GetMessage('Settings.ApplicationsDuplicate', [AName])
            );
            Exit(False);
        end;

    Result := True;
end;

procedure TSettingsForm.bAppAddClick(Sender: TObject);
var
    NewName: string;
    Item: TListItem;
begin
    NewName := '';
    if not InputQuery(
        Caption,
        TUIStateLoader.GetMessage('Settings.ApplicationsAddPrompt'),
        NewName
    ) then Exit;

    if not TryNormalizeAppName(NewName, '') then Exit;

    Item := lvApplications.Items.Add;
    Item.Caption := NewName;
    Item.Checked := True;
    lvApplications.Selected := Item;
end;

procedure TSettingsForm.bAppRenameClick(Sender: TObject);
var
    Item: TListItem;
    NewName, OldName: string;
    Profile: TAllowedApplicationsItem;
begin
    Item := lvApplications.Selected;
    if Item = nil then
        Exit;

    OldName := Item.Caption;
    NewName := OldName;
    if not InputQuery(
        Caption,
        TUIStateLoader.GetMessage('Settings.ApplicationsRenamePrompt'),
        NewName
    ) then Exit;

    if not TryNormalizeAppName(NewName, OldName) then Exit;

    Item.Caption := NewName;

    if not SameText(OldName, NewName) then
        if FAppProfiles.TryGetValue(OldName.ToLower, Profile) then
        begin
            FAppProfiles.Remove(OldName.ToLower);
            FAppProfiles.AddOrSetValue(NewName.ToLower, Profile);
        end;
end;

procedure TSettingsForm.bAppDeleteClick(Sender: TObject);
var
    Item: TListItem;
begin
    Item := lvApplications.Selected;
    if Item = nil then
        Exit;

    if not MessagesHandler.AskWarning(
        TUIStateLoader.GetMessage('Settings.ApplicationsDeleteConfirm', [Item.Caption]),
        TUIStateLoader.GetMessage('Common.Warning')
    ) then Exit;

    FAppProfiles.Remove(Item.Caption.ToLower);
    Item.Delete;
    UpdateProfileButtonState;
end;

procedure TSettingsForm.bAppPickClick(Sender: TObject);
var
    Picked: TArray<TAppEntry>;
    Entry: TAppEntry;
    Name: string;
    Item: TListItem;
    Duplicate: Boolean;
begin
    Picked := TAppPickerForm.Execute(Self, AppContext);

    for Entry in Picked do
    begin
        Name := Trim(Entry.ExeName);
        if Name.IsEmpty then
            Continue;

        Name := ExtractFileName(Name);
        if not Name.ToLower.EndsWith('.exe') then
            Name := Name + '.exe';

        Duplicate := False;
        for Item in lvApplications.Items do
            if SameText(Item.Caption, Name) then
            begin
                Duplicate := True;
                Break;
            end;

        if Duplicate then
            Continue;

        Item := lvApplications.Items.Add;
        Item.Caption := Name;
        Item.Checked := True;
    end;
end;

procedure TSettingsForm.bAppProfileClick(Sender: TObject);
var
    Item: TListItem;
    Profile: TAllowedApplicationsItem;
begin
    Item := lvApplications.Selected;
    if Item = nil then
        Exit;

    Profile := GetAppProfile(Item.Caption);
    if TWindowProfileDialog.Execute(Self, AppContext, Item.Caption, Profile) then
        FAppProfiles.AddOrSetValue(Item.Caption.ToLower, Profile);
end;

procedure TSettingsForm.cbVCLStyleChange(Sender: TObject);
var
    Setts: TAppSettings;
    NewStyle, FailedStyle: string;
begin
    if cbVCLStyle.ItemIndex < 0 then
        Exit;

    if cbVCLStyle.ItemIndex = 0 then
        NewStyle := ''
    else
        NewStyle := cbVCLStyle.Items[cbVCLStyle.ItemIndex];

    Setts := AppContext.SettingsManager.Data;
    if SameText(NewStyle, Setts.UISettings.VCLStyle) then
        Exit;

    if IsUIChanged and (not MessagesHandler.AskWarning(
        TUIStateLoader.GetMessage('Common.DiscardChangesConfirm'),
        TUIStateLoader.GetMessage('Common.Warning'))) then
    begin
        cbVCLStyle.ItemIndex := cbVCLStyle.Items.IndexOf(Setts.UISettings.VCLStyle);
        if cbVCLStyle.ItemIndex < 0 then
            cbVCLStyle.ItemIndex := 0;
        Exit;
    end;

    FStyleSavedPage := pcSettings.ActivePage;
    FStyleSavedFocus := ActiveControl;

    if not TVCLStyleService.ApplyStyle(NewStyle) then
    begin
        if NewStyle.IsEmpty then
            FailedStyle := 'Windows'
        else
            FailedStyle := NewStyle;

        MessagesHandler.ShowError(TUIStateLoader.GetMessage('Settings.StyleApplyError', [FailedStyle]));
        cbVCLStyle.ItemIndex := cbVCLStyle.Items.IndexOf(Setts.UISettings.VCLStyle);
        if cbVCLStyle.ItemIndex < 0 then
            cbVCLStyle.ItemIndex := 0;
        Exit;
    end;

    TSynThemeAdapter.ApplyThemeToAll;

    Setts.UISettings.VCLStyle := NewStyle;
    AppContext.SettingsManager.Data := Setts;
    AppContext.SettingsManager.Save;

    cbVCLStyle.ItemIndex := cbVCLStyle.Items.IndexOf(NewStyle);
    if cbVCLStyle.ItemIndex < 0 then
        cbVCLStyle.ItemIndex := 0;
end;

procedure TSettingsForm.DoStyleRecreated;
begin
    inherited;

    if not Assigned(FAppContext) then
        Exit;

    DoInitialize;
    CaptureSnapshot;

    if (FStyleSavedPage <> nil) and FStyleSavedPage.TabVisible then
        pcSettings.ActivePage := FStyleSavedPage;

    if (FStyleSavedFocus <> nil) and FStyleSavedFocus.CanFocus then
        ActiveControl := FStyleSavedFocus;

    FStyleSavedPage := nil;
    FStyleSavedFocus := nil;
end;

function TSettingsForm.ResolveHotkey(HotKeyCtrl: THotKey; Enabled: Boolean; const Saved: THotkeyConfig): THotkeyConfig;
begin
    if HotKeyCtrl.HotKey = Vcl.Menus.ShortCut(Saved.Key, Win32ModifiersToShiftState(Saved.Modifiers)) then
    begin
        Result := Saved;
        Result.Enabled := Enabled;
    end
    else
        Result := VCLHotkeyToWin32(HotKeyCtrl, Enabled);
end;

procedure TSettingsForm.bSaveClick(Sender: TObject);
var
    Setts: TAppSettings;
    I: Integer;
    AppProfile: TAllowedApplicationsItem;
    Info: TActionHotkeyInfo;
begin
    Setts := AppContext.SettingsManager.Data;
    Setts.Hotkeys.QuickSearch := ResolveHotkey(hkQuickSearch, chkEnableQuickSearch.Checked, FSavedQuickSearch);
    Setts.Hotkeys.PasswordGen := ResolveHotkey(hkPassGen, chkEnablePassGen.Checked, FSavedPasswordGen);
    Setts.Hotkeys.RepeatLast := ResolveHotkey(hkRepeatLast, chkEnableRepeatLast.Checked, FSavedRepeatLast);
    Setts.Hotkeys.FavoriteSlots := ResolveHotkey(hkFavSlots, chkEnableFavSlots.Checked, FSavedFavoriteSlots);

    // --- Сохраняем настройки синхронизации ---
    Setts.SyncDirectory := Trim(ledMarkdownPath.Text);
    Setts.SyncOnStart := cbSyncOnStart.Checked;
    Setts.SyncOnExit := cbSyncOnExit.Checked;

    // --- Периодический экспорт в Vault ---
    Setts.AutoExportEnabled := cbAutoExport.Checked;
    Setts.AutoExportIntervalMinutes := IndexToAutoExportInterval(cbAutoExportInterval.ItemIndex);
    Setts.AutoExportDefined := True;
    // --------------------------------------

    Setts.TagsMatchAll := cbTagsMatchAll.Checked;
    Setts.SecurityScanStrict := cbSecurityStrict.Checked;

    // --- Настройки фоновой проверки секретов ---
    Setts.SecurityBackgroundScanEnabled := cbSecurityBackground.Checked;
    Setts.SecurityBackgroundScanIntervalMinutes := IndexToScanInterval(cbSecurityInterval.ItemIndex);
    Setts.SecurityBackgroundScanDefined := True;
    // -------------------------------------------

    Setts.UISettings.SnippetListColumns := 0;
    if cbColLanguage.Checked then
        Setts.UISettings.SnippetListColumns := Setts.UISettings.SnippetListColumns or 1;
    if cbColLastRun.Checked then
        Setts.UISettings.SnippetListColumns := Setts.UISettings.SnippetListColumns or 2;
    if cbColUpdated.Checked then
        Setts.UISettings.SnippetListColumns := Setts.UISettings.SnippetListColumns or 4;
    Setts.UISettings.SnippetListColumnsDefined := True;

    // --- Настройки автобэкапа ---
    Setts.Backup.Enabled := chkBackupEnabled.Checked;
    Setts.Backup.IntervalSeconds := IndexToInterval(cbBackupInterval.ItemIndex);
    Setts.Backup.Keep := seBackupKeep.Value;
    Setts.BackupDefined := True;
    // ----------------------------

    SetLength(Setts.AllowedApplications.Items, lvApplications.Items.Count);
    for I := 0 to lvApplications.Items.Count - 1 do
    begin
        Setts.AllowedApplications.Items[I].ExeName := lvApplications.Items[I].Caption;
        Setts.AllowedApplications.Items[I].Enabled := lvApplications.Items[I].Checked;

        if FAppProfiles.TryGetValue(lvApplications.Items[I].Caption.ToLower, AppProfile) then
        begin
            Setts.AllowedApplications.Items[I].TitleIncludeRegex := AppProfile.TitleIncludeRegex;
            Setts.AllowedApplications.Items[I].TitleExcludeRegex := AppProfile.TitleExcludeRegex;
            Setts.AllowedApplications.Items[I].WindowClasses := AppProfile.WindowClasses;
        end;
    end;

    for Info in FLocalActions.Values do
        AppContext.HotkeyService.SetActionShortCut(Info.ActionName, Info.CurrentShortCut);

    Setts.CustomShortCuts := AppContext.HotkeyService.SaveToSettings;

    AppContext.SettingsManager.Data := Setts;
    AppContext.SettingsManager.Save;

    GWinMonitor.ClearAllowedProcesses;
    for I := 0 to lvApplications.Items.Count - 1 do
        if lvApplications.Items[I].Checked then
            GWinMonitor.AddAllowedProcess(lvApplications.Items[I].Caption.ToLower);

    GProfileManager.SyncFromApplications(AppContext.SettingsManager.Data.AllowedApplications.Items);

    for I := 0 to Screen.FormCount - 1 do
        AppContext.HotkeyService.ApplySettingsToForm(Screen.Forms[I]);

    CaptureSnapshot;
    ModalResult := mrOk;
end;

procedure TSettingsForm.bCancelClick(Sender: TObject);
begin
    ModalResult := mrCancel;
end;

procedure TSettingsForm.bSelectVaultPathClick(Sender: TObject);
var
    ChosenDir: string;
begin
    ChosenDir := ledMarkdownPath.Text;

    // Вызываем стандартный диалог выбора папки Windows
    if SelectDirectory(TUIStateLoader.GetMessage('Settings.SelectVaultPath'), '', ChosenDir) then
    begin
        ledMarkdownPath.Text := ChosenDir;
    end;
end;

procedure TSettingsForm.FormShow(Sender: TObject);
begin
    if FFirstShowDone then
        Exit;

    pcSettings.ActivePage := tsHotkeys;
    CaptureSnapshot;
    FFirstShowDone := True;
end;

procedure TSettingsForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
    // Фоновое копирование ещё идёт: Synchronize должен попасть в живую форму
    if FBackupBusy or FDbBusy then
    begin
        CanClose := False;
        Exit;
    end;

    if IsUIChanged and (not MessagesHandler.AskWarning(
        TUIStateLoader.GetMessage('Common.DiscardChangesConfirm'),
        TUIStateLoader.GetMessage('Common.Warning'))) then
        CanClose := False;
end;

function TSettingsForm.BuildUISnapshot: string;
var
    SB: TStringBuilder;
    KeyName: string;
    KeyNames: TArray<string>;
    ProfileKeys: TArray<string>;
    Item: TListItem;
    AppProfile: TAllowedApplicationsItem;
    C: string;
begin
    SB := TStringBuilder.Create;
    try
        SB.Append(hkQuickSearch.HotKey).Append('|')
            .Append(chkEnableQuickSearch.Checked).Append('|')
            .Append(hkPassGen.HotKey).Append('|')
            .Append(chkEnablePassGen.Checked).Append('|')
            .Append(hkRepeatLast.HotKey).Append('|')
            .Append(chkEnableRepeatLast.Checked).Append('|')
            .Append(hkFavSlots.HotKey).Append('|')
            .Append(chkEnableFavSlots.Checked).Append('|')
            .Append(Trim(ledMarkdownPath.Text)).Append('|')
            .Append(cbSyncOnStart.Checked).Append('|')
            .Append(cbSyncOnExit.Checked).Append('|')
            .Append(cbAutoExport.Checked).Append('|')
            .Append(cbAutoExportInterval.ItemIndex).Append('|')
            .Append(cbTagsMatchAll.Checked).Append('|')
            .Append(cbSecurityStrict.Checked).Append('|')
            .Append(cbSecurityBackground.Checked).Append('|')
            .Append(cbSecurityInterval.ItemIndex).Append('|')
            .Append(cbColLanguage.Checked).Append('|')
            .Append(cbColLastRun.Checked).Append('|')
            .Append(cbColUpdated.Checked).Append('|')
            .Append(chkBackupEnabled.Checked).Append('|')
            .Append(cbBackupInterval.ItemIndex).Append('|')
            .Append(seBackupKeep.Value).Append('|');

        for Item in lvApplications.Items do
            SB.Append(Item.Caption).Append(':')
                .Append(Item.Checked).Append(';');

        SB.Append('|');

        ProfileKeys := FAppProfiles.Keys.ToArray;
        TArray.Sort<string>(ProfileKeys);
        for KeyName in ProfileKeys do
        begin
            AppProfile := FAppProfiles[KeyName];
            SB.Append(KeyName).Append('=')
                .Append(AppProfile.TitleIncludeRegex).Append('>')
                .Append(AppProfile.TitleExcludeRegex).Append('>');
            for C in AppProfile.WindowClasses do
                SB.Append(C).Append(',');
            SB.Append(';');
        end;

        SB.Append('|');

        KeyNames := FLocalActions.Keys.ToArray;
        TArray.Sort<string>(KeyNames);
        for KeyName in KeyNames do
            SB.Append(KeyName).Append('=')
                .Append(FLocalActions[KeyName].CurrentShortCut).Append(';');

        Result := SB.ToString;
    finally
        SB.Free;
    end;
end;

procedure TSettingsForm.CaptureSnapshot;
begin
    FSnapshottedUI := BuildUISnapshot;
end;

function TSettingsForm.IsUIChanged: Boolean;
begin
    Result := BuildUISnapshot <> FSnapshottedUI;
end;

end.

