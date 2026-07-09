unit CategoryService;

interface

uses
    System.SysUtils,
    Category,
    CategoryRepository;

type
    TCategoryService = class
    private
        FCategoryRepo: TCategoryRepository;
    public
        constructor Create(ACategoryRepo: TCategoryRepository);

        function GetAllCategories(UserID: NativeInt = 0): TArray<TCategoryDTO>; // <-- ДОБАВЛЕНО
        function GetCategoryByID(CategoryID: NativeInt): TCategoryDTO;         // <-- ДОБАВЛЕНО

        function CreateCategory(const Category: TCategoryDTO): NativeInt;
        procedure RenameCategory(CategoryID: NativeInt; const NewName: string);// <-- ДОБАВЛЕНО
        procedure MoveCategory(CategoryID, NewParentID, Position: NativeInt);  // <-- ДОБАВЛЕНО
        procedure DeleteCategory(CategoryID: NativeInt);
    end;

implementation

constructor TCategoryService.Create(ACategoryRepo: TCategoryRepository);
begin
    FCategoryRepo := ACategoryRepo;
end;

function TCategoryService.GetAllCategories(UserID: NativeInt): TArray<TCategoryDTO>;
begin
    // Передаем UserID в репозиторий (0 означает "все пользователи")
    Result := FCategoryRepo.GetAll(UserID);
end;

function TCategoryService.GetCategoryByID(CategoryID: NativeInt): TCategoryDTO;
begin
    if CategoryID <= 0 then
        raise Exception.Create('Некорректный ID категории');
    Result := FCategoryRepo.GetByID(CategoryID);
end;

function TCategoryService.CreateCategory(const Category: TCategoryDTO): NativeInt;
begin
    if Trim(Category.Name) = '' then
        raise Exception.Create('Имя категории не может быть пустым');
    Result := FCategoryRepo.AddCategory(Category.Name, Category.ParentID, Category.UserID);
end;

procedure TCategoryService.RenameCategory(CategoryID: NativeInt; const NewName: string);
begin
    if CategoryID <= 0 then
        raise Exception.Create('Некорректный ID категории');
    if Trim(NewName) = '' then
        raise Exception.Create('Имя категории не может быть пустым');

    FCategoryRepo.UpdateName(CategoryID, NewName);
end;

procedure TCategoryService.MoveCategory(CategoryID, NewParentID, Position: NativeInt);
begin
    if CategoryID <= 0 then
        raise Exception.Create('Некорректный ID категории');
    // Проверка на циклические ссылки (перемещение родителя в ребенка) должна быть в репозитории или здесь
    FCategoryRepo.MoveCategory(CategoryID, NewParentID, Position);
end;

procedure TCategoryService.DeleteCategory(CategoryID: NativeInt);
begin
    if CategoryID <= 0 then
        raise Exception.Create('Некорректный ID категории');
    FCategoryRepo.DeleteCategory(CategoryID);
end;

end.
