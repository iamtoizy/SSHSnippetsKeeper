unit SynThemeAdapter;

interface

uses
    System.SysUtils,
    System.Classes,
    Vcl.Graphics,
    Vcl.Themes,
    Vcl.Forms,
    Winapi.Windows,
    Winapi.Messages,
    SynEdit,
    SynEditHighlighter;

type
    // Глобальный класс-перехватчик.
    // Он доступен всем формам, которые подключат этот модуль.
    TSynEdit = class(SynEdit.TSynEdit)
        private
        procedure WMEraseBkgnd(var Message: TWmEraseBkgnd); message WM_ERASEBKGND;
    end;

    TSynPalette = record
        Background: TColor;
        Foreground: TColor;
        Keyword: TColor;
        Comment: TColor;
        Str: TColor;
        Number: TColor;
        Symbol: TColor;
        ActiveLine: TColor;
        GutterBackground: TColor;
        GutterForeground: TColor;
        GutterBorder: TColor;
        RightEdge: TColor;
    end;

    TSynThemeAdapter = class
    private
        class function IsDarkTheme(BgColor: TColor): Boolean;
        class function GetDarkPalette: TSynPalette;
        class function GetLightPalette: TSynPalette;
    public
        class procedure ApplyTheme(SynEdit: TCustomSynEdit);
    end;

implementation

{ TSynThemeAdapter }

class function TSynThemeAdapter.IsDarkTheme(BgColor: TColor): Boolean;
var
    RGBColor: Longint;
    R, G, B: Byte;
    Luminance: Integer;
begin
    RGBColor := ColorToRGB(BgColor);
    R := GetRValue(RGBColor);
    G := GetGValue(RGBColor);
    B := GetBValue(RGBColor);
    Luminance := Trunc(0.299 * R + 0.587 * G + 0.114 * B);
    Result := Luminance < 128;
end;

class function TSynThemeAdapter.GetDarkPalette: TSynPalette;
begin
    Result.Background := $001E1E1E;
    Result.Foreground := $00D4D4D4;
    Result.Keyword := $00D69C56;
    Result.Comment := $005C8A5C;
    Result.Str := $0080B0CE;
    Result.Number := $00AAC6B5;
    Result.Symbol := $00D4D4D4;
    Result.ActiveLine := $00323232;
    Result.GutterBackground := $00252526;
    Result.GutterForeground := $00858585;
    Result.GutterBorder := $00404040;
    Result.RightEdge := $00404040;
end;

class function TSynThemeAdapter.GetLightPalette: TSynPalette;
begin
    Result.Background := clWindow;
    Result.Foreground := clWindowText;
    Result.Keyword := clNavy;
    Result.Comment := $00808000;
    Result.Str := clBlue;
    Result.Number := clBlack;
    Result.Symbol := clBlack;
    Result.ActiveLine := $00E6E6FF;
    Result.GutterBackground := clBtnFace;
    Result.GutterForeground := clWindowText;
    Result.GutterBorder := clSilver;
    Result.RightEdge := clSilver;
end;

class procedure TSynThemeAdapter.ApplyTheme(SynEdit: TCustomSynEdit);
var
    SysBgColor: TColor;
    Palette: TSynPalette;
    Hl: TSynCustomHighlighter;
    I: Integer;
    Attr: TSynHighlighterAttributes;
    AttrName: string;
begin
    if not Assigned(SynEdit) then
        Exit;

  // Берем цвет напрямую из текущего стиля VCL (решает проблему с мерцанием)
    if TStyleManager.IsCustomStyleActive then
        SysBgColor := TStyleManager.ActiveStyle.GetStyleColor(scEdit)
    else
        SysBgColor := clWindow;

    if IsDarkTheme(SysBgColor) then
        Palette := GetDarkPalette
    else
        Palette := GetLightPalette;

  // Базовые цвета редактора
    SynEdit.Color := SysBgColor;
    SynEdit.Font.Color := Palette.Foreground;
    SynEdit.ActiveLineColor := Palette.ActiveLine;

  // Цвета панели Gutter
    SynEdit.Gutter.Color := Palette.GutterBackground;
    SynEdit.Gutter.Font.Color := Palette.GutterForeground;

  // Именно это свойство отвечает за вертикальную разделительную линию
    SynEdit.Gutter.BorderColor := Palette.GutterBorder;

    SynEdit.RightEdgeColor := Palette.RightEdge;

  // Адаптация хайлайтера
    Hl := SynEdit.Highlighter;
    if Assigned(Hl) then
    begin
        for I := 0 to Hl.AttrCount - 1 do
        begin
            Attr := Hl.Attribute[I];
            AttrName := UpperCase(Attr.Name);
            Attr.Background := clNone;

            if (Pos('KEY', AttrName) > 0) or (Pos('RESERVED', AttrName) > 0) then
                Attr.Foreground := Palette.Keyword
            else if Pos('COMMENT', AttrName) > 0 then
                Attr.Foreground := Palette.Comment
            else if Pos('STRING', AttrName) > 0 then
                Attr.Foreground := Palette.Str
            else if Pos('NUMBER', AttrName) > 0 then
                Attr.Foreground := Palette.Number
            else if Pos('SYMBOL', AttrName) > 0 then
                Attr.Foreground := Palette.Symbol
            else if Pos('IDENTIFIER', AttrName) > 0 then
                Attr.Foreground := Palette.Foreground
            else if Pos('SPACE', AttrName) > 0 then
            begin
                Attr.Foreground := Palette.Foreground;
                Attr.Background := clNone;
            end
            else
                Attr.Foreground := Palette.Foreground;
        end;
    end;

  // Настройка CodeFolding (плюсики/минусики и их линии)
    SynEdit.CodeFolding.CollapsedLineColor := Palette.GutterForeground;
    SynEdit.CodeFolding.FolderBarLinesColor := Palette.GutterBorder;
end;

{ TSynEdit }

procedure TSynEdit.WMEraseBkgnd(var Message: TWmEraseBkgnd);
var
    LBrush: HBRUSH;
    LRect: TRect;
begin
    Winapi.Windows.GetClientRect(Handle, LRect);
    LBrush := CreateSolidBrush(ColorToRGB(Self.Color));
    try
        FillRect(Message.DC, LRect, LBrush);
    finally
        DeleteObject(LBrush);
    end;
    Message.Result := 1;
end;

initialization
    if TStyleManager.Engine <> nil then
        TStyleManager.Engine.RegisterStyleHook(TCustomSynEdit, TScrollingStyleHook);

end.
