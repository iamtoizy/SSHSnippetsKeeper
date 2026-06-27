unit TagRepository;

interface

uses
    System.SysUtils, System.Generics.Collections, FireDAC.Comp.Client, Tag,
    System.Variants;

type
    TTagRepository = class
    private
        FConnection: TFDConnection;

        function InternalLoadTags(const SQL: string; const Params: array of Variant): TArray<TTagDTO>;

    public
        constructor Create(Connection: TFDConnection);

        function Add(const ATag: TTagDTO): Integer;
        procedure Update(const ATag: TTagDTO);
        procedure Delete(ID: Integer);

        function GetByID(ID: Integer): TArray<TTagDTO>;
        function GetByName(const Name: string): TArray<TTagDTO>;
        function GetAll: TArray<TTagDTO>;

        function GetSnippetTags(SnippetID: Integer): TArray<TTagDTO>;

        procedure SetSnippetTags(SnippetID: Integer; const Tags: TArray<TTagDTO>);
        procedure DeleteUnusedTags;
        procedure AddTagToSnippet(SnippetID: Integer; const TagName: string);
    end;

implementation

constructor TTagRepository.Create(Connection: TFDConnection);
begin
    inherited Create;
    FConnection := Connection;
end;

function TTagRepository.InternalLoadTags(const SQL: string; const Params: array of Variant): TArray<TTagDTO>;
var
    Query: TFDQuery;
    List: TList<TTagDTO>;
    Tag: TTagDTO;
    i: Integer;
begin
    Query := TFDQuery.Create(nil);
    List := TList<TTagDTO>.Create;

    try
        Query.Connection := FConnection;
        Query.SQL.Text := SQL;

        for i := 0 to High(Params) do
            Query.Params[i].Value := Params[i];

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

function TTagRepository.GetAll: TArray<TTagDTO>;
begin
    Result := InternalLoadTags('SELECT id, name FROM tags ORDER BY name', []);
end;

function TTagRepository.GetByID(ID: Integer): TArray<TTagDTO>;
var
    Arr: TArray<TTagDTO>;
begin
    Arr := InternalLoadTags('SELECT id, name FROM tags WHERE id = ?', [ID]);

    if Length(Arr) > 0 then
        Exit(Arr);
end;

function TTagRepository.GetByName(const Name: string): TArray<TTagDTO>;
begin
    Result := InternalLoadTags('SELECT id, name ' + 'FROM tags ' + 'WHERE name LIKE ? ' + 'ORDER BY name', ['%' + Name + '%']);
end;

function TTagRepository.Add(const ATag: TTagDTO): Integer;
var
    NewID: Variant;
begin
    FConnection.ExecSQL('INSERT INTO tags(name) VALUES(?)', [ATag.Name]);

    NewID := FConnection.ExecSQLScalar('SELECT last_insert_rowid()');

    Result := Integer(NewID);
end;

procedure TTagRepository.Update(const ATag: TTagDTO);
begin
    FConnection.ExecSQL('UPDATE tags SET name = ? WHERE id = ?', [ATag.Name, ATag.ID]);
end;

procedure TTagRepository.Delete(ID: Integer);
begin
    FConnection.ExecSQL('DELETE FROM tags WHERE id = ?', [ID]);
end;

function TTagRepository.GetSnippetTags(SnippetID: Integer): TArray<TTagDTO>;
begin
    Result := InternalLoadTags('SELECT t.id, t.name ' + 'FROM tags t ' + 'JOIN snippet_tags st ' + 'ON st.tag_id = t.id ' + 'WHERE st.snippet_id = ? ' + 'ORDER BY t.name', [SnippetID]);
end;

procedure TTagRepository.SetSnippetTags(SnippetID: Integer; const Tags: TArray<TTagDTO>);
var
    Existing: TArray<TTagDTO>;
    ExistingNames: TDictionary<string, Integer>;
    NewNames: TDictionary<string, Byte>;
    Tag: TTagDTO;
begin
    Existing := GetSnippetTags(SnippetID);

    ExistingNames := TDictionary<string, Integer>.Create;

    NewNames := TDictionary<string, Byte>.Create;

    FConnection.StartTransaction;

    try
        try
            for Tag in Existing do
                ExistingNames.AddOrSetValue(LowerCase(Tag.Name), Tag.ID);

            for Tag in Tags do
                NewNames.AddOrSetValue(LowerCase(Tag.Name), 0);

                //
            // удалить только отсутствующие
            //

            for Tag in Existing do
                if not NewNames.ContainsKey(LowerCase(Tag.Name)) then
                begin
                    FConnection.ExecSQL('DELETE FROM snippet_tags ' + 'WHERE snippet_id = ? ' + 'AND tag_id = ?', [SnippetID, Tag.ID]);
                end;

            //
            // добавить только новые
            //

            for Tag in Tags do
                if not ExistingNames.ContainsKey(LowerCase(Tag.Name)) then
                    AddTagToSnippet(SnippetID, Tag.Name);

            FConnection.Commit; // <-- Все FTS триггеры сработают разом и быстро
        except
            FConnection.Rollback; // <-- Откат при любой ошибке
            raise;
        end;
    finally
        ExistingNames.Free;
        NewNames.Free;
    end;
end;

procedure TTagRepository.DeleteUnusedTags;
begin
    FConnection.ExecSQL('DELETE FROM tags WHERE NOT EXISTS (  SELECT 1 ' + 'FROM snippet_tags st WHERE st.tag_id = tags.id)');
end;

procedure TTagRepository.AddTagToSnippet(SnippetID: Integer; const TagName: string);
var
    TagID: Variant;
    CleanName: string;
begin
    // 1. Защита от пустых тегов и лишних пробелов
    CleanName := Trim(TagName);
    if CleanName = '' then
        Exit;

    // 2. Ищем ID существующего тега.
    // Благодаря COLLATE NOCASE в схеме БД, SQLite сам сравнит строки без учета регистра.
    TagID := FConnection.ExecSQLScalar('SELECT id FROM tags WHERE name = ?', [CleanName]);

    // 3. Если тег не найден, создаем его (с защитой от гонок)
    if VarIsNull(TagID) or VarIsEmpty(TagID) then
    begin
        // ON CONFLICT DO NOTHING защитит от ошибки UNIQUE, если тег был создан
        // другим потоком ровно между нашим SELECT и INSERT.
        FConnection.ExecSQL('INSERT INTO tags (name) VALUES (?) ON CONFLICT(name) DO NOTHING', [CleanName]);

        // Запрашиваем ID снова (теперь он 100% существует в базе)
        TagID := FConnection.ExecSQLScalar('SELECT id FROM tags WHERE name = ?', [CleanName]);
    end;

    // 4. Связываем сниппет и тег.
    // INSERT OR IGNORE предотвратит падение с ошибкой PRIMARY KEY,
    // если этот тег уже привязан к данному сниппету.
    FConnection.ExecSQL('INSERT OR IGNORE INTO snippet_tags (snippet_id, tag_id) VALUES (?, ?)', [SnippetID, Integer(TagID)]);
end;

end.

