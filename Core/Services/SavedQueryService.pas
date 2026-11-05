unit SavedQueryService;

interface

uses
    Core.Entities.SavedQuery,
    Core.Interfaces.Data,
    Core.Interfaces.Services
    ;

type
    TSavedQueryService = class(TInterfacedObject, ISavedQueryService)
    private
        FRepository: ISavedQueryRepository;
    public
        constructor Create(SavedQueryRepository: ISavedQueryRepository);

        function GetAllSavedQueries(UserID: Integer): TArray<TSavedQueryDTO>;
        function GetSavedQueryByID(ID: Integer): TSavedQueryDTO;
        function CreateSavedQuery(UserID: Integer; const Name, QueryText: string): Integer;
        procedure RenameSavedQuery(ID: Integer; const NewName: string);
        procedure DeleteSavedQuery(ID: Integer);
    end;

implementation

uses
    Common.Localization,
    System.SysUtils
    ;

{ TSavedQueryService }

constructor TSavedQueryService.Create(SavedQueryRepository: ISavedQueryRepository);
begin
    inherited Create;
    FRepository := SavedQueryRepository;
end;

function TSavedQueryService.GetAllSavedQueries(UserID: Integer): TArray<TSavedQueryDTO>;
begin
    Result := FRepository.GetAll(UserID);
end;

function TSavedQueryService.GetSavedQueryByID(ID: Integer): TSavedQueryDTO;
begin
    Result := FRepository.GetByID(ID);
end;

function TSavedQueryService.CreateSavedQuery(UserID: Integer; const Name, QueryText: string): Integer;
var
    SavedQuery: TSavedQueryDTO;
    TrimmedName, TrimmedQuery: string;
begin
    TrimmedName := Trim(Name);
    if TrimmedName = '' then
        raise Exception.Create(TUIStateLoader.GetMessage('SavedQueries.Error.EmptyName'));

    TrimmedQuery := Trim(QueryText);
    if TrimmedQuery = '' then
        raise Exception.Create(TUIStateLoader.GetMessage('SavedQueries.Error.EmptyQuery'));

    if FRepository.NameExists(TrimmedName, UserID, 0) then
        raise Exception.Create(TUIStateLoader.GetMessage('SavedQueries.Error.DuplicateName', [TrimmedName]));

    SavedQuery := Default(TSavedQueryDTO);
    SavedQuery.UserID := UserID;
    SavedQuery.Name := TrimmedName;
    SavedQuery.QueryText := TrimmedQuery;
    Result := FRepository.Add(SavedQuery);
end;

procedure TSavedQueryService.RenameSavedQuery(ID: Integer; const NewName: string);
var
    SavedQuery: TSavedQueryDTO;
    TrimmedName: string;
begin
    TrimmedName := Trim(NewName);
    if TrimmedName = '' then
        raise Exception.Create(TUIStateLoader.GetMessage('SavedQueries.Error.EmptyName'));

    SavedQuery := FRepository.GetByID(ID);
    if SavedQuery.ID = 0 then
        raise Exception.Create(TUIStateLoader.GetMessage('SavedQueries.Error.NotFound'));

    if FRepository.NameExists(TrimmedName, SavedQuery.UserID, ID) then
        raise Exception.Create(TUIStateLoader.GetMessage('SavedQueries.Error.DuplicateName', [TrimmedName]));

    FRepository.UpdateName(ID, TrimmedName);
end;

procedure TSavedQueryService.DeleteSavedQuery(ID: Integer);
begin
    FRepository.Delete(ID);
end;

end.
