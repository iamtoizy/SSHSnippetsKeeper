unit uDataModule;

interface

uses
    System.SysUtils, System.Classes, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
    FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.SQLite,
    FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs, FireDAC.VCLUI.Wait, FireDAC.Phys.SQLiteWrapper.Stat,
    FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet, FireDAC.Comp.Client,
    System.IOUtils, VCL.Forms, VCL.Dialogs, Winapi.Windows, FireDAC.Comp.ScriptCommands, FireDAC.Stan.Util, FireDAC.Comp.Script,
    Category, VCL.ComCtrls, SnippetRepository, UserRepository, TagRepository;

type
    TDataModuleCommon = class(TDataModule)
        FDConnection: TFDConnection;
        TFDPhysSQLiteDriverLink: TFDPhysSQLiteDriverLink;
        FDQuery: TFDQuery;
        procedure DataModuleCreate(Sender: TObject);
        procedure DataModuleDestroy(Sender: TObject);
    private
        FCategories: TArray<TCategoryDTO>;
        FSnippetRepository: TSnippetRepository;
        FUserRepository: TUserRepository;
        FTagRepository: TTagRepository;
        function LoadSQLFromResource(const ResourceName: string): string;
        procedure InitializeDatabase(Connection: TFDConnection; Filename: string);
        function LoadCategories: TArray<TCategoryDTO>;
    public
        procedure CloseDatabase;
        procedure CreateDatabase(Filename: string);
        procedure OpenDatabase(Filename: string);
        procedure BuildTree(Tree: TTreeView);
        property Categories: TArray<TCategoryDTO> read FCategories write FCategories;
        property SnippetRepository: TSnippetRepository read FSnippetRepository write FSnippetRepository;
        property UserRepository: TUserRepository read FUserRepository write FUserRepository;
        property TagRepository: TTagRepository read FTagRepository write FTagRepository;
    end;

var
    DataModuleCommon: TDataModuleCommon;

implementation

