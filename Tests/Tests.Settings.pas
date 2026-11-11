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

implementation

uses
    JSONSerializer,
    System.Classes,
    System.IOUtils
    ;

const
    SECRET_TEST_KEY = 'sk-live-1234567890abcdef';
    PLACEHOLDER_API_KEY = 'Paste-your-API-key-here';

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
    if TFile.Exists(SettingsPath) then
        TFile.Delete(SettingsPath);
    if TFile.Exists(SettingsPath + '.tmp') then
        TFile.Delete(SettingsPath + '.tmp');
end;

procedure TSettingsManagerTests.TearDown;
begin
    if TFile.Exists(SettingsPath) then
        TFile.Delete(SettingsPath);
    if TFile.Exists(SettingsPath + '.tmp') then
        TFile.Delete(SettingsPath + '.tmp');
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

end.
