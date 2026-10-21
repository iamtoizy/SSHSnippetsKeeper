unit SnippetHistoryRepository;

interface

uses
    Core.Entities.Snippet,
    Core.Interfaces.Data,
    FireDAC.Comp.Client,
    RepositoryBase,
    System.Generics.Collections
    ;

type
    TSnippetHistoryRepository = class(TRepositoryBase, ISnippetHistoryRepository)
    private
        function InternalLoadVersions(const SQL: string; const Params: array of Variant): TArray<TSnippetVersionDTO>;
    public
        function GetVersions(SnippetID, Limit: Integer): TArray<TSnippetVersionDTO>;
        function GetVersion(VersionID: Integer): TSnippetVersionDTO;
        function GetVersionCount(SnippetID: Integer): Integer;
        procedure DeleteOldest(SnippetID, KeepCount: Integer);
        procedure SetSuppressed(Suppressed: Boolean);
    end;

implementation

uses
    System.SysUtils
    ;

const
    SQL_SELECT_FIELDS = 'SELECT id, snippet_id, title, content, comment, category_id, changed_at FROM snippet_history';
    SQL_GET_VERSIONS = SQL_SELECT_FIELDS + ' WHERE snippet_id = ? ORDER BY changed_at DESC, id DESC';
    SQL_GET_VERSIONS_LIMITED = SQL_GET_VERSIONS + ' LIMIT ?';
    SQL_GET_VERSION = SQL_SELECT_FIELDS + ' WHERE id = ?';
    SQL_GET_VERSION_COUNT = 'SELECT COUNT(*) FROM snippet_history WHERE snippet_id = ?';
    SQL_PRUNE_OLDEST =
        'DELETE FROM snippet_history WHERE snippet_id = ? AND id NOT IN ' +
        '(SELECT id FROM snippet_history WHERE snippet_id = ? ORDER BY changed_at DESC, id DESC LIMIT ?)';
    SQL_SET_SUPPRESSED = 'UPDATE service_flags SET value = ? WHERE name = ''history_suppressed''';

{ TSnippetHistoryRepository }

function TSnippetHistoryRepository.InternalLoadVersions(const SQL: string;
    const Params: array of Variant): TArray<TSnippetVersionDTO>;
var
    Query: TFDQuery;
    List: TList<TSnippetVersionDTO>;
    Ver: TSnippetVersionDTO;
begin
    Result := [];

    List := TList<TSnippetVersionDTO>.Create;
    Query := CreateQuery;
    try
        Query.SQL.Text := SQL;
        SetQueryParams(Query, Params);
        Query.Open;

        while not Query.Eof do
        begin
            Ver.ID := Query.FieldByName('id').AsInteger;
            Ver.SnippetID := Query.FieldByName('snippet_id').AsInteger;
            Ver.Title := Query.FieldByName('title').AsString;
            Ver.Content := Query.FieldByName('content').AsString;
            Ver.Comment := Query.FieldByName('comment').AsString;
            Ver.CategoryID := Query.FieldByName('category_id').AsInteger;
            Ver.ChangedAt := Query.FieldByName('changed_at').AsLargeInt;
            List.Add(Ver);
            Query.Next;
        end;

        Result := List.ToArray;
    finally
        Query.Free;
        List.Free;
    end;
end;

function TSnippetHistoryRepository.GetVersions(SnippetID, Limit: Integer): TArray<TSnippetVersionDTO>;
begin
    if Limit > 0 then
        Result := InternalLoadVersions(SQL_GET_VERSIONS_LIMITED, [SnippetID, Limit])
    else
        Result := InternalLoadVersions(SQL_GET_VERSIONS, [SnippetID]);
end;

function TSnippetHistoryRepository.GetVersion(VersionID: Integer): TSnippetVersionDTO;
var
    Arr: TArray<TSnippetVersionDTO>;
begin
    Arr := InternalLoadVersions(SQL_GET_VERSION, [VersionID]);
    if Length(Arr) > 0 then
        Exit(Arr[0]);
    Result := Default(TSnippetVersionDTO);
end;

function TSnippetHistoryRepository.GetVersionCount(SnippetID: Integer): Integer;
begin
    Result := ExecuteSQLScalar(SQL_GET_VERSION_COUNT, [SnippetID]);
end;

procedure TSnippetHistoryRepository.DeleteOldest(SnippetID, KeepCount: Integer);
begin
    if KeepCount <= 0 then
        ExecuteSQL('DELETE FROM snippet_history WHERE snippet_id = ?', [SnippetID])
    else
        ExecuteSQL(SQL_PRUNE_OLDEST, [SnippetID, SnippetID, KeepCount]);
end;

procedure TSnippetHistoryRepository.SetSuppressed(Suppressed: Boolean);
var
    Value: string;
begin
    if Suppressed then
        Value := '1'
    else
        Value := '0';
    ExecuteSQL(SQL_SET_SUPPRESSED, [Value]);
end;

end.
