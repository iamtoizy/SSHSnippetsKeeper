unit NetworkCalcService;

interface

uses
    System.SysUtils,
    System.Math,
    System.StrUtils,
    System.Classes;

type
    // Типы сетей
    TIPNetworkType = (ntPublic, ntPrivate, ntLoopback, ntLinkLocal, ntMulticast, ntBroadcast);

    TIPv4Network = record
    private
        FIP: Cardinal;
        FMaskBits: Byte;
        function GetNetmask: Cardinal;
        function GetNetwork: Cardinal;
        function GetBroadcast: Cardinal;
        function GetWildcard: Cardinal;
    public
        constructor Create(const AIP: string; AMaskBits: Byte); overload;
        constructor Create(const ACIDRString: string); overload; // Формат '192.168.1.1/24'
        constructor Create(AIP: Cardinal; AMaskBits: Byte); overload;

        property IP: Cardinal read FIP;
        property MaskBits: Byte read FMaskBits;

        property Netmask: Cardinal read GetNetmask;
        property Network: Cardinal read GetNetwork;
        property Broadcast: Cardinal read GetBroadcast;
        property Wildcard: Cardinal read GetWildcard;

        function HostsCount: UInt64; // UInt64 на случай /0 (весь интернет)
        function FirstHost: Cardinal;
        function LastHost: Cardinal;

        function GetNetworkType: TIPNetworkType;

        // Вспомогательные методы
        class function IPToStr(AIP: Cardinal): string; static;
        class function StrToIP(const S: string): Cardinal; overload; static;
        class function ToBinaryStr(AIP: Cardinal; AMaskBits: Byte = 0): string; static;

        // Методы, чтобы калькулятор понимал варианты ввода вроде:
        // 192.168.1.50 255.255.255.0, 192.168.1.50/24 или 192.168.1.50 24,
        // а также строго проверял диапазоны октетов (чтобы 192.168.300.1 не считался валидным)
        class function StrToIP(const S: string; out IP: Cardinal): Boolean; overload; static;
        class function NetmaskToBits(const MaskStr: string): Byte; static;
        class function TryParseInput(const Input: string; DefaultMask: Byte; out IP: Cardinal; out MaskBits: Byte): Boolean; static;
    end;

implementation

{ TIPv4Network }

constructor TIPv4Network.Create(const AIP: string; AMaskBits: Byte);
begin
    FIP := StrToIP(AIP);
    FMaskBits := EnsureRange(AMaskBits, 0, 32);
end;

constructor TIPv4Network.Create(const ACIDRString: string);
var
    Parts: TArray<string>;
begin
    Parts := ACIDRString.Trim.Split(['/']);
    FIP := StrToIP(Parts[0]);

    if Length(Parts) > 1 then
        FMaskBits := EnsureRange(StrToIntDef(Parts[1], 32), 0, 32)
    else
        FMaskBits := 32; // По умолчанию 1 хост
end;

class function TIPv4Network.StrToIP(const S: string): Cardinal;
var
    Octets: TArray<string>;
    I: Integer;
begin
    Result := 0;
    Octets := S.Split(['.']);
    if Length(Octets) <> 4 then
        Exit; // Возвращаем 0 при ошибке (в приложении можно бросить Exception)

    for I := 0 to 3 do
        Result := Result or (Cardinal(StrToIntDef(Octets[I], 0)) shl ((3 - I) * 8));
end;

class function TIPv4Network.IPToStr(AIP: Cardinal): string;
begin
    Result := Format('%d.%d.%d.%d', [(AIP shr 24) and $FF, (AIP shr 16) and $FF, (AIP shr 8) and $FF, AIP and $FF]);
end;

function TIPv4Network.GetNetmask: Cardinal;
begin
    if FMaskBits = 0 then
        Result := 0
    else
        // Сдвигаем единицы влево. Например для /24 это будет 32-24 = 8 нулей справа
        Result := $FFFFFFFF shl (32 - FMaskBits);
end;

function TIPv4Network.GetWildcard: Cardinal;
begin
    Result := not GetNetmask;
end;

function TIPv4Network.GetNetwork: Cardinal;
begin
    Result := FIP and GetNetmask;
end;

function TIPv4Network.GetBroadcast: Cardinal;
begin
    Result := GetNetwork or GetWildcard;
end;

constructor TIPv4Network.Create(AIP: Cardinal; AMaskBits: Byte);
begin
    FIP := AIP;
    FMaskBits := EnsureRange(AMaskBits, 0, 32);
end;

function TIPv4Network.FirstHost: Cardinal;
begin
    if FMaskBits >= 31 then // Для /31 и /32 нет Broadcast и Network
        Result := GetNetwork
    else
        Result := GetNetwork + 1;
end;

function TIPv4Network.LastHost: Cardinal;
begin
    if FMaskBits >= 31 then
        Result := GetBroadcast
    else
        Result := GetBroadcast - 1;
end;

class function TIPv4Network.NetmaskToBits(const MaskStr: string): Byte;
var
    MaskIP, ExpectedMask: Cardinal;
    Bits: Byte;
