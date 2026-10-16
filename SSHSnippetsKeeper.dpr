program SSHSnippetsKeeper;

// TODO: [Feature] �������� ������� ������
// TODO: [Feature] ������� ������� ��� ���������� ����� ��������
// TODO: [Refactor] �������� ���������� ��� ����-������������
// TODO: [Feature] �������� ����-�����

{$R '000_schema_init.res' 'Database\Schema\000_schema_init.rc'}
{$R *.dres}

{$IFDEF RELEASE}
  // �������� ������������ ����������� ���� ������������ (�������� "�������" ���, �������� ����� � ����������).
  // ������ ��������� Project -> Options -> Delphi Compiler -> Compiling -> Optimization
  {$OPTIMIZATION ON}

  // ��������� ��������� ���������� ���������� (������ �����, ����� ����������) ������ ���������������� ������.
  // ������ ��������� Project -> Options -> Delphi Compiler -> Compiling -> Debug information
  {$DEBUGINFO OFF}

  // ��������� ���������� ��������� �������� (���� ��������� ���������� ������ ��������/�������).
  // ��� ����� �������� �� ������ �������� �������� ����������, �� ������ exe ����������.
  // ������ ��������� Project -> Options -> Delphi Compiler -> Compiling -> Local symbols
  {$LOCALSYMBOLS OFF}

  // ��������� ��������� ���������� � ������������ ������� �������� (Symbol Reference Info).
  // ��� ���������� ����� IDE ��� ��������� �� ���� (Ctrl+Click), � �������� exe ��� �� �����.
  {$DEFINITIONINFO OFF}

  // ����� ���������� RTTI (Run-Time Type Information).
  // ���������� ����������/��������� "�����������" ���������� � ����� � �������, �������
  // ��������������, �� ������� ����� � ����� ���� �� ���������� � �� ������������.
  {$WEAKLINKRTTI ON}

  // ������ ��������� ��������� ������������ RTTI ��� �������, ������� � �����
  // ��� ���� ������� � ������� (���� ������ ��� ���� �� ��������� ��������� ����� {$RTTI EXPLICIT...}).
  // � ����� ������� Delphi RTTI ������������ �� ��������� ��� ����� ������ � ������ ��������� exe.
  // ��� ��������� - ������� ���������� ��� ������������ "���������" ����������.
  {$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$ENDIF}

