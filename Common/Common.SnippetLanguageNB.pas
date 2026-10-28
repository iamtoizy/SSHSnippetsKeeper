unit Common.SnippetLanguageNB;

// Наивный Байесовский классификатор языков скриптов (bash / bat / powershell).
//
// Математика (фиксированные требования):
//   1. Сглаживание Лапласа: P(word|lang) = (Count + 1) / (TotalTokens + VocabSize) -
//      неизвестные слова не обнуляют общую вероятность.
//   2. Логарифмы: вероятности логарифмируются (Log2) и СКЛАДЫВАЮТСЯ - нет
//      underflow. Оценка языка - IDF-взвешенный подъём лог-правдоподобия
//      совпавших токенов над базовым уровнем unseen-токена (иначе язык с
//      большим числом совпадений получал бы более отрицательный счёт).
//   3. Без априорных вероятностей (LogPrior = 0): размер выборки не влияет на
//      прогноз, учитывается только содержимое самого текста (TF).
//   4. TF-IDF: вклад каждого токена умножается на IDF(w, lang) =
//      Log2((DocCount + 1) / (DocFreq + 1)) - штраф словам-универсалиям внутри
//      языка (встречаются почти в каждом документе), бонус редким маркерным.
//
// Токенизатор: проход по тексту через PWideChar без Split/TStringList и без
// промежуточных массивов строк; токены сразу в нижнем регистре.
//
// Имена языков - произвольные строки (классификатор агностичен); тренер и
// приложение передают канонические идентификаторы из Common.SnippetLanguages.

interface

uses
    System.Character,
    System.Classes,
    System.Generics.Collections,
    System.IOUtils,
    System.Math,
    System.SysUtils
    ;

const
    NB_FORMAT_VERSION = 1;
    NB_MAGIC = 'SSKNBW01';

    // Файл весов по умолчанию (лежит рядом с exe)
    NB_DEFAULT_WEIGHTS_FILE = 'scripts_weights.bin';

    // Токены короче 2 символов - шум (переменные 'f', 'x', знаки);
    // операторные токены ('|', '&&', '>>') исключение - не обрезаются
    MIN_TOKEN_LEN = 2;
    // Длинные токены (base64-хвосты и т.п.) обрезаются - для языка не важны
    MAX_TOKEN_LEN = 48;

    // Порог уверенности: максимальный счёт ниже этого значения - доказательство
    // слишком слабое (типично для однострочников) - сдаемся, язык по умолчанию
    NB_DEFAULT_MIN_EVIDENCE = 3.0;
    // Порог уверенности: отрыв лидера от второго места меньше этого значения -
    // уверенного перевеса нет - сдаемся
    NB_DEFAULT_MIN_MARGIN = 1.0;

