unit Tests.DbCrypto;

interface

uses
    DUnitX.TestFramework,
    Common.DbCrypto,
    System.SysUtils
    ;

type
    [TestFixture]
    TDbCryptoPbkdf2Tests = class(TObject)
    public
        [Test]
        procedure Pbkdf2_Rfc7914_Vectors;
        [Test]
        procedure Pbkdf2_LongPassword_Vector;
        [Test]
        procedure Pbkdf2_PartialLastBlock_Vector;
        [Test]
        procedure Pbkdf2_ZeroIterations_Raises;
    end;

    [TestFixture]
    TDbCryptoGcmTests = class(TObject)
    public
        [Test]
        procedure Gcm_EmptyPlaintext_KnownTag;
        [Test]
        procedure Gcm_Block16_Aes128_KnownCiphertext;
        [Test]
        procedure Gcm_Aes256_KnownVectors;
        [Test]
        procedure Gcm_CustomVectors_FromWindowsBCrypt;
        [Test]
        procedure Gcm_Roundtrip_PreservesPlaintext;
        [Test]
        procedure Gcm_TamperedCiphertext_Raises;
        [Test]
        procedure Gcm_TamperedTag_Raises;
        [Test]
        procedure Gcm_WrongKeyLength_Raises;
        [Test]
        procedure Gcm_TooShortSealed_Raises;
    end;

    [TestFixture]
    TDbCryptoKeyFileTests = class(TObject)
    public
        [Test]
        procedure ExportImport_Roundtrip;
        [Test]
        procedure Export_WrongPassword_ImportRaises;
        [Test]
        procedure Export_JsonStructure_FieldsPresent;
        [Test]
        procedure Import_CorruptJson_Raises;
        [Test]
        procedure RandomBytes_LengthAndUniqueness;
    end;

implementation

uses
    System.JSON,
    System.NetEncoding
    ;

const
    // PBKDF2-HMAC-SHA256, dkLen=32 (RFC 7914, раздел 11; сверено с hashlib)
    PBKDF2_PASSWORD_SALT_C1 = '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b';
    PBKDF2_PASSWORD_SALT_C2 = 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43';
    PBKDF2_PASSWORD_SALT_C4096 = 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a';
    PBKDF2_PASSWORD_NACL_C2 = '7897885f70bce63d18e043ad11c3a4b71a326b50c5e183d740d8924f5c3ead46';
    PBKDF2_LONGPWORD_S1_C1000 = '0593d2b715a8d4b38301986d8057f5bb96fb12a6f5a0c812f18ef9b60db90398';

    // PBKDF2-HMAC-SHA256, c=3, dkLen=25 (неполный последний блок):
    // сверено между Windows CNG (BCryptDeriveKeyPBKDF2) и независимой
    // HMAC-SHA256-реализацией - значения совпали
    PBKDF2_PASSWORD_SALT_C3_DKLEN25 = 'ad35240ac683febfaf3cd49d845473fbbbaa2437f5f82d5a41';

    // AES-GCM, кастомные векторы получены из Windows BCrypt (bcrypt.dll)
    // и сверены с чистой python-реализацией FIPS 197/800-38D
    GCM_KEY16_NONCE12_EMPTY = '58e2fccefa7e3061367f1d57a4e7455a';
    GCM_KEY16_NONCE12_BLOCK16 = '0388dace60b6a392f328c2b971b2fe78ab6e47d42cec13bdf53a67b21257bddf';
    GCM_KEY32_NONCE12_EMPTY = '530f8afbc74536b9a963b4f1c4cb738b';
    GCM_KEY32_NONCE12_BLOCK16 = 'cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919';
    GCM_CUSTOM_KEY_SEQ32 = '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';
    GCM_CUSTOM_NONCE = '0102030405060708090a0b0c';
    GCM_CUSTOM_SEQ16_SEALED = '05eb58d6e891f68144ab694c1c1ee4271fbb2827b78feab405c4d2b8ff9f2c81';
    GCM_CUSTOM_EMPTY_SEALED = '2de03dae663071831859ef8b9da935f6';

