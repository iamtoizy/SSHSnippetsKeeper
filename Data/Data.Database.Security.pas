unit Data.Database.Security;

// Мост между узлом Db настроек и параметрами соединения FireDAC.
// Всякие решения "как из настроек получить ключ для открытия БД" -
// только здесь; TAppDatabase и консольные пути вызывают хелперы.

interface

uses
    Core.Interfaces.Settings,
    FireDAC.Phys.SQLite,
    System.Classes,
    System.SysUtils
    ;

// Полный путь к DLL mc-движка рядом с exe ('' если каталог не определён)
function DbEngineDllPath: string;

// True, если DLL mc-движка найдена рядом с exe. Без DLL FireDAC
// остаётся на статическом движке: незашифрованные БД работают,
// зашифрованные открыть и создать нельзя
function DbEngineDllAvailable: Boolean;

// True, если узел Db настроек требует шифрованного открытия БД
function DbEncryptionEnabled(const ADb: TDbSecuritySettings): Boolean;

// Резолвит материал ключа из узла Db в base64-строку для параметра
// Password соединения FireDAC. Возвращает '' когда шифрование выключено
// или ключ отсутствует/битый - открытие тогда падает с ошибкой SQLite
// (NOTADB), что честнее тихого открытия незашифрованной копии
function DbKeyMaterial(const ADb: TDbSecuritySettings): string; overload;

// Материал сохранённого ключа из узла Db независимо от флага шифрования:
// флаг един на приложение и может относиться к другой базе, а файл
// зашифрован. Возвращает '' при пустом или битом ключе
function DbStoredKeyMaterial(const ADb: TDbSecuritySettings): string; overload;

// Профильные варианты тех же хелперов для TDbSecurityProfile: ключ
// конкретной базы (по нормализованному пути файла) вместо глобального
// слота Db. Флаг Encryption у профиля отсутствует - факт шифрования
// файла проверяет вызывающий код через DbFileIsPlain
function DbKeyMaterial(const AProfile: TDbSecurityProfile): string; overload;
function DbStoredKeyMaterial(const AProfile: TDbSecurityProfile): string; overload;

// True, если файл начинается с магии незашифрованного SQLite
// ('SQLite format 3' + нулевой байт на смещении 15): mc с дефолтными
// настройками шифрует и заголовок, поэтому у зашифрованного файла
// на смещении 0 случайные байты. Отсутствующий, короткий или
// нечитаемый файл трактуется как незашифрованный - его создаст
// соединение при открытии
function DbFileIsPlain(const ADatabaseFile: string): Boolean;

// Параметры движка SQLite: динамическая линковка и VendorLib на DLL
// SQLite3 Multiple Ciphers (современный SQLite + шифрование), лежащей
// рядом с exe. Оба параметра - уровня ДРАЙВЕРА: connection-параметр
// EngineLinkage до InternalLoad не доходит. Если DLL рядом с exe нет -
// свойства не трогаются, FireDAC остаётся на статическом движке
// (без шифрования), приложение продолжит работать с обычными БД
procedure ApplyEngineLinkage(ALink: TFDPhysSQLiteDriverLink);

// Добавляет параметры шифрования ('Encrypt=no', 'Password=...') в
// Params соединения. Encrypt=no запрещает FireDAC добавлять свой префикс
// 'aes-256:' к ключу (формат FDE-сборки): ключ передаётся в
// sqlite3_key как есть, SQLite3 Multiple Ciphers выбирает дефолтный
// шифр ChaCha20-Poly1305 с PBKDF2
procedure ApplyEncryptionParams(const AParams: TStrings; const AKeyBase64: string);

// Шифрование/дешифрование/смена ключа существующего файла БД одним
// PRAGMA rekey на короткоживущем соединении mc-движка:
//   AOldKeyBase64 = '' и ANewKeyBase64 <> ''  - зашифровать открытую БД;
//   AOldKeyBase64 <> '' и ANewKeyBase64 = ''  - снять шифрование;
//   оба непустые                              - сменить ключ.
// Вызывающий код обязан заранее закрыть соединения приложения и сделать
// резервную копию файла. Соединение открывается со старым ключом (или
// без ключа для открытой БД); JournalMode=DELETE гарантирует, что WAL
// слит в основной файл до rekey. Ключи - base64, спецсимволов SQL не
// содержат
procedure ConvertDatabaseEncryption(const ADatabaseFile: string;
    const AOldKeyBase64, ANewKeyBase64: string);

implementation

uses
    Common.DbCrypto,
    Common.Settings,
    FireDAC.Comp.Client,
    FireDAC.Phys.SQLiteWrapper,
    System.IOUtils,
    System.NetEncoding
    ;

const
    DB_VENDOR_DLL = 'sqlite3mc_x64.dll';

function DbEncryptionEnabled(const ADb: TDbSecuritySettings): Boolean;
begin
    Result := ADb.Encryption = DB_ENCRYPTION_AES256;
end;

function DbKeyMaterial(const ADb: TDbSecuritySettings): string;
begin
    Result := '';
    if not DbEncryptionEnabled(ADb) then
        Exit;
    Result := DbStoredKeyMaterial(ADb);
end;

// Общее ядро обоих DbStoredKeyMaterial-оверлоадов: разбирает блоб ключа
// (DPAPI над base64-строкой или открытая base64-строка в памяти)
function StoredKeyFromBlob(const AKeyBlob: string): string;
var
    KeyStr: string;
    Raw: TBytes;
