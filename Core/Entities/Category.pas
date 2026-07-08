unit Category;

interface

type
    TCategoryDTO = record
        ID: Integer;
        UserID: NativeInt;
        Name: string;
        ParentID: Integer; // 0 если корень
        SortOrder: Integer;

        function SetID(AID: Integer): TCategoryDTO;
        function SetName(const AName: string): TCategoryDTO;
        function SetParentID(AParentID: Integer): TCategoryDTO;
        function SetSortOrder(ASortOrder: Integer): TCategoryDTO;
        class function FromEntity(const Category: TCategoryDTO): TCategoryDTO; static;
        function ToEntity: TCategoryDTO;
    end;

implementation

{ TCategoryDTO }

function TCategoryDTO.SetID(AID: Integer): TCategoryDTO;
begin
    Result := Self;
    Result.ID := AID;
end;

function TCategoryDTO.SetName(const AName: string): TCategoryDTO;
begin
    Result := Self;
    Result.Name := AName;
end;

function TCategoryDTO.SetParentID(AParentID: Integer): TCategoryDTO;
begin
    Result := Self;
    Result.ParentID := AParentID;
end;

function TCategoryDTO.SetSortOrder(ASortOrder: Integer): TCategoryDTO;
begin
    Result := Self;
    Result.SortOrder := ASortOrder;
end;

class function TCategoryDTO.FromEntity(const Category: TCategoryDTO): TCategoryDTO;
begin
    Result := Category;
end;

function TCategoryDTO.ToEntity: TCategoryDTO;
begin
    Result := Self;
end;

end.

