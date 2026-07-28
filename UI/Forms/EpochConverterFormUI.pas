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
        procedure mEpochMouseDown(Sender: TObject; Button: TMouseButton; Shift:
            TShiftState; X, Y: Integer);
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
    Vcl.Forms,
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

    // Переопределяем горячую клавишу для установки закладок
    for I := 0 to mEpoch.Keystrokes.Count - 1 do
    begin
        Cmd := mEpoch.Keystrokes[I].Command;
        if (Cmd >= ecSetMarker0) and (Cmd <= ecSetMarker9) then
        begin
            // Ord(Cmd) - Ord(ecSetMarker0) даст число от 0 до 9
            mEpoch.Keystrokes[I].ShortCut := ShortCut(Word('0') + (Ord(Cmd) - Ord(ecSetMarker0)), [ssAlt]);
        end;
    end;
end;

class procedure TEpochConverterForm.ExecuteGlobal(Owner: TComponent; AppContext: IAppContext);
begin
    if Assigned(FCurrentInstance) then
    begin
        if FCurrentInstance.WindowState = wsMinimized then
            FCurrentInstance.WindowState := wsNormal;
        SetForegroundWindow(FCurrentInstance.Handle);
        FCurrentInstance.BringToFront;
        Exit;
    end;

    FCurrentInstance := TEpochConverterForm.Create(Owner);
    try
        FCurrentInstance.Initialize(AppContext);
        FCurrentInstance.FormStyle := fsStayOnTop;
        FCurrentInstance.ShowModal;
    finally
        FreeAndNil(FCurrentInstance);
    end;
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

    // Время, заданное в DateTimePicker, всегда трактуем как локальное
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

    // Регистрация подсказок
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

procedure TEpochConverterForm.mEpochMouseDown(Sender: TObject; Button:
    TMouseButton; Shift: TShiftState; X, Y: Integer);
var
    I, MarkX, MarkY: Integer;
    NewItem: TMenuItem;
    LineText: string;
    HasAnyBookmarks: Boolean;
    HasBookmarkOnCurrentLine: Boolean;
begin
    if Button = mbRight then
    begin
        // Состояние стандартных пунктов меню
        nCut.Enabled := mEpoch.SelLength > 0;
        nCopy.Enabled := mEpoch.SelLength > 0;
        nPaste.Enabled := Clipboard.HasFormat(CF_TEXT);
        nSelectAll.Enabled := mEpoch.Text <> '';

        // Проверка закладок для динамической смены заголовка
        HasBookmarkOnCurrentLine := False;

        for I := 0 to 9 do
        begin
            MarkX := 0;
            MarkY := 0;
            mEpoch.GetBookMark(I, MarkX, MarkY);

            // Если хотя бы одна закладка указывает на текущую строку курсора
            if (MarkY > 0) and (MarkY = mEpoch.CaretY) then
            begin
                HasBookmarkOnCurrentLine := True;
                Break;
            end;
        end;

        // Меняем заголовок пункта в зависимости от наличия закладки на строке
        if HasBookmarkOnCurrentLine then
            nToggleBookmark.Caption := TUIStateLoader.GetMessage('Epoch.DeleteBookmark')
        else
            nToggleBookmark.Caption := TUIStateLoader.GetMessage('Epoch.CreateBookmark');

        // Динамическое обновление подменю "перейти к закладке"
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

    // Запоминаем границы системного выделения мышью (если оно есть)
    if mEpoch.SelAvail then
    begin
        SelBegin := mEpoch.BlockBegin;
        SelEnd := mEpoch.BlockEnd;
        // Нормализуем координаты (пользователь мог выделять текст снизу вверх)
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

        // Проверка пересечения с выделением
        MatchOverlapsSelection := False;
        if mEpoch.SelAvail then
        begin
            // Проверяем, находится ли таймстемп на строке, задетой выделением
            if (Match.LineIdx >= SelBegin.Line) and (Match.LineIdx <= SelEnd.Line) then
            begin
                MatchStart := Match.CharIdx;
                MatchEnd := Match.CharIdx + Match.PosLength;

                IsBeforeSel := (Match.LineIdx = SelBegin.Line) and (MatchEnd <= SelBegin.Char);
                IsAfterSel := (Match.LineIdx = SelEnd.Line) and (MatchStart >= SelEnd.Char);

                // Если маркер не ДО и не ПОСЛЕ выделения, значит они пересекаются
                if not (IsBeforeSel or IsAfterSel) then
                    MatchOverlapsSelection := True;
            end;
        end;

        // Если этот кусок текста выделен мышью, и он НЕ является
        // текущим активным элементом лога - отменяем нашу заливку.
        // TSynEdit сам покажет свое родное синее выделениe.
        if MatchOverlapsSelection and not IsActiveItem then
            Continue;

        // Отрисовка
        CoordStart := BufferCoord(Match.CharIdx, Match.LineIdx);
        DispCoord := mEpoch.BufferToDisplayPos(CoordStart);

        if (DispCoord.Row >= mEpoch.TopLine) and (DispCoord.Row <= mEpoch.TopLine + mEpoch.LinesInWindow) then
        begin
            P1 := mEpoch.RowColumnToPixels(DispCoord);
            R := Rect(P1.X, P1.Y, P1.X + (Match.PosLength * mEpoch.CharWidth), P1.Y + mEpoch.LineHeight);

            if IsActiveItem then
                Canvas.Brush.Color := $0000FFFF  // Ярко-желтый для активного
            else
                Canvas.Brush.Color := $00FFCC99; // Светло-голубой для неактивных

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
    // Windows (начиная с Windows Vista и вплоть до Windows 11)
    // перехватывает нажатие Ctrl+Shift+0 на самом низком уровне ОС.
    // Из-за этого сообщение о нажатии клавиш просто не доходит до приложения.
    // При этом переход к закладке (Ctrl+0) работает отлично, так как в нём нет Shift.
    // Поэтому раздаем слоты начиная с 1. Проблемный 0 слот оставляем напоследок.
    // Его можно назначить только кодом.
    SlotPriority: array[0..9] of Integer = (1, 2, 3, 4, 5, 6, 7, 8, 9, 0);
var
    I, Slot, MarkX, MarkY: Integer;
    BookmarkFound: Boolean;
    FreeSlot: Integer;
begin
    BookmarkFound := False;
    FreeSlot := -1;

    // Сначала проверяем, есть ли на текущей строке уже установленные закладки
    for I := 0 to 9 do
    begin
        MarkX := 0;
        MarkY := 0;
        mEpoch.GetBookMark(I, MarkX, MarkY);

        // Если закладка стоит на текущей строке - удаляем её
        if (MarkY > 0) and (MarkY = mEpoch.CaretY) then
        begin
            mEpoch.ClearBookMark(I);
            BookmarkFound := True;
        end;
    end;

    // Если закладок на строке не было, ищем свободный слот
    if not BookmarkFound then
    begin
        // Ищем по массиву приоритетов
        for I := 0 to 9 do
        begin
            Slot := SlotPriority[I];
            MarkX := 0;
            MarkY := 0;
            mEpoch.GetBookMark(Slot, MarkX, MarkY);

            // Если MarkY = 0, значит этот слот свободен
            if MarkY = 0 then
            begin
                FreeSlot := Slot;
                Break;
            end;
        end;

        // Если все 10 слотов забиты, перезаписываем слот 1 (как самый используемый)
        if FreeSlot = -1 then
            FreeSlot := 1;

        // Устанавливаем закладку
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
