unit UI.BusyIndicator;

interface

uses
    System.Classes,
    System.SysUtils,
    Vcl.Forms
    ;

type
    // Статический контейнер для показа индикатора занятости на время тяжёлой работы.
    TUIBusyIndicator = record
    public
        // Рисует по центру формы-хозяина карточку с кольцом занятости и подписью,
        // выполняет AWork (синхронно, в главном потоке) и убирает индикатор.
        // На время работы форма-хозяин блокируется для ввода. Сообщения не прокачиваются:
        // кольцо статично, но показывается мгновенно и без риска реентерабельности.
        class procedure Run(AHostForm: TCustomForm; const ACaption: string; AWork: TProc); static;
    end;

implementation

uses
    System.Math,
    Vcl.Controls,
    Vcl.Graphics,
    Vcl.Themes,
    Vcl.WinXCtrls,
    Winapi.Windows
    ;

const
    // Геометрия карточки индикатора
    BUSY_PAD_X = 28;
    BUSY_PAD_Y = 22;
    BUSY_TEXT_GAP = 14;
    BUSY_MIN_TEXT_W = 140;
    BUSY_CORNER_DIA = 18;

type
    // Кодовый оверлей без .dfm: перекрывает клиентскую область формы-хозяина
    TUIBusyOverlay = class(TCustomControl)
    private
        FCaption: string;
        FIndicator: TActivityIndicator;
    protected
        procedure Paint; override;
        procedure Resize; override;
    public
        constructor Create(AOwner: TComponent); override;
        // Подпись под кольцом занятости
        property BusyCaption: string read FCaption write FCaption;
    end;

// Относительная яркость цвета (0..1) для выбора контрастного цвета кольца
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

{ TUIBusyOverlay }

constructor TUIBusyOverlay.Create(AOwner: TComponent);
begin
    inherited Create(AOwner);
    ControlStyle := ControlStyle + [csOpaque];
    DoubleBuffered := True;
    FCaption := '';

    FIndicator := TActivityIndicator.Create(Self);
    FIndicator.Parent := Self;
    FIndicator.IndicatorSize := aisLarge;
end;

procedure TUIBusyOverlay.Paint;
var
    Svc: TCustomStyleServices;
    CardColor: TColor;
    TextW, TextH, CardW, CardH, CardL, CardT, TextL, TextT: Integer;
begin
    Svc := StyleServices;

    // Фоновый слой поверх клиентской области формы-хозяина
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := Svc.GetSystemColor(clBtnFace);
    Canvas.FillRect(ClientRect);

    // Размер карточки определяется подписью и кольцом
    Canvas.Font := Font;
    TextW := Canvas.TextWidth(FCaption);
    TextH := Canvas.TextHeight(FCaption);
    CardW := Max(TextW, BUSY_MIN_TEXT_W) + BUSY_PAD_X * 2;
    CardH := FIndicator.Height + BUSY_TEXT_GAP + TextH + BUSY_PAD_Y * 2;
    CardL := (Width - CardW) div 2;
    CardT := (Height - CardH) div 2;

    // Карточка со скруглёнными углами, цвета берём из активного стиля VCL
    CardColor := Svc.GetSystemColor(clWindow);
    Canvas.Pen.Width := 1;
    Canvas.Pen.Color := Svc.GetSystemColor(clBtnShadow);
    Canvas.Brush.Color := CardColor;
    Canvas.RoundRect(CardL, CardT, CardL + CardW, CardT + CardH, BUSY_CORNER_DIA, BUSY_CORNER_DIA);

    // Цвет кольца контрастен фону карточки
    if GetRelativeLuminance(CardColor) < 0.5 then
        FIndicator.IndicatorColor := aicWhite
    else
        FIndicator.IndicatorColor := aicBlack;

    // Кольцо по центру карточки, подпись под ним
    FIndicator.SetBounds(
        CardL + (CardW - FIndicator.Width) div 2,
        CardT + BUSY_PAD_Y,
        FIndicator.Width,
        FIndicator.Height);

    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := Svc.GetSystemColor(clWindowText);
    TextL := CardL + (CardW - TextW) div 2;
    TextT := CardT + BUSY_PAD_Y + FIndicator.Height + BUSY_TEXT_GAP;
    Canvas.TextOut(TextL, TextT, FCaption);
end;

procedure TUIBusyOverlay.Resize;
begin
    inherited Resize;
    Invalidate;
end;

{ TUIBusyIndicator }

class procedure TUIBusyIndicator.Run(AHostForm: TCustomForm; const ACaption: string; AWork: TProc);
var
    Overlay: TUIBusyOverlay;
    WasEnabled: Boolean;
begin
    if not Assigned(AWork) then
        Exit;

    // Форму-хозяина можно не передавать: берём активную, затем главную
    if AHostForm = nil then
        AHostForm := Screen.ActiveCustomForm;
    if AHostForm = nil then
        AHostForm := Application.MainForm;

    // Показывать индикатор некому - просто выполняем работу
    if AHostForm = nil then
    begin
        AWork();
        Exit;
    end;

    Overlay := TUIBusyOverlay.Create(AHostForm);
    try
        Overlay.BusyCaption := ACaption;
        Overlay.Parent := AHostForm;
        Overlay.Align := alClient;
        Overlay.Visible := True;
        Overlay.BringToFront;
        Overlay.Invalidate;
        Overlay.Update;

        // Блокируем ввод на форме-хозяине, пока выполняется тяжёлая работа
        WasEnabled := AHostForm.Enabled;
        AHostForm.Enabled := False;
        try
            AWork();
        finally
            AHostForm.Enabled := WasEnabled;
        end;
    finally
        Overlay.Free;
    end;
end;

end.
