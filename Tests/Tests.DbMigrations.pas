unit Tests.DbMigrations;

interface

uses
    DUnitX.TestFramework,
    Data.Database.Migrations,
    FireDAC.Comp.Client,
    System.Classes
    ;

type
    [TestFixture]
    TDbMigrationTests = class(TObject)
    private
        FConn: TFDConnection;
        function MigrationsDir: string;
        function LoadMigrationSQL(const AResourceName: string): string;
        function SchemaFilePath(const AFilename: string): string;
        procedure ExecFile(AConn: TFDConnection; const AFilename: string);
        function ObjectNames(AConn: TFDConnection): TStringList;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test]
        procedure EmptyDB_CatchesUpToCurrentVersion;

        [Test]
        procedure MigratedSchema_MatchesBaselineObjects;

        [Test]
        procedure BaselineDB_RunnerIsNoOp;

        [Test]
        procedure NewerSchema_RaisesVersionError;

        [Test]
        procedure RealFile_CreatesBackup_AndPrunesOld;

        [Test]
        procedure Backup_ToCustomTarget;

        [Test]
        procedure Backup_WhileAnotherConnectionWrites;

        [Test]
        procedure BaselineScript_AppliesInSingleTransaction;

        [Test]
        procedure FailedScript_RollsBackWholeTransaction;
    end;

implementation

uses
    Data.Database.Security,
    FireDAC.Comp.DataSet,
    FireDAC.Comp.Script,
    FireDAC.ConsoleUI.Wait,
    FireDAC.DApt,
    FireDAC.Phys.SQLite,
    FireDAC.Stan.Async,
    FireDAC.Stan.Def,
    FireDAC.Stan.ExprFuncs,
    System.IOUtils,
    System.SysUtils
    ;

var
    GDriverLink: TFDPhysSQLiteDriverLink;

function TDbMigrationTests.MigrationsDir: string;
var
    Dir: string;
begin
    Dir := TPath.GetDirectoryName(ParamStr(0));
    repeat
        Result := TPath.Combine(Dir, 'Database\Migrations');
        if TDirectory.Exists(Result) then
            Exit;
        Dir := TPath.GetDirectoryName(Dir);
    until Dir = '';
    raise Exception.Create('Migrations directory not found');
end;

function TDbMigrationTests.LoadMigrationSQL(const AResourceName: string): string;
var
    Files: TArray<string>;
    Mask: string;
begin
    // SCHEMA_MIGRATION_012 -> V012__*.sql
    Mask := 'V' + Copy(AResourceName, Length('SCHEMA_MIGRATION_') + 1, 3) + '__*.sql';
    Files := TDirectory.GetFiles(MigrationsDir, Mask);

    if Length(Files) = 0 then
        raise Exception.Create('Migration file not found: ' + Mask);

    Result := TFile.ReadAllText(Files[0], TEncoding.UTF8);
end;

function TDbMigrationTests.SchemaFilePath(const AFilename: string): string;
var
    Dir: string;
begin
    Dir := TPath.GetDirectoryName(ParamStr(0));
    repeat
        Result := TPath.Combine(Dir, TPath.Combine('Database', 'Schema', AFilename));
        if TFile.Exists(Result) then
            Exit;
        Dir := TPath.GetDirectoryName(Dir);
    until Dir = '';
    raise Exception.Create('Schema file not found: ' + AFilename);
end;

procedure TDbMigrationTests.ExecFile(AConn: TFDConnection; const AFilename: string);
var
    Script: TFDScript;
begin
    Script := TFDScript.Create(nil);
    try
        Script.Connection := AConn;
        Script.SQLScripts.Add.SQL.Text :=
            TFile.ReadAllText(SchemaFilePath(AFilename), TEncoding.UTF8);
        Script.ExecuteAll;
    finally
        Script.Free;
    end;
end;

function TDbMigrationTests.ObjectNames(AConn: TFDConnection): TStringList;
var
    Q: TFDQuery;
begin
    Result := TStringList.Create;
    Result.Sorted := True;

    Q := TFDQuery.Create(nil);
    try
        Q.Connection := AConn;
        Q.SQL.Text :=
            'SELECT type, name FROM sqlite_master ' +
            'WHERE name NOT LIKE ''sqlite_%'' ORDER BY type, name';
        Q.Open;
        while not Q.Eof do
        begin
            Result.Add(Q.FieldByName('type').AsString + '=' + Q.FieldByName('name').AsString);
            Q.Next;
        end;
    finally
        Q.Free;
    end;
end;

procedure TDbMigrationTests.Setup;
begin
    FConn := TFDConnection.Create(nil);
    FConn.Params.Add('DriverID=SQLite');
    FConn.Params.Add('Database=:memory:');
    FConn.Connected := True;
    FConn.ExecSQL('PRAGMA foreign_keys = ON');
