unit SecurityMarkerPlugin;

interface

uses
    SecurityScanner,
    SynDWrite,
    SynEdit,
    SynEditTypes,
    SynFunc,
    SynThemeAdapter,
    System.Math,
    System.SysUtils,
    Vcl.Graphics,
    Winapi.D2D1,
    Winapi.Windows
    ;

type
    // Красные подчёркивания под фрагментами, найденными сканером секретов
    // в редакторе сниппета. Как TMacroCardPlugin: форк рендерит текст через
    // Direct2D, поэтому единственный надёжный хук - phAfterPaint. Линия
    // подчёркивания в нижней полосе строки не перекрывает текст и не
    // конфликтует ни с хайлайтером, ни с карточками макросов
    TSecurityMarkerPlugin = class(TSynEditPlugin)
    private
        FRanges: TArray<TSecretRange>;
        FVisible: Boolean;
        function BufferPosFromOffset(AOffset: Integer): TBufferCoord;
        function HitTestX(const ARowText: string; ACol: TSynNativeInt;
            ATrailing: Boolean): Single;
        function RowTopY(ARow: TSynNativeInt): Integer;
        function RowTextAt(ARow: TSynNativeInt; out AText: string;
            out ALine, AStartChar: TSynNativeInt): Boolean;
        procedure PaintRange(ACanvas: TCanvas; const AClip: TRect;
            const ARange: TSecretRange);
    protected
        procedure AfterPaint(ACanvas: TCanvas; const AClip: TRect;
            FirstLine, LastLine: TSynNativeInt); override;
        property Editor;
    public
        constructor Create(AEditor: TCustomSynEdit);
        // Полная замена набора находок (результат FindSensitiveRanges)
        procedure SetRanges(const ARanges: TArray<TSecretRange>);
        // Подсветка выключена (галочка "Доверенный" в форме)
        property Visible: Boolean read FVisible write FVisible;
    end;

implementation

{ TSecurityMarkerPlugin }

constructor TSecurityMarkerPlugin.Create(AEditor: TCustomSynEdit);
begin
    inherited Create(AEditor, [phAfterPaint]);
    FVisible := True;
end;

procedure TSecurityMarkerPlugin.SetRanges(const ARanges: TArray<TSecretRange>);
begin
    FRanges := ARanges;
    if (Editor <> nil) and Editor.HandleAllocated then
        Editor.Invalidate;
end;

// 0-based офсет в тексте -> буферная координата SynEdit (обход строк,
// +1 символ на перевод строки между ними)
function TSecurityMarkerPlugin.BufferPosFromOffset(AOffset: Integer): TBufferCoord;
var
    I, Remaining, LineLen: Integer;
begin
    Result := BufferCoord(1, 1);
    if (Editor = nil) or (not Editor.HandleAllocated) then
        Exit;

    Remaining := AOffset;
    for I := 0 to Editor.Lines.CountNative - 1 do
    begin
        LineLen := Editor.Lines[I].Length;
        if Remaining <= LineLen then
            Exit(BufferCoord(Remaining + 1, I + 1));
        Dec(Remaining, LineLen + 1);
    end;

    // За пределами текста - конец последней строки
    if Editor.Lines.CountNative > 0 then
        Result := BufferCoord(Editor.Lines[Editor.Lines.CountNative - 1].Length + 1,
            Editor.Lines.CountNative);
end;

function TSecurityMarkerPlugin.HitTestX(const ARowText: string; ACol: TSynNativeInt;
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

function TSecurityMarkerPlugin.RowTopY(ARow: TSynNativeInt): Integer;
begin
    Result := ToInt32((ARow - Editor.TopLine) * Editor.LineHeight);
end;

function TSecurityMarkerPlugin.RowTextAt(ARow: TSynNativeInt; out AText: string;
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

procedure TSecurityMarkerPlugin.PaintRange(ACanvas: TCanvas; const AClip: TRect;
    const ARange: TSecretRange);
var
    StartPos, EndPos, LastCharPos: TBufferCoord;
    RowText: string;
    Row, RowFirst, RowLast: TSynNativeInt;
    RangeLine, RangeStartChar: TSynNativeInt;
    ColFirst, ColLast: TSynNativeInt;
    X1, X2, Y, Y2: Integer;
    Dark: Boolean;
begin
    StartPos := BufferPosFromOffset(ARange.StartOffset);
    EndPos := BufferPosFromOffset(ARange.StartOffset + ARange.Length);
    if StartPos.Line > Editor.Lines.CountNative then
        Exit;

    Dark := TSynThemeAdapter.IsDarkTheme(Editor.Color);
    if Dark then
        // Красный читается на тёмном фоне
        ACanvas.Pen.Color := $005050F0
    else
        ACanvas.Pen.Color := $003C3CC8;
    ACanvas.Pen.Width := 2;
    ACanvas.Brush.Style := bsClear;

    RowFirst := Editor.BufferToDisplayPos(StartPos).Row;
    RowLast := RowFirst;
    if ARange.Length > 0 then
    begin
        LastCharPos := EndPos;
        Dec(LastCharPos.Char);
        RowLast := Editor.BufferToDisplayPos(LastCharPos).Row;
    end;

    for Row := RowFirst to RowLast do
    begin
        if not RowTextAt(Row, RowText, RangeLine, RangeStartChar) then
            Continue;

        ColFirst := 1;
        if (StartPos.Line = RangeLine) and (StartPos.Char >= RangeStartChar) then
            ColFirst := StartPos.Char - RangeStartChar + 1;

        ColLast := Max(1, RowText.Length);
        if (EndPos.Line = RangeLine) and
           (EndPos.Char - RangeStartChar < RowText.Length) then
            ColLast := Max(1, EndPos.Char - RangeStartChar);

        X1 := ToInt32(Editor.GutterWidth + Editor.TextMargin -
            (Editor.LeftChar - 1) * Editor.CharWidth) +
            Round(HitTestX(RowText, ColFirst, False));
        X2 := ToInt32(Editor.GutterWidth + Editor.TextMargin -
            (Editor.LeftChar - 1) * Editor.CharWidth) +
            Round(HitTestX(RowText, ColLast, True)) + 1;

        Y := RowTopY(Row);
        // Дисциплина полосы строки из TMacroCardPlugin: рисуем только
        // внутри [Y, Y+LineHeight-1], иначе пиксели живут как "призраки"
        Y2 := Y + ToInt32(Editor.LineHeight) - 1;

        // Линия подчёркивания 2px на нижней кромке строки
        if Rect(X1, Y2 - 2, Max(X2, X1 + 2), Y2 + 1).IntersectsWith(AClip) then
        begin
            ACanvas.MoveTo(X1, Y2 - 1);
            ACanvas.LineTo(Max(X2, X1 + 2), Y2 - 1);
        end;
    end;
end;

procedure TSecurityMarkerPlugin.AfterPaint(ACanvas: TCanvas; const AClip: TRect;
    FirstLine, LastLine: TSynNativeInt);
var
    Range: TSecretRange;
begin
    if (not FVisible) or (Editor = nil) or (not Editor.HandleAllocated) then
        Exit;

    for Range in FRanges do
        PaintRange(ACanvas, AClip, Range);
end;

end.
