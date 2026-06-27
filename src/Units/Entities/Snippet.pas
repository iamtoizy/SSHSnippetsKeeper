unit Snippet;

interface

uses
    Tag, Category;

type
    // DTO
    PSnippetDTO = ^TSnippetDTO;
    TSnippetDTO = record
    private
        class function New: TSnippetDTO; static;
    public
        // Поля
        ID: Integer;
        UserID: Integer;
        Title: string;
        Content: string;
        CategoryID: Integer;
        Category: TCategoryDTO; // для удобного отображения
        CreatedAt: Int64;
        UpdatedAt: Int64;
        Tags: TArray<TTagDTO>;

        class function Create: TSnippetDTO; static;

        // fluent API
        function SetID(AID: Integer): TSnippetDTO;
        function SetUserID(AUserID: Integer): TSnippetDTO;
        function SetTitle(const ATitle: string): TSnippetDTO;
        function SetContent(const AContent: string): TSnippetDTO;
        function SetCategoryID(ID: Integer): TSnippetDTO;
        function SetCategory(const Category: TCategoryDTO): TSnippetDTO;
        function SetCreatedAt(AValue: Int64): TSnippetDTO;
        function SetUpdatedAt(AValue: Int64): TSnippetDTO;
        function SetTags(const Tags: TArray<string>): TSnippetDTO;

        // Маппинг
        class function FromEntity(const E: TSnippetDTO): TSnippetDTO; static;
        function ToEntity: TSnippetDTO;
    end;

implementation

{ TSnippetDTO }

class function TSnippetDTO.New: TSnippetDTO;
begin
    Result := Default(TSnippetDTO);
end;

class function TSnippetDTO.Create: TSnippetDTO;
begin
    Result := New;
end;

function TSnippetDTO.SetCategoryID(ID: Integer): TSnippetDTO;
begin
    Result := Self;
    Result.CategoryID := ID;
end;

function TSnippetDTO.SetCategory(const Category: TCategoryDTO): TSnippetDTO;
begin
    Result := Self;
    Result.Category := Category;
    Result.CategoryID := Category.ID;
end;

function TSnippetDTO.SetContent(const AContent: string): TSnippetDTO;
begin
    Result := Self;
    Result.Content := AContent;
end;

function TSnippetDTO.SetCreatedAt(AValue: Int64): TSnippetDTO;
begin
    Result := Self;
    Result.CreatedAt := AValue;
end;

function TSnippetDTO.SetID(AID: Integer): TSnippetDTO;
begin
    Result := Self;
    Result.ID := AID;
end;

function TSnippetDTO.SetTags(const Tags: TArray<string>): TSnippetDTO;
var
    I: Integer;
begin
    Result := Self;
    SetLength(Result.Tags, Length(Result.Tags));
    for I := 0 to High(Tags) do
        Result.Tags[I].Name := Tags[I];
end;

function TSnippetDTO.SetTitle(const ATitle: string): TSnippetDTO;
begin
    Result := Self;
    Result.Title := ATitle;
end;

function TSnippetDTO.SetUpdatedAt(AValue: Int64): TSnippetDTO;
begin
    Result := Self;
    Result.UpdatedAt := AValue;
end;

function TSnippetDTO.SetUserID(AUserID: Integer): TSnippetDTO;
begin
    Result := Self;
    Result.UserID := AUserID;
end;

class function TSnippetDTO.FromEntity(const E: TSnippetDTO): TSnippetDTO;
begin
    Result := Default(TSnippetDTO);
    Result.ID := E.ID;
    Result.UserID := E.UserID;
    Result.Title := E.Title;
    Result.Content := E.Content;
    Result.Category := E.Category;
    Result.CreatedAt := E.CreatedAt;
    Result.UpdatedAt := E.UpdatedAt;
    Result.Tags := E.Tags; // Предполагаем, что TSnippet.Tags - это TArray<string>
end;

function TSnippetDTO.ToEntity: TSnippetDTO;
begin
    Result := Default(TSnippetDTO);
    Result := Self;
end;

end.

