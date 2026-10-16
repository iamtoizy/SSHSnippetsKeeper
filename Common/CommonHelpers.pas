unit CommonHelpers;

interface

uses
    Core.Interfaces,
    System.Classes,
    System.Generics.Collections,
    System.Generics.Defaults,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.Menus,
    Vcl.StdCtrls,
    System.SysUtils
    ;

type
    // ����������� �����-�������� ��� ������ � �������� ����� (MRU)
    THistoryHelper = class
    public
        class procedure Add(var History: TArray<THistoryItem>; const NewValue: string; MaxItems: Integer = 15);
    end;

{ �������� ����-����������� }
procedure ShowSimpleToast(const Text: string; const Title: string = '');
{ ����� ����������� ����� ������������ ��� �� (��� TUIStateLoader � SQLite) }
function ResolvePath(const PathName: string; IsDirectory: Boolean = False): string;
{ ��������� ������� ����� ��� �������� ��������/���������� }
function GetDefaultDataDir: string;
{ ���������� �������� ����������� TListView }
procedure WipeListViewPasswords(ListView: TListView);
{ ���������� �������� ����������� TCustomEdit }
procedure WipeVCLControlText(Control: TCustomEdit);
{ ��������� ����� ������ ������ }
procedure SecureZeroMemory(Ptr: Pointer; Size: NativeUInt);
{ ���������� ����������� � ����� ������ }
procedure CopyToClipboardSecure(const Text: string);
{ ���������� ����������� ��������� ����� � RAM }
procedure WipeString(var S: string);
{ ����������� �� Win32 (RegisterHotKey) � VCL (THotKey) }
procedure Win32HotkeyToVCL(const Config: THotkeyConfig; HotKeyCtrl: THotKey);
{ ����������� �� VCL (THotKey) � Win32 (RegisterHotKey) }
function VCLHotkeyToWin32(HotKeyCtrl: THotKey; Enabled: Boolean = True): THotkeyConfig;
{ �������������� ���������� � �������� ������ ��� ���������� (�������� "Ctrl + Alt + Q") }
function HotkeyToString(const Config: THotkeyConfig): string;
{ ������� ��� ��������� ��������� Basic Auth }
function GenerateHtpasswdString(const Username, Password: string): string;
{ ������ pip }
function RunCmdCommand(const WorkingDir, Command: string; out Output: string; TimeoutMs: Cardinal = 300000): Boolean;
{ Single point of logging: appends a timestamped line to the log file }
procedure LogMsg(const Msg: string);
{ Logs an exception (class + message) with the given operation context }
procedure LogException(const Context: string; E: Exception);

implementation

uses
    System.IOUtils,
    System.Hash,
    System.NetEncoding,
    System.Notification,
    System.SyncObjs,
    UI.StateLoader,
    Vcl.Clipbrd,
    Winapi.Windows
    ;

var
    NotificationCenter: TNotificationCenter;
    GLogLock: TCriticalSection;

{ �������� ����-����������� }
procedure ShowSimpleToast(const Text: string; const Title: string = '');
var
    Notification: TNotification;
begin
    if NotificationCenter.Supported then
    begin
        Notification := NotificationCenter.CreateNotification;
        try
            Notification.Name := 'SnippetNotification';
            if (Title.IsEmpty) then
                Notification.Title := TUIStateLoader.GetMessage('Common.NotificationDefaultCaption')
            else
                Notification.Title := Title;
            Notification.AlertBody := Text;
            NotificationCenter.PresentNotification(Notification);
        finally
            Notification.Free;
        end;
    end;
end;

{ ����� ����������� ����� ������������ ��� �� (��� TUIStateLoader � SQLite) }
function ResolvePath(const PathName: string; IsDirectory: Boolean = False): string;
var
    ExePath, DevPath, TargetDir: string;

    function NonEmptyDirOrFileExists(const APath: string): Boolean;
    begin
        if IsDirectory then
            // ����� ���������� � � ��� ���� �����
            Result := DirectoryExists(APath) and (Length(TDirectory.GetFileSystemEntries(APath)) > 0)
        else
            Result := FileExists(APath);
    end;
begin
    ExePath := ExtractFilePath(ParamStr(0));

    // 1. ��������� ����� � ������������ (����� � .exe)
    Result := TPath.Combine(ExePath, PathName);
    if NonEmptyDirOrFileExists(Result) then
        Exit;

    // 2. ���� � ����� ������������ (Assets\ExeData\...)
    DevPath := ExpandFileName(TPath.Combine(ExePath, '..\..\..\Assets\ExeData'));
    DevPath := TPath.Combine(DevPath, PathName);
    if NonEmptyDirOrFileExists(DevPath) then
    begin
        Result := DevPath;
        Exit;
    end;

    // 3. ���� ������ �� �����, ���������� ���� ����� � .exe
    Result := TPath.Combine(ExePath, PathName);
    if IsDirectory then
        TargetDir := Result
    else
        TargetDir := ExtractFilePath(Result);

    if not TargetDir.IsEmpty and not DirectoryExists(TargetDir) then
        ForceDirectories(TargetDir);
