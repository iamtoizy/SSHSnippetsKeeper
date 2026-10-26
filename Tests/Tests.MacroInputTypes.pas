unit Tests.MacroInputTypes;

interface

uses
    DUnitX.TestFramework,
    MacroInputTypes,
    System.DateUtils,
    System.SysUtils
    ;

type
    [TestFixture]
    TMacroInputTypesTests = class(TObject)
    public
        [Test]
        procedure Float_AcceptsDotAndComma;
        [Test]
        procedure Float_RejectsGarbage;
        [Test]
        procedure Hex_AcceptsPlainAndPrefixed;
        [Test]
        procedure Hex_RejectsBad;
        [Test]
        procedure Number_AndPassword;
        [Test]
        procedure DateTime_AcceptsIsoVariants;
        [Test]
        procedure DateTime_AcceptsLocaleFormats;
        [Test]
        procedure DateTime_RejectsGarbage;
        [Test]
        procedure DateTime_ParseValues;
        [Test]
        procedure Date_AcceptsVariants;
        [Test]
        procedure Time_AcceptsVariants;
        [Test]
        procedure Date_AndTime_ParseValues;
        [Test]
        procedure FreeTypes_AlwaysValid;
    end;

implementation

procedure TMacroInputTypesTests.Float_AcceptsDotAndComma;
begin
    Assert.IsTrue(IsMacroValueValid('1.3', mitFloat));
    Assert.IsTrue(IsMacroValueValid('1,3', mitFloat));
    Assert.IsTrue(IsMacroValueValid('3,14', mitFloat));
    Assert.IsTrue(IsMacroValueValid('-2,5', mitFloat));
end;

procedure TMacroInputTypesTests.Float_RejectsGarbage;
begin
    Assert.IsFalse(IsMacroValueValid('', mitFloat));
    Assert.IsFalse(IsMacroValueValid('abc', mitFloat));
    Assert.IsFalse(IsMacroValueValid('1..2', mitFloat));
end;

procedure TMacroInputTypesTests.Hex_AcceptsPlainAndPrefixed;
begin
    Assert.IsTrue(IsMacroValueValid('FF', mitHex));
    Assert.IsTrue(IsMacroValueValid('0xFF', mitHex));
    Assert.IsTrue(IsMacroValueValid('a1b2', mitHex));
end;

procedure TMacroInputTypesTests.Hex_RejectsBad;
begin
    Assert.IsFalse(IsMacroValueValid('', mitHex));
    Assert.IsFalse(IsMacroValueValid('ZZ', mitHex));
    Assert.IsFalse(IsMacroValueValid('0x', mitHex));
    Assert.IsFalse(IsMacroValueValid('123456789', mitHex));
end;

procedure TMacroInputTypesTests.Number_AndPassword;
begin
    Assert.IsTrue(IsMacroValueValid('100', mitNumber));
    Assert.IsFalse(IsMacroValueValid('1.5', mitNumber));
    Assert.IsFalse(IsMacroValueValid('1,5', mitNumber));
    Assert.IsTrue(IsMacroValueValid('x', mitPassword));
    Assert.IsFalse(IsMacroValueValid('', mitPassword));
end;

procedure TMacroInputTypesTests.DateTime_AcceptsIsoVariants;
begin
    Assert.IsTrue(IsMacroValueValid('2026-10-25', mitDateTime));
    Assert.IsTrue(IsMacroValueValid('2026-10-25 14:30', mitDateTime));
    Assert.IsTrue(IsMacroValueValid('2026-10-25 14:30:59', mitDateTime));
    Assert.IsTrue(IsMacroValueValid('2026-10-25T14:30', mitDateTime));
    Assert.IsTrue(IsMacroValueValid('2026-10-25T14:30:59', mitDateTime));
    Assert.IsTrue(IsMacroValueValid('2026-10-25_14:30', mitDateTime));
    Assert.IsTrue(IsMacroValueValid('2026-10-25_14:30:59', mitDateTime));
end;

procedure TMacroInputTypesTests.DateTime_AcceptsLocaleFormats;
begin
    Assert.IsTrue(IsMacroValueValid(DateToStr(Date), mitDateTime));
    Assert.IsTrue(IsMacroValueValid(DateToStr(Date) + ' ' + TimeToStr(EncodeTime(14, 30, 0, 0)), mitDateTime));
    Assert.IsTrue(IsMacroValueValid(DateToStr(Date) + '_' + TimeToStr(EncodeTime(14, 30, 0, 0)), mitDateTime));
