unit User;

interface

type
    TUserDTO = record
        ID: Integer;
        Name: string;
        CreatedAt: Int64;

        function SetID(ID: Integer): TUserDTO;
        function SetName(Name: string): TUserDTO;
        function SetCreatedAt(AValue: Int64): TUserDTO;

        class function FromEntity(const User: TUserDTO): TUserDTO; static;
        function ToEntity: TUserDTO;
    end;

implementation

function TUserDTO.SetID(ID: Integer): TUserDTO;
begin
    Result := Self;
    Result.ID := ID;
end;

function TUserDTO.SetName(Name: string): TUserDTO;
begin
    Result := Self;
    Result.Name := Name;
end;

function TUserDTO.SetCreatedAt(AValue: Int64): TUserDTO;
begin
    Result := Self;
    Result.CreatedAt := AValue;
end;

class function TUserDTO.FromEntity(const User: TUserDTO): TUserDTO;
begin
    Result := User;
end;

function TUserDTO.ToEntity: TUserDTO;
begin
    Result := Self;
end;

end.
