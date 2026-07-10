unit MacroActions;

interface

uses
    System.SysUtils,
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

procedure TInputAction.Execute;
var
    S: string;
begin
    // Специальная обработка для Confirm
    if FInputType = mitConfirm then
    begin
        if FHasPreCollectedValue then
        begin
            // Значение уже собрано при pre-collect
            if FPreCollectedValue <> '__CONFIRMED__' then
                TInterlocked.Exchange(FContext.Cancelled, 1);
        end
        else
        begin
            // Fallback: спрашиваем прямо во время выполнения
            if Assigned(FContext.OnConfirm) then
            begin
                if not FContext.OnConfirm(FPrompt) then
                    TInterlocked.Exchange(FContext.Cancelled, 1);
            end;
        end;
        Exit; // НЕ печатаем ничего в терминал!
    end;

    // Стандартная обработка для остальных типов
    if FHasPreCollectedValue then
    begin
        if Assigned(FContext.Executor) then
            FContext.Executor.TypeRawText(FPreCollectedValue);
    end
    else
    begin
        if not Assigned(FContext.OnInput) then
            Exit;

        S := FContext.OnInput(FPrompt);
        if Assigned(FContext.Executor) then
            FContext.Executor.TypeRawText(S);
    end;
end;

end.
