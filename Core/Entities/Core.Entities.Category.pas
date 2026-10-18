unit Core.Entities.Category;

interface

type
    TCategoryDTO = record
        ID: Integer;
        UserID: Integer;
        Name: string;
        ParentID: Integer; // 0 если корень
        SortOrder: Integer;
    end;

implementation

end.

