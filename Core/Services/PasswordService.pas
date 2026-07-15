unit PasswordService;

interface

uses
    System.Math,
    System.SysUtils,
    Core.Interfaces,
    System.Generics.Collections;

type
    TPasswordService = class(TInterfacedObject, IPasswordService)
    private
        const
            ALPHA_LOWER = 'abcdefghijklmnopqrstuvwxyz';
            ALPHA_UPPER = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
            NUMBERS = '0123456789';
            SYMBOLS_STD = '!@#$%^&*()-_=+[{]};:,.<>/?';
            HEX_CHARS = 'abcdef0123456789';

            POOL_URL_SAFE = ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '-_.~';
            POOL_BITRIX = ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '!?()@#$-+=_';
            POOL_ORACLE = ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '_$#';
            POOL_NO_LOOK_ALIKES = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%^&*';

            // Новые пулы
            POOL_BASE64 = ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '+/';
            POOL_WEB_STD = ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '!@#$%*?';

            MAX_HISTORY_LEN = 512;
    private
        FHistory: TList<TPasswordHistoryItem>;

        // Вспомогательный метод: Фильтрует строку, удаляя из нее запрещенные символы
        function FilterForbiddenChars(const Source, Forbidden: string): string;

        // Перемешивает строку случайным образом (алгоритм Фишера-Йетса)
        function ShuffleString(const Source: string): string;

        // Изящный генератор без повторений символов
        function GenerateUniqueSequence(const FullPool, FirstCharPool: string; Length: Integer): string;

        // Стандартный быстрый генератор с повторениями
        function GenerateStandardSequence(const FullPool, FirstCharPool: string; Length: Integer): string;

        function HasAnyChar(const Str, Chars: string): Boolean;
        function IsValidForActiveDirectory(const Pwd: string): Boolean;

        // История
        procedure AddToHistory(const Password: string; Preset: TPasswordPreset; PassLen: Integer);
        function GetHistory: TArray<TPasswordHistoryItem>;
        procedure ClearHistory;

        // Внутренние вспомогательные генераторы фиксированных структур
        function GenerateMacAddress: string;
        function GenerateUUIDv4: string;
    public
        constructor Create;
        destructor Destroy; override;

        function GetCustomPoolSize(const Settings: TCustomPasswordSettings): Integer;
        function GeneratePassword(Preset: TPasswordPreset; Length: Integer; UniqueChars: Boolean): string;
        function GetPresetDescription(Preset: TPasswordPreset): string;
        function GetPoolSize(Preset: TPasswordPreset): Integer;
        function CalculateEntropy(Length, PoolSize: Integer): Double;
        function GenerateCustomPassword(const Settings: TCustomPasswordSettings; Length: Integer; UniqueChars: Boolean): string;
        procedure AddToHistoryCustom(const Password, CustomDescription: string; Entropy: Double);
    end;

implementation

{ TPasswordGeneratorService }

function TPasswordService.GetPresetDescription(Preset: TPasswordPreset): string;
begin
    case Preset of
        wpWebStandard:        Result := '[1] Обычный пароль для сайта (Web Safe)';
        wpActiveDirectory:    Result := '[2] Active Directory (A-Z, a-z, 0-9, спецсимвол)';
        wpStrictAlphaNumeric: Result := '[3] Только буквы и цифры (A-Z, a-z, 0-9)';
        wpMacAddress:         Result := '[4] MAC-адрес (XX:XX:XX:XX:XX:XX)';
        wpUUIDv4:             Result := '[5] UUID v4 (Случайный GUID)';
        wpBase64Key:          Result := '[6] Base64 Ключ (JWT/API)';
        wpBashSafe:           Result := '[7] Bash Safe (без $, !, `, \ и кавычек)';
        wpDockerEnvSafe:      Result := '[8] Docker & .env Safe';
        wpBitrixDb:           Result := '[9] Для БД Bitrix';
        wpPinCode:            Result := '[0] Пин-код (Только цифры)';
        wpCustom:             Result := '[C] Кастомные настройки...';
        wpHexToken:           Result := '[H] Hex-токен (a-f, 0-9)';
        wpUrlSafe:            Result := '[U] URL Safe (RFC 3986)';
        wpOracleSafe:         Result := '[O] Oracle DB (только _$#, с буквы)';
        wpNoLookAlikes:       Result := 'Без похожих символов (I, l, 1, O, 0)';
    else
        Result := 'Неизвестный шаблон';
    end;
