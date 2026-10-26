unit Tests.CustomBashSyn;

interface

uses
    DUnitX.TestFramework,
    CustomBashSyn,
    SynEdit,
    SynEditTypes
    ;

type
    [TestFixture]
    TCustomBashSynTests = class(TObject)
    public
        [Test]
        procedure IsIdentChar_Latin_True;
        [Test]
        procedure IsIdentChar_Cyrillic_True;
        [Test]
        procedure IsIdentChar_Separators_False;
        [Test]
        procedure Editor_GetWordBoundaries_CyrillicWord;
    end;

implementation

uses
    System.SysUtils
    ;

procedure TCustomBashSynTests.IsIdentChar_Latin_True;
var
    Syn: TCustomBashSyn;
begin
    Syn := TCustomBashSyn.Create(nil);
    try
        Assert.IsTrue(Syn.IsIdentChar('e'));
        Assert.IsTrue(Syn.IsIdentChar('_'));
        Assert.IsTrue(Syn.IsIdentChar('9'));
    finally
        Syn.Free;
    end;
end;

procedure TCustomBashSynTests.IsIdentChar_Cyrillic_True;
var
    Syn: TCustomBashSyn;
begin
    Syn := TCustomBashSyn.Create(nil);
    try
        Assert.IsTrue(Syn.IsIdentChar(Chr($0410)));
        Assert.IsTrue(Syn.IsIdentChar(Chr($0430)));
        Assert.IsTrue(Syn.IsIdentChar(Chr($042F)));
        Assert.IsTrue(Syn.IsIdentChar(Chr($044F)));
        Assert.IsTrue(Syn.IsIdentChar(Chr($0401)));
        Assert.IsTrue(Syn.IsIdentChar(Chr($0451)));
    finally
        Syn.Free;
    end;
end;

procedure TCustomBashSynTests.IsIdentChar_Separators_False;
var
    Syn: TCustomBashSyn;
begin
    Syn := TCustomBashSyn.Create(nil);
    try
        Assert.IsFalse(Syn.IsIdentChar(' '));
        Assert.IsFalse(Syn.IsIdentChar('-'));
        Assert.IsFalse(Syn.IsIdentChar('{'));
        Assert.IsFalse(Syn.IsIdentChar(Chr($2500)));
    finally
        Syn.Free;
    end;
end;

procedure TCustomBashSynTests.Editor_GetWordBoundaries_CyrillicWord;
var
    Syn: TCustomBashSyn;
    Ed: TCustomSynEdit;
    Word: string;
    BB, BE: TBufferCoord;
begin
    Word := Chr($041F) + Chr($0440) + Chr($0438) + Chr($0432) + Chr($0435) + Chr($0442);
    Syn := TCustomBashSyn.Create(nil);
    Ed := TCustomSynEdit.Create(nil);
    try
        Ed.Highlighter := Syn;
        Ed.Lines.Text := 'echo ' + Word;
        Ed.GetWordBoundaries(BufferCoord(7, 1), BB, BE);
        Assert.AreEqual(6, Integer(BB.Char));
        Assert.AreEqual(12, Integer(BE.Char));
        Assert.AreEqual(Word, Copy(Ed.Lines[0], 6, Integer(BE.Char - BB.Char)));
        Ed.GetWordBoundaries(BufferCoord(6, 1), BB, BE);
        Assert.AreEqual(6, Integer(BB.Char));
        Assert.AreEqual(12, Integer(BE.Char));
    finally
        Ed.Free;
        Syn.Free;
    end;
end;

end.
