unit QuickSearchFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    Core.Interfaces.Automation,
    Core.Interfaces.Passwords,
    Core.Interfaces.Services,
    System.Classes,
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
    TQuickSearchForm = class(TBaseForm)
        pnlTop: TPanel;
        lvQuickResults: TListView;
        ebQuickSearch: TEdit;
        rbText: TRadioButton;
        rbFTS: TRadioButton;
        cbUser: TComboBox;
        procedure FormDestroy(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure FormResize(Sender: TObject);
        procedure cbUserChange(Sender: TObject);
        procedure ebQuickSearchChange(Sender: TObject);
        procedure FormHide(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure lvQuickResultsDblClick(Sender: TObject);
        procedure lvQuickResultsEnter(Sender: TObject);
        procedure lvQuickResultsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure lvQuickResultsDeletion(Sender: TObject; Item: TListItem);
        procedure pnlTopResize(Sender: TObject);
    private
        FSnippetService: ISnippetService;
        FUserService: IUserService;
        FTargetHWND: HWND;
        FUserID: Integer;
        FOldAppMessage: TMessageEvent;
        FWindowHelper: IWindowHelper;
        // Глобальный перехватчик подсказок
        FOldAppShowHint: TShowHintEvent;
        FDeactivateTimer: TTimer;
        FSearchTimer: TTimer;
        // Защита от повторного входа при пересчете раскладки верхней панели
        FLayoutLock: Boolean;
        // Естественная ширина cbUser до первого растягивания в вертикальном режиме
        FCbUserBaseWidth: Integer;

        procedure AppMessage(var Msg: TMsg; var Handled: Boolean);
        // Генератор подсказок
        procedure AppShowHint(var HintStr: string; var CanShow: Boolean; var HintInfo: VCL.Controls.THintInfo);
        procedure DeactivateTimerTick(Sender: TObject);
        procedure SearchTimerTick(Sender: TObject);
        procedure InsertSelectedSnippet;
        procedure UpdateResults;
        procedure LoadUsersToComboBox;
        procedure FreeQuickResultsData;
        // Адаптивная раскладка верхней панели: в строку или в столбец
        procedure LayoutTopPanel;
        // Минимальная ширина верхней панели, при которой элементы помещаются в строку
        function TopPanelRequiredWidth: Integer;
        procedure WMActivate(var Msg: TWMActivate); message WM_ACTIVATE;
    protected
        procedure CreateParams(var Params: TCreateParams); override;
        procedure DoClose(var Action: TCloseAction); override;
        procedure DoShownOnScreen; override;
    public
        procedure DoInitialize; override;
        procedure ShowWithService(
            Sender: TObject;
            AppContext: IAppContext;
            UserID: Integer;
            CurrentHWND: HWND
        );
    end;

var
    QuickSearchForm: TQuickSearchForm;

implementation

uses
    Core.Entities.Snippet,
    SnippetRunner,
    SnippetViewData,
    System.UITypes,
    Common.Localization,
    UI.HoverHelpManager,

    Core.Entities.User
    ;

{$R *.dfm}

const
    RESIZE_BORDER_WIDTH = 6;
    // Параметры адаптивной раскладки верхней панели
    TOP_PANEL_GAP = 6;       // Промежуток между элементами
    TOP_PANEL_MARGIN = 2;    // Отступ сверху и снизу внутри панели
    MIN_SEARCH_WIDTH = 150;  // Минимальная ширина поля поиска в горизонтальном режиме

procedure TQuickSearchForm.FormDestroy(Sender: TObject);
begin
    Application.OnMessage := FOldAppMessage;
    FOldAppMessage := nil;

    Application.OnShowHint := FOldAppShowHint;
    FOldAppShowHint := nil;

    FreeQuickResultsData;
    lvQuickResults.Items.Clear;

    inherited;
end;

procedure TQuickSearchForm.FormCreate(Sender: TObject);
begin
    FOldAppMessage := Application.OnMessage;
    Application.OnMessage := AppMessage;

    // Возвращаем старый обработчик подсказок на место при закрытии
    FOldAppShowHint := Application.OnShowHint;
    Application.OnShowHint := AppShowHint;

    Self.ShowHint := True;
    lvQuickResults.ShowHint := True; // Обязательно включаем VCL-подсказки дл¤ списка
    lvQuickResults.HideSelection := False;

    FDeactivateTimer := TTimer.Create(Self);
    FDeactivateTimer.Interval := 30;
    FDeactivateTimer.Enabled := False;
    FDeactivateTimer.OnTimer := DeactivateTimerTick;

    FSearchTimer := TTimer.Create(Self);
    FSearchTimer.Interval := 250;
    FSearchTimer.Enabled := False;
    FSearchTimer.OnTimer := SearchTimerTick;
end;

procedure TQuickSearchForm.DoInitialize;
begin
    // Справка по панели быстрого поиска. Кнопка «?» появляется при наведении
    // на верхнюю панель или на список результатов.
    RegisterHelp(pnlTop, hipTopRight, 'Help.QuickSearchForm', hkCustomForm, -2, 2);
    RegisterHelp(lvQuickResults, hipTopRight, 'Help.QuickSearchForm', hkCustomForm, -2, 2);

    // Локализация уже применена, радиокнопки получили итоговую ширину
    LayoutTopPanel;
end;

function TQuickSearchForm.TopPanelRequiredWidth: Integer;
begin
    // Ширину cbUser запоминаем до первого растягивания: в вертикальном
    // режиме он растягивается на всю панель, и если считать требуемую
    // ширину по текущей, обратный переход в строку станет невозможным
    if FCbUserBaseWidth = 0 then
        FCbUserBaseWidth := cbUser.Width;

    Result := MIN_SEARCH_WIDTH + TOP_PANEL_GAP + rbText.Width +
        TOP_PANEL_GAP + rbFTS.Width + TOP_PANEL_GAP + FCbUserBaseWidth;
end;

procedure TQuickSearchForm.LayoutTopPanel;
var
    ContentWidth: Integer;
    RequiredWidth: Integer;
    CenterTop: Integer;
    PanelHeight: Integer;
    ListHeight: Integer;
begin
    if FLayoutLock then Exit;
    if (pnlTop = nil) or (ebQuickSearch = nil) or (rbText = nil) or
       (rbFTS = nil) or (cbUser = nil) or (lvQuickResults = nil) then Exit;

    FLayoutLock := True;
    try
        ContentWidth := pnlTop.ClientWidth;
        if ContentWidth < 1 then
            ContentWidth := 1;

        RequiredWidth := TopPanelRequiredWidth;

        if ContentWidth >= RequiredWidth then
        begin
            // Элементы помещаются в строку: поиск растягивается,
            // остальные контролы прижимаются к правому краю
            PanelHeight := cbUser.Height + 2 * TOP_PANEL_MARGIN;

            cbUser.SetBounds(ContentWidth - FCbUserBaseWidth, TOP_PANEL_MARGIN,
                FCbUserBaseWidth, cbUser.Height);
            rbFTS.SetBounds(cbUser.Left - TOP_PANEL_GAP - rbFTS.Width, 0,
                rbFTS.Width, rbFTS.Height);
            rbText.SetBounds(rbFTS.Left - TOP_PANEL_GAP - rbText.Width, 0,
                rbText.Width, rbText.Height);
            ebQuickSearch.SetBounds(0, TOP_PANEL_MARGIN,
                rbText.Left - TOP_PANEL_GAP, ebQuickSearch.Height);

            // Радиокнопки центрируем по вертикали относительно поля поиска
            CenterTop := TOP_PANEL_MARGIN + (cbUser.Height - rbText.Height) div 2;
            rbText.Top := CenterTop;
            rbFTS.Top := CenterTop;
        end
        else
        begin
            // Элементы не помещаются: выстраиваем их в столбец
            ebQuickSearch.SetBounds(0, TOP_PANEL_MARGIN, ContentWidth, ebQuickSearch.Height);

            rbText.SetBounds(0, ebQuickSearch.Top + ebQuickSearch.Height + TOP_PANEL_GAP,
                rbText.Width, rbText.Height);
            rbFTS.SetBounds(0, rbText.Top + rbText.Height + TOP_PANEL_GAP,
                rbFTS.Width, rbFTS.Height);
            cbUser.SetBounds(0, rbFTS.Top + rbFTS.Height + TOP_PANEL_GAP,
                ContentWidth, cbUser.Height);

            PanelHeight := cbUser.Top + cbUser.Height + TOP_PANEL_MARGIN;
        end;

        // Высоту меняем только при необходимости: любое изменение панели
        // снова вызывает OnResize, а раскладка уже посчитана
        if pnlTop.Height <> PanelHeight then
            pnlTop.Height := PanelHeight;

        // Список результатов позиционируем вручную, а не через alClient:
        // VCL выравнивает alClient-контролы до того, как панель получит новую
        // высоту, и при переходе в столбец список перекрывал бы панель
        ListHeight := ClientHeight - pnlTop.Top - PanelHeight - Padding.Bottom;
        if ListHeight < 1 then
            ListHeight := 1;
        lvQuickResults.SetBounds(pnlTop.Left, pnlTop.Top + PanelHeight,
            ClientWidth - pnlTop.Left - Padding.Right, ListHeight);
    finally
        FLayoutLock := False;
    end;
end;

procedure TQuickSearchForm.FormResize(Sender: TObject);
begin
    // При изменении размеров формы панель и список пересчитываются вместе
    LayoutTopPanel;
end;

procedure TQuickSearchForm.pnlTopResize(Sender: TObject);
begin
    LayoutTopPanel;
end;

procedure TQuickSearchForm.DoShownOnScreen;
begin
    inherited;

    // Форма прячется через caHide и помнит размер с прошлого показа, поэтому
    // событие OnResize панели при открытии может не прийти. А изменения
    // размеров, сделанные в скрытом состоянии, не всегда применяются к
    // реальным окнам - пересчитываем раскладку в момент фактического показа
    LayoutTopPanel;
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
    // Пропускаем вызов дальше, если были другие обработчики
    if Assigned(FOldAppShowHint) then
        FOldAppShowHint(HintStr, CanShow, HintInfo);

    // Если система просит подсказку именно дл¤ нашего списка:
    if HintInfo.HintControl = lvQuickResults then
    begin
        // Находим, над какой строчкой сейчас мышь
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

        // Говорим менеджеру подсказок: "Ёта подсказка действительна только в границах этого Item-а".
        // пока мышь двигаетс¤ внутри этих границ, VCL не будет перерисовывать окно и моргать.
        // как только мышь выйдет за границы Item-а, VCL сам скроет хинт и запросит новый.
        HintInfo.CursorRect := Item.DisplayRect(drBounds);

        // Динамический расчет ширины и формирование текста
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

            HintStr := ''; // Записываем прямо в системную переменную HintStr

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
    // Пока открыта модальная форма (например, справка), панель не прячем
    if Application.ModalLevel > 0 then Exit;

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
                    // THelpPopupWindow - плавающая кнопка справки: клик по ней
                    // не должен закрывать панель
                    if (ClsName <> 'ComboLBox') and (ClsName <> 'THintWindow') and
                       (ClsName <> 'tooltips_class32') and (ClsName <> 'THelpPopupWindow') then
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

procedure TQuickSearchForm.DoClose(var Action: TCloseAction);
begin
    inherited DoClose(Action);
    Action := caHide;
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
    FSearchTimer.Enabled := False;
    FSearchTimer.Enabled := True;
end;

procedure TQuickSearchForm.SearchTimerTick(Sender: TObject);
begin
    FSearchTimer.Enabled := False;
    UpdateResults;
end;

procedure TQuickSearchForm.FormHide(Sender: TObject);
begin
    FDeactivateTimer.Enabled := False;
    FSearchTimer.Enabled := False;
end;

procedure TQuickSearchForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
    Step: Integer;
    NewAlpha: Integer;
begin
    case Key of
        VK_ESCAPE:
            begin
                if Trim(ebQuickSearch.Text) <> '' then
                begin
                    ebQuickSearch.Text := '';
                    FSearchTimer.Enabled := False;
                    UpdateResults;
                    Key := 0;
                    Exit;
                end;

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

procedure TQuickSearchForm.ShowWithService(
    Sender: TObject;
    AppContext: IAppContext;
    UserID: Integer;
    CurrentHWND: HWND
);
var
    I: Integer;
    ForegroundThread, AppThread: DWORD;
begin
    if FAppContext = nil then
        Initialize(AppContext);

    FSnippetService := AppContext.SnippetService;
    FUserService := AppContext.UserService;
    FTargetHWND := CurrentHWND;
    FUserID := UserID;
    FWindowHelper := AppContext.WindowHelper;

    LoadUsersToComboBox;

    cbUser.ItemIndex := 0;
    for i := 0 to cbUser.Items.Count - 1 do
    begin
        if Integer(cbUser.Items.Objects[i]) = FUserID then
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

    UpdateResults;
    QuickSearchForm.SetFocus;
    ebQuickSearch.SetFocus;
end;

procedure TQuickSearchForm.lvQuickResultsDblClick(Sender: TObject);
begin
    InsertSelectedSnippet;
end;

procedure TQuickSearchForm.lvQuickResultsDeletion(Sender: TObject; Item: TListItem);
begin
    if Assigned(Item.Data) then
        TSnippetViewData(Item.Data).Free;
end;

procedure TQuickSearchForm.FreeQuickResultsData;
var
    I: Integer;
begin
    for I := 0 to lvQuickResults.Items.Count - 1 do
        if Assigned(lvQuickResults.Items[I].Data) then
        begin
            TSnippetViewData(lvQuickResults.Items[I].Data).Free;
            lvQuickResults.Items[I].Data := nil;
        end;
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
        var TickEnd := GetTickCount + 100;
        while (GetForegroundWindow <> FTargetHWND) and (GetTickCount < TickEnd) do
            Sleep(5);
    end;

    Hide;

    Runner := TSnippetRunner.Create(FUserID, AppContext);
    try
        Runner.ExecuteSnippet(Snippet);
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
    SelectedUserID: Integer;
    I: Integer;
    IsFavoritesMode: Boolean;
begin
    // Принудительно гасим подсказку, если она висит, чтобы не было "призраков"
    Application.CancelHint;

    SelectedUserID := 0;
    if cbUser.ItemIndex >= 0 then
        SelectedUserID := Integer(cbUser.Items.Objects[cbUser.ItemIndex]);

    IsFavoritesMode := Trim(ebQuickSearch.Text) = '';

    lvQuickResults.Items.BeginUpdate;
    try
        // TListItems.Clear не вызывает OnDeletion, поэтому данные строк
        // освобождаем вручную, иначе каждая перезагрузка списка течёт
        FreeQuickResultsData;
        lvQuickResults.Items.Clear;

        if IsFavoritesMode then
            // Пустой запрос: показываем избранное (первые 10 - горячие слоты)
            Snippets := FSnippetService.GetFavorites(SelectedUserID)
        else
            Snippets := FSnippetService.SearchSnippets(ebQuickSearch.Text, rbFTS.Checked, SelectedUserID);

        I := 0;
        for Snip in Snippets do
        begin
            Item := lvQuickResults.Items.Add;

            if IsFavoritesMode then
            begin
                if I <= 9 then
                    Item.Caption := #9733 + IntToStr((I + 1) mod 10) + ' ' + Snip.Title
                else
                    Item.Caption := #9733 + ' ' + Snip.Title;
            end
            else
                Item.Caption := Snip.Title;

            ViewData := TSnippetViewData.Create;
            ViewData.ID := Snip.ID;
            ViewData.Title := Snip.Title;
            ViewData.Content := Snip.Content;
            ViewData.Comment := Snip.Comment;
            Item.Data := ViewData;
            Inc(I);
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
        // Модальная справка забирает активацию — панель при этом не закрываем
        if Application.ModalLevel > 0 then Exit;
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
        cbUser.Items.AddObject(TUIStateLoader.GetMessage('Workspace.AllSpaces'), TObject(0));
        Users := FUserService.GetAllUsers;
        for User in Users do
            cbUser.Items.AddObject(User.Name, TObject(Integer(User.ID)));
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
var
    SlotIndex: Integer;
begin
    if Key = VK_RETURN then
    begin
        lvQuickResultsDblClick(lvQuickResults);
        Key := 0;
        Exit;
    end;

    // Цифровые слоты 1..9, 0 работают в списке при пустом запросе (режим избранного)
    if (Shift = []) and (Trim(ebQuickSearch.Text) = '') then
    begin
        SlotIndex := -1;
        case Key of
            Ord('1')..Ord('9'): SlotIndex := Key - Ord('1');
            Ord('0'):           SlotIndex := 9;
            VK_NUMPAD1..VK_NUMPAD9: SlotIndex := Key - VK_NUMPAD1;
            VK_NUMPAD0:         SlotIndex := 9;
        end;

        if (SlotIndex >= 0) and (SlotIndex < lvQuickResults.Items.Count) then
        begin
            lvQuickResults.Selected := lvQuickResults.Items[SlotIndex];
            lvQuickResults.ItemFocused := lvQuickResults.Items[SlotIndex];
            lvQuickResultsDblClick(lvQuickResults);
            Key := 0;
        end;
    end;
end;

end.
