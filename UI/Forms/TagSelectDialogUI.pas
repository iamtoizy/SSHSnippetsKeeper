unit TagSelectDialogUI;

interface

uses
    BaseFormUI,
    Core.Entities.Tag,
    Core.Interfaces.App,
    System.Classes,
    System.Generics.Collections,
    System.SysUtils,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.StdCtrls,
    Winapi.Messages,
    Winapi.Windows
    ;

type
    TTagSelectForm = class(TBaseForm)
        edSearch: TEdit;
        lvTags: TListView;
        btnOK: TButton;
        btnCancel: TButton;
        procedure edSearchChange(Sender: TObject);
        procedure lvTagsDblClick(Sender: TObject);
        procedure btnOKClick(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    private
        FAllTags: TArray<TTagDTO>;
        FSelectedTag: string;
        procedure RefreshList;
        function MatchMask(const Mask, Value: string): Boolean;
    protected
        procedure DoInitialize; override;
    public
        property SelectedTag: string read FSelectedTag;
        class function Execute(Owner: TComponent; AppContext: IAppContext; out TagName: string): Boolean; static;
    end;

implementation

uses
    Common.Localization,
    System.Generics.Defaults,
    UI.HoverHelpManager
    ;

{$R *.dfm}

class function TTagSelectForm.Execute(Owner: TComponent; AppContext: IAppContext; out TagName: string): Boolean;
var
    Form: TTagSelectForm;
begin
    TagName := '';
    Form := TTagSelectForm.Create(Owner);
    try
        Form.Initialize(AppContext);
        Result := Form.ShowModal = mrOk;
        if Result then
            TagName := Form.SelectedTag;
    finally
        Form.Free;
    end;
end;

procedure TTagSelectForm.DoInitialize;
begin
    Caption := TUIStateLoader.GetMessage('MultiSelect.AddTag.Caption');
    edSearch.TextHint := TUIStateLoader.GetMessage('MultiSelect.AddTag.SearchHint');
    lvTags.Columns[0].Caption := TUIStateLoader.GetMessage('MultiSelect.AddTag.ColTag');
    btnOK.Caption := TUIStateLoader.GetMessage('Common.OK');
    btnCancel.Caption := TUIStateLoader.GetMessage('Common.Cancel');

    FAllTags := AppContext.TagService.GetAllTags;
    TArray.Sort<TTagDTO>(FAllTags, TComparer<TTagDTO>.Construct(
        function(const Left, Right: TTagDTO): Integer
        begin
            Result := CompareText(Left.Name, Right.Name);
        end));
    RefreshList;

    RegisterHelp(edSearch, hipTopRight, 'Help.TagSelectDialog.edSearch');
    RegisterHelp(lvTags, hipTopRight, 'Help.TagSelectDialog.lvTags');
end;

function TTagSelectForm.MatchMask(const Mask, Value: string): Boolean;
begin
    if Mask = '' then
        Exit(True);
    Result := Pos(LowerCase(Mask), LowerCase(Value)) > 0;
end;

procedure TTagSelectForm.RefreshList;
var
    Tag: TTagDTO;
    Mask: string;
begin
    Mask := Trim(edSearch.Text);
    lvTags.Items.BeginUpdate;
    try
        lvTags.Items.Clear;
        for Tag in FAllTags do
        begin
            if not MatchMask(Mask, Tag.Name) then
                Continue;
            with lvTags.Items.Add do
            begin
                Caption := Tag.Name;
                Data := Pointer(IntPtr(Tag.ID));
            end;
        end;
    finally
        lvTags.Items.EndUpdate;
    end;
end;

procedure TTagSelectForm.edSearchChange(Sender: TObject);
begin
    RefreshList;
end;

procedure TTagSelectForm.lvTagsDblClick(Sender: TObject);
begin
    if lvTags.Selected <> nil then
        btnOKClick(btnOK);
end;

procedure TTagSelectForm.btnOKClick(Sender: TObject);
begin
    if lvTags.Selected <> nil then
        FSelectedTag := lvTags.Selected.Caption
    else
        FSelectedTag := Trim(edSearch.Text);

    if FSelectedTag = '' then
        Exit;

    ModalResult := mrOk;
end;

procedure TTagSelectForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
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