end;

{ ��������� ������� ����� ��� �������� ��������/���������� }
function GetDefaultDataDir: string;
var
    ExePath, DevPath: string;
begin
    ExePath := ExtractFilePath(ParamStr(0));

    // ��������� ���� � ����� ������������
    DevPath := ExpandFileName(TPath.Combine(ExePath, '..\..\..\Assets\ExeData'));

    // ���������, ���������� �� ����� ���������� (� �� ����)
    if TDirectory.Exists(DevPath) then
        Result := DevPath
    else
        Result := ExePath; // ���� ����� ���, ���������� ���������� � .exe
end;

procedure WipeListViewPasswords(ListView: TListView);
var
    I: Integer;
    S: string;
    P: Pointer;
begin
    if not Assigned(ListView) then Exit;

    // ����������� �� ���� ������� �������
    for I := 0 to ListView.Items.Count - 1 do
    begin
        // ������ �������� �� ������ ������� (������ 1)
        if ListView.Items[I].SubItems.Count > 1 then
        begin
            // �������� ������ ������ �� ���� ������ �� �������
            S := ListView.Items[I].SubItems[1];
            if S <> '' then
            begin
                // ����� ������ ��������� �� ������ ������
                P := PChar(S);
                // ��������� �������� ����� � ���� (heap) ������.
                // ��������� �� ���������� �� ���������, �� "������" ������
                // ����� ������ ����� ��������� TListView!
                SecureZeroMemory(P, Length(S) * SizeOf(Char));
            end;
        end;
    end;

    // ������, ����� � ������ ������� ����� ������ ����, ����� ���������
    // ������ ��� ����� ������� �������
    ListView.Items.Clear;
end;

procedure WipeVCLControlText(Control: TCustomEdit);
begin
    if not Assigned(Control) or (Control.GetTextLen = 0) then Exit;
    // ��������� �������������� ������� ������ �������� ������,
    // ������ ��� ���������� ������
    Control.Text := StringOfChar('0', Control.GetTextLen);
    Control.Text := '';
end;

procedure SecureZeroMemory(Ptr: Pointer; Size: NativeUInt);
begin
    // �� ����� �� �������� ���������� �������?
    if (Ptr <> nil) and (Size > 0) then
        FillChar(Ptr^, Size, 0);
end;

procedure CopyToClipboardSecure(const Text: string);
var
    ExcludeFormat: UINT;
    MemBlock: HGLOBAL;
begin
    // 1. ������������ ����. ������ Windows 10/11 ��� �������� ������� ������ ������ (Win+V)
    // ����� ���������� �������� ������ ������ (� ���� ��) ������������� ���� �����
    ExcludeFormat := RegisterClipboardFormat('ExcludeClipboardContentFromMonitor');

    Vcl.Clipbrd.Clipboard.Open;
    try
        Vcl.Clipbrd.Clipboard.AsText := Text;

        // ������� ������� �� ����� ��� ����� �����������
        if ExcludeFormat <> 0 then
        begin
            MemBlock := GlobalAlloc(GMEM_MOVEABLE or GMEM_ZEROINIT, 1);
            if MemBlock <> 0 then
                SetClipboardData(ExcludeFormat, MemBlock);
        end;
    finally
        Vcl.Clipbrd.Clipboard.Close;
    end;
end;

procedure WipeString(var S: string);
begin
    // StringRefCount ���������� -1 ��� ��������� �������� (��������� � ����).
    // ������� �������� ��������� ������� ���� (Access Violation).
    if (S <> '') and (StringRefCount(S) = 1) then
    begin
        // ��������� �������� ������������ ���� ������ ������
        SecureZeroMemory(PChar(S), Length(S) * SizeOf(Char));
    end;
    S := ''; // �������� ���������
end;

procedure LogMsg(const Msg: string);
begin
    if not Assigned(GLogLock) then
        Exit;
    try
        GLogLock.Enter;
        try
            TFile.AppendAllText(
                ResolvePath('SSHSnippetsKeeper.log'),
                FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' [TID ' +
                IntToStr(GetCurrentThreadId) + '] ' + Msg + sLineBreak,
                TEncoding.UTF8);
        finally
            GLogLock.Leave;
        end;
    except
        // Logging must never raise
    end;
end;

procedure LogException(const Context: string; E: Exception);
begin
    if E = nil then
        Exit;
    LogMsg('EXCEPTION in ' + Context + ': ' + E.ClassName + ': ' + E.Message);
end;

{ THistoryHelper }