function ToHex(const ABytes: TBytes): string;
const
    DIGITS = '0123456789abcdef';
var
    I: Integer;
begin
    Result := '';
    SetLength(Result, Length(ABytes) * 2);
    for I := 0 to High(ABytes) do
    begin
        Result[I * 2 + 1] := DIGITS[(ABytes[I] shr 4) + 1];
        Result[I * 2 + 2] := DIGITS[(ABytes[I] and $0F) + 1];
    end;
end;

function FromHex(const AHex: string): TBytes;

    function Nibble(C: Char): Byte;
    begin
        case C of
            '0'..'9': Result := Ord(C) - Ord('0');
            'a'..'f': Result := Ord(C) - Ord('a') + 10;
            'A'..'F': Result := Ord(C) - Ord('A') + 10;
        else
            raise Exception.Create('Test hex: invalid character');
        end;
    end;

var
    I: Integer;
begin
    SetLength(Result, Length(AHex) div 2);
    for I := 0 to High(Result) do
        Result[I] := (Nibble(AHex[I * 2 + 1]) shl 4) or Nibble(AHex[I * 2 + 2]);
end;

function Zeros(ACount: Integer): TBytes;
begin
    SetLength(Result, ACount);
    if ACount > 0 then
        FillChar(Result[0], ACount, 0);
end;

function Sequence(ACount: Integer): TBytes;
var
    I: Integer;
begin
    SetLength(Result, ACount);
    for I := 0 to ACount - 1 do
        Result[I] := Byte(I);
end;

function Utf8Bytes(const AValue: string): TBytes;
begin
    Result := TEncoding.UTF8.GetBytes(AValue);
end;

{ TDbCryptoPbkdf2Tests }

procedure TDbCryptoPbkdf2Tests.Pbkdf2_Rfc7914_Vectors;
begin
    Assert.AreEqual(PBKDF2_PASSWORD_SALT_C1,
        ToHex(DbPbkdf2Sha256(Utf8Bytes('password'), Utf8Bytes('salt'), 1, 32)));
    Assert.AreEqual(PBKDF2_PASSWORD_SALT_C2,
        ToHex(DbPbkdf2Sha256(Utf8Bytes('password'), Utf8Bytes('salt'), 2, 32)));
    Assert.AreEqual(PBKDF2_PASSWORD_SALT_C4096,
        ToHex(DbPbkdf2Sha256(Utf8Bytes('password'), Utf8Bytes('salt'), 4096, 32)));
    Assert.AreEqual(PBKDF2_PASSWORD_NACL_C2,
        ToHex(DbPbkdf2Sha256(Utf8Bytes('Password'), Utf8Bytes('NaCl'), 2, 32)));
end;

procedure TDbCryptoPbkdf2Tests.Pbkdf2_LongPassword_Vector;
var
    LongPassword: string;
begin
    // 64-байтный пароль длиннее HMAC-блока SHA-256 (64 байта):
    // ключ обязан сначала прогоняться через сам хеш
    LongPassword := '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    Assert.AreEqual(PBKDF2_LONGPWORD_S1_C1000,
        ToHex(DbPbkdf2Sha256(Utf8Bytes(LongPassword), Utf8Bytes('s1'), 1000, 32)));
end;

procedure TDbCryptoPbkdf2Tests.Pbkdf2_PartialLastBlock_Vector;
begin
    // dkLen не кратен HLEN=32: последний блок используется частично
    Assert.AreEqual(PBKDF2_PASSWORD_SALT_C3_DKLEN25,
        ToHex(DbPbkdf2Sha256(Utf8Bytes('password'), Utf8Bytes('salt'), 3, 25)));
end;

