unit MacroEngine;

interface

uses
    MacroCounters,
    MacroInputTypes,
    System.Generics.Collections,
    System.RegularExpressions,
    System.SysUtils
    ;

const
    MAX_MACRO_CACHE = 5000;
    MAX_SLEEP_MS = 600000;
    DEFAULT_RANDOM_LENGTH = 16;
    MAX_RANDOM_LENGTH = 1024;
    DEFAULT_DATETIME_FORMAT = 'yyyy-MM-dd HH:mm:ss';
    RANDOM_CHARSET = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    // Единый реестр имён макросов (источник истины, ровно как парсит
    // ParseTokens): подсветка схемы в TSynMultiSyn собирается из него
    // через BuildMacroStartExpr. Короткие формы {UUID}, {COUNTER},
    // {DATETIME:fmt}, {ENV:VAR}, {CLIPBOARD} и т.д.
    MACRO_BASE_NAMES: TArray<string> = [
        'CLEARLINE', 'CLIPBOARD', 'COUNTER', 'DATETIME', 'ENTER', 'ENV',
        'INPUT', 'KEYDELAY', 'RANDOM', 'SENDKEY', 'SENDKEYEX', 'SLEEP', 'UUID'
    ];

function IsKnownMacroName(const AName: string): Boolean;
function BuildMacroStartExpr: string;

type
    TMacroToken = record
        Kind: TMacroTokenKind;
        Text: string;
        Value: Integer;
        InputType: TMacroInputType;
        DefaultValue: string;
        KeyModifiers: Integer;
        // Макрос распознан, но в аргументе опечатка (плохой SLEEP/KEYDELAY,
        // мусор в значении по умолчанию INPUT, неверная длина RANDOM).
        // Исполняется с прежним смягчением, карточка рисуется красной
        Invalid: Boolean;
        StartOffset: Integer;
        Length: Integer;
    end;

function TryParseSendKey(const AArgs: string; out AKey: Integer; out AText: string): Boolean;
function TryParseSendKeyEx(const AArgs: string; out AKey: Integer; out AModifiers: Integer; out AText: string): Boolean;

type
    TMacroEngine = class
    private
        FRegex: TRegEx;
        FCache: TDictionary<string, TArray<TMacroToken>>;
        FCacheLock: TObject;
        FCacheOrder: TQueue<string>; // Очередь для контроля порядка кэша
        function ParseTokens(const Text: string): TArray<TMacroToken>;
        function GetClipboardTextSync: string;
        function ResolveValueToken(const Token: TMacroToken; Context: TMacroContext; var ARunState: TCounterRunState): string;
    public
        constructor Create;
        destructor Destroy; override;

        function GetTokens(const Text: string): TArray<TMacroToken>;
        function ValidateCommands(const Text: string): TArray<string>;
        function InputDescriptors(const Text: string): TArray<TMacroParamDescriptor>;
        function Parse(const Text: string; Context: TMacroContext): TArray<IScriptAction>;
        procedure PreCollectInputs(const Actions: TArray<IScriptAction>; Context: TMacroContext);
        // Транскрипт сухого прогона: шаги без исполнения, COUNTER не потребляется
        function DryRunTranscript(const Text: string; Context: TMacroContext): TArray<TTranscriptLine>;
    end;

implementation

uses
    MacroActions,
    System.Classes,
    System.Math,
    Vcl.Clipbrd,
    Winapi.Windows
    ;

function IsKnownMacroName(const AName: string): Boolean;
var
    N: string;
begin
    Result := True;
    for N in MACRO_BASE_NAMES do
        if N = AName then
            Exit;
    Result := False;
end;

function BuildMacroStartExpr: string;
var
    Names: TArray<string>;
    Sb: TStringBuilder;
    I, J: Integer;
    Tmp: string;
