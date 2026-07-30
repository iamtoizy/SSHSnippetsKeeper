unit ChmodService;

interface

uses
    System.SysUtils,
    System.StrUtils,
    System.RegularExpressions;

type
    // Битовая маска для прав (12 бит)
    TChmodBits = set of 0..11;

    TChmodService = class
    public
        // Константы битов (для удобства читаемости)
        const
            BIT_O_X = 0; BIT_O_W = 1; BIT_O_R = 2; // Other (Public)
            BIT_G_X = 3; BIT_G_W = 4; BIT_G_R = 5; // Group
            BIT_U_X = 6; BIT_U_W = 7; BIT_U_R = 8; // User (Owner)
            BIT_STICKY = 9; BIT_SGID = 10; BIT_SUID = 11; // Special

        // Из набора битов в строку (напр. "0755" или "755")
        class function BitsToOctal(const Bits: TChmodBits): string;

        // Из восьмеричной строки в набор битов
        class function OctalToBits(const OctalStr: string): TChmodBits;

        // Из набора битов в символьную строку (напр. "rwxr-xr-x")
        class function BitsToSymbolic(const Bits: TChmodBits; IsDirectory: Boolean): string;

        // Из символьной строки в набор битов
        class function SymbolicToBits(const SymbolicStr: string): TChmodBits;

        // Генерация готовой bash команды
        class function BuildCommand(
            const OctalBits, User, Group, FileName: string;
            IsDir, IsRecursive, IsSudo, IsSmartX, IsSeparateMode: Boolean): string;
    end;

implementation

{ TChmodService }

class function TChmodService.BitsToOctal(const Bits: TChmodBits): string;
var
    Special, User, Group, Other: Integer;
begin
    Special := 0; User := 0; Group := 0; Other := 0;

    if BIT_SUID in Bits then Special := Special + 4;
    if BIT_SGID in Bits then Special := Special + 2;
    if BIT_STICKY in Bits then Special := Special + 1;

    if BIT_U_R in Bits then User := User + 4;
    if BIT_U_W in Bits then User := User + 2;
    if BIT_U_X in Bits then User := User + 1;

    if BIT_G_R in Bits then Group := Group + 4;
    if BIT_G_W in Bits then Group := Group + 2;
    if BIT_G_X in Bits then Group := Group + 1;

    if BIT_O_R in Bits then Other := Other + 4;
    if BIT_O_W in Bits then Other := Other + 2;
    if BIT_O_X in Bits then Other := Other + 1;

    if Special > 0 then
        Result := Format('%d%d%d%d', [Special, User, Group, Other])
    else
        Result := Format('0%d%d%d', [User, Group, Other]); // Стандартный префикс 0
end;

class function TChmodService.BitsToSymbolic(const Bits: TChmodBits; IsDirectory: Boolean): string;
var
    S: string;
begin
    S := '----------';
    if IsDirectory then S[1] := 'd';

    // User
    if BIT_U_R in Bits then S[2] := 'r';
    if BIT_U_W in Bits then S[3] := 'w';
    if BIT_U_X in Bits then S[4] := 'x';

    if BIT_SUID in Bits then
    begin
        if BIT_U_X in Bits then S[4] := 's' else S[4] := 'S';
    end;

    // Group
    if BIT_G_R in Bits then S[5] := 'r';
    if BIT_G_W in Bits then S[6] := 'w';
    if BIT_G_X in Bits then S[7] := 'x';

    if BIT_SGID in Bits then
    begin
        if BIT_G_X in Bits then S[7] := 's' else S[7] := 'S';
    end;

    // Other
    if BIT_O_R in Bits then S[8] := 'r';
    if BIT_O_W in Bits then S[9] := 'w';
    if BIT_O_X in Bits then S[10] := 'x';

    if BIT_STICKY in Bits then
    begin
        if BIT_O_X in Bits then S[10] := 't' else S[10] := 'T';
    end;

    Result := S;
end;

class function TChmodService.OctalToBits(const OctalStr: string): TChmodBits;
var
    CleanStr: string;
begin
    Result := [];
    CleanStr := OctalStr.Trim;
    if CleanStr.StartsWith('0') and (Length(CleanStr) > 1) then
        CleanStr := CleanStr.Substring(1); // Убираем префикс '0'

    // В реальности правильнее парсить восьмеричное
    // Напишем строгий парсер справа налево
    var Len := Length(CleanStr);
    if Len > 0 then
    begin
        var O := StrToIntDef(CleanStr[Len], 0);
        if (O and 1) <> 0 then Include(Result, BIT_O_X);
        if (O and 2) <> 0 then Include(Result, BIT_O_W);
        if (O and 4) <> 0 then Include(Result, BIT_O_R);
    end;
    if Len > 1 then
    begin
        var G := StrToIntDef(CleanStr[Len-1], 0);
        if (G and 1) <> 0 then Include(Result, BIT_G_X);
        if (G and 2) <> 0 then Include(Result, BIT_G_W);
        if (G and 4) <> 0 then Include(Result, BIT_G_R);
    end;
    if Len > 2 then
    begin
        var U := StrToIntDef(CleanStr[Len-2], 0);
        if (U and 1) <> 0 then Include(Result, BIT_U_X);
        if (U and 2) <> 0 then Include(Result, BIT_U_W);
        if (U and 4) <> 0 then Include(Result, BIT_U_R);
    end;
    if Len > 3 then
    begin
        var S := StrToIntDef(CleanStr[Len-3], 0);
        if (S and 1) <> 0 then Include(Result, BIT_STICKY);
        if (S and 2) <> 0 then Include(Result, BIT_SGID);
        if (S and 4) <> 0 then Include(Result, BIT_SUID);
    end;
