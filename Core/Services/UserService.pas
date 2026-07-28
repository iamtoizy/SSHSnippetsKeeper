unit UserService;

interface

uses
    Core.Interfaces,
    System.SysUtils,
    User
    ;

type
    TUserService = class(TInterfacedObject, IUserService)
    private
        FUserRepo: IUserRepository;
    public
        constructor Create(UserRepo: IUserRepository);

        function GetAllUsers: TArray<TUserDTO>;
        function GetUserByID(UserID: Integer): TUserDTO;
        function AddUser(const User: TUserDTO): Integer;
        procedure UpdateUser(const User: TUserDTO);
        procedure DeleteUser(UserID: Integer);
    end;

implementation

uses
    UI.StateLoader
    ;

constructor TUserService.Create(UserRepo: IUserRepository);
begin
    FUserRepo := UserRepo;
end;

function TUserService.GetAllUsers: TArray<TUserDTO>;
begin
    Result := FUserRepo.GetAll;
end;

function TUserService.GetUserByID(UserID: Integer): TUserDTO;
begin
    if UserID <= 0 then
        raise Exception.Create(
            TUIStateLoader.GetMessage('User.InvalidIdError')
        );
    // Делегируем получение данных репозиторию
    Result := FUserRepo.GetByID(UserID);
end;

function TUserService.AddUser(const User: TUserDTO): Integer;
begin
    if Trim(User.Name) = '' then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Workspace.EmptyNameError')
        );
    Result := FUserRepo.Add(User);
end;

procedure TUserService.UpdateUser(const User: TUserDTO);
begin
    if Trim(User.Name) = '' then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Workspace.EmptyNameError')
        );
    FUserRepo.Update(User);
end;

procedure TUserService.DeleteUser(UserID: Integer);
begin
    if UserID = 1 then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Workspace.SystemSpaceError')
        );
    FUserRepo.Delete(UserID);
end;

end.
