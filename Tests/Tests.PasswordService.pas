unit Tests.PasswordService;

interface

uses
    DUnitX.TestFramework,
    Core.Interfaces.Passwords,
    PasswordService
    ;

type
    [TestFixture]
    TPasswordServiceTests = class(TObject)
    private
        function NewService: TPasswordService;
        function AllCharsIn(const S, Allowed: string): Boolean;
        function CategoriesCount(const Pwd: string): Integer;
        function HasDuplicates(const S: string): Boolean;
    public
        [Test]
        procedure PinCode_DigitsOnly;
        [Test]
        procedure HexToken_LowercaseHex;
        [Test]
        procedure MacAddress_Format;
        [Test]
        procedure UUIDv4_Format;
        [Test]
        procedure ActiveDirectory_Min3Categories;
        [Test]
        procedure UniqueChars_NoDuplicates;
        [Test]
        procedure Entropy_Formula;
        [Test]
        procedure PoolSizes;
        [Test]
        procedure Custom_ExcludeChars;
        [Test]
        procedure Custom_IncludeCharsPresent;
        [Test]
        procedure History_TracksAndClears;
    end;

implementation

uses
    System.Character,
    System.Math,
    System.SysUtils
    ;

{ TPasswordServiceTests }

function TPasswordServiceTests.NewService: TPasswordService;
begin
    Result := TPasswordService.Create;
end;

function TPasswordServiceTests.AllCharsIn(const S, Allowed: string): Boolean;
var
    C: Char;
begin
    Result := True;
    for C in S do
        if Pos(C, Allowed) = 0 then
            Exit(False);
end;

function TPasswordServiceTests.CategoriesCount(const Pwd: string): Integer;
const
    SYMBOLS = '!@#$%^&*()-_=+[{]};:,.<>/?';
var
    C: Char;
    HasLower, HasUpper, HasDigit, HasSymbol: Boolean;
begin
    HasLower := False;
    HasUpper := False;
    HasDigit := False;
    HasSymbol := False;
    for C in Pwd do
    begin
        if C.IsLower then HasLower := True
        else if C.IsUpper then HasUpper := True
        else if C.IsDigit then HasDigit := True
        else if Pos(C, SYMBOLS) > 0 then HasSymbol := True;
    end;
    Result := Ord(HasLower) + Ord(HasUpper) + Ord(HasDigit) + Ord(HasSymbol);
end;

function TPasswordServiceTests.HasDuplicates(const S: string): Boolean;
var
    I, J: Integer;
begin
    Result := False;
    for I := 1 to Length(S) - 1 do
        for J := I + 1 to Length(S) do
            if S[I] = S[J] then
                Exit(True);
end;

procedure TPasswordServiceTests.PinCode_DigitsOnly;
var
    Svc: TPasswordService;
    Pwd: string;
begin
    Svc := NewService;
    try
        Pwd := Svc.GeneratePassword(wpPinCode, 6, False);
        Assert.AreEqual(6, Length(Pwd));
        Assert.IsTrue(AllCharsIn(Pwd, '0123456789'));
    finally
        Svc.Free;
    end;
end;

procedure TPasswordServiceTests.HexToken_LowercaseHex;
var
    Svc: TPasswordService;
    Pwd: string;
begin
    Svc := NewService;
    try
        Pwd := Svc.GeneratePassword(wpHexToken, 32, False);
        Assert.AreEqual(32, Length(Pwd));
        Assert.IsTrue(AllCharsIn(Pwd, 'abcdef0123456789'));
    finally
        Svc.Free;
    end;
end;

procedure TPasswordServiceTests.MacAddress_Format;
var
    Svc: TPasswordService;
    Pwd: string;
begin
    Svc := NewService;
    try
        Pwd := Svc.GeneratePassword(wpMacAddress, 0, False);
        Assert.AreEqual(17, Length(Pwd));
        Assert.IsTrue(AllCharsIn(Pwd, '0123456789abcdef:'));
        Assert.AreEqual(':', string(Pwd[3]));
        Assert.AreEqual(':', string(Pwd[6]));
        Assert.AreEqual(':', string(Pwd[9]));
        Assert.AreEqual(':', string(Pwd[12]));
        Assert.AreEqual(':', string(Pwd[15]));
        Assert.IsTrue(Pos(Pwd[2], '02468ace') > 0);
    finally
        Svc.Free;
    end;
end;

procedure TPasswordServiceTests.UUIDv4_Format;
var
    Svc: TPasswordService;
    Pwd: string;
