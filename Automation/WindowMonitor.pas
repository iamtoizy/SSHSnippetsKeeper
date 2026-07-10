unit WindowMonitor;

interface

uses
    Winapi.Windows,
    System.SysUtils,
    ArrayHelper;

type
    TWindowMonitorInfo = record
        HWND: THandle;
        PID: DWORD;
        ExePath: string;
        ExeName: string;
        WindowTitle: string;
        ActivatedAt: TDateTime;
    end;

    TWindowMonitor = class
    private
        FAllowedWindowHistory: TArrayRecord<TWindowMonitorInfo>;
        FWinEventHook: THandle;
        FAllowedProcesses: TArrayRecord<string>;

        function GetWindowInfo(HWND: THandle): TWindowMonitorInfo;
        function IsProcessAllowed(const ExeName: string): Boolean;
        procedure AddToHistory(WindowInfo: TWindowMonitorInfo);
        procedure RemoveFromHistory(HWND: THandle);
        procedure CleanupInvalidWindows;
        function GetAllowedWindowCount: Integer;
    public
        constructor Create;
        destructor Destroy; override;

        function GetLastAllowedWindow: TWindowMonitorInfo;
        function GetAllowedWindowsHistory: TArray<TWindowMonitorInfo>;
        function GetCurrentForegroundWindow: TWindowMonitorInfo;
        function CanAutoType: Boolean;
        function ActivateWindow(AWindowInfo: TWindowMonitorInfo): Boolean;

        procedure AddAllowedProcess(const ExeName: string);
        procedure RemoveAllowedProcess(const ExeName: string);
        procedure ClearAllowedProcesses;

        procedure StartMonitoring;
        procedure StopMonitoring;

        property AllowedWindowCount: Integer read GetAllowedWindowCount;

    end;

var
    WinMonitor: TWindowMonitor;

procedure WinEventProc(hWinEventHook: THandle; eventType: DWORD; HWND: THandle; idObject, idChild: LONG; dwEventThread, dwmsEventTime: DWORD); stdcall;

implementation

const
    PROCESS_QUERY_LIMITED_INFORMATION = $1000;
    MAX_HISTORY_SIZE = 50;  // Храним только последние 50 окон

function QueryFullProcessImageName(hProcess: THandle; dwFlags: DWORD; lpExeName: PWideChar; var lpdwSize: DWORD): BOOL; stdcall; external 'kernel32' name 'QueryFullProcessImageNameW';

function GetExeNameFromHWND(AHWND: THandle): string;
var
    PID: DWORD;
    hProcess: THandle;
    Buffer: array[0..MAX_PATH] of Char;
    dwSize: DWORD;
begin
    Result := '';
    if (AHWND = 0) or (not IsWindow(AHWND)) then
        Exit;

    GetWindowThreadProcessId(AHWND, @PID);
    if PID = 0 then
        Exit;

    hProcess := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, PID);
    if hProcess <> 0 then
    begin
        try
            FillChar(Buffer, SizeOf(Buffer), 0);
            dwSize := MAX_PATH;
            if QueryFullProcessImageName(hProcess, 0, Buffer, dwSize) then
                Result := LowerCase(ExtractFileName(Buffer));
        finally
            CloseHandle(hProcess);
        end;
    end;
end;

{ Глобальный колбэк - ведёт историю разрешённых окон }
procedure WinEventProc(hWinEventHook: THandle; eventType: DWORD; HWND: THandle; idObject, idChild: LONG; dwEventThread, dwmsEventTime: DWORD); stdcall;
var
    ExeName: string;
    WindowMonitorInfo: TWindowMonitorInfo;
begin
    if (eventType <> EVENT_SYSTEM_FOREGROUND) or (HWND = 0) then
        Exit;

    if not IsWindowVisible(HWND) then
        Exit;

    ExeName := GetExeNameFromHWND(HWND);
    if ExeName = '' then
        Exit;

    // Добавляем в историю ТОЛЬКО разрешённые процессы
    if Assigned(WinMonitor) and WinMonitor.IsProcessAllowed(ExeName) then
    begin
        WindowMonitorInfo := WinMonitor.GetWindowInfo(HWND);
        WindowMonitorInfo.ActivatedAt := Now;
        WinMonitor.AddToHistory(WindowMonitorInfo);

        {$IFDEF DEBUG}
        OutputDebugString(PChar(Format('[WinMonitor] Added to history: HWND=%d, Exe=%s, Title=%s', [HWND, ExeName, WindowMonitorInfo.WindowTitle])));
        {$ENDIF}
    end
    else
    begin
        {$IFDEF DEBUG}
        OutputDebugString(PChar(Format('[WinMonitor] Ignored: HWND=%d, Exe=%s', [HWND, ExeName])));
        {$ENDIF}
    end;
end;

{ TWindowMonitor }

