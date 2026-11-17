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
        FTemplatePath: string;

        function GetSettingsPath: string;
        function GetAutocompletePath: string;

        // Одноразовая миграция: bash.autocomplete.json -> autocomplete.json
        procedure MigrateLegacyAutocomplete;

        // Внутренние методы инициализации дефолтов
        procedure ApplyDefaults;

        // Копирует settings.template.json в settings.json, если файла настроек нет
        function EnsureSettingsFromTemplate(const APath: string): Boolean;

        // Сохраняет битый settings.json как .corrupt для диагностики
        procedure BackupCorruptSettings(const APath: string);

        // Пробует поднять конфиг из шаблона в память (без записи на диск)
        function TryLoadSettingsFromTemplate: Boolean;

        // Отбрасывает битые элементы AllowedApplications/AISettings, клампит числа
        procedure SanitizeSettings(var ASettings: TAppSettings);

        function GetSettings: TAppSettings;
        procedure SetSettings(const Value: TAppSettings);
        function GetCurrentLanguage: string;
        procedure SetCurrentLanguage(const Value: string);
    public
        constructor Create;
        destructor Destroy; override;

        procedure Load;
        procedure Save;

        property CurrentLanguage: string read GetCurrentLanguage write SetCurrentLanguage;

        // Путь к шаблону настроек. По умолчанию ResolvePath('settings.template.json');
        // в тестах задаётся явно, чтобы не зависеть от расположения Assets\ExeData
        property TemplatePath: string read FTemplatePath write FTemplatePath;
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

// Недавние базы: путь (нормализованный) в начало списка без дублей,
// длина ограничена RECENT_DATABASES_LIMIT; :memory: и пустые игнорируются
procedure AddRecentDatabase(var Settings: TAppSettings; const ADatabaseFile: string);

// Удаление пути из недавних вместе с профилем шифрования этой базы
procedure RemoveRecentDatabase(var Settings: TAppSettings; const ADatabaseFile: string);

// Удаление всех недоступных баз: из недавних и из профилей, вместе с
// их профилями шифрования; возвращает число удалённых записей
function RemoveMissingDatabasePaths(var Settings: TAppSettings): Integer;

// Все известные пути баз: недавние первыми, затем пути профилей,
// не попавшие в недавние; без дублей, в нормализованном виде
function GetAllDatabasePaths(const Settings: TAppSettings): TArray<string>;

implementation

uses
    ArrayHelper,
    Common.Helpers,
    Common.RegexSafety,
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

// XORSHIFT-раунд детерминированной энтропии. Вынесен в отдельную функцию,
// чтобы смена {$Q} была локализована в одном маленьком блоке, а не в теле
// BuildSecretEntropy. Пара {$IFOPT}/{$DEFINE}/{$IFDEF} восстанавливает
// исходное состояние Q (включая случай, когда Q- задан снаружи).
procedure FillEntropyXorShift(var ARaw: TBytes);
var
    X: UInt32;
    I: Integer;
begin
    // {$Q-} обязателен: xorshift намеренно заворачивается по модулю 2^32,
    // иначе Debug-конфиг с DCC_IntegerOverflowCheck поднимал бы EIntOverflow.
    // Флаг SSK_ENTROPY_Q_RESTORE восстанавливает исходное состояние Q
    // (включая случай, когда Q был выключен снаружи), а не навязывает {$Q+}.
{$IFOPT Q+}
{$DEFINE SSK_ENTROPY_Q_RESTORE}
{$Q-}
{$ENDIF}
    X := $9E3779B9;
    for I := 0 to High(ARaw) do
    begin
        X := X xor (X shl 13);
        X := X xor (X shr 17);
        X := X xor (X shl 5);
        X := X + $85EBCA6B + UInt32(I) * $C2B2AE3D;
        ARaw[I] := Byte(X shr ((I and 3) shl 3));
    end;
{$IFDEF SSK_ENTROPY_Q_RESTORE}
{$UNDEF SSK_ENTROPY_Q_RESTORE}
{$Q+}
{$ENDIF}
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
begin
    SetLength(Raw, 64);
    try
        FillEntropyXorShift(Raw);
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

