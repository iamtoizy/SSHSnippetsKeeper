unit InputFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    MacroInputTypes,
    System.Classes,
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
        procedure FillSelectItems;
        procedure ValidateInput;
    public
        property ResultValue: string read FResultValue;
    end;

function IsMacroValueValid(const Value: string; InputType: TMacroInputType): Boolean;
function ShowInputForm(const Prompt, DefaultValue: string; InputType: TMacroInputType; const AppContext: IAppContext; var FormResult: string): Boolean;

var
    InputForm: TInputForm;

implementation

uses
    System.SysUtils,
    Common.Localization
    ;

const
    SP_PREFIX = '⏵ ';
    SP_POSTFIX = ', ⏎';

{$R *.dfm}

function IsMacroValueValid(const Value: string; InputType: TMacroInputType): Boolean;
var
    HexStr: string;
    IntVal: Integer;
    FloatVal: Double;
    DateVal: TDateTime;
    I: Integer;
begin
    case InputType of
        mitNumber:
            Result := TryStrToInt(Value, IntVal);

        mitHex:
            begin
                HexStr := Value;
                if (Length(HexStr) >= 2) and (Copy(HexStr, 1, 2) = '0x') then
                    HexStr := Copy(HexStr, 3, MaxInt);

                Result := (HexStr <> '') and (Length(HexStr) <= 8);
                if Result then
                begin
                    for I := 1 to Length(HexStr) do
                    begin
                        if not CharInSet(HexStr[I], ['0'..'9', 'A'..'F', 'a'..'f']) then
                            Exit(False);
                    end;
                end;
            end;

        mitFloat:
            Result := TryStrToFloat(Value, FloatVal);

        mitPassword:
            Result := Length(Value) > 0;

        mitDate:
            Result := TryStrToDate(Value, DateVal);

    else
        Result := True;
    end;
end;

function ShowInputFormModal(const Prompt, DefaultValue: string; InputType: TMacroInputType; const AppContext: IAppContext; var Value: string): Boolean;
var
    Form: TInputForm;
begin
    Form := TInputForm.Create(nil);
    try
        Form.Initialize(AppContext);
        if (Prompt <> '') then
        begin
            Form.Caption := Prompt;
            Form.lbPrompt.Caption := Prompt;
        end;

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
                sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.String') + SP_POSTFIX;
                ebEdit.Text := FDefaultValue;
            end;

        mitNumber:
            begin
                sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Number') + SP_POSTFIX;
                ebEdit.Text := FDefaultValue;
            end;

        mitHex:
            begin
                sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Hex') + SP_POSTFIX;
                ebEdit.Text := FDefaultValue;
                ebEdit.CharCase := ecUpperCase;
            end;

        mitFloat:
            begin
                sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Float') + SP_POSTFIX;
                ebEdit.Text := FDefaultValue;
            end;

        mitPassword:
            begin
                sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Password') + SP_POSTFIX;
                ebEdit.PasswordChar := '*';
                ebEdit.Text := FDefaultValue;
            end;

        mitDate:
            begin
                sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Date') + SP_POSTFIX;
                ebEdit.Text := FDefaultValue;
            end;

        mitSelect:
            begin
                FillSelectItems;
                sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Select') + SP_POSTFIX;
            end;
    end;

    if FInputType = mitSelect then
    begin
        ebEdit.Visible := False;
        cbSelect.Visible := True;
        cbSelect.SetFocus;
    end
    else
        ebEdit.SetFocus;
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
                sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Number') + SP_POSTFIX;
            mitHex:
                sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Hex') + SP_POSTFIX;
            mitFloat:
                sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Float') + SP_POSTFIX;
            mitDate:
                sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Date') + SP_POSTFIX;
        end;
    end
    else
    begin
        case FInputType of
            mitNumber:
                sbBottom.SimpleText := TUIStateLoader.GetMessage('InputForm.Error.Number');
            mitHex:
                sbBottom.SimpleText := TUIStateLoader.GetMessage('InputForm.Error.Hex');
            mitFloat:
                sbBottom.SimpleText := TUIStateLoader.GetMessage('InputForm.Error.Float');
            mitDate:
                sbBottom.SimpleText := TUIStateLoader.GetMessage('InputForm.Error.Date');
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

end.

