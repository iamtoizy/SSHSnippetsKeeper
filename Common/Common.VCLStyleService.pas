unit Common.VCLStyleService;

interface

uses
    Core.Interfaces.Settings,
    System.Classes,
    System.Generics.Collections,
    Vcl.Controls,
    Vcl.Themes
    ;

type
    TVCLStyleService = class
    private
        class var FLoadedStyles: TList<TCustomStyleServices>;
        class var FPendingRecycle: Boolean;
        class var FRetryDeadline: UInt64;
        class var FInRecycle: Boolean;
        class var FRecycleQueued: Boolean;
        class function MenuTrackingActive: Boolean;
        class procedure RecycleFormStyleHooks;
        class procedure RetryPendingRecycle;
        class procedure DoRecycleFormStyleHooks;
        class procedure RefreshFormChrome;
    public
        class constructor Create;
        class destructor Destroy;
        class function GetStylesFolder: string;
        class procedure FillStyleList(Items: TStrings);
        class function ApplyStyle(const StyleName: string): Boolean;
        class procedure ApplySavedStyle(SettingsManager: ISettingsManager);
        // Удаляет пары (контрол, style-hook) из карты движка до разрушения
        // контрола: при системном стиле VCL молчит (TWinControl.Destroy шлёт
        // snControlDestroyed только под sfHandleMessages), мёртвые ключи
        // остаются в TStyleEngine.FControls, и последующая итерация карты
        // при recycle разыменовывает освобождённые объекты
        class procedure PurgeStyleHooks(Control: TWinControl);
        // Выполняет отложенную пере-регистрацию хуков форм после закрытия
        // модального окна: при ModalLevel > 0 ApplyStyle только ставит флаг
        class procedure FlushPendingRecycle;
        class procedure Shutdown;
    end;

implementation

uses
    Common.Helpers,
    System.IOUtils,
    System.SysUtils,
    Vcl.Forms,
    Winapi.Messages,
    Winapi.Windows
    ;

{ TVCLStyleService }

class procedure TVCLStyleService.PurgeStyleHooks(Control: TWinControl);
begin
    if Control = nil then
        Exit;
    // Убираем пару (контрол, hook) из карты TStyleEngine.FControls ДО
    // разрушения контрола. Прямой вызов Notification(snControlDestroyed)
    // минует гейт sfHandleMessages в TWinControl.Destroy/WndProc: при
    // системном стиле VCL его пропускает, и мёртвые ключи оседают в карте,
    // после чего итерация карты при recycle разыменовывает освобождённые
    // объекты (наш AV в TStyleHook.GetHandle из MenuExit). DoRemoveControl
    // внутри движка работает только со своей картой и не трогает контрол -
    // вызов безопасен и при системном, и при кастомном стиле
    TStyleManager.Notification(snControlDestroyed, Control);
end;

class function TVCLStyleService.GetStylesFolder: string;
begin
    Result := ResolvePath('Styles', True);
end;

class procedure TVCLStyleService.FillStyleList(Items: TStrings);
var
    Files: TArray<string>;
    FileName: string;
begin
    Items.BeginUpdate;
    try
        Items.Clear;
        Items.Add('Windows');

        Files := TDirectory.GetFiles(GetStylesFolder, '*.vsf');
        TArray.Sort<string>(Files);
        for FileName in Files do
            Items.Add(TPath.GetFileNameWithoutExtension(FileName));
    finally
        Items.EndUpdate;
    end;
end;

