unit Data.Database.Migrations;

interface

uses
    Common.CmdLine,
    FireDAC.Comp.Client,
    System.SysUtils
    ;

const
    // Текущая версия схемы БД. При изменении схемы:
    //   1) создать Database\Migrations\V<номер>__<имя>.sql (идемпотентные инструкции)
    //   2) зарегистрировать имя ресурса в Database\Migrations\Migrations.rc
    //   3) добавить шаг в реестр MIGRATIONS (implementation)
    //   4) увеличить APP_DB_VERSION
    //   5) синхронизировать "PRAGMA user_version" в Database\Schema\000_schema_init.sql
    APP_DB_VERSION = 12;

    // Сколько последних резервных копий хранится рядом с файлом БД
    MIGRATION_BACKUP_KEEP = 3;

    // Сколько последних pre_import_-снапшотов хранится рядом с файлом БД
    IMPORT_SNAPSHOT_KEEP = 3;

    // Коды возврата консольных команд (/migrate, /backup, /checkdb, /newdb)
    MIGRATE_EXIT_OK           = 0;
    MIGRATE_EXIT_NEWER_SCHEMA = 2;
    MIGRATE_EXIT_FAILED       = 3;
    MIGRATE_EXIT_NO_FILE      = 4;
    MIGRATE_EXIT_INTEGRITY    = 5;

type
    // БД создана более новой версией приложения - применять миграции (и откат) нельзя
    ESchemaVersionError = class(Exception);

    // Сбой применения миграции; текст содержит номер шага и путь к резервной копии
    ESchemaMigrationError = class(Exception);

    // Поставщик SQL-текста миграции: по умолчанию читает RCDATA-ресурс exe.
    // Вынесен в тип, чтобы тесты могли подгружать SQL напрямую с диска.
    TMigrationSQLLoader = reference to function(const AResourceName: string): string;

    TDatabaseMigrator = class
    private
        FConnection: TFDConnection;
        FDatabaseFile: string;
        FSQLLoader: TMigrationSQLLoader;
        FAppliedCount: Integer;
        FBackupPath: string;
        function ReadUserVersion: Integer;
        procedure PruneBackups;
        function TableExists(const ATableName: string): Boolean;
        function ColumnExists(const ATableName, AColumnName: string): Boolean;
        procedure EnsureSnippetColumn(const AColumnName, ADDL: string);
        procedure ApplyColumnGuards(AVersion: Integer);
        procedure ApplyStep(AVersion: Integer; const AResourceName: string);
    public
        constructor Create(AConnection: TFDConnection; const ADatabaseFile: string;
            ASQLLoader: TMigrationSQLLoader = nil);
        // Накатывает недостающие миграции, по одной транзакции на шаг.
        // Перед первым шагом создаёт резервную копию файла БД.
        // Если схема актуальна - не делает ничего.
        procedure Run;
        function CurrentVersion: Integer;
        // Снапшот файла БД через VACUUM INTO (безопасен при активных писателях).
        // Без параметра - копия с меткой времени рядом с БД, участвует в ротации
        // MIGRATION_BACKUP_KEEP; с параметром - копия в указанный файл без ротации.
        procedure CreateBackup(const ATargetFile: string = '');
        property AppliedCount: Integer read FAppliedCount;
        property BackupPath: string read FBackupPath;
    end;

// Снапшот файла БД перед массовым импортом markdown: VACUUM INTO в
// <имя БД>.pre_import_<метка времени>.bak рядом с БД + ротация,
// хранящая IMPORT_SNAPSHOT_KEEP последних копий.
// Для :memory:/отсутствующего файла БД возвращает '' (снапшотить нечего).
function CreateImportSnapshot(AConnection: TFDConnection;
    const ADatabaseFile: string): string;

// Консольный режим ключа /migrate: накатывает схему и завершает процесс
// с кодом возврата (без GUI и мьютекса единственного экземпляра).
// Путь к БД берётся из Params.DbPath (ключ /db).
function ExecuteMigrateCommand(const Params: TCmdLineParams): Integer;

// Единая точка входа консольных команд: /help, /version, /newdb, /migrate,
// /backup, /checkdb. Возвращает код возврата процесса. Вызывается до мьютекса
// единственного экземпляра, поэтому работает и при уже запущенном GUI.
function ExecuteMaintenanceCommand(const Params: TCmdLineParams): Integer;

