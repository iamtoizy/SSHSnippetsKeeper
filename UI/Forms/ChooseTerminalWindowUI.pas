unit ChooseTerminalWindowUI;

interface

uses
    BaseFormUI,
    System.Classes,
    System.Generics.Collections,
    Vcl.Buttons,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.ImgList,
    Vcl.StdCtrls,
    Winapi.Messages,
    Winapi.Windows,
    WindowMonitor, System.ImageList
    ;

type
    TChooseTerminalWindow = class(TBaseForm)
        pTop: TPanel;
        ebFilter: TEdit;
        pPreview: TPanel;
        splPreview: TSplitter;
        pViewButtons: TPanel;
        sbTiles: TSpeedButton;
        sbTable: TSpeedButton;
        sbGroup: TSpeedButton;
        lvTerminalList: TListView;
        sbBottom: TStatusBar;
        ilIcons: TImageList;
        ilSmallIcons: TImageList;
        lbPreviewEmpty: TLabel;
        sbPreview: TSpeedButton;
        procedure lvTerminalListDblClick(Sender: TObject);
        procedure lvTerminalListColumnClick(Sender: TObject; Column: TListColumn);
        procedure lvTerminalListSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure ViewButtonClick(Sender: TObject);
        procedure sbGroupClick(Sender: TObject);
        procedure sbPreviewClick(Sender: TObject);
        procedure ttPreviewWatchTimer(Sender: TObject);
        procedure pPreviewResize(Sender: TObject);
        procedure splPreviewMoved(Sender: TObject);
        procedure FormResize(Sender: TObject);
        procedure ebFilterChange(Sender: TObject);
        procedure FormShow(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure FormDestroy(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure FormKeyPress(Sender: TObject; var Key: Char);
    private
        FSelectedWindow: TWindowMonitorInfo;
        FWindows: TArray<TWindowMonitorInfo>;
        FIconCache: TDictionary<string, Integer>;
        FSmallIconCache: TDictionary<string, Integer>;
        FSearchText: string;
        FSearchTick: DWORD;
        FSortColumn: Integer;
        FSortAscending: Boolean;
        FGroupByProcess: Boolean;
        FThumb: THandle;
        FThumbHwnd: HWND;
        FPreviewWanted: HWND;
        FPreviewWasIconic: Boolean;
        FUserSized: Boolean;
        FPreviewSavedHeight: Integer;
        ttPreviewWatch: TTimer;
        FDefListProc: TWndMethod;
        procedure PopulateList;
        procedure AdjustFormHeight;
        function ResolveIconIndex(const ExePath: string; ASmall: Boolean): Integer;
        function MatchesFilter(const WindowInfo: TWindowMonitorInfo; const Filter: string): Boolean;
        function CompareWindows(Left, Right: Integer): Integer;
        procedure ConfirmSelection;
        procedure SelectByNumber(Index: Integer);
        procedure ApplyViewStyle(AITableView: Boolean);
        procedure SaveViewSetting(AITableView: Boolean);
        procedure SaveGroupSetting(AGroup: Boolean);
        procedure UpdatePreview(AHwnd: HWND);
        procedure RegisterPreview(AHwnd: HWND);
        procedure LayoutPreview;
        procedure ClearPreview;
        procedure ShowPreviewPlaceholder(const AMsgKey: string);
        procedure ApplyPreviewState;
        procedure SavePreviewSetting(AVisible: Boolean);
        procedure ListWndProc(var Message: TMessage);
        function IsDarkStyleActive: Boolean;
        procedure UpdateColumnCaptions;
        procedure UpdateStatusText(AShownCount: Integer);
        procedure RestoreGeometry;
        procedure SaveGeometry;
        procedure FillLastColumn;
        function FormSizeValid(AWidth, AHeight: Integer): Boolean;
        function PreviewHeightValid(AHeight: Integer): Boolean;
        procedure WMSizing(var Message: TMessage); message WM_SIZING;
        procedure WMExitSizeMove(var Message: TMessage); message WM_EXITSIZEMOVE;
    public
        property SelectedWindow: TWindowMonitorInfo read FSelectedWindow;
    end;

var
    ChooseTerminalWindowForm: TChooseTerminalWindow;

implementation

uses
    Core.Interfaces.Settings,
    Common.Localization,
    System.Generics.Defaults,
    System.Math,
    System.SysUtils,
    System.Types,
    SynThemeAdapter,
    Vcl.Forms,
    Vcl.Graphics,
    Vcl.Themes,
    Winapi.CommCtrl,
    Winapi.Dwmapi,
    Winapi.ShellAPI
    ;

{$R *.dfm}

procedure TChooseTerminalWindow.FormCreate(Sender: TObject);
begin
    FSelectedWindow.HWND := 0;
    FThumb := 0;
    FThumbHwnd := 0;
    FPreviewWanted := 0;
    FPreviewWasIconic := False;
    FUserSized := False;
    FPreviewSavedHeight := 0;
    FGroupByProcess := False;
    FIconCache := TDictionary<string, Integer>.Create;
    FSmallIconCache := TDictionary<string, Integer>.Create;
    FSortColumn := -1;
    FSortAscending := True;
    FDefListProc := lvTerminalList.WindowProc;
    lvTerminalList.WindowProc := ListWndProc;
    ttPreviewWatch := TTimer.Create(Self);
    ttPreviewWatch.Interval := 500;
    ttPreviewWatch.OnTimer := ttPreviewWatchTimer;
    ttPreviewWatch.Enabled := True;

    // Подписи зависят от языка: заполняем из ресурсов.
    // FAppContext в FormCreate ещё nil (Initialize приходит позже),
    // поэтому настройки читаются в FormShow
    ebFilter.TextHint := TUIStateLoader.GetMessage('Terminal.FilterHint');
    sbTiles.Caption := TUIStateLoader.GetMessage('Terminal.ViewTiles');
    sbTable.Caption := TUIStateLoader.GetMessage('Terminal.ViewTable');
    sbGroup.Caption := TUIStateLoader.GetMessage('Terminal.ViewGroups');
    sbGroup.Hint := TUIStateLoader.GetMessage('Terminal.ViewGroupsHint');
    sbGroup.ShowHint := True;
    lbPreviewEmpty.Caption := TUIStateLoader.GetMessage('Terminal.PreviewEmpty');
    UpdateColumnCaptions;
end;

procedure TChooseTerminalWindow.FormDestroy(Sender: TObject);
begin
    SaveGeometry;
    if Assigned(FDefListProc) then
        lvTerminalList.WindowProc := FDefListProc;
    ClearPreview;
    FreeAndNil(FIconCache);
    FreeAndNil(FSmallIconCache);
end;

procedure TChooseTerminalWindow.FormShow(Sender: TObject);
begin
    // Сохранённый режим отображения (False = плитки, как раньше)
    FGroupByProcess := FAppContext.SettingsManager.Data.TerminalChooserGroupByProcess;
    sbGroup.Down := FGroupByProcess;
    ApplyViewStyle(FAppContext.SettingsManager.Data.TerminalChooserTableView);
    sbPreview.Down := FAppContext.SettingsManager.Data.TerminalChooserPreviewVisible;
    ApplyPreviewState;
    RestoreGeometry;
    PopulateList;
    if lvTerminalList.Items.Count > 0 then
        lvTerminalList.SetFocus;
    AdjustFormHeight;
end;

procedure TChooseTerminalWindow.lvTerminalListDblClick(Sender: TObject);
begin
    ConfirmSelection;
end;

procedure TChooseTerminalWindow.ConfirmSelection;
begin
    if lvTerminalList.Selected <> nil then
    begin
        FSelectedWindow := FWindows[Integer(lvTerminalList.Selected.Data)];
        ModalResult := mrOk;
    end;
end;

procedure TChooseTerminalWindow.SelectByNumber(Index: Integer);
begin
    if Index < lvTerminalList.Items.Count then
    begin
        lvTerminalList.ItemIndex := Index;
        FSelectedWindow := FWindows[Integer(lvTerminalList.Items[Index].Data)];
        ModalResult := mrOk;
    end;
end;

procedure TChooseTerminalWindow.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    case Key of
        VK_ESCAPE:
            begin
                Key := 0;
                ModalResult := mrCancel;
            end;
        VK_RETURN:
            begin
                Key := 0;
                if ActiveControl = ebFilter then
                begin
                    // Enter в фильтре: берём первую отфильтрованную строку
                    if lvTerminalList.Items.Count > 0 then
                        SelectByNumber(0);
                end
                else
                    ConfirmSelection;
            end;
        VK_DOWN:
            if ActiveControl = ebFilter then
            begin
                Key := 0;
                if lvTerminalList.Items.Count > 0 then
                    lvTerminalList.ItemIndex := 0;
                lvTerminalList.SetFocus;
            end;
        VK_UP:
            if (ActiveControl = lvTerminalList) and (lvTerminalList.ItemIndex <= 0) then
            begin
                Key := 0;
                ebFilter.SetFocus;
            end;
    end;
end;

procedure TChooseTerminalWindow.FormKeyPress(Sender: TObject; var Key: Char);
var
    Ch: Char;
begin
    // Инкрементальный поиск только при фокусе в списке: набираемое
    // попадает в тот же фильтр, что и поле ebFilter
    if ActiveControl <> lvTerminalList then
        Exit;

    if CharInSet(Key, ['1'..'9']) then
    begin
        SelectByNumber(Ord(Key) - Ord('1'));
        Key := #0;
        Exit;
    end;

    if Key = #8 then
    begin
        Key := #0;
        if FSearchText <> '' then
            SetLength(FSearchText, Length(FSearchText) - 1);
        FSearchTick := GetTickCount;
        ebFilter.Text := FSearchText;
        Exit;
    end;

    if Ord(Key) >= 32 then
    begin
        Ch := Key;
        Key := #0;
        // Пауза больше 800 мс - считаем набранное новой строкой поиска
        if GetTickCount - FSearchTick > DWORD(800) then
            FSearchText := '';
        FSearchText := FSearchText + Ch;
        FSearchTick := GetTickCount;
        ebFilter.Text := FSearchText;
    end;
end;

procedure TChooseTerminalWindow.ebFilterChange(Sender: TObject);
begin
    // Печатает и пользователь в поле, и инкрементальный поиск из списка
    if FSearchText <> ebFilter.Text then
        FSearchText := '';
    PopulateList;
end;

procedure TChooseTerminalWindow.ViewButtonClick(Sender: TObject);
begin
    SaveViewSetting(sbTable.Down);
    ApplyViewStyle(sbTable.Down);
    PopulateList;
    AdjustFormHeight;
end;

procedure TChooseTerminalWindow.ApplyViewStyle(AITableView: Boolean);
begin
    sbTable.Down := AITableView;
    sbTiles.Down := not AITableView;
    if AITableView then
        lvTerminalList.ViewStyle := vsReport
    else
    begin
        lvTerminalList.GroupView := False;
        lvTerminalList.ViewStyle := vsTile;
    end;
end;

procedure TChooseTerminalWindow.SaveViewSetting(AITableView: Boolean);
var
    Settings: TAppSettings;
begin
    Settings := FAppContext.SettingsManager.Data;
    Settings.TerminalChooserTableView := AITableView;
    FAppContext.SettingsManager.Data := Settings;
    FAppContext.SettingsManager.Save;
end;

procedure TChooseTerminalWindow.SaveGroupSetting(AGroup: Boolean);
var
    Settings: TAppSettings;
begin
    Settings := FAppContext.SettingsManager.Data;
    Settings.TerminalChooserGroupByProcess := AGroup;
    FAppContext.SettingsManager.Data := Settings;
    FAppContext.SettingsManager.Save;
end;

procedure TChooseTerminalWindow.sbGroupClick(Sender: TObject);
begin
    FGroupByProcess := sbGroup.Down;
    SaveGroupSetting(FGroupByProcess);
    PopulateList;
end;

procedure TChooseTerminalWindow.lvTerminalListSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
    if Selected and (Item <> nil) and
        (Integer(Item.Data) >= 0) and (Integer(Item.Data) <= High(FWindows)) then
        UpdatePreview(FWindows[Integer(Item.Data)].HWND)
    else
        UpdatePreview(0);
end;

procedure TChooseTerminalWindow.UpdatePreview(AHwnd: HWND);
begin
    FPreviewWanted := AHwnd;
    if not pPreview.Visible then
        Exit;
    if not IsWindow(AHwnd) then
    begin
        ShowPreviewPlaceholder('Terminal.PreviewEmpty');
        Exit;
    end;
    if IsIconic(AHwnd) then
    begin
        FPreviewWasIconic := True;
        ShowPreviewPlaceholder('Terminal.PreviewMinimized');
        Exit;
    end;
    FPreviewWasIconic := False;
    if (FThumb = 0) or (FThumbHwnd <> AHwnd) then
        RegisterPreview(AHwnd)
    else
        LayoutPreview;
end;

procedure TChooseTerminalWindow.RegisterPreview(AHwnd: HWND);
var
    Thumb: THandle;
begin
    ClearPreview;
    if Succeeded(DwmRegisterThumbnail(Handle, AHwnd, @Thumb)) then
    begin
        FThumb := Thumb;
        FThumbHwnd := AHwnd;
        lbPreviewEmpty.Visible := False;
        LayoutPreview;
    end
    else
    begin
        lbPreviewEmpty.Caption := TUIStateLoader.GetMessage('Terminal.PreviewUnavailable');
        lbPreviewEmpty.Visible := True;
    end;
end;

procedure TChooseTerminalWindow.LayoutPreview;
var
    SrcRect: TRect;
    Area: TRect;
    SrcW, SrcH: Integer;
    Scale: Double;
    Props: TDwmThumbnailProperties;
begin
    if (FThumb = 0) or IsIconic(FThumbHwnd) then
        Exit;
    if (pPreview.ClientWidth <= 8) or (pPreview.ClientHeight <= 8) then
        Exit;

    FillChar(Props, SizeOf(Props), 0);
    Props.dwFlags := DWM_TNP_RECTDESTINATION or DWM_TNP_VISIBLE or
        DWM_TNP_SOURCECLIENTAREAONLY or DWM_TNP_OPACITY;
    Props.fVisible := True;
    Props.fSourceClientAreaOnly := True;
    Props.opacity := 255;

    if Winapi.Windows.GetClientRect(FThumbHwnd, SrcRect) and
        (SrcRect.Right > SrcRect.Left) and (SrcRect.Bottom > SrcRect.Top) then
    begin
        SrcW := SrcRect.Right - SrcRect.Left;
        SrcH := SrcRect.Bottom - SrcRect.Top;
        Area := pPreview.BoundsRect;
        Area.Offset(ClientOrigin.X - Left, ClientOrigin.Y - Top);
        Area.Inflate(-4, -4);
        Inc(Area.Top, 8);
        Scale := Min(Area.Width / SrcW, Area.Height / SrcH);
        Props.rcDestination := TRect.Create(
            Area.Left + (Area.Width - Round(SrcW * Scale)) div 2,
            Area.Top + (Area.Height - Round(SrcH * Scale)) div 2,
            Area.Left + (Area.Width - Round(SrcW * Scale)) div 2 + Round(SrcW * Scale),
            Area.Top + (Area.Height - Round(SrcH * Scale)) div 2 + Round(SrcH * Scale));
    end;

    DwmUpdateThumbnailProperties(FThumb, Props);
end;

procedure TChooseTerminalWindow.ClearPreview;
begin
    ShowPreviewPlaceholder('Terminal.PreviewEmpty');
end;

procedure TChooseTerminalWindow.ShowPreviewPlaceholder(const AMsgKey: string);
begin
    if FThumb <> 0 then
    begin
        DwmUnregisterThumbnail(FThumb);
        FThumb := 0;
    end;
    FThumbHwnd := 0;
    lbPreviewEmpty.Caption := TUIStateLoader.GetMessage(AMsgKey);
    lbPreviewEmpty.Visible := True;
end;

procedure TChooseTerminalWindow.ApplyPreviewState;
begin
    if sbPreview.Down and (FPreviewSavedHeight > 0) then
        pPreview.Height := FPreviewSavedHeight;
    pPreview.Visible := sbPreview.Down;
    splPreview.Visible := sbPreview.Down;
    if sbPreview.Down then
        sbPreview.Caption := #9660 + ' ' + TUIStateLoader.GetMessage('Terminal.PreviewHeader')
    else
        sbPreview.Caption := #9650 + ' ' + TUIStateLoader.GetMessage('Terminal.PreviewHeader');
    if pPreview.Visible then
    begin
        if FPreviewWanted <> 0 then
            UpdatePreview(FPreviewWanted)
        else
            ShowPreviewPlaceholder('Terminal.PreviewEmpty');
    end
    else
        ClearPreview;
end;

procedure TChooseTerminalWindow.SavePreviewSetting(AVisible: Boolean);
var
    Settings: TAppSettings;
begin
    Settings := FAppContext.SettingsManager.Data;
    Settings.TerminalChooserPreviewVisible := AVisible;
    FAppContext.SettingsManager.Data := Settings;
    FAppContext.SettingsManager.Save;
end;

procedure TChooseTerminalWindow.sbPreviewClick(Sender: TObject);
var
    MinNeeded: Integer;
begin
    SavePreviewSetting(sbPreview.Down);
    ApplyPreviewState;
    if sbPreview.Down and FUserSized then
    begin
        // Ручная геометрия: не даём списку схлопнуться, растим форму в пределах рабочей области
        MinNeeded := pTop.Height + pPreview.Height + splPreview.Height +
            sbBottom.Height + 100;
        if ClientHeight < MinNeeded then
            ClientHeight := Min(MinNeeded, Screen.WorkAreaHeight);
    end;
    AdjustFormHeight;
end;

procedure TChooseTerminalWindow.splPreviewMoved(Sender: TObject);
begin
    if pPreview.Height >= splPreview.MinSize then
        FPreviewSavedHeight := pPreview.Height;
    SaveGeometry;
end;

procedure TChooseTerminalWindow.FormResize(Sender: TObject);
begin
    FillLastColumn;
end;

procedure TChooseTerminalWindow.FillLastColumn;
var
    I, Fill: Integer;
begin
    if (lvTerminalList.ViewStyle = vsReport) and lvTerminalList.HandleAllocated then
    begin
        Fill := lvTerminalList.ClientWidth;
        for I := 0 to lvTerminalList.Columns.Count - 2 do
            Dec(Fill, ListView_GetColumnWidth(lvTerminalList.Handle, I));
        if Fill > 0 then
            ListView_SetColumnWidth(lvTerminalList.Handle, lvTerminalList.Columns.Count - 1, Fill);
    end;
end;

procedure TChooseTerminalWindow.ttPreviewWatchTimer(Sender: TObject);
begin
    if FPreviewWanted = 0 then
        Exit;
    if not IsWindow(FPreviewWanted) then
    begin
        FPreviewWanted := 0;
        ShowPreviewPlaceholder('Terminal.PreviewEmpty');
        Exit;
    end;
    if pPreview.Visible and (IsIconic(FPreviewWanted) <> FPreviewWasIconic) then
        UpdatePreview(FPreviewWanted);
end;

function TChooseTerminalWindow.IsDarkStyleActive: Boolean;
var
    SysBgColor: TColor;
begin
    if TStyleManager.IsCustomStyleActive then
        SysBgColor := TStyleManager.ActiveStyle.GetStyleColor(scEdit)
    else
        SysBgColor := clWindow;
    Result := TSynThemeAdapter.IsDarkTheme(SysBgColor);
end;

procedure TChooseTerminalWindow.ListWndProc(var Message: TMessage);
const
    GroupPad = 10;
var
    Draw: PNMLVCustomDraw;
    Hdr: PNMHdr;
    Group: TLVGroup;
    HeaderText: string;
    OldFont: HFONT;
    R: TRect;
begin
    Hdr := PNMHdr(Pointer(Message.LParam));
    if (Message.Msg = CN_NOTIFY) and (Hdr^.code = NM_CUSTOMDRAW) and
        (Hdr^.hwndFrom = lvTerminalList.Handle) and IsDarkStyleActive then
    begin
        Draw := PNMLVCustomDraw(Pointer(Message.LParam));
        if Draw^.dwItemType = LVCDI_GROUP then
        begin
            FDefListProc(Message);
            if Draw^.nmcd.dwDrawStage = CDDS_PREPAINT then
            begin
                if Message.Result = CDRF_DODEFAULT then
                    Message.Result := CDRF_NOTIFYITEMDRAW;
                ZeroMemory(@Group, SizeOf(Group));
                Group.cbSize := SizeOf(Group);
                Group.mask := LVGF_HEADER;
                SetLength(HeaderText, 256);
                Group.pszHeader := PChar(HeaderText);
                Group.cchHeader := Length(HeaderText);
                SendMessage(lvTerminalList.Handle, LVM_GETGROUPINFO,
                    Draw^.nmcd.dwItemSpec, LPARAM(@Group));
                HeaderText := PChar(HeaderText);
                if HeaderText <> '' then
                begin
                    ZeroMemory(@R, SizeOf(R));
                    R.Top := LVGGR_HEADER;
                    if SendMessage(lvTerminalList.Handle, LVM_GETGROUPRECT,
                        Draw^.nmcd.dwItemSpec, LPARAM(@R)) = 0 then
                        R := Draw^.nmcd.rc;
                    Inc(R.Left, GroupPad);
                    Dec(R.Right, GroupPad);
                    SetBkMode(Draw^.nmcd.hdc, TRANSPARENT);
                    SetTextColor(Draw^.nmcd.hdc, RGB(235, 235, 235));
                    OldFont := SelectObject(Draw^.nmcd.hdc,
                        lvTerminalList.Font.Handle);
                    DrawTextW(Draw^.nmcd.hdc, PChar(HeaderText),
                        Length(HeaderText), R, DT_SINGLELINE or DT_VCENTER or
                        DT_END_ELLIPSIS or DT_NOPREFIX);
                    SelectObject(Draw^.nmcd.hdc, OldFont);
                    Message.Result := CDRF_SKIPDEFAULT;
                end;
            end;
            Exit;
        end;
        if (Draw^.nmcd.dwDrawStage and CDDS_ITEM) <> 0 then
            FDefListProc(Message)
        else
        begin
            FDefListProc(Message);
            if (Draw^.nmcd.dwDrawStage = CDDS_PREPAINT) and
                (Message.Result = CDRF_DODEFAULT) then
                Message.Result := CDRF_NOTIFYITEMDRAW;
        end;
        Exit;
    end;
    FDefListProc(Message);
end;

procedure TChooseTerminalWindow.pPreviewResize(Sender: TObject);
begin
    LayoutPreview;
end;

procedure TChooseTerminalWindow.AdjustFormHeight;
var
    LvH, PerRow, Rows, Total, MaxAvail: Integer;
begin
    // Размер задан пользователем вручную: авто-подгонку не трогаем
    if FUserSized then
        Exit;
    if lvTerminalList.Items.Count <= 0 then
        Exit;

    if lvTerminalList.ViewStyle = vsReport then
        LvH := Max(264, lvTerminalList.Items.Count * 20 + 28)
    else
    begin
        PerRow := Max(1, lvTerminalList.ClientWidth div 204);
        Rows := Min(Ceil(lvTerminalList.Items.Count / PerRow), 6);
        LvH := Max(208, Rows * 68 + 4);
    end;

    Total := pTop.Height + sbBottom.Height + LvH;
    if pPreview.Visible then
        Inc(Total, pPreview.Height);
    MaxAvail := Screen.WorkAreaHeight - 60;
    if Total > MaxAvail then
    begin
        // Сначала сжимаем превью до минимума сплиттера
        if pPreview.Visible then
        begin
            pPreview.Height := Max(splPreview.MinSize, pPreview.Height - (Total - MaxAvail));
            FPreviewSavedHeight := pPreview.Height;
            Total := pTop.Height + sbBottom.Height + LvH + pPreview.Height;
        end;
    end;
    ClientHeight := Min(Total, MaxAvail);
end;

function TChooseTerminalWindow.FormSizeValid(AWidth, AHeight: Integer): Boolean;
begin
    // Адекватные размеры: не мельче Constraints и в пределах рабочей области
    Result := (AWidth >= Constraints.MinWidth) and (AHeight >= Constraints.MinHeight) and
        (AWidth <= Screen.WorkAreaWidth) and (AHeight <= Screen.WorkAreaHeight);
end;

function TChooseTerminalWindow.PreviewHeightValid(AHeight: Integer): Boolean;
begin
    // Превью не мельче минимума сплиттера и оставляет место остальному окну
    Result := (AHeight >= splPreview.MinSize) and
        (AHeight <= Screen.WorkAreaHeight - Constraints.MinHeight);
end;

procedure TChooseTerminalWindow.RestoreGeometry;
var
    SavedW, SavedH: Integer;
begin
    SavedW := FAppContext.SettingsManager.Data.TerminalChooserWidth;
    SavedH := FAppContext.SettingsManager.Data.TerminalChooserHeight;
    // Неадекватная сохранённая геометрия игнорируется: окно остаётся авто-размера
    if FormSizeValid(SavedW, SavedH) then
    begin
        FUserSized := True;
        // poScreenCenter не пересчитает центр после смены размера в OnShow
        SetBounds((Screen.Width - SavedW) div 2, (Screen.Height - SavedH) div 2,
            SavedW, SavedH);
    end
    else
        FUserSized := False;

    FPreviewSavedHeight := 0;
    if PreviewHeightValid(FAppContext.SettingsManager.Data.TerminalChooserPreviewHeight) then
    begin
        FPreviewSavedHeight := FAppContext.SettingsManager.Data.TerminalChooserPreviewHeight;
        if pPreview.Visible then
            pPreview.Height := FPreviewSavedHeight;
    end;
end;

procedure TChooseTerminalWindow.SaveGeometry;
var
    Settings: TAppSettings;
begin
    Settings := FAppContext.SettingsManager.Data;
    // Неадекватную геометрию не храним: 0 = авто-подгон при следующем открытии
    if FUserSized and FormSizeValid(Width, Height) then
    begin
        Settings.TerminalChooserWidth := Width;
        Settings.TerminalChooserHeight := Height;
    end
    else
    begin
        Settings.TerminalChooserWidth := 0;
        Settings.TerminalChooserHeight := 0;
    end;

    if pPreview.Visible and PreviewHeightValid(pPreview.Height) then
        Settings.TerminalChooserPreviewHeight := pPreview.Height
    else
        Settings.TerminalChooserPreviewHeight := 0;

    FAppContext.SettingsManager.Data := Settings;
    FAppContext.SettingsManager.Save;
end;

procedure TChooseTerminalWindow.WMSizing(var Message: TMessage);
begin
    // WM_SIZING приходит только при интерактивном ресайзе пользователем
    FUserSized := True;
    DefaultHandler(Message);
end;

procedure TChooseTerminalWindow.WMExitSizeMove(var Message: TMessage);
begin
    inherited;
    SaveGeometry;
end;

procedure TChooseTerminalWindow.lvTerminalListColumnClick(Sender: TObject; Column: TListColumn);
begin
    if Column.Index = FSortColumn then
        FSortAscending := not FSortAscending
    else
    begin
        FSortColumn := Column.Index;
        FSortAscending := True;
    end;
    UpdateColumnCaptions;
    PopulateList;
end;

procedure TChooseTerminalWindow.UpdateColumnCaptions;
const
    ColumnKeys: array[0..2] of string =
        ('Terminal.ColTitle', 'Terminal.ColProcess', 'Terminal.ColActivated');
var
    I: Integer;
    Caption: string;
begin
    for I := 0 to High(ColumnKeys) do
    begin
        Caption := TUIStateLoader.GetMessage(ColumnKeys[I]);
        if I = FSortColumn then
        begin
            if FSortAscending then
                Caption := Caption + ' ▲'
            else
                Caption := Caption + ' ▼';
        end;
        lvTerminalList.Columns[I].Caption := Caption;
    end;
end;

procedure TChooseTerminalWindow.UpdateStatusText(AShownCount: Integer);
begin
    if AShownCount < 0 then
        sbBottom.SimpleText := TUIStateLoader.GetMessage('Terminal.HistoryEmpty')
    else if AShownCount = 0 then
        sbBottom.SimpleText := TUIStateLoader.GetMessage('Terminal.FilterEmpty')
    else
        sbBottom.SimpleText := Format('%s   ·   %s',
            [TUIStateLoader.GetMessage('Terminal.WindowsCount', [AShownCount]),
             TUIStateLoader.GetMessage('Terminal.KeyboardHint')]);
end;

function TChooseTerminalWindow.MatchesFilter(const WindowInfo: TWindowMonitorInfo; const Filter: string): Boolean;
begin
    if Filter = '' then
        Exit(True);
    Result := (Pos(Filter, WindowInfo.WindowTitle.ToLower) > 0) or
        (Pos(Filter, WindowInfo.ExeName.ToLower) > 0);
end;

function TChooseTerminalWindow.CompareWindows(Left, Right: Integer): Integer;
begin
    case FSortColumn of
        0: Result := CompareText(FWindows[Left].WindowTitle, FWindows[Right].WindowTitle);
        1: Result := CompareText(FWindows[Left].ExeName, FWindows[Right].ExeName);
        2: Result := CompareValue(Double(FWindows[Left].ActivatedAt), Double(FWindows[Right].ActivatedAt));
    else
        Result := 0;
    end;
    if not FSortAscending then
        Result := -Result;
end;

function TChooseTerminalWindow.ResolveIconIndex(const ExePath: string; ASmall: Boolean): Integer;
var
    Info: TSHFileInfo;
    Icon: TIcon;
    Cache: TDictionary<string, Integer>;
    Key: string;
    Flags: Cardinal;
begin
    Key := LowerCase(ExePath);
    if ASmall then
    begin
        Cache := FSmallIconCache;
        Flags := SHGFI_SMALLICON;
    end
    else
    begin
        Cache := FIconCache;
        Flags := SHGFI_LARGEICON;
    end;
    if Cache.TryGetValue(Key, Result) then
        Exit;

    Result := -1;
    Icon := TIcon.Create;
    try
        FillChar(Info, SizeOf(Info), 0);
        // Иконка конкретного процесса - по пути его exe
        if ExePath <> '' then
            SHGetFileInfo(PChar(ExePath), 0, Info, SizeOf(Info), SHGFI_ICON or Flags);

        // Не извлеклась - стандартная иконка exe без чтения файла
        if Info.hIcon = 0 then
            SHGetFileInfo('placeholder.exe', FILE_ATTRIBUTE_NORMAL, Info, SizeOf(Info),
                SHGFI_ICON or Flags or SHGFI_USEFILEATTRIBUTES);

        if Info.hIcon <> 0 then
        begin
            Icon.Handle := Info.hIcon;
            // AddIcon кладёт копию в список, Icon.Free уничтожит оригинал HICON
            if ASmall then
                Result := ilSmallIcons.AddIcon(Icon)
            else
                Result := ilIcons.AddIcon(Icon);
        end;
    finally
        Icon.Free;
    end;

    Cache.AddOrSetValue(Key, Result);
end;

procedure TChooseTerminalWindow.PopulateList;
var
    Order: TArray<Integer>;
    Count: Integer;
    I, K, Index: Integer;
    Item: TListItem;
    WindowInfo: TWindowMonitorInfo;
    Filter: string;
    GroupMap: TDictionary<string, Integer>;
    GroupId: Integer;
    LG: TLVGroup;
    RawIt: TLVItem;
begin
    GroupMap := nil;
    Filter := Trim(ebFilter.Text).ToLower;

    lvTerminalList.Items.BeginUpdate;
    try
        lvTerminalList.Clear;
        lvTerminalList.Groups.Clear;
        lvTerminalList.HandleNeeded;
        SendMessage(lvTerminalList.Handle, LVM_REMOVEALLGROUPS, 0, 0);
        FWindows := GWinMonitor.GetAllowedWindowsHistory;

        if Length(FWindows) = 0 then
        begin
            UpdateStatusText(-1);
            Exit;
        end;

        // Новые окна сверху (от конца истории к началу) + фильтр
        SetLength(Order, Length(FWindows));
        Count := 0;
        for I := Length(FWindows) - 1 downto 0 do
            if MatchesFilter(FWindows[I], Filter) then
            begin
                Order[Count] := I;
                Inc(Count);
            end;
        SetLength(Order, Count);

        // Сортировка по клику на колонку (режим таблицы)
        if (FSortColumn >= 0) and (Count > 1) then
            TArray.Sort<Integer>(Order, TComparer<Integer>.Construct(
                function(const Left, Right: Integer): Integer
                begin
                    Result := CompareWindows(Left, Right);
                end))
        else if FGroupByProcess and (Count > 1) then
            TArray.Sort<Integer>(Order, TComparer<Integer>.Construct(
                function(const Left, Right: Integer): Integer
                begin
                    Result := CompareText(FWindows[Left].ExeName, FWindows[Right].ExeName);
                    if Result = 0 then
                        Result := -CompareValue(Double(FWindows[Left].ActivatedAt),
                            Double(FWindows[Right].ActivatedAt));
                end));

        lvTerminalList.GroupView := FGroupByProcess and (lvTerminalList.ViewStyle = vsReport);
        if lvTerminalList.GroupView then
            GroupMap := TDictionary<string, Integer>.Create;

        for K := 0 to Count - 1 do
        begin
            Index := Order[K];
            WindowInfo := FWindows[Index];
            Item := lvTerminalList.Items.Add;
            if K < 9 then
                Item.Caption := Format('%d. %s', [K + 1, WindowInfo.WindowTitle])
            else
                Item.Caption := WindowInfo.WindowTitle;
            // Подпись плитки: процесс и время последней активации
            Item.SubItems.Add(Format('%s  ·  %s',
                [WindowInfo.ExeName, FormatDateTime('hh:nn:ss', WindowInfo.ActivatedAt)]));
            // В таблице - мелкие иконки, в плитках - крупные
            if lvTerminalList.ViewStyle = vsReport then
                Item.ImageIndex := ResolveIconIndex(WindowInfo.ExePath, True)
            else
                Item.ImageIndex := ResolveIconIndex(WindowInfo.ExePath, False);
            Item.Data := Pointer(Index);

            if GroupMap <> nil then
            begin
                if not GroupMap.TryGetValue(WindowInfo.ExeName, GroupId) then
                begin
                    GroupId := GroupMap.Count;
                    FillChar(LG, SizeOf(LG), 0);
                    LG.cbSize := SizeOf(LG);
                    LG.mask := LVGF_GROUPID or LVGF_HEADER;
                    LG.iGroupId := GroupId;
                    LG.pszHeader := PChar(WindowInfo.ExeName);
                    LG.cchHeader := Length(WindowInfo.ExeName) + 1;
                    SendMessage(lvTerminalList.Handle, LVM_INSERTGROUP, WPARAM(-1), LPARAM(@LG));
                    GroupMap.Add(WindowInfo.ExeName, GroupId);
                end;
                FillChar(RawIt, SizeOf(RawIt), 0);
                RawIt.mask := LVIF_GROUPID;
                RawIt.iItem := Item.Index;
                RawIt.iGroupID := GroupId;
                SendMessage(lvTerminalList.Handle, LVM_SETITEM, 0, LPARAM(@RawIt));
            end;

            if Index = High(FWindows) then
                Item.SubItems[0] := Item.SubItems[0] + '  ·  ' +
                    TUIStateLoader.GetMessage('Terminal.LastUsed');
        end;

        if Count > 0 then
            lvTerminalList.ItemIndex := 0;
        UpdateStatusText(Count);
    finally
        GroupMap.Free;
        lvTerminalList.Items.EndUpdate;
    end;

    FillLastColumn;
end;

end.
