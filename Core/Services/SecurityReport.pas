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

end.
