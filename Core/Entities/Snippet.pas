unit Snippet;

interface

uses
    Tag, Category;

type
    // DTO
    TSnippetDTO = record
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
    end;

implementation

end.

