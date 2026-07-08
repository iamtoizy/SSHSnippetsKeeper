unit InputFormUI;

interface

uses
    Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
    Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Mask,
    Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Samples.Spin,
    MacroActions, MacroInputTypes;

type
    TInputForm = class(TForm)
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
        property ResultValue: string read FResultValue;
    end;

function ShowInputForm(const APrompt, ADefaultValue: string; AInputType: TMacroInputType; var AResult: string): Boolean;

var
    InputForm: TInputForm;

implementation

const
    SP_PREFIX = '⏵ ';
    SP_POSTFIX = ', нажми ⏎';

{$R *.dfm}

function ShowInputForm(const APrompt, ADefaultValue: string; AInputType: TMacroInputType; var AResult: string): Boolean;
var
    Form: TInputForm;
begin
    Form := TInputForm.Create(nil);
    try
        if (APrompt <> '') then
        begin
            Form.Caption := APrompt;
            Form.lbPrompt.Caption := APrompt;
        end;

        Form.FInputType := AInputType;
        if (ADefaultValue <> '') then
            Form.FDefaultValue := ADefaultValue;

        Result := Form.ShowModal = mrOk;
        if Result then
            AResult := Form.ResultValue;
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
            sbBottom.SimpleText := SP_PREFIX + 'Введи текст' + SP_POSTFIX;
        end;

        mitNumber:
        begin
            sbBottom.SimpleText := SP_PREFIX + 'Введи целое число' + SP_POSTFIX;
            ebEdit.Text := FDefaultValue;
        end;

        mitHex:
        begin
            sbBottom.SimpleText := SP_PREFIX + 'Введи hex значение (например, FF или 0xFF)' + SP_POSTFIX;
            ebEdit.Text := FDefaultValue;
            ebEdit.CharCase := ecUpperCase;
        end;

        mitFloat:
        begin
            sbBottom.SimpleText := SP_PREFIX + 'Введи число с плавающей точкой (например, 3.14)' + SP_POSTFIX;
            ebEdit.Text := FDefaultValue;
        end;

        mitPassword:
        begin
            sbBottom.SimpleText := SP_PREFIX + 'Введи пароль' + SP_POSTFIX;
            ebEdit.PasswordChar := '*';
            ebEdit.Text := FDefaultValue;
        end;

        mitDate:
        begin
            sbBottom.SimpleText := SP_PREFIX + 'Введи дату (ГГГГ-ММ-ДД)' + SP_POSTFIX;
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
                sbBottom.SimpleText := 'Ошибка: введи целое число'
            else
                sbBottom.SimpleText := SP_PREFIX + 'Введи целое число' + SP_POSTFIX;
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
                sbBottom.SimpleText := 'Ошибка: введи hex значение (0-9, A-F)'
            else
                sbBottom.SimpleText := SP_PREFIX + 'Введи hex значение' + SP_POSTFIX;
        end;

        mitFloat:
        begin
            Valid := TryStrToFloat(Value, FloatVal);
            if not Valid then
                sbBottom.SimpleText := 'Ошибка: введи число (например, 3.14)'
            else
                sbBottom.SimpleText := SP_PREFIX + 'Введи число с плавающей точкой' + SP_POSTFIX;
        end;

        mitPassword:
            Valid := Length(Value) > 0;

        mitDate:
        begin
            var DateVal: TDateTime;
            Valid := TryStrToDate(Value, DateVal);
            if not Valid then
                sbBottom.SimpleText := 'Ошибка: формат даты ГГГГ-ММ-ДД'
            else
                sbBottom.SimpleText := SP_PREFIX + 'Введи дату (ГГГГ-ММ-ДД)' + SP_POSTFIX;
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
