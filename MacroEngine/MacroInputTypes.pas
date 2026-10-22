unit MacroInputTypes;

interface

uses
    System.SysUtils
    ;

type
    TMacroTokenKind = (tkText, tkSleep, tkEnter, tkInput, tkSendKey, tkUnknown);
    TMacroInputType = (mitString, mitNumber, mitHex, mitFloat, mitPassword, mitDate, mitConfirm);
    TInputCallback = reference to function(const Prompt: string): string;
    TConfirmCallback = reference to function(const Prompt: string): Boolean;
    TRecordRunCallback = reference to procedure(SnippetID, UserID: Integer);

    ITextExecutor = interface;

    TMacroContext = class
    public
        Executor: ITextExecutor;
        OnInput: TInputCallback;
        OnConfirm: TConfirmCallback;
        OnRecordRun: TRecordRunCallback;
        OnFocusLost: TProc;
        OnTypingFinished: TProc;
        Canceled: Integer;
        CurrentInputType: TMacroInputType;
        CurrentDefaultValue: string;
        UserCanceled: Boolean;
        SnippetID: Integer;
        UserID: Integer;
    end;

    ITextExecutor = interface
        ['{65C96380-78F5-4B0B-9D15-65C99E3C4D4A}']
        procedure TypeRawText(const Text: string; Context: TMacroContext);
        procedure PressEnter(Context: TMacroContext);
        procedure PressKey(Key: Word; Context: TMacroContext);
    end;

    IScriptAction = interface
        ['{5D2A9360-8082-4C7F-9A70-257CCB52AA1B}']
        procedure Execute;
    end;

    TScriptAction = class(TInterfacedObject, IScriptAction)
    protected
        FContext: TMacroContext;
    public
        constructor Create(Context: TMacroContext);
        procedure Execute; virtual; abstract;
    end;

    TTypeTextAction = class(TScriptAction)
    private
        FText: string;
    public
        constructor Create(Context: TMacroContext; const AText: string);
        procedure Execute; override;
    end;

    TSleepAction = class(TScriptAction)
    private
        FMilliseconds: Cardinal;
    public
        constructor Create(Context: TMacroContext; AMS: Cardinal);
        procedure Execute; override;
    end;

    TEnterAction = class(TScriptAction)
    public
        constructor Create(Context: TMacroContext);
        procedure Execute; override;
    end;

    TSendKeyAction = class(TScriptAction)
    private
        FKey: Word;
    public
        constructor Create(Context: TMacroContext; AKey: Word);
        procedure Execute; override;
    end;

implementation

uses
    Winapi.Windows,
    System.SyncObjs,
    System.Classes
    ;

{ TScriptAction }

constructor TScriptAction.Create(Context: TMacroContext);
begin
    inherited Create;
    FContext := Context;
end;

{ TTypeTextAction }

constructor TTypeTextAction.Create(Context: TMacroContext; const AText: string);
begin
    inherited Create(Context);
    FText := AText;
end;

procedure TTypeTextAction.Execute;
begin
    if Assigned(FContext.Executor) then
        FContext.Executor.TypeRawText(FText, FContext);
end;

{ TSleepAction }

constructor TSleepAction.Create(Context: TMacroContext; AMS: Cardinal);
begin
    inherited Create(Context);
    FMilliseconds := AMS;
end;

procedure TSleepAction.Execute;
var
    StartTick: Cardinal;
begin
    StartTick := GetTickCount;

    while GetTickCount - StartTick < FMilliseconds do
    begin
        // Проверяем оба флага: пользовательскую отмену И системное завершение потока
        if Assigned(FContext) and
           (TInterlocked.CompareExchange(FContext.Canceled, 0, 0) <> 0) then
            Exit;

        if TThread.CurrentThread.CheckTerminated then
            Exit;

        Sleep(5);
    end;
end;

{ TEnterAction }

constructor TEnterAction.Create(Context: TMacroContext);
begin
    inherited Create(Context);
end;

procedure TEnterAction.Execute;
begin
    if Assigned(FContext.Executor) then
        FContext.Executor.PressEnter(FContext);
end;

{ TSendKeyAction }

constructor TSendKeyAction.Create(Context: TMacroContext; AKey: Word);
begin
    inherited Create(Context);
    FKey := AKey;
end;

procedure TSendKeyAction.Execute;
begin
    if Assigned(FContext.Executor) then
        FContext.Executor.PressKey(FKey, FContext);
end;

end.
