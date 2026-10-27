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

    TMacroBodyTokenKind = (mbtKey, mbtArg);

    // Тело макроса внутри TSynMultiSyn: открывающий '{' и закрывающий '}'
    // отрезаются маркерами схемы, поэтому на вход приходит "INPUT[...] Имя".
    // Первое слово - имя директивы (Key), остаток строки - аргументы (Arg).
    // Имена атрибутов (Key/String) подбираются темой в SynThemeAdapter.
    TMacroBodySyn = class(TSynCustomHighlighter)
    private
        FKeyAttri: TSynHighlighterAttributes;
        FArgAttri: TSynHighlighterAttributes;
        FTokenKind: TMacroBodyTokenKind;
        FInArgs: Boolean;
    public
        constructor Create(AOwner: TComponent); override;
        class function GetLanguageName: string; override;
        class function GetFriendlyLanguageName: string; override;
        function GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes; override;
        function GetEol: Boolean; override;
        function GetTokenAttribute: TSynHighlighterAttributes; override;
        function GetTokenKind: TSynNativeInt; override;
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

{ TMacroBodySyn }

constructor TMacroBodySyn.Create(AOwner: TComponent);
begin
    inherited Create(AOwner);

    FKeyAttri := TSynHighlighterAttributes.Create('Key', 'Key');
    FKeyAttri.Style := [fsBold];
    AddAttribute(FKeyAttri);

    FArgAttri := TSynHighlighterAttributes.Create('String', 'String');
    AddAttribute(FArgAttri);

    SetAttributesOnChange(DefHighlightChange);

    FTokenKind := mbtKey;
    FInArgs := False;
end;

class function TMacroBodySyn.GetLanguageName: string;
begin
    Result := 'MacroBody';
end;

class function TMacroBodySyn.GetFriendlyLanguageName: string;
begin
    Result := 'MacroBody';
end;

function TMacroBodySyn.GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes;
begin
    case Index of
        SYN_ATTR_KEYWORD: Result := FKeyAttri;
        SYN_ATTR_STRING: Result := FArgAttri;
    else
        Result := FKeyAttri;
    end;
end;

function TMacroBodySyn.GetEol: Boolean;
begin
    Result := Run > fLineLen;
end;

function TMacroBodySyn.GetTokenAttribute: TSynHighlighterAttributes;
begin
    if FTokenKind = mbtKey then
        Result := FKeyAttri
    else
        Result := FArgAttri;
end;

function TMacroBodySyn.GetTokenKind: TSynNativeInt;
begin
    Result := Ord(FTokenKind);
end;

procedure TMacroBodySyn.Next;
var
    C: WideChar;
begin
    fTokenPos := Run;

    if Run >= fLineLen then
    begin
        Inc(Run);
        inherited;
        Exit;
    end;

    if not FInArgs then
    begin
        C := fLine[Run];
        if ((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) or
            ((C >= '0') and (C <= '9')) or (C = '_') then
        begin
            while Run < fLineLen do
            begin
                C := fLine[Run];
                if not (((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) or
                    ((C >= '0') and (C <= '9')) or (C = '_')) then
                    Break;
                Inc(Run);
            end;
        end
        else
            Inc(Run);
        FTokenKind := mbtKey;
        FInArgs := True;
    end
    else
    begin
        FTokenKind := mbtArg;
        Run := fLineLen;
    end;

    inherited;
end;

function TMacroBodySyn.GetRange: Pointer;
begin
    Result := Pointer(Ord(FInArgs));
end;

procedure TMacroBodySyn.ResetRange;
begin
    FInArgs := False;
end;

procedure TMacroBodySyn.SetRange(Value: Pointer);
begin
    FInArgs := Value <> nil;
end;

end.
