unit MacroCardPlugin;

interface

uses
    MacroCardController,
    MacroEngine,
    MacroInputTypes,
    SynDWrite,
    SynEdit,
    SynEditTypes,
    SynFunc,
    SynThemeAdapter,
    System.Classes,
    System.Math,
    System.SysUtils,
    Vcl.Graphics,
    Winapi.D2D1,
    Winapi.Windows
    ;

type
    // Подсветка макросов-карточек в TSynEdit.
    // В этом форке текст рендерится через Direct2D, а PaintTransient
    // вызывается вне цикла D2D-отрисовки и затирается следующим репейнтом.
    // Единственный надёжный хук на каждую перерисовку - phAfterPaint:
    // карточки рисуются ПОСЛЕ текста, поэтому заливка полупрозрачная
    // (AlphaBlend из msimg32, premultiplied 1x1 DIB),
    // рамка и индикатор переноса - непрозрачные.
    TMacroCardPlugin = class(TSynEditPlugin)
    private
        FController: TMacroCardController;
        FSelectedCard: Integer;
        FDropOffset: Integer;
        FDropValid: Boolean;
        FDragActive: Boolean;
        function HitTestX(const ARowText: string; ACol: TSynNativeInt;
            ATrailing: Boolean): Single;
        function ColumnToPixelX(const ARowText: string; ACol: TSynNativeInt;
            ATrailing: Boolean): Integer;
        function RowTopY(ARow: TSynNativeInt): Integer;
        function RowTextAt(ARow: TSynNativeInt; out AText: string;
            out ALine, AStartChar: TSynNativeInt): Boolean;
        procedure CardColors(const AToken: TMacroToken; ACardPos: Integer;
            out AFill, ABorder: TColor);
        procedure FillAlphaRect(ACanvas: TCanvas; const R: TRect;
            AColor: TColor; AAlpha: Byte);
        procedure PaintCard(ACanvas: TCanvas; const AClip: TRect;
            const AToken: TMacroToken; ACardPos: Integer);
        procedure PaintDropHint(ACanvas: TCanvas);
    protected
        procedure AfterPaint(ACanvas: TCanvas; const AClip: TRect;
            FirstLine, LastLine: TSynNativeInt); override;
        property Editor;
    public
        constructor Create(AEditor: TCustomSynEdit; AController: TMacroCardController);
        property Controller: TMacroCardController read FController;
        property SelectedCard: Integer read FSelectedCard write FSelectedCard;
        // Смещение строки-индикатора переноса (0-based, -1 = не рисовать)
        property DropOffset: Integer read FDropOffset write FDropOffset;
        property DropValid: Boolean read FDropValid write FDropValid;
        property DragActive: Boolean read FDragActive write FDragActive;
    end;

implementation

const
    CardAlphaNormal = 100;
    CardAlphaSelected = 140;
    CardAlphaUnknown = 120;

var
    AlphaLib: THandle = 0;
    AlphaBlendFn: function(hdcDest: HDC; nXOriginDest, nYOriginDest,
        nWidthDest, nHeightDest: Integer; hdcSrc: HDC; nXOriginSrc, nYOriginSrc,
        nSrcWidth, nSrcHeight: Integer; blend: TBlendFunction): BOOL; stdcall = nil;
    FillDC: HDC = 0;
    FillBmp: HBITMAP = 0;
    FillOldBmp: HGDIOBJ = 0;
    FillBits: Pointer = nil;

{ TMacroCardPlugin }

procedure EnsureAlphaFill;
var
    BI: TBitmapInfo;
begin
    if Assigned(AlphaBlendFn) then
        Exit;

    if AlphaLib = 0 then
        AlphaLib := LoadLibrary(msimg32);
    if AlphaLib = 0 then
        Exit;

    @AlphaBlendFn := GetProcAddress(AlphaLib, 'AlphaBlend');
    if not Assigned(AlphaBlendFn) then
        Exit;

    FillDC := CreateCompatibleDC(0);
    FillChar(BI, SizeOf(BI), 0);
    BI.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
    BI.bmiHeader.biWidth := 1;
    BI.bmiHeader.biHeight := 1;
    BI.bmiHeader.biPlanes := 1;
    BI.bmiHeader.biBitCount := 32;
    BI.bmiHeader.biCompression := BI_RGB;
    FillBmp := CreateDIBSection(FillDC, BI, DIB_RGB_COLORS, FillBits, 0, 0);
    if FillBmp <> 0 then
        FillOldBmp := SelectObject(FillDC, FillBmp)
    else
        FillBits := nil;
