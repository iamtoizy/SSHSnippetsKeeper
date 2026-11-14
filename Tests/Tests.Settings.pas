unit Tests.Settings;

interface

uses
    DUnitX.TestFramework,
    Core.Interfaces.Settings,
    Common.Settings,
    System.SysUtils
    ;

type
    [TestFixture]
    TSettingsDpapiTests = class(TObject)
    public
        [Test]
        procedure ProtectSecret_RoundtripsThroughUnprotect;
        [Test]
        procedure ProtectSecret_IdempotentOnProtected;
        [Test]
        procedure ProtectSecret_EmptyStaysEmpty;
        [Test]
        procedure Unprotect_PassthroughForPlainText;
        [Test]
        procedure Unprotect_EmptyInput_EmptyResult;
        [Test]
        procedure IsProtectedSecret_Boundaries;
        [Test]
        procedure WipeSecretBytes_NilsArray;
    end;

    [TestFixture]
    TSettingsManagerTests = class(TObject)
    private
        function SettingsPath: string;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test]
        procedure SaveLoad_Roundtrip_EncryptsKeys_NoPlaintext;
        [Test]
        procedure Save_PlaceholderStaysPlain;
        [Test]
        procedure Load_MissingFile_CreatesDefaults;
        [Test]
        procedure Load_NormalizesLegacyDpapi2Prefix;
        [Test]
        procedure Load_CorruptFile_FallsBackToDefaults;
    end;

    [TestFixture]
    TSettingsDbSecurityTests = class(TObject)
    private
        function SettingsPath: string;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test]
        procedure SaveLoad_Roundtrip_PreservesDbSecurity;
        [Test]
        procedure Save_DbKeyStoredAsDpapiBlob_NoPlaintext;
        [Test]
        procedure Load_MissingDbNode_RestoresDefaults;
        [Test]
        procedure Load_InvalidDbModes_FallBackToDefaults;
        [Test]
        procedure Load_PassphraseNotRemembered_StaleKeyCleared;
        [Test]
        procedure StoredKeyMaterial_DpapiBlob_ReturnsBase64Key;
        [Test]
        procedure StoredKeyMaterial_PlainBase64_ReturnsSameKey;
        [Test]
        procedure StoredKeyMaterial_GarbageOrWrongLength_ReturnsEmpty;
        [Test]
        procedure ClearUnrememberedDbKey_OnlyPassphraseWithoutRemember;
        [Test]
        procedure ClearUnrememberedDbKey_SweepsUnrememberedProfiles;
        [Test]
        procedure PinDbKey_Passphrase_ForcedAlwaysRemembers;
        [Test]
        procedure PinDbKey_Passphrase_NoForce_RespectsRememberFlag;
        [Test]
        procedure PinDbKey_Dpapi_RebindsKeyToLocalMachine;
        [Test]
        procedure NormalizeDbProfilePath_NormalizesCaseAndSpecial;
        [Test]
        procedure FindDbProfile_MatchesCaseInsensitively;
        [Test]
        procedure SaveDbProfile_UpsertsByPath;
        [Test]
        procedure DeleteDbProfile_RemovesOnlyTarget;
        [Test]
        procedure GetDbProfile_MissingReturnsDpapiDefault;
        [Test]
        procedure PinDbKeyTo_CreatesProfile_AndRespectsRememberFlag;
        [Test]
        procedure PinDbKeyTo_Dpapi_AlwaysStores;
        [Test]
        procedure SaveLoad_Roundtrip_PreservesProfiles_EncryptedKeys;
        [Test]
        procedure StoredKeyMaterial_Profile_ReturnsBase64Key;
    end;

implementation

uses
    Common.DbCrypto,
    Data.Database.Security,
    JSONSerializer,
    System.Classes,
    System.IOUtils,
    System.NetEncoding
    ;

const
    SECRET_TEST_KEY = 'sk-live-1234567890abcdef';
    PLACEHOLDER_API_KEY = 'Paste-your-API-key-here';