constructor TWindowMonitor.Create;
begin
    inherited Create;
    FWinEventHook := 0;
end;

destructor TWindowMonitor.Destroy;
begin
    StopMonitoring;
    inherited;
end;

procedure TWindowMonitor.AddToHistory(WindowInfo: TWindowMonitorInfo);
var
    I: Integer;
    ExistingWindow: TWindowMonitorInfo;
begin
    // Проверяем, есть ли это окно уже в истории
    for I := 0 to FAllowedWindowHistory.Count - 1 do
    begin
        ExistingWindow := FAllowedWindowHistory[I];
        if ExistingWindow.HWND = WindowInfo.HWND then
        begin
            // Окно уже в истории - удаляем его
            FAllowedWindowHistory.Delete(I);
            Break;
        end;
    end;

    // Добавляем в конец списка
    FAllowedWindowHistory.Add(WindowInfo);

    // Удаляем старые записи, если превышен лимит
    while FAllowedWindowHistory.Count > MAX_HISTORY_SIZE do
    begin
        {$IFDEF DEBUG}
        OutputDebugString(PChar(Format('[WinMonitor] Removed old entry: HWND=%d', [FAllowedWindowHistory[0].HWND])));
        {$ENDIF}
        FAllowedWindowHistory.Delete(0);  // Удаляем самое старое
    end;

    {$IFDEF DEBUG}
    OutputDebugString(PChar(Format('[WinMonitor] History size: %d', [FAllowedWindowHistory.Count])));
    {$ENDIF}
end;

procedure TWindowMonitor.RemoveFromHistory(HWND: THandle);
var
    I: Integer;
begin
    for I := FAllowedWindowHistory.Count - 1 downto 0 do
    begin
        if FAllowedWindowHistory[I].HWND = HWND then
        begin
            FAllowedWindowHistory.Delete(I);
            Break;
        end;
    end;
end;

procedure TWindowMonitor.CleanupInvalidWindows;
var
    I: Integer;
begin
    // Удаляем из истории окна, которые больше не существуют
    for I := FAllowedWindowHistory.Count - 1 downto 0 do
    begin
        if not IsWindow(FAllowedWindowHistory[I].HWND) then
        begin
            {$IFDEF DEBUG}
            OutputDebugString(PChar(Format('[WinMonitor] Removed invalid window: HWND=%d', [FAllowedWindowHistory[I].HWND])));
            {$ENDIF}
            FAllowedWindowHistory.Delete(I);
        end;
    end;
end;

function TWindowMonitor.IsProcessAllowed(const ExeName: string): Boolean;
var
    Process: string;
begin
    Result := False;
    for Process in FAllowedProcesses do
    begin
        if SameText(Process, ExeName) then
            Exit(True);
    end;
end;

procedure TWindowMonitor.AddAllowedProcess(const ExeName: string);
begin
    if not FAllowedProcesses.Contains(LowerCase(ExeName)) then
        FAllowedProcesses.Add(LowerCase(ExeName));
end;

procedure TWindowMonitor.RemoveAllowedProcess(const ExeName: string);
begin
    FAllowedProcesses.Remove(LowerCase(ExeName));
end;

procedure TWindowMonitor.ClearAllowedProcesses;
begin
    FAllowedProcesses.Clear;
end;

function TWindowMonitor.GetWindowInfo(HWND: THandle): TWindowMonitorInfo;
var
    hProcess: THandle;
    Buffer: array[0..MAX_PATH] of Char;
    TitleBuffer: array[0..1023] of Char;
    dwSize: DWORD;
begin
    Result.HWND := HWND;
    Result.PID := 0;
    Result.ExePath := '';
    Result.ExeName := '';
    Result.WindowTitle := '';
    Result.ActivatedAt := 0;

    if (HWND = 0) or (not IsWindow(HWND)) then
        Exit;

    GetWindowText(HWND, TitleBuffer, SizeOf(TitleBuffer) div SizeOf(Char));
    Result.WindowTitle := TitleBuffer;

    GetWindowThreadProcessId(HWND, @Result.PID);
    if Result.PID = 0 then
        Exit;

    hProcess := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, Result.PID);
    if hProcess <> 0 then
    begin
        try
            FillChar(Buffer, SizeOf(Buffer), 0);
            dwSize := MAX_PATH;
            if QueryFullProcessImageName(hProcess, 0, Buffer, dwSize) then
            begin
                Result.ExePath := Buffer;
                Result.ExeName := ExtractFileName(Result.ExePath);
            end;
        finally
            CloseHandle(hProcess);
        end;
    end;
end;

