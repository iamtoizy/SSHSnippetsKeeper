unit Common.Helpers;

interface

uses
    Core.Interfaces.Settings, Core.Interfaces.Passwords,
    System.Classes,
    System.Generics.Collections,
    System.Generics.Defaults,
    System.Notification,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.Menus,
    Vcl.StdCtrls,
    System.SysUtils
    ;

type
    // Статический класс-помощник для работы с историей ввода (MRU)
    THistoryHelper = class
    public
        class procedure Add(var History: TArray<THistoryItem>; const NewValue: string; MaxItems: Integer = 15);
    end;

{ Показать тост-уведомление }
procedure ShowSimpleToast(const Text: string; const Title: string = ''; const AName: string = 'SnippetNotification');
{ Поддерживает ли система тост-уведомления }
function SimpleToastSupported: Boolean;
{ Снимает все показанные тосты и чистит кэш WinRT-уведомлений. Вызывать
  при закрытии приложения: классовый деструктор TNotificationCenterWinRT
  освобождает словарь тостов на финализации, когда Release-вызовы уже
  падают AV внутри WinRT-окружения }
procedure ShutdownToasts;
{ Подписка на клики по тост-уведомлениям (обработчик один на приложение) }
procedure SetToastNotificationHandler(Handler: TOnReceiveLocalNotification);
{ Поиск конкретного файла конфигурации или БД (Для TUIStateLoader и SQLite) }
function ResolvePath(const PathName: string; IsDirectory: Boolean = False): string;
{ Получение базовой папки для диалогов открытия/сохранения }
function GetDefaultDataDir: string;
{ Безопасное удаление содержимого TCustomEdit }
procedure WipeVCLControlText(Control: TCustomEdit);
{ Затирание блока памяти нулями }
procedure SecureZeroMemory(Ptr: Pointer; Size: NativeUInt);
{ Безопасное копирование в буфер обмена }
procedure CopyToClipboardSecure(const Text: string);
{ Безопасное уничтожение локальных строк в RAM }
procedure WipeString(var S: string);
{ Конвертация из Win32 (RegisterHotKey) в VCL (THotKey) }
procedure Win32HotkeyToVCL(const Config: THotkeyConfig; HotKeyCtrl: THotKey);
{ Конвертация из VCL (THotKey) в Win32 (RegisterHotKey) }
function VCLHotkeyToWin32(HotKeyCtrl: THotKey; Enabled: Boolean = True): THotkeyConfig;
function Win32ModifiersToShiftState(Modifiers: Cardinal): TShiftState;
{ Преобразование комбинации в красивую строку для интерфейса (например "Ctrl + Alt + Q") }
function HotkeyToString(const Config: THotkeyConfig): string;
{ Функция для генерации заголовка Basic Auth }
function GenerateHtpasswdString(const Username, Password: string): string;
{ Запуск git }
function RunCmdCommand(const WorkingDir, Command: string; out Output: string; TimeoutMs: Cardinal = 300000): Boolean;{ Логирование простых сообщений }
procedure LogMsg(const Msg: string);
{ Логирование исключений (class + message) + контекст }
procedure LogException(const Context: string; E: Exception);

implementation

uses
    System.IOUtils,
    System.Hash,
    System.NetEncoding,
    System.SyncObjs,
    Common.Localization,
    Vcl.Clipbrd,
    Winapi.Windows
    ;

var
    GNotificationCenter: TNotificationCenter;
    GLogLock: TCriticalSection;
    GLogWriteCount: Integer;

procedure ShowSimpleToast(const Text: string; const Title: string = ''; const AName: string = 'SnippetNotification');
var
    Notification: TNotification;
begin
    if GNotificationCenter.Supported then
    begin
        Notification := GNotificationCenter.CreateNotification;
        try
            Notification.Name := AName;
            if (Title.IsEmpty) then
                Notification.Title := TUIStateLoader.GetMessage('Common.NotificationDefaultCaption')
            else
                Notification.Title := Title;
            Notification.AlertBody := Text;
            GNotificationCenter.PresentNotification(Notification);
        finally
            Notification.Free;
        end;
    end;
end;

function SimpleToastSupported: Boolean;
begin
    Result := GNotificationCenter.Supported;
end;

procedure SetToastNotificationHandler(Handler: TOnReceiveLocalNotification);
begin
    GNotificationCenter.OnReceiveLocalNotification := Handler;
end;

procedure ShutdownToasts;
begin
    // На системах без поддержки тостов кэш пуст по определению,
    // а CancelAll на несозданном нотифаере безопаснее не вызывать
    if not SimpleToastSupported then
        Exit;

    GNotificationCenter.CancelAll;