end;

constructor TMacroCardPlugin.Create(AEditor: TCustomSynEdit; AController: TMacroCardController);
begin
    inherited Create(AEditor, [phAfterPaint]);
    FController := AController;
    FSelectedCard := -1;
    FDropOffset := -1;
end;

procedure TMacroCardPlugin.CardColors(const AToken: TMacroToken; ACardPos: Integer;
    out AFill, ABorder: TColor);
var
    Dark: Boolean;
begin
    Dark := TSynThemeAdapter.IsDarkTheme(Editor.Color);

    if (AToken.Kind = tkUnknown) or AToken.Invalid then
    begin
        if Dark then
        begin
            AFill := $00303048;
            ABorder := $005555A0;
        end
        else
        begin
            AFill := $00DFDFFA;
            ABorder := $006A6AC4;
        end;
    end
    else if ACardPos = FSelectedCard then
    begin
        if Dark then
        begin
            AFill := $005E4C3E;
            ABorder := $00B4783C;
        end
        else
        begin
            AFill := $00F2E0CC;
            ABorder := $00964B1E;
        end
    end
    else
    begin
        if Dark then
        begin
            AFill := $00443830;
            ABorder := $0086705A;
        end
        else
        begin
            AFill := $00FAF1E8;
            ABorder := $00DCC4A8;
        end;
    end;
end;

procedure TMacroCardPlugin.FillAlphaRect(ACanvas: TCanvas; const R: TRect;
    AColor: TColor; AAlpha: Byte);
var
    BF: TBlendFunction;
    C: Integer;
begin
    EnsureAlphaFill;
    if (not Assigned(AlphaBlendFn)) or (FillBits = nil) or IsRectEmpty(R) then
        Exit;

    C := ColorToRGB(AColor);
    PCardinal(FillBits)^ := (Cardinal(AAlpha) shl 24) or
        (Cardinal((C and $FF) * AAlpha div 255) shl 16) or
        (Cardinal(((C shr 8) and $FF) * AAlpha div 255) shl 8) or
        Cardinal(((C shr 16) and $FF) * AAlpha div 255);

    BF.BlendOp := AC_SRC_OVER;
    BF.BlendFlags := 0;
    BF.SourceConstantAlpha := 255;
    BF.AlphaFormat := AC_SRC_ALPHA;

    AlphaBlendFn(ACanvas.Handle, R.Left, R.Top, R.Right - R.Left,
        R.Bottom - R.Top, FillDC, 0, 0, 1, 1, BF);
end;

function TMacroCardPlugin.HitTestX(const ARowText: string; ACol: TSynNativeInt;
    ATrailing: Boolean): Single;
var
    Layout: TSynTextLayout;
    X, Y: Single;
    HTM: TDwriteHitTestMetrics;
begin
    if ARowText = '' then
        Exit(0);

    Layout.Create(Editor.TextFormat, PChar(ARowText), ARowText.Length,
        MaxInt, Editor.LineHeight);
    Layout.IDW.HitTestTextPosition(ToUInt32(Max(ACol - 1, 0)), ATrailing, X, Y, HTM);
    Result := X;
end;

function TMacroCardPlugin.ColumnToPixelX(const ARowText: string;
    ACol: TSynNativeInt; ATrailing: Boolean): Integer;
begin
    Result := ToInt32(Editor.GutterWidth + Editor.TextMargin -
        (Editor.LeftChar - 1) * Editor.CharWidth);
    if ARowText = '' then
        Exit;

    Result := Result + Round(HitTestX(ARowText, ACol, ATrailing));
    if ATrailing then
        Inc(Result);
