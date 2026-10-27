unit Common.SnippetLanguageDetect;

// Средний автодетект языка сниппета по эвристикам (score-система).
// Детерминированный, без регулярных выражений; работает по первым строкам.
// Ничего убедительного не найдено -> язык по умолчанию (bash).

interface

function DetectSnippetLanguage(const AContent: string): string;

implementation

uses
    Common.Consts,
    Common.SnippetLanguages,
    System.Math,
    System.SysUtils
    ;

const
    MAX_SCAN_LINES = 300;
    MIN_CONFIDENT_SCORE = 4;

    // Порядок разрешения равных счетчиков: специфичные языки раньше,
    // bash (значение по умолчанию) - последним.
    DETECT_PRIORITY: array[0..6] of string = (
        SNIPPET_LANG_XML,
        SNIPPET_LANG_JSON,
        SNIPPET_LANG_BAT,
        SNIPPET_LANG_POWERSHELL,
        SNIPPET_LANG_INI,
        SNIPPET_LANG_MARKDOWN,
        SNIPPET_LANG_BASH
    );

    PS_VERBS: array[0..15] of string = (
        'GET-', 'SET-', 'NEW-', 'REMOVE-', 'WRITE-', 'OUT-', 'INVOKE-',
        'TEST-', 'IMPORT-', 'EXPORT-', 'CONVERTTO-', 'CONVERTFROM-',
        'START-', 'STOP-', 'COPY-', 'MOVE-'
    );

function DetectSnippetLanguage(const AContent: string): string;
var
    Lines: TArray<string>;
    I, Verb: Integer;
    L, UpL, CT: string;
    BashScore, BatScore, PsScore, XmlScore, JsonScore, IniScore, MdScore: Integer;
    Scores: array[0..6] of Integer;
    Best, BestScore: Integer;
begin
    CT := Trim(AContent);
    if CT = '' then
        Exit(DEFAULT_SNIPPET_LANGUAGE);

    BashScore := 0;
    BatScore := 0;
    PsScore := 0;
    XmlScore := 0;
    JsonScore := 0;
    IniScore := 0;
    MdScore := 0;

    // JSON: текст целиком начинается/заканчивается как объект или массив
    if (CT[1] = '{') or (CT[1] = '[') then
        JsonScore := JsonScore + 2;
    if (CT[Length(CT)] = '}') or (CT[Length(CT)] = ']') then
        JsonScore := JsonScore + 1;

    Lines := CT.Split([#10]);
    for I := 0 to Min(Length(Lines) - 1, MAX_SCAN_LINES - 1) do
    begin
        L := Trim(Lines[I]);
        if L = '' then
            Continue;
        UpL := UpperCase(L);

        // Shebang: однозначный маркер
        if L.StartsWith('#!') then
        begin
            if (Pos('POWERSHELL', UpL) > 0) or (Pos('PWSH', UpL) > 0) then
                PsScore := PsScore + 12
            else
                BashScore := BashScore + 8;
        end;

        // --- bat/cmd ---
        if UpL = '@ECHO OFF' then
            BatScore := BatScore + 10
        else if UpL.StartsWith('@ECHO') then
            BatScore := BatScore + 6;
        if Pos('SETLOCAL', UpL) > 0 then
            BatScore := BatScore + 4;
        if Pos('GOTO ', UpL) > 0 then
            BatScore := BatScore + 3;
        if Pos('ERRORLEVEL', UpL) > 0 then
            BatScore := BatScore + 3;
        if L.StartsWith('::') then
            BatScore := BatScore + 2;
        if Pos('REM ', UpL) = 1 then
            BatScore := BatScore + 2;
        if UpL.StartsWith('SET ') and (Pos('=', L) > 0) then
            BatScore := BatScore + 2;

        // --- powershell ---
        if Pos('#REQUIRES', UpL) > 0 then
            PsScore := PsScore + 6;
        if Pos('[CMDLETBINDING', UpL) > 0 then
            PsScore := PsScore + 6;
        if Pos('PARAM(', UpL) > 0 then
            PsScore := PsScore + 5;
        for Verb := Low(PS_VERBS) to High(PS_VERBS) do
            if Pos(PS_VERBS[Verb], UpL) > 0 then
            begin
                PsScore := PsScore + 4;
                Break;
            end;
        if (Pos('$', L) > 0) and (Pos(' = ', L) > 0) then
            PsScore := PsScore + 2;
        if UpL.Equals('TRY') or UpL.StartsWith('TRY {') or (Pos('CATCH', UpL) > 0) then
            PsScore := PsScore + 2;

        // --- xml ---
        if L.StartsWith('<?xml') then
            XmlScore := XmlScore + 10;
        if Pos('XMLNS', UpL) > 0 then
            XmlScore := XmlScore + 5;
        if L.StartsWith('<') and L.EndsWith('>') then
        begin
            XmlScore := XmlScore + 1;
            if Pos('="', L) > 0 then
                XmlScore := XmlScore + 2;
        end;
        if L.StartsWith('</') then
            XmlScore := XmlScore + 2;

        // --- json: "ключ": значение ---
        if Pos('":', L) > 0 then
            JsonScore := JsonScore + 2;

        // --- ini ---
        if L.StartsWith('[') and L.EndsWith(']') and (Length(L) > 2) then
            IniScore := IniScore + 5;
        if (Pos(';', L) = 1) or (Pos('#', L) = 1) then
            IniScore := IniScore + 1
        else if (Pos('=', L) > 1) and CharInSet(L[1], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
            IniScore := IniScore + 1;

        // --- markdown ---
        if (Length(L) > 1) and (L[1] = '#') and (L[2] = ' ') then
            MdScore := MdScore + 3;
        if L.StartsWith('```') then
            MdScore := MdScore + 6;
        if L.StartsWith('- ') or L.StartsWith('* ') then
            MdScore := MdScore + 1;
        if Pos('**', L) > 0 then
            MdScore := MdScore + 2;
        if Pos('](', L) > 0 then
            MdScore := MdScore + 2;

        // --- bash ---
        if Pos('$(', L) > 0 then
            BashScore := BashScore + 3;
        if Pos('${', L) > 0 then
            BashScore := BashScore + 3;
        if Pos(' && ', L) > 0 then
            BashScore := BashScore + 2;
        if Pos(' | ', L) > 0 then
            BashScore := BashScore + 1;
        if UpL.StartsWith('SUDO ') or UpL.StartsWith('APT ') or UpL.StartsWith('APT-GET ')
            or UpL.StartsWith('SYSTEMCTL ') or UpL.StartsWith('DOCKER ') or UpL.StartsWith('GIT ')
            or UpL.StartsWith('EXPORT ') or UpL.StartsWith('SOURCE ') then
            BashScore := BashScore + 2;
    end;

    Scores[0] := XmlScore;
    Scores[1] := JsonScore;
    Scores[2] := BatScore;
    Scores[3] := PsScore;
    Scores[4] := IniScore;
    Scores[5] := MdScore;
    Scores[6] := BashScore;

    Best := 0;
    BestScore := Scores[0];
    for I := 1 to High(Scores) do
        if Scores[I] > BestScore then
        begin
            BestScore := Scores[I];
            Best := I;
        end;

    if BestScore >= MIN_CONFIDENT_SCORE then
        Result := DETECT_PRIORITY[Best]
    else
        Result := DEFAULT_SNIPPET_LANGUAGE;
end;

end.
