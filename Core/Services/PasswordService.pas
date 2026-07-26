unit PasswordService;

interface

uses
    System.Math,
    System.SysUtils,
    Core.Interfaces,
    System.Generics.Collections,
    Winapi.Windows,
    System.SyncObjs;

const
    // Константы для Windows DPAPI (RAM Encryption)
    CRYPTPROTECTMEMORY_BLOCK_SIZE = 16;
    CRYPTPROTECTMEMORY_SAME_PROCESS = 0;

// Импорт криптографических функций для шифрования и очистки памяти
function CryptProtectMemory(pDataIn: Pointer; cbDataIn: Cardinal; dwFlags: Cardinal): BOOL; stdcall; external 'Crypt32.dll';
function CryptUnprotectMemory(pDataIn: Pointer; cbDataIn: Cardinal; dwFlags: Cardinal): BOOL; stdcall; external 'Crypt32.dll';
function RtlGenRandom(RandomBuffer: Pointer; RandomBufferLength: ULONG): BOOLEAN; stdcall; external 'advapi32.dll' name 'SystemFunction036';

type
    // Внутренняя структура: пароль надежно зашифрован в RAM
    TEncryptedHistoryItem = record
        EncryptedPassword: TBytes;
        OriginalLen: Integer;
        PresetName: string;
        Entropy: Double;
        CreatedAt: TDateTime;
    end;

    TPasswordHistoryBuffer = class
    private
        FItems: TArray<TEncryptedHistoryItem>;
        FCapacity: Integer;
        FHead: Integer;
        FCount: Integer;
    public
        constructor Create(ACapacity: Integer);
        procedure Add(const Item: TEncryptedHistoryItem);
        function ToArray: TArray<TEncryptedHistoryItem>;
        procedure Clear;
    end;

    TPasswordService = class(TInterfacedObject, IPasswordService)
    private
        const
            ALPHA_LOWER         = 'abcdefghijklmnopqrstuvwxyz';
            ALPHA_UPPER         = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
            NUMBERS             = '0123456789';
            SYMBOLS_STD         = '!@#$%^&*()-_=+[{]};:,.<>/?';
            HEX_CHARS           = 'abcdef0123456789';

            POOL_URL_SAFE       = ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '-_.~';
            POOL_BITRIX         = ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '!?()@#$-+=_';
            POOL_ORACLE         = ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '_$#';
            POOL_NO_LOOK_ALIKES = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%^&*';

            POOL_BASE64         = ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '+/';
            POOL_WEB_STD        = ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '!@#$%*?';

            MAX_HISTORY_LEN     = 512;
    private
        FHistory: TPasswordHistoryBuffer;
        FHistoryLock: TCriticalSection;

        // DPAPI Helpers (Скрыты от внешнего мира)
        function ProtectString(const S: string; out OriginalBytes: Integer): TBytes;
        function DecryptHistoryItem(const Item: TEncryptedHistoryItem): string;

        function FilterForbiddenChars(const Source, Forbidden: string): string;
        function ShuffleString(const Source: string): string;

        function GenerateUniqueSequence(const FullPool, FirstCharPool: string; Length: Integer): string;
        function GenerateStandardSequence(const FullPool, FirstCharPool: string; Length: Integer): string;

        function HasAnyChar(const Str, Chars: string): Boolean;
        function IsValidForActiveDirectory(const Pwd: string): Boolean;

        procedure AddToHistory(const Password: string; Preset: TPasswordPreset; PassLen: Integer); overload;
        procedure AddToHistoryCustom(const Password, CustomDescription: string; PassLen: Integer; Entropy: Double);

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

        // История возвращает стандартный интерфейсный DTO
        function GetHistory: TArray<TPasswordHistoryItem>;
        procedure ClearHistory;
    end;

implementation

uses
    System.Hash,
    UI.StateLoader,
    CommonHelpers;

function SecureRandom(Max: Integer): Integer;
var
    Buffer: Cardinal;
    UMax: Cardinal;
    Guid: TGUID;
    HashBytes: TBytes;
    Product: UInt64;