class function TVCLStyleService.ApplyStyle(const StyleName: string): Boolean;

    procedure ResetActiveControls;
    var
        I: Integer;
    begin
        for I := 0 to Screen.FormCount - 1 do
            Screen.Forms[I].ActiveControl := nil;
    end;

    // Смена стиля несовместима с активным трекингом главного меню:
    // вложенный цикл меню держит ссылки на хук, который переживает
    // пересоздание. WM_CANCELMODE гасит трекинг (TFormStyleHook
    // сбрасывает InMenuLoop) до того, как хуки начнут меняться
    procedure CancelMenuModes;
    var
        I: Integer;
    begin
        for I := 0 to Screen.FormCount - 1 do
            if Screen.Forms[I].HandleAllocated and
                IsWindowVisible(Screen.Forms[I].Handle) then
                SendMessage(Screen.Forms[I].Handle, WM_CANCELMODE, 0, 0);
    end;

var
    FileName: string;
    Handle: TStyleManager.TStyleServicesHandle;
    ExistingName: string;
    StyleInfo: TStyleInfo;
    RealName: string;
begin
    Result := False;
    try
        if StyleName.IsEmpty or SameText(StyleName, 'Windows') then
        begin
            if TStyleManager.IsCustomStyleActive then
            begin
                ResetActiveControls;
                CancelMenuModes;
                Result := TStyleManager.TrySetStyle('Windows', False);
                RecycleFormStyleHooks;
                Exit;
            end;
            Exit(True);
        end;

        FileName := TPath.Combine(GetStylesFolder, StyleName + '.vsf');
        if not TFile.Exists(FileName) then
            Exit;

        if not TStyleManager.IsValidStyle(FileName, StyleInfo) then
            Exit;

        // Реальное имя стиля хранится внутри .vsf и может отличаться от имени
        // файла (CharcoalDarkSlate.vsf -> 'Charcoal Dark Slate'); TStyleManager
        // регистрирует стиль под внутренним именем, поэтому сравнивать надо с ним
        RealName := StyleInfo.Name;
        if RealName.IsEmpty then
            RealName := StyleName;

        for ExistingName in TStyleManager.StyleNames do
            if SameText(ExistingName, RealName) then
            begin
                ResetActiveControls;
                CancelMenuModes;
                Result := TStyleManager.TrySetStyle(ExistingName, False);
                if Result then
                    RecycleFormStyleHooks;
                Exit;
            end;

        Handle := TStyleManager.LoadFromFile(FileName);
        if Handle = nil then
            Exit;

        ResetActiveControls;
        CancelMenuModes;
        TStyleManager.SetStyle(Handle);
        Result := TStyleManager.IsCustomStyleActive;
        if Result then
        begin
            FLoadedStyles.Add(TStyleManager.ActiveStyle);
            RecycleFormStyleHooks;
        end;
    except
        Result := False;
    end;
end;

class function TVCLStyleService.MenuTrackingActive: Boolean;
var
    Info: TGUIThreadInfo;
begin
    // ОКНО НЕОПАСНОСТИ: пока активен трекинг меню (наш ProcessMenuLoop
    // вокруг TrackPopupMenu, системный menu-mode или capture мыши у хука
    // главного меню), ре-регистрация TFormStyleHook освобождает хук,
    // по которому ProcessMenuLoop ещё крутит until not FInMenuLoop -
    // возврат идёт в освобождённую память (фриз после смены темы).
    // GUI_INMENUMODE/POPUP/SYSTEMMENUMODE ставятся системой только вокруг
    // нативного TrackPopupMenu, capture покрывает mouse-capture-фазу хука,
    // когда mode-флаги ещё не подняты
    Info.cbSize := SizeOf(Info);
    if GetGUIThreadInfo(GetCurrentThreadId, Info) then
        Result := (Info.flags and (GUI_INMENUMODE or GUI_POPUPMENUMODE or
            GUI_SYSTEMMENUMODE) <> 0) or (Info.hwndCapture <> 0)
    else
        // Запрос не удался - считаем опасное состояние активным: отказ в
        // пользу отложения ре-регистрации
        Result := True;
end;

class procedure TVCLStyleService.RecycleFormStyleHooks;
var
    I: Integer;
