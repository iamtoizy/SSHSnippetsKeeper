unit SecurityScanner;

interface

uses
    System.SysUtils,
    System.RegularExpressions
    ;

type
    // Два уровня сканирования:
    // scanStrict  – отчёт аудита: старая токенизация, допускает ложные
    //               срабатывания (лучше лишний раз показать, чем пропустить);
    // scanTolerant – run-time (запуск/сохранение): не отвлекает пользователя.
    TSecurityScanMode = (scanTolerant, scanStrict);

    // Найденный чувствительный фрагмент: позиция нужна для визуализации
    // (красное подчёркивание в редакторе сниппета)
    TSecretRange = record
        StartOffset: Integer; // 0-based от начала текста
        Length: Integer;
        Reason: string;
    end;

    ISecurityScanner = interface
        ['{4BE7DF73-F059-4F22-B05D-330D07B6E655}']
        function HasSensitiveData(const Text: string; out Reason: string): Boolean;
        // Все находки с позициями (для подсветки в редакторе). Reason из
        // HasSensitiveData = Reason первого элемента результата: сначала
        // regex-детекторы в порядке добавления, затем энтропия
        function FindSensitiveRanges(const Text: string): TArray<TSecretRange>;
    end;

    TSecretPattern = record
        Name: string;
        Regex: TRegEx;
    end;

    TSecurityScanner = class(TInterfacedObject, ISecurityScanner)
    private
        FPatterns: TArray<TSecretPattern>;
        FMode: TSecurityScanMode;
        procedure InitializePatterns;
        procedure ScanByRegexRanges(const Text: string; var ARanges: TArray<TSecretRange>);
        procedure ScanByEntropyRanges(const Text: string; var ARanges: TArray<TSecretRange>);
        function IsTokenSeparator(C: Char): Boolean;
        function CalculateEntropy(const S: string): Double;
        function IsValidSecretCandidate(const S: string): Boolean;
    public
        constructor Create(AMode: TSecurityScanMode = scanTolerant);
        // Маппинг настройки "Строгая проверка секретов" в режим сканера
        class function ScanModeFromSetting(AStrict: Boolean): TSecurityScanMode; static;
        function HasSensitiveData(const Text: string; out Reason: string): Boolean;
        function FindSensitiveRanges(const Text: string): TArray<TSecretRange>;
    end;

implementation

uses
    System.Math,
    Common.Localization
    ;

{ TSecurityScanner }

constructor TSecurityScanner.Create(AMode: TSecurityScanMode);
begin
    inherited Create;
    FMode := AMode;
    InitializePatterns;
end;

class function TSecurityScanner.ScanModeFromSetting(AStrict: Boolean): TSecurityScanMode;
begin
    if AStrict then
        Result := scanStrict
    else
        Result := scanTolerant;
end;

procedure TSecurityScanner.InitializePatterns;

    procedure AddPattern(const AName, APattern: string);
    var
        Pattern: TSecretPattern;
    begin
        Pattern.Name := AName;
        Pattern.Regex := TRegEx.Create(APattern, [roCompiled, roIgnoreCase]);
        FPatterns := FPatterns + [Pattern];
    end;