procedure AddRecentDatabase(var Settings: TAppSettings; const ADatabaseFile: string);
var
    Path: string;
    I, Existing: Integer;
begin
    Path := NormalizeDbProfilePath(ADatabaseFile);
    if Path = '' then
        Exit;

    // Dedupe: повторное открытие поднимает базу наверх списка
    Existing := Settings.RecentDatabases.IndexOf(Path);
    if Existing >= 0 then
        Settings.RecentDatabases.Delete(Existing);
    Settings.RecentDatabases.Insert(0, Path);

    // Обрезка хвоста до лимита
    for I := Settings.RecentDatabases.Count - 1 downto RECENT_DATABASES_LIMIT do
        Settings.RecentDatabases.Delete(I);
end;

procedure RemoveRecentDatabase(var Settings: TAppSettings; const ADatabaseFile: string);
var
    Idx: Integer;
begin
    Idx := Settings.RecentDatabases.IndexOf(NormalizeDbProfilePath(ADatabaseFile));
    if Idx >= 0 then
        Settings.RecentDatabases.Delete(Idx);
    DeleteDbProfile(Settings, ADatabaseFile);
end;

function RemoveMissingDatabasePaths(var Settings: TAppSettings): Integer;
var
    Paths: TArray<string>;
    I: Integer;
begin
    Result := 0;
    // Обратный обход: пути уникальны и нормализованы, RemoveRecentDatabase
    // снимает и запись недавних, и профиль шифрования
    Paths := GetAllDatabasePaths(Settings);
    for I := High(Paths) downto 0 do
        if not TFile.Exists(Paths[I]) then
        begin
            RemoveRecentDatabase(Settings, Paths[I]);
            Inc(Result);
        end;
end;

function GetAllDatabasePaths(const Settings: TAppSettings): TArray<string>;
var
    Paths: TArrayRecord<string>;
    I: Integer;
    Path: string;
begin
    Paths := Settings.RecentDatabases;
    // Пути профилей, не попавшие в недавние (шифрование снято до
    // появления списка недавних и т.п.), дописываем в хвост
    for I := 0 to High(Settings.DbProfiles.Items) do
    begin
        Path := Settings.DbProfiles.Items[I].Path;
        if (Path <> '') and (Paths.IndexOf(Path) < 0) then
            Paths.Add(Path);
    end;
    Result := Paths.Items;
end;

const
    // Единый источник значений дефолтов настроек. Безусловное заполнение
    // (ApplyDefaults) и восстановление отсутствующего после DSON.fromJson
    // (Load) ссылаются на одни константы, чтобы значения не разъезжались
    // при правках. Guard-условия у блоков разные по замыму: ApplyDefaults
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
    DEFAULT_AUTOEXPORT_INTERVAL_MINUTES = 5;
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
    // Шаблон ищем рядом с exe, затем в Assets\ExeData (dev-сборка)
    FTemplatePath := ResolvePath('settings.template.json');
    ApplyDefaults; // Скалярные дефолты; массивы приходят из settings.json/шаблона
end;

destructor TSettingsManager.Destroy;
begin
    inherited;
end;

function TSettingsManager.GetSettingsPath: string;
begin
    Result := ResolvePath('settings.json');
end;

function TSettingsManager.GetAutocompletePath: string;
begin
    Result := ResolvePath('autocomplete.json');
end;

// Одноразовая миграция старого одноязычного файла: его содержимое
// целиком переносится в секцию "bash" нового общего файла,
// после чего старый файл удаляется
procedure TSettingsManager.MigrateLegacyAutocomplete;
var
    NewPath, OldPath, JsonText: string;
    OldRoot, NewRoot, BashSection: TJSONObject;
