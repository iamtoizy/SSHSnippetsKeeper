unit Tests.ArrayRecord;

// Золотые тесты TArrayRecord<T> (docs\ArrayHelper.SPEC.md).
// Фикстуры сняты эмпирической пробой со старого ThirdParty\ArrayHelper.pas
// 2026-11-21 (docs\ArrayHelper.FIXTURES.txt); замена не должна их ломать.

interface

uses
    DUnitX.TestFramework,
    Common.ArrayRecord
    ;

type
    [TestFixture]
    TArrayRecordTests = class(TObject)
    private type
        TProbeRec = record
            Name: string;
            Value: Integer;
        end;
    public
        [Test]
        procedure Default_IsEmpty;
        [Test]
        procedure Create_Capacity_SetsCountAndDefaults;
        [Test]
        procedure Create_Values_CopiesArray;
        [Test]
        procedure Add_ReturnsIndexAndAppends;
        [Test]
        procedure SetCount_Grow_DefaultsNewItems;
        [Test]
        procedure SetCount_Shrink_TruncatesTail;
        [Test]
        procedure SetCount_Negative_RaisesRangeError;
        [Test]
        procedure ItemAt_ReadWrite;
        [Test]
        procedure ItemAt_ReadOutOfRange_ReturnsDefaultSilently;
        [Test]
        procedure Insert_Middle_ShiftsTail;
        [Test]
        procedure Insert_HeadTail;
        [Test]
        procedure Insert_Negative_Raises;
        [Test]
        procedure Insert_BeyondCount_Raises;
        [Test]
        procedure Delete_Middle_ShiftsTail;
        [Test]
        procedure Delete_Negative_Raises;
        [Test]
        procedure Delete_AtCount_Raises;
        [Test]
        procedure Delete_Strings_NoLeaksNoCorruption;
        [Test]
        procedure IndexOf_CaseSensitive;
        [Test]
        procedure Contains;
        [Test]
        procedure Remove_FirstOccurrenceOnly;
        [Test]
        procedure Remove_Missing_ReturnsFalse;
        [Test]
        procedure AddIfNotContains;
        [Test]
        procedure Clear_NilsItems;
        [Test]
        procedure ForIn_OrderAndCompleteness;
        [Test]
        procedure RecordItems_RefcountSafe;
        [Test]
        procedure RttiView_SinglePublicField_Items;
    end;

implementation

uses
    System.SysUtils,
    System.Rtti,
    System.TypInfo
    ;

procedure TArrayRecordTests.Default_IsEmpty;
var
    A: TArrayRecord<string>;
begin
    A := Default(TArrayRecord<string>);
    Assert.AreEqual(Integer(0), A.Count);
    Assert.AreEqual(Integer(0), Integer(Length(A.Items)));
    Assert.IsTrue(A.Items = nil);
end;

procedure TArrayRecordTests.Create_Capacity_SetsCountAndDefaults;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(5);
    Assert.AreEqual(Integer(5), A.Count);
    Assert.AreEqual(Integer(5), Integer(Length(A.Items)));
    Assert.AreEqual('', A[0]);
    Assert.AreEqual('', A[4]);
end;

procedure TArrayRecordTests.Create_Values_CopiesArray;
var
    A: TArrayRecord<string>;
    Src: TArray<string>;
begin
    Src := TArray<string>.Create('a', 'b', 'c');
    A := TArrayRecord<string>.Create(Src);
    Assert.AreEqual(Integer(3), A.Count);
    Assert.AreEqual('a', A[0]);
    Assert.AreEqual('b', A[1]);
    Assert.AreEqual('c', A[2]);
    // Независимость от исходного массива
    Src[0] := 'changed';
    Assert.AreEqual('a', A[0]);
end;

procedure TArrayRecordTests.Add_ReturnsIndexAndAppends;
var
    A: TArrayRecord<string>;
begin
    A := Default(TArrayRecord<string>);
    Assert.AreEqual(Integer(0), A.Add('x1'));
    Assert.AreEqual(Integer(1), A.Add('x2'));
    Assert.AreEqual(Integer(2), A.Count);
    Assert.AreEqual('x1', A[0]);
    Assert.AreEqual('x2', A[1]);
