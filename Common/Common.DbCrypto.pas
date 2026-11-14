unit Common.DbCrypto;

// Криптопримитивы для шифрования БД: PBKDF2-HMAC-SHA256 и AES-256-GCM.
// Оба примитива идут напрямую через bcrypt.dll (CNG), т.к. в RTL нет
// Winapi.BCrypt, а чистая Delphi-сборка PBKDF2 на 600000 итераций
// подвешивала UI-поток. Единица самодостаточна: не зависит от настроек и UI.

interface

uses
    System.SysUtils
    ;

const
    // Размеры всех двоичных величин схемы шифрования БД
    DB_KEY_BYTES = 32;          // мастер-ключ AES-256
    DB_SALT_BYTES = 16;         // соль PBKDF2
    DB_GCM_NONCE_BYTES = 12;    // nonce GCM (ровно 12 - требование контракта)
    DB_GCM_TAG_BYTES = 16;      // тег аутентичности GCM

    // Количество итераций PBKDF2 по умолчанию. В тестах и при экспорте
    // ключа можно передать меньшее значение явно
    DB_PBKDF2_ITERATIONS = 600000;

    // Формат файла экспорта ключа
    DB_KEY_FILE_VERSION = 1;
    DB_KEY_FILE_KDF = 'pbkdf2-sha256';

    // Минимальная допустимая длина ключа для примитива GCM (AES-128)
    DB_GCM_KEY_MIN = 16;

type
    EDbCryptoError = class(Exception);

    // Сбой на уровне CNG (отрицательный NTSTATUS) - отдельный класс,
    // чтобы вызывающий код мог отличить его от ошибки входных данных
    EDbCryptoStatusError = class(EDbCryptoError);

// Случайные байты из BCryptGenRandom (системный ГСЧ CNG)
function DbRandomBytes(ACount: Integer): TBytes;

// Генераторы величин схемы
function DbGenerateMasterKey: TBytes;
function DbGenerateSalt: TBytes;
function DbGenerateNonce: TBytes;

// PBKDF2-HMAC-SHA256. APassword и ASalt - сырые байты
function DbPbkdf2Sha256(const APassword, ASalt: TBytes; AIterations, ADerivedBytes: Integer): TBytes;

// Обёртка над PBKDF2: пароль - строка (UTF-8), вывод - 32 байта под AES-256
function DbDeriveKey(const APassword: string; const ASalt: TBytes; AIterations: Integer): TBytes;

// AES-GCM. AKey - 16, 24 или 32 байта (AES-128/192/256), ANonce - ровно
// 12 байт. DbAesGcmSeal возвращает шифртекст || тег (16 байт),
// DbAesGcmOpen разбирает такой же пакет; сбой тега = EDbCryptoError
function DbAesGcmSeal(const AKey, ANonce, APlainText: TBytes): TBytes;
function DbAesGcmOpen(const AKey, ANonce, ASealed: TBytes): TBytes;

// Экспорт/импорт мастер-ключа: JSON с обёрткой PBKDF2 вокруг экспортной
// фразы. Поля: version, kdf, iterations, salt, nonce, data (все base64,
// кроме version/kdf/iterations). Неверная фраза = EDbCryptoError при импорте
function DbExportKeyToJson(const AExportPassword: string; const AMasterKey: TBytes; AIterations: Integer = DB_PBKDF2_ITERATIONS): string;
function DbImportKeyFromJson(const AJson: string; const AExportPassword: string): TBytes;

implementation

uses
    System.JSON,
    System.NetEncoding
    ;

const
    BCRYPT_USE_SYSTEM_PREFERRED_RNG = $00000002;
    BCRYPT_ALG_HANDLE_HMAC_FLAG = $00000008;
    CHAINING_MODE_GCM = 'ChainingModeGCM';
    BCRYPT_SHA256_ALGORITHM = 'SHA256';

