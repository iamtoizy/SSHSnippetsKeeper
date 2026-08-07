unit WorkspaceManagerUI;

interface

uses
    BaseFormUI,
    Core.Interfaces,
    System.Classes,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Menus,
    Vcl.StdCtrls, System.Actions, Vcl.ActnList
    ;

type
    TWorkspaceManagerForm = class(TBaseForm)
        pBottom: TPanel;
        bOK: TButton;
        bCancel: TButton;
        lvWorkspaces: TListView;
        MainMenu: TMainMenu;
        nWorkspaces: TMenuItem;
        nWorkspaceAdd: TMenuItem;
        nWorkspaceDelete: TMenuItem;
        nWorkspaceRename: TMenuItem;
    ActionList: TActionList;
    actAddWorkspace: TAction;
    actDeleteWorkspace: TAction;
    actEditWorkspace: TAction;
        procedure actAddWorkspaceExecute(Sender: TObject);
        procedure actDeleteWorkspaceExecute(Sender: TObject);
        procedure actEditWorkspaceExecute(Sender: TObject);
        procedure bOKClick(Sender: TObject);
        procedure bCancelClick(Sender: TObject);
        procedure lvWorkspacesEdited(Sender: TObject; Item: TListItem; var S: string);
        procedure FormResize(Sender: TObject);
        procedure FormShow(Sender: TObject);
        procedure lvWorkspacesDblClick(Sender: TObject);
        procedure lvWorkspacesResize(Sender: TObject);
    private
        procedure RefreshWorkspaces;
        procedure DoAddWorkspace;
        procedure DoDeleteWorkspace;
        procedure DoRenameWorkspace;
        procedure AdjustColumnWidth;
    public
        procedure DoInitialize; override;
    end;

var
    WorkspaceManagerForm: TWorkspaceManagerForm;

implementation

uses
    System.SysUtils,
    UI.StateLoader,
    User,
    Vcl.Dialogs,
    Vcl.Forms,
    Winapi.CommCtrl,
    Winapi.Windows
    ;

{$R *.dfm}

procedure TWorkspaceManagerForm.actAddWorkspaceExecute(Sender: TObject);
begin
    DoAddWorkspace;
end;

procedure TWorkspaceManagerForm.actDeleteWorkspaceExecute(Sender: TObject);
begin
    DoDeleteWorkspace;
end;

procedure TWorkspaceManagerForm.actEditWorkspaceExecute(Sender: TObject);
begin
    DoRenameWorkspace;
end;

procedure TWorkspaceManagerForm.RefreshWorkspaces;
var
    Users: TArray<TUserDTO>;
    User: TUserDTO;
    Item: TListItem;
begin
    Users := AppContext.UserService.GetAllUsers;
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
    if not InputQuery(
        TUIStateLoader.GetMessage('WorkspaceManagerForm.NewWorkspaceCaption'),
        TUIStateLoader.GetMessage('WorkspaceManagerForm.NewWorkspaceName'),
        NewName) then Exit;

    NewName := Trim(NewName);
    if NewName = '' then
        Exit;

    try
        UserDTO := Default(TUserDTO);
        UserDTO.Name := NewName;

        // ѕолучаем ID новой записи из сервиса (а не пытаемс€ прочитать UserDTO.ID)
        NewID := AppContext.UserService.AddUser(UserDTO);

        Item := lvWorkspaces.Items.Add;
        Item.Caption := NewName;
        Item.Data := Pointer(NewID);
        Item.Selected := True;
        Item.MakeVisible(False);
    except
        on E: Exception do
            MessagesHandler.ShowError(TUIStateLoader.GetMessage('WorkspaceManagerForm.AddError', [E.Message]));
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
        PChar(TUIStateLoader.GetMessage('WorkspaceManagerForm.DeleteConfirm', [UserName])),
        PChar(TUIStateLoader.GetMessage('Common.Confirmation')),
        MB_YESNO or MB_ICONWARNING) <> IDYES then Exit;

    try
        // Ѕизнес-проверка "ID=1" теперь выполн€етс€ внутри сервиса
        AppContext.UserService.DeleteUser(UserID);
        Item.Delete;
    except
        on E: Exception do
            MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('WorkspaceManagerForm.DeleteError', [E.Message])
            );
    end;
end;

procedure TWorkspaceManagerForm.DoInitialize;
begin
    RefreshWorkspaces;
end;

procedure TWorkspaceManagerForm.DoRenameWorkspace;
begin
    if lvWorkspaces.Selected = nil then
    begin
        MessagesHandler.ShowInfo(
            TUIStateLoader.GetMessage('WorkspaceManagerForm.SelectWorkspaceFirst')
        );
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

        AppContext.UserService.UpdateUser(UserDTO);
    except
        on E: Exception do
        begin
            MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('WorkspaceManagerForm.RenameError', [E.Message])
            );
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
    //  онстанта LVSCW_AUTOSIZE_USEHEADER (-2) приказывает Windows автоматически раст€нуть
    // последнюю колонку на всЄ доступное пространство.
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

end.

