unit CronService;

interface

uses
    Core.Interfaces
    ;

type
    TCronService = class(TInterfacedObject, ICronService)
    private
        function GetDeclension(Value: Integer; const W1, W2, W5: string): string;
        function ParseComponent(const Part: string; const UnitName1, UnitName2, UnitName5: string; const PrepDict, BaseDict: TArray<string>): string;

        function GetMonthsPrep: TArray<string>;
        function GetMonthsBase: TArray<string>;
        function GetDowPrep: TArray<string>;
        function GetDowBase: TArray<string>;

        function ParseMinutes(const Part: string): string;
        function ParseHours(const Part: string): string;
        function ParseDaysOfMonth(const Part: string): string;
        function ParseMonths(const Part: string): string;
        function ParseDaysOfWeek(const Part: string): string;
    public
        function ExpressionToHumanText(const Expression: string): string;
        function ValidateExpression(const Expression: string; out ErrorMsg: string): Boolean;
    end;

implementation

uses
    UI.StateLoader,
    System.SysUtils
    ;

{ TCronService }

function TCronService.GetMonthsPrep: TArray<string>;
begin
    Result := [
        '',
        TUIStateLoader.GetMessage('Cron.Month-Prep-1'),
        TUIStateLoader.GetMessage('Cron.Month-Prep-2'),
        TUIStateLoader.GetMessage('Cron.Month-Prep-3'),
        TUIStateLoader.GetMessage('Cron.Month-Prep-4'),
        TUIStateLoader.GetMessage('Cron.Month-Prep-5'),
        TUIStateLoader.GetMessage('Cron.Month-Prep-6'),
        TUIStateLoader.GetMessage('Cron.Month-Prep-7'),
        TUIStateLoader.GetMessage('Cron.Month-Prep-8'),
        TUIStateLoader.GetMessage('Cron.Month-Prep-9'),
        TUIStateLoader.GetMessage('Cron.Month-Prep-10'),
        TUIStateLoader.GetMessage('Cron.Month-Prep-11'),
        TUIStateLoader.GetMessage('Cron.Month-Prep-12')
    ];
end;

function TCronService.GetMonthsBase: TArray<string>;
begin
    Result := [
        '',
        TUIStateLoader.GetMessage('Cron.Month-1').ToLower,
        TUIStateLoader.GetMessage('Cron.Month-2').ToLower,
        TUIStateLoader.GetMessage('Cron.Month-3').ToLower,
        TUIStateLoader.GetMessage('Cron.Month-4').ToLower,
        TUIStateLoader.GetMessage('Cron.Month-5').ToLower,
        TUIStateLoader.GetMessage('Cron.Month-6').ToLower,
        TUIStateLoader.GetMessage('Cron.Month-7').ToLower,
        TUIStateLoader.GetMessage('Cron.Month-8').ToLower,
        TUIStateLoader.GetMessage('Cron.Month-9').ToLower,
        TUIStateLoader.GetMessage('Cron.Month-10').ToLower,
        TUIStateLoader.GetMessage('Cron.Month-11').ToLower,
        TUIStateLoader.GetMessage('Cron.Month-12').ToLower
    ];
end;

function TCronService.GetDowPrep: TArray<string>;
begin
    Result := [
        TUIStateLoader.GetMessage('Cron.Dow-Prep-0'),
        TUIStateLoader.GetMessage('Cron.Dow-Prep-1'),
        TUIStateLoader.GetMessage('Cron.Dow-Prep-2'),
        TUIStateLoader.GetMessage('Cron.Dow-Prep-3'),
        TUIStateLoader.GetMessage('Cron.Dow-Prep-4'),
        TUIStateLoader.GetMessage('Cron.Dow-Prep-5'),
        TUIStateLoader.GetMessage('Cron.Dow-Prep-6'),
        TUIStateLoader.GetMessage('Cron.Dow-Prep-0')  // 7 - Воскресенье
    ];
end;

