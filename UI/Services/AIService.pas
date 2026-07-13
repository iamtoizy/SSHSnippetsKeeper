unit AIService;

interface

uses
    System.SysUtils,
    System.Classes,
    System.JSON,
    System.NetEncoding,
    System.Net.HttpClient,
    System.Net.HttpClientComponent,
    System.Net.URLClient,
    System.RegularExpressions;

type
    IAIService = interface
        ['{2D2338EA-1D0A-4C88-9E8A-2F1771282DBF}']
        function AskAssistant(const Instruction, CodeContext: string): string;
    end;

    TAITextCleaner = class
    private
        class function CleanInlineMarkdown(const Line: string): string;
    public
        class function ExtractPureCode(const RawText: string): string;
    end;

    TYandexAIService = class(TInterfacedObject, IAIService)
    private
        FApiKey: string;
        FFolderID: string;
        FModel: string;
        FAgentID: string; // ID Агента из Yandex AI Studio
        FUseAgent: Boolean;
    public
    // Конструктор поддерживает как обычную модель, так и Агента (передаем пустую строку в AModel, если нужен Агент)
        constructor Create(const AApiKey, AFolderID, AModel, AAgentID: string);
        function AskAssistant(const Instruction, CodeContext: string): string;
    end;

implementation

uses
    System.Generics.Collections
    ;

{ TAITextCleaner }

class function TAITextCleaner.CleanInlineMarkdown(const Line: string): string;
begin
    Result := Line;
    if Result.IsEmpty then
        Exit;
    Result := TRegEx.Replace(Result, '(\*\*|__)(.*?)\1', '$2');
    Result := TRegEx.Replace(Result, '(\*|_)(.*?)\1', '$2');
    Result := TRegEx.Replace(Result, '`(.*?)`', '$1');
    Result := TRegEx.Replace(Result, '\[(.*?)\]\(.*?\)', '$1');
end;

class function TAITextCleaner.ExtractPureCode(const RawText: string): string;
var
    Lines: TStringList;
    CodeLines: TStringList;
    I: Integer;
    InCodeBlock: Boolean;
    CurrentLine: string;
begin
    Result := Trim(RawText);
    if Result.IsEmpty then
        Exit;

    Lines := TStringList.Create;
    CodeLines := TStringList.Create;
    try
        Lines.Text := RawText;
        InCodeBlock := False;

        for I := 0 to Lines.Count - 1 do
        begin
            CurrentLine := Trim(Lines[I]);
            if CurrentLine.StartsWith('```') then
            begin
                if InCodeBlock then
                begin
//                    InCodeBlock := False;
                    Break;
                end
                else
                begin
                    InCodeBlock := True;
                    Continue;
                end;
            end;

            if InCodeBlock then
                CodeLines.Add(CleanInlineMarkdown(Lines[I]));
        end;

        if CodeLines.Count > 0 then
            Result := Trim(CodeLines.Text)
        else
        begin
            for I := 0 to Lines.Count - 1 do
                Lines[I] := CleanInlineMarkdown(Lines[I]);
            Result := Trim(Lines.Text);
        end;
    finally
        CodeLines.Free;
        Lines.Free;
    end;
end;

{ TYandexAIService }

constructor TYandexAIService.Create(const AApiKey, AFolderID, AModel, AAgentID: string);
begin
    FApiKey := AApiKey;
    FFolderID := AFolderID;
    FModel := AModel;
    FAgentID := AAgentID;
  // Если передан AgentID, значит используем режим Агента
    FUseAgent := not FAgentID.Trim.IsEmpty;
end;

function TYandexAIService.AskAssistant(const Instruction, CodeContext: string): string;
var
    Client: TNetHTTPClient;
    RequestJSON: TJSONObject;
    PromptJSON: TJSONObject;
    ToolsArray: TJSONArray;
    ToolObj: TJSONObject;
    ContainerObj: TJSONObject;
    FileIdsArray: TJSONArray;
    Response: IHTTPResponse;
    ResponseJSON: TJSONObject;
    StringStream: TStringStream;
    FullURL: string;
    RawResponse: string;
    OutputArray, ContentArray: TJSONArray;
    I, J: Integer;
    ItemObj, ContentObj: TJSONObject;
    CurrentLine: string;
    CombinedInput: string;
