unit SecurityReportFormUI;

// Отчёт сканера безопасности по всей базе: список сниппетов, в содержимом
// или комментарии которых сканер нашёл чувствительные данные. Двойной клик
// открывает сниппет на правку; после закрытия редактора отчёт пересчитывается.
// Кнопка "Пересканировать" запускает сканер заново, фильтр в нижней панели
// скрывает сниппеты, для которых включено "доверять". Сканирование выполняется
// в фоновом потоке с изолированным подключением к БД: окно не подвисает,
// прогресс и затраченное время отображаются в статус-баре.

interface

uses
    BaseFormUI,
    Core.Entities.Snippet,
    Core.Interfaces.App,
    SecurityReport,
    System.Classes,
    System.Generics.Collections,
    System.Threading,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.StdCtrls
    ;

type
    // Результат фонового сканирования, передаваемый в UI-поток одним куском
    TScanOutcome = record
        Findings: TArray<TSecurityFinding>;
        SnippetCount: Integer;
        ElapsedMs: Int64;
    end;

    TSecurityReportForm = class(TBaseForm)
        lbSummary: TLabel;
        lvFindings: TListView;
        pBottom: TPanel;
        lbFilter: TLabel;
        cbFilter: TComboBox;
        bRescan: TButton;
        bClose: TButton;
        sbBottom: TStatusBar;
        procedure lvFindingsDblClick(Sender: TObject);
        procedure cbFilterChange(Sender: TObject);
        procedure bRescanClick(Sender: TObject);
        procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    protected
        procedure DoInitialize; override;
    private const
        fltAll = 0;
        fltNotTrusted = 1;
    private
        FFindings: TArray<TSecurityFinding>;
        FSnippetCount: Integer;
        FCategoryNames: TDictionary<Integer, string>;
        FScanTask: ITask;
        FScanGeneration: Integer;
        FScanInProgress: Boolean;

        function GetCategoryName(CategoryID: Integer): string;
        function ComposeReason(const Finding: TSecurityFinding): string;
        procedure ApplyFilter;
        procedure FinishScanUI;
        procedure ApplyScanOutcome(const Outcome: TScanOutcome);
        procedure StartScan;
    public
        class procedure Execute(Owner: TComponent; AppContext: IAppContext);
        destructor Destroy; override;
    end;

implementation

{$R *.dfm}

uses
    AddEditSnippetFormUI,
    Common.Helpers,
    Common.Localization,
    Core.Entities.Category,
    Core.Interfaces.Services,
    SecurityScanner,
    System.Diagnostics,
    System.SysUtils,
    Winapi.Windows
    ;

{ TSecurityReportForm }

class procedure TSecurityReportForm.Execute(Owner: TComponent;
    AppContext: IAppContext);
var
    Frm: TSecurityReportForm;
begin
    Frm := TSecurityReportForm.Create(Owner);
    try
        Frm.LockDrawing;
        try
            Frm.Initialize(AppContext);
            Frm.StartScan;
        finally
            Frm.UnlockDrawing;
        end;
        Frm.WarmUpPaint;
        Frm.PrepareGuardedShow;
        Frm.ShowModal;
    finally
        Frm.Free;
    end;
end;

// Кеш имён категорий принадлежит окну: без явного освобождения TDictionary
// остаётся в памяти после закрытия отчёта вместе со всеми закешированными
// строками (FastMM показывает их как UnicodeString)
destructor TSecurityReportForm.Destroy;
begin
    FreeAndNil(FCategoryNames);
    inherited Destroy;
end;

procedure TSecurityReportForm.DoInitialize;
begin
    inherited;
    FCategoryNames := TDictionary<Integer, string>.Create;
    OnCloseQuery := FormCloseQuery;

    cbFilter.Items.BeginUpdate;
    try
        cbFilter.Items.Clear;
        cbFilter.Items.Add(TUIStateLoader.GetMessage('Security.ReportFilterAll'));
        cbFilter.Items.Add(TUIStateLoader.GetMessage('Security.ReportFilterNotTrusted'));
    finally
        cbFilter.Items.EndUpdate;
    end;
    cbFilter.ItemIndex := fltAll;
end;

procedure TSecurityReportForm.FormCloseQuery(Sender: TObject;
    var CanClose: Boolean);
begin
    // Пока идёт сканирование, форма не закрывается: фоновая задача замкнута
    // на контролы формы, и её очередь UI-вызовов должна успеть отработать
    CanClose := not FScanInProgress;
end;

// Имена категорий читаются лениво одним запросом на категорию и кешируются
// на всё время жизни окна: отчёт пересчитывается после правки, но категории
// за это время не меняются
function TSecurityReportForm.GetCategoryName(CategoryID: Integer): string;
var
    Cat: TCategoryDTO;
begin
    if FCategoryNames = nil then
        FCategoryNames := TDictionary<Integer, string>.Create;

    if not FCategoryNames.TryGetValue(CategoryID, Result) then
    begin
        Cat := AppContext.CategoryService.GetCategoryByID(CategoryID);
        if Cat.ID <> 0 then
            Result := Cat.Name
        else
            Result := '';
        FCategoryNames.Add(CategoryID, Result);
    end;
end;

function TSecurityReportForm.ComposeReason(
    const Finding: TSecurityFinding): string;
begin
    Result := '';

    if Finding.ContentReason <> '' then
        Result := TUIStateLoader.GetMessage(
            'Security.ReportInContent', [Finding.ContentReason]);

    if Finding.CommentReason <> '' then
    begin
        if Result <> '' then
            Result := Result + '; ';
        Result := Result + TUIStateLoader.GetMessage(
            'Security.ReportInComment', [Finding.CommentReason]);
    end;
end;

