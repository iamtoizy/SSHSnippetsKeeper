unit Tests.SnippetLanguageDetect;

interface

uses
    DUnitX.TestFramework,
    Common.SnippetLanguages
    ;

type
    [TestFixture]
    TSnippetLanguageDetectTests = class(TObject)
    public
        [Test]
        procedure Detect_BashShebang;
        [Test]
        procedure Detect_BashCommands;
        [Test]
        procedure Detect_PowerShellShebang;
        [Test]
        procedure Detect_PowerShellCmdlets;
        [Test]
        procedure Detect_BatchEchoOff;
        [Test]
        procedure Detect_Xml;
        [Test]
        procedure Detect_Json;
        [Test]
        procedure Detect_Ini;
        [Test]
        procedure Detect_Markdown;
        [Test]
        procedure Detect_PlainText_AndEmpty_DefaultBash;
        [Test]
        procedure Detect_NeverReturnsPlainText;
    end;

implementation

uses
    Common.Consts,
    Common.SnippetLanguageDetect,
    Common.SnippetLanguageNB,
    System.SysUtils
    ;

const
    LF = #10;

{ TSnippetLanguageDetectTests }

procedure TSnippetLanguageDetectTests.Detect_BashShebang;
begin
    Assert.AreEqual(SNIPPET_LANG_BASH,
        DetectSnippetLanguage('#!/bin/bash' + LF + 'echo ${HOME} && ls | wc -l'));
end;

procedure TSnippetLanguageDetectTests.Detect_BashCommands;
begin
    Assert.AreEqual(SNIPPET_LANG_BASH,
        DetectSnippetLanguage('docker ps -a && docker compose down'));
end;

procedure TSnippetLanguageDetectTests.Detect_PowerShellShebang;
begin
    Assert.AreEqual(SNIPPET_LANG_POWERSHELL,
        DetectSnippetLanguage('#!/usr/bin/pwsh -NoLogo'));
end;

procedure TSnippetLanguageDetectTests.Detect_PowerShellCmdlets;
begin
    Assert.AreEqual(SNIPPET_LANG_POWERSHELL,
        DetectSnippetLanguage('Get-Process | Stop-Process -Name notepad'));

    Assert.AreEqual(SNIPPET_LANG_POWERSHELL,
        DetectSnippetLanguage('$user = "x"' + LF + 'Write-Host $user'));
end;

procedure TSnippetLanguageDetectTests.Detect_BatchEchoOff;
begin
    Assert.AreEqual(SNIPPET_LANG_BAT,
        DetectSnippetLanguage('@echo off' + LF + 'setlocal' + LF + 'set DIR=%~dp0'));
end;

procedure TSnippetLanguageDetectTests.Detect_Xml;
begin
    Assert.AreEqual(SNIPPET_LANG_XML,
        DetectSnippetLanguage('<?xml version="1.0"?>' + LF + '<catalog xmlns:x="urn:x">'));
end;

procedure TSnippetLanguageDetectTests.Detect_Json;
begin
    Assert.AreEqual(SNIPPET_LANG_JSON,
        DetectSnippetLanguage('{"name": "value", "n": 1}'));
end;

procedure TSnippetLanguageDetectTests.Detect_Ini;
begin
    Assert.AreEqual(SNIPPET_LANG_INI,
        DetectSnippetLanguage('[core]' + LF + 'repositoryformatversion = 0'));
end;

procedure TSnippetLanguageDetectTests.Detect_Markdown;
begin
    Assert.AreEqual(SNIPPET_LANG_MARKDOWN,
        DetectSnippetLanguage('# Title' + LF + '- item 1' + LF + '- item 2' + LF + '**bold** [link](x)'));
end;

procedure TSnippetLanguageDetectTests.Detect_PlainText_AndEmpty_DefaultBash;
begin
    Assert.AreEqual(SNIPPET_LANG_BASH, DetectSnippetLanguage('echo hello world'));
    Assert.AreEqual(DEFAULT_SNIPPET_LANGUAGE, DetectSnippetLanguage(''));
end;

procedure TSnippetLanguageDetectTests.Detect_NeverReturnsPlainText;
begin
    // plaintext — режим «без подсветки», а не язык.
    // Автодетект ни через эвристику, ни через NB-классификатор
    // не должен вернуть его: это нарушает контракты UI.
    Assert.AreNotEqual(SNIPPET_LANG_PLAINTEXT, DetectSnippetLanguage(''));
    Assert.AreNotEqual(SNIPPET_LANG_PLAINTEXT, DetectSnippetLanguage('echo hello'));
    Assert.AreNotEqual(SNIPPET_LANG_PLAINTEXT, DetectSnippetLanguage('# Title'));

    // NB обучена только на скриптовых языках; проза для неё — '' или
    // случайный язык, но никогда plaintext
    Assert.AreNotEqual(SNIPPET_LANG_PLAINTEXT,
        TScriptLanguageClassifier.Shared.PredictLanguage('Just a prose without any code at all'));
end;

end.