end;

procedure TDbMigrationTests.TearDown;
begin
    FreeAndNil(FConn);
end;

procedure TDbMigrationTests.EmptyDB_CatchesUpToCurrentVersion;
var
    Migrator: TDatabaseMigrator;
begin
    Migrator := TDatabaseMigrator.Create(FConn, ':memory:', LoadMigrationSQL);
    try
        Migrator.Run;

        Assert.AreEqual(Integer(APP_DB_VERSION), Integer(FConn.ExecSQLScalar('PRAGMA user_version')));

        // v7/v11/v12: колонки snippets, добавляемые по pragma_table_info
        Assert.AreEqual(3, Integer(FConn.ExecSQLScalar(
            'SELECT COUNT(*) FROM pragma_table_info(''snippets'') ' +
            'WHERE name IN (''is_security_ignored'', ''language'', ''language_locked'')')));

        // v8..v10: таблицы
        Assert.AreEqual(5, Integer(FConn.ExecSQLScalar(
            'SELECT COUNT(*) FROM sqlite_master WHERE type = ''table'' AND name IN ' +
            '(''snippet_favorites'', ''snippet_history'', ''service_flags'', ' +
            '''snippet_chains'', ''snippet_chain_steps'')')));

        Assert.AreEqual(1, Integer(FConn.ExecSQLScalar(
            'SELECT COUNT(*) FROM service_flags WHERE name = ''history_suppressed''')));
    finally
        Migrator.Free;
    end;
end;

procedure TDbMigrationTests.MigratedSchema_MatchesBaselineObjects;
var
    BaselineConn: TFDConnection;
    BaselineNames, MigratedNames: TStringList;
    Migrator: TDatabaseMigrator;
begin
    Migrator := TDatabaseMigrator.Create(FConn, ':memory:', LoadMigrationSQL);
    try
        Migrator.Run;
    finally
        Migrator.Free;
    end;

    // Эталон: чистая БД из базового скрипта 000_schema_init.sql
    BaselineConn := TFDConnection.Create(nil);
    try
        BaselineConn.Params.Add('DriverID=SQLite');
        BaselineConn.Params.Add('Database=:memory:');
        BaselineConn.Connected := True;
        ExecFile(BaselineConn, '000_schema_init.sql');

        MigratedNames := ObjectNames(FConn);
        BaselineNames := ObjectNames(BaselineConn);
        try
            Assert.AreEqual(BaselineNames.Text, MigratedNames.Text);
        finally
            BaselineNames.Free;
            MigratedNames.Free;
        end;
    finally
        BaselineConn.Free;
    end;
end;

procedure TDbMigrationTests.BaselineDB_RunnerIsNoOp;
var
    Migrator: TDatabaseMigrator;
begin
    ExecFile(FConn, '000_schema_init.sql');

    Migrator := TDatabaseMigrator.Create(FConn, ':memory:', LoadMigrationSQL);
    try
        Migrator.Run;
        Assert.AreEqual(0, Migrator.AppliedCount);
    finally
        Migrator.Free;
    end;
end;

procedure TDbMigrationTests.NewerSchema_RaisesVersionError;
var
    Migrator: TDatabaseMigrator;
begin
    FConn.ExecSQL('PRAGMA user_version = ' + IntToStr(APP_DB_VERSION + 1));

    Migrator := TDatabaseMigrator.Create(FConn, ':memory:', LoadMigrationSQL);
    try
        Assert.WillRaise(
            procedure
            begin
                Migrator.Run;
            end,
            ESchemaVersionError);
    finally
        Migrator.Free;
    end;
end;

procedure TDbMigrationTests.RealFile_CreatesBackup_AndPrunesOld;
var
    Conn: TFDConnection;
    DbFile, TempDir: string;
    I: Integer;
    Migrator: TDatabaseMigrator;
begin
    TempDir := TPath.Combine(TPath.GetTempPath, 'ssk_mig_' + TGuid.NewGuid.ToString);
    TDirectory.CreateDirectory(TempDir);
    DbFile := TPath.Combine(TempDir, 'test.sqlite');

    Conn := TFDConnection.Create(nil);
    try
        Conn.Params.Add('DriverID=SQLite');
        Conn.Params.Add('Database=' + DbFile);
        Conn.Connected := True;
        Conn.ExecSQL('PRAGMA foreign_keys = ON');

        // Четыре прогона с сбросом версии: каждый должен оставить резервную копию,
        // а раннер - обрезать хвост, оставив только MIGRATION_BACKUP_KEEP последних
        for I := 1 to 4 do
        begin
            Conn.ExecSQL('PRAGMA user_version = 0');

            Migrator := TDatabaseMigrator.Create(Conn, DbFile, LoadMigrationSQL);
            try
                Migrator.Run;
                // С каждым сбросом версии накатываются все шаги реестра заново -
                // это заодно стресс-проверка идемпотентности каждой миграции
                Assert.IsTrue(Migrator.AppliedCount > 0);
                Assert.IsTrue(Migrator.BackupPath <> '');
            finally
                Migrator.Free;
            end;
        end;

        Assert.AreEqual(Integer(MIGRATION_BACKUP_KEEP),
            Integer(Length(TDirectory.GetFiles(TempDir, 'test.sqlite.backup-*.bak'))));
        Assert.AreEqual(Integer(APP_DB_VERSION), Integer(Conn.ExecSQLScalar('PRAGMA user_version')));
    finally
        Conn.Free;
        TDirectory.Delete(TempDir, True);
    end;
