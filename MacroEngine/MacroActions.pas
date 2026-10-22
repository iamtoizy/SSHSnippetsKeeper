unit MacroActions;

interface

uses
    MacroInputTypes
    ;

type
    TInputAction = class(TScriptAction)
    private
        FPrompt: string;
        FInputType: TMacroInputType;
        FDefaultValue: string;
        FPreCollectedValue: string;
        FHasPreCollectedValue: Boolean;
        function PromptUser(const APrompt: string): string;
        function ConfirmUser(const APrompt: string): Boolean;
    public
        constructor Create(Context: TMacroContext; const Prompt: string; InputType: TMacroInputType; const DefaultValue: string);
        procedure SetPreCollectedValue(const Value: string);
        function GetPrompt: string;
        function GetInputType: TMacroInputType;
        function GetDefaultValue: string;
        procedure Execute; override;
    end;

implementation

uses
    System.Classes,
    System.SyncObjs
    ;

{ TInputAction }

constructor TInputAction.Create(Context: TMacroContext; const Prompt: string; InputType: TMacroInputType; const DefaultValue: string);
begin
    inherited Create(Context);
    FPrompt := Prompt;
    FInputType := InputType;
    FDefaultValue := DefaultValue;
    FHasPreCollectedValue := False;
end;

procedure TInputAction.SetPreCollectedValue(const Value: string);
begin
    FPreCollectedValue := Value;
    FHasPreCollectedValue := True;
end;

function TInputAction.GetDefaultValue: string;
begin
    Result := FDefaultValue;
end;

function TInputAction.GetInputType: TMacroInputType;
begin
    Result := FInputType;
end;

function TInputAction.GetPrompt: string;
begin
    Result := FPrompt;
end;

function TInputAction.PromptUser(const APrompt: string): string;
var
    Res: string;
begin
    if TThread.CurrentThread.ThreadID = MainThreadID then
        Exit(FContext.OnInput(APrompt));
    TThread.Synchronize(nil,
        procedure
        begin
            Res := FContext.OnInput(APrompt);
        end);
    Result := Res;
end;

function TInputAction.ConfirmUser(const APrompt: string): Boolean;
var
    Res: Boolean;
begin
    if TThread.CurrentThread.ThreadID = MainThreadID then
        Exit(FContext.OnConfirm(APrompt));
    TThread.Synchronize(nil,
        procedure
        begin
            Res := FContext.OnConfirm(APrompt);
        end);
    Result := Res;
end;

procedure TInputAction.Execute;
var
    S: string;
begin
    // Confirm всегда спрашивается в потоке: PreCollectInputs его пропускает
    if FInputType = mitConfirm then
    begin
        if Assigned(FContext.OnConfirm) then
        begin
            if not ConfirmUser(FPrompt) then
                TInterlocked.Exchange(FContext.Canceled, 1);
        end;
        Exit; // НЕ печатаем ничего в терминал!
    end;

    // Стандартная обработка для остальных типов
    if FHasPreCollectedValue then
    begin
        if Assigned(FContext.Executor) then
            FContext.Executor.TypeRawText(FPreCollectedValue, FContext);
    end
    else
    begin
        if not Assigned(FContext.OnInput) then
            Exit;

        S := PromptUser(FPrompt);
        if Assigned(FContext.Executor) then
            FContext.Executor.TypeRawText(S, FContext);
    end;
end;

end.
