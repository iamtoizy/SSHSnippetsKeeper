unit MacroEngine;

interface

uses
    MacroInputTypes,
    System.Generics.Collections,
    System.RegularExpressions,
    System.SysUtils
    ;

const
    MAX_MACRO_CACHE = 5000;
    MAX_SLEEP_MS = 600000;

type
    TMacroToken = record
        Kind: TMacroTokenKind;
        Text: string;
        Value: Integer;
        InputType: TMacroInputType;
        DefaultValue: string;
    end;

function TryParseSendKey(const AArgs: string; out AKey: Integer; out AText: string): Boolean;

type
    TMacroEngine = class
    private
        FRegex: TRegEx;
        FCache: TDictionary<string, TArray<TMacroToken>>;
        FCacheLock: TObject;
        FCacheOrder: TQueue<string>; // Очередь для контроля порядка кэша
        function ParseTokens(const Text: string): TArray<TMacroToken>;
    public
        constructor Create;
        destructor Destroy; override;

        function GetTokens(const Text: string): TArray<TMacroToken>;
        function ValidateCommands(const Text: string): TArray<string>;
        function Parse(const Text: string; Context: TMacroContext): TArray<IScriptAction>;
        procedure PreCollectInputs(const Actions: TArray<IScriptAction>; Context: TMacroContext);
    end;

implementation

uses
    MacroActions,
    System.Math,
    Winapi.Windows
    ;

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

function TMacroEngine.ParseTokens(const Text: string): TArray<TMacroToken>;
var
    Matches: TMatchCollection;
    Match: TMatch;
    Tokens: TList<TMacroToken>;
    Token: TMacroToken;
    LastPos, MatchStart: Integer;
    Cmd, Name, Args, ParamStr, KeyChar: string;
    P, BracketEnd: Integer;
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
        else if TypeStr = 'CONFIRM' then AType := mitConfirm
        else AType := mitString;
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
                    Tokens.Add(Token);
                end;
            end;

            Cmd := TrimLeft(Match.Groups[1].Value);

            P := 1;
            while (P <= Length(Cmd)) and not CharInSet(Cmd[P], [' ', '[']) do
                Inc(P);

            Name := UpperCase(Trim(Copy(Cmd, 1, P - 1)));
            Args := Trim(Copy(Cmd, P, MaxInt));

            Token.Text := '';
            Token.Value := 0;
            Token.InputType := mitString;
            Token.DefaultValue := '';

            if Name = 'SLEEP' then
            begin
                Token.Kind := tkSleep;
                Token.Value := EnsureRange(StrToIntDef(Args, 0), 0, MAX_SLEEP_MS);
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
                if TryParseSendKey(Args, Token.Value, KeyChar) then
                begin
                    if KeyChar <> '' then
                    begin
                        Token.Kind := tkText;
                        Token.Text := KeyChar;
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
    Value: string;
begin
    Context.UserCanceled := False;

    for Action in Actions do
    begin
        if Context.UserCanceled then
            Break;

        if Action is TInputAction then
        begin
            InputAction := Action as TInputAction;

            // Confirm НЕ собираем заранее, он выполнится в потоке
            if InputAction.GetInputType = mitConfirm then
                Continue;

            if Assigned(Context.OnInput) then
            begin
                Context.CurrentInputType := InputAction.GetInputType;
                Context.CurrentDefaultValue := InputAction.GetDefaultValue;

                Value := Context.OnInput(InputAction.GetPrompt);

                if not Context.UserCanceled then
                    InputAction.SetPreCollectedValue(Value);
            end;
        end;
    end;
end;

function TMacroEngine.Parse(const Text: string; Context: TMacroContext): TArray<IScriptAction>;
var
    Tokens: TArray<TMacroToken>;
    Token: TMacroToken;
    Actions: TList<IScriptAction>;
begin
    Tokens := GetTokens(Text);

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
                    Actions.Add(TSendKeyAction.Create(Context, Token.Value));
                tkUnknown:
                    ;
            end;
        end;
        Result := Actions.ToArray;
    finally
        Actions.Free;
    end;
end;

end.
