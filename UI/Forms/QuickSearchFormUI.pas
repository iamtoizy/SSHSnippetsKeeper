unit QuickSearchFormUI;

interface

uses
    Winapi.Windows,
    Winapi.Messages,
    System.SysUtils,
    System.Variants,
    System.Classes,
    Vcl.Graphics,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.Dialogs,
    Vcl.StdCtrls,
    Core.Interfaces,
    Snippet,
    SnippetRunner,
    User,
    UserService,
    Vcl.ComCtrls,
    Vcl.ExtCtrls,
    System.UITypes,
    TrackBarEx;

type
    TQuickSearchForm = class(TForm)
        lvQuickResults: TListView;
        ebQuickSearch: TEdit;
        rbText: TRadioButton;
        rbFTS: TRadioButton;
        cbUser: TComboBox;
        procedure FormDestroy(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure cbUserChange(Sender: TObject);
        procedure ebQuickSearchChange(Sender: TObject);
        procedure FormHide(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure lvQuickResultsDblClick(Sender: TObject);
        procedure lvQuickResultsEnter(Sender: TObject);
        procedure lvQuickResultsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    private
        FSnippetService: ISnippetService;
        FUserService: IUserService;
        FTargetHWND: HWND;
        FUserID: NativeInt;
        FOldAppMessage: TMessageEvent;
        // √лобальный перехватчик подсказок
        FOldAppShowHint: TShowHintEvent;
        FDeactivateTimer: TTimer;

        procedure AppMessage(var Msg: TMsg; var Handled: Boolean);
        // √енератор подсказок
        procedure AppShowHint(var HintStr: string; var CanShow: Boolean; var HintInfo: VCL.Controls.THintInfo);
        procedure DeactivateTimerTick(Sender: TObject);
        procedure InsertSelectedSnippet;
        procedure UpdateResults;
        procedure LoadUsersToComboBox;
        procedure WMActivate(var Msg: TWMActivate); message WM_ACTIVATE;
    protected
        procedure CreateParams(var Params: TCreateParams); override;
    public
        procedure ShowWithService(Sender: TObject; SnippetService: ISnippetService; UserService: IUserService; UserID: NativeInt; CurrentHWND: HWND);
    end;

var
    QuickSearchForm: TQuickSearchForm;

implementation

uses
    SnippetViewData;

{$R *.dfm}

const
    RESIZE_BORDER_WIDTH = 6;

procedure TQuickSearchForm.FormDestroy(Sender: TObject);
begin
    if Assigned(FOldAppMessage) then
    begin
        Application.OnMessage := FOldAppMessage;
        FOldAppMessage := nil;
    end;

    // ¬озвращаем старый обработчик подсказок на место при закрытии
    if Assigned(FOldAppShowHint) then
    begin
        Application.OnShowHint := FOldAppShowHint;
        FOldAppShowHint := nil;
    end;

    inherited;
end;

procedure TQuickSearchForm.FormCreate(Sender: TObject);
begin
    FOldAppMessage := Application.OnMessage;
    Application.OnMessage := AppMessage;

    // ѕерехватываем генерацию подсказок на уровне всего приложени€
    FOldAppShowHint := Application.OnShowHint;
    Application.OnShowHint := AppShowHint;

    Self.ShowHint := True;
    lvQuickResults.ShowHint := True; // ќб€зательно включаем VCL-подсказки дл€ списка
    lvQuickResults.HideSelection := False;

    FDeactivateTimer := TTimer.Create(Self);
    FDeactivateTimer.Interval := 30;
    FDeactivateTimer.Enabled := False;
    FDeactivateTimer.OnTimer := DeactivateTimerTick;
end;

procedure TQuickSearchForm.AppShowHint(var HintStr: string; var CanShow: Boolean; var HintInfo: VCL.Controls.THintInfo);
var
    Item: TListItem;
    Pt: TPoint;
    ViewData: TSnippetViewData;
    Lines: TStringList;
    I, MaxLines: Integer;
    CurrentLine: string;
    MaxTipWidth: Integer;
    CurrentMonitor: TMonitor;
begin
    // ѕропускаем вызов дальше, если были другие обработчики
    if Assigned(FOldAppShowHint) then
        FOldAppShowHint(HintStr, CanShow, HintInfo);

    // ≈сли система просит подсказку именно дл€ нашего списка:
    if HintInfo.HintControl = lvQuickResults then
    begin
        // Ќаходим, над какой строчкой сейчас мышь
        Pt := lvQuickResults.ScreenToClient(Mouse.CursorPos);
        Item := lvQuickResults.GetItemAt(Pt.X, Pt.Y);

        if (Item = nil) or (Item.Data = nil) then
        begin
            CanShow := False;
            Exit;
        end;

        ViewData := TSnippetViewData(Item.Data);
        if ViewData.Content.IsEmpty then
        begin
            CanShow := False;
            Exit;
        end;

        // √оворим менеджеру подсказок: "Ёта подсказка действительна только в границах этого Item-а".
        // ѕока мышь двигаетс€ внутри этих границ, VCL не будет перерисовывать окно и моргать.
        //  ак только мышь выйдет за границы Item-а, VCL сам скроет хинт и запросит новый.
        HintInfo.CursorRect := Item.DisplayRect(drBounds);

        // ƒинамический расчет ширины и формирование текста
        CurrentMonitor := Screen.MonitorFromWindow(Handle);
        MaxTipWidth := Round(CurrentMonitor.Width * 0.40);

        Self.Canvas.Font.Assign(Self.Font);
        Self.Canvas.Font.Size := Screen.HintFont.Size;

        Lines := TStringList.Create;
        try
            Lines.Text := ViewData.Content;

            if Lines.Count > 10 then
                MaxLines := 10
            else
                MaxLines := Lines.Count;

            HintStr := ''; // «аписываем пр€мо в системную переменную HintStr

            for I := 0 to MaxLines - 1 do
            begin
                if I > 0 then HintStr := HintStr + #13#10;
                CurrentLine := Lines[I];

                if Self.Canvas.TextWidth(CurrentLine) > MaxTipWidth then
                begin
                    while (CurrentLine <> '') and (Self.Canvas.TextWidth(CurrentLine + '...') > MaxTipWidth) do
                    begin
                        Delete(CurrentLine, Length(CurrentLine), 1);
                    end;
                    CurrentLine := CurrentLine + '...';
                end;

                HintStr := HintStr + CurrentLine;
            end;

            if Lines.Count > 10 then
                HintStr := HintStr + #13#10 + '...';
        finally
            Lines.Free;
        end;
    end;
end;

procedure TQuickSearchForm.DeactivateTimerTick(Sender: TObject);
var
    ForeWnd, WndAtPos: HWND;
    ClickPos: TPoint;
    ProcessId: DWORD;
    IsMouseDown: Boolean;
    WinClassName: array[0..255] of Char;
    ClsName: string;
begin
    if not Self.Visible then Exit;
    if TSnippetRunner.IsExecuting then Exit;

    ForeWnd := GetForegroundWindow;
    if (ForeWnd <> 0) and (ForeWnd <> FTargetHWND) and (ForeWnd <> Self.Handle) then
    begin
        Close;
        Exit;
    end;

    IsMouseDown := (GetAsyncKeyState(VK_LBUTTON) < 0) or
                   (GetAsyncKeyState(VK_RBUTTON) < 0) or
                   (GetAsyncKeyState(VK_MBUTTON) < 0);

    if IsMouseDown then
    begin
        GetCursorPos(ClickPos);
        WndAtPos := WindowFromPoint(ClickPos);
        if WndAtPos <> 0 then
        begin
            GetWindowThreadProcessId(WndAtPos, @ProcessId);
            if ProcessId <> GetCurrentProcessId() then
            begin
                Close;
                Exit;
            end
            else
            begin
                if (WndAtPos <> Self.Handle) and not IsChild(Self.Handle, WndAtPos) then
                begin
                    GetClassName(WndAtPos, WinClassName, Length(WinClassName));
                    ClsName := string(WinClassName);
                    if (ClsName <> 'ComboLBox') and (ClsName <> 'THintWindow') and (ClsName <> 'tooltips_class32') then
                    begin
                        Close;
                        Exit;
                    end;
                end;
            end;
        end;
    end;
end;

procedure TQuickSearchForm.CreateParams(var Params: TCreateParams);
begin
    inherited CreateParams(Params);
    Params.Style := WS_POPUP or WS_CLIPCHILDREN;
    Params.ExStyle := Params.ExStyle or WS_EX_TOPMOST or WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE;
    Params.WndParent := GetDesktopWindow;
end;

procedure TQuickSearchForm.AppMessage(var Msg: TMsg; var Handled: Boolean);
    function GetHitZone(ScreenPt: TPoint): Integer;
    var
        ClientPt: TPoint;
    begin
        ClientPt := ScreenToClient(ScreenPt);

        if ClientPt.X < RESIZE_BORDER_WIDTH then
        begin
            if ClientPt.Y < RESIZE_BORDER_WIDTH then Exit(HTTOPLEFT);
            if ClientPt.Y >= ClientHeight - RESIZE_BORDER_WIDTH then Exit(HTBOTTOMLEFT);
            Exit(HTLEFT);
        end;

        if ClientPt.X >= ClientWidth - RESIZE_BORDER_WIDTH then
        begin
            if ClientPt.Y < RESIZE_BORDER_WIDTH then Exit(HTTOPRIGHT);
            if ClientPt.Y >= ClientHeight - RESIZE_BORDER_WIDTH then Exit(HTBOTTOMRIGHT);
            Exit(HTRIGHT);
        end;

        if ClientPt.Y < RESIZE_BORDER_WIDTH then Exit(HTTOP);
        if ClientPt.Y >= ClientHeight - RESIZE_BORDER_WIDTH then Exit(HTBOTTOM);

        if (GetKeyState(VK_CONTROL) and $8000) <> 0 then
            Exit(HTCAPTION);

        Result := HTCLIENT;
    end;
var
    HitZone: Integer;
    SysCmd: WPARAM;
    Pt: TPoint;
    IsOverForm: Boolean;
    WndUnderMouse: HWND;
begin
    if Assigned(FOldAppMessage) then
        FOldAppMessage(Msg, Handled);

    if Handled or not Self.Visible then Exit;

    Pt := Msg.pt;
    IsOverForm := PtInRect(Self.BoundsRect, Pt);

    if Msg.message = WM_KEYDOWN then
    begin
        if (Msg.wParam = VK_CONTROL) and ((Msg.lParam and (1 shl 30)) = 0) then
        begin
            if IsOverForm then
            begin
                Screen.Cursor := crSizeAll;
                WndUnderMouse := WindowFromPoint(Pt);
                if WndUnderMouse <> 0 then
                    SendMessage(WndUnderMouse, WM_SETCURSOR, WndUnderMouse, HTCLIENT or (WM_MOUSEMOVE shl 16));
            end;
        end;
    end
    else if Msg.message = WM_KEYUP then
    begin
        if Msg.wParam = VK_CONTROL then
        begin
            if Screen.Cursor = crSizeAll then
            begin
                Screen.Cursor := crDefault;
                WndUnderMouse := WindowFromPoint(Pt);
                if WndUnderMouse <> 0 then
                    SendMessage(WndUnderMouse, WM_SETCURSOR, WndUnderMouse, HTCLIENT or (WM_MOUSEMOVE shl 16));
            end;
        end;
    end;

    if (Msg.message = WM_MOUSEMOVE) or (Msg.message = WM_LBUTTONDOWN) then
    begin
        if not IsOverForm then
        begin
            if Screen.Cursor <> crDefault then
                Screen.Cursor := crDefault;
        end
        else
        begin
            if (Msg.hwnd = Handle) or IsChild(Handle, Msg.hwnd) then
            begin
                HitZone := GetHitZone(Pt);

                if HitZone <> HTCLIENT then
                begin
                    if Msg.message = WM_MOUSEMOVE then
                    begin
                        case HitZone of
                            HTCAPTION:                Screen.Cursor := crSizeAll;
                            HTLEFT, HTRIGHT:          Screen.Cursor := crSizeWE;
                            HTTOP, HTBOTTOM:          Screen.Cursor := crSizeNS;
                            HTTOPLEFT, HTBOTTOMRIGHT: Screen.Cursor := crSizeNWSE;
                            HTTOPRIGHT, HTBOTTOMLEFT: Screen.Cursor := crSizeNESW;
                        end;
                        Handled := True;
                    end
                    else if Msg.message = WM_LBUTTONDOWN then
                    begin
                        ReleaseCapture;
                        case HitZone of
                            HTCAPTION:     SysCmd := $F012;
                            HTLEFT:        SysCmd := SC_SIZE + 1;
                            HTRIGHT:       SysCmd := SC_SIZE + 2;
                            HTTOP:         SysCmd := SC_SIZE + 3;
                            HTTOPLEFT:     SysCmd := SC_SIZE + 4;
                            HTTOPRIGHT:    SysCmd := SC_SIZE + 5;
                            HTBOTTOM:      SysCmd := SC_SIZE + 6;
                            HTBOTTOMLEFT:  SysCmd := SC_SIZE + 7;
                            HTBOTTOMRIGHT: SysCmd := SC_SIZE + 8;
                        else
                            SysCmd := 0;
                        end;

                        if SysCmd <> 0 then
                        begin
                            SendMessage(Handle, WM_SYSCOMMAND, SysCmd, 0);
                            GetCursorPos(Pt);
                            if ((GetKeyState(VK_CONTROL) and $8000) <> 0) and PtInRect(Self.BoundsRect, Pt) then
                                Screen.Cursor := crSizeAll
                            else
                                Screen.Cursor := crDefault;
                        end;
                        Handled := True;
                    end;
                end
                else
                begin
                    if Screen.Cursor <> crDefault then
                        Screen.Cursor := crDefault;
                end;
            end;
        end;
    end;
end;

procedure TQuickSearchForm.cbUserChange(Sender: TObject);
begin
    if cbUser.ItemIndex >= 0 then
        UpdateResults;
end;

procedure TQuickSearchForm.ebQuickSearchChange(Sender: TObject);
begin
    UpdateResults;
end;

procedure TQuickSearchForm.FormHide(Sender: TObject);
begin
    FDeactivateTimer.Enabled := False;
end;

procedure TQuickSearchForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
    Step: Integer;
    NewAlpha: Integer;
begin
    case Key of
        VK_ESCAPE:
            begin
                Close;
                Exit;
            end;
        VK_RETURN:
            begin
                InsertSelectedSnippet;
                Key := 0;
                Exit;
            end;
        VK_UP, VK_DOWN:
            begin
                if (ssCtrl in Shift) and (ssAlt in Shift) then
                begin
                    if ssShift in Shift then Step := 20 else Step := 10;
                    if Key = VK_DOWN then Step := -Step;

                    NewAlpha := Self.AlphaBlendValue + Step;
                    if NewAlpha < 30 then NewAlpha := 30;
                    if NewAlpha > 255 then NewAlpha := 255;

                    Self.AlphaBlend := True;
                    Self.AlphaBlendValue := NewAlpha;

                    Key := 0;
                    Exit;
                end;

                if not lvQuickResults.Focused then
                begin
                    lvQuickResults.SetFocus;
                    Key := 0;
                end;
            end;
    end;
end;

procedure TQuickSearchForm.ShowWithService(Sender: TObject; SnippetService: ISnippetService; UserService: IUserService; UserID: NativeInt; CurrentHWND: HWND);
var
    i: Integer;
    ForegroundThread, AppThread: DWORD;
begin
    FSnippetService := SnippetService;
    FUserService := UserService;
    FTargetHWND := CurrentHWND;
    FUserID := UserID;

    LoadUsersToComboBox;

    cbUser.ItemIndex := 0;
    for i := 0 to cbUser.Items.Count - 1 do
    begin
        if NativeInt(cbUser.Items.Objects[i]) = FUserID then
        begin
            cbUser.ItemIndex := i;
            Break;
        end;
    end;

    Show;
    FDeactivateTimer.Enabled := True;

    ForegroundThread := GetWindowThreadProcessId(GetForegroundWindow, nil);
    AppThread := GetCurrentThreadId;

    if ForegroundThread <> AppThread then
    begin
        AttachThreadInput(AppThread, ForegroundThread, True);
        try
            SetForegroundWindow(Handle);
            BringWindowToTop(Handle);
        finally
            AttachThreadInput(AppThread, ForegroundThread, False);
        end;
    end
    else
    begin
        SetForegroundWindow(Handle);
        BringWindowToTop(Handle);
    end;

    ebQuickSearch.Text := '';
    UpdateResults;
    QuickSearchForm.SetFocus;
    ebQuickSearch.SetFocus;
end;

procedure TQuickSearchForm.lvQuickResultsDblClick(Sender: TObject);
begin
    InsertSelectedSnippet;
end;

procedure TQuickSearchForm.InsertSelectedSnippet;
var
    Item: TListItem;
    Runner: TSnippetRunner;
    Snippet: TSnippetDTO;
    ForeThread, AppThread: DWORD;
begin
    Item := lvQuickResults.Selected;
    if Item = nil then Exit;

    Snippet.ID := TSnippetViewData(Item.Data).ID;
    Snippet.Title := TSnippetViewData(Item.Data).Title;
    Snippet.Content := TSnippetViewData(Item.Data).Content;
    Snippet.Comment := TSnippetViewData(Item.Data).Comment;

    if IsWindow(FTargetHWND) then
    begin
        ForeThread := GetWindowThreadProcessId(GetForegroundWindow, nil);
        AppThread := GetCurrentThreadId;

        if ForeThread <> AppThread then
            AttachThreadInput(AppThread, ForeThread, True);

        try
            SetForegroundWindow(FTargetHWND);
            BringWindowToTop(FTargetHWND);
        finally
            if ForeThread <> AppThread then
                AttachThreadInput(AppThread, ForeThread, False);
        end;
        Sleep(20);
    end;

    Hide;

    Runner := TSnippetRunner.Create(FUserID);
    try
        Runner.ExecuteSnippet(Snippet, False);
    finally
        Runner.Free;
    end;
end;

procedure TQuickSearchForm.UpdateResults;
var
    Snippets: TArray<TSnippetDTO>;
    Snip: TSnippetDTO;
    Item: TListItem;
    ViewData: TSnippetViewData;
    SelectedUserID: NativeInt;
begin
    // ѕринудительно гасим подсказку, если она висит, чтобы не было "призраков"
    Application.CancelHint;

    SelectedUserID := 0;
    if cbUser.ItemIndex >= 0 then
        SelectedUserID := NativeInt(cbUser.Items.Objects[cbUser.ItemIndex]);

    lvQuickResults.Items.BeginUpdate;
    try
        lvQuickResults.Items.Clear;
        Snippets := FSnippetService.SearchSnippets(ebQuickSearch.Text, rbFTS.Checked, SelectedUserID);

        for Snip in Snippets do
        begin
            Item := lvQuickResults.Items.Add;
            Item.Caption := Snip.Title;
            ViewData := TSnippetViewData.Create;
            ViewData.ID := Snip.ID;
            ViewData.Title := Snip.Title;
            ViewData.Content := Snip.Content;
            ViewData.Comment := Snip.Comment;
            Item.Data := ViewData;
        end;

        if lvQuickResults.Items.Count > 0 then
        begin
            lvQuickResults.ItemIndex := 0;
            lvQuickResults.Selected := lvQuickResults.Items[0];
            lvQuickResults.Items[0].Focused := True;
        end;
    finally
        lvQuickResults.Items.EndUpdate;
    end;
end;

procedure TQuickSearchForm.WMActivate(var Msg: TWMActivate);
begin
    inherited;
    if Msg.Active = WA_INACTIVE then
    begin
        if not TSnippetRunner.IsExecuting then
            Close;
    end;
end;

procedure TQuickSearchForm.LoadUsersToComboBox;
var
    Users: TArray<TUserDTO>;
    User: TUserDTO;
begin
    cbUser.Items.BeginUpdate;
    try
        cbUser.Clear;
        cbUser.Items.AddObject('¬се пространства', TObject(0));
        Users := FUserService.GetAllUsers;
        for User in Users do
            cbUser.Items.AddObject(User.Name, TObject(NativeInt(User.ID)));
        cbUser.ItemIndex := 0;
    finally
        cbUser.Items.EndUpdate;
    end;
end;

procedure TQuickSearchForm.lvQuickResultsEnter(Sender: TObject);
begin
    if (lvQuickResults.Items.Count > 0) and (lvQuickResults.Selected = nil) then
    begin
        lvQuickResults.ItemIndex := 0;
        lvQuickResults.Selected := lvQuickResults.Items[0];
        lvQuickResults.Items[0].Focused := True;
        lvQuickResults.Selected.MakeVisible(False);
    end;
end;

procedure TQuickSearchForm.lvQuickResultsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if Key = VK_RETURN then
    begin
        lvQuickResultsDblClick(lvQuickResults);
        Key := 0;
    end;
end;

end.
