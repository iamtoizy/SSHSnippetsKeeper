unit InputFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    MacroInputTypes,
    System.Classes,
    System.Types,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls
    ;

type
    TInputForm = class(TBaseForm)
        pnlMain: TPanel;
        bOK: TButton;
        bCancel: TButton;
        lbPrompt: TLabel;
        sbBottom: TStatusBar;
        ebEdit: TEdit;
        cbSelect: TComboBox;
        procedure FormCreate(Sender: TObject);
        procedure FormShow(Sender: TObject);
        procedure bOKClick(Sender: TObject);
        procedure ebEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure ebEditChange(Sender: TObject);
        procedure bCancelClick(Sender: TObject);
        procedure cbSelectKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure HandleKeyPresses(const Key: Word);
    private
        FInputType: TMacroInputType;
        FDefaultValue: string;
        FResultValue: string;
        FPrompt: string;
        FStatusText: string;
    procedure SetPrompt(const AValue: string);
    procedure SetStatusText(const AText: string);
    procedure ApplyStatusText;
    procedure AdjustLayout;
    procedure FocusInput;
    function DpiScale(AValue: Integer): Integer;
    function TargetWorkArea: TRect;
    procedure FillSelectItems;
    procedure ValidateInput;
    protected
        procedure DoAfterMonitorDpiChanged(OldDPI, NewDPI: Integer); override;
        procedure DoShownOnScreen; override;
    public
        property ResultValue: string read FResultValue;
    end;

function ShowInputForm(const Prompt, DefaultValue: string; InputType: TMacroInputType; const AppContext: IAppContext; var FormResult: string): Boolean;

var
    InputForm: TInputForm;

implementation

uses
    System.Math,
    System.SysUtils,
    Common.Localization,
    Winapi.Windows
    ;

const
    SP_PREFIX = '⏵ ';
    SP_POSTFIX = ', ⏎';
    ELLIPSIS = '…';
    BASE_CLIENT_WIDTH = 347;
    PAD = 8;
    LABEL_TOP = 8;
    LABEL_EDIT_GAP = 6;
    EDIT_H = 21;
    EDIT_BTN_GAP = 5;
    BTN_H = 25;
    BTN_SB_GAP = 6;
    WORKAREA_MARGIN = 24;
    STATUS_LEFT_PAD = 8;

{$R *.dfm}

function ShowInputFormModal(const Prompt, DefaultValue: string; InputType: TMacroInputType; const AppContext: IAppContext; var Value: string): Boolean;
var
    Form: TInputForm;
begin
    Form := TInputForm.Create(nil);
    try
        Form.Initialize(AppContext);
        Form.SetPrompt(Prompt);

        Form.FInputType := InputType;
        if (DefaultValue <> '') then
            Form.FDefaultValue := DefaultValue;

        Form.WarmUpPaint;
        Form.PrepareGuardedShow;

        Result := Form.ShowModal = mrOk;
        if Result then
            Value := Form.ResultValue;
    finally
        Form.Free;
    end;
end;

function ShowInputForm(const Prompt, DefaultValue: string; InputType: TMacroInputType; const AppContext: IAppContext; var FormResult: string): Boolean;
var
    ModalOk: Boolean;
    ModalValue: string;
begin
    ModalOk := False;
    ModalValue := '';

    if TThread.CurrentThread.ThreadID = MainThreadID then
        ModalOk := ShowInputFormModal(Prompt, DefaultValue, InputType, AppContext, ModalValue)
    else
        TThread.Synchronize(nil,
            procedure
            begin
                ModalOk := ShowInputFormModal(Prompt, DefaultValue, InputType, AppContext, ModalValue);
            end);

    Result := ModalOk;
    if Result then
        FormResult := ModalValue;
end;

procedure TInputForm.FormCreate(Sender: TObject);
begin
    FResultValue := '';
end;

