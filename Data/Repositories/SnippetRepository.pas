unit SnippetRepository;

interface

uses
    System.Generics.Collections,
    Snippet,
    Tag,
    FireDAC.Comp.Client,
    RepositoryBase,
    Core.Interfaces;

type
    TSnippetRepository = class(TRepositoryBase, ISnippetRepository)
    private
        function InternalLoadSnippets(const SQL: string; const Params: array of Variant): TArray<TSnippetDTO>;
        function GetSnippetTagsBatch(const SnippetIDs: TArray<NativeInt>): TDictionary<NativeInt, TArray<TTagDTO>>;
    public
        function Add(const Snippet: TSnippetDTO): NativeInt;
        procedure Update(const Snippet: TSnippetDTO);
        procedure Delete(ID: NativeInt);
        function GetById(ID: NativeInt): TSnippetDTO;
        function GetAll(UserID: NativeInt = 0): TArray<TSnippetDTO>;
        function GetSnippetByCategory(const CategoryID, UserID: NativeInt): TArray<TSnippetDTO>;
        procedure RecordRun(SnippetID: NativeInt; UserID: NativeInt);
        function GetSnippetTags(SnippetID: NativeInt): TArray<TTagDTO>;
        function GetSnippetsByTag(const TagID: NativeInt): TArray<TSnippetDTO>;
        function Search(const Query: string): TArray<TSnippetDTO>;
        function SearchByMaskFTS(const Mask: string; UserID: NativeInt = 0): TArray<TSnippetDTO>;
        function SearchByMaskSimple(const Mask: string; UserID: NativeInt = 0): TArray<TSnippetDTO>;
        procedure UpdateTags(SnippetID: NativeInt; const TagIDs: TArray<NativeInt>);
        function GetRecentSnippets(UserID: NativeInt; Limit: Integer): TArray<TSnippetDTO>;
        function GetTopSnippets(UserID: NativeInt; Limit: Integer): TArray<TSnippetDTO>;
        function GetSnippetCountByCategory(UserID: NativeInt): TDictionary<NativeInt, Integer>;
    end;

implementation

uses
    System.SysUtils,
    System.Classes,
    System.Variants,
    FireDAC.Stan.Param,
    Data.DB;

