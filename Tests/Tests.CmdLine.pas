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

end.
