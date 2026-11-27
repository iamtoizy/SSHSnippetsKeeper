unit Tests.DenyRuleSets;

interface

uses
    DUnitX.TestFramework,
    Core.Interfaces.Settings,
    Core.Interfaces.App,
    Common.Settings,
    Common.JsonSerializer
    ;

type
    [TestFixture]
    TDenyRuleSetsTests = class(TObject)
    private
        function SettingsPath: string;
        procedure SafeDeleteIfPresent(const APath: string);
        function MakeRule(const AName, APattern: string; AEnabled: Boolean = True): TGlobalTitleDenyRule;
        function MakeSet(const AName: string; const ARules: TArray<TGlobalTitleDenyRule>): TDenyRuleSet;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test]
        procedure NewFields_DefaultToEmpty;
        [Test]
        procedure DenyRuleSets_SurviveSaveLoadRoundtrip;
        [Test]
        procedure NestedRules_SurviveRoundtrip_ValuesIntact;
        [Test]
        procedure LegacyJson_WithoutNewFields_EmptyAndBlankActive;
        [Test]
        procedure LastWorkspaceID_SurvivesRoundtrip;
        [Test]
        procedure Sanitize_DropsEmptyNamedSets;
        [Test]
        procedure Sanitize_DropsDuplicateNames_CaseInsensitive;
        [Test]
        procedure Sanitize_DropsBadRegexRules_InSets;
        [Test]
        procedure Sanitize_ResetsOrphanActiveName;
        [Test]
        procedure Sanitize_KeepsEmptyRulesSet;
        [Test]
        procedure Sanitize_TrimsNamesAndPatterns;
    end;

implementation

uses
    System.SysUtils,
    System.IOUtils
    ;

{ TDenyRuleSetsTests }

function TDenyRuleSetsTests.SettingsPath: string;
begin
    Result := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'settings.json');
end;

// Удаление с учётом TOCTOU: между Exists и Delete файл может исчезнуть
// (внешний синк/антивирус), и DeleteFile вернёт FILE_NOT_FOUND
procedure TDenyRuleSetsTests.SafeDeleteIfPresent(const APath: string);
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

function TDenyRuleSetsTests.MakeRule(const AName, APattern: string;
    AEnabled: Boolean): TGlobalTitleDenyRule;
begin
    Result := Default(TGlobalTitleDenyRule);
    Result.Name := AName;
    Result.Pattern := APattern;
    Result.CaseSensitive := False;
    Result.Enabled := AEnabled;
end;

function TDenyRuleSetsTests.MakeSet(const AName: string;
    const ARules: TArray<TGlobalTitleDenyRule>): TDenyRuleSet;
begin
    Result := Default(TDenyRuleSet);
    Result.Name := AName;
    Result.Rules := ARules;
end;

procedure TDenyRuleSetsTests.Setup;
begin
    SafeDeleteIfPresent(SettingsPath);
    SafeDeleteIfPresent(SettingsPath + '.tmp');
    SafeDeleteIfPresent(SettingsPath + '.corrupt');
end;

procedure TDenyRuleSetsTests.TearDown;
begin
    SafeDeleteIfPresent(SettingsPath);
    SafeDeleteIfPresent(SettingsPath + '.tmp');
    SafeDeleteIfPresent(SettingsPath + '.corrupt');
end;

procedure TDenyRuleSetsTests.NewFields_DefaultToEmpty;
var
    Setts: TAppSettings;
begin
    Setts := Default(TAppSettings);

    Assert.AreEqual(0, Integer(Length(Setts.DenyRuleSets)));
    Assert.AreEqual('', Setts.ActiveDenyRuleSet);
    Assert.AreEqual(0, Setts.UISettings.LastWorkspaceID);
end;

procedure TDenyRuleSetsTests.DenyRuleSets_SurviveSaveLoadRoundtrip;
var
    M1, M2: ISettingsManager;
    S: TAppSettings;
