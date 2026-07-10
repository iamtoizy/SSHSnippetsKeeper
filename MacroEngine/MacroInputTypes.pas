unit MacroInputTypes;

interface

type
    TMacroTokenKind = (tkText, tkSleep, tkEnter, tkInput, tkSendKey);
    TMacroInputType = (mitString, mitNumber, mitHex, mitFloat, mitPassword, mitDate, mitConfirm);
    TInputCallback = reference to function(const Prompt: string): string;
    TConfirmCallback = reference to function(const Prompt: string): Boolean;

    ITextExecutor = interface
        ['{65C96380-78F5-4B0B-9D15-65C99E3C4D4A}']
        procedure TypeRawText(const Text: string);
        procedure PressEnter;
        procedure PressKey(Key: Word);
    end;

    TMacroContext = class
    public
        Executor: ITextExecutor;
        OnInput: TInputCallback;
        OnConfirm: TConfirmCallback;
        Cancelled: Integer;
        CurrentInputType: TMacroInputType;
        CurrentDefaultValue: string;
        UserCancelled: Boolean;
        SnippetID: Integer;
        UserID: Integer;
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
        FContext.Executor.TypeRawText(FText);
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
           (TInterlocked.CompareExchange(FContext.Cancelled, 0, 0) <> 0) then
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
        FContext.Executor.PressEnter;
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
        FContext.Executor.PressKey(FKey);
end;

end.