begin
    Svc := NewService;
    try
        Pwd := Svc.GeneratePassword(wpUUIDv4, 0, False);
        Assert.AreEqual(36, Length(Pwd));
        Assert.IsTrue(AllCharsIn(Pwd, '0123456789abcdef-'));
        Assert.AreEqual('-', string(Pwd[9]));
        Assert.AreEqual('-', string(Pwd[14]));
        Assert.AreEqual('-', string(Pwd[19]));
        Assert.AreEqual('-', string(Pwd[24]));
        Assert.AreEqual('4', string(Pwd[15]));
    finally
        Svc.Free;
    end;
end;

procedure TPasswordServiceTests.ActiveDirectory_Min3Categories;
var
    Svc: TPasswordService;
    Pwd: string;
begin
    Svc := NewService;
    try
        Pwd := Svc.GeneratePassword(wpActiveDirectory, 16, False);
        Assert.AreEqual(16, Length(Pwd));
        Assert.IsTrue(CategoriesCount(Pwd) >= 3);
    finally
        Svc.Free;
    end;
end;

procedure TPasswordServiceTests.UniqueChars_NoDuplicates;
var
    Svc: TPasswordService;
    Pwd: string;
begin
    Svc := NewService;
    try
        Pwd := Svc.GeneratePassword(wpStrictAlphaNumeric, 40, True);
        Assert.AreEqual(40, Length(Pwd));
        Assert.IsFalse(HasDuplicates(Pwd));
    finally
        Svc.Free;
    end;
end;

procedure TPasswordServiceTests.Entropy_Formula;
var
    Svc: TPasswordService;
begin
    Svc := NewService;
    try
        Assert.IsTrue(Abs(Svc.CalculateEntropy(8, 62) - 8 * Log2(62)) < 1e-9);
        Assert.AreEqual(Double(0), Svc.CalculateEntropy(0, 62));
        Assert.AreEqual(Double(0), Svc.CalculateEntropy(8, 0));
    finally
        Svc.Free;
    end;
end;

procedure TPasswordServiceTests.PoolSizes;
var
    Svc: TPasswordService;
begin
    Svc := NewService;
    try
        Assert.AreEqual(10, Svc.GetPoolSize(wpPinCode));
        Assert.AreEqual(16, Svc.GetPoolSize(wpHexToken));
        Assert.AreEqual(62, Svc.GetPoolSize(wpStrictAlphaNumeric));
        Assert.AreEqual(64, Svc.GetPoolSize(wpBase64Key));
        Assert.AreEqual(69, Svc.GetPoolSize(wpWebStandard));
    finally
        Svc.Free;
    end;
end;

procedure TPasswordServiceTests.Custom_ExcludeChars;
var
    Svc: TPasswordService;
    Settings: TCustomPasswordSettings;
    Pwd: string;
begin
    Svc := NewService;
    try
        Settings := Default(TCustomPasswordSettings);
        Settings.UseNumbers := True;
        Settings.ExcludeChars := '019';
        Pwd := Svc.GenerateCustomPassword(Settings, 12, False);
        Assert.AreEqual(12, Length(Pwd));
        Assert.IsTrue(AllCharsIn(Pwd, '2345678'));
    finally
        Svc.Free;
    end;
end;

procedure TPasswordServiceTests.Custom_IncludeCharsPresent;
var
    Svc: TPasswordService;
    Settings: TCustomPasswordSettings;
    Pwd: string;
begin
    Svc := NewService;
    try
        Settings := Default(TCustomPasswordSettings);
        Settings.UseNumbers := True;
        Settings.IncludeChars := 'X';
        Pwd := Svc.GenerateCustomPassword(Settings, 10, False);
        Assert.AreEqual(10, Length(Pwd));
        Assert.IsTrue(Pos('X', Pwd) > 0);
    finally
        Svc.Free;
    end;
end;

procedure TPasswordServiceTests.History_TracksAndClears;
var
    Svc: IPasswordService;
begin
    Svc := TPasswordService.Create;
    Svc.AddToHistory('secret1', wpPinCode, 8);
    Svc.AddToHistory('secret2', wpHexToken, 16);
    Svc.AddToHistory('secret3', wpStrictAlphaNumeric, 12);
    Assert.AreEqual(3, Integer(Length(Svc.GetHistory)));
    Svc.ClearHistory;
    Assert.AreEqual(0, Integer(Length(Svc.GetHistory)));
end;

end.
