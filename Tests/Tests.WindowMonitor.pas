unit Tests.WindowMonitor;

interface

uses
    DUnitX.TestFramework
    ;

type
    [TestFixture]
    TWindowMonitorTests = class(TObject)
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test]
        procedure RegisterWindow_RejectsInvalidHandles;

        [Test]
        procedure RegisterWindow_RejectsDisallowedProcess;

        [Test]
        procedure RegisterWindow_AcceptsVisibleAllowedWindow;

        [Test]
        procedure RegisterWindow_ProfileClassFilter_BlocksOtherClass;

        [Test]
        procedure RegisterWindow_ProfileClassFilter_AcceptsKnownClass;

        [Test]
        procedure RegisterWindow_ProfileTitleFilters_BlockedTitles;

        [Test]
        procedure RegisterWindow_DoesNotDuplicateEntries;

        [Test]
        procedure RemoveWindow_RemovesOnlyTargetWindow;

        [Test]
        procedure RemoveWindow_UnknownHandle_IsNoOp;

        [Test]
        procedure ClearHistory_EmptiesHistory;

        [Test]
        procedure RemovedWindow_CanBeRegisteredAgain;

        [Test]
        procedure GetOpenAllowedWindows_ListsAllowedVisibleWindows;

        [Test]
        procedure RegisterWindow_GlobalDeny_BlocksAllowedWindow;

        [Test]
        procedure GlobalDeny_BlocksEvenWithPermissiveProfile;

        [Test]
        procedure GlobalDeny_BlocksWindowWithoutProfile;

        [Test]
        procedure GlobalDeny_DisabledRule_Ignored;

        [Test]
        procedure GlobalDeny_CaseSensitivity_PerRule;

        [Test]
        procedure TryIsWindowAllowed_ReportsMatchedRule;
    end;

    [TestFixture]
    TProcessProfileFilterTests = class(TObject)
    public
        [Test]
        procedure EvaluateWindowFilters_DisabledProfile_ReturnsDisabled;

        [Test]
        procedure EvaluateWindowFilters_NoFilters_PassesAnyWindow;

        [Test]
        procedure EvaluateWindowFilters_TitleInclude_MismatchBlocks;

        [Test]
        procedure EvaluateWindowFilters_TitleExclude_MatchBlocks;

        [Test]
        procedure EvaluateWindowFilters_ClassList_MismatchBlocks;

        [Test]
        procedure EvaluateWindowFilters_ClassList_EmptyListPassesAnyClass;

        [Test]
        procedure EvaluateWindowFilters_ClassList_CaseInsensitiveMatch;

        [Test]
        procedure MatchesWindow_AgreesWithEvaluateWindowFilters;

        [Test]
        procedure FindClassHiddenApps_DetectsStaleClassFilter;

        [Test]
        procedure FindClassHiddenApps_SkipsDisabledEmptyAndMatching;
    end;

implementation

uses
    Core.Interfaces.Settings,
    System.SysUtils,
    Winapi.Windows,
    ProcessProfile,
    WindowMonitor
    ;

const
    PROCESS_QUERY_LIMITED_INFORMATION = $1000;

function QueryFullProcessImageName(hProcess: THandle; dwFlags: DWORD;
    lpExeName: PWideChar; var lpdwSize: DWORD): BOOL; stdcall;
    external 'kernel32' name 'QueryFullProcessImageNameW';

{ Копия резолва exe из WindowMonitor: там функция не экспортируется }
function GetExeNameOfWindow(AHWND: THandle): string;
var
    PID: DWORD;
    hProcess: THandle;
    Buffer: array[0..MAX_PATH] of Char;
    dwSize: DWORD;
begin
    Result := '';
    GetWindowThreadProcessId(AHWND, @PID);
    if PID = 0 then
        Exit;

    hProcess := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, PID);
    if hProcess = 0 then
        Exit;
    try
        FillChar(Buffer, SizeOf(Buffer), 0);
        dwSize := MAX_PATH;
        if QueryFullProcessImageName(hProcess, 0, Buffer, dwSize) then
            Result := LowerCase(ExtractFileName(Buffer));
    finally
        CloseHandle(hProcess);
    end;