begin
    // VCL при открытом модальном окне пропускает FreeControlHooks
    // (TStyleEngine.Notification проверяет Application.ModalLevel),
    // поэтому пере-регистрация сейчас оставила бы смесь старых и новых
    // хуков. Откладываем: ставим только флаг, реальное выполнение
    // произойдёт в FlushPendingRecycle после закрытия модального окна.
    // Раньше здесь был TThread.ForceQueue с само-переподрядчиванием -
    // очередь перезапускала себя бесконечно, пока ModalLevel > 0,
    // и главный поток переставал качать сообщения: окно зависало
    if Application.ModalLevel > 0 then
    begin
        FPendingRecycle := True;
        Exit;
    end;
    // Смена стиля из-под активного меню (клик по меню сразу после смены
    // темы): ре-регистрацию нельзя выполнять, пока жив - ProcessMenuLoop
    // предыдущего хука. WM_CANCELMODE через SendMessage до TrackPopupMenu
    // НЕ доходит как сообщение очереди (same-thread = прямой вызов
    // WndProc, луп его PeekMessage-сканом не видит), поэтому сначала
    // закрываем меню через PostMessage (очередь лупа его вытащит), затем
    // ре-регистрация уходит в очередь и с гейтом ждёт, пока трекинг
    // реально завершится. Пользователь увидит закрытие меню вместо фриза
    if MenuTrackingActive then
    begin
        for I := 0 to Screen.FormCount - 1 do
            if Screen.Forms[I].HandleAllocated and
                IsWindowVisible(Screen.Forms[I].Handle) then
                PostMessage(Screen.Forms[I].Handle, WM_CANCELMODE, 0, 0);
        FPendingRecycle := True;
        FRetryDeadline := GetTickCount64 + 2000;
        TThread.ForceQueue(nil, RetryPendingRecycle);
        Exit;
    end;
    // Выполнение переносим в очередь синхронных вызовов: ре-регистрация
    // освобождает живые TFormStyleHook прямо из-под цепочки диспетчера
    // сообщений (HandleMessage -> WndProc -> OnChange), и возврат в эпилог
    // освобождённого хука читает мусорные FInMenuLoop/FDispatchMessage -
    // ProcessMenuLoop заклинивает в PeekMessage-спин-лупе (наш фриз после
    // смены темы). CheckSynchronize вызовет нас, когда стек диспетчера
    // уже пуст. FRecycleQueued гасит дубли, guard от повторного входа
    // сохранён: деструкторы хуков прокачивают сообщения и могут ре-энтерить
    if FInRecycle or FRecycleQueued then
        Exit;
    FRecycleQueued := True;
    TThread.ForceQueue(nil, DoRecycleFormStyleHooks);
end;

class procedure TVCLStyleService.RetryPendingRecycle;
var
    I: Integer;
begin
    if not FPendingRecycle then
        Exit;
    // Трекинг всё ещё активен: WM_CANCELMODE закрывает луп не мгновенно -
    // ждём следующий оборот очереди. Окно 2 сек по wall-clock: быстрый
    // PeekMessage-скан лупа прокручивает очередь тысячи раз в секунду и
    // счётчик попыток сгорел бы мгновенно. По истечении окна выполняем
    // ре-регистрацию принудительно, иначе recycle потерян навсегда
    if MenuTrackingActive and (GetTickCount64 < FRetryDeadline) then
    begin
        for I := 0 to Screen.FormCount - 1 do
            if Screen.Forms[I].HandleAllocated and
                IsWindowVisible(Screen.Forms[I].Handle) then
                PostMessage(Screen.Forms[I].Handle, WM_CANCELMODE, 0, 0);
        TThread.ForceQueue(nil, RetryPendingRecycle);
        Exit;
    end;
    FPendingRecycle := False;
    if FInRecycle or FRecycleQueued then
        Exit;
    FRecycleQueued := True;
    TThread.ForceQueue(nil, DoRecycleFormStyleHooks);
end;

