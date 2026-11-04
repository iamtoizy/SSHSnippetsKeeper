unit Tests.CmdLine;

interface

uses
    DUnitX.TestFramework,
    Common.CmdLine
    ;

type
    [TestFixture]
    TCmdLineTests = class(TObject)
    private
        function Parse(const Args: TArray<string>): TCmdLineParams;
    public
        [Test]
        procedure EmptyArgsYieldDefaults;
        [Test]
        procedure DbWithEqualsSign;
        [Test]
        procedure DbWithSpaceSeparatedValue;
        [Test]
        procedure DbWithSlashPrefixAndUpperCase;
        [Test]
        procedure DbKeepsInternalSpaces;
        [Test]
        procedure UserWithEqualsSign;
        [Test]
        procedure AllFlagsCombined;
        [Test]
        procedure HelpAliases;
        [Test]
        procedure NoSyncAndMinimizedAliases;
        [Test]
        procedure NonSwitchArgsIgnored;
        [Test]
        procedure UnknownSwitchIgnored;
        [Test]
        procedure MissingValueTreatedAsEmpty;
        [Test]
        procedure VersionFlag;
        [Test]
        procedure BackupWithoutPath;
        [Test]
        procedure BackupWithPath;
        [Test]
        procedure BackupWithEqualsSign;
        [Test]
        procedure BackupBeforeDbSwitchDoesNotConsume;
        [Test]
        procedure CheckDbFlag;
        [Test]
        procedure NewDbWithValue;
        [Test]
        procedure NewDbMissingValueTreatedAsEmpty;
        [Test]
        procedure HasConsoleCommandDetection;
    end;

implementation

{ TCmdLineTests }

function TCmdLineTests.Parse(const Args: TArray<string>): TCmdLineParams;
begin
    Result := TCmdLineParams.ParseFrom(Args);
end;

procedure TCmdLineTests.EmptyArgsYieldDefaults;
var
    P: TCmdLineParams;
begin
    P := Parse([]);
    Assert.AreEqual('', P.DbPath);
    Assert.AreEqual('', P.UserName);
    Assert.IsFalse(P.NoSync);
    Assert.IsFalse(P.Minimized);
    Assert.IsFalse(P.Help);
end;

procedure TCmdLineTests.DbWithEqualsSign;
var
    P: TCmdLineParams;
begin
    P := Parse(['-db=C:\dir\base.sqlite']);
    Assert.AreEqual('C:\dir\base.sqlite', P.DbPath);
end;

procedure TCmdLineTests.DbWithSpaceSeparatedValue;
var
    P: TCmdLineParams;
begin
    P := Parse(['-db', 'C:\dir\base.sqlite']);
    Assert.AreEqual('C:\dir\base.sqlite', P.DbPath);
end;

procedure TCmdLineTests.DbWithSlashPrefixAndUpperCase;
var
    P: TCmdLineParams;
begin
    P := Parse(['/DB=C:\dir\base.sqlite']);
    Assert.AreEqual('C:\dir\base.sqlite', P.DbPath);
end;

procedure TCmdLineTests.DbKeepsInternalSpaces;
var
    P: TCmdLineParams;
begin
    P := Parse(['-db=C:\My Dir\base.sqlite']);
    Assert.AreEqual('C:\My Dir\base.sqlite', P.DbPath);
end;

procedure TCmdLineTests.UserWithEqualsSign;
var
    P: TCmdLineParams;
begin
    P := Parse(['-user=admin']);
    Assert.AreEqual('admin', P.UserName);
end;

procedure TCmdLineTests.AllFlagsCombined;
var
    P: TCmdLineParams;
begin
    P := Parse(['-db=C:\b.sqlite', '-user=admin', '-nosync', '-minimized']);
    Assert.AreEqual('C:\b.sqlite', P.DbPath);
    Assert.AreEqual('admin', P.UserName);
    Assert.IsTrue(P.NoSync);
    Assert.IsTrue(P.Minimized);
    Assert.IsFalse(P.Help);
end;

procedure TCmdLineTests.HelpAliases;
begin
    Assert.IsTrue(Parse(['-help']).Help);
    Assert.IsTrue(Parse(['/help']).Help);
    Assert.IsTrue(Parse(['-h']).Help);
    Assert.IsTrue(Parse(['-?']).Help);
end;

procedure TCmdLineTests.NoSyncAndMinimizedAliases;
begin
    Assert.IsTrue(Parse(['-no-sync']).NoSync);
    Assert.IsFalse(Parse(['-nosync']).Minimized);
    Assert.IsTrue(Parse(['-min']).Minimized);
    Assert.IsFalse(Parse(['-min']).NoSync);
