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
        lblHint: TLabel;
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
        FSelectedTagID: Integer;
        FSelectedTagIDs: TArray<Integer>;
        FForSnippets: Boolean;
        procedure SortTags;
        procedure RefreshList;
        function MatchMask(const Mask, Value: string): Boolean;
        function ListViewHelpOffset(LV: TListView): Integer;
    protected
        procedure DoInitialize; override;
    public
        property SelectedTag: string read FSelectedTag;
        property SelectedTagID: Integer read FSelectedTagID;
        property SelectedTagIDs: TArray<Integer> read FSelectedTagIDs;
        procedure LoadSnippetsTags(const SnippetIDs: TArray<Integer>);
        class function Execute(Owner: TComponent; AppContext: IAppContext; out TagName: string): Boolean; static;
        class function ExecuteForSnippets(Owner: TComponent; AppContext: IAppContext;
            const SnippetIDs: TArray<Integer>; out TagIDs: TArray<Integer>): Boolean; static;
    end;

implementation

uses
    Common.Localization,
    System.Generics.Defaults,
    System.Math,
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

class function TTagSelectForm.ExecuteForSnippets(Owner: TComponent; AppContext: IAppContext;
    const SnippetIDs: TArray<Integer>; out TagIDs: TArray<Integer>): Boolean;
var
    Form: TTagSelectForm;
begin
    TagIDs := nil;
    Form := TTagSelectForm.Create(Owner);
    try
        Form.Initialize(AppContext);
        Form.LoadSnippetsTags(SnippetIDs);
        Result := Form.ShowModal = mrOk;
        if Result then
            TagIDs := Form.SelectedTagIDs;
    finally
        Form.Free;
    end;
end;

procedure TTagSelectForm.DoInitialize;
begin
    Caption := TUIStateLoader.GetMessage('MultiSelect.AddTag.Caption');
    edSearch.TextHint := TUIStateLoader.GetMessage('MultiSelect.AddTag.SearchHint');
    lblHint.Caption := TUIStateLoader.GetMessage('MultiSelect.AddTag.Hint');
    lvTags.Columns[0].Caption := TUIStateLoader.GetMessage('MultiSelect.AddTag.ColTag');
    btnOK.Caption := TUIStateLoader.GetMessage('Common.OK');
    btnCancel.Caption := TUIStateLoader.GetMessage('Common.Cancel');

    FAllTags := AppContext.TagService.GetAllTags;
    SortTags;
    RefreshList;

    RegisterHelp(edSearch, hipTopRight, 'Help.TagSelectDialog.edSearch');
    RegisterHelp(lvTags, hipTopRight, 'Help.TagSelectDialog.lvTags', hkCustomForm, 0, ListViewHelpOffset(lvTags));
end;

procedure TTagSelectForm.LoadSnippetsTags(const SnippetIDs: TArray<Integer>);
var
    Seen: TDictionary<Integer, Boolean>;
    List: TList<TTagDTO>;
    SnippetTags: TArray<TTagDTO>;
    Tag: TTagDTO;
    SnippetID: Integer;
begin
    FForSnippets := True;
    lvTags.MultiSelect := True;
    Caption := TUIStateLoader.GetMessage('MultiSelect.RemoveTag.Caption');
    lblHint.Caption := TUIStateLoader.GetMessage('MultiSelect.RemoveTag.Hint');

    Seen := TDictionary<Integer, Boolean>.Create;
    List := TList<TTagDTO>.Create;
    try
        for SnippetID in SnippetIDs do
        begin
            SnippetTags := AppContext.TagService.GetSnippetTags(SnippetID);
            for Tag in SnippetTags do
                if not Seen.ContainsKey(Tag.ID) then
                begin
                    Seen.Add(Tag.ID, True);
                    List.Add(Tag);
                end;
        end;
        FAllTags := List.ToArray;
    finally
        List.Free;
        Seen.Free;
    end;

    SortTags;
    RefreshList;
end;

function TTagSelectForm.ListViewHelpOffset(LV: TListView): Integer;
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

procedure TTagSelectForm.SortTags;
begin
    TArray.Sort<TTagDTO>(FAllTags, TComparer<TTagDTO>.Construct(
        function(const Left, Right: TTagDTO): Integer
        begin
            Result := CompareText(Left.Name, Right.Name);
        end));
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
var
    I: Integer;
    IDs: TList<Integer>;
begin
    if FForSnippets then
    begin
        if lvTags.SelCount = 0 then
            Exit;

        IDs := TList<Integer>.Create;
        try
            for I := 0 to lvTags.Items.Count - 1 do
                if lvTags.Items[I].Selected then
                    IDs.Add(Integer(IntPtr(lvTags.Items[I].Data)));
            FSelectedTagIDs := IDs.ToArray;
        finally
            IDs.Free;
        end;

        ModalResult := mrOk;
        Exit;
    end;

    if lvTags.Selected <> nil then
    begin
        FSelectedTag := lvTags.Selected.Caption;
        FSelectedTagID := Integer(IntPtr(lvTags.Selected.Data));
    end
    else
    begin
        FSelectedTag := Trim(edSearch.Text);
        FSelectedTagID := 0;
    end;

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
