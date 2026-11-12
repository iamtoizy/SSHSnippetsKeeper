unit ChainRunPanelUI;

interface

uses
    System.Classes,
    System.Math,
    System.SysUtils,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls,
    Winapi.Messages,
    Winapi.Windows
    ;

type
    TChainRunPanel = class(TForm)
        lblProgress: TLabel;
        btnStop: TButton;
        tmTopMost: TTimer;
        procedure btnStopClick(Sender: TObject);
        procedure tmTopMostTimer(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    private
        FStopRequested: Boolean;
        FChainName: string;
        FBaseCaption: string;
    public
        procedure Initialize(const PanelCaption, SequenceName: string; TotalSteps: Integer);
        procedure SetStep(Index, Total: Integer; const SnippetTitle: string);
        // Живой статус печати шага: пауза фокуса / остаток сна / прогресс символов
        procedure SetTypingStatus(Paused, SleepRemainingMs, TypedChars, TotalChars: Integer);
        procedure EnsureTopMost;
        property StopRequested: Boolean read FStopRequested;
    end;

implementation

uses
    Common.Localization
    ;

{$R *.dfm}

{ TChainRunPanel }

procedure TChainRunPanel.Initialize(const PanelCaption, SequenceName: string; TotalSteps: Integer);
var
    WorkArea: TRect;
begin
    FStopRequested := False;
    FChainName := SequenceName;
    FBaseCaption := '';

    Caption := PanelCaption;
    btnStop.Caption := TUIStateLoader.GetMessage('Chains.Run.Stop');
    lblProgress.Caption := '';

    WorkArea := Screen.WorkAreaRect;
    Left := WorkArea.Right - Width - 16;
    Top := WorkArea.Bottom - Height - 16;
    PopupMode := pmExplicit;
    EnsureTopMost;
end;

procedure TChainRunPanel.SetStep(Index, Total: Integer; const SnippetTitle: string);
begin
    FBaseCaption :=
        Format(TUIStateLoader.GetMessage('Chains.Run.Progress'), [FChainName, Index, Total, SnippetTitle]);
    lblProgress.Caption := FBaseCaption;
    Update;
    EnsureTopMost;
end;

procedure TChainRunPanel.SetTypingStatus(Paused, SleepRemainingMs, TypedChars, TotalChars: Integer);
var
    NewCaption: string;
begin
    // Приоритет как в Stop-панели: пауза фокуса > остаток SLEEP > прогресс
    NewCaption := FBaseCaption;
    if Paused > 0 then
        NewCaption := NewCaption + sLineBreak +
            TUIStateLoader.GetMessage('Macro.PauseWaiting')
    else if SleepRemainingMs > 0 then
        NewCaption := NewCaption + sLineBreak +
            TUIStateLoader.GetMessage('Macro.PauseRemaining', [Max(1, SleepRemainingMs div 1000)])
    else if TotalChars > 0 then
        NewCaption := NewCaption + sLineBreak +
            TUIStateLoader.GetMessage('Macro.ProgressChars',
                [TypedChars, TotalChars, Min(100, TypedChars * 100 div TotalChars)]);
    if NewCaption = lblProgress.Caption then
        Exit;
    lblProgress.Caption := NewCaption;
    Update;
end;

procedure TChainRunPanel.btnStopClick(Sender: TObject);
begin
    FStopRequested := True;
end;

procedure TChainRunPanel.EnsureTopMost;
begin
    SetWindowPos(Handle, HWND_NOTOPMOST, 0, 0, 0, 0,
        SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_NOOWNERZORDER);
    SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0,
        SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_NOOWNERZORDER);
end;

procedure TChainRunPanel.tmTopMostTimer(Sender: TObject);
begin
    EnsureTopMost;
end;

procedure TChainRunPanel.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if Key = VK_ESCAPE then
    begin
        FStopRequested := True;
        Key := 0;
    end;
end;

end.