end;

function ResolvePath(const PathName: string; IsDirectory: Boolean = False): string;
var
    ExePath, DevPath, TargetDir: string;

    function NonEmptyDirOrFileExists(const APath: string): Boolean;
    begin
        if IsDirectory then
            // Папка существует И в ней есть файлы
            Result := DirectoryExists(APath) and (Length(TDirectory.GetFileSystemEntries(APath)) > 0)
        else
            Result := FileExists(APath);
    end;
begin
    ExePath := ExtractFilePath(ParamStr(0));

    // 1. Проверяем папку у пользователя (рядом с .exe)
    Result := TPath.Combine(ExePath, PathName);
    if NonEmptyDirOrFileExists(Result) then
        Exit;

    // 2. Ищем в папке разработчика (Assets\ExeData\...)
    DevPath := ExpandFileName(TPath.Combine(ExePath, '..\..\..\Assets\ExeData'));
    DevPath := TPath.Combine(DevPath, PathName);
    if NonEmptyDirOrFileExists(DevPath) then
    begin
        Result := DevPath;
        Exit;
    end;

    // 3. Если ничего не нашли, возвращаем путь рядом с .exe
    Result := TPath.Combine(ExePath, PathName);
    if IsDirectory then
        TargetDir := Result
    else
        TargetDir := ExtractFilePath(Result);

    if not TargetDir.IsEmpty and not DirectoryExists(TargetDir) then
        ForceDirectories(TargetDir);
end;

function GetDefaultDataDir: string;
var
    ExePath, DevPath: string;
begin
    ExePath := ExtractFilePath(ParamStr(0));

    // Формируем путь к папке разработчика
    DevPath := ExpandFileName(TPath.Combine(ExePath, '..\..\..\Assets\ExeData'));

    // Проверяем, существует ли такая ДИРЕКТОРИЯ (а не файл)
    if TDirectory.Exists(DevPath) then
        Result := DevPath
    else
        Result := ExePath; // Если папки нет, возвращаем директорию с .exe
end;

procedure WipeVCLControlText(Control: TCustomEdit);
var
    S: string;
begin
    if not Assigned(Control) or (Control.GetTextLen = 0) then Exit;
    // Физически перезаписываем участок памяти контрола нулями,
    // прежде чем освободить строку
    S := Control.Text;
    if StringRefCount(S) = 1 then
        SecureZeroMemory(PChar(S), Length(S) * SizeOf(Char));
    Control.Text := '';
end;

procedure SecureZeroMemory(Ptr: Pointer; Size: NativeUInt);
begin
    // Не стоит ли затирать рандомными данными?
    if (Ptr <> nil) and (Size > 0) then
        FillChar(Ptr^, Size, 0);
end;

procedure CopyToClipboardSecure(const Text: string);
var
    ExcludeFormat: UINT;
    MemBlock: HGLOBAL;
begin
    // 1. Регистрируем спец. формат Windows 10/11 для пропуска истории буфера обмена (Win+V)
    // Любой нормальный менеджер буфера обмена (и сама ОС) проигнорирует этот текст
    ExcludeFormat := RegisterClipboardFormat('ExcludeClipboardContentFromMonitor');

    Vcl.Clipbrd.Clipboard.Open;
    try
        Vcl.Clipbrd.Clipboard.AsText := Text;

        // Говорим системе не вести лог этого копирования
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
    // StringRefCount возвращает -1 для строковых констант (литералов в коде).
    // Попытка затереть константу вызовет краш (Access Violation).
    if (S <> '') and (StringRefCount(S) = 1) then
    begin
        // Физически затираем оригинальный блок памяти нулями
        SecureZeroMemory(PChar(S), Length(S) * SizeOf(Char));
    end;
    S := ''; // Обнуляем указатель
end;

procedure LogMsg(const Msg: string);
const
    // Ротация: размер файла проверяем не на каждой записи, а раз в N записей
    LOG_ROTATION_CHECK_INTERVAL = 256;
    // Порог ротации: 1 МБ
    LOG_ROTATION_SIZE_LIMIT = 1 * 1024 * 1024;
var
    LogPath, OldPath: string;
