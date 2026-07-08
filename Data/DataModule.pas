unit DataModule;

interface

uses
    System.SysUtils,
    System.Classes,
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
    FireDAC.VCLUI.Wait,
    FireDAC.Phys.SQLiteWrapper.Stat,
    FireDAC.Stan.Param,
    FireDAC.DatS,
    FireDAC.DApt.Intf,
    FireDAC.DApt,
    Data.DB,
    FireDAC.Comp.DataSet,
    FireDAC.Comp.Client,
    System.IOUtils,
    VCL.Forms,
    VCL.Dialogs,
    Winapi.Windows,
    FireDAC.Comp.ScriptCommands,
    FireDAC.Stan.Util,
    FireDAC.Comp.Script,
    SnippetRepository,
    UserRepository,
    TagRepository,
    CategoryRepository,
    System.ImageList,
    Vcl.ImgList,
    Vcl.Controls,
    System.Actions,
    Vcl.ActnList,
    Vcl.Imaging.pngimage,
    Vcl.VirtualImageList,
    Vcl.BaseImageCollection,
    Vcl.ImageCollection,
    FireDAC.ConsoleUI.Wait,
    FireDAC.Comp.UI, System.Notification;

type
    TDataModuleCommon = class(TDataModule)
        FDConnection: TFDConnection;
        TFDPhysSQLiteDriverLink: TFDPhysSQLiteDriverLink;
        FDQuery: TFDQuery;
        FDManager: TFDManager;
        FDGUIxWaitCursor: TFDGUIxWaitCursor;
        procedure DataModuleCreate(Sender: TObject);
        procedure DataModuleDestroy(Sender: TObject);
    private
        FSnippetRepository: TSnippetRepository;
        FUserRepository: TUserRepository;
        FTagRepository: TTagRepository;
        FCategoryRepository: TCategoryRepository;
        function LoadSQLFromResource(const ResourceName: string): string;
        procedure InitializeDatabase(Connection: TFDConnection; Filename: string);
        procedure ApplyPRAGMA;
    public
        procedure CloseDatabase;
        procedure CreateDatabase(Filename: string);
        procedure OpenDatabase(Filename: string);
        procedure UnlockDatabase(const Password: string);
        procedure FlushToDisk;

        property SnippetRepository: TSnippetRepository read FSnippetRepository;
        property UserRepository: TUserRepository read FUserRepository;
        property TagRepository: TTagRepository read FTagRepository;
        property CategoryRepository: TCategoryRepository read FCategoryRepository;
    end;

var
    DataModuleCommon: TDataModuleCommon;

implementation

uses
    MainFormUI,
    AppStateManager;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

procedure TDataModuleCommon.CloseDatabase;
begin
    FDConnection.Close;
    TStateMgr.Instance.CloseDatabase;
    FlushToDisk;
end;

procedure TDataModuleCommon.CreateDatabase(Filename: string);
var
    FS: TFileStream;
