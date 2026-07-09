unit TagService;

interface

uses
    System.SysUtils,
    Tag,
    TagRepository;

type
    TTagService = class
    private
        FTagRepo: TTagRepository;
    public
        constructor Create(ATagRepo: TTagRepository);

        function GetAllTags: TArray<TTagDTO>;
        // Метод, который искал компилятор:
        function GetSnippetTags(SnippetID: NativeInt): TArray<TTagDTO>;

        function CreateTag(const Name, Color: string): NativeInt;
        procedure DeleteTag(TagID: NativeInt);
        procedure RenameTag(TagID: NativeInt; const NewName: string);
    end;

implementation

constructor TTagService.Create(ATagRepo: TTagRepository);
begin
    FTagRepo := ATagRepo;
end;

function TTagService.GetAllTags: TArray<TTagDTO>;
begin
    Result := FTagRepo.GetAll;
end;

function TTagService.GetSnippetTags(SnippetID: NativeInt): TArray<TTagDTO>;
begin
    // Базовая проверка бизнес-логики: ID не может быть нулевым или отрицательным
    if SnippetID <= 0 then
        Exit(nil);

    Result := FTagRepo.GetSnippetTags(SnippetID);
end;

function TTagService.CreateTag(const Name, Color: string): NativeInt;
var
    CleanName: string;
    NewTag: TTagDTO;
begin
    CleanName := Trim(Name);

    if CleanName = '' then
        raise Exception.Create('Имя тега не может быть пустым');

    if FTagRepo.ExistsByName(CleanName) then
        raise Exception.CreateFmt('Тег с именем "%s" уже существует!', [CleanName]);

    NewTag := Default(TTagDTO);
    NewTag.Name := CleanName;

    // Если в будущем добавишь поддержку цвета:
    // NewTag.Color := Color;

    Result := FTagRepo.Add(NewTag);
end;

procedure TTagService.DeleteTag(TagID: NativeInt);
begin
    if TagID <= 0 then
        raise Exception.Create('Некорректный ID тега');

    FTagRepo.Delete(TagID);
end;

procedure TTagService.RenameTag(TagID: NativeInt; const NewName: string);
var
    CleanName: string;
    TagToUpdate: TTagDTO;
begin
    CleanName := Trim(NewName);

    if CleanName = '' then
        raise Exception.Create('Имя тега не может быть пустым');

    if FTagRepo.ExistsByName(CleanName) then
        raise Exception.CreateFmt('Тег с именем "%s" уже существует!', [CleanName]);

    TagToUpdate := Default(TTagDTO);
    TagToUpdate.ID := TagID;
    TagToUpdate.Name := CleanName;

    FTagRepo.Update(TagToUpdate);
end;

end.
