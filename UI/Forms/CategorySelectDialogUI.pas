unit CategorySelectDialogUI;

interface

uses
    BaseFormUI,
    Core.Entities.Category,
    Core.Entities.User,
    Core.Interfaces.App,
    System.Classes,
    System.SysUtils,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.StdCtrls,
    Winapi.Messages,
    Winapi.Windows
    ;

type
    TCategorySelectForm = class(TBaseForm)
        tvCategories: TTreeView;
        btnOK: TButton;
        btnCancel: TButton;
        procedure btnOKClick(Sender: TObject);
        procedure tvCategoriesDblClick(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    private
        FCategoryID: Integer;
        procedure BuildTree(PreferredUserID: Integer);
        procedure AddCategoryNode(ParentNode: TTreeNode; const Categories: TArray<TCategoryDTO>; const Cat: TCategoryDTO);
    protected
        procedure DoInitialize; override;
    public
        property CategoryID: Integer read FCategoryID;
        class function Execute(Owner: TComponent; AppContext: IAppContext; PreferredUserID: Integer; out CategoryID: Integer): Boolean; static;
    end;

implementation

uses
    Common.Localization,
    UI.HoverHelpManager
    ;

{$R *.dfm}

class function TCategorySelectForm.Execute(Owner: TComponent; AppContext: IAppContext; PreferredUserID: Integer; out CategoryID: Integer): Boolean;
var
    Form: TCategorySelectForm;
begin
    CategoryID := 0;
    Form := TCategorySelectForm.Create(Owner);
    try
        Form.Initialize(AppContext);
        Form.BuildTree(PreferredUserID);
        Result := Form.ShowModal = mrOk;
        if Result then
            CategoryID := Form.CategoryID;
    finally
        Form.Free;
    end;
end;

procedure TCategorySelectForm.DoInitialize;
begin
    Caption := TUIStateLoader.GetMessage('MultiSelect.Move.Caption');
    btnOK.Caption := TUIStateLoader.GetMessage('Common.OK');
    btnCancel.Caption := TUIStateLoader.GetMessage('Common.Cancel');

    RegisterHelp(tvCategories, hipTopRight, 'Help.CategorySelectDialog.tvCategories');
end;

procedure TCategorySelectForm.BuildTree(PreferredUserID: Integer);
var
    Users: TArray<TUserDTO>;
    Categories: TArray<TCategoryDTO>;
    User: TUserDTO;
    Cat: TCategoryDTO;
    Root: TTreeNode;
    Node: TTreeNode;
    FirstCategory: TTreeNode;
begin
    tvCategories.Items.BeginUpdate;
    try
        tvCategories.Items.Clear;
        Users := AppContext.UserService.GetAllUsers;
        for User in Users do
        begin
            Root := tvCategories.Items.AddChildObject(nil, User.Name, Pointer(IntPtr(-User.ID)));
            Categories := AppContext.CategoryService.GetAllCategories(User.ID);
            for Cat in Categories do
                if Cat.ParentID = 0 then
                    AddCategoryNode(Root, Categories, Cat);

            if User.ID = PreferredUserID then
            begin
                Root.Expand(True);
                FirstCategory := nil;
                Node := Root.GetFirstChild;
                while Node <> nil do
                begin
                    if Integer(IntPtr(Node.Data)) > 0 then
                    begin
                        FirstCategory := Node;
                        Break;
                    end;
                    Node := Node.GetNextSibling;
                end;
                if FirstCategory <> nil then
                    FirstCategory.Selected := True;
            end;
        end;
    finally
        tvCategories.Items.EndUpdate;
    end;
end;

procedure TCategorySelectForm.AddCategoryNode(ParentNode: TTreeNode; const Categories: TArray<TCategoryDTO>; const Cat: TCategoryDTO);
var
    Child: TCategoryDTO;
    Node: TTreeNode;
begin
    Node := tvCategories.Items.AddChildObject(ParentNode, Cat.Name, Pointer(IntPtr(Cat.ID)));
    for Child in Categories do
        if Child.ParentID = Cat.ID then
            AddCategoryNode(Node, Categories, Child);
end;

procedure TCategorySelectForm.btnOKClick(Sender: TObject);
begin
    if tvCategories.Selected = nil then
        Exit;

    FCategoryID := Integer(IntPtr(tvCategories.Selected.Data));
    if FCategoryID <= 0 then
        Exit;

    ModalResult := mrOk;
end;

procedure TCategorySelectForm.tvCategoriesDblClick(Sender: TObject);
begin
    if tvCategories.Selected <> nil then
        btnOKClick(btnOK);
end;

procedure TCategorySelectForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if Key = VK_ESCAPE then
    begin
        ModalResult := mrCancel;
        Key := 0;
    end
    else if Key = VK_RETURN then
    begin
        btnOKClick(btnOK);
        Key := 0;
    end;
end;

end.
