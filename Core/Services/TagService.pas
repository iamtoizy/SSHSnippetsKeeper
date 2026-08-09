unit TagService;

interface

uses
    Core.Interfaces,
    System.SysUtils,
    Tag
    ;

type
    TTagService = class(TInterfacedObject, ITagService)
    private
        FTagRepo: ITagRepository;
    public
        constructor Create(TagRepo: ITagRepository);
        function GetAllTags: TArray<TTagDTO>;
        function GetSnippetTags(SnippetID: Integer): TArray<TTagDTO>;
        function CreateTag(const Name, Color: string): Integer;
        procedure DeleteTag(TagID: Integer);
        procedure RenameTag(TagID: Integer; const NewName: string);
        function GetOrCreateTag(const Name: string): Integer;
    end;

implementation

uses
    UI.StateLoader
    ;

constructor TTagService.Create(TagRepo: ITagRepository);
begin
    FTagRepo := TagRepo;
end;

function TTagService.GetAllTags: TArray<TTagDTO>;
begin
    Result := FTagRepo.GetAll;
end;

function TTagService.GetOrCreateTag(const Name: string): Integer;
var
    CleanName: string;
begin
    CleanName := Trim(Name);
    if CleanName = '' then
        Exit(0);

    Result := FTagRepo.GetOrCreateTag(CleanName);
end;

function TTagService.GetSnippetTags(SnippetID: Integer): TArray<TTagDTO>;
begin
    // ID не может быть нулевым или отрицательным
    if SnippetID <= 0 then
        Exit(nil);

    Result := FTagRepo.GetSnippetTags(SnippetID);
end;

function TTagService.CreateTag(const Name, Color: string): Integer;
var
    CleanName: string;
    NewTag: TTagDTO;
begin
    CleanName := Trim(Name);

    if CleanName = '' then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Tag.EmptyNameError')
        );

    if FTagRepo.ExistsByName(CleanName) then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Tag.DuplicateNameError', [CleanName])
        );

    NewTag := Default(TTagDTO);
    NewTag.Name := CleanName;
    Result := FTagRepo.Add(NewTag);
end;

procedure TTagService.DeleteTag(TagID: Integer);
begin
    if TagID <= 0 then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Tag.InvalidIdError')
        );

    FTagRepo.Delete(TagID);
end;

procedure TTagService.RenameTag(TagID: Integer; const NewName: string);
var
    CleanName: string;
    TagToUpdate: TTagDTO;
begin
    CleanName := Trim(NewName);

    if CleanName = '' then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Tag.EmptyNameError')
        );

    if FTagRepo.ExistsByName(CleanName) then
        raise Exception.Create(
            TUIStateLoader.GetMessage('Tag.DuplicateNameError', [CleanName])
        );

    TagToUpdate := Default(TTagDTO);
    TagToUpdate.ID := TagID;
    TagToUpdate.Name := CleanName;
    FTagRepo.Update(TagToUpdate);
end;

end.