// Чтение RCDATA-ресурса как UTF8-текста (общее для TAppDatabase и раннера)
function LoadSQLResource(const ResourceName: string): string;

implementation

uses
    Common.AppVersion,
    Common.Localization,
    FireDAC.Comp.DataSet,
    FireDAC.Comp.Script,
    FireDAC.Phys.SQLite,
    System.Classes,
    System.Generics.Collections,
    System.Generics.Defaults,
    System.IOUtils,
    Winapi.Windows
    ;

type
    TMigrationStep = record
        Version: Integer;
        ResourceName: string;
    end;

const
    // Реестр применяемых миграций, по возрастанию версии.
    // v2..v6 в истории не выделялись отдельными шагами - их изменения
    // включены в базовый скрипт V001 (все шаги идемпотентны).
    MIGRATIONS: array [0..6] of TMigrationStep = (
        (Version: 1;  ResourceName: 'SCHEMA_MIGRATION_001'),
        (Version: 7;  ResourceName: 'SCHEMA_MIGRATION_007'),
        (Version: 8;  ResourceName: 'SCHEMA_MIGRATION_008'),
        (Version: 9;  ResourceName: 'SCHEMA_MIGRATION_009'),
        (Version: 10; ResourceName: 'SCHEMA_MIGRATION_010'),
        (Version: 11; ResourceName: 'SCHEMA_MIGRATION_011'),
        (Version: 12; ResourceName: 'SCHEMA_MIGRATION_012')
    );

function LoadSQLResource(const ResourceName: string): string;
var
    ResStream: TResourceStream;
    SL: TStringList;
begin
    ResStream := TResourceStream.Create(HInstance, ResourceName, RT_RCDATA);
    try
        SL := TStringList.Create;
        try
            SL.LoadFromStream(ResStream, TEncoding.UTF8);
            Result := SL.Text;
        finally
            SL.Free;
        end;
    finally
        ResStream.Free;
    end;
end;

constructor TDatabaseMigrator.Create(AConnection: TFDConnection;
    const ADatabaseFile: string; ASQLLoader: TMigrationSQLLoader);
begin
    inherited Create;
    FConnection := AConnection;
    FDatabaseFile := ADatabaseFile;

    if Assigned(ASQLLoader) then
        FSQLLoader := ASQLLoader
    else
        FSQLLoader := LoadSQLResource;
end;

function TDatabaseMigrator.ReadUserVersion: Integer;
begin
    Result := FConnection.ExecSQLScalar('PRAGMA user_version');
end;

function TDatabaseMigrator.CurrentVersion: Integer;
begin
    Result := ReadUserVersion;
end;

procedure TDatabaseMigrator.Run;
var
    Current, I: Integer;
begin
    Current := ReadUserVersion;

    if Current > APP_DB_VERSION then
        raise ESchemaVersionError.Create(
            TUIStateLoader.GetMessage('DB.NewerVersion',
                [IntToStr(Current), IntToStr(APP_DB_VERSION)]));

    FAppliedCount := 0;
    if Current = APP_DB_VERSION then
        Exit;

    CreateBackup;

    for I := Low(MIGRATIONS) to High(MIGRATIONS) do
        if MIGRATIONS[I].Version > Current then
        begin
            ApplyStep(MIGRATIONS[I].Version, MIGRATIONS[I].ResourceName);
            Inc(FAppliedCount);
        end;
end;

procedure TDatabaseMigrator.ApplyStep(AVersion: Integer; const AResourceName: string);
var
    ErrMsg: string;
    Script: TFDScript;
begin
    Script := TFDScript.Create(nil);
    try
        Script.Connection := FConnection;
        Script.SQLScripts.Add.SQL.Text := FSQLLoader(AResourceName);

        // Одна транзакция на миграцию: шаг применяется целиком или полностью откатывается.
        // PRAGMA user_version транзакционна в SQLite, поэтому версия растёт вместе со схемой.
        FConnection.StartTransaction;
        try
            Script.ExecuteAll;
            ApplyColumnGuards(AVersion);
            FConnection.ExecSQL(Format('PRAGMA user_version = %d;', [AVersion]));
            FConnection.Commit;
        except
            on E: Exception do
            begin
                FConnection.Rollback;

                ErrMsg := TUIStateLoader.GetMessage('DB.MigrateFailed',
                    [IntToStr(AVersion), E.Message]);

                if FBackupPath <> '' then
                    ErrMsg := ErrMsg + sLineBreak +
                        TUIStateLoader.GetMessage('DB.BackupCreated', [FBackupPath]);

                raise ESchemaMigrationError.Create(ErrMsg);
            end;
        end;
    finally
        Script.Free;
    end;
