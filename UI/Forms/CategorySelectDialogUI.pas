unit CategorySelectDialogUI;

interface

uses
    BaseFormUI,
    Core.Entities.Category,
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
        procedure BuildTree(UserID: Integer);
        procedure AddCategoryNode(ParentNode: TTreeNode; const Categories: TArray<TCategoryDTO>; const Cat: TCategoryDTO);
    protected
        procedure DoInitialize; override;
    public
        property CategoryID: Integer read FCategoryID;
        class function Execute(Owner: TComponent; AppContext: IAppContext; UserID: Integer; out CategoryID: Integer): Boolean; static;
    end;

implementation

uses
    Common.Localization,
    UI.HoverHelpManager
    ;

{$R *.dfm}

class function TCategorySelectForm.Execute(Owner: TComponent; AppContext: IAppContext; UserID: Integer; out CategoryID: Integer): Boolean;
var
    Form: TCategorySelectForm;
begin
    CategoryID := 0;
    Form := TCategorySelectForm.Create(Owner);
    try
        Form.Initialize(AppContext);
        Form.BuildTree(UserID);
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

procedure TCategorySelectForm.BuildTree(UserID: Integer);
var
    Categories: TArray<TCategoryDTO>;
    Cat: TCategoryDTO;
begin
    tvCategories.Items.BeginUpdate;
    try
        tvCategories.Items.Clear;
        Categories := AppContext.CategoryService.GetAllCategories(UserID);
        for Cat in Categories do
            if Cat.ParentID = 0 then
                AddCategoryNode(nil, Categories, Cat);
    finally
        tvCategories.Items.EndUpdate;
    end;

    if tvCategories.Items.Count > 0 then
    begin
        tvCategories.Items.GetFirstNode.Expand(False);
        tvCategories.Items.GetFirstNode.Selected := True;
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