begin
    // Сортировка по длине по убыванию, иначе SENDKEYEX перебивается
    // коротким SENDKEY
    Names := Copy(MACRO_BASE_NAMES, 0, Length(MACRO_BASE_NAMES));
    for I := 0 to High(Names) - 1 do
        for J := I + 1 to High(Names) do
            if Length(Names[J]) > Length(Names[I]) then
            begin
                Tmp := Names[I];
                Names[I] := Names[J];
                Names[J] := Tmp;
            end;

    // Создание без строкового аргумента: перегрузки TStringBuilder.Create
    // разрешаются нестабильно (строка уходила в Capacity и терялась)
    Sb := TStringBuilder.Create;
    try
        Sb.Append('(?<![@$])\{(?=(?:');
        for I := 0 to High(Names) do
        begin
            if I > 0 then
                Sb.Append('|');
            Sb.Append(Names[I]);
        end;
        Sb.Append(')(?=[\[:\s}]))');
        Result := Sb.ToString;
    finally
        Sb.Free;
    end;
end;

// Похож ли первый идентификатор в скобках на попытку макроса: только
// ВЕРХНИЙ_РЕГИСТР/цифры/подчёркивание - так пишутся директивы движка.
// '{ $_.CPU }', '{ Default }' из PowerShell/bash - не макросы, а
// '{SLEP 500}' (опечатка в верхнем регистре) подсказку сохранит.
function IsMacroAttemptLike(const ARawName: string): Boolean;
var
    C: Char;
begin
    Result := Length(ARawName) >= 2;
    if not Result then
        Exit;
    for C in ARawName do
        if not CharInSet(C, ['A'..'Z', '0'..'9', '_']) then
            Exit(False);
end;

constructor TMacroEngine.Create;
begin
    inherited;
    FCache := TDictionary<string, TArray<TMacroToken>>.Create;
    FCacheOrder := TQueue<string>.Create;
    FCacheLock := TObject.Create;
    FRegex := TRegEx.Create('\{([^}]*)\}');
end;

destructor TMacroEngine.Destroy;
begin
    FCache.Free;
    FCacheOrder.Free;
    FCacheLock.Free;
    inherited;
end;

function TryParseSendKey(const AArgs: string; out AKey: Integer; out AText: string): Boolean;
var
    KeyName: string;
    Num: Integer;
begin
    AKey := 0;
    AText := '';
    KeyName := UpperCase(Trim(AArgs));

    if KeyName = '' then
        Exit(False);

    if Length(Trim(AArgs)) = 1 then
    begin
        AText := Trim(AArgs);
        Exit(True);
    end;

    if TryStrToInt(KeyName, Num) and (Num >= 1) and (Num <= 255) then
    begin
        AKey := Word(Num);
        Exit(True);
    end;

    if KeyName = 'ENTER' then AKey := VK_RETURN
    else if KeyName = 'TAB' then AKey := VK_TAB
    else if (KeyName = 'ESC') or (KeyName = 'ESCAPE') then AKey := VK_ESCAPE
    else if KeyName = 'SPACE' then AKey := VK_SPACE
    else if (KeyName = 'BACKSPACE') or (KeyName = 'BS') then AKey := VK_BACK
    else if (KeyName = 'DELETE') or (KeyName = 'DEL') then AKey := VK_DELETE
    else if (KeyName = 'INSERT') or (KeyName = 'INS') then AKey := VK_INSERT
    else if KeyName = 'HOME' then AKey := VK_HOME
    else if KeyName = 'END' then AKey := VK_END
    else if (KeyName = 'PAGEUP') or (KeyName = 'PGUP') then AKey := VK_PRIOR
    else if (KeyName = 'PAGEDOWN') or (KeyName = 'PGDN') then AKey := VK_NEXT
    else if KeyName = 'LEFT' then AKey := VK_LEFT
    else if KeyName = 'UP' then AKey := VK_UP
    else if KeyName = 'RIGHT' then AKey := VK_RIGHT
    else if KeyName = 'DOWN' then AKey := VK_DOWN
    else if (Length(KeyName) = 2) and (KeyName[1] = 'F') and
        TryStrToInt(Copy(KeyName, 2, 1), Num) and (Num >= 1) and (Num <= 9) then
        AKey := Word(VK_F1 + Num - 1)
    else if KeyName = 'F10' then AKey := VK_F10
    else if KeyName = 'F11' then AKey := VK_F11
    else if KeyName = 'F12' then AKey := VK_F12
    else
        Exit(False);

    Result := True;
