unit SnippetRepository;

interface

uses
    System.Generics.Collections,
    Snippet,
    HostRepository,
    Tag,
    FireDAC.Comp.Client,
    VCL.Dialogs
    ;

type
    TSnippetRepository = class(TObject)
    private
        FConnection: TFDConnection;
        // Внутренний helper для загрузки списка DTO из БД
        function InternalLoadSnippets(const SQL: string; const Params: array of Variant): TArray<TSnippetDTO>;
        function GetSnippetTagsBatch(const SnippetIDs: TArray<Integer>): TDictionary<Integer, TArray<TTagDTO>>;
    public
        constructor Create(Connection: TFDConnection);
        function Add(const Snippet: TSnippetDTO): Integer;
        procedure Update(const Snippet: TSnippetDTO);
        procedure Delete(ID: Integer);
        function &GetById(ID: Integer): TSnippetDTO;
        function GetAll: TArray<TSnippetDTO>;
        function GetByTag(const Tag: string): TArray<TSnippetDTO>;
        function GetSnippetByCategory(const CategoryID: Integer): TArray<TSnippetDTO>;
        procedure RecordRun(SnippetID: Integer; HostID: Integer);
        function GetSnippetTags(SnippetID: Integer): TArray<TTagDTO>;
        function Search(const Query: string): TArray<TSnippetDTO>;
    end;

implementation

uses
    System.SysUtils,
    System.Classes,
    System.Variants,
    FireDAC.Stan.Param,
    Winapi.Windows
    ;

constructor TSnippetRepository.Create(Connection: TFDConnection);
begin
    inherited Create;
    FConnection := Connection;
end;

procedure TSnippetRepository.Delete(ID: Integer);
begin
    // CASCADE удалит и теги, и статистику
    FConnection.ExecSQL('DELETE FROM snippets WHERE id = ?', [ID]);
end;

function TSnippetRepository.GetAll: TArray<TSnippetDTO>;
begin
    Result := InternalLoadSnippets(
        'SELECT id, user_id, title, content, category, created_at, updated_at FROM snippets ORDER BY title',
        []
    );
end;

function TSnippetRepository.GetSnippetByCategory(const CategoryID: Integer): TArray<TSnippetDTO>;
begin
    Result := InternalLoadSnippets(
        'SELECT id, user_id, title, content, category_id, created_at, updated_at FROM snippets WHERE category_id = ? ORDER BY title',
        [CategoryID]
    );
end;

function TSnippetRepository.GetById(ID: Integer): TSnippetDTO;
var
    Arr: TArray<TSnippetDTO>;
begin
    Arr := InternalLoadSnippets('SELECT id, user_id, title, content, category_id, created_at, updated_at FROM snippets WHERE id = ?', [ID]);
    if Length(Arr) > 0 then
        Exit(Arr[0]);
    Result := Default(TSnippetDTO);
end;

function TSnippetRepository.GetByTag(const Tag: string): TArray<TSnippetDTO>;
begin
    Result := InternalLoadSnippets(
        'SELECT s.id, s.user_id, s.title, s.content, s.category_id, s.created_at, s.updated_at ' +
        'FROM snippets s ' +
        'JOIN snippet_tags st ON s.id = st.snippet_id ' +
        'JOIN tags t ON st.tag_id = t.id ' +
        'WHERE t.name = ? ' +
        'ORDER BY s.title',
        [Tag]
    );
end;

function TSnippetRepository.GetSnippetTags(SnippetID: Integer): TArray<TTagDTO>;
var
    Query: TFDQuery;
    Tag: TTagDTO;
    List: TList<TTagDTO>;
begin
    { TODO : Оптимизировать загрузку тегов (group_concat в sqlite) чтобы сократить число запросов }
    List := TList<TTagDTO>.Create;
    Query := TFDQuery.Create(nil);
    try
        Query.Connection := FConnection;
        Query.SQL.Text := 'SELECT t.name FROM tags t JOIN snippet_tags st ON t.id = st.tag_id WHERE st.snippet_id = ? ORDER BY t.name';
        Query.ParamByName('snippet_id').AsInteger := SnippetID;
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
var
    Query: TFDQuery;
    Map: TDictionary<Integer, TList<TTagDTO>>;
    i: Integer;
    Key: Integer;
    Tag: TTagDTO;
    ParamName: string;
    SQL: TStringBuilder;
begin
    Result := nil;

    if Length(SnippetIDs) = 0 then
        Exit;

    Query := TFDQuery.Create(nil);
    Map := TDictionary<Integer, TList<TTagDTO>>.Create;
    SQL := TStringBuilder.Create;

    try
        Query.Connection := FConnection;

        // 1. Собираем SQL с динамическим количеством параметров
        SQL.Append('SELECT st.snippet_id, t.id, t.name ');
        SQL.Append('FROM snippet_tags st ');
        SQL.Append('JOIN tags t ON t.id = st.tag_id ');
        SQL.Append('WHERE st.snippet_id IN (');

        for i := 0 to High(SnippetIDs) do
        begin
            ParamName := 'id' + i.ToString;
            SQL.Append(':' + ParamName);
            if i < High(SnippetIDs) then
                SQL.Append(',');
        end;

        SQL.Append(') ');
        SQL.Append('ORDER BY t.name');

        Query.SQL.Text := SQL.ToString;

        // 2. Присваиваем значения параметрам
        for i := 0 to High(SnippetIDs) do
        begin
            ParamName := 'id' + i.ToString;
            Query.ParamByName(ParamName).AsInteger := SnippetIDs[i];
        end;

        // 3. Выполняем запрос
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

        // 4. Преобразуем в результат
        Result := TDictionary<Integer, TArray<TTagDTO>>.Create;
        for Key in Map.Keys do
            Result.Add(Key, Map[Key].ToArray);

    finally
        for Key in Map.Keys do
            Map[Key].Free;

        Map.Free;
        SQL.Free;
        Query.Free;
    end;
