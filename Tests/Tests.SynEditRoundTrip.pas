unit Tests.SynEditRoundTrip;

// Round-trip TCustomSynEdit.Text: присвоение из БД (LF-only) и обратное чтение
// не должны менять текст, иначе IsSnippetChanged даёт ложное срабатывание
// при открытии сниппета и отмене без правок.

interface

uses
    DUnitX.TestFramework,
    SynEdit
    ;

type
    [TestFixture]
    TSynEditRoundTripTests = class(TObject)
    private
        function RoundTrip(const ASource: string): string;
        function NormalizeLF(const AValue: string): string;
    public
        [Test] procedure LF_NoTrailing_Exact;
        [Test] procedure LF_WithTrailing_Exact;
        [Test] procedure Empty_Exact;
        [Test] procedure SingleLine_Exact;
        [Test] procedure BlankLineInside_Exact;
        [Test] procedure CRLF_WithTrailing_CompareEqual;
        [Test] procedure CRLF_NoTrailing_CompareEqual;
        [Test] procedure Mixed_CompareEqual;
        [Test] procedure WordWrap_DoesNotAffectText;
        [Test] procedure Highlighter_DoesNotAffectText;
    end;

implementation

uses
    System.SysUtils,
    SynHighlighterUnixShellScript
    ;

function TSynEditRoundTripTests.RoundTrip(const ASource: string): string;
var
    Ed: TCustomSynEdit;
begin
    Ed := TCustomSynEdit.Create(nil);
    try
        Ed.Lines.Text := ASource;
        Result := Ed.Text;
    finally
        Ed.Free;
    end;
end;

function TSynEditRoundTripTests.NormalizeLF(const AValue: string): string;
begin
    Result := StringReplace(AValue, #13#10, #10, [rfReplaceAll]);
end;

procedure TSynEditRoundTripTests.LF_NoTrailing_Exact;
const
    Source = 'cmd1' + #10 + 'cmd2';
begin
    Assert.AreEqual(Source, RoundTrip(Source));
end;

procedure TSynEditRoundTripTests.LF_WithTrailing_Exact;
const
    Source = 'cmd1' + #10 + 'cmd2' + #10;
begin
    Assert.AreEqual(Source, RoundTrip(Source));
end;

procedure TSynEditRoundTripTests.Empty_Exact;
begin
    Assert.AreEqual('', RoundTrip(''));
end;

procedure TSynEditRoundTripTests.SingleLine_Exact;
begin
    Assert.AreEqual('echo hello', RoundTrip('echo hello'));
end;

procedure TSynEditRoundTripTests.BlankLineInside_Exact;
const
    Source = 'cmd1' + #10 + #10 + 'cmd2' + #10;
begin
    Assert.AreEqual(Source, RoundTrip(Source));
end;

procedure TSynEditRoundTripTests.CRLF_WithTrailing_CompareEqual;
const
    Source = 'cmd1' + #13#10 + 'cmd2' + #13#10;
begin
    Assert.AreEqual(NormalizeLF(Source), NormalizeLF(RoundTrip(Source)));
end;

procedure TSynEditRoundTripTests.CRLF_NoTrailing_CompareEqual;
const
    Source = 'cmd1' + #13#10 + 'cmd2';
begin
    Assert.AreEqual(NormalizeLF(Source), NormalizeLF(RoundTrip(Source)));
end;

procedure TSynEditRoundTripTests.Mixed_CompareEqual;
const
    Source = 'cmd1' + #10 + 'cmd2' + #13#10 + 'cmd3' + #10;
begin
    Assert.AreEqual(NormalizeLF(Source), NormalizeLF(RoundTrip(Source)));
end;

procedure TSynEditRoundTripTests.WordWrap_DoesNotAffectText;
const
    Source = 'cmd1' + #10 + 'cmd2' + #10;
var
    Ed: TCustomSynEdit;
begin
    Ed := TCustomSynEdit.Create(nil);
    try
        Ed.WordWrap := True;
        Ed.Lines.Text := Source;
        Assert.AreEqual(Source, Ed.Text);
    finally
        Ed.Free;
    end;
end;

procedure TSynEditRoundTripTests.Highlighter_DoesNotAffectText;
const
    Source = 'echo ' + #10 + '{INPUT:user}' + #10 + 'ls -la' + #10;
var
    Ed: TCustomSynEdit;
begin
    Ed := TCustomSynEdit.Create(nil);
    try
        Ed.Highlighter := TSynUNIXShellScriptSyn.Create(Ed);
        Ed.Lines.Text := Source;
        Assert.AreEqual(Source, Ed.Text);
    finally
        Ed.Free;
    end;
end;

end.
