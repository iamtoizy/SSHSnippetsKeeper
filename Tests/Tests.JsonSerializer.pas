unit Tests.JsonSerializer;

// Р—РѕР»РѕС‚С‹Рµ С‚РµСЃС‚С‹ СЃРѕР±СЃС‚РІРµРЅРЅРѕРіРѕ СЃРµСЂРёР°Р»РёР·Р°С‚РѕСЂР° (docs\JsonSerializer.SPEC.md В§8).
// Р¤РёРєСЃС‚СѓСЂС‹ СЃРЅСЏС‚С‹ СЌРјРїРёСЂРёС‡РµСЃРєРѕР№ РїСЂРѕР±РѕР№ СЃРѕ СЃС‚Р°СЂРѕРіРѕ ThirdParty\JSONSerializer.pas
// 2026-11-21; СЃРјРµРЅР° СЃРµСЂРёР°Р»РёР·Р°С‚РѕСЂР° РЅРµ РґРѕР»Р¶РЅР° РёС… Р»РѕРјР°С‚СЊ.

interface

uses
    DUnitX.TestFramework,
    Core.Interfaces.Settings,
    Common.JsonSerializer
    ;

type
    [TestFixture]
    TJsonSerializerTests = class(TObject)
    private
        function MakeFixtureSettings: TAppSettings;
    public
        [Test]
        procedure ToJson_Compact_MatchesGoldenFixture;
        [Test]
        procedure Roundtrip_FromCompactJson_RestoresIdenticalOutput;
        [Test]
        procedure FromJson_LegacyPartialJson_DefaultsForMissing;
        [Test]
        procedure FromJson_NullStringMember_IsSkipped;
        [Test]
        procedure FromJson_UnknownMember_IsIgnored;
        [Test]
        procedure FromJson_InvalidJson_ReturnsDefaultSilently;
        [Test]
        procedure FromJson_TopLevelNumber_Raises;
        [Test]
        procedure FromJson_TopLevelArray_Raises;
        [Test]
        procedure FromJson_StringIntoIntegerField_Raises;
        [Test]
        procedure FromJson_ArrayNodeNotArray_Raises;
        [Test]
        procedure FromJson_NullBoolMember_IsSkipped;
        [Test]
        procedure FromJson_EmptyObject_AllDefaults;
        [Test]
        procedure FromJson_ArrayRecordWithExtraCount_UsesItems;
        [Test]
        procedure FromJson_PartialArrayItem_DefaultsForMissing;
        [Test]
        procedure FromJson_NumberIntoStringField_Converts;
        [Test]
        procedure FromJson_MissingArrayField_StaysEmpty;
        [Test]
        procedure ToJson_EmptyArrayFields_AreOmitted;
    end;

implementation

uses
    System.SysUtils,
    System.JSON
    ;