function TCronService.GetDowBase: TArray<string>;
begin
    Result := [
        TUIStateLoader.GetMessage('Cron.Dow-0').ToLower,
        TUIStateLoader.GetMessage('Cron.Dow-1').ToLower,
        TUIStateLoader.GetMessage('Cron.Dow-2').ToLower,
        TUIStateLoader.GetMessage('Cron.Dow-3').ToLower,
        TUIStateLoader.GetMessage('Cron.Dow-4').ToLower,
        TUIStateLoader.GetMessage('Cron.Dow-5').ToLower,
        TUIStateLoader.GetMessage('Cron.Dow-6').ToLower,
        TUIStateLoader.GetMessage('Cron.Dow-0').ToLower  // 7 - Воскресенье
    ];
end;

function TCronService.GetDeclension(Value: Integer; const W1, W2, W5: string): string;
var
    V: Integer;
begin
    V := Abs(Value) mod 100;
    if (V >= 11) and (V <= 19) then
        Exit(W5);
    V := V mod 10;
    if V = 1 then
        Exit(W1);
    if (V >= 2) and (V <= 4) then
        Exit(W2);
    Result := W5;
end;

function TCronService.ValidateExpression(const Expression: string; out ErrorMsg: string): Boolean;
var
    Parts: TArray<string>;
begin
    ErrorMsg := '';
    Parts := Expression.Trim.Split([' '], TStringSplitOptions.ExcludeEmpty);
    if Length(Parts) <> 5 then
    begin
        ErrorMsg := TUIStateLoader.GetMessage('Cron.Error-5Elements');
        Exit(False);
    end;
    Result := True;
end;

function TCronService.ParseComponent(const Part: string; const UnitName1, UnitName2, UnitName5: string; const PrepDict, BaseDict: TArray<string>): string;
var
    Val: Integer;
    Range: TArray<string>;
    ArrStr: TArray<string>;
    Sb: TStringBuilder;
    I: Integer;
begin
    if (Part = '*') or (Part = '*/1') then
        Exit('');

    if Part.StartsWith('*/') then
    begin
        Val := StrToIntDef(Part.Substring(2), 1);
        Exit(TUIStateLoader.GetMessage('Cron.EveryStep', [Val, GetDeclension(Val, UnitName1, UnitName2, UnitName5)]));
    end;

    if Part.Contains('-') and not Part.Contains(',') then
    begin
        Range := Part.Split(['-']);
        if Length(BaseDict) > 0 then
        begin
            Val := StrToIntDef(Range[0], -1);
            var EndVal := StrToIntDef(Range[1], -1);
            if (Val >= Low(BaseDict)) and (EndVal >= Low(BaseDict)) and (Val <= High(BaseDict)) and (EndVal <= High(BaseDict)) then
                Exit(TUIStateLoader.GetMessage('Cron.Range-Base', [BaseDict[Val], BaseDict[EndVal]])); // "январь - март"
        end;
        Exit(TUIStateLoader.GetMessage('Cron.Range', [Range[0], Range[1]])); // "с 2 по 5"
    end;

    if Part.Contains(',') or (StrToIntDef(Part, -1) >= 0) then
    begin
        ArrStr := Part.Split([',']);
        if Length(PrepDict) > 0 then
        begin
            Sb := TStringBuilder.Create;
            try
                for I := 0 to High(ArrStr) do
                begin
                    Val := StrToIntDef(ArrStr[I], -1);
                    if (Val >= Low(PrepDict)) and (Val <= High(PrepDict)) then
                    begin
                        if I > 0 then
                            Sb.Append(', ');
                        Sb.Append(PrepDict[Val]); // "в январе, в марте"
                    end;
                end;
                Exit(Sb.ToString);
            finally
                Sb.Free;
            end;
        end;
        Exit(Part); // "1, 15, 30"
    end;

    Result := Part;
end;

function TCronService.ParseMinutes(const Part: string): string;
var Res: string;
begin
    if (Part = '*') or (Part = '*/1') then
        Exit(TUIStateLoader.GetMessage('Cron.Every-Minutes'));

    Res := ParseComponent(Part,
        TUIStateLoader.GetMessage('Cron.Word-Minute-1'),
        TUIStateLoader.GetMessage('Cron.Word-Minute-2'),
        TUIStateLoader.GetMessage('Cron.Word-Minute-5'), [], []);

    if Part.StartsWith('*/') then Exit(Res); // "каждые 5 минут"

    Result := TUIStateLoader.GetMessage('Cron.Prefix-Minutes', [Res]);
end;