type
    EScriptLangNBError = class(Exception);

    TLangScore = record
        Language: string;
        Score: Double; // взвешенное лог-правдоподобие (больше = лучше)
        Prob: Double;  // софтмакс для отображения (сумма по языкам = 1)
    end;

    TTokenEvent = reference to procedure(const AToken: string);

    TWordStat = record
        Count: Int64;   // суммарное число вхождений в корпусе языка (TF)
        DocFreq: Int64; // в скольких документах языка встретилось (для IDF)
    end;

    TLangModel = class
        Name: string;
        DocCount: Int64;
        TotalTokens: Int64;
        Words: TDictionary<string, TWordStat>;
        constructor Create(const AName: string);
        destructor Destroy; override;
    end;

    TScriptLanguageClassifier = class
    private
        FLangs: TObjectDictionary<string, TLangModel>;
        FMinEvidence: Double;
        FMinMargin: Double;
        // Ленивый кэш на процесс: weights читаются с диска один раз,
        // формы и сервисы не владеют экземпляром и не освобождают его
        class var FShared: TScriptLanguageClassifier;
        function GetOrCreateLang(const AName: string): TLangModel;
        function PredictInternal(const AText: string;
            out AScores: TArray<TLangScore>; out AMatchedTokens: Integer): Boolean;
    public
        constructor Create;
        destructor Destroy; override;

        // Общий экземпляр: при первом обращении читает NB_DEFAULT_WEIGHTS_FILE
        // из папки exe; без файла или с битым файлом остаётся необученным
        // (PredictLanguage = ''), исключение наружу не пробрасывается
        class function Shared: TScriptLanguageClassifier;

        // Быстрый PChar-токенизатор: слова с приклеенными '-'/'$' (get-process,
        // -name, $var) + операторные последовательности ('|', '||', '&&', '>>',
        // '>&' из '2>&1') как самостоятельные токены. Публичен для тестов.
        class procedure ForEachToken(const AText: string; const AOnToken: TTokenEvent); static;

        // Wrapper-скрипты (bat, оборачивающий powershell -c "...") загрязняют
        // профиль bat токенами PowerShell - для обучения датасет стерилен:
        // такие файлы тренер исключает. Сам классификатор на предсказании их
        // НЕ фильтрует: побеждает язык основной массы токенов (для подсветки
        // TSynEdit это корректно - подсвечивается основная логика).
        class function IsPowerShellWrapperScript(const AText: string): Boolean; static;

        // Обучение на одном документе
        procedure TrainText(const AText: string; const ALanguage: string);

        // Удаление слов с Count < MinOccurrences (анти-переобучение на именах
        // пользовательских переменных); TotalTokens пересчитывается
        procedure PruneRareWords(MinOccurrences: Integer);

        // Оценки по всем языкам, отсортированы по убыванию Score
        function PredictScores(const AText: string): TArray<TLangScore>;

        // Канонический id языка-победителя или '' (нет модели / нет знакомых токенов)
        function PredictLanguage(const AText: string): string;

        function IsTrained: Boolean;
        function VocabSize(const ALanguage: string): Integer;
        function DocumentCount(const ALanguage: string): Int64;

        // Пороги уверенности PredictLanguage (см. константы NB_DEFAULT_*)
        property MinEvidence: Double read FMinEvidence write FMinEvidence;
        property MinMargin: Double read FMinMargin write FMinMargin;

        // Бинарная сериализация через TBinaryWriter/TBinaryReader (без JSON)
        procedure SaveToFile(const AFileName: string);
        procedure LoadFromFile(const AFileName: string);
    end;

implementation

function IsWordCharW(C: WideChar): Boolean; inline;
begin
    // ASCII-быстрый путь: буквы/цифры/'_' + сигил '$' и дефис '-':
    // 'Get-Process', '-name', '$var' остаются ЦЕЛЫМИ токенами - это
    // сильнейшие маркеры PowerShell; '$1' - маркер bash. Прочее
    // (включая кириллицу) - через TCharacter; '%' - разделитель.
    if ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or
        ((C >= '0') and (C <= '9')) or (C = '_') or (C = '-') or (C = '$') then
        Exit(True);
    Result := (Ord(C) >= $80) and TCharacter.IsLetterOrDigit(C);
end;

// Операторные символы: извлекаются последовательностями ('|', '||', '&&',
// '>>', '>&' из '2>&1') как самостоятельные токены - в скриптах они
// несут колоссальный IDF-вес
function IsOpCharW(C: WideChar): Boolean; inline;
begin
    Result := (C = '|') or (C = '&') or (C = '>') or (C = '<') or (C = '!');
end;

{ TLangModel }

constructor TLangModel.Create(const AName: string);
begin
    inherited Create;
    Name := AName;
    Words := TDictionary<string, TWordStat>.Create;
end;

destructor TLangModel.Destroy;
begin
    Words.Free;
    inherited;
end;

{ TScriptLanguageClassifier }

constructor TScriptLanguageClassifier.Create;
begin
    inherited Create;
    FLangs := TObjectDictionary<string, TLangModel>.Create([doOwnsValues]);
    FMinEvidence := NB_DEFAULT_MIN_EVIDENCE;
    FMinMargin := NB_DEFAULT_MIN_MARGIN;
end;