end;

function TMacroCardPlugin.RowTopY(ARow: TSynNativeInt): Integer;
begin
    Result := ToInt32((ARow - Editor.TopLine) * Editor.LineHeight);
end;

function TMacroCardPlugin.RowTextAt(ARow: TSynNativeInt; out AText: string;
    out ALine, AStartChar: TSynNativeInt): Boolean;
var
    BC, NextBC: TBufferCoord;
    LineText: string;
begin
    Result := False;
    AText := '';
    ALine := 0;
    AStartChar := 1;
    if (Editor = nil) or (not Editor.HandleAllocated) or (ARow < 1) then
        Exit;

    BC := Editor.DisplayToBufferPos(DisplayCoord(1, ARow));
    ALine := BC.Line;
    AStartChar := BC.Char;
    if (ALine < 1) or (ALine > Editor.Lines.CountNative) then
        Exit;

    LineText := Editor.Lines[ALine - 1];
    if AStartChar > LineText.Length + 1 then
        AStartChar := LineText.Length + 1;

    if Editor.WordWrap then
    begin
        NextBC := Editor.DisplayToBufferPos(DisplayCoord(1, ARow + 1));
        if (NextBC.Line = ALine) and (NextBC.Char > AStartChar) then
            AText := Copy(LineText, AStartChar, NextBC.Char - AStartChar)
        else
            AText := Copy(LineText, AStartChar, LineText.Length - AStartChar + 1);
    end
    else
    begin
        AStartChar := 1;
        AText := LineText;
    end;
    Result := True;
end;

procedure TMacroCardPlugin.PaintCard(ACanvas: TCanvas; const AClip: TRect;
    const AToken: TMacroToken; ACardPos: Integer);
var
    StartPos, EndPos, LastCharPos: TBufferCoord;
    RowText: string;
    Row, RowFirst, RowLast: TSynNativeInt;
    TokenLine, TokenStartChar: TSynNativeInt;
    ColFirst, ColLast: TSynNativeInt;
    Origin, X1, X2, Y, Y2: Integer;
    LeftLine, RightLine: Integer;
    TrailX: Single;
    R: TRect;
    Fill, Border: TColor;
    Alpha: Byte;
begin
    StartPos := FController.BufferPosFromOffset(AToken.StartOffset - 1);
    EndPos := FController.BufferPosFromOffset(AToken.StartOffset - 1 + AToken.Length);
    if StartPos.Line > Editor.Lines.CountNative then
        Exit;

    CardColors(AToken, ACardPos, Fill, Border);

    if (AToken.Kind = tkUnknown) or AToken.Invalid then
        Alpha := CardAlphaUnknown
    else if ACardPos = FSelectedCard then
        Alpha := CardAlphaSelected
    else
        Alpha := CardAlphaNormal;

    ACanvas.Pen.Color := Border;
    ACanvas.Pen.Width := 1;
    ACanvas.Brush.Style := bsClear;

    Origin := ToInt32(Editor.GutterWidth + Editor.TextMargin -
        (Editor.LeftChar - 1) * Editor.CharWidth);

    RowFirst := Editor.BufferToDisplayPos(StartPos).Row;
    RowLast := RowFirst;
    if AToken.Length > 0 then
    begin
        LastCharPos := EndPos;
        Dec(LastCharPos.Char);
        RowLast := Editor.BufferToDisplayPos(LastCharPos).Row;
    end;

    for Row := RowFirst to RowLast do
    begin
        if not RowTextAt(Row, RowText, TokenLine, TokenStartChar) then
            Continue;

        ColFirst := 1;
        if (StartPos.Line = TokenLine) and (StartPos.Char >= TokenStartChar) then
            ColFirst := StartPos.Char - TokenStartChar + 1;

        ColLast := Max(1, RowText.Length);
        if (EndPos.Line = TokenLine) and
           (EndPos.Char - TokenStartChar < RowText.Length) then
            ColLast := Max(1, EndPos.Char - TokenStartChar);

        TrailX := HitTestX(RowText, ColLast, True);
        X1 := Origin + Round(HitTestX(RowText, ColFirst, False));
        X2 := Origin + Round(TrailX) + 1;
        Y := RowTopY(Row);
        // Всю отрисовку держим в полосе строки [Y, Y+LineHeight-1]:
        // InvalidateLines инвалидирует целыми полосами, и пиксель на
        // Y+LineHeight выживает как "призрак" при сжатии строки.
        Y2 := Y + ToInt32(Editor.LineHeight) - 1;
        R := Rect(X1, Y, Max(X2, X1 + 2), Y2 + 1);

        if not R.IntersectsWith(AClip) then
            Continue;

        FillAlphaRect(ACanvas, R, Fill, Alpha);

        LeftLine := R.Left;
        RightLine := Origin + Floor(TrailX);
        if RightLine <= LeftLine then
            RightLine := R.Right - 1;

        ACanvas.MoveTo(LeftLine, Y + 1);
        ACanvas.LineTo(RightLine, Y + 1);
        ACanvas.MoveTo(LeftLine, Y2);
        ACanvas.LineTo(RightLine, Y2);
        ACanvas.MoveTo(LeftLine, Y + 1);
        ACanvas.LineTo(LeftLine, Y2);
        ACanvas.MoveTo(RightLine, Y + 1);
        ACanvas.LineTo(RightLine, Y2);
    end;
