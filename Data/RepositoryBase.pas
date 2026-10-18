unit RepositoryBase;

interface

uses
    FireDAC.Comp.Client,
    System.SysUtils
    ;

type
    TRepositoryBase = class(TInterfacedObject)
    protected
        FConnection: TFDConnection;

        function CreateQuery: TFDQuery;
        procedure SetQueryParams(Query: TFDQuery; const Params: array of Variant);

        // Централизованный метод для выполнения запросов с автоочисткой памяти
        procedure ExecuteQuery(const SQL: string; const Params: array of Variant; Proc: TProc<TFDQuery>);
        function ExecuteSQL(const SQL: string; const Params: array of Variant): Integer;
        function ExecuteSQLScalar(const SQL: string; const Params: array of Variant): Variant;
    public
        constructor Create(Connection: TFDConnection);
    end;

implementation

uses
    FireDAC.Stan.Param,
    System.Classes
    ;

{ TRepositoryBase }

constructor TRepositoryBase.Create(Connection: TFDConnection);
begin
    inherited Create;
    FConnection := Connection;
end;

function TRepositoryBase.CreateQuery: TFDQuery;
begin
    Result := TFDQuery.Create(nil);
    Result.Connection := FConnection;
    // Настройки для оптимизации выборок
    Result.FetchOptions.Unidirectional := True;
end;

procedure TRepositoryBase.ExecuteQuery(const SQL: string; const Params: array of Variant; Proc: TProc<TFDQuery>);
var
    Query: TFDQuery;
begin
    // Единая точка настройки запроса - CreateQuery, заполнение параметров - SetQueryParams
    Query := CreateQuery;
    try
        Query.SQL.Text := SQL;
        SetQueryParams(Query, Params);
        Proc(Query);
    finally
        Query.Free;
    end;
end;

function TRepositoryBase.ExecuteSQL(const SQL: string; const Params: array of Variant): Integer;
begin
    Result := FConnection.ExecSQL(SQL, Params);
end;

function TRepositoryBase.ExecuteSQLScalar(const SQL: string; const Params: array of Variant): Variant;
begin
    Result := FConnection.ExecSQLScalar(SQL, Params);
end;

procedure TRepositoryBase.SetQueryParams(Query: TFDQuery; const Params: array of Variant);
var
    I: Integer;
begin
    for I := 0 to High(Params) do
        Query.Params[I].Value := Params[I];
end;

end.
