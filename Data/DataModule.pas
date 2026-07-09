unit DataModule;

interface

uses
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
    // Твои модули:
    SnippetRepository,
    CategoryRepository,
    TagRepository,
    UserRepository,
    SnippetService,
    CategoryService,
    TagService,
    UserService, FireDAC.VCLUI.Wait
    ;

type
    TDataModuleCommon = class(TDataModule)
        // ВАЖНО: Эти поля управляются Delphi (из .dfm). НЕ удаляй их!
        FDConnection: TFDConnection;
        FDQuery: TFDQuery;
        FDManager: TFDManager;
    FDGUIxWaitCursor: TFDGUIxWaitCursor;
    FDPhysSQLiteDriverLink: TFDPhysSQLiteDriverLink;

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
    public
        // Отдаем наружу ТОЛЬКО сервисы
        property SnippetService: TSnippetService read FSnippetService;
        property CategoryService: TCategoryService read FCategoryService;
        property TagService: TTagService read FTagService;
        property UserService: TUserService read FUserService;
    end;

var
    DataModuleCommon: TDataModuleCommon;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

procedure TDataModuleCommon.DataModuleCreate(Sender: TObject);
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

procedure TDataModuleCommon.DataModuleDestroy(Sender: TObject);
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

end.

