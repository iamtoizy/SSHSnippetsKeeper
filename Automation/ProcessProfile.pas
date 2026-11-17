unit ProcessProfile;

interface

uses
    Core.Interfaces.Settings,
    System.Generics.Collections
    ;

type
    // Результат проверки заголовка окна фильтрами профиля:
    // превью в диалоге профиля показывает причину блокировки
    TTitleFilterResult = (tfrPass, tfrBlockedByInclude, tfrBlockedByExclude, tfrBlockedByGlobal);

    // Результат полной проверки окна фильтрами профиля: заголовки + классы.
    // Общий код гейта (MatchesWindow), превью в диалоге профиля,
    // санити-чека сохранения и экрана диагностики
    TWindowFilterResult = (wfrPass, wfrDisabled, wfrBlockedByInclude, wfrBlockedByExclude, wfrBlockedByClass);

    TProcessProfile = class
    private
        FExeName: string;
        FTitleIncludeRegex: string;
        FTitleExcludeRegex: string;
        FWindowClasses: TArray<string>;
        FEnabled: Boolean;
        // Список классов: пустой = любые окна процесса
        class function MatchesWindowClassList(const AClasses: TArray<string>;
            const AWinClass: string): Boolean; static;
    public
        constructor Create(const ExeName: string);

        property ExeName: string read FExeName write FExeName;
        property TitleIncludeRegex: string read FTitleIncludeRegex write FTitleIncludeRegex;
        property TitleExcludeRegex: string read FTitleExcludeRegex write FTitleExcludeRegex;
        property WindowClasses: TArray<string> read FWindowClasses;

        procedure SetWindowClasses(const AClasses: TArray<string>);
        function MatchesWindowClass(const AWinClass: string): Boolean;
        function MatchesTitle(const Title: string): Boolean;
        // Проверка заголовка фильтрами без привязки к профилю - единая
        // семантика для монитора окон и превью в диалоге профиля
        class function EvaluateTitleFilter(const ATitle, AIncludeRegex, AExcludeRegex: string): TTitleFilterResult; static;
        // Глобальный запрет: True, если заголовок совпал с любым включённым
        // правилом deny-набора. AMatchedRule - имя правила (или Pattern,
        // если имя пустое). Битые шаблоны пропускаются без падения
        class function EvaluateGlobalDeny(const ATitle: string;
            const ARules: TArray<TGlobalTitleDenyRule>;
            out AMatchedRule: string): Boolean; static;
        // Полная проверка окна. Выключенный профиль = без фильтров (только exe-список)
        function MatchesWindow(const AWinClass, ATitle: string): Boolean;

        // Полная проверка окна фильтрами с причиной результата: единая
        // семантика гейта для превью профиля, санити-чека и диагностики
        class function EvaluateWindowFilters(const AEnabled: Boolean;
            const AIncludeRegex, AExcludeRegex: string;
            const AClasses: TArray<string>;
            const AWinClass, ATitle: string): TWindowFilterResult; static;
    end;

    TProfileManager = class
    private
        FProfiles: TObjectList<TProcessProfile>;
        FGlobalDenyRules: TArray<TGlobalTitleDenyRule>;
    public
        constructor Create;
        destructor Destroy; override;

        function AddProfile(const AExeName: string): TProcessProfile;
        procedure RemoveProfile(AProfile: TProcessProfile);
        function FindProfile(const AExeName: string): TProcessProfile;

        // Пересобирает профили из списка разрешённых приложений настроек
        procedure SyncFromApplications(const AApps: TArray<TAllowedApplicationsItem>);

        // Заменяет глобальный deny-набор (defensive copy во избежание
        // совместного владения массивом с настройками)
        procedure SetGlobalDenyRules(const ARules: TArray<TGlobalTitleDenyRule>);

        // True = ввод разрешён. ADenyRule - имя сработавшего глобального
        // правила (или его Pattern, если имя пустое), '' = запрет не связан
        // с deny-набором (или разрешено)
        function TryIsWindowAllowed(const AExeName, AWinClass, AWindowTitle: string;
            out ADenyRule: string): Boolean;
        function IsWindowAllowed(const AExeName, AWinClass, AWindowTitle: string): Boolean;

        property Profiles: TObjectList<TProcessProfile> read FProfiles;
        property GlobalDenyRules: TArray<TGlobalTitleDenyRule> read FGlobalDenyRules;
    end;

var
    GProfileManager: TProfileManager;

implementation

uses
    Common.RegexSafety,
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

class function TProcessProfile.MatchesWindowClassList(const AClasses: TArray<string>;
    const AWinClass: string): Boolean;
var
    C: string;