const
    GOLDEN_COMPACT =
      '{"UISettings":{"Help":{"HelpButton":{"HoverDelay":1500,"FadeDuration":500}},' +
      '"VCLStyle":"Windows10","SnippetListColumns":7,"SnippetListColumnsDefined":true,' +
      '"LastWorkspaceID":3},"WindowHelper":{"ActivationDelay":100,"SetFocusDelay":50,' +
      '"KeyPressInterval":10},"AllowedApplications":{"Items":[{"ExeName":"putty.exe",' +
      '"Enabled":true,"TitleIncludeRegex":"","TitleExcludeRegex":"","WindowClasses":["PuTTY"]}]},' +
      '"GlobalTitleDenyRules":{"Items":[{"Name":"rule","Pattern":"^deny me$",' +
      '"CaseSensitive":false,"Enabled":true}]},"ActiveDenyRuleSet":"","AISettings":{"Items":' +
      '[{"Name":"Hub","URL":"https://example.com/","Comment":"test","Items":{"Items":' +
      '[{"Name":"Model A","APIKey":"K","Folder":"","Model":"","Agent":"","Params":' +
      '{"Temperature":0.300000011920929,"MaxOutputTokens":1024,"Content":"c",' +
      '"ReasoningEffort":"none"}}]}}]},"CurrentLanguage":"ru","ArchiveLastFormat":0,' +
      '"ArchiveRelativePath":false,"ArchiveMaxCompression":false,"ArchiveSplit":false,' +
      '"ArchiveSplitSize":0,"Hotkeys":{"QuickSearch":{"Modifiers":0,"Key":0,"Enabled":false},' +
      '"PasswordGen":{"Modifiers":0,"Key":0,"Enabled":false},"RepeatLast":{"Modifiers":0,' +
      '"Key":0,"Enabled":false},"FavoriteSlots":{"Modifiers":0,"Key":0,"Enabled":false}},' +
      '"SyncDirectory":"","SyncOnStart":false,"SyncOnExit":false,"AutoExportEnabled":false,' +
      '"AutoExportIntervalMinutes":0,"AutoExportDefined":false,"TagsMatchAll":true,' +
      '"Backup":{"Enabled":false,"IntervalSeconds":0,"Keep":0},"BackupDefined":false,' +
      '"Db":{"Encryption":"","KeyMode":"","Key":"","Salt":"","RememberKey":false,' +
      '"FirstRunPromptDone":false,"DbDefined":false},"DbProfiles":{},"RecentDatabases":{},' +
      '"TerminalChooserTableView":false,"TerminalChooserGroupByProcess":false,' +
      '"TerminalChooserPreviewVisible":false,"TerminalChooserWidth":0,"TerminalChooserHeight":0,' +
      '"TerminalChooserPreviewHeight":0,"SecurityScanStrict":false,' +
      '"SecurityBackgroundScanEnabled":false,"SecurityBackgroundScanIntervalMinutes":0,' +
      '"SecurityBackgroundScanDefined":false}';

{ TJsonSerializerTests }

function TJsonSerializerTests.MakeFixtureSettings: TAppSettings;
var
    S: TAppSettings;
begin
    S := Default(TAppSettings);
    S.UISettings.Help.HelpButton.HoverDelay := 1500;
    S.UISettings.Help.HelpButton.FadeDuration := 500;
    S.UISettings.VCLStyle := 'Windows10';
    S.UISettings.SnippetListColumns := 7;
    S.UISettings.SnippetListColumnsDefined := True;
    S.UISettings.LastWorkspaceID := 3;
    S.WindowHelper.ActivationDelay := 100;
    S.WindowHelper.SetFocusDelay := 50;
    S.WindowHelper.KeyPressInterval := 10;
    S.AllowedApplications.Count := 1;
    S.AllowedApplications.Items[0].ExeName := 'putty.exe';
    S.AllowedApplications.Items[0].Enabled := True;
    S.AllowedApplications.Items[0].TitleIncludeRegex := '';
    S.AllowedApplications.Items[0].TitleExcludeRegex := '';
    S.AllowedApplications.Items[0].WindowClasses := TArray<string>.Create('PuTTY');
    S.GlobalTitleDenyRules.Count := 1;
    S.GlobalTitleDenyRules.Items[0].Name := 'rule';
    S.GlobalTitleDenyRules.Items[0].Pattern := '^deny me$';
    S.GlobalTitleDenyRules.Items[0].CaseSensitive := False;
    S.GlobalTitleDenyRules.Items[0].Enabled := True;
    S.AISettings.Count := 1;
    S.AISettings.Items[0].Name := 'Hub';
    S.AISettings.Items[0].URL := 'https://example.com/';
    S.AISettings.Items[0].Comment := 'test';
    S.AISettings.Items[0].Items.Count := 1;
    S.AISettings.Items[0].Items.Items[0].Name := 'Model A';
    S.AISettings.Items[0].Items.Items[0].APIKey := 'K';
    S.AISettings.Items[0].Items.Items[0].Folder := '';
    S.AISettings.Items[0].Items.Items[0].Model := '';
    S.AISettings.Items[0].Items.Items[0].Agent := '';
    S.AISettings.Items[0].Items.Items[0].Params.Temperature := 0.3;
    S.AISettings.Items[0].Items.Items[0].Params.MaxOutputTokens := 1024;
    S.AISettings.Items[0].Items.Items[0].Params.Content := 'c';
    S.AISettings.Items[0].Items.Items[0].Params.ReasoningEffort := 'none';
    S.CurrentLanguage := 'ru';
    S.TagsMatchAll := True;
    Result := S;
