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
        FErrorHandler: IUIErrorHandler;

        function GetSettingsPath: string;
        function GetBashPath: string;
        procedure ApplyDefaults;

        function GetSettings: TAppSettings;
        procedure SetSettings(const Value: TAppSettings);
        function GetBashAutocomplete: TStringList;
    public
        constructor Create;
        destructor Destroy; override;

        procedure Load;
        procedure Save;
    end;

implementation

uses
    System.SysUtils,
    JSONSerializer,
    System.IOUtils,
    Winapi.Windows,
    UI.Interfaces;

{ TSettingsManager }

constructor TSettingsManager.Create;
begin
    inherited Create;
    FBashAutocomplete := TStringList.Create;
    ApplyDefaults; // Сразу ставим дефолты на случай, если файла еще нет
    FErrorHandler := TVCLErrorHandler.Create;
end;

destructor TSettingsManager.Destroy;
begin
    FBashAutocomplete.Free;
    inherited;
end;

// Безопасное получение пути рядом с exe-файлом!
function TSettingsManager.GetSettingsPath: string;
begin
    Result := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'settings.json');
end;

function TSettingsManager.GetBashPath: string;
begin
    Result := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'bash-autocomplete.txt');
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
begin
    // 1. Загрузка Bash-скриптов
    if TFile.Exists(GetBashPath) then
    try
        FBashAutocomplete.LoadFromFile(GetBashPath, TEncoding.UTF8);
    except
        // Игнорируем ошибку чтения, просто список будет пуст
    end;

    // 2. Загрузка JSON настроек
    if not TFile.Exists(GetSettingsPath) then
    begin
        Save; // Если файла нет, сразу создаем его с дефолтными значениями
        Exit;
    end;

    try
        JsonString := TFile.ReadAllText(GetSettingsPath, TEncoding.UTF8);
        FSettings := DSON.fromJson<TAppSettings>(JsonString);

        // Проверка: если парсер загрузил нули (ключи отсутствовали в json), восстанавливаем дефолты
        if FSettings.WindowHelper.ActivationDelay <= 0 then
            FSettings.WindowHelper.ActivationDelay := 100;
        if FSettings.WindowHelper.SetFocusDelay <= 0 then
            FSettings.WindowHelper.SetFocusDelay := 50;
        if FSettings.WindowHelper.KeyPressInterval <= 0 then
            FSettings.WindowHelper.KeyPressInterval := 10;

    except
        on E: Exception do
        begin
            // Если ИТ-шник сломал JSON руками, мы не даем программе упасть.
            // Мы применяем безопасные дефолты.
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

procedure TSettingsManager.SetSettings(const Value: TAppSettings);
begin
    FSettings := Value;
end;

function TSettingsManager.GetBashAutocomplete: TStringList;
begin
    Result := FBashAutocomplete;
end;

end.
