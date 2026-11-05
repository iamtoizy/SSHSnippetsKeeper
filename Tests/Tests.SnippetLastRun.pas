unit Tests.SnippetLastRun;

interface

uses
    DUnitX.TestFramework,
    FireDAC.Comp.Client,
    System.Generics.Collections,
    Core.Interfaces.Services
    ;

type
    [TestFixture]
    TSnippetLastRunTests = class(TObject)
    private
        FConn: TFDConnection;
        function SchemaPath(const Filename: string): string;
        procedure ExecScript(const Filenames: array of string);
        function AddCategoryRaw(const Name: string; UserID: Integer = 1): Integer;
        function MakeService: ISnippetService;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;
        [Test]
        procedure Batch_AfterRecordRun_ReturnsTimestamp;
        [Test]
        procedure Batch_UnknownIDs_MissingFromMap;
        [Test]
        procedure Batch_EmptyInput_ReturnsNil;
    end;

implementation

uses
    System.SysUtils,
    System.DateUtils,
    System.IOUtils,
    SnippetService,
    SnippetRepository,
    CategoryRepository,
    TagRepository,
    UserRepository,
    Core.Entities.Snippet,
    FireDAC.Comp.Script,
    FireDAC.Comp.ScriptCommands,
    FireDAC.Phys.SQLite,
    FireDAC.Phys.SQLiteWrapper.Stat,
    FireDAC.Stan.Def,
    FireDAC.Stan.Async,
    FireDAC.Stan.ExprFuncs,
    FireDAC.Stan.Error,
    FireDAC.ConsoleUI.Wait,
    FireDAC.Phys.SQLiteWrapper
    ;

function TSnippetLastRunTests.SchemaPath(const Filename: string): string;
var
    Dir: string;
begin
    Dir := TPath.GetDirectoryName(ParamStr(0));
    repeat
        Result := TPath.Combine(Dir, TPath.Combine('Database', TPath.Combine('Schema', Filename)));
        if TFile.Exists(Result) then
            Exit;
        Dir := TPath.GetDirectoryName(Dir);
    until Dir = '';
    raise Exception.Create('Schema file not found: ' + Result);
end;

procedure TSnippetLastRunTests.ExecScript(const Filenames: array of string);
var
    Script: TFDScript;
    SQL, Path: string;
    I: Integer;
begin
    SQL := '';
    for I := Low(Filenames) to High(Filenames) do
    begin
        Path := SchemaPath(Filenames[I]);
        if SQL <> '' then
            SQL := SQL + sLineBreak;
        SQL := SQL + TFile.ReadAllText(Path, TEncoding.UTF8);
    end;
    Script := TFDScript.Create(nil);
    try
        Script.Connection := FConn;
        Script.SQLScripts.Add.SQL.Text := SQL;
        Script.ExecuteAll;
    finally
        Script.Free;
    end;
end;

procedure TSnippetLastRunTests.Setup;
begin
    FConn := TFDConnection.Create(nil);
    FConn.Params.Add('DriverID=SQLite');
    FConn.Params.Add('Database=:memory:');
    FConn.Connected := True;
    FConn.ExecSQL('PRAGMA foreign_keys = ON');
    ExecScript(['000_schema_init.sql']);
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'')');
end;

procedure TSnippetLastRunTests.TearDown;
begin
    FreeAndNil(FConn);
end;

function TSnippetLastRunTests.AddCategoryRaw(const Name: string; UserID: Integer): Integer;
begin
    FConn.ExecSQL('INSERT INTO snippet_categories (user_id, name, parent_id, sort_order) VALUES (?, ?, NULL, 0)',
        [UserID, Name]);
    Result := FConn.ExecSQLScalar('SELECT last_insert_rowid()');
end;

function TSnippetLastRunTests.MakeService: ISnippetService;
begin
    Result := TSnippetService.Create(
        TSnippetRepository.Create(FConn),
        TCategoryRepository.Create(FConn),
        TTagRepository.Create(FConn),
        TUserRepository.Create(FConn));
end;

procedure TSnippetLastRunTests.Batch_AfterRecordRun_ReturnsTimestamp;
var
    Svc: ISnippetService;
    Snip: TSnippetDTO;
    CatID, SnipID: Integer;
    Map: TDictionary<Integer, Int64>;
begin
    CatID := AddCategoryRaw('w');
    Svc := MakeService;

    Snip := Default(TSnippetDTO);
    Snip.UserID := 1;
    Snip.Title := 'runme';
    Snip.Content := 'echo hi';
    Snip.CategoryID := CatID;
    SnipID := Svc.CreateSnippet(Snip, []);

    Svc.RecordRun(SnipID, 1);

    Map := Svc.GetLastRunBatch([SnipID]);
    try
        Assert.IsNotNull(Map);
        Assert.IsTrue(Map.ContainsKey(SnipID));
        Assert.IsTrue(Map[SnipID] > 0);
    finally
        Map.Free;
    end;
end;

procedure TSnippetLastRunTests.Batch_UnknownIDs_MissingFromMap;
var
    Svc: ISnippetService;
    Map: TDictionary<Integer, Int64>;
begin
    Svc := MakeService;

    // Сниппет без запусков и несуществующий ID в карту не попадают
    Map := Svc.GetLastRunBatch([123456, 999999]);
    try
        Assert.IsNotNull(Map);
        Assert.IsFalse(Map.ContainsKey(123456));
        Assert.IsFalse(Map.ContainsKey(999999));
    finally
        Map.Free;
    end;
end;

procedure TSnippetLastRunTests.Batch_EmptyInput_ReturnsNil;
var
    Svc: ISnippetService;
    Map: TDictionary<Integer, Int64>;
begin
    Svc := MakeService;
    Map := Svc.GetLastRunBatch([]);
    try
        Assert.IsFalse(Assigned(Map));
    finally
        Map.Free;
    end;
end;

end.