begin
    M1 := TSettingsManager.Create;
    S := M1.Data;
    SetLength(S.DenyRuleSets, 2);
    S.DenyRuleSets[0] := MakeSet('Work', [
        MakeRule('Bank', '.*Bank.*'),
        MakeRule('Terminal', '^Terminal$', False)
    ]);
    S.DenyRuleSets[1] := MakeSet('Home', []);
    S.ActiveDenyRuleSet := 'Work';
    M1.Data := S;
    M1.Save;
    M1 := nil;

    M2 := TSettingsManager.Create;
    M2.Load;
    S := M2.Data;

    Assert.AreEqual(2, Integer(Length(S.DenyRuleSets)));
    Assert.AreEqual('Work', S.DenyRuleSets[0].Name);
    Assert.AreEqual('Home', S.DenyRuleSets[1].Name);
    Assert.AreEqual('Work', S.ActiveDenyRuleSet);
    M2 := nil;
end;

procedure TDenyRuleSetsTests.NestedRules_SurviveRoundtrip_ValuesIntact;
var
    M1, M2: ISettingsManager;
    S: TAppSettings;
begin
    M1 := TSettingsManager.Create;
    S := M1.Data;
    SetLength(S.DenyRuleSets, 1);
    S.DenyRuleSets[0] := MakeSet('Work', [
        MakeRule('Bank', '.*Bank.*'),
        MakeRule('Terminal', '^Terminal$', False)
    ]);
    M1.Data := S;
    M1.Save;
    M1 := nil;

    M2 := TSettingsManager.Create;
    M2.Load;
    S := M2.Data;

    Assert.AreEqual(2, Integer(Length(S.DenyRuleSets[0].Rules)));
    Assert.AreEqual('Bank', S.DenyRuleSets[0].Rules[0].Name);
    Assert.AreEqual('.*Bank.*', S.DenyRuleSets[0].Rules[0].Pattern);
    Assert.IsFalse(S.DenyRuleSets[0].Rules[1].Enabled);
    Assert.AreEqual('^Terminal$', S.DenyRuleSets[0].Rules[1].Pattern);
    Assert.IsFalse(S.DenyRuleSets[0].Rules[1].CaseSensitive);
    M2 := nil;
end;

procedure TDenyRuleSetsTests.LegacyJson_WithoutNewFields_EmptyAndBlankActive;
var
    M: ISettingsManager;
    S: TAppSettings;
begin
    // Старый settings.json без новых узлов: пустые шаблоны и пустое
    // активное имя = прежнее поведение
    TFile.WriteAllText(SettingsPath, '{"CurrentLanguage":"en"}', TEncoding.UTF8);

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;

    Assert.AreEqual(0, Integer(Length(S.DenyRuleSets)));
    Assert.AreEqual('', S.ActiveDenyRuleSet);
    Assert.AreEqual(0, S.UISettings.LastWorkspaceID);
    M := nil;
end;

procedure TDenyRuleSetsTests.LastWorkspaceID_SurvivesRoundtrip;
var
    M1, M2: ISettingsManager;
    S: TAppSettings;
begin
    M1 := TSettingsManager.Create;
    S := M1.Data;
    S.UISettings.LastWorkspaceID := 3;
    M1.Data := S;
    M1.Save;
    M1 := nil;

    M2 := TSettingsManager.Create;
    M2.Load;
    S := M2.Data;

    Assert.AreEqual(3, S.UISettings.LastWorkspaceID);
    M2 := nil;
end;

procedure TDenyRuleSetsTests.Sanitize_DropsEmptyNamedSets;
var
    M: ISettingsManager;
    S: TAppSettings;
begin
    // Шаблон с пустым именем отбрасывается целиком
    TFile.WriteAllText(SettingsPath,
        '{"CurrentLanguage":"en","DenyRuleSets":[' +
        '{"Name":"Valid","Rules":[]},' +
        '{"Name":"   ","Rules":[]},' +
        '{"Name":"Dup","Rules":[]}' +
        ']}', TEncoding.UTF8);

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;

    Assert.AreEqual(2, Integer(Length(S.DenyRuleSets)));
    Assert.AreEqual('Valid', S.DenyRuleSets[0].Name);
    Assert.AreEqual('Dup', S.DenyRuleSets[1].Name);
    M := nil;
