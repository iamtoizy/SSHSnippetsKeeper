unit Core.Interfaces.Tools;

interface

uses
    System.Classes
    ;

type
    // Структура для хранения найденного в логах таймстемпа
    TEpochMatch = record
        RawText: string;     // Сама строка (например, '1698245312')
        FormatName: string;  // Название распознанного формата
        UnixSeconds: Int64;  // Нормализованные секунды
        LineIdx: Integer;    // Строка (1-based, идеально для SynEdit)
        CharIdx: Integer;    // Позиция символа в строке (1-based)
        PosLength: Integer;  // Длина таймстемпа
    end;

    IEpochService = interface
        ['{395A784D-32ED-4C3E-A395-22BE4A89D2C2}']
        // Умный парсинг (поддерживает секунды, миллисекунды и извлечение из текста)
        function ParseToUnixSeconds(const Input: string; out UnixSeconds: Int64): Boolean;

        // Конвертация Unix -> DateTime
        function UnixToLocal(const UnixSeconds: Int64): TDateTime;
        function UnixToUTC(const UnixSeconds: Int64): TDateTime;

        // Конвертация DateTime -> Unix
        function LocalToUnix(const LocalTime: TDateTime): Int64;
        function UTCToUnix(const UTCTime: TDateTime): Int64;

        // Форматирование
        function FormatISO8601(const ADateTime: TDateTime): string;
        function GetRelativeTimeHumanized(const ADateTime: TDateTime): string;
        function ExtractAllTimestamps(const Lines: TStrings): TArray<TEpochMatch>;
    end;

    // Настройки для визуального конструктора Cron
    TCronSettings = record
        MinuteMode: (cmEveryMinute, cmIntervalMinute, cmCustomMinute);
        MinuteInterval: Integer; // Для */N
        MinuteCustom: string;    // Ручной ввод "0,15,30,45"

        HourMode: (cmEveryHour, cmIntervalHour, cmCustomHour);
        HourInterval: Integer;   // Для */N
        HourCustom: string;      // Ручной ввод "2,4"

        DayOfMonthMode: (cmEveryDay, cmCustomDayOfMonth);
        DayOfMonthCustom: string;

        MonthMode: (cmEveryMonth, cmCustomMonth);
        MonthCustom: string;

        DayOfWeekMode: (cmEveryDayOfWeek, cmWorkDays, cmWeekends, cmCustomDayOfWeek);
        DayOfWeekCustom: string;
    end;

    ICronService = interface
        ['{B1FE59DC-482B-4C01-9C73-02E6DF3F9E59}']
        // Преобразует строку cron в правильный русский текст с учетом склонений
        function ExpressionToHumanText(const Expression: string): string;
        // Проверяет валидность структуры cron (5 компонентов)
        function ValidateExpression(const Expression: string; out ErrorMsg: string): Boolean;
    end;

    ILocalAIService = interface
        ['{78EEB8FB-9550-46CB-A7B8-3692B2510474}']
        function LoadModel(const GgufPath: string): Boolean;
        function IsModelLoaded: Boolean;

        // Главный метод: отправляет промпт и возвращает ответ
        function Ask(const SystemPrompt, UserPrompt: string): string;

        // Проверяет, живой ли вообще интерпретатор
        function IsPythonAvailable: Boolean;

        // Проверяет, установлен ли модуль
        function IsLlamaModuleInstalled: Boolean;

        // Выполняет установку пакета
        function InstallLlamaModule(out Log: string): Boolean;
    end;

implementation

end.
