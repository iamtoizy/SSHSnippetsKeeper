unit UI.Services.MessagesHandler;

interface

uses
    Core.Interfaces,
    System.Classes,
    Winapi.Windows
    ;

type
    TUIMessagesHandler = class(TInterfacedObject, IUIMessagesHandler)
    private
        // Вспомогательный метод для получения правильного владельца окна
        function GetSafeHandle: HWND;
    public
        procedure ShowError(const Message: string);
        procedure ShowInfo(const Message: string);
        procedure ShowWarning(const Message: string);
        function AskConfirmation(const Message, Title: string; Flags: Cardinal = MB_YESNO or MB_ICONQUESTION): Boolean;
        function AskWarning(const Message, Title: string): Boolean;
    end;

implementation

uses
    UI.StateLoader,
    Vcl.Forms
    ;

{ TUIMessagesHandler }

function TUIMessagesHandler.GetSafeHandle: HWND;
begin
    // Если есть активная форма, привязываем диалог к ней. Иначе к Application.
    if Assigned(Screen.ActiveForm) then
        Result := Screen.ActiveForm.Handle
    else if Assigned(Application) then
        Result := Application.Handle
    else
        Result := 0;
end;

procedure TUIMessagesHandler.ShowError(const Message: string);
begin
    // Асинхронные сообщения (Fire-and-forget) отправляем через TThread.Queue,
    // чтобы они гарантированно вызвались в главном потоке VCL, не блокируя фоновый поток.
    TThread.Queue(nil,
        procedure
        begin
            MessageBox(GetSafeHandle, PChar(Message), PChar(TUIStateLoader.GetMessage('Common.Error')), MB_OK or MB_ICONERROR);
        end
    );
end;

procedure TUIMessagesHandler.ShowInfo(const Message: string);
begin
    TThread.Queue(nil,
        procedure
        begin
            MessageBox(GetSafeHandle, PChar(Message), PChar(TUIStateLoader.GetMessage('Common.Information')), MB_OK or MB_ICONINFORMATION);
        end
    );
end;

procedure TUIMessagesHandler.ShowWarning(const Message: string);
begin
    TThread.Queue(nil,
        procedure
        begin
            MessageBox(GetSafeHandle, PChar(Message), PChar(TUIStateLoader.GetMessage('Common.Warning')), MB_OK or MB_ICONWARNING);
        end
    );
end;

function TUIMessagesHandler.AskConfirmation(const Message, Title: string; Flags: Cardinal): Boolean;
var
    DlgResult: Integer;
begin
    // Окно с вопросом ДОЛЖНО остановить фоновый поток и дождаться ответа.
    // Проверяем, находимся ли мы уже в главном потоке:
    if TThread.CurrentThread.ThreadID = MainThreadID then
    begin
        Result := MessageBox(GetSafeHandle, PChar(Message), PChar(Title), Flags) = IDYES;
    end
    else
    begin
        // Если мы в фоне (TTask), используем Synchronize для безопасной остановки и показа UI
        TThread.Synchronize(nil,
            procedure
            begin
                DlgResult := MessageBox(GetSafeHandle, PChar(Message), PChar(Title), Flags);
            end
        );
        Result := (DlgResult = IDYES);
    end;
end;

function TUIMessagesHandler.AskWarning(const Message, Title: string): Boolean;
var
    DlgResult: Integer;
begin
    if TThread.CurrentThread.ThreadID = MainThreadID then
    begin
        Result := MessageBox(GetSafeHandle, PChar(Message), PChar(Title), MB_YESNO or MB_ICONWARNING or MB_DEFBUTTON2) = IDYES;
    end
    else
    begin
        TThread.Synchronize(nil,
            procedure
            begin
                DlgResult := MessageBox(GetSafeHandle, PChar(Message), PChar(Title), MB_YESNO or MB_ICONWARNING or MB_DEFBUTTON2);
            end
        );
        Result := (DlgResult = IDYES);
    end;
end;

end.
