unit Tests.SecurityReport;

interface

uses
    DUnitX.TestFramework,
    SecurityScanner,
    SecurityReport,
    Core.Entities.Snippet,
    Core.Interfaces.Settings,
    JSONSerializer
    ;

type
    [TestFixture]
    TSecurityReportTests = class(TObject)
    private
        function MakeSnippet(const Title, Content, Comment: string): TSnippetDTO;
    public
        [Test]
        procedure CleanSnippets_ProduceNoFindings;
        [Test]
        procedure SensitiveContent_ProducesFinding;
        [Test]
        procedure SensitiveComment_ProducesCommentReason;
        [Test]
        procedure TrustedSnippet_ListedAndMarked;
        [Test]
        procedure Finding_KeepsIdsAndTitle;
        [Test]
        procedure Filter_HideTrusted_HidesIgnoredSnippets;
        [Test]
        procedure Filter_ShowAll_EmptyInputStaysEmpty;
    end;

    [TestFixture]
    TSecurityScannerEntropyTests = class(TObject)
    public
        [Test]
        procedure SqlAggregation_NotFlaggedByEntropy;
        [Test]
        procedure AwsSecretStyle_StillFlaggedByEntropy;
        [Test]
        procedure Base64Secret_StillFlaggedByEntropy;
        [Test]
        procedure JwtToken_StillFlaggedByRegex;
        [Test]
        procedure NonAlphabetChar_RejectedByComposition;
        [Test]
        procedure StrictMode_SpecialCharPassword_FlaggedByDesign;
        [Test]
        procedure TolerantMode_SamePassword_NotFlagged;
        [Test]
        procedure StrictMode_SqlAggregation_FlaggedByDesign;
        [Test]
        procedure StrictMode_Base64Secret_StillFlagged;
    end;

    [TestFixture]
    TSecuritySettingsTests = class(TObject)
    public
        [Test]
        procedure DefaultSettings_AreTolerant;
        [Test]
        procedure StrictSetting_SurvivesRoundtrip;
        [Test]
        procedure LegacyJson_WithoutField_IsTolerant;
        [Test]
        procedure ScanModeFromSetting_MapsBothWays;
    end;

    [TestFixture]
    TSecurityRangesTests = class(TObject)
    public
        [Test]
        procedure Ranges_EmptyText_NoRanges;
        [Test]
        procedure Ranges_RegexHit_OffsetsMatch;
        [Test]
        procedure Ranges_EntropyHit_OffsetsMatch;
        [Test]
        procedure NewPrefixes_AIProviders_Detected;
        [Test]
        procedure NewPrefixes_DevPlatforms_Detected;
        [Test]
        procedure Boundary_AKIAInsideWord_NotMatched;
    end;

implementation

{ TSecurityReportTests }

function TSecurityReportTests.MakeSnippet(const Title, Content,
    Comment: string): TSnippetDTO;
begin
    Result := Default(TSnippetDTO);
    Result.ID := Random(100000) + 1;
    Result.UserID := 1;
    Result.CategoryID := 7;
    Result.Title := Title;
    Result.Content := Content;
    Result.Comment := Comment;
end;

procedure TSecurityReportTests.CleanSnippets_ProduceNoFindings;
var
    Scanner: ISecurityScanner;
    Snippets: TArray<TSnippetDTO>;
    Findings: TArray<TSecurityFinding>;
begin
    Scanner := TSecurityScanner.Create;
    Snippets := [
        MakeSnippet('ls', 'ls -la /var/log', 'список логов'),
        MakeSnippet('df', 'df -h', '')];

    Findings := BuildSecurityReport(Scanner, Snippets);

    Assert.AreEqual(0, Integer(Length(Findings)));
end;

procedure TSecurityReportTests.SensitiveContent_ProducesFinding;
var
    Scanner: ISecurityScanner;
    Snippets: TArray<TSnippetDTO>;
    Findings: TArray<TSecurityFinding>;