end;

function TryParseSendKeyEx(const AArgs: string; out AKey: Integer; out AModifiers: Integer; out AText: string): Boolean;
var
    Parts: TArray<string>;
    I: Integer;
    ModPart, LastPart: string;
    Modifiers: Integer;
begin
    AKey := 0;
    AModifiers := 0;
    AText := '';
    Modifiers := 0;

    Parts := AArgs.Split(['+']);
    if Length(Parts) = 0 then
        Exit(False);

    // Всё кроме последней части - модификаторы
    if Length(Parts) > 1 then
    begin
        for I := 0 to Length(Parts) - 2 do
        begin
            ModPart := UpperCase(Trim(Parts[I]));
            if ModPart = '' then
                Exit(False);
            if (ModPart = 'CTRL') or (ModPart = 'CONTROL') then
                Modifiers := Modifiers or MOD_CONTROL
            else if ModPart = 'ALT' then
                Modifiers := Modifiers or MOD_ALT
            else if ModPart = 'SHIFT' then
                Modifiers := Modifiers or MOD_SHIFT
            else
                Exit(False);
        end;
    end;

    LastPart := Trim(Parts[High(Parts)]);
    if LastPart = '' then
        Exit(False);

    if not TryParseSendKey(LastPart, AKey, AText) then
        Exit(False);

    // Символ без модификаторов остается текстом; с модификаторами
    // доступна только буквенно-цифровая клавиша
    if (AText <> '') and (Modifiers <> 0) then
    begin
        if (Length(AText) = 1) and CharInSet(UpCase(AText[1]), ['A'..'Z', '0'..'9']) then
        begin
            AKey := Ord(UpCase(AText[1]));
            AText := '';
        end
        else
            Exit(False);
    end;

    AModifiers := Modifiers;
    Result := True;
end;

function TMacroEngine.ParseTokens(const Text: string): TArray<TMacroToken>;
var
    Matches: TMatchCollection;
    Match: TMatch;
    Tokens: TList<TMacroToken>;
    Token: TMacroToken;
    LastPos, MatchStart: Integer;
    Cmd, Name, Args, ParamStr, KeyChar: string;
    RawName: string;
    ValueDir, ValueArg: string;
    P, BracketEnd, ValueColon: Integer;
    SleepMs, RandomLen: Integer;
    Chunk: string;

    procedure ParseInputParams(const AParamStr: string; var AType: TMacroInputType; var ADefault: string);
    var
        TypeStr: string;
        ColonPos: Integer;
    begin
        AType := mitString;
        ADefault := '';

        if AParamStr = '' then Exit;

        ColonPos := Pos(':', AParamStr);
        if ColonPos > 0 then
        begin
            TypeStr := UpperCase(Copy(AParamStr, 1, ColonPos - 1));
            ADefault := Copy(AParamStr, ColonPos + 1, MaxInt);
        end
        else
        begin
            TypeStr := UpperCase(AParamStr);
        end;

        if TypeStr = 'STRING' then AType := mitString
        else if TypeStr = 'NUMBER' then AType := mitNumber
        else if TypeStr = 'HEX' then AType := mitHex
        else if TypeStr = 'FLOAT' then AType := mitFloat
        else if TypeStr = 'PASSWORD' then AType := mitPassword
        else if TypeStr = 'DATE' then AType := mitDate
        else if TypeStr = 'TIME' then AType := mitTime
        else if TypeStr = 'DATETIME' then AType := mitDateTime
        else if TypeStr = 'CONFIRM' then AType := mitConfirm
        else if TypeStr = 'SELECT' then AType := mitSelect
        else AType := mitString;
    end;

    function InputDefaultInvalid(const AType: TMacroInputType;
        const ADefault: string): Boolean;
    var
        Option: string;
    begin
        // SELECT требует хотя бы одну непустую опцию; у STRING/CONFIRM и
        // пустого значения по умолчанию ошибки нет, остальное валидирует
        // IsMacroValueValid
        if AType = mitSelect then
        begin
            Result := True;
            for Option in ADefault.Split(['|']) do
                if Trim(Option) <> '' then
                    Exit(False);
        end
        else if (AType = mitString) or (AType = mitConfirm) or
                (Trim(ADefault) = '') then
            Result := False
        else
            Result := not IsMacroValueValid(Trim(ADefault), AType);
    end;

