unit Data.Database;

interface

uses
    Core.Interfaces.Data,
    Data.DB,
    FireDAC.Comp.Client,
    FireDAC.Comp.DataSet,
    FireDAC.Comp.Script,
    FireDAC.Comp.ScriptCommands,
    FireDAC.Comp.UI,
    FireDAC.DApt,
    FireDAC.DApt.Intf,
    FireDAC.DatS,
    FireDAC.Phys,
    FireDAC.Phys.Intf,
    FireDAC.Phys.SQLite,
    FireDAC.Phys.SQLiteDef,
    FireDAC.Phys.SQLiteWrapper.Stat,
    FireDAC.Stan.Async,
    FireDAC.Stan.Def,
    FireDAC.Stan.Error,
    FireDAC.Stan.ExprFuncs,
    FireDAC.Stan.Intf,
    FireDAC.Stan.Option,
    FireDAC.Stan.Param,
    FireDAC.Stan.Pool,
    FireDAC.Stan.Util,
    FireDAC.UI.Intf,
    FireDAC.VCLUI.Wait,
    System.Classes,
    System.SysUtils,
    Winapi.Windows
    ;

type
    TAppDatabase = class(TDataModule, IDatabaseManager)
        FDConnection: TFDConnection;
        FDQuery: TFDQuery;
        FDManager: TFDManager;
        FDGUIxWaitCursor: TFDGUIxWaitCursor;
        FDPhysSQLiteDriverLink: TFDPhysSQLiteDriverLink;
        FDScript: TFDScript;
    private
        procedure InitializeDatabase(Filename: string);
        procedure ApplyPRAGMA;
        procedure ApplySchemaMigrations;
        procedure FlushToDisk;
        function LoadSQLFromResource(const ResourceName: string): string;
    public
        procedure CreateDatabase(const Filename: string);
        procedure OpenDatabase(const Filename: string);
        procedure CloseDatabase;
        function IsConnected: Boolean;
        function GetConnectionString: string;
    end;

var
    AppDatabase: TAppDatabase;

implementation

uses
    Common.Localization
    ;

{$R *.dfm}

procedure TAppDatabase.CreateDatabase(const Filename: string);
begin
    InitializeDatabase(Filename);
end;

procedure TAppDatabase.OpenDatabase(const Filename: string);
begin
    CloseDatabase;

    FDConnection.Params.Database := Filename;
    FDConnection.Params.Add('DriverID=SQLite');
    FDConnection.Params.Add('CharacterSet=utf8');
    FDConnection.Connected := True;

    ApplyPRAGMA;
    ApplySchemaMigrations;
end;

procedure TAppDatabase.InitializeDatabase(Filename: string);
begin
    OpenDatabase(Filename);

    FDScript.Connection := FDConnection;
    FDScript.SQLScripts.Clear;

    with FDScript.SQLScripts.Add do
        SQL.Text :=
            LoadSQLFromResource('SCHEMA_INIT_SQL') +
            LoadSQLFromResource('SCHEMA_SEED_SQL');

    try
        FDScript.ExecuteAll;
    except
        on E: Exception do
            raise Exception.Create(
                TUIStateLoader.GetMessage('DB.SQLExecutionError', [E.Message])
            );
    end;

    FDConnection.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'');');
end;

function TAppDatabase.IsConnected: Boolean;
begin
    Result := FDConnection.Connected;
end;

function TAppDatabase.LoadSQLFromResource(const ResourceName: string): string;
var
    ResStream: TResourceStream;
    SL: TStringList;
begin
    ResStream := TResourceStream.Create(HInstance, ResourceName, RT_RCDATA);
    try
        SL := TStringList.Create;
        try
            SL.LoadFromStream(ResStream, TEncoding.UTF8);
            Result := SL.Text;
        finally
            SL.Free;
        end;
    finally
        ResStream.Free;
    end;
end;

procedure TAppDatabase.ApplyPRAGMA;
begin
    FDConnection.ExecSQL('PRAGMA foreign_keys = ON;');
    FDConnection.ExecSQL('PRAGMA journal_mode = WAL;');
    FDConnection.ExecSQL('PRAGMA synchronous = NORMAL;');
    FDConnection.ExecSQL('PRAGMA temp_store = MEMORY;');
    FDConnection.ExecSQL('PRAGMA recursive_triggers = OFF;');
    FDConnection.ExecSQL('PRAGMA busy_timeout = 1000;');
    FDConnection.ExecSQL('PRAGMA cache_size = -20000;');
end;

procedure TAppDatabase.ApplySchemaMigrations;
begin
    FDScript.Connection := FDConnection;
    FDScript.SQLScripts.Clear;

    with FDScript.SQLScripts.Add do
        SQL.Text := LoadSQLFromResource('SCHEMA_MIGRATE_SQL');

    try
        FDScript.ExecuteAll;
    except
        on E: Exception do
            raise Exception.Create(
                TUIStateLoader.GetMessage('DB.SQLExecutionError', [E.Message])
            );
    end;

    // v11: язык сниппета. ALTER TABLE ADD COLUMN не поддерживает IF NOT EXISTS,
    // а миграции выполняются при каждом открытии БД, поэтому колонку добавляем по условию.
    // На новой БД таблицы snippets ещё нет (InitializeDatabase накатывает базовую схему
    // после миграций) — там колонку задаёт 000_schema_init.sql.
    if FDConnection.ExecSQLScalar('SELECT COUNT(*) FROM sqlite_master WHERE type = ''table'' AND name = ''snippets''') > 0 then
        if FDConnection.ExecSQLScalar('SELECT COUNT(*) FROM pragma_table_info(''snippets'') WHERE name = ''language''') = 0 then
            FDConnection.ExecSQL('ALTER TABLE snippets ADD COLUMN language TEXT NOT NULL DEFAULT ''bash''');
end;

procedure TAppDatabase.CloseDatabase;
begin
    FlushToDisk;
    FDConnection.Close;
    FDConnection.Params.Clear;
end;

procedure TAppDatabase.FlushToDisk;
begin
    if FDConnection.Connected then
    begin
        // Принудительный checkpoint: все данные из WAL -> основной файл
        FDConnection.ExecSQL('PRAGMA wal_checkpoint(TRUNCATE)');
        // Освобождаем -wal и -shm файлы
        FDConnection.ExecSQL('PRAGMA wal_checkpoint(PASSIVE)');
    end;
end;

function TAppDatabase.GetConnectionString: string;
begin
    Result := FDConnection.Params.Text;
end;

end.

