unit MacroBuilder;

interface

uses
    MacroEngine,
    MacroInputTypes,
    System.SysUtils
    ;

type
    TMacroStepKind = (mskText, mskSleep, mskEnter, mskKey, mskInput, mskValue, mskClearLine, mskKeyDelay);

    TMacroStep = record
        Kind: TMacroStepKind;
        // mskText: текст; mskKey: выражение (CTRL+C, F5, a); mskInput: имя;
        // mskValue: аргумент (формат/длина/имя переменной)
        Text: string;
        // mskSleep и mskKeyDelay: миллисекунды
        Num: Integer;
        // mskInput: тип ввода
        InputType: TMacroInputType;
        // mskValue: DATETIME/UUID/RANDOM/COUNTER/ENV/CLIPBOARD
        ValueKind: string;
        // mskInput: значение по умолчанию или опции SELECT через |
        Default: string;
    end;

function StepToMacro(const Step: TMacroStep): string;
function StepsToMacro(const Steps: TArray<TMacroStep>): string;
function StepsFromTokens(const Tokens: TArray<TMacroToken>): TArray<TMacroStep>;
function StepsFromMacroText(const Text: string): TArray<TMacroStep>;
function InputTypeTokenName(AType: TMacroInputType): string;
function IndexOfInputType(AType: TMacroInputType): Integer;

const
    // Порядок совпадает с TMacroInputType
    INPUT_TYPE_NAMES: array [0 .. 7] of string =
        ('STRING', 'NUMBER', 'HEX', 'FLOAT', 'PASSWORD', 'DATE', 'CONFIRM', 'SELECT');
    INPUT_TYPE_VALUES: array [0 .. 7] of TMacroInputType =
        (mitString, mitNumber, mitHex, mitFloat, mitPassword, mitDate, mitConfirm, mitSelect);

implementation

uses
    System.Classes,
    System.Generics.Collections,
    Winapi.Windows
    ;

function InputTypeTokenName(AType: TMacroInputType): string;
begin
    case AType of
        mitNumber: Result := 'NUMBER';
        mitHex: Result := 'HEX';
        mitFloat: Result := 'FLOAT';
        mitPassword: Result := 'PASSWORD';
        mitDate: Result := 'DATE';
        mitConfirm: Result := 'CONFIRM';
        mitSelect: Result := 'SELECT';
    else
        Result := 'STRING';
    end;
end;

function IndexOfInputType(AType: TMacroInputType): Integer;
var
    I: Integer;
begin
    Result := 0;
    for I := Low(INPUT_TYPE_VALUES) to High(INPUT_TYPE_VALUES) do
        if INPUT_TYPE_VALUES[I] = AType then
            Exit(I);
end;

function KeyNameFromVK(AVK: Word): string;
begin
    case AVK of
        VK_RETURN: Result := 'ENTER';
        VK_TAB: Result := 'TAB';
        VK_ESCAPE: Result := 'ESC';
        VK_SPACE: Result := 'SPACE';
        VK_BACK: Result := 'BACKSPACE';
        VK_DELETE: Result := 'DELETE';
        VK_INSERT: Result := 'INSERT';
        VK_HOME: Result := 'HOME';
        VK_END: Result := 'END';
        VK_PRIOR: Result := 'PAGEUP';
        VK_NEXT: Result := 'PAGEDOWN';
        VK_LEFT: Result := 'LEFT';
        VK_UP: Result := 'UP';
        VK_RIGHT: Result := 'RIGHT';
        VK_DOWN: Result := 'DOWN';
        VK_F1..VK_F9: Result := 'F' + IntToStr(AVK - VK_F1 + 1);
        VK_F10: Result := 'F10';
        VK_F11: Result := 'F11';
        VK_F12: Result := 'F12';
    else
        if ((AVK >= Ord('A')) and (AVK <= Ord('Z'))) or
           ((AVK >= Ord('0')) and (AVK <= Ord('9'))) then
            Result := Chr(AVK)
        else
            Result := IntToStr(AVK);
    end;
end;