begin
    NewPath := GetAutocompletePath;
    if TFile.Exists(NewPath) then
        Exit;

    OldPath := ResolvePath('bash.autocomplete.json');
    if not TFile.Exists(OldPath) then
        Exit;

    try
        JsonText := TFile.ReadAllText(OldPath, TEncoding.UTF8);
        OldRoot := TJSONObject.ParseJSONValue(JsonText) as TJSONObject;
        if not Assigned(OldRoot) then
            Exit;

        try
            NewRoot := TJSONObject.Create;
            try
                if not (OldRoot.FindValue('completion') is TJSONObject) then
                    Exit;
                BashSection := TJSONObject.Create;
                BashSection.AddPair('completion',
                    OldRoot.GetValue('completion').Clone as TJSONObject);
                NewRoot.AddPair('version', TJSONNumber.Create(2));
                NewRoot.AddPair('bash', BashSection);
                TFile.WriteAllText(NewPath, NewRoot.ToJSON, TEncoding.UTF8);
            finally
                NewRoot.Free;
            end;
        finally
            OldRoot.Free;
        end;

        TFile.Delete(OldPath);
    except
        on E: Exception do
            LogException('TSettingsManager.MigrateLegacyAutocomplete', E);
    end;
end;

function TSettingsManager.GetCurrentLanguage: string;
begin
    Result := FSettings.CurrentLanguage;
end;

// =============================================================================
// БЛОК ИНИЦИАЛИЗАЦИИ ДЕФОЛТОВ
// =============================================================================

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

    // Периодический экспорт в Vault: включён, раз в 5 минут
    FSettings.AutoExportEnabled := True;
    FSettings.AutoExportIntervalMinutes := DEFAULT_AUTOEXPORT_INTERVAL_MINUTES;
    FSettings.AutoExportDefined := True;

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

    // Массивы AllowedApplications/AISettings намеренно НЕ заполняются:
    // их единственный источник - settings.json или settings.template.json

    // Шифрование БД по умолчанию выключено
    ApplyDbSecurityDefaults(FSettings);
end;

// Копирует шаблон в settings.json, если файла настроек нет.
// Возвращает True, если файл настроек теперь существует.
function TSettingsManager.EnsureSettingsFromTemplate(const APath: string): Boolean;
var
    TemplatePath: string;
begin
    TemplatePath := FTemplatePath;
    if TemplatePath = '' then
        TemplatePath := ResolvePath('settings.template.json');

    if not TFile.Exists(TemplatePath) then
        Exit(False);

    try
        // Копируем без изменений: плейсхолдеры API-ключей не шифруются,
        // форматирование шаблона сохраняется
        TFile.Copy(TemplatePath, APath, True);
        Result := True;
    except
        on E: Exception do
        begin
            LogException('TSettingsManager.EnsureSettingsFromTemplate', E);
            Result := False;
        end;
    end;
end;

// Сохраняет битый файл настроек как .corrupt (не затирая оригинал),
// чтобы пользователь мог разобраться, что именно сломалось
procedure TSettingsManager.BackupCorruptSettings(const APath: string);
var
    CorruptPath: string;
begin
    if not TFile.Exists(APath) then
        Exit;

    CorruptPath := APath + '.corrupt';
    try
        TFile.Copy(APath, CorruptPath, True);
        LogMsg('TSettingsManager.Load: corrupt settings copied to ' + CorruptPath);
    except
        on E: Exception do
            LogException('TSettingsManager.BackupCorruptSettings', E);
    end;
end;

// Пробует поднять конфиг из шаблона в память (без записи на диск):
// используется, когда settings.json битый и его нельзя затирать
function TSettingsManager.TryLoadSettingsFromTemplate: Boolean;
var
    TemplatePath, Json: string;
begin
    TemplatePath := FTemplatePath;
    if TemplatePath = '' then
        TemplatePath := ResolvePath('settings.template.json');

    if not TFile.Exists(TemplatePath) then
        Exit(False);

    try
        Json := TFile.ReadAllText(TemplatePath, TEncoding.UTF8);
        FSettings := DSON.fromJson<TAppSettings>(Json);
        SanitizeSettings(FSettings);
        Result := True;
    except
        on E: Exception do
        begin
            LogException('TSettingsManager.TryLoadSettingsFromTemplate', E);
            Result := False;
        end;
    end;
end;

