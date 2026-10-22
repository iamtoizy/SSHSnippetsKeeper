unit MacroStopPanelUI;

interface

uses
    MacroInputTypes,
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
        FTitle: string;
        FContext: TMacroContext;
        FOnStop: TProc;
        procedure UpdateProgress;
    protected
        procedure CreateParams(var Params: TCreateParams); override;
    public
        procedure Initialize(const ASnippetTitle: string; AOnStop: TProc; AContext: TMacroContext);
        procedure ShowNoActivate;
        procedure EnsureTopMost;
        procedure StopTracking;
    end;

implementation

uses
    Common.Localization,
    System.Math,
    System.SyncObjs
    ;

{$R *.dfm}

{ TMacroStopPanel }

procedure TMacroStopPanel.Initialize(const ASnippetTitle: string; AOnStop: TProc; AContext: TMacroContext);
var
    WorkArea: TRect;
begin
    FOnStop := AOnStop;
    FContext := AContext;
    FTitle := ASnippetTitle;

    Caption := TUIStateLoader.GetMessage('Macro.StopPanelTitle');
    lblInfo.Caption := FTitle;
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

procedure TMacroStopPanel.UpdateProgress;
var
    Typed, Total, Pct: Integer;
begin
    if FContext = nil then
        Exit;

    // SLEEP публикует остаток прямо из своего цикла ожидания
    if TInterlocked.CompareExchange(FContext.SleepRemainingMs, 0, 0) > 0 then
    begin
        lblInfo.Caption := FTitle + sLineBreak + TUIStateLoader.GetMessage('Macro.PauseRemaining',
            [Max(1, TInterlocked.CompareExchange(FContext.SleepRemainingMs, 0, 0) div 1000)]);
        Exit;
    end;

    Typed := TInterlocked.CompareExchange(FContext.TypedChars, 0, 0);
    Total := TInterlocked.CompareExchange(FContext.ProgressTotal, 0, 0);
    if Total <= 0 then
        Exit;

    Pct := Typed * 100 div Total;
    if Pct > 100 then
        Pct := 100;

    lblInfo.Caption := FTitle + sLineBreak +
        TUIStateLoader.GetMessage('Macro.ProgressChars', [Typed, Total, Pct]);
end;

procedure TMacroStopPanel.StopTracking;
begin
    FContext := nil;
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
    UpdateProgress;
end;

end.
