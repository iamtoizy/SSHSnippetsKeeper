unit Common.VCLStyleService;

interface

uses
    Core.Interfaces.Settings,
    System.Classes,
    System.Generics.Collections,
    Vcl.Themes
    ;

type
    TVCLStyleService = class
    private
        class var FLoadedStyles: TList<TCustomStyleServices>;
    public
        class constructor Create;
        class destructor Destroy;
        class function GetStylesFolder: string;
        class procedure FillStyleList(Items: TStrings);
        class function ApplyStyle(const StyleName: string): Boolean;
        class procedure ApplySavedStyle(SettingsManager: ISettingsManager);
        class procedure Shutdown;
    end;

implementation

uses
    Common.Helpers,
    System.IOUtils,
    System.SysUtils,
    Vcl.Forms,
    Winapi.Windows
    ;

{ TVCLStyleService }

class function TVCLStyleService.GetStylesFolder: string;
begin
    Result := ResolvePath('Styles', True);
end;

class procedure TVCLStyleService.FillStyleList(Items: TStrings);
var
    Files: TArray<string>;
    FileName: string;
begin
    Items.BeginUpdate;
    try
        Items.Clear;
        Items.Add('Windows');

        Files := TDirectory.GetFiles(GetStylesFolder, '*.vsf');
        TArray.Sort<string>(Files);
        for FileName in Files do
            Items.Add(TPath.GetFileNameWithoutExtension(FileName));
    finally
        Items.EndUpdate;
    end;
end;

class function TVCLStyleService.ApplyStyle(const StyleName: string): Boolean;

    procedure ResetActiveControls;
    var
        I: Integer;
    begin
        for I := 0 to Screen.FormCount - 1 do
            Screen.Forms[I].ActiveControl := nil;
    end;

var
    FileName: string;
    Handle: TStyleManager.TStyleServicesHandle;
    ExistingName: string;
begin
    Result := False;
    try
        if StyleName.IsEmpty or SameText(StyleName, 'Windows') then
        begin
            if TStyleManager.IsCustomStyleActive then
            begin
                ResetActiveControls;
                Exit(TStyleManager.TrySetStyle('Windows', False));
            end;
            Exit(True);
        end;

        FileName := TPath.Combine(GetStylesFolder, StyleName + '.vsf');
        if not TFile.Exists(FileName) then
            Exit;

        for ExistingName in TStyleManager.StyleNames do
            if SameText(ExistingName, StyleName) then
            begin
                ResetActiveControls;
                Exit(TStyleManager.TrySetStyle(StyleName, False));
            end;

        if not TStyleManager.IsValidStyle(FileName) then
            Exit;

        Handle := TStyleManager.LoadFromFile(FileName);
        if Handle = nil then
            Exit;

        ResetActiveControls;
        TStyleManager.SetStyle(Handle);
        Result := TStyleManager.IsCustomStyleActive;
        if Result then
            FLoadedStyles.Add(TStyleManager.ActiveStyle);
    except
        Result := False;
    end;
end;

class constructor TVCLStyleService.Create;
begin
    FLoadedStyles := TList<TCustomStyleServices>.Create;
end;

class destructor TVCLStyleService.Destroy;
begin
    FLoadedStyles.Free;
end;

class procedure TVCLStyleService.Shutdown;
var
    LoadedStyle: TCustomStyleServices;
begin
    if TStyleManager.IsCustomStyleActive then
    begin
        TStyleManager.SetStyle(TStyleManager.SystemStyle);
        CheckSynchronize;
    end;

    for LoadedStyle in FLoadedStyles do
    begin
        TStyleManager.UnRegisterStyle(LoadedStyle);
        LoadedStyle.Free;
    end;

    FLoadedStyles.Clear;
end;

class procedure TVCLStyleService.ApplySavedStyle(SettingsManager: ISettingsManager);
var
    SavedStyle: string;
begin
    if SettingsManager = nil then
        Exit;

    SavedStyle := SettingsManager.Data.UISettings.VCLStyle;
    if SavedStyle.IsEmpty then
        Exit;

    if not ApplyStyle(SavedStyle) then
        OutputDebugString(PChar('[VCLStyle] Failed to apply style "' + SavedStyle + '"'));
end;

end.
