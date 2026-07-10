unit UI.Interfaces;

interface

uses
    Core.Interfaces
    ;

type
    TVCLErrorHandler = class(TInterfacedObject, IUIErrorHandler)
        procedure ShowError(const Message: string);
        procedure ShowInfo(const Message: string);
        procedure ShowWarning(const Message: string);
    end;

implementation

// TODO: Добавить логирование и дополнительные методы по мере необходимости

uses
    VCL.Dialogs,
    Winapi.Windows
    ;

{ TVCLErrorHandler }

procedure TVCLErrorHandler.ShowError(const Message: string);
begin
    MessageBox(0, PChar(Message), 'Ошибка', MB_OK or MB_ICONERROR);
end;

procedure TVCLErrorHandler.ShowInfo(const Message: string);
begin
    MessageBox(0, PChar(Message), 'Ошибка', MB_OK or MB_ICONINFORMATION);
end;

procedure TVCLErrorHandler.ShowWarning(const Message: string);
begin
    MessageBox(0, PChar(Message), 'Ошибка', MB_OK or MB_ICONWARNING);
end;

end.
