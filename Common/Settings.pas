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
        ActivationDelay: NativeUInt;
        SetFocusDelay: NativeUInt;
        KeyPressInterval: NativeUInt;
    end;

    TAllowedApplications = record
        ExeName: string;
        Enabled: Boolean;
    end;

    TJSONSettings = record
        AllowedWindows: TArrayRecord<TWindowsNode>;
        WindowHelper: TWindowHelperNode;
        AllowedApplications: TArrayRecord<TAllowedApplications>;
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
    Winapi.Windows
    ;

procedure LoadSettingsFromJson;
var
    S: string;
begin
    S := TFile.ReadAllText(TDirectory.GetCurrentDirectory + '\settings.json');
    SettingsRecord := DSON.fromJson<TJSONSettings>(S);

    if SettingsRecord.WindowHelper.ActivationDelay = 0 then
        SettingsRecord.WindowHelper.ActivationDelay := 100;
    if SettingsRecord.WindowHelper.SetFocusDelay = 0 then
        SettingsRecord.WindowHelper.SetFocusDelay := 50;
    if SettingsRecord.WindowHelper.KeyPressInterval = 0 then
        SettingsRecord.WindowHelper.KeyPressInterval := 10;

    // Bash
    BashAutocomplete.LoadFromFile(TDirectory.GetCurrentDirectory + '\bash-autocomplete.txt')
end;

procedure SaveSettingsToJson;
var
    S: string;
begin
    SettingsRecord.WindowHelper.ActivationDelay := 100;
    SettingsRecord.WindowHelper.SetFocusDelay := 50;
    SettingsRecord.WindowHelper.KeyPressInterval := 10;
    S := DSON.toJson<TJSONSettings>(SettingsRecord);
    TFile.WriteAllText(TDirectory.GetCurrentDirectory + '\settings.json', S);
end;

initialization

//SaveSettingsToJson;
    BashAutocomplete := TStringList.Create;

finalization
    BashAutocomplete.Free;

end.
