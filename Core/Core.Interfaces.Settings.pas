unit Core.Interfaces.Settings;

interface

uses
    ArrayHelper,
    System.Classes
    ;

type
    // Domain Models настроек
    THelpButton = record
        HoverDelay: Integer;
        FadeDuration: Integer;
    end;

    THelp = record
        HelpButton: THelpButton;
    end;

    TUISettings = record
        Help: THelp;
        VCLStyle: string;
        // Видимость колонок списка сниппетов (битовая маска):
        // bit0 = «Язык» (Tag 3), bit1 = «Последний запуск» (Tag 2),
        // bit2 = «Последнее изменение» (Tag 4); «Название» (Tag 1) видна всегда
        SnippetListColumns: Integer;
        // Маркер инициализации: False = старый settings.json без маски колонок
        SnippetListColumnsDefined: Boolean;
    end;

    TWindowHelperNode = record
        ActivationDelay: Integer;
        SetFocusDelay: Integer;
        KeyPressInterval: Integer;
    end;

    // Профиль разрешения приложения: exe-имя плюс опциональные фильтры окон.
    // Пустые фильтры = пропускаются любые окна процесса (старое поведение)
    TAllowedApplicationsItem = record
        ExeName: string;
        Enabled: Boolean;
        // Окно разрешено, только если заголовок совпадает с этим regex (пусто = любой)
        TitleIncludeRegex: string;
        // Окно блокируется, если заголовок совпадает с этим regex
        TitleExcludeRegex: string;
        // Классы окон (GetClassName), которые разрешено вводить (пусто = любые)
        WindowClasses: TArray<string>;
    end;

    TAIParams = record
        Temperature: Single;
        MaxOutputTokens: Integer;
        Content: string;
        ReasoningEffort: string;
    end;

    TAIItem = record
        Name: string;
        APIKey: string;
        Folder: string;
        Model: string;
        Agent: string;
        Params: TAIParams;
    end;

    TAIHub = record
        Name: string;
        URL: string;
        Comment: string;
        Items: TArrayRecord<TAIItem>;
    end;

    // Структура предустановок Chmod
    TChmodPreset = record
        Name: string;
        OctalBits: Integer; // Например 755 или 644
        IsDir: Boolean;     // Нужно ли ставить галку "Это директория"
    end;

    // Элемент истории с весом
    THistoryItem = record
        Value: string;
        UseCount: Integer;
    end;

    // Структура предустановок архиватора
    TArchivePreset = record
        Name: string;
        FormatIndex: Integer; // 0=zip, 1=tar.gz, 2=tar.bz2, 3=tar.xz, 4=7z
        ExcludeMask: string;
        MaxCompression: Boolean;
    end;

    // Конфигурация одной горячей клавиши
    THotkeyConfig = record
        Modifiers: Cardinal; // Битмаска Win32 MOD_ALT, MOD_CONTROL, MOD_SHIFT, MOD_WIN
        Key: Cardinal;       // Virtual Key Code (например, VK_Q или Ord('Q'))
        Enabled: Boolean;
    end;

    // Настройки всех глобальных горячих клавиш программы
    THotkeySettings = record
        QuickSearch: THotkeyConfig; // HUD Быстрого поиска (Alt + Q)
        PasswordGen: THotkeyConfig; // Генератор паролей (Ctrl + Alt + G)
        RepeatLast: THotkeyConfig;  // Повтор последнего сниппета (Alt + V)
        FavoriteSlots: THotkeyConfig; // Слоты избранного 1..0: используются Modifiers и Enabled, Key игнорируется
    end;

    // В настройках храним только измененные юзером шорткаты
    TCustomShortCut = record
        ActionName: string;
        ShortCutValue: Integer;
    end;

    // Автобэкап БД при открытии (auto_*.bak рядом с файлом БД)
    TBackupSettings = record
        // Автобэкап включён
        Enabled: Boolean;
        // Минимальный интервал между копиями, секунды (3600 = 1ч, 86400 = сутки)
        IntervalSeconds: Integer;
        // Сколько последних копий хранится (ротация)
        Keep: Integer;
    end;

    TAppSettings = record
        UISettings: TUISettings;
        WindowHelper: TWindowHelperNode;
        AllowedApplications: TArrayRecord<TAllowedApplicationsItem>;
        AISettings: TArrayRecord<TAIHub>;
        CurrentLanguage: string;
        ChmodPresets: TArray<TChmodPreset>;

        // Массивы для истории Chmod
        HistoryUsers: TArray<THistoryItem>;
        HistoryGroups: TArray<THistoryItem>;
        HistoryFiles: TArray<THistoryItem>;

        // Архивация
        ArchivePresets: TArray<TArchivePreset>;
        // История путей архивации
        HistoryArchivePaths: TArray<THistoryItem>; // Для путей (Source)
        HistoryArchiveDests: TArray<THistoryItem>; // Для имен архивов (Dest)

        // Сохранение состояния контролов
        ArchiveLastFormat: Integer;
        ArchiveRelativePath: Boolean;
        ArchiveMaxCompression: Boolean;
        ArchiveSplit: Boolean;
        ArchiveSplitSize: Integer;

        // Глобальные горячие клавиши
        Hotkeys: THotkeySettings;
        CustomShortCuts: TArray<TCustomShortCut>;

        // Синхронизация Markdown
        SyncDirectory: string;
        SyncOnStart: Boolean;
        SyncOnExit: Boolean;

        // Фильтр по тегам: True = сниппет должен иметь все выбранные теги
        TagsMatchAll: Boolean;

        // Резервное копирование БД
        Backup: TBackupSettings;
        // Маркер инициализации: False = старый settings.json без узла Backup
        BackupDefined: Boolean;

        // Окно выбора терминала: True = режим таблицы, False = плитки
        TerminalChooserTableView: Boolean;

        // Окно выбора терминала: True = группировать окна таблицы по процессу
        TerminalChooserGroupByProcess: Boolean;

        // Окно выбора терминала: True = панель предпросмотра развернута
        TerminalChooserPreviewVisible: Boolean;

        // Окно выбора терминала: сохраненная пользователем геометрия (0 = авто)
        TerminalChooserWidth: Integer;
        TerminalChooserHeight: Integer;
        TerminalChooserPreviewHeight: Integer;

        // Сканирование секретов при запуске/сохранении сниппетов:
        // True = строгий режим аудита (больше ложных срабатываний),
        // False = терпимый режим (по умолчанию)
        SecurityScanStrict: Boolean;

        // Периодическая фоновая проверка всех сниппетов сканером:
        // тост при появлении новых находок + подсветка проблемных строк
        SecurityBackgroundScanEnabled: Boolean;
        // Минуты между проверками (типовое значение 30)
        SecurityBackgroundScanIntervalMinutes: Integer;
        // Маркер инициализации: False = старый settings.json без этих полей
        SecurityBackgroundScanDefined: Boolean;
    end;

    // Интерфейс менеджера
    ISettingsManager = interface
        ['{A1B2C3D4-E5F6-47A8-9B0C-1D2E3F4A5B6C}']
        function GetSettings: TAppSettings;
        procedure SetSettings(const Value: TAppSettings);
        function GetCurrentLanguage: string;
        procedure SetCurrentLanguage(const Value: string);
        function GetBashAutocomplete: TStringList;

        procedure Load;
        procedure Save;

        property Data: TAppSettings read GetSettings write SetSettings;
        property BashAutocomplete: TStringList read GetBashAutocomplete;
        property CurrentLanguage: string read GetCurrentLanguage write SetCurrentLanguage;
    end;

implementation

end.