function TWindowMonitor.GetLastAllowedWindow: TWindowMonitorInfo;
begin
    // Сначала чистим историю от закрытых окон
    CleanupInvalidWindows;

    // Возвращаем последний элемент истории (самый недавний)
    if FAllowedWindowHistory.Count > 0 then
        Result := FAllowedWindowHistory[FAllowedWindowHistory.Count - 1]
    else
    begin
        Result.HWND := 0;
        Result.PID := 0;
        Result.ExePath := '';
        Result.ExeName := '';
        Result.WindowTitle := '';
        Result.ActivatedAt := 0;
    end;
end;

function TWindowMonitor.GetAllowedWindowsHistory: TArray<TWindowMonitorInfo>;
begin
    // Чистим историю перед возвратом
    CleanupInvalidWindows;
    Result := FAllowedWindowHistory.Items;
end;

function TWindowMonitor.GetAllowedWindowCount: Integer;
begin
    CleanupInvalidWindows;
    Result := FAllowedWindowHistory.Count;
end;

function TWindowMonitor.GetCurrentForegroundWindow: TWindowMonitorInfo;
begin
    Result := GetWindowInfo(GetForegroundWindow);
end;

function TWindowMonitor.CanAutoType: Boolean;
var
    LastWindow: TWindowMonitorInfo;
begin
    CleanupInvalidWindows;

    // Можно вводить, если в истории есть хотя бы одно разрешённое окно
    Result := FAllowedWindowHistory.Count > 0;

    if Result then
    begin
        LastWindow := GetLastAllowedWindow;
        {$IFDEF DEBUG}
        OutputDebugString(PChar(Format('[WinMonitor] CanAutoType: YES, Target=%s (HWND=%d)', [LastWindow.ExeName, LastWindow.HWND])));
        {$ENDIF}
    end
    else
        {$IFDEF DEBUG}
        OutputDebugString('[WinMonitor] CanAutoType: NO, No allowed windows in history');
        {$ENDIF}
end;

function TWindowMonitor.ActivateWindow(AWindowInfo: TWindowMonitorInfo): Boolean;
var
    ForegroundThread, CurrentThread: DWORD;
begin
    Result := False;

    if (AWindowInfo.HWND = 0) or (not IsWindow(AWindowInfo.HWND)) then
        Exit;

    // Если окно свёрнуто - восстанавливаем
    if IsIconic(AWindowInfo.HWND) then
        ShowWindow(AWindowInfo.HWND, SW_RESTORE);

    // Попытка 1: стандартная активация
    SetForegroundWindow(AWindowInfo.HWND);

    if GetForegroundWindow = AWindowInfo.HWND then
        Exit(True);

    // Попытка 2: через AttachThreadInput (для обхода ограничений Windows)
    ForegroundThread := GetWindowThreadProcessId(GetForegroundWindow, nil);
    CurrentThread := GetCurrentThreadId;

    if ForegroundThread <> CurrentThread then
    begin
        AttachThreadInput(ForegroundThread, CurrentThread, True);
        try
            SetForegroundWindow(AWindowInfo.HWND);
            BringWindowToTop(AWindowInfo.HWND);
        finally
            AttachThreadInput(ForegroundThread, CurrentThread, False);
        end;
    end
    else
    begin
        SetForegroundWindow(AWindowInfo.HWND);
        BringWindowToTop(AWindowInfo.HWND);
    end;

    Sleep(50);
    Result := (GetForegroundWindow = AWindowInfo.HWND);

    if Result then
        {$IFDEF DEBUG}
        OutputDebugString(PChar(Format('[WinMonitor] Activated: %s (HWND=%d)', [AWindowInfo.ExeName, AWindowInfo.HWND])))
        {$ENDIF}
    else
        {$IFDEF DEBUG}
        OutputDebugString(PChar(Format('[WinMonitor] Failed to activate: HWND=%d', [AWindowInfo.HWND])));
        {$ENDIF}
end;

procedure TWindowMonitor.StartMonitoring;
begin
    if FWinEventHook <> 0 then
        Exit;

    FWinEventHook := SetWinEventHook(EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, 0, @WinEventProc, 0, 0, WINEVENT_OUTOFCONTEXT or WINEVENT_SKIPOWNPROCESS);

    if FWinEventHook = 0 then
        raise Exception.Create('Не удалось установить WinEventHook. Ошибка: ' + SysErrorMessage(GetLastError));

    // Добавляем текущее окно в историю, если оно разрешено
    if IsProcessAllowed(GetExeNameFromHWND(GetForegroundWindow)) then
    begin
        var WindowMonitorInfo := GetWindowInfo(GetForegroundWindow);
        WindowMonitorInfo.ActivatedAt := Now;
        AddToHistory(WindowMonitorInfo);
    end;
end;

procedure TWindowMonitor.StopMonitoring;
begin
    if FWinEventHook <> 0 then
    begin
        UnhookWinEvent(FWinEventHook);
        FWinEventHook := 0;
    end;
end;

initialization
    WinMonitor := TWindowMonitor.Create;


finalization
    WinMonitor.Free;

end.