begin
    // --- Инфраструктурные ключи ---
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.PrivateSSHKey'),
        '-----BEGIN (RSA|OPENSSH|DSA|EC|PGP)?\s*PRIVATE KEY-----');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.GitHubToken'),
        '\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{36}\b');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.AWSAccessKey'),
        '\bAKIA[0-9A-Z]{16}\b');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.GoogleCloudAPIKey'),
        '\bAIza[0-9A-Za-z\-_]{35}\b');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.StripeSecretKey'),
        '\bsk_(live|test)_[0-9a-zA-Z]{24}\b');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.TelegramBotToken'),
        '\b[0-9]{9,10}:[a-zA-Z0-9_-]{35}\b');

    // --- Веб-токены и авторизация ---
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.JWTToken'),
        '\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.SlackToken'),
        '\bxox[baprs]-[0-9a-zA-Z]{10,48}\b');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.BearerToken'),
        '\bbearer\s+[A-Za-z0-9_\-\.\+]{15,}\b');

    // --- AI-провайдеры: уникальные префиксы дают почти ноль ложных ---
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.AIToken'),
        '\bsk-(ant(-api\d+)?|proj|svcacct)-[A-Za-z0-9_\-]{20,}\b');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.AIToken'),
        '\bsk-[A-Za-z0-9]{48}\b');

    // --- Сервисы разработки: уникальные префиксы ---
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.DevPlatformToken'),
        '\bgithub_pat_[A-Za-z0-9_]{20,}\b');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.DevPlatformToken'),
        '\bglpat-[A-Za-z0-9_\-]{20,}\b');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.DevPlatformToken'),
        '\bnpm_[A-Za-z0-9]{36}\b');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.DevPlatformToken'),
        '\bpypi-[A-Za-z0-9_\-]{40,}\b');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.DevPlatformToken'),
        '\bdop_v1_[a-f0-9]{64}\b');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.DevPlatformToken'),
        '\bhf_[A-Za-z0-9]{30,}\b');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.DevPlatformToken'),
        '\bSG\.[A-Za-z0-9_\-]{16,}\.[A-Za-z0-9_\-]{16,}\b');

    // --- Пароли и строки подключения ---
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.URLConnectionString'),
        '(https?|ftp|postgres|mysql|mongodb(\+srv)?):\/\/[^\s:@]+:[^\s:@]+@[^\s\/]+');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.ExplicitPasswordKey'),
        '(password|passwd|secret|api[_-]?key|token|auth)\s*[:=]\s*[''"]?[A-Za-z0-9$_\-\.\+]{8,}[''"]?');

    // --- Криптография (которую не ловит энтропия из-за малого алфавита) ---
    // Ловит 32-64 символьные HEX-строки, но игнорирует стандартные UUID с дефисами (8-4-4-4-12)
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.HashKey'),
        '\b([A-Fa-f0-9]{32}|[A-Fa-f0-9]{40}|[A-Fa-f0-9]{64})\b');
end;

function TSecurityScanner.HasSensitiveData(const Text: string; out Reason: string): Boolean;
var
    Ranges: TArray<TSecretRange>;
begin
    Ranges := FindSensitiveRanges(Text);
    Result := Length(Ranges) > 0;
    if Result then
        Reason := Ranges[0].Reason
    else
        Reason := '';
end;

function TSecurityScanner.FindSensitiveRanges(const Text: string): TArray<TSecretRange>;
begin
    Result := [];

    if Trim(Text).IsEmpty then
        Exit;

    // 1. Точные и быстрые регулярные выражения (в порядке приоритета)
    ScanByRegexRanges(Text, Result);

    // 2. Аномально случайные строки (хэши, закодированные пароли)
    ScanByEntropyRanges(Text, Result);
end;

procedure TSecurityScanner.ScanByRegexRanges(const Text: string; var ARanges: TArray<TSecretRange>);
var
    Pattern: TSecretPattern;
    M: TMatch;
    Range: TSecretRange;
begin
    for Pattern in FPatterns do
        for M in Pattern.Regex.Matches(Text) do
        begin
            Range := Default(TSecretRange);
            Range.StartOffset := M.Index - 1;
            Range.Length := M.Length;
            Range.Reason := Pattern.Name;
            ARanges := ARanges + [Range];
        end;
end;

