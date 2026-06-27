unit Category;

interface

type
    TCategoryDTO = record
        ID: Integer;
        Name: string;
        ParentID: Integer; // 0 если корень

        function SetID(AID: Integer): TCategoryDTO;
        function SetName(const AName: string): TCategoryDTO;
        function SetParentID(AParentID: Integer): TCategoryDTO;
        class function FromEntity(const Cat: TCategoryDTO): TCategoryDTO; static;
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

class function TCategoryDTO.FromEntity(const Cat: TCategoryDTO): TCategoryDTO;
begin
    Result := Cat;
end;

function TCategoryDTO.ToEntity: TCategoryDTO;
begin
    Result := Self;
end;

end.

