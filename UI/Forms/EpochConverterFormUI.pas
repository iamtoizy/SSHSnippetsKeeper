unit EpochConverterFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces,
    SynEdit,
    System.Classes,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.Graphics,
    Vcl.Menus,
    Vcl.StdCtrls
    ;

type
    TEpochConverterForm = class(TBaseForm)
        gbParse: TGroupBox;
        tmrLiveUpdate: TTimer;
        pBottom: TPanel;
        gbDetectedDateTime: TGroupBox;
        bCopyLocal: TButton;
        lbISO: TLabel;
        lbDetectedFormat: TLabel;
        lbLocal: TLabel;
        lbRelative: TLabel;
        lbUTC: TLabel;
        bCopyISO: TButton;
        bCopyUTC: TButton;
        bNow: TButton;
        ebISO: TEdit;
        ebLocal: TEdit;
        ebUTC: TEdit;
        dtpDate: TDateTimePicker;
        dtpTime: TDateTimePicker;
        lvParsed: TListView;
        bCopySource: TButton;
        ebSourceTime: TEdit;
        lbSourceTime: TLabel;
        mEpoch: TSynEdit;
        PopupMenu: TPopupMenu;
        nCut: TMenuItem;
        nCopy: TMenuItem;
        nPaste: TMenuItem;
        N4: TMenuItem;
        nSelectAll: TMenuItem;
        N1: TMenuItem;
        nToggleBookmark: TMenuItem;
        nBookmarks: TMenuItem;

        procedure FormDestroy(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure bNowClick(Sender: TObject);
        procedure dtpChange(Sender: TObject);
        procedure tmrLiveUpdateTimer(Sender: TObject);
        procedure FormResize(Sender: TObject);
        procedure FormShow(Sender: TObject);
        procedure lvParsedClick(Sender: TObject);
        procedure lvParsedResize(Sender: TObject);
        procedure lvParsedSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure mEpochChange(Sender: TObject);
        procedure mEpochPaintTransient(Sender: TObject; Canvas: TCanvas; TransientType: TTransientType);
        procedure CopyToClipboardClick(Sender: TObject);
        procedure FormClose(Sender: TObject; var Action: TCloseAction);
        procedure mEpochMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

        // НОВОЕ СОБЫТИЕ: Обработка клавиатуры для mEpoch
        procedure mEpochKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

        procedure nCopyClick(Sender: TObject);
        procedure nCutClick(Sender: TObject);
        procedure nPasteClick(Sender: TObject);
        procedure nSelectAllClick(Sender: TObject);
        procedure nToggleBookmarkClick(Sender: TObject);
    private
        class var FCurrentInstance: TEpochConverterForm;

        FCurrentParsedEpoch: Int64;
        FIsValidEpoch: Boolean;
        FMatches: TArray<TEpochMatch>;
        FUpdatingUI: Boolean;

        procedure UpdateRelativeTime;
        procedure UpdateListViewRelativeTimes;
        procedure GenerateTimestamp;
        procedure ResizeLVColumns;
        procedure DisplayTime;
        procedure OnBookmarkMenuItemClick(Sender: TObject);
    public
        class procedure ExecuteGlobal(Owner: TComponent; AppContext: IAppContext);
        procedure Initialize(AppContext: IAppContext);
    end;

var
    EpochConverterForm: TEpochConverterForm;

implementation

uses
    CommonHelpers,
    SynEditKeyCmds,
    SynEditTypes,
    SynThemeAdapter,
    System.RegularExpressions,
    System.SysUtils,
    UI.HoverHelpManager,
    UI.StateLoader,
    Vcl.Clipbrd,
    Winapi.ActiveX,
    Winapi.CommCtrl,
    Winapi.Windows
    ;

{$R *.dfm}

procedure TEpochConverterForm.FormDestroy(Sender: TObject);
begin
    if mEpoch.HandleAllocated then RevokeDragDrop(mEpoch.Handle);
end;

procedure TEpochConverterForm.FormCreate(Sender: TObject);
var
    I: Integer;
    Cmd: TSynEditorCommand;
begin
    dtpDate.OnChange := dtpChange;
    dtpTime.OnChange := dtpChange;

    bCopySource.Tag := 0;
    bCopyLocal.Tag  := 1;
    bCopyUTC.Tag    := 2;
    bCopyISO.Tag    := 3;

    bCopyLocal.OnClick := CopyToClipboardClick;
    bCopyUTC.OnClick   := CopyToClipboardClick;
    bCopyISO.OnClick   := CopyToClipboardClick;

    TSynThemeAdapter.ApplyTheme(mEpoch);

    mEpoch.Gutter.Visible := True;
    mEpoch.Gutter.ShowLineNumbers := True;
    mEpoch.WordWrap := False;
    mEpoch.ScrollOptions := mEpoch.ScrollOptions + [eoScrollPastEOL];
    mEpoch.OnChange := mEpochChange;
    mEpoch.OnPaintTransient := mEpochPaintTransient;
    mEpoch.OnKeyDown := mEpochKeyDown;

    // Отключаем системные закладки SynEdit (ecSetMarker0..9), так как теперь
    // мы будем управлять ими вручную, чтобы избежать дублей и потери фокуса из-за ALT
    for I := 0 to mEpoch.Keystrokes.Count - 1 do
    begin
        Cmd := mEpoch.Keystrokes[I].Command;
        if (Cmd >= ecSetMarker0) and (Cmd <= ecSetMarker9) then
            mEpoch.Keystrokes[I].ShortCut := 0;
    end;
end;

procedure TEpochConverterForm.mEpochKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
    Digit, I, MarkX, MarkY: Integer;
    IsToggleOff: Boolean;
begin
    // Перехватываем комбинацию CTRL+ALT+(цифра от 0 до 9)
    if (Shift = [ssCtrl, ssAlt]) and (Key >= Ord('0')) and (Key <= Ord('9')) then
    begin
        Digit := Key - Ord('0');
        IsToggleOff := False;

        // Ищем любые другие закладки на текущей строке и удаляем их
        for I := 0 to 9 do
        begin
            MarkX := 0;
            MarkY := 0;
            mEpoch.GetBookMark(I, MarkX, MarkY);

            // Если закладка стоит на текущей строке курсора
            if (MarkY > 0) and (MarkY = mEpoch.CaretY) then
            begin
                mEpoch.ClearBookMark(I);

                // Если мы нажали ту же самую цифру, которая уже стояла,
                // мы просто снимаем закладку (режим Toggle)
                if I = Digit then
                    IsToggleOff := True;
            end;
        end;

        // Если мы не выключали эту же самую закладку, ставим новую
        if not IsToggleOff then
            mEpoch.SetBookMark(Digit, mEpoch.CaretX, mEpoch.CaretY);

        // Обнуляем Key.
        // Это скажет Windows, что комбинация клавиш обработана,
        // и не нужно передавать фокус в главное меню формы по нажатию ALT.
        Key := 0;
    end;
end;

class procedure TEpochConverterForm.ExecuteGlobal(Owner: TComponent; AppContext: IAppContext);
begin
    // Если окно уже открыто - просто выводим его наверх
    if Assigned(FCurrentInstance) then
    begin
        if FCurrentInstance.WindowState = wsMinimized then
            FCurrentInstance.WindowState := wsNormal;
        SetForegroundWindow(FCurrentInstance.Handle);
        FCurrentInstance.BringToFront;
        Exit;
    end;

    // Иначе создаем новое.
    FCurrentInstance := TEpochConverterForm.Create(Application);
    FCurrentInstance.Initialize(AppContext);
    FCurrentInstance.FormStyle := fsStayOnTop;

    FCurrentInstance.Show;
end;

procedure TEpochConverterForm.FormShow(Sender: TObject);
begin
    FUpdatingUI := True;
    try
        dtpDate.Date := Date;
        dtpTime.Time := Time;
    finally
        FUpdatingUI := False;
    end;
    GenerateTimestamp;

    if Clipboard.HasFormat(CF_TEXT) then
    begin
        if TRegEx.IsMatch(Clipboard.AsText, '\b[1-9]\d{8,15}(?:[\.,]\d{1,6})?\b') then
            mEpoch.Text := Clipboard.AsText;
    end;
end;

procedure TEpochConverterForm.UpdateRelativeTime;
var
    LocalParsedTime: TDateTime;
begin
    if not FIsValidEpoch or not Assigned(FAppContext) then Exit;

    LocalParsedTime := FAppContext.EpochService.UnixToLocal(FCurrentParsedEpoch);
    lbRelative.Caption := FAppContext.EpochService.GetRelativeTimeHumanized(LocalParsedTime);
end;

procedure TEpochConverterForm.UpdateListViewRelativeTimes;
var
    I: Integer;
    LocalTime: TDateTime;
begin
    if (lvParsed.Items.Count = 0) or (Length(FMatches) <> lvParsed.Items.Count) or not Assigned(FAppContext) then
        Exit;

    lvParsed.Items.BeginUpdate;
    try
        for I := 0 to lvParsed.Items.Count - 1 do
        begin
            LocalTime := FAppContext.EpochService.UnixToLocal(FMatches[I].UnixSeconds);
            lvParsed.Items[I].SubItems[1] := FAppContext.EpochService.GetRelativeTimeHumanized(LocalTime);
        end;
    finally
        lvParsed.Items.EndUpdate;
    end;
end;

procedure TEpochConverterForm.tmrLiveUpdateTimer(Sender: TObject);
begin
    UpdateRelativeTime;
    UpdateListViewRelativeTimes;
end;

procedure TEpochConverterForm.bNowClick(Sender: TObject);
begin
    FUpdatingUI := True;
    try
        dtpDate.Date := Date;
        dtpTime.Time := Time;
    finally
        FUpdatingUI := False;
    end;

    GenerateTimestamp;

    if Assigned(lvParsed.Selected) then
    begin
        lvParsed.Selected := nil;
        mEpoch.Invalidate;
    end;
end;

procedure TEpochConverterForm.dtpChange(Sender: TObject);
begin
    if FUpdatingUI then Exit;

    GenerateTimestamp;

    if Assigned(lvParsed.Selected) then
    begin
        lvParsed.Selected := nil;
        mEpoch.Invalidate;
    end;
end;

procedure TEpochConverterForm.GenerateTimestamp;
var
    CombinedTime: TDateTime;
    EpochResult: Int64;
begin
    if not Assigned(FAppContext) or not Assigned(FAppContext.EpochService) then Exit;

    CombinedTime := Trunc(dtpDate.Date) + Frac(dtpTime.Time);
    EpochResult := FAppContext.EpochService.LocalToUnix(CombinedTime);

    FCurrentParsedEpoch := EpochResult;
    FIsValidEpoch := True;

    ebSourceTime.Text := IntToStr(EpochResult);
    ebLocal.Text      := DateTimeToStr(FAppContext.EpochService.UnixToLocal(EpochResult));
    ebUTC.Text        := DateTimeToStr(FAppContext.EpochService.UnixToUTC(EpochResult));
    ebISO.Text        := FAppContext.EpochService.FormatISO8601(FAppContext.EpochService.UnixToUTC(EpochResult));

    lbDetectedFormat.Caption := TUIStateLoader.GetMessage('Epoch.Format-seconds');

    UpdateRelativeTime;
    tmrLiveUpdate.Enabled := True;
end;

procedure TEpochConverterForm.Initialize(AppContext: IAppContext);
begin
    inherited Initialize(AppContext);

    RegisterHelp(mEpoch,   hipBottomRight, 'Help.EpochConverterForm.mEpoch',   hkCustomForm);
    RegisterHelp(lvParsed, hipBottomRight, 'Help.EpochConverterForm.lvParsed', hkCustomForm);
end;

procedure TEpochConverterForm.CopyToClipboardClick(Sender: TObject);
var
    TargetText: string;
    BtnTag: Integer;
begin
    BtnTag := (Sender as TComponent).Tag;
    TargetText := '';

    case BtnTag of
        0: TargetText := ebSourceTime.Text;
        1: TargetText := ebLocal.Text;
        2: TargetText := ebUTC.Text;
        3: TargetText := ebISO.Text;
    end;

    if (TargetText <> '') then
    begin
        Clipboard.AsText := TargetText;
        ShowSimpleToast(TUIStateLoader.GetMessage('Common.CopiedToClipboard'));
    end;
end;

procedure TEpochConverterForm.DisplayTime;
var
    Match: TEpochMatch;
    LI: TListItem;
    LocalTime: TDateTime;
begin
    if mEpoch.Text = '' then
    begin
        lvParsed.Items.Clear;
        SetLength(FMatches, 0);
        Exit;
    end;

    FMatches := FAppContext.EpochService.ExtractAllTimestamps(mEpoch.Lines);

    lvParsed.Items.BeginUpdate;
    try
        lvParsed.Items.Clear;
        for Match in FMatches do
        begin
            LocalTime := FAppContext.EpochService.UnixToLocal(Match.UnixSeconds);

            LI := lvParsed.Items.Add;
            LI.Caption := Match.RawText;
            LI.SubItems.Add(DateTimeToStr(LocalTime));
            LI.SubItems.Add(FAppContext.EpochService.GetRelativeTimeHumanized(LocalTime));
        end;
    finally
        lvParsed.Items.EndUpdate;
    end;

    if lvParsed.Items.Count > 0 then
    begin
        lvParsed.ItemIndex := 0;
        lvParsedClick(lvParsed);
    end;

    mEpoch.Invalidate;
end;

procedure TEpochConverterForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
    Action := caFree;
    FCurrentInstance := nil;
end;

procedure TEpochConverterForm.FormResize(Sender: TObject);
begin
    ResizeLVColumns;
end;

procedure TEpochConverterForm.lvParsedClick(Sender: TObject);
var
    MatchIdx: Integer;
    Match: TEpochMatch;
    CleanLen: Integer;
    LocalParsedTime: TDateTime;
begin
    if not Assigned(lvParsed.Selected) then Exit;

    MatchIdx := lvParsed.Selected.Index;
    if (MatchIdx < 0) or (MatchIdx >= Length(FMatches)) then Exit;

    Match := FMatches[MatchIdx];
    FCurrentParsedEpoch := Match.UnixSeconds;
    FIsValidEpoch := True;

    mEpoch.BlockBegin := BufferCoord(Match.CharIdx, Match.LineIdx);
    mEpoch.BlockEnd := BufferCoord(Match.CharIdx + Match.PosLength, Match.LineIdx);
    mEpoch.CaretXY := mEpoch.BlockEnd;
    mEpoch.EnsureCursorPosVisible;

    CleanLen := Length(StringReplace(StringReplace(Match.RawText, '.', '', [rfReplaceAll]), ',', '', [rfReplaceAll]));

    case CleanLen of
        10:  lbDetectedFormat.Caption := TUIStateLoader.GetMessage('Epoch.Format-seconds');
        13:  lbDetectedFormat.Caption := TUIStateLoader.GetMessage('Epoch.Format-milliseconds');
        16:  lbDetectedFormat.Caption := TUIStateLoader.GetMessage('Epoch.Format-microseconds');
        else lbDetectedFormat.Caption := TUIStateLoader.GetMessage('Epoch.Format-non-standard');
    end;

    ebSourceTime.Text := Match.RawText;
    ebLocal.Text      := DateTimeToStr(FAppContext.EpochService.UnixToLocal(FCurrentParsedEpoch));
    ebUTC.Text        := DateTimeToStr(FAppContext.EpochService.UnixToUTC(FCurrentParsedEpoch));
    ebISO.Text        := FAppContext.EpochService.FormatISO8601(FAppContext.EpochService.UnixToUTC(FCurrentParsedEpoch));

    FUpdatingUI := True;
    try
        LocalParsedTime := FAppContext.EpochService.UnixToLocal(FCurrentParsedEpoch);
        dtpDate.Date := Trunc(LocalParsedTime);
        dtpTime.Time := Frac(LocalParsedTime);
    finally
        FUpdatingUI := False;
    end;

    UpdateRelativeTime;
    tmrLiveUpdate.Enabled := True;

    mEpoch.Invalidate;
end;

procedure TEpochConverterForm.lvParsedResize(Sender: TObject);
begin
    ResizeLVColumns;
end;

procedure TEpochConverterForm.lvParsedSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
    if Selected then lvParsedClick(Sender);
end;

procedure TEpochConverterForm.mEpochChange(Sender: TObject);
begin
    DisplayTime;
end;

procedure TEpochConverterForm.mEpochMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
    I, MarkX, MarkY: Integer;
    NewItem: TMenuItem;
    LineText: string;
    HasAnyBookmarks: Boolean;
    HasBookmarkOnCurrentLine: Boolean;
begin
    if Button = mbRight then
    begin
        nCut.Enabled := mEpoch.SelLength > 0;
        nCopy.Enabled := mEpoch.SelLength > 0;
        nPaste.Enabled := Clipboard.HasFormat(CF_TEXT);
        nSelectAll.Enabled := mEpoch.Text <> '';

        HasBookmarkOnCurrentLine := False;

        for I := 0 to 9 do
        begin
            MarkX := 0;
            MarkY := 0;
            mEpoch.GetBookMark(I, MarkX, MarkY);

            if (MarkY > 0) and (MarkY = mEpoch.CaretY) then
            begin
                HasBookmarkOnCurrentLine := True;
                Break;
            end;
        end;

        if HasBookmarkOnCurrentLine then
            nToggleBookmark.Caption := TUIStateLoader.GetMessage('Epoch.DeleteBookmark')
        else
            nToggleBookmark.Caption := TUIStateLoader.GetMessage('Epoch.CreateBookmark');

        nBookmarks.Clear;
        HasAnyBookmarks := False;

        for I := 0 to 9 do
        begin
            MarkX := 0;
            MarkY := 0;
            mEpoch.GetBookMark(I, MarkX, MarkY);

            if MarkY > 0 then
            begin
                HasAnyBookmarks := True;

                try
                    LineText := Trim(mEpoch.Lines[MarkY - 1]);
                except
                    LineText := '';
                end;

                if LineText = '' then
                    LineText := TUIStateLoader.GetMessage('Epoch.EmptryString');

                if Length(LineText) > 35 then
                    LineText := Copy(LineText, 1, 35) + '...';

                NewItem := TMenuItem.Create(nBookmarks);
                NewItem.Caption := Format('[%d] (%d): %s', [I, MarkY, LineText]);
                NewItem.Tag := I;
                NewItem.OnClick := OnBookmarkMenuItemClick;

                nBookmarks.Add(NewItem);
            end;
        end;

        nBookmarks.Enabled := HasAnyBookmarks;
        if not HasAnyBookmarks then
        begin
            NewItem := TMenuItem.Create(nBookmarks);
            NewItem.Caption := TUIStateLoader.GetMessage('Epoch.NoActiveBookmarks');
            NewItem.Enabled := False;
            nBookmarks.Add(NewItem);
        end;
    end;
end;

procedure TEpochConverterForm.mEpochPaintTransient(Sender: TObject; Canvas: TCanvas; TransientType: TTransientType);
var
    I: Integer;
    Match: TEpochMatch;
    P1: TPoint;
    CoordStart: TBufferCoord;
    DispCoord: TDisplayCoord;
    R: TRect;
    SelBegin, SelEnd: TBufferCoord;
    MatchOverlapsSelection, IsActiveItem: Boolean;
    MatchStart, MatchEnd: Integer;
    IsBeforeSel, IsAfterSel: Boolean;
begin
    if TransientType <> ttAfter then Exit;

    Canvas.Brush.Style := bsSolid;
    Canvas.Font.Assign(mEpoch.Font);
    Canvas.Font.Style := [fsBold];

    if mEpoch.SelAvail then
    begin
        SelBegin := mEpoch.BlockBegin;
        SelEnd := mEpoch.BlockEnd;
        if (SelBegin.Line > SelEnd.Line) or ((SelBegin.Line = SelEnd.Line) and (SelBegin.Char > SelEnd.Char)) then
        begin
            SelBegin := mEpoch.BlockEnd;
            SelEnd := mEpoch.BlockBegin;
        end;
    end;

    for I := 0 to High(FMatches) do
    begin
        Match := FMatches[I];
        IsActiveItem := (lvParsed.Selected <> nil) and (lvParsed.Selected.Index = I);

        MatchOverlapsSelection := False;
        if mEpoch.SelAvail then
        begin
            if (Match.LineIdx >= SelBegin.Line) and (Match.LineIdx <= SelEnd.Line) then
            begin
                MatchStart := Match.CharIdx;
                MatchEnd := Match.CharIdx + Match.PosLength;

                IsBeforeSel := (Match.LineIdx = SelBegin.Line) and (MatchEnd <= SelBegin.Char);
                IsAfterSel := (Match.LineIdx = SelEnd.Line) and (MatchStart >= SelEnd.Char);

                if not (IsBeforeSel or IsAfterSel) then
                    MatchOverlapsSelection := True;
            end;
        end;

        if MatchOverlapsSelection and not IsActiveItem then
            Continue;

        CoordStart := BufferCoord(Match.CharIdx, Match.LineIdx);
        DispCoord := mEpoch.BufferToDisplayPos(CoordStart);

        if (DispCoord.Row >= mEpoch.TopLine) and (DispCoord.Row <= mEpoch.TopLine + mEpoch.LinesInWindow) then
        begin
            P1 := mEpoch.RowColumnToPixels(DispCoord);
            R := Rect(P1.X, P1.Y, P1.X + (Match.PosLength * mEpoch.CharWidth), P1.Y + mEpoch.LineHeight);

            if IsActiveItem then
                Canvas.Brush.Color := $0000FFFF
            else
                Canvas.Brush.Color := $00FFCC99;

            Canvas.Font.Color := clBlack;
            Canvas.FillRect(R);
            Canvas.TextOut(P1.X, P1.Y, Match.RawText);
        end;
    end;
end;

procedure TEpochConverterForm.nCopyClick(Sender: TObject);
begin
    mEpoch.CopyToClipboard;
end;

procedure TEpochConverterForm.nCutClick(Sender: TObject);
begin
    mEpoch.CutToClipboard;
end;

procedure TEpochConverterForm.nPasteClick(Sender: TObject);
begin
    mEpoch.PasteFromClipboard;
end;

procedure TEpochConverterForm.nSelectAllClick(Sender: TObject);
begin
    mEpoch.SelectAll;
end;

procedure TEpochConverterForm.nToggleBookmarkClick(Sender: TObject);
const
    SlotPriority: array[0..9] of Integer = (1, 2, 3, 4, 5, 6, 7, 8, 9, 0);
var
    I, Slot, MarkX, MarkY: Integer;
    BookmarkFound: Boolean;
    FreeSlot: Integer;
begin
    BookmarkFound := False;
    FreeSlot := -1;

    for I := 0 to 9 do
    begin
        MarkX := 0;
        MarkY := 0;
        mEpoch.GetBookMark(I, MarkX, MarkY);

        if (MarkY > 0) and (MarkY = mEpoch.CaretY) then
        begin
            mEpoch.ClearBookMark(I);
            BookmarkFound := True;
        end;
    end;

    if not BookmarkFound then
    begin
        for I := 0 to 9 do
        begin
            Slot := SlotPriority[I];
            MarkX := 0;
            MarkY := 0;
            mEpoch.GetBookMark(Slot, MarkX, MarkY);

            if MarkY = 0 then
            begin
                FreeSlot := Slot;
                Break;
            end;
        end;

        if FreeSlot = -1 then
            FreeSlot := 1;

        mEpoch.SetBookMark(FreeSlot, mEpoch.CaretX, mEpoch.CaretY);
    end;
end;

procedure TEpochConverterForm.OnBookmarkMenuItemClick(Sender: TObject);
var
    BookmarkIdx: Integer;
begin
    if Sender is TMenuItem then
    begin
        BookmarkIdx := TMenuItem(Sender).Tag;
        mEpoch.GotoBookMark(BookmarkIdx);
        mEpoch.EnsureCursorPosVisible;
        mEpoch.SetFocus;
    end;
end;

procedure TEpochConverterForm.ResizeLVColumns;
var
    TotalWidth: Integer;
begin
    if not Assigned(lvParsed) or (lvParsed.Columns.Count < 3) or not lvParsed.HandleAllocated then
        Exit;

    lvParsed.Items.BeginUpdate;
    try
        lvParsed.Columns[0].Width := LVSCW_AUTOSIZE_USEHEADER;
        if lvParsed.Columns[0].Width < 100 then
            lvParsed.Columns[0].Width := 100;

        lvParsed.Columns[1].Width := LVSCW_AUTOSIZE_USEHEADER;
        if lvParsed.Columns[1].Width < 120 then
            lvParsed.Columns[1].Width := 120;

        TotalWidth := lvParsed.ClientWidth;
        lvParsed.Columns[2].Width := TotalWidth - lvParsed.Columns[0].Width - lvParsed.Columns[1].Width;

        if lvParsed.Columns[2].Width < 90 then
            lvParsed.Columns[2].Width := 90;
    finally
        lvParsed.Items.EndUpdate;
    end;
end;

end.
