unit Common.CmdLine;

interface

type
    TCmdLineParams = record
        DbPath: string;
        UserName: string;
        NoSync: Boolean;
        Minimized: Boolean;
        Help: Boolean;

        class function Parse: TCmdLineParams; static;
        class function ParseFrom(const Args: TArray<string>): TCmdLineParams; static;
    end;

implementation

uses
    System.SysUtils
    ;

class function TCmdLineParams.Parse: TCmdLineParams;
var
    Args: TArray<string>;
    I: Integer;
begin
    SetLength(Args, ParamCount);
    for I := 1 to ParamCount do
        Args[I - 1] := ParamStr(I);
    Result := ParseFrom(Args);
end;

class function TCmdLineParams.ParseFrom(const Args: TArray<string>): TCmdLineParams;

    function NormalizeSwitch(const AToken: string): string;
    begin
        Result := AToken.TrimLeft(['-', '/']).ToLower;
    end;

    function IsSwitchToken(const AToken: string): Boolean;
    begin
        Result := (AToken <> '') and CharInSet(AToken[1], ['-', '/']);
    end;

var
    I: Integer;
    S, Name, Value: string;
    EqPos: Integer;
begin
    Result := Default(TCmdLineParams);

    I := 0;
    while I < Length(Args) do
    begin
        S := Args[I].Trim;

        if IsSwitchToken(S) then
        begin
            Value := '';
            EqPos := Pos('=', S);

            if EqPos > 0 then
            begin
                Name := NormalizeSwitch(Copy(S, 1, EqPos - 1));
                Value := Copy(S, EqPos + 1, MaxInt).Trim;
            end
            else
            begin
                Name := NormalizeSwitch(S);

                if (Name = 'db') or (Name = 'user') then
                    if (I + 1 < Length(Args)) and (not IsSwitchToken(Args[I + 1].Trim)) then
                    begin
                        Inc(I);
                        Value := Args[I].Trim;
                    end;
            end;

            if Name = 'db' then
                Result.DbPath := Value
            else if Name = 'user' then
                Result.UserName := Value
            else if (Name = 'nosync') or (Name = 'no-sync') then
                Result.NoSync := True
            else if (Name = 'minimized') or (Name = 'min') then
                Result.Minimized := True
            else if (Name = 'help') or (Name = 'h') or (Name = '?') then
                Result.Help := True;
        end;

        Inc(I);
    end;
end;

end.
