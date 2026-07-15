unit Snippet;

interface

uses
    Tag, Category;

type
    TSnippetDTO = record
        ID: Integer;
        UserID: Integer;
        Title: string;
        Content: string;
        Comment: string;
        CategoryID: Integer;
        Category: TCategoryDTO;
        CreatedAt: Int64;
        UpdatedAt: Int64;
        Tags: TArray<TTagDTO>;
        IsSecurityCheckIgnored: Boolean;
    end;

implementation

end.

