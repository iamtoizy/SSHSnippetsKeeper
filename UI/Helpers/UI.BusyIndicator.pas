unit UI.BusyIndicator;

interface

uses
    System.Classes,
    System.SysUtils,
    Vcl.Forms
    ;

type
    // Статический контейнер индикатора занятости. Одновременно существует не более
    // одного индикатора (UI однопоточный). Типовой сценарий "до показа формы":
    // Show -> подготовка формы -> ShowModal; индикатор скрывается автоматически
    // в TBaseForm.DoShownOnScreen в момент фактического показа формы на экране.
    TUIBusyIndicator = record
    public
        // Показывает вуаль с карточкой-подписью поверх формы-хозяина и включает
        // системный анимированный курсор ожидания. Кольцо ожидания рисует сама ОС,
        // поэтому движение не замирает даже при полностью занятом UI-потоке.
        // Хозяин не блокируется: оверлей перехватывает мышь, сообщения UI-потока не прокачиваются.
        class procedure Show(AHostForm: TCustomForm; const ACaption: string); static;
        // Убирает индикатор и восстанавливает курсор. Повторный вызов безопасен.
        class procedure Hide; static;
        // Показывает индикатор, синхронно выполняет AWork и убирает индикатор.
        class procedure Run(AHostForm: TCustomForm; const ACaption: string; AWork: TProc); static;
    end;

implementation

uses
    System.Math,
    System.Types,
    UI.HoverHelpManager,
    Vcl.Controls,
    Vcl.Graphics,
    Vcl.Themes,
    Winapi.Messages,
    Winapi.Windows
    ;

const
    // Геометрия карточки (в условных пикселях, масштабируется под DPI)
    BUSY_PAD_X = 28;
    BUSY_PAD_Y = 22;
    BUSY_MIN_TEXT_W = 140;
    BUSY_CORNER_DIA = 18;

    // Непрозрачность вуали (0..255): интерфейс за индикатором остаётся видимым,
    // состояние списка/дерева не выглядит "потерянным"
    BUSY_SCRIM_ALPHA = 215;

    BUSY_WND_CLASS = 'SSHSnippetsBusyOverlayWnd';

    // Потоковые сообщения управления оверлеем (PostThreadMessage, hwnd = 0)
    BUSY_THREAD_MSG_SHOW = WM_USER + 1;
    BUSY_THREAD_MSG_HIDE = WM_USER + 2;

type
    // Единственный поток оверлея, живёт всю работу приложения: создаётся в
    // initialization и крутит собственный цикл сообщений. Показ и скрытие
    // сводятся к PostThreadMessage без какого-либо ожидания в UI-потоке.
    // Оверлей статичен: вуаль + карточка с подписью рисуются одним кадром.
    // Покадровая перерисовка слоистого окна блокировалась на секунды во время
    // холодной постройки формы (синхронные замки win32k/DWM), поэтому сигналом
    // движения стал системный курсор ожидания IDC_WAIT, анимируемый самой ОС.
    // Поток не трогает VCL: палитра, шрифт и геометрия готовятся в UI-потоке,
    // рисование - чистый GDI в контексте этого потока.
    TBusyOverlayThread = class(TThread)
    private
        FQueueReady: THandle;
        FClassRegistered: Boolean;
        FRect: TRect;
        FCaption: string;
        FFontName: string;
        FFontHeight: Integer;
        FScaleNum: Integer;
        FScaleDen: Integer;
        FAlpha: Byte;
        FDimColor: COLORREF;
        FCardColor: COLORREF;
        FBorderColor: COLORREF;
        FTextColor: COLORREF;
        FWnd: HWND;
        FDimBrush: HBRUSH;
        FCardBrush: HBRUSH;
        FBorderPen: HPEN;
        FFont: HFONT;

        class function WndProcStatic(Wnd: HWND; Msg: UINT; WParam: WPARAM;
            LParam: LPARAM): LRESULT; static; stdcall;
        function HandleMsg(Wnd: HWND; Msg: UINT; WParam: WPARAM;
            LParam: LPARAM): LRESULT;
        procedure RegisterOverlayClass;
        function EnsureWindow: Boolean;
        procedure WarmUpFonts;
        procedure ApplyShow;
        procedure ApplyHide;
        procedure CreateGdiObjects;
        procedure FreeGdiObjects;
        procedure DoPaint(DC: HDC);
    protected
        procedure Execute; override;
    public
        constructor Create;
        procedure AfterConstruction; override;
        // Готовит параметры и просит поток показать оверлей (не блокирует UI)
        procedure ShowAsync(AHostForm: TCustomForm; const ACaption: string);
        // Просит поток скрыть оверлей (не блокирует UI)
        procedure HideAsync;
    end;