end;

{ Поиск кандидата для теста перечисления: первое видимое окно чужого
  процесса с непустым заголовком. Собственные окна в перечисление
  не попадают по дизайну менеджера }
var
    GCandidateExe: string;

function CandidateEnumProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
    Exe: string;
begin
    Result := True;
    if not IsWindowVisible(Wnd) then
        Exit;
    if (GetWindowLong(Wnd, GWL_EXSTYLE) and WS_EX_TOOLWINDOW) <> 0 then
        Exit;
    if GetWindowTextLength(Wnd) <= 0 then
        Exit;

    Exe := GetExeNameOfWindow(Wnd);
    if Exe = '' then
        Exit;
    if SameText(Exe, LowerCase(ExtractFileName(ParamStr(0)))) then
        Exit;

    GCandidateExe := Exe;
    Result := False;
end;

{ Реальное видимое окно верхнего уровня: WS_VISIBLE делает его
  "видимым" для IsWindowVisible без прокачки очереди сообщений }
function CreateVisibleWindow(const ACaption: string): HWND;
begin
    Result := CreateWindowEx(0, 'STATIC', PChar(ACaption),
        WS_OVERLAPPEDWINDOW or WS_VISIBLE, 0, 0, 160, 80, 0, 0, HInstance, nil);
    Assert.IsTrue(IsWindow(Result), 'Test window was not created');
    Assert.IsTrue(IsWindowVisible(Result), 'Test window is not visible');
end;

procedure TWindowMonitorTests.Setup;
begin
    GWinMonitor.ClearAllowedProcesses;
    GWinMonitor.ClearHistory;
    GProfileManager.Profiles.Clear;
    GProfileManager.SetGlobalDenyRules(nil);
end;

procedure TWindowMonitorTests.TearDown;
begin
    GWinMonitor.ClearAllowedProcesses;
    GWinMonitor.ClearHistory;
    GProfileManager.Profiles.Clear;
    GProfileManager.SetGlobalDenyRules(nil);
end;

procedure TWindowMonitorTests.RegisterWindow_RejectsInvalidHandles;
begin
    Assert.IsFalse(GWinMonitor.RegisterWindow(0));
    Assert.IsFalse(GWinMonitor.RegisterWindow(HWND($DEADBEEF)));
    Assert.AreEqual(0, GWinMonitor.AllowedWindowCount);
end;

procedure TWindowMonitorTests.RegisterWindow_RejectsDisallowedProcess;
var
    Wnd: HWND;
begin
    Wnd := CreateVisibleWindow('SSK Test Window');
    try
        Assert.IsFalse(GWinMonitor.RegisterWindow(Wnd));
        Assert.AreEqual(0, GWinMonitor.AllowedWindowCount);
    finally
        DestroyWindow(Wnd);
    end;
end;

procedure TWindowMonitorTests.RegisterWindow_AcceptsVisibleAllowedWindow;
var
    Wnd: HWND;
    Info: TWindowMonitorInfo;
begin
    GWinMonitor.AddAllowedProcess(ExtractFileName(ParamStr(0)));
    Wnd := CreateVisibleWindow('SSK Test Window');
    try
        Assert.IsTrue(GWinMonitor.RegisterWindow(Wnd));
        Assert.AreEqual(1, GWinMonitor.AllowedWindowCount);

        Info := GWinMonitor.GetLastAllowedWindow;
        Assert.AreEqual(UInt64(Wnd), UInt64(Info.HWND));
        Assert.IsTrue(SameText(ExtractFileName(ParamStr(0)), Info.ExeName),
            'ExeName does not match test process');
        Assert.IsTrue(Info.ActivatedAt <> 0, 'ActivatedAt must be set');
    finally
        DestroyWindow(Wnd);
    end;
end;

procedure TWindowMonitorTests.RegisterWindow_ProfileClassFilter_BlocksOtherClass;
var
    Wnd: HWND;
    Profile: TProcessProfile;