end;

procedure TPasswordService.AddToHistory(const Password: string; Preset: TPasswordPreset; PassLen: Integer);
var
    Item: TPasswordHistoryItem;
    PoolSize: Integer;
begin
    Item.Password := Password;
    Item.PresetName := GetPresetDescription(Preset);
    PoolSize := GetPoolSize(Preset);
    Item.Entropy := CalculateEntropy(PassLen, PoolSize);
    Item.CreatedAt := Now;

    FHistory.Insert(0, Item);
    while FHistory.Count > MAX_HISTORY_LEN do
        FHistory.Delete(FHistory.Count - 1);
end;

procedure TPasswordService.AddToHistoryCustom(const Password, CustomDescription: string; Entropy: Double);
var
    Item: TPasswordHistoryItem;
begin
    Item.Password := Password;
    Item.PresetName := CustomDescription;
    Item.Entropy := Entropy;
    Item.CreatedAt := Now;

    FHistory.Insert(0, Item);
    while FHistory.Count > 20 do
        FHistory.Delete(FHistory.Count - 1);
end;

function TPasswordService.CalculateEntropy(Length, PoolSize: Integer): Double;
begin
    if (Length <= 0) or (PoolSize <= 0) then
        Exit(0.0);

    // Формула Шеннона: E = L * Log2(R)
    Result := Length * Log2(PoolSize);
end;

function TPasswordService.GetCustomPoolSize(const Settings: TCustomPasswordSettings): Integer;
var
    Pool: string;
    I: Integer;
begin
    Pool := '';
    if Settings.UseLower then Pool := Pool + ALPHA_LOWER;
    if Settings.UseUpper then Pool := Pool + ALPHA_UPPER;
    if Settings.UseNumbers then Pool := Pool + NUMBERS;
    if Settings.UseSymbols then Pool := Pool + SYMBOLS_STD;

    for I := 1 to Settings.IncludeChars.Length do
    begin
        if Pos(Settings.IncludeChars[I], Pool) = 0 then
            Pool := Pool + Settings.IncludeChars[I];
    end;

    Pool := FilterForbiddenChars(Pool, Settings.ExcludeChars);
    Result := Pool.Length;
end;

function TPasswordService.GetHistory: TArray<TPasswordHistoryItem>;
begin
    Result := FHistory.ToArray;
end;

function TPasswordService.GetPoolSize(Preset: TPasswordPreset): Integer;
var
    DummyPool: string;
begin
    case Preset of
        wpStrictAlphaNumeric: DummyPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS;
        wpPinCode:            DummyPool := NUMBERS;
        wpHexToken:           DummyPool := HEX_CHARS;
        wpBashSafe:           DummyPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '@%^&*()-_=+[{]};:,.<>/?';
        wpDockerEnvSafe:      DummyPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '_+-@%^&*()[]{}|;:,.<>/?';
        wpUrlSafe:            DummyPool := POOL_URL_SAFE;
        wpBitrixDb:           DummyPool := POOL_BITRIX;
        wpOracleSafe:         DummyPool := POOL_ORACLE;
        wpActiveDirectory:    DummyPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS + SYMBOLS_STD;
        wpNoLookAlikes:       DummyPool := POOL_NO_LOOK_ALIKES;
        // Пулы новых пресетов
        wpMacAddress, wpUUIDv4: DummyPool := HEX_CHARS; // Информативно для энтропии
        wpBase64Key:          DummyPool := POOL_BASE64;
        wpWebStandard:        DummyPool := POOL_WEB_STD;
    else
        DummyPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS;
    end;
    Result := Length(DummyPool);
end;

function TPasswordService.GenerateStandardSequence(const FullPool, FirstCharPool: string; Length: Integer): string;
var
    I: Integer;
begin
    Result := '';
    if Length <= 0 then Exit;
    Result := Result + FirstCharPool[Random(FirstCharPool.Length) + 1];
    for I := 2 to Length do
        Result := Result + FullPool[Random(FullPool.Length) + 1];
end;

function TPasswordService.GenerateUniqueSequence(const FullPool, FirstCharPool: string; Length: Integer): string;
var
    FirstChar: Char;
    RemainingPool: string;
    ResultStr: string;
    I: Integer;
