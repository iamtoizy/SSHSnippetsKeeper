unit MacroThread;

interface

uses
    MacroInputTypes,
    System.Classes,
    System.SysUtils
    ;

type
    TMacroThread = class(TThread)
    private
        FActions: TArray<IScriptAction>;
        FContext: TMacroContext;
        FCanceled: Integer;
        FDone: Boolean;
        // Добавляем поле для коллбэка
        FOnRecordRun: TRecordRunCallback;
    protected
        procedure Execute; override;
    public
        // Внедряем коллбэк через конструктор (по умолчанию nil, чтобы не ломать старый код, если где-то он вызывается без него)
        // Suspended = True позволяет привязать OnTerminate до фактического запуска потока
        constructor Create(const Actions: TArray<IScriptAction>; Context: TMacroContext; OnRecordRun: TRecordRunCallback = nil; Suspended: Boolean = False);
        procedure Cancel;
        function IsFinished: Boolean;
    end;

implementation

uses
    Common.Helpers,
    System.StrUtils,
    System.SyncObjs,
    Winapi.Windows
    ;

constructor TMacroThread.Create(const Actions: TArray<IScriptAction>; Context: TMacroContext; OnRecordRun: TRecordRunCallback = nil; Suspended: Boolean = False);
begin
    FActions := Actions;
    FContext := Context;
    FOnRecordRun := OnRecordRun; // Сохраняем коллбэк

    // FreeOnTerminate обязан быть False: объектом владеет TWindowHelper -
    // он же освобождает после WaitFor. Самоосвобождение закрывает дескриптор
    // и превращает чужой WaitFor в EThread "Неверный дескриптор"
    FreeOnTerminate := False;

    inherited Create(Suspended);
end;

procedure TMacroThread.Cancel;
begin
    TInterlocked.Exchange(FCanceled, 1);
    Terminate;
end;

function TMacroThread.IsFinished: Boolean;
begin
    Result := FDone;
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
            if (TInterlocked.Add(FCanceled, 0) <> 0) or
                (Assigned(FContext) and (TInterlocked.Add(FContext.Canceled, 0) <> 0)) then
            begin
                CompletedSuccessfully := False;
                Break;
            end;

            try
                A.Execute;
            except
                // Необработанное исключение в потоке убивает процесс (RTE 216):
                // логируем, помечаем макрос как незавершённый и прерываем цикл
                on E: Exception do
                begin
                    CompletedSuccessfully := False;
                    LogException('TMacroThread.Execute', E);
                    Break;
                end;
            end;
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

        if Assigned(FContext) and Assigned(FContext.OnTypingFinished) then
            TThread.Synchronize(nil,
                procedure
                begin
                    FContext.OnTypingFinished();
                end
            );

        if Assigned(FContext) then
            FreeAndNil(FContext);

        FDone := True;
    end;
end;

end.