begin
    Scanner := TSecurityScanner.Create;
    // Явное указание пароля (ExplicitPasswordKey) + ключ AWS (AKIA+16)
    Snippets := [MakeSnippet('deploy',
        'aws deploy --key AKIAABCDEFGHIJKLMNOP --password = Sup3rS3cret!',
        '')];

    Findings := BuildSecurityReport(Scanner, Snippets);

    Assert.AreEqual(1, Integer(Length(Findings)));
    Assert.IsNotEmpty(Findings[0].ContentReason);
    Assert.AreEqual('', Findings[0].CommentReason);
end;

procedure TSecurityReportTests.SensitiveComment_ProducesCommentReason;
var
    Scanner: ISecurityScanner;
    Snippets: TArray<TSnippetDTO>;
    Findings: TArray<TSecurityFinding>;
begin
    Scanner := TSecurityScanner.Create;
    // Контент чистый, секрет спрятан в комментарии (токен GitHub - ghp_ + 36 символов)
    Snippets := [MakeSnippet('backup', 'tar -czf backup.tar.gz /etc',
        'token = ghp_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHH1111')];

    Findings := BuildSecurityReport(Scanner, Snippets);

    Assert.AreEqual(1, Integer(Length(Findings)));
    Assert.AreEqual('', Findings[0].ContentReason);
    Assert.IsNotEmpty(Findings[0].CommentReason);
end;

procedure TSecurityReportTests.TrustedSnippet_ListedAndMarked;
var
    Scanner: ISecurityScanner;
    Snippets: TArray<TSnippetDTO>;
    Findings: TArray<TSecurityFinding>;
begin
    Scanner := TSecurityScanner.Create;
    Snippets := [MakeSnippet('legacy', 'token = my_secret_token_value', '')];
    Snippets[0].IsSecurityCheckIgnored := True;

    // Доверенный сниппет не исключается из отчёта, а помечается флагом
    Findings := BuildSecurityReport(Scanner, Snippets);

    Assert.AreEqual(1, Integer(Length(Findings)));
    Assert.IsTrue(Findings[0].Trusted);
    Assert.IsNotEmpty(Findings[0].ContentReason);
end;

procedure TSecurityReportTests.Finding_KeepsIdsAndTitle;
var
    Scanner: ISecurityScanner;
    Snippets: TArray<TSnippetDTO>;
    Findings: TArray<TSecurityFinding>;
begin
    Scanner := TSecurityScanner.Create;
    Snippets := [
        MakeSnippet('clean', 'echo ok', ''),
        MakeSnippet('leaky', 'password = my_hidden_secret', '')];
    Snippets[1].ID := 4242;
    Snippets[1].CategoryID := 9;
    Snippets[1].UserID := 3;

    Findings := BuildSecurityReport(Scanner, Snippets);

    Assert.AreEqual(1, Integer(Length(Findings)));
    Assert.AreEqual(4242, Findings[0].SnippetID);
    Assert.AreEqual(9, Findings[0].CategoryID);
    Assert.AreEqual(3, Findings[0].UserID);
    Assert.AreEqual('leaky', Findings[0].Title);
    Assert.IsFalse(Findings[0].Trusted);
end;

procedure TSecurityReportTests.Filter_HideTrusted_HidesIgnoredSnippets;
var
    Scanner: ISecurityScanner;
    Snippets: TArray<TSnippetDTO>;
    Findings, Filtered: TArray<TSecurityFinding>;
begin
    Scanner := TSecurityScanner.Create;
    Snippets := [
        MakeSnippet('legacy', 'token = my_secret_token_value', ''),
        MakeSnippet('leaky', 'password = my_hidden_secret', '')];
    Snippets[0].IsSecurityCheckIgnored := True;

    Findings := BuildSecurityReport(Scanner, Snippets);
    Assert.AreEqual(2, Integer(Length(Findings)));

    // Скрываем доверенные: остаётся только 'leaky'
    Filtered := FilterSecurityReport(Findings, True);
    Assert.AreEqual(1, Integer(Length(Filtered)));
    Assert.AreEqual('leaky', Filtered[0].Title);
    Assert.IsFalse(Filtered[0].Trusted);

    // Без фильтра возвращаются обе записи
    Filtered := FilterSecurityReport(Findings, False);
    Assert.AreEqual(2, Integer(Length(Filtered)));
