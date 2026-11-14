unit PassphraseFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    System.Classes,
    System.Types,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls
    ;

type
    TPassphraseForm = class(TBaseForm)
        pnlMain: TPanel;
        bOK: TButton;
        bCancel: TButton;
        lbPrompt: TLabel;
        lbConfirm: TLabel;
        sbBottom: TStatusBar;
        ebPass: TEdit;
        ebConfirm: TEdit;
        procedure FormShow(Sender: TObject);
        procedure bOKClick(Sender: TObject);
        procedure ebPassChange(Sender: TObject);
        procedure ebConfirmChange(Sender: TObject);
        procedure ebPassKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure ebConfirmKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    private
        FPrompt: string;
        FConfirmPrompt: string;
        FMismatchText: string;
        FResultPassphrase: string;
        procedure AdjustLayout;
        procedure FocusInput;
        function DpiScale(AValue: Integer): Integer;
        procedure HandleKeyPresses(const Key: Word);
        procedure ValidateInput;
    protected
        procedure DoAfterMonitorDpiChanged(OldDPI, NewDPI: Integer); override;
        procedure DoShownOnScreen; override;
    public
        procedure Setup(const APrompt, AConfirmPrompt, AMismatchText: string);
        property ResultPassphrase: string read FResultPassphrase;
    end;

function ShowPasswordConfirmForm(const APrompt, AConfirmPrompt, AMismatchText: string;
    const AppContext: IAppContext; var AResult: string): Boolean;

implementation

uses
    System.Math,
    Winapi.Windows
    ;

const
    BASE_CLIENT_WIDTH = 347;
    PAD = 8;
    LABEL_TOP = 8;
    LABEL_EDIT_GAP = 6;
    EDIT_H = 21;
    EDIT_LABEL_GAP = 10;
    BTN_H = 25;
    BTN_EDIT_GAP = 10;
    BTN_SB_GAP = 6;

{$R *.dfm}

function ShowPasswordConfirmForm(const APrompt, AConfirmPrompt, AMismatchText: string;
    const AppContext: IAppContext; var AResult: string): Boolean;
var
    Form: TPassphraseForm;
begin
    Form := TPassphraseForm.Create(nil);
    try
        Form.Initialize(AppContext);
        Form.Setup(APrompt, AConfirmPrompt, AMismatchText);
        Form.WarmUpPaint;
        Form.PrepareGuardedShow;

        Result := Form.ShowModal = mrOk;
        if Result then
            AResult := Form.ResultPassphrase;
    finally
        Form.Free;
    end;
end;

procedure TPassphraseForm.Setup(const APrompt, AConfirmPrompt, AMismatchText: string);
begin
    FPrompt := APrompt;
    FConfirmPrompt := AConfirmPrompt;
    FMismatchText := AMismatchText;

    if FPrompt <> '' then
    begin
        Caption := FPrompt;
        lbPrompt.Caption := FPrompt;
    end;
    if FConfirmPrompt <> '' then
        lbConfirm.Caption := FConfirmPrompt;
end;

procedure TPassphraseForm.FormShow(Sender: TObject);
begin
    AdjustLayout;
    ValidateInput;
    FocusInput;
end;

procedure TPassphraseForm.FocusInput;
begin
    if ebPass.CanFocus then
        ebPass.SetFocus;
end;

procedure TPassphraseForm.DoShownOnScreen;
begin
    inherited;

    ForceForeground;
    FocusInput;
end;

procedure TPassphraseForm.DoAfterMonitorDpiChanged(OldDPI, NewDPI: Integer);
begin
    inherited;
    AdjustLayout;
end;

function TPassphraseForm.DpiScale(AValue: Integer): Integer;
begin
    Result := MulDiv(AValue, CurrentPPI, 96);
end;

procedure TPassphraseForm.AdjustLayout;
var
    PromptW, ConfirmW, NeededW, EditTop, ConfirmTop, ConfirmEditTop, ButtonsTop, NeededH: Integer;
begin
    PromptW := Canvas.TextWidth(FPrompt);
    ConfirmW := Canvas.TextWidth(FConfirmPrompt);

    NeededW := 2 * DpiScale(PAD) + Max(PromptW, ConfirmW);
    NeededW := Max(NeededW, DpiScale(BASE_CLIENT_WIDTH));
    ClientWidth := NeededW;

    EditTop := DpiScale(LABEL_TOP) + lbPrompt.Height + DpiScale(LABEL_EDIT_GAP);
    ConfirmTop := EditTop + DpiScale(EDIT_H) + DpiScale(EDIT_LABEL_GAP);
    ConfirmEditTop := ConfirmTop + lbConfirm.Height + DpiScale(LABEL_EDIT_GAP);
    ButtonsTop := ConfirmEditTop + DpiScale(EDIT_H) + DpiScale(BTN_EDIT_GAP);

    ebPass.Top := EditTop;
    lbConfirm.Top := ConfirmTop;
    ebConfirm.Top := ConfirmEditTop;
    bOK.Top := ButtonsTop;
    bCancel.Top := ButtonsTop;

    NeededH := ButtonsTop + DpiScale(BTN_H) + DpiScale(BTN_SB_GAP) + sbBottom.Height;
    ClientHeight := NeededH;
end;

procedure TPassphraseForm.ValidateInput;
var
    Pass1, Pass2: string;
begin
    Pass1 := ebPass.Text;
    Pass2 := ebConfirm.Text;

    if (Pass1 <> '') and (Pass1 = Pass2) then
    begin
        sbBottom.SimpleText := '';
        bOK.Enabled := True;
    end
    else
    begin
        if (Pass1 <> '') and (Pass2 <> '') then
            sbBottom.SimpleText := FMismatchText
        else
            sbBottom.SimpleText := '';
        bOK.Enabled := False;
    end;
end;

procedure TPassphraseForm.HandleKeyPresses(const Key: Word);
begin
    case Key of
        13:
            if bOK.Enabled then
                bOKClick(Self);
        27:
            ModalResult := mrCancel;
    end;
end;

procedure TPassphraseForm.bOKClick(Sender: TObject);
begin
    FResultPassphrase := ebPass.Text;
    ModalResult := mrOk;
end;

procedure TPassphraseForm.ebPassChange(Sender: TObject);
begin
    ValidateInput;
end;

procedure TPassphraseForm.ebConfirmChange(Sender: TObject);
begin
    ValidateInput;
end;

procedure TPassphraseForm.ebPassKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    HandleKeyPresses(Key);
end;

procedure TPassphraseForm.ebConfirmKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    HandleKeyPresses(Key);
end;

end.
