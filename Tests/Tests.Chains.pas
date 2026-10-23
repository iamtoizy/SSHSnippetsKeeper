unit Tests.Chains;

interface

uses
    DUnitX.TestFramework,
    FireDAC.Comp.Client,
    ChainRepository,
    Core.Entities.Chain
    ;

type
    [TestFixture]
    TChainsTests = class(TObject)
    private
        FConn: TFDConnection;
        FRepo: TChainRepository;
        function SchemaPath(const Filename: string): string;
        procedure ExecScript(const Filenames: array of string);
        function AddChain(const Name: string; UserID: Integer): Integer;
        function AddSnippet(const Title: string; UserID: Integer = 1): Integer;
        function AddStepRaw(ChainID, Position, SnippetID: Integer; PauseMs: Integer = 0): Integer;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;
        [Test]
        procedure Add_ReturnsID_AndGetByID;
        [Test]
        procedure Add_DuplicateName_SameWorkspace_Raises;
        [Test]
        procedure Add_SameName_DifferentWorkspaces_Allowed;
        [Test]
        procedure GetAll_FiltersByUserID;
        [Test]
        procedure UpdateName_Renames;
        [Test]
        procedure NameExists_ExcludesSelf;
        [Test]
        procedure GetSteps_OrderAndTitles;
        [Test]
        procedure ReplaceSteps_ReplacesAll;
        [Test]
        procedure DeleteChain_CascadesSteps;
        [Test]
        procedure DeleteSnippet_CascadesSteps;
        [Test]
        procedure ReplaceSteps_NegativePauseRejected;
    end;

implementation

uses
    System.SysUtils,
    System.IOUtils,
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

var
    GDriverLink: TFDPhysSQLiteDriverLink;

function TChainsTests.SchemaPath(const Filename: string): string;
begin
    Result := TPath.GetFullPath(TPath.Combine(TPath.GetDirectoryName(ParamStr(0)) + PathDelim + '..', TPath.Combine('Database', 'Schema', Filename)));
    if not TFile.Exists(Result) then
        raise Exception.Create('Schema file not found: ' + Result);
end;

procedure TChainsTests.ExecScript(const Filenames: array of string);
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

procedure TChainsTests.Setup;
begin
    FConn := TFDConnection.Create(nil);
    FConn.Params.Add('DriverID=SQLite');
    FConn.Params.Add('Database=:memory:');
    FConn.Connected := True;
    FConn.ExecSQL('PRAGMA foreign_keys = ON');
    ExecScript(['000_schema_init.sql', '100_migrations.sql']);
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'')');
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (2, ''Second User'')');
    FRepo := TChainRepository.Create(FConn);
end;

procedure TChainsTests.TearDown;
begin
    FreeAndNil(FRepo);
    FreeAndNil(FConn);
end;

function TChainsTests.AddChain(const Name: string; UserID: Integer): Integer;
var
    Chain: TChainDTO;
begin
    Chain := Default(TChainDTO);
    Chain.UserID := UserID;
    Chain.Name := Name;
    Result := FRepo.Add(Chain);
end;

function TChainsTests.AddSnippet(const Title: string; UserID: Integer): Integer;
begin
    FConn.ExecSQL('INSERT INTO snippets (user_id, title, content) VALUES (?, ?, ?)',
        [UserID, Title, 'echo ' + Title]);
    Result := FConn.ExecSQLScalar('SELECT last_insert_rowid()');
end;

function TChainsTests.AddStepRaw(ChainID, Position, SnippetID: Integer; PauseMs: Integer): Integer;
begin
    FConn.ExecSQL('INSERT INTO snippet_chain_steps (chain_id, position, snippet_id, pause_ms) VALUES (?, ?, ?, ?)',
        [ChainID, Position, SnippetID, PauseMs]);
    Result := FConn.ExecSQLScalar('SELECT last_insert_rowid()');
end;

procedure TChainsTests.Add_ReturnsID_AndGetByID;
var
    ID: Integer;
    Chain: TChainDTO;
begin
    ID := AddChain('deploy', 1);
    Assert.IsTrue(ID > 0);

    Chain := FRepo.GetByID(ID);
    Assert.AreEqual(ID, Chain.ID);
    Assert.AreEqual('deploy', Chain.Name);
    Assert.AreEqual(1, Chain.UserID);
end;

procedure TChainsTests.Add_DuplicateName_SameWorkspace_Raises;
begin
    AddChain('deploy', 1);
    Assert.WillRaise(
        procedure begin AddChain('DEPLOY', 1); end,
        ESQLiteNativeException);
end;

procedure TChainsTests.Add_SameName_DifferentWorkspaces_Allowed;
var
    ID1, ID2: Integer;
begin
    ID1 := AddChain('deploy', 1);
    ID2 := AddChain('deploy', 2);
    Assert.IsTrue(ID1 > 0);
    Assert.IsTrue(ID2 > 0);
    Assert.AreNotEqual(ID1, ID2);
end;

