unit Settings;

interface

uses
    System.Classes,
    System.JSON,
    System.Generics.Collections,
    ArrayHelper,
    Core.Interfaces;

type
    // Реализация менеджера
    TSettingsManager = class(TInterfacedObject, ISettingsManager)
    private
        FSettings: TAppSettings;
        FBashAutocomplete: TStringList;

        function GetSettingsPath: string;
        function GetBashPath: string;
        procedure ApplyDefaults;

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
    System.SysUtils,
    JSONSerializer,
    System.IOUtils,
    Winapi.Windows,
    UI.Services.MessagesHandler,
    CommonHelpers;

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

// Установка значений по умолчанию
procedure TSettingsManager.ApplyDefaults;
begin
    // Заполняем только критичные числовые значения
    FSettings.WindowHelper.ActivationDelay := 100;
    FSettings.WindowHelper.SetFocusDelay := 50;
    FSettings.WindowHelper.KeyPressInterval := 10;
end;

procedure TSettingsManager.Load;
var
    JsonString: string;
    Path: string;
begin
    Path := GetBashPath;
    // Загрузка Bash-скриптов
    if TFile.Exists(Path) then
    try
        FBashAutocomplete.LoadFromFile(Path, TEncoding.UTF8);
    except
        // Игнорируем ошибку чтения, просто список будет пуст
    end;

    // Загрузка JSON настроек
    Path := GetSettingsPath;
    if not TFile.Exists(Path) then
    begin
        Save; // Если файла нет, сразу создаем его с дефолтными значениями
        Exit;
    end;

    try
        JsonString := TFile.ReadAllText(Path, TEncoding.UTF8);
        FSettings := DSON.fromJson<TAppSettings>(JsonString);

        // Восстанавливаем дефолты, если необходимо
        if FSettings.UISettings.Help.HelpButton.HoverDelay <= 0 then
            FSettings.UISettings.Help.HelpButton.HoverDelay := 350;
        if FSettings.UISettings.Help.HelpButton.FadeDuration <= 0 then
            FSettings.UISettings.Help.HelpButton.FadeDuration := 200;
        if FSettings.WindowHelper.ActivationDelay <= 0 then
            FSettings.WindowHelper.ActivationDelay := 100;
        if FSettings.WindowHelper.SetFocusDelay <= 0 then
            FSettings.WindowHelper.SetFocusDelay := 50;
        if FSettings.WindowHelper.KeyPressInterval <= 0 then
            FSettings.WindowHelper.KeyPressInterval := 10;

    except
        on E: Exception do
        begin
            // Если чел сломал JSON руками, не даем программе упасть.
            // Применяем безопасные дефолты.
            ApplyDefaults;
            // В идеале тут залогировать ошибку или показать MessageDlg
        end;
    end;
end;

procedure TSettingsManager.Save;
var
    JsonString: string;
begin
    try
        JsonString := DSON.toJson<TAppSettings>(FSettings);

        // Современный и быстрый способ записи без TStringList.
        // TFile.WriteAllText корректно работает с UTF8.
        TFile.WriteAllText(GetSettingsPath, JsonString, TEncoding.UTF8);
    except
        // Обработка ошибки, если нет прав на запись в папку
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