begin
    Result := '';
    Client := TNetHTTPClient.Create(nil);
    RequestJSON := TJSONObject.Create;
    StringStream := TStringStream.Create('', TEncoding.UTF8);
    try
    // Формируем ввод для ИИ (Инструкция + контекст существующего кода)
        if CodeContext.Trim.IsEmpty then
            CombinedInput := Instruction
        else
            CombinedInput := Format('Инструкция: %s' + #13#10 + 'Текущий код сниппета:' + #13#10 + '%s', [Instruction, CodeContext]);

    // --- РАЗДЕЛЕНИЕ ЛОГИКИ ЗАПРОСА ---
        if FUseAgent then
        begin
      // Сборка JSON для Агента согласно новой инструкции
            PromptJSON := TJSONObject.Create;
            PromptJSON.AddPair('id', FAgentID);
            RequestJSON.AddPair('prompt', PromptJSON);

            RequestJSON.AddPair('input', CombinedInput);
            RequestJSON.AddPair('max_output_tokens', TJSONNumber.Create(1500));

      // Добавляем обязательный массив tools для code_interpreter
            ToolsArray := TJSONArray.Create;
            ToolObj := TJSONObject.Create;
            ToolObj.AddPair('type', 'code_interpreter');

            ContainerObj := TJSONObject.Create;
            ContainerObj.AddPair('type', 'auto');

            FileIdsArray := TJSONArray.Create;
            ContainerObj.AddPair('file_ids', FileIdsArray);
            ToolObj.AddPair('container', ContainerObj);

            ToolsArray.AddElement(ToolObj);
            RequestJSON.AddPair('tools', ToolsArray);
        end
        else
        begin
      // Стандартный JSON для обычной текстовой модели (YandexGPT / DeepSeek)
            RequestJSON.AddPair('model', Format('gpt://%s/%s', [FFolderID, FModel]));
            RequestJSON.AddPair('temperature', TJSONNumber.Create(0.3));
            RequestJSON.AddPair('max_output_tokens', TJSONNumber.Create(1500));
            RequestJSON.AddPair('instructions', Instruction);
            RequestJSON.AddPair('content', 'Верни ТОЛЬКО чистый программный код.');
            RequestJSON.AddPair('reasoning_effort', 'none');

            if CodeContext.Trim.IsEmpty then
                RequestJSON.AddPair('input', 'Напиши полезный сниппет кода.')
            else
                RequestJSON.AddPair('input', CodeContext);
        end;

    // Настройка заголовков
        Client.CustomHeaders['Authorization'] := 'Bearer ' + FApiKey;
        Client.CustomHeaders['X-Folder-Id'] := FFolderID;
        Client.CustomHeaders['Content-Type'] := 'application/json';

        StringStream.WriteString(RequestJSON.ToString);
        StringStream.Position := 0;

        // СТРОГО ЧИСТЫЙ URL БЕЗ СКОБОК MARKDOWN И ЛИШНИХ СИМВОЛОВ
        FullURL := 'https://ai.api.cloud.yandex.net/v1/responses';

        // Для полной безопасности принудительно очистим строку от возможных невидимых символов
        FullURL := Trim(FullURL).DeQuotedString('"').DeQuotedString('''');

        // Выполняем POST запрос
        Response := Client.Post(FullURL, StringStream);

        RawResponse := Response.ContentAsString;

        if Response.StatusCode <> 200 then
            raise Exception.CreateFmt('Ошибка API (%d): %s', [Response.StatusCode, RawResponse]);

        ResponseJSON := TJSONObject.ParseJSONValue(RawResponse) as TJSONObject;
        try
            if Assigned(ResponseJSON) then
            begin
        // Агенты возвращают ответ либо в плоском корневом ключе 'output_text', либо в структуре 'output'
                if ResponseJSON.TryGetValue<string>('output_text', Result) then
                begin
                    Result := TAITextCleaner.ExtractPureCode(Result);
                    Exit;
                end;

        // Fallback-партинг по массиву output (если ответ всё же разбился на части)
                if ResponseJSON.TryGetValue('output', OutputArray) then
                begin
                    for I := 0 to OutputArray.Count - 1 do
                    begin
                        if OutputArray.Items[I] is TJSONObject then
                        begin
                            ItemObj := OutputArray.Items[I] as TJSONObject;
                            if ItemObj.TryGetValue('content', ContentArray) then
                            begin
                                for J := 0 to ContentArray.Count - 1 do
                                begin
                                    if ContentArray.Items[J] is TJSONObject then
                                    begin
                                        ContentObj := ContentArray.Items[J] as TJSONObject;
                                        if Assigned(ContentObj) then
                                        begin
                                            CurrentLine := ContentObj.GetValue<string>('text');
                                            Result := Result + CurrentLine;
                                        end;
                                    end;
                                end;
                            end;
                        end;
                    end;
                end
                else if ResponseJSON.TryGetValue('content', Result) then
                begin
          // Обычная строка контента
                end
                else
                    raise Exception.Create('Не удалось извлечь ответ из JSON: ' + RawResponse);

                Result := TAITextCleaner.ExtractPureCode(Result);
            end;
        finally
            ResponseJSON.Free;
        end;
    finally
        StringStream.Free;
        RequestJSON.Free;
        Client.Free;
    end;
end;

end.

