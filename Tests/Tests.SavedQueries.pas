unit Tests.SavedQueries;

interface

uses
    DUnitX.TestFramework,
    FireDAC.Comp.Client,
    SavedQueryRepository,
    Core.Entities.Chain,
    Core.Entities.SavedQuery
    ;

type
    [TestFixture]
    TSavedQueriesTests = class(TObject)
    private
        FConn: TFDConnection;
        FRepo: TSavedQueryRepository;
        function SchemaPath(const Filename: string): string;
        procedure ExecScript(const Filenames: array of string);
        function AddQuery(const Name, QueryText: string; UserID: Integer): Integer;
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
        procedure UpdateQueryText_Updates;
        [Test]
        procedure NameExists_ExcludesSelf;
        [Test]
        procedure Delete_Removes;
        [Test]
        procedure DeleteUser_CascadesQueries;
        [Test]
        procedure NodeID_RoundTrip_AndRanges;
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

function TSavedQueriesTests.SchemaPath(const Filename: string): string;
var
    Dir: string;
begin
    Dir := TPath.GetDirectoryName(ParamStr(0));
    repeat
        Result := TPath.Combine(Dir, TPath.Combine('Database', 'Schema', Filename));
        if TFile.Exists(Result) then
            Exit;
        Dir := TPath.GetDirectoryName(Dir);
    until Dir = '';
    raise Exception.Create('Schema file not found: ' + Result);
end;

procedure TSavedQueriesTests.ExecScript(const Filenames: array of string);
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

procedure TSavedQueriesTests.Setup;
begin
    FConn := TFDConnection.Create(nil);
    FConn.Params.Add('DriverID=SQLite');
    FConn.Params.Add('Database=:memory:');
    FConn.Connected := True;
    FConn.ExecSQL('PRAGMA foreign_keys = ON');
    ExecScript(['000_schema_init.sql']);
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'')');
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (2, ''Second User'')');
    FRepo := TSavedQueryRepository.Create(FConn);
end;

procedure TSavedQueriesTests.TearDown;
begin
    FreeAndNil(FRepo);
    FreeAndNil(FConn);
end;

function TSavedQueriesTests.AddQuery(const Name, QueryText: string; UserID: Integer): Integer;
var
    SavedQuery: TSavedQueryDTO;
begin
    SavedQuery := Default(TSavedQueryDTO);
    SavedQuery.UserID := UserID;
    SavedQuery.Name := Name;
    SavedQuery.QueryText := QueryText;
    Result := FRepo.Add(SavedQuery);
end;

procedure TSavedQueriesTests.Add_ReturnsID_AndGetByID;
var
    ID: Integer;
    SavedQuery: TSavedQueryDTO;
begin
    ID := AddQuery('log-check', 'tag:nginx fav title:restart', 1);
    Assert.IsTrue(ID > 0);

    SavedQuery := FRepo.GetByID(ID);
    Assert.AreEqual(ID, SavedQuery.ID);
    Assert.AreEqual('log-check', SavedQuery.Name);
    Assert.AreEqual('tag:nginx fav title:restart', SavedQuery.QueryText);
    Assert.AreEqual(1, SavedQuery.UserID);
end;

procedure TSavedQueriesTests.Add_DuplicateName_SameWorkspace_Raises;
begin
    AddQuery('deploy', 'tag:prod', 1);
    Assert.WillRaise(
        procedure begin AddQuery('DEPLOY', 'tag:dev', 1); end,
        ESQLiteNativeException);
end;

procedure TSavedQueriesTests.Add_SameName_DifferentWorkspaces_Allowed;
var
    ID1, ID2: Integer;
begin
    ID1 := AddQuery('deploy', 'tag:prod', 1);
    ID2 := AddQuery('deploy', 'tag:dev', 2);
    Assert.IsTrue(ID1 > 0);
    Assert.IsTrue(ID2 > 0);
    Assert.AreNotEqual(ID1, ID2);
end;