var
    // Единственный экземпляр потока оверлея (создаётся в initialization)
    GBusyThread: TBusyOverlayThread = nil;
    // Оверлей показан (флаг UI-потока, мгновенная защита от повторного Show)
    GBusyShown: Boolean = False;

// Относительная яркость цвета (0..1) для выбора контрастной палитры
function GetRelativeLuminance(AColor: TColor): Double;
var
    R, G, B: Byte;
begin
    AColor := ColorToRGB(AColor);
    R := GetRValue(AColor);
    G := GetGValue(AColor);
    B := GetBValue(AColor);
    Result := (0.299 * R + 0.587 * G + 0.114 * B) / 255.0;
end;

{ TBusyOverlayThread }

constructor TBusyOverlayThread.Create;
begin
    inherited Create(True);
    FreeOnTerminate := False;
    FQueueReady := CreateEventW(nil, True, False, nil);
    FWnd := 0;
    FClassRegistered := False;
end;

procedure TBusyOverlayThread.AfterConstruction;
begin
    inherited;
    Start;
end;

procedure TBusyOverlayThread.RegisterOverlayClass;
var
    WC: TWndClassW;
    RegAtom: ATOM;
    LastErr: DWORD;
begin
    if FClassRegistered then
        Exit;
    FillChar(WC, SizeOf(WC), 0);
    // Курсор класса - системное анимированное кольцо ожидания: его вращает ОС
    // независимо от загрузки приложения. Без CS_SAVEBITS: слоистое окно
    // композитит DWM, а экономия битов экрана даёт артефакты восстановления
    WC.lpfnWndProc := TFNWndProc(@TBusyOverlayThread.WndProcStatic);
    WC.hInstance := HInstance;
    WC.hCursor := LoadCursor(0, IDC_WAIT);
    WC.lpszClassName := PWideChar(BUSY_WND_CLASS);
    RegAtom := RegisterClassW(WC);
    LastErr := GetLastError;
    FClassRegistered := (RegAtom <> 0) or (LastErr = ERROR_CLASS_ALREADY_EXISTS);
end;

function TBusyOverlayThread.EnsureWindow: Boolean;
begin
    if FWnd <> 0 then
        Exit(True);
    if not FClassRegistered then
        RegisterOverlayClass;
    if not FClassRegistered then
        Exit(False);
    // Владелец из другого потока в CreateWindowExW даёт ERROR_INVALID_WINDOW_HANDLE:
    // создаём окно без владельца, поверх всех окон его держит WS_EX_TOPMOST.
    // Окно живёт вечно скрытым: создание окна выполняется заранее, на старте потока
    FWnd := CreateWindowExW(
        WS_EX_TOPMOST or WS_EX_LAYERED or WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE,
        PWideChar(BUSY_WND_CLASS), '',
        WS_POPUP,
        0, 0, 1, 1,
        0, 0, HInstance, Pointer(Self));
    if FWnd = 0 then
        Exit(False);
    Result := True;
end;

procedure TBusyOverlayThread.WarmUpFonts;
var
    DC, MemDC: HDC;
    Bmp, OldBmp: HBITMAP;
    Fnt: HFONT;
    OldFnt: HGDIOBJ;
    Sz: TSize;
    S: string;