begin
    Result := True;

    // Пустой список классов = разрешены любые окна процесса
    if Length(AClasses) = 0 then
        Exit;

    for C in AClasses do
        if SameText(C, AWinClass) then
            Exit(True);

    Result := False;
end;

function TProcessProfile.MatchesWindowClass(const AWinClass: string): Boolean;
begin
    Result := MatchesWindowClassList(FWindowClasses, AWinClass);
end;

class function TProcessProfile.EvaluateTitleFilter(const ATitle, AIncludeRegex, AExcludeRegex: string): TTitleFilterResult;
begin
    Result := tfrPass;

    // Include: заголовок обязан совпасть с regex
    if AIncludeRegex <> '' then
        if not TRegexSafety.IsMatch(ATitle, AIncludeRegex, [roIgnoreCase]) then
            Exit(tfrBlockedByInclude);

    // Exclude: совпавший с regex заголовок блокируется
    if AExcludeRegex <> '' then
        if TRegexSafety.IsMatch(ATitle, AExcludeRegex, [roIgnoreCase]) then
            Exit(tfrBlockedByExclude);
end;

class function TProcessProfile.EvaluateWindowFilters(const AEnabled: Boolean;
    const AIncludeRegex, AExcludeRegex: string;
    const AClasses: TArray<string>;
    const AWinClass, ATitle: string): TWindowFilterResult;
var
    TitleRes: TTitleFilterResult;
begin
    // Выключенный профиль = без фильтров: окно проходит по одному списку exe
    if not AEnabled then
        Exit(wfrDisabled);

    TitleRes := EvaluateTitleFilter(ATitle, AIncludeRegex, AExcludeRegex);
    if TitleRes = tfrBlockedByInclude then
        Exit(wfrBlockedByInclude);
    if TitleRes = tfrBlockedByExclude then
        Exit(wfrBlockedByExclude);

    if not MatchesWindowClassList(AClasses, AWinClass) then
        Exit(wfrBlockedByClass);

    Result := wfrPass;
end;

class function TProcessProfile.EvaluateGlobalDeny(const ATitle: string;
    const ARules: TArray<TGlobalTitleDenyRule>;
    out AMatchedRule: string): Boolean;
var
    Rule: TGlobalTitleDenyRule;
    Options: TRegExOptions;
begin
    AMatchedRule := '';

    for Rule in ARules do
    begin
        // Выключенные и пустые правила пропускаются
        if (not Rule.Enabled) or (Trim(Rule.Pattern) = '') then
            Continue;

        Options := [roCompiled];
        if not Rule.CaseSensitive then
            Include(Options, roIgnoreCase);

        if TRegexSafety.IsMatch(ATitle, Rule.Pattern, Options) then
        begin
            if Trim(Rule.Name) = '' then
                AMatchedRule := Rule.Pattern
            else
                AMatchedRule := Rule.Name;
            Exit(True);
        end;
    end;

    Result := False;
end;

function TProcessProfile.MatchesTitle(const Title: string): Boolean;
begin
    if not FEnabled then
        Exit(False);

    Result := EvaluateTitleFilter(Title, FTitleIncludeRegex, FTitleExcludeRegex) = tfrPass;
end;

function TProcessProfile.MatchesWindow(const AWinClass, ATitle: string): Boolean;
begin
    // Один код с EvaluateWindowFilters: гейт и превью не расходятся
    Result := EvaluateWindowFilters(FEnabled, FTitleIncludeRegex, FTitleExcludeRegex,
        FWindowClasses, AWinClass, ATitle) in [wfrPass, wfrDisabled];
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

procedure TProfileManager.SetGlobalDenyRules(const ARules: TArray<TGlobalTitleDenyRule>);
begin
    FGlobalDenyRules := Copy(ARules, 0, Length(ARules));
end;

function TProfileManager.TryIsWindowAllowed(const AExeName, AWinClass, AWindowTitle: string;
    out ADenyRule: string): Boolean;
var
    Profile: TProcessProfile;
begin
    ADenyRule := '';
    Result := True;

    // Глобальный запрет проверяется первым и перекрывает любые профили
    if TProcessProfile.EvaluateGlobalDeny(AWindowTitle, FGlobalDenyRules, ADenyRule) then
        Exit(False);

    Profile := FindProfile(AExeName);
    if Profile <> nil then
        Result := Profile.MatchesWindow(AWinClass, AWindowTitle);
end;

function TProfileManager.IsWindowAllowed(const AExeName, AWinClass, AWindowTitle: string): Boolean;
var
    Dummy: string;
begin
    Result := TryIsWindowAllowed(AExeName, AWinClass, AWindowTitle, Dummy);
end;

initialization
    GProfileManager := TProfileManager.Create;


finalization
    GProfileManager.Free;

end.