begin
    GWinMonitor.AddAllowedProcess(ExtractFileName(ParamStr(0)));
    Profile := GProfileManager.AddProfile(ExtractFileName(ParamStr(0)));
    Profile.SetWindowClasses(['PuTTY']);

    Wnd := CreateVisibleWindow('SSK Test Window');
    try
        Assert.IsFalse(GWinMonitor.RegisterWindow(Wnd));
        Assert.AreEqual(0, GWinMonitor.AllowedWindowCount);
    finally
        DestroyWindow(Wnd);
    end;
end;

procedure TWindowMonitorTests.RegisterWindow_ProfileClassFilter_AcceptsKnownClass;
var
    Wnd: HWND;
    Info: TWindowMonitorInfo;
    Profile: TProcessProfile;
begin
    GWinMonitor.AddAllowedProcess(ExtractFileName(ParamStr(0)));
    Profile := GProfileManager.AddProfile(ExtractFileName(ParamStr(0)));
    Profile.SetWindowClasses(['STATIC']);

    Wnd := CreateVisibleWindow('SSK Test Window');
    try
        Assert.IsTrue(GWinMonitor.RegisterWindow(Wnd));
        Assert.AreEqual(1, GWinMonitor.AllowedWindowCount);

        Info := GWinMonitor.GetLastAllowedWindow;
        Assert.AreEqual('STATIC', Info.WindowClass);
    finally
        DestroyWindow(Wnd);
    end;
end;

procedure TWindowMonitorTests.RegisterWindow_ProfileTitleFilters_BlockedTitles;
var
    Wnd: HWND;
    Profile: TProcessProfile;
begin
    GWinMonitor.AddAllowedProcess(ExtractFileName(ParamStr(0)));
    Profile := GProfileManager.AddProfile(ExtractFileName(ParamStr(0)));

    // Exclude по заголовку
    Profile.TitleExcludeRegex := 'SSK';
    Wnd := CreateVisibleWindow('SSK Test Window');
    try
        Assert.IsFalse(GWinMonitor.RegisterWindow(Wnd));
        Assert.AreEqual(0, GWinMonitor.AllowedWindowCount);
    finally
        DestroyWindow(Wnd);
    end;

    // Include, которому заголовок не соответствует
    Profile.TitleExcludeRegex := '';
    Profile.TitleIncludeRegex := 'NoMatchHere';
    Wnd := CreateVisibleWindow('SSK Test Window');
    try
        Assert.IsFalse(GWinMonitor.RegisterWindow(Wnd));
        Assert.AreEqual(0, GWinMonitor.AllowedWindowCount);
    finally
        DestroyWindow(Wnd);
    end;
end;

procedure TWindowMonitorTests.RegisterWindow_DoesNotDuplicateEntries;
var
    Wnd: HWND;
begin
    GWinMonitor.AddAllowedProcess(ExtractFileName(ParamStr(0)));
    Wnd := CreateVisibleWindow('SSK Test Window');
    try
        Assert.IsTrue(GWinMonitor.RegisterWindow(Wnd));
        Assert.IsTrue(GWinMonitor.RegisterWindow(Wnd));
        Assert.AreEqual(1, GWinMonitor.AllowedWindowCount);
    finally
        DestroyWindow(Wnd);
    end;
end;

procedure TWindowMonitorTests.RemoveWindow_RemovesOnlyTargetWindow;
var
    W1, W2: HWND;
begin
    GWinMonitor.AddAllowedProcess(ExtractFileName(ParamStr(0)));
    W1 := CreateVisibleWindow('SSK Test Window 1');
    W2 := CreateVisibleWindow('SSK Test Window 2');
    try
        Assert.IsTrue(GWinMonitor.RegisterWindow(W1));
        Assert.IsTrue(GWinMonitor.RegisterWindow(W2));
        Assert.AreEqual(2, GWinMonitor.AllowedWindowCount);

        GWinMonitor.RemoveWindow(W1);
        Assert.AreEqual(1, GWinMonitor.AllowedWindowCount);
        Assert.AreEqual(UInt64(W2), UInt64(GWinMonitor.GetLastAllowedWindow.HWND));
    finally
        DestroyWindow(W1);
        DestroyWindow(W2);
    end;