uses
  {$IFDEF DEBUG}
  FastMM5,
  {$ENDIF }
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
  Vcl.StdCtrls,
  Winapi.Windows,
  System.IOUtils,
  System.SysUtils,
  MainFormUI in 'UI\Forms\MainFormUI.pas' {MainForm},
  JSONSerializer in 'ThirdParty\JSONSerializer.pas',
   Common.Settings in 'Common\Common.Settings.pas',
   Data.Database in 'Data\Data.Database.pas' {AppDatabase: TDataModule},
   Core.Entities.Snippet in 'Core\Entities\Core.Entities.Snippet.pas',
  SnippetRepository in 'Data\Repositories\SnippetRepository.pas',
   Core.Entities.Tag in 'Core\Entities\Core.Entities.Tag.pas',
   Core.Entities.Category in 'Core\Entities\Core.Entities.Category.pas',
  CategoryRepository in 'Data\Repositories\CategoryRepository.pas',
  UserRepository in 'Data\Repositories\UserRepository.pas',
   Core.Entities.User in 'Core\Entities\Core.Entities.User.pas',
  TagRepository in 'Data\Repositories\TagRepository.pas',
  RepositoryBase in 'Data\RepositoryBase.pas',
  ArrayHelper in 'ThirdParty\ArrayHelper.pas',
  WindowHelper in 'Automation\WindowHelper.pas',
  AddEditSnippetUI in 'UI\Forms\AddEditSnippetUI.pas' {AddEditSnippetForm},
  HintTextEdit in 'UI\Controls\HintTextEdit.pas',
  HintTextMemo in 'UI\Controls\HintTextMemo.pas',
  BaseFormUI in 'UI\Forms\BaseFormUI.pas',
  AppStateManager in 'UI\Services\AppStateManager.pas',
  UI.Helpers in 'UI\Helpers\UI.Helpers.pas',
  UI.TreeViewSearchHelper in 'UI\Helpers\UI.TreeViewSearchHelper.pas',
   SnippetViewData in 'UI\ViewModels\SnippetViewData.pas',
   PresetData in 'UI\ViewModels\PresetData.pas',
  MacroActions in 'MacroEngine\MacroActions.pas',
  MacroThread in 'MacroEngine\MacroThread.pas',
  MacroEngine in 'MacroEngine\MacroEngine.pas',
  WindowMonitor in 'Automation\WindowMonitor.pas',
  ProcessProfile in 'Automation\ProcessProfile.pas',
  ChooseTerminalWindowUI in 'UI\Forms\ChooseTerminalWindowUI.pas' {ChooseTerminalWindow},
  InputFormUI in 'UI\Forms\InputFormUI.pas' {InputForm},
  MacroInputTypes in 'MacroEngine\MacroInputTypes.pas',
  TagEditorUI in 'UI\Forms\TagEditorUI.pas' {TagEditorForm},
  WorkspaceManagerUI in 'UI\Forms\WorkspaceManagerUI.pas' {WorkspaceManagerForm},
  SynThemeAdapter in 'UI\Controls\SynThemeAdapter.pas',
  CustomBashSyn in 'UI\Controls\CustomBashSyn.pas',
  BashCompletionEngine in 'Core\BashCompletionEngine.pas',
  CommonConsts in 'Common\CommonConsts.pas',
  CommonHelpers in 'Common\CommonHelpers.pas',
  SnippetService in 'Core\Services\SnippetService.pas',
  TagService in 'Core\Services\TagService.pas',
  CategoryService in 'Core\Services\CategoryService.pas',
  UserService in 'Core\Services\UserService.pas',
  Core.Interfaces in 'Core\Core.Interfaces.pas',
  SnippetRunner in 'UI\Controllers\SnippetRunner.pas',
  QuickSearchFormUI in 'UI\Forms\QuickSearchFormUI.pas' {QuickSearchForm},
  GlobalHotkeyManager in 'UI\Controllers\GlobalHotkeyManager.pas',
  TrackBarEx in 'UI\Controls\TrackBarEx.pas',
  AI.Service in 'UI\Services\AI.Service.pas',
  AI.TextCleaner in 'UI\Services\AI.TextCleaner.pas',
  AISettingsFormUI in 'UI\Forms\AISettingsFormUI.pas' {AISettingsForm},
  SecurityScanner in 'Core\Services\SecurityScanner.pas',
  PasswordService in 'Core\Services\PasswordService.pas',
  PasswordGenFormUI in 'UI\Forms\PasswordGenFormUI.pas' {PasswordGenForm},
  Core.AppContext in 'Core\Core.AppContext.pas',
  UI.StateLoader in 'UI\Helpers\UI.StateLoader.pas',
  UI.HoverHelpManager in 'UI\Helpers\UI.HoverHelpManager.pas',
  CustomHelpFormUI in 'UI\Forms\CustomHelpFormUI.pas' {CustomHelpForm},
  UI.Services.MessagesHandler in 'UI\Services\UI.Services.MessagesHandler.pas',
  CronService in 'Core\Services\CronService.pas',
  CronGenFormUI in 'UI\Forms\CronGenFormUI.pas' {CronGenForm},
  EpochService in 'Core\Services\EpochService.pas',
  EpochConverterFormUI in 'UI\Forms\EpochConverterFormUI.pas' {EpochConverterForm},
  NetworkCalcService in 'Core\Services\NetworkCalcService.pas',
  NetworkFormUI in 'UI\Forms\NetworkFormUI.pas' {NetworkForm},
  ChmodService in 'Core\Services\ChmodService.pas',
  ChmodFormUI in 'UI\Forms\ChmodFormUI.pas' {ChmodForm},
  ArchiveBuilderFormUI in 'UI\Forms\ArchiveBuilderFormUI.pas' {ArchiveBuilderForm},
  SettingsFormUI in 'UI\Forms\SettingsFormUI.pas' {SettingsForm},
  HotkeyService in 'Core\Services\HotkeyService.pas',
  Bcrypt in 'ThirdParty\Bcrypt.pas',
  Core.MarkdownExporter in 'Core\Core.MarkdownExporter.pas',
  Core.MarkdownImporter in 'Core\Core.MarkdownImporter.pas',
  LocalAIService in 'Core\LocalAIService.pas';

