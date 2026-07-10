unit DataModule;

interface

uses
    Winapi.Windows,
    System.SysUtils,
    System.Classes,
    FireDAC.Comp.Client,
    FireDAC.Stan.Intf,
    FireDAC.Stan.Option,
    FireDAC.Stan.Error,
    FireDAC.UI.Intf,
    FireDAC.Phys.Intf,
    FireDAC.Stan.Def,
    FireDAC.Stan.Pool,
    FireDAC.Stan.Async,
    FireDAC.Phys,
    FireDAC.Phys.SQLite,
    FireDAC.Phys.SQLiteDef,
    FireDAC.Stan.ExprFuncs,
    FireDAC.Phys.SQLiteWrapper.Stat,
    FireDAC.Stan.Param,
    FireDAC.DatS,
    FireDAC.DApt.Intf,
    FireDAC.DApt,
    FireDAC.ConsoleUI.Wait,
    FireDAC.Comp.UI,
    Data.DB,
    FireDAC.Comp.DataSet,
    SnippetRepository,
    CategoryRepository,
    TagRepository,
    UserRepository,
    SnippetService,
    CategoryService,
    TagService,
    UserService,
    FireDAC.VCLUI.Wait,
    FireDAC.Comp.ScriptCommands,
    FireDAC.Stan.Util,
    FireDAC.Comp.Script;

type
    TAppDatabase = class(TDataModule)
        FDConnection: TFDConnection;
        FDQuery: TFDQuery;
        FDManager: TFDManager;
        FDGUIxWaitCursor: TFDGUIxWaitCursor;
        FDPhysSQLiteDriverLink: TFDPhysSQLiteDriverLink;
        FDScript: TFDScript;
        procedure DataModuleCreate(Sender: TObject);
        procedure DataModuleDestroy(Sender: TObject);
    private
        // 1. Репозитории (Data слой)
        FSnippetRepo: TSnippetRepository;
        FCategoryRepo: TCategoryRepository;
        FTagRepo: TTagRepository;
        FUserRepo: TUserRepository;

        // 2. Сервисы (Слой бизнес-логики)
        FSnippetService: TSnippetService;
        FCategoryService: TCategoryService;
        FTagService: TTagService;
        FUserService: TUserService;
        procedure InitializeDatabase(Filename: string);
        procedure ApplyPRAGMA;
        procedure FlushToDisk;
        function LoadSQLFromResource(const ResourceName: string): string;
    public
        procedure CreateDatabase(Filename: string);
        procedure CloseDatabase;

        // Отдаем наружу ТОЛЬКО сервисы
        property SnippetService: TSnippetService read FSnippetService;
        property CategoryService: TCategoryService read FCategoryService;
        property TagService: TTagService read FTagService;
        property UserService: TUserService read FUserService;
    end;

var
    AppDatabase: TAppDatabase;

implementation

uses
    System.IOUtils,
    VCL.Forms;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

procedure TAppDatabase.DataModuleCreate(Sender: TObject);
begin
    // 1. Создаем репозитории, передавая им визуальный FDConnection
    FSnippetRepo := TSnippetRepository.Create(FDConnection);
    FCategoryRepo := TCategoryRepository.Create(FDConnection);
    FTagRepo := TTagRepository.Create(FDConnection);
    FUserRepo := TUserRepository.Create(FDConnection);

    // 2. Создаем Сервисы. Каждый получает только те репозитории, которые ему нужны.
    FSnippetService := TSnippetService.Create(FSnippetRepo, FCategoryRepo, FTagRepo);
    FCategoryService := TCategoryService.Create(FCategoryRepo);
    FTagService := TTagService.Create(FTagRepo);
    FUserService := TUserService.Create(FUserRepo);
end;

procedure TAppDatabase.DataModuleDestroy(Sender: TObject);
begin
    // Освобождаем сервисы
    FTagService.Free;
    FCategoryService.Free;
    FSnippetService.Free;

    // Освобождаем репозитории
    FUserRepo.Free;
    FTagRepo.Free;
    FCategoryRepo.Free;
    FSnippetRepo.Free;
end;

procedure TAppDatabase.CreateDatabase(Filename: string);
var
    FS: TFileStream;
begin
    FDConnection.Close;
    FDConnection.Connected := False;
    FDConnection.Params.Values['Database'] := FileName;
    FDConnection.Connected := True;
    InitializeDatabase(Filename);
end;

procedure TAppDatabase.InitializeDatabase(Filename: string);
begin
    CloseDatabase;

    FDConnection.Params.Database := Filename;
    FDConnection.Params.Add('DriverID=SQLite');
    FDConnection.Params.Add('CharacterSet=utf8');
    FDConnection.Connected := True;

    FDScript.Connection := FDConnection;
    FDScript.SQLScripts.Clear;

    // Добавляем скрипты
    with FDScript.SQLScripts.Add do
        SQL.Text :=
            LoadSQLFromResource('SCHEMA_INIT_SQL') +
            LoadSQLFromResource('SCHEMA_SEED_SQL');

    try
        FDScript.ExecuteAll;
    except
        on E: Exception do
            raise Exception.Create('Ошибка при выполнении SQL-скриптов: ' + E.Message);
    end;

    FDConnection.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'');');
    ApplyPRAGMA;
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
    FDConnection.ExecSQL('PRAGMA busy_timeout = 5000;');
    FDConnection.ExecSQL('PRAGMA cache_size = -20000;');
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
        // Принудительный checkpoint: все данные из WAL → основной файл
        FDConnection.ExecSQL('PRAGMA wal_checkpoint(TRUNCATE)');
        // Освобождаем -wal и -shm файлы
        FDConnection.ExecSQL('PRAGMA wal_checkpoint(PASSIVE)');
    end;
end;

end.

