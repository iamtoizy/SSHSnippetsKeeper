unit Core.Entities.Snippet;

interface

uses
    Core.Entities.Category,
    Core.Entities.Tag
    ;

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
        KeyDelayMs: Integer;
    end;

    TSnippetVersionDTO = record
        ID: Integer;
        SnippetID: Integer;
        Title: string;
        Content: string;
        Comment: string;
        CategoryID: Integer;
        ChangedAt: Int64;
    end;

implementation

end.

