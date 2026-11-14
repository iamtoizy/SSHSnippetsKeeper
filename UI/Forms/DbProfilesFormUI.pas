unit DbProfilesFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    System.Classes,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.StdCtrls
    ;

type
    TDbProfilesForm = class(TBaseForm)
        lvProfiles: TListView;
        bCleanup: TButton;
        bDelete: TButton;
        bClose: TButton;
        procedure FormShow(Sender: TObject);
        procedure lvProfilesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure bCleanupClick(Sender: TObject);
        procedure bDeleteClick(Sender: TObject);
    private
        procedure Localize;
        procedure PopulateProfilesList;
        procedure UpdateButtonsState;
    end;

procedure ShowDbProfilesForm(const AppContext: IAppContext);

implementation

uses
    Common.Localization,
    Common.Settings,
    Core.Interfaces.Settings,
    Data.Database.Security,
    System.IOUtils,
    System.SysUtils
    ;

{$R *.dfm}

procedure ShowDbProfilesForm(const AppContext: IAppContext);
var
    Form: TDbProfilesForm;
begin
    Form := TDbProfilesForm.Create(nil);
    try
        Form.Initialize(AppContext);
        Form.WarmUpPaint;
        Form.PrepareGuardedShow;
        Form.ShowModal;
    finally
        Form.Free;
    end;
end;

// Локализация на показе: форма создаётся динамически, надписи
// выставляются кодом, а не в DFM
procedure TDbProfilesForm.Localize;
var
    Col: TListColumn;
begin
    Caption := TUIStateLoader.GetMessage('Settings.DbProfilesTitle');
    bDelete.Caption := TUIStateLoader.GetMessage('Settings.DbProfilesDelete');
    bCleanup.Caption := TUIStateLoader.GetMessage('Settings.DbProfilesDeleteMissing');
    bClose.Caption := TUIStateLoader.GetMessage('Common.Cancel');
    bClose.ModalResult := mrOk;
    if lvProfiles.Columns.Count = 0 then
    begin
        Col := lvProfiles.Columns.Add;
        Col.Caption := TUIStateLoader.GetMessage('Settings.DbProfilesColDb');
        Col.Width := 330;
        Col := lvProfiles.Columns.Add;
        Col.Caption := TUIStateLoader.GetMessage('Settings.DbProfilesColMode');
        Col.Width := 110;
        Col := lvProfiles.Columns.Add;
        Col.Caption := TUIStateLoader.GetMessage('Settings.DbProfilesColKey');
        Col.Width := 132;
    end;
end;

procedure TDbProfilesForm.FormShow(Sender: TObject);
begin
    Localize;
    PopulateProfilesList;
end;

procedure TDbProfilesForm.PopulateProfilesList;
var
    Setts: TAppSettings;
    I: Integer;
    Item: TListItem;
begin
    Setts := AppContext.SettingsManager.Data;
    lvProfiles.Items.BeginUpdate;
    try
        lvProfiles.Items.Clear;
        for I := 0 to High(Setts.DbProfiles.Items) do
        begin
            Item := lvProfiles.Items.Add;
            Item.Caption := Setts.DbProfiles.Items[I].Path;
            if Setts.DbProfiles.Items[I].KeyMode = DB_KEYMODE_PASSPHRASE then
                Item.SubItems.Add(TUIStateLoader.GetMessage('Settings.DbModePassphrase'))
            else
                Item.SubItems.Add(TUIStateLoader.GetMessage('Settings.DbModeDpapi'));
            if DbStoredKeyMaterial(Setts.DbProfiles.Items[I]) <> '' then
                Item.SubItems.Add(TUIStateLoader.GetMessage('Settings.DbProfilesKeyStored'))
            else
                Item.SubItems.Add(TUIStateLoader.GetMessage('Settings.DbProfilesKeyNotStored'));
        end;
    finally
        lvProfiles.Items.EndUpdate;
    end;
    UpdateButtonsState;
end;

procedure TDbProfilesForm.UpdateButtonsState;
begin
    bDelete.Enabled := lvProfiles.Selected <> nil;
end;

procedure TDbProfilesForm.lvProfilesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
    UpdateButtonsState;
end;

procedure TDbProfilesForm.bDeleteClick(Sender: TObject);
var
    Setts: TAppSettings;
begin
    if lvProfiles.Selected = nil then
        Exit;
    if not MessagesHandler.AskWarning(
        TUIStateLoader.GetMessage('Settings.DbProfilesDeleteAsk'),
        TUIStateLoader.GetMessage('Common.Warning')) then
        Exit;
    Setts := AppContext.SettingsManager.Data;
    DeleteDbProfile(Setts, lvProfiles.Selected.Caption);
    AppContext.SettingsManager.Data := Setts;
    AppContext.SettingsManager.Save;
    PopulateProfilesList;
end;

procedure TDbProfilesForm.bCleanupClick(Sender: TObject);
var
    Setts: TAppSettings;
    I, Removed: Integer;
begin
    Setts := AppContext.SettingsManager.Data;
    Removed := 0;
    // Обратный обход: удаление элемента сдвигает хвост массива
    for I := High(Setts.DbProfiles.Items) downto 0 do
        if not TFile.Exists(Setts.DbProfiles.Items[I].Path) then
        begin
            Setts.DbProfiles.Delete(I);
            Inc(Removed);
        end;
    if Removed > 0 then
    begin
        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;
    end;
    PopulateProfilesList;
    MessagesHandler.ShowInfo(TUIStateLoader.GetMessage(
        'Settings.DbProfilesCleanupDone', [Removed]));
end;

end.