// Санитизация загруженной конфигурации: битые элементы отбрасываются,
// битые regex сбрасываются в '', числа клампятся. Валидные данные
// сохраняются; о потерях пишем в лог.
procedure TSettingsManager.SanitizeSettings(var ASettings: TAppSettings);
var
    I, J, K, Kept, DroppedApps, DroppedItems, DroppedRules: Integer;
    Classes: TArray<string>;
    ExeName, Pattern: string;
    DenyRule: TGlobalTitleDenyRule;

    function TryCompileRegex(const APattern: string): Boolean;
    var
        Err: string;
    begin
        Result := TRegexSafety.TryCompile(APattern, Err);
        if not Result then
            LogMsg('TSettingsManager.Sanitize: bad regex "' + APattern + '": ' + Err);
    end;
begin
    DroppedApps := 0;
    DroppedItems := 0;
    DroppedRules := 0;

    // AllowedApplications
    Kept := 0;
    for I := 0 to High(ASettings.AllowedApplications.Items) do
    begin
        ExeName := Trim(ASettings.AllowedApplications.Items[I].ExeName);
        if ExeName = '' then
        begin
            Inc(DroppedApps);
            Continue;
        end;
        ASettings.AllowedApplications.Items[I].ExeName := ExeName;

        Pattern := ASettings.AllowedApplications.Items[I].TitleIncludeRegex;
        if (Pattern <> '') and not TryCompileRegex(Pattern) then
            ASettings.AllowedApplications.Items[I].TitleIncludeRegex := '';

        Pattern := ASettings.AllowedApplications.Items[I].TitleExcludeRegex;
        if (Pattern <> '') and not TryCompileRegex(Pattern) then
            ASettings.AllowedApplications.Items[I].TitleExcludeRegex := '';

        // WindowClasses: убираем пустые
        SetLength(Classes, 0);
        for J := 0 to High(ASettings.AllowedApplications.Items[I].WindowClasses) do
            if Trim(ASettings.AllowedApplications.Items[I].WindowClasses[J]) <> '' then
            begin
                SetLength(Classes, Length(Classes) + 1);
                Classes[High(Classes)] := ASettings.AllowedApplications.Items[I].WindowClasses[J];
            end;
        ASettings.AllowedApplications.Items[I].WindowClasses := Classes;

        if Kept <> I then
            ASettings.AllowedApplications.Items[Kept] := ASettings.AllowedApplications.Items[I];
        Inc(Kept);
    end;
    SetLength(ASettings.AllowedApplications.Items, Kept);

    // GlobalTitleDenyRules: пустой или битый Pattern - правило отбрасывается.
    // Молчаливое хранение такого правила опасно: защита выглядит включённой,
    // но не работает
    Kept := 0;
    for I := 0 to High(ASettings.GlobalTitleDenyRules.Items) do
    begin
        DenyRule := ASettings.GlobalTitleDenyRules.Items[I];
        DenyRule.Name := Trim(DenyRule.Name);
        DenyRule.Pattern := Trim(DenyRule.Pattern);

        if (DenyRule.Pattern = '') or not TryCompileRegex(DenyRule.Pattern) then
        begin
            Inc(DroppedRules);
            Continue;
        end;

        if Kept <> I then
            ASettings.GlobalTitleDenyRules.Items[Kept] := DenyRule;
        Inc(Kept);
    end;
    SetLength(ASettings.GlobalTitleDenyRules.Items, Kept);

    // AISettings
    Kept := 0;
    for I := 0 to High(ASettings.AISettings.Items) do
    begin
        if Trim(ASettings.AISettings.Items[I].Name) = '' then
        begin
            Inc(DroppedItems);
            Continue;
        end;
        if Trim(ASettings.AISettings.Items[I].URL) = '' then
            LogMsg('TSettingsManager.Sanitize: AI hub without URL: ' +
                ASettings.AISettings.Items[I].Name);

        K := 0;
        for J := 0 to High(ASettings.AISettings.Items[I].Items.Items) do
        begin
            if Trim(ASettings.AISettings.Items[I].Items.Items[J].Name) = '' then
            begin
                Inc(DroppedItems);
                Continue;
            end;

            if ASettings.AISettings.Items[I].Items.Items[J].Params.MaxOutputTokens <= 0 then
                ASettings.AISettings.Items[I].Items.Items[J].Params.MaxOutputTokens := 1024;

            if ASettings.AISettings.Items[I].Items.Items[J].Params.Temperature < 0 then
                ASettings.AISettings.Items[I].Items.Items[J].Params.Temperature := 0
            else if ASettings.AISettings.Items[I].Items.Items[J].Params.Temperature > 2 then
                ASettings.AISettings.Items[I].Items.Items[J].Params.Temperature := 2;

            if K <> J then
                ASettings.AISettings.Items[I].Items.Items[K] := ASettings.AISettings.Items[I].Items.Items[J];
            Inc(K);
        end;
        SetLength(ASettings.AISettings.Items[I].Items.Items, K);

        if Kept <> I then
            ASettings.AISettings.Items[Kept] := ASettings.AISettings.Items[I];
        Inc(Kept);
    end;
    SetLength(ASettings.AISettings.Items, Kept);

    if (DroppedApps > 0) or (DroppedItems > 0) or (DroppedRules > 0) then
        LogMsg(Format('TSettingsManager.Sanitize: dropped %d app(s), %d AI item(s), %d deny rule(s)',
            [DroppedApps, DroppedItems, DroppedRules]));
