unit Tests.RunCmdCommand;

interface

uses
    DUnitX.TestFramework
    ;

type
    [TestFixture]
    TRunCmdCommandTests = class(TObject)
    public
        [Test]
        procedure Echo_ReturnsOutputAndSuccess;

        [Test]
        procedure AmpersandInQuotedPath_StaysLiteral;

        [Test]
        procedure Timeout_TerminatesAndReturnsFalse;
    end;

implementation

uses
    System.SysUtils,
    System.IOUtils,
    Common.Helpers
    ;

const
    INJECTION_MARKER = 'INJECTED_MARKER_SSK';

procedure TRunCmdCommandTests.Echo_ReturnsOutputAndSuccess;
var
    Output: string;
begin
    Assert.IsTrue(RunCmdCommand('', 'echo hello_world_ssk', Output, 15000));
    Assert.IsTrue(Output.Contains('hello_world_ssk'), 'Output: ' + Output);
end;

procedure TRunCmdCommandTests.AmpersandInQuotedPath_StaysLiteral;
var
    SrcExe, TestDir, FakeExe, Output, Command: string;
begin
    // Путь исполняемого файла содержит & и маркер в имени папки: cmd с
    // /s /c и внешними кавычками обязан сохранить кавычки пути, иначе
    // маркер выполнился бы как отдельная команда
    SrcExe := GetEnvironmentVariable('SystemRoot') + '\System32\whoami.exe';
    Assert.IsTrue(TFile.Exists(SrcExe), 'whoami.exe not found');

    TestDir := TPath.Combine(TPath.GetTempPath, 'ssk_&echo ' + INJECTION_MARKER + '&x');
    FakeExe := TPath.Combine(TestDir, 'whoami.exe');
    TDirectory.CreateDirectory(TestDir);
    try
        TFile.Copy(SrcExe, FakeExe, True);

        Command := '"' + FakeExe + '"';
        Assert.IsTrue(RunCmdCommand('', Command, Output, 15000));
        Assert.IsFalse(Output.Contains(INJECTION_MARKER),
            'Ampersand split the command: ' + Output);
        Assert.IsFalse(Output.Contains('не является'), 'Command failed: ' + Output);
    finally
        TDirectory.Delete(TestDir, True);
    end;
end;

procedure TRunCmdCommandTests.Timeout_TerminatesAndReturnsFalse;
var
    Output: string;
begin
    // 3 пинга идут заметно дольше таймаута - функция должна убить процесс
    // и вернуть False
    Assert.IsFalse(RunCmdCommand('', 'ping -n 3 127.0.0.1', Output, 500));
end;

end.