begin
    FDConnection.Close;

    if TFile.Exists(Filename) then
    begin
        Application.NormalizeTopMosts;
        try
            if MessageBox(Application.Handle, PChar('Такой файл уже существует. Заменить его новой базой данных?'), PChar('База данных существует'), MB_YESNO or MB_ICONQUESTION) = IDNO then
                Exit;

            try
                FS := TFileStream.Create(Filename, fmCreate);
                try
                finally
                    FS.Free;
                end;
            except
                on E: Exception do
                begin
                    MessageBox(Application.Handle, PChar('Невозможно создать базу данных по указанному пути:'#13#10 + E.Message), PChar('Ошибка доступа'), MB_OK or MB_ICONERROR);
                    Exit;
                end;
            end;

            InitializeDatabase(Self.FDConnection, Filename);
            TStateMgr.Instance.CreateDatabase;
        finally
            Application.RestoreTopMosts;
        end;
    end
    else
    begin
        try
            InitializeDatabase(Self.FDConnection, Filename);
        except
            on E: Exception do
            begin
                MessageBox(Application.Handle, PChar('Не удалось создать базу данных:'#13#10#13#10 + E.Message), PChar('Ошибка инициализации'), MB_OK or MB_ICONERROR);
                Exit;
            end;
        end;
    end;
end;

procedure TDataModuleCommon.DataModuleCreate(Sender: TObject);
begin
    // Отключаем автоматическое появление курсора crSQLWait
    FDManager.ResourceOptions.SilentMode := True;
    FDConnection.Params.Database := '';
    //System.IOUtils.TPath.GetDirectoryName(Application.ExeName) + '\snippets.sqlite';
    FSnippetRepository := TSnippetRepository.Create(FDConnection);
    FUserRepository := TUserRepository.Create(FDConnection);
    FTagRepository := TTagRepository.Create(FDConnection);
    FCategoryRepository := TCategoryRepository.Create(FDConnection);
end;

procedure TDataModuleCommon.DataModuleDestroy(Sender: TObject);
begin
    FSnippetRepository.Free;
    FUserRepository.Free;
    FTagRepository.Free;
    FCategoryRepository.Free;
end;

procedure TDataModuleCommon.InitializeDatabase(Connection: TFDConnection; Filename: string);
var
    FDScript: TFDScript;
begin
    Connection.Close;
    Connection.Params.Clear;
    Connection.DriverName := 'SQLite';
    Connection.Params.Database := Filename;
    // Явно указываем, что клиентский интерфейс использует UTF-8
    Connection.Params.Add('CharacterSet=utf8');
    Connection.Connected := True;

    FDScript := TFDScript.Create(nil);
    try
        FDScript.Connection := Connection;
        FDScript.SQLScripts.Add;
        FDScript.SQLScripts[0].SQL.Add(LoadSQLFromResource('SCHEMA_INIT_SQL'));
        FDScript.SQLScripts[0].SQL.Add(LoadSQLFromResource('SCHEMA_SEED_SQL'));
        FDScript.ExecuteAll;
    finally
        FDScript.Free;
    end;

    Connection.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'');');

    ApplyPRAGMA;
end;

function TDataModuleCommon.LoadSQLFromResource(const ResourceName: string): string;
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

procedure TDataModuleCommon.OpenDatabase(Filename: string);
begin
    if not TFile.Exists(Filename) then
        raise Exception.Create('Файл базы данных не существует: ' + Filename);

    FDConnection.Close;
    FDConnection.Params.Clear;
    FDConnection.DriverName := 'SQLite';
    FDConnection.Params.Database := Filename;
    FDConnection.LoginPrompt := False;

    var Q := TFDQuery.Create(nil);
    try
//    FDConnection.Connected := True;
        Q.Connection := FDConnection;
//    Q.SQL.Text := 'PRAGMA cipher_version';
//    Q.Open;
//    ShowMessage(Q.Fields[0].AsString);
    finally
        Q.Free;
    end;

    try
        FDConnection.Connected := True;

        // ❗ ВАЖНО: пока НЕ выполняем PRAGMA key
        // Мы не знаем, зашифрована БД или нет

        ApplyPRAGMA;
        TStateMgr.Instance.OpenDatabase;

    except
        on E: Exception do
        begin
            FDConnection.Close;
            raise Exception.Create('Не удалось открыть базу данных:'#13#10 + E.Message);
        end;
    end;
end;

procedure TDataModuleCommon.UnlockDatabase(const Password: string);
begin
    if Password = '' then
        Exit;

    FDConnection.ExecSQL('PRAGMA key = ''' + StringReplace(Password, '''', '''''', [rfReplaceAll]) + '''');

    // Проверка, что ключ подошёл
    try
        FDConnection.ExecSQL('SELECT count(*) FROM sqlite_master');
    except
        on E: Exception do
            raise Exception.Create('Неверный пароль или база не зашифрована');
    end;
end;

procedure TDataModuleCommon.ApplyPRAGMA;
begin
    FDConnection.ExecSQL('PRAGMA foreign_keys = ON;');
    FDConnection.ExecSQL('PRAGMA journal_mode = WAL;');
    FDConnection.ExecSQL('PRAGMA synchronous = NORMAL;');
    FDConnection.ExecSQL('PRAGMA temp_store = MEMORY;');
    FDConnection.ExecSQL('PRAGMA recursive_triggers = OFF;');
    FDConnection.ExecSQL('PRAGMA busy_timeout = 5000;');
    FDConnection.ExecSQL('PRAGMA cache_size = -20000;');
end;

procedure TDataModuleCommon.FlushToDisk;
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

