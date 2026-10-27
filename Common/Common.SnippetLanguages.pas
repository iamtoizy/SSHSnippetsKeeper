unit Common.SnippetLanguages;

// Реестр поддерживаемых языков подсветки синтаксиса сниппетов.
// Используется ядром (репозиторий, Markdown import/export) и UI (фабрика
// хайлайтеров), поэтому живёт в Common без зависимостей от SynEdit.

interface

const
    SNIPPET_LANG_BASH = 'bash';
    SNIPPET_LANG_BAT = 'bat';
    SNIPPET_LANG_POWERSHELL = 'powershell';
    SNIPPET_LANG_XML = 'xml';
    SNIPPET_LANG_JSON = 'json';
    SNIPPET_LANG_INI = 'ini';
    SNIPPET_LANG_MARKDOWN = 'markdown';

// Канонические идентификаторы в порядке для комбобокса (bash - по умолчанию)
var
    SNIPPET_LANGUAGE_IDS: TArray<string> = [
        SNIPPET_LANG_BASH,
        SNIPPET_LANG_BAT,
        SNIPPET_LANG_POWERSHELL,
        SNIPPET_LANG_XML,
        SNIPPET_LANG_JSON,
        SNIPPET_LANG_INI,
        SNIPPET_LANG_MARKDOWN
    ];

// Приводит значение к каноническому идентификатору; '' и неизвестные
// значения (в т.ч. алиасы) сворачиваются к поддерживаемым языкам.
function NormalizeSnippetLanguage(const Value: string): string;

function IsSupportedSnippetLanguage(const Value: string): Boolean;

// Тег ограждения кода для Markdown (```<tag>); совпадает с каноническим id
function FenceTagForSnippetLanguage(const Value: string): string;

implementation

uses
    Common.Consts,
    System.SysUtils
    ;

function NormalizeSnippetLanguage(const Value: string): string;
var
    L: string;
    Id: string;
begin
    L := LowerCase(Trim(Value));

    if (L = '') or (L = 'sh') or (L = 'shell') or (L = 'zsh') then
        Exit(SNIPPET_LANG_BASH);

    if (L = 'cmd') or (L = 'batch') or (L = 'dos') then
        Exit(SNIPPET_LANG_BAT);

    if (L = 'ps') or (L = 'ps1') or (L = 'pwsh') then
        Exit(SNIPPET_LANG_POWERSHELL);

    if (L = 'cfg') or (L = 'conf') or (L = 'config') then
        Exit(SNIPPET_LANG_INI);

    if (L = 'md') then
        Exit(SNIPPET_LANG_MARKDOWN);

    for Id in SNIPPET_LANGUAGE_IDS do
        if L = Id then
            Exit(L);

    Result := DEFAULT_SNIPPET_LANGUAGE;
end;

function IsSupportedSnippetLanguage(const Value: string): Boolean;
var
    L, Id: string;
begin
    L := LowerCase(Trim(Value));
    for Id in SNIPPET_LANGUAGE_IDS do
        if L = Id then
            Exit(True);
    Result := False;
end;

function FenceTagForSnippetLanguage(const Value: string): string;
begin
    Result := NormalizeSnippetLanguage(Value);
end;

end.
