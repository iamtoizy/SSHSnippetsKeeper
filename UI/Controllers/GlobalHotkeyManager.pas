unit GlobalHotkeyManager;

interface

uses
    Core.AppContext,
    Core.Interfaces.App,
    Core.Interfaces.Automation,
    Core.Interfaces.Data,
    Core.Interfaces.Passwords,
    Core.Interfaces.Settings,
    Core.Interfaces.UI,
    PasswordGenFormUI,
    System.SysUtils,
    Vcl.Controls,
    Vcl.Forms,
    Winapi.Messages,
    Winapi.Windows,
    WindowHelper,
    WindowMonitor
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
        function HotkeyDisplayName(ID: Integer): string;
    public
        constructor Create(AppContext: IAppContext);
        destructor Destroy; override;

        procedure StartListening;
        procedure StopListening;
        procedure ReloadHotkeys; // Перерегистрация при изменении настроек в UI
    end;

implementation

uses
    Common.Helpers,
    Common.Localization,
    QuickSearchFormUI,
    System.Classes
    ;

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
            // Если комбинация занята другой программой в Windows
            ShowSimpleToast(TUIStateLoader.GetMessage('Common.HotkeyRegistrationError',
                [HotkeyDisplayName(ID)]));
    end;
end;

function TGlobalHotkeyManager.HotkeyDisplayName(ID: Integer): string;
begin
    case ID of
        HOTKEY_ID_HUD:
            Result := TUIStateLoader.GetMessage('Actions.GlobalQuickSearch');
        HOTKEY_ID_PASSGEN:
            Result := TUIStateLoader.GetMessage('Actions.GlobalPasswordGen');
    else
        Result := IntToStr(ID);
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
    ActiveWindowInfo := GWinMonitor.GetLastAllowedWindow;

    if QuickSearchForm.Visible then
    begin
        QuickSearchForm.Hide;
        Exit;
    end;

    if not FAppContext.DatabaseManager.IsConnected then
    begin
        {$IFDEF DEBUG}
        OutputDebugString('[HotkeyMgr] HUD blocked: DB not connected');
        {$ENDIF}
        Exit;
    end;

    if not IsWindow(CurrentHWND) then
    begin
        {$IFDEF DEBUG}
        OutputDebugString('[HotkeyMgr] HUD blocked: foreground window is invalid');
        {$ENDIF}
        Exit;
    end;

    if ActiveWindowInfo.HWND <> CurrentHWND then
    begin
        {$IFDEF DEBUG}
        OutputDebugString(PChar(Format('[HotkeyMgr] HUD blocked: last allowed "%s" (HWND=%d) <> foreground (HWND=%d)',
            [ActiveWindowInfo.ExeName, ActiveWindowInfo.HWND, CurrentHWND])));
        {$ENDIF}
        Exit;
    end;

    QuickSearchForm.ShowWithService(nil, FAppContext, 0, CurrentHWND);
    QuickSearchForm.Show;
end;

procedure TGlobalHotkeyManager.OnPassGenHotkeyTriggered;
begin
    TPasswordGenForm.ExecuteGlobal(nil, FAppContext.PasswordService, FAppContext);
end;

end.