begin
    Tokens := TList<TMacroToken>.Create;
    try
        Matches := FRegex.Matches(Text);
        LastPos := 1;

        for Match in Matches do
        begin
            MatchStart := Match.Index;

            if MatchStart > LastPos then
            begin
                Chunk := Copy(Text, LastPos, MatchStart - LastPos);
                if Chunk <> '' then
                begin
                    Token.Kind := tkText;
                    Token.Text := Chunk;
                    Token.Value := 0;
                    Token.InputType := mitString;
                    Token.DefaultValue := '';
                    Token.KeyModifiers := 0;
                    Token.Invalid := False;
                    Token.StartOffset := LastPos;
                    Token.Length := MatchStart - LastPos;
                    Tokens.Add(Token);
                end;
            end;

            Cmd := TrimLeft(Match.Groups[1].Value);

            P := 1;
            while (P <= Length(Cmd)) and not CharInSet(Cmd[P], [' ', '[']) do
                Inc(P);

            RawName := Trim(Copy(Cmd, 1, P - 1));
            Name := UpperCase(RawName);
            Args := Trim(Copy(Cmd, P, MaxInt));

            Token.Text := '';
            Token.Value := 0;
            Token.InputType := mitString;
            Token.DefaultValue := '';
            Token.KeyModifiers := 0;
            Token.Invalid := False;
            Token.StartOffset := MatchStart;
            Token.Length := Match.Length;

            // Значения, вычисляемые при каждом запуске: в кэш токенов
            // попадает только имя директивы, не само значение
            ValueDir := UpperCase(Name);
            ValueArg := '';
            ValueColon := Pos(':', ValueDir);
            if ValueColon > 0 then
            begin
                ValueArg := Trim(Copy(Cmd, ValueColon + 1, MaxInt));
                ValueDir := Copy(ValueDir, 1, ValueColon - 1);
            end;

            // Скобки без макро-намерения (PowerShell/bash/JSON) - обычный
            // текст: без токена, красной карточки и предупреждений.
            // Проверка ПОСЛЕ разделения '{ENV:ARG}'/'{VALUE_X:ARG}' на имя
            // и аргумент, иначе колоночные формы терялись.
            if (not IsKnownMacroName(Name)) and
               (not ((ValueColon > 0) and IsKnownMacroName(ValueDir))) and
               (not IsMacroAttemptLike(RawName)) then
            begin
                LastPos := MatchStart + Match.Length;
                Continue;
            end;

            if (ValueDir = 'DATETIME') or (ValueDir = 'UUID') or (ValueDir = 'RANDOM') or
               (ValueDir = 'COUNTER') or (ValueDir = 'ENV') or (ValueDir = 'CLIPBOARD') then
            begin
                if (ValueDir = 'ENV') and (ValueArg = '') then
                begin
                    Token.Kind := tkUnknown;
                    Token.Text := Match.Value;
                end
                else
                begin
                    Token.Kind := tkValue;
                    Token.Text := ValueDir;
                    Token.DefaultValue := ValueArg;
                    if (ValueDir = 'RANDOM') and (ValueArg <> '') then
                    begin
                        if (not TryStrToInt(ValueArg, RandomLen)) or
                           (RandomLen < 1) or (RandomLen > MAX_RANDOM_LENGTH) then
                            Token.Invalid := True;
                    end
                    else if (ValueDir = 'COUNTER') and (ValueArg <> '') then
                        Token.Invalid := not IsCounterParamsValid(ValueArg);
                end;

                Tokens.Add(Token);
                LastPos := MatchStart + Match.Length;
                Continue;
            end;

            if Name = 'SLEEP' then
            begin
                Token.Kind := tkSleep;
                // Опечатка в миллисекундах не ломает запуск (смягчение как
                // раньше), но карточка помечается для красной подсветки
                SleepMs := 0;
                if TryStrToInt(Args, SleepMs) then
                    Token.Invalid := (SleepMs < 0) or (SleepMs > MAX_SLEEP_MS)
                else
                    Token.Invalid := True;
                Token.Value := EnsureRange(SleepMs, 0, MAX_SLEEP_MS);
            end
            else if Name = 'ENTER' then
            begin
                Token.Kind := tkEnter;
            end
            else if Name = 'INPUT' then
            begin
                Token.Kind := tkInput;

                if (Args <> '') and (Args[1] = '[') then
                begin
                    BracketEnd := Pos(']', Args); // Ищем первую ']' - разделитель параметров и промпта
                    if BracketEnd > 0 then
                    begin
                        ParamStr := Copy(Args, 2, BracketEnd - 2);  // Hex:FF
                        Token.Text := Trim(Copy(Args, BracketEnd + 1, MaxInt));
                        ParseInputParams(ParamStr, Token.InputType, Token.DefaultValue);
                        Token.Invalid := InputDefaultInvalid(Token.InputType, Token.DefaultValue);
                    end
                    else
                    begin
                        Token.Text := Args;
                    end;
                end
                else
                begin
                    Token.Text := Args;
                end;
            end
            else if Name = 'SENDKEY' then
            begin
                if TryParseSendKeyEx(Args, Token.Value, Token.KeyModifiers, KeyChar) then
                begin
                    if KeyChar <> '' then
                    begin
                        if Token.KeyModifiers = 0 then
                        begin
                            Token.Kind := tkText;
                            Token.Text := KeyChar;
                        end
                        else if CharInSet(UpCase(KeyChar[1]), ['A'..'Z', '0'..'9']) then
                        begin
                            Token.Kind := tkSendKey;
                            Token.Value := Ord(UpCase(KeyChar[1]));
                        end
                        else
                        begin
                            Token.Kind := tkUnknown;
                            Token.Text := Match.Value;
                        end;
                    end
                    else
                        Token.Kind := tkSendKey;
                end
                else
                begin
                    Token.Kind := tkUnknown;
                    Token.Text := Match.Value;
                end;
            end
            else if Name = 'CLEAR_LINE' then
            begin
                Token.Kind := tkClearLine;
            end
            else if Name = 'KEYDELAY' then
            begin
                Token.Value := StrToIntDef(Trim(Args), -1);
                if (Token.Value < 0) or (Token.Value > MAX_SLEEP_MS) then
                begin
                    Token.Kind := tkUnknown;
                    Token.Text := Match.Value;
                end
                else
                    Token.Kind := tkKeyDelay;
            end
            else
            begin
                Token.Kind := tkUnknown;
                Token.Text := Match.Value;
            end;

            Tokens.Add(Token);
            LastPos := MatchStart + Match.Length;
        end;

        if LastPos <= Length(Text) then
        begin
            Token.Kind := tkText;
            Token.Text := Copy(Text, LastPos, MaxInt);
            Token.Value := 0;
            Token.InputType := mitString;
            Token.DefaultValue := '';
            Token.KeyModifiers := 0;
            Token.Invalid := False;
            Token.StartOffset := LastPos;
            Token.Length := Length(Text) - LastPos + 1;
            Tokens.Add(Token);
        end;

        Result := Tokens.ToArray;
    finally
        Tokens.Free;
    end;
