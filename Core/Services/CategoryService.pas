unit CategoryService;

interface

uses
    Core.Entities.Category,
    Core.Interfaces.Data, Core.Interfaces.Services, Core.Interfaces.Passwords,
    System.SysUtils
    ;

type
    TCategoryService = class(TInterfacedObject, ICategoryService)
    private const
        MAX_TREE_DEPTH = 32;
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

uses
    Common.Localization
    ;

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
        raise Exception.Create(
            TUIStateLoader.GetMessage('Category.InvalidIdError')
        );
    Result := FCategoryRepo.GetByID(CategoryID);
end;

function TCategoryService.CreateCategory(const Category: TCategoryDTO): Integer;
var
    CleanName: string;
begin
    CleanName := Trim(Category.Name);
    if CleanName = '' then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Category.EmptyNameError')
        );
    // Дубли ловим до UNIQUE-индекса: иначе юзер видит сырую ошибку SQLite
    if FCategoryRepo.ExistsInParent(CleanName, Category.ParentID, Category.UserID) then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Category.DuplicateNameError', [CleanName])
        );
    Result := FCategoryRepo.AddCategory(CleanName, Category.ParentID, Category.UserID);
end;

procedure TCategoryService.RenameCategory(CategoryID: Integer; const NewName: string);
var
    CleanName: string;
    Cat: TCategoryDTO;
begin
    if CategoryID <= 0 then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Category.InvalidIdError')
        );
    CleanName := Trim(NewName);
    if CleanName = '' then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Category.EmptyNameError')
        );

    Cat := FCategoryRepo.GetByID(CategoryID);
    if Cat.ID = 0 then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Category.CategoryNotFound')
        );

    // Сама категория не считается дублем своего текущего имени
    if (not SameText(CleanName, Cat.Name)) and
        FCategoryRepo.ExistsInParent(CleanName, Cat.ParentID, Cat.UserID) then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Category.DuplicateNameError', [CleanName])
        );

    FCategoryRepo.UpdateName(CategoryID, CleanName);
end;

procedure TCategoryService.MoveCategory(CategoryID, NewParentID, Position: Integer);
var
    Cur: TCategoryDTO;
    Depth: Integer;
begin
    if CategoryID <= 0 then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Category.InvalidIdError')
        );
    if NewParentID < 0 then
        NewParentID := 0;

    // Защита от цикла: новый родитель - сам узел или его потомок.
    // UI-гвард drag&drop работает по узлам дерева и может видеть устаревшие
    // данные, поэтому проверяем по фактической цепочке родителей в БД
    if NewParentID = CategoryID then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Category.CircularMoveError')
        );
    if NewParentID > 0 then
    begin
        Cur := FCategoryRepo.GetByID(NewParentID);
        Depth := 0;
        while (Cur.ParentID > 0) and (Depth < MAX_TREE_DEPTH) do
        begin
            if Cur.ParentID = CategoryID then
                raise Exception.Create(
                    TUIStateLoader.GetMessage('Category.CircularMoveError')
                );
            Cur := FCategoryRepo.GetByID(Cur.ParentID);
            Inc(Depth);
        end;
    end;

    FCategoryRepo.MoveCategory(CategoryID, NewParentID, Position);
end;

procedure TCategoryService.DeleteCategory(CategoryID: Integer);
begin
    if CategoryID <= 0 then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Category.InvalidIdError')
        );
    FCategoryRepo.DeleteCategory(CategoryID);
end;

end.
