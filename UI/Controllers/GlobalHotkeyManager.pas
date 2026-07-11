unit GlobalHotkeyManager;

interface

uses
    Winapi.Windows,
    Winapi.Messages,
    System.SysUtils,
    Vcl.Forms,
    Vcl.Controls,
    WindowMonitor,
    Core.Interfaces;

type
    TGlobalHotkeyManager = class
    private
        const
            HOTKEY_ID = 1001;
    private
        FWindowHandle: Winapi.Windows.HWND;
        FSnippetService: ISnippetService;
        FUserService: IUserService;
        FDBManager: IDatabaseManager;
        FUserID: NativeInt;
        procedure WndProc(var Msg: TMessage);
        procedure OnHotkeyTriggered;
    public
        constructor Create(SnippetService: ISnippetService; UserService: IUserService; UserID: NativeInt; DBManager: IDatabaseManager);
        destructor Destroy; override;
        procedure StartListening;
        procedure StopListening;
    end;

implementation

uses
    System.Classes,
    QuickSearchFormUI;

constructor TGlobalHotkeyManager.Create(SnippetService: ISnippetService; UserService: IUserService; UserID: NativeInt; DBManager: IDatabaseManager);
begin
    inherited Create;
    FSnippetService := SnippetService;
    FUserService := UserService;
    FDBManager := DBManager;
    FUserID := UserID;
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
    // Регистрируем, например, Alt + Q (MOD_ALT и ORD('Q'))
    // Можно вынести в настройки Settings.SettingsRecord
    Winapi.Windows.RegisterHotKey(FWindowHandle, HOTKEY_ID, MOD_ALT, Ord('Q'));
end;

procedure TGlobalHotkeyManager.StopListening;
begin
    Winapi.Windows.UnregisterHotKey(FWindowHandle, HOTKEY_ID);
end;

procedure TGlobalHotkeyManager.WndProc(var Msg: TMessage);
begin
    if Msg.Msg = WM_HOTKEY then
    begin
        if Msg.WParam = HOTKEY_ID then
        begin
            OnHotkeyTriggered;
            Msg.Result := 0;
        end;
    end;
    Msg.Result := DefWindowProc(FWindowHandle, Msg.Msg, Msg.WParam, Msg.LParam);
end;

procedure TGlobalHotkeyManager.OnHotkeyTriggered;
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
        QuickSearchForm.ShowWithService(nil, FSnippetService, FUserService, FUserID, CurrentHWND);

        // Показываем как независимое окно
        QuickSearchForm.Show;
    end;
end;

end.

