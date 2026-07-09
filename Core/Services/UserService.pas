unit UserService;

interface

uses
    System.SysUtils,
    User,
    UserRepository;

type
    TUserService = class
    private
        FUserRepo: TUserRepository;
    public
        constructor Create(AUserRepo: TUserRepository);

        function GetAllUsers: TArray<TUserDTO>;
        function GetUserByID(UserID: NativeInt): TUserDTO; // <-- ДОБАВЛЕНО
        function AddUser(const User: TUserDTO): NativeInt;
        procedure UpdateUser(const User: TUserDTO);
        procedure DeleteUser(UserID: NativeInt);
    end;

implementation

constructor TUserService.Create(AUserRepo: TUserRepository);
begin
    FUserRepo := AUserRepo;
end;

function TUserService.GetAllUsers: TArray<TUserDTO>;
begin
    Result := FUserRepo.GetAll;
end;

function TUserService.GetUserByID(UserID: NativeInt): TUserDTO;
begin
    if UserID <= 0 then
        raise Exception.Create('Некорректный ID пользователя');
    // Делегируем получение данных репозиторию
    Result := FUserRepo.GetByID(UserID);
end;

function TUserService.AddUser(const User: TUserDTO): NativeInt;
begin
    if Trim(User.Name) = '' then
        raise Exception.Create('Имя пространства не может быть пустым');
    Result := FUserRepo.Add(User);
end;

procedure TUserService.UpdateUser(const User: TUserDTO);
begin
    if Trim(User.Name) = '' then
        raise Exception.Create('Имя пространства не может быть пустым');
    FUserRepo.Update(User);
end;

procedure TUserService.DeleteUser(UserID: NativeInt);
begin
    if UserID = 1 then
        raise Exception.Create('Это пространство нельзя удалить (системное).');
    FUserRepo.Delete(UserID);
end;

end.