class procedure TVCLStyleService.DoRecycleFormStyleHooks;
begin
    FRecycleQueued := False;
    if FInRecycle then
        Exit;
    // Double-check при исполнении: между постом и обработкой очереди
    // пользователь мог снова открыть меню - тогда откладываем ещё раз,
    // освобождение хука из-под ProcessMenuLoop и даёт фриз
    if MenuTrackingActive then
    begin
        FPendingRecycle := True;
        FRetryDeadline := GetTickCount64 + 2000;
        TThread.ForceQueue(nil, RetryPendingRecycle);
        Exit;
    end;
    FInRecycle := True;
    try
        try
            TStyleManager.Engine.UnRegisterStyleHook(TCustomForm, TFormStyleHook);
            TStyleManager.Engine.UnRegisterStyleHook(TForm, TFormStyleHook);
        except
        end;
        try
            TStyleManager.Engine.RegisterStyleHook(TForm, TFormStyleHook);
            TStyleManager.Engine.RegisterStyleHook(TCustomForm, TFormStyleHook);
        except
        end;
    finally
        FInRecycle := False;
        RefreshFormChrome;
    end;
end;

class procedure TVCLStyleService.RefreshFormChrome;
var
    I: Integer;
    Form: TCustomForm;
begin
    // После пересоздания хуков форм: (1) SWP_FRAMECHANGED заставляет
    // WM_NCCALCSIZE заново построить FMainMenuBarHook (Vcl.Forms.pas:19453,
    // иначе меню мертво до resize); (2) WM_SYSCOLORCHANGE вынуждает нативные
    // заголовки (SysHeader32 у TListView) перекраситься под новую тему
    for I := 0 to Screen.FormCount - 1 do
    begin
        Form := Screen.Forms[I];
        if not Form.HandleAllocated then
            Continue;
        SetWindowPos(Form.Handle, 0, 0, 0, 0, 0, SWP_FRAMECHANGED or
            SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE or
            SWP_NOCOPYBITS);
        SendMessage(Form.Handle, WM_SYSCOLORCHANGE, 0, 0);
    end;
end;

class procedure TVCLStyleService.FlushPendingRecycle;
begin
    if not FPendingRecycle then
        Exit;
    FPendingRecycle := False;
    RecycleFormStyleHooks;
end;

class constructor TVCLStyleService.Create;
begin
    FLoadedStyles := TList<TCustomStyleServices>.Create;
    FPendingRecycle := False;
    FRetryDeadline := 0;
    FInRecycle := False;
    FRecycleQueued := False;
end;

class destructor TVCLStyleService.Destroy;
begin
    FLoadedStyles.Free;
end;

class procedure TVCLStyleService.Shutdown;
var
    LoadedStyle: TCustomStyleServices;
begin
    if TStyleManager.IsCustomStyleActive then
    begin
        TStyleManager.SetStyle(TStyleManager.SystemStyle);
        CheckSynchronize;
    end;

    for LoadedStyle in FLoadedStyles do
    begin
        TStyleManager.UnRegisterStyle(LoadedStyle);
        LoadedStyle.Free;
    end;

    FLoadedStyles.Clear;
end;

class procedure TVCLStyleService.ApplySavedStyle(SettingsManager: ISettingsManager);
var
    SavedStyle: string;
begin
    if SettingsManager = nil then
        Exit;

    SavedStyle := SettingsManager.Data.UISettings.VCLStyle;
    if SavedStyle.IsEmpty then
        Exit;

    if not ApplyStyle(SavedStyle) then
        OutputDebugString(PChar('[VCLStyle] Failed to apply style "' + SavedStyle + '"'));
    // На старте модальных окон ещё нет: отложенный при ModalLevel > 0
    // recycle хуков выполняем сразу, а не ждём чужой flush после модалки
    if Application.ModalLevel = 0 then
        FlushPendingRecycle;
end;

end.
