unit ChainRepository;

interface

uses
    Core.Entities.Chain,
    Core.Interfaces.Data,
    FireDAC.Comp.Client,
    RepositoryBase
    ;

type
    TChainRepository = class(TRepositoryBase, IChainRepository)
    public
        function GetAll(UserID: Integer = 0): TArray<TChainDTO>;
        function GetByID(ID: Integer): TChainDTO;
        function Add(const Chain: TChainDTO): Integer;
        procedure UpdateName(ID: Integer; const NewName: string);
        procedure Delete(ID: Integer);
        function GetSteps(ChainID: Integer): TArray<TChainStepDTO>;
        procedure ReplaceSteps(ChainID: Integer; const Steps: TArray<TChainStepDTO>);
        function NameExists(const Name: string; UserID, ExcludeChainID: Integer): Boolean;
    end;

implementation

uses
    Data.DB,
    FireDAC.Stan.Param,
    System.Generics.Collections,
    System.SysUtils
    ;

{ TChainRepository }

function TChainRepository.GetAll(UserID: Integer = 0): TArray<TChainDTO>;
var
    Query: TFDQuery;
    List: TList<TChainDTO>;
    Chain: TChainDTO;
begin
    if not FConnection.Connected then Exit(Result);

    List := TList<TChainDTO>.Create;
    Query := CreateQuery;
    try
        if UserID > 0 then
            Query.Open('SELECT id, user_id, name, created_at FROM snippet_chains WHERE user_id = ? ORDER BY name COLLATE NOCASE', [UserID])
        else
            Query.Open('SELECT id, user_id, name, created_at FROM snippet_chains ORDER BY user_id, name COLLATE NOCASE');

        while not Query.Eof do
        begin
            Chain.ID := Query.FieldByName('id').AsInteger;
            Chain.UserID := Query.FieldByName('user_id').AsInteger;
            Chain.Name := Query.FieldByName('name').AsString;
            Chain.CreatedAt := Query.FieldByName('created_at').AsLargeInt;

            List.Add(Chain);
            Query.Next;
        end;
        Result := List.ToArray;
    finally
        List.Free;
        Query.Free;
    end;
end;

function TChainRepository.GetByID(ID: Integer): TChainDTO;
var
    Q: TFDQuery;
begin
    Result := Default(TChainDTO);

    if ID <= 0 then Exit;

    Q := CreateQuery;
    try
        Q.SQL.Text := 'SELECT id, user_id, name, created_at FROM snippet_chains WHERE id = :id';
        Q.ParamByName('id').AsInteger := ID;
        Q.Open;

        if not Q.Eof then
        begin
            Result.ID := Q.FieldByName('id').AsInteger;
            Result.UserID := Q.FieldByName('user_id').AsInteger;
            Result.Name := Q.FieldByName('name').AsString;
            Result.CreatedAt := Q.FieldByName('created_at').AsLargeInt;
        end;
    finally
        Q.Free;
    end;
end;

function TChainRepository.Add(const Chain: TChainDTO): Integer;
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        Q.SQL.Text := 'INSERT INTO snippet_chains (user_id, name) VALUES (:uid, :name) RETURNING id';
        Q.ParamByName('uid').AsInteger := Chain.UserID;
        Q.ParamByName('name').AsString := Chain.Name;
        Q.Open;
        Result := Q.Fields[0].AsInteger;
    finally
        Q.Free;
    end;
end;

procedure TChainRepository.UpdateName(ID: Integer; const NewName: string);
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        Q.SQL.Text := 'UPDATE snippet_chains SET name = :name WHERE id = :id';
        Q.ParamByName('name').AsString := NewName;
        Q.ParamByName('id').AsInteger := ID;
        Q.ExecSQL;
    finally
        Q.Free;
    end;
end;

procedure TChainRepository.Delete(ID: Integer);
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        Q.SQL.Text := 'DELETE FROM snippet_chains WHERE id = :id';
        Q.ParamByName('id').AsInteger := ID;
        Q.ExecSQL;
    finally
        Q.Free;
    end;
end;

function TChainRepository.GetSteps(ChainID: Integer): TArray<TChainStepDTO>;
var
    Query: TFDQuery;
    List: TList<TChainStepDTO>;
    Step: TChainStepDTO;
begin
    if not FConnection.Connected then Exit(Result);

    List := TList<TChainStepDTO>.Create;
    Query := CreateQuery;
    try
        Query.SQL.Text :=
            'SELECT s.id, s.chain_id, s.position, s.snippet_id, ' +
            'COALESCE(sn.title, '''') AS snippet_title, s.pause_ms ' +
            'FROM snippet_chain_steps s ' +
            'LEFT JOIN snippets sn ON sn.id = s.snippet_id ' +
            'WHERE s.chain_id = :cid ORDER BY s.position, s.id';
        Query.ParamByName('cid').AsInteger := ChainID;
        Query.Open;

        while not Query.Eof do
        begin
            Step.ID := Query.FieldByName('id').AsInteger;
            Step.ChainID := Query.FieldByName('chain_id').AsInteger;
            Step.Position := Query.FieldByName('position').AsInteger;
            Step.SnippetID := Query.FieldByName('snippet_id').AsInteger;
            Step.SnippetTitle := Query.FieldByName('snippet_title').AsString;
            Step.PauseMs := Query.FieldByName('pause_ms').AsInteger;

            List.Add(Step);
            Query.Next;
        end;
        Result := List.ToArray;
    finally
        List.Free;
        Query.Free;
    end;
end;

procedure TChainRepository.ReplaceSteps(ChainID: Integer; const Steps: TArray<TChainStepDTO>);
var
    Q: TFDQuery;
    I: Integer;
begin
    Q := CreateQuery;
    try
        FConnection.StartTransaction;
        try
            Q.SQL.Text := 'DELETE FROM snippet_chain_steps WHERE chain_id = :cid';
            Q.ParamByName('cid').AsInteger := ChainID;
            Q.ExecSQL;

            Q.SQL.Text := 'INSERT INTO snippet_chain_steps (chain_id, position, snippet_id, pause_ms) VALUES (:cid, :pos, :sid, :pause)';
            for I := 0 to High(Steps) do
            begin
                Q.ParamByName('cid').AsInteger := ChainID;
                Q.ParamByName('pos').AsInteger := I;
                Q.ParamByName('sid').AsInteger := Steps[I].SnippetID;
                Q.ParamByName('pause').AsInteger := Steps[I].PauseMs;
                Q.ExecSQL;
            end;

            FConnection.Commit;
        except
            FConnection.Rollback;
            raise;
        end;
    finally
        Q.Free;
    end;
end;

function TChainRepository.NameExists(const Name: string; UserID, ExcludeChainID: Integer): Boolean;
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        Q.SQL.Text :=
            'SELECT COUNT(*) FROM snippet_chains ' +
            'WHERE name = :name AND user_id = :uid AND id <> :excl';
        Q.ParamByName('name').AsString := Name;
        Q.ParamByName('uid').AsInteger := UserID;
        Q.ParamByName('excl').AsInteger := ExcludeChainID;
        Q.Open;
        Result := Q.Fields[0].AsInteger > 0;
    finally
        Q.Free;
    end;
end;

end.
