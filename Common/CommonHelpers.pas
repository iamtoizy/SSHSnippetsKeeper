unit CommonHelpers;

interface

{ Показать тост-уведомление }
procedure ShowSimpleToast(const Text: string; const Title: string = '');
{ Поиск конкретного файла конфигурации или БД (Для TUIStateLoader и SQLite) }
function ResolvePath(const PathName: string; IsDirectory: Boolean = False): string;
{ Получение базовой папки для диалогов открытия/сохранения }
function GetDefaultDataDir: string;

implementation

uses
    System.Notification,
    System.SysUtils,
    System.IOUtils,
    UI.StateLoader;

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

initialization
    NotificationCenter := TNotificationCenter.Create(nil);


finalization
    NotificationCenter.Free;

end.

