unit Tests.DirtyDetection;

// Регрессия на ложное срабатывание IsSnippetChanged: открытие сниппета на
// редактирование и отмена без правок не должны показывать предупреждение
// "обнаружены изменения". Форма строится по тому же пути, что и
// TAddEditSnippetForm.ExecuteEdit (Create -> Initialize -> Prepare ->
// WarmUpPaint), но без ShowModal; проверка чистоты вызывается напрямую.
// Данные берутся из реальных сервисов над in-memory SQLite.

interface

uses
    AddEditSnippetFormUI,
    DUnitX.TestFramework,
    Core.Entities.Category,
    Core.Entities.Snippet,
    Core.Interfaces.App,
    FireDAC.Comp.Client,
    MainFormUI,
    System.SysUtils
    ;

type
    [TestFixture]
    TDirtyDetectionTests = class(TObject)
    private
        FConn: TFDConnection;
        FContext: IAppContext;
        FMainForm: TMainForm;
        FForm: TAddEditSnippetForm;
        function SchemaPath(const AFilename: string): string;
        procedure ExecSchema(AConn: TFDConnection);
        function NewCategoryID: Integer;
        procedure OpenEditForm(const ASnippet: TSnippetDTO);
        procedure AssertClean(const AContext: string);
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test] procedure OpenEdit_CancelImmediately_LF_NoTrailing_IsClean;
        [Test] procedure OpenEdit_CancelImmediately_LF_Trailing_IsClean;
        [Test] procedure OpenEdit_CancelImmediately_CRLF_Importer_IsClean;
        [Test] procedure OpenEdit_CancelImmediately_EmptyContent_IsClean;
        [Test] procedure OpenEdit_CancelImmediately_Tags_Locks_Security_IsClean;
        [Test] procedure SecurityIgnore_RoundTrip_ThroughDB;
    end;

implementation

uses
    FireDAC.Comp.Script,
    System.IOUtils,
    System.Classes,
    Tests.MarkdownImporter
    ;

{ TDirtyDetectionTests }

function TDirtyDetectionTests.SchemaPath(const AFilename: string): string;
var
    Dir: string;
begin
    Dir := TPath.GetDirectoryName(ParamStr(0));
    repeat
        Result := TPath.Combine(Dir, TPath.Combine('Database', 'Schema', AFilename));
        if TFile.Exists(Result) then
            Exit;
        Dir := TPath.GetDirectoryName(Dir);
    until Dir = '';
    raise Exception.Create('Schema file not found: ' + Result);
end;

procedure TDirtyDetectionTests.ExecSchema(AConn: TFDConnection);
var
    Script: TFDScript;
begin
    Script := TFDScript.Create(nil);
    try
        Script.Connection := AConn;
        Script.SQLScripts.Add.SQL.Text :=
            TFile.ReadAllText(SchemaPath('000_schema_init.sql'), TEncoding.UTF8);
        Script.ExecuteAll;
    finally
        Script.Free;
    end;
end;

procedure TDirtyDetectionTests.Setup;
var
    DbManager: TTestDatabaseManager;
begin
    FConn := TFDConnection.Create(nil);
    FConn.Params.Add('DriverID=SQLite');
    FConn.Params.Add('Database=:memory:');
    FConn.Connected := True;
    FConn.ExecSQL('PRAGMA foreign_keys = ON');
    ExecSchema(FConn);
    FConn.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'')');

    DbManager := TTestDatabaseManager.Create;
    FContext := TTestAppContext.Create(FConn, DbManager);

    // FormCreate формы сниппета берёт vilTags из глобальной главной формы
    FMainForm := TMainForm.Create(nil);
    MainForm := FMainForm;
end;

procedure TDirtyDetectionTests.TearDown;
begin
    FreeAndNil(FForm);
    MainForm := nil;
    FreeAndNil(FMainForm);
    FContext := nil;
    FreeAndNil(FConn);
end;

function TDirtyDetectionTests.NewCategoryID: Integer;
var
    Cat: TCategoryDTO;
begin
    Cat := Default(TCategoryDTO);
    Cat.Name := 'dirty-tests-' + TGuid.NewGuid.ToString;
    Cat.ParentID := 0;
    Cat.UserID := 1;
    Result := FContext.CategoryService.CreateCategory(Cat);
end;

procedure TDirtyDetectionTests.OpenEditForm(const ASnippet: TSnippetDTO);
begin
    // Путь TAddEditSnippetForm.ExecuteEdit без модальных частей
    FreeAndNil(FForm);
    FForm := TAddEditSnippetForm.Create(nil);
    FForm.Initialize(FContext);
    FForm.Prepare(True, ASnippet, ASnippet.CategoryID, ASnippet.UserID);
    FForm.HandleNeeded;
    FForm.WarmUpPaint;
end;

procedure TDirtyDetectionTests.AssertClean(const AContext: string);
begin
    Assert.IsFalse(FForm.IsSnippetChanged,
        AContext + ': отмена без правок не должна считать сниппет изменённым');
end;

procedure TDirtyDetectionTests.OpenEdit_CancelImmediately_LF_NoTrailing_IsClean;
var
    Snip, Loaded: TSnippetDTO;
