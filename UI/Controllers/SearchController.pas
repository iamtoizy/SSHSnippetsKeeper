unit SearchController;

interface

uses
    Common.Helpers,
    Core.Entities.Snippet,
    Core.Interfaces.App,
    Core.Interfaces.Services,
    System.Classes,
    System.SysUtils,
    System.Threading,
    Vcl.ExtCtrls,
    Vcl.StdCtrls
    ;

type
    // Асинхронный поиск сниппетов с отменой устаревших запросов
    TMainSearchController = class
    private
        FAppContext: IAppContext;
        FSearchEdit: TEdit;
        FIsFTSMode: TFunc<Boolean>;
        FFilterUserID: Integer;
        FSearchTask: ITask;
        FOnResults: TProc<TArray<TSnippetDTO>>;
        FOnEmptyQuery: TProc;
        procedure DisplayResults(const Results: TArray<TSnippetDTO>);
    public
        constructor Create(AppContext: IAppContext; SearchEdit: TEdit; IsFTSMode: TFunc<Boolean>; OnResults: TProc<TArray<TSnippetDTO>>; OnEmptyQuery: TProc);
        destructor Destroy; override;

        procedure SetUserFilter(UserID: Integer);
        procedure SearchAsync(const Mask: string);
        procedure CancelPending;
    end;

implementation

{ TMainSearchController }

constructor TMainSearchController.Create(AppContext: IAppContext; SearchEdit: TEdit; IsFTSMode: TFunc<Boolean>; OnResults: TProc<TArray<TSnippetDTO>>; OnEmptyQuery: TProc);
begin
    inherited Create;
    FAppContext := AppContext;
    FSearchEdit := SearchEdit;
    FIsFTSMode := IsFTSMode;
    FOnResults := OnResults;
    FOnEmptyQuery := OnEmptyQuery;
end;

destructor TMainSearchController.Destroy;
begin
    CancelPending;
    inherited;
end;

procedure TMainSearchController.SetUserFilter(UserID: Integer);
begin
    FFilterUserID := UserID;
end;

procedure TMainSearchController.CancelPending;
begin
    if Assigned(FSearchTask) then
        FSearchTask.Cancel;
end;

procedure TMainSearchController.DisplayResults(const Results: TArray<TSnippetDTO>);
begin
    if Assigned(FOnResults) then
        FOnResults(Results);
end;

procedure TMainSearchController.SearchAsync(const Mask: string);
var
    TaskUserID: Integer;
    IsFTS: Boolean;
    SearchStr: string;
begin
    SearchStr := Trim(Mask);

    CancelPending;

    if SearchStr.IsEmpty then
    begin
        if Assigned(FOnEmptyQuery) then
            FOnEmptyQuery();
        Exit;
    end;

    if SearchStr.Length < 3 then
        Exit;

    TaskUserID := FFilterUserID;
    IsFTS := FIsFTSMode();

    FSearchTask := TTask.Run(
        procedure
        var
            BgConnection: TComponent;
            BgService: ISnippetService;
            Results: TArray<TSnippetDTO>;
        begin
            try
                BgService := FAppContext.CreateIsolatedSnippetService(BgConnection);
                try
                    if TTask.CurrentTask.Status = TTaskStatus.Canceled then Exit;

                    // Вызываем сервис, передавая правильный TaskUserID
                    Results := BgService.SearchSnippets(SearchStr, IsFTS, TaskUserID);

                    if TTask.CurrentTask.Status = TTaskStatus.Canceled then Exit;

                    TThread.Queue(nil,
                        procedure
                        begin
                            if SameText(Trim(FSearchEdit.Text), SearchStr) then
                                DisplayResults(Results);
                        end
                    );
                finally
                    if Assigned(BgConnection) then
                        BgConnection.Free;
                end;
            except
                on E: Exception do
                    LogException('TMainSearchController.SearchAsync', E);
            end
        end
    );
end;

end.