end;

procedure TJsonSerializerTests.ToJson_Compact_MatchesGoldenFixture;
var
    S: TAppSettings;
begin
    S := MakeFixtureSettings;
    Assert.AreEqual(GOLDEN_COMPACT, TJsonSerializer.ToJson<TAppSettings>(S, False));
end;

procedure TJsonSerializerTests.Roundtrip_FromCompactJson_RestoresIdenticalOutput;
var
    S, S2: TAppSettings;
begin
    S := TJsonSerializer.FromJson<TAppSettings>(GOLDEN_COMPACT);
    Assert.AreEqual(GOLDEN_COMPACT, TJsonSerializer.ToJson<TAppSettings>(S, False));
    S2 := TJsonSerializer.FromJson<TAppSettings>(GOLDEN_COMPACT);
    Assert.AreEqual(GOLDEN_COMPACT, TJsonSerializer.ToJson<TAppSettings>(S2, False));
end;

procedure TJsonSerializerTests.FromJson_LegacyPartialJson_DefaultsForMissing;
var
    S: TAppSettings;
begin
    S := TJsonSerializer.FromJson<TAppSettings>('{"TagsMatchAll": true}');
    Assert.IsTrue(S.TagsMatchAll);
    Assert.AreEqual('', S.CurrentLanguage);
    Assert.AreEqual(0, S.UISettings.Help.HelpButton.HoverDelay);
    Assert.AreEqual(Integer(0), Integer(Length(S.AllowedApplications.Items)));
end;

procedure TJsonSerializerTests.FromJson_NullStringMember_IsSkipped;
var
    S: TAppSettings;
begin
    S := TJsonSerializer.FromJson<TAppSettings>('{"CurrentLanguage": null}');
    Assert.AreEqual('', S.CurrentLanguage);
end;

procedure TJsonSerializerTests.FromJson_UnknownMember_IsIgnored;
var
    S: TAppSettings;
begin
    S := TJsonSerializer.FromJson<TAppSettings>('{"NoSuchKey": 42}');
    Assert.AreEqual('', S.CurrentLanguage);
    Assert.IsFalse(S.TagsMatchAll);
end;

procedure TJsonSerializerTests.FromJson_InvalidJson_ReturnsDefaultSilently;
var
    S: TAppSettings;
begin
    S := TJsonSerializer.FromJson<TAppSettings>('not json');
    Assert.AreEqual('', S.CurrentLanguage);
end;

procedure TJsonSerializerTests.FromJson_TopLevelNumber_Raises;
begin
    Assert.WillRaise(
        procedure
        begin
            TJsonSerializer.FromJson<TAppSettings>('5');
        end, EJsonSerializerException);
end;

procedure TJsonSerializerTests.FromJson_TopLevelArray_Raises;
begin
    Assert.WillRaise(
        procedure
        begin
            TJsonSerializer.FromJson<TAppSettings>('[]');
        end, EJsonSerializerException);
end;

procedure TJsonSerializerTests.FromJson_StringIntoIntegerField_Raises;
begin
    // SPEC §5: скалярные конверсии выполняет System.JSON, EJSONException
    // пробрасывается как есть (не оборачивается)
    Assert.WillRaise(
        procedure
        begin
            TJsonSerializer.FromJson<TAppSettings>('{"ArchiveLastFormat": "str"}');
        end, EJSONException);
end;

procedure TJsonSerializerTests.FromJson_ArrayNodeNotArray_Raises;
begin
    Assert.WillRaise(
        procedure
        begin
            TJsonSerializer.FromJson<TAppSettings>('{"AllowedApplications": {"Items": 5}}');
        end, EJsonSerializerException);
