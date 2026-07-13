unit UserRepository;

interface

uses
    System.Generics.Collections,
    User,
    FireDAC.Comp.Client,
    RepositoryBase,
    Core.Interfaces;

type
    TUserRepository = class(TRepositoryBase, IUserRepository)
    private
        function InternalLoadUsers(const SQL: string; const Params: array of Variant): TArray<TUserDTO>;
    public
        function Add(const User: TUserDTO): NativeInt;
        procedure Update(const User: TUserDTO);
        procedure Delete(Id: NativeInt);

        function GetByID(Id: NativeInt): TUserDTO;
        function GetAll: TArray<TUserDTO>;
        function GetByName(const Name: string): TArray<TUserDTO>;
        function TryGetByID(ID: NativeInt; out User: TUserDTO): Boolean;
    end;

implementation

uses
    System.SysUtils,
    System.Variants,
    FireDAC.Stan.Param,
    System.Classes;

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

function TUserRepository.GetByID(Id: NativeInt): TUserDTO;
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

function TUserRepository.Add(const User: TUserDTO): NativeInt;
var
    NewID: Variant;
begin
    FConnection.ExecSQL('INSERT INTO users (name, created_at) VALUES (?, ?)', [User.Name, User.CreatedAt]);
    NewID := FConnection.ExecSQLScalar('SELECT last_insert_rowid()');
    Result := NativeInt(NewID);
end;

procedure TUserRepository.Update(const User: TUserDTO);
begin
    FConnection.ExecSQL('UPDATE users ' + 'SET name = ? ' + 'WHERE id = ?', [User.Name, User.Id]);
end;

procedure TUserRepository.Delete(Id: NativeInt);
begin
    FConnection.ExecSQL('DELETE FROM users WHERE id = ?', [Id]);
end;

function TUserRepository.TryGetByID(ID: NativeInt; out User: TUserDTO): Boolean;
var
    Arr: TArray<TUserDTO>;
begin
    Arr := InternalLoadUsers('SELECT id, name, created_at FROM users WHERE id = ?', [ID]);

    Result := Length(Arr) > 0;

    if Result then
        User := Arr[0];
end;

end.

