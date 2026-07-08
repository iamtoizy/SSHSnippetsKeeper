unit ProcessProfile;

interface

uses
    System.SysUtils, System.Generics.Collections, System.RegularExpressions;

type
    TProcessProfile = class
    private
        FExeName: string;
        FTitleIncludeRegex: string;
        FTitleExcludeRegex: string;
        FEnabled: Boolean;
    public
        constructor Create(const AExeName: string);

        property ExeName: string read FExeName write FExeName;
        property TitleIncludeRegex: string read FTitleIncludeRegex write FTitleIncludeRegex;
        property TitleExcludeRegex: string read FTitleExcludeRegex write FTitleExcludeRegex;
        property Enabled: Boolean read FEnabled write FEnabled;

        function MatchesTitle(const ATitle: string): Boolean;
    end;

    TProfileManager = class
    private
        FProfiles: TObjectList<TProcessProfile>;
    public
        constructor Create;
        destructor Destroy; override;

        function AddProfile(const AExeName: string): TProcessProfile;
        procedure RemoveProfile(AProfile: TProcessProfile);
        function FindProfile(const AExeName: string): TProcessProfile;

        function IsWindowAllowed(const AExeName: string; const AWindowTitle: string): Boolean;

        property Profiles: TObjectList<TProcessProfile> read FProfiles;
    end;

var
    ProfileManager: TProfileManager;

implementation

{ TProcessProfile }

constructor TProcessProfile.Create(const AExeName: string);
begin
    inherited Create;
    FExeName := AExeName;
    FTitleIncludeRegex := '.*'; // По умолчанию разрешаем все заголовки
    FTitleExcludeRegex := '';
    FEnabled := True;
end;

function TProcessProfile.MatchesTitle(const ATitle: string): Boolean;
var
    IncludeMatch, ExcludeMatch: Boolean;
begin
    Result := False;

    if not FEnabled then
        Exit;

    // Проверяем Include regex
    if FTitleIncludeRegex <> '' then
    begin
        IncludeMatch := TRegEx.IsMatch(ATitle, FTitleIncludeRegex, [roIgnoreCase]);
        if not IncludeMatch then
            Exit;
    end;

    // Проверяем Exclude regex
    if FTitleExcludeRegex <> '' then
    begin
        ExcludeMatch := TRegEx.IsMatch(ATitle, FTitleExcludeRegex, [roIgnoreCase]);
        if ExcludeMatch then
            Exit(False);
    end;

    Result := True;
end;

{ TProfileManager }

constructor TProfileManager.Create;
begin
    inherited Create;
    FProfiles := TObjectList<TProcessProfile>.Create(True);
end;

destructor TProfileManager.Destroy;
begin
    FProfiles.Free;
    inherited;
end;

function TProfileManager.AddProfile(const AExeName: string): TProcessProfile;
begin
    Result := TProcessProfile.Create(AExeName);
    FProfiles.Add(Result);
end;

procedure TProfileManager.RemoveProfile(AProfile: TProcessProfile);
begin
    FProfiles.Remove(AProfile);
end;

function TProfileManager.FindProfile(const AExeName: string): TProcessProfile;
var
    Profile: TProcessProfile;
begin
    Result := nil;
    for Profile in FProfiles do
    begin
        if SameText(Profile.ExeName, AExeName) then
        begin
            Result := Profile;
            Exit;
        end;
    end;
end;

function TProfileManager.IsWindowAllowed(const AExeName: string; const AWindowTitle: string): Boolean;
var
    Profile: TProcessProfile;
begin
    Result := False;
    Profile := FindProfile(AExeName);
    if Profile <> nil then
        Result := Profile.MatchesTitle(AWindowTitle);
end;

initialization

ProfileManager := TProfileManager.Create;

finalization

ProfileManager.Free;

end.