begin
    if not Assigned(GLogLock) then
        Exit;
    try
        GLogLock.Enter;
        try
            LogPath := ResolvePath('SSHSnippetsKeeper.log');
            // Раз в LOG_ROTATION_CHECK_INTERVAL записей проверяем размер и
            // при превышении порога переименовываем .log в .log.old
            // (старый .log.old перезаписывается)
            Inc(GLogWriteCount);
            if GLogWriteCount >= LOG_ROTATION_CHECK_INTERVAL then
            begin
                GLogWriteCount := 0;
                try
                    if TFile.Exists(LogPath) and
                        (TFile.GetSize(LogPath) > LOG_ROTATION_SIZE_LIMIT) then
                    begin
                        OldPath := ChangeFileExt(LogPath, '.log.old');
                        if TFile.Exists(OldPath) then
                            TFile.Delete(OldPath);
                        TFile.Move(LogPath, OldPath);
                    end;
                except
                    // Не удалось проверить размер или повернуть - пишем дальше
                end;
            end;
            TFile.AppendAllText(
                LogPath,
                FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' [TID ' +
                IntToStr(GetCurrentThreadId) + '] ' + Msg + sLineBreak,
                TEncoding.UTF8);
        finally
            GLogLock.Leave;
        end;
    except
        // Никогда не выбрасываем исключения
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
    // 1. Ищем элемент. Если нашли - увеличиваем вес
    for I := Low(History) to High(History) do
    begin
        if SameText(History[I].Value, NewValue) then
        begin
            Inc(History[I].UseCount);
            Found := True;
            Break;
        end;
    end;

    // 2. Если не нашли — добавляем новый с весом 1
    if not Found then
    begin
        SetLength(History, Length(History) + 1);
        History[High(History)].Value := NewValue;
        History[High(History)].UseCount := 1;
    end;

    // 3. Сортируем массив по весу (UseCount) по убыванию (от частых к редким)
    TArray.Sort<THistoryItem>(History, TComparer<THistoryItem>.Construct(
        function(const Left, Right: THistoryItem): Integer
        begin
            Result := Right.UseCount - Left.UseCount; // Сортировка по убыванию
        end));

    // 4. Ограничиваем размер истории (обрезаем хвост из самых редких)
    if Length(History) > MaxItems then
        SetLength(History, MaxItems);
end;

function Win32ModifiersToShiftState(Modifiers: Cardinal): TShiftState;
begin
    Result := [];
    if (Modifiers and MOD_ALT) <> 0 then
        Include(Result, ssAlt);
    if (Modifiers and MOD_CONTROL) <> 0 then
        Include(Result, ssCtrl);
    if (Modifiers and MOD_SHIFT) <> 0 then
        Include(Result, ssShift);
end;

procedure Win32HotkeyToVCL(const Config: THotkeyConfig; HotKeyCtrl: THotKey);
begin
    // Vcl.Menus.ShortCut сам соберет правильный Integer (TShortCut),
    // а компонент THotKey автоматически обновит свои визуальные Modifiers
    HotKeyCtrl.HotKey := Vcl.Menus.ShortCut(Config.Key, Win32ModifiersToShiftState(Config.Modifiers));
end;

function VCLHotkeyToWin32(HotKeyCtrl: THotKey; Enabled: Boolean = True): THotkeyConfig;
var
    Key: Word;
    ShiftState: TShiftState;
    WinModifiers: Cardinal;
