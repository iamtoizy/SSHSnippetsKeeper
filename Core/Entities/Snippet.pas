unit Snippet;

interface

uses
    Tag, Category;

type
    TSnippetDTO = record
        ID: NativeInt;
        UserID: NativeInt;
        Title: string;
        Content: string;
        Comment: string;
        CategoryID: NativeInt;
        Category: TCategoryDTO;
        CreatedAt: Int64;
        UpdatedAt: Int64;
        Tags: TArray<TTagDTO>;
    end;

implementation

end.

