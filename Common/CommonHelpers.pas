unit CommonHelpers;

interface

uses
    Core.Interfaces,
    System.Generics.Collections,
    System.Generics.Defaults,
    Vcl.ComCtrls,
    Vcl.StdCtrls
    ;

type
    // Статический класс-помощник для работы с историей ввода (MRU)
    THistoryHelper = class
    public
        class procedure Add(var History: TArray<THistoryItem>; const NewValue: string; MaxItems: Integer = 15);
    end;

{ Показать тост-уведомление }
procedure ShowSimpleToast(const Text: string; const Title: string = '');
{ Поиск конкретного файла конфигурации или БД (Для TUIStateLoader и SQLite) }
function ResolvePath(const PathName: string; IsDirectory: Boolean = False): string;
{ Получение базовой папки для диалогов открытия/сохранения }
function GetDefaultDataDir: string;
{ Безопасное удаление содержимого TListView }
procedure WipeListViewPasswords(ListView: TListView);
{ Безопасное удаление содержимого TCustomEdit }
procedure WipeVCLControlText(Control: TCustomEdit);
{ Затирание блока памяти нулями }
procedure SecureZeroMemory(Ptr: Pointer; Size: NativeUInt);
{ Безопасное копирование в буфер обмена }
procedure CopyToClipboardSecure(const Text: string);
{ Безопасное уничтожение локальных строк в RAM }
procedure WipeString(var S: string);

implementation

uses
    System.IOUtils,
    System.Notification,
    System.SysUtils,
    UI.StateLoader,
    Vcl.Clipbrd,
    Winapi.Windows
    ;

var
    NotificationCenter: TNotificationCenter;

{ Показать тост-уведомление }
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

{ Поиск конкретного файла конфигурации или БД (Для TUIStateLoader и SQLite) }
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

{ Получение базовой папки для диалогов открытия/сохранения }
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

procedure WipeListViewPasswords(ListView: TListView);
var
    I: Integer;
    S: string;
    P: Pointer;
begin
    if not Assigned(ListView) then Exit;

    // Пробегаемся по всем строкам таблицы
    for I := 0 to ListView.Items.Count - 1 do
    begin
        // Пароль хранится во второй колонке (индекс 1)
        if ListView.Items[I].SubItems.Count > 1 then
        begin
            // Получаем прямую ссылку на блок памяти со строкой
            S := ListView.Items[I].SubItems[1];
            if S <> '' then
            begin
                // Берем прямой указатель на первый символ
                P := PChar(S);
                // Физически затираем байты в куче (heap) нулями.
                // Поскольку мы обращаемся по указателю, мы "ломаем" строку
                // прямо внутри самой структуры TListView!
                SecureZeroMemory(P, Length(S) * SizeOf(Char));
            end;
        end;
    end;

    // Теперь, когда в памяти таблицы лежат только нули, можно безопасно
    // отдать эти блоки обратно системе
    ListView.Items.Clear;
end;

procedure WipeVCLControlText(Control: TCustomEdit);
begin
    if not Assigned(Control) or (Control.Text = '') then Exit;
    // Физически перезаписываем участок памяти контрола нулями,
    // прежде чем освободить строку
    Control.Text := StringOfChar('0', Control.GetTextLen);
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
    if (S <> '') and (StringRefCount(S) > 0) then
    begin
        // Физически затираем оригинальный блок памяти нулями
        SecureZeroMemory(PChar(S), Length(S) * SizeOf(Char));
    end;
    S := ''; // Обнуляем указатель
end;

{ THistoryHelper }

class procedure THistoryHelper.Add(var History: TArray<THistoryItem>; const NewValue: string; MaxItems: Integer);
var
    I: Integer;
    Found: Boolean;
begin
    if NewValue.Trim = '' then Exit;

    Found := False;
    // 1. Ищем элемент. Если нашли — увеличиваем вес
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

initialization
    NotificationCenter := TNotificationCenter.Create(nil);


finalization
    NotificationCenter.Free;

end.

