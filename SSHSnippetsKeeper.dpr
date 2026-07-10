program SSHSnippetsKeeper;

// TODO: [Feature] Редактор горячих клавиш
// TODO: [Feature] Горячая клавиша для повторного ввода сниппета
// TODO: [Refactor] Добавить интерфейсы для юнит-тестирования
// TODO: [Feature] Добавить юнит-тесты

{$R '000_schema_init.res' 'Database\Schema\000_schema_init.rc'}

uses
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
  Winapi.Windows,
  MainFormUI in 'UI\Forms\MainFormUI.pas' {MainForm},
  JSONSerializer in 'Common\JSONSerializer.pas',
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
  ArrayHelper in 'Common\ArrayHelper.pas',
  WindowHelper in 'Automation\WindowHelper.pas',
  AddEditSnippetUI in 'UI\Forms\AddEditSnippetUI.pas' {AddEditSnippet},
  HintTextEdit in 'UI\Controls\HintTextEdit.pas',
  HintTextMemo in 'UI\Controls\HintTextMemo.pas',
  BaseFormUI in 'UI\Forms\BaseFormUI.pas',
  AppStateManager in 'UI\Services\AppStateManager.pas',
  UIHelpers in 'UI\Helpers\UIHelpers.pas',
  UITreeViewSearchHelper in 'UI\Helpers\UITreeViewSearchHelper.pas',
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
  Core.Interfaces in 'Core\Core.Interfaces.pas';

{$R *.res}

var
    hMutex: THandle;
    FoundWnd: HWND;

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
    // 1. Создаем мьютекс
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

    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    TStyleManager.TrySetStyle('Glow');
    Application.Title := 'SSH Snippets Keeper';
    Application.CreateForm(TAppDatabase, AppDatabase);
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TInputForm, InputForm);
  Application.Run;
  // --- Освобождаем мьютекс при закрытии программы ---
    if hMutex <> 0 then
    begin
        ReleaseMutex(hMutex);
        CloseHandle(hMutex);
    end;
end.