begin
    if Max <= 0 then Exit(0);
    UMax := Cardinal(Max);
    repeat
        if not RtlGenRandom(@Buffer, SizeOf(Buffer)) then
        begin
            CreateGUID(Guid);
            HashBytes := THashSHA2.GetHashBytes(Guid.ToString);
            Move(HashBytes[0], Buffer, SizeOf(Buffer));
        end;
        Product := UInt64(Buffer) * UInt64(UMax);
    until Cardinal(Product) >= UMax;
    Result := Integer(Product shr 32);
end;

{ TPasswordService }

// DPAPI: Шифрование RAM
function TPasswordService.ProtectString(const S: string; out OriginalBytes: Integer): TBytes;
var
    RawBytes: TBytes;
    PaddedLen: Integer;
begin
    RawBytes := TEncoding.UTF8.GetBytes(S);
    OriginalBytes := Length(RawBytes);

    PaddedLen := OriginalBytes;
    if (PaddedLen mod CRYPTPROTECTMEMORY_BLOCK_SIZE) <> 0 then
        PaddedLen := PaddedLen + (CRYPTPROTECTMEMORY_BLOCK_SIZE - (PaddedLen mod CRYPTPROTECTMEMORY_BLOCK_SIZE));
    if PaddedLen = 0 then PaddedLen := CRYPTPROTECTMEMORY_BLOCK_SIZE;

    SetLength(Result, PaddedLen);
    FillChar(Result[0], PaddedLen, 0);
    if OriginalBytes > 0 then
        Move(RawBytes[0], Result[0], OriginalBytes);

    if Length(RawBytes) > 0 then
        SecureZeroMemory(@RawBytes[0], Length(RawBytes));

    if Length(Result) > 0 then
        CryptProtectMemory(@Result[0], PaddedLen, CRYPTPROTECTMEMORY_SAME_PROCESS);
end;

function TPasswordService.DecryptHistoryItem(const Item: TEncryptedHistoryItem): string;
var
    TempData: TBytes;
begin
    if Length(Item.EncryptedPassword) = 0 then Exit('');

    SetLength(TempData, Length(Item.EncryptedPassword));
    Move(Item.EncryptedPassword[0], TempData[0], Length(Item.EncryptedPassword));

    CryptUnprotectMemory(@TempData[0], Length(TempData), CRYPTPROTECTMEMORY_SAME_PROCESS);
    Result := TEncoding.UTF8.GetString(TempData, 0, Item.OriginalLen);

    SecureZeroMemory(@TempData[0], Length(TempData));
end;

function TPasswordService.GetHistory: TArray<TPasswordHistoryItem>;
var
    EncryptedItems: TArray<TEncryptedHistoryItem>;
    I: Integer;
begin
    FHistoryLock.Acquire;
    try
        EncryptedItems := FHistory.ToArray;
    finally
        FHistoryLock.Release;
    end;

    // Распаковываем зашифрованные элементы в интерфейсный формат для UI
    SetLength(Result, Length(EncryptedItems));
    for I := 0 to High(EncryptedItems) do
    begin
        Result[I].Password := DecryptHistoryItem(EncryptedItems[I]);
        Result[I].PresetName := EncryptedItems[I].PresetName;
        Result[I].Entropy := EncryptedItems[I].Entropy;
        Result[I].CreatedAt := EncryptedItems[I].CreatedAt;
    end;
end;

function TPasswordService.GetPresetDescription(Preset: TPasswordPreset): string;
begin
    case Preset of
        wpWebStandard:        Result := '[1] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.WebStandard');
        wpActiveDirectory:    Result := '[2] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.ActiveDirectory');
        wpStrictAlphaNumeric: Result := '[3] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.StrictAlphaNumeric');
        wpMacAddress:         Result := '[4] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.MacAddress');
        wpUUIDv4:             Result := '[5] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.UUIDv4');
        wpBase64Key:          Result := '[6] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.Base64Key');
        wpBashSafe:           Result := '[7] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.BashSafe');
        wpDockerEnvSafe:      Result := '[8] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.DockerEnvSafe');
        wpBitrixDb:           Result := '[9] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.BitrixDb');
        wpPinCode:            Result := '[0] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.PinCode');
        wpCustom:             Result := '[C] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.Custom');
        wpHexToken:           Result := '[H] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.HexToken');
        wpUrlSafe:            Result := '[U] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.UrlSafe');
        wpOracleSafe:         Result := '[O] ' + TUIStateLoader.GetMessage('PasswordGenForm.Presets.OracleSafe');
        wpNoLookAlikes:       Result := TUIStateLoader.GetMessage('PasswordGenForm.Presets.NoLookAlikes');
    else
        Result := TUIStateLoader.GetMessage('PasswordGenForm.Presets.Unknown');
    end;