end;

procedure TSecurityReportTests.Filter_ShowAll_EmptyInputStaysEmpty;
var
    Findings: TArray<TSecurityFinding>;
begin
    Findings := [];

    Assert.AreEqual(0, Integer(Length(FilterSecurityReport(Findings, True))));
    Assert.AreEqual(0, Integer(Length(FilterSecurityReport(Findings, False))));
end;

{ TSecurityScannerEntropyTests }

procedure TSecurityScannerEntropyTests.SqlAggregation_NotFlaggedByEntropy;
var
    Scanner: ISecurityScanner;
    Reason: string;
begin
    Scanner := TSecurityScanner.Create;

    // Реальный SQL-сниппет из практики: вызов функции со скобками и делением.
    // Пунктуация кода разбивает токены, энтропия ни одного не превышает порог.
    Assert.IsFalse(Scanner.HasSensitiveData(
        'SELECT table_schema, ROUND(SUM(data_length+index_length)/1024/1024,2) AS mb ' +
        'FROM information_schema.tables GROUP BY table_schema;', Reason));
end;

procedure TSecurityScannerEntropyTests.AwsSecretStyle_StillFlaggedByEntropy;
var
    Scanner: ISecurityScanner;
    Reason: string;
begin
    Scanner := TSecurityScanner.Create;

    // AWS secret access key: Base64-подобный, содержит '/', не разрывается
    Assert.IsTrue(Scanner.HasSensitiveData('wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY', Reason));
end;

procedure TSecurityScannerEntropyTests.Base64Secret_StillFlaggedByEntropy;
var
    Scanner: ISecurityScanner;
    Reason: string;
begin
    Scanner := TSecurityScanner.Create;

    Assert.IsTrue(Scanner.HasSensitiveData('kM5tX9wQ2vR7bN4yJ6hF3cL1zP8sD0gEaUoTiq=', Reason));
end;

procedure TSecurityScannerEntropyTests.JwtToken_StillFlaggedByRegex;
var
    Scanner: ISecurityScanner;
    Reason: string;
begin
    Scanner := TSecurityScanner.Create;

    Assert.IsTrue(Scanner.HasSensitiveData(
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIn0.' +
        'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c', Reason));
end;

procedure TSecurityScannerEntropyTests.NonAlphabetChar_RejectedByComposition;
var
    Scanner: ISecurityScanner;
    Reason: string;
begin
    Scanner := TSecurityScanner.Create;

    // Строка достаточно случайная (энтропия ~5.1 > порога 4.5), но '$' –
    // признак переменной/кода, а не секрета: отсеивается проверкой состава.
    Assert.IsFalse(Scanner.HasSensitiveData('Kx7$mQ2vB9nR4tZ8yW3cF6hJ1pL5sD0gEa', Reason));
end;

procedure TSecurityScannerEntropyTests.StrictMode_SpecialCharPassword_FlaggedByDesign;
var
    Scanner: ISecurityScanner;
    Reason: string;
begin
    Scanner := TSecurityScanner.Create(scanStrict);

    // Спецсимвольный пароль (H~4.96, каждый фрагмент короче 16):
    // строгий сканер аудита должен его поймать, ложное срабатывание приемлемо.
    Assert.IsTrue(Scanner.HasSensitiveData('Qw7!Xr2#Km9@Tb4%Vn6^Zc8*He3!Jp5@Ls7', Reason));
end;

procedure TSecurityScannerEntropyTests.TolerantMode_SamePassword_NotFlagged;
var
    Scanner: ISecurityScanner;
    Reason: string;
begin
    Scanner := TSecurityScanner.Create(scanTolerant);

    // Тот же пароль в run-time: фрагменты < 16 символов – не отвлекаем пользователя.
    Assert.IsFalse(Scanner.HasSensitiveData('Qw7!Xr2#Km9@Tb4%Vn6^Zc8*He3!Jp5@Ls7', Reason));