begin
    // Первый рендер текста (инициализация движка, растеризация глифов) идёт
    // заметно долго - прогреваем его вне пути первого показа
    DC := GetDC(0);
    try
        MemDC := CreateCompatibleDC(DC);
        try
            Bmp := CreateCompatibleBitmap(DC, 64, 64);
            OldBmp := SelectObject(MemDC, Bmp);
            Fnt := CreateFontW(-12, 0, 0, 0, FW_NORMAL, 0, 0, 0,
                DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                CLEARTYPE_QUALITY, DEFAULT_PITCH, 'Segoe UI');
            OldFnt := SelectObject(MemDC, Fnt);
            S := 'Открытие формы...';
            GetTextExtentPoint32W(MemDC, PWideChar(S), Length(S), Sz);
            TextOutW(MemDC, 0, 0, PWideChar(S), Length(S));
            SelectObject(MemDC, OldFnt);
            DeleteObject(Fnt);
            SelectObject(MemDC, OldBmp);
            DeleteObject(Bmp);
        finally
            DeleteDC(MemDC);
        end;
    finally
        ReleaseDC(0, DC);
    end;
end;

procedure TBusyOverlayThread.CreateGdiObjects;
begin
    FDimBrush := CreateSolidBrush(FDimColor);
    FCardBrush := CreateSolidBrush(FCardColor);
    FBorderPen := CreatePen(PS_SOLID, 1, FBorderColor);
    FFont := CreateFontW(-Abs(FFontHeight), 0, 0, 0, FW_NORMAL, 0, 0, 0,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
        DEFAULT_PITCH, PWideChar(FFontName));
end;

procedure TBusyOverlayThread.FreeGdiObjects;
begin
    if FDimBrush <> 0 then DeleteObject(FDimBrush);
    if FCardBrush <> 0 then DeleteObject(FCardBrush);
    if FBorderPen <> 0 then DeleteObject(FBorderPen);
    if FFont <> 0 then DeleteObject(FFont);
    FDimBrush := 0;
    FCardBrush := 0;
    FBorderPen := 0;
    FFont := 0;
end;

procedure TBusyOverlayThread.ApplyShow;
begin
    if not EnsureWindow then
        Exit;

    // Палитра, шрифт и масштаб могут измениться между показами
    FreeGdiObjects;
    CreateGdiObjects;

    // Окно с WS_EX_LAYERED без установленных атрибутов вообще не отображается:
    // при неудаче убираем слоистость, оверлей остаётся непрозрачным
    if not SetLayeredWindowAttributes(FWnd, 0, 0, LWA_ALPHA) then
        SetWindowLongPtr(FWnd, GWL_EXSTYLE,
            GetWindowLongPtr(FWnd, GWL_EXSTYLE) and not WS_EX_LAYERED);
    SetWindowPos(FWnd, HWND_TOPMOST,
        FRect.Left, FRect.Top,
        FRect.Right - FRect.Left, FRect.Bottom - FRect.Top,
        SWP_NOACTIVATE or SWP_SHOWWINDOW);
    // Единственный кадр: карточка статична, перерисовывать нечего - движение
    // показывает системный курсор ожидания
    InvalidateRect(FWnd, nil, False);
    UpdateWindow(FWnd);
    SetLayeredWindowAttributes(FWnd, 0, FAlpha, LWA_ALPHA);
end;

procedure TBusyOverlayThread.ApplyHide;
begin
    // Окно не уничтожаем - оно постоянное, скрываем и освобождаем GDI-объекты
    if FWnd <> 0 then
        ShowWindow(FWnd, SW_HIDE);
    FreeGdiObjects;
end;

procedure TBusyOverlayThread.Execute;
var
    Msg: TMsg;
begin
    // Очередь сообщений должна существовать до первого PostThreadMessage из UI-потока
    PeekMessage(Msg, 0, WM_USER, WM_USER, PM_NOREMOVE);
    SetEvent(FQueueReady);
    RegisterOverlayClass;
    // Дорогие разовые операции - вне пути первого показа
    EnsureWindow;
    WarmUpFonts;

    // Оверлей статичен: поток только обслуживает показ/скрытие окна,
    // никакой анимации и таймеров
    while Integer(GetMessageW(Msg, 0, 0, 0)) > 0 do
    begin
        if Msg.message = BUSY_THREAD_MSG_SHOW then
            ApplyShow
        else if Msg.message = BUSY_THREAD_MSG_HIDE then
            ApplyHide
        else
        begin
            TranslateMessage(Msg);
            DispatchMessageW(Msg);
        end;
    end;

    ApplyHide;
    if FWnd <> 0 then
    begin
        DestroyWindow(FWnd);
        FWnd := 0;
    end;
    CloseHandle(FQueueReady);