// Удаление с учётом TOCTOU: между Exists и Delete файл может исчезнуть
// (внешний синк/антивирус), и DeleteFile вернёт FILE_NOT_FOUND
procedure SafeDeleteIfPresent(const APath: string);
begin
    if not TFile.Exists(APath) then
        Exit;
    try
        TFile.Delete(APath);
    except
        // Цель очистки достигнута, если файла больше нет; иначе ошибка настоящая
        on E: EInOutError do
            if TFile.Exists(APath) then
                raise;
    end;
end;

{ TSettingsDpapiTests }

procedure TSettingsDpapiTests.ProtectSecret_RoundtripsThroughUnprotect;
var
    ProtectedValue: string;
begin
    ProtectedValue := ProtectSecret(SECRET_TEST_KEY);

    Assert.IsTrue(ProtectedValue.StartsWith('dpapi:'));
    Assert.AreNotEqual(SECRET_TEST_KEY, ProtectedValue);
    Assert.AreEqual(SECRET_TEST_KEY,
        TEncoding.UTF8.GetString(UnprotectSecretToBytes(ProtectedValue)));
end;

procedure TSettingsDpapiTests.ProtectSecret_IdempotentOnProtected;
var
    First, Second: string;
begin
    First := ProtectSecret(SECRET_TEST_KEY);
    Second := ProtectSecret(First);

    Assert.AreEqual(First, Second);
end;

procedure TSettingsDpapiTests.ProtectSecret_EmptyStaysEmpty;
begin
    Assert.AreEqual('', ProtectSecret(''));
end;

procedure TSettingsDpapiTests.Unprotect_PassthroughForPlainText;
begin
    Assert.AreEqual('hello world',
        TEncoding.UTF8.GetString(UnprotectSecretToBytes('hello world')));
end;

procedure TSettingsDpapiTests.Unprotect_EmptyInput_EmptyResult;
begin
    Assert.AreEqual(0, Integer(Length(UnprotectSecretToBytes(''))));
end;

procedure TSettingsDpapiTests.IsProtectedSecret_Boundaries;
begin
    Assert.IsFalse(IsProtectedSecret(''));
    Assert.IsFalse(IsProtectedSecret('plain-key'));
    Assert.IsTrue(IsProtectedSecret('dpapi:'));
    Assert.IsTrue(IsProtectedSecret('DPAPI:AbCd'));
end;

procedure TSettingsDpapiTests.WipeSecretBytes_NilsArray;
var
    Raw: TBytes;
begin
    Raw := TBytes.Create(1, 2, 3);
    WipeSecretBytes(Raw);

    Assert.AreEqual(0, Integer(Length(Raw)));
end;

{ TSettingsManagerTests }

function TSettingsManagerTests.SettingsPath: string;
begin
    Result := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'settings.json');
end;

procedure TSettingsManagerTests.Setup;
begin
    SafeDeleteIfPresent(SettingsPath);
    SafeDeleteIfPresent(SettingsPath + '.tmp');
end;

procedure TSettingsManagerTests.TearDown;
begin
    SafeDeleteIfPresent(SettingsPath);
    SafeDeleteIfPresent(SettingsPath + '.tmp');
end;

procedure TSettingsManagerTests.SaveLoad_Roundtrip_EncryptsKeys_NoPlaintext;
var
    M1, M2: ISettingsManager;
    S: TAppSettings;
    Raw, LoadedKey: string;
begin
    M1 := TSettingsManager.Create;
    S := M1.Data;
    S.CurrentLanguage := 'en';
    S.AISettings.Items[1].Items.Items[0].APIKey := SECRET_TEST_KEY;
    M1.Data := S;
    M1.Save;
    M1 := nil;

    Assert.IsTrue(TFile.Exists(SettingsPath));
    Raw := TFile.ReadAllText(SettingsPath, TEncoding.UTF8);
    Assert.IsTrue(Raw.Contains('dpapi:'));
    Assert.IsFalse(Raw.Contains(SECRET_TEST_KEY));
    Assert.IsTrue(Raw.Contains(PLACEHOLDER_API_KEY));

    M2 := TSettingsManager.Create;
    M2.Load;
    S := M2.Data;
    Assert.AreEqual('en', S.CurrentLanguage);
    LoadedKey := S.AISettings.Items[1].Items.Items[0].APIKey;
    Assert.IsTrue(LoadedKey.StartsWith('dpapi:'));
    Assert.AreEqual(SECRET_TEST_KEY,
        TEncoding.UTF8.GetString(UnprotectSecretToBytes(LoadedKey)));
    M2 := nil;
