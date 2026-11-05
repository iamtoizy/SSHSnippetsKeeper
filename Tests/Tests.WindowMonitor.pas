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
    end;

implementation

uses
    System.SysUtils,
    Winapi.Windows,
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
end;

procedure TWindowMonitorTests.TearDown;
begin
    GWinMonitor.ClearAllowedProcesses;
    GWinMonitor.ClearHistory;
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

end.
