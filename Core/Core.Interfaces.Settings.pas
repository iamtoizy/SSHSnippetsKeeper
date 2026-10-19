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
    end;

    TWindowsNode = record
        Name: string;
        WinClass: string;
    end;

    TWindowHelperNode = record
        ActivationDelay: Integer;
        SetFocusDelay: Integer;
        KeyPressInterval: Integer;
    end;

    TAllowedApplicationsItem = record
        ExeName: string;
        Enabled: Boolean;
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
    end;

    // В настройках храним только измененные юзером шорткаты
    TCustomShortCut = record
        ActionName: string;
        ShortCutValue: Integer;
    end;

    TAppSettings = record
        UISettings: TUISettings;
        AllowedWindows: TArrayRecord<TWindowsNode>;
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
