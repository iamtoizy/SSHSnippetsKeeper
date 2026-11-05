unit SecurityReportFormUI;

// Отчёт сканера безопасности по всей базе: список сниппетов, в содержимом
// или комментарии которых сканер нашёл чувствительные данные. Двойной клик
// открывает сниппет на правку; после закрытия редактора отчёт пересчитывается.

interface

uses
    BaseFormUI,
    Core.Entities.Snippet,
    Core.Interfaces.App,
    SecurityReport,
    System.Classes,
    System.Generics.Collections,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.StdCtrls
    ;

type
    TSecurityReportForm = class(TBaseForm)
        lbSummary: TLabel;
        lvFindings: TListView;
        pBottom: TPanel;
        bClose: TButton;
        procedure lvFindingsDblClick(Sender: TObject);
    protected
        procedure DoInitialize; override;
    private
        FFindings: TArray<TSecurityFinding>;
        FCategoryNames: TDictionary<Integer, string>;

        function GetCategoryName(CategoryID: Integer): string;
        function ComposeReason(const Finding: TSecurityFinding): string;
        procedure Rescan;
    public
        class procedure Execute(Owner: TComponent; AppContext: IAppContext);
    end;

implementation

{$R *.dfm}

uses
    AddEditSnippetFormUI,
    Common.Localization,
    Core.Entities.Category,
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
            Frm.Rescan;
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

procedure TSecurityReportForm.DoInitialize;
begin
    inherited;
    FCategoryNames := TDictionary<Integer, string>.Create;
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

procedure TSecurityReportForm.Rescan;
var
    Snippets: TArray<TSnippetDTO>;
    Findings: TArray<TSecurityFinding>;
    Finding: TSecurityFinding;
    Item: TListItem;
    Summary: string;
begin
    lvFindings.Items.BeginUpdate;
    try
        FCategoryNames.Free;
        FCategoryNames := TDictionary<Integer, string>.Create;

        lvFindings.Items.Clear;

        // Вся база, все пользователи: UserID = 0 снимает фильтр пространства
        Snippets := AppContext.SnippetService.GetAllSnippets(0);
        FFindings := BuildSecurityReport(AppContext.SecurityScanner, Snippets);

        for Finding in FFindings do
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

        if Length(FFindings) > 0 then
            Summary := TUIStateLoader.GetMessage('Security.ReportSummary',
                [Length(Snippets), Length(FFindings)])
        else
            Summary := TUIStateLoader.GetMessage('Security.ReportSummaryClean',
                [Length(Snippets)]);
        lbSummary.Caption := Summary;
    finally
        lvFindings.Items.EndUpdate;
    end;
end;

procedure TSecurityReportForm.lvFindingsDblClick(Sender: TObject);
var
    Item: TListItem;
    Snippet: TSnippetDTO;
begin
    Item := lvFindings.Selected;
    if (Item = nil) or not Assigned(Item.Data) then
        Exit;

    Snippet := AppContext.SnippetService.GetSnippetByID(
        Integer(IntPtr(Item.Data)));
    if Snippet.ID = 0 then
        Exit;

    // После правки пересчитываем отчёт: сниппет мог быть исправлен
    if TAddEditSnippetForm.ExecuteEdit(Self, AppContext, Snippet) then
        Rescan;
end;

end.
