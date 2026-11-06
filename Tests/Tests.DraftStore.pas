unit Tests.DraftStore;

interface

uses
    Common.DraftStore,
    DUnitX.TestFramework,
    System.SysUtils
    ;

type
    [TestFixture]
    TDraftStoreTests = class(TObject)
    private
        FDir: string;
        function NewPayload(const AKey: string): TDraftPayload;
        function RawFileText(const AKey: string): string;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test]
        procedure Roundtrip_AllFields;
        [Test]
        procedure SaveDraft_PresetsSavedAtKept;
        [Test]
        procedure NoPlaintextOnDisk;
        [Test]
        procedure DeleteDraft_RemovesFile;
        [Test]
        procedure LoadDraft_MissingFile_False;
        [Test]
        procedure LoadDraft_CorruptFile_False;
        [Test]
        procedure LoadDraft_PlainTextFile_False;
        [Test]
        procedure SanitizeKey_SpecialCharsReplaced;
        [Test]
        procedure SaveDraft_CreatesMissingDir;
        [Test]
        procedure PurgeStale_OrphanStaleCorruptRemoved;
        [Test]
        procedure PurgeStale_MissingDir_Zero;
        [Test]
        procedure DbScopeFor_DeterministicAndDistinct;
        [Test]
        procedure Scope_IsolatesKeysBetweenDbs;
        [Test]
        procedure Scope_Purge_ForeignOnlyByAge;
        [Test]
        procedure Scope_Purge_OwnLiveOrphanAndLegacy;
    end;

implementation

uses
    System.Classes,
    System.DateUtils,
    System.IOUtils
    ;

{ TDraftStoreTests }

procedure TDraftStoreTests.Setup;
begin
    FDir := TPath.Combine(TPath.GetTempPath, 'SSKDraftTests_' + TGUID.NewGuid.ToString);
    TDirectory.CreateDirectory(FDir);
end;

procedure TDraftStoreTests.TearDown;
begin
    if TDirectory.Exists(FDir) then
        TDirectory.Delete(FDir, True);
end;

function TDraftStoreTests.NewPayload(const AKey: string): TDraftPayload;
begin
    Result := Default(TDraftPayload);
    Result.Key := AKey;
    Result.Title := 'Backup server';
    Result.Content := 'tar -czf backup.tar.gz /etc';
    Result.Comment := 'nightly';
    Result.Language := 'bash';
    Result.LanguageLocked := True;
    Result.SecurityIgnore := False;
    Result.Tags := TArray<string>.Create('linux', 'cron');
end;

function TDraftStoreTests.RawFileText(const AKey: string): string;
begin
    Result := TFile.ReadAllText(TPath.Combine(FDir, AKey + '.draft'), TEncoding.UTF8);
end;

procedure TDraftStoreTests.Roundtrip_AllFields;
var
    Store: TDraftStore;
    P, Loaded: TDraftPayload;
begin
    Store := TDraftStore.Create(FDir);
    try
        P := NewPayload('new');
        Assert.IsTrue(Store.SaveDraft(P));
        Assert.IsTrue(P.SavedAt > 0);
        Assert.AreEqual(DRAFT_FORMAT_VERSION, P.Version);

        Assert.IsTrue(Store.DraftExists('new'));
        Assert.IsTrue(Store.LoadDraft('new', Loaded));
        Assert.AreEqual('new', Loaded.Key);
        Assert.AreEqual(P.SavedAt, Loaded.SavedAt);
        Assert.AreEqual('Backup server', Loaded.Title);
        Assert.AreEqual('tar -czf backup.tar.gz /etc', Loaded.Content);
        Assert.AreEqual('nightly', Loaded.Comment);
        Assert.AreEqual('bash', Loaded.Language);
        Assert.IsTrue(Loaded.LanguageLocked);
        Assert.IsFalse(Loaded.SecurityIgnore);
        Assert.AreEqual(2, Integer(Length(Loaded.Tags)));
        Assert.AreEqual('linux', Loaded.Tags[0]);
        Assert.AreEqual('cron', Loaded.Tags[1]);
        Assert.AreEqual(DRAFT_FORMAT_VERSION, Loaded.Version);
    finally
        Store.Free;
    end;
end;

procedure TDraftStoreTests.SaveDraft_PresetsSavedAtKept;
var
    Store: TDraftStore;
    P, Loaded: TDraftPayload;
begin
    Store := TDraftStore.Create(FDir);
    try
        P := NewPayload('new');
        P.SavedAt := 1234567890;
        Assert.IsTrue(Store.SaveDraft(P));
        Assert.AreEqual(Int64(1234567890), P.SavedAt);
        Assert.IsTrue(Store.LoadDraft('new', Loaded));
        Assert.AreEqual(Int64(1234567890), Loaded.SavedAt);
    finally
        Store.Free;
    end;
end;

procedure TDraftStoreTests.NoPlaintextOnDisk;
var
    Store: TDraftStore;
    P: TDraftPayload;
    Raw: string;
