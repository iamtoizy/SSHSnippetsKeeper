unit UI.Services.AITextCleaner;

interface

uses
    System.SysUtils
    ;

type
    TAITextCleaner = class
    private
        class function CleanInlineMarkdown(const Line: string): string;
        class function StripWrappingQuotes(const S: string): string;
    public
        class function ExtractPureCode(const RawText: string): string;
        class function ExtractOneLine(const RawText: string;
            AMaxLength: Integer): string;
        class function ExtractTagSuggestions(const RawText: string;
            AMaxTags, AMaxTagLen: Integer): TArray<string>;
    end;

implementation

uses
    System.Classes,
    System.Generics.Collections,
    System.RegularExpressions
    ;

{ TAITextCleaner }

class function TAITextCleaner.CleanInlineMarkdown(const Line: string): string;
begin
    Result := Line;
    if Result.IsEmpty then
        Exit;

    // 1. Удаляем жирный текст и курсив: **текст** или __текст__ -> текст
    Result := TRegEx.Replace(Result, '(\*\*|__)(.*?)\1', '$2');

    // 2. Удаляем обычный курсив: *текст* или _текст_ -> текст
    // Используем границы слов [^|\s], чтобы случайно не порезать пути вроде /var/log/ или переменные_с_подчеркиванием
    Result := TRegEx.Replace(Result, '(\*|_)(.*?)\1', '$2');

    // 3. Удаляем инлайн-блоки кода: `команда` -> команда
    Result := TRegEx.Replace(Result, '`(.*?)`', '$1');

    // 4. Удаляем ссылки Markdown: [Google](https://google.com) -> Google
    Result := TRegEx.Replace(Result, '\[(.*?)\]\(.*?\)', '$1');
end;

class function TAITextCleaner.ExtractPureCode(const RawText: string): string;
var
    Lines: TStringList;
    CodeLines: TStringList;
    I: Integer;
    InCodeBlock: Boolean;
    CurrentLine: string;
begin
    Result := Trim(RawText);
    if Result.IsEmpty then
        Exit;

    Lines := TStringList.Create;
    CodeLines := TStringList.Create;
    try
        Lines.Text := RawText;
        InCodeBlock := False;

        for I := 0 to Lines.Count - 1 do
        begin
            CurrentLine := Trim(Lines[I]);

            // Проверяем маркер начала/конца блока кода Markdown
            if CurrentLine.StartsWith('```') then
            begin
                if InCodeBlock then
                begin
                    Break; // Основной блок кода собран, игнорируем всё, что после него
                end
                else
                begin
                    InCodeBlock := True;
                    Continue; // Пропускаем строку с маркером открытия (```bash)
                end;
            end;

          // Если мы внутри блока кода или если нейросеть вообще не использовала маркеры ```
            if InCodeBlock then
            begin
            // Очищаем саму строку от возможного инлайн-мусора (жирный, курсив и т.д.)
                CodeLines.Add(CleanInlineMarkdown(Lines[I]));
            end;
        end;

        // Фаллбэк: Если нейросеть вообще проигнорировала маркеры ``` и выдала просто текст
        if CodeLines.Count > 0 then
            Result := Trim(CodeLines.Text)
        else
        begin
          // Построчно чистим весь текст от инлайн разметки
            for I := 0 to Lines.Count - 1 do
                Lines[I] := CleanInlineMarkdown(Lines[I]);
            Result := Trim(Lines.Text);
        end;

    finally
        CodeLines.Free;
        Lines.Free;
    end;
end;

class function TAITextCleaner.StripWrappingQuotes(const S: string): string;
begin
    Result := Trim(S);
    while Length(Result) >= 2 do
        if ((Result[1] = '"') and (Result[Length(Result)] = '"')) or
            ((Result[1] = '''') and (Result[Length(Result)] = '''')) or
            ((Result[1] = '`') and (Result[Length(Result)] = '`')) or
            ((Result[1] = '«') and (Result[Length(Result)] = '»')) then
            Result := Trim(Copy(Result, 2, Length(Result) - 2))
        else
            Break;
end;

class function TAITextCleaner.ExtractOneLine(const RawText: string;
    AMaxLength: Integer): string;
var
    Lines: TStringList;
    I: Integer;
begin
    Result := '';
    Lines := TStringList.Create;
    try
        Lines.Text := RawText;
        for I := 0 to Lines.Count - 1 do
            if Trim(Lines[I]) <> '' then
            begin
                Result := CleanInlineMarkdown(Trim(Lines[I]));
                Break;
            end;
    finally
        Lines.Free;
    end;

    Result := StripWrappingQuotes(TRegEx.Replace(Result, '\s+', ' ').Trim);
    if (AMaxLength > 0) and (Length(Result) > AMaxLength) then
        Result := Copy(Result, 1, AMaxLength);
end;

class function TAITextCleaner.ExtractTagSuggestions(const RawText: string;
    AMaxTags, AMaxTagLen: Integer): TArray<string>;
var
    Normalized: string;
    Parts: TArray<string>;
    Part, CleanPart: string;
    Tags: TList<string>;
    I: Integer;
    Known: Boolean;
begin
    Result := [];
    if Trim(RawText).IsEmpty or (AMaxTags <= 0) then
        Exit;

    Normalized := StringReplace(RawText, ';', #10, [rfReplaceAll]);
    Normalized := StringReplace(Normalized, ',', #10, [rfReplaceAll]);
    Parts := Normalized.Split([#10, #13]);

    Tags := TList<string>.Create;
    try
        for Part in Parts do
        begin
            CleanPart := StripWrappingQuotes(TRegEx.Replace(
                CleanInlineMarkdown(Trim(Part)), '\s+', ' '));
            if CleanPart.IsEmpty then
                Continue;
            if (AMaxTagLen > 0) and (Length(CleanPart) > AMaxTagLen) then
                Continue;

            Known := False;
            for I := 0 to Tags.Count - 1 do
                if SameText(Tags[I], CleanPart) then
                begin
                    Known := True;
                    Break;
                end;
            if Known then
                Continue;

            Tags.Add(CleanPart);
            if Tags.Count >= AMaxTags then
                Break;
        end;
        Result := Tags.ToArray;
    finally
        Tags.Free;
    end;
end;

end.

