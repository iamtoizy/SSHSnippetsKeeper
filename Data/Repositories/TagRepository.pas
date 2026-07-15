unit TagRepository;

interface

uses
    System.SysUtils,
    System.Generics.Collections,
    Tag,
    System.Variants,
    RepositoryBase,
    Core.Interfaces;

type
    TTagRepository = class(TRepositoryBase, ITagRepository)
    private
        function InternalLoadTags(const SQL: string; const Params: array of Variant): TArray<TTagDTO>;
    public
        function Add(const Tag: TTagDTO): Integer;
        procedure Update(const Tag: TTagDTO);
        procedure Delete(ID: Integer);

        function GetByID(ID: Integer): TTagDTO;
        function GetByName(const Name: string): TArray<TTagDTO>;
        function GetAll: TArray<TTagDTO>;

        function GetSnippetTags(SnippetID: Integer): TArray<TTagDTO>;
        procedure DeleteUnusedTags;

        function GetOrCreateTag(const TagName: string): Integer;
        procedure LinkTagToSnippet(SnippetID, TagID: Integer);
        procedure UnlinkTagFromSnippet(SnippetID, TagID: Integer);
        procedure ClearTagsForSnippet(SnippetID: Integer);

        procedure LinkTagsToSnippetBatch(SnippetID: Integer; const TagIDs: TArray<Integer>);
        function ExistsByName(const Name: string): Boolean;
    end;

implementation

uses
    FireDAC.Stan.Param,
    FireDAC.Comp.Client,
    System.Classes;

function TTagRepository.InternalLoadTags(const SQL: string; const Params: array of Variant): TArray<TTagDTO>;
var
    Query: TFDQuery;
    List: TList<TTagDTO>;
    Tag: TTagDTO;
begin
    Result := [];
    if not FConnection.Connected then
        Exit;

    List := TList<TTagDTO>.Create;
    Query := CreateQuery;
    try
        Query.SQL.Text := SQL;
        SetQueryParams(Query, Params);
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

function TTagRepository.GetByID(ID: Integer): TTagDTO;
var
    Arr: TArray<TTagDTO>;
begin
    Result := Default(TTagDTO);
    Arr := InternalLoadTags('SELECT id, name FROM tags WHERE id = ?', [ID]);

    if Length(Arr) > 0 then
        Result := Arr[0];
end;

function TTagRepository.GetByName(const Name: string): TArray<TTagDTO>;
begin
    Result := InternalLoadTags('SELECT id, name FROM tags WHERE name LIKE ? ORDER BY name', ['%' + Name + '%']);
end;

function TTagRepository.Add(const Tag: TTagDTO): Integer;
begin
    ExecuteSQL('INSERT INTO tags(name) VALUES(?)', [Tag.Name]);
    Result := ExecuteSQLScalar('SELECT last_insert_rowid()', []);
end;

procedure TTagRepository.Update(const Tag: TTagDTO);
begin
    ExecuteSQL('UPDATE tags SET name = ? WHERE id = ?', [Tag.Name, Tag.ID]);
end;

procedure TTagRepository.Delete(ID: Integer);
begin
    ExecuteSQL('DELETE FROM tags WHERE id = ?', [ID]);
end;

function TTagRepository.GetSnippetTags(SnippetID: Integer): TArray<TTagDTO>;
begin
    Result := InternalLoadTags('SELECT t.id, t.name FROM tags t ' + 'JOIN snippet_tags st ON st.tag_id = t.id ' + 'WHERE st.snippet_id = ? ORDER BY t.name', [SnippetID]);
end;

procedure TTagRepository.DeleteUnusedTags;
begin
    ExecuteSQL('DELETE FROM tags WHERE NOT EXISTS (SELECT 1 FROM snippet_tags st WHERE st.tag_id = tags.id)', []);
end;

function TTagRepository.GetOrCreateTag(const TagName: string): Integer;
var
    TagID: Variant;
    CleanName: string;
begin
    CleanName := Trim(TagName);
    if CleanName = '' then
        Exit(0);

    TagID := ExecuteSQLScalar('SELECT id FROM tags WHERE name = ?', [CleanName]);

    if VarIsNull(TagID) or VarIsEmpty(TagID) then
    begin
        ExecuteSQL('INSERT INTO tags (name) VALUES (?) ON CONFLICT(name) DO NOTHING', [CleanName]);
        TagID := ExecuteSQLScalar('SELECT id FROM tags WHERE name = ?', [CleanName]);
    end;

    Result := TagID;
end;

procedure TTagRepository.LinkTagToSnippet(SnippetID, TagID: Integer);
begin
    ExecuteSQL('INSERT OR IGNORE INTO snippet_tags (snippet_id, tag_id) VALUES (?, ?)', [SnippetID, TagID]);
end;

procedure TTagRepository.UnlinkTagFromSnippet(SnippetID, TagID: Integer);
begin
    ExecuteSQL('DELETE FROM snippet_tags WHERE snippet_id = ? AND tag_id = ?', [SnippetID, TagID]);
end;

procedure TTagRepository.ClearTagsForSnippet(SnippetID: Integer);
begin
    ExecuteSQL('DELETE FROM snippet_tags WHERE snippet_id = ?', [SnippetID]);
end;

// РЕАЛИЗАЦИЯ ПАКЕТНОЙ ВСТАВКИ (Array DML)
procedure TTagRepository.LinkTagsToSnippetBatch(SnippetID: Integer; const TagIDs: TArray<Integer>);
var
    Q: TFDQuery;
    I: Integer;
begin
    if Length(TagIDs) = 0 then
        Exit;

    Q := CreateQuery;
    try
        Q.SQL.Text := 'INSERT OR IGNORE INTO snippet_tags (snippet_id, tag_id) VALUES (:snip_id, :tag_id)';

        // 1. Говорим FireDAC размер пакета
        Q.Params.ArraySize := Length(TagIDs);

        // 2. Заполняем массивы параметров
        for I := 0 to High(TagIDs) do
        begin
            Q.ParamByName('snip_id').AsIntegers[I] := SnippetID;
            Q.ParamByName('tag_id').AsIntegers[I] := TagIDs[I];
        end;

        // 3. Выполняем весь пакет одним разом
        Q.Execute(Q.Params.ArraySize);
    finally
        Q.Free;
    end;
end;

function TTagRepository.ExistsByName(const Name: string): Boolean;
var
    Count: Variant;
begin
    // Используем COLLATE NOCASE, чтобы 'Delphi' и 'delphi' считались одним тегом (если БД это поддерживает)
    Count := ExecuteSQLScalar('SELECT COUNT(*) FROM tags WHERE name = ? COLLATE NOCASE', [Trim(Name)]);
    Result := Integer(Count) > 0;
end;

end.

