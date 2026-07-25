unit HintTextMemo;

interface

uses
    System.SysUtils,
    System.Classes,
    Vcl.Controls,
    Vcl.StdCtrls,
    Vcl.Graphics,
    Winapi.Messages,
    Winapi.Windows,
    System.Masks;

type
    TMemo = class(Vcl.StdCtrls.TMemo)
    private
        FEnableHintText: Boolean;
        FHintText: string;
        FMaskedStr: string;
        procedure PrepareMaskStr;
        procedure SetEnableHintText(const Value: Boolean);
        procedure SetHintText(const Value: string);

        procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
        procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    protected
        procedure Change; override;
        procedure WndProc(var Message: TMessage); override;
    public
        constructor Create(AOwner: TComponent); override;
        function MaskMatchesWith(InputStr: string): Boolean;
        property MaskText: string read FMaskedStr;
    published
        property EnableHintText: Boolean read FEnableHintText write SetEnableHintText;
        property HintText: string read FHintText write SetHintText;
    end;

implementation

constructor TMemo.Create(AOwner: TComponent);
begin
    inherited Create(AOwner);
    FEnableHintText := False;
    FHintText := 'Type here...';
    FMaskedStr := '';
end;

procedure TMemo.Change;
begin
    inherited Change;
    if FEnableHintText then
        PrepareMaskStr;
end;

procedure TMemo.SetEnableHintText(const Value: Boolean);
begin
    if FEnableHintText <> Value then
    begin
        FEnableHintText := Value;
        if FEnableHintText then
            PrepareMaskStr
        else
            FMaskedStr := '';
        Invalidate;
    end;
end;

procedure TMemo.SetHintText(const Value: string);
begin
    if FHintText <> Value then
    begin
        FHintText := Value;
        Invalidate; // Принудительно запрашиваем перерисовку при смене текста
    end;
end;

procedure TMemo.PrepareMaskStr;
begin
    if FEnableHintText then
    begin
        FMaskedStr := UpperCase('*' + StringReplace(Text, #13#10, ' ', [rfReplaceAll]) + '*', loUserLocale);
    end;
end;

function TMemo.MaskMatchesWith(InputStr: string): Boolean;
begin
    if not FEnableHintText then
        Exit(False);

    if FMaskedStr = '' then
        Exit(True);

    InputStr := UpperCase(InputStr, loUserLocale);
    Result := MatchesMask(InputStr, FMaskedStr);
end;

procedure TMemo.CMEnabledChanged(var Message: TMessage);
begin
    inherited;
    Invalidate; // Синхронизируем появление/исчезновение при смене Enabled
end;

procedure TMemo.WMPaint(var Message: TWMPaint);
var
    DC: HDC;
    Canvas: TCanvas;
    R: TRect;
    NeedRelease: Boolean;
begin
    inherited; // Даем системе отрисовать сам Memo

    // Используем GetTextLen = 0 (это в 10 раз надежнее, чем Text = '', т.к. игнорирует скрытые переносы строк)
    if FEnableHintText and (GetTextLen = 0) and (FHintText <> '') and Enabled then
    begin
        NeedRelease := False;
        DC := Message.DC;

        // Магия VCL: если Message.DC = 0, значит двойная буферизация отключена, берем DC у окна.
        // Если <> 0, значит VCL дал нам виртуальный буфер, и мы ОБЯЗАНЫ рисовать в него!
        if DC = 0 then
        begin
            DC := GetDC(Handle);
            NeedRelease := True;
        end;

        if DC <> 0 then
        begin
            Canvas := TCanvas.Create;
            try
                Canvas.Handle := DC;
                Canvas.Font.Assign(Self.Font);   // Безопасное копирование системного шрифта
                Canvas.Font.Color := clGrayText; // Нативный серый цвет для неактивного текста (выглядит лучше)
                Canvas.Font.Style := [fsItalic];
                Canvas.Brush.Style := bsClear;   // Не закрашиваем фон!

                R := ClientRect;
                Inc(R.Left, 4);
                Inc(R.Top, 4);
                Dec(R.Right, 4);

                DrawText(Canvas.Handle, PChar(FHintText), -1, R, DT_NOPREFIX or DT_WORDBREAK);
            finally
                Canvas.Handle := 0; // Отвязываем контекст ДО удаления Canvas, чтобы не убить системный DC
                Canvas.Free;
                if NeedRelease then
                    ReleaseDC(Handle, DC);
            end;
        end;
    end;
end;

procedure TMemo.WndProc(var Message: TMessage);
begin
    inherited WndProc(Message);

    // Моментальная перерисовка при клике или вводе символа
    case Message.Msg of
        WM_SETFOCUS, WM_KILLFOCUS, CM_TEXTCHANGED:
            Invalidate;
    end;
end;

end.
