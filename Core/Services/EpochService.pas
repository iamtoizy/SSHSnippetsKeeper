unit EpochService;

interface

uses
    Core.Interfaces,
    System.Classes,
    System.SysUtils,
    System.TimeSpan
    ;

type
    TEpochService = class(TInterfacedObject, IEpochService)
    private
        FEngFormat: TFormatSettings;
        FLocalFormat: TFormatSettings;

        // ���������� ������� ��� ������� ����
        function TryParseEpoch(const S: string; out UnixSecs: Int64): Boolean;
        function TryParseISO8601(const S: string; out UnixSecs: Int64): Boolean;
        function TryParseApache(const S: string; out UnixSecs: Int64): Boolean;
        function TryParseSyslog(const S: string; out UnixSecs: Int64): Boolean;
        function TryParseStandard(const S: string; out UnixSecs: Int64): Boolean;

        // ������� ��� Syslog (����������� 'Oct' -> 10)
        function MonthStrToInt(const M: string): Word;
    public
        constructor Create;

        function ParseToUnixSeconds(const Input: string; out UnixSeconds: Int64): Boolean;
        function UnixToLocal(const UnixSeconds: Int64): TDateTime;
        function UnixToUTC(const UnixSeconds: Int64): TDateTime;
        function LocalToUnix(const LocalTime: TDateTime): Int64;
        function UTCToUnix(const UTCTime: TDateTime): Int64;
        function FormatISO8601(const ADateTime: TDateTime): string;
        function GetRelativeTimeHumanized(const ADateTime: TDateTime): string;

        function ExtractAllTimestamps(const Lines: TStrings): TArray<TEpochMatch>;
    end;

implementation

uses
    System.Generics.Collections,
    System.DateUtils,
    System.RegularExpressions,
    UI.StateLoader
    ;

{ TEpochService }

constructor TEpochService.Create;
begin
    inherited;
    // ���� ���� ����� �� ���������� (Jan, Feb, Oct), ������� ������� ����������� �� �� ���������
    FEngFormat := TFormatSettings.Create('en-US');

    // ����: FLocalFormat := TFormatSettings.Create(GetUserDefaultLCID);
    // �����: ����� ������ �� ��������� ��� ������ WinAPI
    FLocalFormat := TFormatSettings.Create;
end;

function TEpochService.MonthStrToInt(const M: string): Word;
var I: Integer;
begin
    Result := 0;
    for I := 1 to 12 do
        if SameText(M, FEngFormat.ShortMonthNames[I]) then Exit(I);
end;

// =======================================================================
//                           ������� ��������
// =======================================================================

function TEpochService.TryParseEpoch(const S: string; out UnixSecs: Int64): Boolean;
var CleanStr: string; RawValue: Int64;
begin
    UnixSecs := 0;
    CleanStr := StringReplace(StringReplace(S, '.', '', [rfReplaceAll]), ',', '', [rfReplaceAll]);
    if not TryStrToInt64(CleanStr, RawValue) then Exit(False);

    if RawValue > 1000000000000000 then UnixSecs := RawValue div 1000000
    else if RawValue > 1000000000000 then UnixSecs := RawValue div 1000
    else UnixSecs := RawValue;
    Result := True;
end;

function TEpochService.TryParseISO8601(const S: string; out UnixSecs: Int64): Boolean;
var DT: TDateTime;
begin
    Result := TryISO8601ToDate(S, DT);
    // ISO8601ToDate ���������� ����� � UTC, ������� AInputIsUTC = True
    if Result then UnixSecs := DateTimeToUnix(DT, True);
end;

function TEpochService.TryParseApache(const S: string; out UnixSecs: Int64): Boolean;
var
    Match: TMatch;
    DT: TDateTime;
    D, Y, H, M, Sec: Word;
    Mo: Word;
    OffsetStr: string;
    OffsetSecs: Int64;
begin
    Result := False;
    // ������: 25/Oct/2023:14:30:00
    Match := TRegEx.Match(S, '(\d{2})/([A-Za-z]{3})/(\d{4}):(\d{2}):(\d{2}):(\d{2})(?:\s*([+-]\d{4}|Z))?');
    if Match.Success then
    begin
        D := StrToIntDef(Match.Groups[1].Value, 1);
        Mo := MonthStrToInt(Match.Groups[2].Value);
        Y := StrToIntDef(Match.Groups[3].Value, 2000);
        H := StrToIntDef(Match.Groups[4].Value, 0);
        M := StrToIntDef(Match.Groups[5].Value, 0);
        Sec := StrToIntDef(Match.Groups[6].Value, 0);

        if TryEncodeDateTime(Y, Mo, D, H, M, Sec, 0, DT) then
        begin
            // Apache/Nginx writes LOCAL time plus an explicit offset (+HHMM or Z).
            // Components above are encoded as if UTC, then shifted back to real UTC.
            if Match.Groups[7].Success and (Match.Groups[7].Value <> 'Z') then
            begin
                OffsetStr := Match.Groups[7].Value;
                OffsetSecs := StrToIntDef(Copy(OffsetStr, 2, 2), 0) * 3600 +
                              StrToIntDef(Copy(OffsetStr, 4, 2), 0) * 60;
                if OffsetStr[1] = '-' then
                    OffsetSecs := -OffsetSecs;
                UnixSecs := UTCToUnix(DT) - OffsetSecs;
            end
            else
                UnixSecs := UTCToUnix(DT);
            Result := True;
        end;
    end;