destructor TScriptLanguageClassifier.Destroy;
begin
    FLangs.Free;
    inherited;
end;

class function TScriptLanguageClassifier.Shared: TScriptLanguageClassifier;
var
    ExeDir, WeightsPath: string;
begin
    if FShared = nil then
    begin
        FShared := TScriptLanguageClassifier.Create;
        try
            // Тот же порядок поиска, что и у Common.Helpers.ResolvePath:
            // сначала рядом с exe, затем дев-папка Assets\ExeData
            ExeDir := TPath.GetDirectoryName(ParamStr(0));
            WeightsPath := TPath.Combine(ExeDir, NB_DEFAULT_WEIGHTS_FILE);
            if not FileExists(WeightsPath) then
                WeightsPath := ExpandFileName(TPath.Combine(ExeDir,
                    '..\..\..\Assets\ExeData\' + NB_DEFAULT_WEIGHTS_FILE));
            FShared.LoadFromFile(WeightsPath);
        except
            // Нет файла / чужой формат - детектор просто необучен,
            // вызывающий код уходит в эвристический fallback
            on E: Exception do ;
        end;
    end;
    Result := FShared;
end;

function TScriptLanguageClassifier.GetOrCreateLang(const AName: string): TLangModel;
begin
    if not FLangs.TryGetValue(AName, Result) then
    begin
        Result := TLangModel.Create(AName);
        FLangs.Add(AName, Result);
    end;
end;

class procedure TScriptLanguageClassifier.ForEachToken(const AText: string;
    const AOnToken: TTokenEvent);
var
    P, Start: PWideChar;
    Buf: array[0..MAX_TOKEN_LEN - 1] of WideChar;
    Len: Integer;
    C, LC: WideChar;
    Token: string;
begin
    if AText = '' then
        Exit;

    P := PWideChar(AText);
    while P^ <> #0 do
    begin
        // 1. Слово (с приклеенными '-' и '$')
        if IsWordCharW(P^) then
        begin
            Len := 0;
            while IsWordCharW(P^) do
            begin
                if Len < MAX_TOKEN_LEN then
                begin
                    C := P^;
                    if (C >= 'A') and (C <= 'Z') then
                        LC := WideChar(Word(C) + $20)
                    else if C < #$00C0 then
                        LC := C // ASCII вне 'A'..'Z' менять не нужно
                    else
                        LC := TCharacter.ToLower(C);
                    Buf[Len] := LC;
                    Inc(Len);
                end;
                Inc(P);
            end;
            if Len >= MIN_TOKEN_LEN then
            begin
                SetString(Token, Buf, Len); // одна аллокация на токен
                AOnToken(Token);
            end;
            Continue;
        end;

        // 2. Операторная последовательность: без порога длины, целиком
        if IsOpCharW(P^) then
        begin
            Start := P;
            while IsOpCharW(P^) do
                Inc(P);
            SetString(Token, Start, P - Start);
            AOnToken(Token);
            Continue;
        end;

        // 3. Прочие разделители
        Inc(P);
    end;
end;

class function TScriptLanguageClassifier.IsPowerShellWrapperScript(const AText: string): Boolean;
begin
    // Строгий критерий стерильности датасета: любое упоминание вызова
    // powershell/pwsh ('powershell -c ...', 'powershell.exe -file ...')
    Result := (Pos('POWERSHELL', UpperCase(AText)) > 0) or
        (Pos('PWSH', UpperCase(AText)) > 0);
end;

procedure TScriptLanguageClassifier.TrainText(const AText: string; const ALanguage: string);
var
    Lang: TLangModel;
    DocTf: TDictionary<string, Integer>;
    Pair: TPair<string, Integer>;
    Stat: TWordStat;
begin
    if Trim(AText) = '' then
        Exit;

    // TF документа: различаем типы токенов один раз за документ (для DocFreq)
    DocTf := TDictionary<string, Integer>.Create;
    try
        ForEachToken(AText,
            procedure(const AToken: string)
            var
                Cnt: Integer;
            begin
                if DocTf.TryGetValue(AToken, Cnt) then
                    DocTf.AddOrSetValue(AToken, Cnt + 1)
                else
                    DocTf.AddOrSetValue(AToken, 1);
            end);

        if DocTf.Count = 0 then
            Exit;

        Lang := GetOrCreateLang(ALanguage);
        Lang.DocCount := Lang.DocCount + 1;

        for Pair in DocTf do
        begin
            if Lang.Words.TryGetValue(Pair.Key, Stat) then
            begin
                Stat.Count := Stat.Count + Pair.Value;
                Stat.DocFreq := Stat.DocFreq + 1;
            end
            else
            begin
                Stat.Count := Pair.Value;
                Stat.DocFreq := 1;
            end;
            Lang.Words.AddOrSetValue(Pair.Key, Stat);
            Inc(Lang.TotalTokens, Pair.Value);
        end;
    finally
        DocTf.Free;
    end;
end;

procedure TScriptLanguageClassifier.PruneRareWords(MinOccurrences: Integer);
var
    Lang: TLangModel;
    Dead: TList<string>;
    Pair: TPair<string, TWordStat>;
    W: string;
    Total: Int64;
begin
    for Lang in FLangs.Values do
    begin
        // Удалять во время перечисления нельзя - сначала собираем список
        Dead := TList<string>.Create;
        try
            for Pair in Lang.Words do
                if Pair.Value.Count < MinOccurrences then
                    Dead.Add(Pair.Key);
            for W in Dead do
                Lang.Words.Remove(W);
        finally
            Dead.Free;
        end;

        Total := 0;
        for Pair in Lang.Words do
            Inc(Total, Pair.Value.Count);
        Lang.TotalTokens := Total;
    end;
end;

function TScriptLanguageClassifier.PredictInternal(const AText: string;
    out AScores: TArray<TLangScore>; out AMatchedTokens: Integer): Boolean;
var
    DocTf: TDictionary<string, Integer>;
    DocPair: TPair<string, Integer>;
    Lang: TLangModel;
    Stat: TWordStat;
    Score, IDF, LL, LLFloor, MaxScore, SumExp: Double;
    Tmp: TLangScore;
    LangMatched, I, N: Integer;
begin
    Result := False;
    AScores := nil;
    AMatchedTokens := 0;

    if (FLangs.Count = 0) or (Trim(AText) = '') then
        Exit;

    // TF текста: частоты типов токенов внутри предсказываемого документа
    DocTf := TDictionary<string, Integer>.Create;
    try
        ForEachToken(AText,
            procedure(const AToken: string)
            var
                Cnt: Integer;
            begin
                if DocTf.TryGetValue(AToken, Cnt) then
                    DocTf.AddOrSetValue(AToken, Cnt + 1)
                else
                    DocTf.AddOrSetValue(AToken, 1);
            end);

        if DocTf.Count = 0 then
            Exit;

        SetLength(AScores, FLangs.Count);
        I := 0;
        for Lang in FLangs.Values do
        begin
            Score := 0;
            LangMatched := 0;
            // Базовый уровень вероятности unseen-токена (знаменатель с Лапласом)
            LLFloor := Log2(1 / (Lang.TotalTokens + Lang.Words.Count));
            if Lang.Words.Count > 0 then
                for DocPair in DocTf do
                    if Lang.Words.TryGetValue(DocPair.Key, Stat) then
                    begin
                        // TF-IDF: штраф универсальным словам языка
                        IDF := Log2((Lang.DocCount + 1) / (Stat.DocFreq + 1));
                        // Лаплас: P(w|lang) = (Count + 1) / (TotalTokens + Vocab);
                        // сравнение с уровнем unseen даёт ПОЛОЖИТЕЛЬНЫЙ подъём
                        // доказательства - больше совпадений = лучше язык
                        LL := Log2((Stat.Count + 1) / (Lang.TotalTokens + Lang.Words.Count));
                        Score := Score + IDF * (LL - LLFloor) * DocPair.Value;
                        Inc(LangMatched, DocPair.Value);
                    end;
            // Язык без единого совпадения не может выигрывать "по умолчанию":
            // в лог-шкале 0 выше любого честного (отрицательного) счёта
            if LangMatched = 0 then
                Score := NegInfinity;
            AScores[I].Language := Lang.Name;
            AScores[I].Score := Score;
            AScores[I].Prob := 0;
            Inc(I);
        end;

        // Сколько токенов текста вообще знакомы хоть одному языку
        for DocPair in DocTf do
        begin
            for Lang in FLangs.Values do
                if Lang.Words.ContainsKey(DocPair.Key) then
                begin
                    Inc(AMatchedTokens, DocPair.Value);
                    Break;
                end;
        end;

        // Сортировка по убыванию (языков мало - пузырёк дешевле общего рода)
        for I := 0 to High(AScores) - 1 do
            for N := I + 1 to High(AScores) do
                if AScores[N].Score > AScores[I].Score then
                begin
                    Tmp := AScores[I];
                    AScores[I] := AScores[N];
                    AScores[N] := Tmp;
                end;

        // Софтмакс только для отображения; сами Score уже логарифмы
        MaxScore := AScores[0].Score;
        if MaxScore = NegInfinity then
            Exit(True); // совпадений нет ни у кого - вероятности оставляем нулями
        for I := 1 to High(AScores) do
            if AScores[I].Score > MaxScore then
                MaxScore := AScores[I].Score;
        SumExp := 0;
        for I := 0 to High(AScores) do
        begin
            AScores[I].Prob := Exp(AScores[I].Score - MaxScore);
            SumExp := SumExp + AScores[I].Prob;
        end;
        if SumExp > 0 then
            for I := 0 to High(AScores) do
                AScores[I].Prob := AScores[I].Prob / SumExp;

        Result := True;
    finally
        DocTf.Free;
    end;
end;

function TScriptLanguageClassifier.PredictScores(const AText: string): TArray<TLangScore>;
var
    Matched: Integer;
begin
    if not PredictInternal(AText, Result, Matched) then
        Result := nil;
end;

function TScriptLanguageClassifier.PredictLanguage(const AText: string): string;
var
    Scores: TArray<TLangScore>;
    Matched: Integer;
begin
    Result := '';
    // Полностью незнакомый текст не классифицируем - пусть решает эвристика
    if not PredictInternal(AText, Scores, Matched) then
        Exit;
    if (Matched = 0) or (Length(Scores) = 0) then
        Exit;

    // Порог уверенности (однострочники/слабое доказательство):
    // 1) абсолютный счёт лидера слишком мал - перевод мал;
    // 2) отрыв от второго места минимален - перевес неуверенный.
    // В обоих случаях сдаемся: вызывающий код применит дефолт (bash)
    if Scores[0].Score < FMinEvidence then
        Exit;
    if (Length(Scores) > 1) and (Scores[0].Score - Scores[1].Score < FMinMargin) then
        Exit;

    Result := Scores[0].Language; // после сортировки лидер первый
end;

function TScriptLanguageClassifier.IsTrained: Boolean;
var
    Lang: TLangModel;
begin
    Result := False;
    for Lang in FLangs.Values do
        if Lang.DocCount > 0 then
            Exit(True);
end;

function TScriptLanguageClassifier.VocabSize(const ALanguage: string): Integer;
var
    Lang: TLangModel;
begin
    Result := 0;
    if FLangs.TryGetValue(ALanguage, Lang) then
        Result := Lang.Words.Count;
end;

function TScriptLanguageClassifier.DocumentCount(const ALanguage: string): Int64;
var
    Lang: TLangModel;
begin
    Result := 0;
    if FLangs.TryGetValue(ALanguage, Lang) then
        Result := Lang.DocCount;
end;

procedure TScriptLanguageClassifier.SaveToFile(const AFileName: string);
var
    FS: TFileStream;
    BW: TBinaryWriter;
    MagicBytes: TBytes;
    Lang: TLangModel;
    Pair: TPair<string, TWordStat>;
begin
    if ExtractFilePath(AFileName) <> '' then
        ForceDirectories(ExtractFilePath(AFileName));

    FS := TFileStream.Create(AFileName, fmCreate);
    try
        // AOwnsStream = False: стримом управляет внешний try..finally
        BW := TBinaryWriter.Create(FS, TEncoding.UTF8, False);
        try
            // Магию пишем напрямую через стрим - не зависим от поведения
            // Write(TBytes) у TBinaryWriter
            MagicBytes := TEncoding.ASCII.GetBytes(NB_MAGIC);
            FS.WriteBuffer(MagicBytes[0], Length(MagicBytes));
            // Все числа - с ЯВНЫМ типом: разрешение перегрузок Write у
            // TBinaryWriter для нетипизированных/Integer значений нестабильно
            // (нетипизированная константа уходила в Write(Byte), Integer -
            // в Write(Int64), ломая формат)
            BW.Write(Int32(NB_FORMAT_VERSION));
            BW.Write(Int32(FLangs.Count));
            for Lang in FLangs.Values do
            begin
                BW.Write(Lang.Name);
                BW.Write(Int64(Lang.DocCount));
                BW.Write(Int64(Lang.TotalTokens));
                BW.Write(Int32(Lang.Words.Count));
                for Pair in Lang.Words do
                begin
                    BW.Write(Pair.Key);
                    BW.Write(Int64(Pair.Value.Count));
                    BW.Write(Int64(Pair.Value.DocFreq));
                end;
            end;
        finally
            BW.Free;
        end;
    finally
        FS.Free;
    end;
end;

procedure TScriptLanguageClassifier.LoadFromFile(const AFileName: string);
var
    FS: TFileStream;
    BR: TBinaryReader;
    MagicBytes: TBytes;
    NLangs, NWords, I, J: Integer;
    LangName, W: string;
    Lang: TLangModel;
    Stat: TWordStat;
begin
    FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
        // AOwnsStream = False: стримом управляет внешний try..finally
        BR := TBinaryReader.Create(FS, TEncoding.UTF8, False);
        try
            // Магию читаем напрямую через стрим (см. SaveToFile)
            MagicBytes := TEncoding.ASCII.GetBytes(NB_MAGIC);
            FS.ReadBuffer(MagicBytes[0], Length(MagicBytes));
            if TEncoding.ASCII.GetString(MagicBytes) <> NB_MAGIC then
                raise EScriptLangNBError.Create('NB weights: invalid magic in ' + AFileName);
            if BR.ReadInt32 <> NB_FORMAT_VERSION then
                raise EScriptLangNBError.Create('NB weights: unsupported format version in ' + AFileName);

            // Битый файл не должен оставлять наполовину загруженную модель
            FLangs.Clear;
            try
                NLangs := BR.ReadInt32;
                if NLangs < 0 then
                    raise EScriptLangNBError.Create('NB weights: corrupted language count');

                for I := 0 to NLangs - 1 do
                begin
                    LangName := BR.ReadString;
                    Lang := TLangModel.Create(LangName);
                    try
                        Lang.DocCount := BR.ReadInt64;
                        Lang.TotalTokens := BR.ReadInt64;
                        NWords := BR.ReadInt32;
                        if NWords < 0 then
                            raise EScriptLangNBError.Create('NB weights: corrupted word count');
                        for J := 0 to NWords - 1 do
                        begin
                            W := BR.ReadString;
                            Stat.Count := BR.ReadInt64;
                            Stat.DocFreq := BR.ReadInt64;
                            Lang.Words.Add(W, Stat);
                        end;
                    except
                        Lang.Free;
                        raise;
                    end;
                    FLangs.Add(LangName, Lang);
                end;
            except
                FLangs.Clear;
                raise;
            end;
        finally
            BR.Free;
        end;
    finally
        FS.Free;
    end;
end;

initialization

finalization
    // Общие веса живут ровно столько, сколько процесс
    FreeAndNil(TScriptLanguageClassifier.FShared);

end.