end;

procedure TDenyRuleSetsTests.Sanitize_DropsDuplicateNames_CaseInsensitive;
var
    M: ISettingsManager;
    S: TAppSettings;
begin
    // Дубликат имени (без учёта регистра): первый выживает
    TFile.WriteAllText(SettingsPath,
        '{"CurrentLanguage":"en","DenyRuleSets":[' +
        '{"Name":"Work","Rules":[]},' +
        '{"Name":"WORK","Rules":[]}' +
        ']}', TEncoding.UTF8);

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;

    Assert.AreEqual(1, Integer(Length(S.DenyRuleSets)));
    Assert.AreEqual('Work', S.DenyRuleSets[0].Name);
    M := nil;
end;

procedure TDenyRuleSetsTests.Sanitize_DropsBadRegexRules_InSets;
var
    M: ISettingsManager;
    S: TAppSettings;
begin
    // Внутри шаблона: пустой Pattern и битый regex отбрасываются,
    // валидное правило сохраняется
    TFile.WriteAllText(SettingsPath,
        '{"CurrentLanguage":"en","DenyRuleSets":[' +
        '{"Name":"S","Rules":[' +
        '{"Name":"Good","Pattern":"ok","CaseSensitive":false,"Enabled":true},' +
        '{"Name":"Bad","Pattern":"[","CaseSensitive":false,"Enabled":true},' +
        '{"Name":"","Pattern":"   ","CaseSensitive":false,"Enabled":true}' +
        ']}]}', TEncoding.UTF8);

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;

    Assert.AreEqual(1, Integer(Length(S.DenyRuleSets)));
    Assert.AreEqual(1, Integer(Length(S.DenyRuleSets[0].Rules)));
    Assert.AreEqual('Good', S.DenyRuleSets[0].Rules[0].Name);
    M := nil;
end;

procedure TDenyRuleSetsTests.Sanitize_ResetsOrphanActiveName;
var
    M: ISettingsManager;
    S: TAppSettings;
begin
    // Активное имя без шаблона сбрасывается в пустое
    TFile.WriteAllText(SettingsPath,
        '{"CurrentLanguage":"en","ActiveDenyRuleSet":"Ghost"}', TEncoding.UTF8);

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;

    Assert.AreEqual('', S.ActiveDenyRuleSet);
    M := nil;
end;

procedure TDenyRuleSetsTests.Sanitize_KeepsEmptyRulesSet;
var
    M: ISettingsManager;
    S: TAppSettings;
begin
    // Шаблон без правил - валидное состояние («ничего не запрещено»)
    TFile.WriteAllText(SettingsPath,
        '{"CurrentLanguage":"en","DenyRuleSets":[' +
        '{"Name":"EmptyOk","Rules":[]}],' +
        '"ActiveDenyRuleSet":"EmptyOk"}', TEncoding.UTF8);

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;

    Assert.AreEqual(1, Integer(Length(S.DenyRuleSets)));
    Assert.AreEqual('EmptyOk', S.ActiveDenyRuleSet);
    M := nil;
end;

procedure TDenyRuleSetsTests.Sanitize_TrimsNamesAndPatterns;
var
    M: ISettingsManager;
    S: TAppSettings;
begin
    // Имена шаблонов и паттерны правил триммятся; активное имя
    // сверяется с триммированными именами
    TFile.WriteAllText(SettingsPath,
        '{"CurrentLanguage":"en","DenyRuleSets":[' +
        '{"Name":"  Name  ","Rules":[' +
        '{"Name":"","Pattern":"  .*x.*  ","CaseSensitive":false,"Enabled":true}' +
        ']}],' +
        '"ActiveDenyRuleSet":"  Name  "}', TEncoding.UTF8);

    M := TSettingsManager.Create;
    M.Load;
    S := M.Data;

    Assert.AreEqual('Name', S.DenyRuleSets[0].Name);
    Assert.AreEqual('.*x.*', S.DenyRuleSets[0].Rules[0].Pattern);
    Assert.AreEqual('Name', S.ActiveDenyRuleSet);
    M := nil;
end;

end.