end;

class function TBusyOverlayThread.WndProcStatic(Wnd: HWND; Msg: UINT;
    WParam: WPARAM; LParam: LPARAM): LRESULT;
var
    Obj: TBusyOverlayThread;
begin
    // Пока CreateWindowExW не вернулся, поле FWnd ещё нулевое, поэтому все
    // сообщения создания маршрутизируем только через реальный Wnd
    if Msg = WM_NCCREATE then
    begin
        SetWindowLongPtr(Wnd, GWLP_USERDATA,
            NativeInt(PCREATESTRUCTW(LParam).lpCreateParams));
        Result := DefWindowProcW(Wnd, Msg, WParam, LParam);
        Exit;
    end;
    Obj := TBusyOverlayThread(GetWindowLongPtr(Wnd, GWLP_USERDATA));
    if Obj <> nil then
        Result := Obj.HandleMsg(Wnd, Msg, WParam, LParam)
    else
        Result := DefWindowProcW(Wnd, Msg, WParam, LParam);
end;

function TBusyOverlayThread.HandleMsg(Wnd: HWND; Msg: UINT; WParam: WPARAM;
    LParam: LPARAM): LRESULT;
var
    PS: TPaintStruct;
    DC: HDC;
begin
    case Msg of
        WM_ERASEBKGND:
            // Фон целиком рисуется в WM_PAINT одной проходкой, без мерцания
            Result := 1;
        WM_PAINT:
            begin
                DC := BeginPaint(Wnd, PS);
                try
                    DoPaint(DC);
                finally
                    EndPaint(Wnd, PS);
                end;
                Result := 0;
            end;
    else
        Result := DefWindowProcW(Wnd, Msg, WParam, LParam);
    end;
end;

procedure TBusyOverlayThread.DoPaint(DC: HDC);
var
    W, H: Integer;
    S: Double;
    Sz: TSize;
    PadX, PadY, Corner: Integer;
    TextW, TextH, CardW, CardH, CardL, CardT: Integer;
    OldFont: HGDIOBJ;
begin
    W := FRect.Right - FRect.Left;
    H := FRect.Bottom - FRect.Top;
    if (W <= 0) or (H <= 0) then
        Exit;
    S := FScaleNum / FScaleDen;
    PadX := Max(2, Round(BUSY_PAD_X * S));
    PadY := Max(2, Round(BUSY_PAD_Y * S));
    Corner := Max(2, Round(BUSY_CORNER_DIA * S));

    // Вуаль
    FillRect(DC, Rect(0, 0, W, H), FDimBrush);

    // Подпись и размеры карточки
    OldFont := SelectObject(DC, FFont);
    GetTextExtentPoint32W(DC, PWideChar(FCaption), Length(FCaption), Sz);
    TextW := Sz.cx;
    TextH := Sz.cy;
    CardW := Max(TextW, Round(BUSY_MIN_TEXT_W * S)) + PadX * 2;
    CardH := TextH + PadY * 2;
    CardL := (W - CardW) div 2;
    CardT := (H - CardH) div 2;

    // Карточка со скруглёнными углами и подписью по центру
    SelectObject(DC, FBorderPen);
    SelectObject(DC, FCardBrush);
    RoundRect(DC, CardL, CardT, CardL + CardW, CardT + CardH, Corner, Corner);
    SetBkMode(DC, TRANSPARENT);
    SetTextColor(DC, FTextColor);
    TextOutW(DC, CardL + (CardW - TextW) div 2, CardT + (CardH - TextH) div 2,
        PWideChar(FCaption), Length(FCaption));
    SelectObject(DC, OldFont);
end;

procedure TBusyOverlayThread.ShowAsync(AHostForm: TCustomForm; const ACaption: string);
var
    Svc: TCustomStyleServices;
    DimColor: TColor;
    DarkUI: Boolean;
    R: TRect;
    P: TPoint;
    ScaleNum: Integer;
    FontHeight: Integer;