begin
    Snip := Default(TSnippetDTO);
    Snip.UserID := 1;
    Snip.CategoryID := NewCategoryID;
    Snip.Title := 'LF no trailing';
    Snip.Content := 'echo a' + #10 + 'echo b';
    Snip.Comment := 'plain comment';
    Snip.Language := 'bash';
    Snip.CreatedAt := 1600000000;
    Loaded := FContext.SnippetService.GetSnippetByID(FContext.SnippetService.CreateSnippet(Snip, []));
    OpenEditForm(Loaded);
    AssertClean('LF no trailing');
end;

procedure TDirtyDetectionTests.OpenEdit_CancelImmediately_LF_Trailing_IsClean;
var
    Snip, Loaded: TSnippetDTO;
begin
    Snip := Default(TSnippetDTO);
    Snip.UserID := 1;
    Snip.CategoryID := NewCategoryID;
    Snip.Title := 'LF trailing';
    Snip.Content := 'echo a' + #10 + 'echo b' + #10;
    Snip.Comment := 'comment';
    Snip.Language := 'bash';
    Snip.CreatedAt := 1600000000;
    Loaded := FContext.SnippetService.GetSnippetByID(FContext.SnippetService.CreateSnippet(Snip, []));
    OpenEditForm(Loaded);
    AssertClean('LF trailing');
end;

procedure TDirtyDetectionTests.OpenEdit_CancelImmediately_CRLF_Importer_IsClean;
var
    Snip, Loaded: TSnippetDTO;
begin
    // Как markdown-импортёр: string.Join(sLineBreak, ...) - CRLF без завершающего
    Snip := Default(TSnippetDTO);
    Snip.UserID := 1;
    Snip.CategoryID := NewCategoryID;
    Snip.Title := 'CRLF importer';
    Snip.Content := 'echo a' + #13#10 + 'echo b' + #13#10 + 'echo c';
    Snip.Comment := 'line1' + #13#10 + 'line2';
    Snip.Language := 'bash';
    Snip.CreatedAt := 1600000000;
    Loaded := FContext.SnippetService.GetSnippetByID(FContext.SnippetService.CreateSnippet(Snip, []));
    OpenEditForm(Loaded);
    AssertClean('CRLF importer');
end;

procedure TDirtyDetectionTests.OpenEdit_CancelImmediately_EmptyContent_IsClean;
var
    Snip, Loaded: TSnippetDTO;
begin
    Snip := Default(TSnippetDTO);
    Snip.UserID := 1;
    Snip.CategoryID := NewCategoryID;
    Snip.Title := 'Empty';
    Snip.Content := '';
    Snip.Comment := '';
    Snip.Language := '';
    Snip.CreatedAt := 1600000000;
    Loaded := FContext.SnippetService.GetSnippetByID(FContext.SnippetService.CreateSnippet(Snip, []));
    OpenEditForm(Loaded);
    AssertClean('Empty content');
end;

procedure TDirtyDetectionTests.OpenEdit_CancelImmediately_Tags_Locks_Security_IsClean;
var
    Snip, Loaded: TSnippetDTO;
    Tag1, Tag2: Integer;
begin
    Tag1 := FContext.TagService.CreateTag('ssh');
    Tag2 := FContext.TagService.CreateTag('net');

    Snip := Default(TSnippetDTO);
    Snip.UserID := 1;
    Snip.CategoryID := NewCategoryID;
    Snip.Title := 'Tags and locks';
    Snip.Content := 'echo a' + #10 + 'echo b';
    Snip.Comment := 'comment';
    Snip.Language := 'bash';
    Snip.LanguageLocked := True;
    Snip.IsSecurityCheckIgnored := True;
    Snip.CreatedAt := 1600000000;
    Loaded := FContext.SnippetService.GetSnippetByID(FContext.SnippetService.CreateSnippet(Snip, [Tag1, Tag2]));
    OpenEditForm(Loaded);
    AssertClean('Tags+Locks+Security');
end;

procedure TDirtyDetectionTests.SecurityIgnore_RoundTrip_ThroughDB;
var
    Snip, Loaded: TSnippetDTO;
    SnippetID: Integer;
begin
    // Галочка "доверять сниппету" обязана переживать запись и чтение из БД
    Snip := Default(TSnippetDTO);
    Snip.UserID := 1;
    Snip.CategoryID := NewCategoryID;
    Snip.Title := 'Security ignore round trip';
    Snip.Content := 'echo a';
    Snip.Comment := 'comment';
    Snip.Language := 'bash';
    Snip.IsSecurityCheckIgnored := True;
    Snip.CreatedAt := 1600000000;
    SnippetID := FContext.SnippetService.CreateSnippet(Snip, []);

    Loaded := FContext.SnippetService.GetSnippetByID(SnippetID);
    Assert.IsTrue(Loaded.IsSecurityCheckIgnored, 'is_security_ignored должен прочитаться как True');

    Loaded.IsSecurityCheckIgnored := False;
    Loaded.UpdatedAt := 1600000001;
    FContext.SnippetService.UpdateSnippet(Loaded, []);

    Loaded := FContext.SnippetService.GetSnippetByID(SnippetID);
    Assert.IsFalse(Loaded.IsSecurityCheckIgnored, 'is_security_ignored должен прочитаться как False после Update');
end;

end.