end;

procedure TPasswordService.AddToHistory(const Password: string; Preset: TPasswordPreset; PassLen: Integer);
begin
    AddToHistoryCustom(Password, GetPresetDescription(Preset), PassLen, CalculateEntropy(PassLen, GetPoolSize(Preset)));
end;

procedure TPasswordService.AddToHistoryCustom(const Password, CustomDescription: string; PassLen: Integer; Entropy: Double);
var
    Item: TEncryptedHistoryItem;
begin
    Item.EncryptedPassword := ProtectString(Password, Item.OriginalLen);
    Item.PresetName        := CustomDescription;
    Item.Entropy           := Entropy;
    Item.CreatedAt         := Now;

    FHistoryLock.Acquire;
    try
        FHistory.Add(Item);
    finally
        FHistoryLock.Release;
    end;
end;

function TPasswordService.CalculateEntropy(Length, PoolSize: Integer): Double;
begin
    if (Length <= 0) or (PoolSize <= 0) then Exit(0.0);
    Result := Length * Log2(PoolSize);
end;

function TPasswordService.GetCustomPoolSize(const Settings: TCustomPasswordSettings): Integer;
var
    Pool: string;
    I: Integer;
begin
    Pool := '';
    if Settings.UseLower then Pool   := Pool + ALPHA_LOWER;
    if Settings.UseUpper then Pool   := Pool + ALPHA_UPPER;
    if Settings.UseNumbers then Pool := Pool + NUMBERS;
    if Settings.UseSymbols then Pool := Pool + SYMBOLS_STD;

    for I := 1 to Settings.IncludeChars.Length do
        if Pos(Settings.IncludeChars[I], Pool) = 0 then Pool := Pool + Settings.IncludeChars[I];

    Pool := FilterForbiddenChars(Pool, Settings.ExcludeChars);
    Result := Pool.Length;
end;

function TPasswordService.GetPoolSize(Preset: TPasswordPreset): Integer;
var
    DummyPool: string;
begin
    case Preset of
        wpStrictAlphaNumeric:   DummyPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS;
        wpPinCode:              DummyPool := NUMBERS;
        wpHexToken:             DummyPool := HEX_CHARS;
        wpBashSafe:             DummyPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '@%^&*()-_=+[{]};:,.<>/?';
        wpDockerEnvSafe:        DummyPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS + '_+-@%^&*()[]{}|;:,.<>/?';
        wpUrlSafe:              DummyPool := POOL_URL_SAFE;
        wpBitrixDb:             DummyPool := POOL_BITRIX;
        wpOracleSafe:           DummyPool := POOL_ORACLE;
        wpActiveDirectory:      DummyPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS + SYMBOLS_STD;
        wpNoLookAlikes:         DummyPool := POOL_NO_LOOK_ALIKES;
        wpMacAddress, wpUUIDv4: DummyPool := HEX_CHARS;
        wpBase64Key:            DummyPool := POOL_BASE64;
        wpWebStandard:          DummyPool := POOL_WEB_STD;
    else
        DummyPool := ALPHA_LOWER + ALPHA_UPPER + NUMBERS;
    end;
    Result := Length(DummyPool);
end;

// Генераторы
function TPasswordService.GenerateStandardSequence(const FullPool, FirstCharPool: string; Length: Integer): string;
var I: Integer;
begin
    if Length <= 0 then Exit('');
    SetLength(Result, Length);
    Result[1] := FirstCharPool[SecureRandom(FirstCharPool.Length) + 1];
    for I := 2 to Length do
        Result[I] := FullPool[SecureRandom(FullPool.Length) + 1];
