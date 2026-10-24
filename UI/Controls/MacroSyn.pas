unit MacroSyn;

interface

uses
    SynFunc,
    SynEditHighlighter,
    System.Classes,
    Vcl.Graphics
    ;

type
    TMacroTokenKind = (mtkText, mtkKey, mtkArg, mtkBrace);

    // Подсветка макросов сниппета: {INPUT[SELECT:a|b] Name}, {SLEEP 500}, {ENV:HOME}...
    // Имена атрибутов (Key/String/Symbol/Text) подбираются темой в SynThemeAdapter.
    TMacroSyn = class(TSynCustomHighlighter)
    private
        FTextAttri: TSynHighlighterAttributes;
        FKeyAttri: TSynHighlighterAttributes;
        FArgAttri: TSynHighlighterAttributes;
        FBraceAttri: TSynHighlighterAttributes;
        FTokenKind: TMacroTokenKind;
        // 0 - вне макроса, 1 - ждём имя директивы после '{', 2 - аргументы
        FState: Integer;
    public
        constructor Create(AOwner: TComponent); override;
        class function GetLanguageName: string; override;
        class function GetFriendlyLanguageName: string; override;
        function GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes; override;
        function GetEol: Boolean; override;
        function GetTokenAttribute: TSynHighlighterAttributes; override;
        function GetTokenKind: TSynNativeInt; override;
        function IsIdentChar(AChar: WideChar): Boolean; override;
        procedure Next; override;
        function GetRange: Pointer; override;
        procedure ResetRange; override;
        procedure SetRange(Value: Pointer); override;
    end;

implementation

{ TMacroSyn }

constructor TMacroSyn.Create(AOwner: TComponent);
begin
    inherited Create(AOwner);

    FTextAttri := TSynHighlighterAttributes.Create('Text', 'Text');
    AddAttribute(FTextAttri);

    FKeyAttri := TSynHighlighterAttributes.Create('Key', 'Key');
    FKeyAttri.Style := [fsBold];
    AddAttribute(FKeyAttri);

    FArgAttri := TSynHighlighterAttributes.Create('String', 'String');
    AddAttribute(FArgAttri);

    FBraceAttri := TSynHighlighterAttributes.Create('Symbol', 'Symbol');
    AddAttribute(FBraceAttri);

    SetAttributesOnChange(DefHighlightChange);

    FState := 0;
end;

class function TMacroSyn.GetLanguageName: string;
begin
    Result := 'Macros';
end;

class function TMacroSyn.GetFriendlyLanguageName: string;
begin
    Result := 'Macros';
end;

function TMacroSyn.GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes;
begin
    case Index of
        SYN_ATTR_KEYWORD: Result := FKeyAttri;
        SYN_ATTR_STRING: Result := FArgAttri;
        SYN_ATTR_SYMBOL: Result := FBraceAttri;
    else
        Result := FTextAttri;
    end;
end;

function TMacroSyn.GetEol: Boolean;
begin
    Result := Run > fLineLen;
end;

function TMacroSyn.GetTokenAttribute: TSynHighlighterAttributes;
begin
    case FTokenKind of
        mtkKey: Result := FKeyAttri;
        mtkArg: Result := FArgAttri;
        mtkBrace: Result := FBraceAttri;
    else
        Result := FTextAttri;
    end;
end;

function TMacroSyn.GetTokenKind: TSynNativeInt;
begin
    Result := Ord(FTokenKind);
end;

function TMacroSyn.IsIdentChar(AChar: WideChar): Boolean;
begin
    Result := ((AChar >= 'A') and (AChar <= 'Z')) or
        ((AChar >= 'a') and (AChar <= 'z')) or
        ((AChar >= '0') and (AChar <= '9')) or
        (AChar = '_');
end;

procedure TMacroSyn.Next;
var
    C: WideChar;
begin
    fTokenPos := Run;

    if Run >= fLineLen then
    begin
        FTokenKind := mtkText;
        Inc(Run);
        inherited;
        Exit;
    end;

    C := fLine[Run];

    case FState of
        0: // обычный текст до следующего '{'
        begin
            if C = '{' then
            begin
                Inc(Run);
                FTokenKind := mtkBrace;
                FState := 1;
            end
            else
            begin
                FTokenKind := mtkText;
                while (fLine[Run] <> '{') and (Run < fLineLen) do
                    Inc(Run);
            end;
        end;

        1: // сразу после '{': имя директивы
        begin
            if C = '}' then
            begin
                Inc(Run);
                FTokenKind := mtkBrace;
                FState := 0;
            end
            else if IsIdentChar(C) then
            begin
                FTokenKind := mtkKey;
                while IsIdentChar(fLine[Run]) do
                    Inc(Run);
                FState := 2;
            end
            else
            begin
                Inc(Run);
                FTokenKind := mtkArg;
                FState := 2;
            end;
        end;
    else // 2: аргументы до '}' или конца строки
        begin
            if C = '}' then
            begin
                Inc(Run);
                FTokenKind := mtkBrace;
                FState := 0;
            end
            else
            begin
                FTokenKind := mtkArg;
                while (fLine[Run] <> '}') and (Run < fLineLen) do
                    Inc(Run);
            end;
        end;
    end;

    inherited;
end;

function TMacroSyn.GetRange: Pointer;
begin
    Result := Pointer(FState);
end;

procedure TMacroSyn.ResetRange;
begin
    FState := 0;
end;

procedure TMacroSyn.SetRange(Value: Pointer);
begin
    FState := Integer(Value);
end;

end.
