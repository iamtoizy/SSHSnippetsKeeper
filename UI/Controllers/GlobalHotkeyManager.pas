unit GlobalHotkeyManager;

{$DEFINE FastMM_FullDebugMode}

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
    WindowHelper,
    Core.AppContext
    ;

type
    TGlobalHotkeyManager = class
    private
        const
            HOTKEY_ID_HUD = 1001;
            HOTKEY_ID_PASSGEN = 1002;
    private
        FWindowHandle: Winapi.Windows.HWND;
        FAppContext: IAppContext;
        FIsListening: Boolean;

        procedure WndProc(var Msg: TMessage);
        procedure OnHUDHotkeyTriggered;
        procedure OnPassGenHotkeyTriggered;
        procedure RegisterSingleHotkey(ID: Integer; const Config: THotkeyConfig);
    public
        constructor Create(AppContext: IAppContext);
        destructor Destroy; override;

        procedure StartListening;
        procedure StopListening;
        procedure ReloadHotkeys; // Перерегистрация при изменении настроек в UI
    end;

implementation

uses
    QuickSearchFormUI,
    System.Classes,
    UI.StateLoader;

constructor TGlobalHotkeyManager.Create(AppContext: IAppContext);
begin
    inherited Create;
    FAppContext := AppContext;
    FIsListening := False;
    FWindowHandle := AllocateHWnd(WndProc);
end;

destructor TGlobalHotkeyManager.Destroy;
begin
    StopListening;
    DeallocateHWnd(FWindowHandle);
    inherited;
end;

procedure TGlobalHotkeyManager.RegisterSingleHotkey(ID: Integer; const Config: THotkeyConfig);
var
    Flags: Cardinal;
begin
    // Сначала обязательно снимаем старую регистрацию
    Winapi.Windows.UnregisterHotKey(FWindowHandle, ID);

    if Config.Enabled and (Config.Key <> 0) then
    begin
        // Добавляем MOD_NOREPEAT, чтобы убрать автоповтор при зажатии клавиши
        Flags := Config.Modifiers or MOD_NOREPEAT;

        if not Winapi.Windows.RegisterHotKey(FWindowHandle, ID, Flags, Config.Key) then
        begin
            // Если комбинация занята другой программой в Windows
            if Assigned(FAppContext) and Assigned(FAppContext.MessagesHandler) then
                FAppContext.MessagesHandler.ShowWarning(
                    TUIStateLoader.GetMessage('Common.HotkeyRegistrationError', [ID])
                );
        end;
    end;
end;

procedure TGlobalHotkeyManager.StartListening;
var
    Settings: TAppSettings;
begin
    if FIsListening then Exit;

    Settings := FAppContext.SettingsManager.Data;

    // Регистрируем динамические значения из настроек
    RegisterSingleHotkey(HOTKEY_ID_HUD, Settings.Hotkeys.QuickSearch);
    RegisterSingleHotkey(HOTKEY_ID_PASSGEN, Settings.Hotkeys.PasswordGen);

    FIsListening := True;
end;

procedure TGlobalHotkeyManager.StopListening;
begin
    Winapi.Windows.UnregisterHotKey(FWindowHandle, HOTKEY_ID_HUD);
    Winapi.Windows.UnregisterHotKey(FWindowHandle, HOTKEY_ID_PASSGEN);
    FIsListening := False;
end;

procedure TGlobalHotkeyManager.ReloadHotkeys;
begin
    // Перезагрузка горячих клавиш на лету при сохранении настроек
    StopListening;
    StartListening;
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
                Exit;
            end;
            HOTKEY_ID_PASSGEN:
            begin
                OnPassGenHotkeyTriggered;
                Msg.Result := 0;
                Exit;
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
    CurrentHWND := Winapi.Windows.GetForegroundWindow;
    ActiveWindowInfo := WinMonitor.GetLastAllowedWindow;

    if QuickSearchForm.Visible then
    begin
        QuickSearchForm.Hide;
        Exit;
    end;

    if (ActiveWindowInfo.HWND = CurrentHWND) and IsWindow(CurrentHWND) and (FAppContext.DatabaseManager.IsConnected) then
    begin
        QuickSearchForm.ShowWithService(nil, FAppContext, 0, CurrentHWND);
        QuickSearchForm.Show;
    end;
end;

procedure TGlobalHotkeyManager.OnPassGenHotkeyTriggered;
begin
    TPasswordGenForm.ExecuteGlobal(nil, FAppContext.PasswordService, FAppContext);
end;

end.