end;

function TPasswordService.GenerateUniqueSequence(const FullPool, FirstCharPool: string; Length: Integer): string;
var
    FirstChar: Char;
    RemainingPool: string;
    I: Integer;
begin
    if Length <= 0 then Exit('');
    SetLength(Result, Length);

    FirstChar := FirstCharPool[SecureRandom(FirstCharPool.Length) + 1];
    Result[1] := FirstChar;

    RemainingPool := FullPool;
    I := Pos(FirstChar, RemainingPool);
    if I > 0 then Delete(RemainingPool, I, 1);
    RemainingPool := ShuffleString(RemainingPool);

    I := 2;
    while (I <= Length) and ((I - 1) <= RemainingPool.Length) do
    begin
        Result[I] := RemainingPool[I - 1];
        Inc(I);
    end;

    while I <= Length do
    begin
        Result[I] := FullPool[SecureRandom(FullPool.Length) + 1];
        Inc(I);
    end;

    if (Length > 2) and (Length > FullPool.Length) then
    begin
        RemainingPool := Copy(Result, 2, Length - 1);
        RemainingPool := ShuffleString(RemainingPool);
        for I := 2 to Length do
            Result[I] := RemainingPool[I - 1];
    end;
end;

function TPasswordService.GenerateUUIDv4: string;
var Guid: TGUID;
begin
  CreateGUID(Guid);
  Result := LowerCase(Copy(GuidToString(Guid), 2, 36));
end;

function TPasswordService.HasAnyChar(const Str, Chars: string): Boolean;
var C: Char;
begin
    Result := False;
    for C in Str do
        if Pos(C, Chars) > 0 then Exit(True);
end;

function TPasswordService.IsValidForActiveDirectory(const Pwd: string): Boolean;
var CategoriesCount: Integer;
begin
    CategoriesCount := 0;
    if HasAnyChar(Pwd, ALPHA_LOWER) then Inc(CategoriesCount);
    if HasAnyChar(Pwd, ALPHA_UPPER) then Inc(CategoriesCount);
    if HasAnyChar(Pwd, NUMBERS) then     Inc(CategoriesCount);
    if HasAnyChar(Pwd, SYMBOLS_STD) then Inc(CategoriesCount);
    Result := CategoriesCount >= 3;
end;

procedure TPasswordService.ClearHistory;
begin
    FHistoryLock.Acquire;
    try
        FHistory.Clear;
    finally
        FHistoryLock.Release;
    end;
end;

constructor TPasswordService.Create;
begin
    inherited Create;
    FHistory := TPasswordHistoryBuffer.Create(MAX_HISTORY_LEN);
    FHistoryLock := TCriticalSection.Create;
end;

destructor TPasswordService.Destroy;
begin
    ClearHistory;
    FHistoryLock.Free;
    FHistory.Free;
    inherited Destroy;
end;

function TPasswordService.FilterForbiddenChars(const Source, Forbidden: string): string;
var C: Char;
begin
    Result := '';
    for C in Source do
        if Pos(C, Forbidden) = 0 then Result := Result + C;
end;

function TPasswordService.ShuffleString(const Source: string): string;
var I, J: Integer; Temp: Char;
begin
    Result := Source;
    if Result.Length <= 1 then Exit;
    for I := Result.Length downto 2 do
    begin
        J := SecureRandom(I) + 1;
        Temp := Result[I];
        Result[I] := Result[J];
        Result[J] := Temp;
    end;
end;

function TPasswordService.GenerateCustomPassword(const Settings: TCustomPasswordSettings; Length: Integer; UniqueChars: Boolean): string;
var
    FullPool: string;
    I, RndIdx, TargetPos: Integer;
    Positions: TList<Integer>;
    SB: TStringBuilder;