procedure TDbCryptoPbkdf2Tests.Pbkdf2_ZeroIterations_Raises;
begin
    Assert.WillRaise(
        procedure
        begin
            DbPbkdf2Sha256(Utf8Bytes('password'), Utf8Bytes('salt'), 0, 32);
        end, EDbCryptoError);
end;

{ TDbCryptoGcmTests }

procedure TDbCryptoGcmTests.Gcm_EmptyPlaintext_KnownTag;
begin
    // NIST AES-128-GCM: пустой открытый текст, ключ и nonce из нулей
    Assert.AreEqual(GCM_KEY16_NONCE12_EMPTY,
        ToHex(DbAesGcmSeal(Zeros(16), Zeros(12), nil)));
end;

procedure TDbCryptoGcmTests.Gcm_Block16_Aes128_KnownCiphertext;
begin
    Assert.AreEqual(GCM_KEY16_NONCE12_BLOCK16,
        ToHex(DbAesGcmSeal(Zeros(16), Zeros(12), Zeros(16))));
end;

procedure TDbCryptoGcmTests.Gcm_Aes256_KnownVectors;
begin
    Assert.AreEqual(GCM_KEY32_NONCE12_EMPTY,
        ToHex(DbAesGcmSeal(Zeros(32), Zeros(12), nil)));
    Assert.AreEqual(GCM_KEY32_NONCE12_BLOCK16,
        ToHex(DbAesGcmSeal(Zeros(32), Zeros(12), Zeros(16))));
end;

procedure TDbCryptoGcmTests.Gcm_CustomVectors_FromWindowsBCrypt;
var
    Key, Nonce: TBytes;
begin
    Key := FromHex(GCM_CUSTOM_KEY_SEQ32);
    Nonce := FromHex(GCM_CUSTOM_NONCE);
    Assert.AreEqual(GCM_CUSTOM_SEQ16_SEALED, ToHex(DbAesGcmSeal(Key, Nonce, Sequence(16))));
    Assert.AreEqual(GCM_CUSTOM_EMPTY_SEALED, ToHex(DbAesGcmSeal(Key, Nonce, nil)));
end;

procedure TDbCryptoGcmTests.Gcm_Roundtrip_PreservesPlaintext;
var
    Key, Nonce, Plain: TBytes;
begin
    Key := FromHex(GCM_CUSTOM_KEY_SEQ32);
    Nonce := FromHex(GCM_CUSTOM_NONCE);

    Plain := Sequence(16);
    Assert.AreEqual(ToHex(Plain), ToHex(DbAesGcmOpen(Key, Nonce, DbAesGcmSeal(Key, Nonce, Plain))));

    // Пустой открытый текст
    Plain := nil;
    Assert.AreEqual(0, Integer(Length(DbAesGcmOpen(Key, Nonce, DbAesGcmSeal(Key, Nonce, Plain)))));
end;

procedure TDbCryptoGcmTests.Gcm_TamperedCiphertext_Raises;
var
    Key, Nonce, Sealed: TBytes;
begin
    Key := FromHex(GCM_CUSTOM_KEY_SEQ32);
    Nonce := FromHex(GCM_CUSTOM_NONCE);
    Sealed := DbAesGcmSeal(Key, Nonce, Sequence(16));
    Sealed[0] := Sealed[0] xor 1;

    Assert.WillRaise(
        procedure
        begin
            DbAesGcmOpen(Key, Nonce, Sealed);
        end, EDbCryptoError);
end;

procedure TDbCryptoGcmTests.Gcm_TamperedTag_Raises;
var
    Key, Nonce, Sealed: TBytes;
begin
    Key := FromHex(GCM_CUSTOM_KEY_SEQ32);
    Nonce := FromHex(GCM_CUSTOM_NONCE);
    Sealed := DbAesGcmSeal(Key, Nonce, Sequence(16));
    Sealed[High(Sealed)] := Sealed[High(Sealed)] xor 1;

    Assert.WillRaise(
        procedure
        begin
            DbAesGcmOpen(Key, Nonce, Sealed);
        end, EDbCryptoError);
