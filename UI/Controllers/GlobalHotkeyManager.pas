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
            HOTKEY_ID_REPEAT_LAST = 1003;
            HOTKEY_ID_SLOT_BASE = 1010; // 1010..1019: слоты избранного 1..0
    private
        FWindowHandle: Winapi.Windows.HWND;
        FAppContext: IAppContext;
        FIsListening: Boolean;

        procedure WndProc(var Msg: TMessage);
        procedure OnHUDHotkeyTriggered;
        procedure OnPassGenHotkeyTriggered;
        procedure OnRepeatLastTriggered;
        procedure OnFavoriteSlotTriggered(SlotIndex: Integer);
        procedure RegisterSingleHotkey(ID: Integer; const Config: THotkeyConfig);
        function HotkeyDisplayName(ID: Integer): string;
        function IsForegroundAllowed(out CurrentHWND: HWND): Boolean;
        class function SlotVirtualKey(SlotIndex: Integer): Cardinal; static;
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
    SnippetRunner,
    System.Classes,
    Core.Entities.Snippet
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
    if (ID >= HOTKEY_ID_SLOT_BASE) and (ID < HOTKEY_ID_SLOT_BASE + 10) then
    begin
        if ID - HOTKEY_ID_SLOT_BASE = 9 then
            Result := TUIStateLoader.GetMessage('Actions.FavoriteSlot') + ' 0'
        else
            Result := TUIStateLoader.GetMessage('Actions.FavoriteSlot') + ' ' + IntToStr(ID - HOTKEY_ID_SLOT_BASE + 1);
        Exit;
    end;

    case ID of
        HOTKEY_ID_HUD:
            Result := TUIStateLoader.GetMessage('Actions.GlobalQuickSearch');
        HOTKEY_ID_PASSGEN:
            Result := TUIStateLoader.GetMessage('Actions.GlobalPasswordGen');
        HOTKEY_ID_REPEAT_LAST:
            Result := TUIStateLoader.GetMessage('Actions.GlobalRepeatLast');
    else
        Result := IntToStr(ID);
    end;
end;

class function TGlobalHotkeyManager.SlotVirtualKey(SlotIndex: Integer): Cardinal;
begin
    // Слоты 0..8 -> клавиши 1..9, слот 9 -> клавиша 0
    if SlotIndex = 9 then
        Result := Ord('0')
    else
        Result := Ord('1') + SlotIndex;
end;

procedure TGlobalHotkeyManager.StartListening;
var
    Settings: TAppSettings;
    SlotConfig: THotkeyConfig;
    I: Integer;
begin
    if FIsListening then Exit;

    Settings := FAppContext.SettingsManager.Data;

    // Регистрируем динамические значения из настроек
    RegisterSingleHotkey(HOTKEY_ID_HUD, Settings.Hotkeys.QuickSearch);
    RegisterSingleHotkey(HOTKEY_ID_PASSGEN, Settings.Hotkeys.PasswordGen);
    RegisterSingleHotkey(HOTKEY_ID_REPEAT_LAST, Settings.Hotkeys.RepeatLast);

    if Settings.Hotkeys.FavoriteSlots.Enabled then
    begin
        SlotConfig := Settings.Hotkeys.FavoriteSlots;
        for I := 0 to 9 do
        begin
            SlotConfig.Key := SlotVirtualKey(I);
            RegisterSingleHotkey(HOTKEY_ID_SLOT_BASE + I, SlotConfig);
        end;
    end;

    FIsListening := True;
end;

procedure TGlobalHotkeyManager.StopListening;
var
    I: Integer;
begin
    Winapi.Windows.UnregisterHotKey(FWindowHandle, HOTKEY_ID_HUD);
    Winapi.Windows.UnregisterHotKey(FWindowHandle, HOTKEY_ID_PASSGEN);
    Winapi.Windows.UnregisterHotKey(FWindowHandle, HOTKEY_ID_REPEAT_LAST);
    for I := 0 to 9 do
        Winapi.Windows.UnregisterHotKey(FWindowHandle, HOTKEY_ID_SLOT_BASE + I);
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
            HOTKEY_ID_REPEAT_LAST:
            begin
                OnRepeatLastTriggered;
                Msg.Result := 0;
                Exit;
            end;
        end;

        if (Msg.WParam >= HOTKEY_ID_SLOT_BASE) and (Msg.WParam < HOTKEY_ID_SLOT_BASE + 10) then
        begin
            OnFavoriteSlotTriggered(Msg.WParam - HOTKEY_ID_SLOT_BASE);
            Msg.Result := 0;
            Exit;
        end;
    end;
    Msg.Result := DefWindowProc(FWindowHandle, Msg.Msg, Msg.WParam, Msg.LParam);
