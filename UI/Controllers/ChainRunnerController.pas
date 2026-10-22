unit ChainRunnerController;

interface

uses
    Core.Entities.Chain,
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
            TargetHWND: HWND); static;
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
    System.Math
    ;

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
    Result := NodeValue <= CHAIN_NODE_ID_BASE * -1;
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

    with TSnippetRunner.Create(Chain.UserID, AppContext) do
    try
        if not PickTargetWindow(TargetHWND) then
            Exit;
    finally
        Free;
    end;

    FRunning := True;
    if Assigned(FOnStarted) then
        FOnStarted;
    try
        RunSteps(AppContext, TUIStateLoader.GetMessage('Chains.Run.PanelTitle'), Chain.Name,
            Steps, Chain.UserID, TargetHWND);
    finally
        FRunning := False;
        if Assigned(FOnFinished) then
            FOnFinished;
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
    FRunning := True;
    if Assigned(FOnStarted) then
        FOnStarted;
    try
        RunSteps(AppContext, PanelCaption, PanelCaption, Steps, 0, TargetHWND);
    finally
        FRunning := False;
        if Assigned(FOnFinished) then
            FOnFinished;
    end;
end;

class procedure TChainRunner.RunSteps(
    AppContext: IAppContext;
    const PanelCaption, SequenceName: string;
    const Steps: TArray<TChainStepDTO>;
    RunnerUserID: Integer;
    TargetHWND: HWND);
var
    Panel: TChainRunPanel;
    I: Integer;
    Snippet: TSnippetDTO;
    RunnerID: Integer;
    StopReason: string;
    RemainingPause: Integer;
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

            with TSnippetRunner.Create(RunnerID, AppContext) do
            try
                ExecuteSnippetInWindow(Snippet, TargetHWND, False);
            finally
                Free;
            end;

            while AppContext.WindowHelper.IsTypingBusy and not (Panel.StopRequested or FStopRequested) do
            begin
                Sleep(30);
                Application.ProcessMessages;
            end;

            if Panel.StopRequested or FStopRequested then
            begin
                AppContext.WindowHelper.CancelTyping;
                while AppContext.WindowHelper.IsTypingBusy do
                begin
                    Sleep(20);
                    Application.ProcessMessages;
                end;
                Break;
            end;

            RemainingPause := Max(0, Steps[I].PauseMs);
            while (RemainingPause > 0) and not (Panel.StopRequested or FStopRequested) do
            begin
                Sleep(30);
                Dec(RemainingPause, 30);
                Application.ProcessMessages;
            end;
        end;

        if StopReason <> '' then
            AppContext.MessagesHandler.ShowError(StopReason);
    finally
        Panel.Free;
    end;
end;

end.