end;

function TMacroEngine.GetTokens(const Text: string): TArray<TMacroToken>;
begin
    TMonitor.Enter(FCacheLock);
    try
        if not FCache.TryGetValue(Text, Result) then
        begin
            Result := ParseTokens(Text);

            // Если кэш переполнен, удаляем самый старый элемент по очереди
            if FCache.Count >= MAX_MACRO_CACHE then
            begin
                if FCacheOrder.Count > 0 then
                    FCache.Remove(FCacheOrder.Dequeue);
            end;

            FCache.Add(Text, Result);
            FCacheOrder.Enqueue(Text);
        end;
    finally
        TMonitor.Exit(FCacheLock);
    end;
end;

function TMacroEngine.ValidateCommands(const Text: string): TArray<string>;
var
    Tokens: TArray<TMacroToken>;
    Token: TMacroToken;
    List: TList<string>;
begin
    Tokens := GetTokens(Text);
    List := TList<string>.Create;
    try
        for Token in Tokens do
            if Token.Kind = tkUnknown then
                List.Add(Token.Text);
        Result := List.ToArray;
    finally
        List.Free;
    end;
end;

procedure TMacroEngine.PreCollectInputs(const Actions: TArray<IScriptAction>; Context: TMacroContext);
var
    Action: IScriptAction;
    InputAction: TInputAction;
    Inputs: TList<TInputAction>;
    Params: TArray<TMacroParamDescriptor>;
    Values: TArray<string>;
    Value: string;
    I: Integer;
