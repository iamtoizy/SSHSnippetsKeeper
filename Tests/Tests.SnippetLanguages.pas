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
    end;

implementation

uses
    Common.Consts
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

end.
