unit InputFormUI;

interface

uses
    System.SysUtils,
    System.Classes,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.StdCtrls,
    Vcl.ExtCtrls,
    Vcl.ComCtrls,
    MacroInputTypes,
    BaseFormUI,
    Core.Interfaces,
    Core.AppContext;

type
    TInputForm = class(TBaseForm)
        pnlMain: TPanel;
        bOK: TButton;
        bCancel: TButton;
        lbPrompt: TLabel;
        sbBottom: TStatusBar;
        ebEdit: TEdit;
        procedure FormCreate(Sender: TObject);
        procedure FormShow(Sender: TObject);
        procedure bOKClick(Sender: TObject);
        procedure ebEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure ebEditChange(Sender: TObject);
        procedure bCancelClick(Sender: TObject);
        procedure HandleKeyPresses(const Key: Word);
    private
        FInputType: TMacroInputType;
        FDefaultValue: string;
        FResultValue: string;
        procedure ValidateInput;
    public
        procedure Initialize(AppContext: IAppContext);
        property ResultValue: string read FResultValue;
    end;

function ShowInputForm(const Prompt, DefaultValue: string; InputType: TMacroInputType; const AppContext: IAppContext; var FormResult: string): Boolean;

var
    InputForm: TInputForm;

implementation

uses
    UI.StateLoader
    ;

const
    SP_PREFIX = '⏵ ';
    SP_POSTFIX = ', ⏎';

{$R *.dfm}

function ShowInputForm(const Prompt, DefaultValue: string; InputType: TMacroInputType; const AppContext: IAppContext; var FormResult: string): Boolean;
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

        Result := Form.ShowModal = mrOk;
        if Result then
            FormResult := Form.ResultValue;
    finally
        Form.Free;
    end;
end;

procedure TInputForm.FormCreate(Sender: TObject);
begin
    FResultValue := '';
end;

procedure TInputForm.FormShow(Sender: TObject);
begin
    // Настраиваем контрол в зависимости от типа
    case FInputType of
        mitString:
            begin
                sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.String') + SP_POSTFIX;
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
    end;

    ebEdit.SetFocus;
end;

procedure TInputForm.HandleKeyPresses(const Key: Word);
begin
    case Key of
        13:
            bOKClick(InputForm);
        27:
            bCancelClick(InputForm);
    end;
end;

procedure TInputForm.Initialize(AppContext: IAppContext);
begin
    inherited;
    FAppContext := AppContext;
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

procedure TInputForm.ValidateInput;
var
    Value: string;
    IntVal: Integer;
    FloatVal: Double;
    Valid: Boolean;
begin
    Value := Trim(ebEdit.Text);
    Valid := True;

    case FInputType of
        mitString:
            Valid := True;

        mitNumber:
            begin
                Valid := TryStrToInt(Value, IntVal);
                if not Valid then
                    sbBottom.SimpleText := TUIStateLoader.GetMessage('InputForm.Error.Number')
                else
                    sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Number') + SP_POSTFIX;
            end;

        mitHex:
            begin
                var HexStr := Value;
                if (Length(HexStr) >= 2) and (Copy(HexStr, 1, 2) = '0x') then
                    HexStr := Copy(HexStr, 3, MaxInt);

                Valid := (HexStr <> '') and (Length(HexStr) <= 8);
                if Valid then
                begin
                    for var I := 1 to Length(HexStr) do
                    begin
                        if not CharInSet(HexStr[I], ['0'..'9', 'A'..'F', 'a'..'f']) then
                        begin
                            Valid := False;
                            Break;
                        end;
                    end;
                end;

                if not Valid then
                    sbBottom.SimpleText := TUIStateLoader.GetMessage('InputForm.Error.Hex')
                else
                    sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('InputForm.Prompt.Hex') + SP_POSTFIX;
            end;

        mitFloat:
            begin
                Valid := TryStrToFloat(Value, FloatVal);
                if not Valid then
                    sbBottom.SimpleText := TUIStateLoader.GetMessage('InputForm.Error.Float')
                else
                    sbBottom.SimpleText := TUIStateLoader.GetMessage('InputForm.Prompt.Float') + SP_POSTFIX;
            end;

        mitPassword:
            Valid := Length(Value) > 0;

        mitDate:
            begin
                var DateVal: TDateTime;
                Valid := TryStrToDate(Value, DateVal);
                if not Valid then
                    sbBottom.SimpleText := TUIStateLoader.GetMessage('InputForm.Error.Date')
                else
                    sbBottom.SimpleText := TUIStateLoader.GetMessage('InputForm.Prompt.Date') + SP_POSTFIX;
            end;
    end;

    bOK.Enabled := Valid;
end;

procedure TInputForm.bOKClick(Sender: TObject);
begin
    FResultValue := Trim(ebEdit.Text);
    ModalResult := mrOk;
end;

end.

