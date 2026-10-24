program SSHSnippetsKeeper;

{$R 'Resources\000_schema_init.res' 'Database\Schema\000_schema_init.rc'}
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
  Core.Shutdown in 'Core\Core.Shutdown.pas',
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
  SnippetHistoryRepository in 'Data\Repositories\SnippetHistoryRepository.pas',
   Core.Entities.Tag in 'Core\Entities\Core.Entities.Tag.pas',
   Core.Entities.Category in 'Core\Entities\Core.Entities.Category.pas',
   Core.Entities.Chain in 'Core\Entities\Core.Entities.Chain.pas',
  CategoryRepository in 'Data\Repositories\CategoryRepository.pas',
  UserRepository in 'Data\Repositories\UserRepository.pas',
   Core.Entities.User in 'Core\Entities\Core.Entities.User.pas',
  TagRepository in 'Data\Repositories\TagRepository.pas',
  ChainRepository in 'Data\Repositories\ChainRepository.pas',
  RepositoryBase in 'Data\RepositoryBase.pas',
  ArrayHelper in 'ThirdParty\ArrayHelper.pas',
  WindowHelper in 'Automation\WindowHelper.pas',
  AddEditSnippetFormUI in 'UI\Forms\AddEditSnippetFormUI.pas' {AddEditSnippetForm},
  HintTextEdit in 'UI\Controls\HintTextEdit.pas',
  HintTextMemo in 'UI\Controls\HintTextMemo.pas',
  BaseFormUI in 'UI\Forms\BaseFormUI.pas',
  UI.Services.AppStateManager in 'UI\Services\UI.Services.AppStateManager.pas',
  UI.AppStatusBar in 'UI\Helpers\UI.AppStatusBar.pas',
  UI.Helpers in 'UI\Helpers\UI.Helpers.pas',
  UI.TreeViewSearchHelper in 'UI\Helpers\UI.TreeViewSearchHelper.pas',
   SnippetViewData in 'UI\ViewModels\SnippetViewData.pas',
   PresetData in 'UI\ViewModels\PresetData.pas',
  MacroActions in 'MacroEngine\MacroActions.pas',
  MacroThread in 'MacroEngine\MacroThread.pas',
  MacroEngine in 'MacroEngine\MacroEngine.pas',
  MacroBuilder in 'MacroEngine\MacroBuilder.pas',
  WindowMonitor in 'Automation\WindowMonitor.pas',
  ProcessProfile in 'Automation\ProcessProfile.pas',
  ChooseTerminalWindowUI in 'UI\Forms\ChooseTerminalWindowUI.pas' {ChooseTerminalWindow},
  AppEnumerator in 'Automation\AppEnumerator.pas',
  AppPickerFormUI in 'UI\Forms\AppPickerFormUI.pas' {AppPickerForm},
  InputFormUI in 'UI\Forms\InputFormUI.pas' {InputForm},
  ParamsFormUI in 'UI\Forms\ParamsFormUI.pas' {ParamsForm},
  MacroBuilderFormUI in 'UI\Forms\MacroBuilderFormUI.pas' {MacroBuilderForm},
  MacroInputTypes in 'MacroEngine\MacroInputTypes.pas',
  TagEditorFormUI in 'UI\Forms\TagEditorFormUI.pas' {TagEditorForm},
  WorkspaceManagerFormUI in 'UI\Forms\WorkspaceManagerFormUI.pas' {WorkspaceManagerForm},
  SynThemeAdapter in 'UI\Controls\SynThemeAdapter.pas',
  CustomBashSyn in 'UI\Controls\CustomBashSyn.pas',
  MacroSyn in 'UI\Controls\MacroSyn.pas',
  Core.BashCompletionEngine in 'Core\Core.BashCompletionEngine.pas',
  Common.Consts in 'Common\Common.Consts.pas',
  Common.Helpers in 'Common\Common.Helpers.pas',
  Common.QueryLanguage in 'Common\Common.QueryLanguage.pas',
  Common.VCLStyleService in 'Common\Common.VCLStyleService.pas',
  SnippetService in 'Core\Services\SnippetService.pas',
  SnippetHistoryService in 'Core\Services\SnippetHistoryService.pas',
  TagService in 'Core\Services\TagService.pas',
  CategoryService in 'Core\Services\CategoryService.pas',
  UserService in 'Core\Services\UserService.pas',
  ChainService in 'Core\Services\ChainService.pas',
  Core.Interfaces.Settings in 'Core\Core.Interfaces.Settings.pas',
  Core.Interfaces.Data in 'Core\Core.Interfaces.Data.pas',
  Core.Interfaces.Services in 'Core\Core.Interfaces.Services.pas',
  Core.Interfaces.Automation in 'Core\Core.Interfaces.Automation.pas',
  Core.Interfaces.Passwords in 'Core\Core.Interfaces.Passwords.pas',
  Core.Interfaces.Tools in 'Core\Core.Interfaces.Tools.pas',
  Core.Interfaces.UI in 'Core\Core.Interfaces.UI.pas',
  Core.Interfaces.App in 'Core\Core.Interfaces.App.pas',
  SnippetRunner in 'UI\Controllers\SnippetRunner.pas',
  SyncController in 'UI\Controllers\SyncController.pas',
  SearchController in 'UI\Controllers\SearchController.pas',
  CategoryTreeController in 'UI\Controllers\CategoryTreeController.pas',
  LanguageMenuController in 'UI\Controllers\LanguageMenuController.pas',
  TagListController in 'UI\Controllers\TagListController.pas',
  QuickSearchFormUI in 'UI\Forms\QuickSearchFormUI.pas' {QuickSearchForm},
  ChainEditorFormUI in 'UI\Forms\ChainEditorFormUI.pas' {ChainEditorForm},
  ChainRunPanelUI in 'UI\Forms\ChainRunPanelUI.pas' {ChainRunPanel},
  MacroStopPanelUI in 'UI\Forms\MacroStopPanelUI.pas' {MacroStopPanel},
  ChainRunnerController in 'UI\Controllers\ChainRunnerController.pas',
  CategorySelectDialogUI in 'UI\Forms\CategorySelectDialogUI.pas' {CategorySelectForm},
  TagSelectDialogUI in 'UI\Forms\TagSelectDialogUI.pas' {TagSelectForm},
  SequenceOrderDialogUI in 'UI\Forms\SequenceOrderDialogUI.pas' {SequenceOrderForm},
  GlobalHotkeyManager in 'UI\Controllers\GlobalHotkeyManager.pas',
  TrackBarEx in 'UI\Controls\TrackBarEx.pas',
  UI.Services.AIService in 'UI\Services\UI.Services.AIService.pas',
  UI.Services.AITextCleaner in 'UI\Services\UI.Services.AITextCleaner.pas',
  UI.Services.LocalAISmokeTest in 'UI\Services\UI.Services.LocalAISmokeTest.pas',
  AISettingsFormUI in 'UI\Forms\AISettingsFormUI.pas' {AISettingsForm},
  SecurityScanner in 'Core\Services\SecurityScanner.pas',
  PasswordService in 'Core\Services\PasswordService.pas',
  PasswordGenFormUI in 'UI\Forms\PasswordGenFormUI.pas' {PasswordGenForm},
  Core.AppContext in 'Core\Core.AppContext.pas',
  Common.Localization in 'Common\Common.Localization.pas',
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
  Core.TextDiff in 'Core\Core.TextDiff.pas',
  HistoryFormUI in 'UI\Forms\HistoryFormUI.pas' {HistoryForm},
  Core.LocalAIService in 'Core\Core.LocalAIService.pas';

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
    RegisterShutdownWindowHelper(WindowHelper);
    ErrorHandler := TUIMessagesHandler.Create;

    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    TVCLStyleService.ApplySavedStyle(SettingsManager);
  Application.Title := 'SSH Snippets Keeper';
    Application.CreateForm(TAppDatabase, AppDatabase);
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TQuickSearchForm, QuickSearchForm);
  Application.CreateForm(TCustomHelpForm, CustomHelpForm);
  Application.CreateForm(TInputForm, InputForm);
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
    MainForm.LockDrawing;
    try
        MainForm.Initialize(AppContext);
    finally
        MainForm.UnlockDrawing;
    end;
    MainForm.Show;

    Application.Run;

    TVCLStyleService.Shutdown;

    AppContext := nil;
    SettingsManager := nil;

    // Освобождаем мьютекс при закрытии программы
    if hMutex <> 0 then
    begin
        ReleaseMutex(hMutex);
        CloseHandle(hMutex);
    end;
end.