end;

procedure TArrayRecordTests.SetCount_Grow_DefaultsNewItems;
var
    A: TArrayRecord<string>;
begin
    A := Default(TArrayRecord<string>);
    A.Count := 3;
    Assert.AreEqual(Integer(3), Integer(Length(A.Items)));
    Assert.AreEqual('', A[0]);
    Assert.AreEqual('', A[2]);
end;

procedure TArrayRecordTests.SetCount_Shrink_TruncatesTail;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a', 'b', 'c', 'd']);
    A.Count := 2;
    Assert.AreEqual(Integer(2), A.Count);
    Assert.AreEqual('a', A[0]);
    Assert.AreEqual('b', A[1]);
end;

procedure TArrayRecordTests.SetCount_Negative_RaisesRangeError;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a', 'b']);
    Assert.WillRaise(
        procedure
        begin
            A.Count := -5;
        end,
        ERangeError);
end;

procedure TArrayRecordTests.ItemAt_ReadWrite;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['k0', 'k1', 'k2']);
    Assert.AreEqual('k1', A[1]);
    A[1] := 'changed';
    Assert.AreEqual('changed', A[1]);
    Assert.AreEqual('k0', A[0]);
    Assert.AreEqual('k2', A[2]);
end;

procedure TArrayRecordTests.ItemAt_ReadOutOfRange_ReturnsDefaultSilently;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a']);
    Assert.AreEqual('', A[5]);
end;

procedure TArrayRecordTests.Insert_Middle_ShiftsTail;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a', 'b']);
    A.Insert(1, 'mid');
    Assert.AreEqual(Integer(3), A.Count);
    Assert.AreEqual('a', A[0]);
    Assert.AreEqual('mid', A[1]);
    Assert.AreEqual('b', A[2]);
end;

procedure TArrayRecordTests.Insert_HeadTail;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a', 'b']);
    A.Insert(0, 'head');
    A.Insert(A.Count, 'tail');
    Assert.AreEqual(Integer(4), A.Count);
    Assert.AreEqual('head', A[0]);
    Assert.AreEqual('a', A[1]);
    Assert.AreEqual('b', A[2]);
    Assert.AreEqual('tail', A[3]);
end;

procedure TArrayRecordTests.Insert_Negative_Raises;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a', 'b']);
    Assert.WillRaise(
        procedure
        begin
            A.Insert(-1, 'X');
        end,
        EArgumentOutOfRangeException);
    Assert.AreEqual(Integer(2), A.Count);
end;

procedure TArrayRecordTests.Insert_BeyondCount_Raises;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a', 'b']);
    Assert.WillRaise(
        procedure
        begin
            A.Insert(999, 'X');
        end,
        EArgumentOutOfRangeException);
    Assert.AreEqual(Integer(2), A.Count);
end;

procedure TArrayRecordTests.Delete_Middle_ShiftsTail;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a', 'b', 'c']);
    A.Delete(1);
    Assert.AreEqual(Integer(2), A.Count);
    Assert.AreEqual('a', A[0]);
    Assert.AreEqual('c', A[1]);
end;

procedure TArrayRecordTests.Delete_Negative_Raises;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a', 'b', 'c']);
    Assert.WillRaise(
        procedure
        begin
            A.Delete(-1);
        end,
        EArgumentOutOfRangeException);
    Assert.AreEqual(Integer(3), A.Count);
end;

procedure TArrayRecordTests.Delete_AtCount_Raises;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a', 'b', 'c']);
    Assert.WillRaise(
        procedure
        begin
            A.Delete(999);
        end,
        EArgumentOutOfRangeException);
    Assert.AreEqual(Integer(3), A.Count);
end;

procedure TArrayRecordTests.Delete_Strings_NoLeaksNoCorruption;
var
    A: TArrayRecord<string>;
    I: Integer;
