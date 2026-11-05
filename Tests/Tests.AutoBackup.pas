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
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;
        [Test]
        procedure Create_WritesSnapshotNextToDatabase;
        [Test]
        procedure Create_TwicePerDay_SecondSkipped;
        [Test]
        procedure Rotation_KeepsLatestThree;
        [Test]
        procedure MemoryDatabase_ReturnsEmpty;
    end;

implementation

uses
    System.SysUtils,
    System.IOUtils,
    Data.Database.Migrations
    ;

procedure TAutoBackupTests.Setup;
begin
    // Уникальная папка на тест: страж «раз в сутки» опирается на имена
    // файлов рядом с БД, поэтому тесты не должны видеть чужие бэкапы
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

procedure TAutoBackupTests.Create_TwicePerDay_SecondSkipped;
var
    First, Second: string;
begin
    First := CreateAutoBackup(FConn, FDbFile);
    Assert.IsNotEmpty(First);

    // Повторный вызов в тот же день: новый снапшот не нужен
    Second := CreateAutoBackup(FConn, FDbFile);
    Assert.AreEqual('', Second);
    Assert.AreEqual(1, Integer(Length(AutoBackups)));
end;

procedure TAutoBackupTests.Rotation_KeepsLatestThree;
var
    I: Integer;
    BackupFile: string;
    Names: TArray<string>;
    DbName: string;
begin
    DbName := ExtractFileName(FDbFile);

    // Три «старых» бэкапа с фейковыми датами (содержимое не важно -
    // ротация работает по именам)
    for I := 1 to 3 do
        TFile.WriteAllText(TPath.Combine(FTempDir, DbName +
            Format('.auto_2024010%d_120000000.bak', [I])), 'fake');

    BackupFile := CreateAutoBackup(FConn, FDbFile);
    Assert.IsNotEmpty(BackupFile);

    // AUTO_BACKUP_KEEP = 3: осталась сегодняшняя копия и две самые свежие
    // из фейковых, самая старая (20240101) удалена
    Names := AutoBackups;
    Assert.AreEqual(3, Integer(Length(Names)));
    Assert.IsFalse(TFile.Exists(TPath.Combine(FTempDir, DbName +
        '.auto_20240101_120000000.bak')), 'старейший бэкап не удалён');
    Assert.IsTrue(TFile.Exists(TPath.Combine(FTempDir, DbName +
        '.auto_20240103_120000000.bak')), 'свежий фейковый бэкап удалён ошибочно');
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

end.
