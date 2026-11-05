program SSHSnippetsKeeperTests;

{$APPTYPE CONSOLE}

uses
    System.SysUtils,
    DUnitX.TestFramework,
    DUnitX.Loggers.Console,
    Tests.EpochService in 'Tests.EpochService.pas',
    Tests.CmdLine in 'Tests.CmdLine.pas',
    Tests.PasswordService in 'Tests.PasswordService.pas',
    Tests.MacroEngine in 'Tests.MacroEngine.pas',
    Tests.MacroCounters in 'Tests.MacroCounters.pas',
    Tests.MacroBuilder in 'Tests.MacroBuilder.pas',
    Tests.MacroSyn in 'Tests.MacroSyn.pas',
    Tests.MacroCardController in 'Tests.MacroCardController.pas',
    Tests.HotkeyService in 'Tests.HotkeyService.pas',
    Tests.TextDiff in 'Tests.TextDiff.pas',
    Tests.QueryLanguage in 'Tests.QueryLanguage.pas',
    Tests.SearchTags in 'Tests.SearchTags.pas',
    Tests.DbMigrations in 'Tests.DbMigrations.pas',
    Tests.WindowMonitor in 'Tests.WindowMonitor.pas',
    Tests.Chains in 'Tests.Chains.pas',
    Tests.MarkdownImporter in 'Tests.MarkdownImporter.pas',
    Tests.MultiSelect in 'Tests.MultiSelect.pas',
    Tests.SnippetDuplicate in 'Tests.SnippetDuplicate.pas',
    Tests.SnippetLastRun in 'Tests.SnippetLastRun.pas',
    Tests.AutoBackup in 'Tests.AutoBackup.pas',
    Tests.SecurityReport in 'Tests.SecurityReport.pas',
    Tests.CustomBashSyn in 'Tests.CustomBashSyn.pas',
    Tests.MacroInputTypes in 'Tests.MacroInputTypes.pas',
    Tests.SnippetLanguages in 'Tests.SnippetLanguages.pas',
    Tests.SnippetLanguageDetect in 'Tests.SnippetLanguageDetect.pas',
    Tests.SnippetLanguageNB in 'Tests.SnippetLanguageNB.pas',
    Tests.SynHighlighterFactory in 'Tests.SynHighlighterFactory.pas',
    Tests.SynEditRoundTrip in 'Tests.SynEditRoundTrip.pas',
    Tests.DirtyDetection in 'Tests.DirtyDetection.pas'
    ;

var
    Runner: ITestRunner;
    Results: IRunResults;

begin
    try
        TDUnitX.RegisterTestFixture(TEpochServiceTests);
        TDUnitX.RegisterTestFixture(TCmdLineTests);
        TDUnitX.RegisterTestFixture(TPasswordServiceTests);
        TDUnitX.RegisterTestFixture(TMacroEngineTests);
        TDUnitX.RegisterTestFixture(TMacroCountersTests);
        TDUnitX.RegisterTestFixture(TMacroBuilderTests);
        TDUnitX.RegisterTestFixture(TMacroSynTests);
        TDUnitX.RegisterTestFixture(TMacroCardControllerTests);
        TDUnitX.RegisterTestFixture(THotkeyServiceTests);
        TDUnitX.RegisterTestFixture(TTextDiffTests);
        TDUnitX.RegisterTestFixture(TQueryLanguageTests);
        TDUnitX.RegisterTestFixture(TSearchTagsTests);
        TDUnitX.RegisterTestFixture(TDbMigrationTests);
        TDUnitX.RegisterTestFixture(TWindowMonitorTests);
        TDUnitX.RegisterTestFixture(TChainsTests);
        TDUnitX.RegisterTestFixture(TMarkdownImporterTests);
        TDUnitX.RegisterTestFixture(TMultiSelectTests);
        TDUnitX.RegisterTestFixture(TSnippetDuplicateTests);
        TDUnitX.RegisterTestFixture(TSnippetLastRunTests);
        TDUnitX.RegisterTestFixture(TAutoBackupTests);
        TDUnitX.RegisterTestFixture(TSecurityReportTests);
        TDUnitX.RegisterTestFixture(TCustomBashSynTests);
        TDUnitX.RegisterTestFixture(TMacroInputTypesTests);
        TDUnitX.RegisterTestFixture(TSnippetLanguagesTests);
        TDUnitX.RegisterTestFixture(TSnippetLanguageDetectTests);
        TDUnitX.RegisterTestFixture(TSnippetLanguageNBTests);
        TDUnitX.RegisterTestFixture(TSynHighlighterFactoryTests);
        TDUnitX.RegisterTestFixture(TSynEditRoundTripTests);
        TDUnitX.RegisterTestFixture(TDirtyDetectionTests);
        TDUnitX.RegisterTestFixture(TMacroBodySynTests);
        TDUnitX.RegisterTestFixture(TMacroSchemeRegexTests);
        Runner := TDUnitX.CreateRunner([TDUnitXConsoleLogger.Create(False)]);
        Runner.UseRTTI := True;
        Results := Runner.Execute;
        if not Results.AllPassed then
            ExitCode := 1;
    except
        on E: Exception do
        begin
            Writeln(E.ClassName, ': ', E.Message);
            ExitCode := 2;
        end;
    end;
end.
