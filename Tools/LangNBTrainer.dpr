program LangNBTrainer;

{ Консольный тренер наивного Байеса для определения языка скриптов.

  Использование:
    LangNBTrainer.exe <bash_scripts> <cmd_scripts> <ps_scripts> [out\scripts_weights.bin]
    LangNBTrainer.exe -p <scripts_weights.bin> ["text"]   - проверка модели
      (без текста читает строки из stdin, пустая строка - выход)

  Обходит папки рекурсивно, фильтрует файлы по расширениям (.sh/.bash,
  .bat/.cmd, .ps1/.psm1); если по расширениям не нашлось ничего, а файлы в
  папке есть - берёт все подряд. Обучает модель, чистит словари
  (PruneRareWords, порог 3) и сохраняет веса в бинарный scripts_weights.bin. }

{$APPTYPE CONSOLE}

uses
    System.Classes,
    System.Generics.Collections,
    System.IOUtils,
    System.SysUtils,
    Winapi.Windows,
    Common.Consts in '..\Common\Common.Consts.pas',
    Common.SnippetLanguages in '..\Common\Common.SnippetLanguages.pas',
    Common.SnippetLanguageNB in '..\Common\Common.SnippetLanguageNB.pas'
    ;

const
    PRUNE_THRESHOLD = 3;
    DEFAULT_OUTPUT_FILE = 'scripts_weights.bin';

    // Порядок аргументов командной строки
    LANG_IDS: array[0..2] of string = (
        SNIPPET_LANG_BASH,
        SNIPPET_LANG_BAT,
        SNIPPET_LANG_POWERSHELL
    );

    LANG_EXTS: array[0..2] of TArray<string> = (
        ['.sh', '.bash'],
        ['.bat', '.cmd'],
        ['.ps1', '.psm1']
    );

function IsProbablyUtf8(const Bytes: TBytes): Boolean;
var
    I, Len, Cont: Integer;
    B: Byte;
begin
    Result := True;
    I := 0;
    Len := Length(Bytes);
    while I < Len do
    begin
        B := Bytes[I];
        if B < $80 then
            Inc(I)
        else
        begin
            if (B and $E0) = $C0 then
                Cont := 1
            else if (B and $F0) = $E0 then
                Cont := 2
            else if (B and $F8) = $F0 then
                Cont := 3
            else
                Exit(False);
            if I + Cont >= Len then
                Exit(False);
            Inc(I);
            while Cont > 0 do
            begin
                if (Bytes[I] and $C0) <> $80 then
                    Exit(False);
                Inc(I);
                Dec(Cont);
            end;
        end;
    end;
end;

// BOM -> UTF-8; валидный UTF-8 без BOM -> UTF-8; иначе ANSI (TEncoding.Default)
function ReadTextAuto(const AFileName: string): string;
var
    Bytes: TBytes;
begin
    Bytes := TFile.ReadAllBytes(AFileName);
    if (Length(Bytes) >= 3) and (Bytes[0] = $EF) and (Bytes[1] = $BB) and (Bytes[2] = $BF) then
        Exit(TEncoding.UTF8.GetString(Bytes, 3, Length(Bytes) - 3));
    if IsProbablyUtf8(Bytes) then
        Exit(TEncoding.UTF8.GetString(Bytes));
    Result := TEncoding.Default.GetString(Bytes);
end;

function CollectScripts(const ADir: string; const AExts: TArray<string>): TArray<string>;
var
    All, Filt: TList<string>;
    F, Ext: string;
    E: string;
begin
    Result := nil;
    if not TDirectory.Exists(ADir) then
        Exit;

    All := TList<string>.Create;
    Filt := TList<string>.Create;
    try
        for F in TDirectory.GetFiles(ADir, '*', TSearchOption.soAllDirectories) do
        begin
            All.Add(F);
            Ext := LowerCase(ExtractFileExt(F));
            for E in AExts do
                if Ext = E then
                begin
                    Filt.Add(F);
                    Break;
                end;
        end;

        // Фоллбэк: файлы есть, но ни один не подошёл по расширению -
        // почти всегда это перепутанные аргументы командной строки
        if (Filt.Count = 0) and (All.Count > 0) then
        begin
            Writeln('WARNING: ', ADir, ': no files matched extensions, using all ',
                All.Count, ' files (check argument order)');
            Result := All.ToArray
        end
        else
            Result := Filt.ToArray;
    finally
        All.Free;
        Filt.Free;
    end;
end;

procedure PrintUsage;
begin
    Writeln('Usage:');
    Writeln('  LangNBTrainer.exe <bash_scripts> <cmd_scripts> <ps_scripts> [out\scripts_weights.bin]');
    Writeln('  LangNBTrainer.exe -p <scripts_weights.bin> ["text"]');
    Writeln('Default output: scripts_weights.bin (current dir), prune threshold = 3');