procedure TChainsTests.GetAll_FiltersByUserID;
begin
    AddChain('alpha', 1);
    AddChain('beta', 1);
    AddChain('gamma', 2);

    Assert.AreEqual(2, Integer(Length(FRepo.GetAll(1))));
    Assert.AreEqual(1, Integer(Length(FRepo.GetAll(2))));
    Assert.AreEqual(3, Integer(Length(FRepo.GetAll(0))));
end;

procedure TChainsTests.UpdateName_Renames;
var
    ID: Integer;
begin
    ID := AddChain('old-name', 1);
    FRepo.UpdateName(ID, 'new-name');

    Assert.AreEqual('new-name', FRepo.GetByID(ID).Name);
end;

procedure TChainsTests.NameExists_ExcludesSelf;
var
    ID: Integer;
begin
    ID := AddChain('deploy', 1);
    Assert.IsTrue(FRepo.NameExists('deploy', 1, 0));
    Assert.IsFalse(FRepo.NameExists('deploy', 1, ID));
    Assert.IsTrue(FRepo.NameExists('DEPLOY', 1, 0));
    Assert.IsFalse(FRepo.NameExists('deploy', 2, 0));
end;

procedure TChainsTests.GetSteps_OrderAndTitles;
var
    ChainID, S1, S2: Integer;
    Steps: TArray<TChainStepDTO>;
begin
    ChainID := AddChain('deploy', 1);
    S1 := AddSnippet('first step');
    S2 := AddSnippet('second step');

    AddStepRaw(ChainID, 1, S2, 500);
    AddStepRaw(ChainID, 0, S1, 250);

    Steps := FRepo.GetSteps(ChainID);
    Assert.AreEqual(2, Integer(Length(Steps)));
    Assert.AreEqual(S1, Steps[0].SnippetID);
    Assert.AreEqual('first step', Steps[0].SnippetTitle);
    Assert.AreEqual(250, Steps[0].PauseMs);
    Assert.AreEqual(S2, Steps[1].SnippetID);
    Assert.AreEqual('second step', Steps[1].SnippetTitle);
    Assert.AreEqual(500, Steps[1].PauseMs);
end;

procedure TChainsTests.ReplaceSteps_ReplacesAll;
var
    ChainID, S1, S2: Integer;
    Steps: TArray<TChainStepDTO>;
begin
    ChainID := AddChain('deploy', 1);
    S1 := AddSnippet('first step');
    S2 := AddSnippet('second step');

    AddStepRaw(ChainID, 0, S1, 0);
    AddStepRaw(ChainID, 1, S1, 0);

    SetLength(Steps, 2);
    Steps[0] := Default(TChainStepDTO);
    Steps[0].SnippetID := S2;
    Steps[0].PauseMs := 1000;
    Steps[1] := Default(TChainStepDTO);
    Steps[1].SnippetID := S1;
    Steps[1].PauseMs := 0;

    FRepo.ReplaceSteps(ChainID, Steps);

    Steps := FRepo.GetSteps(ChainID);
    Assert.AreEqual(2, Integer(Length(Steps)));
    Assert.AreEqual(S2, Steps[0].SnippetID);
    Assert.AreEqual(1000, Steps[0].PauseMs);
    Assert.AreEqual(0, Steps[0].Position);
    Assert.AreEqual(S1, Steps[1].SnippetID);
    Assert.AreEqual(1, Steps[1].Position);
end;

procedure TChainsTests.DeleteChain_CascadesSteps;
var
    ChainID, S1: Integer;
begin
    ChainID := AddChain('deploy', 1);
    S1 := AddSnippet('first step');
    AddStepRaw(ChainID, 0, S1, 0);

    FRepo.Delete(ChainID);

    Assert.AreEqual(0, Integer(Length(FRepo.GetSteps(ChainID))));
    Assert.AreEqual(0, Integer(FConn.ExecSQLScalar('SELECT COUNT(*) FROM snippet_chain_steps')));
end;

procedure TChainsTests.DeleteSnippet_CascadesSteps;
var
    ChainID, S1: Integer;
begin
    ChainID := AddChain('deploy', 1);
    S1 := AddSnippet('first step');
    AddStepRaw(ChainID, 0, S1, 0);

    FConn.ExecSQL('DELETE FROM snippets WHERE id = ?', [S1]);

    Assert.AreEqual(0, Integer(FConn.ExecSQLScalar('SELECT COUNT(*) FROM snippet_chain_steps')));
end;

procedure TChainsTests.ReplaceSteps_NegativePauseRejected;
var
    ChainID, S1: Integer;
    Steps: TArray<TChainStepDTO>;
    Action: TProc;
begin
    ChainID := AddChain('deploy', 1);
    S1 := AddSnippet('first step');

    SetLength(Steps, 1);
    Steps[0] := Default(TChainStepDTO);
    Steps[0].SnippetID := S1;
    Steps[0].PauseMs := -5;

    Action := procedure begin FRepo.ReplaceSteps(ChainID, Steps); end;
    Assert.WillRaise(Action, ESQLiteNativeException);
end;

initialization
    GDriverLink := TFDPhysSQLiteDriverLink.Create(nil);

finalization
    GDriverLink.Free;

end.