end;

procedure TMacroCardPlugin.PaintDropHint(ACanvas: TCanvas);
var
    BP: TBufferCoord;
    RowText: string;
    Row, TokenLine, TokenStartChar: TSynNativeInt;
    X, Y, Y2: Integer;
    Dark: Boolean;
begin
    if (not FDragActive) or (FDropOffset < 0) or (FController = nil) or
       (Editor = nil) or (not Editor.HandleAllocated) then
        Exit;

    BP := FController.BufferPosFromOffset(FDropOffset);
    Row := Editor.BufferToDisplayPos(BP).Row;
    if not RowTextAt(Row, RowText, TokenLine, TokenStartChar) then
        Exit;

    X := ColumnToPixelX(RowText,
        Min(Max(BP.Char - TokenStartChar + 1, 1), RowText.Length + 1), False);
    Y := RowTopY(Row);
    // Та же дисциплина полосы строки, что и в PaintCard
    Y2 := Y + ToInt32(Editor.LineHeight) - 1;

    Dark := TSynThemeAdapter.IsDarkTheme(Editor.Color);
    if FDropValid then
    begin
        if Dark then
            ACanvas.Pen.Color := $0070B050
        else
            ACanvas.Pen.Color := $0050A020;
    end
    else
    begin
        if Dark then
            ACanvas.Pen.Color := $006060C0
        else
            ACanvas.Pen.Color := $004040C0;
    end;

    ACanvas.Pen.Width := 2;
    ACanvas.MoveTo(X, Y);
    ACanvas.LineTo(X, Y2);
    ACanvas.Pen.Width := 1;
end;

procedure TMacroCardPlugin.AfterPaint(ACanvas: TCanvas; const AClip: TRect;
    FirstLine, LastLine: TSynNativeInt);
var
    CardPos: Integer;
    Token: TMacroToken;
begin
    if (FController = nil) or (Editor = nil) or (not Editor.HandleAllocated) then
        Exit;

    for CardPos := 0 to FController.ScannedCardCount - 1 do
    begin
        Token := FController.ScannedCardToken(CardPos);
        PaintCard(ACanvas, AClip, Token, CardPos);
    end;

    PaintDropHint(ACanvas);
end;

initialization

finalization

if FillDC <> 0 then
begin
    if FillOldBmp <> 0 then
        SelectObject(FillDC, FillOldBmp);
    if FillBmp <> 0 then
        DeleteObject(FillBmp);
    DeleteDC(FillDC);
    FillDC := 0;
    FillBmp := 0;
    FillOldBmp := 0;
    FillBits := nil;
end;
if AlphaLib <> 0 then
begin
    FreeLibrary(AlphaLib);
    AlphaLib := 0;
    AlphaBlendFn := nil;
end;

end.
