program SSHSnippetsKeeperTests;

{$APPTYPE CONSOLE}

uses
    System.SysUtils,
    DUnitX.TestFramework,
    DUnitX.Loggers.Console,
    Tests.EpochService in 'Tests.EpochService.pas',
    Tests.PasswordService in 'Tests.PasswordService.pas',
    Tests.MacroEngine in 'Tests.MacroEngine.pas',
    Tests.HotkeyService in 'Tests.HotkeyService.pas'
    ;

var
    Runner: ITestRunner;
    Results: IRunResults;

begin
    try
        TDUnitX.RegisterTestFixture(TEpochServiceTests);
        TDUnitX.RegisterTestFixture(TPasswordServiceTests);
        TDUnitX.RegisterTestFixture(TMacroEngineTests);
        TDUnitX.RegisterTestFixture(THotkeyServiceTests);
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