const
    SQL_GET_ALL_SNIPPETS_BASE = 'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at FROM snippets';
    SQL_ADD_SNIPPET = 'INSERT INTO snippets (user_id, category_id, title, content, comment, created_at, updated_at) ' +
            'VALUES (:user_id, :cat_id, :title, :content, :comment, :created_at, :updated_at)';
    SQL_DELETE_SNIPPET = 'DELETE FROM snippets WHERE id = :id';
    SQL_GET_ALL_SNIPPETS = 'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at FROM snippets ORDER BY title';
    SQL_UPDATE_SNIPPET = 'UPDATE snippets SET title = :title, content = :content, ' +
        'comment = :comment, category_id = :category_id, updated_at = :updated_at ' +
        'WHERE id = :id';
    SQL_UPDATE_TAGS_DELETE_QUERY = 'DELETE FROM snippet_tags WHERE snippet_id = :id';
    SQL_UPDATE_TAGS_INSERT_QUERY = 'INSERT INTO snippet_tags (snippet_id, tag_id) VALUES (:snip_id, :tag_id)';
    SQL_SELECT_SNIPPETS_BY_ID = 'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at FROM snippets WHERE id = ?';
    SQL_SELECT_SNIPPETS_BY_CATEGORY =
        'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at FROM snippets WHERE category_id = ? ORDER BY title';
    SQL_SELECT_SNIPPETS_BY_CATEGORY_USER =
        'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at FROM snippets WHERE category_id = ? AND user_id = ? ORDER BY title';
    SQL_SELECT_SNIPPETS_BY_TAG =
        'SELECT s.id, s.user_id, s.title, s.content, s.comment, ' +
        's.category_id, s.created_at, s.updated_at ' +
        'FROM snippets s ' +
        'JOIN snippet_tags st ON s.id = st.snippet_id ' +
        'WHERE st.tag_id = ? ' +
        'ORDER BY s.title';
    SQL_SELECT_SNIPPET_TAGS = 'SELECT t.id, t.name FROM tags t JOIN snippet_tags st ON t.id = st.tag_id WHERE st.snippet_id = :SnippetID ORDER BY t.name';
    SQL_FULLTEXT_SEARCH = 'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at ' + 'FROM snippets ' +
        'WHERE title LIKE :m COLLATE NOCASE ' + '   OR content LIKE :m COLLATE NOCASE ' + 'ORDER BY updated_at DESC, title ASC';
    SQL_SNIPPET_SEARCH = 'SELECT s.id, s.title, s.category_id, snippet_fts.rank ' + 'FROM snippet_fts ' + 'JOIN snippets s ON s.id = snippet_fts.rowid ' +
        'WHERE snippet_fts MATCH :search ' + 'ORDER BY rank DESC';
    SQL_SEARCH_BY_MASK_FTS = 'SELECT s.id, s.user_id, s.title, s.content, s.category_id, s.created_at, s.updated_at, snippet_fts.rank ' +
        'FROM snippet_fts ' +
        'JOIN snippets s ON s.rowid = snippet_fts.rowid ' + // В FTS5 rowid совпадает с ID сниппета
        'WHERE snippet_fts MATCH :term ' + 'ORDER BY rank ASC'; // Чем меньше rank, тем точнее совпадение;
    SQL_RECORD_RUN = 'INSERT INTO snippet_runs (snippet_id, run_at, executed_by_user_id) VALUES (?, strftime(''%s'', ''now''), ?)';
    SQL_GET_SNIPPET_BY_CATEGORY_ID_WITH_USER_ID = 'SELECT category_id, COUNT(*) AS cnt FROM snippets WHERE user_id = ? GROUP BY category_id';
    SQL_GET_SNIPPET_BY_CATEGORY_ID_NO_USER_ID = 'SELECT category_id, COUNT(*) AS cnt FROM snippets GROUP BY category_id';
    SQL_GET_TOP_SNIPPETS =
        'SELECT s.id, s.user_id, s.title, s.content, s.comment, s.category_id, s.created_at, s.updated_at ' +
        'FROM snippets s ' +
        'JOIN snippet_stats st ON st.snippet_id = s.id ' +
        'WHERE s.user_id = ? ' +
        'ORDER BY st.exec_count DESC, st.last_exec_at DESC ' +
        'LIMIT ?';
    SQL_GET_RECENT_SNIPPETS =
        'SELECT s.id, s.user_id, s.title, s.content, s.comment, s.category_id, s.created_at, s.updated_at ' +
        'FROM snippets s ' +
        'JOIN snippet_stats st ON st.snippet_id = s.id ' +
        'WHERE s.user_id = ? ' +
        'ORDER BY st.last_exec_at DESC ' +
        'LIMIT ?';

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

procedure TSnippetRepository.Delete(ID: NativeInt);
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

function TSnippetRepository.GetAll(UserID: NativeInt = 0): TArray<TSnippetDTO>;
var
    SQL: string;
begin
    SQL := SQL_GET_ALL_SNIPPETS_BASE;
    if UserID > 0 then
        Result := InternalLoadSnippets(SQL + ' WHERE user_id = ? ORDER BY title', [UserID])
    else
        Result := InternalLoadSnippets(SQL + ' ORDER BY title', []);
end;

function TSnippetRepository.GetById(ID: NativeInt): TSnippetDTO;
var
    Arr: TArray<TSnippetDTO>;
begin
    Arr := InternalLoadSnippets(SQL_SELECT_SNIPPETS_BY_ID, [ID]);
    if Length(Arr) > 0 then
        Exit(Arr[0]);
    Result := Default (TSnippetDTO);
end;