end;

procedure TSettingsManagerTests.Save_PlaceholderStaysPlain;
var
    M: ISettingsManager;
    Raw: string;
begin
    M := TSettingsManager.Create;
    M.Save;
    M := nil;

    Raw := TFile.ReadAllText(SettingsPath, TEncoding.UTF8);
    Assert.IsTrue(Raw.Contains(PLACEHOLDER_API_KEY));
    Assert.IsFalse(Raw.Contains('dpapi:'));
end;

procedure TSettingsManagerTests.Load_MissingFile_CreatesDefaults;
var
    M: ISettingsManager;
    S: TAppSettings;
begin
    M := TSettingsManager.Create;
    M.Load;
    M := nil;

    Assert.IsTrue(TFile.Exists(SettingsPath));

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;
    Assert.AreEqual('ru', S.CurrentLanguage);
    Assert.AreEqual(10, S.WindowHelper.KeyPressInterval);
    Assert.AreEqual(100, S.WindowHelper.ActivationDelay);
    Assert.AreEqual(50, S.WindowHelper.SetFocusDelay);
    M := nil;
end;

procedure TSettingsManagerTests.Load_NormalizesLegacyDpapi2Prefix;
var
    M: ISettingsManager;
    S: TAppSettings;
    Json: string;
begin
    M := TSettingsManager.Create;
    S := M.Data;
    S.AISettings.Items[0].Items.Items[0].APIKey := 'dpapi2:QUJDRA==';
    Json := DSON.toJson<TAppSettings>(S);
    M := nil;
    TFile.WriteAllText(SettingsPath, Json, TEncoding.UTF8);

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;
    Assert.AreEqual('dpapi:QUJDRA==', S.AISettings.Items[0].Items.Items[0].APIKey);
    M := nil;
end;

procedure TSettingsManagerTests.Load_CorruptFile_FallsBackToDefaults;
var
    M: ISettingsManager;
    S: TAppSettings;
begin
    TFile.WriteAllText(SettingsPath, 'not json', TEncoding.UTF8);

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;
    Assert.AreEqual('ru', S.CurrentLanguage);
    Assert.AreEqual(10, S.WindowHelper.KeyPressInterval);
    M := nil;
end;

{ TSettingsDbSecurityTests }

function TSettingsDbSecurityTests.SettingsPath: string;
begin
    Result := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'settings.json');
end;

procedure TSettingsDbSecurityTests.Setup;
begin
    SafeDeleteIfPresent(SettingsPath);
    SafeDeleteIfPresent(SettingsPath + '.tmp');
end;

procedure TSettingsDbSecurityTests.TearDown;
begin
    SafeDeleteIfPresent(SettingsPath);
    SafeDeleteIfPresent(SettingsPath + '.tmp');
end;

procedure TSettingsDbSecurityTests.SaveLoad_Roundtrip_PreservesDbSecurity;
var
    M: ISettingsManager;
    S: TAppSettings;
    LoadedKey: string;
begin
    M := TSettingsManager.Create;
    S := M.Data;
    S.Db.Encryption := DB_ENCRYPTION_AES256;
    S.Db.KeyMode := DB_KEYMODE_PASSPHRASE;
    S.Db.Key := 'c2VjcmV0a2V5YmFzZTY0';
    S.Db.Salt := 'c2FsdHNhbHRzYWx0c2FsdA==';
    S.Db.RememberKey := True;
    S.Db.FirstRunPromptDone := True;
    M.Data := S;
    M.Save;
    M := nil;

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;
    Assert.AreEqual(DB_ENCRYPTION_AES256, S.Db.Encryption);
    Assert.AreEqual(DB_KEYMODE_PASSPHRASE, S.Db.KeyMode);
    LoadedKey := S.Db.Key;
    Assert.AreEqual('c2VjcmV0a2V5YmFzZTY0',
        TEncoding.UTF8.GetString(UnprotectSecretToBytes(LoadedKey)));
    Assert.AreEqual('c2FsdHNhbHRzYWx0c2FsdA==', S.Db.Salt);
    Assert.IsTrue(S.Db.RememberKey);
    Assert.IsTrue(S.Db.FirstRunPromptDone);
    M := nil;