end;

procedure TDatabaseMigrator.ApplyColumnGuards(AVersion: Integer);
begin
    // ALTER TABLE ADD COLUMN не поддерживает IF NOT EXISTS, поэтому
    // добавление колонок проверяется по pragma_table_info в коде раннера
    case AVersion of
        7:  EnsureSnippetColumn('is_security_ignored', 'INTEGER NOT NULL DEFAULT 0');
        11: EnsureSnippetColumn('language', 'TEXT NOT NULL DEFAULT ''bash''');
        12: EnsureSnippetColumn('language_locked', 'INTEGER NOT NULL DEFAULT 0');
    end;
end;

procedure TDatabaseMigrator.EnsureSnippetColumn(const AColumnName, ADDL: string);
begin
    if (not TableExists('snippets')) or ColumnExists('snippets', AColumnName) then
        Exit;

    FConnection.ExecSQL(Format('ALTER TABLE snippets ADD COLUMN %s %s', [AColumnName, ADDL]));
end;

function TDatabaseMigrator.TableExists(const ATableName: string): Boolean;
begin
    Result := FConnection.ExecSQLScalar(
        'SELECT COUNT(*) FROM sqlite_master WHERE type = ''table'' AND name = ?',
        [ATableName]) > 0;
end;

function TDatabaseMigrator.ColumnExists(const ATableName, AColumnName: string): Boolean;
begin
    Result := FConnection.ExecSQLScalar(
        'SELECT COUNT(*) FROM pragma_table_info(?) WHERE name = ?',
        [ATableName, AColumnName]) > 0;
end;

// Имя резервной копии по умолчанию: файл БД + метка времени.
// Миллисекунды в метке исключают коллизию имени
// при повторных бэкапах в пределах одной секунды
function DefaultBackupFileName(const ADatabaseFile: string): string;
begin
    Result := ADatabaseFile + '.backup-' + FormatDateTime('yyyymmdd_hhnnsszzz', Now) + '.bak';
end;

procedure TDatabaseMigrator.CreateBackup(const ATargetFile: string);
var
    BackupFile: string;
    UseRotation: Boolean;
begin
    FBackupPath := '';

    // :memory: и несуществующие файлы бэкапировать нечего
    if (FDatabaseFile = '') or SameText(FDatabaseFile, ':memory:') or
        (not TFile.Exists(FDatabaseFile)) then
        Exit;

    UseRotation := ATargetFile = '';
    if UseRotation then
        BackupFile := DefaultBackupFileName(FDatabaseFile)
    else
        BackupFile := ATargetFile;

    try
        try
            // VACUUM INTO создаёт целостный снапшот с учётом WAL и работает
            // параллельно с писателями (WAL-читатели не блокируются).
            // Существующий файл не перезаписывает - удаляем на всякий случай
            // (совпадение метки времени до секунды маловероятно).
            if TFile.Exists(BackupFile) then
                TFile.Delete(BackupFile);

            FConnection.ExecSQL('VACUUM INTO ' + QuotedStr(BackupFile));
        except
            // Запасной путь для старых SQLite без VACUUM INTO:
            // сброс WAL в основной файл и прямое копирование
            FConnection.ExecSQL('PRAGMA wal_checkpoint(TRUNCATE)');
            TFile.Copy(FDatabaseFile, BackupFile, True);
        end;
    except
        on E: Exception do
            // Без резервной копии схему менять нельзя - прерываем до первого шага
            raise ESchemaMigrationError.Create(
                TUIStateLoader.GetMessage('DB.BackupFailed', [FDatabaseFile, E.Message]));
    end;

    FBackupPath := BackupFile;

    // Ротация по умолчанию применяется только к копиям с автогенерируемым
    // именем; явно заданный файл пользователь ротирует сам
    if UseRotation then
        PruneBackups;
