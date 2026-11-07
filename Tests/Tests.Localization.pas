unit Tests.Localization;

interface

uses
    Common.Localization,
    DUnitX.TestFramework,
    System.SysUtils
    ;

type
    [TestFixture]
    TLocalizationDiagnosticsTests = class(TObject)
    private
        FDir: string;
        function WriteLanguageFile(const AName, AJson: string): string;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test]
        procedure MissingKey_ReturnsMarkerAndRecordsIssue;
        [Test]
        procedure MissingKey_Twice_Counted;
        [Test]
        procedure Take_ClearsPending;
        [Test]
        procedure StructuralMiss_KindInvalidStructure;
        [Test]
        procedure FormatError_KindFormatError;
        [Test]
        procedure ExistingKey_NoIssue;
        [Test]
        procedure BrokenReload_KeepsPreviousSnapshot;
    end;

implementation

uses
    System.IOUtils
    ;

const
    BASE_JSON = '{"Messages":{"Known":{"Text":"ok"}}}';

{ TLocalizationDiagnosticsTests }

procedure TLocalizationDiagnosticsTests.Setup;
begin
    FDir := TPath.Combine(TPath.GetTempPath, 'SSKLoc_' + TGUID.NewGuid.ToString);
    TDirectory.CreateDirectory(FDir);
    TUIStateLoader.ClearPendingLocalizationIssues;
end;

procedure TLocalizationDiagnosticsTests.TearDown;
begin
    TUIStateLoader.ClearPendingLocalizationIssues;
    if TDirectory.Exists(FDir) then
        TDirectory.Delete(FDir, True);
end;

function TLocalizationDiagnosticsTests.WriteLanguageFile(const AName, AJson: string): string;
begin
    Result := TPath.Combine(FDir, AName + '.json');
    TFile.WriteAllText(Result, AJson, TEncoding.UTF8);
end;

procedure TLocalizationDiagnosticsTests.MissingKey_ReturnsMarkerAndRecordsIssue;
var
    Text: string;
    Issues: TArray<TLocalizationIssue>;
begin
    TUIStateLoader.LoadLanguageFile(WriteLanguageFile('base', BASE_JSON));

    Text := TUIStateLoader.GetMessage('Known.Missing');
    Assert.IsTrue(Text.StartsWith('[ERROR: Key'));
    Assert.IsTrue(Text.Contains('Known.Missing'));

    Issues := TUIStateLoader.TakePendingLocalizationIssues;
    Assert.AreEqual<Integer>(1, Length(Issues));
    Assert.AreEqual('Known.Missing', Issues[0].Key);
    Assert.AreEqual(Ord(likKeyNotFound), Ord(Issues[0].Kind));
    Assert.AreEqual(1, Issues[0].Count);
end;

procedure TLocalizationDiagnosticsTests.MissingKey_Twice_Counted;
var
    Issues: TArray<TLocalizationIssue>;
begin
    TUIStateLoader.LoadLanguageFile(WriteLanguageFile('base', BASE_JSON));

    TUIStateLoader.GetMessage('Known.Missing');
    TUIStateLoader.GetMessage('Known.Missing');

    Issues := TUIStateLoader.TakePendingLocalizationIssues;
    Assert.AreEqual<Integer>(1, Length(Issues));
    Assert.AreEqual(2, Issues[0].Count);
end;

procedure TLocalizationDiagnosticsTests.Take_ClearsPending;
begin
    TUIStateLoader.LoadLanguageFile(WriteLanguageFile('base', BASE_JSON));

    TUIStateLoader.GetMessage('A.B');
    Assert.IsTrue(TUIStateLoader.HasPendingLocalizationIssues);
    Assert.AreEqual<Integer>(1, Length(TUIStateLoader.TakePendingLocalizationIssues));
    Assert.IsFalse(TUIStateLoader.HasPendingLocalizationIssues);
    Assert.AreEqual<Integer>(0, Length(TUIStateLoader.TakePendingLocalizationIssues));
end;

procedure TLocalizationDiagnosticsTests.StructuralMiss_KindInvalidStructure;
var
    Text: string;
    Issues: TArray<TLocalizationIssue>;
begin
    TUIStateLoader.LoadLanguageFile(WriteLanguageFile('nested', '{"Messages":{"A":{"B":"x"}}}'));

    Text := TUIStateLoader.GetMessage('A.C.D');
    Assert.IsTrue(Text.StartsWith('[ERROR: Invalid JSON structure'));

    Issues := TUIStateLoader.TakePendingLocalizationIssues;
    Assert.AreEqual<Integer>(1, Length(Issues));
    Assert.AreEqual('A.C.D', Issues[0].Key);
    Assert.AreEqual(Ord(likInvalidStructure), Ord(Issues[0].Kind));
end;

procedure TLocalizationDiagnosticsTests.FormatError_KindFormatError;
var
    Text: string;
    Issues: TArray<TLocalizationIssue>;
begin
    TUIStateLoader.LoadLanguageFile(WriteLanguageFile('fmt', '{"Messages":{"Fmt":"%d %d"}}'));

    Text := TUIStateLoader.GetMessage('Fmt', ['only-one-arg']);
    Assert.AreEqual('[FORMAT ERROR: Fmt]', Text);

    Issues := TUIStateLoader.TakePendingLocalizationIssues;
    Assert.AreEqual<Integer>(1, Length(Issues));
    Assert.AreEqual('Fmt', Issues[0].Key);
    Assert.AreEqual(Ord(likFormatError), Ord(Issues[0].Kind));
end;

procedure TLocalizationDiagnosticsTests.ExistingKey_NoIssue;
begin
    TUIStateLoader.LoadLanguageFile(WriteLanguageFile('base', BASE_JSON));

    Assert.AreEqual('ok', TUIStateLoader.GetMessage('Known.Text'));
    Assert.IsFalse(TUIStateLoader.HasPendingLocalizationIssues);
end;

procedure TLocalizationDiagnosticsTests.BrokenReload_KeepsPreviousSnapshot;
var
    Raised: Boolean;
begin
    TUIStateLoader.LoadLanguageFile(WriteLanguageFile('one', '{"Messages":{"K":"one"}}'));
    Assert.AreEqual('one', TUIStateLoader.GetMessage('K'));

    Raised := False;
    try
        TUIStateLoader.LoadLanguageFile(WriteLanguageFile('broken', '{ not a json'));
    except
        Raised := True;
    end;
    Assert.IsTrue(Raised, 'Битый JSON должен приводить к исключению');

    Assert.AreEqual('one', TUIStateLoader.GetMessage('K'));
end;

end.