end;

// =============================================================================

procedure TSettingsManager.Load;
var
    JsonString: string;
    JsonValue: TJSONValue;
    Path: string;
    I: Integer;
begin
    MigrateLegacyAutocomplete;

    Path := GetSettingsPath;
    if not TFile.Exists(Path) then
    begin
        // Шаблон - единственный источник стартового конфига. Если его нет,
        // остаёмся на скалярных дефолтах и не плодим пустой settings.json.
        if not EnsureSettingsFromTemplate(Path) then
        begin
            LogMsg('TSettingsManager.Load: settings.json and template not found');
            Exit;
        end;
    end;

    try
        JsonString := TFile.ReadAllText(Path, TEncoding.UTF8);

        // TJSONObject.ParseJSONValue возвращает nil на синтаксически битом JSON
        // (исключения System.JSON не бросает). Без этой проверки битый файл молча
        // превращался бы в пустой конфиг вместо .corrupt + подстановки шаблона.
        JsonValue := TJSONObject.ParseJSONValue(JsonString);
        if JsonValue = nil then
            raise Exception.Create('settings.json is not valid JSON');
        JsonValue.Free;

        // DSON.fromJson затирает массивы (делает их длину = 0), если они
        // отсутствуют в загружаемом JSON. Пустой AllowedApplications/AISettings -
        // валидное состояние (пользователь мог удалить все элементы), поэтому
        // дефолты сюда больше не подставляются.
        FSettings := DSON.fromJson<TAppSettings>(JsonString);
        SanitizeSettings(FSettings);

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

        // Узел периодического экспорта: в старом settings.json его нет —
        // восстанавливаем дефолты (экспорт включён, раз в 5 минут)
        if not FSettings.AutoExportDefined then
        begin
            FSettings.AutoExportEnabled := True;
            FSettings.AutoExportIntervalMinutes := DEFAULT_AUTOEXPORT_INTERVAL_MINUTES;
            FSettings.AutoExportDefined := True;
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
        if FSettings.AutoExportIntervalMinutes <= 0 then
            FSettings.AutoExportIntervalMinutes := DEFAULT_AUTOEXPORT_INTERVAL_MINUTES;

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

        // 3. API-ключи остаются DPAPI-блобами: расшифровка только в момент использования
        NormalizeSecretPrefixes(FSettings);

    except
        on E: Exception do
        begin
            // Битый файл не затираем дефолтами: сохраняем копию для
            // диагностики, затем пробуем поднять конфиг из шаблона в памяти.
            LogException('TSettingsManager.Load(settings.json)', E);
            BackupCorruptSettings(Path);
            if not TryLoadSettingsFromTemplate then
            begin
                FSettings := Default(TAppSettings);
                ApplyDefaults;
            end;
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

end.