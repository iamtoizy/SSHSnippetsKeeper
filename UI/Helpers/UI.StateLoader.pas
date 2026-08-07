unit UI.StateLoader;

interface

uses
    System.Classes,
    Vcl.Forms
    ;

type
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
    end;

implementation

uses
    System.IOUtils,
    System.JSON,
    System.SysUtils,
    System.TypInfo,
    Vcl.ComCtrls,
    Vcl.Dialogs;

var
    // Глобальный кэш языкового файла в оперативной памяти
    GCachedLanguageData: TJSONObject = nil;

class procedure TUIStateLoader.LoadLanguageFile(const JsonFilePath: string);
var
    JsonText: string;
    ParsedValue: TJSONValue;
begin
    if not TFile.Exists(JsonFilePath) then
        Exit;

    if Assigned(GCachedLanguageData) then
        FreeAndNil(GCachedLanguageData);

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

    // 5. Всё отлично, кэшируем
    GCachedLanguageData := TJSONObject(ParsedValue);
end;

class procedure TUIStateLoader.ApplyTranslations(Form: TCustomForm);
var
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
    if not Assigned(GCachedLanguageData) then
        Exit;

    // Вытаскиваем имя класса (Например, 'TAddEditSnippetForm' -> 'AddEditSnippetForm')
    ClassKey := Form.ClassName;
    if ClassKey.StartsWith('T') then
        ClassKey := ClassKey.Substring(1);

    // Ищем блок с именем нашей формы (например, "MainForm")
    // Ищем сначала по имени класса (Надежно!), если не нашли - по имени экземпляра
    if GCachedLanguageData.TryGetValue<TJSONObject>(ClassKey, FormObj) or
       GCachedLanguageData.TryGetValue<TJSONObject>(Form.Name, FormObj) or
       GCachedLanguageData.TryGetValue<TJSONObject>(Form.ClassName, FormObj) then
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
                    raise Exception.Create('Компонент не найден на форме: ' + PropPair.JsonString.Value);
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
                    // Применяем стандартные свойства к компоненту
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

    if not Assigned(GCachedLanguageData) then Exit;

    // 1. Входим в корень "Messages"
    MessagesVal := GCachedLanguageData.GetValue('Messages');
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
            // Если переводчик ошибся (например, написал %d вместо %s)
            Result := '[FORMAT ERROR: ' + MessageKey + ']';
    end;
end;

class function TUIStateLoader.GetMessage(const MessageKey: string): string;
const
    ERR_KEY_NOT_FOUND     = '[ERROR: Key "%s" not found]';
    ERR_INVALID_STRUCTURE = '[ERROR: Invalid JSON structure at token "%s" in key "%s"]';
    ERR_NOT_A_STRING      = '[ERROR: Value for key "%s" is not a string]';
var
    MessagesVal, CurrentVal: TJSONValue;
    CurrentObj: TJSONObject;
    Tokens: TArray<string>;
    I: Integer;
begin
    // По умолчанию считаем, что ключа вообще нет
    Result := Format(ERR_KEY_NOT_FOUND, [MessageKey]);

    if not Assigned(GCachedLanguageData) then
    begin
        Result := '[ERROR: Language data not initialized]';
        Exit;
    end;

    // 1. Входим в корневой узел "Messages"
    MessagesVal := GCachedLanguageData.GetValue('Messages');
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
            Exit;
        end;

        if Assigned(CurrentVal) and (CurrentVal is TJSONObject) then
            CurrentObj := TJSONObject(CurrentVal)
        else
        begin
            // Ошибка: такого токена вообще нет в этом объекте
            Result := Format(ERR_INVALID_STRUCTURE, [Tokens[I], MessageKey]);
            ShowMessage(Result);
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
    end;
    // Если CurrentVal = nil, мы ничего не делаем, и метод завершается,
    // возвращая Result с текстом ошибки.
end;

initialization

finalization
    // Автоматическая очистка памяти при завершении работы программы
    if Assigned(GCachedLanguageData) then
        GCachedLanguageData.Free;

end.

