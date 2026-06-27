unit Host;

interface

type
    // DTO
    THostDTO = record
        // Поля
        ID: Integer;
        Name: string;

        // Fluent API
        function SetID(ID: Integer): THostDTO;
        function SetName(Name: string): THostDTO;

        // Маппинг
        class function FromEntity(const Host: THostDTO): THostDTO; static;
        function ToEntity: THostDTO;
    end;

implementation

{ THostDTO }

function THostDTO.SetID(ID: Integer): THostDTO;
begin
    Result := default(THostDTO);
    Result.ID := ID;
end;

function THostDTO.SetName(Name: string): THostDTO;
begin
    Result := Self;
    Result.Name := Name;
end;

class function THostDTO.FromEntity(const Host: THostDTO): THostDTO;
begin
    Result := Default(THostDTO);
    Result.ID := Host.ID;
    Result.Name := Host.Name;
end;

function THostDTO.ToEntity: THostDTO;
begin
    Result := Self;
end;

end.

