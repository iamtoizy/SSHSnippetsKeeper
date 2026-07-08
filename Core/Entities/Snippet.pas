unit Snippet;

interface

uses
    Tag, Category;

type
    // DTO
    TSnippetDTO = record
    private
        class function New: TSnippetDTO; static;
    public
        // Поля
        ID: NativeInt;
        UserID: NativeInt;
        Title: string;
        Content: string;
        Comment: string;
        CategoryID: NativeInt;
        Category: TCategoryDTO; // для удобного отображения
        CreatedAt: Int64;
        UpdatedAt: Int64;
        Tags: TArray<TTagDTO>;

        class function Create: TSnippetDTO; static;

        // fluent API
        function SetID(AID: NativeInt): TSnippetDTO;
        function SetUserID(AUserID: NativeInt): TSnippetDTO;
        function SetTitle(const ATitle: string): TSnippetDTO;
        function SetContent(const AContent: string): TSnippetDTO;
        function SetComment(const AComment: string): TSnippetDTO;
        function SetCategoryID(ID: NativeInt): TSnippetDTO;
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

function TSnippetDTO.SetCategoryID(ID: NativeInt): TSnippetDTO;
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

function TSnippetDTO.SetComment(const AComment: string): TSnippetDTO;
begin
    Result := Self;
    Result.Comment := AComment;
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

function TSnippetDTO.SetID(AID: NativeInt): TSnippetDTO;
begin
    Result := Self;
    Result.ID := AID;
end;

function TSnippetDTO.SetTags(const Tags: TArray<string>): TSnippetDTO;
var
    I: NativeInt;
begin
    Result := Self;
    SetLength(Result.Tags, Length(Tags));
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

function TSnippetDTO.SetUserID(AUserID: NativeInt): TSnippetDTO;
begin
    Result := Self;
    Result.UserID := AUserID;
end;

class function TSnippetDTO.FromEntity(const E: TSnippetDTO): TSnippetDTO;
begin
    Result := E;
end;

function TSnippetDTO.ToEntity: TSnippetDTO;
begin
    Result := Self;
end;

end.