end;

procedure TWindowMonitorTests.RemoveWindow_UnknownHandle_IsNoOp;
var
    Wnd: HWND;
begin
    GWinMonitor.AddAllowedProcess(ExtractFileName(ParamStr(0)));
    Wnd := CreateVisibleWindow('SSK Test Window');
    try
        Assert.IsTrue(GWinMonitor.RegisterWindow(Wnd));
        GWinMonitor.RemoveWindow(HWND(987654321));
        Assert.AreEqual(1, GWinMonitor.AllowedWindowCount);
    finally
        DestroyWindow(Wnd);
    end;
end;

procedure TWindowMonitorTests.ClearHistory_EmptiesHistory;
var
    W1, W2: HWND;
begin
    GWinMonitor.AddAllowedProcess(ExtractFileName(ParamStr(0)));
    W1 := CreateVisibleWindow('SSK Test Window 1');
    W2 := CreateVisibleWindow('SSK Test Window 2');
    try
        Assert.IsTrue(GWinMonitor.RegisterWindow(W1));
        Assert.IsTrue(GWinMonitor.RegisterWindow(W2));
        Assert.AreEqual(2, GWinMonitor.AllowedWindowCount);

        GWinMonitor.ClearHistory;
        Assert.AreEqual(0, GWinMonitor.AllowedWindowCount);
        Assert.AreEqual(UInt64(0), UInt64(GWinMonitor.GetLastAllowedWindow.HWND));
    finally
        DestroyWindow(W1);
        DestroyWindow(W2);
    end;
end;

procedure TWindowMonitorTests.RemovedWindow_CanBeRegisteredAgain;
var
    Wnd: HWND;
begin
    GWinMonitor.AddAllowedProcess(ExtractFileName(ParamStr(0)));
    Wnd := CreateVisibleWindow('SSK Test Window');
    try
        Assert.IsTrue(GWinMonitor.RegisterWindow(Wnd));
        GWinMonitor.RemoveWindow(Wnd);
        Assert.AreEqual(0, GWinMonitor.AllowedWindowCount);

        Assert.IsTrue(GWinMonitor.RegisterWindow(Wnd));
        Assert.AreEqual(1, GWinMonitor.AllowedWindowCount);
        Assert.AreEqual(UInt64(Wnd), UInt64(GWinMonitor.GetLastAllowedWindow.HWND));
    finally
        DestroyWindow(Wnd);
    end;
end;

procedure TWindowMonitorTests.GetOpenAllowedWindows_ListsAllowedVisibleWindows;
var
    Exe: string;
    List: TArray<TWindowMonitorInfo>;
    I: Integer;
    Found: Boolean;
begin
    GCandidateExe := '';
    EnumWindows(@CandidateEnumProc, 0);
    Assert.IsTrue(GCandidateExe <> '', 'No visible foreign window on desktop');
    Exe := GCandidateExe;

    GWinMonitor.AddAllowedProcess(Exe);
    List := GWinMonitor.GetOpenAllowedWindows;
    Assert.IsTrue(Length(List) > 0, 'Enumeration returned nothing');

    Found := False;
    for I := 0 to High(List) do
        if SameText(List[I].ExeName, Exe) then
            Found := True;
    Assert.IsTrue(Found, 'Allowed visible window missing from result');
end;

procedure TWindowMonitorTests.RegisterWindow_GlobalDeny_BlocksAllowedWindow;
var
    Rules: TArray<TGlobalTitleDenyRule>;
    Wnd: HWND;
begin
    GWinMonitor.AddAllowedProcess(ExtractFileName(ParamStr(0)));

    SetLength(Rules, 1);
    Rules[0] := Default(TGlobalTitleDenyRule);
    Rules[0].Name := 'Deny SSK';
    Rules[0].Pattern := 'SSK';
    Rules[0].Enabled := True;
    GProfileManager.SetGlobalDenyRules(Rules);

    Wnd := CreateVisibleWindow('SSK Test Window');
    try
        Assert.IsFalse(GWinMonitor.RegisterWindow(Wnd));
        Assert.AreEqual(0, GWinMonitor.AllowedWindowCount);
    finally
        DestroyWindow(Wnd);
    end;