end;

procedure TSettingsDbSecurityTests.Save_DbKeyStoredAsDpapiBlob_NoPlaintext;
var
    M: ISettingsManager;
    S: TAppSettings;
    Raw: string;
begin
    M := TSettingsManager.Create;
    S := M.Data;
    S.Db.Encryption := DB_ENCRYPTION_AES256;
    S.Db.Key := 'c2VjcmV0a2V5YmFzZTY0';
    M.Data := S;
    M.Save;
    M := nil;

    Raw := TFile.ReadAllText(SettingsPath, TEncoding.UTF8);
    Assert.IsTrue(Raw.Contains('dpapi:'));
    Assert.IsFalse(Raw.Contains('c2VjcmV0a2V5YmFzZTY0'));
end;

procedure TSettingsDbSecurityTests.Load_MissingDbNode_RestoresDefaults;
var
    M: ISettingsManager;
    S: TAppSettings;
begin
    // Файл от версии без узла Db
    TFile.WriteAllText(SettingsPath, '{"CurrentLanguage":"en"}', TEncoding.UTF8);

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;
    Assert.AreEqual('en', S.CurrentLanguage);
    Assert.AreEqual(DB_ENCRYPTION_NONE, S.Db.Encryption);
    Assert.AreEqual(DB_KEYMODE_DPAPI, S.Db.KeyMode);
    Assert.AreEqual('', S.Db.Key);
    Assert.AreEqual('', S.Db.Salt);
    Assert.IsFalse(S.Db.RememberKey);
    Assert.IsFalse(S.Db.FirstRunPromptDone);
    Assert.IsTrue(S.Db.DbDefined);
    M := nil;
end;

procedure TSettingsDbSecurityTests.Load_InvalidDbModes_FallBackToDefaults;
var
    M: ISettingsManager;
    S: TAppSettings;
begin
    TFile.WriteAllText(SettingsPath,
        '{"Db":{"Encryption":"rot13","KeyMode":"magic","Key":"zzz"}}', TEncoding.UTF8);

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;
    Assert.AreEqual(DB_ENCRYPTION_NONE, S.Db.Encryption);
    Assert.AreEqual(DB_KEYMODE_DPAPI, S.Db.KeyMode);
    M := nil;
end;

procedure TSettingsDbSecurityTests.Load_PassphraseNotRemembered_StaleKeyCleared;
var
    M: ISettingsManager;
    S: TAppSettings;
begin
    // Ключ остался на диске от сессии с «запомнить», RememberKey снят -
    // при загрузке он затирается: фраза запрашивается при старте заново
    TFile.WriteAllText(SettingsPath,
        '{"Db":{"Encryption":"aes256","KeyMode":"passphrase",' +
        '"Key":"zzz","RememberKey":false}}', TEncoding.UTF8);

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;
    Assert.AreEqual('', S.Db.Key);
    Assert.IsFalse(S.Db.RememberKey);
    M := nil;
end;

procedure TSettingsDbSecurityTests.StoredKeyMaterial_DpapiBlob_ReturnsBase64Key;
var
    Db: TDbSecuritySettings;
    I: Integer;
    Key: string;
    Raw: TBytes;
begin
    // Регрессия NOTADB при старте: ключ на диске - DPAPI-блоб над
    // base64-строкой. Материал ключа обязан декодировать строку до
    // сырых 32 байт и вернуть ту же строку: если вернётся '', открытие
    // зашифрованной БД пойдёт без Password и упадёт с file is not a
    // database (PASSPHRASE + RememberKey + Key)
    SetLength(Raw, DB_KEY_BYTES);
    for I := 0 to High(Raw) do
        Raw[I] := Byte($A0 + I);
    Key := TNetEncoding.Base64.EncodeBytesToString(Raw);

    Db := Default(TDbSecuritySettings);
    Db.Key := ProtectSecret(Key);
    Assert.AreEqual(Key, DbStoredKeyMaterial(Db));
end;

procedure TSettingsDbSecurityTests.StoredKeyMaterial_PlainBase64_ReturnsSameKey;
var
    Db: TDbSecuritySettings;
    I: Integer;
    Key: string;
    Raw: TBytes;
