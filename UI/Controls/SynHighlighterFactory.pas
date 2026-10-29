unit SynHighlighterFactory;

// Фабрика хайлайтеров по идентификатору языка сниппета.
// Экземпляры создаются с Owner = nil: временем жизни управляет вызывающий код
// (форма пересоздает хайлайтер при смене языка).

interface

uses
    Common.SnippetLanguages,
    SynEditHighlighter
    ;

type
    TSynHighlighterFactory = class
    public
        class function SupportedLanguages: TArray<string>;
        class function DisplayName(const ALanguage: string): string;
        class function CreateHighlighter(const ALanguage: string): TSynCustomHighlighter;
    end;

implementation

uses
    CustomBashSyn,
    SynHighlighterBat,
    SynHighlighterIni,
    SynHighlighterJSON,
    SynHighlighterMarkdown,
    SynHighlighterPowerShell,
    SynHighlighterXML,
    System.SysUtils
    ;

{ TSynHighlighterFactory }

class function TSynHighlighterFactory.SupportedLanguages: TArray<string>;
begin
    Result := SNIPPET_LANGUAGE_IDS;
end;

class function TSynHighlighterFactory.DisplayName(const ALanguage: string): string;
var
    Id: string;
begin
    Id := NormalizeSnippetLanguage(ALanguage);

    if Id = SNIPPET_LANG_BAT then
        Result := 'Batch (cmd)'
    else if Id = SNIPPET_LANG_POWERSHELL then
        Result := 'PowerShell'
    else if Id = SNIPPET_LANG_XML then
        Result := 'XML'
    else if Id = SNIPPET_LANG_JSON then
        Result := 'JSON'
    else if Id = SNIPPET_LANG_INI then
        Result := 'INI'
    else if Id = SNIPPET_LANG_MARKDOWN then
        Result := 'Markdown'
    else if Id = SNIPPET_LANG_PLAINTEXT then
        Result := 'Plain text'
    else
        Result := 'Bash / Shell';
end;

class function TSynHighlighterFactory.CreateHighlighter(const ALanguage: string): TSynCustomHighlighter;
var
    Id: string;
begin
    Id := NormalizeSnippetLanguage(ALanguage);

    if Id = SNIPPET_LANG_BAT then
        Result := TSynBatSyn.Create(nil)
    else if Id = SNIPPET_LANG_POWERSHELL then
        Result := TSynPowerShellSyn.Create(nil)
    else if Id = SNIPPET_LANG_XML then
        Result := TSynXMLSyn.Create(nil)
    else if Id = SNIPPET_LANG_JSON then
        Result := TSynJSONSyn.Create(nil)
    else if Id = SNIPPET_LANG_INI then
        Result := TSynIniSyn.Create(nil)
    else if Id = SNIPPET_LANG_MARKDOWN then
        Result := TSynMarkdownSyn.Create(nil)
    else if Id = SNIPPET_LANG_PLAINTEXT then
        // Подсветки нет: nil = редактор рисует текст одним цветом.
        // Исключение для вызывающего кода — сам факт nil-возврата.
        Result := nil
    else
        Result := TCustomBashSyn.Create(nil);
end;

end.
