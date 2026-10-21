unit ChainEditorFormUI;

interface

uses
    BaseFormUI,
    Core.Entities.Chain,
    Core.Entities.Snippet,
    Core.Entities.User,
    Core.Interfaces.App,
    System.Classes,
    System.Generics.Collections,
    System.SysUtils,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls,
    Winapi.Messages,
    Winapi.Windows
    ;

type
    TChainEditorForm = class(TBaseForm)
        lblName: TLabel;
        edName: TEdit;
        lblSteps: TLabel;
        lvSteps: TListView;
        lblPause: TLabel;
        edPause: TEdit;
        lblPauseHint: TLabel;
        btnMoveUp: TButton;
        btnMoveDown: TButton;
        btnRemoveStep: TButton;
        lblLibrary: TLabel;
        edSearch: TEdit;
        lvLibrary: TListView;
        btnAddStep: TButton;
        lblLibraryHint: TLabel;
        btnOK: TButton;
        btnCancel: TButton;
        procedure btnAddStepClick(Sender: TObject);
        procedure btnRemoveStepClick(Sender: TObject);
        procedure btnMoveUpClick(Sender: TObject);
        procedure btnMoveDownClick(Sender: TObject);
        procedure lvStepsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure lvStepsDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
        procedure lvStepsDragDrop(Sender, Source: TObject; X, Y: Integer);
        procedure lvLibrarySelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure lvLibraryDblClick(Sender: TObject);
        procedure edPauseExit(Sender: TObject);
        procedure edSearchChange(Sender: TObject);
        procedure btnOKClick(Sender: TObject);
        procedure FormDestroy(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    private
        FUserID: Integer;
        FChainID: Integer;
        FSteps: TList<TChainStepDTO>;
        FAllSnippets: TArray<TSnippetDTO>;
        FUsers: TArray<TUserDTO>;
        procedure LoadLibrary;
        procedure ApplySearchFilter;
        procedure RefreshStepsList;
        procedure ReselectStep(Index: Integer);
        function SelectedStepIndex: Integer;
        procedure ApplyPauseEdit;
        procedure UpdateButtonsState;
        function UserNameByID(UserID: Integer): string;
        function ListViewHelpOffset(LV: TListView): Integer;
        procedure FitColumns(LV: TListView);
    protected
        procedure DoInitialize; override;
    public
        procedure Setup(ChainID, InitialSnippetID, DefaultUserID: Integer);
        property ChainID: Integer read FChainID;
    end;

implementation

uses
    Common.Localization,
    System.Math,
    UI.HoverHelpManager
    ;

{$R *.dfm}

{ TChainEditorForm }

procedure TChainEditorForm.DoInitialize;
begin
    Caption := TUIStateLoader.GetMessage('Chains.Editor.CaptionAdd');
    lblName.Caption := TUIStateLoader.GetMessage('Chains.Editor.Name');
    lblSteps.Caption := TUIStateLoader.GetMessage('Chains.Editor.Steps');
    btnAddStep.Caption := TUIStateLoader.GetMessage('Chains.Editor.AddStep');
    btnRemoveStep.Caption := TUIStateLoader.GetMessage('Chains.Editor.RemoveStep');
    btnMoveUp.Caption := TUIStateLoader.GetMessage('Chains.Editor.MoveUp');
    btnMoveDown.Caption := TUIStateLoader.GetMessage('Chains.Editor.MoveDown');
    lblPause.Caption := TUIStateLoader.GetMessage('Chains.Editor.PauseSec');
    lblPauseHint.Caption := TUIStateLoader.GetMessage('Chains.Editor.PauseHint');
    lblLibrary.Caption := TUIStateLoader.GetMessage('Chains.Editor.Library');
    edSearch.TextHint := TUIStateLoader.GetMessage('Chains.Editor.Search');
    lblLibraryHint.Caption := TUIStateLoader.GetMessage('Chains.Editor.LibraryHint');
    lvSteps.Columns[0].Caption := TUIStateLoader.GetMessage('Chains.Editor.ColStep');
    lvSteps.Columns[1].Caption := TUIStateLoader.GetMessage('Chains.Editor.ColSnippet');
    lvSteps.Columns[2].Caption := TUIStateLoader.GetMessage('Chains.Editor.ColPause');
    lvLibrary.Columns[0].Caption := TUIStateLoader.GetMessage('Chains.Editor.ColSnippet');
    lvLibrary.Columns[1].Caption := TUIStateLoader.GetMessage('Chains.Editor.ColWorkspace');
    btnOK.Caption := TUIStateLoader.GetMessage('Common.OK');
    btnCancel.Caption := TUIStateLoader.GetMessage('Common.Cancel');

    FitColumns(lvSteps);
    FitColumns(lvLibrary);

    RegisterHelp(lvSteps, hipTopRight, 'Help.ChainEditorForm.lvSteps', hkCustomForm, 0, ListViewHelpOffset(lvSteps));
    RegisterHelp(edPause, hipTopRight, 'Help.ChainEditorForm.edPause');
    RegisterHelp(lvLibrary, hipTopRight, 'Help.ChainEditorForm.lvLibrary', hkCustomForm, 0, ListViewHelpOffset(lvLibrary));
end;

function TChainEditorForm.ListViewHelpOffset(LV: TListView): Integer;
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

procedure TChainEditorForm.FitColumns(LV: TListView);
var
    I, Used: Integer;
begin
    Used := 0;
    for I := 0 to LV.Columns.Count - 2 do
        Inc(Used, LV.Columns[I].Width);
    LV.Columns[LV.Columns.Count - 1].Width :=
        Max(40, LV.ClientWidth - Used - GetSystemMetrics(SM_CXVSCROLL) - 2);
end;

procedure TChainEditorForm.Setup(ChainID, InitialSnippetID, DefaultUserID: Integer);
var
    Chain: TChainDTO;
    Snippet: TSnippetDTO;
    Step: TChainStepDTO;
begin
    FreeAndNil(FSteps);
    FSteps := TList<TChainStepDTO>.Create;
    FUserID := DefaultUserID;
    FChainID := ChainID;

    if ChainID > 0 then
    begin
        Chain := AppContext.ChainService.GetChainByID(ChainID);
        FUserID := Chain.UserID;
        Caption := TUIStateLoader.GetMessage('Chains.Editor.CaptionEdit');
        edName.Text := Chain.Name;
        FSteps.AddRange(AppContext.ChainService.GetSteps(ChainID));
    end
    else if InitialSnippetID > 0 then
    begin
        Snippet := AppContext.SnippetService.GetSnippetByID(InitialSnippetID);
        FUserID := Snippet.UserID;
        Step := Default(TChainStepDTO);
        Step.SnippetID := Snippet.ID;
        Step.SnippetTitle := Snippet.Title;
        FSteps.Add(Step);
    end;

    LoadLibrary;
    RefreshStepsList;
end;

procedure TChainEditorForm.FormDestroy(Sender: TObject);
begin
    FreeAndNil(FSteps);
end;

procedure TChainEditorForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if not lvSteps.Focused then
        Exit;

    if (Shift = [ssCtrl]) and (Key = VK_UP) then
    begin
        btnMoveUpClick(Sender);
        Key := 0;
    end
    else if (Shift = [ssCtrl]) and (Key = VK_DOWN) then
    begin
        btnMoveDownClick(Sender);
        Key := 0;
    end
    else if (Key = VK_DELETE) and (Shift = []) and (lvSteps.Selected <> nil) then
    begin
        btnRemoveStepClick(Sender);
        Key := 0;
    end;
end;

function TChainEditorForm.UserNameByID(UserID: Integer): string;
var
    User: TUserDTO;
begin
    Result := '';
    for User in FUsers do
        if User.ID = UserID then
            Exit(User.Name);
end;

procedure TChainEditorForm.LoadLibrary;
begin
    FUsers := AppContext.UserService.GetAllUsers;
    FAllSnippets := AppContext.SnippetService.GetAllSnippets(0);
    ApplySearchFilter;
end;

procedure TChainEditorForm.ApplySearchFilter;
var
    Filter: string;
    Snippet: TSnippetDTO;
    Title: string;
begin
    Filter := LowerCase(Trim(edSearch.Text));

    lvLibrary.Items.BeginUpdate;
    try
        lvLibrary.Items.Clear;
        for Snippet in FAllSnippets do
        begin
            if (Filter <> '') and (Pos(Filter, LowerCase(Snippet.Title)) = 0) then
                Continue;

            if Snippet.Title = '' then
                Title := TUIStateLoader.GetMessage('Chains.Editor.Untitled')
            else
                Title := Snippet.Title;

            with lvLibrary.Items.Add do
            begin
                Caption := Title;
                Data := Pointer(IntPtr(Snippet.ID));
                SubItems.Add(UserNameByID(Snippet.UserID));
            end;
        end;
    finally
        lvLibrary.Items.EndUpdate;
    end;
    UpdateButtonsState;
end;

procedure TChainEditorForm.RefreshStepsList;
var
    I: Integer;
    Item: TListItem;
begin
    lvSteps.Items.BeginUpdate;
    try
        lvSteps.Items.Clear;
        for I := 0 to FSteps.Count - 1 do
        begin
            Item := lvSteps.Items.Add;
            Item.Caption := IntToStr(I + 1);
            Item.Data := Pointer(IntPtr(FSteps[I].SnippetID));
            if FSteps[I].SnippetTitle = '' then
                Item.SubItems.Add(TUIStateLoader.GetMessage('Chains.Editor.Untitled'))
            else
                Item.SubItems.Add(FSteps[I].SnippetTitle);
            Item.SubItems.Add(IntToStr(FSteps[I].PauseMs div 1000));
        end;
    finally
        lvSteps.Items.EndUpdate;
    end;
    UpdateButtonsState;
end;

procedure TChainEditorForm.ReselectStep(Index: Integer);
begin
    if (Index >= 0) and (Index < lvSteps.Items.Count) then
    begin
        lvSteps.ItemIndex := Index;
        lvSteps.Selected := lvSteps.Items[Index];
        lvSteps.Selected.Selected := True;
    end;
end;

function TChainEditorForm.SelectedStepIndex: Integer;
begin
    if lvSteps.Selected <> nil then
        Result := lvSteps.Selected.Index
    else
        Result := -1;
end;

procedure TChainEditorForm.UpdateButtonsState;
var
    Index: Integer;
begin
    Index := SelectedStepIndex;
    btnRemoveStep.Enabled := FSteps.Count > 0;
    btnMoveUp.Enabled := Index > 0;
    btnMoveDown.Enabled := (Index >= 0) and (Index < FSteps.Count - 1);
    btnAddStep.Enabled := lvLibrary.Selected <> nil;
end;

procedure TChainEditorForm.btnAddStepClick(Sender: TObject);
var
    Selected: TListItem;
    Step: TChainStepDTO;
begin
    Selected := lvLibrary.Selected;
    if Selected = nil then
        Exit;

    Step := Default(TChainStepDTO);
    Step.SnippetID := Integer(IntPtr(Selected.Data));
    Step.SnippetTitle := Selected.Caption;
    Step.PauseMs := 0;

    FSteps.Add(Step);
    RefreshStepsList;
    ReselectStep(FSteps.Count - 1);
end;

procedure TChainEditorForm.btnRemoveStepClick(Sender: TObject);
var
    Index: Integer;
begin
    Index := SelectedStepIndex;
    if Index < 0 then
        Exit;

    FSteps.Delete(Index);
    RefreshStepsList;
    ReselectStep(Min(Index, FSteps.Count - 1));
end;

procedure TChainEditorForm.btnMoveUpClick(Sender: TObject);
var
    Index: Integer;
begin
    Index := SelectedStepIndex;
    if Index < 1 then
        Exit;

    FSteps.Exchange(Index, Index - 1);
    RefreshStepsList;
    ReselectStep(Index - 1);
end;

procedure TChainEditorForm.btnMoveDownClick(Sender: TObject);
var
    Index: Integer;
begin
    Index := SelectedStepIndex;
    if (Index < 0) or (Index >= FSteps.Count - 1) then
        Exit;

    FSteps.Exchange(Index, Index + 1);
    RefreshStepsList;
    ReselectStep(Index + 1);
end;

procedure TChainEditorForm.lvStepsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
    if Selected and Assigned(Item) then
        edPause.Text := IntToStr(FSteps[Item.Index].PauseMs div 1000);
    UpdateButtonsState;
end;

procedure TChainEditorForm.lvStepsDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
    Accept := (Source = lvSteps) and (lvSteps.Selected <> nil);
end;

procedure TChainEditorForm.lvStepsDragDrop(Sender, Source: TObject; X, Y: Integer);
var
    FromIndex, ToIndex: Integer;
    Step: TChainStepDTO;
begin
    FromIndex := SelectedStepIndex;
    if FromIndex < 0 then
        Exit;

    if lvSteps.DropTarget <> nil then
        ToIndex := lvSteps.DropTarget.Index
    else
        ToIndex := lvSteps.Items.Count - 1;

    if ToIndex = FromIndex then
        Exit;

    Step := FSteps[FromIndex];
    FSteps.Delete(FromIndex);
    FSteps.Insert(ToIndex, Step);
    RefreshStepsList;
    ReselectStep(ToIndex);
end;

procedure TChainEditorForm.lvLibrarySelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
    UpdateButtonsState;
end;

procedure TChainEditorForm.lvLibraryDblClick(Sender: TObject);
begin
    btnAddStepClick(Sender);
end;

procedure TChainEditorForm.ApplyPauseEdit;
var
    Index: Integer;
    Seconds: Integer;
    Step: TChainStepDTO;
begin
    Index := SelectedStepIndex;
    if Index < 0 then
        Exit;

    Seconds := StrToIntDef(Trim(edPause.Text), FSteps[Index].PauseMs div 1000);
    Seconds := Min(Max(Seconds, 0), 86400);

    Step := FSteps[Index];
    Step.PauseMs := Seconds * 1000;
    FSteps[Index] := Step;
    edPause.Text := IntToStr(Seconds);
    if lvSteps.Items[Index] <> nil then
        lvSteps.Items[Index].SubItems[1] := IntToStr(Seconds);
end;

procedure TChainEditorForm.edPauseExit(Sender: TObject);
begin
    ApplyPauseEdit;
end;

procedure TChainEditorForm.edSearchChange(Sender: TObject);
begin
    ApplySearchFilter;
end;

procedure TChainEditorForm.btnOKClick(Sender: TObject);
var
    ChainName: string;
    IsNew: Boolean;
begin
    ChainName := Trim(edName.Text);
    if ChainName = '' then
    begin
        MessagesHandler.ShowError(TUIStateLoader.GetMessage('Chains.Error.EmptyName'));
        Exit;
    end;

    ApplyPauseEdit;

    IsNew := FChainID = 0;
    try
        try
            if IsNew then
                FChainID := AppContext.ChainService.CreateChain(FUserID, ChainName)
            else
                AppContext.ChainService.RenameChain(FChainID, ChainName);

            AppContext.ChainService.SaveSteps(FChainID, FSteps.ToArray);
            ModalResult := mrOk;
        except
            if IsNew and (FChainID > 0) then
            begin
                AppContext.ChainService.DeleteChain(FChainID);
                FChainID := 0;
            end;
            raise;
        end;
    except
        on E: Exception do
            MessagesHandler.ShowError(E.Message);
    end;
end;

end.
