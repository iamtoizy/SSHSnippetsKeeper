unit TypingGuard;

interface

uses
    System.SysUtils,
    System.RegularExpressions,
    System.Generics.Collections,
    Common.Localization,
    SecurityScanner
    ;

type
    TGuardFindingKind = (gfSecret, gfDanger);

    TGuardFinding = record
        Kind: TGuardFindingKind;
        Reason: string;
        MatchText: string;
    end;

    TTypingGuard = record
    private
        class function CutPreview(const S: string): string; static;
    public
        class function Findings(const AText: string;
            const AScanner: ISecurityScanner): TArray<TGuardFinding>; static;
        class function HasFindings(const AText: string;
            const AScanner: ISecurityScanner;
            out ASummary: string): Boolean; static;
        class function SummaryText(
            const AFindings: TArray<TGuardFinding>): string; static;
        class function ReportText(const AFindings: TArray<TGuardFinding>;
            AMaxLines: Integer): string; static;
    end;

implementation

uses
    System.Classes,
    System.Math
    ;

type
    TGuardRule = record
        Pattern: string;
        ReasonKey: string;
    end;

const
    MaxMatchPreviewLen = 60;
    SecretReasonKey = 'Security.SensitiveDataFound';

    DangerRules: array[0..10] of TGuardRule = (
        (Pattern: '\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r|--recursive\b)';
         ReasonKey: 'Guard.Danger.RmRf'),
        (Pattern: ':\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:';
         ReasonKey: 'Guard.Danger.ForkBomb'),
        (Pattern: '\b(curl|wget)\b[^;|\n]*\|\s*(ba|z|da|k)?sh\b';
         ReasonKey: 'Guard.Danger.CurlSh'),
        (Pattern: '\bdd\b[^;|\n]*of=/dev/';
         ReasonKey: 'Guard.Danger.DdDevice'),
        (Pattern: '\bmkfs(\.[a-z0-9]+)?\b';
         ReasonKey: 'Guard.Danger.Mkfs'),
        (Pattern: '>\s*/dev/(sd[a-z]+|hd[a-z]+|nvme[0-9]+n[0-9]+)';
         ReasonKey: 'Guard.Danger.DiskOverwrite'),
        (Pattern: '\bdrop\s+(table|database|schema)\b';
         ReasonKey: 'Guard.Danger.SqlDrop'),
        (Pattern: '\bgit\s+push\b[^;\n]*--force(-with-lease)?';
         ReasonKey: 'Guard.Danger.GitForcePush'),
        (Pattern: '\bchmod\s+(-R\s+)?777\s+/(\s|$)';
         ReasonKey: 'Guard.Danger.ChmodRoot'),
        (Pattern: '\bformat(\.com)?\s+c:';
         ReasonKey: 'Guard.Danger.FormatC'),
        (Pattern: '\bremove-item\b[^;\n]*\b(-recurse\b[^;\n]*-force\b|-force\b[^;\n]*-recurse\b)';
         ReasonKey: 'Guard.Danger.RemoveItemForce')
    );

{ TTypingGuard }

class function TTypingGuard.CutPreview(const S: string): string;
begin
    Result := Trim(S);
    if Length(Result) > MaxMatchPreviewLen then
        Result := Copy(Result, 1, MaxMatchPreviewLen) + '…';
end;

class function TTypingGuard.Findings(const AText: string;
    const AScanner: ISecurityScanner): TArray<TGuardFinding>;
var
    Rule: TGuardRule;
    M: TMatch;
    SecretRange: TSecretRange;
    Finding: TGuardFinding;
    All: TList<TGuardFinding>;
begin
    All := TList<TGuardFinding>.Create;
    try
        if AText.Trim <> '' then
        begin
            for Rule in DangerRules do
            begin
                M := TRegEx.Match(AText, Rule.Pattern,
                    [roIgnoreCase, roMultiLine]);
                if not M.Success then
                    Continue;
                Finding.Kind := gfDanger;
                Finding.Reason := TUIStateLoader.GetMessage(Rule.ReasonKey);
                Finding.MatchText := CutPreview(M.Value);
                All.Add(Finding);
            end;
            if AScanner <> nil then
                for SecretRange in AScanner.FindSensitiveRanges(AText) do
                begin
                    Finding.Kind := gfSecret;
                    Finding.Reason := SecretRange.Reason;
                    Finding.MatchText := CutPreview(Copy(AText,
                        SecretRange.StartOffset + 1, SecretRange.Length));
                    All.Add(Finding);
                end;
        end;
        Result := All.ToArray;
    finally
        All.Free;
    end;
end;

class function TTypingGuard.HasFindings(const AText: string;
    const AScanner: ISecurityScanner; out ASummary: string): Boolean;
var
    Found: TArray<TGuardFinding>;
begin
    Found := Findings(AText, AScanner);
    ASummary := SummaryText(Found);
    Result := Length(Found) > 0;
end;

class function TTypingGuard.SummaryText(
    const AFindings: TArray<TGuardFinding>): string;
begin
    Result := Format(TUIStateLoader.GetMessage('Guard.Summary'),
        [Length(AFindings)]);
end;

class function TTypingGuard.ReportText(
    const AFindings: TArray<TGuardFinding>; AMaxLines: Integer): string;
var
    Lines: TStringList;
    I: Integer;
begin
    Lines := TStringList.Create;
    try
        Lines.Add(SummaryText(AFindings));
        for I := 0 to Min(High(AFindings), AMaxLines - 1) do
            Lines.Add(Format(TUIStateLoader.GetMessage('Guard.FindingLine'),
                [AFindings[I].Reason, AFindings[I].MatchText]));
        if Length(AFindings) > AMaxLines then
            Lines.Add(Format(TUIStateLoader.GetMessage('Guard.SummaryMore'),
                [Length(AFindings) - AMaxLines]));
        Result := Lines.Text;
    finally
        Lines.Free;
    end;
end;

end.
