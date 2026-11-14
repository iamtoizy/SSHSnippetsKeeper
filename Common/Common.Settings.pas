unit Common.Settings;

interface

uses
    Core.Interfaces.Settings, Core.Interfaces.Automation,
    System.Classes, System.SysUtils
    ;

const
    PLACEHOLDER_API_KEY = 'Paste-your-API-key-here';

type
    // Реализация менеджера
    TSettingsManager = class(TInterfacedObject, ISettingsManager)
    private
        FSettings: TAppSettings;
        FBashAutocomplete: TStringList;

        function GetSettingsPath: string;
        function GetBashPath: string;

        // Внутренние методы инициализации дефолтов
        procedure ApplyDefaults;
        procedure InitDefaultAllowedApplications;
        procedure InitDefaultAISettings;

        function GetSettings: TAppSettings;
        procedure SetSettings(const Value: TAppSettings);
        function GetBashAutocomplete: TStringList;
        function GetCurrentLanguage: string;
        procedure SetCurrentLanguage(const Value: string);
    public
        constructor Create;
        destructor Destroy; override;

        procedure Load;
        procedure Save;

        property CurrentLanguage: string read GetCurrentLanguage write SetCurrentLanguage;
    end;

function ProtectSecret(const Value: string): string;
function UnprotectSecretToBytes(const Value: string): TBytes;
function IsProtectedSecret(const Value: string): Boolean;
procedure WipeSecretBytes(var ABytes: TBytes);
procedure ClearUnrememberedDbKey(var Settings: TAppSettings);
procedure PinDbKey(var Settings: TAppSettings; const AKey: string;
    AForceRemember: Boolean);

// Нормализованный ключ профиля: ExpandFileName + lowercase.
// '' для :memory: и пустых путей - такие базы без профилей
function NormalizeDbProfilePath(const ADatabaseFile: string): string;

// Индекс профиля базы в Settings.DbProfiles (-1 если профиля нет)
function FindDbProfileIndex(const Settings: TAppSettings;
    const ADatabaseFile: string): Integer;

// Профиль базы; для отсутствующего - дефолтный DPAPI-профиль без ключа
function GetDbProfile(const Settings: TAppSettings;
    const ADatabaseFile: string): TDbSecurityProfile;

// Вставка или обновление профиля по полю Path
procedure SaveDbProfile(var Settings: TAppSettings;
    const AProfile: TDbSecurityProfile);

// Удаление профиля базы (например, при снятии шифрования с файла)
procedure DeleteDbProfile(var Settings: TAppSettings; const ADatabaseFile: string);

// Закрепление фактического ключа открытой базы в её профиле; семантика
// как у PinDbKey, но запись адресуется путём файла и создаётся при нужде
procedure PinDbKeyTo(var Settings: TAppSettings; const ADatabaseFile: string;
    const AKey: string; AForceRemember: Boolean);

implementation

uses
    Common.Helpers,
    JSONSerializer,
    System.Generics.Collections,
    System.Hash,
    System.NetEncoding,
    System.IOUtils,
    System.JSON,
    Winapi.Windows
    ;

const
    SECRET_PREFIX = 'dpapi:';
    SECRET_PREFIX_OLD = 'dpapi2:';
    CRYPTPROTECT_UI_FORBIDDEN = $1;

type
    PDataBlob = ^TDataBlob;
    TDataBlob = record
        cbData: DWORD;
        pbData: PByte;
    end;