end;

procedure TDbCryptoGcmTests.Gcm_WrongKeyLength_Raises;
begin
    // 15 байт - ни одна из допустимых длин AES (16/24/32)
    Assert.WillRaise(
        procedure
        begin
            DbAesGcmSeal(Zeros(15), Zeros(12), Sequence(4));
        end, EDbCryptoError);
    Assert.WillRaise(
        procedure
        begin
            DbAesGcmOpen(Zeros(32), Zeros(8), Sequence(32));
        end, EDbCryptoError);
end;

procedure TDbCryptoGcmTests.Gcm_TooShortSealed_Raises;
var
    Key, Nonce: TBytes;
begin
    Key := FromHex(GCM_CUSTOM_KEY_SEQ32);
    Nonce := FromHex(GCM_CUSTOM_NONCE);
    Assert.WillRaise(
        procedure
        begin
            DbAesGcmOpen(Key, Nonce, Sequence(DB_GCM_TAG_BYTES - 1));
        end, EDbCryptoError);
end;

{ TDbCryptoKeyFileTests }

procedure TDbCryptoKeyFileTests.ExportImport_Roundtrip;
var
    MasterKey: TBytes;
    Json: string;
begin
    MasterKey := Sequence(32);
    Json := DbExportKeyToJson('export pass-phrase', MasterKey, 1000);
    Assert.AreEqual(ToHex(MasterKey),
        ToHex(DbImportKeyFromJson(Json, 'export pass-phrase')));
end;

procedure TDbCryptoKeyFileTests.Export_WrongPassword_ImportRaises;
var
    Json: string;
begin
    Json := DbExportKeyToJson('export pass-phrase', Sequence(32), 1000);
    Assert.WillRaise(
        procedure
        begin
            DbImportKeyFromJson(Json, 'wrong pass-phrase');
        end, EDbCryptoError);
end;

procedure TDbCryptoKeyFileTests.Export_JsonStructure_FieldsPresent;
var
    Root: TJSONObject;
    Json: string;
begin
    Json := DbExportKeyToJson('export pass-phrase', Sequence(32), 1000);
    Root := TJSONObject.ParseJSONValue(Json) as TJSONObject;
    try
        Assert.AreEqual(1, Root.GetValue<Integer>('version'));
        Assert.AreEqual('pbkdf2-sha256', Root.GetValue<string>('kdf'));
        Assert.AreEqual(1000, Root.GetValue<Integer>('iterations'));
        Assert.AreEqual(DB_SALT_BYTES,
            Integer(Length(TNetEncoding.Base64.DecodeStringToBytes(Root.GetValue<string>('salt')))));
        Assert.AreEqual(DB_GCM_NONCE_BYTES,
            Integer(Length(TNetEncoding.Base64.DecodeStringToBytes(Root.GetValue<string>('nonce')))));
        // 32 байта ключа + 16 байт тега
        Assert.AreEqual(DB_KEY_BYTES + DB_GCM_TAG_BYTES,
            Integer(Length(TNetEncoding.Base64.DecodeStringToBytes(Root.GetValue<string>('data')))));
    finally
        Root.Free;
    end;
end;

procedure TDbCryptoKeyFileTests.Import_CorruptJson_Raises;
begin
    Assert.WillRaise(
        procedure
        begin
            DbImportKeyFromJson('not json', 'export pass-phrase');
        end, EDbCryptoError);
end;

procedure TDbCryptoKeyFileTests.RandomBytes_LengthAndUniqueness;
var
    First, Second: TBytes;
begin
    First := DbRandomBytes(32);
    Second := DbRandomBytes(32);
    Assert.AreEqual(32, Integer(Length(First)));
    Assert.AreEqual(32, Integer(Length(Second)));
    Assert.AreNotEqual(ToHex(First), ToHex(Second));

    Assert.AreEqual(0, Integer(Length(DbRandomBytes(0))));
end;

end.
