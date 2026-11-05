unit Tests.SecurityReport;

interface

uses
    DUnitX.TestFramework,
    SecurityScanner,
    SecurityReport,
    Core.Entities.Snippet
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

end.