function TSnippetRepository.GetSnippetsByTag(const TagID: NativeInt): TArray<TSnippetDTO>;
begin
    Result := InternalLoadSnippets(SQL_SELECT_SNIPPETS_BY_TAG, [TagID]);
end;

function TSnippetRepository.GetSnippetTags(SnippetID: NativeInt): TArray<TTagDTO>;
var
    Query: TFDQuery;
    Tag: TTagDTO;
    List: TList<TTagDTO>;
begin
    List := TList<TTagDTO>.Create;
    Query := CreateQuery;
    try
        Query.SQL.Text := SQL_SELECT_SNIPPET_TAGS;
        // Теперь FireDAC точно знает, куда подставить значение
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

function TSnippetRepository.GetSnippetTagsBatch(const SnippetIDs: TArray<NativeInt>): TDictionary<NativeInt, TArray<TTagDTO>>;
const
    MAX_PARAMS = 900; // Защита от лимита SQLite
var
    Query: TFDQuery;
    Map: TDictionary<NativeInt, TList<TTagDTO>>;
    i, ChunkStart, ChunkEnd: NativeInt;
    Key: NativeInt;
    Tag: TTagDTO;
    ParamName: string;
    SQL: TStringBuilder;
    ChunkIDs: TArray<NativeInt>;
begin
    Result := nil;

    if Length(SnippetIDs) = 0 then
        Exit;

    Map := TDictionary<NativeInt, TList<TTagDTO>>.Create;
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
        Result := TDictionary<NativeInt, TArray<TTagDTO>>.Create;
        for Key in Map.Keys do
            Result.Add(Key, Map[Key].ToArray);
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
    IDList: TList<NativeInt>;
    TagMap: TDictionary<NativeInt, TArray<TTagDTO>>;
    Snip: TSnippetDTO;
    i: NativeInt;
begin
    Result := [];

    List := TList<TSnippetDTO>.Create;
    IDList := TList<NativeInt>.Create;
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
        Q.ParamByName('id').AsInteger := Snippet.ID;
        Q.ExecSQL;
    finally
        Q.Free;
    end;
end;

procedure TSnippetRepository.UpdateTags(SnippetID: NativeInt; const TagIDs: TArray<NativeInt>);
var
    Q, QTags: TFDQuery;
    TagID: NativeInt;
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

function TSnippetRepository.Add(const Snippet: TSnippetDTO): NativeInt;
var
    Q: TFDQuery;
    SnippetID: NativeInt;
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

    // БЛОК "Вставка связей с тегами" ПОЛНОСТЬЮ УДАЛЕН ОТСЮДА!
    // Вставка связей с тегами
//    if Length(TagIDs) > 0 then
//    begin
//        QTags := CreateQuery;
//        try
//            QTags.SQL.Text := 'INSERT INTO snippet_tags (snippet_id, tag_id) VALUES (:snip_id, :tag_id)';
//            for TagID in TagIDs do
//            begin
//                QTags.ParamByName('snip_id').AsInteger := SnippetID;
//                QTags.ParamByName('tag_id').AsInteger := TagID;
//                QTags.ExecSQL;
//            end;
//        finally
//            QTags.Free;
//        end;
//    end;
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

function TSnippetRepository.SearchByMaskFTS(const Mask: string; UserID: NativeInt = 0): TArray<TSnippetDTO>;
var
    Query: TFDQuery;
    List: TList<TSnippetDTO>;
    Snip: TSnippetDTO;
    SafeMask, SQL: string;
