unit Common.SnippetLanguages;

// Реестр поддерживаемых языков подсветки синтаксиса сниппетов.
// Используется ядром (репозиторий, Markdown import/export) и UI (фабрика
// хайлайтеров), поэтому живёт в Common без зависимостей от SynEdit.

interface

const
    // Автодетект языка запускается только при накопленном существенном изменении:
    // короче порога текст слишком похож на префикс и классификатор шумит
    SNIPPET_DETECT_MIN_TEXT_LENGTH = 40;
    SNIPPET_DETECT_MIN_DELTA = 20;
    SNIPPET_DETECT_DELTA_PERCENT = 10;

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

// Стоит ли пересчитывать язык после правки: True, если текст изменился не меньше
// чем на SNIPPET_DETECT_MIN_DELTA символов или на 10% длины, и текста достаточно
// для уверенного прогноза (SNIPPET_DETECT_MIN_TEXT_LENGTH).
function ShouldRedetectSnippetLanguage(const APreviousText, ACurrentText: string): Boolean;

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

function ShouldRedetectSnippetLanguage(const APreviousText, ACurrentText: string): Boolean;
var
    PrevLen, CurLen, Delta, Threshold: Integer;
begin
    if ACurrentText = APreviousText then
        Exit(False);

    CurLen := Length(Trim(ACurrentText));
    if CurLen < SNIPPET_DETECT_MIN_TEXT_LENGTH then
        Exit(False);

    PrevLen := Length(Trim(APreviousText));
    Threshold := (PrevLen * SNIPPET_DETECT_DELTA_PERCENT) div 100;
    if Threshold < SNIPPET_DETECT_MIN_DELTA then
        Threshold := SNIPPET_DETECT_MIN_DELTA;

    Delta := Abs(CurLen - PrevLen);
    Result := Delta >= Threshold;
end;

function FenceTagForSnippetLanguage(const Value: string): string;
begin
    Result := NormalizeSnippetLanguage(Value);
end;

end.
