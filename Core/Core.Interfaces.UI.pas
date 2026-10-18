unit Core.Interfaces.UI;

interface

uses
    Winapi.Windows
    ;

type
    IUIMessagesHandler = interface
        ['{0A3EC5A3-E39D-41C5-8661-42F22294031C}']
        procedure ShowError(const Message: string);
        procedure ShowInfo(const Message: string);
        procedure ShowWarning(const Message: string);
        function AskConfirmation(const Message, Title: string; Flags: Cardinal = MB_YESNO or MB_ICONQUESTION): Boolean;
        function AskWarning(const Message, Title: string): Boolean;
        function AskInput(const Title, Prompt: string; var Value: string): Boolean;
    end;

    ILocalizable = interface
        ['{FDFCEAF6-9467-40DA-BB8F-D31C3ABFB8F5}']
        procedure ApplyLanguage;
    end;

implementation

end.