begin
    Result := [];
    SafeMask := SanitizeFTS5(Mask);

    if SafeMask = '' then Exit;

    List := TList<TSnippetDTO>.Create;
    Query := CreateQuery;
    try
        // Формируем динамический SQL в зависимости от UserID
        SQL := 'SELECT s.id, s.user_id, s.title, s.content, s.category_id, s.created_at, s.updated_at, snippet_fts.rank ' +
               'FROM snippet_fts ' +
               'JOIN snippets s ON s.rowid = snippet_fts.rowid ' +
               'WHERE snippet_fts MATCH :term ';

        if UserID > 0 then
            SQL := SQL + ' AND s.user_id = :uid ';

        SQL := SQL + 'ORDER BY rank ASC';

        Query.SQL.Text := SQL;
        Query.ParamByName('term').AsString := SafeMask + '*';

        if UserID > 0 then
            Query.ParamByName('uid').AsInteger := UserID;

        Query.Open;

        while not Query.Eof do
        begin
            Snip.ID := Query.FieldByName('id').AsInteger;
            Snip.UserID := Query.FieldByName('user_id').AsInteger;
            Snip.Title := Query.FieldByName('title').AsString;
            Snip.Content := Query.FieldByName('content').AsString;
            Snip.CategoryID := Query.FieldByName('category_id').AsInteger;
            Snip.CreatedAt := Query.FieldByName('created_at').AsLargeInt;
            Snip.UpdatedAt := Query.FieldByName('updated_at').AsLargeInt;
            Snip.Tags := [];

            List.Add(Snip);
            Query.Next;
        end;
        Result := List.ToArray;
    finally
        Query.Free;
        List.Free;
    end;
end;

function TSnippetRepository.SearchByMaskSimple(const Mask: string; UserID: NativeInt = 0): TArray<TSnippetDTO>;
var
    Query: TFDQuery;
    List: TList<TSnippetDTO>;
    Snip: TSnippetDTO;
    SQL: string;
begin
    Result := [];

    if Trim(Mask) = '' then
        Exit;

    List := TList<TSnippetDTO>.Create;
    Query := CreateQuery;
    try
        SQL := 'SELECT id, user_id, title, content, comment, category_id, created_at, updated_at ' +
               'FROM snippets ' +
               'WHERE (title LIKE :m COLLATE NOCASE OR content LIKE :m COLLATE NOCASE)';

        if UserID > 0 then
            SQL := SQL + ' AND user_id = :uid';

        SQL := SQL + ' ORDER BY updated_at DESC, title ASC';

        Query.SQL.Text := SQL;
        Query.ParamByName('m').AsString := '%' + Trim(Mask) + '%';

        if UserID > 0 then
            Query.ParamByName('uid').AsInteger := UserID;

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
            Snip.Tags := [];

            List.Add(Snip);
            Query.Next;
        end;
        Result := List.ToArray;
    finally
        Query.Free;
        List.Free;
    end;
end;

procedure TSnippetRepository.RecordRun(SnippetID: NativeInt; UserID: NativeInt);
begin
    FConnection.ExecSQL(SQL_RECORD_RUN, [SnippetID, UserID]);
end;

function TSnippetRepository.GetSnippetByCategory(const CategoryID, UserID: NativeInt): TArray<TSnippetDTO>;
begin
    if UserID > 0 then
        Result := InternalLoadSnippets(SQL_SELECT_SNIPPETS_BY_CATEGORY_USER, [CategoryID, UserID])
    else
        Result := InternalLoadSnippets(SQL_SELECT_SNIPPETS_BY_CATEGORY, [CategoryID]);
end;

function TSnippetRepository.GetSnippetCountByCategory(UserID: NativeInt): TDictionary<NativeInt, Integer>;
var
    Q: TFDQuery;
begin
    Result := TDictionary<NativeInt, Integer>.Create;
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

function TSnippetRepository.GetTopSnippets(UserID: NativeInt; Limit: Integer): TArray<TSnippetDTO>;
begin
    Result := InternalLoadSnippets(SQL_GET_TOP_SNIPPETS, [UserID, Limit]);
end;

function TSnippetRepository.GetRecentSnippets(UserID: NativeInt; Limit: Integer): TArray<TSnippetDTO>;
begin
    Result := InternalLoadSnippets(SQL_GET_RECENT_SNIPPETS, [UserID, Limit]);
end;

end.
