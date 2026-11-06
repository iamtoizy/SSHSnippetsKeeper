unit Tests.AutoBackup;

interface

uses
    DUnitX.TestFramework,
    FireDAC.Comp.Client
    ;

type
    [TestFixture]
    TAutoBackupTests = class(TObject)
    private
        FConn: TFDConnection;
        FMemConn: TFDConnection;
        FTempDir: string;
        FDbFile: string;
        function AutoBackups: TArray<string>;
        procedure WriteFakeBackup(const AStamp: TDateTime);
        function FakeBackupPath(const AStamp: TDateTime): string;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;
        [Test]
        procedure Create_WritesSnapshotNextToDatabase;
        [Test]
        procedure Create_RepeatedImmediately_SkippedByInterval;
        [Test]
        procedure Rotation_KeepsLatestThree;
        [Test]
        procedure MemoryDatabase_ReturnsEmpty;
        [Test]
        procedure IntervalGuard_ConfiguredInterval_SkipsFreshCopy;
        [Test]
        procedure IntervalGuard_OldCopy_CreatesNew;
        [Test]
        procedure ForceCreate_BypassesInterval;
        [Test]
        procedure Rotation_ConfigurableKeep;
        [Test]
        procedure Standalone_CreatesBackupOnOwnConnection;
        [Test]
        procedure AutoBackupDue_NoBackups_True;
        [Test]
        procedure AutoBackupDue_FreshCopy_False;
        [Test]
        procedure AutoBackupDue_OldCopy_True;
        [Test]
        procedure FindLatest_ReturnsNewestWithStamp;
        [Test]
        procedure FindLatest_NoBackups_EmptyPath;
    end;

implementation

uses
    System.DateUtils,
    System.SysUtils,
    System.IOUtils,
    Data.Database.Migrations
    ;

procedure TAutoBackupTests.Setup;
begin
    // Уникальная папка на тест: страж интервала опирается на метки времени
    // в именах файлов рядом с БД, поэтому тесты не должны видеть чужие бэкапы
    FTempDir := TPath.Combine(TPath.GetTempPath, 'SSK_AutoBackup_' +
        TGuid.NewGuid.ToString);
    TDirectory.CreateDirectory(FTempDir);

    FDbFile := TPath.Combine(FTempDir, 'test.snippets.sqlite');

    FConn := TFDConnection.Create(nil);
    FConn.Params.Add('DriverID=SQLite');
    FConn.Params.Add('Database=' + FDbFile);
    // Подключение само создаёт файл БД - CreateAutoBackup требует существующий файл
    FConn.Connected := True;

    FMemConn := nil;
end;

procedure TAutoBackupTests.TearDown;
begin
    FreeAndNil(FConn);
    FreeAndNil(FMemConn);
    if FTempDir <> '' then
    try
        TDirectory.Delete(FTempDir, True);
    except
        on E: Exception do ;
    end;
end;

function TAutoBackupTests.AutoBackups: TArray<string>;
begin
    Result := TDirectory.GetFiles(FTempDir, '*.auto_*.bak');
end;

// Фейковая копия с заданной меткой времени в имени (содержимое не важно -
// страж интервала и ротация работают по именам)
procedure TAutoBackupTests.WriteFakeBackup(const AStamp: TDateTime);
begin
    TFile.WriteAllText(FakeBackupPath(AStamp), 'fake');
end;

function TAutoBackupTests.FakeBackupPath(const AStamp: TDateTime): string;
begin
    Result := TPath.Combine(FTempDir, ExtractFileName(FDbFile) +
        '.auto_' + FormatDateTime('yyyymmdd_hhnnsszzz', AStamp) + '.bak');
end;

procedure TAutoBackupTests.Create_WritesSnapshotNextToDatabase;
var
    BackupFile: string;
begin
    BackupFile := CreateAutoBackup(FConn, FDbFile);

    Assert.IsNotEmpty(BackupFile);
    Assert.IsTrue(TFile.Exists(BackupFile), 'файл бэкапа не создан');
    Assert.IsTrue(ExtractFileName(BackupFile)
        .StartsWith(ExtractFileName(FDbFile) + '.auto_'),
        'неожиданное имя файла бэкапа: ' + BackupFile);
    Assert.AreEqual(1, Integer(Length(AutoBackups)));
