unit SnippetHistoryService;

interface

uses
    Core.Entities.Snippet,
    Core.Interfaces.Data,
    Core.Interfaces.Services,
    SnippetService,
    System.SysUtils
    ;

type
    TSnippetHistoryService = class(TInterfacedObject, ISnippetHistoryService)
    private const
        DEFAULT_HISTORY_DEPTH = 20;
    private
        FHistoryRepo: ISnippetHistoryRepository;
        FSnippetService: ISnippetService;
    public
        constructor Create(HistoryRepo: ISnippetHistoryRepository; SnippetService: ISnippetService);

        function GetVersions(SnippetID: Integer; Limit: Integer = 0): TArray<TSnippetVersionDTO>;
        function GetVersion(VersionID: Integer): TSnippetVersionDTO;
        function GetVersionCount(SnippetID: Integer): Integer;
        procedure RestoreVersion(SnippetID, VersionID: Integer);
        procedure Prune(SnippetID: Integer);
        procedure SetSuppressed(Suppressed: Boolean);
    end;

implementation

uses
    Common.Localization,
    System.DateUtils
    ;

{ TSnippetHistoryService }

constructor TSnippetHistoryService.Create(HistoryRepo: ISnippetHistoryRepository;
    SnippetService: ISnippetService);
begin
    inherited Create;
    FHistoryRepo := HistoryRepo;
    FSnippetService := SnippetService;
end;

function TSnippetHistoryService.GetVersions(SnippetID: Integer; Limit: Integer): TArray<TSnippetVersionDTO>;
begin
    if Limit <= 0 then
        Limit := DEFAULT_HISTORY_DEPTH;
    Result := FHistoryRepo.GetVersions(SnippetID, Limit);
end;

function TSnippetHistoryService.GetVersion(VersionID: Integer): TSnippetVersionDTO;
begin
    Result := FHistoryRepo.GetVersion(VersionID);
end;

function TSnippetHistoryService.GetVersionCount(SnippetID: Integer): Integer;
begin
    Result := FHistoryRepo.GetVersionCount(SnippetID);
end;

procedure TSnippetHistoryService.RestoreVersion(SnippetID, VersionID: Integer);
var
    Current: TSnippetDTO;
    Ver: TSnippetVersionDTO;
    TagIDs: TArray<Integer>;
    I: Integer;
begin
    if SnippetID <= 0 then
        raise ESnippetValidationException.Create(
            TUIStateLoader.GetMessage('Snippet.InvalidIdError')
        );

    Ver := FHistoryRepo.GetVersion(VersionID);
    if (Ver.ID = 0) or (Ver.SnippetID <> SnippetID) then
        raise ESnippetValidationException.Create(
            TUIStateLoader.GetMessage('History.VersionNotFound')
        );

    Current := FSnippetService.GetSnippetByID(SnippetID);

    SetLength(TagIDs, Length(Current.Tags));
    for I := 0 to High(Current.Tags) do
        TagIDs[I] := Current.Tags[I].ID;

    Current.Title := Ver.Title;
    Current.Content := Ver.Content;
    Current.Comment := Ver.Comment;
    Current.UpdatedAt := DateTimeToUnix(Now);

    FSnippetService.UpdateSnippet(Current, TagIDs);
    Prune(SnippetID);
end;

procedure TSnippetHistoryService.Prune(SnippetID: Integer);
begin
    FHistoryRepo.DeleteOldest(SnippetID, DEFAULT_HISTORY_DEPTH);
end;

procedure TSnippetHistoryService.SetSuppressed(Suppressed: Boolean);
begin
    FHistoryRepo.SetSuppressed(Suppressed);
end;

end.