// Полный пересчёт в фоновом потоке: выборка сниппетов и прогон сканера идут
// через изолированный сервис со своим подключением к БД (см. SearchController),
// UI остаётся отзывчивым. Пока задача не завершилась, закрытие окна и повторный
// запуск заблокированы, поэтому замыкания задачи не могут пережить форму.
procedure TSecurityReportForm.StartScan;
var
    Generation: Integer;
begin
    if FScanInProgress then
        Exit;

    Inc(FScanGeneration);
    Generation := FScanGeneration;
    FScanInProgress := True;
    bRescan.Enabled := False;
    cbFilter.Enabled := False;
    bClose.Enabled := False;
    sbBottom.SimpleText := TUIStateLoader.GetMessage('Security.ReportScanning');

    FScanTask := TTask.Run(
        procedure
        var
            Outcome: TScanOutcome;
            BgConnection: TComponent;
            BgService: ISnippetService;
            BgScanner: ISecurityScanner;
            Snippets: TArray<TSnippetDTO>;
            SW: TStopwatch;
        begin
            try
                BgService := FAppContext.CreateIsolatedSnippetService(BgConnection);
                try
                    if TTask.CurrentTask.Status = TTaskStatus.Canceled then
                        Exit;

                    // Сканер создаётся локально в потоке: он не имеет
                    // состояния, делиться экземпляром из AppContext незачем.
                    // Для аудита – строгий режим: ложные срабатывания здесь
                    // приемлемы, пропустить настоящий секрет – нет.
                    BgScanner := TSecurityScanner.Create(scanStrict);

                    SW := TStopwatch.StartNew;
                    Snippets := BgService.GetAllSnippets(0);
                    Outcome.SnippetCount := Length(Snippets);
                    Outcome.Findings := BuildSecurityReport(BgScanner, Snippets);
                    SW.Stop;
                    Outcome.ElapsedMs := SW.ElapsedMilliseconds;

                    if TTask.CurrentTask.Status = TTaskStatus.Canceled then
                        Exit;

                    TThread.Queue(nil,
                        procedure
                        begin
                            if Generation <> FScanGeneration then
                                Exit;
                            ApplyScanOutcome(Outcome);
                        end);
                finally
                    if Assigned(BgConnection) then
                        BgConnection.Free;
                end;
            except
                on E: Exception do
                begin
                    LogException('TSecurityReportForm.StartScan', E);
                    TThread.Queue(nil,
                        procedure
                        begin
                            if Generation <> FScanGeneration then
                                Exit;
                            FinishScanUI;
                            sbBottom.SimpleText := TUIStateLoader.GetMessage(
                                'Security.ReportScanError', [E.Message]);
                        end);
                end;
            end;
        end);
end;

procedure TSecurityReportForm.FinishScanUI;
begin
    FScanInProgress := False;
    FScanTask := nil;
    bRescan.Enabled := True;
    cbFilter.Enabled := True;
    bClose.Enabled := True;
end;

procedure TSecurityReportForm.ApplyScanOutcome(const Outcome: TScanOutcome);
begin
    FinishScanUI;
    FFindings := Outcome.Findings;
    FSnippetCount := Outcome.SnippetCount;

    ApplyFilter;

    if Length(FFindings) > 0 then
        lbSummary.Caption := TUIStateLoader.GetMessage('Security.ReportSummary',
            [FSnippetCount, Length(FFindings)])
    else
        lbSummary.Caption := TUIStateLoader.GetMessage('Security.ReportSummaryClean',
            [FSnippetCount]);

    sbBottom.SimpleText := TUIStateLoader.GetMessage('Security.ReportScanTime',
        [FormatFloat('0.00', Outcome.ElapsedMs / 1000)]);
end;

// Перезаливка списка из кеша FFindings без повторного прогона сканера
procedure TSecurityReportForm.ApplyFilter;
var
    VisibleFindings: TArray<TSecurityFinding>;
    Finding: TSecurityFinding;
    Item: TListItem;
begin
    VisibleFindings := FilterSecurityReport(FFindings,
        cbFilter.ItemIndex = fltNotTrusted);

    lvFindings.Items.BeginUpdate;
    try
        lvFindings.Items.Clear;

        for Finding in VisibleFindings do
        begin
            Item := lvFindings.Items.Add;
            Item.Caption := Finding.Title;
            Item.Data := Pointer(IntPtr(Finding.SnippetID));
            Item.SubItems.Add(GetCategoryName(Finding.CategoryID));
            Item.SubItems.Add(ComposeReason(Finding));
            if Finding.Trusted then
                Item.SubItems.Add(TUIStateLoader.GetMessage('Security.ReportTrusted'))
            else
                Item.SubItems.Add(TUIStateLoader.GetMessage('Security.ReportNotTrusted'));
        end;
    finally
        lvFindings.Items.EndUpdate;
    end;
end;

procedure TSecurityReportForm.lvFindingsDblClick(Sender: TObject);
var
    Item: TListItem;
    Snippet: TSnippetDTO;
begin
    // Во время сканирования список перестраивается: открытие сниппета откладываем
    if FScanInProgress then
        Exit;

    Item := lvFindings.Selected;
    if (Item = nil) or not Assigned(Item.Data) then
        Exit;

    Snippet := AppContext.SnippetService.GetSnippetByID(
        Integer(IntPtr(Item.Data)));
    if Snippet.ID = 0 then
        Exit;

    // После правки пересчитываем отчёт: сниппет мог быть исправлен
    if TAddEditSnippetForm.ExecuteEdit(Self, AppContext, Snippet) then
        StartScan;
end;

procedure TSecurityReportForm.bRescanClick(Sender: TObject);
begin
    StartScan;
end;

procedure TSecurityReportForm.cbFilterChange(Sender: TObject);
begin
    ApplyFilter;
end;

end.
