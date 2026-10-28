unit Tests.SnippetLanguageNB;

interface

uses
    DUnitX.TestFramework,
    Common.SnippetLanguageNB
    ;

type
    [TestFixture]
    TSnippetLanguageNBTests = class(TObject)
    private
        function TrainedClassifier: TScriptLanguageClassifier;
    public
        [Test]
        procedure Tokenize_OperatorsAndGluedSigils;
        [Test]
        procedure Predict_ObviousScripts;
        [Test]
        procedure Predict_LowConfidence_Surrenders;
        [Test]
        procedure Predict_WrapperMajority_Wins;
        [Test]
        procedure IsWrapper_BatWithPowershell_Detected;
        [Test]
        procedure NoPrior_SmallCorpus_Wins;
        [Test]
        procedure Prune_RemovesRareWords;
        [Test]
        procedure SaveLoad_RoundTrip;
        [Test]
        procedure Untrained_OrUnknownText_ReturnsEmpty;
        [Test]
        procedure Shared_ReturnsSameInstance;
    end;

implementation

uses
    Common.Consts,
    Common.SnippetLanguages,
    System.Generics.Collections,
    System.IOUtils,
    System.SysUtils
    ;

const
    BASH_SAMPLES: TArray<string> = [
        '#!/bin/bash' + #10 + 'sudo apt-get update && sudo apt-get install nginx',
        '#!/bin/sh' + #10 + 'docker ps -a | grep exited',
        'cd /var/log && tar -czf backup.tar.gz syslog',
        'for f in *.conf; do cp "$f" "$f.bak"; done',
        'export PATH=$PATH:/usr/local/bin && source ~/.bashrc',
        'systemctl restart nginx && tail -f /var/log/syslog'
    ];

    BAT_SAMPLES: TArray<string> = [
        '@echo off' + #10 + 'setlocal' + #10 + 'set DIR=%~dp0',
        '@echo off' + #10 + 'if errorlevel 1 goto :fail',
        'setlocal enabledelayedexpansion' + #10 + 'for %%f in (*.log) do echo %%f',
        'reg query HKLM\SOFTWARE /v Version' + #10 + 'goto :eof',
        'net stop wuauserv' + #10 + 'robocopy C:\temp D:\backup /MIR',
        'REM backup script' + #10 + 'xcopy /Y /E src dst'
    ];

    PS_SAMPLES: TArray<string> = [
        'Get-Process | Where-Object { $_.CPU -gt 10 }',
        '$users = Get-ADUser -Filter *' + #10 + 'Write-Host $users.Count',
        'param([string]$Name)' + #10 + 'Write-Output "Hello, $Name"',
        'Import-Module ActiveDirectory' + #10 + 'Set-ADUser -Identity user1',
        '$items = Get-ChildItem -Recurse' + #10 + '$items | Export-Csv out.csv',
        'try { Invoke-WebRequest $url } catch { Write-Warning $_.Message }'
    ];

{ TSnippetLanguageNBTests }

function TSnippetLanguageNBTests.TrainedClassifier: TScriptLanguageClassifier;
var
    S: string;
begin
    Result := TScriptLanguageClassifier.Create;
    for S in BASH_SAMPLES do
        Result.TrainText(S, SNIPPET_LANG_BASH);
    for S in BAT_SAMPLES do
        Result.TrainText(S, SNIPPET_LANG_BAT);
    for S in PS_SAMPLES do
        Result.TrainText(S, SNIPPET_LANG_POWERSHELL);
end;

procedure TSnippetLanguageNBTests.Tokenize_OperatorsAndGluedSigils;
var
    Tokens: TList<string>;
