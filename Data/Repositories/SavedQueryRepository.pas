unit SavedQueryRepository;

interface

uses
    Core.Entities.SavedQuery,
    Core.Interfaces.Data,
    FireDAC.Comp.Client,
    RepositoryBase
    ;

type
    TSavedQueryRepository = class(TRepositoryBase, ISavedQueryRepository)
    public
        function GetAll(UserID: Integer = 0): TArray<TSavedQueryDTO>;
        function GetByID(ID: Integer): TSavedQueryDTO;
        function Add(const SavedQuery: TSavedQueryDTO): Integer;
        procedure UpdateName(ID: Integer; const NewName: string);
        procedure UpdateQueryText(ID: Integer; const NewQueryText: string);
        procedure Delete(ID: Integer);
        function NameExists(const Name: string; UserID, ExcludeID: Integer): Boolean;
    end;

implementation

uses
    FireDAC.Stan.Param,
    System.Generics.Collections,
    System.SysUtils
    ;

{ TSavedQueryRepository }

function TSavedQueryRepository.GetAll(UserID: Integer = 0): TArray<TSavedQueryDTO>;
var
    Query: TFDQuery;
    List: TList<TSavedQueryDTO>;
    Item: TSavedQueryDTO;
begin
    if not FConnection.Connected then Exit(Result);

    List := TList<TSavedQueryDTO>.Create;
    Query := CreateQuery;
    try
        if UserID > 0 then
            Query.Open('SELECT id, user_id, name, query_text, created_at FROM saved_queries WHERE user_id = ? ORDER BY name COLLATE NOCASE', [UserID])
        else
            Query.Open('SELECT id, user_id, name, query_text, created_at FROM saved_queries ORDER BY user_id, name COLLATE NOCASE');

        while not Query.Eof do
        begin
            Item.ID := Query.FieldByName('id').AsInteger;
            Item.UserID := Query.FieldByName('user_id').AsInteger;
            Item.Name := Query.FieldByName('name').AsString;
            Item.QueryText := Query.FieldByName('query_text').AsString;
            Item.CreatedAt := Query.FieldByName('created_at').AsLargeInt;

            List.Add(Item);
            Query.Next;
        end;
        Result := List.ToArray;
    finally
        List.Free;
        Query.Free;
    end;
end;

function TSavedQueryRepository.GetByID(ID: Integer): TSavedQueryDTO;
var
    Q: TFDQuery;
begin
    Result := Default(TSavedQueryDTO);

    if ID <= 0 then Exit;

    Q := CreateQuery;
    try
        Q.SQL.Text := 'SELECT id, user_id, name, query_text, created_at FROM saved_queries WHERE id = :id';
        Q.ParamByName('id').AsInteger := ID;
        Q.Open;

        if not Q.Eof then
        begin
            Result.ID := Q.FieldByName('id').AsInteger;
            Result.UserID := Q.FieldByName('user_id').AsInteger;
            Result.Name := Q.FieldByName('name').AsString;
            Result.QueryText := Q.FieldByName('query_text').AsString;
            Result.CreatedAt := Q.FieldByName('created_at').AsLargeInt;
        end;
    finally
        Q.Free;
    end;
end;

function TSavedQueryRepository.Add(const SavedQuery: TSavedQueryDTO): Integer;
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        Q.SQL.Text := 'INSERT INTO saved_queries (user_id, name, query_text) VALUES (:uid, :name, :query) RETURNING id';
        Q.ParamByName('uid').AsInteger := SavedQuery.UserID;
        Q.ParamByName('name').AsString := SavedQuery.Name;
        Q.ParamByName('query').AsString := SavedQuery.QueryText;
        Q.Open;
        Result := Q.Fields[0].AsInteger;
    finally
        Q.Free;
    end;
end;

procedure TSavedQueryRepository.UpdateName(ID: Integer; const NewName: string);
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        Q.SQL.Text := 'UPDATE saved_queries SET name = :name WHERE id = :id';
        Q.ParamByName('name').AsString := NewName;
        Q.ParamByName('id').AsInteger := ID;
        ExecSQLWithRetry(Q);
    finally
        Q.Free;
    end;
end;

procedure TSavedQueryRepository.UpdateQueryText(ID: Integer; const NewQueryText: string);
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        Q.SQL.Text := 'UPDATE saved_queries SET query_text = :query WHERE id = :id';
        Q.ParamByName('query').AsString := NewQueryText;
        Q.ParamByName('id').AsInteger := ID;
        ExecSQLWithRetry(Q);
    finally
        Q.Free;
    end;
end;

procedure TSavedQueryRepository.Delete(ID: Integer);
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        Q.SQL.Text := 'DELETE FROM saved_queries WHERE id = :id';
        Q.ParamByName('id').AsInteger := ID;
        ExecSQLWithRetry(Q);
    finally
        Q.Free;
    end;
end;

function TSavedQueryRepository.NameExists(const Name: string; UserID, ExcludeID: Integer): Boolean;
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        Q.SQL.Text :=
            'SELECT COUNT(*) FROM saved_queries ' +
            'WHERE name = :name AND user_id = :uid AND id <> :excl';
        Q.ParamByName('name').AsString := Name;
        Q.ParamByName('uid').AsInteger := UserID;
        Q.ParamByName('excl').AsInteger := ExcludeID;
        Q.Open;
        Result := Q.Fields[0].AsInteger > 0;
    finally
        Q.Free;
    end;
end;

end.