end;

procedure TSecurityScannerEntropyTests.StrictMode_SqlAggregation_FlaggedByDesign;
var
    Scanner: ISecurityScanner;
    Reason: string;
begin
    Scanner := TSecurityScanner.Create(scanStrict);

    // SQL, который терпимый режим пропускает: в строгом остаётся одним токеном
    // с энтропией выше порога – задокументированное ложное срабатывание аудита.
    Assert.IsTrue(Scanner.HasSensitiveData(
        'SELECT table_schema, ROUND(SUM(data_length+index_length)/1024/1024,2) AS mb ' +
        'FROM information_schema.tables GROUP BY table_schema;', Reason));
end;

procedure TSecurityScannerEntropyTests.StrictMode_Base64Secret_StillFlagged;
var
    Scanner: ISecurityScanner;
    Reason: string;
begin
    Scanner := TSecurityScanner.Create(scanStrict);

    Assert.IsTrue(Scanner.HasSensitiveData('kM5tX9wQ2vR7bN4yJ6hF3cL1zP8sD0gEaUoTiq=', Reason));
end;

{ TSecuritySettingsTests }

// Спецсимвольный пароль: строгий режим флагает, терпимый нет
const
    MODE_PROBE_SECRET = 'Qw7!Xr2#Km9@Tb4%Vn6^Zc8*He3!Jp5@Ls7';

procedure TSecuritySettingsTests.DefaultSettings_AreTolerant;
var
    Setts: TAppSettings;
    Scanner: ISecurityScanner;
    Reason: string;
begin
    Setts := Default(TAppSettings);

    Assert.IsFalse(Setts.SecurityScanStrict);
    Scanner := TSecurityScanner.Create(TSecurityScanner.ScanModeFromSetting(Setts.SecurityScanStrict));
    Assert.IsFalse(Scanner.HasSensitiveData(MODE_PROBE_SECRET, Reason));
end;

procedure TSecuritySettingsTests.StrictSetting_SurvivesRoundtrip;
var
    Setts: TAppSettings;
    Scanner: ISecurityScanner;
    Reason: string;
begin
    Setts := Default(TAppSettings);
    Setts.SecurityScanStrict := True;

    Setts := DSON.fromJson<TAppSettings>(DSON.toJson<TAppSettings>(Setts));

    Assert.IsTrue(Setts.SecurityScanStrict);
    Scanner := TSecurityScanner.Create(TSecurityScanner.ScanModeFromSetting(Setts.SecurityScanStrict));
    Assert.IsTrue(Scanner.HasSensitiveData(MODE_PROBE_SECRET, Reason));
end;

procedure TSecuritySettingsTests.LegacyJson_WithoutField_IsTolerant;
var
    Setts: TAppSettings;
    Scanner: ISecurityScanner;
    Reason: string;
begin
    // Старый settings.json без нового поля: терпимый режим = прежнее поведение
    Setts := DSON.fromJson<TAppSettings>('{"TagsMatchAll": true}');

    Assert.IsFalse(Setts.SecurityScanStrict);
    Scanner := TSecurityScanner.Create(TSecurityScanner.ScanModeFromSetting(Setts.SecurityScanStrict));
    Assert.IsFalse(Scanner.HasSensitiveData(MODE_PROBE_SECRET, Reason));
end;

procedure TSecuritySettingsTests.ScanModeFromSetting_MapsBothWays;
begin
    Assert.IsTrue(TSecurityScanner.ScanModeFromSetting(False) = scanTolerant);
    Assert.IsTrue(TSecurityScanner.ScanModeFromSetting(True) = scanStrict);
end;

{ TSecurityRangesTests }

procedure TSecurityRangesTests.Ranges_EmptyText_NoRanges;
var
    Scanner: ISecurityScanner;
begin
    Scanner := TSecurityScanner.Create;

    Assert.AreEqual(0, Integer(Length(Scanner.FindSensitiveRanges(''))));
    Assert.AreEqual(0, Integer(Length(Scanner.FindSensitiveRanges('   '))));