begin
    Context.UserCanceled := False;

    Inputs := TList<TInputAction>.Create;
    try
        for Action in Actions do
        begin
            if Action is TInputAction then
            begin
                InputAction := Action as TInputAction;

                // Confirm НЕ собираем заранее, он выполнится в потоке
                if InputAction.GetInputType <> mitConfirm then
                    Inputs.Add(InputAction);
            end;
        end;

        if Inputs.Count = 0 then
            Exit;

        // Единый диалог на все параметры: один запрос вместо цепочки окон
        if (Inputs.Count > 1) and Assigned(Context.OnBatchInput) then
        begin
            SetLength(Params, Inputs.Count);
            for I := 0 to Inputs.Count - 1 do
            begin
                Params[I].Name := Inputs[I].GetPrompt;
                Params[I].InputType := Inputs[I].GetInputType;
                Params[I].DefaultValue := Inputs[I].GetDefaultValue;
            end;

            if Context.OnBatchInput(Params, Values) and (Length(Values) = Inputs.Count) then
            begin
                for I := 0 to Inputs.Count - 1 do
                    Inputs[I].SetPreCollectedValue(Values[I]);
            end
            else
                Context.UserCanceled := True;

            Exit;
        end;

        for I := 0 to Inputs.Count - 1 do
        begin
            if Context.UserCanceled then
                Break;

            if Assigned(Context.OnInput) then
            begin
                Context.CurrentInputType := Inputs[I].GetInputType;
                Context.CurrentDefaultValue := Inputs[I].GetDefaultValue;

                Value := Context.OnInput(Inputs[I].GetPrompt);

                if not Context.UserCanceled then
                    Inputs[I].SetPreCollectedValue(Value);
            end;
        end;
    finally
        Inputs.Free;
    end;
end;

function TMacroEngine.GetClipboardTextSync: string;
begin
    try
        Result := Clipboard.AsText;
    except
        Result := '';
    end;
end;

function TMacroEngine.ResolveValueToken(const Token: TMacroToken; Context: TMacroContext; var ARunState: TCounterRunState): string;
var
    FormatMask: string;
    Len, I: Integer;
    GUID: TGUID;
