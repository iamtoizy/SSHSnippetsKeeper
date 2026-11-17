unit Tests.AITextCleaner;

interface

uses
    DUnitX.TestFramework,
    UI.Services.AITextCleaner
    ;

type
    TAITextCleanerTests = class(TObject)
    public
        [Test]
        procedure ExtractPureCode_TakesFencedBlock;

        [Test]
        procedure ExtractOneLine_TakesFirstNonEmpty;

        [Test]
        procedure ExtractOneLine_StripsWrappingQuotes;

        [Test]
        procedure ExtractOneLine_TruncatesToLimit;

        [Test]
        procedure ExtractTagSuggestions_ParsesDelimiters;

        [Test]
        procedure ExtractTagSuggestions_DedupesCaseInsensitive;

        [Test]
        procedure ExtractTagSuggestions_SkipsLongAndCapsCount;

        [Test]
        procedure ExtractTagSuggestions_EmptyInput_NoTags;
    end;

implementation

{ TAITextCleanerTests }

procedure TAITextCleanerTests.ExtractPureCode_TakesFencedBlock;
begin
    Assert.AreEqual('echo hi', TAITextCleaner.ExtractPureCode(
        'Sure!' + sLineBreak + '```bash' + sLineBreak + 'echo hi' +
        sLineBreak + '```' + sLineBreak + 'more text'));
end;

procedure TAITextCleanerTests.ExtractOneLine_TakesFirstNonEmpty;
begin
    Assert.AreEqual('My Title', TAITextCleaner.ExtractOneLine(
        sLineBreak + '   My Title   ' + sLineBreak + 'second line', 0));
end;

procedure TAITextCleanerTests.ExtractOneLine_StripsWrappingQuotes;
begin
    Assert.AreEqual('Заголовок', TAITextCleaner.ExtractOneLine('«Заголовок»', 0));
    Assert.AreEqual('Backup script', TAITextCleaner.ExtractOneLine('"Backup script"', 0));
end;

procedure TAITextCleanerTests.ExtractOneLine_TruncatesToLimit;
begin
    Assert.AreEqual<Integer>(5, Length(TAITextCleaner.ExtractOneLine(
        'abcdefgh', 5)));
end;

procedure TAITextCleanerTests.ExtractTagSuggestions_ParsesDelimiters;
var
    Tags: TArray<string>;
begin
    Tags := TAITextCleaner.ExtractTagSuggestions('linux; bash, backup', 7, 32);
    Assert.AreEqual<Integer>(3, Length(Tags));
    Assert.AreEqual('linux', Tags[0]);
    Assert.AreEqual('bash', Tags[1]);
    Assert.AreEqual('backup', Tags[2]);
end;

procedure TAITextCleanerTests.ExtractTagSuggestions_DedupesCaseInsensitive;
begin
    Assert.AreEqual<Integer>(2, Length(
        TAITextCleaner.ExtractTagSuggestions('API; api; bash', 7, 32)));
end;

procedure TAITextCleanerTests.ExtractTagSuggestions_SkipsLongAndCapsCount;
begin
    Assert.AreEqual<Integer>(1, Length(TAITextCleaner.ExtractTagSuggestions(
        'ok; this-tag-is-way-too-long-for-a-single-tag-value', 7, 32)));
    Assert.AreEqual<Integer>(2, Length(TAITextCleaner.ExtractTagSuggestions(
        'a; b; c; d', 2, 32)));
end;

procedure TAITextCleanerTests.ExtractTagSuggestions_EmptyInput_NoTags;
begin
    Assert.AreEqual<Integer>(0,
        Length(TAITextCleaner.ExtractTagSuggestions('   ', 7, 32)));
end;

end.