end;

procedure TAutoBackupTests.Create_RepeatedImmediately_SkippedByInterval;
var
    First, Second: string;
begin
    First := CreateAutoBackup(FConn, FDbFile);
    Assert.IsNotEmpty(First);

    // Повторный вызов сразу же: свежайшая копия моложе дефолтного интервала
    // (сутки) - новый снапшот не нужен
    Second := CreateAutoBackup(FConn, FDbFile);
    Assert.AreEqual('', Second);
    Assert.AreEqual(1, Integer(Length(AutoBackups)));
end;

procedure TAutoBackupTests.Rotation_KeepsLatestThree;
var
    I: Integer;
    BackupFile: string;
    Names: TArray<string>;
begin
    // Три «старых» бэкапа с фейковыми датами (содержимое не важно -
    // ротация работает по именам)
    for I := 1 to 3 do
        WriteFakeBackup(EncodeDateTime(2024, 1, I, 12, 0, 0, 0));

    BackupFile := CreateAutoBackup(FConn, FDbFile);
    Assert.IsNotEmpty(BackupFile);

    // Дефолтная ротация AUTO_BACKUP_KEEP = 3: осталась сегодняшняя копия
    // и две самые свежие из фейковых, самая старая (20240101) удалена
    Names := AutoBackups;
    Assert.AreEqual(3, Integer(Length(Names)));
    Assert.IsFalse(TFile.Exists(FakeBackupPath(EncodeDateTime(2024, 1, 1, 12, 0, 0, 0))),
        'старейший бэкап не удалён');
    Assert.IsTrue(TFile.Exists(FakeBackupPath(EncodeDateTime(2024, 1, 3, 12, 0, 0, 0))),
        'свежий фейковый бэкап удалён ошибочно');
end;

procedure TAutoBackupTests.MemoryDatabase_ReturnsEmpty;
var
    BackupFile: string;
begin
    FMemConn := TFDConnection.Create(nil);
    FMemConn.Params.Add('DriverID=SQLite');
    FMemConn.Params.Add('Database=:memory:');
    FMemConn.Connected := True;

    BackupFile := CreateAutoBackup(FMemConn, ':memory:');
    Assert.AreEqual('', BackupFile);
end;

procedure TAutoBackupTests.IntervalGuard_ConfiguredInterval_SkipsFreshCopy;
var
    First, Second: string;
begin
    // Копия только что создана: она моложе часа - часовой интервал пропускает
    First := CreateAutoBackup(FConn, FDbFile, 3600, AUTO_BACKUP_KEEP);
    Assert.IsNotEmpty(First);

    Second := CreateAutoBackup(FConn, FDbFile, 3600, AUTO_BACKUP_KEEP);
    Assert.AreEqual('', Second);
    Assert.AreEqual(1, Integer(Length(AutoBackups)));
end;

procedure TAutoBackupTests.IntervalGuard_OldCopy_CreatesNew;
var
    BackupFile: string;
begin
    // Последняя копия два часа назад: часовой интервал истёк - создаётся новая
    WriteFakeBackup(IncHour(Now, -2));

    BackupFile := CreateAutoBackup(FConn, FDbFile, 3600, AUTO_BACKUP_KEEP);
    Assert.IsNotEmpty(BackupFile);
    Assert.AreEqual(2, Integer(Length(AutoBackups)));
end;

procedure TAutoBackupTests.ForceCreate_BypassesInterval;
var
    First, Second: string;
begin
    First := CreateAutoBackup(FConn, FDbFile);
    Assert.IsNotEmpty(First);

    // AForce = «Создать копию сейчас»: интервал игнорируется, копия создаётся
    Second := CreateAutoBackup(FConn, FDbFile,
        AUTO_BACKUP_INTERVAL_SECONDS, AUTO_BACKUP_KEEP, True);
    Assert.IsNotEmpty(Second);
    Assert.AreNotEqual(First, Second, 'создалась копия с тем же именем');
    Assert.AreEqual(2, Integer(Length(AutoBackups)));