end;

procedure TWindowMonitorTests.GlobalDeny_BlocksEvenWithPermissiveProfile;
var
    Rules: TArray<TGlobalTitleDenyRule>;
    Profile: TProcessProfile;
begin
    // Профиль пропускает всё, но deny-набор перекрывает его
    Profile := GProfileManager.AddProfile('test.exe');
    Profile.TitleIncludeRegex := '.*';

    SetLength(Rules, 1);
    Rules[0] := Default(TGlobalTitleDenyRule);
    Rules[0].Name := 'Production';
    Rules[0].Pattern := 'production';
    Rules[0].Enabled := True;
    GProfileManager.SetGlobalDenyRules(Rules);

    Assert.IsFalse(GProfileManager.IsWindowAllowed('test.exe', 'PuTTY', 'host production-01'));
    Assert.IsTrue(GProfileManager.IsWindowAllowed('test.exe', 'PuTTY', 'host dev-01'));
end;

procedure TWindowMonitorTests.GlobalDeny_BlocksWindowWithoutProfile;
var
    Rules: TArray<TGlobalTitleDenyRule>;
begin
    SetLength(Rules, 1);
    Rules[0] := Default(TGlobalTitleDenyRule);
    Rules[0].Pattern := 'secret';
    Rules[0].Enabled := True;
    GProfileManager.SetGlobalDenyRules(Rules);

    // Профиля для exe нет вовсе - deny-набор всё равно блокирует
    Assert.IsFalse(GProfileManager.IsWindowAllowed('unknown.exe', 'Class', 'my secret window'));
    Assert.IsTrue(GProfileManager.IsWindowAllowed('unknown.exe', 'Class', 'ordinary window'));
end;

procedure TWindowMonitorTests.GlobalDeny_DisabledRule_Ignored;
var
    Rules: TArray<TGlobalTitleDenyRule>;
begin
    SetLength(Rules, 2);
    Rules[0] := Default(TGlobalTitleDenyRule);
    Rules[0].Pattern := 'disabled-block';
    Rules[0].Enabled := False;
    Rules[1] := Default(TGlobalTitleDenyRule);
    Rules[1].Name := 'Enabled Rule';
    Rules[1].Pattern := 'enabled-block';
    Rules[1].Enabled := True;
    GProfileManager.SetGlobalDenyRules(Rules);

    Assert.IsTrue(GProfileManager.IsWindowAllowed('any.exe', '', 'title disabled-block title'));
    Assert.IsFalse(GProfileManager.IsWindowAllowed('any.exe', '', 'title enabled-block title'));
end;

procedure TWindowMonitorTests.GlobalDeny_CaseSensitivity_PerRule;
var
    Rules: TArray<TGlobalTitleDenyRule>;
begin
    // Чувствительность к регистру задаётся на правило
    SetLength(Rules, 2);
    Rules[0] := Default(TGlobalTitleDenyRule);
    Rules[0].Name := 'Strict';
    Rules[0].Pattern := 'PROD-\d+';
    Rules[0].CaseSensitive := True;
    Rules[0].Enabled := True;
    Rules[1] := Default(TGlobalTitleDenyRule);
    Rules[1].Name := 'Loose';
    Rules[1].Pattern := 'staging-\d+';
    Rules[1].CaseSensitive := False;
    Rules[1].Enabled := True;
    GProfileManager.SetGlobalDenyRules(Rules);

    // Строгое правило: нижний регистр не совпадает
    Assert.IsTrue(GProfileManager.IsWindowAllowed('any.exe', '', 'host prod-123'));
    Assert.IsFalse(GProfileManager.IsWindowAllowed('any.exe', '', 'host PROD-123'));
    // Нестрогое: регистр не важен
    Assert.IsFalse(GProfileManager.IsWindowAllowed('any.exe', '', 'host Staging-9'));
end;

