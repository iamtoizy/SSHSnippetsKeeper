unit MacroStopPanelUI;

interface

uses
    System.Classes,
    System.SysUtils,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls,
    Winapi.Messages,
    Winapi.Windows
    ;

type
    TMacroStopPanel = class(TForm)
        lblInfo: TLabel;
        btnStop: TButton;
        tmTopMost: TTimer;
        procedure btnStopClick(Sender: TObject);
        procedure tmTopMostTimer(Sender: TObject);
    private
        FOnStop: TProc;
    protected
        procedure CreateParams(var Params: TCreateParams); override;
    public
        procedure Initialize(const ATitle: string; AOnStop: TProc);
        procedure ShowNoActivate;
        procedure EnsureTopMost;
    end;

implementation

{$R *.dfm}

{ TMacroStopPanel }

procedure TMacroStopPanel.Initialize(const ATitle: string; AOnStop: TProc);
var
    WorkArea: TRect;
begin
    FOnStop := AOnStop;

    Caption := ATitle;
    lblInfo.Caption := ATitle;
    btnStop.Enabled := True;

    WorkArea := Screen.WorkAreaRect;
    Left := WorkArea.Right - Width - 16;
    Top := WorkArea.Bottom - Height - 16;
    PopupMode := pmExplicit;
    EnsureTopMost;
end;

procedure TMacroStopPanel.CreateParams(var Params: TCreateParams);
begin
    inherited;
    Params.ExStyle := Params.ExStyle or WS_EX_NOACTIVATE or WS_EX_TOOLWINDOW;
end;

procedure TMacroStopPanel.ShowNoActivate;
begin
    ShowWindow(Handle, SW_SHOWNOACTIVATE);
    Visible := True;
    EnsureTopMost;
end;

procedure TMacroStopPanel.EnsureTopMost;
begin
    SetWindowPos(Handle, HWND_NOTOPMOST, 0, 0, 0, 0,
        SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_NOOWNERZORDER);
    SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0,
        SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_NOOWNERZORDER);
end;

procedure TMacroStopPanel.btnStopClick(Sender: TObject);
begin
    btnStop.Enabled := False;
    if Assigned(FOnStop) then
        FOnStop();
end;

procedure TMacroStopPanel.tmTopMostTimer(Sender: TObject);
begin
    EnsureTopMost;
end;

end.
