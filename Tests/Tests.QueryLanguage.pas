unit Tests.QueryLanguage;

interface

uses
    DUnitX.TestFramework,
    Common.QueryLanguage
    ;

type
    [TestFixture]
    TQueryLanguageTests = class(TObject)
    private
        function Join(const Values: TArray<string>): string;
    public
        [Test]
        procedure PlainText_GoesToBareWords;
        [Test]
        procedure FavToken_SetsOnlyFavorites;
        [Test]
        procedure FavInsideWord_NotFlag;
        [Test]
        procedure TagPrefix_CaseInsensitive;
        [Test]
        procedure CatTitleCommentPrefixes_Bucketed;
        [Test]
        procedure ExcludedWords_Collected;
        [Test]
        procedure MixedQuery_AllBuckets;
        [Test]
        procedure EmptyPrefixValue_Ignored;
        [Test]
        procedure UnknownColonPrefix_ToBareWords;
        [Test]
        procedure LoneDash_Ignored;
        [Test]
        procedure WhitespaceOnly_Empty;
        [Test]
        procedure MixedFlags_StructuredDetected;
    end;

implementation

{ TQueryLanguageTests }

function TQueryLanguageTests.Join(const Values: TArray<string>): string;
var
    V: string;
begin
    Result := '';
    for V in Values do
    begin
        if Result <> '' then
            Result := Result + ',';
        Result := Result + V;
    end;
end;

procedure TQueryLanguageTests.PlainText_GoesToBareWords;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('hello world');
    Assert.AreEqual('hello,world', Join(Parsed.BareWords));
    Assert.IsFalse(Parsed.HasStructuredFilters);
    Assert.IsFalse(Parsed.IsEmpty);
    Assert.AreEqual(0, Integer(Length(Parsed.TagValues)));
    Assert.AreEqual(0, Integer(Length(Parsed.ExcludedWords)));
end;

procedure TQueryLanguageTests.FavToken_SetsOnlyFavorites;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('fav');
    Assert.IsTrue(Parsed.OnlyFavorites);
    Assert.IsTrue(Parsed.HasStructuredFilters);
    Assert.IsFalse(Parsed.IsEmpty);
end;

procedure TQueryLanguageTests.FavInsideWord_NotFlag;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('favorite');
    Assert.IsFalse(Parsed.OnlyFavorites);
    Assert.AreEqual('favorite', Join(Parsed.BareWords));
end;

procedure TQueryLanguageTests.TagPrefix_CaseInsensitive;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('TAG:Linux tag:nginx');
    Assert.AreEqual('Linux,nginx', Join(Parsed.TagValues));
    Assert.AreEqual(0, Integer(Length(Parsed.BareWords)));
end;

procedure TQueryLanguageTests.CatTitleCommentPrefixes_Bucketed;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('cat:db title:backup comment:restore');
    Assert.AreEqual('db', Join(Parsed.CategoryValues));
    Assert.AreEqual('backup', Join(Parsed.TitleValues));
    Assert.AreEqual('restore', Join(Parsed.CommentValues));
end;

procedure TQueryLanguageTests.ExcludedWords_Collected;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('-docker -nginx word');
    Assert.AreEqual('docker,nginx', Join(Parsed.ExcludedWords));
    Assert.AreEqual('word', Join(Parsed.BareWords));
end;

procedure TQueryLanguageTests.MixedQuery_AllBuckets;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('tag:sql -test title:users fav');
    Assert.AreEqual('sql', Join(Parsed.TagValues));
    Assert.AreEqual('test', Join(Parsed.ExcludedWords));
    Assert.AreEqual('users', Join(Parsed.TitleValues));
    Assert.IsTrue(Parsed.OnlyFavorites);
    Assert.AreEqual(0, Integer(Length(Parsed.BareWords)));
end;

procedure TQueryLanguageTests.EmptyPrefixValue_Ignored;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('tag:');
    Assert.IsTrue(Parsed.IsEmpty);
end;

procedure TQueryLanguageTests.UnknownColonPrefix_ToBareWords;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('foo:bar');
    Assert.AreEqual('foo:bar', Join(Parsed.BareWords));
end;

procedure TQueryLanguageTests.LoneDash_Ignored;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('-');
    Assert.IsTrue(Parsed.IsEmpty);
end;

procedure TQueryLanguageTests.WhitespaceOnly_Empty;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('   '#9);
    Assert.IsTrue(Parsed.IsEmpty);
end;

procedure TQueryLanguageTests.MixedFlags_StructuredDetected;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('tag:x bare');
    Assert.IsTrue(Parsed.HasStructuredFilters);
    Assert.IsFalse(Parsed.IsEmpty);
    Assert.AreEqual('bare', Join(Parsed.BareWords));
end;

end.
