unit SecurityScanner;

interface

uses
    System.SysUtils,
    System.RegularExpressions,
    System.Math,
    System.Character;

type
    ISecurityScanner = interface
        ['{4BE7DF73-F059-4F22-B05D-330D07B6E655}']
        function HasSensitiveData(const Text: string; out Reason: string): Boolean;
    end;

    TSecretPattern = record
        Name: string;
        Regex: TRegEx;
    end;

    TSecurityScanner = class(TInterfacedObject, ISecurityScanner)
    private
        FPatterns: TArray<TSecretPattern>;
        procedure InitializePatterns;
        function CalculateEntropy(const S: string): Double;
        function IsValidSecretCandidate(const S: string): Boolean;
        function ScanByRegex(const Text: string; out Reason: string): Boolean;
        function ScanByEntropy(const Text: string; out Reason: string): Boolean;
    public
        constructor Create;
        function HasSensitiveData(const Text: string; out Reason: string): Boolean;
    end;

implementation

{ TSecurityScanner }

constructor TSecurityScanner.Create;
begin
    inherited Create;
    InitializePatterns;
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
    AddPattern('Приватный SSH/RSA ключ', '-----BEGIN (RSA|OPENSSH|DSA|EC|PGP)?\s*PRIVATE KEY-----');
    AddPattern('Токен GitHub', '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{36}');
    AddPattern('Ключ AWS Access Key', 'AKIA[0-9A-Z]{16}');
    AddPattern('Ключ Google Cloud / API', 'AIza[0-9A-Za-z\-_]{35}');
    AddPattern('Секретный ключ Stripe', 'sk_(live|test)_[0-9a-zA-Z]{24}');
    AddPattern('Токен Telegram Bot', '[0-9]{9,10}:[a-zA-Z0-9_-]{35}');

    // --- Веб-токены и авторизация ---
    AddPattern('Токен JWT', 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}');
    AddPattern('Токен Slack', 'xox[baprs]-[0-9a-zA-Z]{10,48}');
    AddPattern('Авторизационный Bearer токен', 'bearer\s+[A-Za-z0-9_\-\.\+]{15,}');

    // --- Пароли и строки подключения ---
    AddPattern('Учетные данные в URL (Connection String)', '(https?|ftp|postgres|mysql|mongodb(\+srv)?):\/\/[^\s:@]+:[^\s:@]+@[^\s\/]+');
    AddPattern('Явное указание пароля/ключа', '(password|passwd|secret|api[_-]?key|token|auth)\s*[:=]\s*[''"]?[A-Za-z0-9$_\-\.\+]{8,}[''"]?');

    // --- Криптография (которую не ловит энтропия из-за малого алфавита) ---
    // Ловит 32-64 символьные HEX-строки, но игнорирует стандартные UUID с дефисами (8-4-4-4-12)
    AddPattern('MD5/SHA хэш или Hex-ключ', '\b([A-Fa-f0-9]{32}|[A-Fa-f0-9]{40}|[A-Fa-f0-9]{64})\b');
end;

function TSecurityScanner.HasSensitiveData(const Text: string; out Reason: string): Boolean;
begin
    Result := False;
    Reason := '';

    if Trim(Text).IsEmpty then
        Exit;

    // 1. Ищем по точным и быстрым регулярным выражениям
    if ScanByRegex(Text, Reason) then
        Exit(True);

    // 2. Ищем аномально случайные строки (хэши, закодированные пароли)
    if ScanByEntropy(Text, Reason) then
        Exit(True);
end;

function TSecurityScanner.ScanByRegex(const Text: string; out Reason: string): Boolean;
var
    Pattern: TSecretPattern;
begin
    for Pattern in FPatterns do
    begin
        if Pattern.Regex.IsMatch(Text) then
        begin
            Reason := Pattern.Name;
            Exit(True);
        end;
    end;
    Result := False;
end;

function TSecurityScanner.ScanByEntropy(const Text: string; out Reason: string): Boolean;
var
    Words: TArray<string>;
    WordStr: string;
    Entropy: Double;
begin
    Result := False;
    Words := Text.Split([' ', #13, #10, #9, '=', ':', '"', '''']);

    for WordStr in Words do
    begin
        // Игнорируем короткие строки. Пароли/хэши обычно длиннее 16 символов.
        if Length(WordStr) >= 16 then
        begin
            // Проверяем, что в слове есть и буквы, и цифры (уменьшает ложные срабатывания на длинных URL)
            if IsValidSecretCandidate(WordStr) then
            begin
                Entropy := CalculateEntropy(WordStr);

                // Энтропия > 4.5 характерна для Base64 и сложных сгенерированных строк
                if Entropy > 4.5 then
                begin
                    Reason := Format('Высокоэнтропийная строка (возможно, хэш или токен): "%s..."', [Copy(WordStr, 1, 10)]);
                    Exit(True);
                end;
            end;
        end;
    end;
end;

function TSecurityScanner.IsValidSecretCandidate(const S: string): Boolean;
begin
    // Секреты (токены, пароли, хэши) крайне редко содержат пробелы.
    // Если в строке есть пробел, скорее всего это обычный текст или SQL-запрос.
    if S.Contains(' ') then
        Exit(False);

    // Дополнительно можно отсечь строки, где нет ни букв, ни цифр
    // (например, кусок ASCII-арта), но для базовой проверки этого достаточно.
    Result := True;
end;

function TSecurityScanner.CalculateEntropy(const S: string): Double;
var
    CharCounts: array[0..255] of Integer; // Массив всего на 1 КБ (256 * 4 байта)
    C: Char;
    Len, ValidLen, I: Integer;
    Prob: Double;
begin
    Result := 0.0;
    Len := Length(S);
    if Len = 0 then
        Exit;

    FillChar(CharCounts, SizeOf(CharCounts), 0);
    ValidLen := 0;

    // Считаем только ASCII-символы, игнорируем кириллицу/юникод при расчете энтропии токенов
    for C in S do
    begin
        if Ord(C) <= 255 then
        begin
            Inc(CharCounts[Ord(C)]);
            Inc(ValidLen);
        end;
    end;

    if ValidLen = 0 then
        Exit;

    for I := 0 to 255 do
    begin
        if CharCounts[I] > 0 then
        begin
            Prob := CharCounts[I] / ValidLen;
            Result := Result - (Prob * Log2(Prob));
        end;
    end;
end;

end.