function CryptProtectData(pDataIn: PDataBlob; szDataDescr: LPCWSTR; pOptionalEntropy: Pointer; pvReserved: Pointer; pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall; external 'crypt32' name 'CryptProtectData';
function CryptUnprotectData(pDataIn: PDataBlob; ppszDataDescr: PLPWSTR; pOptionalEntropy: Pointer; pvReserved: Pointer; pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall; external 'crypt32' name 'CryptUnprotectData';

procedure WipeSecretBytes(var ABytes: TBytes);
begin
    if Length(ABytes) > 0 then
        FillChar(ABytes[0], Length(ABytes), 0);
    ABytes := nil;
end;

// Детерминированная энтропия DPAPI. Это КОНСТАНТА приложения, а НЕ секрет:
// она выводится из бинарника. Модель угроз: CryptProtectData привязывает
// данные к пользователю Windows, энтропия дополнительно - к приложению,
// поэтому скопированный settings.json не расшифровывается на другой машине
// или под другим пользователем. От процессов того же пользователя защиты
// нет - иначе приложение само не смогло бы читать ключи
function BuildSecretEntropy: TBytes;
var
    Raw: TBytes;
    Hasher: THashSHA2;
    X: UInt32;
    I: Integer;
begin
    SetLength(Raw, 64);
    try
{$IFOPT Q+}
{$DEFINE ENTROPY_Q_RESTORE}
{$Q-}
{$ENDIF}
        X := $9E3779B9;
        for I := 0 to High(Raw) do
        begin
            X := X xor (X shl 13);
            X := X xor (X shr 17);
            X := X xor (X shl 5);
            X := X + $85EBCA6B + UInt32(I) * $C2B2AE3D;
            Raw[I] := Byte(X shr ((I and 3) shl 3));
        end;
{$IFDEF ENTROPY_Q_RESTORE}
{$UNDEF ENTROPY_Q_RESTORE}
{$Q+}
{$ENDIF}
        Hasher := THashSHA2.Create(SHA256);
        Hasher.Update(Raw);
        Result := Hasher.HashAsBytes;
    finally
        WipeSecretBytes(Raw);
    end;
end;

function IsProtectedSecret(const Value: string): Boolean;
begin
    Result := Value.StartsWith(SECRET_PREFIX, True);
end;

function ProtectSecret(const Value: string): string;
var
    InBlob, OutBlob, EntropyBlob: TDataBlob;
    RawBytes, Entropy: TBytes;
begin
    Result := Value;
    if Value.IsEmpty or IsProtectedSecret(Value) then Exit;

    Entropy := BuildSecretEntropy;
    try
        InBlob.cbData := Length(Value) * SizeOf(Char);
        InBlob.pbData := PByte(PChar(Value));
        EntropyBlob.cbData := Length(Entropy);
        EntropyBlob.pbData := @Entropy[0];

        // Сбой DPAPI - не повод писать открытый текст на диск, падаем громко
        if not CryptProtectData(@InBlob, nil, @EntropyBlob, nil, nil, CRYPTPROTECT_UI_FORBIDDEN, @OutBlob) then
            raise Exception.Create(
                'CryptProtectData failed - refusing to store the secret as plain text');

        try
            SetLength(RawBytes, OutBlob.cbData);
            if OutBlob.cbData > 0 then
                Move(OutBlob.pbData^, RawBytes[0], OutBlob.cbData);
            Result := SECRET_PREFIX + System.NetEncoding.TNetEncoding.Base64.EncodeBytesToString(RawBytes);
            Result := Result.Replace(#13, '').Replace(#10, '');
        finally
            LocalFree(HLOCAL(OutBlob.pbData));
        end;
    finally
        WipeSecretBytes(Entropy);
    end;
end;

function UnprotectSecretToBytes(const Value: string): TBytes;
var
    InBlob, OutBlob, EntropyBlob: TDataBlob;
    RawBytes, Plain16, Entropy: TBytes;
begin
    Result := nil;
    if not IsProtectedSecret(Value) then
        Exit(TEncoding.UTF8.GetBytes(Value));

    RawBytes := System.NetEncoding.TNetEncoding.Base64.DecodeStringToBytes(Value.Substring(Length(SECRET_PREFIX)));
    if Length(RawBytes) = 0 then Exit;

    InBlob.cbData := Length(RawBytes);
    InBlob.pbData := @RawBytes[0];

    Plain16 := nil;
    Entropy := BuildSecretEntropy;
    try
        EntropyBlob.cbData := Length(Entropy);
        EntropyBlob.pbData := @Entropy[0];

        if not CryptUnprotectData(@InBlob, nil, @EntropyBlob, nil, nil, CRYPTPROTECT_UI_FORBIDDEN, @OutBlob) then Exit;

        try
            SetLength(Plain16, OutBlob.cbData);
            if OutBlob.cbData > 0 then
                Move(OutBlob.pbData^, Plain16[0], OutBlob.cbData);
            Result := TEncoding.Convert(TEncoding.Unicode, TEncoding.UTF8, Plain16);
        finally
            LocalFree(HLOCAL(OutBlob.pbData));
        end;
    finally
        WipeSecretBytes(Entropy);
        WipeSecretBytes(Plain16);
    end;
end;

procedure EncryptAIKeys(var Settings: TAppSettings);
var
    HubIdx, KeyIdx: Integer;
begin
    for HubIdx := 0 to High(Settings.AISettings.Items) do
        for KeyIdx := 0 to High(Settings.AISettings.Items[HubIdx].Items.Items) do
            if Settings.AISettings.Items[HubIdx].Items.Items[KeyIdx].APIKey <> PLACEHOLDER_API_KEY then
                Settings.AISettings.Items[HubIdx].Items.Items[KeyIdx].APIKey :=
                    ProtectSecret(Settings.AISettings.Items[HubIdx].Items.Items[KeyIdx].APIKey);
end;

procedure NormalizeSecretPrefixes(var Settings: TAppSettings);
var
    HubIdx, KeyIdx: Integer;
    Key: string;
begin
    for HubIdx := 0 to High(Settings.AISettings.Items) do
        for KeyIdx := 0 to High(Settings.AISettings.Items[HubIdx].Items.Items) do
        begin
            Key := Settings.AISettings.Items[HubIdx].Items.Items[KeyIdx].APIKey;
            if Key.StartsWith(SECRET_PREFIX_OLD, True) then
                Settings.AISettings.Items[HubIdx].Items.Items[KeyIdx].APIKey :=
                    SECRET_PREFIX + Key.Substring(Length(SECRET_PREFIX_OLD));
        end;
end;

// Дефолты узла Db: без шифрования (DB_ENCRYPTION_NONE / DB_KEYMODE_DPAPI).
// Используется и при первичной инициализации, и при загрузке старого
// settings.json без узла Db
procedure ApplyDbSecurityDefaults(var Settings: TAppSettings);
begin
    Settings.Db.Encryption := DB_ENCRYPTION_NONE;
    Settings.Db.KeyMode := DB_KEYMODE_DPAPI;
    Settings.Db.Key := '';
    Settings.Db.Salt := '';
    Settings.Db.RememberKey := False;
    Settings.Db.FirstRunPromptDone := False;
    Settings.Db.DbDefined := True;
end;

procedure ClearUnrememberedDbKey(var Settings: TAppSettings);
var
    I: Integer;
begin
    // Инвариант passphrase: без «запомнить» производный ключ не хранится
    // нигде, включая копию настроек в памяти
    if (Settings.Db.KeyMode = DB_KEYMODE_PASSPHRASE) and
        (not Settings.Db.RememberKey) then
        Settings.Db.Key := '';

    // Тот же инвариант для профилей отдельных баз
    for I := 0 to High(Settings.DbProfiles.Items) do
        if (Settings.DbProfiles.Items[I].KeyMode = DB_KEYMODE_PASSPHRASE) and
            (not Settings.DbProfiles.Items[I].RememberKey) then
            Settings.DbProfiles.Items[I].Key := '';
end;

// Закрепление фактического ключа открытой базы в настройках: passphrase
// хранит ключ только при включённом запоминании (AForceRemember - явное
// «запомнить сейчас»), DPAPI - всегда, с перепривязкой к этой машине.
// Флаг шифрования подводится к факту: файл уже зашифрован
procedure PinDbKey(var Settings: TAppSettings; const AKey: string;
    AForceRemember: Boolean);
begin
    Settings.Db.DbDefined := True;
    Settings.Db.Encryption := DB_ENCRYPTION_AES256;
    if Settings.Db.KeyMode = DB_KEYMODE_PASSPHRASE then
    begin
        if AForceRemember or Settings.Db.RememberKey then
        begin
            Settings.Db.RememberKey := True;
            Settings.Db.Key := AKey;
        end;
    end
    else
    begin
        Settings.Db.KeyMode := DB_KEYMODE_DPAPI;
        Settings.Db.Salt := '';
        Settings.Db.RememberKey := True;
        Settings.Db.Key := AKey;
    end;
end;

function NormalizeDbProfilePath(const ADatabaseFile: string): string;
begin
    Result := '';
    if ADatabaseFile.IsEmpty or SameText(ADatabaseFile, ':memory:') then
        Exit;
    // lowercase: один профиль на файл независимо от регистра букв в пути
    Result := LowerCase(ExpandFileName(ADatabaseFile));
end;

function FindDbProfileIndex(const Settings: TAppSettings;
    const ADatabaseFile: string): Integer;
var
    Path: string;
    I: Integer;
begin
    Result := -1;
    Path := NormalizeDbProfilePath(ADatabaseFile);
    if Path = '' then
        Exit;
    for I := 0 to High(Settings.DbProfiles.Items) do
        if Settings.DbProfiles.Items[I].Path = Path then
            Exit(I);
end;

function GetDbProfile(const Settings: TAppSettings;
    const ADatabaseFile: string): TDbSecurityProfile;
var
    Idx: Integer;
begin
    // Для базы без профиля - дефолтный DPAPI-профиль без ключа: открытие
    // и создание работают так же, как раньше с пустым узлом Db. Path
    // заполняется сразу - правки дефолта можно сохранять как есть
    Result := Default(TDbSecurityProfile);
    Result.KeyMode := DB_KEYMODE_DPAPI;
    Result.Path := NormalizeDbProfilePath(ADatabaseFile);
    Idx := FindDbProfileIndex(Settings, ADatabaseFile);
    if Idx >= 0 then
        Result := Settings.DbProfiles.Items[Idx];
end;

procedure SaveDbProfile(var Settings: TAppSettings;
    const AProfile: TDbSecurityProfile);
var
    Idx: Integer;
begin
    Idx := FindDbProfileIndex(Settings, AProfile.Path);
    if Idx < 0 then
        Settings.DbProfiles.Add(AProfile)
    else
        Settings.DbProfiles.Items[Idx] := AProfile;
end;

procedure DeleteDbProfile(var Settings: TAppSettings; const ADatabaseFile: string);
var
    Idx: Integer;
begin
    Idx := FindDbProfileIndex(Settings, ADatabaseFile);
    if Idx >= 0 then
        Settings.DbProfiles.Delete(Idx);
end;

procedure PinDbKeyTo(var Settings: TAppSettings; const ADatabaseFile: string;
    const AKey: string; AForceRemember: Boolean);
var
    Idx: Integer;
begin
    Idx := FindDbProfileIndex(Settings, ADatabaseFile);
    if Idx < 0 then
    begin
        // Базы без файла на диске (:memory:) профилей не получают
        if NormalizeDbProfilePath(ADatabaseFile) = '' then
            Exit;
        Idx := Settings.DbProfiles.Add(Default(TDbSecurityProfile));
        Settings.DbProfiles.Items[Idx].Path := NormalizeDbProfilePath(ADatabaseFile);
    end;

    // Семантика как у PinDbKey: passphrase хранит ключ только при
    // включённом запоминании, DPAPI - всегда
    if Settings.DbProfiles.Items[Idx].KeyMode = DB_KEYMODE_PASSPHRASE then
    begin
        if AForceRemember or Settings.DbProfiles.Items[Idx].RememberKey then
        begin
            Settings.DbProfiles.Items[Idx].RememberKey := True;
            Settings.DbProfiles.Items[Idx].Key := AKey;
        end;
    end
    else
    begin
        Settings.DbProfiles.Items[Idx].KeyMode := DB_KEYMODE_DPAPI;
        Settings.DbProfiles.Items[Idx].Salt := '';
        Settings.DbProfiles.Items[Idx].RememberKey := True;
        Settings.DbProfiles.Items[Idx].Key := AKey;
    end;
end;

procedure EncryptDbKey(var Settings: TAppSettings);
var
    I: Integer;
begin
    ClearUnrememberedDbKey(Settings);
    if Settings.Db.Key <> '' then
        Settings.Db.Key := ProtectSecret(Settings.Db.Key);
    for I := 0 to High(Settings.DbProfiles.Items) do
        if Settings.DbProfiles.Items[I].Key <> '' then
            Settings.DbProfiles.Items[I].Key :=
                ProtectSecret(Settings.DbProfiles.Items[I].Key);
end;

const
    // Системный промпт для всех моделей ИИ
    AI_SYSTEM_PROMPT = 'Твоя роль - инструмент выполнения кода. ОТВЕЧАЙ ТОЛЬКО ЧИСТЫМ КОДОМ. ' +
                       'ЗАПРЕЩЕНО: писать объяснения, вступления, заключения, markdown-теги ```bash, ```delphi или другие. ' +
                       'ВЫДАВАТЬ ТОЛЬКО СИМВОЛЫ КОДА. Если пользователь просит команду - выдай только эту команду.' +
                       'ПРИМЕР ТВОЕГО ОТВЕТА (всегда в таком формате): ls -la /var/www/html, systemctl restart nginx ' +
                       'Никакого текста вокруг, только код. Команда должна умещаться в одну строку, если пользователь не попросил иначе.';

    // Единый источник значений дефолтов настроек. Безусловное заполнение
    // (ApplyDefaults) и восстановление отсутствующего после DSON.fromJson
    // (Load) ссылаются на одни константы, чтобы значения не разъезжались
    // при правках. Guard-условия у блоков разные по замыслу: ApplyDefaults
    // перезаписывает всё, Load подставляет только отсутствующее/битое.
    DEFAULT_HOVER_DELAY = 1500;
    DEFAULT_FADE_DURATION = 500;
    DEFAULT_ACTIVATION_DELAY = 100;
    DEFAULT_SETFOCUS_DELAY = 50;
    DEFAULT_KEYPRESS_INTERVAL = 10;
    DEFAULT_LANGUAGE = 'ru';
    // Маска видимости колонок списка сниппетов: все 3 бита
    DEFAULT_SNIPPET_COLUMNS_MASK = 7;
    DEFAULT_BACKUP_INTERVAL_SECONDS = 86400;
    DEFAULT_BACKUP_KEEP = 3;
    DEFAULT_SCAN_INTERVAL_MINUTES = 30;
    DEFAULT_QS_MODIFIERS = MOD_ALT;
    DEFAULT_QS_KEY = Ord('Q');
    DEFAULT_PG_MODIFIERS = MOD_CONTROL or MOD_ALT;
    DEFAULT_PG_KEY = Ord('G');
    DEFAULT_RL_MODIFIERS = MOD_ALT;
    DEFAULT_RL_KEY = Ord('V');
    DEFAULT_FS_MODIFIERS = MOD_ALT;
    DEFAULT_FS_KEY = Ord('1');

{ TSettingsManager }

constructor TSettingsManager.Create;
begin
    inherited Create;
    FBashAutocomplete := TStringList.Create;
    ApplyDefaults; // Сразу ставим дефолты на случай, если файла еще нет
end;

destructor TSettingsManager.Destroy;
begin
    FBashAutocomplete.Free;
    inherited;
end;

function TSettingsManager.GetSettingsPath: string;
begin
    Result := ResolvePath('settings.json');
end;

function TSettingsManager.GetBashPath: string;
begin
    Result := ResolvePath('bash.autocomplete.json');
end;

function TSettingsManager.GetCurrentLanguage: string;
begin
    Result := FSettings.CurrentLanguage;
end;

// =============================================================================
// БЛОК ИНИЦИАЛИЗАЦИИ ДЕФОЛТОВ
// =============================================================================

procedure TSettingsManager.InitDefaultAllowedApplications;
begin
    SetLength(FSettings.AllowedApplications.Items, 6);

    // Классы окон из дефолтных профилей заведомо известны только для
    // части терминалов; пустой список = разрешены все окна процесса
    FSettings.AllowedApplications.Items[0].ExeName := 'mobaxterm.exe';
    FSettings.AllowedApplications.Items[0].Enabled := True;
    FSettings.AllowedApplications.Items[0].WindowClasses := ['CMoTTY'];

    FSettings.AllowedApplications.Items[1].ExeName := 'xshell.exe';
    FSettings.AllowedApplications.Items[1].Enabled := True;
    FSettings.AllowedApplications.Items[1].WindowClasses := ['AfxFrameOrView140u'];

    FSettings.AllowedApplications.Items[2].ExeName := 'putty.exe';
    FSettings.AllowedApplications.Items[2].Enabled := True;
    FSettings.AllowedApplications.Items[2].WindowClasses := ['PuTTY'];

    FSettings.AllowedApplications.Items[3].ExeName := 'tabby.exe';
    FSettings.AllowedApplications.Items[3].Enabled := True;

    FSettings.AllowedApplications.Items[4].ExeName := 'kitty.exe';
    FSettings.AllowedApplications.Items[4].Enabled := True;

    FSettings.AllowedApplications.Items[5].ExeName := 'securecrt.exe';
    FSettings.AllowedApplications.Items[5].Enabled := True;
end;

procedure TSettingsManager.InitDefaultAISettings;
begin
    SetLength(FSettings.AISettings.Items, 2);

    // Провайдер 1: Yandex AIStudio [Agents]
    FSettings.AISettings.Items[0].Name := 'Yandex AIStudio [Agents]';
    FSettings.AISettings.Items[0].URL := 'https://aistudio.yandex.ru/platform/folders/';
    FSettings.AISettings.Items[0].Comment := 'Платформа для создания AI-решений и агентов';
    SetLength(FSettings.AISettings.Items[0].Items.Items, 1);

    with FSettings.AISettings.Items[0].Items.Items[0] do
    begin
        Name := 'Qwen3.6-35B (1024 токена)';
        APIKey := PLACEHOLDER_API_KEY;
        Folder := 'Paste-your-folder-id-here';
        Model := '';
        Agent := 'Paste-your-agent-id-here';
        Params.Temperature := 0.3;
        Params.MaxOutputTokens := 1024;
        Params.Content := AI_SYSTEM_PROMPT;
        Params.ReasoningEffort := 'none';
    end;

    // Провайдер 2: Yandex AIStudio [LLM]
    FSettings.AISettings.Items[1].Name := 'Yandex AIStudio [LLM]';
    FSettings.AISettings.Items[1].URL := 'https://aistudio.yandex.ru/platform/folders/';
    FSettings.AISettings.Items[1].Comment := 'Платформа для создания AI-решений и агентов';
    SetLength(FSettings.AISettings.Items[1].Items.Items, 4);

    with FSettings.AISettings.Items[1].Items.Items[0] do
    begin
        Name := 'YandexGPT 5 Lite (1024 токена)';
        APIKey := PLACEHOLDER_API_KEY;
        Folder := 'Paste-your-folder-id-here';
        Model := 'yandexgpt-5-lite/latest';
        Agent := 'Paste-your-agent-id-here';
        Params.Temperature := 0.3;
        Params.MaxOutputTokens := 1024;
        Params.Content := AI_SYSTEM_PROMPT;
        Params.ReasoningEffort := 'none';
    end;

    with FSettings.AISettings.Items[1].Items.Items[1] do
    begin
        Name := 'YandexGPT 5 Lite (32к токенов)';
        APIKey := PLACEHOLDER_API_KEY;
        Folder := 'Paste-your-folder-id-here';
        Model := 'yandexgpt-5-lite/latest';
        Agent := 'Paste-your-agent-id-here';
        Params.Temperature := 0.3;
        Params.MaxOutputTokens := 32768;
        Params.Content := AI_SYSTEM_PROMPT;
        Params.ReasoningEffort := 'none';
    end;

    with FSettings.AISettings.Items[1].Items.Items[2] do
    begin
        Name := 'DeepSeek V4 Flash (1024 токена)';
        APIKey := PLACEHOLDER_API_KEY;
        Folder := 'Paste-your-folder-id-here';
        Model := 'deepseek-v4-flash/latest';
        Agent := 'Paste-your-agent-id-here';
        Params.Temperature := 0.3;
        Params.MaxOutputTokens := 1024;
        Params.Content := AI_SYSTEM_PROMPT;
        Params.ReasoningEffort := 'none';
    end;

    with FSettings.AISettings.Items[1].Items.Items[3] do
    begin
        Name := 'AliceAI LLM Flash (1024 токена)';
        APIKey := PLACEHOLDER_API_KEY;
        Folder := 'Paste-your-folder-id-here';
        Model := 'aliceai-llm-flash/latest';
        Agent := 'Paste-your-agent-id-here';
        Params.Temperature := 0.3;
        Params.MaxOutputTokens := 1024;
        Params.Content := AI_SYSTEM_PROMPT;
        Params.ReasoningEffort := 'none';
    end;
end;

procedure TSettingsManager.ApplyDefaults;
begin
    // Заполняем критичные скалярные значения
    FSettings.WindowHelper.ActivationDelay := DEFAULT_ACTIVATION_DELAY;
    FSettings.WindowHelper.SetFocusDelay := DEFAULT_SETFOCUS_DELAY;
    FSettings.WindowHelper.KeyPressInterval := DEFAULT_KEYPRESS_INTERVAL;
    FSettings.UISettings.Help.HelpButton.HoverDelay := DEFAULT_HOVER_DELAY;
    FSettings.UISettings.Help.HelpButton.FadeDuration := DEFAULT_FADE_DURATION;
    FSettings.CurrentLanguage := DEFAULT_LANGUAGE;

    // Все колонки списка сниппетов видимы по умолчанию
    FSettings.UISettings.SnippetListColumns := DEFAULT_SNIPPET_COLUMNS_MASK;
    FSettings.UISettings.SnippetListColumnsDefined := True;

    // Автобэкап БД: включён, раз в сутки, хранить 3 копии
    FSettings.Backup.Enabled := True;
    FSettings.Backup.IntervalSeconds := DEFAULT_BACKUP_INTERVAL_SECONDS;
    FSettings.Backup.Keep := DEFAULT_BACKUP_KEEP;
    FSettings.BackupDefined := True;

    // Фоновая проверка секретов: включена, раз в полчаса
    FSettings.SecurityBackgroundScanEnabled := True;
    FSettings.SecurityBackgroundScanIntervalMinutes := DEFAULT_SCAN_INTERVAL_MINUTES;
    FSettings.SecurityBackgroundScanDefined := True;

    // Дефолты для глобальных горячих клавиш
    FSettings.Hotkeys.QuickSearch.Modifiers := DEFAULT_QS_MODIFIERS;
    FSettings.Hotkeys.QuickSearch.Key := DEFAULT_QS_KEY;
    FSettings.Hotkeys.QuickSearch.Enabled := True;

    FSettings.Hotkeys.PasswordGen.Modifiers := DEFAULT_PG_MODIFIERS;
    FSettings.Hotkeys.PasswordGen.Key := DEFAULT_PG_KEY;
    FSettings.Hotkeys.PasswordGen.Enabled := True;

    FSettings.Hotkeys.RepeatLast.Modifiers := DEFAULT_RL_MODIFIERS;
    FSettings.Hotkeys.RepeatLast.Key := DEFAULT_RL_KEY;
    FSettings.Hotkeys.RepeatLast.Enabled := True;

    FSettings.Hotkeys.FavoriteSlots.Modifiers := DEFAULT_FS_MODIFIERS;
    FSettings.Hotkeys.FavoriteSlots.Key := DEFAULT_FS_KEY;
    FSettings.Hotkeys.FavoriteSlots.Enabled := True;

    // Инициализируем массивы-справочники
    InitDefaultAllowedApplications;
    InitDefaultAISettings;

    // Шифрование БД по умолчанию выключено
    ApplyDbSecurityDefaults(FSettings);
end;

// =============================================================================

procedure TSettingsManager.Load;
var
    JsonString, Cmd: string;
    Path: string;
    JsonRoot: TJSONObject;
    CompletionObj, CommandsArr: TJSONValue;
    I: Integer;
begin
    Path := GetBashPath;
    if TFile.Exists(Path) then
    try
        JsonString := TFile.ReadAllText(Path, TEncoding.UTF8);
        JsonRoot := TJSONObject.ParseJSONValue(JsonString) as TJSONObject;
        if Assigned(JsonRoot) then
        try
            CompletionObj := JsonRoot.FindValue('completion');
            if CompletionObj is TJSONObject then
            begin
                CommandsArr := TJSONObject(CompletionObj).FindValue('commands');
                if CommandsArr is TJSONArray then
                begin
                    FBashAutocomplete.BeginUpdate;
                    try
                        FBashAutocomplete.Clear;
                        for I := 0 to TJSONArray(CommandsArr).Count - 1 do
                        begin
                            Cmd := Trim(TJSONArray(CommandsArr).Items[I].Value);
                            if Cmd <> '' then
                                FBashAutocomplete.Add(Cmd);
                        end;
                    finally
                        FBashAutocomplete.EndUpdate;
                    end;
                end;
            end;
        finally
            JsonRoot.Free;
        end;
    except
        on E: Exception do
            LogException('TSettingsManager.Load(BashAutocomplete)', E);
    end;

    Path := GetSettingsPath;
    if not TFile.Exists(Path) then
    begin
        Save; // Запишет дефолты в новый файл
        Exit;
    end;

    try
        JsonString := TFile.ReadAllText(Path, TEncoding.UTF8);

        // ВНИМАНИЕ: DSON.fromJson может затереть массивы (сделать их длину = 0),
        // если они отсутствуют в загружаемом JSON.
        FSettings := DSON.fromJson<TAppSettings>(JsonString);

        // --- Восстановление пропавших данных (После загрузки) ---

        // 1. Скалярные настройки UI и поведения
        if FSettings.UISettings.Help.HelpButton.HoverDelay <= 0 then
            FSettings.UISettings.Help.HelpButton.HoverDelay := DEFAULT_HOVER_DELAY;
        if FSettings.UISettings.Help.HelpButton.FadeDuration <= 0 then
            FSettings.UISettings.Help.HelpButton.FadeDuration := DEFAULT_FADE_DURATION;
        if FSettings.WindowHelper.ActivationDelay <= 0 then
            FSettings.WindowHelper.ActivationDelay := DEFAULT_ACTIVATION_DELAY;
        if FSettings.WindowHelper.SetFocusDelay <= 0 then
            FSettings.WindowHelper.SetFocusDelay := DEFAULT_SETFOCUS_DELAY;
        if FSettings.WindowHelper.KeyPressInterval <= 0 then
            FSettings.WindowHelper.KeyPressInterval := DEFAULT_KEYPRESS_INTERVAL;
        if Trim(FSettings.CurrentLanguage) = '' then
            FSettings.CurrentLanguage := DEFAULT_LANGUAGE;

        // Маска видимости колонок списка сниппетов: в старом файле настроек
        // поля нет — считаем все колонки видимыми; маску чистим от лишних битов
        if not FSettings.UISettings.SnippetListColumnsDefined then
            FSettings.UISettings.SnippetListColumns := DEFAULT_SNIPPET_COLUMNS_MASK;
        FSettings.UISettings.SnippetListColumns := FSettings.UISettings.SnippetListColumns and DEFAULT_SNIPPET_COLUMNS_MASK;
        FSettings.UISettings.SnippetListColumnsDefined := True;

        // Узел бэкапа: в старом settings.json его нет — восстанавливаем
        // дефолты (автобэкап до нововведения работал всегда)
        if not FSettings.BackupDefined then
        begin
            FSettings.Backup.Enabled := True;
            FSettings.Backup.IntervalSeconds := DEFAULT_BACKUP_INTERVAL_SECONDS;
            FSettings.Backup.Keep := DEFAULT_BACKUP_KEEP;
            FSettings.BackupDefined := True;
        end;

        // Узел фоновой проверки секретов: в старом settings.json его нет —
        // восстанавливаем дефолты (проверка включена, раз в полчаса)
        if not FSettings.SecurityBackgroundScanDefined then
        begin
            FSettings.SecurityBackgroundScanEnabled := True;
            FSettings.SecurityBackgroundScanIntervalMinutes := DEFAULT_SCAN_INTERVAL_MINUTES;
            FSettings.SecurityBackgroundScanDefined := True;
        end;

        // Узел шифрования БД: в старом settings.json его нет - дефолты
        if not FSettings.Db.DbDefined then
            ApplyDbSecurityDefaults(FSettings);

        // Битые значения режимов не должны ломать открытие БД; Key не
        // трогаем - потребитель сам разбирает dpapi:блоб через
        // UnprotectSecretToBytes (прозрачно пропускает открытый текст)
        if not ((FSettings.Db.Encryption = DB_ENCRYPTION_NONE) or
                (FSettings.Db.Encryption = DB_ENCRYPTION_AES256)) then
            FSettings.Db.Encryption := DB_ENCRYPTION_NONE;
        if not ((FSettings.Db.KeyMode = DB_KEYMODE_DPAPI) or
                (FSettings.Db.KeyMode = DB_KEYMODE_PASSPHRASE)) then
            FSettings.Db.KeyMode := DB_KEYMODE_DPAPI;

        // Битые режимы в профилях не должны ломать открытие баз
        for I := 0 to High(FSettings.DbProfiles.Items) do
            if not ((FSettings.DbProfiles.Items[I].KeyMode = DB_KEYMODE_DPAPI) or
                    (FSettings.DbProfiles.Items[I].KeyMode = DB_KEYMODE_PASSPHRASE)) then
                FSettings.DbProfiles.Items[I].KeyMode := DB_KEYMODE_DPAPI;

        // Тот же инвариант passphrase, что и в EncryptDbKey: затираем
        // устаревший ключ с диска, чтобы стартовый цикл ввода фразы не
        // подхватил ключ от прежней сессии с «запомнить» (глобальный слот
        // и профили отдельных баз)
        ClearUnrememberedDbKey(FSettings);

        // Битые значения не должны отключать бэкап или ротацию
        if FSettings.Backup.IntervalSeconds <= 0 then
            FSettings.Backup.IntervalSeconds := DEFAULT_BACKUP_INTERVAL_SECONDS;
        if FSettings.Backup.Keep <= 0 then
            FSettings.Backup.Keep := DEFAULT_BACKUP_KEEP;
        if FSettings.SecurityBackgroundScanIntervalMinutes <= 0 then
            FSettings.SecurityBackgroundScanIntervalMinutes := DEFAULT_SCAN_INTERVAL_MINUTES;

        // 2. Глобальные горячие клавиши
        if FSettings.Hotkeys.QuickSearch.Key = 0 then
        begin
            FSettings.Hotkeys.QuickSearch.Modifiers := DEFAULT_QS_MODIFIERS;
            FSettings.Hotkeys.QuickSearch.Key := DEFAULT_QS_KEY;
            FSettings.Hotkeys.QuickSearch.Enabled := True;
        end;

        if FSettings.Hotkeys.PasswordGen.Key = 0 then
        begin
            FSettings.Hotkeys.PasswordGen.Modifiers := DEFAULT_PG_MODIFIERS;
            FSettings.Hotkeys.PasswordGen.Key := DEFAULT_PG_KEY;
            FSettings.Hotkeys.PasswordGen.Enabled := True;
        end;

        if FSettings.Hotkeys.RepeatLast.Key = 0 then
        begin
            FSettings.Hotkeys.RepeatLast.Modifiers := DEFAULT_RL_MODIFIERS;
            FSettings.Hotkeys.RepeatLast.Key := DEFAULT_RL_KEY;
            FSettings.Hotkeys.RepeatLast.Enabled := True;
        end;

        if FSettings.Hotkeys.FavoriteSlots.Modifiers = 0 then
        begin
            FSettings.Hotkeys.FavoriteSlots.Modifiers := DEFAULT_FS_MODIFIERS;
            FSettings.Hotkeys.FavoriteSlots.Key := DEFAULT_FS_KEY;
            FSettings.Hotkeys.FavoriteSlots.Enabled := True;
        end;

        // 3. Восстановление списков, если они оказались пустыми
        // Это спасет юзера, если он удалил их из JSON или обновил программу с очень старой версии
        if Length(FSettings.AllowedApplications.Items) = 0 then
            InitDefaultAllowedApplications;

        if Length(FSettings.AISettings.Items) = 0 then
            InitDefaultAISettings;

        // 4. API-ключи остаются DPAPI-блобами: расшифровка только в момент использования
        NormalizeSecretPrefixes(FSettings);

    except
        on E: Exception do
        begin
            // Настройки восстанавливаются к дефолту, но причина сбоя не должна теряться
            LogException('TSettingsManager.Load(settings.json)', E);
            ApplyDefaults;
        end;
    end;
end;

procedure TSettingsManager.Save;
var
    JsonString: string;
    TmpPath: string;
    SafeSettings: TAppSettings;
    Err: DWORD;
begin
    try
        // Шифруем копию настроек: в памяти FSettings остается с открытыми ключами
        SafeSettings := FSettings;
        EncryptAIKeys(SafeSettings);
        EncryptDbKey(SafeSettings);

        JsonString := DSON.toJson<TAppSettings>(SafeSettings);

        // Атомарная замена: целевой файл не исчезает с диска ни на мгновение
        TmpPath := GetSettingsPath + '.tmp';
        TFile.WriteAllText(TmpPath, JsonString, TEncoding.UTF8);
        if not MoveFileEx(PChar(TmpPath), PChar(GetSettingsPath), MOVEFILE_REPLACE_EXISTING) then
        begin
            Err := GetLastError;
            if TFile.Exists(TmpPath) then
                TFile.Delete(TmpPath);
            raise Exception.Create(SysErrorMessage(Err));
        end;
    except
        // Без логирования пользователь молча потерял бы все изменения
        on E: Exception do
            LogException('TSettingsManager.Save', E);
    end;
end;

function TSettingsManager.GetSettings: TAppSettings;
begin
    Result := FSettings;
end;

procedure TSettingsManager.SetCurrentLanguage(const Value: string);
begin
    FSettings.CurrentLanguage := Value;
end;

procedure TSettingsManager.SetSettings(const Value: TAppSettings);
begin
    FSettings := Value;
end;

function TSettingsManager.GetBashAutocomplete: TStringList;
begin
    Result := FBashAutocomplete;
end;

end.
