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
    Vcl.StdCtrls,
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
        cbTagsMatchAll: TCheckBox;
        lbVCLStyle: TLabel;
        cbVCLStyle: TComboBox;
        tsApplications: TTabSheet;
        lvApplications: TListView;
        pApplicationsButtons: TPanel;
        bAppAdd: TButton;
        bAppRename: TButton;
        bAppDelete: TButton;
        bAppPick: TButton;

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
        procedure cbVCLStyleChange(Sender: TObject);
    private
        FLocalActions: TDictionary<string, TActionHotkeyInfo>;
        FHotkeyData: TObjectList<THotkeyViewData>;
        FSnapshottedUI: string;
        FFirstShowDone: Boolean;
        FStyleSavedPage: TTabSheet;
        FStyleSavedFocus: TWinControl;
        procedure LoadSettingsToUI;
        procedure PopulateHotkeysList(const FilterText: string = '');
        procedure PopulateApplicationsList;
        function TryNormalizeAppName(var AName: string; const AIgnoreExisting: string): Boolean;
        function BuildUISnapshot: string;
        procedure CaptureSnapshot;
        function IsUIChanged: Boolean;
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
    Common.Helpers,
    HotkeyService,
    System.IOUtils,
    Common.Localization,
    SynThemeAdapter,
    Vcl.FileCtrl,
    Vcl.Menus,
    Common.VCLStyleService,
    WindowMonitor
    ;

constructor TSettingsForm.Create(AOwner: TComponent);
begin
    inherited Create(AOwner);
    FLocalActions := TDictionary<string, TActionHotkeyInfo>.Create;
    FHotkeyData := TObjectList<THotkeyViewData>.Create;
end;

destructor TSettingsForm.Destroy;
begin
    FHotkeyData.Free;
    FLocalActions.Free;
    inherited Destroy;
end;

procedure TSettingsForm.DoInitialize;
begin
    hkEditor.HotKey := 0;
    pEditor.Enabled := False;
    LoadSettingsToUI;
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

    Win32HotkeyToVCL(Setts.Hotkeys.PasswordGen, hkPassGen);
    chkEnablePassGen.Checked := Setts.Hotkeys.PasswordGen.Enabled;

    Win32HotkeyToVCL(Setts.Hotkeys.RepeatLast, hkRepeatLast);
    chkEnableRepeatLast.Checked := Setts.Hotkeys.RepeatLast.Enabled;

    Win32HotkeyToVCL(Setts.Hotkeys.FavoriteSlots, hkFavSlots);
    chkEnableFavSlots.Checked := Setts.Hotkeys.FavoriteSlots.Enabled;

    // --- Блок синхронизации Markdown ---
    if Setts.SyncDirectory.IsEmpty then
        // По умолчанию: папка 'SnippetsVault' рядом с EXE программы
        ledMarkdownPath.Text := TPath.Combine(ExtractFilePath(ParamStr(0)), 'SnippetsVault')
    else
        ledMarkdownPath.Text := Setts.SyncDirectory;

    cbSyncOnStart.Checked := Setts.SyncOnStart;
    cbSyncOnExit.Checked := Setts.SyncOnExit;
    // -----------------------------------

    cbTagsMatchAll.Checked := Setts.TagsMatchAll;

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

procedure TSettingsForm.PopulateApplicationsList;
var
    Item: TListItem;
begin
    lvApplications.Items.BeginUpdate;
    try
        lvApplications.Items.Clear;

        for var App in AppContext.SettingsManager.Data.AllowedApplications do
        begin
            Item := lvApplications.Items.Add;
            Item.Caption := App.ExeName;
            Item.Checked := App.Enabled;
        end;
    finally
        lvApplications.Items.EndUpdate;
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
    NewName: string;
begin
    Item := lvApplications.Selected;
    if Item = nil then
        Exit;

    NewName := Item.Caption;
    if not InputQuery(
        Caption,
        TUIStateLoader.GetMessage('Settings.ApplicationsRenamePrompt'),
        NewName
    ) then Exit;

    if not TryNormalizeAppName(NewName, Item.Caption) then Exit;

    Item.Caption := NewName;
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

    Item.Delete;
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
end;

procedure TSettingsForm.DoStyleRecreated;
begin
    inherited;

    if (FStyleSavedPage <> nil) and FStyleSavedPage.TabVisible then
        pcSettings.ActivePage := FStyleSavedPage;

    if (FStyleSavedFocus <> nil) and FStyleSavedFocus.CanFocus then
        ActiveControl := FStyleSavedFocus;

    FStyleSavedPage := nil;
    FStyleSavedFocus := nil;
end;

procedure TSettingsForm.bSaveClick(Sender: TObject);
var
    Setts: TAppSettings;
    I: Integer;
    Info: TActionHotkeyInfo;
begin
    Setts := AppContext.SettingsManager.Data;

    Setts.Hotkeys.QuickSearch := VCLHotkeyToWin32(hkQuickSearch, chkEnableQuickSearch.Checked);
    Setts.Hotkeys.PasswordGen := VCLHotkeyToWin32(hkPassGen, chkEnablePassGen.Checked);
    Setts.Hotkeys.RepeatLast := VCLHotkeyToWin32(hkRepeatLast, chkEnableRepeatLast.Checked);
    Setts.Hotkeys.FavoriteSlots := VCLHotkeyToWin32(hkFavSlots, chkEnableFavSlots.Checked);

    // --- Сохраняем настройки синхронизации ---
    Setts.SyncDirectory := Trim(ledMarkdownPath.Text);
    Setts.SyncOnStart := cbSyncOnStart.Checked;
    Setts.SyncOnExit := cbSyncOnExit.Checked;
    // -----------------------------------------

    Setts.TagsMatchAll := cbTagsMatchAll.Checked;

    SetLength(Setts.AllowedApplications.Items, lvApplications.Items.Count);
    for I := 0 to lvApplications.Items.Count - 1 do
    begin
        Setts.AllowedApplications.Items[I].ExeName := lvApplications.Items[I].Caption;
        Setts.AllowedApplications.Items[I].Enabled := lvApplications.Items[I].Checked;
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
    Item: TListItem;
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
            .Append(ledMarkdownPath.Text).Append('|')
            .Append(cbSyncOnStart.Checked).Append('|')
            .Append(cbSyncOnExit.Checked).Append('|')
            .Append(cbTagsMatchAll.Checked).Append('|');

        for Item in lvApplications.Items do
            SB.Append(Item.Caption).Append(':')
                .Append(Item.Checked).Append(';');

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

