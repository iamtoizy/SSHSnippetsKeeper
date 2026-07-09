unit WorkspaceManagerUI;

interface

uses
    Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
    Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus,
    User,
    UserService; // <-- Подключаем сервис бизнес-логики

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
        procedure lvWorkspacesKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
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
        FUserService: TUserService; // <-- Храним ссылку на сервис

        procedure RefreshWorkspaces; // <-- Вынесли логику загрузки сюда
        procedure DoAddWorkspace;
        procedure DoDeleteWorkspace;
        procedure DoRenameWorkspace;
        procedure AdjustColumnWidth;
    public
        // Внедрение зависимости
        constructor CreateWithService(AOwner: TComponent; AUserService: TUserService);
    end;

var
    WorkspaceManagerForm: TWorkspaceManagerForm;

implementation

{$R *.dfm}

constructor TWorkspaceManagerForm.CreateWithService(AOwner: TComponent; AUserService: TUserService);
begin
    inherited Create(AOwner);
    FUserService := AUserService;

    // Безопасно загружаем данные после того, как сервис инициализирован
    RefreshWorkspaces;
end;

procedure TWorkspaceManagerForm.FormCreate(Sender: TObject);
begin
    lvWorkspaces.OwnerData := False;
    lvWorkspaces.ReadOnly := False; // Разрешаем редактирование
end;

procedure TWorkspaceManagerForm.RefreshWorkspaces;
var
    Users: TArray<TUserDTO>;
    User: TUserDTO;
    Item: TListItem;
begin
    if not Assigned(FUserService) then Exit;

    Users := FUserService.GetAllUsers;
    lvWorkspaces.Items.BeginUpdate;
    try
        lvWorkspaces.Items.Clear;
        for User in Users do
        begin
            Item := lvWorkspaces.Items.Add;
            Item.Caption := User.Name;
            Item.Data := Pointer(NativeInt(User.ID));
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
    NewID: NativeInt;
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
            ShowMessage('Ошибка добавления пространства: ' + E.Message);
    end;
end;

procedure TWorkspaceManagerForm.DoDeleteWorkspace;
var
    Item: TListItem;
    UserID: NativeInt;
    UserName: string;
begin
    Item := lvWorkspaces.Selected;
    if Item = nil then Exit;

    UserID := NativeInt(Item.Data);
    UserName := Item.Caption;

    if MessageBox(Application.Handle,
        PChar(Format('Удалить пространство "%s"?' + sLineBreak +
                     'Все вложенные сниппеты этого пространства будут удалены!', [UserName])),
        'Подтверждение', MB_YESNO or MB_ICONWARNING) <> IDYES then
        Exit;

    try
        // Бизнес-проверка "ID=1" теперь выполняется внутри сервиса!
        FUserService.DeleteUser(UserID);
        Item.Delete;
    except
        on E: Exception do
            ShowMessage('Ошибка удаления пространства: ' + E.Message);
    end;
end;

procedure TWorkspaceManagerForm.DoRenameWorkspace;
begin
    if lvWorkspaces.Selected = nil then
    begin
        ShowMessage('Сначала выберите пространство.');
        Exit;
    end;
    lvWorkspaces.Selected.EditCaption;
end;

procedure TWorkspaceManagerForm.lvWorkspacesKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    case Key of
        VK_INSERT:
            begin
                DoAddWorkspace;
                Key := 0;
            end;
        VK_DELETE:
            begin
                DoDeleteWorkspace;
                Key := 0;
            end;
        VK_F2:
            begin
                DoRenameWorkspace;
                Key := 0;
            end;
    end;
end;

procedure TWorkspaceManagerForm.lvWorkspacesEdited(Sender: TObject; Item: TListItem; var S: string);
var
    UserID: NativeInt;
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

    UserID := NativeInt(Item.Data);

    try
        UserDTO := Default(TUserDTO);
        UserDTO.ID := UserID;
        UserDTO.Name := S;

        FUserService.UpdateUser(UserDTO);
    except
        on E: Exception do
        begin
            ShowMessage('Ошибка переименования пространства: ' + E.Message);
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
    // Константа -2 приказывает Windows автоматически растянуть
    // последнюю колонку на всё доступное пространство.
    lvWorkspaces.Columns[0].Width := -2;
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