begin
    Result := 32;
    if not StrToIP(MaskStr, MaskIP) then
        Exit;

    Bits := 0;
    while (Bits < 32) and (((MaskIP shr (31 - Bits)) and 1) = 1) do
        Inc(Bits);

    // Строгая проверка: формируем идеальную маску из полученных бит
    ExpectedMask := 0;
    if Bits > 0 then
        ExpectedMask := $FFFFFFFF shl (32 - Bits);

    // Если идеальная маска не совпадает с тем, что ввели (например, 255.255.0.255),
    // значит маска некорректная. Возвращаем 0.
    if MaskIP <> ExpectedMask then
        Exit(0);

    Result := EnsureRange(Bits, 0, 32);
end;

class function TIPv4Network.StrToIP(const S: string; out IP: Cardinal): Boolean;
var
    Octets: TArray<string>;
    I, Val: Integer;
begin
    IP := 0;
    Result := False;

    Octets := S.Trim.Split(['.']);
    if Length(Octets) <> 4 then
        Exit;

    for I := 0 to 3 do
    begin
        if not TryStrToInt(Octets[I], Val) then
            Exit;
        // Октет должен быть строго в диапазоне от 0 до 255
        if (Val < 0) or (Val > 255) then
            Exit;

        IP := IP or (Cardinal(Val) shl ((3 - I) * 8));
    end;

    Result := True;
end;

function TIPv4Network.HostsCount: UInt64;
begin
    if FMaskBits = 32 then
        Exit(1);
    if FMaskBits = 31 then
        Exit(2); // RFC 3021 (Point-to-Point)

    // (2 ^ (32 - MaskBits)) - 2
    Result := (UInt64(1) shl (32 - FMaskBits)) - 2;
end;

function TIPv4Network.GetNetworkType: TIPNetworkType;
var
    Oct1, Oct2: Byte;
begin
    Oct1 := (FIP shr 24) and $FF;
    Oct2 := (FIP shr 16) and $FF;

    if FIP = $FFFFFFFF then
        Exit(ntBroadcast);
    if (Oct1 >= 224) and (Oct1 <= 239) then
        Exit(ntMulticast);
    if Oct1 = 127 then
        Exit(ntLoopback);
    if (Oct1 = 169) and (Oct2 = 254) then
        Exit(ntLinkLocal); // APIPA

    // Private Networks (RFC 1918)
    if (Oct1 = 10) or ((Oct1 = 172) and (Oct2 >= 16) and (Oct2 <= 31)) or ((Oct1 = 192) and (Oct2 = 168)) then
        Exit(ntPrivate);

    Result := ntPublic;
end;

class function TIPv4Network.ToBinaryStr(AIP: Cardinal; AMaskBits: Byte): string;
var
    I: Integer;
    Bit: Cardinal;
begin
    Result := '';
    for I := 31 downto 0 do
    begin
        Bit := (AIP shr I) and 1;
        Result := Result + IntToStr(Bit);

        // Добавляем точку каждые 8 бит
        if (I mod 8 = 0) and (I > 0) then
            Result := Result + '.';

        // Можно добавить визуальный разделитель (например '|') где заканчивается маска
        if (32 - I) = AMaskBits then
            Result := Result + '|';
    end;
end;

class function TIPv4Network.TryParseInput(const Input: string; DefaultMask: Byte; out IP: Cardinal; out MaskBits: Byte): Boolean;
var
    CleanInput, IPPart, MaskPart: string;
    Parts: TArray<string>;
    ParsedBits: Integer;
begin
    Result := False;
    IP := 0;
    MaskBits := EnsureRange(DefaultMask, 0, 32);

    CleanInput := Input.Trim;
    if CleanInput = '' then
        Exit;

    // Формат CIDR со слешем (192.168.1.1/24 или 192.168.1.1/255.255.255.0)
    if CleanInput.Contains('/') then
    begin
        Parts := CleanInput.Split(['/']);
        IPPart := Parts[0].Trim;
        MaskPart := Parts[1].Trim;

        if not StrToIP(IPPart, IP) then
            Exit;

        if MaskPart.Contains('.') then
            MaskBits := NetmaskToBits(MaskPart)
        else if TryStrToInt(MaskPart, ParsedBits) then
            MaskBits := EnsureRange(ParsedBits, 0, 32)
        else
            Exit;

        Exit(True);
    end;

    // Формат с пробелом (192.168.1.1 255.255.255.0 или 192.168.1.1 24)
    if CleanInput.Contains(' ') then
    begin
        // Заменяем множественные пробелы на один
        while CleanInput.Contains('  ') do
            CleanInput := StringReplace(CleanInput, '  ', ' ', [rfReplaceAll]);

        Parts := CleanInput.Split([' ']);
        if Length(Parts) >= 2 then
        begin
            IPPart := Parts[0].Trim;
            MaskPart := Parts[1].Trim;

            if not StrToIP(IPPart, IP) then
                Exit;

            if MaskPart.Contains('.') then
                MaskBits := NetmaskToBits(MaskPart)
            else if TryStrToInt(MaskPart, ParsedBits) then
                MaskBits := EnsureRange(ParsedBits, 0, 32)
            else
                Exit;

            Exit(True);
        end;
    end;

    // Только IP-адрес без маски
    if StrToIP(CleanInput, IP) then
    begin
        MaskBits := EnsureRange(DefaultMask, 0, 32);
        Exit(True);
    end;
end;

end.

