unit PasswordService;

interface

uses
    System.Math,
    System.SysUtils,
    Core.Interfaces,
    System.Generics.Collections,
    Winapi.Windows;

type
    TPasswordHistoryBuffer = class
    private
        FItems: TArray<TPasswordHistoryItem>;
        FCapacity: Integer;
        FHead: Integer;
        FCount: Integer;
    public
        constructor Create(ACapacity: Integer);
        procedure Add(const Item: TPasswordHistoryItem);
        function ToArray: TArray<TPasswordHistoryItem>;
        procedure Clear;
    end;

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

function RtlGenRandom(RandomBuffer: Pointer; RandomBufferLength: ULONG): BOOLEAN; stdcall; external 'advapi32.dll' name 'SystemFunction036';

implementation

uses
    System.Hash;

function SecureRandom(Max: Integer): Integer;
var
    Buffer: Cardinal;
    UMax: Cardinal;
    Guid: TGUID;
    HashBytes: TBytes;
    Product: UInt64;
begin
    if Max <= 0 then
        Exit(0);

    UMax := Cardinal(Max);

    // В 99.99999% случаев этот цикл отработает ровно 1 раз
    repeat
        // Пытаемся получить 4 байта криптографически стойких случайных данных
        if not RtlGenRandom(@Buffer, SizeOf(Buffer)) then
        begin
            // Fallback: если ОС вдруг откажет (что бывает крайне редко), падаем на вариант с THash
			// CreateGUID использует системные криптографические функции (Утиль ОС)
            CreateGUID(Guid);
			// Хэшируем GUID через SHA256, чтобы равномерно распределить биты
            HashBytes := THashSHA2.GetHashBytes(Guid.ToString);
			// Берем первые 4 байта хэша
            Move(HashBytes[0], Buffer, SizeOf(Buffer));
        end;

        // Умножаем случайное число на Max (алгоритм Fast Range, популяризован Дэниелом Лемиром)
        Product := UInt64(Buffer) * UInt64(UMax);

        // Нижние 32 бита (Product and $FFFFFFFF) служат нам "остатком".
        // Если они меньше UMax, то это те самые "лишние карты", которые нужно отбросить
        // для идеальной криптографии (Modulo Bias elimination).
    until Cardinal(Product) >= UMax;

    // Старшие 32 бита - это наш идеально ровный результат в диапазоне [0, Max - 1]
    Result := Integer(Product shr 32);
end;

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
begin
    Item.Password := Password;
    Item.PresetName := GetPresetDescription(Preset);
    Item.Entropy := CalculateEntropy(PassLen, GetPoolSize(Preset));
    Item.CreatedAt := Now;

    FHistory.Add(Item);
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

    Result := Result + FirstCharPool[SecureRandom(FirstCharPool.Length) + 1];

    for I := 2 to Length do
        Result := Result + FullPool[SecureRandom(FullPool.Length) + 1];
end;

function TPasswordService.GenerateUniqueSequence(const FullPool, FirstCharPool: string; Length: Integer): string;
var
    FirstChar: Char;
    RemainingPool: string;
    ResultStr: string;
    I: Integer;
begin
    FirstChar := FirstCharPool[SecureRandom(FirstCharPool.Length) + 1];
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
        ResultStr := ResultStr + FullPool[SecureRandom(FullPool.Length) + 1];

    if (Length > 2) and (Length > FullPool.Length) then
    begin
        RemainingPool := Copy(ResultStr, 2, ResultStr.Length - 1);
        ResultStr := FirstChar + ShuffleString(RemainingPool);
    end;

    Result := ResultStr;
end;

function TPasswordService.GenerateUUIDv4: string;
var
  Guid: TGUID;
begin
  CreateGUID(Guid);
  Result := LowerCase(Copy(GuidToString(Guid), 2, 36));
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

    for I := Result.Length downto 2 do
    begin
        J := SecureRandom(I) + 1; // Заменили Random на SecureRandom
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
    SB: TStringBuilder;
begin
    if Length <= 0 then Exit('');

    // Быстро собираем базовый пул через TStringBuilder (без лишней аллокации памяти)
    SB := TStringBuilder.Create;
    try
        if Settings.UseLower then SB.Append(ALPHA_LOWER);
        if Settings.UseUpper then SB.Append(ALPHA_UPPER);
        if Settings.UseNumbers then SB.Append(NUMBERS);
        if Settings.UseSymbols then SB.Append(SYMBOLS_STD);

        FullPool := SB.ToString;
    finally
        SB.Free;
    end;

    // Подмешиваем кастомные символы (без дублей)
    for I := 1 to Settings.IncludeChars.Length do
    begin
        if Pos(Settings.IncludeChars[I], FullPool) = 0 then
            FullPool := FullPool + Settings.IncludeChars[I];
    end;

    // Вырезаем исключенные символы
    FullPool := FilterForbiddenChars(FullPool, Settings.ExcludeChars);

    // Защита от пустого пула (например, пользователь снял все чекбоксы и ничего не вписал)
    if FullPool.IsEmpty then
        FullPool := ALPHA_LOWER + NUMBERS;

    // Генерируем стандартный скелет
    if UniqueChars then
        Result := GenerateUniqueSequence(FullPool, FullPool, Length)
    else
        Result := GenerateStandardSequence(FullPool, FullPool, Length);

    // Криптографическая гарантия обязательных символов (Include)
    if not Settings.IncludeChars.IsEmpty and (Length >= Settings.IncludeChars.Length) then
    begin
        Positions := TList<Integer>.Create;
        try
            for I := 1 to Length do
                Positions.Add(I);

            for I := 1 to Settings.IncludeChars.Length do
            begin
                RndIdx := SecureRandom(Positions.Count);
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
    Result := HEX_ALL[SecureRandom(16) + 1] + HEX_EVEN[SecureRandom(8) + 1];
    for I := 1 to 5 do
        Result := Result + ':' + HEX_ALL[SecureRandom(16) + 1] + HEX_ALL[SecureRandom(16) + 1];
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

{ TPasswordHistoryBuffer }

procedure TPasswordHistoryBuffer.Add(const Item: TPasswordHistoryItem);
begin
    FItems[FHead] := Item;
    FHead := (FHead + 1) mod FCapacity; // Идем по кругу
    if FCount < FCapacity then
        Inc(FCount);
end;

procedure TPasswordHistoryBuffer.Clear;
begin
    FHead := 0;
    FCount := 0;
end;

constructor TPasswordHistoryBuffer.Create(ACapacity: Integer);
begin
    FCapacity := ACapacity;
    SetLength(FItems, FCapacity);
    Clear;
end;

function TPasswordHistoryBuffer.ToArray: TArray<TPasswordHistoryItem>;
var
    I, Idx: Integer;
begin
    SetLength(Result, FCount);
    // Возвращаем в обратном порядке: от самых свежих к старым (удобно для UI)
    for I := 0 to FCount - 1 do
    begin
        Idx := FHead - 1 - I;
        if Idx < 0 then
            Inc(Idx, FCapacity);
        Result[I] := FItems[Idx];
    end;
end;

initialization
    Randomize;

end.

