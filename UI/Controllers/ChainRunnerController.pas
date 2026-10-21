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
    public
        class function IsChainRunning: Boolean; static;
        class function EncodeChainNodeID(ChainID: Integer): Integer; static;
        class function TryGetChainID(NodeValue: Integer; out ChainID: Integer): Boolean; static;
        class procedure ExecuteChain(AppContext: IAppContext; ChainID: Integer); static;
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
    Panel: TChainRunPanel;
    I: Integer;
    Snippet: TSnippetDTO;
    StopReason: string;
    RemainingPause: Integer;
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
    Panel := TChainRunPanel.Create(nil);
    try
        Panel.Initialize(Chain.Name, Length(Steps));
        Panel.Show;
        Panel.Update;

        StopReason := '';
        for I := 0 to High(Steps) do
        begin
            if Panel.StopRequested then
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

            with TSnippetRunner.Create(Chain.UserID, AppContext) do
            try
                ExecuteSnippetInWindow(Snippet, TargetHWND, False);
            finally
                Free;
            end;

            while AppContext.WindowHelper.IsTypingBusy and not Panel.StopRequested do
            begin
                Sleep(30);
                Application.ProcessMessages;
            end;

            if Panel.StopRequested then
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
            while (RemainingPause > 0) and not Panel.StopRequested do
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
        FRunning := False;
    end;
end;

end.
