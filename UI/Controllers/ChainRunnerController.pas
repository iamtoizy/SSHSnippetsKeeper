unit ChainRunnerController;

interface

uses
    Core.Entities.Chain,
    Core.Entities.SavedQuery,
    Core.Entities.Snippet,
    Core.Interfaces.App,
    System.SysUtils,
    Vcl.Forms,
    Winapi.Windows
    ;

type
    TChainRunner = class
    private class var
        FRunning: Boolean;
        FStopRequested: Boolean;
        FOnStarted: TProc;
        FOnFinished: TProc;
    private
    class procedure RunSteps(
        AppContext: IAppContext;
        const PanelCaption, SequenceName: string;
        const Steps: TArray<TChainStepDTO>;
        RunnerUserID: Integer;
        TargetHWND: HWND;
        AutoEnter: Boolean); static;
    public
        class function IsChainRunning: Boolean; static;
        class procedure RequestStop; static;
        class property OnStarted: TProc read FOnStarted write FOnStarted;
        class property OnFinished: TProc read FOnFinished write FOnFinished;
        class function EncodeChainNodeID(ChainID: Integer): Integer; static;
        class function TryGetChainID(NodeValue: Integer; out ChainID: Integer): Boolean; static;
        class procedure ExecuteChain(AppContext: IAppContext; ChainID: Integer); static;
        class procedure ExecuteSnippetSequence(AppContext: IAppContext; const Snippets: TArray<TSnippetDTO>); static;
    end;

implementation

uses
    ChainRunPanelUI,
    Common.Localization,
    SnippetRunner,
    System.Classes,
    System.Math
    ;

const
    // Сколько мс шаг может не подавать признаков жизни (не пауза фокуса,
    // не остаток SLEEP, не огромный KEYDELAY), прежде чем он считается
    // зависшим и его печать отменяется
    STEP_STALL_TIMEOUT_MS = 20000;
    // После CancelTyping даём потоку ограниченное время на выход
    STEP_STALL_KILL_WAIT_MS = 5000;

{ TChainRunner }

class function TChainRunner.IsChainRunning: Boolean;
begin
    Result := FRunning;
end;

class procedure TChainRunner.RequestStop;
begin
    FStopRequested := True;
end;

class function TChainRunner.EncodeChainNodeID(ChainID: Integer): Integer;
begin
    Result := -(CHAIN_NODE_ID_BASE + ChainID);
end;

class function TChainRunner.TryGetChainID(NodeValue: Integer; out ChainID: Integer): Boolean;
begin
    // Диапазон умных папок (SAVED_QUERY_NODE_ID_BASE) в цепочки не попадает
    Result := (NodeValue <= CHAIN_NODE_ID_BASE * -1) and
              (NodeValue > SAVED_QUERY_NODE_ID_BASE * -1);
    if Result then
        ChainID := (NodeValue * -1) - CHAIN_NODE_ID_BASE;
end;

class procedure TChainRunner.ExecuteChain(AppContext: IAppContext; ChainID: Integer);
var
    Chain: TChainDTO;
    Steps: TArray<TChainStepDTO>;
    TargetHWND: HWND;
begin
    if FRunning then
    begin
        AppContext.MessagesHandler.ShowInfo(TUIStateLoader.GetMessage('Chains.Run.ErrorActive'));
        Exit;
    end;

    if TSnippetRunner.IsExecuting then
        Exit;

    Chain := AppContext.ChainService.GetChainByID(ChainID);
    if Chain.ID = 0 then
        Exit;

    Steps := AppContext.ChainService.GetSteps(ChainID);
    if Length(Steps) = 0 then
    begin
        AppContext.MessagesHandler.ShowInfo(TUIStateLoader.GetMessage('Chains.Run.Empty', [Chain.Name]));
        Exit;
    end;

    FRunning := True;
    try
        with TSnippetRunner.Create(Chain.UserID, AppContext) do
        try
            if not PickTargetWindow(TargetHWND) then
                Exit;
        finally
            Free;
        end;

        if Assigned(FOnStarted) then
            FOnStarted;
        try
            RunSteps(AppContext, TUIStateLoader.GetMessage('Chains.Run.PanelTitle'), Chain.Name,
                Steps, Chain.UserID, TargetHWND, Chain.AutoEnter);
        finally
            if Assigned(FOnFinished) then
                FOnFinished;
        end;
    finally
        FRunning := False;
    end;
