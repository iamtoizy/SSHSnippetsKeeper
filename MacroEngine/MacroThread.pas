unit MacroThread;

interface

uses
    System.Classes,
    MacroActions,
    System.SysUtils,
    System.SyncObjs,
    MacroInputTypes
    ;

type
    TMacroThread = class(TThread)
    private
        FActions: TArray<IScriptAction>;
        FContext: TMacroContext;
    protected
        procedure Execute; override;
    public
        constructor Create(const Actions: TArray<IScriptAction>; AContext: TMacroContext);
        procedure Cancel;
    end;

implementation

uses
    Winapi.Windows,
    DataModule,
    System.StrUtils
    ;

constructor TMacroThread.Create(const Actions: TArray<IScriptAction>; AContext: TMacroContext);
begin
    FActions := Actions;
    FContext := AContext;

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
{    finally
        // Записываем статистику ТОЛЬКО если макрос завершился успешно
        if CompletedSuccessfully and Assigned(FContext) and (FContext.SnippetID > 0) then
        begin
            try
                DataModuleCommon.SnippetRepository.RecordRun(
                    FContext.SnippetID,
                    FContext.UserID
                );
            except
                on E: Exception do
                    OutputDebugString(PChar('[MacroThread] Failed to record run: ' + E.Message));
            end;
        end;

        if Assigned(FContext) then
            FreeAndNil(FContext);
    end;     }
    finally
        if CompletedSuccessfully and Assigned(FContext) and (FContext.SnippetID > 0) then
        begin
            var LSnippetID := FContext.SnippetID;
            var LUserID := FContext.UserID;

            TThread.Synchronize(nil,
                procedure
                begin
                    try
                        DataModuleCommon.SnippetRepository.RecordRun(LSnippetID, LUserID);
                    except
                        on E: Exception do
                            OutputDebugString(PChar('[MacroThread] Sync failed: ' + E.Message));
                    end;
                end
            );
        end
        else
        begin
            OutputDebugString(PChar(Format('[MacroThread] Skipping record: Completed=%s, Context=%s, SnippetID=%s',
                [BoolToStr(CompletedSuccessfully, True),
                 BoolToStr(Assigned(FContext), True),
                 IfThen(Assigned(FContext), FContext.SnippetID.ToString, '-1')])));
        end;

        if Assigned(FContext) then
            FreeAndNil(FContext);
    end;
end;

end.