begin
    // Дефис и '$' приклеиваются к словам, операторы - самостоятельные
    // токены; '2>&1' дает '>&'; одиночные цифры/буквы отсекаются
    Tokens := TList<string>.Create;
    try
        TScriptLanguageClassifier.ForEachToken(
            'Get-Process | Out-Null 2>&1 >> c:\log && $VAR=1',
            procedure(const AToken: string)
            begin
                Tokens.Add(AToken);
            end);

        Assert.AreEqual(8, Integer(Tokens.Count));
        Assert.AreEqual('get-process', Tokens[0]);
        Assert.AreEqual('|', Tokens[1]);
        Assert.AreEqual('out-null', Tokens[2]);
        Assert.AreEqual('>&', Tokens[3]);
        Assert.AreEqual('>>', Tokens[4]);
        Assert.AreEqual('log', Tokens[5]);
        Assert.AreEqual('&&', Tokens[6]);
        Assert.AreEqual('$var', Tokens[7]);
    finally
        Tokens.Free;
    end;
end;

procedure TSnippetLanguageNBTests.Predict_ObviousScripts;
var
    Clf: TScriptLanguageClassifier;
begin
    Clf := TrainedClassifier;
    try
        Assert.AreEqual(SNIPPET_LANG_BASH,
            Clf.PredictLanguage('sudo systemctl restart docker && tail -f /var/log/syslog'));
        Assert.AreEqual(SNIPPET_LANG_BAT,
            Clf.PredictLanguage('@echo off' + #10 + 'setlocal' + #10 + 'if errorlevel 1 goto :eof'));
        Assert.AreEqual(SNIPPET_LANG_POWERSHELL,
            Clf.PredictLanguage('Get-ChildItem -Recurse | Export-Csv out.csv'));
    finally
        Clf.Free;
    end;
end;

procedure TSnippetLanguageNBTests.Predict_LowConfidence_Surrenders;
var
    Clf: TScriptLanguageClassifier;
begin
    Clf := TrainedClassifier;
    try
        // 'echo' тянет к bat, 'done' - к bash: доказательство слабое и
        // перевес минимальный - детектор должен сдаться (умолчание bash)
        Assert.AreEqual('', Clf.PredictLanguage('echo done'));
    finally
        Clf.Free;
    end;
end;

procedure TSnippetLanguageNBTests.Predict_WrapperMajority_Wins;
var
    Clf: TScriptLanguageClassifier;
    Wrapper: string;
begin
    Clf := TrainedClassifier;
    try
        // На предсказании обертки НЕ фильтруются: если основная масса
        // токенов PowerShell - для подсветки выигрывает PowerShell
        Wrapper := '@echo off' + #10 + 'setlocal' + #10 +
            'powershell -Command "' + PS_SAMPLES[0] + '" ; ' + PS_SAMPLES[3];
        Assert.AreEqual(SNIPPET_LANG_POWERSHELL, Clf.PredictLanguage(Wrapper));
    finally
        Clf.Free;
    end;
end;

procedure TSnippetLanguageNBTests.IsWrapper_BatWithPowershell_Detected;
begin
    Assert.IsTrue(TScriptLanguageClassifier.IsPowerShellWrapperScript(
        '@echo off' + #10 + 'powershell -Command "Get-Process"'));
    Assert.IsTrue(TScriptLanguageClassifier.IsPowerShellWrapperScript(
        'call :init' + #10 + 'pwsh -File script.ps1'));
    Assert.IsFalse(TScriptLanguageClassifier.IsPowerShellWrapperScript(
        '@echo off' + #10 + 'robocopy C:\src D:\dst /MIR'));
end;

procedure TSnippetLanguageNBTests.NoPrior_SmallCorpus_Wins;
var
    Clf: TScriptLanguageClassifier;
    S: string;
begin
    // 6 документов bash против 2 документов bat: априорные вероятности
    // отключены (LogPrior = 0), поэтому редкий язык выигрывает на своих
    // токенах, когда доказательство превышает порог уверенности
    // (на крошечном корпусе IDF слов ~ 0, поэтому порог ослаблен)
    Clf := TScriptLanguageClassifier.Create;
    try
        for S in BASH_SAMPLES do
            Clf.TrainText(S, SNIPPET_LANG_BASH);
        Clf.TrainText(BAT_SAMPLES[0], SNIPPET_LANG_BAT);
        Clf.TrainText(BAT_SAMPLES[1], SNIPPET_LANG_BAT);

        Assert.AreEqual(6, Integer(Clf.DocumentCount(SNIPPET_LANG_BASH)));
        Assert.AreEqual(2, Integer(Clf.DocumentCount(SNIPPET_LANG_BAT)));

        Clf.MinEvidence := 0.1;
        Clf.MinMargin := 0.1;
        Assert.AreEqual(SNIPPET_LANG_BAT,
            Clf.PredictLanguage('@echo off' + #10 + 'setlocal'));
    finally
        Clf.Free;
    end;
end;

procedure TSnippetLanguageNBTests.Prune_RemovesRareWords;
var
    Clf: TScriptLanguageClassifier;
begin
    Clf := TScriptLanguageClassifier.Create;
    try
        Clf.TrainText('sudo reboot now', SNIPPET_LANG_BASH);
        Clf.TrainText('sudo poweroff now', SNIPPET_LANG_BASH);
        Clf.TrainText('zzqq boot once', SNIPPET_LANG_BASH);
        Assert.AreEqual(7, Integer(Clf.VocabSize(SNIPPET_LANG_BASH)));

        // Остаются только слова с Count >= 2: sudo (2) и now (2)
        Clf.PruneRareWords(2);
        Assert.AreEqual(2, Integer(Clf.VocabSize(SNIPPET_LANG_BASH)));
    finally
        Clf.Free;
    end;
end;

procedure TSnippetLanguageNBTests.SaveLoad_RoundTrip;
var
    Clf, Clf2: TScriptLanguageClassifier;
    WeightFile: string;
    LangsToCheck: TArray<string>;
    Lang: string;
begin
    WeightFile := TPath.Combine(TPath.GetTempPath, 'ssk_nb_test_weights.bin');
    LangsToCheck := [SNIPPET_LANG_BASH, SNIPPET_LANG_BAT, SNIPPET_LANG_POWERSHELL];
    Clf := TrainedClassifier;
    try
        Clf.PruneRareWords(2);
        Clf.SaveToFile(WeightFile);

        Clf2 := TScriptLanguageClassifier.Create;
        try
            Clf2.LoadFromFile(WeightFile);

            for Lang in LangsToCheck do
            begin
                Assert.AreEqual(Clf.DocumentCount(Lang), Clf2.DocumentCount(Lang));
                Assert.AreEqual(Clf.VocabSize(Lang), Clf2.VocabSize(Lang));
            end;

            Assert.AreEqual(Clf.PredictLanguage('sudo systemctl restart docker'),
                Clf2.PredictLanguage('sudo systemctl restart docker'));
            Assert.AreEqual(Clf.PredictLanguage('Get-Service | Stop-Service'),
                Clf2.PredictLanguage('Get-Service | Stop-Service'));
        finally
            Clf2.Free;
        end;
    finally
        Clf.Free;
        TFile.Delete(WeightFile);
    end;
end;

procedure TSnippetLanguageNBTests.Untrained_OrUnknownText_ReturnsEmpty;
var
    Clf: TScriptLanguageClassifier;
begin
    Clf := TScriptLanguageClassifier.Create;
    try
        Assert.AreEqual('', Clf.PredictLanguage('sudo reboot'));
        Assert.AreEqual(0, Integer(Length(Clf.PredictScores('sudo reboot'))));
    finally
        Clf.Free;
    end;

    // Обученная модель, но полностью незнакомые токены
    Clf := TrainedClassifier;
    try
        Assert.AreEqual('', Clf.PredictLanguage('qwertyzxc vbnm12345'));
    finally
        Clf.Free;
    end;
end;

procedure TSnippetLanguageNBTests.Shared_ReturnsSameInstance;
begin
    // Ленивый кэш на процесс: оба вызова обязаны вернуть один и тот же
    // объект; файл весов рядом с тестовым exe отсутствует - экземпляр
    // остаётся необученным, и это тоже валидное состояние
    Assert.AreSame(TObject(TScriptLanguageClassifier.Shared),
        TObject(TScriptLanguageClassifier.Shared));
    Assert.IsFalse(TScriptLanguageClassifier.Shared.IsTrained);
end;

end.
