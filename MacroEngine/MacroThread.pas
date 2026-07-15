unit MacroThread;

interface

uses
    System.Classes,
    System.SysUtils,
    System.SyncObjs,
    MacroInputTypes
    ;

type
    TMacroThread = class(TThread)
    private
        FActions: TArray<IScriptAction>;
        FContext: TMacroContext;
        // Добавляем поле для коллбэка
        FOnRecordRun: TProc<Integer, Integer>;
    protected
        procedure Execute; override;
    public
        // Внедряем коллбэк через конструктор (по умолчанию nil, чтобы не ломать старый код, если где-то он вызывается без него)
        constructor Create(const Actions: TArray<IScriptAction>; Context: TMacroContext; OnRecordRun: TProc<Integer, Integer> = nil);
        procedure Cancel;
    end;

implementation

uses
    Winapi.Windows,
    System.StrUtils
    ;

constructor TMacroThread.Create(const Actions: TArray<IScriptAction>; Context: TMacroContext; OnRecordRun: TProc<Integer, Integer> = nil);
begin
    FActions := Actions;
    FContext := Context;
    FOnRecordRun := OnRecordRun; // Сохраняем коллбэк

    inherited Create(False);

    FreeOnTerminate := True;
end;

procedure TMacroThread.Cancel;
begin
    if Assigned(FContext) then
        TInterlocked.Exchange(FContext.Cancelled, 1);
    Terminate;
end;

procedure TMacroThread.Execute;
var
    A: IScriptAction;
    CompletedSuccessfully: Boolean;
begin
    CompletedSuccessfully := True;
    try
        for A in FActions do
        begin
            if Terminated then
            begin
                CompletedSuccessfully := False;
                Break;
            end;
            if Assigned(FContext) and (TInterlocked.Add(FContext.Cancelled, 0) <> 0) then
            begin
                CompletedSuccessfully := False;
                Break;
            end;

            A.Execute;
        end;
    finally
        if CompletedSuccessfully and Assigned(FContext) and (FContext.SnippetID > 0) then
        begin
            var LSnippetID := FContext.SnippetID;
            var LUserID := FContext.UserID;

            TThread.Synchronize(nil,
                procedure
                begin
                    try
                        // Вместо жесткой привязки к БД, просто вызываем переданный коллбэк
                        if Assigned(FOnRecordRun) then
                            FOnRecordRun(LSnippetID, LUserID);
                    except
                        on E: Exception do
                            {$IFDEF DEBUG}
                            OutputDebugString(PChar('[MacroThread] Sync failed: ' + E.Message));
                            {$ENDIF}
                    end;
                end
            );
        end
        else
        begin
            {$IFDEF DEBUG}
            OutputDebugString(PChar(Format('[MacroThread] Skipping record: Completed=%s, Context=%s, SnippetID=%s',
                [BoolToStr(CompletedSuccessfully, True),
                 BoolToStr(Assigned(FContext), True),
                 IfThen(Assigned(FContext), FContext.SnippetID.ToString, '-1')])));
            {$ENDIF}
        end;

        if Assigned(FContext) then
            FreeAndNil(FContext);
    end;
end;

end.
