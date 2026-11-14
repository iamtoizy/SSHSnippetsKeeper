unit Tests.DatabaseEncryption;

// Roundtrip шифрования БД на реальном FireDAC: динамическая DLL
// sqlite3mc_x64.dll (SQLite3 Multiple Ciphers, SQLite 3.54 + ChaCha20-
// Poly1305) через ApplyEngineParams/ApplyEncryptionParams. Проверяются
// и обычные (незашифрованные) БД на том же движке, и поиск trigram FTS5
// внутри зашифрованной БД - ровно то, что не умеет статическая FDE-сборка.
// Без DLL рядом с тестом тесты пропускаются: в этом окружении шифрование
// недоступно

interface

uses
    DUnitX.TestFramework,
    FireDAC.Comp.Client,
    FireDAC.Comp.Script,
    FireDAC.Comp.ScriptCommands,
    FireDAC.Phys.SQLite,
    System.Classes,
    System.NetEncoding,
    System.SysUtils,
    System.IOUtils
    ;

type
    [TestFixture]
    TDbEncryptionRoundtripTests = class(TObject)
    private
        FDriverLink: TFDPhysSQLiteDriverLink;

        function DbPath: string;
        procedure CleanupFiles;
        function NewConnection(const AKey: string; APlain: Boolean = False): TFDConnection;
        function KeyMaterial(ASeed: Byte): string;
        procedure CreateEncryptedFixture(const AKey: string);
        function SchemaPath(const Filename: string): string;
        procedure ExecSchema(AConn: TFDConnection);
        function McDllAvailable: Boolean;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test]
        procedure PlainDb_Roundtrip_OnMcEngine;
        [Test]
        procedure Encrypt_CreateReopen_DataPreserved;
        [Test]
        procedure Encrypt_TrigramFts_SearchWorks;
        [Test]
        procedure Encrypt_WrongKey_OpenFails;
        [Test]
        procedure Encrypt_MissingKey_OpenFails;
        [Test]
        procedure Convert_EncryptPlainDb_DataSurvives_PlainOpenFails;
        [Test]
        procedure Convert_DecryptEncryptedDb_OpensPlain;
        [Test]
        procedure Detect_PlainDb_MagicMatched;
        [Test]
        procedure Detect_EncryptedDb_MagicAbsent;
        [Test]
        procedure Detect_MissingOrShortFile_TreatedPlain;
        [Test]
        procedure Detect_CorruptMagic_TreatedEncrypted;
    end;

implementation

uses
    Data.Database.Security
    ;

{ TDbEncryptionRoundtripTests }

function TDbEncryptionRoundtripTests.McDllAvailable: Boolean;
begin
    Result := DbEngineDllAvailable;
end;

function TDbEncryptionRoundtripTests.DbPath: string;
begin
    Result := TPath.Combine(TPath.GetTempPath, 'ssk_enc_roundtrip.sqlite');
end;

procedure TDbEncryptionRoundtripTests.CleanupFiles;
begin
    if TFile.Exists(DbPath) then
        TFile.Delete(DbPath);
    if TFile.Exists(DbPath + '-wal') then
        TFile.Delete(DbPath + '-wal');
    if TFile.Exists(DbPath + '-shm') then
        TFile.Delete(DbPath + '-shm');
end;

function TDbEncryptionRoundtripTests.KeyMaterial(ASeed: Byte): string;
var
    Raw: TBytes;
    I: Integer;
begin
    SetLength(Raw, 32);
    for I := 0 to High(Raw) do
        Raw[I] := Byte(ASeed + I);
    Result := TNetEncoding.Base64.EncodeBytesToString(Raw);
end;

function TDbEncryptionRoundtripTests.SchemaPath(const Filename: string): string;
var
    Dir: string;
begin
    Dir := TPath.GetDirectoryName(ParamStr(0));
    repeat
        Result := TPath.Combine(Dir, TPath.Combine('Database', TPath.Combine('Schema', Filename)));
        if TFile.Exists(Result) then
            Exit;
        Dir := TPath.GetDirectoryName(Dir);
    until Dir = '';
    raise Exception.Create('Schema file not found: ' + Result);
end;

procedure TDbEncryptionRoundtripTests.ExecSchema(AConn: TFDConnection);
var
    Script: TFDScript;
begin
    Script := TFDScript.Create(nil);
    try
        Script.Connection := AConn;
        // Ошибка statement обязана прерывать скрипт: частичная схема
        // не должна выглядеть как успешное применение
        Script.ScriptOptions.BreakOnError := True;
        Script.SQLScripts.Add.SQL.Text :=
            TFile.ReadAllText(SchemaPath('000_schema_init.sql'), TEncoding.UTF8);
        Script.ExecuteAll;
    finally
        Script.Free;
    end;
end;

procedure TDbEncryptionRoundtripTests.CreateEncryptedFixture(const AKey: string);
var
    Conn: TFDConnection;