end;

procedure TDatabaseMigrator.PruneBackups;
var
    Files: TArray<string>;
    I: Integer;
begin
    if FBackupPath = '' then
        Exit;

    Files := TDirectory.GetFiles(TPath.GetDirectoryName(FDatabaseFile),
        TPath.GetFileName(FDatabaseFile) + '.backup-*.bak');

    if Length(Files) <= MIGRATION_BACKUP_KEEP then
        Exit;

    // Имя содержит метку времени yyyymmdd_hhnnss, поэтому лексикографическая
    // сортировка по убыванию ставит первыми самые свежие копии
    TArray.Sort<string>(Files,
        TComparer<string>.Construct(
            function(const ALeft, ARight: string): Integer
            begin
                Result := CompareText(ARight, ALeft);
            end));

    for I := MIGRATION_BACKUP_KEEP to High(Files) do
        TFile.Delete(Files[I]);
end;

function CreateImportSnapshot(AConnection: TFDConnection;
    const ADatabaseFile: string): string;
var
    BackupFile: string;
    Files: TArray<string>;
    I: Integer;
    Migrator: TDatabaseMigrator;
begin
    Result := '';
    BackupFile := ADatabaseFile + '.pre_import_' +
        FormatDateTime('yyyymmdd_hhnnsszzz', Now) + '.bak';

    // Снапшот выполняется ДО открытия транзакции импорта: VACUUM INTO
    // нельзя выполнять в активной транзакции на том же соединении
    Migrator := TDatabaseMigrator.Create(AConnection, ADatabaseFile);
    try
        Migrator.CreateBackup(BackupFile);
        Result := Migrator.BackupPath;
    finally
        Migrator.Free;
    end;

    if Result = '' then
        Exit;

    // Ротация: храним только IMPORT_SNAPSHOT_KEEP последних снапшотов.
    // Метка времени в имени гарантирует, что лексикографический порядок
    // совпадает с хронологией
    Files := TDirectory.GetFiles(TPath.GetDirectoryName(ADatabaseFile),
        TPath.GetFileName(ADatabaseFile) + '.pre_import_*.bak');

    if Length(Files) <= IMPORT_SNAPSHOT_KEEP then
        Exit;

    TArray.Sort<string>(Files,
        TComparer<string>.Construct(
            function(const ALeft, ARight: string): Integer
            begin
                Result := CompareText(ARight, ALeft);
            end));

    for I := IMPORT_SNAPSHOT_KEEP to High(Files) do
        TFile.Delete(Files[I]);
end;

function ConsoleWriteTextW(hConsoleOutput: THandle; lpBuffer: PWideChar;
    nNumberOfCharsToWrite: DWORD; var lpNumberOfCharsWritten: DWORD;
    lpReserved: Pointer): BOOL; stdcall; external kernel32 name 'WriteConsoleW';

procedure ConsoleWrite(const AText: string);
var
    Handle: THandle;
    Src: TBytes;
    Written: DWORD;
begin
    Handle := GetStdHandle(STD_OUTPUT_HANDLE);
    if (Handle = 0) or (Handle = INVALID_HANDLE_VALUE) then
        Exit;

    // В консоли пишем через WriteConsoleW (сохраняет Unicode),
    // при перенаправленном выводе (pipe/файл) - UTF8 через WriteFile
    if not ConsoleWriteTextW(Handle, PChar(AText), Length(AText), Written, nil) then
    begin
        Src := TEncoding.UTF8.GetBytes(AText + sLineBreak);
        WriteFile(Handle, Src[0], Length(Src), Written, nil);
    end;
end;

// Открывает существующий файл БД с рабочими PRAGMA и выполняет действие.
// Исключения маппятся в коды возврата консольных команд.
function ExecuteWithConnection(const ADbFile: string;
    const AAction: TFunc<TFDConnection, Integer>): Integer;
var
    Connection: TFDConnection;
    DriverLink: TFDPhysSQLiteDriverLink;