end;

class procedure TChainRunner.ExecuteSnippetSequence(AppContext: IAppContext; const Snippets: TArray<TSnippetDTO>);
var
    Steps: TArray<TChainStepDTO>;
    TargetHWND: HWND;
    I: Integer;
    PanelCaption: string;
begin
    if FRunning then
    begin
        AppContext.MessagesHandler.ShowInfo(TUIStateLoader.GetMessage('MultiSelect.RunSequence.ErrorActive'));
        Exit;
    end;

    if TSnippetRunner.IsExecuting then
        Exit;

    if Length(Snippets) = 0 then
        Exit;

    FRunning := True;
    try
        with TSnippetRunner.Create(Snippets[0].UserID, AppContext) do
        try
            if not PickTargetWindow(TargetHWND) then
                Exit;
        finally
            Free;
        end;

        SetLength(Steps, Length(Snippets));
        for I := 0 to High(Snippets) do
        begin
            Steps[I] := Default(TChainStepDTO);
            Steps[I].Position := I + 1;
            Steps[I].SnippetID := Snippets[I].ID;
            Steps[I].PauseMs := 0;
        end;

        PanelCaption := TUIStateLoader.GetMessage('MultiSelect.RunSequence.PanelTitle');

        if Assigned(FOnStarted) then
            FOnStarted;
        try
            RunSteps(AppContext, PanelCaption, PanelCaption, Steps, 0, TargetHWND, True);
        finally
            if Assigned(FOnFinished) then
                FOnFinished;
        end;
    finally
        FRunning := False;
    end;
end;

class procedure TChainRunner.RunSteps(
    AppContext: IAppContext;
    const PanelCaption, SequenceName: string;
    const Steps: TArray<TChainStepDTO>;
    RunnerUserID: Integer;
    TargetHWND: HWND;
    AutoEnter: Boolean);
var
    Panel: TChainRunPanel;
    I: Integer;
    Snippet: TSnippetDTO;
    RunnerID: Integer;
    StopReason: string;
    RemainingPause, PauseShownSec: Integer;
    SnapPaused, SnapSleepMs, SnapTyped, SnapTotal, SnapKeyDelay: Integer;
    LastTyped: Integer;
    LastChangedTick, StallDeadline: DWORD;
