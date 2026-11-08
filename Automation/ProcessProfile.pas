unit ProcessProfile;

interface

uses
    Core.Interfaces.Settings,
    System.Generics.Collections
    ;

type
    TProcessProfile = class
    private
        FExeName: string;
        FTitleIncludeRegex: string;
        FTitleExcludeRegex: string;
        FWindowClasses: TArray<string>;
        FEnabled: Boolean;
    public
        constructor Create(const ExeName: string);

        property ExeName: string read FExeName write FExeName;
        property TitleIncludeRegex: string read FTitleIncludeRegex write FTitleIncludeRegex;
        property TitleExcludeRegex: string read FTitleExcludeRegex write FTitleExcludeRegex;
        property WindowClasses: TArray<string> read FWindowClasses;

        procedure SetWindowClasses(const AClasses: TArray<string>);
        function MatchesWindowClass(const AWinClass: string): Boolean;
        function MatchesTitle(const Title: string): Boolean;
        // Полная проверка окна. Выключенный профиль = без фильтров (только exe-список)
        function MatchesWindow(const AWinClass, ATitle: string): Boolean;
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

        // Пересобирает профили из списка разрешённых приложений настроек
        procedure SyncFromApplications(const AApps: TArray<TAllowedApplicationsItem>);

        function IsWindowAllowed(const AExeName, AWinClass, AWindowTitle: string): Boolean;

        property Profiles: TObjectList<TProcessProfile> read FProfiles;
    end;

var
    GProfileManager: TProfileManager;

implementation

uses
    System.RegularExpressions,
    System.SysUtils
    ;

{ TProcessProfile }

constructor TProcessProfile.Create(const ExeName: string);
begin
    inherited Create;
    FExeName := ExeName;
    FTitleIncludeRegex := '.*'; // По умолчанию разрешаем все заголовки
    FTitleExcludeRegex := '';
    FEnabled := True;
end;

procedure TProcessProfile.SetWindowClasses(const AClasses: TArray<string>);
var
    I, Count: Integer;
    S: string;
    Trimmed: TArray<string>;
begin
    SetLength(Trimmed, Length(AClasses));
    Count := 0;
    for I := 0 to High(AClasses) do
    begin
        S := Trim(AClasses[I]);
        if S <> '' then
        begin
            Trimmed[Count] := S;
            Inc(Count);
        end;
    end;

    SetLength(FWindowClasses, Count);
    for I := 0 to Count - 1 do
        FWindowClasses[I] := Trimmed[I];
end;

function TProcessProfile.MatchesWindowClass(const AWinClass: string): Boolean;
var
    C: string;
begin
    Result := True;

    // Пустой список классов = разрешены любые окна процесса
    if Length(FWindowClasses) = 0 then
        Exit;

    for C in FWindowClasses do
        if SameText(C, AWinClass) then
            Exit(True);

    Result := False;
end;

function TProcessProfile.MatchesTitle(const Title: string): Boolean;
var
    IncludeMatch, ExcludeMatch: Boolean;
begin
    Result := False;

    if not FEnabled then
        Exit;

    // Проверяем Include regex
    if FTitleIncludeRegex <> '' then
    begin
        IncludeMatch := TRegEx.IsMatch(Title, FTitleIncludeRegex, [roIgnoreCase]);
        if not IncludeMatch then
            Exit;
    end;

    // Проверяем Exclude regex
    if FTitleExcludeRegex <> '' then
    begin
        ExcludeMatch := TRegEx.IsMatch(Title, FTitleExcludeRegex, [roIgnoreCase]);
        if ExcludeMatch then
            Exit(False);
    end;

    Result := True;
end;

function TProcessProfile.MatchesWindow(const AWinClass, ATitle: string): Boolean;
begin
    if not FEnabled then
        Exit(True);

    Result := MatchesTitle(ATitle);
    if Result then
        Result := MatchesWindowClass(AWinClass);
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

procedure TProfileManager.SyncFromApplications(const AApps: TArray<TAllowedApplicationsItem>);
var
    App: TAllowedApplicationsItem;
    Profile: TProcessProfile;
begin
    FProfiles.Clear;
    for App in AApps do
    begin
        if not App.Enabled then
            Continue;

        Profile := AddProfile(App.ExeName);
        Profile.TitleIncludeRegex := App.TitleIncludeRegex;
        Profile.TitleExcludeRegex := App.TitleExcludeRegex;
        Profile.SetWindowClasses(App.WindowClasses);
    end;
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

function TProfileManager.IsWindowAllowed(const AExeName, AWinClass, AWindowTitle: string): Boolean;
var
    Profile: TProcessProfile;
begin
    Result := True;

    Profile := FindProfile(AExeName);
    if Profile <> nil then
        Result := Profile.MatchesWindow(AWinClass, AWindowTitle);
end;

initialization
    GProfileManager := TProfileManager.Create;


finalization
    GProfileManager.Free;

end.

