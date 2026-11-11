unit Common.QueryLanguage;

interface

uses
    System.Generics.Collections,
    System.SysUtils
    ;

type
    TQueryDateField = (qdfCreated, qdfUpdated);
    TQueryDateOp = (qdoEqual, qdoGreater, qdoGreaterEqual, qdoLess, qdoLessEqual);

    // Границы окна даты: EpochFrom - включительно, EpochTo - исключительно
    TQueryDateFilter = record
        Field: TQueryDateField;
        Op: TQueryDateOp;
        EpochFrom: Int64;
        EpochTo: Int64;
    end;

    TStructuredQuery = record
        TagValues: TArray<string>;
        CategoryValues: TArray<string>;
        TitleValues: TArray<string>;
        TitlePhrases: TArray<string>;
        CommentValues: TArray<string>;
        CommentPhrases: TArray<string>;
        ContentValues: TArray<string>;
        ContentPhrases: TArray<string>;
        LanguageValues: TArray<string>;
        ExcludedWords: TArray<string>;
        ExcludedPhrases: TArray<string>;
        BareWords: TArray<string>;
        BarePhrases: TArray<string>;
        DateFilters: TArray<TQueryDateFilter>;
        OnlyFavorites: Boolean;
        ExcludeFavorites: Boolean;
        function HasStructuredFilters: Boolean;
        function IsEmpty: Boolean;
    end;

    TQueryLanguageParser = class
    public
        class function Parse(const Query: string): TStructuredQuery; static;
    end;

implementation

uses
    System.DateUtils
    ;

const
    KnownPrefixes: array [0..7] of string =
        ('tag', 'cat', 'title', 'comment', 'lang', 'content', 'created', 'updated');

{ TStructuredQuery }

function TStructuredQuery.HasStructuredFilters: Boolean;
begin
    Result := OnlyFavorites
        or ExcludeFavorites
        or (Length(TagValues) > 0)
        or (Length(CategoryValues) > 0)
        or (Length(TitleValues) > 0)
        or (Length(TitlePhrases) > 0)
        or (Length(CommentValues) > 0)
        or (Length(CommentPhrases) > 0)
        or (Length(ContentValues) > 0)
        or (Length(ContentPhrases) > 0)
        or (Length(LanguageValues) > 0)
        or (Length(ExcludedWords) > 0)
        or (Length(ExcludedPhrases) > 0)
        or (Length(BarePhrases) > 0)
        or (Length(DateFilters) > 0);
end;

function TStructuredQuery.IsEmpty: Boolean;
begin
    Result := (not HasStructuredFilters)
        and (Length(BareWords) = 0)
        and (Length(BarePhrases) = 0);
end;

{ Служебные функции разбора }

// Разбиение по пробелам вне кавычек: "два слова" остаётся одним токеном
function ExtractTokens(const Query: string): TArray<string>;
var
    List: TList<string>;
    I, Start: Integer;
    InQuotes: Boolean;