{ TODO : Переписать на отдельные классы }
{ TODO : FDConnection.ExecSQL('PRAGMA foreign_keys = ON;'); // ОБЯЗАТЕЛЬНО! И другие PRAGMA }

uses
    System.Generics.Collections
    ;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

procedure TDataModuleCommon.CloseDatabase;
begin
    FDConnection.Close;
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
            if MessageBox(
                Application.Handle,
                PChar('Такой файл уже существует. Заменить его новой базой данных?'),
                PChar('База данных существует'),
                MB_YESNO or MB_ICONQUESTION) = IDNO then Exit;

            // Проверяем, можем ли мы записать в этот путь (и заодно удалим старый файл)
            try
                FS := TFileStream.Create(Filename, fmCreate);
                FS.Free;
            except
                on E: Exception do
                begin
                    MessageBox(Application.Handle, PChar('Невозможно создать базу данных по указанному пути:'#13#10 + E.Message), PChar('Ошибка доступа'), MB_OK or MB_ICONERROR);
                    Exit;
                end;
            end;

            // Теперь инициализируем новую базу
            InitializeDatabase(Self.FDConnection, Filename);
        finally
            Application.RestoreTopMosts;
        end;
    end
    else
    begin
        // Файла нет - просто создаём
        try
            InitializeDatabase(Self.FDConnection, Filename);
        except
            on E: Exception do
            begin
                MessageBox(
                    Application.Handle,
                    PChar('Не удалось создать базу данных:'#13#10#13#10 + E.Message),
                    PChar('Ошибка инициализации'),
                    MB_OK or MB_ICONERROR);
                Exit; //raise
            end;
        end;
    end;
end;

procedure TDataModuleCommon.DataModuleCreate(Sender: TObject);
begin
    FDConnection.Params.Database := System.IOUtils.TPath.GetDirectoryName(Application.ExeName) + '\snippets.sqlite';
    FSnippetRepository := TSnippetRepository.Create(FDConnection);
    FUserRepository := TUserRepository.Create(FDConnection);
    FTagRepository := TTagRepository.Create(FDConnection);
end;

procedure TDataModuleCommon.DataModuleDestroy(Sender: TObject);
begin
    FSnippetRepository.Free;
    FUserRepository.Free;
    FTagRepository.Free;
end;

procedure TDataModuleCommon.InitializeDatabase(Connection: TFDConnection; Filename: string);
const
    CreateUserSQL = 'INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'');';
var
    FDScript: TFDScript;
begin
    Connection.Close;
    Connection.Params.Clear;
    Connection.DriverName := 'SQLite';
    Connection.Params.Database := Filename;
    Connection.Connected := True;

    FDScript := TFDScript.Create(nil);
    try
        FDScript.Connection := Connection;
        FDScript.SQLScripts.Add;
        FDScript.SQLScripts[0].SQL.Add(LoadSQLFromResource('SCHEMA_INIT_SQL'));
        FDScript.ExecuteAll;
    finally
        FDScript.Free;
    end;

    Connection.ExecSQL('INSERT OR IGNORE INTO users (id, name) VALUES (1, ''Local User'');');
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
            ShowMessage(Result);
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

    try
        FDConnection.Connected := True;

        // Обязательные PRAGMA
        FDConnection.ExecSQL('PRAGMA foreign_keys = ON;');

        // Дополнительные PRAGMA (по желанию)
        // FDConnection.ExecSQL('PRAGMA journal_mode = WAL;'); // Улучшает параллельность
        // FDConnection.ExecSQL('PRAGMA synchronous = NORMAL;'); // Баланс между безопасностью и скоростью
        LoadCategories;

    except
        on E: Exception do
        begin
            FDConnection.Close;
            raise Exception.Create('Не удалось открыть базу данных:'#13#10 + E.Message);
        end;
    end;
end;

function TDataModuleCommon.LoadCategories: TArray<TCategoryDTO>;
var
    Query: TFDQuery;
    List: TList<TCategoryDTO>;
    Cat: TCategoryDTO;
begin
    List := TList<TCategoryDTO>.Create;
    Query := TFDQuery.Create(nil);
    try
        Query.Connection := FDConnection;
        Query.Open('SELECT id, name, parent_id FROM snippet_categories ORDER BY name');

        while not Query.Eof do
        begin
            Cat.ID := Query.FieldByName('id').AsInteger;
            Cat.Name := Query.FieldByName('name').AsString;
            Cat.ParentID := Query.FieldByName('parent_id').AsInteger;

            List.Add(Cat);
            Query.Next;
        end;

        FCategories := List.ToArray;
        Result := FCategories;
    finally
        List.Free;
        Query.Free;
    end;
end;

procedure TDataModuleCommon.BuildTree(Tree: TTreeView);
var
    CatMap: TDictionary<Integer, TList<TCategoryDTO>>;
    RootNodes: TList<TCategoryDTO>;

    procedure AddNodes(ParentNode: TTreeNode; ParentID: Integer);
    var
        i: Integer;
        Node: TTreeNode;
        List: TList<TCategoryDTO>;
    begin
        if CatMap.TryGetValue(ParentID, List) then
            for i := 0 to List.Count - 1 do
            begin
                Node := Tree.Items.AddChild(ParentNode, List[i].Name);
                Node.Data := Pointer(List[i].ID); // Сохраняем ID в Data
                AddNodes(Node, List[i].ID);
            end;
    end;

var
    Cat: TCategoryDTO;
begin
  // Создаём словарь parent_id -> список детей
    CatMap := TDictionary<Integer, TList<TCategoryDTO>>.Create;
    RootNodes := TList<TCategoryDTO>.Create;
    try
        for Cat in FCategories do
        begin
            if Cat.ParentID = 0 then
                RootNodes.Add(Cat)
            else
            begin
                if not CatMap.ContainsKey(Cat.ParentID) then
                    CatMap.Add(Cat.ParentID, TList<TCategoryDTO>.Create);
                CatMap[Cat.ParentID].Add(Cat);
            end;
        end;

        Tree.Items.BeginUpdate;
        try
            Tree.Items.Clear;
            for Cat in RootNodes do
            begin
                var Node := Tree.Items.Add(nil, Cat.Name);
                Node.Data := Pointer(Cat.ID);
                AddNodes(Node, Cat.ID);
            end;
        finally
            Tree.Items.EndUpdate;
        end;

    finally
        for var List: TList<TCategoryDTO> in CatMap.Values do
            List.Free;
        CatMap.Free;
        RootNodes.Free;
    end;
end;

end.
