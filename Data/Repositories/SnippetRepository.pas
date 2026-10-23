unit SnippetRepository;

interface

uses
    Core.Entities.Snippet,
    Core.Entities.Tag,
    Core.Interfaces.Data,
    Common.QueryLanguage,
    FireDAC.Comp.Client,
    RepositoryBase,
    System.Generics.Collections
    ;

type
    TSnippetRepository = class(TRepositoryBase, ISnippetRepository)
    private
        function InternalLoadSnippets(const SQL: string; const Params: array of Variant): TArray<TSnippetDTO>;
        function GetSnippetTagsBatch(const SnippetIDs: TArray<Integer>): TDictionary<Integer, TArray<TTagDTO>>;
    public
        function Add(const Snippet: TSnippetDTO): Integer;
        procedure Update(const Snippet: TSnippetDTO);
        procedure Delete(ID: Integer);
        function GetById(ID: Integer): TSnippetDTO;
        function GetAll(UserID: Integer = 0): TArray<TSnippetDTO>;
        function GetSnippetByCategory(const CategoryID, UserID: Integer): TArray<TSnippetDTO>;
        procedure RecordRun(SnippetID: Integer; UserID: Integer);
        function GetSnippetTags(SnippetID: Integer): TArray<TTagDTO>;
        function GetSnippetsByTag(const TagID: Integer): TArray<TSnippetDTO>;
        function GetSnippetsByTags(const TagIDs: TArray<Integer>; MatchAll: Boolean = False): TArray<TSnippetDTO>;
        function Search(const Query: string): TArray<TSnippetDTO>;
        function SearchByMaskFTS(const Mask: string; UserID: Integer = 0): TArray<TSnippetDTO>;
        function SearchByMaskSimple(const Mask: string; UserID: Integer = 0): TArray<TSnippetDTO>;
        function SearchAdvanced(const Query: TStructuredQuery; UseFTS: Boolean; UserID: Integer = 0): TArray<TSnippetDTO>;
        procedure UpdateTags(SnippetID: Integer; const TagIDs: TArray<Integer>);
        procedure MoveToWorkspace(SnippetID, NewUserID, NewCategoryID: Integer);
        function GetRecentSnippets(UserID: Integer; Limit: Integer): TArray<TSnippetDTO>;
        function GetTopSnippets(UserID: Integer; Limit: Integer): TArray<TSnippetDTO>;
        function GetSnippetCountByCategory(UserID: Integer): TDictionary<Integer, Integer>;
        function GetFavorites(UserID: Integer): TArray<TSnippetDTO>;
        function GetFavoriteOrder(UserID: Integer): TArray<Integer>;
        function IsFavorite(SnippetID, UserID: Integer): Boolean;
        procedure AddFavorite(SnippetID, UserID: Integer);
        procedure RemoveFavorite(SnippetID, UserID: Integer);
        procedure MoveFavorite(SnippetID, UserID, NewPosition: Integer);
        function GetLastRunSnippetID(UserID: Integer): Integer;
    end;

implementation

uses
    Data.DB,
    FireDAC.Stan.Param,
    System.Classes,
    System.SysUtils,
    System.Variants
    ;

const
    SQL_GET_ALL_SNIPPETS_BASE = 'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at, key_delay_ms FROM snippets';
    SQL_ADD_SNIPPET = 'INSERT INTO snippets (user_id, category_id, title, content, comment, key_delay_ms, created_at, updated_at) ' +
            'VALUES (:user_id, :cat_id, :title, :content, :comment, :key_delay_ms, :created_at, :updated_at)';
    SQL_DELETE_SNIPPET = 'DELETE FROM snippets WHERE id = :id';
    SQL_GET_ALL_SNIPPETS = 'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at, key_delay_ms FROM snippets ORDER BY title';
    SQL_UPDATE_SNIPPET = 'UPDATE snippets SET title = :title, content = :content, ' +
        'comment = :comment, category_id = :category_id, updated_at = :updated_at, key_delay_ms = :key_delay_ms ' +
        'WHERE id = :id';
    SQL_UPDATE_TAGS_DELETE_QUERY = 'DELETE FROM snippet_tags WHERE snippet_id = :id';
    SQL_UPDATE_TAGS_INSERT_QUERY = 'INSERT INTO snippet_tags (snippet_id, tag_id) VALUES (:snip_id, :tag_id)';
    SQL_SELECT_SNIPPETS_BY_ID = 'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at, key_delay_ms FROM snippets WHERE id = ?';
    SQL_SELECT_SNIPPETS_BY_CATEGORY =
        'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at, key_delay_ms FROM snippets WHERE category_id = ? ORDER BY title';
    SQL_SELECT_SNIPPETS_BY_CATEGORY_USER =
        'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at, key_delay_ms FROM snippets WHERE category_id = ? AND user_id = ? ORDER BY title';
    SQL_SELECT_SNIPPETS_BY_TAG =
        'SELECT s.id, s.user_id, s.title, s.content, s.comment, ' +
        's.category_id, s.created_at, s.updated_at, s.key_delay_ms ' +
        'FROM snippets s ' +
        'JOIN snippet_tags st ON s.id = st.snippet_id ' +
        'WHERE st.tag_id = ? ' +
        'ORDER BY s.title';
    SQL_SELECT_SNIPPET_TAGS = 'SELECT t.id, t.name FROM tags t JOIN snippet_tags st ON t.id = st.tag_id WHERE st.snippet_id = :SnippetID ORDER BY t.name';
    SQL_FULLTEXT_SEARCH = 'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at, key_delay_ms ' + 'FROM snippets ' +
        'WHERE title LIKE :m COLLATE NOCASE ' + '   OR content LIKE :m COLLATE NOCASE ' + 'ORDER BY updated_at DESC, title ASC';
    SQL_SNIPPET_SEARCH = 'SELECT s.id, s.title, s.category_id, snippet_fts.rank ' + 'FROM snippet_fts ' + 'JOIN snippets s ON s.id = snippet_fts.rowid ' +
        'WHERE snippet_fts MATCH :search ' + 'ORDER BY rank DESC';