begin
    DriverLink := TFDPhysSQLiteDriverLink.Create(nil);
    Connection := TFDConnection.Create(nil);
    try
        Connection.Params.Add('DriverID=SQLite');
        Connection.Params.Add('Database=' + ADbFile);
        // FireDAC глобально включает shared cache SQLite (табличные блокировки
        // между соединениями одного процесса); консольная команда должна
        // работать с блокировками как между процессами, как при запущенном GUI
        Connection.Params.Add('SharedCache=False');
        // Без этого параметра FireDAC при каждом открытии выполняет
        // "PRAGMA journal_mode = DELETE": БД молча выводится из WAL,
        // а при активном писателе открытие падает с ошибкой блокировки
        Connection.Params.Add('JournalMode=WAL');
        // Аналогично: дефолт FireDAC - "PRAGMA locking_mode = Exclusive",
        // что в WAL требует монопольного доступа ко всей БД
        Connection.Params.Add('LockingMode=Normal');
        // Задаётся параметром, а не PRAGMA после открытия: FireDAC
        // выполняет свои PRAGMA уже на этапе открытия
        Connection.Params.Add('BusyTimeout=5000');
        Connection.Params.Add('CharacterSet=utf8');
        // FireDAC перед каждым оператором сбрасывает busy_timeout в ноль,
        // если у оператора LockWait=False (дефолт)
        Connection.UpdateOptions.LockWait := True;
        Connection.Connected := True;
        Connection.ExecSQL('PRAGMA foreign_keys = ON');

        Result := AAction(Connection);
    except
        on E: ESchemaVersionError do
        begin
            Result := MIGRATE_EXIT_NEWER_SCHEMA;
            ConsoleWrite(E.Message);
        end;
        on E: ESchemaMigrationError do
        begin
            Result := MIGRATE_EXIT_FAILED;
            ConsoleWrite(E.Message);
        end;
        on E: Exception do
        begin
            Result := MIGRATE_EXIT_FAILED;
            ConsoleWrite(TUIStateLoader.GetMessage('DB.OpenError', [E.Message]));
        end;
    end;

    Connection.Free;
    DriverLink.Free;
end;

// Проверки пути к существующей БД, общие для /migrate, /backup и /checkdb.
// Возвращает True, если путь корректен; иначе печатает причину и код возврата.
function ResolveExistingDbFile(const ADbPath: string; out ADbFile: string): Integer;
begin
    Result := MIGRATE_EXIT_OK;

    if ADbPath = '' then
    begin
        ConsoleWrite(TUIStateLoader.GetMessage('CmdLine.NoDbParam'));
        Exit(MIGRATE_EXIT_NO_FILE);
    end;

    ADbFile := ExpandFileName(ADbPath);

    // FireDAC при Connected := True молча создаёт несуществующий SQLite-файл,
    // поэтому путь проверяем явно: команды работают только с готовыми БД
    if not TFile.Exists(ADbFile) then
    begin
        ConsoleWrite(TUIStateLoader.GetMessage('CmdLine.DbFileNotFound', [ADbFile]));
        Exit(MIGRATE_EXIT_NO_FILE);
    end;
end;

function ExecuteMigrateCommand(const Params: TCmdLineParams): Integer;
var
    DbFile: string;
begin
    Result := ResolveExistingDbFile(Params.DbPath, DbFile);
    if Result <> MIGRATE_EXIT_OK then
        Exit;

    Result := ExecuteWithConnection(DbFile,
        function(AConnection: TFDConnection): Integer
        var
            Migrator: TDatabaseMigrator;
        begin
            Migrator := TDatabaseMigrator.Create(AConnection, DbFile);
            try
                Migrator.Run;

                if Migrator.AppliedCount > 0 then
                    ConsoleWrite(TUIStateLoader.GetMessage('DB.MigratedSuccess',
                        [IntToStr(APP_DB_VERSION)]))
                else
                    ConsoleWrite(TUIStateLoader.GetMessage('DB.MigrateUpToDate',
                        [IntToStr(Migrator.CurrentVersion)]));

                if Migrator.BackupPath <> '' then
                    ConsoleWrite(TUIStateLoader.GetMessage('DB.BackupCreated',
                        [Migrator.BackupPath]));
            finally
                Migrator.Free;
            end;

            Result := MIGRATE_EXIT_OK;
        end);
end;

function ExecuteBackupCommand(const Params: TCmdLineParams): Integer;
var
    DbFile, TargetFile: string;
