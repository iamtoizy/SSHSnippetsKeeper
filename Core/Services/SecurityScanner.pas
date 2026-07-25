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

uses
    UI.StateLoader,
    System.Generics.Collections
    ;

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
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.PrivateSSHKey'),
        '-----BEGIN (RSA|OPENSSH|DSA|EC|PGP)?\s*PRIVATE KEY-----');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.GitHubToken'),
        '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{36}');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.AWSAccessKey'),
        'AKIA[0-9A-Z]{16}');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.GoogleCloudAPIKey'),
        'AIza[0-9A-Za-z\-_]{35}');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.StripeSecretKey'),
        'sk_(live|test)_[0-9a-zA-Z]{24}');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.TelegramBotToken'),
        '[0-9]{9,10}:[a-zA-Z0-9_-]{35}');

    // --- Веб-токены и авторизация ---
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.JWTToken'),
        'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.SlackToken'),
        'xox[baprs]-[0-9a-zA-Z]{10,48}');
    AddPattern(
        TUIStateLoader.GetMessage('Security.DenyReason.BearerToken'),
        'bearer\s+[A-Za-z0-9_\-\.\+]{15,}');

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
                    Reason := TUIStateLoader.GetMessage('Security.DenyReason.HighEntropyString', [Copy(WordStr, 1, 10)]);
                    Exit(True);
                end;
            end;
        end;
    end;
end;

function TSecurityScanner.IsValidSecretCandidate(const S: string): Boolean;
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

        if CharInSet(C, ['0'..'9']) then
            HasDigit := True
        else if CharInSet(C, ['a'..'z', 'A'..'Z']) then
            HasAlpha := True;
    end;

    // 2. Токены и секреты высокой энтропии практически всегда состоят
    // из комбинации букв И цифр (Base64, API keys, Hashes).
    // Это исключает ложные срабатывания на длинные последовательности из одних спецсимволов или слов.
    Result := HasDigit and HasAlpha;
end;

function TSecurityScanner.CalculateEntropy(const S: string): Double;
var
    CharCounts: TDictionary<Char, Integer>;
    C: Char;
    Count: Integer;
    Len: Integer;
    Prob: Double;
begin
    Result := 0.0;
    Len := Length(S);
    if Len = 0 then
        Exit;

    // Честный расчёт энтропии через словарь для всех символов без искажения длины
    CharCounts := TDictionary<Char, Integer>.Create;
    try
        for C in S do
        begin
            if CharCounts.TryGetValue(C, Count) then
                CharCounts[C] := Count + 1
            else
                CharCounts.Add(C, 1);
        end;

        for Count in CharCounts.Values do
        begin
            Prob := Count / Len;
            Result := Result - (Prob * Log2(Prob));
        end;
    finally
        CharCounts.Free;
    end;
end;

end.