begin
    // В памяти ключ лежит открытой base64-строкой (например, сразу после
    // включения шифрования до Save) - тот же контракт, без DPAPI-обёртки
    SetLength(Raw, DB_KEY_BYTES);
    for I := 0 to High(Raw) do
        Raw[I] := Byte($11 * I);
    Key := TNetEncoding.Base64.EncodeBytesToString(Raw);

    Db := Default(TDbSecuritySettings);
    Db.Key := Key;
    Assert.AreEqual(Key, DbStoredKeyMaterial(Db));
end;

procedure TSettingsDbSecurityTests.StoredKeyMaterial_GarbageOrWrongLength_ReturnsEmpty;
var
    Db: TDbSecuritySettings;
begin
    Db := Default(TDbSecuritySettings);

    // Пустой ключ
    Db.Key := '';
    Assert.AreEqual('', DbStoredKeyMaterial(Db));

    // base64 не от 32 байт (битая/чужая запись) - material пуст
    Db.Key := TNetEncoding.Base64.EncodeBytesToString(TEncoding.UTF8.GetBytes('short-key'));
    Assert.AreEqual('', DbStoredKeyMaterial(Db));

    // DPAPI-блоб над не-base64-строкой
    Db.Key := ProtectSecret('not a base64 key at all!');
    Assert.AreEqual('', DbStoredKeyMaterial(Db));

    // Битый блоб под валидным префиксом
    Db.Key := 'dpapi:' + TNetEncoding.Base64.EncodeBytesToString(
        TEncoding.UTF8.GetBytes('not a dpapi blob'));
    Assert.AreEqual('', DbStoredKeyMaterial(Db));
end;

procedure TSettingsDbSecurityTests.ClearUnrememberedDbKey_OnlyPassphraseWithoutRemember;
var
    S: TAppSettings;
begin
    // Инвариант passphrase без «запомнить»: ключ не хранится нигде,
    // включая копию настроек в памяти
    S := Default(TAppSettings);
    S.Db.Encryption := DB_ENCRYPTION_AES256;
    S.Db.KeyMode := DB_KEYMODE_PASSPHRASE;
    S.Db.Key := 'c2VjcmV0a2V5YmFzZTY0';
    S.Db.RememberKey := False;
    ClearUnrememberedDbKey(S);
    Assert.AreEqual('', S.Db.Key);

    // С «запомнить» ключ сохраняется (далее шифруется EncryptDbKey)
    S.Db.Key := 'c2VjcmV0a2V5YmFzZTY0';
    S.Db.RememberKey := True;
    ClearUnrememberedDbKey(S);
    Assert.AreEqual('c2VjcmV0a2V5YmFzZTY0', S.Db.Key);

    // DPAPI-режим инварианту не подчиняется
    S.Db.KeyMode := DB_KEYMODE_DPAPI;
    S.Db.RememberKey := False;
    ClearUnrememberedDbKey(S);
    Assert.AreEqual('c2VjcmV0a2V5YmFzZTY0', S.Db.Key);
end;

procedure TSettingsDbSecurityTests.PinDbKey_Passphrase_ForcedAlwaysRemembers;
var
    S: TAppSettings;
begin
    // Явное «запомнить сейчас»: ключ закрепляется даже при выключенной
    // галке запоминания
    S := Default(TAppSettings);
    S.Db.KeyMode := DB_KEYMODE_PASSPHRASE;
    S.Db.RememberKey := False;
    S.Db.Key := '';
    PinDbKey(S, 'c2VjcmV0a2V5YmFzZTY0', True);
    Assert.AreEqual(True, S.Db.DbDefined);
    Assert.AreEqual(DB_ENCRYPTION_AES256, S.Db.Encryption);
    Assert.AreEqual(True, S.Db.RememberKey);
    Assert.AreEqual('c2VjcmV0a2V5YmFzZTY0', S.Db.Key);
end;

procedure TSettingsDbSecurityTests.PinDbKey_Passphrase_NoForce_RespectsRememberFlag;
var
    S: TAppSettings;
