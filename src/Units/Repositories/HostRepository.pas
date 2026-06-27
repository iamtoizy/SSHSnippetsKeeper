unit HostRepository;

interface

uses
    System.Generics.Collections,
    Host,
    FireDAC.Comp.Client
    ;

type
    THostRepository = class(TObject)
    private
        FConnection: TFDConnection;
    public
        constructor Create(Connection: TFDConnection);
        function CreateHost(const AHost: THostDTO): Integer;
        function UpdateHost(const AHost: THostDTO): Boolean;
        function DeleteHost(const HostID: Integer): Boolean;
        function EnsureHost(const HostName: string): Integer;
        function GetHostByName(const HostName: string): THostDTO;
        function GetAllHosts: TArray<THostDTO>;
    end;

implementation

{ TODO : Добавить кеширование }

{ THostRepository }

constructor THostRepository.Create(Connection: TFDConnection);
begin
    inherited Create;
    FConnection := Connection;
end;

function THostRepository.CreateHost(const AHost: THostDTO): Integer;
var
    Host: THostDTO;
begin
    Host := AHost.ToEntity;
    FConnection.ExecSQL('INSERT INTO hosts (name) VALUES (?)', [Host.Name]);
    Result := FConnection.ExecSQLScalar('SELECT last_insert_rowid()');
end;

function THostRepository.UpdateHost(const AHost: THostDTO): Boolean;
begin
    Result := FConnection.ExecSQL('UPDATE hosts SET name=? WHERE id=?', [AHost.Name, AHost.ID]) > 0;
end;

function THostRepository.DeleteHost(const HostID: Integer): Boolean;
begin
    Result := FConnection.ExecSQL('DELETE FROM hosts WHERE id=?', [HostID]) > 0;
end;

function THostRepository.EnsureHost(const HostName: string): Integer;
begin
    // Вставляем, если не существует, и возвращаем ID
    FConnection.ExecSQL('INSERT OR IGNORE INTO hosts (name) VALUES (?)', [HostName]);
    Result := FConnection.ExecSQLScalar('SELECT id FROM hosts WHERE name = ?', [HostName]);
end;

function THostRepository.GetAllHosts: TArray<THostDTO>;
var
    Query: TFDQuery;
    List: TList<THostDTO>;
    Host: THostDTO;
begin
    List := TList<THostDTO>.Create;
    Query := TFDQuery.Create(nil);

    try
        Query.Connection := FConnection;
        Query.Open('SELECT id, name FROM hosts ORDER BY name');

        while not Query.Eof do
        begin
            Host.ID := Query.FieldByName('id').AsInteger;
            Host.Name := Query.FieldByName('name').AsString;
            List.Add(THostDTO.FromEntity(Host));
            Query.Next;
        end;

        Result := List.ToArray;
    finally
        List.Free;
        Query.Free;
    end;
end;

function THostRepository.GetHostByName(const HostName: string): THostDTO;
var
    Query: TFDQuery;
    Host: THostDTO;
begin
    Result.ID := 0;
    Result.Name := '';

    Query := TFDQuery.Create(nil);
    try
        Query.Connection := FConnection;
        Query.Open('SELECT id, name FROM hosts WHERE name=?', [HostName]);

        if not Query.Eof then
        begin
            Host.ID := Query.FieldByName('id').AsInteger;
            Host.Name := Query.FieldByName('name').AsString;
            Result := THostDTO.FromEntity(Host);
        end;
    finally
        Query.Free;
    end;
end;

end.