begin
    List := TList<string>.Create;
    try
        InQuotes := False;
        Start := 1;
        for I := 1 to Length(Query) do
        begin
            if Query[I] = '"' then
                InQuotes := not InQuotes
            else if (not InQuotes) and CharInSet(Query[I], [' ', #9, #13, #10]) then
            begin
                if I > Start then
                    List.Add(Copy(Query, Start, I - Start));
                Start := I + 1;
            end;
        end;
        if Start <= Length(Query) then
            List.Add(Copy(Query, Start, MaxInt));
        Result := List.ToArray;
    finally
        List.Free;
    end;
end;

function StripQuotes(const S: string): string;
var
    C: Char;
begin
    Result := '';
    for C in S do
        if C <> '"' then
            Result := Result + C;
end;

function IsDigits(const S: string): Boolean;
var
    C: Char;
begin
    if S = '' then
        Exit(False);
    for C in S do
        if not CharInSet(C, ['0'..'9']) then
            Exit(False);
    Result := True;
end;

function DaysInMonthOf(Y, Mo: Integer): Integer;
begin
    case Mo of
        4, 6, 9, 11: Result := 30;
        2: if IsLeapYear(Y) then Result := 29 else Result := 28;
    else
        Result := 31;
    end;
end;

// Дата YYYY-MM-DD, YYYY-MM, плюс время "HH:MM[:SS]" через пробел или T.
// Возвращает границы окна с учётом точности (месяц/день/минута/секунда).
function TryParseDateBounds(const Value: string; out EpochFrom, EpochTo: Int64): Boolean;
var
    DatePart, TimePart: string;
    DateComps, TimeComps: TArray<string>;
    Y, Mo, D, H, Mi, S, J: Integer;
    BaseDT: TDateTime;
    SpacePos: Integer;
const
    SecPerDay = 86400;
begin
    Result := False;
    EpochFrom := 0;
    EpochTo := 0;

    DatePart := Value;
    TimePart := '';
    SpacePos := Pos(' ', DatePart);
    if SpacePos = 0 then
        SpacePos := Pos('T', DatePart);
    if SpacePos > 0 then
    begin
        TimePart := Copy(DatePart, SpacePos + 1, MaxInt);
        DatePart := Copy(DatePart, 1, SpacePos - 1);
    end;

    DateComps := DatePart.Split(['-']);
    if (Length(DateComps) < 2) or (Length(DateComps) > 3) then
        Exit;
    for J := 0 to High(DateComps) do
        if not IsDigits(DateComps[J]) then
            Exit;

    Y := StrToIntDef(DateComps[0], -1);
    Mo := StrToIntDef(DateComps[1], -1);
    D := 1;
    if Length(DateComps) = 3 then
        D := StrToIntDef(DateComps[2], -1);

    if (Y < 1970) or (Y > 2999) or (Mo < 1) or (Mo > 12) then
        Exit;
    if (Length(DateComps) = 3) and ((D < 1) or (D > DaysInMonthOf(Y, Mo))) then
        Exit;

    H := 0;
    Mi := 0;
    S := 0;
    if TimePart <> '' then
    begin
        TimeComps := TimePart.Split([':']);
        if (Length(TimeComps) < 1) or (Length(TimeComps) > 3) then
            Exit;
        for J := 0 to High(TimeComps) do
            if not IsDigits(TimeComps[J]) then
                Exit;
        H := StrToIntDef(TimeComps[0], -1);
        if Length(TimeComps) > 1 then
            Mi := StrToIntDef(TimeComps[1], -1);
        if Length(TimeComps) > 2 then
            S := StrToIntDef(TimeComps[2], -1);
        if (H < 0) or (H > 23) or (Mi < 0) or (Mi > 59) or (S < 0) or (S > 59) then
            Exit;
    end;

    //created_at/updated_at хранят локальный epoch (DateTimeToUnix(Now)), UI показывает локально
    BaseDT := EncodeDate(Y, Mo, D) + EncodeTime(H, Mi, S, 0);
    EpochFrom := DateTimeToUnix(BaseDT, False);

    if TimePart <> '' then
    begin
        case Length(TimeComps) of
            1: EpochTo := EpochFrom + 3600;
            2: EpochTo := EpochFrom + 60;
        else
            EpochTo := EpochFrom + 1;
        end;
    end
    else if Length(DateComps) = 2 then
        EpochTo := EpochFrom + DaysInMonthOf(Y, Mo) * SecPerDay
    else
        EpochTo := EpochFrom + SecPerDay;

    Result := True;
end;

{ TQueryLanguageParser }

class function TQueryLanguageParser.Parse(const Query: string): TStructuredQuery;
var
    Tokens: TArray<string>;
    Token, Prefix, Value: string;
    Tags, Categories, Titles, TitlePhrases: TList<string>;
    Comments, CommentPhrases, Contents, ContentPhrases: TList<string>;
    Languages, Excluded, ExcludedPhrases, Bare, BarePhrases: TList<string>;
    DateFilters: TList<TQueryDateFilter>;
    DF: TQueryDateFilter;
    ColonPos, PrefixIndex, I: Integer;
    IsKnown, HadQuote: Boolean;
begin
    Result := Default(TStructuredQuery);
    Tags := TList<string>.Create;
    Categories := TList<string>.Create;
    Titles := TList<string>.Create;
    TitlePhrases := TList<string>.Create;
    Comments := TList<string>.Create;
    CommentPhrases := TList<string>.Create;
    Contents := TList<string>.Create;
    ContentPhrases := TList<string>.Create;
    Languages := TList<string>.Create;
    Excluded := TList<string>.Create;
    ExcludedPhrases := TList<string>.Create;
    Bare := TList<string>.Create;
    BarePhrases := TList<string>.Create;
    DateFilters := TList<TQueryDateFilter>.Create;
    try
        Tokens := ExtractTokens(Query);

        for Token in Tokens do
        begin
            if SameText(Token, 'fav') then
            begin
                Result.OnlyFavorites := True;
                Continue;
            end;

            if SameText(Token, '-fav') then
            begin
                Result.ExcludeFavorites := True;
                Continue;
            end;

            if Token = '-' then
                Continue;

            if (Length(Token) > 1) and (Token[1] = '-') then
            begin
                Value := StripQuotes(Copy(Token, 2, MaxInt));
                if Value <> '' then
                    if Pos('"', Token) > 0 then
                        ExcludedPhrases.Add(Value)
                    else
                        Excluded.Add(Value);
                Continue;
            end;

            // Токен, начинающийся с кавычки: фраза без префикса
            if (Length(Token) > 0) and (Token[1] = '"') then
            begin
                Value := StripQuotes(Token);
                if Value <> '' then
                    BarePhrases.Add(Value);
                Continue;
            end;

            ColonPos := Pos(':', Token);
            IsKnown := False;
            PrefixIndex := -1;
            HadQuote := Pos('"', Token) > 0;

            if ColonPos > 1 then
            begin
                Prefix := LowerCase(Copy(Token, 1, ColonPos - 1));
                for I := Low(KnownPrefixes) to High(KnownPrefixes) do
                    if Prefix = KnownPrefixes[I] then
                    begin
                        IsKnown := True;
                        PrefixIndex := I;
                        Break;
                    end;

                if IsKnown then
                begin
                    Value := StripQuotes(Copy(Token, ColonPos + 1, MaxInt));
                    if Value = '' then
                        Continue;

                    case PrefixIndex of
                        0: Tags.Add(Value);
                        1: Categories.Add(Value);
                        2: if HadQuote then TitlePhrases.Add(Value) else Titles.Add(Value);
                        3: if HadQuote then CommentPhrases.Add(Value) else Comments.Add(Value);
                        4: Languages.Add(Value);
                        5: if HadQuote then ContentPhrases.Add(Value) else Contents.Add(Value);
                        6, 7:
                            begin
                                DF := Default(TQueryDateFilter);
                                if PrefixIndex = 6 then
                                    DF.Field := qdfCreated
                                else
                                    DF.Field := qdfUpdated;
                                DF.Op := qdoEqual;
                                if Copy(Value, 1, 2) = '>=' then
                                begin
                                    DF.Op := qdoGreaterEqual;
                                    Value := Copy(Value, 3, MaxInt);
                                end
                                else if Copy(Value, 1, 2) = '<=' then
                                begin
                                    DF.Op := qdoLessEqual;
                                    Value := Copy(Value, 3, MaxInt);
                                end
                                else if Copy(Value, 1, 1) = '>' then
                                begin
                                    DF.Op := qdoGreater;
                                    Value := Copy(Value, 2, MaxInt);
                                end
                                else if Copy(Value, 1, 1) = '<' then
                                begin
                                    DF.Op := qdoLess;
                                    Value := Copy(Value, 2, MaxInt);
                                end
                                else if Copy(Value, 1, 1) = '=' then
                                    Value := Copy(Value, 2, MaxInt);

                                // Некорректная дата игнорируется целиком
                                if not TryParseDateBounds(Value, DF.EpochFrom, DF.EpochTo) then
                                    Continue;
                                DateFilters.Add(DF);
                            end;
                    end;
                    Continue;
                end;
            end;

            if HadQuote then
            begin
                Value := StripQuotes(Token);
                if Value <> '' then
                    BarePhrases.Add(Value);
            end
            else
                Bare.Add(Token);
        end;

        Result.TagValues := Tags.ToArray;
        Result.CategoryValues := Categories.ToArray;
        Result.TitleValues := Titles.ToArray;
        Result.TitlePhrases := TitlePhrases.ToArray;
        Result.CommentValues := Comments.ToArray;
        Result.CommentPhrases := CommentPhrases.ToArray;
        Result.ContentValues := Contents.ToArray;
        Result.ContentPhrases := ContentPhrases.ToArray;
        Result.LanguageValues := Languages.ToArray;
        Result.ExcludedWords := Excluded.ToArray;
        Result.ExcludedPhrases := ExcludedPhrases.ToArray;
        Result.BareWords := Bare.ToArray;
        Result.BarePhrases := BarePhrases.ToArray;
        Result.DateFilters := DateFilters.ToArray;
    finally
        Tags.Free;
        Categories.Free;
        Titles.Free;
        TitlePhrases.Free;
        Comments.Free;
        CommentPhrases.Free;
        Contents.Free;
        ContentPhrases.Free;
        Languages.Free;
        Excluded.Free;
        ExcludedPhrases.Free;
        Bare.Free;
        BarePhrases.Free;
        DateFilters.Free;
    end;
end;

end.
