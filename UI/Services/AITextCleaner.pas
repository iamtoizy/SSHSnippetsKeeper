unit AITextCleaner;

interface

uses
    System.SysUtils,
    System.Classes,
    System.JSON,
    System.Net.HttpClient,
    System.Net.URLClient,
    System.RegularExpressions;

type
    TAITextCleaner = class
    private
        class function CleanInlineMarkdown(const Line: string): string;
    public
        class function ExtractPureCode(const RawText: string): string;
    end;

implementation

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
                    // InCodeBlock := False;
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

end.

