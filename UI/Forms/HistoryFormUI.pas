unit HistoryFormUI;

interface

uses
    BaseFormUI,
    Core.Entities.Snippet,
    Core.Interfaces.App,
    Core.Interfaces.Services,
    Core.Interfaces.UI,
    Core.TextDiff,
    SynEdit,
    System.Classes,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Graphics,
    Vcl.StdCtrls
    ;

type
    THistoryForm = class(TBaseForm)
        pBottom: TPanel;
        bRestore: TButton;
        bClose: TButton;
        mDiff: TSynEdit;
        lvVersions: TListView;
        procedure bCloseClick(Sender: TObject);
        procedure bRestoreClick(Sender: TObject);
        procedure lvVersionsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure mDiffSpecialLineColors(Sender: TObject; Line: Integer;
            var Special: Boolean; var FG, BG: TColor);
    protected
        procedure DoInitialize; override;
    private
        FSnippetID: Integer;
        FVersions: TArray<TSnippetVersionDTO>;
        FDiffLines: TArray<TDiffLine>;
        FCurrentContent: string;
        FSelectedVersionID: Integer;
        FRestoredVersion: TSnippetVersionDTO;

        procedure LoadVersions;
        procedure ShowVersionDiff(Index: Integer);
    public
        property SnippetID: Integer read FSnippetID write FSnippetID;

        class function Execute(Owner: TComponent; AppContext: IAppContext;
            ASnippetID: Integer; out RestoredVersion: TSnippetVersionDTO): Boolean;
    end;

implementation

{$R *.dfm}

uses
    Common.Localization,
    SynThemeAdapter,
    System.SysUtils,
    System.UITypes
    ;

{ THistoryForm }

class function THistoryForm.Execute(Owner: TComponent; AppContext: IAppContext;
    ASnippetID: Integer; out RestoredVersion: TSnippetVersionDTO): Boolean;
var
    Frm: THistoryForm;
begin
    RestoredVersion := Default(TSnippetVersionDTO);

    Frm := THistoryForm.Create(Owner);
    try
        Frm.LockDrawing;
        try
            Frm.SnippetID := ASnippetID;
            Frm.Initialize(AppContext);
        finally
            Frm.UnlockDrawing;
        end;
        Frm.WarmUpPaint;
        Frm.PrepareGuardedShow;
        Result := (Frm.ShowModal = mrOk);
        if Result then
            RestoredVersion := Frm.FRestoredVersion;
    finally
        Frm.Free;
    end;
end;

procedure THistoryForm.DoInitialize;
begin
    inherited;
    TSynThemeAdapter.ApplyTheme(mDiff);
    LoadVersions;
end;

procedure THistoryForm.LoadVersions;
var
    I: Integer;
    Item: TListItem;
    Ver: TSnippetVersionDTO;
    Current: TSnippetDTO;
begin
    FVersions := AppContext.HistoryService.GetVersions(FSnippetID);
    Current := AppContext.SnippetService.GetSnippetByID(FSnippetID);
    FCurrentContent := Current.Content;
    FRestoredVersion := Default(TSnippetVersionDTO);
    FSelectedVersionID := 0;
    FDiffLines := [];

    lvVersions.Items.BeginUpdate;
    try
        lvVersions.Items.Clear;

        Item := lvVersions.Items.Add;
        Item.Caption := FormatDateTime('dd.mm.yyyy hh:nn:ss',
            AppContext.EpochService.UnixToLocal(Current.UpdatedAt));
        if Current.Title.IsEmpty then
            Item.SubItems.Add(TUIStateLoader.GetMessage('History.CurrentRow'))
        else
            Item.SubItems.Add(TUIStateLoader.GetMessage('History.CurrentRow') +
                ': ' + Current.Title);
        Item.SubItems.Add(Length(Current.Content).ToString);
        Item.Data := Pointer(IntPtr(0));

        for I := 0 to High(FVersions) do
        begin
            Ver := FVersions[I];
            Item := lvVersions.Items.Add;
            Item.Caption := FormatDateTime('dd.mm.yyyy hh:nn:ss',
                AppContext.EpochService.UnixToLocal(Ver.ChangedAt));
            Item.SubItems.Add(Ver.Title);
            Item.SubItems.Add(Length(Ver.Content).ToString);
            Item.Data := Pointer(IntPtr(Ver.ID));
        end;
    finally
        lvVersions.Items.EndUpdate;
    end;

    mDiff.Lines.Clear;
    bRestore.Enabled := False;

    if lvVersions.Items.Count > 0 then
        lvVersions.ItemIndex := 0;
end;

procedure THistoryForm.ShowVersionDiff(Index: Integer);
var
    Line: TDiffLine;
begin
    if (Index < 0) or (Index > High(FVersions) + 1) then
        Exit;

    if Index = 0 then
    begin
        FSelectedVersionID := 0;
        FDiffLines := [];
        mDiff.Lines.BeginUpdate;
        try
            mDiff.Lines.Text := FCurrentContent;
            mDiff.TopLine := 1;
        finally
            mDiff.Lines.EndUpdate;
        end;
        bRestore.Enabled := False;
        Exit;
    end;

    FSelectedVersionID := FVersions[Index - 1].ID;

    FDiffLines := TTextDiff.ToUnified(FCurrentContent,
        FVersions[Index - 1].Content, 3);

    mDiff.Lines.BeginUpdate;
    try
        mDiff.Lines.Clear;
        for Line in FDiffLines do
            mDiff.Lines.Add(Line.Text);
        mDiff.TopLine := 1;
    finally
        mDiff.Lines.EndUpdate;
    end;

    bRestore.Enabled := True;
end;

procedure THistoryForm.lvVersionsSelectItem(Sender: TObject; Item: TListItem;
    Selected: Boolean);
begin
    if Selected and Assigned(Item) then
        ShowVersionDiff(Item.Index);
end;

procedure THistoryForm.mDiffSpecialLineColors(Sender: TObject; Line: Integer;
    var Special: Boolean; var FG, BG: TColor);
begin
    Special := False;
    if (Line >= 1) and (Line <= Length(FDiffLines)) then
        case FDiffLines[Line - 1].Kind of
            dlInsert:
                begin
                    Special := True;
                    FG := clGreen;
                    BG := TColor($D8F0D8);
                end;
            dlDelete:
                begin
                    Special := True;
                    FG := clRed;
                    BG := TColor($F0D8D8);
                end;
        end;
end;

procedure THistoryForm.bCloseClick(Sender: TObject);
begin
    ModalResult := mrCancel;
end;

procedure THistoryForm.bRestoreClick(Sender: TObject);
var
    Ver, Found: TSnippetVersionDTO;
    IsFound: Boolean;
begin
    if FSelectedVersionID <= 0 then
        Exit;

    IsFound := False;
    for Ver in FVersions do
        if Ver.ID = FSelectedVersionID then
        begin
            Found := Ver;
            IsFound := True;
            Break;
        end;

    if not IsFound then
        Exit;

    if not MessagesHandler.AskWarning(
        TUIStateLoader.GetMessage('History.RestoreConfirm',
            [FormatDateTime('dd.mm.yyyy hh:nn:ss',
                AppContext.EpochService.UnixToLocal(Found.ChangedAt))]),
        TUIStateLoader.GetMessage('History.Caption'))
    then
        Exit;

    try
        AppContext.HistoryService.RestoreVersion(FSnippetID, FSelectedVersionID);
        FRestoredVersion := Found;
        ModalResult := mrOk;
    except
        on E: Exception do
            MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('History.RestoreError', [E.Message]));
    end;
end;

end.