class procedure THistoryHelper.Add(var History: TArray<THistoryItem>; const NewValue: string; MaxItems: Integer);
var
    I: Integer;
    Found: Boolean;
begin
    if NewValue.Trim = '' then Exit;

    Found := False;
    // 1. ���� �������. ���� ����� � ����������� ���
    for I := Low(History) to High(History) do
    begin
        if SameText(History[I].Value, NewValue) then
        begin
            Inc(History[I].UseCount);
            Found := True;
            Break;
        end;
    end;

    // 2. ���� �� ����� � ��������� ����� � ����� 1
    if not Found then
    begin
        SetLength(History, Length(History) + 1);
        History[High(History)].Value := NewValue;
        History[High(History)].UseCount := 1;
    end;

    // 3. ��������� ������ �� ���� (UseCount) �� �������� (�� ������ � ������)
    TArray.Sort<THistoryItem>(History, TComparer<THistoryItem>.Construct(
        function(const Left, Right: THistoryItem): Integer
        begin
            Result := Right.UseCount - Left.UseCount; // ���������� �� ��������
        end));

    // 4. ������������ ������ ������� (�������� ����� �� ����� ������)
    if Length(History) > MaxItems then
        SetLength(History, MaxItems);
end;

procedure Win32HotkeyToVCL(const Config: THotkeyConfig; HotKeyCtrl: THotKey);
var
    ShiftState: TShiftState;
begin
    ShiftState := [];
    // �������� ����������� VCL TShiftState �� Win32 ������
    if (Config.Modifiers and MOD_ALT) <> 0 then
        Include(ShiftState, ssAlt);
    if (Config.Modifiers and MOD_CONTROL) <> 0 then
        Include(ShiftState, ssCtrl);
    if (Config.Modifiers and MOD_SHIFT) <> 0 then
        Include(ShiftState, ssShift);

    // Vcl.Menus.ShortCut ��� ������� ���������� Integer (TShortCut),
    // � ��������� THotKey ������������� ������� ���� ���������� Modifiers
    HotKeyCtrl.HotKey := Vcl.Menus.ShortCut(Config.Key, ShiftState);
end;

function VCLHotkeyToWin32(HotKeyCtrl: THotKey; Enabled: Boolean = True): THotkeyConfig;
var
    Key: Word;
    ShiftState: TShiftState;
    WinModifiers: Cardinal;
begin
    // ���������� TShortCut ������� �� ������ � ����������� TShiftState
    Vcl.Menus.ShortCutToKey(HotKeyCtrl.HotKey, Key, ShiftState);

    WinModifiers := 0;
    // �������� ����� Win32
    if ssAlt in ShiftState then
        WinModifiers := WinModifiers or MOD_ALT;
    if ssCtrl in ShiftState then
        WinModifiers := WinModifiers or MOD_CONTROL;
    if ssShift in ShiftState then
        WinModifiers := WinModifiers or MOD_SHIFT;

    Result.Modifiers := WinModifiers;
    Result.Key := Key;
    Result.Enabled := Enabled and (Result.Key <> 0);
end;

function HotkeyToString(const Config: THotkeyConfig): string;
var
    Parts: string;
    KeyName: array[0..31] of Char;
    ScanCode: UINT;
begin
    if not Config.Enabled or (Config.Key = 0) then
        Exit('���');

    Parts := '';
    if (Config.Modifiers and MOD_CONTROL) <> 0 then Parts := Parts + 'Ctrl + ';
    if (Config.Modifiers and MOD_ALT) <> 0 then Parts := Parts + 'Alt + ';
    if (Config.Modifiers and MOD_SHIFT) <> 0 then Parts := Parts + 'Shift + ';
    if (Config.Modifiers and MOD_WIN) <> 0 then Parts := Parts + 'Win + ';

    ScanCode := MapVirtualKey(Config.Key, MAPVK_VK_TO_VSC);
    if GetKeyNameText(ScanCode shl 16, KeyName, Length(KeyName)) > 0 then
        Parts := Parts + string(KeyName)
    else
        Parts := Parts + Chr(Config.Key);

    Result := Parts;
end;

function GenerateHtpasswdString(const Username, Password: string): string;
var
    HashBytes: TBytes;
    Base64Str: string;