function TSecurityScanner.IsTokenSeparator(C: Char): Boolean;
begin
    if FMode = scanStrict then
        // Строгий режим (отчёт аудита): классическая токенизация по пробелам
        // и базовой пунктуации; спецсимволы кода остаются в токене, поэтому
        // ложные срабатывания возможны – здесь это осознанный компромисс.
        Result := CharInSet(C, [' ', #13, #10, #9, '=', ':', '"', ''''])
    else
        // Терпимый режим (run-time): пунктуация кода – тоже разделитель: иначе
        // склеенный вызов вида ROUND(SUM(data_length+index_length)/1024/1024,2)
        // образует один длинный токен с высокой энтропией и даёт ложное
        // срабатывание. Символы алфавита кодирования (+ / = . _ -) разделителями
        // не являются, чтобы не разрывать настоящие секреты (Base64, JWT, ключи).
        Result := CharInSet(C, [' ', #13, #10, #9, '=', ':', '"', '''',
            '(', ')', ',', ';', '<', '>', '[', ']', '{', '}',
            '|', '&', '%', '!', '?', '#', '~', '^', '@', '*']);
end;

procedure TSecurityScanner.ScanByEntropyRanges(const Text: string; var ARanges: TArray<TSecretRange>);
var
    I, TokenStart, TokenLen: Integer;
    Token: string;
    Entropy: Double;
    Range: TSecretRange;
begin
    // Токенизация с трекингом офсетов: старый Text.Split позиции терял
    TokenStart := -1;

    for I := 1 to Length(Text) + 1 do
    begin
        if I <= Length(Text) then
        begin
            if not IsTokenSeparator(Text[I]) then
            begin
                if TokenStart < 0 then
                    TokenStart := I - 1;
                Continue;
            end;
        end;

        // Разделитель (или конец текста) - закрываем накопленный токен
        if TokenStart >= 0 then
        begin
            TokenLen := (I - 1) - TokenStart;
            if TokenLen >= 16 then
            begin
                // Пароли/хэши обычно длиннее 16 символов
                Token := Copy(Text, TokenStart + 1, TokenLen);
                if IsValidSecretCandidate(Token) then
                begin
                    Entropy := CalculateEntropy(Token);

                    // Энтропия > 4.5 характерна для Base64 и сложных
                    // сгенерированных строк. Превью 4 символа: длиннее -
                    // утечка куска настоящего секрета в текст статуса
                    if Entropy > 4.5 then
                    begin
                        Range := Default(TSecretRange);
                        Range.StartOffset := TokenStart;
                        Range.Length := TokenLen;
                        Range.Reason := TUIStateLoader.GetMessage(
                            'Security.DenyReason.HighEntropyString', [Copy(Token, 1, 4)]);
                        ARanges := ARanges + [Range];
                    end;
                end;
            end;

            TokenStart := -1;
        end;
    end;
end;

function TSecurityScanner.IsValidSecretCandidate(const S: string): Boolean;
const
    // Алфавит настоящих секретов (Base64, JWT, hex, API-ключи).
    // Всё, что выходит за него ($, скобки, % и т.п.), – код или переменная.
    AllowedSecretChars = ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '+', '/', '=', '.'];
var
    C: Char;
    HasDigit, HasAlpha: Boolean;
begin
    HasDigit := False;
    HasAlpha := False;

    for C in S do
    begin
        // 1. Если в слове есть кириллица или не-ASCII символы (Ord > 127) —
        // это точно человеческий текст/комментарий, а не ключ/хэш/токен.
        if Ord(C) > 127 then
            Exit(False);

        // 2. Проверка чистоты состава: настоящий секрет состоит только
        // из букв, цифр и символов алфавита кодирования ($, скобки, % и т.п.
        // выдают код или переменную). Только в терпимом режиме: строгий
        // сканер аудита сознательно допускает срабатывания на спецсимволах.
        if (FMode = scanTolerant) and (not CharInSet(C, AllowedSecretChars)) then
            Exit(False);

        if CharInSet(C, ['0'..'9']) then
            HasDigit := True
        else if CharInSet(C, ['a'..'z', 'A'..'Z']) then
            HasAlpha := True;
    end;

    // 3. Токены и секреты высокой энтропии практически всегда состоят
    // из комбинации букв И цифр (Base64, API keys, Hashes).
    // Это исключает ложные срабатывания на длинные последовательности из одних спецсимволов или слов.
    Result := HasDigit and HasAlpha;
end;

function TSecurityScanner.CalculateEntropy(const S: string): Double;
var
    CharCounts: array[0..255] of Integer;
    C: Char;
    Count, Len, I: Integer;
    Prob: Double;
begin
    Result := 0.0;
    Len := Length(S);
    if Len = 0 then
        Exit;

    for I := 0 to 255 do
        CharCounts[I] := 0;

    // Вызов гарантирован только для ASCII-строк (IsValidSecretCandidate отсекает Ord > 127)
    for C in S do
    begin
        if Ord(C) > 255 then Continue;
        Inc(CharCounts[Ord(C)]);
    end;

    for I := 0 to 255 do
    begin
        Count := CharCounts[I];
        if Count > 0 then
        begin
            Prob := Count / Len;
            Result := Result - (Prob * Log2(Prob));
        end;
    end;
end;

end.

