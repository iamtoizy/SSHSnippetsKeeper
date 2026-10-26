program SSHSnippetsKeeperTests;

{$APPTYPE CONSOLE}

uses
    System.SysUtils,
    DUnitX.TestFramework,
    DUnitX.Loggers.Console,
    Tests.EpochService in 'Tests.EpochService.pas',
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
    Tests.Chains in 'Tests.Chains.pas',
    Tests.MultiSelect in 'Tests.MultiSelect.pas',
    Tests.CustomBashSyn in 'Tests.CustomBashSyn.pas',
    Tests.MacroInputTypes in 'Tests.MacroInputTypes.pas'
    ;

var
    Runner: ITestRunner;
    Results: IRunResults;

begin
    try
        TDUnitX.RegisterTestFixture(TEpochServiceTests);
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
        TDUnitX.RegisterTestFixture(TChainsTests);
        TDUnitX.RegisterTestFixture(TMultiSelectTests);
        TDUnitX.RegisterTestFixture(TCustomBashSynTests);
        TDUnitX.RegisterTestFixture(TMacroInputTypesTests);
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
