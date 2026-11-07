unit Tests.SecurityScanDelta;

interface

uses
    DUnitX.TestFramework,
    SecurityScanDelta
    ;

type
    [TestFixture]
    TSecurityScanDeltaTests = class(TObject)
    public
        [Test]
        procedure ComputeNewIDs_EmptyPrevious_AllCurrentAreNew;
        [Test]
        procedure ComputeNewIDs_EmptyCurrent_ResultEmpty;
        [Test]
        procedure ComputeNewIDs_Overlap_OnlyNewReturned;
        [Test]
        procedure ComputeNewIDs_DuplicatesInCurrent_ReturnedOnce;
        [Test]
        procedure ComputeNewIDs_BothEmpty_ResultEmpty;
        [Test]
        procedure MessageKey_Russian_PluralForms;
        [Test]
        procedure MessageKey_Russian_TeenExceptions;
        [Test]
        procedure MessageKey_English_OneOrMany;
        [Test]
        procedure MessageKey_LanguageCaseInsensitive;
    end;

implementation

{ TSecurityScanDeltaTests }

procedure TSecurityScanDeltaTests.ComputeNewIDs_EmptyPrevious_AllCurrentAreNew;
var
    NewIDs: TArray<Integer>;
begin
    NewIDs := ComputeNewIDs([3, 7, 9], []);

    Assert.AreEqual(3, Integer(Length(NewIDs)));
    Assert.AreEqual(3, NewIDs[0]);
    Assert.AreEqual(7, NewIDs[1]);
    Assert.AreEqual(9, NewIDs[2]);
end;

procedure TSecurityScanDeltaTests.ComputeNewIDs_EmptyCurrent_ResultEmpty;
var
    NewIDs: TArray<Integer>;
begin
    NewIDs := ComputeNewIDs([], [1, 2, 3]);

    Assert.AreEqual(0, Integer(Length(NewIDs)));
end;

procedure TSecurityScanDeltaTests.ComputeNewIDs_Overlap_OnlyNewReturned;
var
    NewIDs: TArray<Integer>;
begin
    // 3 и 7 были в базе, 5 - новая находка, 8 исчезла и не должна вернуться
    NewIDs := ComputeNewIDs([3, 5, 7], [3, 7, 8]);

    Assert.AreEqual(1, Integer(Length(NewIDs)));
    Assert.AreEqual(5, NewIDs[0]);
end;

procedure TSecurityScanDeltaTests.ComputeNewIDs_DuplicatesInCurrent_ReturnedOnce;
var
    NewIDs: TArray<Integer>;
begin
    NewIDs := ComputeNewIDs([5, 5, 6], []);

    Assert.AreEqual(2, Integer(Length(NewIDs)));
    Assert.AreEqual(5, NewIDs[0]);
    Assert.AreEqual(6, NewIDs[1]);
end;

procedure TSecurityScanDeltaTests.ComputeNewIDs_BothEmpty_ResultEmpty;
var
    NewIDs: TArray<Integer>;
begin
    NewIDs := ComputeNewIDs([], []);

    Assert.AreEqual(0, Integer(Length(NewIDs)));
end;

procedure TSecurityScanDeltaTests.MessageKey_Russian_PluralForms;
begin
    // 1 / 2-4 / 5+ по правилам русского языка
    Assert.AreEqual('Settings.ScanFindingsOne',
        ScanFindingsMessageKey(1, 'ru'));
    Assert.AreEqual('Settings.ScanFindingsFew',
        ScanFindingsMessageKey(2, 'ru'));
    Assert.AreEqual('Settings.ScanFindingsFew',
        ScanFindingsMessageKey(4, 'ru'));
    Assert.AreEqual('Settings.ScanFindingsMany',
        ScanFindingsMessageKey(5, 'ru'));
    Assert.AreEqual('Settings.ScanFindingsMany',
        ScanFindingsMessageKey(25, 'ru'));
    // Ноль находок тоже форма "многих"
    Assert.AreEqual('Settings.ScanFindingsMany',
        ScanFindingsMessageKey(0, 'ru'));
end;

procedure TSecurityScanDeltaTests.MessageKey_Russian_TeenExceptions;
begin
    // 11-14 всегда "многих", несмотря на последнюю цифру 1-4
    Assert.AreEqual('Settings.ScanFindingsMany',
        ScanFindingsMessageKey(11, 'ru'));
    Assert.AreEqual('Settings.ScanFindingsMany',
        ScanFindingsMessageKey(12, 'ru'));
    Assert.AreEqual('Settings.ScanFindingsMany',
        ScanFindingsMessageKey(14, 'ru'));
    // 21 -> один, 22 -> несколько, 111 -> многих, 101 -> один
    Assert.AreEqual('Settings.ScanFindingsOne',
        ScanFindingsMessageKey(21, 'ru'));
    Assert.AreEqual('Settings.ScanFindingsFew',
        ScanFindingsMessageKey(22, 'ru'));
    Assert.AreEqual('Settings.ScanFindingsMany',
        ScanFindingsMessageKey(111, 'ru'));
    Assert.AreEqual('Settings.ScanFindingsOne',
        ScanFindingsMessageKey(101, 'ru'));
end;

procedure TSecurityScanDeltaTests.MessageKey_English_OneOrMany;
begin
    Assert.AreEqual('Settings.ScanFindingsOne',
        ScanFindingsMessageKey(1, 'en'));
    Assert.AreEqual('Settings.ScanFindingsMany',
        ScanFindingsMessageKey(2, 'en'));
    Assert.AreEqual('Settings.ScanFindingsMany',
        ScanFindingsMessageKey(0, 'en'));
end;

procedure TSecurityScanDeltaTests.MessageKey_LanguageCaseInsensitive;
begin
    Assert.AreEqual('Settings.ScanFindingsOne',
        ScanFindingsMessageKey(1, 'RU'));
    Assert.AreEqual('Settings.ScanFindingsMany',
        ScanFindingsMessageKey(5, 'Ru'));
end;

end.