end;

procedure ShowPredict(Clf: TScriptLanguageClassifier; const AText: string);
var
    Scores: TArray<TLangScore>;
    S: TLangScore;
    Verdict: string;
begin
    Scores := Clf.PredictScores(AText);
    if Length(Scores) = 0 then
    begin
        Writeln('no prediction (untrained model or no known tokens)');
        Exit;
    end;

    Writeln('Text: ' + Copy(AText, 1, 120));
    for S in Scores do
        Writeln(Format('  %-10s score=%14.4f prob=%6.1f%%', [S.Language, S.Score, S.Prob * 100]));

    Verdict := Clf.PredictLanguage(AText);
    if Verdict = '' then
        Writeln('=> no confident verdict (thresholds not met, default: bash)')
    else
        Writeln('=> ' + Verdict);
end;

procedure RunPredictMode;
var
    Clf: TScriptLanguageClassifier;
    Text: string;
    I: Integer;
begin
    Clf := TScriptLanguageClassifier.Create;
    try
        Clf.LoadFromFile(ParamStr(2));

        Text := '';
        for I := 3 to ParamCount do
            Text := Text + ' ' + ParamStr(I);

        if Trim(Text) = '' then
        begin
            // stdin-режим: построчно, пустая строка - выход
            while not Eof do
            begin
                ReadLn(Text);
                if Trim(Text) = '' then
                    Break;
                ShowPredict(Clf, Text);
            end;
        end
        else
            ShowPredict(Clf, Text);
    finally
        Clf.Free;
    end;
end;

var
    Clf: TScriptLanguageClassifier;
    OutputFile: string;
    PruneThreshold: Integer;
    Folders: array[0..2] of string;
    Files: TArray<string>;
    Docs, Skipped: array[0..2] of Integer;
    I: Integer;
    F, Text: string;
begin
    SetConsoleOutputCP(CP_UTF8);
    try
        if (ParamCount >= 2) and ((ParamStr(1) = '-p') or (ParamStr(1) = '/p')) then
        begin
            RunPredictMode;
            Exit;
        end;

        if ParamCount < 3 then
        begin
            PrintUsage;
            Halt(2);
        end;

        for I := 0 to 2 do
        begin
            Folders[I] := ParamStr(I + 1);
            if not TDirectory.Exists(Folders[I]) then
            begin
                Writeln('ERROR: folder not found: ', Folders[I]);
                Halt(2);
            end;
        end;

        if ParamCount >= 4 then
            OutputFile := ParamStr(4)
        else
            OutputFile := DEFAULT_OUTPUT_FILE;

        // 5-й аргумент - переопределение порога Prune (для отладки на
        // маленьких корпусах; на реальных данных порог 3 из ТЗ)
        PruneThreshold := PRUNE_THRESHOLD;
        if ParamCount >= 5 then
            PruneThreshold := StrToIntDef(ParamStr(5), PRUNE_THRESHOLD);

        Clf := TScriptLanguageClassifier.Create;
        try
            for I := 0 to 2 do
            begin
                Docs[I] := 0;
                Skipped[I] := 0;
                Files := CollectScripts(Folders[I], LANG_EXTS[I]);
                for F in Files do
                begin
                    Text := ReadTextAuto(F);

                    // Стерильность датасета: bat/bash-обертки вокруг
                    // powershell исключаем, иначе токены PowerShell
                    // запишутся в чужой профиль и граница языков сотрется
                    if (LANG_IDS[I] <> SNIPPET_LANG_POWERSHELL) and
                        TScriptLanguageClassifier.IsPowerShellWrapperScript(Text) then
                    begin
                        Inc(Skipped[I]);
                        Continue;
                    end;

                    Clf.TrainText(Text, LANG_IDS[I]);
                    Inc(Docs[I]);
                end;
            end;

            Clf.PruneRareWords(PruneThreshold);
            Clf.SaveToFile(OutputFile);

            Writeln('Trained naive Bayes model:');
            for I := 0 to 2 do
                Writeln(Format('  %-10s docs=%-4d vocab=%-5d skipped(wrapper)=%d',
                    [LANG_IDS[I], Docs[I], Clf.VocabSize(LANG_IDS[I]), Skipped[I]]));
            Writeln('Prune threshold : ', PruneThreshold);
            Writeln('Weights saved to: ', TPath.GetFullPath(OutputFile));
        finally
            Clf.Free;
        end;
    except
        on E: Exception do
        begin
            Writeln('ERROR: ', E.ClassName, ': ', E.Message);
            Halt(1);
        end;
    end;
end.