begin
    // Обычное открытие без галки: ключ в настройках не появляется
    S := Default(TAppSettings);
    S.Db.KeyMode := DB_KEYMODE_PASSPHRASE;
    S.Db.RememberKey := False;
    PinDbKey(S, 'c2VjcmV0a2V5YmFzZTY0', False);
    Assert.AreEqual(True, S.Db.DbDefined);
    Assert.AreEqual(DB_ENCRYPTION_AES256, S.Db.Encryption);
    Assert.AreEqual(False, S.Db.RememberKey);
    Assert.AreEqual('', S.Db.Key);

    // С ранее включённой галкой ключ сохраняется
    S.Db.RememberKey := True;
    PinDbKey(S, 'c2VjcmV0a2V5YmFzZTY0', False);
    Assert.AreEqual(True, S.Db.RememberKey);
    Assert.AreEqual('c2VjcmV0a2V5YmFzZTY0', S.Db.Key);
end;

procedure TSettingsDbSecurityTests.PinDbKey_Dpapi_RebindsKeyToLocalMachine;
var
    S: TAppSettings;
begin
    // Диалоговый ключ при DPAPI-режиме: настройки целиком переводятся
    // на новый машинно-привязанный ключ
    S := Default(TAppSettings);
    S.Db.KeyMode := DB_KEYMODE_DPAPI;
    S.Db.Salt := 'oldsaltb64';
    S.Db.RememberKey := False;
    S.Db.Key := 'c3RhbGVrZXliYXNlNjQ';
    PinDbKey(S, 'c2VjcmV0a2V5YmFzZTY0', False);
    Assert.AreEqual(DB_KEYMODE_DPAPI, S.Db.KeyMode);
    Assert.AreEqual('', S.Db.Salt);
    Assert.AreEqual(True, S.Db.RememberKey);
    Assert.AreEqual('c2VjcmV0a2V5YmFzZTY0', S.Db.Key);
    Assert.AreEqual(True, S.Db.DbDefined);
    Assert.AreEqual(DB_ENCRYPTION_AES256, S.Db.Encryption);
end;

procedure TSettingsDbSecurityTests.ClearUnrememberedDbKey_SweepsUnrememberedProfiles;
var
    S: TAppSettings;
    P: TDbSecurityProfile;
begin
    // Инвариант passphrase без «запомнить» действует и на профили баз:
    // ключ затирается только у passphrase-профиля без галки запоминания
    S := Default(TAppSettings);

    P := Default(TDbSecurityProfile);
    P.Path := NormalizeDbProfilePath('C:\db\a.sqlite');
    P.KeyMode := DB_KEYMODE_PASSPHRASE;
    P.RememberKey := False;
    P.Key := 'c2VjcmV0a2V5YmFzZTY0';
    SaveDbProfile(S, P);

    P := Default(TDbSecurityProfile);
    P.Path := NormalizeDbProfilePath('C:\db\b.sqlite');
    P.KeyMode := DB_KEYMODE_PASSPHRASE;
    P.RememberKey := True;
    P.Key := 'c2VjcmV0a2V5YmFzZTY0';
    SaveDbProfile(S, P);

    P := Default(TDbSecurityProfile);
    P.Path := NormalizeDbProfilePath('C:\db\c.sqlite');
    P.KeyMode := DB_KEYMODE_DPAPI;
    P.RememberKey := False;
    P.Key := 'c2VjcmV0a2V5YmFzZTY0';
    SaveDbProfile(S, P);

    ClearUnrememberedDbKey(S);
    Assert.AreEqual('', GetDbProfile(S, 'C:\db\a.sqlite').Key);
    Assert.AreEqual('c2VjcmV0a2V5YmFzZTY0', GetDbProfile(S, 'C:\db\b.sqlite').Key);
    Assert.AreEqual('c2VjcmV0a2V5YmFzZTY0', GetDbProfile(S, 'C:\db\c.sqlite').Key);
end;

procedure TSettingsDbSecurityTests.NormalizeDbProfilePath_NormalizesCaseAndSpecial;
begin
    Assert.AreEqual('', NormalizeDbProfilePath(''));
    Assert.AreEqual('', NormalizeDbProfilePath(':memory:'));
    Assert.AreEqual('', NormalizeDbProfilePath(':MEMORY:'));
    Assert.AreEqual(NormalizeDbProfilePath('C:\DB\A.sqlite'),
        NormalizeDbProfilePath('c:\db\a.sqlite'));
    Assert.IsTrue(NormalizeDbProfilePath('a.sqlite')
        .EndsWith('a.sqlite'));
