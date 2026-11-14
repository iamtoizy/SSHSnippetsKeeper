unit AllDatabasesFormUI;

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
    TAllDatabasesForm = class(TBaseForm)
        lvDatabases: TListView;
        bOpen: TButton;
        bCleanup: TButton;
        bDelete: TButton;
        bClose: TButton;
        procedure FormShow(Sender: TObject);
        procedure lvDatabasesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure lvDatabasesDblClick(Sender: TObject);
        procedure bOpenClick(Sender: TObject);
        procedure bDeleteClick(Sender: TObject);
        procedure bCleanupClick(Sender: TObject);
    private
        // Пути показанного списка: индекс строки = индекс в массиве
        FPaths: TArray<string>;
        FCurrentDb: string;
        FSelectedPath: string;
        procedure Localize;
        procedure PopulateList;
        procedure UpdateButtonsState;
        function SelectedPaths: TArray<string>;
    end;

// Модальное окно всех известных путей баз (недавние + профили). Возвращает
// путь, выбранный для открытия ('' = окно закрыто без выбора); удаление
// записей (вместе с профилями шифрования) окно выполняет само
function ShowAllDatabasesForm(const AppContext: IAppContext): string;

implementation

uses
    Common.Localization,
    Common.Settings,
    Core.Interfaces.Settings,
    System.IOUtils,
    System.SysUtils
    ;

{$R *.dfm}

function ShowAllDatabasesForm(const AppContext: IAppContext): string;
var
    Form: TAllDatabasesForm;
begin
    Form := TAllDatabasesForm.Create(nil);
    try
        Form.Initialize(AppContext);
        Form.WarmUpPaint;
        Form.PrepareGuardedShow;
        Form.ShowModal;
        Result := Form.FSelectedPath;
    finally
        Form.Free;
    end;
end;

// Локализация на показе: форма создаётся динамически, надписи
// выставляются кодом, а не в DFM
procedure TAllDatabasesForm.Localize;
var
    Col: TListColumn;
begin
    Caption := TUIStateLoader.GetMessage('AllDatabases.Title');
    bOpen.Caption := TUIStateLoader.GetMessage('AllDatabases.Open');
    bDelete.Caption := TUIStateLoader.GetMessage('AllDatabases.DeleteSelected');
    bCleanup.Caption := TUIStateLoader.GetMessage('AllDatabases.DeleteMissing');
    bClose.Caption := TUIStateLoader.GetMessage('Common.Cancel');
    bClose.ModalResult := mrOk;
    if lvDatabases.Columns.Count = 0 then
    begin
        Col := lvDatabases.Columns.Add;
        Col.Caption := TUIStateLoader.GetMessage('AllDatabases.ColPath');
        Col.Width := 420;
        Col := lvDatabases.Columns.Add;
        Col.Caption := TUIStateLoader.GetMessage('AllDatabases.ColStatus');
        Col.Width := 130;
    end;
end;

procedure TAllDatabasesForm.FormShow(Sender: TObject);
var
    ConnParts: TStringList;
begin
    Localize;

    // Полный путь открытой базы - для пометки «Открыта» в списке
    FCurrentDb := '';
    if Assigned(AppContext.DatabaseManager) and AppContext.DatabaseManager.IsConnected then
    begin
        ConnParts := TStringList.Create;
        try
            ConnParts.Text := AppContext.DatabaseManager.GetConnectionString;
            FCurrentDb := ConnParts.Values['Database'];
        finally
            ConnParts.Free;
        end;
    end;

    PopulateList;
end;

procedure TAllDatabasesForm.PopulateList;
var
    Setts: TAppSettings;
    Paths: TArray<string>;
    I: Integer;
    Item: TListItem;
begin
    Setts := AppContext.SettingsManager.Data;
    Paths := GetAllDatabasePaths(Setts);
    FPaths := Paths;

    lvDatabases.Items.BeginUpdate;
    try
        lvDatabases.Items.Clear;
        for I := 0 to High(Paths) do
        begin
            Item := lvDatabases.Items.Add;
            Item.Caption := Paths[I];
            if SameText(Paths[I], FCurrentDb) then
                Item.SubItems.Add(TUIStateLoader.GetMessage('AllDatabases.StatusOpen'))
            else if TFile.Exists(Paths[I]) then
                Item.SubItems.Add(TUIStateLoader.GetMessage('AllDatabases.StatusAvailable'))
            else
                Item.SubItems.Add(TUIStateLoader.GetMessage('AllDatabases.StatusMissing'));
        end;
    finally
        lvDatabases.Items.EndUpdate;
    end;
    UpdateButtonsState;
end;

procedure TAllDatabasesForm.UpdateButtonsState;
begin
    bOpen.Enabled := (lvDatabases.Selected <> nil) and
        TFile.Exists(lvDatabases.Selected.Caption);
    bDelete.Enabled := lvDatabases.SelCount > 0;
end;

procedure TAllDatabasesForm.lvDatabasesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
    UpdateButtonsState;
end;

function TAllDatabasesForm.SelectedPaths: TArray<string>;
var
    I: Integer;
begin
    SetLength(Result, 0);
    for I := 0 to lvDatabases.Items.Count - 1 do
        if lvDatabases.Items[I].Selected then
        begin
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := lvDatabases.Items[I].Caption;
        end;
end;

procedure TAllDatabasesForm.bOpenClick(Sender: TObject);
begin
    if not bOpen.Enabled then
        Exit;
    FSelectedPath := lvDatabases.Selected.Caption;
    ModalResult := mrOk;
end;

procedure TAllDatabasesForm.lvDatabasesDblClick(Sender: TObject);
begin
    bOpenClick(Sender);
end;

procedure TAllDatabasesForm.bDeleteClick(Sender: TObject);
var
    Setts: TAppSettings;
    Paths: TArray<string>;
    I: Integer;
begin
    Paths := SelectedPaths;
    if Length(Paths) = 0 then
        Exit;
    if not MessagesHandler.AskWarning(
        TUIStateLoader.GetMessage('AllDatabases.DeleteAsk'),
        TUIStateLoader.GetMessage('Common.Warning')) then
        Exit;
    Setts := AppContext.SettingsManager.Data;
    for I := 0 to High(Paths) do
        RemoveRecentDatabase(Setts, Paths[I]);
    AppContext.SettingsManager.Data := Setts;
    AppContext.SettingsManager.Save;
    PopulateList;
end;

procedure TAllDatabasesForm.bCleanupClick(Sender: TObject);
var
    Setts: TAppSettings;
    Removed: Integer;
begin
    Setts := AppContext.SettingsManager.Data;
    Removed := RemoveMissingDatabasePaths(Setts);
    if Removed > 0 then
    begin
        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;
    end;
    PopulateList;
    MessagesHandler.ShowInfo(TUIStateLoader.GetMessage(
        'AllDatabases.CleanupDone', [Removed]));
end;

end.
