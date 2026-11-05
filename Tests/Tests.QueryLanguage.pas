unit Tests.QueryLanguage;

interface

uses
    DUnitX.TestFramework,
    System.DateUtils,
    System.SysUtils,
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
        [Test]
        procedure LangPrefix_Bucketed_AnyMatch;
        [Test]
        procedure ContentPrefix_WordAndPhrase;
        [Test]
        procedure QuotedPrefixValues_PhraseBuckets;
        [Test]
        procedure TagQuoted_ValueWithSpaces;
        [Test]
        procedure BareQuoted_Phrase;
        [Test]
        procedure ExcludedQuoted_Phrase;
        [Test]
        procedure DashFav_SetsExcludeFavorites;
        [Test]
        procedure DateFilters_OperatorsAndBounds;
        [Test]
        procedure DateFilters_QuotedDatetimeAndTForm;
        [Test]
        procedure DateFilters_Invalid_Ignored;
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

procedure TQueryLanguageTests.LangPrefix_Bucketed_AnyMatch;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('LANG:Python lang:sh');
    Assert.AreEqual('Python,sh', Join(Parsed.LanguageValues));
    Assert.IsTrue(Parsed.HasStructuredFilters);
    Assert.AreEqual(0, Integer(Length(Parsed.BareWords)));
end;

procedure TQueryLanguageTests.ContentPrefix_WordAndPhrase;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('content:systemctl content:"compose up"');
    Assert.AreEqual('systemctl', Join(Parsed.ContentValues));
    Assert.AreEqual('compose up', Join(Parsed.ContentPhrases));
    Assert.IsTrue(Parsed.HasStructuredFilters);
end;

procedure TQueryLanguageTests.QuotedPrefixValues_PhraseBuckets;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse(
        'title:"nginx config" comment:"step 1" content:"docker compose up" title:plain');
    Assert.AreEqual('nginx config', Join(Parsed.TitlePhrases));
    Assert.AreEqual('step 1', Join(Parsed.CommentPhrases));
    Assert.AreEqual('docker compose up', Join(Parsed.ContentPhrases));
    Assert.AreEqual('plain', Join(Parsed.TitleValues));
    Assert.AreEqual(0, Integer(Length(Parsed.BareWords)));
end;

procedure TQueryLanguageTests.TagQuoted_ValueWithSpaces;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('tag:"deploy prod"');
    Assert.AreEqual('deploy prod', Join(Parsed.TagValues));
    Assert.IsTrue(Parsed.HasStructuredFilters);
    Assert.IsFalse(Parsed.IsEmpty);
end;

procedure TQueryLanguageTests.BareQuoted_Phrase;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('"deploy to prod"');
    Assert.AreEqual('deploy to prod', Join(Parsed.BarePhrases));
    Assert.AreEqual(0, Integer(Length(Parsed.BareWords)));
    Assert.IsTrue(Parsed.HasStructuredFilters);
    Assert.IsFalse(Parsed.IsEmpty);
end;

procedure TQueryLanguageTests.ExcludedQuoted_Phrase;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('-"docker ps" word');
    Assert.AreEqual('docker ps', Join(Parsed.ExcludedPhrases));
    Assert.AreEqual(0, Integer(Length(Parsed.ExcludedWords)));
    Assert.AreEqual('word', Join(Parsed.BareWords));
end;

procedure TQueryLanguageTests.DashFav_SetsExcludeFavorites;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('-fav');
    Assert.IsTrue(Parsed.ExcludeFavorites);
    Assert.IsFalse(Parsed.OnlyFavorites);
    Assert.IsTrue(Parsed.HasStructuredFilters);
    Assert.AreEqual(0, Integer(Length(Parsed.ExcludedWords)));

    Parsed := TQueryLanguageParser.Parse('x -FAV');
    Assert.IsTrue(Parsed.ExcludeFavorites);
    Assert.AreEqual('x', Join(Parsed.BareWords));
end;

procedure TQueryLanguageTests.DateFilters_OperatorsAndBounds;
var
    Parsed: TStructuredQuery;
    DF: TQueryDateFilter;
begin
    Parsed := TQueryLanguageParser.Parse('created:>2025-01-01 updated:<=2024-06 created:2025-11-05');
    Assert.AreEqual(3, Integer(Length(Parsed.DateFilters)));

    DF := Parsed.DateFilters[0];
    Assert.IsTrue(DF.Field = qdfCreated);
    Assert.IsTrue(DF.Op = qdoGreater);
    Assert.AreEqual(DateTimeToUnix(EncodeDate(2025, 1, 1), False), DF.EpochFrom);
    Assert.AreEqual(DateTimeToUnix(EncodeDate(2025, 1, 2), False), DF.EpochTo);

    DF := Parsed.DateFilters[1];
    Assert.IsTrue(DF.Field = qdfUpdated);
    Assert.IsTrue(DF.Op = qdoLessEqual);
    Assert.AreEqual(DateTimeToUnix(EncodeDate(2024, 6, 1), False), DF.EpochFrom);
    Assert.AreEqual(DateTimeToUnix(EncodeDate(2024, 7, 1), False), DF.EpochTo);

    DF := Parsed.DateFilters[2];
    Assert.IsTrue(DF.Field = qdfCreated);
    Assert.IsTrue(DF.Op = qdoEqual);
    Assert.AreEqual(DateTimeToUnix(EncodeDate(2025, 11, 5), False), DF.EpochFrom);
    Assert.AreEqual(DateTimeToUnix(EncodeDate(2025, 11, 5), False) + 86400, DF.EpochTo);
end;

procedure TQueryLanguageTests.DateFilters_QuotedDatetimeAndTForm;
var
    Parsed: TStructuredQuery;
    DF: TQueryDateFilter;
    Base: Int64;
begin
    Parsed := TQueryLanguageParser.Parse('created:"2025-11-05 10:30"');
    Assert.AreEqual(1, Integer(Length(Parsed.DateFilters)));
    DF := Parsed.DateFilters[0];
    Base := DateTimeToUnix(EncodeDate(2025, 11, 5) + EncodeTime(10, 30, 0, 0), False);
    Assert.IsTrue(DF.Op = qdoEqual);
    Assert.AreEqual(Base, DF.EpochFrom);
    Assert.AreEqual(Base + 60, DF.EpochTo);

    Parsed := TQueryLanguageParser.Parse('updated:2025-11-05T22:00');
    Assert.AreEqual(1, Integer(Length(Parsed.DateFilters)));
    DF := Parsed.DateFilters[0];
    Base := DateTimeToUnix(EncodeDate(2025, 11, 5) + EncodeTime(22, 0, 0, 0), False);
    Assert.AreEqual(Base, DF.EpochFrom);
    Assert.AreEqual(Base + 60, DF.EpochTo);
end;

procedure TQueryLanguageTests.DateFilters_Invalid_Ignored;
var
    Parsed: TStructuredQuery;
begin
    Parsed := TQueryLanguageParser.Parse('created:abc updated:2025-13-40 created:>=nope "ok phrase"');
    Assert.AreEqual(0, Integer(Length(Parsed.DateFilters)));
    Assert.AreEqual('ok phrase', Join(Parsed.BarePhrases));
    Assert.IsFalse(Parsed.IsEmpty);
end;

end.
