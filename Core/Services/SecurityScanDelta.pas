unit SecurityScanDelta;

// Чистые функции фоновой проверки секретов: вычисление дельты проблемных
// сниппетов и выбор ключа локализации по правилам множественного числа.
// Отделены от контроллера, чтобы покрываться консольными тестами без UI.

interface

// ID сниппетов из Current, которых не было в Previous (новые находки)
function ComputeNewIDs(const Current, Previous: TArray<Integer>): TArray<Integer>;

// Ключ локализации тоста для количества новых находок:
// для ru - One/Few/Many (1 / 2-4 / 5+), для остальных языков - One/Few
function ScanFindingsMessageKey(ACount: Integer; const ALanguage: string): string;

implementation

uses
    System.Generics.Collections,
    System.SysUtils
    ;

function ComputeNewIDs(const Current, Previous: TArray<Integer>): TArray<Integer>;
var
    PreviousSet: TDictionary<Integer, Boolean>;
    ID: Integer;
begin
    PreviousSet := TDictionary<Integer, Boolean>.Create;
    try
        for ID in Previous do
            PreviousSet.AddOrSetValue(ID, True);

        for ID in Current do
            if not PreviousSet.ContainsKey(ID) then
            begin
                Result := Result + [ID];
                // Дубликат в Current не должен посчитаться дважды
                PreviousSet.AddOrSetValue(ID, True);
            end;
    finally
        PreviousSet.Free;
    end;
end;

function ScanFindingsMessageKey(ACount: Integer; const ALanguage: string): string;
begin
    if SameText(ALanguage, 'ru') then
    begin
        // Русские правила: 1 / 2-4 / 5+ (с исключением 11-14)
        if (ACount mod 10 = 1) and (ACount mod 100 <> 11) then
            Exit('Settings.ScanFindingsOne');

        if (ACount mod 10 >= 2) and (ACount mod 10 <= 4) and
            ((ACount mod 100 < 10) or (ACount mod 100 >= 20)) then
            Exit('Settings.ScanFindingsFew');

        Exit('Settings.ScanFindingsMany');
    end;

    if ACount = 1 then
        Result := 'Settings.ScanFindingsOne'
    else
        Result := 'Settings.ScanFindingsMany';
end;

end.
