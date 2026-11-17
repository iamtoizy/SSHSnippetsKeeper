unit Tests.TypingGuard;

interface

uses
    DUnitX.TestFramework,
    SecurityScanner,
    TypingGuard
    ;

type
    TTypingGuardTests = class(TObject)
    public
        [Test]
        procedure DangerousCommands_AreDetected;

        [Test]
        procedure CleanText_HasNoFindings;

        [Test]
        procedure Secrets_AreDetected_ViaScanner;

        [Test]
        procedure Detection_IsCaseInsensitive;

        [Test]
        procedure EmptyText_NoFindings;
    end;

implementation

{ TTypingGuardTests }

procedure TTypingGuardTests.DangerousCommands_AreDetected;
var
    Findings: TArray<TGuardFinding>;
    F: TGuardFinding;
    HasDanger: Boolean;
begin
    HasDanger := False;
    Findings := TTypingGuard.Findings('cd /tmp && rm -rf /old', nil);
    for F in Findings do
        if F.Kind = gfDanger then
            HasDanger := True;
    Assert.IsTrue(HasDanger, 'rm -rf must be detected');
end;

procedure TTypingGuardTests.CleanText_HasNoFindings;
begin
    Assert.AreEqual<Integer>(0, Length(TTypingGuard.Findings(
        'echo "hello world" && ls -la /tmp', nil)),
        'Benign text must produce no findings');
end;

procedure TTypingGuardTests.Secrets_AreDetected_ViaScanner;
var
    Scanner: ISecurityScanner;
begin
    Scanner := TSecurityScanner.Create(scanTolerant);
    Assert.IsTrue(Length(TTypingGuard.Findings(
        'export TOKEN=ghp_' + StringOfChar('a', 36), Scanner)) > 0,
        'Secrets must be detected via scanner');
end;

procedure TTypingGuardTests.Detection_IsCaseInsensitive;
begin
    Assert.IsTrue(Length(TTypingGuard.Findings('RM -RF /', nil)) > 0,
        'Detection must be case-insensitive');
end;

procedure TTypingGuardTests.EmptyText_NoFindings;
begin
    Assert.AreEqual<Integer>(0, Length(TTypingGuard.Findings('', nil)),
        'Empty text must produce no findings');
end;

end.
