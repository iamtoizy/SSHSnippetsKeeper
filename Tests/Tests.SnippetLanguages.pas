unit Tests.SnippetLanguages;

interface

uses
    DUnitX.TestFramework,
    Common.SnippetLanguages
    ;

type
    [TestFixture]
    TSnippetLanguagesTests = class(TObject)
    public
        [Test]
        procedure Normalize_Aliases_AndCase;
        [Test]
        procedure Normalize_Unknown_AndEmpty_DefaultBash;
        [Test]
        procedure Supported_List_CoversAll;
        [Test]
        procedure FenceTag_MatchesNormalized;
        [Test]
        procedure ShouldRedetect_OnlySubstantialChanges;
    end;

implementation

uses
    Common.Consts,
    System.SysUtils
    ;

{ TSnippetLanguagesTests }

procedure TSnippetLanguagesTests.Normalize_Aliases_AndCase;
begin
    Assert.AreEqual(SNIPPET_LANG_BAT, NormalizeSnippetLanguage('CMD'));
    Assert.AreEqual(SNIPPET_LANG_BAT, NormalizeSnippetLanguage('Batch'));
    Assert.AreEqual(SNIPPET_LANG_POWERSHELL, NormalizeSnippetLanguage(' ps1 '));
    Assert.AreEqual(SNIPPET_LANG_POWERSHELL, NormalizeSnippetLanguage('PWSH'));
    Assert.AreEqual(SNIPPET_LANG_BASH, NormalizeSnippetLanguage('SH'));
    Assert.AreEqual(SNIPPET_LANG_INI, NormalizeSnippetLanguage('cfg'));
    Assert.AreEqual(SNIPPET_LANG_MARKDOWN, NormalizeSnippetLanguage('MD'));
    Assert.AreEqual(SNIPPET_LANG_JSON, NormalizeSnippetLanguage('JSON'));
    Assert.AreEqual(SNIPPET_LANG_POWERSHELL, NormalizeSnippetLanguage('PowerShell'));
end;

procedure TSnippetLanguagesTests.Normalize_Unknown_AndEmpty_DefaultBash;
begin
    Assert.AreEqual(DEFAULT_SNIPPET_LANGUAGE, NormalizeSnippetLanguage(''));
    Assert.AreEqual(SNIPPET_LANG_BASH, NormalizeSnippetLanguage('kotlin'));
    Assert.AreEqual(SNIPPET_LANG_BASH, NormalizeSnippetLanguage('python'));
end;

procedure TSnippetLanguagesTests.Supported_List_CoversAll;
begin
    Assert.AreEqual(7, Integer(Length(SNIPPET_LANGUAGE_IDS)));
    Assert.AreEqual(SNIPPET_LANG_BASH, SNIPPET_LANGUAGE_IDS[0]);
    Assert.IsTrue(IsSupportedSnippetLanguage(SNIPPET_LANG_MARKDOWN));
    Assert.IsFalse(IsSupportedSnippetLanguage('python'));
end;

procedure TSnippetLanguagesTests.FenceTag_MatchesNormalized;
begin
    Assert.AreEqual(SNIPPET_LANG_BASH, FenceTagForSnippetLanguage(''));
    Assert.AreEqual(SNIPPET_LANG_BAT, FenceTagForSnippetLanguage('cmd'));
    Assert.AreEqual(SNIPPET_LANG_MARKDOWN, FenceTagForSnippetLanguage('md'));
end;

procedure TSnippetLanguagesTests.ShouldRedetect_OnlySubstantialChanges;
var
    Base: string;
begin
    Base := StringOfChar('a', 100);

    Assert.IsFalse(ShouldRedetectSnippetLanguage(Base, Base), 'identical text');
    Assert.IsFalse(ShouldRedetectSnippetLanguage(Base, Base + 'b'), 'one char edit');
    Assert.IsFalse(ShouldRedetectSnippetLanguage(Base, Copy(Base, 1, 95)), 'five chars removed');
    Assert.IsTrue(ShouldRedetectSnippetLanguage(Base, Base + StringOfChar('b', 20)), 'twenty chars added');

    Assert.IsFalse(ShouldRedetectSnippetLanguage('', 'short text'), 'too short to detect');
    Assert.IsTrue(ShouldRedetectSnippetLanguage('', StringOfChar('b', 50)), 'first meaningful block');

    Base := StringOfChar('c', 400);
    Assert.IsFalse(ShouldRedetectSnippetLanguage(Base, Base + StringOfChar('d', 30)), 'below ten percent');
    Assert.IsTrue(ShouldRedetectSnippetLanguage(Base, Base + StringOfChar('d', 40)), 'ten percent reached');
end;

end.