begin
    // Расщепляем TShortCut обратно на кнопку и стандартный TShiftState
    Vcl.Menus.ShortCutToKey(HotKeyCtrl.HotKey, Key, ShiftState);

    WinModifiers := 0;
    // Собираем флаги Win32
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
        Exit('');

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
    // 1. Получаем SHA-1 хэш от пароля в виде "сырых" байтов (не HEX-строку!)
    HashBytes := THashSHA1.GetHashBytes(Password);

    // 2. Кодируем эти байты в стандартный Base64
    Base64Str := TNetEncoding.Base64.EncodeBytesToString(HashBytes);

    // 3. На всякий случай удаляем возможные переносы строк (Base64 иногда их вставляет)
    Base64Str := Base64Str.Replace(#13#10, '', [rfReplaceAll]);

    // 4. Возвращаем готовую строку для вставки в файл .htpasswd
    Result := Format('%s:{SHA}%s', [Username, Base64Str]);
end;

const
    // В Winapi.Windows отсутствуют
    PROC_THREAD_ATTRIBUTE_HANDLE_LIST = $20002;
    CREATE_EXTENDED_STARTUPINFO_PRESENT = $00080000;

type
    // Расширенный STARTUPINFO с указателем на список атрибутов потока
    TStartupInfoExW = record
        StartupInfo: TStartupInfoW;
        lpAttributeList: Pointer;
    end;

// Обход обертки Winapi.Windows: ее var-параметр lpReturnSize не дает
// передать NULL, а вызов с ненулевым lpReturnSize на текущих сборках
// Windows возвращает ERROR_INVALID_PARAMETER
function UpdateProcThreadAttributeRaw(lpAttributeList: Pointer; dwFlags: DWORD; Attribute: UInt64;
    lpValue: Pointer; cbSize: NativeUInt; lpPreviousValue: Pointer; lpReturnSize: Pointer): BOOL; stdcall;
    external kernel32 name 'UpdateProcThreadAttribute';

function RunCmdCommand(const WorkingDir, Command: string; out Output: string; TimeoutMs: Cardinal): Boolean;
var
    SecurityAttr: TSecurityAttributes;
    ReadPipe, WritePipe: THandle;
    StartInfoEx: TStartupInfoExW;
    ProcInfo: TProcessInformation;
    AttrList: PProcThreadAttributeList;
    AttrListSize: NativeUInt;
    InheritList: array[0..0] of THandle;
    Buffer: array[0..2047] of AnsiChar;
    BytesRead, BytesAvail: DWORD;
    FullCommand, CmdPath: string;
    WorkDirPtr: PChar;
    StartTime: DWORD;
    WaitResult: DWORD;
    SB: TStringBuilder;
begin
    Result := False;
    Output := '';
    SB := TStringBuilder.Create;
    try
        FillChar(SecurityAttr, SizeOf(SecurityAttr), 0);
        SecurityAttr.nLength := SizeOf(SecurityAttr);
        SecurityAttr.bInheritHandle := True;

        // 1. Создаем Pipe
        if not CreatePipe(ReadPipe, WritePipe, @SecurityAttr, 0) then
            Exit;

        // Абсолютный путь к системному cmd.exe: CreateProcess не должен
        // искать исполняемый файл по CWD и PATH
        CmdPath := GetEnvironmentVariable('SystemRoot');
        if CmdPath = '' then
            CmdPath := 'C:\Windows';
        CmdPath := CmdPath + '\System32\cmd.exe';

        FillChar(StartInfoEx, SizeOf(StartInfoEx), 0);
        StartInfoEx.StartupInfo.cb := SizeOf(StartInfoEx);
        StartInfoEx.StartupInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
        StartInfoEx.StartupInfo.wShowWindow := SW_HIDE; // Скрываем окно
        StartInfoEx.StartupInfo.hStdOutput := WritePipe;
        StartInfoEx.StartupInfo.hStdError := WritePipe; // Перенаправляем ошибки в тот же поток

        // Ребенку наследуется только пайп вывода: остальные наследуемые
        // хендлы процесса (пайпы движка Python, сокеты) дочернему процессу
        // больше не достаются
        AttrList := nil;
        AttrListSize := 0;
        InitializeProcThreadAttributeList(nil, 1, 0, AttrListSize);
        GetMem(AttrList, AttrListSize);
        try
            if not InitializeProcThreadAttributeList(AttrList, 1, 0, AttrListSize) then
            begin
                CloseHandle(WritePipe);
                Exit;
            end;

            InheritList[0] := WritePipe;
            if not UpdateProcThreadAttributeRaw(AttrList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
                @InheritList, SizeOf(InheritList), nil, nil) then
            begin
                CloseHandle(WritePipe);
                Exit;
            end;

            // Список атрибутов передается внутри расширенного StartupInfo
            StartInfoEx.lpAttributeList := AttrList;

            // /s /c с внешними кавычками вокруг Command: cmd не вырезает
            // внутренние кавычки команды, спецсимволы пути (& и т.п.)
            // остаются литералами. Контракт: Command закавыччен вызывающей стороной
            FullCommand := '"' + CmdPath + '" /s /c "' + Command + '"';

            // Устанавливаем рабочую директорию
            if WorkingDir <> '' then
                WorkDirPtr := PChar(WorkingDir)
            else
                WorkDirPtr := nil;

            // 2. Запускаем процесс
            if CreateProcess(PChar(CmdPath), PChar(FullCommand), nil, nil, True,
                CREATE_NO_WINDOW or CREATE_EXTENDED_STARTUPINFO_PRESENT, nil, WorkDirPtr,
                StartInfoEx.StartupInfo, ProcInfo) then
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
                            SB.Append(string(AnsiString(Buffer)));
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
                                    SB.Append(string(AnsiString(Buffer)));
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
        finally
            if AttrList <> nil then
            begin
                DeleteProcThreadAttributeList(AttrList);
                FreeMem(AttrList);
            end;
        end;
        CloseHandle(ReadPipe);
        Output := SB.ToString;
    finally
        SB.Free;
    end;
end;

initialization
    GNotificationCenter := TNotificationCenter.Create(nil);
    GLogLock := TCriticalSection.Create;


finalization
    FreeAndNil(GNotificationCenter);
    FreeAndNil(GLogLock);

end.