begin
    Panel := TChainRunPanel.Create(nil);
    try
        Panel.Initialize(PanelCaption, SequenceName, Length(Steps));
        Panel.Show;
        Panel.Update;
        Panel.EnsureTopMost;

        FStopRequested := False;
        StopReason := '';
        for I := 0 to High(Steps) do
        begin
            if Panel.StopRequested or FStopRequested then
                Break;

            Snippet := AppContext.SnippetService.GetSnippetByID(Steps[I].SnippetID);
            if Snippet.ID = 0 then
            begin
                StopReason := TUIStateLoader.GetMessage('Chains.Run.ErrorMissingSnippet', [I + 1]);
                Break;
            end;

            if not IsWindow(TargetHWND) then
            begin
                StopReason := TUIStateLoader.GetMessage('Chains.Run.ErrorWindow');
                Break;
            end;

            Panel.SetStep(I + 1, Length(Steps), Snippet.Title);

            RunnerID := RunnerUserID;
            if RunnerID <= 0 then
                RunnerID := Snippet.UserID;

            // Авто-Enter - одиночный #10, НЕ sLineBreak: TypeRawText жмёт
            // PressEnter на каждый #13/#10, CRLF дал бы двойной Enter
            if AutoEnter and (Snippet.Content <> '') and
                (not AppContext.WindowHelper.EndsTypingWithEnter(Snippet.Content)) then
                Snippet.Content := Snippet.Content + #10;

            with TSnippetRunner.Create(RunnerID, AppContext) do
            try
                ExecuteSnippetInWindow(Snippet, TargetHWND);
            finally
                Free;
            end;

            LastTyped := -1;
            LastChangedTick := GetTickCount;
            Panel.SetTypingStatus(0, 0, 0, 0);
            while AppContext.WindowHelper.IsTypingBusy and not (Panel.StopRequested or FStopRequested) do
            begin
                Sleep(30);
                Application.ProcessMessages;
                CheckSynchronize;

                // Снимок живой печати: индикация в панели + детектор зависания
                if AppContext.WindowHelper.GetTypingSnapshot(
                    SnapPaused, SnapSleepMs, SnapTyped, SnapTotal, SnapKeyDelay) then
                begin
                    Panel.SetTypingStatus(SnapPaused, SnapSleepMs, SnapTyped, SnapTotal);

                    // Прогресс = растущий TypedChars; пауза фокуса, остаток
                    // SLEEP и KEYDELAY больше таймаута зависанием не считаются
                    if (SnapPaused = 0) and (SnapSleepMs <= 0) and
                        (SnapKeyDelay < STEP_STALL_TIMEOUT_MS) and (SnapTyped <> LastTyped) then
                    begin
                        LastTyped := SnapTyped;
                        LastChangedTick := GetTickCount;
                    end;

                    if GetTickCount - LastChangedTick > STEP_STALL_TIMEOUT_MS then
                    begin
                        StopReason := TUIStateLoader.GetMessage('Chains.Run.ErrorStalledStep', [I + 1]);
                        AppContext.WindowHelper.CancelTyping;
                        StallDeadline := GetTickCount + STEP_STALL_KILL_WAIT_MS;
                        while AppContext.WindowHelper.IsTypingBusy do
                        begin
                            Sleep(20);
                            Application.ProcessMessages;
                            CheckSynchronize;
                            if GetTickCount >= StallDeadline then
                                Break;
                        end;
                        Break;
                    end;
                end
                else
                begin
                    // Снимок False = наш поток уже допечатал и освободил
                    // контекст; занятость держит отставший detached-поток
                    // (Executor отрезан - печатать он не может), шаг готов
                    Break;
                end;
            end;

            if StopReason <> '' then
                Break;

            if Panel.StopRequested or FStopRequested then
            begin
                AppContext.WindowHelper.CancelTyping;
                StallDeadline := GetTickCount + STEP_STALL_KILL_WAIT_MS;
                while AppContext.WindowHelper.IsTypingBusy do
                begin
                    Sleep(20);
                    Application.ProcessMessages;
                    CheckSynchronize;
                    if GetTickCount >= StallDeadline then
                        Break;
                end;
                Break;
            end;

            RemainingPause := Max(0, Steps[I].PauseMs);
            if RemainingPause > 0 then
            begin
                Panel.SetTypingStatus(0, RemainingPause, 0, 0);
                PauseShownSec := RemainingPause div 1000;
                while (RemainingPause > 0) and not (Panel.StopRequested or FStopRequested) do
                begin
                    Sleep(30);
                    Dec(RemainingPause, 30);
                    if RemainingPause < 0 then
                        RemainingPause := 0;
                    if RemainingPause div 1000 <> PauseShownSec then
                    begin
                        PauseShownSec := RemainingPause div 1000;
                        Panel.SetTypingStatus(0, RemainingPause, 0, 0);
                    end;
                    Application.ProcessMessages;
                end;
            end;
        end;

    finally
        Panel.Free;
    end;

    // Диалог ошибки - после Panel.Free: панель TopMost и перекрыла бы его
    if StopReason <> '' then
        AppContext.MessagesHandler.ShowError(StopReason);
end;

end.