end;

procedure TSettingsDbSecurityTests.FindDbProfile_MatchesCaseInsensitively;
var
    S: TAppSettings;
    P: TDbSecurityProfile;
begin
    S := Default(TAppSettings);
    P := Default(TDbSecurityProfile);
    P.Path := NormalizeDbProfilePath('C:\db\a.sqlite');
    P.KeyMode := DB_KEYMODE_DPAPI;
    SaveDbProfile(S, P);

    Assert.AreEqual(0, FindDbProfileIndex(S, 'c:\DB\A.SQLITE'));
    Assert.AreEqual(-1, FindDbProfileIndex(S, 'C:\db\other.sqlite'));
    Assert.AreEqual(-1, FindDbProfileIndex(S, ':memory:'));
end;

procedure TSettingsDbSecurityTests.SaveDbProfile_UpsertsByPath;
var
    S: TAppSettings;
    P: TDbSecurityProfile;
begin
    S := Default(TAppSettings);
    P := Default(TDbSecurityProfile);
    P.Path := NormalizeDbProfilePath('C:\db\a.sqlite');
    P.KeyMode := DB_KEYMODE_PASSPHRASE;
    P.Salt := 'c2FsdHNhbHRzYWx0c2FsdA==';
    P.RememberKey := True;
    P.Key := 'c2VjcmV0a2V5YmFzZTY0';
    SaveDbProfile(S, P);
    SaveDbProfile(S, P);

    // Второе сохранение по тому же пути обновляет запись, а не дублирует
    Assert.AreEqual(1, S.DbProfiles.Count);
    Assert.AreEqual('c2VjcmV0a2V5YmFzZTY0', GetDbProfile(S, 'C:\db\a.sqlite').Key);
end;

procedure TSettingsDbSecurityTests.DeleteDbProfile_RemovesOnlyTarget;
var
    S: TAppSettings;
    P: TDbSecurityProfile;
begin
    S := Default(TAppSettings);
    P := Default(TDbSecurityProfile);
    P.Path := NormalizeDbProfilePath('C:\db\a.sqlite');
    SaveDbProfile(S, P);
    P := Default(TDbSecurityProfile);
    P.Path := NormalizeDbProfilePath('C:\db\b.sqlite');
    SaveDbProfile(S, P);

    DeleteDbProfile(S, 'C:\DB\A.SQLITE');
    Assert.AreEqual(1, S.DbProfiles.Count);
    Assert.AreEqual(-1, FindDbProfileIndex(S, 'C:\db\a.sqlite'));
    Assert.AreEqual(0, FindDbProfileIndex(S, 'C:\db\b.sqlite'));
end;

procedure TSettingsDbSecurityTests.GetDbProfile_MissingReturnsDpapiDefault;
var
    S: TAppSettings;
    P: TDbSecurityProfile;
begin
    S := Default(TAppSettings);
    P := GetDbProfile(S, 'C:\db\nope.sqlite');
    Assert.AreEqual(DB_KEYMODE_DPAPI, P.KeyMode);
    Assert.AreEqual('', P.Key);
    Assert.AreEqual('', P.Salt);
    Assert.IsFalse(P.RememberKey);
end;

procedure TSettingsDbSecurityTests.PinDbKeyTo_CreatesProfile_AndRespectsRememberFlag;
var
    S: TAppSettings;
    P: TDbSecurityProfile;
begin
    // Диалоговый ключ закрепляется в профиле базы; без галки запоминания
    // passphrase-ключ в профиле не остаётся
    S := Default(TAppSettings);

    P := GetDbProfile(S, 'C:\db\a.sqlite');
    P.KeyMode := DB_KEYMODE_PASSPHRASE;
    P.Salt := 'c2FsdHNhbHRzYWx0c2FsdA==';
    SaveDbProfile(S, P);

    PinDbKeyTo(S, 'C:\db\a.sqlite', 'c2VjcmV0a2V5YmFzZTY0', False);
    P := GetDbProfile(S, 'c:\DB\A.sqlite');
    Assert.AreEqual(DB_KEYMODE_PASSPHRASE, P.KeyMode);
    Assert.IsFalse(P.RememberKey);
    Assert.AreEqual('', P.Key);

    P.RememberKey := True;
    SaveDbProfile(S, P);
    PinDbKeyTo(S, 'C:\db\a.sqlite', 'c2VjcmV0a2V5YmFzZTY0', False);
    P := GetDbProfile(S, 'C:\db\a.sqlite');
    Assert.AreEqual('c2VjcmV0a2V5YmFzZTY0', P.Key);
