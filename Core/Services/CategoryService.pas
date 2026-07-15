unit CategoryService;

interface

uses
    System.SysUtils,
    Category,
    Core.Interfaces;

type
    TCategoryService = class(TInterfacedObject, ICategoryService)
    private
        FCategoryRepo: ICategoryRepository;
    public
        constructor Create(CategoryRepo: ICategoryRepository);

        function GetAllCategories(UserID: Integer = 0): TArray<TCategoryDTO>;
        function GetCategoryByID(CategoryID: Integer): TCategoryDTO;

        function CreateCategory(const Category: TCategoryDTO): Integer;
        procedure RenameCategory(CategoryID: Integer; const NewName: string);
        procedure MoveCategory(CategoryID, NewParentID, Position: Integer);
        procedure DeleteCategory(CategoryID: Integer);
    end;

implementation

constructor TCategoryService.Create(CategoryRepo: ICategoryRepository);
begin
    FCategoryRepo := CategoryRepo;
end;

function TCategoryService.GetAllCategories(UserID: Integer): TArray<TCategoryDTO>;
begin
    // Передаем UserID в репозиторий (0 означает "все пользователи")
    Result := FCategoryRepo.GetAll(UserID);
end;

function TCategoryService.GetCategoryByID(CategoryID: Integer): TCategoryDTO;
begin
    if CategoryID <= 0 then
        raise Exception.Create('Некорректный ID категории');
    Result := FCategoryRepo.GetByID(CategoryID);
end;

function TCategoryService.CreateCategory(const Category: TCategoryDTO): Integer;
begin
    if Trim(Category.Name) = '' then
        raise Exception.Create('Имя категории не может быть пустым');
    Result := FCategoryRepo.AddCategory(Category.Name, Category.ParentID, Category.UserID);
end;

procedure TCategoryService.RenameCategory(CategoryID: Integer; const NewName: string);
begin
    if CategoryID <= 0 then
        raise Exception.Create('Некорректный ID категории');
    if Trim(NewName) = '' then
        raise Exception.Create('Имя категории не может быть пустым');

    FCategoryRepo.UpdateName(CategoryID, NewName);
end;

procedure TCategoryService.MoveCategory(CategoryID, NewParentID, Position: Integer);
begin
    if CategoryID <= 0 then
        raise Exception.Create('Некорректный ID категории');
    // Проверка на циклические ссылки (перемещение родителя в ребенка) должна быть в репозитории или здесь
    FCategoryRepo.MoveCategory(CategoryID, NewParentID, Position);
end;

procedure TCategoryService.DeleteCategory(CategoryID: Integer);
begin
    if CategoryID <= 0 then
        raise Exception.Create('Некорректный ID категории');
    FCategoryRepo.DeleteCategory(CategoryID);
end;

end.
