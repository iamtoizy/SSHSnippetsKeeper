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
    System.SysUtils
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
        FEncryptionKey: string;

        procedure Connect(const Filename: string);
        procedure InitializeDatabase(Filename: string);
        procedure ApplyPRAGMA;
        procedure ApplySchemaMigrations;
        procedure OptimizeFTS;
        procedure FlushToDisk;
    public
        procedure CreateDatabase(const Filename: string);
        procedure OpenDatabase(const Filename: string);
        procedure CloseDatabase;
        function IsConnected: Boolean;
        function GetConnectionString: string;
        function DatabaseFile: string;
        function CreateImportSnapshot: string;

        // Материал ключа шифрования БД (base64 от 32 байт) для следующего
        // Connect; пустая строка = открытие без шифрования. Выставляется
        // вызывающим кодом ДО CreateDatabase/OpenDatabase
        property EncryptionKey: string read FEncryptionKey write FEncryptionKey;
    end;

var
    AppDatabase: TAppDatabase;

implementation

uses
    Common.Localization,
    Data.Database.Migrations,
    Data.Database.Security,
    Winapi.Windows
    ;

{$R *.dfm}

procedure TAppDatabase.CreateDatabase(const Filename: string);
begin
    InitializeDatabase(Filename);
end;

procedure TAppDatabase.OpenDatabase(const Filename: string);
begin
    Connect(Filename);
    ApplySchemaMigrations;
    OptimizeFTS;
end;

procedure TAppDatabase.Connect(const Filename: string);
begin
    CloseDatabase;

    // Зашифрованное открытие без DLL mc-движка невозможно: статический
    // движок вернул бы NOTADB - сообщаем об отсутствии библиотеки явно
    if (FEncryptionKey <> '') and (not DbEngineDllAvailable) then
        raise Exception.Create(TUIStateLoader.GetMessage(
            'DB.EncryptionEngineMissing', [DbEngineDllPath]));

    FDConnection.Params.Database := Filename;
    FDConnection.Params.Add('DriverID=SQLite');
    // Динамическая линковка: sqlite3mc_x64.dll рядом с exe (SQLite 3.54 +
    // шифрование SQLite3 Multiple Ciphers). Единый движок для шифрованных
    // и обычных БД - открытый файл не зависит от того, с каким ключом
    // его открыли
    ApplyEngineLinkage(FDPhysSQLiteDriverLink);
    // Параметры задаются вместо PRAGMA после открытия: FireDAC на этапе
    // открытия сам выполняет "PRAGMA journal_mode = DELETE" (выкидывает БД
    // из WAL) и "PRAGMA locking_mode = Exclusive" (монопольный лок всей БД).
    // WAL + обычная блокировка обязательны для консольных команд (/backup,
    // /checkdb, /migrate), работающих параллельно с запущенным приложением
    FDConnection.Params.Add('JournalMode=WAL');
    FDConnection.Params.Add('LockingMode=Normal');
    FDConnection.Params.Add('CharacterSet=utf8');
    if FEncryptionKey <> '' then
        ApplyEncryptionParams(FDConnection.Params, FEncryptionKey);
    FDConnection.Connected := True;

    ApplyPRAGMA;
end;

procedure TAppDatabase.InitializeDatabase(Filename: string);
begin
    Connect(Filename);

    FDScript.Connection := FDConnection;
    FDScript.SQLScripts.Clear;
    // Ошибка statement обязана прервать скрипт исключением: с дефолтным
    // BreakOnError=False ExecuteAll молча продолжит и COMMIT закоммитит
    // частичную схему
    FDScript.ScriptOptions.BreakOnError := True;

    // Baseline одной транзакцией: сбой посреди скрипта откатывает всю схему.
    // Соединение уже настроено ApplyPRAGMA; PRAGMA соединения убраны из
    // 000_schema_init.sql, т.к. synchronous/journal_mode в транзакции менять
    // нельзя. foreign_keys отключаем снаружи: внутри транзакции этот PRAGMA -
    // no-op, а seed грузится без проверки связей
    FDConnection.ExecSQL('PRAGMA foreign_keys = OFF');
    try
        with FDScript.SQLScripts.Add do
            SQL.Text :=
                'BEGIN;' + sLineBreak +
                LoadSQLResource('SCHEMA_INIT_SQL') +
                LoadSQLResource('SCHEMA_SEED_SQL') +
                sLineBreak + 'COMMIT;';

        try
            FDScript.ExecuteAll;
        except
            on E: Exception do
            begin
                // Полусозданный файл не оставляем (как в /newdb): закрытие
                // соединения откатывает незавершённую транзакцию, а файлы
                // SQLite держатся открытыми с FILE_SHARE_DELETE и удаляются
                // при освобождении хендлов
                if FDConnection.Connected then
                    FDConnection.Close;
                Winapi.Windows.DeleteFile(PChar(Filename));
                Winapi.Windows.DeleteFile(PChar(Filename + '-wal'));
                Winapi.Windows.DeleteFile(PChar(Filename + '-shm'));
                raise Exception.Create(
                    TUIStateLoader.GetMessage('DB.SQLExecutionError', [E.Message])
                );
            end;
        end;
    finally
        if FDConnection.Connected then
            FDConnection.ExecSQL('PRAGMA foreign_keys = ON');
    end;

    // PRAGMA user_version = APP_DB_VERSION выставляется в заголовке схемы
    // (000_schema_init.sql), поэтому раннер миграций после создания БД
    // ничего не применяет
    FDConnection.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'');');
    OptimizeFTS;
end;

function TAppDatabase.IsConnected: Boolean;
begin
    Result := FDConnection.Connected;
end;

function TAppDatabase.DatabaseFile: string;
begin
    Result := '';
    if not IsConnected then
        Exit;
    Result := FDConnection.Params.Database;
    if SameText(Result, ':memory:') then
        Result := '';
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

procedure TAppDatabase.OptimizeFTS;
begin
    try
        FDConnection.ExecSQL('INSERT INTO snippet_fts(snippet_fts) VALUES(''optimize'')');
    except
        on E: EFDDBEngineException do
        begin
        end;
    end;
end;

procedure TAppDatabase.ApplySchemaMigrations;
var
    Migrator: TDatabaseMigrator;
begin
    Migrator := TDatabaseMigrator.Create(FDConnection, FDConnection.Params.Database);
    try
        Migrator.Run;
    finally
        Migrator.Free;
    end;
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
        // Принудительный checkpoint: все данные из WAL -> основной файл.
        // Достаточно одного TRUNCATE: после него WAL уже обнулён, а при BUSY
        // финальный checkpoint всё равно выполнит sqlite3_close
        // (FDConnection.Close) - он же освобождает -wal и -shm
        FDConnection.ExecSQL('PRAGMA wal_checkpoint(TRUNCATE)');
    end;
end;

function TAppDatabase.GetConnectionString: string;
begin
    Result := FDConnection.Params.Text;
end;

function TAppDatabase.CreateImportSnapshot: string;
begin
    Result := Data.Database.Migrations.CreateImportSnapshot(
        FDConnection, FDConnection.Params.Database);
end;

end.