begin
    Result := ResolveExistingDbFile(Params.DbPath, DbFile);
    if Result <> MIGRATE_EXIT_OK then
        Exit;

    TargetFile := Params.BackupPath;
    if TargetFile <> '' then
    begin
        TargetFile := ExpandFileName(TargetFile);

        // Папка (существующая или с разделителем на конце) - копия
        // с автогенерируемым именем кладётся внутрь неё
        if TDirectory.Exists(TargetFile) or
            ((TargetFile <> '') and CharInSet(TargetFile[Length(TargetFile)], ['\', '/'])) then
            TargetFile := IncludeTrailingPathDelimiter(TargetFile) + DefaultBackupFileName(TPath.GetFileName(DbFile))
        else if TFile.Exists(TargetFile) then
        begin
            // VACUUM INTO не перезаписывает файлы - существующую копию не трогаем
            ConsoleWrite(TUIStateLoader.GetMessage('CmdLine.BackupTargetExists', [TargetFile]));
            Exit(MIGRATE_EXIT_FAILED);
        end;
    end;

    Result := ExecuteWithConnection(DbFile,
        function(AConnection: TFDConnection): Integer
        var
            Migrator: TDatabaseMigrator;
        begin
            Migrator := TDatabaseMigrator.Create(AConnection, DbFile);
            try
                Migrator.CreateBackup(TargetFile);
                ConsoleWrite(TUIStateLoader.GetMessage('DB.BackupCreated',
                    [Migrator.BackupPath]));
            finally
                Migrator.Free;
            end;

            Result := MIGRATE_EXIT_OK;
        end);
end;

function ExecuteCheckDbCommand(const Params: TCmdLineParams): Integer;
var
    DbFile: string;
begin
    Result := ResolveExistingDbFile(Params.DbPath, DbFile);
    if Result <> MIGRATE_EXIT_OK then
        Exit;

    Result := ExecuteWithConnection(DbFile,
        function(AConnection: TFDConnection): Integer
        var
            Problems: TStringList;
            Query: TFDQuery;
        begin
            Problems := TStringList.Create;
            try
                Query := TFDQuery.Create(nil);
                try
                    Query.Connection := AConnection;

                    // Целостность структуры: одна строка 'ok' либо список ошибок
                    Query.SQL.Text := 'PRAGMA integrity_check';
                    Query.Open;
                    while not Query.Eof do
                    begin
                        if Query.Fields[0].AsString <> 'ok' then
                            Problems.Add(Query.Fields[0].AsString);
                        Query.Next;
                    end;

                    // Нарушения внешних ключей (висячие ссылки между таблицами)
                    Query.SQL.Text := 'PRAGMA foreign_key_check';
                    Query.Open;
                    while not Query.Eof do
                    begin
                        Problems.Add('foreign_key_check: ' + Query.Fields[0].AsString +
                            ', rowid=' + Query.Fields[1].AsString);
                        Query.Next;
                    end;
                finally
                    Query.Free;
                end;

                if Problems.Count = 0 then
                begin
                    ConsoleWrite(TUIStateLoader.GetMessage('CmdLine.CheckOk'));
                    Result := MIGRATE_EXIT_OK;
                end
                else
                begin
                    ConsoleWrite(TUIStateLoader.GetMessage('CmdLine.CheckFailed',
                        [Problems.Text.TrimRight]));
                    Result := MIGRATE_EXIT_INTEGRITY;
                end;
            finally
                Problems.Free;
            end;
        end);
end;

function ExecuteNewDbCommand(const Params: TCmdLineParams): Integer;
var
    Connection: TFDConnection;
    DbFile, Dir: string;
    DriverLink: TFDPhysSQLiteDriverLink;
    Script: TFDScript;
begin
    if Params.NewDB = '' then
    begin
        ConsoleWrite(TUIStateLoader.GetMessage('CmdLine.NewDbNoParam'));
        Exit(MIGRATE_EXIT_NO_FILE);
    end;

    DbFile := ExpandFileName(Params.NewDB);

    // Существующую базу не трогаем - /newdb только для новых файлов
    if TFile.Exists(DbFile) then
    begin
        ConsoleWrite(TUIStateLoader.GetMessage('CmdLine.NewDbAlreadyExists', [DbFile]));
        Exit(MIGRATE_EXIT_FAILED);
    end;

    Dir := TPath.GetDirectoryName(DbFile);
    if (Dir <> '') and (not TDirectory.Exists(Dir)) then
    begin
        ConsoleWrite(TUIStateLoader.GetMessage('CmdLine.NewDbDirNotFound', [Dir]));
        Exit(MIGRATE_EXIT_NO_FILE);
    end;

    Result := MIGRATE_EXIT_FAILED;
    DriverLink := TFDPhysSQLiteDriverLink.Create(nil);
    Connection := TFDConnection.Create(nil);
    try
        try
            Connection.Params.Add('DriverID=SQLite');
            Connection.Params.Add('Database=' + DbFile);
            // WAL задаётся параметром: FireDAC иначе выполняет
            // "PRAGMA journal_mode = DELETE" при открытии
            Connection.Params.Add('JournalMode=WAL');
            Connection.Params.Add('LockingMode=Normal');
            Connection.Params.Add('CharacterSet=utf8');
            Connection.Connected := True;
            Connection.ExecSQL('PRAGMA foreign_keys = ON');
            Connection.ExecSQL('PRAGMA synchronous = NORMAL');

            // Baseline-схема: тот же набор ресурсов, что и при создании БД
            // из GUI (TAppDatabase.InitializeDatabase); завершается
            // PRAGMA user_version = APP_DB_VERSION, отдельный раннер не нужен
            Script := TFDScript.Create(nil);
            try
                Script.Connection := Connection;
                Script.SQLScripts.Add.SQL.Text :=
                    LoadSQLResource('SCHEMA_INIT_SQL') +
                    LoadSQLResource('SCHEMA_SEED_SQL');
                Script.ExecuteAll;
            finally
                Script.Free;
            end;

            Connection.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'');');

            ConsoleWrite(TUIStateLoader.GetMessage('CmdLine.NewDbCreated',
                [DbFile, IntToStr(APP_DB_VERSION)]));
            Result := MIGRATE_EXIT_OK;
        except
            on E: Exception do
            begin
                ConsoleWrite(TUIStateLoader.GetMessage('DB.CreateError', [E.Message]));

                // Полусозданный файл не оставляем - скриптам не нужен обломок БД
                Winapi.Windows.DeleteFile(PChar(DbFile));
                Winapi.Windows.DeleteFile(PChar(DbFile + '-wal'));
                Winapi.Windows.DeleteFile(PChar(DbFile + '-shm'));
            end;
        end;
    finally
        Connection.Free;
        DriverLink.Free;
    end;
end;

function ExecuteHelpCommand: Integer;
begin
    ConsoleWrite(TUIStateLoader.GetMessage('CmdLine.HelpTitle'));
    ConsoleWrite('');
    ConsoleWrite(TUIStateLoader.GetMessage('CmdLine.HelpText'));
    Result := MIGRATE_EXIT_OK;
end;

function ExecuteVersionCommand: Integer;
var
    AppVersion: string;
begin
    AppVersion := GetAppVersionInfo;
    if AppVersion = '' then
        AppVersion := 'unknown';

    ConsoleWrite(TUIStateLoader.GetMessage('CmdLine.Version', [AppVersion]));
    Result := MIGRATE_EXIT_OK;
end;

function ExecuteMaintenanceCommand(const Params: TCmdLineParams): Integer;
begin
    // Подключаемся к консоли родительского процесса (cmd/PowerShell),
    // чтобы скрипты и автодеплой видели текст; из Проводника вывод тихий
    AttachConsole(ATTACH_PARENT_PROCESS);

    // Безобидные информационные команды первыми, меняющие данные - после
    if Params.Help then
        Exit(ExecuteHelpCommand);
    if Params.Version then
        Exit(ExecuteVersionCommand);
    if Params.NewDB <> '' then
        Exit(ExecuteNewDbCommand(Params));
    if Params.Migrate then
        Exit(ExecuteMigrateCommand(Params));
    if Params.Backup then
        Exit(ExecuteBackupCommand(Params));
    if Params.CheckDB then
        Exit(ExecuteCheckDbCommand(Params));

    Result := MIGRATE_EXIT_OK;
end;

end.