procedure TInputForm.FormShow(Sender: TObject);
begin
    // Настраиваем контрол в зависимости от типа
    cbSelect.Visible := False;
    ebEdit.Visible := True;

    case FInputType of
        mitString:
            begin
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.String') + SP_POSTFIX);
                ebEdit.Text := FDefaultValue;
            end;

        mitNumber:
            begin
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Number') + SP_POSTFIX);
                ebEdit.Text := FDefaultValue;
            end;

        mitHex:
            begin
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Hex') + SP_POSTFIX);
                ebEdit.Text := FDefaultValue;
                ebEdit.CharCase := ecUpperCase;
            end;

        mitFloat:
            begin
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Float') + SP_POSTFIX);
                ebEdit.Text := FDefaultValue;
            end;

        mitPassword:
            begin
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Password') + SP_POSTFIX);
                ebEdit.PasswordChar := '*';
                ebEdit.Text := FDefaultValue;
            end;

        mitDate:
            begin
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Date') + SP_POSTFIX);
                ebEdit.Text := FDefaultValue;
            end;

        mitTime:
            begin
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Time') + SP_POSTFIX);
                ebEdit.Text := FDefaultValue;
            end;

        mitDateTime:
            begin
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.DateTime') + SP_POSTFIX);
                ebEdit.Text := FDefaultValue;
            end;

        mitSelect:
            begin
                FillSelectItems;
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Select') + SP_POSTFIX);
            end;
    end;

    AdjustLayout;

    if FInputType = mitSelect then
    begin
        ebEdit.Visible := False;
        cbSelect.Visible := True;
    end;

    FocusInput;
end;

procedure TInputForm.FocusInput;
begin
    if FInputType = mitSelect then
    begin
        if cbSelect.CanFocus then
            cbSelect.SetFocus;
    end
    else if ebEdit.CanFocus then
        ebEdit.SetFocus;
end;

procedure TInputForm.DoShownOnScreen;
begin
    inherited;

    ForceForeground;
    FocusInput;
end;

procedure TInputForm.FillSelectItems;
var
    Option: string;
begin
    cbSelect.Items.BeginUpdate;
    try
        cbSelect.Items.Clear;
        for Option in FDefaultValue.Split(['|']) do
            if Trim(Option) <> '' then
                cbSelect.Items.Add(Trim(Option));

        if cbSelect.Items.Count > 0 then
            cbSelect.ItemIndex := 0;
    finally
        cbSelect.Items.EndUpdate;
    end;
end;

procedure TInputForm.HandleKeyPresses(const Key: Word);
begin
    case Key of
        13:
            bOKClick(Self);
        27:
            bCancelClick(Self);
    end;
end;

procedure TInputForm.bCancelClick(Sender: TObject);
begin
    ModalResult := mrCancel;
end;

procedure TInputForm.ebEditChange(Sender: TObject);
begin
    ValidateInput;
end;

procedure TInputForm.ebEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    HandleKeyPresses(Key);
end;

procedure TInputForm.cbSelectKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    HandleKeyPresses(Key);
end;

procedure TInputForm.ValidateInput;
var
    Value: string;
    Valid: Boolean;
begin
    Value := Trim(ebEdit.Text);
    Valid := IsMacroValueValid(Value, FInputType);

    if Valid then
    begin
        case FInputType of
            mitNumber:
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Number') + SP_POSTFIX);
            mitHex:
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Hex') + SP_POSTFIX);
            mitFloat:
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Float') + SP_POSTFIX);
            mitDate:
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Date') + SP_POSTFIX);
            mitTime:
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Time') + SP_POSTFIX);
            mitDateTime:
                SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.DateTime') + SP_POSTFIX);
        end;
    end
    else
    begin
        case FInputType of
            mitNumber:
                SetStatusText(TUIStateLoader.GetMessage('InputForm.Error.Number'));
            mitHex:
                SetStatusText(TUIStateLoader.GetMessage('InputForm.Error.Hex'));
            mitFloat:
                SetStatusText(TUIStateLoader.GetMessage('InputForm.Error.Float'));
            mitDate:
                SetStatusText(TUIStateLoader.GetMessage('InputForm.Error.Date'));
            mitTime:
                SetStatusText(TUIStateLoader.GetMessage('InputForm.Error.Time'));
            mitDateTime:
                SetStatusText(TUIStateLoader.GetMessage('InputForm.Error.DateTime'));
        end;
    end;

    bOK.Enabled := Valid;