end;

procedure TSettingsDbSecurityTests.PinDbKeyTo_Dpapi_AlwaysStores;
var
    S: TAppSettings;
    P: TDbSecurityProfile;
begin
    // DPAPI-ключ хранится всегда, режим перепривязывается к этой машине
    S := Default(TAppSettings);
    PinDbKeyTo(S, 'C:\db\a.sqlite', 'c2VjcmV0a2V5YmFzZTY0', False);
    P := GetDbProfile(S, 'C:\db\a.sqlite');
    Assert.AreEqual(DB_KEYMODE_DPAPI, P.KeyMode);
    Assert.AreEqual('', P.Salt);
    Assert.IsTrue(P.RememberKey);
    Assert.AreEqual('c2VjcmV0a2V5YmFzZTY0', P.Key);
end;

procedure TSettingsDbSecurityTests.SaveLoad_Roundtrip_PreservesProfiles_EncryptedKeys;
var
    M: ISettingsManager;
    S: TAppSettings;
    P: TDbSecurityProfile;
    Raw: string;
begin
    M := TSettingsManager.Create;
    S := M.Data;
    P := Default(TDbSecurityProfile);
    P.Path := NormalizeDbProfilePath('C:\db\a.sqlite');
    P.KeyMode := DB_KEYMODE_PASSPHRASE;
    P.Salt := 'c2FsdHNhbHRzYWx0c2FsdA==';
    P.RememberKey := True;
    P.Key := 'c2VjcmV0a2V5YmFzZTY0';
    SaveDbProfile(S, P);
    P := Default(TDbSecurityProfile);
    P.Path := NormalizeDbProfilePath('C:\db\b.sqlite');
    P.KeyMode := DB_KEYMODE_PASSPHRASE;
    P.RememberKey := False;
    P.Key := 'c2VjcmV0a2V5YmFzZTY0';
    SaveDbProfile(S, P);
    M.Data := S;
    M.Save;
    M := nil;

    // На диске ключей в открытом виде быть не должно; профиль без галки
    // запоминания не сохраняет ключ вовсе
    Raw := TFile.ReadAllText(SettingsPath, TEncoding.UTF8);
    Assert.IsFalse(Raw.Contains('c2VjcmV0a2V5YmFzZTY0'));

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;
    Assert.AreEqual(2, S.DbProfiles.Count);
    P := GetDbProfile(S, 'C:\db\a.sqlite');
    Assert.AreEqual(DB_KEYMODE_PASSPHRASE, P.KeyMode);
    Assert.AreEqual('c2FsdHNhbHRzYWx0c2FsdA==', P.Salt);
    Assert.AreEqual('c2VjcmV0a2V5YmFzZTY0',
        TEncoding.UTF8.GetString(UnprotectSecretToBytes(P.Key)));
    P := GetDbProfile(S, 'C:\db\b.sqlite');
    Assert.AreEqual('', P.Key);
    M := nil;
end;

procedure TSettingsDbSecurityTests.StoredKeyMaterial_Profile_ReturnsBase64Key;
var
    P: TDbSecurityProfile;
begin
    // Профильный оверлоад разбирает тот же формат блоба, что и глобальный:
    // DPAPI-обёртка и открытая base64-строка в памяти
    P := Default(TDbSecurityProfile);
    P.Key := 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
    Assert.AreEqual('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
        DbStoredKeyMaterial(P));

    P.Key := ProtectSecret('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=');
    Assert.AreEqual('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
        DbStoredKeyMaterial(P));

    P.Key := '';
    Assert.AreEqual('', DbStoredKeyMaterial(P));
    P.Key := 'zzz';
    Assert.AreEqual('', DbStoredKeyMaterial(P));
end;

end.
