unit HintTextEdit;

interface

uses
    Winapi.Windows,
    Winapi.Messages,
    System.SysUtils,
    System.Classes,
    Vcl.Graphics,
    Vcl.Controls,
    Vcl.StdCtrls,
    Vcl.ExtCtrls,
    Vcl.ComCtrls,
    System.Types,
    System.UITypes,
    System.Masks,
    Vcl.Dialogs;

type
    TEdit = class(Vcl.StdCtrls.TEdit)
    private
        FCanvas: TCanvas;
        FEnableHintText: Boolean;
        FHintText: string;
        FMaskedStr: string;
        procedure WMPaint(var Message: TWMPaint); message WM_PAINT;

        procedure PrepareMaskStr;
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

{$REGION 'CUSTOM TEDIT'}

constructor TEdit.Create(AOwner: TComponent);
begin
    inherited Create(AOwner);
    FEnableHintText := False;
    FHintText := 'Type here... ("*", "?" wildcards are supported)';
    FMaskedStr := '';
    FCanvas := TControlCanvas.Create;
    TControlCanvas(FCanvas).Control := Self;
end;

destructor TEdit.Destroy;
begin
    FCanvas.Free;
    inherited Destroy;
end;

procedure TEdit.WMPaint(var Message: TWMPaint);
var
    EditRect: TRect;
begin
    inherited;
    if ((FEnableHintText) and (Length(Text) = 0)) then
    begin
        EditRect := ClientRect;
        FCanvas.Font := Self.Font;
        FCanvas.Font.Style := FCanvas.Font.Style + [fsItalic];
        FCanvas.Font.Color := clGray;
        FCanvas.Brush.Style := bsClear;
        FCanvas.TextOut(0, 0, FHintText);
    end;
end;

procedure TEdit.WndProc(var Message: TMessage);
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
                        // FOnChangeEx(Self);
                        Invalidate;
                    end;
                WM_CHAR, WM_SETTEXT, WM_CUT, WM_PASTE:
                    begin
                        PrepareMaskStr;
                        OnChange := temp;
                        if (Assigned(OnChange)) then
                            OnChange(Self);
                    end;
            end; // case
    end;
end;

procedure TEdit.PrepareMaskStr;
begin
    if (FEnableHintText) then
    begin
        FMaskedStr := UpperCase('*' + Text + '*', loUserLocale);
    end;
end;

function TEdit.MaskMatchesWith(InputStr: string): Boolean;
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