end;

procedure TInputForm.bOKClick(Sender: TObject);
begin
    if FInputType = mitSelect then
    begin
        if (cbSelect.ItemIndex >= 0) and (cbSelect.ItemIndex < cbSelect.Items.Count) then
            FResultValue := cbSelect.Items[cbSelect.ItemIndex]
        else
            FResultValue := '';
    end
    else
        FResultValue := Trim(ebEdit.Text);

    ModalResult := mrOk;
end;

procedure TInputForm.SetPrompt(const AValue: string);
begin
    FPrompt := AValue;
    if FPrompt <> '' then
    begin
        Caption := FPrompt;
        lbPrompt.Caption := FPrompt;
    end;
end;

procedure TInputForm.SetStatusText(const AText: string);
begin
    FStatusText := AText;
    ApplyStatusText;
end;

procedure TInputForm.ApplyStatusText;
var
    S: string;
    MaxW: Integer;
begin
    S := FStatusText;
    MaxW := sbBottom.ClientWidth - DpiScale(STATUS_LEFT_PAD);
    if (S <> '') and (sbBottom.Canvas.TextWidth(S) > MaxW) then
    begin
        while (Length(S) > 1) and (sbBottom.Canvas.TextWidth(S + ELLIPSIS) > MaxW) do
            Delete(S, Length(S), 1);
        S := S + ELLIPSIS;
    end;
    sbBottom.SimpleText := S;
end;

function TInputForm.DpiScale(AValue: Integer): Integer;
begin
    Result := MulDiv(AValue, CurrentPPI, 96);
end;

function TInputForm.TargetWorkArea: TRect;
var
    Ref: TCustomForm;
begin
    Ref := Screen.ActiveCustomForm;
    if (Ref <> nil) and (Ref <> Self) and Ref.Visible and (Ref.Monitor <> nil) then
        Result := Ref.Monitor.WorkareaRect
    else
        Result := Screen.WorkAreaRect;
end;

procedure TInputForm.AdjustLayout;
var
    Work: TRect;
    PromptW, NeededW, LabelW, Lines, LineH, EditTop, ButtonsTop, NeededH: Integer;
begin
    Work := TargetWorkArea;

    PromptW := Canvas.TextWidth(FPrompt);
    NeededW := 2 * DpiScale(PAD) + PromptW;
    NeededW := Max(NeededW, DpiScale(BASE_CLIENT_WIDTH));
    NeededW := Min(NeededW, Work.Width - DpiScale(WORKAREA_MARGIN));
    ClientWidth := NeededW;

    LabelW := ClientWidth - 2 * DpiScale(PAD);
    if PromptW > LabelW then
    begin
        lbPrompt.AutoSize := False;
        lbPrompt.EllipsisPosition := epEndEllipsis;
        Lines := Max(1, Ceil(PromptW / Max(LabelW, 1)));
        LineH := Canvas.TextHeight(FPrompt);
        lbPrompt.Width := LabelW;
        lbPrompt.Height := Lines * LineH;
    end
    else
        lbPrompt.AutoSize := True;

    EditTop := DpiScale(LABEL_TOP) + lbPrompt.Height + DpiScale(LABEL_EDIT_GAP);
    ButtonsTop := EditTop + DpiScale(EDIT_H) + DpiScale(EDIT_BTN_GAP);
    NeededH := ButtonsTop + DpiScale(BTN_H) + DpiScale(BTN_SB_GAP) + sbBottom.Height;
    NeededH := Min(NeededH, Work.Height - DpiScale(WORKAREA_MARGIN));
    ClientHeight := NeededH;

    ebEdit.Top := EditTop;
    cbSelect.Top := EditTop;
    bOK.Top := ButtonsTop;
    bCancel.Top := ButtonsTop;

    ApplyStatusText;
end;

procedure TInputForm.DoAfterMonitorDpiChanged(OldDPI, NewDPI: Integer);
begin
    inherited;
    if FPrompt <> '' then
        AdjustLayout;
end;

end.

