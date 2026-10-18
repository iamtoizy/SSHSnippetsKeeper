unit Tests.EpochService;

interface

uses
    DUnitX.TestFramework,
    Core.Interfaces.Tools,
    System.Classes,
    EpochService
    ;

type
    [TestFixture]
    TEpochServiceTests = class(TObject)
    private
        function MakeService: TEpochService;
    public
        [Test]
        procedure ParseEpochSeconds;
        [Test]
        procedure ParseEpochMilliseconds;
        [Test]
        procedure ParseEpochMicroseconds;
        [Test]
        procedure ParseEpochWithFractionalPart;
        [Test]
        procedure ParseEpochRejectsGarbage;
        [Test]
        procedure ParseISO8601Zulu;
        [Test]
        procedure ParseApacheZulu;
        [Test]
        procedure ParseApacheWithOffset;
        [Test]
        procedure ParseSyslogReturnsPositive;
        [Test]
        procedure UnixToUTCOfZeroIsUnixEpochDate;
        [Test]
        procedure LocalUnixRoundtrip;
        [Test]
        procedure ExtractFindsISOWithoutEpochFalsePositive;
        [Test]
        procedure ExtractFindsUnixTimestamp;
    end;

implementation

uses
    System.SysUtils
    ;

const
    ISO_TEST = '2023-10-25T14:30:00Z';
    EPOCH_TEST: Int64 = 1698244200;

{ TEpochServiceTests }

function TEpochServiceTests.MakeService: TEpochService;
begin
    Result := TEpochService.Create;
end;

procedure TEpochServiceTests.ParseEpochSeconds;
var
    Svc: TEpochService;
    OutSecs: Int64;
begin
    Svc := MakeService;
    try
        Assert.IsTrue(Svc.ParseToUnixSeconds('1698244200', OutSecs));
        Assert.AreEqual(EPOCH_TEST, OutSecs);
    finally
        Svc.Free;
    end;
end;

procedure TEpochServiceTests.ParseEpochMilliseconds;
var
    Svc: TEpochService;
    OutSecs: Int64;
begin
    Svc := MakeService;
    try
        Assert.IsTrue(Svc.ParseToUnixSeconds('1698244200000', OutSecs));
        Assert.AreEqual(EPOCH_TEST, OutSecs);
    finally
        Svc.Free;
    end;
end;

procedure TEpochServiceTests.ParseEpochMicroseconds;
var
    Svc: TEpochService;
    OutSecs: Int64;
begin
    Svc := MakeService;
    try
        Assert.IsTrue(Svc.ParseToUnixSeconds('1698244200000000', OutSecs));
        Assert.AreEqual(EPOCH_TEST, OutSecs);
    finally
        Svc.Free;
    end;
end;

procedure TEpochServiceTests.ParseEpochWithFractionalPart;
var
    Svc: TEpochService;
    OutSecs: Int64;
begin
    Svc := MakeService;
    try
        Assert.IsTrue(Svc.ParseToUnixSeconds('1698244200.500', OutSecs));
        Assert.AreEqual(EPOCH_TEST, OutSecs);
    finally
        Svc.Free;
    end;
end;

procedure TEpochServiceTests.ParseEpochRejectsGarbage;
var
    Svc: TEpochService;
    OutSecs: Int64;
begin
    Svc := MakeService;
    try
        Assert.IsFalse(Svc.ParseToUnixSeconds('not a timestamp', OutSecs));
        Assert.IsFalse(Svc.ParseToUnixSeconds('202310', OutSecs));
    finally
        Svc.Free;
    end;
end;

procedure TEpochServiceTests.ParseISO8601Zulu;
var
    Svc: TEpochService;
    OutSecs: Int64;
begin
    Svc := MakeService;
    try
        Assert.IsTrue(Svc.ParseToUnixSeconds(ISO_TEST, OutSecs));
        Assert.AreEqual(EPOCH_TEST, OutSecs);
    finally
        Svc.Free;
    end;
end;

procedure TEpochServiceTests.ParseApacheZulu;
var
    Svc: TEpochService;
    OutSecs: Int64;
begin
    Svc := MakeService;
    try
        Assert.IsTrue(Svc.ParseToUnixSeconds('25/Oct/2023:14:30:00 +0000', OutSecs));
        Assert.AreEqual(EPOCH_TEST, OutSecs);
    finally
        Svc.Free;
    end;
end;

procedure TEpochServiceTests.ParseApacheWithOffset;
var
    Svc: TEpochService;
    OutSecs: Int64;
begin
    Svc := MakeService;
    try
        Assert.IsTrue(Svc.ParseToUnixSeconds('25/Oct/2023:14:30:00 +0300', OutSecs));
        Assert.AreEqual(Int64(1698233400), OutSecs);
    finally
        Svc.Free;
    end;
end;

procedure TEpochServiceTests.ParseSyslogReturnsPositive;
var
    Svc: TEpochService;
    OutSecs: Int64;
begin
    Svc := MakeService;
    try
        Assert.IsTrue(Svc.ParseToUnixSeconds('Oct 25 14:30:00', OutSecs));
        Assert.IsTrue(OutSecs > 0);
    finally
        Svc.Free;
    end;
end;

procedure TEpochServiceTests.UnixToUTCOfZeroIsUnixEpochDate;
var
    Svc: TEpochService;
begin
    Svc := MakeService;
    try
        Assert.IsTrue(Abs(Svc.UnixToUTC(0) - 25569.0) < 1e-9);
    finally
        Svc.Free;
    end;
end;

procedure TEpochServiceTests.LocalUnixRoundtrip;
var
    Svc: TEpochService;
begin
    Svc := MakeService;
    try
        Assert.AreEqual(EPOCH_TEST, Svc.LocalToUnix(Svc.UnixToLocal(EPOCH_TEST)));
    finally
        Svc.Free;
    end;
end;

procedure TEpochServiceTests.ExtractFindsISOWithoutEpochFalsePositive;
var
    Svc: TEpochService;
    Lines: TStringList;
    Matches: TArray<TEpochMatch>;
begin
    Svc := MakeService;
    Lines := TStringList.Create;
    try
        Lines.Text := ISO_TEST;
        Matches := Svc.ExtractAllTimestamps(Lines);
        Assert.AreEqual(1, Integer(Length(Matches)));
        Assert.AreEqual(EPOCH_TEST, Matches[0].UnixSeconds);
        Assert.AreEqual(1, Matches[0].LineIdx);
    finally
        Lines.Free;
        Svc.Free;
    end;
end;

procedure TEpochServiceTests.ExtractFindsUnixTimestamp;
var
    Svc: TEpochService;
    Lines: TStringList;
    Matches: TArray<TEpochMatch>;
begin
    Svc := MakeService;
    Lines := TStringList.Create;
    try
        Lines.Text := 'line1' + sLineBreak + '1698244200' + sLineBreak + 'line3';
        Matches := Svc.ExtractAllTimestamps(Lines);
        Assert.AreEqual(1, Integer(Length(Matches)));
        Assert.AreEqual(EPOCH_TEST, Matches[0].UnixSeconds);
        Assert.AreEqual(2, Matches[0].LineIdx);
    finally
        Lines.Free;
        Svc.Free;
    end;
end;

end.