end;

class function TChmodService.SymbolicToBits(const SymbolicStr: string): TChmodBits;
var
    S: string;
begin
    Result := [];
    S := SymbolicStr.Trim;
    if S.Length < 9 then Exit;

    // Игнорируем первый символ (d/-), берем последние 9
    S := S.Substring(S.Length - 9);

    if S[1] = 'r' then Include(Result, BIT_U_R);
    if S[2] = 'w' then Include(Result, BIT_U_W);
    if CharInSet(S[3], ['x', 's']) then Include(Result, BIT_U_X);
    if CharInSet(S[3], ['s', 'S']) then Include(Result, BIT_SUID);

    if S[4] = 'r' then Include(Result, BIT_G_R);
    if S[5] = 'w' then Include(Result, BIT_G_W);
    if CharInSet(S[6], ['x', 's']) then Include(Result, BIT_G_X);
    if CharInSet(S[6], ['s', 'S']) then Include(Result, BIT_SGID);

    if S[7] = 'r' then Include(Result, BIT_O_R);
    if S[8] = 'w' then Include(Result, BIT_O_W);
    if CharInSet(S[9], ['x', 't']) then Include(Result, BIT_O_X);
    if CharInSet(S[9], ['t', 'T']) then Include(Result, BIT_STICKY);
end;

class function TChmodService.BuildCommand(
    const OctalBits, User, Group, FileName: string;
    IsDir, IsRecursive, IsSudo, IsSmartX, IsSeparateMode: Boolean): string;
var
    CmdMode, CmdOwner, TargetPath: string;
    Prefix: string;
    SmartXStr: string;
begin
    if FileName.Trim = '' then
        TargetPath := '<target>'
    else
        TargetPath := FileName.Trim;

    Prefix := '';
    if IsSudo then
        Prefix := 'sudo ';

    // 1. Формируем команду chown (если указан владелец или группа)
    CmdOwner := '';
    if (User.Trim <> '') or (Group.Trim <> '') then
    begin
        CmdOwner := User.Trim;
        if Group.Trim <> '' then
            CmdOwner := CmdOwner + ':' + Group.Trim;

        CmdOwner := Prefix + 'chown ';
        if IsRecursive then
            CmdOwner := CmdOwner + '-R ';

        CmdOwner := CmdOwner + User.Trim;
        if Group.Trim <> '' then
            CmdOwner := CmdOwner + ':' + Group.Trim;

        CmdOwner := CmdOwner + ' ' + TargetPath;
    end;

    // 2. Формируем команду chmod
    CmdMode := '';

    // Сценарий 1: Раздельный режим для вебмастеров (через find)
    if IsSeparateMode and IsRecursive then
    begin
        // В раздельном режиме мы жестко зашиваем классику: Папки 755, Файлы 644
        // (Или можно брать OctalBits для файлов, а для папок генерировать отдельно,
        // но обычно вебмастерам нужна именно эта пара)
        CmdMode := Prefix + 'find ' + TargetPath + ' -type d -exec chmod 755 {} \;' + ' && ' +
                   Prefix + 'find ' + TargetPath + ' -type f -exec chmod 644 {} \;';
    end
    // Сценарий 2: Умный X (+X)
    else if IsSmartX and IsRecursive then
    begin
        SmartXStr := 'a+X'; // Базовое право на вход в директории

        // Читаем с конца, чтобы не зависеть от того, есть ли ведущий ноль (0755) или нет (755)
        var Len := Length(OctalBits);
        if Len >= 3 then
        begin
            // Права владельца (User)
            if CharInSet(OctalBits[Len-2], ['6', '7']) then SmartXStr := SmartXStr + ',u+rw'
            else SmartXStr := SmartXStr + ',u+r';

            // Права группы (Group)
            if CharInSet(OctalBits[Len-1], ['6', '7']) then SmartXStr := SmartXStr + ',g+rw'
            else if CharInSet(OctalBits[Len-1], ['4', '5']) then SmartXStr := SmartXStr + ',g+r';

            // Публичные права (Other)
            if CharInSet(OctalBits[Len],   ['6', '7']) then SmartXStr := SmartXStr + ',o+rw'
            else if CharInSet(OctalBits[Len],   ['4', '5']) then SmartXStr := SmartXStr + ',o+r';
        end;

        CmdMode := Prefix + 'chmod -R ' + SmartXStr + ' ' + TargetPath;
    end
    // Сценарий 3: Классический chmod
    else
    begin
        CmdMode := Prefix + 'chmod ';
        if IsRecursive then
            CmdMode := CmdMode + '-R ';
        CmdMode := CmdMode + OctalBits + ' ' + TargetPath;
    end;

    // 3. Склеиваем результат
    if (CmdOwner <> '') and (CmdMode <> '') then
        Result := CmdOwner + ' && ' + CmdMode
    else if CmdOwner <> '' then
        Result := CmdOwner
    else if CmdMode <> '' then
        Result := CmdMode
    else
        Result := '';
end;

end.
