unit WorkspaceManagerUI;

interface

uses
    Winapi.Windows,
    System.SysUtils,
    System.Classes,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.Dialogs,
    Vcl.ComCtrls,
    Vcl.StdCtrls,
    Vcl.ExtCtrls,
    Vcl.Menus,
    User,
    Core.Interfaces,
    UI.Interfaces
    ;

type
    TWorkspaceManagerForm = class(TForm)
        pBottom: TPanel;
        bOK: TButton;
        bCancel: TButton;
        lvWorkspaces: TListView;
        MainMenu: TMainMenu;
        N1: TMenuItem;
        nAdd: TMenuItem;
        nDelete: TMenuItem;
        nRename: TMenuItem;
        procedure bOKClick(Sender: TObject);
        procedure bCancelClick(Sender: TObject);
        procedure lvWorkspacesEdited(Sender: TObject; Item: TListItem; var S: string);
        procedure FormCreate(Sender: TObject);
        procedure FormResize(Sender: TObject);
        procedure FormShow(Sender: TObject);
        procedure lvWorkspacesDblClick(Sender: TObject);
        procedure lvWorkspacesResize(Sender: TObject);
        procedure nAddClick(Sender: TObject);
        procedure nDeleteClick(Sender: TObject);
        procedure nRenameClick(Sender: TObject);
    private
        FUserService: IUserService;
        FErrorHandler: IUIErrorHandler;

        procedure RefreshWorkspaces;
        procedure DoAddWorkspace;
        procedure DoDeleteWorkspace;
        procedure DoRenameWorkspace;
        procedure AdjustColumnWidth;
    public
        // Внедрение зависимости
        constructor Create(Owner: TComponent; UserService: IUserService); reintroduce;
    end;

var
    WorkspaceManagerForm: TWorkspaceManagerForm;

implementation

uses
    Winapi.CommCtrl;

{$R *.dfm}

constructor TWorkspaceManagerForm.Create(Owner: TComponent; UserService: IUserService);
begin
    inherited Create(Owner);
    FUserService := UserService;

    // Безопасно загружаем данные после того, как сервис инициализирован
    RefreshWorkspaces;
end;

procedure TWorkspaceManagerForm.FormCreate(Sender: TObject);
begin
    FErrorHandler := TVCLErrorHandler.Create;
    lvWorkspaces.OwnerData := False;
    lvWorkspaces.ReadOnly := False; // Разрешаем редактирование
end;

procedure TWorkspaceManagerForm.RefreshWorkspaces;
var
    Users: TArray<TUserDTO>;
    User: TUserDTO;
    Item: TListItem;
begin
    if not Assigned(FUserService) then
        Exit;

    Users := FUserService.GetAllUsers;
    lvWorkspaces.Items.BeginUpdate;
    try
        lvWorkspaces.Items.Clear;
        for User in Users do
        begin
            Item := lvWorkspaces.Items.Add;
            Item.Caption := User.Name;
            Item.Data := Pointer(Integer(User.ID));
        end;
    finally
        lvWorkspaces.Items.EndUpdate;
    end;
end;

procedure TWorkspaceManagerForm.DoAddWorkspace;
var
    NewName: string;
    UserDTO: TUserDTO;
    Item: TListItem;
    NewID: Integer;
begin
    if not InputQuery('Новое пространство', 'Введите имя:', NewName) then
        Exit;

    NewName := Trim(NewName);
    if NewName = '' then
        Exit;

    try
        UserDTO := Default(TUserDTO);
        UserDTO.Name := NewName;

        // Получаем ID новой записи из сервиса (а не пытаемся прочитать UserDTO.ID)
        NewID := FUserService.AddUser(UserDTO);

        Item := lvWorkspaces.Items.Add;
        Item.Caption := NewName;
        Item.Data := Pointer(NewID);
        Item.Selected := True;
        Item.MakeVisible(False);
    except
        on E: Exception do
            FErrorHandler.ShowError('Ошибка добавления пространства: ' + E.Message);
    end;
