unit Common.Localization;

interface

uses
    System.Classes,
    Vcl.Forms
    ;

type
    // Почему строка не найдена: по категории видно, что именно сломано
    // в языковом файле (нет ключа, нет промежуточного узла, битая маска Format)
    TLocalizationIssueKind = (likKeyNotFound, likInvalidStructure, likFormatError);

    // Один уникальный промах локализации с числом обращений
    TLocalizationIssue = record
        Key: string;
        Kind: TLocalizationIssueKind;
        Count: Integer;
    end;

    TUIStateLoader = class
    public
        // Загрузка файла в память (Вызывается 1 раз при старте приложения)
        class procedure LoadLanguageFile(const JsonFilePath: string);

        // Применение текстов к форме и её компонентам
        class procedure ApplyTranslations(Form: TCustomForm);

        // Получение любого системного текста по ключу (для ошибок, диалогов)
        class function GetMessage(const MessageKey: string): string; overload;
        class function GetMessage(const MessageKey: string; const Args: array of const): string; overload;

        class procedure GetHelpTexts(const BasePath: string; out Title, MainText, ExpText: string);

        // Диагностика отсутствующих строк. GetMessage - горячий путь (сотни
        // вызовов, в том числе из фоновых потоков), поэтому он никогда не
        // блокирует и ничего не показывает: промахи копятся здесь, а отчёт
        // показывает UI из главного потока (UI.Services.LocalizationDiagnostics)
        class function HasPendingLocalizationIssues: Boolean;
        class function TakePendingLocalizationIssues: TArray<TLocalizationIssue>;
        class procedure ClearPendingLocalizationIssues;
        class function LocalizationIssueKindName(AKind: TLocalizationIssueKind): string;
    end;

implementation

uses
    System.Generics.Collections,
    System.Generics.Defaults,
    System.IOUtils,
    System.JSON,
    System.SyncObjs,
    System.SysUtils,
    System.TypInfo,
    Vcl.ComCtrls;

const
    ERR_KEY_NOT_FOUND     = '[ERROR: Key "%s" not found]';
    ERR_INVALID_STRUCTURE = '[ERROR: Invalid JSON structure at token "%s" in key "%s"]';
    ERR_NO_LANGUAGE_DATA  = '[ERROR: Language data not initialized]';

    // Предел уникальных промахов в очереди: защита от лавины при ошибке
    // в цикле (например, рендер длинного списка одним битым ключом)
    MAX_PENDING_ISSUES = 512;

var
    // Текущий снапшот языкового файла. Читатели берут указатель и работают
    // с ним без блокировки, поэтому старые снапшоты не освобождаются при
    // перезагрузке, а уходят "в отставку" до финализации: иначе фоновый
    // поток мог бы прочитать указатель, а объект к этому моменту уже удалён
    // в главном потоке (переключение языка). Перезагрузка - редкое действие,
    // файлы небольшие, поэтому отложенное освобождение дешевле, чем лок
    // на каждом из сотен вызовов GetMessage
    GCachedLanguageData: TJSONObject = nil;
    GLanguageLock: TCriticalSection = nil;
    GRetiredLanguageData: TList<TJSONObject> = nil;

    // Накопитель промахов: лок берётся только на самом промахе и при выдаче
    // отчёта, горячий путь чтения остаётся без блокировок
    GPendingIssues: TDictionary<string, TLocalizationIssue> = nil;
    GPendingIssuesLock: TCriticalSection = nil;

function IssueMapKey(const AKey: string; AKind: TLocalizationIssueKind): string;
begin
    Result := IntToStr(Ord(AKind)) + '|' + AKey;
end;

// Записывает промах для последующего отчёта. Ничего не показывает и не
// блокирует вызывающий поток дольше короткой критической секции
procedure RecordLocalizationIssue(const AKey: string; AKind: TLocalizationIssueKind);
var
    MapKey: string;
    Item: TLocalizationIssue;