begin
    // Refcount-безопасность сдвига: строки не теряются и не дублируются
    A := TArrayRecord<string>.Create(['alpha', 'beta', 'gamma', 'delta']);
    A.Delete(0);
    A.Delete(1);
    Assert.AreEqual(Integer(2), A.Count);
    Assert.AreEqual('beta', A[0]);
    Assert.AreEqual('delta', A[1]);
    for I := 0 to A.Count - 1 do
        Assert.IsTrue(Length(A[I]) > 0);
end;

procedure TArrayRecordTests.IndexOf_CaseSensitive;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['alpha', 'beta', 'gamma']);
    Assert.AreEqual(Integer(1), A.IndexOf('beta'));
    Assert.AreEqual(Integer(-1), A.IndexOf('nope'));
    Assert.AreEqual(Integer(-1), A.IndexOf('BETA'));
end;

procedure TArrayRecordTests.Contains;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['alpha', 'beta', 'gamma']);
    Assert.IsTrue(A.Contains('beta'));
    Assert.IsFalse(A.Contains('nope'));
end;

procedure TArrayRecordTests.Remove_FirstOccurrenceOnly;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a', 'b', 'a', 'c']);
    Assert.IsTrue(A.Remove('a'));
    Assert.AreEqual(Integer(3), A.Count);
    Assert.AreEqual('b', A[0]);
    Assert.AreEqual('a', A[1]);
    Assert.AreEqual('c', A[2]);
end;

procedure TArrayRecordTests.Remove_Missing_ReturnsFalse;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a', 'b']);
    Assert.IsFalse(A.Remove('zzz'));
    Assert.AreEqual(Integer(2), A.Count);
end;

procedure TArrayRecordTests.AddIfNotContains;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a', 'b']);
    Assert.IsFalse(A.AddIfNotContains('a'));
    Assert.AreEqual(Integer(2), A.Count);
    Assert.IsTrue(A.AddIfNotContains('c'));
    Assert.AreEqual(Integer(3), A.Count);
    Assert.AreEqual('c', A[2]);
end;

procedure TArrayRecordTests.Clear_NilsItems;
var
    A: TArrayRecord<string>;
begin
    A := TArrayRecord<string>.Create(['a', 'b']);
    A.Clear;
    Assert.AreEqual(Integer(0), A.Count);
    Assert.IsTrue(A.Items = nil);
end;

procedure TArrayRecordTests.ForIn_OrderAndCompleteness;
var
    A: TArrayRecord<string>;
    S: string;
    Acc: string;
begin
    A := TArrayRecord<string>.Create(['one', 'two', 'three']);
    Acc := '';
    for S in A do
        Acc := Acc + S + ';';
    Assert.AreEqual('one;two;three;', Acc);
end;

procedure TArrayRecordTests.RecordItems_RefcountSafe;
var
    A: TArrayRecord<TProbeRec>;
    R: TProbeRec;
begin
    R.Name := 'n1';
    R.Value := 1;
    A.Add(R);
    R.Name := 'n2';
    R.Value := 2;
    A.Add(R);
    Assert.AreEqual(Integer(2), A.Count);
    A.Delete(0);
    Assert.AreEqual(Integer(1), A.Count);
    Assert.AreEqual('n2', A[0].Name);
    Assert.AreEqual(Integer(2), A[0].Value);
end;

procedure TArrayRecordTests.RttiView_SinglePublicField_Items;
var
    Ctx: TRttiContext;
    RttiType: TRttiType;
begin
    // Контрактообразующий факт: RTTI записи видит ровно один declared
    // field (Items); JSON-сериализатор настроек зависит от этой формы
    Ctx := TRttiContext.Create;
    RttiType := Ctx.GetType(TypeInfo(TArrayRecord<string>));
    Assert.AreEqual(Integer(1), Integer(Length(RttiType.GetDeclaredFields)));
    Assert.AreEqual('Items', RttiType.GetDeclaredFields[0].Name);
    Assert.AreEqual(Integer(0), Integer(Length(RttiType.GetDeclaredProperties)));
end;

initialization
    TDUnitX.RegisterTestFixture(TArrayRecordTests);

end.