{$R *.res}

var
    hMutex: THandle;
    FoundWnd: HWND;
    SettingsManager: ISettingsManager;
    WindowHelper: TWindowHelper;
    AppContext: IAppContext;
    ErrorHandler: IUIMessagesHandler;

// Callback-�������, ������� ���������� ��� ���� � �������
function EnumWindowsProc(Wnd: HWND; lParam: LParam): BOOL; stdcall;
begin
    Result := True; // ���������� ������� �� ���������

    // ���������, ���� �� � ������������ ���� ���� ���������� ��������
    if GetProp(Wnd, PChar(UNIQUE_APP_STR)) <> 0 then
    begin
        // �� ����� ���� ������ �����!
        FoundWnd := Wnd;
        Result := False; // ��������� �������
    end;
end;

begin
{$IFDEF DEBUG}
ReportMemoryLeaksOnShutdown := True;
{$ENDIF}

    // ������� �������
    hMutex := CreateMutex(nil, False, PChar(UNIQUE_APP_STR + '_Mutex'));

    if GetLastError = ERROR_ALREADY_EXISTS then
    begin
        // ��������� ��� ��������. ���� � ����.
        FoundWnd := 0;
        // ������� EnumWindows ������� EnumWindowsProc ��� ������� ���� �� ������� �����
        EnumWindows(@EnumWindowsProc, 0);

        if FoundWnd <> 0 then
        begin
            // ��������������� � ���������� ������ �����
            if IsIconic(FoundWnd) then
                ShowWindow(FoundWnd, SW_RESTORE);

            // ������ SetForegroundWindow �� ����������� ��-�� ������ Windows (Focus Stealing).
            // ����� ������� ��� ������, ������� "�����������" ��� ����� � ������ ���� ����.
            SetForegroundWindow(FoundWnd);
        end;

        // ��������� ������ �����
        Exit;
    end;

    SettingsManager := TSettingsManager.Create;
    SettingsManager.Load;

    // --- ���������� �������� ����� �� �������� ���� ---
    var GlobalLang: string := SettingsManager.Data.CurrentLanguage;
    if GlobalLang = '' then
        GlobalLang := 'ru';

    TUIStateLoader.LoadLanguageFile(ResolvePath('Translation\ui-texts.' + GlobalLang + '.json'));
    // ---------------------------------------------------------

    WindowHelper := TWindowHelper.Create(SettingsManager);
    ErrorHandler := TUIMessagesHandler.Create;

    Application.Initialize;
    Application.MainFormOnTaskbar := True;
//    TStyleManager.TrySetStyle('Glow');
//    TStyleManager.UseParentPaintBuffers := True;
    Application.Title := 'SSH Snippets Keeper';
    Application.CreateForm(TAppDatabase, AppDatabase);
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TQuickSearchForm, QuickSearchForm);
  Application.CreateForm(TCustomHelpForm, CustomHelpForm);
  Application.CreateForm(TInputForm, InputForm);
  //-----------------------------------
    AppContext := TAppContext.Create(
        AppDatabase,               // ��������� IDatabaseManager
        AppDatabase.FDConnection,  // ������ �� ��������� �����������
        SettingsManager,           // ���������
        WindowHelper,              //
        ErrorHandler               //
    );
    //-----------------------------------
    QuickSearchForm.Initialize(AppContext);
    MainForm.LockDrawing;
    try
        MainForm.Initialize(AppContext);
    finally
        MainForm.UnlockDrawing;
    end;
    MainForm.Show;

    Application.Run;

    AppContext := nil;
    SettingsManager := nil;

    // ����������� ������� ��� �������� ���������
    if hMutex <> 0 then
    begin
        ReleaseMutex(hMutex);
        CloseHandle(hMutex);
    end;
end.

