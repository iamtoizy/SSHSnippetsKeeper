program SSHSnippetsKeeper;

// TODO: [Feature] Редактор горячих клавиш
// TODO: [Feature] Горячая клавиша для повторного ввода сниппета
// TODO: [Refactor] Добавить интерфейсы для юнит-тестирования
// TODO: [Feature] Добавить юнит-тесты

{$R '000_schema_init.res' 'Database\Schema\000_schema_init.rc'}
{$R *.dres}

{$IFDEF RELEASE}
  // Включает максимальную оптимизацию кода компилятором (вырезает "мертвый" код, упрощает циклы и вычисления).
  // Аналог настройки Project -> Options -> Delphi Compiler -> Compiling -> Optimization
  {$OPTIMIZATION ON}

  // Отключает генерацию отладочной информации (номера строк, имена переменных) внутри скомпилированных файлов.
  // Аналог настройки Project -> Options -> Delphi Compiler -> Compiling -> Debug information
  {$DEBUGINFO OFF}

  // Отключает сохранение локальных символов (имен локальных переменных внутри процедур/функций).
  // Без этого отладчик не сможет показать значения переменных, но размер exe уменьшится.
  // Аналог настройки Project -> Options -> Delphi Compiler -> Compiling -> Local symbols
  {$LOCALSYMBOLS OFF}

  // Отключает генерацию информации о перекрестных ссылках символов (Symbol Reference Info).
  // Это информация нужна IDE для навигации по коду (Ctrl+Click), в релизном exe она не нужна.
  {$DEFINITIONINFO OFF}

  // Умное связывание RTTI (Run-Time Type Information).
  // Заставляет компилятор/линковщик "выбрасывать" метаданные о типах и классах, которые
  // скомпилированы, но реально нигде в вашем коде не вызываются и не используются.
  {$WEAKLINKRTTI ON}

  // Жестко отключает генерацию расширенного RTTI для методов, свойств и полей
  // для всех классов в проекте (если только они явно не потребуют обратного через {$RTTI EXPLICIT...}).
  // В новых версиях Delphi RTTI генерируется по умолчанию для всего подряд и сильно раздувает exe.
  // Эта директива - главный инструмент для радикального "похудения" приложения.
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
  Settings in 'Common\Settings.pas',
  DataModule in 'Data\DataModule.pas' {AppDatabase: TDataModule},
  Snippet in 'Core\Entities\Snippet.pas',
  SnippetRepository in 'Data\Repositories\SnippetRepository.pas',
  Tag in 'Core\Entities\Tag.pas',
  Category in 'Core\Entities\Category.pas',
  CategoryRepository in 'Data\Repositories\CategoryRepository.pas',
  UserRepository in 'Data\Repositories\UserRepository.pas',
  User in 'Core\Entities\User.pas',
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
  Core.MarkdownImporter in 'Core\Core.MarkdownImporter.pas';

{$R *.res}

var
    hMutex: THandle;
    FoundWnd: HWND;
    SettingsManager: ISettingsManager;
    WindowHelper: TWindowHelper;
    AppContext: IAppContext;
    ErrorHandler: IUIMessagesHandler;

// Callback-функция, которая перебирает все окна в системе
function EnumWindowsProc(Wnd: HWND; lParam: LParam): BOOL; stdcall;
begin
    Result := True; // Продолжаем перебор по умолчанию

    // Проверяем, есть ли у проверяемого окна наше уникальное свойство
    if GetProp(Wnd, PChar(UNIQUE_APP_STR)) <> 0 then
    begin
        // Мы нашли окно первой копии!
        FoundWnd := Wnd;
        Result := False; // Прерываем перебор
    end;
end;

begin
{$IFDEF DEBUG}
ReportMemoryLeaksOnShutdown := True;
{$ENDIF}

    // Создаем мьютекс
    hMutex := CreateMutex(nil, False, PChar(UNIQUE_APP_STR + '_Mutex'));

    if GetLastError = ERROR_ALREADY_EXISTS then
    begin
        // Программа уже запущена. Ищем её окно.
        FoundWnd := 0;
        // Функция EnumWindows вызовет EnumWindowsProc для каждого окна на рабочем столе
        EnumWindows(@EnumWindowsProc, 0);

        if FoundWnd <> 0 then
        begin
        // Восстанавливаем и показываем первую копию
            if IsIconic(FoundWnd) then
                ShowWindow(FoundWnd, SW_RESTORE);

        // Иногда SetForegroundWindow не срабатывает из-за защиты Windows (Focus Stealing).
        // Чтобы пробить эту защиту, сначала "прикрепляем" наш поток к потоку того окна.
            SetForegroundWindow(FoundWnd);
        end;

        // Завершаем вторую копию
        Exit;
    end;

    SettingsManager := TSettingsManager.Create;
    SettingsManager.Load;

    // --- Глобальная загрузка языка до создания окон ---
    var GlobalLang: string := SettingsManager.Data.CurrentLanguage;
    if GlobalLang = '' then
        GlobalLang := 'ru';

    TUIStateLoader.LoadLanguageFile(ResolvePath('Translation\ui-texts.' + GlobalLang + '.json'));
    // ---------------------------------------------------------

    WindowHelper := TWindowHelper.Create(SettingsManager);
    ErrorHandler := TUIMessagesHandler.Create;

    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    TStyleManager.TrySetStyle('Glow');
    Application.Title := 'SSH Snippets Keeper';
    Application.CreateForm(TAppDatabase, AppDatabase);
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TQuickSearchForm, QuickSearchForm);
  Application.CreateForm(TCustomHelpForm, CustomHelpForm);
  //-----------------------------------
    AppContext := TAppContext.Create(
        AppDatabase,               // Реализует IDatabaseManager
        AppDatabase.FDConnection,  // Ссылка на компонент подключения
        SettingsManager,           // Настройки
        WindowHelper,              //
        ErrorHandler               //
    );
    //-----------------------------------
    QuickSearchForm.Initialize(AppContext);
    MainForm.Initialize(AppContext);
    MainForm.Show;
    Application.CreateForm(TInputForm, InputForm);
    Application.Run;

    AppContext := nil;
    SettingsManager := nil;

    // Освобождаем мьютекс при закрытии программы
    if hMutex <> 0 then
    begin
        ReleaseMutex(hMutex);
        CloseHandle(hMutex);
    end;
end.