end;

procedure TDbMigrationTests.Backup_ToCustomTarget;
var
    Conn, SnapshotConn: TFDConnection;
    DbFile, TempDir, Target: string;
    Migrator: TDatabaseMigrator;
begin
    TempDir := TPath.Combine(TPath.GetTempPath, 'ssk_mig_' + TGuid.NewGuid.ToString);
    TDirectory.CreateDirectory(TempDir);
    DbFile := TPath.Combine(TempDir, 'test.sqlite');
    Target := TPath.Combine(TempDir, 'custom_name.db');

    Conn := TFDConnection.Create(nil);
    try
        Conn.Params.Add('DriverID=SQLite');
        Conn.Params.Add('Database=' + DbFile);
        Conn.Connected := True;
        Conn.ExecSQL('PRAGMA journal_mode = WAL');
        Conn.ExecSQL('CREATE TABLE t (v TEXT)');
        Conn.ExecSQL('INSERT INTO t VALUES (''data'')');

        Migrator := TDatabaseMigrator.Create(Conn, DbFile, LoadMigrationSQL);
        try
            Migrator.CreateBackup(Target);
            Assert.AreEqual(Target, Migrator.BackupPath);
        finally
            Migrator.Free;
        end;

        // Кастомная копия не участвует в ротации stamped-копий
        Assert.AreEqual(0, Integer(Length(TDirectory.GetFiles(TempDir, 'test.sqlite.backup-*.bak'))));

        SnapshotConn := TFDConnection.Create(nil);
        try
            SnapshotConn.Params.Add('DriverID=SQLite');
            SnapshotConn.Params.Add('Database=' + Target);
            SnapshotConn.Connected := True;

            Assert.AreEqual('ok', string(SnapshotConn.ExecSQLScalar('PRAGMA integrity_check')));
            Assert.AreEqual(1, Integer(SnapshotConn.ExecSQLScalar('SELECT COUNT(*) FROM t')));
        finally
            SnapshotConn.Free;
        end;
    finally
        Conn.Free;
        TDirectory.Delete(TempDir, True);
    end;
end;

procedure TDbMigrationTests.Backup_WhileAnotherConnectionWrites;
var
    ConnA, ConnB, SnapshotConn: TFDConnection;
    DbFile, SnapshotFile, TempDir: string;
    Migrator: TDatabaseMigrator;

    // Параметры соединения, обязательные для работы WAL-снапшота рядом
    // с другим соединением: SharedCache=False убирает табличные блокировки
    // внутри процесса; JournalMode/LockingMode перекрывают дефолты FireDAC
    // (journal_mode=DELETE, locking_mode=Exclusive), из-за которых открытие
    // и чтение падают с busy
    procedure ApplySharedParams(AConn: TFDConnection);
    begin
        AConn.Params.Add('SharedCache=False');
        AConn.Params.Add('JournalMode=WAL');
        AConn.Params.Add('LockingMode=Normal');
    end;