begin
    Result := '';
    if AKeyBlob.IsEmpty then
        Exit;

    // Key в настройках - DPAPI-блоб над base64-СТРОКОЙ ключа (или открытая
    // base64-строка в памяти); UnprotectSecretToBytes прозрачно разбирает
    // оба варианта и возвращает байты самой строки. Декодируем base64 до
    // сырых DB_KEY_BYTES и валидируем длину: битый блоб или ключ другой
    // длины дают '' - открытие упадёт с NOTADB (см. DbKeyMaterial)
    try
        KeyStr := TEncoding.UTF8.GetString(UnprotectSecretToBytes(AKeyBlob));
        Raw := TNetEncoding.Base64.DecodeStringToBytes(KeyStr);
    except
        on E: Exception do
            Exit;
    end;
    try
        if Length(Raw) <> DB_KEY_BYTES then
            Exit;
        Result := KeyStr;
    finally
        WipeSecretBytes(Raw);
    end;
end;

function DbStoredKeyMaterial(const ADb: TDbSecuritySettings): string;
begin
    Result := StoredKeyFromBlob(ADb.Key);
end;

function DbKeyMaterial(const AProfile: TDbSecurityProfile): string;
begin
    // Профиль существует только для базы, работающей с шифрованием:
    // гейта по флагу Encryption, как у глобального слота, здесь нет
    Result := DbStoredKeyMaterial(AProfile);
end;

function DbStoredKeyMaterial(const AProfile: TDbSecurityProfile): string;
begin
    Result := StoredKeyFromBlob(AProfile.Key);
end;

function DbEngineDllPath: string;
begin
    // DLL ищем рядом с exe: загрузка по голому имени может подхватить
    // чужую sqlite3.dll из PATH
    Result := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), DB_VENDOR_DLL);
end;

function DbEngineDllAvailable: Boolean;
begin
    Result := TFile.Exists(DbEngineDllPath);
end;

function DbFileIsPlain(const ADatabaseFile: string): Boolean;
const
    // 'SQLite format 3' + завершающий нулевой байт
    SQLITE_MAGIC: array[0..15] of Byte = (
        $53, $51, $4C, $69, $74, $65, $20, $66,
        $6F, $72, $6D, $61, $74, $20, $33, $00);
var
    Fs: TFileStream;
    Buf: array[0..15] of Byte;
    I: Integer;
begin
    Result := True;
    if (ADatabaseFile = '') or SameText(ADatabaseFile, ':memory:') or
        (not TFile.Exists(ADatabaseFile)) then
        Exit;

    // Share ReadWrite: файл может быть открыт другим процессом
    // (консольные команды, облачная синхронизация)
    try
        Fs := TFileStream.Create(ADatabaseFile, fmOpenRead or fmShareDenyNone);
    except
        // Нечитаемый файл считаем зашифрованным: открытие с ключом
        // упадёт и попадёт в восстановительную ветку вызывающего кода
        Exit(False);
    end;
    try
        if Fs.Size < Length(SQLITE_MAGIC) then
            Exit;
        Fs.ReadBuffer(Buf, Length(SQLITE_MAGIC));
    finally
        Fs.Free;
    end;

    for I := 0 to High(SQLITE_MAGIC) do
        if Buf[I] <> SQLITE_MAGIC[I] then
            Exit(False);
    Result := True;
end;

procedure ApplyEngineLinkage(ALink: TFDPhysSQLiteDriverLink);
begin
    if DbEngineDllAvailable then
    begin
        // Оба свойства линк при загрузке драйвера переносит в его params,
        // где их читает InternalLoad
        ALink.EngineLinkage := slDynamic;
        ALink.VendorLib := DbEngineDllPath;
    end;
end;

procedure ApplyEncryptionParams(const AParams: TStrings; const AKeyBase64: string);
begin
    // Encrypt=no: FireDAC не добавляет префикс FDE-формата, ключ уходит
    // в sqlite3_key как есть; шифр выбирает SQLite3 Multiple Ciphers
    AParams.Add('Encrypt=no');
    AParams.Add('Password=' + AKeyBase64);
end;

procedure ConvertDatabaseEncryption(const ADatabaseFile: string;
    const AOldKeyBase64, ANewKeyBase64: string);
var
    Connection: TFDConnection;
    DriverLink: TFDPhysSQLiteDriverLink;
begin
    // Свой link - страховка для процесса, где этот путь единственный
    // пользователь FireDAC; параметры драйвера в любом случае берутся
    // из первого зарегистрированного link-компонента
    DriverLink := TFDPhysSQLiteDriverLink.Create(nil);
    ApplyEngineLinkage(DriverLink);
    Connection := TFDConnection.Create(nil);
    try
        Connection.Params.Add('DriverID=SQLite');
        Connection.Params.Add('Database=' + ADatabaseFile);
        // WAL слить в основной файл: rekey перекодирует только страницы
        // основной БД
        Connection.Params.Add('JournalMode=DELETE');
        Connection.Params.Add('LockingMode=Normal');
        Connection.Params.Add('BusyTimeout=5000');
        Connection.Params.Add('CharacterSet=utf8');
        if AOldKeyBase64 <> '' then
            ApplyEncryptionParams(Connection.Params, AOldKeyBase64);
        Connection.Connected := True;

        try
            // Пустой новый ключ = снятие шифрования; base64-ключ не
            // содержит символов кавычек, экранирование не требуется
            Connection.ExecSQL('PRAGMA rekey = ''' + ANewKeyBase64 + '''');
        except
            on E: Exception do
                raise Exception.Create('Database rekey failed: ' + E.Message);
        end;
    finally
        Connection.Free;
        DriverLink.Free;
    end;
end;

end.
