unit SavedQueryEditorFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    System.Classes,
    System.SysUtils,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.StdCtrls,
    Winapi.Messages,
    Winapi.Windows
    ;

type
    TSavedQueryEditorForm = class(TBaseForm)
        lblName: TLabel;
        edName: TEdit;
        lblQuery: TLabel;
        edQuery: TEdit;
        lblHint: TLabel;
        btnOK: TButton;
        btnCancel: TButton;
        procedure btnOKClick(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    private
        FSavedQueryID: Integer;
    protected
        procedure DoInitialize; override;
    public
        property SavedQueryID: Integer read FSavedQueryID;
        procedure Setup(const Name, QueryText: string; SavedQueryID: Integer);
        class function Execute(Owner: TComponent; AppContext: IAppContext;
            SavedQueryID: Integer; const Name, QueryText: string;
            out NewName, NewQueryText: string): Boolean; static;
    end;

implementation

uses
    Common.Localization,
    UI.HoverHelpManager
    ;

{$R *.dfm}

{ TSavedQueryEditorForm }

procedure TSavedQueryEditorForm.Setup(const Name, QueryText: string; SavedQueryID: Integer);
begin
    FSavedQueryID := SavedQueryID;
    edName.Text := Name;
    edQuery.Text := QueryText;
end;

class function TSavedQueryEditorForm.Execute(Owner: TComponent; AppContext: IAppContext;
    SavedQueryID: Integer; const Name, QueryText: string;
    out NewName, NewQueryText: string): Boolean;
var
    Form: TSavedQueryEditorForm;
begin
    NewName := '';
    NewQueryText := '';
    Form := TSavedQueryEditorForm.Create(Owner);
    try
        Form.Initialize(AppContext);
        Form.Setup(Name, QueryText, SavedQueryID);
        Result := Form.ShowModal = mrOk;
        if Result then
        begin
            NewName := Trim(Form.edName.Text);
            NewQueryText := Trim(Form.edQuery.Text);
        end;
    finally
        Form.Free;
    end;
end;

procedure TSavedQueryEditorForm.DoInitialize;
begin
    Caption := TUIStateLoader.GetMessage('SavedQueries.Editor.Caption');
    lblName.Caption := TUIStateLoader.GetMessage('SavedQueries.Editor.NameLabel');
    lblQuery.Caption := TUIStateLoader.GetMessage('SavedQueries.Editor.QueryLabel');
    lblHint.Caption := TUIStateLoader.GetMessage('SavedQueries.Editor.Hint');
    btnOK.Caption := TUIStateLoader.GetMessage('Common.OK');
    btnCancel.Caption := TUIStateLoader.GetMessage('Common.Cancel');

    RegisterHelp(edQuery, hipTopRight, 'Help.SavedQueryEditor.edQuery');
end;

procedure TSavedQueryEditorForm.btnOKClick(Sender: TObject);
begin
    if Trim(edName.Text) = '' then
    begin
        MessagesHandler.ShowError(TUIStateLoader.GetMessage('SavedQueries.Error.EmptyName'));
        Exit;
    end;
    if Trim(edQuery.Text) = '' then
    begin
        MessagesHandler.ShowError(TUIStateLoader.GetMessage('SavedQueries.Error.EmptyQuery'));
        Exit;
    end;

    ModalResult := mrOk;
end;

procedure TSavedQueryEditorForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if Key = VK_ESCAPE then
    begin
        ModalResult := mrCancel;
        Key := 0;
    end;
end;

end.