procedure TWindowMonitorTests.TryIsWindowAllowed_ReportsMatchedRule;
var
    Rules: TArray<TGlobalTitleDenyRule>;
    DenyRule: string;
begin
    SetLength(Rules, 2);
    Rules[0] := Default(TGlobalTitleDenyRule);
    Rules[0].Name := 'Prod Servers';
    Rules[0].Pattern := 'prod-';
    Rules[0].Enabled := True;
    Rules[1] := Default(TGlobalTitleDenyRule);
    Rules[1].Pattern := 'unnamed-\d+';
    Rules[1].Enabled := True;
    GProfileManager.SetGlobalDenyRules(Rules);

    // Разрешено - имя правила пустое
    Assert.IsTrue(GProfileManager.TryIsWindowAllowed('any.exe', '', 'dev host', DenyRule));
    Assert.AreEqual('', DenyRule);

    // Именованное правило: показывается имя
    Assert.IsFalse(GProfileManager.TryIsWindowAllowed('any.exe', '', 'prod-42', DenyRule));
    Assert.AreEqual('Prod Servers', DenyRule);

    // Безымянное правило: показывается Pattern
    Assert.IsFalse(GProfileManager.TryIsWindowAllowed('any.exe', '', 'unnamed-7', DenyRule));
    Assert.AreEqual('unnamed-\d+', DenyRule);
end;

{ TProcessProfileFilterTests }

procedure TProcessProfileFilterTests.EvaluateWindowFilters_DisabledProfile_ReturnsDisabled;
begin
    Assert.IsTrue(TProcessProfile.EvaluateWindowFilters(False, 'secret', 'prod',
        ['PuTTY'], 'PuTTY', 'prod host') = wfrDisabled,
        'Disabled profile must bypass all filters');
end;

procedure TProcessProfileFilterTests.EvaluateWindowFilters_NoFilters_PassesAnyWindow;
begin
    Assert.IsTrue(TProcessProfile.EvaluateWindowFilters(True, '', '', nil,
        'AnyClass', 'Any Title') = wfrPass, 'Empty filters must pass any window');
end;

procedure TProcessProfileFilterTests.EvaluateWindowFilters_TitleInclude_MismatchBlocks;
begin
    Assert.IsTrue(TProcessProfile.EvaluateWindowFilters(True, 'secret', '', nil,
        'PuTTY', 'prod host') = wfrBlockedByInclude,
        'Non-matching include must block');
end;

procedure TProcessProfileFilterTests.EvaluateWindowFilters_TitleExclude_MatchBlocks;
begin
    Assert.IsTrue(TProcessProfile.EvaluateWindowFilters(True, '', 'prod', nil,
        'PuTTY', 'prod host') = wfrBlockedByExclude,
        'Matching exclude must block');
end;

procedure TProcessProfileFilterTests.EvaluateWindowFilters_ClassList_MismatchBlocks;
begin
    { Регрессия инцидента: класс CMoTTY из KiTTY не матчится с реальным
      классом MobaXterm - окно должно блокироваться именно классом }
    Assert.IsTrue(TProcessProfile.EvaluateWindowFilters(True, '', '', ['CMoTTY'],
        'TMobaXtermForm', 'user@host') = wfrBlockedByClass,
        'Unknown window class must be blocked by class filter');
end;

procedure TProcessProfileFilterTests.EvaluateWindowFilters_ClassList_EmptyListPassesAnyClass;
begin
    Assert.IsTrue(TProcessProfile.EvaluateWindowFilters(True, '', '', nil,
        'TMobaXtermForm', 'user@host') = wfrPass,
        'Empty class list must pass any class');
end;

procedure TProcessProfileFilterTests.EvaluateWindowFilters_ClassList_CaseInsensitiveMatch;
begin
    Assert.IsTrue(TProcessProfile.EvaluateWindowFilters(True, '', '', ['putty'],
        'PuTTY', 'host') = wfrPass, 'Class match must be case-insensitive');
end;

procedure TProcessProfileFilterTests.MatchesWindow_AgreesWithEvaluateWindowFilters;
var
    Profile: TProcessProfile;
