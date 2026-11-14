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
    Tests.DraftStore in 'Tests.DraftStore.pas',
    Tests.QueryLanguage in 'Tests.QueryLanguage.pas',
    Tests.SearchTags in 'Tests.SearchTags.pas',
    Tests.DbMigrations in 'Tests.DbMigrations.pas',
    Tests.DatabaseEncryption in 'Tests.DatabaseEncryption.pas',
    Tests.WindowMonitor in 'Tests.WindowMonitor.pas',
    Tests.Chains in 'Tests.Chains.pas',
    Tests.SavedQueries in 'Tests.SavedQueries.pas',
    Tests.MarkdownImporter in 'Tests.MarkdownImporter.pas',
    Tests.MultiSelect in 'Tests.MultiSelect.pas',
    Tests.SnippetDuplicate in 'Tests.SnippetDuplicate.pas',
    Tests.SnippetLastRun in 'Tests.SnippetLastRun.pas',
    Tests.AutoBackup in 'Tests.AutoBackup.pas',
    Tests.SecurityReport in 'Tests.SecurityReport.pas',
    Tests.SecurityScanDelta in 'Tests.SecurityScanDelta.pas',
    Tests.CustomBashSyn in 'Tests.CustomBashSyn.pas',
    Tests.MacroInputTypes in 'Tests.MacroInputTypes.pas',
    Tests.SnippetLanguages in 'Tests.SnippetLanguages.pas',
    Tests.SnippetLanguageDetect in 'Tests.SnippetLanguageDetect.pas',
    Tests.SnippetLanguageNB in 'Tests.SnippetLanguageNB.pas',
    Tests.SynHighlighterFactory in 'Tests.SynHighlighterFactory.pas',
    Tests.SynEditRoundTrip in 'Tests.SynEditRoundTrip.pas',
    Tests.DirtyDetection in 'Tests.DirtyDetection.pas',
    Tests.Localization in 'Tests.Localization.pas',
    Tests.MacroThread in 'Tests.MacroThread.pas',
    Tests.RunCmdCommand in 'Tests.RunCmdCommand.pas',
    Tests.Helpers in 'Tests.Helpers.pas',
    Tests.Settings in 'Tests.Settings.pas',
    Tests.DbCrypto in 'Tests.DbCrypto.pas',
    Tests.WindowHelper in 'Tests.WindowHelper.pas',
    Tests.SyncController in 'Tests.SyncController.pas'
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
        TDUnitX.RegisterTestFixture(TDraftStoreTests);
        TDUnitX.RegisterTestFixture(TQueryLanguageTests);
        TDUnitX.RegisterTestFixture(TSearchTagsTests);
        TDUnitX.RegisterTestFixture(TDbMigrationTests);
        TDUnitX.RegisterTestFixture(TDbEncryptionRoundtripTests);
        TDUnitX.RegisterTestFixture(TWindowMonitorTests);
        TDUnitX.RegisterTestFixture(TChainsTests);
        TDUnitX.RegisterTestFixture(TSavedQueriesTests);
        TDUnitX.RegisterTestFixture(TMarkdownImporterTests);
        TDUnitX.RegisterTestFixture(TMultiSelectTests);
        TDUnitX.RegisterTestFixture(TSnippetDuplicateTests);
        TDUnitX.RegisterTestFixture(TSnippetLastRunTests);
        TDUnitX.RegisterTestFixture(TAutoBackupTests);
        TDUnitX.RegisterTestFixture(TSecurityReportTests);
        TDUnitX.RegisterTestFixture(TSecurityScannerEntropyTests);
        TDUnitX.RegisterTestFixture(TSecuritySettingsTests);
        TDUnitX.RegisterTestFixture(TSecurityScanDeltaTests);
        TDUnitX.RegisterTestFixture(TSecurityRangesTests);
        TDUnitX.RegisterTestFixture(TSecurityRealWorldTests);
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
        TDUnitX.RegisterTestFixture(TLocalizationDiagnosticsTests);
        TDUnitX.RegisterTestFixture(TMacroThreadTests);
        TDUnitX.RegisterTestFixture(TRunCmdCommandTests);
        TDUnitX.RegisterTestFixture(THelpersShortenDbPathTests);
        TDUnitX.RegisterTestFixture(TSettingsDpapiTests);
        TDUnitX.RegisterTestFixture(TSettingsManagerTests);
        TDUnitX.RegisterTestFixture(TSettingsDbSecurityTests);
        TDUnitX.RegisterTestFixture(TSettingsRecentDatabasesTests);
        TDUnitX.RegisterTestFixture(TDbCryptoPbkdf2Tests);
        TDUnitX.RegisterTestFixture(TDbCryptoGcmTests);
        TDUnitX.RegisterTestFixture(TDbCryptoKeyFileTests);
        TDUnitX.RegisterTestFixture(TWindowHelperTests);
        TDUnitX.RegisterTestFixture(TSyncControllerTests);
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
