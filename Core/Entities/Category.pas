unit Category;

interface

type
    TCategoryDTO = record
        ID: Integer;
        UserID: NativeInt;
        Name: string;
        ParentID: Integer; // 0 если корень
        SortOrder: Integer;
    end;

implementation

end.