begin
    Store := TDraftStore.Create(FDir);
    try
        P := NewPayload('new');
        Assert.IsTrue(Store.SaveDraft(P));
        Raw := RawFileText('new');
        Assert.IsFalse(Raw.Contains('Backup server'));
        Assert.IsFalse(Raw.Contains('tar -czf'));
        Assert.IsFalse(Raw.Contains('nightly'));
        Assert.IsTrue(Raw.StartsWith('dpapi:'));
    finally
        Store.Free;
    end;
end;

procedure TDraftStoreTests.DeleteDraft_RemovesFile;
var
    Store: TDraftStore;
    P, Loaded: TDraftPayload;
begin
    Store := TDraftStore.Create(FDir);
    try
        P := NewPayload('new');
        Assert.IsTrue(Store.SaveDraft(P));
        Assert.IsTrue(Store.DraftExists('new'));
        Assert.IsTrue(Store.DeleteDraft('new'));
        Assert.IsFalse(Store.DraftExists('new'));
        Assert.IsFalse(Store.LoadDraft('new', Loaded));
    finally
        Store.Free;
    end;
end;

procedure TDraftStoreTests.LoadDraft_MissingFile_False;
var
    Store: TDraftStore;
    Loaded: TDraftPayload;
begin
    Store := TDraftStore.Create(FDir);
    try
        Assert.IsFalse(Store.LoadDraft('nonexistent', Loaded));
        Assert.IsFalse(Store.DraftExists('nonexistent'));
    finally
        Store.Free;
    end;
end;

procedure TDraftStoreTests.LoadDraft_CorruptFile_False;
var
    Store: TDraftStore;
    Loaded: TDraftPayload;
begin
    Store := TDraftStore.Create(FDir);
    try
        TFile.WriteAllText(TPath.Combine(FDir, 'new.draft'),
            'dpapi:not-a-valid-base64!!!', TEncoding.UTF8);
        Assert.IsFalse(Store.LoadDraft('new', Loaded));
    finally
        Store.Free;
    end;
end;

procedure TDraftStoreTests.LoadDraft_PlainTextFile_False;
var
    Store: TDraftStore;
    Loaded: TDraftPayload;
begin
    Store := TDraftStore.Create(FDir);
    try
        TFile.WriteAllText(TPath.Combine(FDir, 'new.draft'),
            '{"version":1,"title":"leak"}', TEncoding.UTF8);
        Assert.IsFalse(Store.LoadDraft('new', Loaded));
    finally
        Store.Free;
    end;
end;

procedure TDraftStoreTests.SanitizeKey_SpecialCharsReplaced;
var
    Store: TDraftStore;
    P, Loaded: TDraftPayload;
begin
    Store := TDraftStore.Create(FDir);
    try
        P := NewPayload('sn/ippet:1');
        Assert.IsTrue(Store.SaveDraft(P));
        Assert.IsTrue(Store.DraftExists('sn_ippet_1'));
        Assert.IsTrue(Store.LoadDraft('sn_ippet_1', Loaded));
        Assert.AreEqual('sn_ippet_1', Loaded.Key);
    finally
        Store.Free;
    end;
end;

procedure TDraftStoreTests.SaveDraft_CreatesMissingDir;
var
    Store: TDraftStore;
    P: TDraftPayload;
    SubDir: string;
begin
    SubDir := TPath.Combine(FDir, 'sub', 'drafts');
    Store := TDraftStore.Create(SubDir);
    try
        P := NewPayload('new');
        Assert.IsTrue(Store.SaveDraft(P));
        Assert.IsTrue(TDirectory.Exists(SubDir));
        Assert.IsTrue(TFile.Exists(TPath.Combine(SubDir, 'new.draft')));
    finally
        Store.Free;
    end;
end;

procedure TDraftStoreTests.PurgeStale_OrphanStaleCorruptRemoved;
var
    Store: TDraftStore;
    P: TDraftPayload;
    LiveIDs: TArray<Int64>;
    Old, NowEpoch: Int64;
    Removed: Integer;
begin
    Store := TDraftStore.Create(FDir);
    try
        NowEpoch := DateTimeToUnix(Now, False);
        Old := NowEpoch - 30 * 86400;

        P := NewPayload('1');
        P.SavedAt := NowEpoch - 60;
        Store.SaveDraft(P);

        P := NewPayload('2');
        P.SavedAt := NowEpoch - 60;
        Store.SaveDraft(P);

        P := NewPayload('new');
        P.SavedAt := Old;
        Store.SaveDraft(P);

        P := NewPayload('3');
        P.SavedAt := Old;
        Store.SaveDraft(P);

        TFile.WriteAllText(TPath.Combine(FDir, 'broken.draft'), 'garbage', TEncoding.UTF8);

        LiveIDs := TArray<Int64>.Create(1, 3);
        Removed := Store.PurgeStale(NowEpoch - 14 * 86400, LiveIDs);
        Assert.AreEqual(4, Removed);
        Assert.IsTrue(Store.DraftExists('1'));
        Assert.IsFalse(Store.DraftExists('2'));
        Assert.IsFalse(Store.DraftExists('new'));
        Assert.IsFalse(Store.DraftExists('3'));
        Assert.IsFalse(Store.DraftExists('broken'));
    finally
        Store.Free;
    end;