end;

procedure TMacroInputTypesTests.DateTime_RejectsGarbage;
begin
    Assert.IsFalse(IsMacroValueValid('', mitDateTime));
    Assert.IsFalse(IsMacroValueValid('abc', mitDateTime));
    Assert.IsFalse(IsMacroValueValid('2026-13-01', mitDateTime));
    Assert.IsFalse(IsMacroValueValid('2026-10-32', mitDateTime));
    Assert.IsFalse(IsMacroValueValid('24:00', mitDateTime));
    Assert.IsFalse(IsMacroValueValid('2026-10-25 25:00', mitDateTime));
    Assert.IsFalse(IsMacroValueValid('2026_10_25', mitDateTime));
end;

procedure TMacroInputTypesTests.DateTime_ParseValues;
var
    DT: TDateTime;
begin
    Assert.IsTrue(TryParseDateTimeValue('2026-10-25', DT));
    Assert.IsTrue(CompareDateTime(DT, EncodeDate(2026, 10, 25)) = 0);

    Assert.IsTrue(TryParseDateTimeValue('2026-10-25 14:30', DT));
    Assert.IsTrue(CompareDateTime(DT, EncodeDate(2026, 10, 25) + EncodeTime(14, 30, 0, 0)) = 0);

    Assert.IsTrue(TryParseDateTimeValue('2026-10-25_14:30', DT));
    Assert.IsTrue(CompareDateTime(DT, EncodeDate(2026, 10, 25) + EncodeTime(14, 30, 0, 0)) = 0);

    Assert.IsTrue(TryParseDateTimeValue('2026-10-25T14:30:59', DT));
    Assert.IsTrue(CompareDateTime(DT, EncodeDate(2026, 10, 25) + EncodeTime(14, 30, 59, 0)) = 0);
end;

procedure TMacroInputTypesTests.Date_AcceptsVariants;
begin
    Assert.IsTrue(IsMacroValueValid('2026-10-25', mitDate));
    Assert.IsTrue(IsMacroValueValid(DateToStr(Date), mitDate));
    Assert.IsFalse(IsMacroValueValid('2026-10-25 14:30', mitDate));
    Assert.IsFalse(IsMacroValueValid('2026-13-01', mitDate));
    Assert.IsFalse(IsMacroValueValid('', mitDate));
end;

procedure TMacroInputTypesTests.Time_AcceptsVariants;
begin
    Assert.IsTrue(IsMacroValueValid('14:30', mitTime));
    Assert.IsTrue(IsMacroValueValid('14:30:59', mitTime));
    Assert.IsTrue(IsMacroValueValid(TimeToStr(EncodeTime(14, 30, 0, 0)), mitTime));
    Assert.IsFalse(IsMacroValueValid('2026-10-25', mitTime));
    Assert.IsFalse(IsMacroValueValid('24:00', mitTime));
    Assert.IsFalse(IsMacroValueValid('25:00', mitTime));
    Assert.IsFalse(IsMacroValueValid('', mitTime));
end;

procedure TMacroInputTypesTests.Date_AndTime_ParseValues;
var
    DT: TDateTime;
begin
    Assert.IsTrue(TryParseDateValue('2026-10-25', DT));
    Assert.IsTrue(CompareDateTime(DT, EncodeDate(2026, 10, 25)) = 0);

    Assert.IsTrue(TryParseTimeValue('14:30', DT));
    Assert.IsTrue(CompareDateTime(DT, EncodeTime(14, 30, 0, 0)) = 0);

    Assert.IsTrue(TryParseTimeValue('14:30:59', DT));
    Assert.IsTrue(CompareDateTime(DT, EncodeTime(14, 30, 59, 0)) = 0);
end;

procedure TMacroInputTypesTests.FreeTypes_AlwaysValid;
begin
    Assert.IsTrue(IsMacroValueValid('any text', mitString));
    Assert.IsTrue(IsMacroValueValid('', mitString));
    Assert.IsTrue(IsMacroValueValid('', mitConfirm));
    Assert.IsTrue(IsMacroValueValid('a|b|c', mitSelect));
end;

end.
