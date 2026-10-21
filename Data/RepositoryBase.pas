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
        function IsTransientLockError(E: Exception): Boolean;

        // Централизованный метод для выполнения запросов с автоочисткой памяти
        procedure ExecuteQuery(const SQL: string; const Params: array of Variant; Proc: TProc<TFDQuery>);
        function ExecuteSQL(const SQL: string; const Params: array of Variant): Integer;
        function ExecuteSQLScalar(const SQL: string; const Params: array of Variant): Variant;
    public
        constructor Create(Connection: TFDConnection);
    end;

implementation

uses
    Common.Localization,
    FireDAC.Stan.Error,
    FireDAC.Stan.Param,
    System.Classes,
    System.Variants
    ;

const
    SQLITE_BUSY = 5;
    SQLITE_LOCKED = 6;
    BUSY_RETRY_COUNT = 3;
    BUSY_RETRY_DELAY_MS = 200;

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

procedure TRepositoryBase.SetQueryParams(Query: TFDQuery; const Params: array of Variant);
var
    I: Integer;
begin
    for I := 0 to High(Params) do
        Query.Params[I].Value := Params[I];
end;

function TRepositoryBase.IsTransientLockError(E: Exception): Boolean;
var
    I: Integer;
begin
    Result := False;
    if not (E is EFDDBEngineException) then
        Exit;
    for I := 0 to EFDDBEngineException(E).ErrorCount - 1 do
        if EFDDBEngineException(E).Errors[I].ErrorCode in [SQLITE_BUSY, SQLITE_LOCKED] then
        begin
            Result := True;
            Break;
        end;
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
var
    Attempt: Integer;
begin
    Result := 0;
    for Attempt := 1 to BUSY_RETRY_COUNT do
        try
            Result := FConnection.ExecSQL(SQL, Params);
            Exit;
        except
            on E: Exception do
                if (Attempt < BUSY_RETRY_COUNT) and IsTransientLockError(E) then
                    TThread.Sleep(BUSY_RETRY_DELAY_MS)
                else if IsTransientLockError(E) then
                    raise Exception.Create(TUIStateLoader.GetMessage('Common.DatabaseBusy', [E.Message]))
                else
                    raise;
        end;
end;

function TRepositoryBase.ExecuteSQLScalar(const SQL: string; const Params: array of Variant): Variant;
var
    Attempt: Integer;
begin
    Result := Null;
    for Attempt := 1 to BUSY_RETRY_COUNT do
        try
            Result := FConnection.ExecSQLScalar(SQL, Params);
            Exit;
        except
            on E: Exception do
                if (Attempt < BUSY_RETRY_COUNT) and IsTransientLockError(E) then
                    TThread.Sleep(BUSY_RETRY_DELAY_MS)
                else if IsTransientLockError(E) then
                    raise Exception.Create(TUIStateLoader.GetMessage('Common.DatabaseBusy', [E.Message]))
                else
                    raise;
        end;
end;

end.