end;

procedure TAutoBackupTests.Rotation_ConfigurableKeep;
var
    I: Integer;
    Names: TArray<string>;
begin
    for I := 1 to 3 do
        WriteFakeBackup(EncodeDateTime(2024, 1, I, 12, 0, 0, 0));

    // AKeep = 2: после создания новой копии остаются только две свежайшие
    CreateAutoBackup(FConn, FDbFile, AUTO_BACKUP_INTERVAL_SECONDS, 2);

    Names := AutoBackups;
    Assert.AreEqual(2, Integer(Length(Names)));
    Assert.IsTrue(TFile.Exists(FakeBackupPath(EncodeDateTime(2024, 1, 3, 12, 0, 0, 0))),
        'свежайшая фейковая копия удалена ошибочно');
    Assert.IsFalse(TFile.Exists(FakeBackupPath(EncodeDateTime(2024, 1, 2, 12, 0, 0, 0))),
        'копия сверх лимита не удалена');
    Assert.IsFalse(TFile.Exists(FakeBackupPath(EncodeDateTime(2024, 1, 1, 12, 0, 0, 0))),
        'копия сверх лимита не удалена');
end;

procedure TAutoBackupTests.Standalone_CreatesBackupOnOwnConnection;
var
    BackupFile: string;
begin
    // Отдельное соединение открывается параллельно с уже открытым FConn:
    // WAL позволяет читателю VACUUM INTO работать рядом с другим соединением
    BackupFile := CreateAutoBackupStandalone(FDbFile);

    Assert.IsNotEmpty(BackupFile);
    Assert.IsTrue(TFile.Exists(BackupFile), 'файл бэкапа не создан');
    Assert.AreEqual(1, Integer(Length(AutoBackups)));
end;

procedure TAutoBackupTests.AutoBackupDue_NoBackups_True;
begin
    // Копий нет: интервал считается истёкшим - бэкап нужен
    Assert.IsTrue(AutoBackupDue(FDbFile, 86400));
end;

procedure TAutoBackupTests.AutoBackupDue_FreshCopy_False;
begin
    Assert.IsNotEmpty(CreateAutoBackup(FConn, FDbFile));

    // Свежайшая копия моложе интервала - не истёк
    Assert.IsFalse(AutoBackupDue(FDbFile, 86400));

    // Нулевой интервал истекает сразу
    Assert.IsTrue(AutoBackupDue(FDbFile, 0));
end;

procedure TAutoBackupTests.AutoBackupDue_OldCopy_True;
begin
    // Последняя копия два часа назад: часовой интервал истёк, трёхчасовой нет
    WriteFakeBackup(IncHour(Now, -2));

    Assert.IsTrue(AutoBackupDue(FDbFile, 3600));
    Assert.IsFalse(AutoBackupDue(FDbFile, 3 * 3600));
end;

procedure TAutoBackupTests.FindLatest_ReturnsNewestWithStamp;
var
    Expected: TDateTime;
    Latest: string;
    Stamp: TDateTime;
begin
    Expected := EncodeDateTime(2024, 5, 2, 11, 0, 0, 0);
    WriteFakeBackup(EncodeDateTime(2024, 5, 1, 10, 0, 0, 0));
    WriteFakeBackup(Expected);

    Latest := FindLatestAutoBackup(FDbFile, Stamp);

    Assert.AreEqual(FakeBackupPath(Expected), Latest, 'путь свежайшей копии');
    Assert.IsTrue(Abs(Stamp - Expected) < 1 / SecsPerDay,
        'метка времени не распознана из имени файла');
end;

procedure TAutoBackupTests.FindLatest_NoBackups_EmptyPath;
var
    Latest: string;
    Stamp: TDateTime;
begin
    Latest := FindLatestAutoBackup(FDbFile, Stamp);

    Assert.AreEqual('', Latest);
    Assert.IsTrue(Abs(Stamp) < 1 / SecsPerDay, 'метка должна быть нулевой');
end;

end.