type
    // THandle = нетипизированный указатель на дескриптор CNG
    BCRYPT_HANDLE = THandle;
    BCRYPT_ALG_HANDLE = THandle;
    BCRYPT_KEY_HANDLE = THandle;

    // TBCRYPT_AUTHENTICATED_CIPHER_MODE_INFO из bcrypt.h Windows SDK.
    // ВАЖНО: cbData имеет тип ULONGLONG, поэтому на x64 запись занимает
    // ровно 88 байт (cbData - по смещению 72); с ULONG вместо него
    // bcrypt возвращает 0xC000000D. Паддинг вставляет компилятор по {$A8}
    PBCryptAuthInfo = ^TBCryptAuthInfo;
    TBCryptAuthInfo = record
        cbSize: UInt32;             // 0
        dwInfoVersion: UInt32;      // 4 (всегда 1)
        pbNonce: PByte;             // 8
        cbNonce: UInt32;            // 16
        pbAuthData: PByte;          // 24
        cbAuthData: UInt32;         // 32
        pbTag: PByte;               // 40
        cbTag: UInt32;              // 48
        pbMacContext: PByte;        // 56
        cbMacContext: UInt32;       // 64
        cbAAD: UInt32;              // 68
        cbData: UInt64;             // 72
        dwFlags: UInt32;            // 80 (SizeOf = 88)
    end;

function BCryptOpenAlgorithmProvider(out AAlg: BCRYPT_ALG_HANDLE; const AAlgId: PWideChar; const AImplementation: PWideChar; AFlags: UInt32): Integer; stdcall; external 'bcrypt.dll';
function BCryptCloseAlgorithmProvider(AAlg: BCRYPT_ALG_HANDLE; AFlags: UInt32): Integer; stdcall; external 'bcrypt.dll';
function BCryptGetProperty(AObject: BCRYPT_HANDLE; const AProperty: PWideChar; AOutput: Pointer; AOutputSize: UInt32; out AResultSize: UInt32; AFlags: UInt32): Integer; stdcall; external 'bcrypt.dll';
function BCryptSetProperty(AObject: BCRYPT_HANDLE; const AProperty: PWideChar; AInput: Pointer; AInputSize: UInt32; AFlags: UInt32): Integer; stdcall; external 'bcrypt.dll';
function BCryptGenerateSymmetricKey(AAlg: BCRYPT_ALG_HANDLE; out AKey: BCRYPT_KEY_HANDLE; AKeyObject: Pointer; AKeyObjectSize: UInt32; ASecret: Pointer; ASecretSize: UInt32; AFlags: UInt32): Integer; stdcall; external 'bcrypt.dll';
function BCryptDestroyKey(AKey: BCRYPT_KEY_HANDLE): Integer; stdcall; external 'bcrypt.dll';
function BCryptEncrypt(AKey: BCRYPT_KEY_HANDLE; AInput: Pointer; AInputSize: UInt32; APaddingInfo: Pointer; AIV: Pointer; AIVSize: UInt32; AOutput: Pointer; AOutputSize: UInt32; out AResultSize: UInt32; AFlags: UInt32): Integer; stdcall; external 'bcrypt.dll';
function BCryptDecrypt(AKey: BCRYPT_KEY_HANDLE; AInput: Pointer; AInputSize: UInt32; APaddingInfo: Pointer; AIV: Pointer; AIVSize: UInt32; AOutput: Pointer; AOutputSize: UInt32; out AResultSize: UInt32; AFlags: UInt32): Integer; stdcall; external 'bcrypt.dll';
function BCryptGenRandom(AAlgorithm: Pointer; ABuffer: PByte; ABufferSize: UInt32; AFlags: UInt32): Integer; stdcall; external 'bcrypt.dll';
function BCryptDeriveKeyPBKDF2(AAlg: BCRYPT_ALG_HANDLE; APassword: PByte; APasswordSize: UInt32; ASalt: PByte; ASaltSize: UInt32; AIterations: UInt64; ADerivedKey: PByte; ADerivedKeySize: UInt32; AFlags: UInt32): Integer; stdcall; external 'bcrypt.dll';

procedure WipeBytes(var ABytes: TBytes);
begin
    if Length(ABytes) > 0 then
        FillChar(ABytes[0], Length(ABytes), 0);
    ABytes := nil;
end;

// NTSTATUS считается успешным только при неотрицательном значении
procedure CheckStatus(AStatus: Integer; const AOperation: string);
begin
    if AStatus < 0 then
        raise EDbCryptoStatusError.CreateFmt('%s failed: NTSTATUS %s', [AOperation, IntToHex(UInt32(AStatus), 8)]);