end;

procedure TCmdLineTests.NonSwitchArgsIgnored;
var
    P: TCmdLineParams;
begin
    P := Parse(['C:\file.txt', 'plainword', '-nosync']);
    Assert.IsTrue(P.NoSync);
    Assert.AreEqual('', P.DbPath);
end;

procedure TCmdLineTests.UnknownSwitchIgnored;
var
    P: TCmdLineParams;
begin
    P := Parse(['-foo=bar', '-nosync']);
    Assert.IsTrue(P.NoSync);
    Assert.AreEqual('', P.DbPath);
end;

procedure TCmdLineTests.MissingValueTreatedAsEmpty;
var
    P: TCmdLineParams;
begin
    P := Parse(['-db', '-nosync']);
    Assert.AreEqual('', P.DbPath);
    Assert.IsTrue(P.NoSync);
end;

procedure TCmdLineTests.VersionFlag;
begin
    Assert.IsTrue(Parse(['-version']).Version);
    Assert.IsTrue(Parse(['/version']).Version);
    Assert.IsFalse(Parse(['-nosync']).Version);
end;

procedure TCmdLineTests.BackupWithoutPath;
var
    P: TCmdLineParams;
begin
    P := Parse(['/backup']);
    Assert.IsTrue(P.Backup);
    Assert.AreEqual('', P.BackupPath);
end;

procedure TCmdLineTests.BackupWithPath;
var
    P: TCmdLineParams;
begin
    P := Parse(['-backup', 'C:\Backups\dump.db']);
    Assert.IsTrue(P.Backup);
    Assert.AreEqual('C:\Backups\dump.db', P.BackupPath);
end;

procedure TCmdLineTests.BackupWithEqualsSign;
var
    P: TCmdLineParams;
begin
    P := Parse(['-backup=D:\copy.bak']);
    Assert.IsTrue(P.Backup);
    Assert.AreEqual('D:\copy.bak', P.BackupPath);
end;

procedure TCmdLineTests.BackupBeforeDbSwitchDoesNotConsume;
var
    P: TCmdLineParams;
begin
    // Следующий токен - ключ, а не путь: BackupPath остаётся пустым
    P := Parse(['/backup', '/db=C:\b.sqlite']);
    Assert.IsTrue(P.Backup);
    Assert.AreEqual('', P.BackupPath);
    Assert.AreEqual('C:\b.sqlite', P.DbPath);
end;

procedure TCmdLineTests.CheckDbFlag;
begin
    Assert.IsTrue(Parse(['-checkdb']).CheckDB);
    Assert.IsTrue(Parse(['/checkdb']).CheckDB);
    Assert.IsFalse(Parse(['-min']).CheckDB);
end;

procedure TCmdLineTests.NewDbWithValue;
var
    P: TCmdLineParams;
begin
    P := Parse(['-newdb', 'C:\New\base.sqlite']);
    Assert.AreEqual('C:\New\base.sqlite', P.NewDB);

    P := Parse(['/newdb=D:\x.sqlite']);
    Assert.AreEqual('D:\x.sqlite', P.NewDB);
end;

procedure TCmdLineTests.NewDbMissingValueTreatedAsEmpty;
var
    P: TCmdLineParams;
begin
    P := Parse(['-newdb', '-checkdb']);
    Assert.AreEqual('', P.NewDB);
    Assert.IsTrue(P.CheckDB);
end;

procedure TCmdLineTests.HasConsoleCommandDetection;
var
    P: TCmdLineParams;
begin
    Assert.IsFalse(Parse(['-nosync', '-minimized']).HasConsoleCommand);
    Assert.IsFalse(Parse(['-db=C:\b.sqlite', '-user=admin']).HasConsoleCommand);

    P := Parse(['-help']);
    Assert.IsTrue(P.HasConsoleCommand);

    P := Parse(['-version']);
    Assert.IsTrue(P.HasConsoleCommand);

    P := Parse(['-newdb', 'C:\x.sqlite']);
    Assert.IsTrue(P.HasConsoleCommand);

    P := Parse(['/migrate']);
    Assert.IsTrue(P.HasConsoleCommand);

    P := Parse(['/backup']);
    Assert.IsTrue(P.HasConsoleCommand);

    P := Parse(['-checkdb']);
    Assert.IsTrue(P.HasConsoleCommand);
end;

end.
