unit PresetData;

interface

type
    TPresetData = class
    public
        IsCustom: Boolean;
        OriginalName: string;
        constructor Create(AIsCustom: Boolean; const AName: string = '');
    end;

implementation

constructor TPresetData.Create(AIsCustom: Boolean; const AName: string);
begin
    inherited Create;
    IsCustom := AIsCustom;
    OriginalName := AName;
end;

end.
