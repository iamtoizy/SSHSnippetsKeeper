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

    // Коды возврата ключа /migrate (для скриптов и автодеплоя)
    MIGRATE_EXIT_OK           = 0;
    MIGRATE_EXIT_NEWER_SCHEMA = 2;
    MIGRATE_EXIT_FAILED       = 3;
    MIGRATE_EXIT_NO_FILE      = 4;

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
        procedure CreateBackup;
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
        property AppliedCount: Integer read FAppliedCount;
        property BackupPath: string read FBackupPath;
    end;

// Консольный режим ключа /migrate: накатывает схему и завершает процесс
// с кодом возврата (без GUI и мьютекса единственного экземпляра).
// Путь к БД берётся из Params.DbPath (ключ /db).
function ExecuteMigrateCommand(const Params: TCmdLineParams): Integer;

// Чтение RCDATA-ресурса как UTF8-текста (общее для TAppDatabase и раннера)
function LoadSQLResource(const ResourceName: string): string;

implementation

uses
    Common.Localization,
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

procedure TDatabaseMigrator.CreateBackup;
var
    BackupFile, Stamp: string;
begin
    FBackupPath := '';

    // :memory: и несуществующие файлы бэкапировать нечего
    if (FDatabaseFile = '') or SameText(FDatabaseFile, ':memory:') or
        (not TFile.Exists(FDatabaseFile)) then
        Exit;

    // Миллисекунды в метке исключают коллизию имени файла
    // при повторных миграциях в пределах одной секунды
    Stamp := FormatDateTime('yyyymmdd_hhnnsszzz', Now);
    BackupFile := FDatabaseFile + '.backup-' + Stamp + '.bak';

    try
        try
            // VACUUM INTO создаёт целостный снапшот с учётом WAL.
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

function ExecuteMigrateCommand(const Params: TCmdLineParams): Integer;
var
    Connection: TFDConnection;
    DbFile: string;
    DriverLink: TFDPhysSQLiteDriverLink;
    Migrator: TDatabaseMigrator;
begin
    Result := MIGRATE_EXIT_OK;

    // Подключаемся к консоли родительского процесса (cmd/PowerShell),
    // чтобы скрипты и автодеплой видели текст; из Проводника вывод тихий
    AttachConsole(ATTACH_PARENT_PROCESS);

    if Params.DbPath = '' then
    begin
        ConsoleWrite(TUIStateLoader.GetMessage('DB.MigrateNoDbParam'));
        Exit(MIGRATE_EXIT_NO_FILE);
    end;

    DbFile := ExpandFileName(Params.DbPath);

    // FireDAC при Connected := True молча создаёт несуществующий SQLite-файл,
    // поэтому путь проверяем явно: миграция предназначена только для готовых БД
    if not TFile.Exists(DbFile) then
    begin
        ConsoleWrite(TUIStateLoader.GetMessage('CmdLine.DbFileNotFound', [DbFile]));
        Exit(MIGRATE_EXIT_NO_FILE);
    end;

    DriverLink := TFDPhysSQLiteDriverLink.Create(nil);
    Connection := TFDConnection.Create(nil);
    try
        Connection.Params.Add('DriverID=SQLite');
        Connection.Params.Add('Database=' + DbFile);
        Connection.Params.Add('CharacterSet=utf8');
        Connection.Connected := True;
        Connection.ExecSQL('PRAGMA foreign_keys = ON');
        Connection.ExecSQL('PRAGMA busy_timeout = 5000');

        Migrator := TDatabaseMigrator.Create(Connection, DbFile);
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

end.