end;

function TSnippetRepository.InternalLoadSnippets(const SQL: string; const Params: array of Variant): TArray<TSnippetDTO>;
var
    Query: TFDQuery;
    List: TList<TSnippetDTO>;
    Snip: TSnippetDTO;
    IDs: TArray<Integer>;
    TagMap: TDictionary<Integer, TArray<TTagDTO>>;
    i: Integer;
begin
    List := TList<TSnippetDTO>.Create;
    Query := TFDQuery.Create(nil);
    TagMap := nil;

    try
        Query.Connection := FConnection;
        Query.SQL.Text := SQL;
        for i := 0 to High(Params) do
            Query.Params[i].Value := Params[i];
        Query.Open;

        // Собираем ID для батча
        var IDList: TList<Integer> := TList<Integer>.Create;
        try
            Query.First;
            while not Query.Eof do
            begin
                IDList.Add(Query.FieldByName('id').AsInteger);
                Query.Next;
            end;

            IDs := IDList.ToArray;
        finally
            IDList.Free;
        end;

        // Загружаем теги одним запросом
        TagMap := GetSnippetTagsBatch(IDs);

        Query.First;
        while not Query.Eof do
        begin
            Snip.ID := Query.FieldByName('id').AsInteger;
            Snip.UserID := Query.FieldByName('user_id').AsInteger;
            Snip.Title := Query.FieldByName('title').AsString;
            Snip.Content := Query.FieldByName('content').AsString;
            Snip.CategoryID := Query.FieldByName('category_id').AsInteger;
            Snip.CreatedAt := Query.FieldByName('created_at').AsLargeInt;
            Snip.UpdatedAt := Query.FieldByName('updated_at').AsLargeInt;

            // Присваиваем теги из карты
            if TagMap.ContainsKey(Snip.ID) then
                Snip.Tags := TagMap[Snip.ID]
            else
                Snip.Tags := [];

            List.Add(Snip);
            Query.Next;
        end;

        Result := List.ToArray;
    finally
        Query.Free;
        List.Free;
        if (Assigned(TagMap)) then
            TagMap.Free;
    end;
end;

procedure TSnippetRepository.RecordRun(SnippetID, HostID: Integer);
begin
    // используем strftime('%s','now') - sqlite seconds since epoch.
    // Если поле run_at в БД int64, то SQLite сохранит числовой результат.
    FConnection.ExecSQL(
        'INSERT INTO snippet_runs (snippet_id, run_at, host_id, executed_by_user_id) ' +
        'VALUES (?, strftime(''%s'', ''now''), ?, ?)',
        [SnippetID, HostID, 1]
    );
end;

procedure TSnippetRepository.Update(const Snippet: TSnippetDTO);
begin
    FConnection.ExecSQL(
        'UPDATE snippets SET title = ?, content = ?, category_id = ?, updated_at = ? WHERE id = ?',
        [
            Snippet.Title,
            Snippet.Content,
            Snippet.CategoryID,
            Snippet.UpdatedAt,
            Snippet.ID
        ]);
end;

function TSnippetRepository.Add(const Snippet: TSnippetDTO): Integer;
var
    Ent: TSnippetDTO;
    NewIDVariant: Variant;
begin
    // Преобразуем DTO -> Entity (чтобы переиспользовать логику, если нужна)
    Ent := Snippet.ToEntity;
    FConnection.ExecSQL(
        'INSERT INTO snippets ' +
        '(user_id, title, content, category_id, created_at) ' +
        'VALUES (?, ?, ?, ?, ?)',
        [
            Ent.UserID,
            Ent.Title,
            Ent.Content,
            Ent.CategoryID,
            Ent.CreatedAt
        ]);

    // sqlite: last_insert_rowid()
    NewIDVariant := FConnection.ExecSQLScalar('SELECT last_insert_rowid()');
    Result := Integer(NewIDVariant);
end;

function TSnippetRepository.Search(const Query: string): TArray<TSnippetDTO>;
var
    Q: TFDQuery;
    Snippet: TSnippetDTO;
    List: TList<TSnippetDTO>;
begin
    List := TList<TSnippetDTO>.Create;

    Q := TFDQuery.Create(nil);
    try
        Q.Connection := FConnection;

        Q.SQL.Text :=
            'SELECT s.id, s.title, s.category_id, snippet_fts.rank ' +
            'FROM snippet_fts ' +
            'JOIN snippets s ON s.id = snippet_fts.rowid ' +
            'WHERE snippet_fts MATCH :search ' +
            'ORDER BY rank DESC'
        ;

        Q.Params.ParamByName('search').AsString := Query;

        Q.Open;
        while not Q.Eof do
        begin
            Snippet := TSnippetDTO.Create;
            Snippet.ID := Q.FieldByName('id').AsInteger;
            Snippet.Title := Q.FieldByName('title').AsString;
            Snippet.CategoryID := Q.FieldByName('category_id').AsInteger;
            List.Add(Snippet);
            Q.Next;
        end;

    finally
        Q.Free;
    end;
end;

end.

