unit MacroThread;

interface

uses
    MacroInputTypes,
    System.Classes,
    System.SyncObjs,
    System.SysUtils
    ;

type
    TMacroThread = class(TThread)
    private
        FActions: TArray<IScriptAction>;
        FContext: TMacroContext;
        // FreeAndNil(FContext) в Execute и снимок прогресса из главного
        // потока разнесены по потокам - под замком
        FContextLock: TCriticalSection;
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
        destructor Destroy; override;
        procedure Cancel;
        // Аварийный разрыв связей с владельцем: поток продолжает работать,
        // но уже не может звать Executor и коллбэки, указывающие на объекты,
        // которые вот-вот будут освобождены
        procedure Detach;
        function IsFinished: Boolean;
        // Снимок прогресса живого контекста; False - контекста уже нет
        function GetContextSnapshot(out APaused, ASleepRemainingMs, ATypedChars, ATotalChars, AKeyDelayMs: Integer): Boolean;
    end;

implementation

uses
    Common.Helpers,
    System.StrUtils,
    Vcl.Forms,
    Winapi.Windows
    ;

constructor TMacroThread.Create(const Actions: TArray<IScriptAction>; Context: TMacroContext; OnRecordRun: TRecordRunCallback = nil; Suspended: Boolean = False);
begin
    FActions := Actions;
    FContext := Context;
    FContextLock := TCriticalSection.Create;
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

procedure TMacroThread.Detach;
begin
    TInterlocked.Exchange(FCanceled, 1);
    Terminate;

    // FOnRecordRun - копия коллбэка контекста: снимаем и её
    FOnRecordRun := nil;

    if Assigned(FContext) then
    begin
        TInterlocked.Exchange(FContext.Canceled, 1);
        // nil у поля Executor безопасен: все действия проверяют
        // Assigned(FContext.Executor) перед вызовом
        FContext.Executor := nil;
        FContext.OnInput := nil;
        FContext.OnConfirm := nil;
        FContext.OnBatchInput := nil;
        FContext.OnRecordRun := nil;
        FContext.OnFocusLost := nil;
        FContext.OnTypingFinished := nil;
    end;
end;

function TMacroThread.IsFinished: Boolean;
begin
    Result := FDone;
end;

destructor TMacroThread.Destroy;
begin
    FContextLock.Free;
    inherited;
end;

function TMacroThread.GetContextSnapshot(out APaused, ASleepRemainingMs, ATypedChars, ATotalChars, AKeyDelayMs: Integer): Boolean;
begin
    Result := False;
    APaused := 0;
    ASleepRemainingMs := 0;
    ATypedChars := 0;
    ATotalChars := 0;
    AKeyDelayMs := 0;
    if FDone then
        Exit;
    FContextLock.Enter;
    try
        if not Assigned(FContext) then
            Exit;
        APaused := TInterlocked.CompareExchange(FContext.Paused, 0, 0);
        ASleepRemainingMs := TInterlocked.CompareExchange(FContext.SleepRemainingMs, 0, 0);
        ATypedChars := TInterlocked.CompareExchange(FContext.TypedChars, 0, 0);
        ATotalChars := TInterlocked.CompareExchange(FContext.ProgressTotal, 0, 0);
        // Обычное поле без Interlocked: выровненный 32-битный Integer
        // читается без разрыва, замок защищает от FreeAndNil(FContext)
        AKeyDelayMs := FContext.KeyDelayMs;
        Result := True;
    finally
        FContextLock.Leave;
    end;
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
        if CompletedSuccessfully and Assigned(FContext) and (FContext.SnippetID > 0) and
            ((Application = nil) or not Application.Terminated) then
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

        // Коллбэк срабатывает до FreeAndNil(FContext): Stop-панель успевает
        // отвязаться от контекста, пока он ещё жив
        if Assigned(FContext) and Assigned(FContext.OnTypingFinished) and
            ((Application = nil) or not Application.Terminated) then
        begin
            var LOnFinished := FContext.OnTypingFinished;
            TThread.Synchronize(nil,
                procedure
                begin
                    LOnFinished();
                end
            );
        end;

        // Освобождение под тем же замком, что и снимок прогресса:
        // иначе главный поток может читать уже освобождённый контекст
        if Assigned(FContext) then
        begin
            FContextLock.Enter;
            try
                FreeAndNil(FContext);
            finally
                FContextLock.Leave;
            end;
        end;

        FDone := True;
    end;
end;

end.
