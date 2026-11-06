unit SecurityReport;

// Отчёт сканера безопасности по всей базе: прогон ISecurityScanner по
// содержимому и комментарию каждого сниппета. Логика отделена от UI,
// чтобы покрываться консольными тестами без создания форм.

interface

uses
    SecurityScanner,
    Core.Entities.Snippet
    ;

type
    TSecurityFinding = record
        SnippetID: Integer;
        UserID: Integer;
        CategoryID: Integer;
        Title: string;
        // IsSecurityCheckIgnored не исключает сниппет из отчёта, а помечает
        // его как доверенный: пользователь осознанно взял риск на себя
        Trusted: Boolean;
        // Причина срабатывания отдельно для содержимого и комментария;
        // пустая строка - в этой части сниппета чувствительных данных нет
        ContentReason: string;
        CommentReason: string;
    end;

// Прогон сканера по всем переданным сниппетам. Возвращаются только записи,
// у которых есть хотя бы одна причина срабатывания.
function BuildSecurityReport(const Scanner: ISecurityScanner;
    const Snippets: TArray<TSnippetDTO>): TArray<TSecurityFinding>;

// Отбор записей для отображения из уже собранного отчёта: HideTrusted=True
// скрывает сниппеты, для которых включено "доверять" (IsSecurityCheckIgnored).
// Фильтрация списка не запускает повторное сканирование базы.
function FilterSecurityReport(const Findings: TArray<TSecurityFinding>;
    HideTrusted: Boolean): TArray<TSecurityFinding>;

implementation

function BuildSecurityReport(const Scanner: ISecurityScanner;
    const Snippets: TArray<TSnippetDTO>): TArray<TSecurityFinding>;
var
    Snippet: TSnippetDTO;
    Finding: TSecurityFinding;
    Reason: string;
begin
    Result := [];

    if not Assigned(Scanner) then
        Exit;

    for Snippet in Snippets do
    begin
        Finding := Default(TSecurityFinding);
        Finding.SnippetID := Snippet.ID;
        Finding.UserID := Snippet.UserID;
        Finding.CategoryID := Snippet.CategoryID;
        Finding.Title := Snippet.Title;
        Finding.Trusted := Snippet.IsSecurityCheckIgnored;

        if Scanner.HasSensitiveData(Snippet.Content, Reason) then
            Finding.ContentReason := Reason;

        if Scanner.HasSensitiveData(Snippet.Comment, Reason) then
            Finding.CommentReason := Reason;

        if (Finding.ContentReason <> '') or (Finding.CommentReason <> '') then
            Result := Result + [Finding];
    end;
end;

function FilterSecurityReport(const Findings: TArray<TSecurityFinding>;
    HideTrusted: Boolean): TArray<TSecurityFinding>;
var
    Finding: TSecurityFinding;
begin
    Result := [];

    for Finding in Findings do
        if not (HideTrusted and Finding.Trusted) then
            Result := Result + [Finding];
end;

end.