procedure TSavedQueriesTests.GetAll_FiltersByUserID;
begin
    AddQuery('alpha', 'tag:a', 1);
    AddQuery('beta', 'tag:b', 1);
    AddQuery('gamma', 'tag:c', 2);

    Assert.AreEqual(2, Integer(Length(FRepo.GetAll(1))));
    Assert.AreEqual(1, Integer(Length(FRepo.GetAll(2))));
    Assert.AreEqual(3, Integer(Length(FRepo.GetAll(0))));
end;

procedure TSavedQueriesTests.UpdateName_Renames;
var
    ID: Integer;
begin
    ID := AddQuery('old-name', 'tag:a', 1);
    FRepo.UpdateName(ID, 'new-name');

    Assert.AreEqual('new-name', FRepo.GetByID(ID).Name);
end;

procedure TSavedQueriesTests.UpdateQueryText_Updates;
var
    ID: Integer;
begin
    ID := AddQuery('deploy', 'tag:old', 1);
    FRepo.UpdateQueryText(ID, 'tag:new fav');

    Assert.AreEqual('tag:new fav', FRepo.GetByID(ID).QueryText);
end;

procedure TSavedQueriesTests.NameExists_ExcludesSelf;
var
    ID: Integer;
begin
    ID := AddQuery('deploy', 'tag:prod', 1);
    Assert.IsTrue(FRepo.NameExists('deploy', 1, 0));
    Assert.IsFalse(FRepo.NameExists('deploy', 1, ID));
    Assert.IsTrue(FRepo.NameExists('DEPLOY', 1, 0));
    Assert.IsFalse(FRepo.NameExists('deploy', 2, 0));
end;

procedure TSavedQueriesTests.Delete_Removes;
var
    ID: Integer;
begin
    ID := AddQuery('deploy', 'tag:prod', 1);
    FRepo.Delete(ID);

    Assert.AreEqual(0, FRepo.GetByID(ID).ID);
    Assert.AreEqual(0, Integer(FConn.ExecSQLScalar('SELECT COUNT(*) FROM saved_queries')));
end;

procedure TSavedQueriesTests.DeleteUser_CascadesQueries;
begin
    AddQuery('deploy', 'tag:prod', 2);
    Assert.AreEqual(1, Integer(Length(FRepo.GetAll(2))));

    FConn.ExecSQL('DELETE FROM users WHERE id = 2');

    Assert.AreEqual(0, Integer(FConn.ExecSQLScalar('SELECT COUNT(*) FROM saved_queries')));
end;

procedure TSavedQueriesTests.NodeID_RoundTrip_AndRanges;
var
    ID, NodeValue: Integer;
begin
    // Круговое кодирование: ID -> Node.Data -> ID
    ID := 42;
    NodeValue := EncodeSavedQueryNodeID(ID);
    Assert.IsTrue(NodeValue < 0);
    Assert.IsTrue(TryGetSavedQueryID(NodeValue, ID));
    Assert.AreEqual(42, ID);

    // Корневой узел - не узел сохранённого запроса
    Assert.IsTrue(IsSavedQueriesRootNode(SAVED_QUERIES_ROOT_NODE_ID));
    Assert.IsFalse(TryGetSavedQueryID(SAVED_QUERIES_ROOT_NODE_ID, ID));

    // Обычные (положительные) и диапазон цепочек - не умные папки
    Assert.IsFalse(TryGetSavedQueryID(123, ID));
    Assert.IsFalse(TryGetSavedQueryID(-(CHAIN_NODE_ID_BASE + 7), ID));

    // Границы: минимальный ID декодируется, узлы выше BASE - нет
    Assert.IsTrue(TryGetSavedQueryID(-(SAVED_QUERY_NODE_ID_BASE + 1), ID));
    Assert.AreEqual(1, ID);
    Assert.IsFalse(TryGetSavedQueryID(-(SAVED_QUERY_NODE_ID_BASE - 1), ID));
end;

initialization
    GDriverLink := TFDPhysSQLiteDriverLink.Create(nil);

finalization
    GDriverLink.Free;

end.