begin
    // Ключ /backup при запущенном GUI: активная write-транзакция в другом
    // соединении не должна ломать снапшот (WAL-читатели не блокируются)
    TempDir := TPath.Combine(TPath.GetTempPath, 'ssk_mig_' + TGuid.NewGuid.ToString);
    TDirectory.CreateDirectory(TempDir);
    DbFile := TPath.Combine(TempDir, 'test.sqlite');

    ConnA := TFDConnection.Create(nil);
    ConnB := nil;
    SnapshotConn := nil;
    try
        ConnA.Params.Add('DriverID=SQLite');
        ConnA.Params.Add('Database=' + DbFile);
        ApplySharedParams(ConnA);
        ConnA.Connected := True;
        ConnA.ExecSQL('CREATE TABLE t (v TEXT)');

        // Незакоммиченная запись писателя: её не должно быть в снапшоте
        ConnA.StartTransaction;
        ConnA.ExecSQL('INSERT INTO t VALUES (''uncommitted'')');

        ConnB := TFDConnection.Create(nil);
        ConnB.Params.Add('DriverID=SQLite');
        ConnB.Params.Add('Database=' + DbFile);
        ApplySharedParams(ConnB);
        // FireDAC сбрасывает busy_timeout перед каждым оператором
        // при LockWait=False (дефолт)
        ConnB.Params.Add('BusyTimeout=5000');
        ConnB.UpdateOptions.LockWait := True;
        ConnB.Connected := True;

        Migrator := TDatabaseMigrator.Create(ConnB, DbFile, LoadMigrationSQL);
        try
            Migrator.CreateBackup;
            SnapshotFile := Migrator.BackupPath;
        finally
            Migrator.Free;
        end;

        Assert.IsTrue(SnapshotFile <> '');
        Assert.IsTrue(TFile.Exists(SnapshotFile));

        SnapshotConn := TFDConnection.Create(nil);
        SnapshotConn.Params.Add('DriverID=SQLite');
        SnapshotConn.Params.Add('Database=' + SnapshotFile);
        SnapshotConn.Connected := True;

        Assert.AreEqual('ok', string(SnapshotConn.ExecSQLScalar('PRAGMA integrity_check')));
        Assert.AreEqual(1, Integer(SnapshotConn.ExecSQLScalar(
            'SELECT COUNT(*) FROM sqlite_master WHERE type = ''table'' AND name = ''t''')));
        Assert.AreEqual(0, Integer(SnapshotConn.ExecSQLScalar('SELECT COUNT(*) FROM t')));
    finally
        if ConnA.InTransaction then
            ConnA.Rollback;
        SnapshotConn.Free;
        ConnB.Free;
        ConnA.Free;
        TDirectory.Delete(TempDir, True);
    end;
end;

procedure TDbMigrationTests.BaselineScript_AppliesInSingleTransaction;
var
    Script: TFDScript;
begin
    // Как в TAppDatabase.InitializeDatabase и ExecuteNewDbCommand:
    // BreakOnError=True, baseline (схема+seed) в BEGIN...COMMIT,
    // foreign_keys отключается снаружи (внутри транзакции - no-op)
    Script := TFDScript.Create(nil);
    try
        Script.Connection := FConn;
        Script.ScriptOptions.BreakOnError := True;
        Script.SQLScripts.Add.SQL.Text :=
            'BEGIN;' + sLineBreak +
            TFile.ReadAllText(SchemaFilePath('000_schema_init.sql'), TEncoding.UTF8) +
            TFile.ReadAllText(SchemaFilePath('000_seed_data_full.sql'), TEncoding.UTF8) +
            sLineBreak + 'COMMIT;';
        FConn.ExecSQL('PRAGMA foreign_keys = OFF');
        try
            Script.ExecuteAll;
        finally
            FConn.ExecSQL('PRAGMA foreign_keys = ON');
        end;
    finally
        Script.Free;
    end;

    Assert.AreEqual(Integer(APP_DB_VERSION),
        Integer(FConn.ExecSQLScalar('PRAGMA user_version')));
    Assert.AreEqual('ok', string(FConn.ExecSQLScalar('PRAGMA integrity_check')));
    Assert.IsTrue(Integer(FConn.ExecSQLScalar('SELECT COUNT(*) FROM users')) > 0);
end;

procedure TDbMigrationTests.FailedScript_RollsBackWholeTransaction;
var
    Script: TFDScript;
    Threw: Boolean;
begin
    // Сбой посреди скрипта (BreakOnError=True, как в проде) прерывает
    // выполнение, а незавершённая транзакция откатывается целиком:
    // таблица-маркер не должна остаться
    Threw := False;
    Script := TFDScript.Create(nil);
    try
        Script.Connection := FConn;
        Script.ScriptOptions.BreakOnError := True;
        Script.SQLScripts.Add.SQL.Text :=
            'BEGIN;' + sLineBreak +
            'CREATE TABLE rollback_probe (v INTEGER);' + sLineBreak +
            'INSERT INTO no_such_table VALUES (1);' + sLineBreak +
            'COMMIT;';
        try
            Script.ExecuteAll;
        except
            Threw := True;
        end;
    finally
        Script.Free;
    end;

    Assert.IsTrue(Threw);
    // Откат незавершённой транзакции: маркерная таблица исчезает
    if FConn.InTransaction then
        FConn.Rollback;
    Assert.AreEqual(0, Integer(FConn.ExecSQLScalar(
        'SELECT COUNT(*) FROM sqlite_master ' +
        'WHERE type = ''table'' AND name = ''rollback_probe''')));
end;

initialization
    // Параметры драйвера FireDAC (VendorLib/EngineLinkage) берутся из
    // ПЕРВОГО зарегистрированного link-компонента процесса. Без mc-движка
    // здесь драйвер грузит статическую сборку без sqlite3_key, и все
    // шифрованные сценарии падают с -303
    GDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
    ApplyEngineLinkage(GDriverLink);

finalization
    GDriverLink.Free;

end.