begin
    Result := '';

    if Token.Text = 'DATETIME' then
    begin
        FormatMask := Token.DefaultValue;
        if FormatMask = '' then
            FormatMask := DEFAULT_DATETIME_FORMAT;
        Result := FormatDateTime(FormatMask, Now);
    end
    else if Token.Text = 'UUID' then
    begin
        CreateGUID(GUID);
        Result := LowerCase(GUID.ToString);
        Result := StringReplace(Result, '{', '', [rfReplaceAll]);
        Result := StringReplace(Result, '}', '', [rfReplaceAll]);
    end
    else if Token.Text = 'RANDOM' then
    begin
        Len := StrToIntDef(Token.DefaultValue, DEFAULT_RANDOM_LENGTH);
        Len := EnsureRange(Len, 1, MAX_RANDOM_LENGTH);
        SetLength(Result, Len);
        for I := 1 to Len do
            Result[I] := RANDOM_CHARSET[Random(Length(RANDOM_CHARSET)) + 1];
    end
    else if Token.Text = 'COUNTER' then
    begin
        // В сухом прогоне счётчик показывается, но не увеличивается
        if Context.DryRun then
            Result := EvaluateCounterPeek(Context.SnippetID, Token.DefaultValue, ARunState)
        else
            Result := EvaluateCounter(Context.SnippetID, Token.DefaultValue, ARunState);
    end
    else if Token.Text = 'ENV' then
        Result := GetEnvironmentVariable(Token.DefaultValue)
    else if Token.Text = 'CLIPBOARD' then
        Result := GetClipboardTextSync;
end;

function TMacroEngine.InputDescriptors(const Text: string): TArray<TMacroParamDescriptor>;
var
    Tokens: TArray<TMacroToken>;
    Token: TMacroToken;
    List: TList<TMacroParamDescriptor>;
    Desc: TMacroParamDescriptor;
begin
    Tokens := GetTokens(Text);
    List := TList<TMacroParamDescriptor>.Create;
    try
        for Token in Tokens do
        begin
            if Token.Kind <> tkInput then
                Continue;

            if Token.InputType = mitConfirm then
                Continue;

            Desc.Name := Token.Text;
            Desc.InputType := Token.InputType;
            Desc.DefaultValue := Token.DefaultValue;
            List.Add(Desc);
        end;
        Result := List.ToArray;
    finally
        List.Free;
    end;
end;

function TMacroEngine.Parse(const Text: string; Context: TMacroContext): TArray<IScriptAction>;
var
    Tokens: TArray<TMacroToken>;
    Token: TMacroToken;
    Actions: TList<IScriptAction>;
    RunState: TCounterRunState;
begin
    Tokens := GetTokens(Text);
    RunState := Default(TCounterRunState);

    Actions := TList<IScriptAction>.Create;
    try
        for Token in Tokens do
        begin
            case Token.Kind of
                tkText:
                    Actions.Add(TTypeTextAction.Create(Context, Token.Text));
                tkSleep:
                    Actions.Add(TSleepAction.Create(Context, Token.Value));
                tkEnter:
                    Actions.Add(TEnterAction.Create(Context));
                tkInput:
                    Actions.Add(TInputAction.Create(Context, Token.Text, Token.InputType, Token.DefaultValue));
                tkSendKey:
                    Actions.Add(TSendKeyAction.Create(Context, Token.Value, Token.KeyModifiers));
                tkValue:
                    Actions.Add(TTypeTextAction.Create(Context, ResolveValueToken(Token, Context, RunState)));
                tkClearLine:
                    Actions.Add(TClearLineAction.Create(Context));
                tkKeyDelay:
                    Actions.Add(TSetKeyDelayAction.Create(Context, Token.Value));
                tkUnknown:
                    ;
            end;
        end;
        Result := Actions.ToArray;
    finally
        Actions.Free;
    end;
end;

// Читаемое имя клавиши для превью: модификаторы + имя из набора SENDKEY
function SendKeyPreviewText(AKey, AModifiers: Integer): string;
var
    KeyName: string;