end;

procedure ValidateKeyNonce(const AKey, ANonce: TBytes);
begin
    // Примитив допускает стандартные длины ключа AES (128/192/256);
    // схема шифрования БД всегда использует 32 (см. DbDeriveKey)
    if not (Length(AKey) in [DB_GCM_KEY_MIN, 24, DB_KEY_BYTES]) then
        raise EDbCryptoError.Create('AES-GCM: key must be 16, 24 or 32 bytes');
    if Length(ANonce) <> DB_GCM_NONCE_BYTES then
        raise EDbCryptoError.Create('AES-GCM: nonce must be exactly 12 bytes');
end;

procedure FillAuthInfo(out AInfo: TBCryptAuthInfo; const ANonce: TBytes; ATag: PByte);
begin
    FillChar(AInfo, SizeOf(AInfo), 0);
    AInfo.cbSize := SizeOf(AInfo);
    AInfo.dwInfoVersion := 1;
    AInfo.pbNonce := @ANonce[0];
    AInfo.cbNonce := UInt32(Length(ANonce));
    AInfo.pbTag := ATag;
    AInfo.cbTag := DB_GCM_TAG_BYTES;
end;

function OpenGcmAlgorithm: BCRYPT_ALG_HANDLE;
var
    Mode: string;
    Status: Integer;
begin
    Status := BCryptOpenAlgorithmProvider(Result, 'AES', nil, 0);
    CheckStatus(Status, 'BCryptOpenAlgorithmProvider');

    Mode := CHAINING_MODE_GCM;
    // Строка свойства передаётся как UTF-16 с нулевым терминатором
    Status := BCryptSetProperty(Result, 'ChainingMode', PChar(Mode), UInt32((Length(Mode) + 1) * SizeOf(WideChar)), 0);
    if Status < 0 then
    begin
        BCryptCloseAlgorithmProvider(Result, 0);
        CheckStatus(Status, 'BCryptSetProperty(ChainingMode)');
    end;
end;

function AlgorithmObjectLength(AAlg: BCRYPT_ALG_HANDLE): UInt32;
var
    CbNeeded: UInt32;
begin
    // Двухшаговый запрос: размер значения, затем само значение (DWORD)
    CheckStatus(BCryptGetProperty(AAlg, 'ObjectLength', nil, 0, CbNeeded, 0), 'BCryptGetProperty(ObjectLength)');
    if CbNeeded <> SizeOf(UInt32) then
        raise EDbCryptoError.Create('BCryptGetProperty(ObjectLength): unexpected property size');
    CheckStatus(BCryptGetProperty(AAlg, 'ObjectLength', @Result, SizeOf(Result), CbNeeded, 0), 'BCryptGetProperty(ObjectLength)');
end;

// Открывает алгоритм и создаёт рабочий ключ. Буфер key object обязателен:
// с nil-объектом ключ создаётся, но операции с ним возвращают
// 0xC000000D/0xC0000008
procedure OpenGcmKey(const AKeyBytes: TBytes; out AAlg: BCRYPT_ALG_HANDLE; out AKeyHandle: BCRYPT_KEY_HANDLE; out AKeyObj: Pointer);
var
    ObjLen: UInt32;
begin
    AAlg := OpenGcmAlgorithm;
    AKeyHandle := 0;
    AKeyObj := nil;
    try
        ObjLen := AlgorithmObjectLength(AAlg);
        GetMem(AKeyObj, ObjLen);
        CheckStatus(BCryptGenerateSymmetricKey(AAlg, AKeyHandle, AKeyObj, ObjLen,
            @AKeyBytes[0], UInt32(Length(AKeyBytes)), 0), 'BCryptGenerateSymmetricKey');
    except
        if AKeyObj <> nil then
        begin
            FreeMem(AKeyObj);
            AKeyObj := nil;
        end;
        BCryptCloseAlgorithmProvider(AAlg, 0);
        raise;
    end;
end;

procedure CloseGcmKey(var AAlg: BCRYPT_ALG_HANDLE; var AKeyHandle: BCRYPT_KEY_HANDLE; var AKeyObj: Pointer);
begin
    if AKeyHandle <> 0 then
        BCryptDestroyKey(AKeyHandle);
    if AKeyObj <> nil then
        FreeMem(AKeyObj);
    if AAlg <> 0 then
        BCryptCloseAlgorithmProvider(AAlg, 0);
    AAlg := 0;
    AKeyHandle := 0;
    AKeyObj := nil;