begin
    Profile := TProcessProfile.Create('test.exe');
    try
        Profile.SetWindowClasses(['CMoTTY']);

        // Гейт (MatchesWindow) и хелпер обязаны давать одинаковый вердикт
        Assert.IsFalse(Profile.MatchesWindow('TMobaXtermForm', 'user@host'),
            'Gate must block unknown class');
        Assert.IsTrue(TProcessProfile.EvaluateWindowFilters(True,
            Profile.TitleIncludeRegex, Profile.TitleExcludeRegex,
            Profile.WindowClasses, 'TMobaXtermForm', 'user@host') = wfrBlockedByClass,
            'Helper must report the same block');
        Assert.IsTrue(Profile.MatchesWindow('CMoTTY', 'user@host'),
            'Gate must pass known class');
    finally
        Profile.Free;
    end;
end;

procedure TProcessProfileFilterTests.FindClassHiddenApps_DetectsStaleClassFilter;
var
    Apps: TArray<TAllowedApplicationsItem>;
    Raw: TArray<TWindowMonitorInfo>;
    Hidden: TArray<TClassHiddenApp>;
begin
    SetLength(Apps, 1);
    Apps[0] := Default(TAllowedApplicationsItem);
    Apps[0].ExeName := 'mobaxterm.exe';
    Apps[0].Enabled := True;
    Apps[0].WindowClasses := ['CMoTTY'];

    SetLength(Raw, 2);
    Raw[0] := Default(TWindowMonitorInfo);
    Raw[0].ExeName := 'mobaxterm.exe';
    Raw[0].WindowClass := 'TMobaXtermForm';
    Raw[0].WindowTitle := 'user@host';
    Raw[1] := Default(TWindowMonitorInfo);
    Raw[1].ExeName := 'notepad.exe';
    Raw[1].WindowClass := 'Notepad';
    Raw[1].WindowTitle := 'notes';

    Hidden := FindClassHiddenApps(Apps, Raw);
    Assert.AreEqual<Integer>(1, Length(Hidden), 'Stale class filter must be detected');
    Assert.AreEqual('mobaxterm.exe', Hidden[0].ExeName);
    Assert.AreEqual('TMobaXtermForm', Hidden[0].RealClasses[0]);
end;

procedure TProcessProfileFilterTests.FindClassHiddenApps_SkipsDisabledEmptyAndMatching;
var
    Apps: TArray<TAllowedApplicationsItem>;
    Raw: TArray<TWindowMonitorInfo>;
    Hidden: TArray<TClassHiddenApp>;
begin
    SetLength(Apps, 3);

    // Выключенное приложение с мусорным класс-фильтром - не проверяется
    Apps[0] := Default(TAllowedApplicationsItem);
    Apps[0].ExeName := 'disabled.exe';
    Apps[0].Enabled := False;
    Apps[0].WindowClasses := ['NoSuchClass'];

    // Пустой класс-фильтр: скрывать нечего
    Apps[1] := Default(TAllowedApplicationsItem);
    Apps[1].ExeName := 'empty.exe';
    Apps[1].Enabled := True;

    // Класс-фильтр совпадает с реальным окном
    Apps[2] := Default(TAllowedApplicationsItem);
    Apps[2].ExeName := 'putty.exe';
    Apps[2].Enabled := True;
    Apps[2].WindowClasses := ['PuTTY'];

    SetLength(Raw, 2);
    Raw[0] := Default(TWindowMonitorInfo);
    Raw[0].ExeName := 'disabled.exe';
    Raw[0].WindowClass := 'RealClass';
    Raw[0].WindowTitle := 't1';
    Raw[1] := Default(TWindowMonitorInfo);
    Raw[1].ExeName := 'putty.exe';
    Raw[1].WindowClass := 'PuTTY';
    Raw[1].WindowTitle := 't2';

    Hidden := FindClassHiddenApps(Apps, Raw);
    Assert.AreEqual<Integer>(0, Length(Hidden),
        'Disabled, empty-filter and matching apps must be skipped');
end;

end.
