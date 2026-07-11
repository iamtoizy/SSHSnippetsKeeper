unit TrackBarEx;

interface

uses
  System.Classes,
  System.Types,
  Vcl.ComCtrls,
  Vcl.Forms,
  Vcl.Controls,
  Winapi.Windows,
  Winapi.Messages;

type
  TTrackBar = class(Vcl.ComCtrls.TTrackBar)
  private
    FHideFocusApplied: Boolean;
  protected
    procedure WndProc(var Message: TMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure HideFocusRect;
    class procedure DeleteAllFocusRectangles(Form: TForm);
    property OnMouseUp;
  end;

implementation

{ TTrackBar }

constructor TTrackBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FHideFocusApplied := False;
end;

procedure TTrackBar.HideFocusRect;
begin
  FHideFocusApplied := True;
  Invalidate; // Принудительно запрашиваем перерисовку
end;

class procedure TTrackBar.DeleteAllFocusRectangles(Form: TForm);
var
  I: Integer;
begin
  if not Assigned(Form) then Exit;

  for I := 0 to Form.ComponentCount - 1 do
  begin
    if Form.Components[I] is TTrackBar then
      TTrackBar(Form.Components[I]).HideFocusRect;
  end;
end;

procedure TTrackBar.WndProc(var Message: TMessage);
var
  MemDC, DestDC: HDC;
  MemBmp, OldBmp: HBITMAP;
  PS: TPaintStruct;
  R: TRect;
  w, h: Integer;
  OrigWParam: WPARAM;
begin
  // Ловим отрисовку (работает и для классической темы, и для VCL Styles)
  if ((Message.Msg = WM_PAINT) or (Message.Msg = WM_PRINTCLIENT)) and FHideFocusApplied then
  begin
    Winapi.Windows.GetClientRect(Handle, R);
    w := R.Right - R.Left;
    h := R.Bottom - R.Top;

    OrigWParam := Message.WParam;

    if (Message.Msg = WM_PAINT) and (OrigWParam = 0) then
      DestDC := BeginPaint(Handle, PS)
    else
      DestDC := HDC(OrigWParam);

    try
      // Создаем двойной буфер в оперативной памяти
      MemDC := CreateCompatibleDC(DestDC);
      MemBmp := CreateCompatibleBitmap(DestDC, w, h);
      OldBmp := SelectObject(MemDC, MemBmp);
      try
        // 1. Позволяем VCL нарисовать контрол (фон, трекбар, ползунок и рамку) в наш буфер
        Message.WParam := WPARAM(MemDC);
        inherited WndProc(Message);

        // 2. ГРАФИЧЕСКИЙ ХАК (Затирка краев):
        // Рамка всегда на краю. А вот линия на 3 пикселя вглубь — это 100% чистый фон.
        // Берем этот чистый фон и "размазываем" его наружу, перекрывая рамку фокуса.
        SetStretchBltMode(MemDC, COLORONCOLOR);

        // Затираем верх (размазываем чистую строку y=3 вверх на 3 пикселя)
        StretchBlt(MemDC, 0, 0, w, 3, MemDC, 0, 3, w, 1, SRCCOPY);

        // Затираем низ (размазываем чистую строку y=h-4 вниз на 3 пикселя)
        StretchBlt(MemDC, 0, h - 3, w, 3, MemDC, 0, h - 4, w, 1, SRCCOPY);

        // Затираем левый край (размазываем чистый столбец x=3 влево на 3 пикселя)
        StretchBlt(MemDC, 0, 0, 3, h, MemDC, 3, 0, 1, h, SRCCOPY);

        // Затираем правый край (размазываем чистый столбец x=w-4 вправо на 3 пикселя)
        StretchBlt(MemDC, w - 3, 0, 3, h, MemDC, w - 4, 0, 1, h, SRCCOPY);

        // 3. Выводим идеально чистое изображение на настоящий экран
        BitBlt(DestDC, 0, 0, w, h, MemDC, 0, 0, SRCCOPY);
      finally
        SelectObject(MemDC, OldBmp);
        DeleteObject(MemBmp);
        DeleteDC(MemDC);
      end;
    finally
      if (Message.Msg = WM_PAINT) and (OrigWParam = 0) then
        EndPaint(Handle, PS);
    end;

    Message.WParam := OrigWParam;
    Exit;
  end;

  inherited WndProc(Message);
end;

end.
