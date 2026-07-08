unit UserRepository;

interface

uses
    System.Generics.Collections, User, FireDAC.Comp.Client;

type
    TUserRepository = class
    private
        FConnection: TFDConnection;
        function InternalLoadUsers(const SQL: string; const Params: array of Variant): TArray<TUserDTO>;
    public
        constructor Create(Connection: TFDConnection);

        function Add(const User: TUserDTO): Integer;
        procedure Update(const User: TUserDTO);
        procedure Delete(Id: Integer);

        function GetByID(Id: Integer): TUserDTO;
        function GetAll: TArray<TUserDTO>;
        function GetByName(const Name: string): TArray<TUserDTO>;
        function TryGetByID(ID: Integer; out User: TUserDTO): Boolean;
    end;

implementation

uses
    System.SysUtils,
    System.Variants,
    FireDAC.Stan.Param,
    System.Classes
    ;

constructor TUserRepository.Create(Connection: TFDConnection);
begin
    inherited Create;
    FConnection := Connection;
end;

function TUserRepository.InternalLoadUsers(const SQL: string; const Params: array of Variant): TArray<TUserDTO>;
var
    Query: TFDQuery;
    List: TList<TUserDTO>;
    User: TUserDTO;
    i: Integer;
begin
    if not Assigned(FConnection) or FConnection.Connected = False then
        Exit;

    List := TList<TUserDTO>.Create;
    Query := TFDQuery.Create(nil);

    try
        Query.Connection := FConnection;
        Query.SQL.Text := SQL;

        for i := 0 to High(Params) do
            Query.Params[i].Value := Params[i];

        Query.Open;

        while not Query.Eof do
        begin
            User.Id := Query.FieldByName('id').AsInteger;
            User.Name := Query.FieldByName('name').AsString;
            User.CreatedAt := Query.FieldByName('created_at').AsLargeInt;

            List.Add(User);

            Query.Next;
        end;

        Result := List.ToArray;
    finally
        Query.Free;
        List.Free;
    end;
end;

function TUserRepository.GetAll: TArray<TUserDTO>;
begin
    Result := InternalLoadUsers('SELECT id, name, created_at FROM users ORDER BY name', []);
end;

function TUserRepository.GetByID(Id: Integer): TUserDTO;
var
    Arr: TArray<TUserDTO>;
begin
    Arr := InternalLoadUsers('SELECT id, name, created_at FROM users WHERE id = ?', [Id]);

    if Length(Arr) > 0 then
        Exit(Arr[0]);

    Result := Default(TUserDTO);
end;

function TUserRepository.GetByName(const Name: string): TArray<TUserDTO>;
begin
    Result := InternalLoadUsers('SELECT id, name, created_at ' + 'FROM users ' + 'WHERE name LIKE ? ' + 'ORDER BY name', ['%' + Name + '%']);
end;

function TUserRepository.Add(const User: TUserDTO): Integer;
var
    NewID: Variant;
begin
    FConnection.ExecSQL('INSERT INTO users (name, created_at) VALUES (?, ?)', [User.Name, User.CreatedAt]);
    NewID := FConnection.ExecSQLScalar('SELECT last_insert_rowid()');
    Result := Integer(NewID);
end;

procedure TUserRepository.Update(const User: TUserDTO);
begin
    FConnection.ExecSQL('UPDATE users ' + 'SET name = ? ' + 'WHERE id = ?', [User.Name, User.Id]);
end;

procedure TUserRepository.Delete(Id: Integer);
begin
    FConnection.ExecSQL('DELETE FROM users WHERE id = ?', [Id]);
end;

function TUserRepository.TryGetByID(ID: Integer; out User: TUserDTO): Boolean;
var
    Arr: TArray<TUserDTO>;
begin
    Arr := InternalLoadUsers('SELECT id, name, created_at FROM users WHERE id = ?', [ID]);

    Result := Length(Arr) > 0;

    if Result then
        User := Arr[0];
end;

end.

