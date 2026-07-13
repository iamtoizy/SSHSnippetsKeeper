unit UI.Interfaces;

interface

uses
    Core.Interfaces;

type
    TVCLErrorHandler = class(TInterfacedObject, IUIErrorHandler)
    public
        procedure ShowError(const Message: string);
        procedure ShowInfo(const Message: string);
        procedure ShowWarning(const Message: string);
        function AskConfirmation(const Message: string): Boolean;
        function AskWarning(const Message: string): Boolean;
    end;

implementation

uses
    VCL.Dialogs, Winapi.Windows;

{ TVCLErrorHandler }

procedure TVCLErrorHandler.ShowError(const Message: string);
begin
    MessageBox(0, PChar(Message), 'Ошибка', MB_OK or MB_ICONERROR or MB_TOPMOST);
end;

procedure TVCLErrorHandler.ShowInfo(const Message: string);
begin
    MessageBox(0, PChar(Message), 'Информация', MB_OK or MB_ICONINFORMATION or MB_TOPMOST);
end;

procedure TVCLErrorHandler.ShowWarning(const Message: string);
begin
    MessageBox(0, PChar(Message), 'Предупреждение', MB_OK or MB_ICONWARNING or MB_TOPMOST);
end;

function TVCLErrorHandler.AskConfirmation(const Message: string): Boolean;
begin
    // Обычный вопрос, по умолчанию активна кнопка "Да"
    Result := MessageBox(0, PChar(Message), 'Подтверждение',
                         MB_YESNO or MB_ICONQUESTION or MB_TOPMOST) = IDYES;
end;

function TVCLErrorHandler.AskWarning(const Message: string): Boolean;
begin
    // Строгий вопрос для сканера безопасности.
    // MB_DEFBUTTON2 делает кнопку "Нет" активной по умолчанию (защита от случайного нажатия Enter)
    Result := MessageBox(0, PChar(Message), 'Внимание: Чувствительные данные',
                         MB_YESNO or MB_ICONWARNING or MB_TOPMOST or MB_DEFBUTTON2) = IDYES;
end;

end.
