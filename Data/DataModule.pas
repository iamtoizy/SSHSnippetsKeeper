unit DataModule;

interface

uses
    Winapi.Windows,
    System.SysUtils,
    System.Classes,
    FireDAC.Comp.Client,
    FireDAC.Stan.Intf,
    FireDAC.Phys.SQLite,
    FireDAC.Comp.UI,
    Data.DB,
    SnippetRepository,
    CategoryRepository,
    TagRepository,
    UserRepository,
    SnippetService,
    CategoryService,
    TagService,
    UserService,
    FireDAC.Comp.Script,
    Core.Interfaces,
    FireDAC.Stan.Option,
    FireDAC.Stan.Param,
    FireDAC.Stan.Error,
    FireDAC.DatS,
    FireDAC.Phys.Intf,
    FireDAC.DApt.Intf,
    FireDAC.Stan.Async,
    FireDAC.DApt,
    FireDAC.UI.Intf,
    FireDAC.Stan.Def,
    FireDAC.Phys,
    FireDAC.Stan.Pool,
    FireDAC.Phys.SQLiteDef,
    FireDAC.Stan.ExprFuncs,
    FireDAC.VCLUI.Wait,
    FireDAC.Phys.SQLiteWrapper.Stat,
    FireDAC.Comp.ScriptCommands,
    FireDAC.Stan.Util,
    FireDAC.Comp.DataSet;

type
    TAppDatabase = class(TDataModule, IDatabaseManager)
        FDConnection: TFDConnection;
        FDQuery: TFDQuery;
        FDManager: TFDManager;
        FDGUIxWaitCursor: TFDGUIxWaitCursor;
        FDPhysSQLiteDriverLink: TFDPhysSQLiteDriverLink;
        FDScript: TFDScript;
        procedure DataModuleCreate(Sender: TObject);
        procedure DataModuleDestroy(Sender: TObject);
    private
        // Сервисы (Слой бизнес-логики)
        FSnippetService: ISnippetService;
        FCategoryService: ICategoryService;
        FTagService: ITagService;
        FUserService: IUserService;
        //
        procedure InitializeDatabase(Filename: string);
        procedure ApplyPRAGMA;
        procedure FlushToDisk;
        function LoadSQLFromResource(const ResourceName: string): string;
    public
        procedure CreateDatabase(const Filename: string);
        procedure OpenDatabase(const Filename: string);
        procedure CloseDatabase;
        function IsConnected: Boolean;

        // Отдаем наружу только сервисы
        property SnippetService: ISnippetService read FSnippetService;
        property CategoryService: ICategoryService read FCategoryService;
        property TagService: ITagService read FTagService;
        property UserService: IUserService read FUserService;
    end;

var
    AppDatabase: TAppDatabase;

implementation

{$R *.dfm}

procedure TAppDatabase.DataModuleCreate(Sender: TObject);
var
    SnippetRepo: ISnippetRepository;
    CategoryRepo: ICategoryRepository;
    TagRepo: ITagRepository;
    UserRepo: IUserRepository;
begin
    // Объекты создаются, но присваиваются переменным типа ИНТЕРФЕЙС.
    // Благодаря этому они удалятся сами при завершении работы приложения.
    //
    // 1. Создаем репозитории
    SnippetRepo := TSnippetRepository.Create(FDConnection);
    CategoryRepo := TCategoryRepository.Create(FDConnection);
    TagRepo := TTagRepository.Create(FDConnection);
    UserRepo := TUserRepository.Create(FDConnection);

    // 2. Создаем сервисы и присваиваем их переменным-интерфейсам
    FSnippetService := TSnippetService.Create(SnippetRepo, CategoryRepo, TagRepo, UserRepo);
    FCategoryService := TCategoryService.Create(CategoryRepo);
    FTagService := TTagService.Create(TagRepo);
    FUserService := TUserService.Create(UserRepo);
end;

procedure TAppDatabase.DataModuleDestroy(Sender: TObject);
begin
//
end;

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
end;

procedure TAppDatabase.InitializeDatabase(Filename: string);
begin
    // Вместо дублирования кода просто вызываем OpenDatabase,
    // который всё подключит и применит PRAGMA
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
            raise Exception.Create('Ошибка при выполнении SQL-скриптов: ' + E.Message);
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