begin
    Result := '';
    if (AModifiers and MOD_CONTROL) <> 0 then
        Result := 'Ctrl+';
    if (AModifiers and MOD_ALT) <> 0 then
        Result := Result + 'Alt+';
    if (AModifiers and MOD_SHIFT) <> 0 then
        Result := Result + 'Shift+';

    case AKey of
        VK_RETURN: KeyName := 'Enter';
        VK_TAB: KeyName := 'Tab';
        VK_ESCAPE: KeyName := 'Esc';
        VK_SPACE: KeyName := 'Space';
        VK_BACK: KeyName := 'Backspace';
        VK_DELETE: KeyName := 'Delete';
        VK_INSERT: KeyName := 'Insert';
        VK_HOME: KeyName := 'Home';
        VK_END: KeyName := 'End';
        VK_PRIOR: KeyName := 'PageUp';
        VK_NEXT: KeyName := 'PageDown';
        VK_LEFT: KeyName := 'Left';
        VK_UP: KeyName := 'Up';
        VK_RIGHT: KeyName := 'Right';
        VK_DOWN: KeyName := 'Down';
        VK_F1..VK_F12: KeyName := 'F' + IntToStr(AKey - VK_F1 + 1);
    else
        if (AKey >= Ord('A')) and (AKey <= Ord('Z')) then
            KeyName := Chr(AKey)
        else if (AKey >= Ord('0')) and (AKey <= Ord('9')) then
            KeyName := Chr(AKey)
        else
            KeyName := '#' + IntToStr(AKey);
    end;

    Result := Result + KeyName;
end;

function TMacroEngine.DryRunTranscript(const Text: string; Context: TMacroContext): TArray<TTranscriptLine>;
var
    Tokens: TArray<TMacroToken>;
    Token: TMacroToken;
    Lines: TList<TTranscriptLine>;
    Line: TTranscriptLine;
    RunState: TCounterRunState;
begin
    Context.DryRun := True;
    Tokens := GetTokens(Text);
    RunState := Default(TCounterRunState);

    Lines := TList<TTranscriptLine>.Create;
    try
        for Token in Tokens do
        begin
            Line := Default(TTranscriptLine);
            Line.Macro := Copy(Text, Token.StartOffset, Token.Length);

            case Token.Kind of
                tkText:
                    begin
                        Line.Kind := tlText;
                        Line.Detail := Token.Text;
                    end;
                tkEnter:
                    Line.Kind := tlEnter;
                tkSleep:
                    begin
                        Line.Kind := tlSleep;
                        Line.Detail := IntToStr(Token.Value);
                        if Token.Invalid then
                            Line.Warning := DRY_RUN_WARN_INVALID;
                    end;
                tkInput:
                    begin
                        // Confirm спрашивается при запуске, в превью это просто шаг
                        if Token.InputType = mitConfirm then
                            Line.Kind := tlConfirm
                        else
                            Line.Kind := tlInput;
                        Line.Name := Token.Text;
                        Line.InputType := Token.InputType;
                        Line.Detail := Token.DefaultValue;
                        if Token.Invalid then
                            Line.Warning := DRY_RUN_WARN_INVALID;
                    end;
                tkSendKey:
                    begin
                        Line.Kind := tlSendKey;
                        Line.Detail := SendKeyPreviewText(Token.Value, Token.KeyModifiers);
                    end;
                tkValue:
                    begin
                        Line.Kind := tlValue;
                        Line.Name := Token.Text;
                        Line.Detail := ResolveValueToken(Token, Context, RunState);
                        if Token.Invalid then
                            Line.Warning := DRY_RUN_WARN_INVALID;
                    end;
                tkClearLine:
                    Line.Kind := tlClearLine;
                tkKeyDelay:
                    begin
                        Line.Kind := tlKeyDelay;
                        Line.Detail := IntToStr(Token.Value);
                    end;
                tkUnknown:
                    begin
                        Line.Kind := tlWarning;
                        Line.Warning := DRY_RUN_WARN_UNKNOWN;
                    end;
            end;

            Lines.Add(Line);
        end;
        Result := Lines.ToArray;
    finally
        Lines.Free;
    end;
end;

initialization
    Randomize;

end.