function KeyExpressionFromToken(const Token: TMacroToken): string;
begin
    Result := '';

    if (MOD_CONTROL and Token.KeyModifiers) <> 0 then
        Result := Result + 'CTRL+';
    if (MOD_ALT and Token.KeyModifiers) <> 0 then
        Result := Result + 'ALT+';
    if (MOD_SHIFT and Token.KeyModifiers) <> 0 then
        Result := Result + 'SHIFT+';

    Result := Result + KeyNameFromVK(Word(Token.Value));
end;

function StepToMacro(const Step: TMacroStep): string;
begin
    case Step.Kind of
        mskText:
            Result := Step.Text;

        mskSleep:
            Result := Format('{SLEEP %d}', [Step.Num]);

        mskEnter:
            Result := '{ENTER}';

        mskKey:
            Result := Format('{SENDKEY %s}', [Step.Text]);

        mskInput:
        begin
            if Step.InputType = mitConfirm then
                Result := Format('{INPUT[CONFIRM] %s}', [Step.Text])
            else if Step.InputType = mitSelect then
                Result := Format('{INPUT[SELECT:%s] %s}', [Step.Default, Step.Text])
            else if (Step.InputType = mitString) and (Step.Default = '') then
                Result := Format('{INPUT %s}', [Step.Text])
            else if Step.Default = '' then
                Result := Format('{INPUT[%s] %s}', [InputTypeTokenName(Step.InputType), Step.Text])
            else
                Result := Format('{INPUT[%s:%s] %s}', [InputTypeTokenName(Step.InputType), Step.Default, Step.Text]);
        end;

        mskValue:
        begin
            if Step.Text = '' then
                Result := Format('{%s}', [Step.ValueKind])
            else
                Result := Format('{%s:%s}', [Step.ValueKind, Step.Text]);
        end;

        mskClearLine:
            Result := '{CLEAR_LINE}';

        mskKeyDelay:
            Result := Format('{KEYDELAY %d}', [Step.Num]);
    else
        Result := '';
    end;
end;

function StepsToMacro(const Steps: TArray<TMacroStep>): string;
var
    I: Integer;
    Sb: TStringBuilder;
begin
    Sb := TStringBuilder.Create;
    try
        for I := 0 to High(Steps) do
            Sb.Append(StepToMacro(Steps[I]));
        Result := Sb.ToString;
    finally
        Sb.Free;
    end;
end;

function StepsFromTokens(const Tokens: TArray<TMacroToken>): TArray<TMacroStep>;
var
    Steps: TList<TMacroStep>;
    Token: TMacroToken;
    Step: TMacroStep;
begin
    Steps := TList<TMacroStep>.Create;
    try
        for Token in Tokens do
        begin
            Step := Default(TMacroStep);

            case Token.Kind of
                tkText:
                begin
                    Step.Kind := mskText;
                    Step.Text := Token.Text;
                end;

                tkSleep:
                begin
                    Step.Kind := mskSleep;
                    Step.Num := Token.Value;
                end;

                tkEnter:
                    Step.Kind := mskEnter;

                tkSendKey:
                begin
                    Step.Kind := mskKey;
                    Step.Text := KeyExpressionFromToken(Token);
                end;

                tkInput:
                begin
                    Step.Kind := mskInput;
                    Step.Text := Token.Text;
                    Step.InputType := Token.InputType;
                    Step.Default := Token.DefaultValue;
                end;

                tkValue:
                begin
                    Step.Kind := mskValue;
                    Step.ValueKind := Token.Text;
                    Step.Text := Token.DefaultValue;
                end;

                tkClearLine:
                    Step.Kind := mskClearLine;

                tkKeyDelay:
                begin
                    Step.Kind := mskKeyDelay;
                    Step.Num := Token.Value;
                end;

                tkUnknown:
                begin
                    // Нераспознанная конструкция сохраняется как обычный текст
                    Step.Kind := mskText;
                    Step.Text := Token.Text;
                end;
            end;

            Steps.Add(Step);
        end;

        Result := Steps.ToArray;
    finally
        Steps.Free;
    end;
end;

function StepsFromMacroText(const Text: string): TArray<TMacroStep>;
var
    Engine: TMacroEngine;
begin
    Engine := TMacroEngine.Create;
    try
        Result := StepsFromTokens(Engine.GetTokens(Text));
    finally
        Engine.Free;
    end;
end;

end.
