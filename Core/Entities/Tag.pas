unit Tag;

interface

type
    // DTO
    TTagDTO = record
    private
        class function New: TTagDTO; static;
    public
        // Поля
        ID: Integer;
        Name: string;

        // fluent API
        class function Create: TTagDTO; static;
        function &SetID(AID: Integer): TTagDTO; inline;
        function &SetName(const AName: string): TTagDTO; inline;

        // Маппинг
        class function FromEntity(const E: TTagDTO): TTagDTO; static;
        function ToEntity: TTagDTO;
    end;

implementation

{ TTagDTO }

class function TTagDTO.New: TTagDTO;
begin
    Result := Default(TTagDTO);
end;

class function TTagDTO.Create: TTagDTO;
begin
    Result := New;
end;

class function TTagDTO.FromEntity(const E: TTagDTO): TTagDTO;
begin
    Result :=New
        .&SetID(E.ID)
        .&SetName(E.Name);
end;

function TTagDTO.SetID(AID: Integer): TTagDTO;
begin
    Result := Self;
    Result.ID := AID;
end;

function TTagDTO.SetName(const AName: string): TTagDTO;
begin
    Result := Self;
    Result.Name := AName;
end;

function TTagDTO.ToEntity: TTagDTO;
begin
    Result := Self;
end;

end.