end;

procedure TWorkspaceManagerForm.DoDeleteWorkspace;
var
    Item: TListItem;
    UserID: Integer;
    UserName: string;
begin
    Item := lvWorkspaces.Selected;
    if Item = nil then
        Exit;

    UserID := Integer(Item.Data);
    UserName := Item.Caption;

    if MessageBox(
        Application.Handle,
        PChar(
            Format('Удалить пространство "%s"?' + sLineBreak + 'Все вложенные сниппеты этого пространства будут удалены!',
            [UserName])),
        'Подтверждение',
        MB_YESNO or MB_ICONWARNING) <> IDYES then Exit;

    try
        // Бизнес-проверка "ID=1" теперь выполняется внутри сервиса
        FUserService.DeleteUser(UserID);
        Item.Delete;
    except
        on E: Exception do
            FErrorHandler.ShowError('Ошибка удаления пространства: ' + E.Message);
    end;
end;

procedure TWorkspaceManagerForm.DoRenameWorkspace;
begin
    if lvWorkspaces.Selected = nil then
    begin
        FErrorHandler.ShowInfo('Сначала выберите пространство.');
        Exit;
    end;
    lvWorkspaces.Selected.EditCaption;
end;

procedure TWorkspaceManagerForm.lvWorkspacesEdited(Sender: TObject; Item: TListItem; var S: string);
var
    UserID: Integer;
    OldName: string;
    UserDTO: TUserDTO;
begin
    S := Trim(S);
    OldName := Item.Caption;

    if (S = '') or (S = OldName) then
    begin
        S := OldName;
        Exit;
    end;

    UserID := Integer(Item.Data);

    try
        UserDTO := Default(TUserDTO);
        UserDTO.ID := UserID;
        UserDTO.Name := S;

        FUserService.UpdateUser(UserDTO);
    except
        on E: Exception do
        begin
            FErrorHandler.ShowError('Ошибка переименования пространства: ' + E.Message);
            S := OldName;
        end;
    end;
end;

procedure TWorkspaceManagerForm.bOKClick(Sender: TObject);
begin
    ModalResult := mrOk;
end;

procedure TWorkspaceManagerForm.bCancelClick(Sender: TObject);
begin
    ModalResult := mrCancel;
end;

procedure TWorkspaceManagerForm.AdjustColumnWidth;
begin
    if not Assigned(lvWorkspaces) or (lvWorkspaces.Handle = 0) then
        Exit;
    // Константа LVSCW_AUTOSIZE_USEHEADER (-2) приказывает Windows автоматически растянуть
    // последнюю колонку на всё доступное пространство.
    lvWorkspaces.Columns[0].Width := LVSCW_AUTOSIZE_USEHEADER;
end;

procedure TWorkspaceManagerForm.FormResize(Sender: TObject);
begin
    AdjustColumnWidth;
end;

procedure TWorkspaceManagerForm.FormShow(Sender: TObject);
begin
    AdjustColumnWidth;
end;

procedure TWorkspaceManagerForm.lvWorkspacesDblClick(Sender: TObject);
begin
    DoRenameWorkspace;
end;

procedure TWorkspaceManagerForm.lvWorkspacesResize(Sender: TObject);
begin
    ShowScrollBar(lvWorkspaces.Handle, SB_HORZ, False);
    lvWorkspaces.Columns[0].Width := lvWorkspaces.ClientWidth - 30
end;

procedure TWorkspaceManagerForm.nAddClick(Sender: TObject);
begin
    DoAddWorkspace;
end;

procedure TWorkspaceManagerForm.nDeleteClick(Sender: TObject);
begin
    DoDeleteWorkspace;
end;

procedure TWorkspaceManagerForm.nRenameClick(Sender: TObject);
begin
    DoRenameWorkspace;
end;

end.

