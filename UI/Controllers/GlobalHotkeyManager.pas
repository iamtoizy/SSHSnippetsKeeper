unit GlobalHotkeyManager;

interface

uses
    Winapi.Windows,
    Winapi.Messages,
    System.SysUtils,
    Vcl.Forms,
    Vcl.Controls,
    WindowMonitor,
    Core.Interfaces,
    PasswordGenFormUI,
    WindowHelper
    ;

type
    TGlobalHotkeyManager = class
    private
        const
            HOTKEY_ID_HUD = 1001;
            HOTKEY_ID_PASSGEN = 1002;
    private
        FWindowHandle: Winapi.Windows.HWND;
        FSnippetService: ISnippetService;
        FUserService: IUserService;
        FDBManager: IDatabaseManager;
        FPasswordService: IPasswordService;
        FUserID: Integer;
        FWindowHelper: TWindowHelper;
        procedure WndProc(var Msg: TMessage);
        procedure OnHUDHotkeyTriggered;
        procedure OnPassGenHotkeyTriggered;
    public
        constructor Create(
            SnippetService: ISnippetService;
            UserService: IUserService;
            PasswordService: IPasswordService;
            UserID: Integer;
            DBManager: IDatabaseManager;
            WindowHelper: TWindowHelper
        );
        destructor Destroy; override;
        procedure StartListening;
        procedure StopListening;
    end;

implementation

uses
    System.Classes,
    QuickSearchFormUI;

constructor TGlobalHotkeyManager.Create(
    SnippetService: ISnippetService;
    UserService: IUserService;
    PasswordService: IPasswordService;
    UserID: Integer;
    DBManager: IDatabaseManager;
    WindowHelper: TWindowHelper
);
begin
    inherited Create;
    FSnippetService := SnippetService;
    FUserService := UserService;
    FDBManager := DBManager;
    FUserID := UserID;
    FPasswordService := PasswordService;
    FWindowHelper := WindowHelper;
    // Создаем скрытое служебное окно для перехвата сообщений хоткея
    FWindowHandle := AllocateHWnd(WndProc);
end;

destructor TGlobalHotkeyManager.Destroy;
begin
    StopListening;
    DeallocateHWnd(FWindowHandle);
    inherited;
end;

procedure TGlobalHotkeyManager.StartListening;
begin
    // HUD-форма поиска и ввода сниппета:
    // Регистрируем Alt + Q (MOD_ALT и ORD('Q'))
    // Можно вынести в настройки Settings.SettingsRecord
    Winapi.Windows.RegisterHotKey(FWindowHandle, HOTKEY_ID_HUD, MOD_ALT, Ord('Q'));
    // Генератор паролей
    Winapi.Windows.RegisterHotKey(FWindowHandle, HOTKEY_ID_PASSGEN, MOD_CONTROL or MOD_ALT, Ord('G'));
end;

procedure TGlobalHotkeyManager.StopListening;
begin
    Winapi.Windows.UnregisterHotKey(FWindowHandle, HOTKEY_ID_HUD);
end;

procedure TGlobalHotkeyManager.WndProc(var Msg: TMessage);
begin
    if Msg.Msg = WM_HOTKEY then
    begin
        case Msg.WParam of
            HOTKEY_ID_HUD:
            begin
                OnHUDHotkeyTriggered;
                Msg.Result := 0;
            end;
            HOTKEY_ID_PASSGEN:
            begin
                OnPassGenHotkeyTriggered;
                Msg.Result := 0;
            end;
        end;
    end;
    Msg.Result := DefWindowProc(FWindowHandle, Msg.Msg, Msg.WParam, Msg.LParam);
end;

procedure TGlobalHotkeyManager.OnHUDHotkeyTriggered;
var
    CurrentHWND: HWND;
    ActiveWindowInfo: TWindowMonitorInfo;
begin
    // 1. Получаем хендл текущего активного окна в ОС Windows
    CurrentHWND := Winapi.Windows.GetForegroundWindow;

    // 2. Спрашиваем твой WindowMonitor, является ли это окно разрешенным терминалом
    // (Поскольку метод WinMonitor.IsAllowedWindow обычно private или работает внутри,
    // проверим через GetLastAllowedWindow или историю)
    ActiveWindowInfo := WinMonitor.GetLastAllowedWindow;

    // Критичная проверка: хоткей сработает ТОЛЬКО если активное окно совпадает с
    // последним зафиксированным терминалом и оно валидно
    if QuickSearchForm.Visible then
    begin
        QuickSearchForm.Hide;
        Exit;
    end;
    if (ActiveWindowInfo.HWND = CurrentHWND) and IsWindow(CurrentHWND) and (FDBManager.IsConnected) then
    begin
        // 3. Создаем и показываем полупрозрачную поисковую форму поверх
        // Создаем форму БЕЗ модального режима
        QuickSearchForm.ShowWithService(nil, FSnippetService, FUserService, FUserID, CurrentHWND, FWindowHelper);

        // Показываем как независимое окно
        QuickSearchForm.Show;
    end;
end;

procedure TGlobalHotkeyManager.OnPassGenHotkeyTriggered;
begin
    TPasswordGenForm.ExecuteGlobal(nil, FPasswordService);
end;

end.

