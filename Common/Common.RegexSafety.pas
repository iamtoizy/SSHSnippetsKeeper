unit Common.RegexSafety;

interface

uses
    System.RegularExpressions
    ;

type
    TRegexSafety = record
    public const
        MatchLimitCalls = 500000;
    public
        class function TryCompile(const APattern: string;
            out AError: string): Boolean; static;
        class function PatternIsValid(const APattern: string): Boolean; static;
        class function IsMatch(const AInput, APattern: string;
            AOptions: TRegExOptions = []): Boolean; static;
    end;

implementation

uses
    System.RegularExpressionsAPI,
    System.SysUtils
    ;

function OptionsToPCRE(AOptions: TRegExOptions): Integer;
begin
    Result := PCRE_UTF16;
    if roIgnoreCase in AOptions then
        Result := Result or PCRE_CASELESS;
end;

class function TRegexSafety.TryCompile(const APattern: string;
    out AError: string): Boolean;
var
    Code: PPCRE;
    Err: MarshaledAString;
    ErrOffset: Integer;
begin
    Result := True;
    AError := '';
    if APattern = '' then
        Exit;

    Code := pcre_compile(PCRE_STR(APattern), OptionsToPCRE([]),
        @Err, @ErrOffset, nil);
    if Code = nil then
    begin
        if Err <> nil then
            AError := string(Err)
        else
            AError := 'PCRE compile failed';
        Result := False;
        Exit;
    end;

    pcre_dispose(Code, nil, nil);
end;

class function TRegexSafety.PatternIsValid(const APattern: string): Boolean;
var
    Err: string;
begin
    Result := TryCompile(APattern, Err);
end;

class function TRegexSafety.IsMatch(const AInput, APattern: string;
    AOptions: TRegExOptions): Boolean;
var
    Code: PPCRE;
    Extra: TPCREExtra;
    Err: MarshaledAString;
    ErrOffset: Integer;
    OVec: array[0..5] of Integer;
    Rc: Integer;
begin
    if APattern = '' then
        Exit(False);

    Code := pcre_compile(PCRE_STR(APattern), OptionsToPCRE(AOptions),
        @Err, @ErrOffset, nil);
    if Code = nil then
        Exit(False);

    try
        FillChar(Extra, SizeOf(Extra), 0);
        Extra.flags := PCRE_EXTRA_MATCH_LIMIT;
        Extra.match_limit := MatchLimitCalls;
        Rc := pcre_exec(Code, @Extra, PCRE_STR(AInput), Length(AInput),
            0, 0, @OVec[0], Length(OVec));
    finally
        pcre_dispose(Code, nil, nil);
    end;

    Result := Rc >= 0;
end;

end.
