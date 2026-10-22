unit Core.Interfaces.Automation;

interface

uses
    MacroInputTypes,
    Winapi.Windows
    ;

type
    TWindowHelperInfo = record
        Handle: HWND;
        Parent: HWND;
        ClassName: string;
        ParentClassName: string;
        WindowText: string;
    end;

    IWindowHelper = interface(ITextExecutor)
        ['{9A6E6337-0CD6-4F38-948C-C2AFB36471F2}']
        function GetWindowUnderCursor: Boolean;
        procedure TypeTextIntoWindow(const Text: string);
        procedure TypeTextIntoWindowWithContext(const Text: string; Context: TMacroContext);
        procedure SetTargetWindow(Handle: HWND);
        function GetWindowInfo: TWindowHelperInfo;
        function IsTypingBusy: Boolean;
        procedure CancelTyping;
        function EstimateTypingMs(const Text: string): Integer;
        function FindUnknownCommands(const Text: string): TArray<string>;
    end;

implementation

end.
