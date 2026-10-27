unit Tests.SynHighlighterFactory;

interface

uses
    DUnitX.TestFramework,
    Common.SnippetLanguages,
    SynEditHighlighter,
    SynHighlighterFactory
    ;

type
    [TestFixture]
    TSynHighlighterFactoryTests = class(TObject)
    public
        [Test]
        procedure Create_ReturnsClassPerLanguage;
        [Test]
        procedure Create_Unknown_FallsBackToBash;
        [Test]
        procedure DisplayName_NonEmpty_ForAllLanguages;
    end;

implementation

uses
    CustomBashSyn,
    SynHighlighterBat,
    SynHighlighterIni,
    SynHighlighterJSON,
    SynHighlighterMarkdown,
    SynHighlighterPowerShell,
    SynHighlighterXML,
    System.SysUtils
    ;

{ TSynHighlighterFactoryTests }

procedure TSynHighlighterFactoryTests.Create_ReturnsClassPerLanguage;
var
    HL: TSynCustomHighlighter;
begin
    HL := TSynHighlighterFactory.CreateHighlighter(SNIPPET_LANG_BASH);
    try
        Assert.IsTrue(HL is TCustomBashSyn);
    finally
        HL.Free;
    end;

    HL := TSynHighlighterFactory.CreateHighlighter('cmd');
    try
        Assert.IsTrue(HL is TSynBatSyn);
    finally
        HL.Free;
    end;

    HL := TSynHighlighterFactory.CreateHighlighter('powershell');
    try
        Assert.IsTrue(HL is TSynPowerShellSyn);
    finally
        HL.Free;
    end;

    HL := TSynHighlighterFactory.CreateHighlighter('xml');
    try
        Assert.IsTrue(HL is TSynXMLSyn);
    finally
        HL.Free;
    end;

    HL := TSynHighlighterFactory.CreateHighlighter('json');
    try
        Assert.IsTrue(HL is TSynJSONSyn);
    finally
        HL.Free;
    end;

    HL := TSynHighlighterFactory.CreateHighlighter('ini');
    try
        Assert.IsTrue(HL is TSynIniSyn);
    finally
        HL.Free;
    end;

    HL := TSynHighlighterFactory.CreateHighlighter('md');
    try
        Assert.IsTrue(HL is TSynMarkdownSyn);
    finally
        HL.Free;
    end;
end;

procedure TSynHighlighterFactoryTests.Create_Unknown_FallsBackToBash;
var
    HL: TSynCustomHighlighter;
begin
    HL := TSynHighlighterFactory.CreateHighlighter('kotlin');
    try
        Assert.IsTrue(HL is TCustomBashSyn);
    finally
        HL.Free;
    end;

    HL := TSynHighlighterFactory.CreateHighlighter('');
    try
        Assert.IsTrue(HL is TCustomBashSyn);
    finally
        HL.Free;
    end;
end;

procedure TSynHighlighterFactoryTests.DisplayName_NonEmpty_ForAllLanguages;
var
    Id: string;
begin
    for Id in SNIPPET_LANGUAGE_IDS do
        Assert.IsNotEmpty(TSynHighlighterFactory.DisplayName(Id));

    Assert.AreEqual('Batch (cmd)', TSynHighlighterFactory.DisplayName('CMD'));
end;

end.
