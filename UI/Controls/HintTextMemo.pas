unit HintTextMemo;

interface

uses Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
    Vcl.Graphics, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
    System.Types, System.UITypes, System.Masks, Vcl.Dialogs, System.StrUtils;

type
    TMemo = class(Vcl.StdCtrls.TMemo)
    private
        FCanvas: TCanvas;
        FEnableHintText: Boolean;
        FHintText: string;
        FMaskedStr: string;
        procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
        procedure PrepareMaskStr;
        procedure DrawMultiLineHint(const ARect: TRect);
    protected
        procedure WndProc(var Message: TMessage); override;
    public
        constructor Create(AOwner: TComponent); override;
        destructor Destroy; override;
        function MaskMatchesWith(InputStr: string): Boolean;
        property EnableHintText: Boolean read FEnableHintText
          write FEnableHintText;
        property HintText: string read FHintText write FHintText;
        property MaskText: string read FMaskedStr;
    end;

implementation

{$REGION 'CUSTOM TMEMO'} constructor TMemo.Create(AOwner: TComponent);
begin
    inherited Create(AOwner);
    FEnableHintText := False;
    FHintText := 'Type here...' + #13#10 + '("*", "?" wildcards are supported)';
    FMaskedStr := '';
    FCanvas := TControlCanvas.Create;
    TControlCanvas(FCanvas).Control := Self;
end;

destructor TMemo.Destroy;
begin
    FCanvas.Free;
    inherited Destroy;
end;

procedure TMemo.DrawMultiLineHint(const ARect: TRect);
var
    Lines: TStringList;
    i: Integer;
    YPos: Integer;
    LineHeight: Integer;
begin
    Lines := TStringList.Create;
    try
        Lines.Text := FHintText;
        FCanvas.Font := Self.Font;
        FCanvas.Font.Style := FCanvas.Font.Style + [fsItalic];
        FCanvas.Font.Color := clGray;
        FCanvas.Brush.Style := bsClear;
        // Получаем высоту строки
        LineHeight := FCanvas.TextHeight('A');
        // Начальная позиция Y с учетом отступов TMemo
        YPos := ARect.Top + 3;
        // Рисуем каждую строку
        for i := 0 to Lines.Count - 1 do
        begin
            // Проверяем, не вышли ли за пределы видимой области
            if YPos + LineHeight > ARect.Bottom then
                Break;
            FCanvas.TextOut(ARect.Left + 3, YPos, Lines[i]);
            YPos := YPos + LineHeight;
        end;
    finally
        Lines.Free;
    end;
end;

procedure TMemo.WMPaint(var Message: TWMPaint);
var
    MemoRect: TRect;
begin
    inherited;
    if ((FEnableHintText) and (Length(Text) = 0)) then
    begin
        MemoRect := ClientRect;
        DrawMultiLineHint(MemoRect);
    end;
end;

procedure TMemo.WndProc(var Message: TMessage);
var
    temp: TNotifyEvent;
begin
    temp := OnChange;
    if (FEnableHintText) then
    begin
        with Message do
            case Msg of
                WM_CHAR, WM_SETTEXT, WM_CUT, WM_PASTE:
                    OnChange := nil;
            end;
    end;
    inherited WndProc(Message);
    if (FEnableHintText) then
    begin
        with Message do
            case Msg of
                CM_MOUSEENTER, CM_MOUSELEAVE, WM_LBUTTONUP, WM_LBUTTONDOWN,
                  WM_KEYDOWN, WM_KEYUP, WM_SETFOCUS, WM_KILLFOCUS,
                  CM_FONTCHANGED, CM_TEXTCHANGED:
                    begin
                        Invalidate;
                    end;
                WM_CHAR, WM_SETTEXT, WM_CUT, WM_PASTE:
                    begin
                        PrepareMaskStr;
                        OnChange := temp;
                        if (Assigned(OnChange)) then
                            OnChange(Self);
                    end;
            end;
        // case
    end;
end;

procedure TMemo.PrepareMaskStr;
begin
    if (FEnableHintText) then
    begin
        // Для маски убираем переносы строк
        FMaskedStr := UpperCase('*' + StringReplace(Text, #13#10, ' ',
          [rfReplaceAll]) + '*', loUserLocale);
    end;
end;

function TMemo.MaskMatchesWith(InputStr: string): Boolean;
begin
    if (not FEnableHintText) then
    begin
        Result := False;
        Exit;
    end;
    if (FMaskedStr = '') then
    begin
        Result := True;
        Exit;
    end;
    InputStr := UpperCase(InputStr, loUserLocale);
    Result := MatchesMask(InputStr, FMaskedStr);
end;

{$ENDREGION}

end.