end;

procedure TJsonSerializerTests.FromJson_NullBoolMember_IsSkipped;
var
    S: TAppSettings;
begin
    S := TJsonSerializer.FromJson<TAppSettings>('{"TagsMatchAll": null}');
    Assert.IsFalse(S.TagsMatchAll);
end;

procedure TJsonSerializerTests.FromJson_EmptyObject_AllDefaults;
var
    S: TAppSettings;
begin
    S := TJsonSerializer.FromJson<TAppSettings>('{}');
    Assert.AreEqual(Integer(0), Integer(Length(S.AllowedApplications.Items)));
    Assert.AreEqual('', S.CurrentLanguage);
end;

procedure TJsonSerializerTests.FromJson_ArrayRecordWithExtraCount_UsesItems;
var
    S: TAppSettings;
begin
    S := TJsonSerializer.FromJson<TAppSettings>(
        '{"AllowedApplications": {"Count": 5, "Items": [{"ExeName": "a.exe", "Enabled": true}]}}');
    Assert.AreEqual(Integer(1), Integer(Length(S.AllowedApplications.Items)));
    Assert.AreEqual('a.exe', S.AllowedApplications.Items[0].ExeName);
end;

procedure TJsonSerializerTests.FromJson_PartialArrayItem_DefaultsForMissing;
var
    S: TAppSettings;
begin
    S := TJsonSerializer.FromJson<TAppSettings>(
        '{"AllowedApplications": {"Items": [{"ExeName": "a.exe"}]}}');
    Assert.AreEqual(Integer(1), Integer(Length(S.AllowedApplications.Items)));
    Assert.IsFalse(S.AllowedApplications.Items[0].Enabled);
    Assert.AreEqual(Integer(0), Integer(Length(S.AllowedApplications.Items[0].WindowClasses)));
end;

procedure TJsonSerializerTests.FromJson_NumberIntoStringField_Converts;
var
    S: TAppSettings;
begin
    S := TJsonSerializer.FromJson<TAppSettings>(
        '{"AllowedApplications": {"Items": [{"ExeName": 42, "Enabled": true}]}}');
    Assert.AreEqual('42', S.AllowedApplications.Items[0].ExeName);
end;

procedure TJsonSerializerTests.FromJson_MissingArrayField_StaysEmpty;
var
    S: TAppSettings;
begin
    S := TJsonSerializer.FromJson<TAppSettings>('{"CurrentLanguage": "en"}');
    Assert.AreEqual(Integer(0), Integer(Length(S.RecentDatabases.Items)));
end;

procedure TJsonSerializerTests.ToJson_EmptyArrayFields_AreOmitted;
var
    S: TAppSettings;
    Json: string;
begin
    S := Default(TAppSettings);
    Json := TJsonSerializer.ToJson<TAppSettings>(S, False);
    // РџР»РѕСЃРєРёРµ РїСѓСЃС‚С‹Рµ TArray<T> РЅРµ РїРѕРїР°РґР°СЋС‚ РІ JSON (TValue.Empty РЅР° nil-РјР°СЃСЃРёРІРµ)
    Assert.IsFalse(Json.Contains('"ChmodPresets"'));
    Assert.IsFalse(Json.Contains('"DenyRuleSets"'));
    Assert.IsFalse(Json.Contains('"HistoryUsers"'));
    Assert.IsFalse(Json.Contains('"CustomShortCuts"'));
    // РџСѓСЃС‚РѕР№ TArrayRecord -> {} (РєР»СЋС‡ РµСЃС‚СЊ, РјР°СЃСЃРёРІР° РЅРµС‚)
    Assert.IsTrue(Json.Contains('"DbProfiles":{}'));
    Assert.IsTrue(Json.Contains('"RecentDatabases":{}'));
end;

initialization
    TDUnitX.RegisterTestFixture(TJsonSerializerTests);

end.