begin
    if Length <= 0 then Exit('');

    SB := TStringBuilder.Create;
    try
        if Settings.UseLower then   SB.Append(ALPHA_LOWER);
        if Settings.UseUpper then   SB.Append(ALPHA_UPPER);
        if Settings.UseNumbers then SB.Append(NUMBERS);
        if Settings.UseSymbols then SB.Append(SYMBOLS_STD);
        FullPool := SB.ToString;
    finally
        SB.Free;
    end;

    for I := 1 to Settings.IncludeChars.Length do
        if Pos(Settings.IncludeChars[I], FullPool) = 0 then
            FullPool := FullPool + Settings.IncludeChars[I];

    FullPool := FilterForbiddenChars(FullPool, Settings.ExcludeChars);
    if FullPool.IsEmpty then FullPool := ALPHA_LOWER + NUMBERS;

    if UniqueChars then
        Result := GenerateUniqueSequence(FullPool, FullPool, Length)
    else
        Result := GenerateStandardSequence(FullPool, FullPool, Length);

    if not Settings.IncludeChars.IsEmpty and (Length >= Settings.IncludeChars.Length) then
    begin
        Positions := TList<Integer>.Create;
        try
            for I := 1 to Length do Positions.Add(I);
            for I := 1 to Settings.IncludeChars.Length do
            begin
                RndIdx := SecureRandom(Positions.Count);
                TargetPos := Positions[RndIdx];
                Positions.Delete(RndIdx);
                Result[TargetPos] := Settings.IncludeChars[I];
            end;
        finally
            Positions.Free;
        end;
    end;
end;

function TPasswordService.GenerateMacAddress: string;
const HEX_EVEN = '02468ace'; HEX_ALL = '0123456789abcdef';
var I: Integer;
begin
    Result := HEX_ALL[SecureRandom(16) + 1] + HEX_EVEN[SecureRandom(8) + 1];
    for I := 1 to 5 do Result := Result + ':' + HEX_ALL[SecureRandom(16) + 1] + HEX_ALL[SecureRandom(16) + 1];
end;

function TPasswordService.GeneratePassword(Preset: TPasswordPreset; Length: Integer; UniqueChars: Boolean): string;
var FullPool, FirstCharPool: string;
begin
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

    if FirstCharPool.IsEmpty then FirstCharPool := FullPool;

    if UniqueChars then
        Result := GenerateUniqueSequence(FullPool, FirstCharPool, Length)
    else
    begin
        if Preset = wpActiveDirectory then
            repeat Result := GenerateStandardSequence(FullPool, FirstCharPool, Length); until IsValidForActiveDirectory(Result)
        else
            Result := GenerateStandardSequence(FullPool, FirstCharPool, Length);
    end;
end;

{ TPasswordHistoryBuffer }

procedure TPasswordHistoryBuffer.Add(const Item: TEncryptedHistoryItem);
begin
    FItems[FHead] := Item;
    FHead := (FHead + 1) mod FCapacity;
    if FCount < FCapacity then Inc(FCount);
end;

procedure TPasswordHistoryBuffer.Clear;
var
    I: Integer;
begin
    for I := 0 to High(FItems) do
    begin
        if Length(FItems[I].EncryptedPassword) > 0 then
            SecureZeroMemory(@FItems[I].EncryptedPassword[0], Length(FItems[I].EncryptedPassword));

        SetLength(FItems[I].EncryptedPassword, 0);
        FItems[I].OriginalLen := 0;
        FItems[I].PresetName := '';
        FItems[I].Entropy := 0;
    end;
    FHead := 0;
    FCount := 0;
end;

constructor TPasswordHistoryBuffer.Create(ACapacity: Integer);
begin
    FCapacity := ACapacity;
    SetLength(FItems, FCapacity);
    Clear;
end;

function TPasswordHistoryBuffer.ToArray: TArray<TEncryptedHistoryItem>;
var
    I, Idx: Integer;
begin
    SetLength(Result, FCount);
    for I := 0 to FCount - 1 do
    begin
        Idx := FHead - 1 - I;
        if Idx < 0 then Inc(Idx, FCapacity);
        Result[I] := FItems[Idx];
    end;
end;

initialization
    Randomize;

end.
