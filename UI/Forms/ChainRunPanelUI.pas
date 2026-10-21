unit ChainRunPanelUI;

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
    TChainRunPanel = class(TForm)
        lblProgress: TLabel;
        btnStop: TButton;
        procedure btnStopClick(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    private
        FStopRequested: Boolean;
        FChainName: string;
    public
        procedure Initialize(const PanelCaption, SequenceName: string; TotalSteps: Integer);
        procedure SetStep(Index, Total: Integer; const SnippetTitle: string);
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

    Caption := PanelCaption;
    btnStop.Caption := TUIStateLoader.GetMessage('Chains.Run.Stop');
    lblProgress.Caption := '';

    WorkArea := Screen.WorkAreaRect;
    Left := WorkArea.Right - Width - 16;
    Top := WorkArea.Bottom - Height - 16;
end;

procedure TChainRunPanel.SetStep(Index, Total: Integer; const SnippetTitle: string);
begin
    lblProgress.Caption :=
        Format(TUIStateLoader.GetMessage('Chains.Run.Progress'), [FChainName, Index, Total, SnippetTitle]);
    Update;
end;

procedure TChainRunPanel.btnStopClick(Sender: TObject);
begin
    FStopRequested := True;
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