begin
    if (not Assigned(GPendingIssues)) or (AKey = '') then
        Exit;

    MapKey := IssueMapKey(AKey, AKind);

    GPendingIssuesLock.Enter;
    try
        if GPendingIssues.TryGetValue(MapKey, Item) then
        begin
            if Item.Count < High(Integer) then
                Inc(Item.Count);
            GPendingIssues.Items[MapKey] := Item;
        end
        else if GPendingIssues.Count < MAX_PENDING_ISSUES then
        begin
            Item.Key := AKey;
            Item.Kind := AKind;
            Item.Count := 1;
            GPendingIssues.Add(MapKey, Item);
        end;
    finally
        GPendingIssuesLock.Leave;
    end;
end;

class procedure TUIStateLoader.LoadLanguageFile(const JsonFilePath: string);
var
    JsonText: string;
    ParsedValue: TJSONValue;
    NewData: TJSONObject;
begin
    if not TFile.Exists(JsonFilePath) then
        Exit;

    // 1. Читаем файл
    JsonText := TFile.ReadAllText(JsonFilePath, TEncoding.UTF8);

    // 2. Убираем невидимый BOM-символ и лишние пробелы по краям
    JsonText := JsonText.Replace(#$FEFF, '').Trim;

    // 3. Пробуем распарсить в базовый TJSONValue
    ParsedValue := TJSONObject.ParseJSONValue(JsonText);

    // Если вернулся nil, значит в самом тексте JSON есть синтаксическая ошибка
    if not Assigned(ParsedValue) then
        raise Exception.Create('JSON syntax error! Please check the contents of ' + JsonFilePath + ' using jsonlint.com.');

    // 4. Проверяем, что корень файла - это именно Объект { ... }
    if not (ParsedValue is TJSONObject) then
    begin
        ParsedValue.Free;
        raise Exception.Create('JSON parsed successfully, but the root element is not an object { }!');
    end;

    NewData := TJSONObject(ParsedValue);

    // 5. Публикуем снапшот. Старый не освобождаем: его ещё могут читать
    // фоновые потоки. Ошибка парсинга выше оставляет рабочим предыдущий
    // файл - это лучше, чем остаться совсем без строк локализации
    GLanguageLock.Enter;
    try
        if Assigned(GCachedLanguageData) then
            GRetiredLanguageData.Add(GCachedLanguageData);
        GCachedLanguageData := NewData;
    finally
        GLanguageLock.Leave;
    end;
end;

class procedure TUIStateLoader.ApplyTranslations(Form: TCustomForm);
var
    Snapshot: TJSONObject;
    FormObj, CompObj: TJSONObject;
    PropPair, CompPropPair: TJSONPair;
    Comp: TComponent;
    ClassKey: string;

    // Внутренняя функция для установки свойств по точечному пути (например "EditLabel.Caption")
    procedure SetNestedPropValue(AObject: TObject; const Path: string; const Value: string);
    var
        Tokens: TArray<string>;
        I: Integer;
        CurrentObj: TObject;
        PropInfo: PPropInfo;
    begin
        if not Assigned(AObject) then Exit;

        Tokens := Path.Split(['.']);
        CurrentObj := AObject;

        // Спускаемся по дереву объектов (например, сначала берем объект EditLabel)
        for I := 0 to High(Tokens) - 1 do
        begin
            if not IsPublishedProp(CurrentObj, Tokens[I]) then Exit;
            // Получаем ссылку на вложенный объект
            CurrentObj := GetObjectProp(CurrentObj, Tokens[I]);
            if not Assigned(CurrentObj) then Exit;
        end;

        // Применяем значение к последнему свойству (например, Caption)
        if IsPublishedProp(CurrentObj, Tokens[High(Tokens)]) then
        begin
            // Проверка типа свойства: строку нельзя напрямую впихнуть в число и т.д.
            PropInfo := GetPropInfo(CurrentObj, Tokens[High(Tokens)]);
            if Assigned(PropInfo) and (PropInfo^.PropType^.Kind in [tkString, tkLString, tkWString, tkUString]) then
                SetPropValue(CurrentObj, Tokens[High(Tokens)], Value);
        end;
    end;

begin
    // Один указатель на снапшот: переключение языка посреди перевода формы
    // не должно давать полу-старый/полу-новый результат
    Snapshot := GCachedLanguageData;
    if not Assigned(Snapshot) then
        Exit;

    // Вытаскиваем имя класса (Например, 'TAddEditSnippetForm' -> 'AddEditSnippetForm')
    ClassKey := Form.ClassName;
    if ClassKey.StartsWith('T') then
        ClassKey := ClassKey.Substring(1);

    // Ищем блок с именем нашей формы (например, "MainForm")
    // Ищем сначала по имени класса (Надежно!), если не нашли - по имени экземпляра
    if Snapshot.TryGetValue<TJSONObject>(ClassKey, FormObj) or
       Snapshot.TryGetValue<TJSONObject>(Form.Name, FormObj) or
       Snapshot.TryGetValue<TJSONObject>(Form.ClassName, FormObj) then
    begin
        // Перебираем только те ключи, которые есть в JSON
        for PropPair in FormObj do
        begin
            // СЦЕНАРИЙ А: Значение является строкой -> Это свойство самой формы (например, Caption)
            if PropPair.JsonValue is TJSONString then
            begin
                SetNestedPropValue(Form, PropPair.JsonString.Value, PropPair.JsonValue.Value);
            end
            // СЦЕНАРИЙ Б: Значение является объектом -> Это настройки вложенного компонента
            else if PropPair.JsonValue is TJSONObject then
            begin
                CompObj := TJSONObject(PropPair.JsonValue);
                Comp := Form.FindComponent(PropPair.JsonString.Value); // Быстрый поиск компонента по имени
                {$IFDEF DEBUG}
                if not Assigned(Comp) then
                begin
                    raise Exception.Create(TUIStateLoader.GetMessage('Common.DebugComponentNotFound', [PropPair.JsonString.Value]));
                end;
                {$ENDIF}

                if Assigned(Comp) then
                begin
                    // Обработка колонок TListView через tag
                    if (Comp is TListView) and (CompObj.GetValue('Columns') is TJSONObject) then
                    begin
                        var ColObj := TJSONObject(CompObj.GetValue('Columns'));
                        var LV := TListView(Comp);
                        for var ColPair in ColObj do
                        begin
                            var ColTag: Integer;
                            if TryStrToInt(ColPair.JsonString.Value, ColTag) then
                                for var I := 0 to LV.Columns.Count - 1 do
                                    if LV.Columns[I].Tag = ColTag then
                                    begin
                                        LV.Columns[I].Caption := ColPair.JsonValue.Value;
                                        Break;
                                    end;
                        end;
                    end;
                    // ---------------------------------------------
                    //Применяем стандартные свойства к компоненту
                    for CompPropPair in CompObj do
                    begin
                        if CompPropPair.JsonString.Value <> 'Columns' then // Игнорируем узел колонок
                        begin
                            // Используем новую функцию для применения свойства
                            SetNestedPropValue(Comp, CompPropPair.JsonString.Value, CompPropPair.JsonValue.Value);
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

class procedure TUIStateLoader.GetHelpTexts(const BasePath: string; out Title, MainText, ExpText: string);
var
    Snapshot: TJSONObject;
    MessagesVal, CurrentVal: TJSONValue;
    CurrentObj: TJSONObject;
    Tokens: TArray<string>;
    I: Integer;

    // Локальная функция для безопасного извлечения строк с учетом переносов \n
    function ExtractStr(Obj: TJSONObject; const PropName, DefaultVal: string): string;
    var
        Val: TJSONValue;
    begin
        Val := Obj.GetValue(PropName);
        if Assigned(Val) and (Val is TJSONString) then
            Result := StringReplace(Val.Value, '\n', #13#10, [rfReplaceAll])
        else
            Result := DefaultVal;
    end;

begin
    // Задаем безопасные значения по умолчанию
    Title := 'Help';
    MainText := 'Help text not found.';
    ExpText := '';

    Snapshot := GCachedLanguageData;
    if not Assigned(Snapshot) then Exit;

    // 1. Входим в корень "Messages"
    MessagesVal := Snapshot.GetValue('Messages');
    if not (MessagesVal is TJSONObject) then Exit;

    CurrentObj := TJSONObject(MessagesVal);
    Tokens := BasePath.Split(['.']);

    // 2. Спускаемся по дереву ДО САМОГО КОНЦА (теперь цикл идет до High(Tokens))
    for I := 0 to High(Tokens) do
    begin
        CurrentVal := CurrentObj.GetValue(Tokens[I]);

        if not Assigned(CurrentVal) then
        begin
{$IFDEF DEBUG}
            raise Exception.Create('ERROR: Cannot find key "' + Tokens[I] + '"!' + sLineBreak +
                        'Current object contents:' + sLineBreak +
                        CurrentObj.ToString);
{$ENDIF}
            Exit;
        end;

        if not (CurrentVal is TJSONObject) then
        begin
{$IFDEF DEBUG}
            raise Exception.Create('ERROR: Key "' + Tokens[I] + '" found, but it is NOT an object (possibly already a string?)');
{$ENDIF}
            Exit;
        end;

        CurrentObj := TJSONObject(CurrentVal);
    end;

    Title    := ExtractStr(CurrentObj, 'Title', Title);
    MainText := ExtractStr(CurrentObj, 'Main', MainText);
    ExpText  := ExtractStr(CurrentObj, 'Expanded', ExpText);
end;

class function TUIStateLoader.GetMessage(const MessageKey: string; const Args: array of const): string;
var
    Mask: string;
begin
    // 1. Получаем маску или текст ошибки
    Mask := GetMessage(MessageKey);

    // 2. Защита: Если ключа нет в JSON, сразу возвращаем ошибку, не пытаясь форматировать
    // (иначе Format мог бы ругнуться на несовпадение параметров)
    if Mask.StartsWith('[ERROR:') then
    begin
        Result := Mask;
        Exit;
    end;

    // 3. Пытаемся подставить параметры
    try
        Result := Format(Mask, Args);
    except
        on E: Exception do
        begin
            // Если переводчик ошибся (например, написал %d вместо %s)
            Result := '[FORMAT ERROR: ' + MessageKey + ']';
            RecordLocalizationIssue(MessageKey, likFormatError);
        end;
    end;
end;

class function TUIStateLoader.GetMessage(const MessageKey: string): string;
var
    Snapshot: TJSONObject;
    MessagesVal, CurrentVal: TJSONValue;
    CurrentObj: TJSONObject;
    Tokens: TArray<string>;
    I: Integer;
begin
    // По умолчанию считаем, что ключа вообще нет
    Result := Format(ERR_KEY_NOT_FOUND, [MessageKey]);

    // Один локальный указатель на снапшот: живой объект, пока мы его читаем
    Snapshot := GCachedLanguageData;
    if not Assigned(Snapshot) then
    begin
        // Файл ещё не загружен - это не промах ключа, записывать нечего
        Result := ERR_NO_LANGUAGE_DATA;
        Exit;
    end;

    // 1. Входим в корневой узел "Messages"
    MessagesVal := Snapshot.GetValue('Messages');
    if not (MessagesVal is TJSONObject) then
    begin
        Result := '[ERROR: Root node "Messages" is missing or not an object]';
        Exit;
    end;

    CurrentObj := TJSONObject(MessagesVal);

    // 2. Разбираем ключ на массив токенов
    Tokens := MessageKey.Split(['.']);
    if Length(Tokens) = 0 then
        Exit;

    // 3. Динамически спускаемся по дереву объектов до предпоследнего узла
    for I := 0 to High(Tokens) - 1 do
    begin
        CurrentVal := CurrentObj.GetValue(Tokens[I]);

        if Assigned(CurrentVal) and (CurrentVal is TJSONString) then
        begin
            // Ошибка: мы ждали объект (чтобы идти дальше по точке), а там оказалась строка!
            Result := Format('[ERROR: Token "%s" in key "%s" is a string, expected an object]', [Tokens[I], MessageKey]);
            RecordLocalizationIssue(MessageKey, likInvalidStructure);
            Exit;
        end;

        if Assigned(CurrentVal) and (CurrentVal is TJSONObject) then
            CurrentObj := TJSONObject(CurrentVal)
        else
        begin
            // Ошибка: такого токена вообще нет в этом объекте
            Result := Format(ERR_INVALID_STRUCTURE, [Tokens[I], MessageKey]);
            RecordLocalizationIssue(MessageKey, likInvalidStructure);
            Exit;
        end;
    end;

    // 4. Мы дошли до целевого объекта. Извлекаем из него конечное значение
    CurrentVal := CurrentObj.GetValue(Tokens[High(Tokens)]);

    if Assigned(CurrentVal) then
    begin
        // Если дошли сюда — всё супер, перезаписываем Result правильным переводом
        if CurrentVal is TJSONString then
        begin
            Result := CurrentVal.Value;
            Result := StringReplace(Result, '\n', #13#10, [rfReplaceAll]);
        end
        else
            Result := CurrentVal.ToString;
    end
    else
    begin
        Result := Format(ERR_KEY_NOT_FOUND, [MessageKey]);
        RecordLocalizationIssue(MessageKey, likKeyNotFound);
    end;
end;

class function TUIStateLoader.HasPendingLocalizationIssues: Boolean;
begin
    Result := False;
    if not Assigned(GPendingIssues) then
        Exit;

    GPendingIssuesLock.Enter;
    try
        Result := GPendingIssues.Count > 0;
    finally
        GPendingIssuesLock.Leave;
    end;
end;

class function TUIStateLoader.TakePendingLocalizationIssues: TArray<TLocalizationIssue>;
var
    Pair: TPair<string, TLocalizationIssue>;
    List: TList<TLocalizationIssue>;
begin
    Result := nil;
    if not Assigned(GPendingIssues) then
        Exit;

    List := TList<TLocalizationIssue>.Create;
    try
        GPendingIssuesLock.Enter;
        try
            for Pair in GPendingIssues do
                List.Add(Pair.Value);
            GPendingIssues.Clear;
        finally
            GPendingIssuesLock.Leave;
        end;

        Result := List.ToArray;

        // Детерминированный порядок отчёта: сначала частые промахи,
        // затем по алфавиту - так тесты и лог не зависят от хеширования
        if Length(Result) > 1 then
          TArray.Sort<TLocalizationIssue>(Result,
            TComparer<TLocalizationIssue>.Construct(
                function(const Left, Right: TLocalizationIssue): Integer
                begin
                    Result := Right.Count - Left.Count;
                    if Result = 0 then
                        Result := CompareText(Left.Key, Right.Key);
                end));
    finally
        List.Free;
    end;
end;

class procedure TUIStateLoader.ClearPendingLocalizationIssues;
begin
    if not Assigned(GPendingIssues) then
        Exit;

    GPendingIssuesLock.Enter;
    try
        GPendingIssues.Clear;
    finally
        GPendingIssuesLock.Leave;
    end;
end;

class function TUIStateLoader.LocalizationIssueKindName(AKind: TLocalizationIssueKind): string;
begin
    case AKind of
        likKeyNotFound:      Result := 'key not found';
        likInvalidStructure: Result := 'invalid JSON structure';
        likFormatError:      Result := 'format error';
    else
        Result := 'unknown';
    end;
end;

initialization
    GLanguageLock := TCriticalSection.Create;
    GRetiredLanguageData := TList<TJSONObject>.Create;
    GPendingIssuesLock := TCriticalSection.Create;
    GPendingIssues := TDictionary<string, TLocalizationIssue>.Create;

finalization
    // Снапшоты освобождаются только здесь: к моменту финализации фоновых
    // читателей уже нет (Core.Shutdown останавливает макропоток, синхронизация
    // дожидается завершения до выхода из Application.Run)
    if Assigned(GPendingIssues) then
        FreeAndNil(GPendingIssues);
    if Assigned(GPendingIssuesLock) then
        FreeAndNil(GPendingIssuesLock);

    if Assigned(GRetiredLanguageData) then
    begin
        for var Retired in GRetiredLanguageData do
            Retired.Free;
        FreeAndNil(GRetiredLanguageData);
    end;

    if Assigned(GCachedLanguageData) then
        FreeAndNil(GCachedLanguageData);
    if Assigned(GLanguageLock) then
        FreeAndNil(GLanguageLock);

end.