begin
    FirstChar := FirstCharPool[Random(FirstCharPool.Length) + 1];
    ResultStr := FirstChar;

    RemainingPool := FullPool;
    I := Pos(FirstChar, RemainingPool);
    if I > 0 then
        Delete(RemainingPool, I, 1);

    RemainingPool := ShuffleString(RemainingPool);

    I := 1;
    while (ResultStr.Length < Length) and (I <= RemainingPool.Length) do
    begin
        ResultStr := ResultStr + RemainingPool[I];
        Inc(I);
    end;

    while ResultStr.Length < Length do
        ResultStr := ResultStr + FullPool[Random(FullPool.Length) + 1];

    if (Length > 2) and (Length > FullPool.Length) then
    begin
        RemainingPool := Copy(ResultStr, 2, ResultStr.Length - 1);
        ResultStr := FirstChar + ShuffleString(RemainingPool);
    end;

    Result := ResultStr;
end;

function TPasswordService.GenerateUUIDv4: string;
const
    HEX_ALL = '0123456789abcdef';
    HEX_Y   = '89ab'; // UUIDv4 требует 8, 9, a или b в этой позиции
var
    I: Integer;
begin
    Result := '';
    for I := 1 to 8 do Result := Result + HEX_ALL[Random(16) + 1];
    Result := Result + '-';
    for I := 1 to 4 do Result := Result + HEX_ALL[Random(16) + 1];
    Result := Result + '-4'; // Версия 4
    for I := 1 to 3 do Result := Result + HEX_ALL[Random(16) + 1];
    Result := Result + '-';
    Result := Result + HEX_Y[Random(4) + 1];
    for I := 1 to 3 do Result := Result + HEX_ALL[Random(16) + 1];
    Result := Result + '-';
    for I := 1 to 12 do Result := Result + HEX_ALL[Random(16) + 1];
end;

function TPasswordService.HasAnyChar(const Str, Chars: string): Boolean;
var
    C: Char;
begin
    Result := False;
    for C in Str do
        if Pos(C, Chars) > 0 then
            Exit(True);
end;

function TPasswordService.IsValidForActiveDirectory(const Pwd: string): Boolean;
var
    CategoriesCount: Integer;
begin
    // AD требует наличия минимум 3 из 4 категорий
    CategoriesCount := 0;
    if HasAnyChar(Pwd, ALPHA_LOWER) then
        Inc(CategoriesCount);
    if HasAnyChar(Pwd, ALPHA_UPPER) then
        Inc(CategoriesCount);
    if HasAnyChar(Pwd, NUMBERS) then
        Inc(CategoriesCount);
    if HasAnyChar(Pwd, SYMBOLS_STD) then
        Inc(CategoriesCount);

    Result := CategoriesCount >= 3;
end;

procedure TPasswordService.ClearHistory;
begin
    FHistory.Clear;
end;

constructor TPasswordService.Create;
begin
    inherited Create;
    FHistory := TList<TPasswordHistoryItem>.Create;
end;

destructor TPasswordService.Destroy;
begin
    FHistory.Free;
    inherited Destroy;
end;

function TPasswordService.FilterForbiddenChars(const Source, Forbidden: string): string;
var
    C: Char;
begin
    Result := '';
    for C in Source do
        if Pos(C, Forbidden) = 0 then
            Result := Result + C;
end;

function TPasswordService.ShuffleString(const Source: string): string;
var
    I, J: Integer;
    Temp: Char;
begin
    Result := Source;
    if Result.Length <= 1 then
        Exit;

    // Идеальное перемешивание напрямую в строке (Delphi использует индексацию с 1)
    for I := Result.Length downto 2 do
    begin
        J := Random(I) + 1; // Возвращает случайный индекс от 1 до I
        Temp := Result[I];
        Result[I] := Result[J];
        Result[J] := Temp;
    end;
end;

function TPasswordService.GenerateCustomPassword(const Settings: TCustomPasswordSettings; Length: Integer; UniqueChars: Boolean): string;
var
    FullPool: string;
    I: Integer;
    Positions: TList<Integer>;
    RndIdx, TargetPos: Integer;
