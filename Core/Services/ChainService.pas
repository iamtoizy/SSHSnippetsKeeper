unit ChainService;

interface

uses
    Core.Entities.Chain,
    Core.Interfaces.Data,
    Core.Interfaces.Services
    ;

type
    TChainService = class(TInterfacedObject, IChainService)
    private
        FRepository: IChainRepository;
        FSnippetService: ISnippetService;
    public
        constructor Create(ChainRepository: IChainRepository; SnippetService: ISnippetService);

        function GetAllChains(UserID: Integer): TArray<TChainDTO>;
        function GetChainByID(ID: Integer): TChainDTO;
        function CreateChain(UserID: Integer; const Name: string): Integer;
        procedure RenameChain(ID: Integer; const NewName: string);
        procedure DeleteChain(ID: Integer);
        function GetSteps(ChainID: Integer): TArray<TChainStepDTO>;
        procedure SaveSteps(ChainID: Integer; const Steps: TArray<TChainStepDTO>);
    end;

implementation

uses
    Common.Localization,
    System.SysUtils
    ;

{ TChainService }

constructor TChainService.Create(ChainRepository: IChainRepository; SnippetService: ISnippetService);
begin
    inherited Create;
    FRepository := ChainRepository;
    FSnippetService := SnippetService;
end;

function TChainService.GetAllChains(UserID: Integer): TArray<TChainDTO>;
begin
    Result := FRepository.GetAll(UserID);
end;

function TChainService.GetChainByID(ID: Integer): TChainDTO;
begin
    Result := FRepository.GetByID(ID);
end;

function TChainService.CreateChain(UserID: Integer; const Name: string): Integer;
var
    Chain: TChainDTO;
    TrimmedName: string;
begin
    TrimmedName := Trim(Name);
    if TrimmedName = '' then
        raise Exception.Create(TUIStateLoader.GetMessage('Chains.Error.EmptyName'));

    if FRepository.NameExists(TrimmedName, UserID, 0) then
        raise Exception.Create(TUIStateLoader.GetMessage('Chains.Error.DuplicateName', [TrimmedName]));

    Chain := Default(TChainDTO);
    Chain.UserID := UserID;
    Chain.Name := TrimmedName;
    Result := FRepository.Add(Chain);
end;

procedure TChainService.RenameChain(ID: Integer; const NewName: string);
var
    Chain: TChainDTO;
    TrimmedName: string;
begin
    TrimmedName := Trim(NewName);
    if TrimmedName = '' then
        raise Exception.Create(TUIStateLoader.GetMessage('Chains.Error.EmptyName'));

    Chain := FRepository.GetByID(ID);
    if Chain.ID = 0 then
        raise Exception.Create(TUIStateLoader.GetMessage('Chains.Error.NotFound'));

    if FRepository.NameExists(TrimmedName, Chain.UserID, ID) then
        raise Exception.Create(TUIStateLoader.GetMessage('Chains.Error.DuplicateName', [TrimmedName]));

    FRepository.UpdateName(ID, TrimmedName);
end;

procedure TChainService.DeleteChain(ID: Integer);
begin
    FRepository.Delete(ID);
end;

function TChainService.GetSteps(ChainID: Integer): TArray<TChainStepDTO>;
begin
    Result := FRepository.GetSteps(ChainID);
end;

procedure TChainService.SaveSteps(ChainID: Integer; const Steps: TArray<TChainStepDTO>);
var
    I: Integer;
    Normalized: TArray<TChainStepDTO>;
begin
    if FRepository.GetByID(ChainID).ID = 0 then
        raise Exception.Create(TUIStateLoader.GetMessage('Chains.Error.NotFound'));

    Normalized := Copy(Steps, 0, Length(Steps));
    for I := 0 to High(Normalized) do
    begin
        if FSnippetService.GetSnippetByID(Normalized[I].SnippetID).ID = 0 then
            raise Exception.Create(TUIStateLoader.GetMessage('Chains.Error.SnippetNotFound', [I + 1]));
        if Normalized[I].PauseMs < 0 then
            Normalized[I].PauseMs := 0;
        Normalized[I].Position := I;
    end;

    FRepository.ReplaceSteps(ChainID, Normalized);
end;

end.