end;

procedure TDraftStoreTests.PurgeStale_MissingDir_Zero;
var
    Store: TDraftStore;
begin
    Store := TDraftStore.Create(TPath.Combine(FDir, 'no-such-dir'));
    try
        Assert.AreEqual(0, Store.PurgeStale(0, nil));
    finally
        Store.Free;
    end;
end;

procedure TDraftStoreTests.DbScopeFor_DeterministicAndDistinct;
var
    S1, S2, S3: string;
begin
    S1 := TDraftStore.DbScopeFor('C:\db\a\snippets.sqlite');
    S2 := TDraftStore.DbScopeFor('C:\db\a\snippets.sqlite');
    S3 := TDraftStore.DbScopeFor('C:\db\b\snippets.sqlite');
    Assert.AreEqual(8, Length(S1));
    Assert.AreEqual(S1, S2);
    Assert.AreNotEqual(S1, S3);
    Assert.AreEqual('', TDraftStore.DbScopeFor(''));
end;

procedure TDraftStoreTests.Scope_IsolatesKeysBetweenDbs;
var
    A, B: TDraftStore;
    P, Loaded: TDraftPayload;
begin
    A := TDraftStore.Create(FDir, 'aaaa1111');
    try
        B := TDraftStore.Create(FDir, 'bbbb2222');
        try
            P := NewPayload('87');
            Assert.IsTrue(A.SaveDraft(P));
            Assert.AreEqual('aaaa1111', P.DbScope);
            Assert.AreEqual('aaaa1111_87', P.Key);

            Assert.IsFalse(B.DraftExists('87'));
            Assert.IsFalse(B.LoadDraft('87', Loaded));

            Assert.IsTrue(A.DraftExists('87'));
            Assert.IsTrue(A.LoadDraft('87', Loaded));
            Assert.AreEqual('aaaa1111', Loaded.DbScope);
            Assert.AreEqual('aaaa1111_87', Loaded.Key);
        finally
            B.Free;
        end;
    finally
        A.Free;
    end;
end;

procedure TDraftStoreTests.Scope_Purge_ForeignOnlyByAge;
var
    A, B: TDraftStore;
    P: TDraftPayload;
    NowEpoch, Cutoff: Int64;
begin
    A := TDraftStore.Create(FDir, 'aaaa1111');
    try
        B := TDraftStore.Create(FDir, 'bbbb2222');
        try
            NowEpoch := DateTimeToUnix(Now, False);
            Cutoff := NowEpoch - 14 * 86400;

            P := NewPayload('87');
            P.SavedAt := NowEpoch - 60;
            Assert.IsTrue(A.SaveDraft(P));

            Assert.AreEqual(0, B.PurgeStale(Cutoff, nil));
            Assert.IsTrue(A.DraftExists('87'));

            P := NewPayload('99');
            P.SavedAt := NowEpoch - 30 * 86400;
            Assert.IsTrue(A.SaveDraft(P));

            Assert.AreEqual(1, B.PurgeStale(Cutoff, nil));
            Assert.IsFalse(A.DraftExists('99'));
        finally
            B.Free;
        end;
    finally
        A.Free;
    end;
end;

procedure TDraftStoreTests.Scope_Purge_OwnLiveOrphanAndLegacy;
var
    A, U: TDraftStore;
    P: TDraftPayload;
    NowEpoch, Cutoff: Int64;
    LiveIDs: TArray<Int64>;
begin
    A := TDraftStore.Create(FDir, 'aaaa1111');
    try
        U := TDraftStore.Create(FDir);
        try
            NowEpoch := DateTimeToUnix(Now, False);
            Cutoff := NowEpoch - 14 * 86400;

            P := NewPayload('1');
            P.SavedAt := NowEpoch - 60;
            Assert.IsTrue(A.SaveDraft(P));

            P := NewPayload('99');
            P.SavedAt := NowEpoch - 60;
            Assert.IsTrue(A.SaveDraft(P));

            P := NewPayload('55');
            P.SavedAt := NowEpoch - 60;
            Assert.IsTrue(U.SaveDraft(P));

            LiveIDs := TArray<Int64>.Create(1);
            Assert.AreEqual(1, A.PurgeStale(Cutoff, LiveIDs));
            Assert.IsTrue(A.DraftExists('1'));
            Assert.IsFalse(A.DraftExists('99'));
            Assert.IsTrue(TFile.Exists(TPath.Combine(FDir, '55.draft')));
        finally
            U.Free;
        end;
    finally
        A.Free;
    end;
end;

end.
