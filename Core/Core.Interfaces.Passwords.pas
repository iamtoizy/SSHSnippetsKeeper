unit Core.Interfaces.Passwords;

interface

type
    TPasswordPreset = (
        // Базовые
        wpStrictAlphaNumeric, // Только a-z, A-Z, 0-9
        wpPinCode,            // Только цифры (для пин-кодов и простых локов)
        wpHexToken,           // Шестнадцатеричный токен (a-f, 0-9) - для WPA, ключей шифрования

        // Инфраструктурные
        wpBashSafe,           // Безопасно для терминала (без $, !, `, кавычек, слешей)
        wpDockerEnvSafe,      // Безопасно для .env (без #, =, пробелов, кавычек, не с дефиса)
        wpUrlSafe,            // Безопасно для URL (без &, ?, =, %, /, +, пробелов)

        // Специфичные для БД / Систем
        wpBitrixDb,           // Буквы, цифры, и строго определенные знаки (!?()@#$-+=_)
        wpOracleSafe,         // Специфика Oracle: ДОЛЖЕН начинаться с буквы, только _ $ #
        wpActiveDirectory,    // Строго удовлетворяет сложности AD (мин 1 заглавная, 1 строчная, 1 цифра, 1 спец)

        // Человекочитаемые
        wpNoLookAlikes,       // Без похожих символов: (I, l, 1, O, 0) - чтобы диктовать по телефону / читать с экрана

        // НОВЫЕ ШАБЛОНЫ
        wpMacAddress,         // MAC-адрес (XX:XX:XX:XX:XX:XX)
        wpUUIDv4,             // UUID v4
        wpBase64Key,          // Base64 Ключ
        wpWebStandard,        // Стандартный пароль для сайтов (A-Z, a-z, 0-9, !@#$%*?)
        wpCustom              // Кастомный режим (KeePass-like)
    );

    // Настройки для кастомного режима
    TCustomPasswordSettings = record
        UseLower: Boolean;
        UseUpper: Boolean;
        UseNumbers: Boolean;
        UseSymbols: Boolean;
        IncludeChars: string; // Символы, которые ОБЯЗАТЕЛЬНО должны быть в пароле
        ExcludeChars: string; // Символы, которых точно НЕ ДОЛЖНО быть
    end;

    // DTO для истории генераций
    TPasswordHistoryItem = record
        Password: string;
        PresetName: string;
        Entropy: Double;
        CreatedAt: TDateTime;
    end;

    IPasswordService = interface
        ['{C5F1AD9B-21B6-4B42-9267-6C2FF69DA6B6}']
        // Генерирует пароль по выбранному шаблону. Принимает флаг UniqueChars
        function GeneratePassword(Preset: TPasswordPreset; Length: Integer; UniqueChars: Boolean): string;
        function GetPresetDescription(Preset: TPasswordPreset): string;
        function GetPoolSize(Preset: TPasswordPreset): Integer;
        // Расчет размера пула для кастомного режима
        function GetCustomPoolSize(const Settings: TCustomPasswordSettings): Integer;
        function CalculateEntropy(Length, PoolSize: Integer): Double;
        // Методы для истории
        procedure AddToHistory(const Password: string; Preset: TPasswordPreset; PassLen: Integer);
        function GetHistory: TArray<TPasswordHistoryItem>;
        procedure ClearHistory;
        // Генерация по кастомным правилам
        function GenerateCustomPassword(const Settings: TCustomPasswordSettings; Length: Integer; UniqueChars: Boolean): string;
        // Перегруженный метод для истории, чтобы он принимал строку описания напрямую
        procedure AddToHistoryCustom(const Password, CustomDescription: string; PassLen: Integer; Entropy: Double);
    end;

implementation

end.