begin
    Conn := NewConnection(AKey);
    try
        Conn.Connected := True;
        Conn.ExecSQL('CREATE TABLE t (v TEXT)');
        Conn.ExecSQL('INSERT INTO t VALUES (''secret-row'')');
    finally
        Conn.Free;
    end;
end;

function TDbEncryptionRoundtripTests.NewConnection(const AKey: string; APlain: Boolean): TFDConnection;
begin
    Result := TFDConnection.Create(nil);
    Result.Params.Add('DriverID=SQLite');
    Result.Params.Add('Database=' + DbPath);
    // Как в TAppDatabase.Connect: WAL задаётся параметром, не PRAGMA
    Result.Params.Add('JournalMode=WAL');
    Result.Params.Add('CharacterSet=utf8');
    if not APlain then
        ApplyEncryptionParams(Result.Params, AKey);
end;

procedure TDbEncryptionRoundtripTests.Setup;
begin
    CleanupFiles;
    FDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
    ApplyEngineLinkage(FDriverLink);
end;

procedure TDbEncryptionRoundtripTests.TearDown;
begin
    FreeAndNil(FDriverLink);
    CleanupFiles;
end;

procedure TDbEncryptionRoundtripTests.PlainDb_Roundtrip_OnMcEngine;
var
    Conn: TFDConnection;
begin
    if not McDllAvailable then
        Exit;

    // Обычная БД без параметров шифрования на том же mc-движке
    Conn := NewConnection('', True);
    try
        Conn.Connected := True;
        Conn.ExecSQL('CREATE TABLE t (v TEXT)');
        Conn.ExecSQL('INSERT INTO t VALUES (''hello'')');
        Assert.AreEqual('hello', string(Conn.ExecSQLScalar('SELECT v FROM t')));
    finally
        Conn.Free;
    end;
end;

procedure TDbEncryptionRoundtripTests.Encrypt_CreateReopen_DataPreserved;
var
    Conn: TFDConnection;
begin
    if not McDllAvailable then
        Exit;

    CreateEncryptedFixture(KeyMaterial($A0));

    // Повторное открытие с тем же ключом: данные читаются
    Conn := NewConnection(KeyMaterial($A0));
    try
        Conn.Connected := True;
        Assert.AreEqual('secret-row', string(Conn.ExecSQLScalar('SELECT v FROM t')));
    finally
        Conn.Free;
    end;
end;

procedure TDbEncryptionRoundtripTests.Encrypt_TrigramFts_SearchWorks;
var
    Conn: TFDConnection;
begin
    if not McDllAvailable then
        Exit;

    // Ключевая проверка комбинации: trigram FTS5 из рабочей схемы внутри
    // зашифрованной БД (то, что не умеет статическая FDE-сборка 3.31.1)
    Conn := NewConnection(KeyMaterial($A0));
    try
        Conn.Connected := True;
        ExecSchema(Conn);
        Conn.ExecSQL('INSERT INTO snippet_fts(title, content, comment, tags) ' +
            'VALUES (''deploy'', ''run the deploy script now'', '''', '''')');
        Assert.AreEqual(1, Integer(Conn.ExecSQLScalar(
            'SELECT COUNT(*) FROM snippet_fts WHERE snippet_fts MATCH ''deploy''')));
        // Подстрока внутри слова - именно ради этого выбран trigram
        Assert.AreEqual(1, Integer(Conn.ExecSQLScalar(
            'SELECT COUNT(*) FROM snippet_fts WHERE snippet_fts MATCH ''ploy scr''')));
    finally
        Conn.Free;
    end;
end;

procedure TDbEncryptionRoundtripTests.Encrypt_WrongKey_OpenFails;
var
    Conn: TFDConnection;
begin
    if not McDllAvailable then
        Exit;

    CreateEncryptedFixture(KeyMaterial($A0));

    // Неверный ключ: ошибка возникает при открытии или первом чтении
    // (SQLite читает первую страницу в PRAGMA journal_mode)
    Conn := NewConnection(KeyMaterial($5A));
    try
        Assert.WillRaise(
            procedure
            begin
                Conn.Connected := True;
                Conn.ExecSQLScalar('SELECT COUNT(*) FROM t');
            end);
    finally
        Conn.Free;
    end;
end;

procedure TDbEncryptionRoundtripTests.Encrypt_MissingKey_OpenFails;
var
    Conn: TFDConnection;
begin
    if not McDllAvailable then
        Exit;

    CreateEncryptedFixture(KeyMaterial($A0));

    // Открытие зашифрованного файла без ключа - тоже ошибка, а не тихий сбой
    Conn := NewConnection('', True);
    try
        Assert.WillRaise(
            procedure
            begin
                Conn.Connected := True;
                Conn.ExecSQLScalar('SELECT COUNT(*) FROM t');
            end);
    finally
        Conn.Free;
    end;
