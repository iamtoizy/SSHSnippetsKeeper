unit Tests.PunycodeService;

interface

uses
    DUnitX.TestFramework;

type
    [TestFixture]
    TPunycodeServiceTests = class
    public
        [Test]
        procedure BothDirectionsAndRootDot;
        [Test]
        procedure AutoDetectsEachLineAndKeepsErrors;
        [Test]
        procedure RejectsInvalidDomains;
        [Test]
        procedure FormLoadsAndConverts;
    end;

implementation

uses
    PunycodeFormUI,
    PunycodeService,
    System.SysUtils,
    Winapi.Windows;

const
    UnicodeName = #$043F#$0440#$0438#$043C#$0435#$0440'.'#$0440#$0444;
    AsciiName = 'xn--e1afmkfd.xn--p1ai';

procedure TPunycodeServiceTests.BothDirectionsAndRootDot;
var
    Value: string;
begin
    Assert.IsTrue(TryConvertDomain(UnicodeName + #$3002, pmToAscii, Value));
    Assert.AreEqual(AsciiName + '.', Value);
    Assert.IsTrue(TryConvertDomain(UpperCase(AsciiName) + '.', pmToUnicode, Value));
    Assert.AreEqual(UnicodeName + '.', Value);
end;

procedure TPunycodeServiceTests.AutoDetectsEachLineAndKeepsErrors;
var
    Batch: TArray<TPunycodeResult>;
begin
    Batch := ConvertDomains(UnicodeName + #13#10#10'https://example.org'#13 + AsciiName +
        #10'example.org', pmAuto);
    Assert.AreEqual(4, Integer(Length(Batch)));
    Assert.IsTrue(Batch[0].Valid);
    Assert.AreEqual(AsciiName, Batch[0].Value);
    Assert.IsFalse(Batch[1].Valid);
    Assert.AreEqual(3, Batch[1].LineNumber);
    Assert.IsTrue(Batch[2].Valid);
    Assert.AreEqual(UnicodeName, Batch[2].Value);
    Assert.IsTrue(Batch[3].Valid);
    Assert.AreEqual('example.org', Batch[3].Value);
end;

procedure TPunycodeServiceTests.RejectsInvalidDomains;
var
    Value, LongLabel: string;
begin
    LongLabel := StringOfChar('a', 63);
    Assert.IsFalse(TryConvertDomain('www..example', pmAuto, Value));
    Assert.IsFalse(TryConvertDomain('a_b.example', pmAuto, Value));
    Assert.IsFalse(TryConvertDomain('xn--0.example', pmAuto, Value));
    Assert.IsFalse(TryConvertDomain('-example.org', pmAuto, Value));
    Assert.IsFalse(TryConvertDomain(LongLabel + 'a.example', pmAuto, Value));
    Assert.IsFalse(TryConvertDomain(LongLabel + '.' + LongLabel + '.' + LongLabel + '.' +
        LongLabel, pmAuto, Value));
end;

procedure TPunycodeServiceTests.FormLoadsAndConverts;
var
    Form: TPunycodeForm;
    Key: Word;
begin
    Form := TPunycodeForm.Create(nil);
    try
        Form.mInput.Text := UnicodeName + sLineBreak + AsciiName;
        Assert.AreEqual(0, Integer(Form.cbMode.TabOrder));
        Assert.AreEqual(1, Integer(Form.mInput.TabOrder));
        Assert.AreEqual(2, Integer(Form.bCopy.TabOrder));
        Assert.AreEqual(3, Integer(Form.mResult.TabOrder));
        Assert.AreEqual(4, Integer(Form.mErrors.TabOrder));
        Assert.IsTrue(Form.KeyPreview);
        Assert.IsTrue(Form.tmrConvert.Enabled);
        Assert.IsFalse(Form.bCopy.Enabled);
        Form.tmrConvert.OnTimer(Form.tmrConvert);
        Assert.IsFalse(Form.tmrConvert.Enabled);
        Assert.AreEqual(2, Form.mResult.Lines.Count);
        Assert.AreEqual(AsciiName, Form.mResult.Lines[0]);
        Assert.AreEqual(UnicodeName, Form.mResult.Lines[1]);
        Assert.IsTrue(Form.bCopy.Enabled);
        Form.mInput.SelectAll;
        Form.mInput.SelText := '';
        Assert.IsFalse(Form.bCopy.Enabled, 'Editing the input must invalidate the result');
        Assert.IsFalse(Form.tmrConvert.Enabled);
        Key := VK_ESCAPE;
        Form.OnKeyDown(Form, Key, []);
        Assert.AreEqual(0, Integer(Key));
    finally
        Form.Free;
    end;
end;

initialization
    TDUnitX.RegisterTestFixture(TPunycodeServiceTests);

end.
