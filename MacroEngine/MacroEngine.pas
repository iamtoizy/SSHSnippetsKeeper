unit MacroEngine;

interface

uses
    System.SysUtils,
    System.Generics.Collections,
    System.RegularExpressions,
    MacroInputTypes
    ;

const
    MAX_MACRO_CACHE = 5000;

type
    TMacroToken = record
        Kind: TMacroTokenKind;
        Text: string;
        Value: Integer;
        InputType: TMacroInputType;
        DefaultValue: string;
    end;

    TMacroEngine = class
    private
        FRegex: TRegEx;
        FCache: TDictionary<string, TArray<TMacroToken>>;
        FCacheLock: TObject;
        function ParseTokens(const Text: string): TArray<TMacroToken>;
    public
        constructor Create;
        destructor Destroy; override;

        function Parse(const Text: string; Context: TMacroContext): TArray<IScriptAction>;
        procedure PreCollectInputs(const Actions: TArray<IScriptAction>; Context: TMacroContext);
    end;

implementation

uses
    MacroActions
    ;

constructor TMacroEngine.Create;
begin
    inherited;
    FCache := TDictionary < string, TArray < TMacroToken >>.Create;
    FCacheLock := TObject.Create;
    FRegex := TRegEx.Create('\{([^}]*)\}');
end;

destructor TMacroEngine.Destroy;
begin
    FCache.Free;
    FCacheLock.Free;
    inherited;
end;

function TMacroEngine.ParseTokens(const Text: string): TArray<TMacroToken>;
var
    Matches: TMatchCollection;
    Match: TMatch;
    Tokens: TList<TMacroToken>;
    Token: TMacroToken;
    LastPos, MatchStart: Integer;
    Cmd, Name, Args, ParamStr: string;
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

            Cmd := Match.Groups[1].Value;

            P := 1;
            while (P <= Length(Cmd)) and not CharInSet(Cmd[P], [' ', '[']) do
                Inc(P);

            Name := UpperCase(Copy(Cmd, 1, P - 1));
            Args := Trim(Copy(Cmd, P, MaxInt));

            Token.Text := '';
            Token.Value := 0;
            Token.InputType := mitString;
            Token.DefaultValue := '';

            if Name = 'SLEEP' then
            begin
                Token.Kind := tkSleep;
                Token.Value := StrToIntDef(Args, 0);
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
                    BracketEnd := Pos(']', Args);
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
                Token.Kind := tkSendKey;
                Token.Value := StrToIntDef(Args, 0);
            end
            else
            begin
                Token.Kind := tkText;
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

procedure TMacroEngine.PreCollectInputs(const Actions: TArray<IScriptAction>; Context: TMacroContext);
var
    Action: IScriptAction;
    InputAction: TInputAction;
    Value: string;
begin
    Context.UserCancelled := False;

    for Action in Actions do
    begin
        if Context.UserCancelled then
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

                if not Context.UserCancelled then
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
    TMonitor.Enter(FCacheLock);
    try
        if not FCache.TryGetValue(Text, Tokens) then
        begin
            Tokens := ParseTokens(Text);
            FCache.Add(Text, Tokens);
            if FCache.Count >= MAX_MACRO_CACHE then
                for var Pair in FCache do
                begin
                    FCache.Remove(Pair.Key);
                    Break;
                end;
        end;
    finally
        TMonitor.Exit(FCacheLock);
    end;

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
            end;
        end;
        Result := Actions.ToArray;
    finally
        Actions.Free;
    end;
end;

end.
