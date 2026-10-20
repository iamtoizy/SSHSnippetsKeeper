unit Common.Settings;

interface

uses
    Core.Interfaces.Settings, Core.Interfaces.Automation,
    System.Classes
    ;

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

implementation

uses
    Common.Helpers,
    JSONSerializer,
    System.NetEncoding,
    System.IOUtils,
    System.JSON,
    System.SysUtils,
    Winapi.Windows
    ;

const
    SECRET_PREFIX = 'dpapi:';
    CRYPTPROTECT_UI_FORBIDDEN = $1;

type
    PDataBlob = ^TDataBlob;
    TDataBlob = record
        cbData: DWORD;
        pbData: PByte;
    end;

function CryptProtectData(pDataIn: PDataBlob; szDataDescr: LPCWSTR; pOptionalEntropy: Pointer; pvReserved: Pointer; pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall; external 'crypt32' name 'CryptProtectData';
function CryptUnprotectData(pDataIn: PDataBlob; ppszDataDescr: PLPWSTR; pOptionalEntropy: Pointer; pvReserved: Pointer; pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall; external 'crypt32' name 'CryptUnprotectData';

function ProtectSecret(const Value: string): string;
var
    InBlob, OutBlob: TDataBlob;
    RawBytes: TBytes;
begin
    Result := Value;
    if Value.IsEmpty then Exit;

    InBlob.cbData := Length(Value) * SizeOf(Char);
    InBlob.pbData := PByte(PChar(Value));
    if not CryptProtectData(@InBlob, nil, nil, nil, nil, CRYPTPROTECT_UI_FORBIDDEN, @OutBlob) then Exit;

    try
        SetLength(RawBytes, OutBlob.cbData);
        if OutBlob.cbData > 0 then
            Move(OutBlob.pbData^, RawBytes[0], OutBlob.cbData);
        Result := SECRET_PREFIX + System.NetEncoding.TNetEncoding.Base64.EncodeBytesToString(RawBytes);
        Result := Result.Replace(#13, '').Replace(#10, '');
    finally
        LocalFree(HLOCAL(OutBlob.pbData));
    end;
end;

function UnprotectSecret(const Value: string): string;
var
    InBlob, OutBlob: TDataBlob;
    RawBytes: TBytes;
begin
    Result := Value;
    if not Value.StartsWith(SECRET_PREFIX, True) then Exit;

    RawBytes := System.NetEncoding.TNetEncoding.Base64.DecodeStringToBytes(Value.Substring(Length(SECRET_PREFIX)));
    if Length(RawBytes) = 0 then Exit('');

    InBlob.cbData := Length(RawBytes);
    InBlob.pbData := @RawBytes[0];
    if not CryptUnprotectData(@InBlob, nil, nil, nil, nil, CRYPTPROTECT_UI_FORBIDDEN, @OutBlob) then Exit('');

    try
        SetLength(Result, OutBlob.cbData div SizeOf(Char));
        if Length(Result) > 0 then
            Move(OutBlob.pbData^, Pointer(Result)^, Length(Result) * SizeOf(Char));
    finally
        LocalFree(HLOCAL(OutBlob.pbData));
    end;
end;

procedure EncryptAIKeys(var Settings: TAppSettings);
var
    HubIdx, KeyIdx: Integer;
begin
    for HubIdx := 0 to High(Settings.AISettings.Items) do
        for KeyIdx := 0 to High(Settings.AISettings.Items[HubIdx].Items.Items) do
            Settings.AISettings.Items[HubIdx].Items.Items[KeyIdx].APIKey :=
                ProtectSecret(Settings.AISettings.Items[HubIdx].Items.Items[KeyIdx].APIKey);
end;

procedure DecryptAIKeys(var Settings: TAppSettings);
var
    HubIdx, KeyIdx: Integer;
begin
    for HubIdx := 0 to High(Settings.AISettings.Items) do
        for KeyIdx := 0 to High(Settings.AISettings.Items[HubIdx].Items.Items) do
            Settings.AISettings.Items[HubIdx].Items.Items[KeyIdx].APIKey :=
                UnprotectSecret(Settings.AISettings.Items[HubIdx].Items.Items[KeyIdx].APIKey);
end;

const
    // Системный промпт для всех моделей ИИ
    AI_SYSTEM_PROMPT = 'Твоя роль - инструмент выполнения кода. ОТВЕЧАЙ ТОЛЬКО ЧИСТЫМ КОДОМ. ' +
                       'ЗАПРЕЩЕНО: писать объяснения, вступления, заключения, markdown-теги ```bash, ```delphi или другие. ' +
                       'ВЫДАВАЙ ТОЛЬКО СИМВОЛЫ КОДА. Если пользователь просит команду - выдай только эту команду.' +
                       'ПРИМЕР ТВОЕГО ОТВЕТА (всегда в таком формате): ls -la /var/www/html, systemctl restart nginx ' +
                       'Никакого текста вокруг, только код. Команда должна умещаться в одну строку, если пользователь не попросил иначе.';

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
    Result := ResolvePath('bash-autocomplete.txt');
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

    FSettings.AllowedApplications.Items[0].ExeName := 'mobaxterm.exe';
    FSettings.AllowedApplications.Items[0].Enabled := True;

    FSettings.AllowedApplications.Items[1].ExeName := 'xshell.exe';
    FSettings.AllowedApplications.Items[1].Enabled := True;

    FSettings.AllowedApplications.Items[2].ExeName := 'putty.exe';
    FSettings.AllowedApplications.Items[2].Enabled := True;

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
        APIKey := 'Paste-your-API-key-here';
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
        APIKey := 'Paste-your-API-key-here';
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
        APIKey := 'Paste-your-API-key-here';
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
        APIKey := 'Paste-your-API-key-here';
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
        APIKey := 'Paste-your-API-key-here';
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
    FSettings.WindowHelper.ActivationDelay := 100;
    FSettings.WindowHelper.SetFocusDelay := 50;
    FSettings.WindowHelper.KeyPressInterval := 10;
    FSettings.UISettings.Help.HelpButton.HoverDelay := 1500;
    FSettings.UISettings.Help.HelpButton.FadeDuration := 500;
    FSettings.CurrentLanguage := 'ru';

    // Дефолты для глобальных горячих клавиш
    FSettings.Hotkeys.QuickSearch.Modifiers := MOD_ALT;
    FSettings.Hotkeys.QuickSearch.Key := Ord('Q');
    FSettings.Hotkeys.QuickSearch.Enabled := True;

    FSettings.Hotkeys.PasswordGen.Modifiers := MOD_CONTROL or MOD_ALT;
    FSettings.Hotkeys.PasswordGen.Key := Ord('G');
    FSettings.Hotkeys.PasswordGen.Enabled := True;

    FSettings.Hotkeys.RepeatLast.Modifiers := MOD_ALT;
    FSettings.Hotkeys.RepeatLast.Key := Ord('V');
    FSettings.Hotkeys.RepeatLast.Enabled := True;

    FSettings.Hotkeys.FavoriteSlots.Modifiers := MOD_ALT;
    FSettings.Hotkeys.FavoriteSlots.Key := Ord('1');
    FSettings.Hotkeys.FavoriteSlots.Enabled := True;

    // Инициализируем массивы-справочники
    InitDefaultAllowedApplications;
    InitDefaultAISettings;
end;

// =============================================================================

procedure TSettingsManager.Load;
var
    JsonString: string;
    Path: string;
begin
    Path := GetBashPath;
    if TFile.Exists(Path) then
    try
        FBashAutocomplete.LoadFromFile(Path, TEncoding.UTF8);
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
            FSettings.UISettings.Help.HelpButton.HoverDelay := 1500;
        if FSettings.UISettings.Help.HelpButton.FadeDuration <= 0 then
            FSettings.UISettings.Help.HelpButton.FadeDuration := 500;
        if FSettings.WindowHelper.ActivationDelay <= 0 then
            FSettings.WindowHelper.ActivationDelay := 100;
        if FSettings.WindowHelper.SetFocusDelay <= 0 then
            FSettings.WindowHelper.SetFocusDelay := 50;
        if FSettings.WindowHelper.KeyPressInterval <= 0 then
            FSettings.WindowHelper.KeyPressInterval := 10;
        if Trim(FSettings.CurrentLanguage) = '' then
            FSettings.CurrentLanguage := 'ru';

        // 2. Глобальные горячие клавиши
        if FSettings.Hotkeys.QuickSearch.Key = 0 then
        begin
            FSettings.Hotkeys.QuickSearch.Modifiers := MOD_ALT;
            FSettings.Hotkeys.QuickSearch.Key := Ord('Q');
            FSettings.Hotkeys.QuickSearch.Enabled := True;
        end;

        if FSettings.Hotkeys.PasswordGen.Key = 0 then
        begin
            FSettings.Hotkeys.PasswordGen.Modifiers := MOD_CONTROL or MOD_ALT;
            FSettings.Hotkeys.PasswordGen.Key := Ord('G');
            FSettings.Hotkeys.PasswordGen.Enabled := True;
        end;

        if FSettings.Hotkeys.RepeatLast.Key = 0 then
        begin
            FSettings.Hotkeys.RepeatLast.Modifiers := MOD_ALT;
            FSettings.Hotkeys.RepeatLast.Key := Ord('V');
            FSettings.Hotkeys.RepeatLast.Enabled := True;
        end;

        if FSettings.Hotkeys.FavoriteSlots.Modifiers = 0 then
        begin
            FSettings.Hotkeys.FavoriteSlots.Modifiers := MOD_ALT;
            FSettings.Hotkeys.FavoriteSlots.Key := Ord('1');
            FSettings.Hotkeys.FavoriteSlots.Enabled := True;
        end;

        // 3. Восстановление списков, если они оказались пустыми
        // Это спасет юзера, если он удалил их из JSON или обновил программу с очень старой версии
        if Length(FSettings.AllowedApplications.Items) = 0 then
            InitDefaultAllowedApplications;

        if Length(FSettings.AISettings.Items) = 0 then
            InitDefaultAISettings;

        // 4. API-ключи хранятся на диске в виде DPAPI, в памяти работаем с открытым текстом
        DecryptAIKeys(FSettings);

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
begin
    try
        // Шифруем копию настроек: в памяти FSettings остается с открытыми ключами
        SafeSettings := FSettings;
        EncryptAIKeys(SafeSettings);

        JsonString := DSON.toJson<TAppSettings>(SafeSettings);

        // Атомарная запись: сначала во временный файл, затем переименование
        TmpPath := GetSettingsPath + '.tmp';
        TFile.WriteAllText(TmpPath, JsonString, TEncoding.UTF8);
        if TFile.Exists(GetSettingsPath) then
            TFile.Delete(GetSettingsPath);
        TFile.Move(TmpPath, GetSettingsPath);
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