//    SQL_SEARCH_BY_MASK_FTS = 'SELECT s.id, s.user_id, s.title, s.content, s.category_id, s.created_at, s.updated_at, snippet_fts.rank ' +
//        'FROM snippet_fts ' +
//        'JOIN snippets s ON s.rowid = snippet_fts.rowid ' + // В FTS5 rowid совпадает с ID сниппета
//        'WHERE snippet_fts MATCH :term ' + 'ORDER BY rank ASC'; // Чем меньше rank, тем точнее совпадение;
    SQL_RECORD_RUN = 'INSERT INTO snippet_runs (snippet_id, run_at, executed_by_user_id) VALUES (?, strftime(''%s'', ''now''), ?)';
    SQL_RECORD_RUN_NO_USER = 'INSERT INTO snippet_runs (snippet_id, run_at, executed_by_user_id) VALUES (?, strftime(''%s'', ''now''), NULL)';
    SQL_GET_SNIPPET_BY_CATEGORY_ID_WITH_USER_ID = 'SELECT category_id, COUNT(*) AS cnt FROM snippets WHERE user_id = ? GROUP BY category_id';
    SQL_GET_SNIPPET_BY_CATEGORY_ID_NO_USER_ID = 'SELECT category_id, COUNT(*) AS cnt FROM snippets GROUP BY category_id';
    SQL_GET_TOP_SNIPPETS =
        'SELECT s.id, s.user_id, s.title, s.content, s.comment, s.category_id, s.created_at, s.updated_at, s.key_delay_ms ' +
        'FROM snippets s ' +
        'JOIN snippet_stats st ON st.snippet_id = s.id ' +
        'WHERE s.user_id = ? ' +
        'ORDER BY st.exec_count DESC, st.last_exec_at DESC ' +
        'LIMIT ?';
    SQL_GET_RECENT_SNIPPETS =
        'SELECT s.id, s.user_id, s.title, s.content, s.comment, s.category_id, s.created_at, s.updated_at, s.key_delay_ms ' +
        'FROM snippets s ' +
        'JOIN snippet_stats st ON st.snippet_id = s.id ' +
        'WHERE s.user_id = ? ' +
        'ORDER BY st.last_exec_at DESC ' +
        'LIMIT ?';
    SQL_SELECT_SNIPPETS_BY_TAGS_ANY =
        'SELECT DISTINCT s.id, s.user_id, s.title, s.content, s.comment, ' +
        's.category_id, s.created_at, s.updated_at, s.key_delay_ms ' +
        'FROM snippets s ' +
        'JOIN snippet_tags st ON s.id = st.snippet_id ' +
        'WHERE st.tag_id IN (%s) ' +
        'ORDER BY s.title';

    SQL_SELECT_SNIPPETS_BY_TAGS_ALL =
        'SELECT s.id, s.user_id, s.title, s.content, s.comment, ' +
        's.category_id, s.created_at, s.updated_at, s.key_delay_ms ' +
        'FROM snippets s ' +
        'JOIN snippet_tags st ON s.id = st.snippet_id ' +
        'WHERE st.tag_id IN (%s) ' +
        'GROUP BY s.id ' +
        'HAVING COUNT(DISTINCT st.tag_id) = %d ' +
        'ORDER BY s.title';

    SQL_GET_FAVORITES_ALL =
        'SELECT s.id, s.user_id, s.title, s.content, s.comment, s.category_id, s.created_at, s.updated_at, s.key_delay_ms ' +
        'FROM snippet_favorites f ' +
        'JOIN snippets s ON s.id = f.snippet_id ' +
        'ORDER BY f.user_id, f.sort_order, f.created_at';
    SQL_GET_FAVORITES_BY_USER =
        'SELECT s.id, s.user_id, s.title, s.content, s.comment, s.category_id, s.created_at, s.updated_at, s.key_delay_ms ' +
        'FROM snippet_favorites f ' +
        'JOIN snippets s ON s.id = f.snippet_id ' +
        'WHERE f.user_id = ? ' +
        'ORDER BY f.sort_order, f.created_at';
    SQL_GET_FAVORITE_ORDER = 'SELECT snippet_id FROM snippet_favorites WHERE user_id = ? ORDER BY sort_order, created_at';
    SQL_GET_FAVORITE_ORDER_ALL = 'SELECT snippet_id FROM snippet_favorites ORDER BY user_id, sort_order, created_at';
    SQL_IS_FAVORITE = 'SELECT COUNT(*) FROM snippet_favorites WHERE user_id = ? AND snippet_id = ?';
    SQL_ADD_FAVORITE =
        'INSERT OR IGNORE INTO snippet_favorites (user_id, snippet_id, sort_order) ' +
        'VALUES (?, ?, (SELECT COALESCE(MAX(sort_order) + 1, 0) FROM snippet_favorites WHERE user_id = ?))';
    SQL_REMOVE_FAVORITE = 'DELETE FROM snippet_favorites WHERE user_id = ? AND snippet_id = ?';
    SQL_UPDATE_FAVORITE_ORDER = 'UPDATE snippet_favorites SET sort_order = ? WHERE snippet_id = ?';
    SQL_GET_LAST_RUN =
        'SELECT snippet_id FROM snippet_runs WHERE executed_by_user_id = ? ORDER BY run_at DESC, id DESC LIMIT 1';
    SQL_GET_LAST_RUN_NO_USER = 'SELECT snippet_id FROM snippet_runs ORDER BY run_at DESC, id DESC LIMIT 1';

