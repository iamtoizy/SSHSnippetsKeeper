unit PunycodeService;

interface

type
    TPunycodeMode = (pmAuto, pmToAscii, pmToUnicode);

    TPunycodeResult = record
        LineNumber: Integer;
        Value: string;
        Valid: Boolean;
    end;

function TryConvertDomain(const Domain: string; Mode: TPunycodeMode; out Converted: string): Boolean;
function ConvertDomains(const Input: string; Mode: TPunycodeMode): TArray<TPunycodeResult>;

implementation

uses
    System.Classes,
    System.SysUtils,
    Winapi.Windows;

const
    IdnFlags = IDN_USE_STD3_ASCII_RULES;

function ConvertWithWindows(const Input: string; ToAscii: Boolean; out Output: string): Boolean;
var
    Size: Integer;
begin
    Output := '';
    if ToAscii then
        Size := IdnToAscii(IdnFlags, PChar(Input), Length(Input), nil, 0)
    else
        Size := IdnToUnicode(IdnFlags, PChar(Input), Length(Input), nil, 0);
    if Size = 0 then
        Exit(False);

    SetLength(Output, Size);
    if ToAscii then
        Size := IdnToAscii(IdnFlags, PChar(Input), Length(Input), PChar(Output), Size)
    else
        Size := IdnToUnicode(IdnFlags, PChar(Input), Length(Input), PChar(Output), Size);
    SetLength(Output, Size);
    Result := Size <> 0;
end;

function IsValidAsciiDomain(const Domain: string): Boolean;
var
    Name, LabelText: string;
begin
    Name := Domain;
    if Name.EndsWith('.') then
        SetLength(Name, Length(Name) - 1);
    if (Name = '') or (Length(Name) > 253) then
        Exit(False);
    for LabelText in Name.Split(['.']) do
    begin
        if (LabelText = '') or (Length(LabelText) > 63) then
            Exit(False);
        if (LabelText[1] = '-') or (LabelText[Length(LabelText)] = '-') then
            Exit(False);
    end;
    Result := True;
end;

function TryConvertDomain(const Domain: string; Mode: TPunycodeMode; out Converted: string): Boolean;
var
    Input, AsciiDomain, UnicodeDomain, RoundTrip, LabelText: string;
    Ch: Char;
    HasUnicode, HasAceLabel: Boolean;
begin
    Converted := '';
    Input := Trim(Domain).Replace(#$3002, '.').Replace(#$FF0E, '.').Replace(#$FF61, '.');
    if Input = '' then
        Exit(False);

    HasUnicode := False;
    for Ch in Input do
        if Ord(Ch) > 127 then
            HasUnicode := True
        else if not CharInSet(Ch, ['A'..'Z', 'a'..'z', '0'..'9', '-', '.']) then
            Exit(False);

    if not ConvertWithWindows(Input, True, AsciiDomain) or not IsValidAsciiDomain(AsciiDomain) then
        Exit(False);

    HasAceLabel := False;
    for LabelText in AsciiDomain.Split(['.']) do
        if SameText(Copy(LabelText, 1, 4), 'xn--') then
        begin
            HasAceLabel := True;
            Break;
        end;

    if HasAceLabel then
    begin
        if not ConvertWithWindows(AsciiDomain, False, UnicodeDomain) then
            Exit(False);
        if not ConvertWithWindows(UnicodeDomain, True, RoundTrip) or not SameText(AsciiDomain, RoundTrip) then
            Exit(False);
    end
    else
        UnicodeDomain := AsciiDomain;

    if (Mode = pmToUnicode) or ((Mode = pmAuto) and not HasUnicode and HasAceLabel) then
        Converted := UnicodeDomain
    else
        Converted := AsciiDomain;
    Result := True;
end;

function ConvertDomains(const Input: string; Mode: TPunycodeMode): TArray<TPunycodeResult>;
var
    Lines: TStringList;
    I, Count: Integer;
    Domain: string;
begin
    Result := nil;
    Lines := TStringList.Create;
    try
        Lines.Text := Input;
        SetLength(Result, Lines.Count);
        Count := 0;
        for I := 0 to Lines.Count - 1 do
        begin
            Domain := Trim(Lines[I]);
            if Domain = '' then
                Continue;
            Result[Count].LineNumber := I + 1;
            Result[Count].Valid := TryConvertDomain(Domain, Mode, Result[Count].Value);
            Inc(Count);
        end;
        SetLength(Result, Count);
    finally
        Lines.Free;
    end;
end;

end.
