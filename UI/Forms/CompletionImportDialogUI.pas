unit CompletionImportDialogUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    System.Classes,
    System.Generics.Collections,
    System.SysUtils,
    Vcl.CheckLst,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls,
    Winapi.Messages,
    Winapi.Windows
    ;

type
    TCompletionImportForm = class(TBaseForm)
        edSearch: TEdit;
        lblPrompt: TLabel;
        clbItems: TCheckListBox;
        pMode: TPanel;
        rbMerge: TRadioButton;
        rbReplace: TRadioButton;
        pButtons: TPanel;
        btnAll: TButton;
        btnNone: TButton;
        btnOK: TButton;
        btnCancel: TButton;
        btnHelp: TButton;
        procedure edSearchChange(Sender: TObject);
        procedure clbItemsClickCheck(Sender: TObject);
        procedure btnAllClick(Sender: TObject);
        procedure btnNoneClick(Sender: TObject);
        procedure btnOKClick(Sender: TObject);
        procedure btnHelpClick(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    private
        FItems: TArray<string>;
        // Состояние чекбоксов keyed по имени; переживает фильтрацию списка
        FChecked: TDictionary<string, Boolean>;
        procedure RefreshList;
        function MatchMask(const Mask, Value: string): Boolean;
        procedure SetAllChecked(AValue: Boolean);
        function GetSelectedItems: TArray<string>;
        function GetReplaceItems: Boolean;
    protected
        procedure DoInitialize; override;
    public
        destructor Destroy; override;
        procedure LoadItems(const AItems: TArray<string>);
        property SelectedItems: TArray<string> read GetSelectedItems;
        property ReplaceItems: Boolean read GetReplaceItems;
        class function Execute(Owner: TComponent; AppContext: IAppContext;
            const AItems: TArray<string>; out ASelected: TArray<string>;
            out AReplace: Boolean): Boolean; static;
    end;

implementation

uses
    Common.Localization
    ;

{$R *.dfm}

class function TCompletionImportForm.Execute(Owner: TComponent; AppContext: IAppContext;
    const AItems: TArray<string>; out ASelected: TArray<string>;
    out AReplace: Boolean): Boolean;
var
    Form: TCompletionImportForm;
begin
    ASelected := nil;
    AReplace := False;
    Form := TCompletionImportForm.Create(Owner);
    try
        Form.Initialize(AppContext);
        Form.LoadItems(AItems);
        Result := Form.ShowModal = mrOk;
        if Result then
        begin
            ASelected := Form.SelectedItems;
            AReplace := Form.ReplaceItems;
        end;
    finally
        Form.Free;
    end;
end;

destructor TCompletionImportForm.Destroy;
begin
    FreeAndNil(FChecked);
    inherited Destroy;
end;

procedure TCompletionImportForm.DoInitialize;
begin
    Caption := TUIStateLoader.GetMessage('CompletionImport.Caption');
    lblPrompt.Caption := TUIStateLoader.GetMessage('CompletionImport.Prompt');
    edSearch.TextHint := TUIStateLoader.GetMessage('CompletionImport.SearchHint');
    btnAll.Caption := TUIStateLoader.GetMessage('CompletionImport.SelectAll');
    btnNone.Caption := TUIStateLoader.GetMessage('CompletionImport.SelectNone');
    rbMerge.Caption := TUIStateLoader.GetMessage('CompletionImport.ModeMerge');
    rbReplace.Caption := TUIStateLoader.GetMessage('CompletionImport.ModeReplace');
    btnOK.Caption := TUIStateLoader.GetMessage('Common.OK');
    btnCancel.Caption := TUIStateLoader.GetMessage('Common.Cancel');

    FChecked := TDictionary<string, Boolean>.Create;
end;

procedure TCompletionImportForm.LoadItems(const AItems: TArray<string>);
var
    Name: string;
begin
    FItems := AItems;
    for Name in FItems do
        FChecked.AddOrSetValue(Name, True);
    RefreshList;
end;

function TCompletionImportForm.MatchMask(const Mask, Value: string): Boolean;
begin
    if Mask = '' then
        Exit(True);
    Result := Pos(LowerCase(Mask), LowerCase(Value)) > 0;
end;

procedure TCompletionImportForm.RefreshList;
var
    Name: string;
    Mask: string;
begin
    Mask := Trim(edSearch.Text);
    clbItems.Items.BeginUpdate;
    try
        clbItems.Items.Clear;
        for Name in FItems do
        begin
            if not MatchMask(Mask, Name) then
                Continue;
            clbItems.Items.Add(Name);
            clbItems.Checked[clbItems.Items.Count - 1] := FChecked[Name];
        end;
    finally
        clbItems.Items.EndUpdate;
    end;
end;

procedure TCompletionImportForm.edSearchChange(Sender: TObject);
begin
    RefreshList;
end;

procedure TCompletionImportForm.clbItemsClickCheck(Sender: TObject);
begin
    if clbItems.ItemIndex >= 0 then
        FChecked.AddOrSetValue(clbItems.Items[clbItems.ItemIndex],
            clbItems.Checked[clbItems.ItemIndex]);
end;

procedure TCompletionImportForm.SetAllChecked(AValue: Boolean);
var
    I: Integer;
begin
    for I := 0 to clbItems.Items.Count - 1 do
    begin
        clbItems.Checked[I] := AValue;
        FChecked.AddOrSetValue(clbItems.Items[I], AValue);
    end;
end;

procedure TCompletionImportForm.btnAllClick(Sender: TObject);
begin
    SetAllChecked(True);
end;

procedure TCompletionImportForm.btnNoneClick(Sender: TObject);
begin
    SetAllChecked(False);
end;

function TCompletionImportForm.GetSelectedItems: TArray<string>;
var
    Pair: TPair<string, Boolean>;
    List: TList<string>;
begin
    List := TList<string>.Create;
    try
        for Pair in FChecked do
            if Pair.Value then
                List.Add(Pair.Key);
        List.Sort;
        Result := List.ToArray;
    finally
        List.Free;
    end;
end;

function TCompletionImportForm.GetReplaceItems: Boolean;
begin
    Result := rbReplace.Checked;
end;

procedure TCompletionImportForm.btnOKClick(Sender: TObject);
begin
    if Length(GetSelectedItems) = 0 then
    begin
        MessagesHandler.ShowWarning(TUIStateLoader.GetMessage('CompletionImport.NothingSelected'));
        Exit;
    end;
    ModalResult := mrOk;
end;

procedure TCompletionImportForm.btnHelpClick(Sender: TObject);
var
    Title, MainText, ExpText: string;
begin
    TUIStateLoader.GetHelpTexts('Help.CompletionImportDialog', Title, MainText, ExpText);
    ShowCustomHelpHtml(Title, MainText);
end;

procedure TCompletionImportForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
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
