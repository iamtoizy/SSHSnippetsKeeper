unit SettingsFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces,
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
    Vcl.StdCtrls,
    Winapi.Messages,
    Winapi.Windows, Vcl.Mask
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

        procedure bSaveClick(Sender: TObject);
        procedure bCancelClick(Sender: TObject);
        procedure lvHotkeysSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure bApplyShortcutClick(Sender: TObject);
        procedure bResetShortcutClick(Sender: TObject);
        procedure bResetAllClick(Sender: TObject);
        procedure bSelectVaultPathClick(Sender: TObject);
        procedure ebSearchHotkeysChange(Sender: TObject);
        procedure FormShow(Sender: TObject);
        procedure lvHotkeysDeletion(Sender: TObject; Item: TListItem);
        procedure lvHotkeysCompare(Sender: TObject; Item1, Item2: TListItem; Data: Integer; var Compare: Integer);
    private
        FLocalActions: TDictionary<string, TActionHotkeyInfo>;
        procedure LoadSettingsToUI;
        procedure PopulateHotkeysList(const FilterText: string = '');
        function IsLocalShortCutInUse(const ActionID: string; ShortCut: TShortCut; out ConflictingActionName: string): Boolean;
    protected
        procedure DoInitialize; override;
    public
        constructor Create(AOwner: TComponent); override;
        destructor Destroy; override;
    end;

implementation

{$R *.dfm}

uses
    CommonHelpers,
    System.IOUtils,
    UI.StateLoader,
    Vcl.FileCtrl,
    Vcl.Menus
    ;

constructor TSettingsForm.Create(AOwner: TComponent);
begin
    inherited Create(AOwner);
    FLocalActions := TDictionary<string, TActionHotkeyInfo>.Create;
end;

destructor TSettingsForm.Destroy;
begin
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

    // --- Блок синхронизации Markdown ---
    if Setts.SyncDirectory.IsEmpty then
        // По умолчанию: папка 'SnippetsVault' рядом с EXE программы
        ledMarkdownPath.Text := TPath.Combine(ExtractFilePath(ParamStr(0)), 'SnippetsVault')
    else
        ledMarkdownPath.Text := Setts.SyncDirectory;

    cbSyncOnStart.Checked := Setts.SyncOnStart;
    cbSyncOnExit.Checked := Setts.SyncOnExit;
    // -----------------------------------

    FLocalActions.Clear;
    Actions := AppContext.HotkeyService.GetAllActions;
    for Info in Actions do
        FLocalActions.Add(Info.ActionName, Info);

    PopulateHotkeysList;

    for I := 0 to lvHotkeys.Columns.Count - 1 do
        lvHotkeys.Columns[I].Width := -2;
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
    if Assigned(Item.Data) then
        TObject(Item.Data).Free;
end;

procedure TSettingsForm.ebSearchHotkeysChange(Sender: TObject);
begin
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

function TSettingsForm.IsLocalShortCutInUse(const ActionID: string; ShortCut: TShortCut; out ConflictingActionName: string): Boolean;
var
    Info: TActionHotkeyInfo;
    TargetFormClass: string;
    CurrentFormClass: string;
begin
    Result := False;
    ConflictingActionName := '';
    if ShortCut = 0 then Exit;

    TargetFormClass := ActionID.Split(['.'])[0];

    for Info in FLocalActions.Values do
    begin
        if Info.CurrentShortCut = ShortCut then
        begin
            CurrentFormClass := Info.ActionName.Split(['.'])[0];

            if SameText(TargetFormClass, CurrentFormClass) then
            begin
                ConflictingActionName := Info.DisplayName;
                Exit(True);
            end;
        end;
    end;
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

    if IsLocalShortCutInUse(ActionID, hkEditor.HotKey, ConflictName) then
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
        TUIStateLoader.GetMessage('Category.SelectPrompt'),
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

procedure TSettingsForm.bSaveClick(Sender: TObject);
var
    Setts: TAppSettings;
    I: Integer;
    Info: TActionHotkeyInfo;
begin
    Setts := AppContext.SettingsManager.Data;

    Setts.Hotkeys.QuickSearch := VCLHotkeyToWin32(hkQuickSearch, chkEnableQuickSearch.Checked);
    Setts.Hotkeys.PasswordGen := VCLHotkeyToWin32(hkPassGen, chkEnablePassGen.Checked);

    // --- Сохраняем настройки синхронизации ---
    Setts.SyncDirectory := Trim(ledMarkdownPath.Text);
    Setts.SyncOnStart := cbSyncOnStart.Checked;
    Setts.SyncOnExit := cbSyncOnExit.Checked;
    // -----------------------------------------

    for Info in FLocalActions.Values do
        AppContext.HotkeyService.SetActionShortCut(Info.ActionName, Info.CurrentShortCut);

    Setts.CustomShortCuts := AppContext.HotkeyService.SaveToSettings;

    AppContext.SettingsManager.Data := Setts;
    AppContext.SettingsManager.Save;

    for I := 0 to Screen.FormCount - 1 do
        AppContext.HotkeyService.ApplySettingsToForm(Screen.Forms[I]);

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
    pcSettings.ActivePage := tsHotkeys;
end;

end.