end;

procedure TSecurityRangesTests.Ranges_RegexHit_OffsetsMatch;
var
    Scanner: ISecurityScanner;
    Ranges: TArray<TSecretRange>;
begin
    Scanner := TSecurityScanner.Create;
    Ranges := Scanner.FindSensitiveRanges('apikey: supersecret1234');

    // ExplicitPasswordKey: ключ + значение целиком
    Assert.IsTrue(Length(Ranges) >= 1);
    Assert.AreEqual(0, Ranges[0].StartOffset);
    Assert.AreEqual(Length('apikey: supersecret1234'), Ranges[0].Length);
end;

procedure TSecurityRangesTests.Ranges_EntropyHit_OffsetsMatch;
var
    Scanner: ISecurityScanner;
    Ranges: TArray<TSecretRange>;
begin
    Scanner := TSecurityScanner.Create;
    Ranges := Scanner.FindSensitiveRanges('echo ' + 'kM5tX9wQ2vR7bN4yJ6hF3cL1zP8sD0gEaUoTiq=');

    // Единственная находка - base64-токен с точным офсетом; завершающий
    // '=' в токен не входит: он разделитель в обоих режимах токенизации
    Assert.AreEqual(1, Integer(Length(Ranges)));
    Assert.AreEqual(5, Ranges[0].StartOffset);
    Assert.AreEqual(38, Ranges[0].Length);
end;

procedure TSecurityRangesTests.NewPrefixes_AIProviders_Detected;
var
    Scanner: ISecurityScanner;
    Reason: string;
begin
    Scanner := TSecurityScanner.Create;

    // OpenAI legacy: sk- + 48 алнум
    Assert.IsTrue(Scanner.HasSensitiveData(
        'sk-' + StringOfChar('a', 24) + StringOfChar('1', 24), Reason));
    // OpenAI project key
    Assert.IsTrue(Scanner.HasSensitiveData(
        'sk-proj-' + StringOfChar('b', 25), Reason));
    // Anthropic: sk-ant-api03-...
    Assert.IsTrue(Scanner.HasSensitiveData(
        'sk-ant-api03-' + StringOfChar('c', 22), Reason));
    // HuggingFace
    Assert.IsTrue(Scanner.HasSensitiveData('hf_' + StringOfChar('d', 34), Reason));
end;

procedure TSecurityRangesTests.NewPrefixes_DevPlatforms_Detected;
var
    Scanner: ISecurityScanner;
    Reason: string;
begin
    Scanner := TSecurityScanner.Create;

    Assert.IsTrue(Scanner.HasSensitiveData('glpat-' + StringOfChar('a', 20), Reason));
    Assert.IsTrue(Scanner.HasSensitiveData('github_pat_' + StringOfChar('b', 20), Reason));
    Assert.IsTrue(Scanner.HasSensitiveData('npm_' + StringOfChar('1', 36), Reason));
    Assert.IsTrue(Scanner.HasSensitiveData('pypi-' + StringOfChar('2', 40), Reason));
    Assert.IsTrue(Scanner.HasSensitiveData('dop_v1_' + StringOfChar('0', 64), Reason));
    Assert.IsTrue(Scanner.HasSensitiveData(
        'SG.' + StringOfChar('a', 16) + '.' + StringOfChar('b', 16), Reason));
end;

procedure TSecurityRangesTests.Boundary_AKIAInsideWord_NotMatched;
var
    Scanner: ISecurityScanner;
begin
    Scanner := TSecurityScanner.Create;

    // Самостоятельный ключ - ровно один regex-диапазон (энтропия ниже порога)
    Assert.AreEqual(1, Integer(Length(
        Scanner.FindSensitiveRanges('AKIAIOSFODNN7EXAMPLE'))));

    // Тот же ключ внутри более длинного токена: \b не даёт совпадения,
    // энтропия тоже не дотягивает - ноль находок
    Assert.AreEqual(0, Integer(Length(
        Scanner.FindSensitiveRanges('XAKIAIOSFODNN7EXAMPLEZ'))));
end;

end.