end;

function TEpochService.TryParseSyslog(const S: string; out UnixSecs: Int64): Boolean;
var
    Match: TMatch;
    DT, NowDT: TDateTime;
    D, H, M, Sec: Word;
    Mo, Y: Word;
begin
    Result := False;
    // ������: Oct 25 14:30:00 (���� ���)
    Match := TRegEx.Match(S, '([A-Z][a-z]{2})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})');
    if Match.Success then
    begin
        Mo := MonthStrToInt(Match.Groups[1].Value);
        D := StrToIntDef(Match.Groups[2].Value, 1);
        H := StrToIntDef(Match.Groups[3].Value, 0);
        M := StrToIntDef(Match.Groups[4].Value, 0);
        Sec := StrToIntDef(Match.Groups[5].Value, 0);

        NowDT := Now;
        Y := YearOf(NowDT); // ������������ ������� ���

        if TryEncodeDateTime(Y, Mo, D, H, M, Sec, 0, DT) then
        begin
            // ���� ���� ���������� � ������� (��������, ��� �� �������, � ������ ������)
            if DT > NowDT then
                DT := IncYear(DT, -1);

            UnixSecs := LocalToUnix(DT); // Syslog ������ ������� � Local time
            Result := True;
        end;
    end;
end;

function TEpochService.TryParseStandard(const S: string; out UnixSecs: Int64): Boolean;
var DT: TDateTime;
begin
    // ������� ���������� ����������� �������� �� (25.10.2023 14:30:00)
    Result := TryStrToDateTime(S, DT, FLocalFormat);
    if not Result then
        Result := TryStrToDateTime(S, DT, FEngFormat); // �� ������ YYYY/MM/DD

    if Result then UnixSecs := LocalToUnix(DT);
end;

function TEpochService.ExtractAllTimestamps(const Lines: TStrings): TArray<TEpochMatch>;
type
    TLogPattern = record
        Regex: string;
        FormatName: string;
        Parser: function(const S: string; out U: Int64): Boolean of object;
    end;
var
    Patterns: array[0..4] of TLogPattern;
    I, PIdx: Integer;
    LineText: string;
    Match: TMatch;
    Item: TEpochMatch;
    ParsedSecs: Int64;
    ResultList: TList<TEpochMatch>;
begin
    ResultList := TList<TEpochMatch>.Create;
    try
        // �������������� �������� �� ����� ������� � �������

        // 1. ISO 8601 (JSON, Kubernetes)
        Patterns[0].Regex := '\b\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?\b';
        Patterns[0].FormatName := 'ISO 8601 / RFC 3339';
        Patterns[0].Parser := TryParseISO8601;

        // 2. Apache/Nginx (Access log)
        Patterns[1].Regex := '\b\d{2}\/[A-Za-z]{3}\/\d{4}:\d{2}:\d{2}:\d{2}\s(?:[+-]\d{4}|Z)\b';
        Patterns[1].FormatName := 'Apache / Nginx';
        Patterns[1].Parser := TryParseApache;

        // 3. Syslog (auth.log, kern.log)
        Patterns[2].Regex := '\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\b';
        Patterns[2].FormatName := 'Syslog (RFC 3164)';
        Patterns[2].Parser := TryParseSyslog;

        // 4. ������� ���� (SQL, ������ ����)
        Patterns[3].Regex := '\b\d{1,4}[\./-]\d{1,2}[\./-]\d{1,4}\s+\d{2}:\d{2}:\d{2}(?:\.\d+)?\b';
        Patterns[3].FormatName := 'Local DateTime';
        Patterns[3].Parser := TryParseStandard;

        // 5. Unix Timestamp (� ����� �����, ����� �� ������ � ������� �������)
        Patterns[4].Regex := '\b[1-9]\d{8,15}(?:[\.,]\d{1,6})?\b';
        Patterns[4].FormatName := 'Unix Timestamp';
        Patterns[4].Parser := TryParseEpoch;

        for I := 0 to Lines.Count - 1 do
        begin
            LineText := Lines[I];
            if LineText.Trim = '' then Continue;

            // ��������� ������ ����� ������ �������
            for PIdx := 0 to High(Patterns) do
            begin
                for Match in TRegEx.Matches(LineText, Patterns[PIdx].Regex) do
                begin
                    if Patterns[PIdx].Parser(Match.Value, ParsedSecs) then
                    begin
                        Item.RawText := Match.Value;
                        Item.FormatName := Patterns[PIdx].FormatName;
                        Item.UnixSeconds := ParsedSecs;
                        Item.LineIdx := I + 1;
                        Item.CharIdx := Match.Index;
                        Item.PosLength := Match.Length;

                        // ���� ������ Epoch, �������� ������ ����� �����������
                        if PIdx = 4 then
                        begin
                            case Length(StringReplace(StringReplace(Item.RawText, '.', '', [rfReplaceAll]), ',', '', [rfReplaceAll])) of
                                10: Item.FormatName := TUIStateLoader.GetMessage('Epoch.Format-seconds');
                                13: Item.FormatName := TUIStateLoader.GetMessage('Epoch.Format-milliseconds');
                                16: Item.FormatName := TUIStateLoader.GetMessage('Epoch.Format-microseconds');
                            else
                                Item.FormatName := TUIStateLoader.GetMessage('Epoch.Format-non-standard');
                            end;
                        end;

                        ResultList.Add(Item);

                        // ������������: �������� ��������� ����� ��������� � LineText.
                        // ��� �� ���� �������� ������� ����� Unix Timestamp ������ ������ ��� ���������� ISO 8601.
                        LineText := Copy(LineText, 1, Match.Index - 1) +
                                    StringOfChar(' ', Match.Length) +
                                    Copy(LineText, Match.Index + Match.Length, MaxInt);
                    end;
                end;
            end;
        end;

        Result := ResultList.ToArray;
    finally
        ResultList.Free;
    end;
