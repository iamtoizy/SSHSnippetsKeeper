program TabbySnipetsKeeper;

{$R '000_schema_init.res' '..\res\sql\000_schema_init.rc'}

uses
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
  MainFormUI in 'Units\UI\MainFormUI.pas' {MainForm},
  JSONSerializer in 'Units\JSONSerializer.pas',
  uSettings in 'Units\uSettings.pas',
  uDataModule in 'Units\uDataModule.pas' {DataModuleCommon: TDataModule},
  Snippet in 'Units\Entities\Snippet.pas',
  Host in 'Units\Entities\Host.pas',
  SnippetRepository in 'Units\Repositories\SnippetRepository.pas',
  Tag in 'Units\Entities\Tag.pas',
  HostRepository in 'Units\Repositories\HostRepository.pas',
  Category in 'Units\Entities\Category.pas',
  CategoryRepository in 'Units\Repositories\CategoryRepository.pas',
  UserRepository in 'Units\Repositories\UserRepository.pas',
  User in 'Units\Entities\User.pas',
  TagRepository in 'Units\Repositories\TagRepository.pas';

{$R *.res}

begin
    Application.Initialize;
    Application.MainFormOnTaskbar := True;
//    Application.Title := 'Tabby Snippets Keeper';
    Application.Title := 'Tabby Snippets Keeper';
  TStyleManager.TrySetStyle('Onyx Blue');
    Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TDataModuleCommon, DataModuleCommon);
  Application.Run;
end.