begin
    // Очередь потока готова (практически мгновенно; фолбэк на случай,
    // если Show вызван раньше, чем поток вошёл в Execute)
    if WaitForSingleObject(FQueueReady, 2000) <> WAIT_OBJECT_0 then
        Exit;

    // Палитра и шрифт - только в UI-потоке: VCL-стили не потокобезопасны
    Svc := StyleServices;
    DimColor := Svc.GetSystemColor(clBtnFace);
    DarkUI := GetRelativeLuminance(DimColor) < 0.5;
    FDimColor := ColorToRGB(DimColor);
    if DarkUI then
    begin
        FCardColor := RGB(40, 40, 46);
        FBorderColor := RGB(96, 96, 104);
        FTextColor := RGB(235, 235, 235);
    end
    else
    begin
        FCardColor := RGB(255, 255, 255);
        FBorderColor := ColorToRGB(Svc.GetSystemColor(clBtnShadow));
        FTextColor := RGB(20, 20, 20);
    end;

    // Оверлей закрывает клиентскую область хозяина (экранные координаты)
    R := AHostForm.ClientRect;
    P := AHostForm.ClientToScreen(Point(R.Left, R.Top));
    OffsetRect(R, P.X - R.Left, P.Y - R.Top);
    FRect := R;

    ScaleNum := 96;
    {$IF CompilerVersion >= 33.0}
    if AHostForm.CurrentPPI > 0 then
        ScaleNum := AHostForm.CurrentPPI;
    {$IFEND}
    FScaleNum := ScaleNum;
    FScaleDen := 96;

    FontHeight := Abs(AHostForm.Font.Height);
    if FontHeight <= 0 then
        FontHeight := MulDiv(16, ScaleNum, 96);
    FFontHeight := FontHeight;
    FFontName := AHostForm.Font.Name;
    FCaption := ACaption;
    FAlpha := BUSY_SCRIM_ALPHA;

    PostThreadMessage(ThreadID, BUSY_THREAD_MSG_SHOW, 0, 0);
end;

procedure TBusyOverlayThread.HideAsync;
begin
    PostThreadMessage(ThreadID, BUSY_THREAD_MSG_HIDE, 0, 0);
end;

{ TUIBusyIndicator }

class procedure TUIBusyIndicator.Show(AHostForm: TCustomForm; const ACaption: string);
begin
    if GBusyShown then
        Exit;

    // Форму-хозяина можно не передавать: берём активную, затем главную
    if AHostForm = nil then
        AHostForm := Screen.ActiveCustomForm;
    if AHostForm = nil then
        AHostForm := Application.MainForm;
    if (AHostForm = nil) or not AHostForm.HandleAllocated then
        Exit;

    // Плавающие кнопки контекстной помощи замирали поверх индикатора
    // непокрашенным квадратом (сообщения не прокачиваются - скрыться сами не могут)
    TUIHoverHelpManager.SuppressForBusy;
    // Кольцо ожидания рисует ОС: анимированный курсор не замирает,
    // даже когда UI-поток полностью занят постройкой формы
    Screen.Cursor := crHourGlass;
    GBusyShown := True;
    GBusyThread.ShowAsync(AHostForm, ACaption);
end;

class procedure TUIBusyIndicator.Hide;
begin
    if not GBusyShown then
        Exit;
    GBusyShown := False;
    Screen.Cursor := crDefault;
    TUIHoverHelpManager.ResumeAfterBusy;
    // Скрытие неблокирующее: окно скроет поток оверлея в своём цикле
    GBusyThread.HideAsync;
end;

class procedure TUIBusyIndicator.Run(AHostForm: TCustomForm; const ACaption: string; AWork: TProc);
begin
    if not Assigned(AWork) then
        Exit;

    Show(AHostForm, ACaption);
    try
        AWork();
    finally
        Hide;
    end;
end;

initialization
    // Поток оверлея один и живёт всю работу приложения: показ/скрытие без запуска потоков
    GBusyThread := TBusyOverlayThread.Create;

finalization
    if GBusyThread <> nil then
    begin
        PostThreadMessage(GBusyThread.ThreadID, WM_QUIT, 0, 0);
        GBusyThread.WaitFor;
        GBusyThread.Free;
        GBusyThread := nil;
    end;

end.