end;

function TEpochService.ParseToUnixSeconds(const Input: string; out UnixSeconds: Int64): Boolean;
var
    Lines: TStringList;
    Matches: TArray<TEpochMatch>;
begin
    UnixSeconds := 0;
    Lines := TStringList.Create;
    try
        Lines.Text := Input;
        Matches := ExtractAllTimestamps(Lines);
        if Length(Matches) > 0 then
        begin
            UnixSeconds := Matches[0].UnixSeconds;
            Exit(True);
        end;
    finally
        Lines.Free;
    end;
    Result := False;
end;

function TEpochService.UnixToLocal(const UnixSeconds: Int64): TDateTime;
begin
    Result := System.DateUtils.UnixToDateTime(UnixSeconds, False);
end;

function TEpochService.UnixToUTC(const UnixSeconds: Int64): TDateTime;
begin
    Result := System.DateUtils.UnixToDateTime(UnixSeconds, True);
end;

function TEpochService.LocalToUnix(const LocalTime: TDateTime): Int64;
begin
    Result := System.DateUtils.DateTimeToUnix(LocalTime, False);
end;

function TEpochService.UTCToUnix(const UTCTime: TDateTime): Int64;
begin
    Result := System.DateUtils.DateTimeToUnix(UTCTime, True);
end;

function TEpochService.FormatISO8601(const ADateTime: TDateTime): string;
begin
    Result := DateToISO8601(ADateTime, True);
end;

function TEpochService.GetRelativeTimeHumanized(const ADateTime: TDateTime): string;
var
    Diff: TTimeSpan;
    TotalSecs, Val: Integer;
    IsPast: Boolean;
    UnitStr: string;
begin
    Diff := TTimeSpan.Subtract(Now, ADateTime);
    TotalSecs := Trunc(Abs(Diff.TotalSeconds));
    IsPast := Diff.TotalSeconds > 0;

    // ���������� �������� � ������� ���������
    if TotalSecs < 60 then
    begin
        Val := TotalSecs;
        UnitStr := TUIStateLoader.GetMessage('Epoch.Seconds'); // "���" ��� "sec"
    end
    else if TotalSecs < 3600 then
    begin
        Val := TotalSecs div 60;
        UnitStr := TUIStateLoader.GetMessage('Epoch.Minutes'); // "���" ��� "min"
    end
    else if TotalSecs < 86400 then
    begin
        Val := TotalSecs div 3600;
        UnitStr := TUIStateLoader.GetMessage('Epoch.Hours');   // "�" ��� "h"
    end
    else
    begin
        Val := TotalSecs div 86400;
        UnitStr := TUIStateLoader.GetMessage('Epoch.Days');    // "��" ��� "d"
    end;

    // ��������� �������� ������ (������ ������� "%d %s �����" � �.�.)
    if IsPast then
        Result := Format(TUIStateLoader.GetMessage('Epoch.Ago'), [Val, UnitStr])
    else
        Result := Format(TUIStateLoader.GetMessage('Epoch.After'), [Val, UnitStr]);

    // ������ ������ ��� ���������� �������
    if TotalSecs < 5 then
        Result := TUIStateLoader.GetMessage('Epoch.JustNow'); // "������ ���" / "just now"
end;

end.