function TCronService.ParseHours(const Part: string): string;
var Res: string;
begin
    if (Part = '*') or (Part = '*/1') then
        Exit(TUIStateLoader.GetMessage('Cron.Every-Hours'));

    Res := ParseComponent(Part,
        TUIStateLoader.GetMessage('Cron.Word-Hour-1'),
        TUIStateLoader.GetMessage('Cron.Word-Hour-2'),
        TUIStateLoader.GetMessage('Cron.Word-Hour-5'), [], []);

    if Part.StartsWith('*/') then Exit(Res);

    Result := TUIStateLoader.GetMessage('Cron.Prefix-Hours', [Res]);
end;

function TCronService.ParseDaysOfMonth(const Part: string): string;
var Res: string;
begin
    if (Part = '*') or (Part = '*/1') then
        Exit(TUIStateLoader.GetMessage('Cron.Every-DaysOfMonth'));

    Res := ParseComponent(Part,
        TUIStateLoader.GetMessage('Cron.Word-Day-1'),
        TUIStateLoader.GetMessage('Cron.Word-Day-2'),
        TUIStateLoader.GetMessage('Cron.Word-Day-5'), [], []);

    if Part.StartsWith('*/') then Exit(Res);

    Result := TUIStateLoader.GetMessage('Cron.Prefix-DaysOfMonth', [Res]);
end;

function TCronService.ParseMonths(const Part: string): string;
var Res: string;
begin
    if (Part = '*') or (Part = '*/1') then
        Exit(TUIStateLoader.GetMessage('Cron.Every-Months'));

    Res := ParseComponent(Part,
        TUIStateLoader.GetMessage('Cron.Word-Month-1'),
        TUIStateLoader.GetMessage('Cron.Word-Month-2'),
        TUIStateLoader.GetMessage('Cron.Word-Month-5'), GetMonthsPrep, GetMonthsBase);

    if Part.StartsWith('*/') then Exit(Res);

    Result := TUIStateLoader.GetMessage('Cron.Prefix-Months', [Res]);
end;

function TCronService.ParseDaysOfWeek(const Part: string): string;
var Res: string;
begin
    if (Part = '*') or (Part = '*/1') then
        Exit(TUIStateLoader.GetMessage('Cron.Every-DaysOfWeek'));

    if Part = '1-5' then
        Exit(TUIStateLoader.GetMessage('Cron.Prefix-DaysOfWeek', [TUIStateLoader.GetMessage('Cron.Dow-WorkDays')]));
    if (Part = '6,7') or (Part = '7,6') or (Part = '0,6') or (Part = '6,0') then
        Exit(TUIStateLoader.GetMessage('Cron.Prefix-DaysOfWeek', [TUIStateLoader.GetMessage('Cron.Dow-Weekends')]));

    Res := ParseComponent(Part,
        TUIStateLoader.GetMessage('Cron.Word-Dow-1'),
        TUIStateLoader.GetMessage('Cron.Word-Dow-2'),
        TUIStateLoader.GetMessage('Cron.Word-Dow-5'), GetDowPrep, GetDowBase);

    if Part.StartsWith('*/') then Exit(Res);

    Result := TUIStateLoader.GetMessage('Cron.Prefix-DaysOfWeek', [Res]);
end;

function TCronService.ExpressionToHumanText(const Expression: string): string;
var
    Parts: TArray<string>;
    ErrorMsg: string;
    Sb: TStringBuilder;
begin
    if not ValidateExpression(Expression, ErrorMsg) then
        Exit(ErrorMsg);

    Parts := Expression.Trim.Split([' '], TStringSplitOptions.ExcludeEmpty);

    Sb := TStringBuilder.Create;
    try
        Sb.AppendLine('--- 🕒 Расписание задачи: ---');
        Sb.AppendLine(' • ' + ParseMinutes(Parts[0]));
        Sb.AppendLine(' • ' + ParseHours(Parts[1]));
        Sb.AppendLine(' • ' + ParseDaysOfMonth(Parts[2]));
        Sb.AppendLine(' • ' + ParseMonths(Parts[3]));
        Sb.AppendLine(' • ' + ParseDaysOfWeek(Parts[4].Replace('0', '7')));

        Result := Sb.ToString;
    finally
        Sb.Free;
    end;
end;

end.