begin
    if Length <= 0 then Exit('');

    // 1. Собираем пул на основе чекбоксов
    FullPool := '';
    if Settings.UseLower then FullPool := FullPool + ALPHA_LOWER;
    if Settings.UseUpper then FullPool := FullPool + ALPHA_UPPER;
    if Settings.UseNumbers then FullPool := FullPool + NUMBERS;
    if Settings.UseSymbols then FullPool := FullPool + SYMBOLS_STD;

    // 2. Подмешиваем кастомные символы (без дублей)
    for I := 1 to Settings.IncludeChars.Length do
    begin
        if Pos(Settings.IncludeChars[I], FullPool) = 0 then
            FullPool := FullPool + Settings.IncludeChars[I];
    end;

    // 3. Вырезаем исключенные символы
    FullPool := FilterForbiddenChars(FullPool, Settings.ExcludeChars);

    // Защита от пустого пула
    if FullPool.IsEmpty then
        FullPool := ALPHA_LOWER + NUMBERS;

    // 4. Генерируем стандартный скелет
    if UniqueChars then
        Result := GenerateUniqueSequence(FullPool, FullPool, Length)
    else
        Result := GenerateStandardSequence(FullPool, FullPool, Length);

    // 5. Криптографическая гарантия обязательных символов (Include)
    if not Settings.IncludeChars.IsEmpty and (Length >= Settings.IncludeChars.Length) then
    begin
        Positions := TList<Integer>.Create;
        try
            for I := 1 to Length do
                Positions.Add(I);

            for I := 1 to Settings.IncludeChars.Length do
            begin
                RndIdx := Random(Positions.Count);
                TargetPos := Positions[RndIdx];
                Positions.Delete(RndIdx); // Исключаем повторное использование одной позиции

                Result[TargetPos] := Settings.IncludeChars[I];
            end;
        finally
            Positions.Free;
        end;
    end;
end;

function TPasswordService.GenerateMacAddress: string;
const
    HEX_EVEN = '02468ace';
    HEX_ALL  = '0123456789abcdef';
var
    I: Integer;
begin
    // Генерируем валидный локальный Unicast MAC (младший бит первого байта равен 0)
    Result := HEX_ALL[Random(16) + 1] + HEX_EVEN[Random(8) + 1];
    for I := 1 to 5 do
        Result := Result + ':' + HEX_ALL[Random(16) + 1] + HEX_ALL[Random(16) + 1];
end;

function TPasswordService.GeneratePassword(Preset: TPasswordPreset; Length: Integer; UniqueChars: Boolean): string;
var
    FullPool: string;
    FirstCharPool: string;
begin
    // Специфические системные генераторы фиксированной длины
    if Preset = wpMacAddress then Exit(GenerateMacAddress);
    if Preset = wpUUIDv4 then Exit(GenerateUUIDv4);

    if Length <= 0 then Exit('');

    case Preset of
        wpStrictAlphaNumeric: FullPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS;
        wpPinCode:            FullPool := NUMBERS;
        wpHexToken:           FullPool := HEX_CHARS;
        wpUrlSafe:            FullPool := POOL_URL_SAFE;
        wpBitrixDb:           FullPool := POOL_BITRIX;
        wpOracleSafe:         FullPool := POOL_ORACLE;
        wpNoLookAlikes:       FullPool := POOL_NO_LOOK_ALIKES;
        wpActiveDirectory:    FullPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS + SYMBOLS_STD;
        wpBashSafe:           FullPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '@%^&*()-_=+[{]};:,.<>/?';
        wpDockerEnvSafe:      FullPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '_+-@%^&*()[]{}|;:,.<>/?';
        wpBase64Key:          FullPool := POOL_BASE64;
        wpWebStandard:        FullPool := POOL_WEB_STD;
    else
        FullPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS;
    end;

    FirstCharPool := FullPool;
    case Preset of
        wpDockerEnvSafe: FirstCharPool := FilterForbiddenChars(FullPool, '-+');
        wpOracleSafe:    FirstCharPool := ALPHA_LOWER + ALPHA_UPPER;
    end;

    if FirstCharPool.IsEmpty then
        FirstCharPool := FullPool;

    if UniqueChars then
        Result := GenerateUniqueSequence(FullPool, FirstCharPool, Length)
    else
    begin
        if Preset = wpActiveDirectory then
        begin
            repeat
                Result := GenerateStandardSequence(FullPool, FirstCharPool, Length);
            until IsValidForActiveDirectory(Result);
        end
        else
            Result := GenerateStandardSequence(FullPool, FirstCharPool, Length);
    end;
end;

initialization
    Randomize;

end.