function SanitizeFTS5(const Input: string): string;
var
    C: Char;
    Sb: TStringBuilder;
begin
    if Input = '' then
        Exit('');

    Sb := TStringBuilder.Create;
    try
        for C in Input do
        begin
            // Удаляем или заменяем на пробел зарезервированные символы FTS5
            // В FTS5 спецсимволы: * ^ " ' [ ] ( ) { } : + - ~
            if CharInSet(C, ['*', '^', '"', '''', '[', ']', '(', ')', '{', '}', ':', '+', '-', '~']) then
                Sb.Append(' ')
            else
                Sb.Append(C);
        end;
        // Убираем двойные пробелы и пробелы по краям
        Result := Trim(Sb.ToString);
        while Result.IndexOf('  ') >= 0 do
            Result := Result.Replace('  ', ' ');
    finally
        Sb.Free;
    end;
end;

procedure TSnippetRepository.Delete(ID: Integer);
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        // Каскадно удалятся: snippet_tags, snippet_runs, snippet_stats,
        // FTS записи (благодаря триггерам и ON DELETE CASCADE)
        Q.SQL.Text := SQL_DELETE_SNIPPET;
        Q.ParamByName('id').AsInteger := ID;
        Q.ExecSQL;
    finally
        Q.Free;
    end;
end;

function TSnippetRepository.GetAll(UserID: Integer = 0): TArray<TSnippetDTO>;
var
    SQL: string;
begin
    SQL := SQL_GET_ALL_SNIPPETS_BASE;
    if UserID > 0 then
        Result := InternalLoadSnippets(SQL + ' WHERE user_id = ? ORDER BY title', [UserID])
    else
        Result := InternalLoadSnippets(SQL + ' ORDER BY title', []);
end;

function TSnippetRepository.GetById(ID: Integer): TSnippetDTO;
var
    Arr: TArray<TSnippetDTO>;
begin
    Arr := InternalLoadSnippets(SQL_SELECT_SNIPPETS_BY_ID, [ID]);
    if Length(Arr) > 0 then
        Exit(Arr[0]);
    Result := Default (TSnippetDTO);
end;

function TSnippetRepository.GetSnippetsByTag(const TagID: Integer): TArray<TSnippetDTO>;
begin
    Result := InternalLoadSnippets(SQL_SELECT_SNIPPETS_BY_TAG, [TagID]);
end;

function TSnippetRepository.GetSnippetsByTags(const TagIDs: TArray<Integer>; MatchAll: Boolean = False): TArray<TSnippetDTO>;
var
    Sb: TStringBuilder;
    I: Integer;
    Placeholders, SQL: string;
    Params: array of Variant;
begin
    if Length(TagIDs) = 0 then
        Exit(nil);

    // Собираем плейсхолдеры для IN (...); значения передаются через параметрический биндинг
    Sb := TStringBuilder.Create;
    try
        for I := 0 to High(TagIDs) do
        begin
            Sb.Append('?');
            if I < High(TagIDs) then
                Sb.Append(',');
        end;
        Placeholders := Sb.ToString;
    finally
        Sb.Free;
    end;

    SetLength(Params, Length(TagIDs));
    for I := 0 to High(TagIDs) do
        Params[I] := TagIDs[I];

    if MatchAll then
        SQL := Format(SQL_SELECT_SNIPPETS_BY_TAGS_ALL, [Placeholders, Length(TagIDs)])
    else
        SQL := Format(SQL_SELECT_SNIPPETS_BY_TAGS_ANY, [Placeholders]);

    Result := InternalLoadSnippets(SQL, Params);
end;

function TSnippetRepository.GetSnippetTags(SnippetID: Integer): TArray<TTagDTO>;
var
    Query: TFDQuery;
    Tag: TTagDTO;
    List: TList<TTagDTO>;
begin
    List := TList<TTagDTO>.Create;
    Query := CreateQuery;
    try
        Query.SQL.Text := SQL_SELECT_SNIPPET_TAGS;
        Query.ParamByName('SnippetID').AsInteger := SnippetID;
        Query.Open;

        while not Query.Eof do
        begin
            Tag.ID := Query.FieldByName('id').AsInteger;
            Tag.Name := Query.FieldByName('name').AsString;
            List.Add(Tag);
            Query.Next;
        end;
        Result := List.ToArray;
    finally
        List.Free;
        Query.Free;
    end;
end;

function TSnippetRepository.GetSnippetTagsBatch(const SnippetIDs: TArray<Integer>): TDictionary<Integer, TArray<TTagDTO>>;
const
    MAX_PARAMS = 900; // Защита от лимита SQLite
var
    Query: TFDQuery;
    Map: TDictionary<Integer, TList<TTagDTO>>;
    i, ChunkStart, ChunkEnd: Integer;
    Key: Integer;
    Tag: TTagDTO;
    ParamName: string;
    SQL: TStringBuilder;
    ChunkIDs: TArray<Integer>;
begin
    Result := nil;

    if Length(SnippetIDs) = 0 then
        Exit;

    Map := TDictionary<Integer, TList<TTagDTO>>.Create;
    try
        // ✅ Разбиваем на чанки
        ChunkStart := 0;
        while ChunkStart < Length(SnippetIDs) do
        begin
            ChunkEnd := ChunkStart + MAX_PARAMS;
            if ChunkEnd > Length(SnippetIDs) then
                ChunkEnd := Length(SnippetIDs);

            SetLength(ChunkIDs, ChunkEnd - ChunkStart);
            for i := ChunkStart to ChunkEnd - 1 do
                ChunkIDs[i - ChunkStart] := SnippetIDs[i];

            Query := CreateQuery;
            SQL := TStringBuilder.Create;
            try
                SQL.Append('SELECT st.snippet_id, t.id, t.name ');
                SQL.Append('FROM snippet_tags st ');
                SQL.Append('JOIN tags t ON t.id = st.tag_id ');
                SQL.Append('WHERE st.snippet_id IN (');

                for i := 0 to High(ChunkIDs) do
                begin
                    ParamName := 'id' + i.ToString;
                    SQL.Append(':' + ParamName);
                    if i < High(ChunkIDs) then
                        SQL.Append(',');
                end;

                SQL.Append(') ORDER BY t.name');

                Query.SQL.Text := SQL.ToString;

                for i := 0 to High(ChunkIDs) do
                begin
                    ParamName := 'id' + i.ToString;
                    Query.ParamByName(ParamName).AsInteger := ChunkIDs[i];
                end;

                Query.Open;

                while not Query.Eof do
                begin
                    Key := Query.FieldByName('snippet_id').AsInteger;

                    if not Map.ContainsKey(Key) then
                        Map.Add(Key, TList<TTagDTO>.Create);

                    Tag.ID := Query.FieldByName('id').AsInteger;
                    Tag.Name := Query.FieldByName('name').AsString;

                    Map[Key].Add(Tag);
                    Query.Next;
                end;
            finally
                SQL.Free;
                Query.Free;
            end;

            ChunkStart := ChunkEnd;
        end;

        // Преобразуем в результат
        var MappedData := TDictionary<Integer, TArray<TTagDTO>>.Create;
        for Key in Map.Keys do
            MappedData.Add(Key, Map[Key].ToArray);
        Result := MappedData;   // На случай исключения юзаю временную переменную
    finally
        for Key in Map.Keys do
            Map[Key].Free;
        Map.Free;
    end;
end;

function TSnippetRepository.InternalLoadSnippets(const SQL: string; const Params: array of Variant): TArray<TSnippetDTO>;
var
    Query: TFDQuery;
    List: TList<TSnippetDTO>;
    IDList: TList<Integer>;
    TagMap: TDictionary<Integer, TArray<TTagDTO>>;
    Snip: TSnippetDTO;
    I: Integer;
begin
    Result := [];

    List := TList<TSnippetDTO>.Create;
    IDList := TList<Integer>.Create;
    Query := CreateQuery;
    if not Assigned(Query.Connection) then
        Exit(Result);

    TagMap := nil;

    try
        Query.SQL.Text := SQL;
        SetQueryParams(Query, Params);
        Query.Open;

        while not Query.Eof do
        begin
            Snip.ID := Query.FieldByName('id').AsInteger;
            Snip.UserID := Query.FieldByName('user_id').AsInteger;
            Snip.Title := Query.FieldByName('title').AsString;
            Snip.Content := Query.FieldByName('content').AsString;
            Snip.Comment := Query.FieldByName('comment').AsString;
            Snip.CategoryID := Query.FieldByName('category_id').AsInteger;
            Snip.CreatedAt := Query.FieldByName('created_at').AsLargeInt;
            Snip.UpdatedAt := Query.FieldByName('updated_at').AsLargeInt;
            Snip.KeyDelayMs := Query.FieldByName('key_delay_ms').AsInteger;
            Snip.Tags := [];

            List.Add(Snip);
            IDList.Add(Snip.ID);

            Query.Next;
        end;

        TagMap := GetSnippetTagsBatch(IDList.ToArray);

        if Assigned(TagMap) then
            for i := 0 to List.Count - 1 do
                if TagMap.ContainsKey(List[i].ID) then
                begin
                    Snip := List[i];
                    Snip.Tags := TagMap[List[i].ID];
                    List[i] := Snip;
                end;

        Result := List.ToArray;
    finally
        Query.Free;
        List.Free;
        IDList.Free;

        if Assigned(TagMap) then
            TagMap.Free;
    end;
end;

procedure TSnippetRepository.Update(const Snippet: TSnippetDTO);
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        Q.SQL.Text := SQL_UPDATE_SNIPPET;
        Q.ParamByName('title').AsString := Snippet.Title;
        Q.ParamByName('content').AsString := Snippet.Content;
        Q.ParamByName('comment').AsString := Snippet.Comment;
        Q.ParamByName('category_id').AsInteger := Snippet.CategoryID;
        Q.ParamByName('updated_at').AsLargeInt := Snippet.UpdatedAt;
        Q.ParamByName('key_delay_ms').AsInteger := Snippet.KeyDelayMs;
        Q.ParamByName('id').AsInteger := Snippet.ID;
        Q.ExecSQL;
    finally
        Q.Free;
    end;
end;

procedure TSnippetRepository.UpdateTags(SnippetID: Integer; const TagIDs: TArray<Integer>);
var
    Q, QTags: TFDQuery;
    TagID: Integer;
begin
    // Удаляем все старые связи
    Q := CreateQuery;
    try
        Q.SQL.Text := SQL_UPDATE_TAGS_DELETE_QUERY;
        Q.ParamByName('id').AsInteger := SnippetID;
        Q.ExecSQL;
    finally
        Q.Free;
    end;

    // Добавляем новые связи
    if Length(TagIDs) > 0 then
    begin
        QTags := CreateQuery;
        try
            QTags.SQL.Text := SQL_UPDATE_TAGS_INSERT_QUERY;
            for TagID in TagIDs do
            begin
                QTags.ParamByName('snip_id').AsInteger := SnippetID;
                QTags.ParamByName('tag_id').AsInteger := TagID;
                QTags.ExecSQL;
            end;
        finally
            QTags.Free;
        end;
    end;
end;

procedure TSnippetRepository.MoveToWorkspace(SnippetID, NewUserID, NewCategoryID: Integer);
var
    OldUserID: Variant;
begin
    OldUserID := FConnection.ExecSQLScalar('SELECT user_id FROM snippets WHERE id = ?', [SnippetID]);
    if VarIsNull(OldUserID) or (Integer(OldUserID) = 0) then
        raise Exception.Create('Snippet not found: ' + SnippetID.ToString);

    FConnection.StartTransaction;
    try
        FConnection.ExecSQL('UPDATE snippets SET user_id = ?, category_id = ? WHERE id = ?',
            [NewUserID, NewCategoryID, SnippetID]);

        FConnection.ExecSQL('UPDATE OR IGNORE snippet_favorites SET user_id = ? WHERE snippet_id = ? AND user_id = ?',
            [NewUserID, SnippetID, Integer(OldUserID)]);

        FConnection.ExecSQL('DELETE FROM snippet_favorites WHERE snippet_id = ? AND user_id = ?',
            [SnippetID, Integer(OldUserID)]);

        FConnection.Commit;
    except
        FConnection.Rollback;
        raise;
    end;
end;

function TSnippetRepository.Add(const Snippet: TSnippetDTO): Integer;
var
    Q: TFDQuery;
    SnippetID: Integer;
begin
    // Вставка сниппета
    Q := CreateQuery;
    try
        Q.SQL.Text := SQL_ADD_SNIPPET;
        Q.ParamByName('user_id').AsInteger := Snippet.UserID;
        Q.ParamByName('cat_id').AsInteger := Snippet.CategoryID;
        Q.ParamByName('title').AsString := Snippet.Title;
        Q.ParamByName('content').AsString := Snippet.Content;
        Q.ParamByName('comment').AsString := Snippet.Comment;
        Q.ParamByName('key_delay_ms').AsInteger := Snippet.KeyDelayMs;
        Q.ParamByName('created_at').AsLargeInt := Snippet.CreatedAt;
        Q.ParamByName('updated_at').DataType := ftLargeInt;

        if Snippet.UpdatedAt > 0 then
            Q.ParamByName('updated_at').AsLargeInt := Snippet.UpdatedAt
        else
            Q.ParamByName('updated_at').Clear;

        Q.ExecSQL;

        Q.SQL.Text := 'SELECT last_insert_rowid()';
        Q.Open;
        SnippetID := Q.Fields[0].AsInteger;
        Result := SnippetID;
    finally
        Q.Free;
    end;
end;

function TSnippetRepository.Search(const Query: string): TArray<TSnippetDTO>;
var
    Q: TFDQuery;
    List: TList<TSnippetDTO>;
begin
    List := TList<TSnippetDTO>.Create;
    Q := CreateQuery;
    try
        Q.SQL.Text := SQL_SNIPPET_SEARCH;

        Q.Params.ParamByName('search').AsString := Query;
        Q.Open;

        while not Q.Eof do
        begin
            var Snippet: TSnippetDTO;
            Snippet.ID := Q.FieldByName('id').AsInteger;
            Snippet.Title := Q.FieldByName('title').AsString;
            Snippet.CategoryID := Q.FieldByName('category_id').AsInteger;
            List.Add(Snippet);
            Q.Next;
        end;

        Result := List.ToArray;
    finally
        Q.Free;
        List.Free;
    end;
end;

function TSnippetRepository.SearchByMaskFTS(const Mask: string; UserID: Integer = 0): TArray<TSnippetDTO>;
var
    SafeMask, SQL: string;
begin
    SafeMask := SanitizeFTS5(Mask);
    if SafeMask = '' then
        Exit(nil);

    // Оборачиваем запрос в двойные кавычки для поиска точной фразы
    // и добавляем звездочку для префиксного поиска (чтобы искал даже по части слова)
    SafeMask := '"' + SafeMask + '" *';

    // Выбираем только стандартные поля, чтобы InternalLoadSnippets смог их распарсить
    SQL := 'SELECT s.id, s.user_id, s.title, s.content, s.comment, s.category_id, s.created_at, s.updated_at, s.key_delay_ms ' +
           'FROM snippets s ' +
           'JOIN snippet_fts fts ON s.id = fts.rowid ' +
           'WHERE snippet_fts MATCH ? ';

    if UserID > 0 then
    begin
        // Сортировать по fts.rank можно, даже если его нет в блоке SELECT
        SQL := SQL + ' AND s.user_id = ? ORDER BY fts.rank ASC';

        // Используем позиционные параметры (знаки вопроса) - это 100% защита от багов FireDAC
        Result := InternalLoadSnippets(SQL, [SafeMask, UserID]);
    end
    else
    begin
        SQL := SQL + ' ORDER BY fts.rank ASC';
        Result := InternalLoadSnippets(SQL, [SafeMask]);
    end;
end;

function TSnippetRepository.SearchByMaskSimple(const Mask: string; UserID: Integer = 0): TArray<TSnippetDTO>;
var
    SearchStr, SQL: string;
begin
    if Trim(Mask) = '' then
        Exit(nil);

    SearchStr := '%' + Trim(Mask) + '%';

    SQL := 'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at, key_delay_ms ' +
           'FROM snippets ' +
           'WHERE (title LIKE ? COLLATE NOCASE OR content LIKE ? COLLATE NOCASE ' +
           'OR EXISTS (SELECT 1 FROM snippet_tags st JOIN tags t ON t.id = st.tag_id ' +
           'WHERE st.snippet_id = snippets.id AND t.name LIKE ? COLLATE NOCASE)) ';

    if UserID > 0 then
    begin
        SQL := SQL + ' AND user_id = ? ORDER BY updated_at DESC, title ASC';
        // Передаем SearchStr трижды: для title, content и имени тега, четвертым идет UserID
        Result := InternalLoadSnippets(SQL, [SearchStr, SearchStr, SearchStr, UserID]);
    end
    else
    begin
        SQL := SQL + ' ORDER BY updated_at DESC, title ASC';
        Result := InternalLoadSnippets(SQL, [SearchStr, SearchStr, SearchStr]);
    end;
end;

function TSnippetRepository.SearchAdvanced(const Query: TStructuredQuery; UseFTS: Boolean; UserID: Integer): TArray<TSnippetDTO>;
var
    Sb: TStringBuilder;
    Params: TList<Variant>;
    FTSInclude, Safe, Word: string;
    I: Integer;
begin
    Result := nil;

    FTSInclude := '';
    if UseFTS and (Length(Query.BareWords) > 0) then
    begin
        FTSInclude := SanitizeFTS5(string.Join(' ', Query.BareWords));
        if FTSInclude = '' then
            Exit(nil);
        FTSInclude := '"' + FTSInclude + '" *';
    end;

    Sb := TStringBuilder.Create;
    Params := TList<Variant>.Create;
    try
        Sb.Append('SELECT s.id, s.user_id, s.title, s.content, s.comment, s.category_id, s.created_at, s.updated_at, s.key_delay_ms ');
        Sb.Append('FROM snippets s ');

        if FTSInclude <> '' then
            Sb.Append('JOIN snippet_fts fts ON fts.rowid = s.id ');

        Sb.Append('WHERE 1 = 1 ');

        if UserID > 0 then
        begin
            Sb.Append('AND s.user_id = ? ');
            Params.Add(UserID);
        end;

        if Query.OnlyFavorites then
        begin
            Sb.Append('AND EXISTS (SELECT 1 FROM snippet_favorites f WHERE f.snippet_id = s.id ');
            if UserID > 0 then
                Sb.Append('AND f.user_id = ? ');
            Sb.Append(') ');
            if UserID > 0 then
                Params.Add(UserID);
        end;

        if FTSInclude <> '' then
        begin
            Sb.Append('AND snippet_fts MATCH ? ');
            Params.Add(FTSInclude);
        end;

        for Word in Query.ExcludedWords do
        begin
            if UseFTS then
            begin
                Safe := SanitizeFTS5(Word);
                if Safe = '' then
                    Continue;
                Sb.Append('AND s.id NOT IN (SELECT rowid FROM snippet_fts WHERE snippet_fts MATCH ?) ');
                Params.Add('"' + Safe + '" *');
            end
            else
            begin
                Sb.Append('AND NOT (s.title LIKE ? COLLATE NOCASE OR s.content LIKE ? COLLATE NOCASE ' +
                    'OR EXISTS (SELECT 1 FROM snippet_tags st JOIN tags t ON t.id = st.tag_id ' +
                    'WHERE st.snippet_id = s.id AND t.name LIKE ? COLLATE NOCASE)) ');
                Params.Add('%' + Word + '%');
                Params.Add('%' + Word + '%');
                Params.Add('%' + Word + '%');
            end;
        end;

        for Word in Query.TagValues do
        begin
            Sb.Append('AND EXISTS (SELECT 1 FROM snippet_tags st JOIN tags t ON t.id = st.tag_id ' +
                'WHERE st.snippet_id = s.id AND t.name LIKE ? COLLATE NOCASE) ');
            Params.Add('%' + Word + '%');
        end;

        if Length(Query.CategoryValues) > 0 then
        begin
            Sb.Append('AND s.category_id IN (SELECT id FROM snippet_categories WHERE (name LIKE ? COLLATE NOCASE) ');
            Params.Add('%' + Query.CategoryValues[0] + '%');
            for I := 1 to High(Query.CategoryValues) do
            begin
                Sb.Append('OR (name LIKE ? COLLATE NOCASE) ');
                Params.Add('%' + Query.CategoryValues[I] + '%');
            end;
            Sb.Append(') ');
        end;

        for Word in Query.TitleValues do
        begin
            Sb.Append('AND s.title LIKE ? COLLATE NOCASE ');
            Params.Add('%' + Word + '%');
        end;

        for Word in Query.CommentValues do
        begin
            Sb.Append('AND s.comment LIKE ? COLLATE NOCASE ');
            Params.Add('%' + Word + '%');
        end;

        if (not UseFTS) and (Length(Query.BareWords) > 0) then
            for Word in Query.BareWords do
            begin
                Sb.Append('AND (s.title LIKE ? COLLATE NOCASE OR s.content LIKE ? COLLATE NOCASE ' +
                    'OR EXISTS (SELECT 1 FROM snippet_tags st JOIN tags t ON t.id = st.tag_id ' +
                    'WHERE st.snippet_id = s.id AND t.name LIKE ? COLLATE NOCASE)) ');
                Params.Add('%' + Word + '%');
                Params.Add('%' + Word + '%');
                Params.Add('%' + Word + '%');
            end;

        if FTSInclude <> '' then
            Sb.Append('ORDER BY fts.rank ASC')
        else
            Sb.Append('ORDER BY s.updated_at DESC, s.title ASC');

        Result := InternalLoadSnippets(Sb.ToString, Params.ToArray);
    finally
        Params.Free;
        Sb.Free;
    end;
end;

procedure TSnippetRepository.RecordRun(SnippetID: Integer; UserID: Integer);
begin
    // UserID <= 0 - пользователь не определён (запуск через глобальный хоткей).
    // executed_by_user_id nullable (ON DELETE SET NULL): отдельный SQL с литеральным NULL,
    // т.к. FireDAC не выводит тип параметра из нетипизированного Null (ошибка -335).
    if UserID > 0 then
        ExecuteSQL(SQL_RECORD_RUN, [SnippetID, UserID])
    else
        ExecuteSQL(SQL_RECORD_RUN_NO_USER, [SnippetID]);
end;

function TSnippetRepository.GetSnippetByCategory(const CategoryID, UserID: Integer): TArray<TSnippetDTO>;
begin
    if UserID > 0 then
        Result := InternalLoadSnippets(SQL_SELECT_SNIPPETS_BY_CATEGORY_USER, [CategoryID, UserID])
    else
        Result := InternalLoadSnippets(SQL_SELECT_SNIPPETS_BY_CATEGORY, [CategoryID]);
end;

function TSnippetRepository.GetSnippetCountByCategory(UserID: Integer): TDictionary<Integer, Integer>;
var
    Q: TFDQuery;
begin
    Result := TDictionary<Integer, Integer>.Create;
    Q := CreateQuery;
    try
        if UserID > 0 then
        begin
            Q.SQL.Text := SQL_GET_SNIPPET_BY_CATEGORY_ID_WITH_USER_ID;
            Q.Params[0].AsInteger := UserID;
        end
        else
        begin
            Q.SQL.Text := SQL_GET_SNIPPET_BY_CATEGORY_ID_NO_USER_ID;
        end;
        Q.Open;

        while not Q.Eof do
        begin
            Result.AddOrSetValue(
                Q.FieldByName('category_id').AsInteger,
                Q.FieldByName('cnt').AsInteger
            );
            Q.Next;
        end;
    finally
        Q.Free;
    end;
end;

function TSnippetRepository.GetTopSnippets(UserID, Limit: Integer): TArray<TSnippetDTO>;
begin
    Result := InternalLoadSnippets(SQL_GET_TOP_SNIPPETS, [UserID, Limit]);
end;

function TSnippetRepository.GetRecentSnippets(UserID, Limit: Integer): TArray<TSnippetDTO>;
begin
    Result := InternalLoadSnippets(SQL_GET_RECENT_SNIPPETS, [UserID, Limit]);
end;

function TSnippetRepository.GetFavorites(UserID: Integer): TArray<TSnippetDTO>;
begin
    if UserID > 0 then
        Result := InternalLoadSnippets(SQL_GET_FAVORITES_BY_USER, [UserID])
    else
        Result := InternalLoadSnippets(SQL_GET_FAVORITES_ALL, []);
end;

function TSnippetRepository.GetFavoriteOrder(UserID: Integer): TArray<Integer>;
var
    Q: TFDQuery;
    List: TList<Integer>;
begin
    List := TList<Integer>.Create;
    Q := CreateQuery;
    try
        if UserID > 0 then
        begin
            Q.SQL.Text := SQL_GET_FAVORITE_ORDER;
            Q.Params[0].AsInteger := UserID;
        end
        else
            Q.SQL.Text := SQL_GET_FAVORITE_ORDER_ALL;

        Q.Open;
        while not Q.Eof do
        begin
            List.Add(Q.Fields[0].AsInteger);
            Q.Next;
        end;
        Result := List.ToArray;
    finally
        List.Free;
        Q.Free;
    end;
end;

function TSnippetRepository.IsFavorite(SnippetID, UserID: Integer): Boolean;
begin
    Result := ExecuteSQLScalar(SQL_IS_FAVORITE, [UserID, SnippetID]) > 0;
end;

procedure TSnippetRepository.AddFavorite(SnippetID, UserID: Integer);
begin
    if IsFavorite(SnippetID, UserID) then
        Exit;
    ExecuteSQL(SQL_ADD_FAVORITE, [UserID, SnippetID, UserID]);
end;

procedure TSnippetRepository.RemoveFavorite(SnippetID, UserID: Integer);
begin
    ExecuteSQL(SQL_REMOVE_FAVORITE, [UserID, SnippetID]);
end;

procedure TSnippetRepository.MoveFavorite(SnippetID, UserID, NewPosition: Integer);
var
    Q: TFDQuery;
    Order: TList<Integer>;
    I, OldIndex, Target: Integer;
begin
    Order := TList<Integer>.Create;
    Q := CreateQuery;
    try
        if UserID > 0 then
        begin
            Q.SQL.Text := SQL_GET_FAVORITE_ORDER;
            Q.Params[0].AsInteger := UserID;
        end
        else
            Q.SQL.Text := SQL_GET_FAVORITE_ORDER_ALL;

        Q.Open;
        while not Q.Eof do
        begin
            Order.Add(Q.Fields[0].AsInteger);
            Q.Next;
        end;
        Q.Close;

        OldIndex := Order.IndexOf(SnippetID);
        if OldIndex < 0 then
            Exit;

        Target := NewPosition;
        if Target < 0 then
            Target := 0;
        if Target > Order.Count - 1 then
            Target := Order.Count - 1;
        if Target = OldIndex then
            Exit;

        Order.Delete(OldIndex);
        Order.Insert(Target, SnippetID);

        FConnection.StartTransaction;
        try
            Q.SQL.Text := SQL_UPDATE_FAVORITE_ORDER;
            for I := 0 to Order.Count - 1 do
            begin
                Q.Params[0].AsInteger := I;
                Q.Params[1].AsInteger := Order[I];
                Q.ExecSQL;
            end;
            FConnection.Commit;
        except
            FConnection.Rollback;
            raise;
        end;
    finally
        Q.Free;
        Order.Free;
    end;
end;

function TSnippetRepository.GetLastRunSnippetID(UserID: Integer): Integer;
var
    V: Variant;
begin
    Result := 0;
    if UserID > 0 then
        V := ExecuteSQLScalar(SQL_GET_LAST_RUN, [UserID])
    else
        V := ExecuteSQLScalar(SQL_GET_LAST_RUN_NO_USER, []);

    if (not VarIsNull(V)) and (not VarIsEmpty(V)) then
        Result := Integer(V);
end;

end.
