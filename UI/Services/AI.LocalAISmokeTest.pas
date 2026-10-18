unit AI.LocalAISmokeTest;

// Архив мёртвого тестового кода.
// Ниже дословно сохранено тело процедуры TMainForm.nTerminalsClick
// (пункт меню "Terminals"), вырезанное из UI\Forms\MainFormUI.pas при чистке.
// Код не вызывается и требует доработки перед использованием
// (привязка sbBottom/MessagesHandler/ShowSimpleToast и путь к GGUF-модели).

interface

implementation

procedure LocalAISmokeTest;
//var
//    Answer, InstallLog: string;
//    AIService: ILocalAIService;
begin
{    AIService := AppContext.LocalAIService;

    // 1. Проверяем, есть ли вообще Python на ПК инженера
    if not AIService.IsPythonAvailable then
    begin
        MessagesHandler.ShowError(
            'На вашем компьютере не обнаружен Python.' + sLineBreak +
            'Пожалуйста, запросите у отдела ИТ установку Python (рекомендуется версия 3.11) ' +
            'и перезапустите программу.'
        );
        Exit;
    end;

    // 2. Проверяем, установлена ли нейросетевая библиотека
    if not AIService.IsLlamaModuleInstalled then
    begin
        if MessagesHandler.AskConfirmation(
            'Для работы локального ИИ требуется библиотека "llama-cpp-python".' + sLineBreak +
            'Установить её сейчас через корпоративный репозиторий (pip)?',
            'Требуются зависимости'
        ) then
        begin
            sbBottom.Panels[0].Text := 'Установка llama-cpp-python...';
            Application.ProcessMessages;

            // Запускаем установку
            if not AIService.InstallLlamaModule(InstallLog) then
            begin
                MessagesHandler.ShowError('Ошибка установки. Лог:' + sLineBreak + InstallLog);
                sbBottom.Panels[0].Text := 'Ошибка установки зависимостей';
                Exit;
            end;

            ShowSimpleToast('Библиотека успешно установлена!');
        end
        else
            Exit; // Пользователь отказался
    end;

    // 3. Проверяем/грузим модель (пусть путь хранится в SettingsManager)
    if not AIService.IsModelLoaded then
    begin
        sbBottom.Panels[0].Text := 'Загрузка модели Qwen в оперативную память...';
        Application.ProcessMessages;

        if not AIService.LoadModel('C:\Users\toizy\OneDrive\Desktop\Qwen3.5-4B-Q5_K_M.gguf') then
        begin
            MessagesHandler.ShowError('Не удалось загрузить файл модели!');
            Exit;
        end;
    end;

    // 2. Спрашиваем ИИ
    sbBottom.Panels[0].Text := 'ИИ анализирует сниппет...';
    Application.ProcessMessages;

    Answer := AIService.Ask(
        'Ты DevOps инженер. Объясни этот Bash-скрипт коротко и по делу.',
        'find . -size -100k'
    );

    // 3. Выводим ответ
    ShowMessage(Answer);
    sbBottom.Panels[0].Text := 'Готово';        }
end;

end.