end;

procedure GcmEncrypt(const AKeyBytes, ANonce, APlainText: TBytes; out AOutput, ATag: TBytes);
var
    Alg: BCRYPT_ALG_HANDLE;
    KeyHandle: BCRYPT_KEY_HANDLE;
    KeyObj: Pointer;
    CbResult: UInt32;
    Info: TBCryptAuthInfo;
begin
    ValidateKeyNonce(AKeyBytes, ANonce);
    OpenGcmKey(AKeyBytes, Alg, KeyHandle, KeyObj);
    try
        SetLength(AOutput, Length(APlainText));
        SetLength(ATag, DB_GCM_TAG_BYTES);
        // Nonce живёт только в padding-info, IV-буфер не используется
        FillAuthInfo(Info, ANonce, @ATag[0]);
        if Length(APlainText) > 0 then
            // Пустой вход: nil-буферы и нулевые размеры допустимы
            CheckStatus(BCryptEncrypt(KeyHandle, @APlainText[0], UInt32(Length(APlainText)), @Info, nil, 0,
                @AOutput[0], UInt32(Length(AOutput)), CbResult, 0), 'BCryptEncrypt')
        else
            CheckStatus(BCryptEncrypt(KeyHandle, nil, 0, @Info, nil, 0, nil, 0, CbResult, 0), 'BCryptEncrypt');
        if CbResult <> UInt32(Length(APlainText)) then
            raise EDbCryptoError.CreateFmt('BCryptEncrypt: unexpected output size %d', [CbResult]);
    finally
        CloseGcmKey(Alg, KeyHandle, KeyObj);
    end;
end;

procedure GcmDecrypt(const AKeyBytes, ANonce, ACipherText, ATag: TBytes; out AOutput: TBytes);
var
    Alg: BCRYPT_ALG_HANDLE;
    KeyHandle: BCRYPT_KEY_HANDLE;
    KeyObj: Pointer;
    CbResult: UInt32;
    Info: TBCryptAuthInfo;
begin
    ValidateKeyNonce(AKeyBytes, ANonce);
    OpenGcmKey(AKeyBytes, Alg, KeyHandle, KeyObj);
    try
        SetLength(AOutput, Length(ACipherText));
        FillAuthInfo(Info, ANonce, @ATag[0]);
        if Length(ACipherText) > 0 then
            CheckStatus(BCryptDecrypt(KeyHandle, @ACipherText[0], UInt32(Length(ACipherText)), @Info, nil, 0,
                @AOutput[0], UInt32(Length(AOutput)), CbResult, 0), 'BCryptDecrypt')
        else
            CheckStatus(BCryptDecrypt(KeyHandle, nil, 0, @Info, nil, 0, nil, 0, CbResult, 0), 'BCryptDecrypt');
        if CbResult <> UInt32(Length(ACipherText)) then
            raise EDbCryptoError.CreateFmt('BCryptDecrypt: unexpected output size %d', [CbResult]);
    finally
        CloseGcmKey(Alg, KeyHandle, KeyObj);
    end;
    // Несовпадение тега = 0xC000A002, отрицательный NTSTATUS - см. CheckStatus
end;

function DbRandomBytes(ACount: Integer): TBytes;
begin
    if ACount < 0 then
        raise EDbCryptoError.Create('DbRandomBytes: negative count');
    SetLength(Result, ACount);
    if ACount = 0 then
        Exit;
    CheckStatus(BCryptGenRandom(nil, @Result[0], UInt32(ACount), BCRYPT_USE_SYSTEM_PREFERRED_RNG), 'BCryptGenRandom');
end;

function DbGenerateMasterKey: TBytes;
begin
    Result := DbRandomBytes(DB_KEY_BYTES);
end;

function DbGenerateSalt: TBytes;
begin
    Result := DbRandomBytes(DB_SALT_BYTES);
end;

function DbGenerateNonce: TBytes;
begin
    Result := DbRandomBytes(DB_GCM_NONCE_BYTES);
end;

