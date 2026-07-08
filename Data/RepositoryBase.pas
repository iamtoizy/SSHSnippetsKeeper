unit RepositoryBase;

interface

uses
    FireDAC.Comp.Client;

type
    TRepositoryBase = class
    protected
        FConnection: TFDConnection;

        function CreateQuery: TFDQuery;
        procedure SetQueryParams(Query: TFDQuery; const Params: array of Variant);
        function ExecuteSQL(const SQL: string; const Params: array of Variant): Integer;
        function ExecuteSQLScalar(const SQL: string; const Params: array of Variant): Variant;
    public
        constructor Create(Connection: TFDConnection);
    end;

implementation

uses
    System.Variants,
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
    // Для запросов чтения больших выборок:
//    Result.ResourceOptions.SilentMode := True;
    Result.FetchOptions.Unidirectional := True;
end;

procedure TRepositoryBase.SetQueryParams(Query: TFDQuery; const Params: array of Variant);
var
    i: Integer;
begin
    for i := 0 to High(Params) do
        Query.Params[i].Value := Params[i];
end;

function TRepositoryBase.ExecuteSQL(const SQL: string; const Params: array of Variant): Integer;
begin
    Result := FConnection.ExecSQL(SQL, Params);
end;

function TRepositoryBase.ExecuteSQLScalar(const SQL: string; const Params: array of Variant): Variant;
begin
    Result := FConnection.ExecSQLScalar(SQL, Params);
end;

end.