begin
    // 1. �������� SHA-1 ��� �� ������ � ���� "�����" ������ (�� HEX-������!)
    HashBytes := THashSHA1.GetHashBytes(Password);

    // 2. �������� ��� ����� � ����������� Base64
    Base64Str := TNetEncoding.Base64.EncodeBytesToString(HashBytes);

    // 3. �� ������ ������ ������� ��������� �������� ����� (Base64 ������ �� ���������)
    Base64Str := Base64Str.Replace(#13#10, '', [rfReplaceAll]);

    // 4. ���������� ������� ������ ��� ������� � ���� .htpasswd
    Result := Format('%s:{SHA}%s', [Username, Base64Str]);
end;

function RunCmdCommand(const WorkingDir, Command: string; out Output: string; TimeoutMs: Cardinal): Boolean;
var
    SecurityAttr: TSecurityAttributes;
    ReadPipe, WritePipe: THandle;
    StartInfo: TStartupInfo;
    ProcInfo: TProcessInformation;
    Buffer: array[0..2047] of AnsiChar;
    BytesRead, BytesAvail: DWORD;
    FullCommand: string;
    WorkDirPtr: PChar;
    StartTime: DWORD;
    WaitResult: DWORD;
begin
    Result := False;
    Output := '';

    FillChar(SecurityAttr, SizeOf(SecurityAttr), 0);
    SecurityAttr.nLength := SizeOf(SecurityAttr);
    SecurityAttr.bInheritHandle := True;

    // 1. Создаем Pipe
    if not CreatePipe(ReadPipe, WritePipe, @SecurityAttr, 0) then
        Exit;

    FillChar(StartInfo, SizeOf(StartInfo), 0);
    StartInfo.cb := SizeOf(StartInfo);
    StartInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
    StartInfo.wShowWindow := SW_HIDE; // Скрываем окно
    StartInfo.hStdOutput := WritePipe;
    StartInfo.hStdError := WritePipe; // Перенаправляем ошибки в тот же поток

    // Формируем команду для cmd
    FullCommand := 'cmd.exe /c ' + Command;

    // Устанавливаем рабочую директорию
    if WorkingDir <> '' then
        WorkDirPtr := PChar(WorkingDir)
    else
        WorkDirPtr := nil;

    // 2. Запускаем процесс
    if CreateProcess(nil, PChar(FullCommand), nil, nil, True, CREATE_NO_WINDOW, nil, WorkDirPtr, StartInfo, ProcInfo) then
    begin
        // Обязательно закрываем WritePipe со стороны родителя, иначе ReadFile может заблокироваться
        CloseHandle(WritePipe);

        StartTime := GetTickCount;
        Result := True;

        // 3. Главный цикл: чтение + проверка таймаута + проверка состояния процесса
        while True do
        begin
            // Проверка таймаута (Cardinal-арифметика защищает от переполнения GetTickCount)
            if (TimeoutMs <> INFINITE) and (Cardinal(GetTickCount - StartTime) > TimeoutMs) then
            begin
                TerminateProcess(ProcInfo.hProcess, UINT(1));
                WaitForSingleObject(ProcInfo.hProcess, 1000); // Даем время на завершение
                Result := False;
                Break;
            end;

            // Проверяем наличие данных в пайпе без блокировки потока
            BytesAvail := 0;
            if PeekNamedPipe(ReadPipe, nil, 0, nil, @BytesAvail, nil) and (BytesAvail > 0) then
            begin
                // Читаем доступные данные
                if ReadFile(ReadPipe, Buffer, SizeOf(Buffer) - 1, BytesRead, nil) and (BytesRead > 0) then
                begin
                    Buffer[BytesRead] := #0;
                    // Конвертируем вывод CMD (обычно CP866) в системную ANSI
                    OemToCharA(Buffer, Buffer);
                    Output := Output + string(AnsiString(Buffer));
                end;
            end
            else
            begin
                // Если данных пока нет, проверяем, жив ли процесс (ждем 50 мс, чтобы не грузить CPU)
                WaitResult := WaitForSingleObject(ProcInfo.hProcess, 50);

                if WaitResult = WAIT_OBJECT_0 then
                begin
                    // Процесс завершился, дочитываем остатки из пайпа, если они есть
                    while PeekNamedPipe(ReadPipe, nil, 0, nil, @BytesAvail, nil) and (BytesAvail > 0) do
                    begin
                        if ReadFile(ReadPipe, Buffer, SizeOf(Buffer) - 1, BytesRead, nil) and (BytesRead > 0) then
                        begin
                            Buffer[BytesRead] := #0;
                            OemToCharA(Buffer, Buffer);
                            Output := Output + string(AnsiString(Buffer));
                        end
                        else
                            Break;
                    end;

                    Break; // Выходим из главного цикла
                end;
            end;
        end;

        CloseHandle(ProcInfo.hProcess);
        CloseHandle(ProcInfo.hThread);
    end
    else
    begin
        // Если процесс не запустился, нужно закрыть WritePipe для предотвращения утечек
        CloseHandle(WritePipe);
    end;

    CloseHandle(ReadPipe);
end;

initialization
    NotificationCenter := TNotificationCenter.Create(nil);
    GLogLock := TCriticalSection.Create;


finalization
    FreeAndNil(NotificationCenter);
    FreeAndNil(GLogLock);

end.