end;

procedure TDbEncryptionRoundtripTests.Convert_EncryptPlainDb_DataSurvives_PlainOpenFails;
var
    Conn: TFDConnection;
begin
    if not McDllAvailable then
        Exit;

    // 1. Открытая БД с данными
    Conn := NewConnection('', True);
    try
        Conn.Connected := True;
        Conn.ExecSQL('CREATE TABLE t (v TEXT)');
        Conn.ExecSQL('INSERT INTO t VALUES (''secret-row'')');
    finally
        Conn.Free;
    end;

    // 2. Зашифровать: rekey без старого ключа
    ConvertDatabaseEncryption(DbPath, '', KeyMaterial($A0));

    // 3. С ключом данные читаются
    Conn := NewConnection(KeyMaterial($A0));
    try
        Conn.Connected := True;
        Assert.AreEqual('secret-row', string(Conn.ExecSQLScalar('SELECT v FROM t')));
    finally
        Conn.Free;
    end;

    // 4. Без ключа - ошибка, а не тихое чтение открытой копии
    Conn := NewConnection('', True);
    try
        Assert.WillRaise(
            procedure
            begin
                Conn.Connected := True;
                Conn.ExecSQLScalar('SELECT COUNT(*) FROM t');
            end);
    finally
        Conn.Free;
    end;
end;

procedure TDbEncryptionRoundtripTests.Convert_DecryptEncryptedDb_OpensPlain;
var
    Conn: TFDConnection;
begin
    if not McDllAvailable then
        Exit;

    CreateEncryptedFixture(KeyMaterial($A0));

    // Снять шифрование: rekey с пустым новым ключом
    ConvertDatabaseEncryption(DbPath, KeyMaterial($A0), '');

    Conn := NewConnection('', True);
    try
        Conn.Connected := True;
        Assert.AreEqual('secret-row', string(Conn.ExecSQLScalar('SELECT v FROM t')));
    finally
        Conn.Free;
    end;
end;

procedure TDbEncryptionRoundtripTests.Detect_PlainDb_MagicMatched;
var
    Conn: TFDConnection;
begin
    if not McDllAvailable then
        Exit;

    // Незашифрованная БД на том же движке: магия в заголовке
    Conn := NewConnection('', True);
    try
        Conn.Connected := True;
        Conn.ExecSQL('CREATE TABLE t (v TEXT)');
    finally
        Conn.Free;
    end;

    Assert.IsTrue(DbFileIsPlain(DbPath));
end;

procedure TDbEncryptionRoundtripTests.Detect_EncryptedDb_MagicAbsent;
begin
    if not McDllAvailable then
        Exit;

    // mc шифрует и заголовок: магии на смещении 0 быть не должно
    CreateEncryptedFixture(KeyMaterial($A0));
    Assert.IsFalse(DbFileIsPlain(DbPath));
end;

procedure TDbEncryptionRoundtripTests.Detect_MissingOrShortFile_TreatedPlain;
var
    Buf: array[0..7] of Byte;
    Fs: TFileStream;
begin
    // Файла нет - незашифрованный (создастся при открытии)
    Assert.IsTrue(DbFileIsPlain(DbPath));

    // Короткий файл (меньше 16 байт) - тоже незашифрованный
    FillChar(Buf, SizeOf(Buf), $AA);
    Fs := TFileStream.Create(DbPath, fmCreate);
    try
        Fs.WriteBuffer(Buf, SizeOf(Buf));
    finally
        Fs.Free;
    end;
    Assert.IsTrue(DbFileIsPlain(DbPath));
end;

procedure TDbEncryptionRoundtripTests.Detect_CorruptMagic_TreatedEncrypted;
var
    Buf: array[0..31] of Byte;
    I: Integer;
    Fs: TFileStream;
begin
    // Похожая на магию, но битая сигнатура - не незашифрованный файл
    for I := 0 to High(Buf) do
        Buf[I] := $5A;
    Buf[0] := Ord('S');
    Buf[1] := Ord('Q');
    Buf[2] := Ord('L');
    Buf[3] := Ord('i');
    Buf[4] := Ord('t');
    Buf[5] := Ord('e');
    Buf[6] := Ord(' ');
    Buf[7] := Ord('f');
    Buf[8] := Ord('o');
    Buf[9] := Ord('r');
    Buf[10] := Ord('m');
    Buf[11] := Ord('a');
    Buf[12] := Ord('t');
    Buf[13] := Ord(' ');
    Buf[14] := Ord('3');
    Buf[15] := Ord('X');
    Fs := TFileStream.Create(DbPath, fmCreate);
    try
        Fs.WriteBuffer(Buf, SizeOf(Buf));
    finally
        Fs.Free;
    end;
    Assert.IsFalse(DbFileIsPlain(DbPath));
end;

end.
