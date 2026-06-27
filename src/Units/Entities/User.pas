unit User;

interface

type
    // DTO
    TUserDTO = record
        // Поля
        ID: Integer;
        Name: string;
        CreatedAt: Int64;

        // Fluent API
        function SetID(ID: Integer): TUserDTO;
        function SetName(Name: string): TUserDTO;
        function SetCreatedAt(AValue: Int64): TUserDTO;

        // Маппинг
        class function FromEntity(const Host: TUserDTO): TUserDTO; static;
        function ToEntity: TUserDTO;
    end;

implementation

{ THostDTO }

function TUserDTO.SetID(ID: Integer): TUserDTO;
begin
    Result := default(TUserDTO);
    Result.ID := ID;
end;

function TUserDTO.SetName(Name: string): TUserDTO;
begin
    Result := Self;
    Result.Name := Name;
end;

class function TUserDTO.FromEntity(const Host: TUserDTO): TUserDTO;
begin
    Result := Default(TUserDTO);
    Result.ID := Host.ID;
    Result.Name := Host.Name;
end;

function TUserDTO.ToEntity: TUserDTO;
begin
    Result := Self;
end;

function TUserDTO.SetCreatedAt(AValue: Int64): TUserDTO;
begin
    Result := Self;
    Result.CreatedAt := AValue;
end;

end.

