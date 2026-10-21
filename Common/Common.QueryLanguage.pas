unit Common.QueryLanguage;

interface

uses
    System.Generics.Collections,
    System.SysUtils
    ;

type
    TStructuredQuery = record
        TagValues: TArray<string>;
        CategoryValues: TArray<string>;
        TitleValues: TArray<string>;
        CommentValues: TArray<string>;
        ExcludedWords: TArray<string>;
        BareWords: TArray<string>;
        OnlyFavorites: Boolean;
        function HasStructuredFilters: Boolean;
        function IsEmpty: Boolean;
    end;

    TQueryLanguageParser = class
    public
        class function Parse(const Query: string): TStructuredQuery; static;
    end;

implementation

{ TStructuredQuery }

function TStructuredQuery.HasStructuredFilters: Boolean;
begin
    Result := OnlyFavorites
        or (Length(TagValues) > 0)
        or (Length(CategoryValues) > 0)
        or (Length(TitleValues) > 0)
        or (Length(CommentValues) > 0)
        or (Length(ExcludedWords) > 0);
end;

function TStructuredQuery.IsEmpty: Boolean;
begin
    Result := (not HasStructuredFilters) and (Length(BareWords) = 0);
end;

{ TQueryLanguageParser }

class function TQueryLanguageParser.Parse(const Query: string): TStructuredQuery;
const
    KnownPrefixes: array [0..3] of string = ('tag', 'cat', 'title', 'comment');
var
    Tokens: TArray<string>;
    Token, Prefix, Value: string;
    Tags, Categories, Titles, Comments, Excluded, Bare: TList<string>;
    ColonPos, PrefixIndex, I: Integer;
    IsKnown: Boolean;
begin
    Result := Default (TStructuredQuery);
    Tags := TList<string>.Create;
    Categories := TList<string>.Create;
    Titles := TList<string>.Create;
    Comments := TList<string>.Create;
    Excluded := TList<string>.Create;
    Bare := TList<string>.Create;
    try
        Tokens := Query.Split([' ', #9, #13, #10], TStringSplitOptions.ExcludeEmpty);

        for Token in Tokens do
        begin
            if SameText(Token, 'fav') then
            begin
                Result.OnlyFavorites := True;
                Continue;
            end;

            if Token = '-' then
                Continue;

            if (Length(Token) > 1) and (Token[1] = '-') then
            begin
                Value := Copy(Token, 2, MaxInt);
                if Value <> '' then
                    Excluded.Add(Value);
                Continue;
            end;

            ColonPos := Pos(':', Token);
            IsKnown := False;
            PrefixIndex := -1;

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
                    Value := Copy(Token, ColonPos + 1, MaxInt);
                    if Value <> '' then
                        case PrefixIndex of
                            0: Tags.Add(Value);
                            1: Categories.Add(Value);
                            2: Titles.Add(Value);
                            3: Comments.Add(Value);
                        end;
                    Continue;
                end;
            end;

            Bare.Add(Token);
        end;

        Result.TagValues := Tags.ToArray;
        Result.CategoryValues := Categories.ToArray;
        Result.TitleValues := Titles.ToArray;
        Result.CommentValues := Comments.ToArray;
        Result.ExcludedWords := Excluded.ToArray;
        Result.BareWords := Bare.ToArray;
    finally
        Tags.Free;
        Categories.Free;
        Titles.Free;
        Comments.Free;
        Excluded.Free;
        Bare.Free;
    end;
end;

end.
