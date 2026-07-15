unit Settings;

interface

uses
    System.Classes,
    System.JSON,
    System.Generics.Collections,
    ArrayHelper
    ;

type
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
        ReasoningEffort: string;    // none
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

    TJSONSettings = record
        AllowedWindows: TArrayRecord<TWindowsNode>;
        WindowHelper: TWindowHelperNode;
        AllowedApplications: TArrayRecord<TAllowedApplicationsItem>;
        AISettings: TArrayRecord<TAIHub>;
    end;

procedure LoadSettingsFromJson;
procedure SaveSettingsToJson;

var
    SettingsRecord: TJSONSettings;
    BashAutocomplete: TStringList;

implementation

uses
    System.SysUtils,
    JSONSerializer,
    System.IOUtils,
    Winapi.Windows,
    System.RegularExpressions
    ;

procedure LoadSettingsFromJson;
var
    FilePath, S: string;
begin
    FilePath := TPath.Combine(TDirectory.GetCurrentDirectory, 'settings.json');
    if not TFile.Exists(FilePath) then
        Exit;

    // Явно указываем UTF8 при чтении, чтобы гарантированно понять русские буквы
    S := TFile.ReadAllText(FilePath, TEncoding.UTF8);
    SettingsRecord := DSON.fromJson<TJSONSettings>(S);

    if SettingsRecord.WindowHelper.ActivationDelay = 0 then
        SettingsRecord.WindowHelper.ActivationDelay := 100;
    if SettingsRecord.WindowHelper.SetFocusDelay = 0 then
        SettingsRecord.WindowHelper.SetFocusDelay := 50;
    if SettingsRecord.WindowHelper.KeyPressInterval = 0 then
        SettingsRecord.WindowHelper.KeyPressInterval := 10;

    // Bash
    var BashPath := TPath.Combine(TDirectory.GetCurrentDirectory, 'bash-autocomplete.txt');
    if TFile.Exists(BashPath) then
        BashAutocomplete.LoadFromFile(BashPath, TEncoding.UTF8);

//    SaveSettingsToJson;
end;

procedure SaveSettingsToJson;
var
    S: string;
    FilePath: string;
    SL: TStringList;
begin
    SettingsRecord.WindowHelper.ActivationDelay := 100;
    SettingsRecord.WindowHelper.SetFocusDelay := 50;
    SettingsRecord.WindowHelper.KeyPressInterval := 10;

    // Получаем JSON строку
    S := DSON.toJson<TJSONSettings>(SettingsRecord);

    FilePath := TPath.Combine(TDirectory.GetCurrentDirectory, 'settings.json');

    // Сохраняем через TStringList с явным маркером BOM
    SL := TStringList.Create;
    try
        SL.Text := S;
        SL.WriteBOM := True; // Записываем маркер UTF-8 (BOM)
        SL.SaveToFile(FilePath, TEncoding.UTF8);
    finally
        SL.Free;
    end;
end;

initialization

//SaveSettingsToJson;
    BashAutocomplete := TStringList.Create;

finalization
    BashAutocomplete.Free;

end.