function DbPbkdf2Sha256(const APassword, ASalt: TBytes; AIterations, ADerivedBytes: Integer): TBytes;
var
    Alg: BCRYPT_ALG_HANDLE;
    PasswordPtr, SaltPtr: PByte;
begin
    if AIterations < 1 then
        raise EDbCryptoError.Create('PBKDF2: iteration count must be positive');
    if ADerivedBytes < 1 then
        raise EDbCryptoError.Create('PBKDF2: derived length must be positive');

    // CNG PBKDF2-HMAC-SHA256: тот же результат, что и прежняя сборка
    // поверх THashSHA2.GetHMACAsBytes (стандарт RFC 2898, вход - те же
    // сырые байты), но один системный вызов вместо AIterations HMAC-ов
    // с новыми буферами на каждый шаг - 600000 итераций больше не
    // подвешивают UI-поток. Неполный последний блок CNG обрезает сам;
    // при пустом пароле/соли передаём валидный указатель с нулевой
    // длиной - CNG не обязан принимать NULL при cbSize = 0
    Alg := 0;
    CheckStatus(BCryptOpenAlgorithmProvider(Alg, BCRYPT_SHA256_ALGORITHM, nil,
        BCRYPT_ALG_HANDLE_HMAC_FLAG), 'BCryptOpenAlgorithmProvider');
    try
        SetLength(Result, ADerivedBytes);
        if Length(APassword) > 0 then
            PasswordPtr := @APassword[0]
        else
            PasswordPtr := @Result[0];
        if Length(ASalt) > 0 then
            SaltPtr := @ASalt[0]
        else
            SaltPtr := @Result[0];
        CheckStatus(BCryptDeriveKeyPBKDF2(Alg, PasswordPtr, UInt32(Length(APassword)),
            SaltPtr, UInt32(Length(ASalt)), UInt64(AIterations),
            @Result[0], UInt32(ADerivedBytes), 0), 'BCryptDeriveKeyPBKDF2');
    finally
        if Alg <> 0 then
            BCryptCloseAlgorithmProvider(Alg, 0);
    end;
end;

function DbDeriveKey(const APassword: string; const ASalt: TBytes; AIterations: Integer): TBytes;
begin
    Result := DbPbkdf2Sha256(TEncoding.UTF8.GetBytes(APassword), ASalt, AIterations, DB_KEY_BYTES);
end;

function DbAesGcmSeal(const AKey, ANonce, APlainText: TBytes): TBytes;
var
    CipherText, Tag: TBytes;
begin
    GcmEncrypt(AKey, ANonce, APlainText, CipherText, Tag);
    // Пакет: шифртекст || тег
    SetLength(Result, Length(CipherText) + DB_GCM_TAG_BYTES);
    if Length(CipherText) > 0 then
        Move(CipherText[0], Result[0], Length(CipherText));
    Move(Tag[0], Result[Length(CipherText)], DB_GCM_TAG_BYTES);
end;

function DbAesGcmOpen(const AKey, ANonce, ASealed: TBytes): TBytes;
var
    CipherText, Tag: TBytes;
begin
    ValidateKeyNonce(AKey, ANonce);
    if Length(ASealed) < DB_GCM_TAG_BYTES then
        raise EDbCryptoError.Create('AES-GCM: sealed payload shorter than tag');
    CipherText := Copy(ASealed, 0, Length(ASealed) - DB_GCM_TAG_BYTES);
    Tag := Copy(ASealed, Length(ASealed) - DB_GCM_TAG_BYTES, DB_GCM_TAG_BYTES);
    try
        GcmDecrypt(AKey, ANonce, CipherText, Tag, Result);
    except
        // Неверная фраза и битые данные для вызывающего неотличимы - так и задумано
        on E: EDbCryptoStatusError do
            raise EDbCryptoError.Create('AES-GCM: wrong password or corrupted data');
    end;
end;

function DbExportKeyToJson(const AExportPassword: string; const AMasterKey: TBytes; AIterations: Integer): string;
var
    Salt, Nonce, Derived, Sealed: TBytes;
    Root: TJSONObject;