end;

function TGlobalHotkeyManager.IsForegroundAllowed(out CurrentHWND: HWND): Boolean;
var
    ActiveWindowInfo: TWindowMonitorInfo;
begin
    Result := False;
    CurrentHWND := 0;

    if not FAppContext.DatabaseManager.IsConnected then
    begin
        {$IFDEF DEBUG}
        OutputDebugString('[HotkeyMgr] blocked: DB not connected');
        {$ENDIF}
        Exit;
    end;

    CurrentHWND := Winapi.Windows.GetForegroundWindow;

    if not IsWindow(CurrentHWND) then
    begin
        {$IFDEF DEBUG}
        OutputDebugString('[HotkeyMgr] blocked: foreground window is invalid');
        {$ENDIF}
        Exit;
    end;

    ActiveWindowInfo := GWinMonitor.GetLastAllowedWindow;
    if ActiveWindowInfo.HWND <> CurrentHWND then
    begin
        {$IFDEF DEBUG}
        OutputDebugString(PChar(Format('[HotkeyMgr] blocked: last allowed "%s" (HWND=%d) <> foreground (HWND=%d)',
            [ActiveWindowInfo.ExeName, ActiveWindowInfo.HWND, CurrentHWND])));
        {$ENDIF}
        Exit;
    end;

    Result := True;
end;

procedure TGlobalHotkeyManager.OnHUDHotkeyTriggered;
var
    CurrentHWND: HWND;
begin
    if QuickSearchForm.Visible then
    begin
        QuickSearchForm.Hide;
        Exit;
    end;

    if not IsForegroundAllowed(CurrentHWND) then
        Exit;

    QuickSearchForm.ShowWithService(nil, FAppContext, 0, CurrentHWND);
    QuickSearchForm.Show;
end;

procedure TGlobalHotkeyManager.OnPassGenHotkeyTriggered;
begin
    TPasswordGenForm.ExecuteGlobal(nil, FAppContext.PasswordService, FAppContext);
end;

procedure TGlobalHotkeyManager.OnRepeatLastTriggered;
var
    CurrentHWND: HWND;
    SnippetID: Integer;
    Snippet: TSnippetDTO;
    Runner: TSnippetRunner;
begin
    if not IsForegroundAllowed(CurrentHWND) then
        Exit;

    // UserID = 0: последний запуск без привязки к пространству
    // (глобальный хоткей не имеет контекста workspace)
    SnippetID := FAppContext.SnippetService.GetLastRunSnippetID(0);
    if SnippetID <= 0 then
    begin
        {$IFDEF DEBUG}
        OutputDebugString('[HotkeyMgr] RepeatLast: no runs recorded yet');
        {$ENDIF}
        Exit;
    end;

    Snippet := FAppContext.SnippetService.GetSnippetByID(SnippetID);

    Runner := TSnippetRunner.Create(0, FAppContext);
    try
        Runner.ExecuteSnippetInWindow(Snippet, CurrentHWND, False);
    finally
        Runner.Free;
    end;
end;

procedure TGlobalHotkeyManager.OnFavoriteSlotTriggered(SlotIndex: Integer);
var
    CurrentHWND: HWND;
    Favorites: TArray<TSnippetDTO>;
    Runner: TSnippetRunner;
begin
    if not IsForegroundAllowed(CurrentHWND) then
        Exit;

    Favorites := FAppContext.SnippetService.GetFavorites(0);
    if SlotIndex >= Length(Favorites) then
        Exit;

    // Записываем запуск в workspace самого сниппета
    Runner := TSnippetRunner.Create(Favorites[SlotIndex].UserID, FAppContext);
    try
        Runner.ExecuteSnippetInWindow(Favorites[SlotIndex], CurrentHWND, False);
    finally
        Runner.Free;
    end;
end;

end.
