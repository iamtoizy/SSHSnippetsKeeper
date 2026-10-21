unit SequenceOrderDialogUI;

interface

uses
    BaseFormUI,
    Core.Entities.Snippet,
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
    TSequenceOrderForm = class(TBaseForm)
        lblHint: TLabel;
        lvOrder: TListView;
        btnUp: TButton;
        btnDown: TButton;
        btnRemove: TButton;
        btnRun: TButton;
        btnCancel: TButton;
        procedure btnUpClick(Sender: TObject);
        procedure btnDownClick(Sender: TObject);
        procedure btnRemoveClick(Sender: TObject);
        procedure btnRunClick(Sender: TObject);
        procedure lvOrderDblClick(Sender: TObject);
        procedure lvOrderSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure FormDestroy(Sender: TObject);
    private
        FItems: TList<TSnippetDTO>;
        procedure RefreshList(KeepIndex: Integer);
        procedure MoveCurrent(Delta: Integer);
        procedure UpdateButtonsState;
        function ListViewHelpOffset(LV: TListView): Integer;
    protected
        procedure DoInitialize; override;
    public
        procedure Setup(const Snippets: TArray<TSnippetDTO>);
        function GetOrdered: TArray<TSnippetDTO>;
        class function Execute(Owner: TComponent; AppContext: IAppContext;
            const Snippets: TArray<TSnippetDTO>; out Ordered: TArray<TSnippetDTO>): Boolean; static;
    end;

implementation

uses
    Common.Localization,
    System.Math,
    UI.HoverHelpManager
    ;

{$R *.dfm}

class function TSequenceOrderForm.Execute(Owner: TComponent; AppContext: IAppContext;
    const Snippets: TArray<TSnippetDTO>; out Ordered: TArray<TSnippetDTO>): Boolean;
var
    Form: TSequenceOrderForm;
begin
    Ordered := nil;
    Form := TSequenceOrderForm.Create(Owner);
    try
        Form.Initialize(AppContext);
        Form.Setup(Snippets);
        Result := Form.ShowModal = mrOk;
        if Result then
            Ordered := Form.GetOrdered;
    finally
        Form.Free;
    end;
end;

procedure TSequenceOrderForm.DoInitialize;
begin
    Caption := TUIStateLoader.GetMessage('MultiSelect.Sequence.Caption');
    lblHint.Caption := TUIStateLoader.GetMessage('MultiSelect.Sequence.Hint');
    lvOrder.Columns[0].Caption := TUIStateLoader.GetMessage('MultiSelect.Sequence.ColNum');
    lvOrder.Columns[1].Caption := TUIStateLoader.GetMessage('MultiSelect.Sequence.ColSnippet');
    btnUp.Caption := TUIStateLoader.GetMessage('MultiSelect.Sequence.Up');
    btnDown.Caption := TUIStateLoader.GetMessage('MultiSelect.Sequence.Down');
    btnRemove.Caption := TUIStateLoader.GetMessage('MultiSelect.Sequence.Remove');
    btnRun.Caption := TUIStateLoader.GetMessage('MultiSelect.Sequence.Run');
    btnCancel.Caption := TUIStateLoader.GetMessage('Common.Cancel');

    FItems := TList<TSnippetDTO>.Create;

    RegisterHelp(lvOrder, hipTopRight, 'Help.SequenceDialog.lvOrder', hkCustomForm, 0, ListViewHelpOffset(lvOrder));
end;

procedure TSequenceOrderForm.FormDestroy(Sender: TObject);
begin
    FreeAndNil(FItems);
end;

procedure TSequenceOrderForm.Setup(const Snippets: TArray<TSnippetDTO>);
var
    Snippet: TSnippetDTO;
begin
    FItems.Clear;
    for Snippet in Snippets do
        FItems.Add(Snippet);
    RefreshList(-1);
end;

function TSequenceOrderForm.GetOrdered: TArray<TSnippetDTO>;
begin
    Result := FItems.ToArray;
end;

procedure TSequenceOrderForm.RefreshList(KeepIndex: Integer);
var
    I: Integer;
begin
    lvOrder.Items.BeginUpdate;
    try
        lvOrder.Items.Clear;
        for I := 0 to FItems.Count - 1 do
            with lvOrder.Items.Add do
            begin
                Caption := (I + 1).ToString;
                SubItems.Add(FItems[I].Title);
                Selected := I = KeepIndex;
                Focused := I = KeepIndex;
            end;
    finally
        lvOrder.Items.EndUpdate;
    end;
    UpdateButtonsState;
end;

procedure TSequenceOrderForm.MoveCurrent(Delta: Integer);
var
    Idx: Integer;
begin
    if lvOrder.Selected = nil then
        Exit;

    Idx := lvOrder.Selected.Index;
    if (Idx + Delta < 0) or (Idx + Delta > FItems.Count - 1) then
        Exit;

    FItems.Move(Idx, Idx + Delta);
    RefreshList(Idx + Delta);
end;

procedure TSequenceOrderForm.UpdateButtonsState;
begin
    btnUp.Enabled := (lvOrder.Selected <> nil) and (lvOrder.Selected.Index > 0);
    btnDown.Enabled := (lvOrder.Selected <> nil) and (lvOrder.Selected.Index < FItems.Count - 1);
    btnRemove.Enabled := lvOrder.Selected <> nil;
    btnRun.Enabled := FItems.Count > 0;
end;

function TSequenceOrderForm.ListViewHelpOffset(LV: TListView): Integer;
var
    HeaderWnd: HWND;
    R: TRect;
begin
    Result := 2;
    HeaderWnd := FindWindowEx(LV.Handle, 0, 'SysHeader32', nil);
    if (HeaderWnd = 0) or not GetWindowRect(HeaderWnd, R) then
        Exit;
    Result := Max(1, MulDiv(R.Bottom - R.Top, 96, LV.CurrentPPI)) + 2;
end;

procedure TSequenceOrderForm.btnUpClick(Sender: TObject);
begin
    MoveCurrent(-1);
end;

procedure TSequenceOrderForm.btnDownClick(Sender: TObject);
begin
    MoveCurrent(1);
end;

procedure TSequenceOrderForm.btnRemoveClick(Sender: TObject);
var
    Idx: Integer;
begin
    if lvOrder.Selected = nil then
        Exit;

    Idx := lvOrder.Selected.Index;
    FItems.Delete(Idx);
    if Idx > FItems.Count - 1 then
        Idx := FItems.Count - 1;
    RefreshList(Idx);
end;

procedure TSequenceOrderForm.btnRunClick(Sender: TObject);
begin
    if FItems.Count = 0 then
        Exit;

    ModalResult := mrOk;
end;

procedure TSequenceOrderForm.lvOrderDblClick(Sender: TObject);
begin
    btnRunClick(btnRun);
end;

procedure TSequenceOrderForm.lvOrderSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
    UpdateButtonsState;
end;

procedure TSequenceOrderForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if Key = VK_ESCAPE then
    begin
        ModalResult := mrCancel;
        Key := 0;
    end
    else if Key = VK_RETURN then
    begin
        btnRunClick(btnRun);
        Key := 0;
    end
    else if (Key = VK_UP) and (ssCtrl in Shift) then
    begin
        MoveCurrent(-1);
        Key := 0;
    end
    else if (Key = VK_DOWN) and (ssCtrl in Shift) then
    begin
        MoveCurrent(1);
        Key := 0;
    end
    else if Key = VK_DELETE then
    begin
        btnRemoveClick(btnRemove);
        Key := 0;
    end;
end;

end.