begin
    if Length(AMasterKey) <> DB_KEY_BYTES then
        raise EDbCryptoError.Create('Export: master key must be exactly 32 bytes');
    if AExportPassword.IsEmpty then
        raise EDbCryptoError.Create('Export: password must not be empty');
    if AIterations < 1 then
        raise EDbCryptoError.Create('Export: iteration count must be positive');

    Salt := DbGenerateSalt;
    Nonce := DbGenerateNonce;
    Derived := DbDeriveKey(AExportPassword, Salt, AIterations);
    try
        Sealed := DbAesGcmSeal(Derived, Nonce, AMasterKey);
    finally
        WipeBytes(Derived);
    end;

    Root := TJSONObject.Create;
    try
        Root.AddPair('version', TJSONNumber.Create(DB_KEY_FILE_VERSION));
        Root.AddPair('kdf', DB_KEY_FILE_KDF);
        Root.AddPair('iterations', TJSONNumber.Create(AIterations));
        Root.AddPair('salt', TNetEncoding.Base64.EncodeBytesToString(Salt));
        Root.AddPair('nonce', TNetEncoding.Base64.EncodeBytesToString(Nonce));
        Root.AddPair('data', TNetEncoding.Base64.EncodeBytesToString(Sealed));
        Result := Root.ToJSON;
    finally
        Root.Free;
    end;
end;

function DbImportKeyFromJson(const AJson: string; const AExportPassword: string): TBytes;
var
    Root: TJSONValue;
    Obj: TJSONObject;
    Salt, Nonce, Data, Derived, Plain: TBytes;
    Iterations: Integer;

    function IntField(const AName: string): Integer;
    var
        FieldValue: TJSONValue;
    begin
        FieldValue := Obj.FindValue(AName);
        if FieldValue = nil then
            raise EDbCryptoError.CreateFmt('Key file: missing field "%s"', [AName]);
        Result := StrToIntDef(FieldValue.Value, 0);
    end;

    function StrField(const AName: string): string;
    var
        FieldValue: TJSONValue;
    begin
        FieldValue := Obj.FindValue(AName);
        if FieldValue = nil then
            raise EDbCryptoError.CreateFmt('Key file: missing field "%s"', [AName]);
        Result := FieldValue.Value;
    end;

    function BytesField(const AName: string): TBytes;
    begin
        try
            Result := TNetEncoding.Base64.DecodeStringToBytes(StrField(AName));
        except
            raise EDbCryptoError.CreateFmt('Key file: field "%s" is not valid base64', [AName]);
        end;
    end;

begin
    Result := nil;
    Root := TJSONObject.ParseJSONValue(AJson);
    if not (Root is TJSONObject) then
    begin
        Root.Free;
        raise EDbCryptoError.Create('Key file: invalid JSON');
    end;
    Obj := TJSONObject(Root);
    try
        if IntField('version') <> DB_KEY_FILE_VERSION then
            raise EDbCryptoError.Create('Key file: unsupported version');
        if StrField('kdf') <> DB_KEY_FILE_KDF then
            raise EDbCryptoError.Create('Key file: unsupported KDF');

        Iterations := IntField('iterations');
        if Iterations < 1 then
            raise EDbCryptoError.Create('Key file: invalid iteration count');

        Salt := BytesField('salt');
        if Length(Salt) <> DB_SALT_BYTES then
            raise EDbCryptoError.Create('Key file: salt must be 16 bytes');
        Nonce := BytesField('nonce');
        if Length(Nonce) <> DB_GCM_NONCE_BYTES then
            raise EDbCryptoError.Create('Key file: nonce must be 12 bytes');
        Data := BytesField('data');
        if Length(Data) < DB_GCM_TAG_BYTES + DB_KEY_BYTES then
            raise EDbCryptoError.Create('Key file: payload too short');

        Derived := DbDeriveKey(AExportPassword, Salt, Iterations);
        try
            Plain := DbAesGcmOpen(Derived, Nonce, Data);
        finally
            WipeBytes(Derived);
        end;

        if Length(Plain) <> DB_KEY_BYTES then
        begin
            WipeBytes(Plain);
            raise EDbCryptoError.Create('Key file: unexpected key length');
        end;

        // Копия в Result, буфер расшифровки затирается
        Result := Copy(Plain, 0, Length(Plain));
        WipeBytes(Plain);
    finally
        Root.Free;
    end;
end;

end.
