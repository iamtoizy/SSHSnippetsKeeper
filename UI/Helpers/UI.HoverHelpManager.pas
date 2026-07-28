unit UI.HoverHelpManager;

interface

uses
    Core.Interfaces,
    System.Classes,
    System.Diagnostics,
    System.Generics.Collections,
    Vcl.Buttons,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Winapi.Messages,
    Winapi.Windows
    ;

type
    THelpIconPosition = (hipTopLeft, hipTopRight, hipLeftCenter, hipRightCenter, hipBottomLeft, hipBottomRight);
    THelpKind = (hkCustomForm, hkTaskDialog);
    THelpState = (hsHidden, hsWaiting, hsFadingIn, hsVisible);

    THelpSetup = record
        Position: THelpIconPosition;
        HelpKey: string;
        HelpKind: THelpKind;
    end;

    TOnShowHelpEvent = procedure(Target: TControl; const HelpKey: string; HelpKind: THelpKind) of object;

    // Плавающее окно с кнопкой
    THelpPopupWindow = class(TForm)
    private
        FButton: TSpeedButton;
        FOnClickEvent: TNotifyEvent;
        procedure OnButtonClick(Sender: TObject);
        procedure WMMouseActivate(var Message: TWMMouseActivate); message WM_MOUSEACTIVATE;
    protected
        procedure CreateParams(var Params: TCreateParams); override;
        procedure CreateWnd; override;
    public
        constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
        property OnClickEvent: TNotifyEvent read FOnClickEvent write FOnClickEvent;
    end;

    // Менеджер
    TUIHoverHelpManager = class(TComponent)
    private
        FRegistered: TDictionary<TControl, THelpSetup>;
        FTimer: TTimer;
        FSharedButton: THelpPopupWindow;
        FLastWnd: HWND;             // Кэш дескриптора окна
        FStopwatch: TStopwatch;     // Для высокоточного отсчета времени
        FLastMousePt: TPoint;       // Для кэширования позиции мыши
        FLastHoveredCtrl: TControl; // Кэш найденного контрола
        FCurrentTarget: TControl;   // Текущий контрол под курсором
        FOnShowHelp: TOnShowHelpEvent;
        FSettings: TUISettings;
        FHelpState: THelpState;
        FWaitStartTick: Int64;
        FFadeStartTick: Int64;
        FOldWndProc: TWndMethod;

        procedure HookTarget(Target: TControl);
        procedure UnhookTarget;
        procedure TargetWndProc(var Message: TMessage);
        procedure OnTimerTick(Sender: TObject);
        procedure OnPopupButtonClick(Sender: TObject);
        procedure UpdateButtonPosition(Target: TControl; Pos: THelpIconPosition);
        procedure HideButton;
    protected
        procedure Notification(Component: TComponent; Operation: TOperation); override;
    public
        constructor Create(Owner: TComponent); override;
        destructor Destroy; override;

        procedure RegisterControl(Control: TControl; Position: THelpIconPosition; const HelpKey: string; HelpKind: THelpKind = hkCustomForm);
        procedure UnregisterControl(Control: TControl);
        procedure Configure(Settings: TUISettings);

        property OnShowHelp: TOnShowHelpEvent read FOnShowHelp write FOnShowHelp;
    end;

implementation

uses
    System.Types,
    Vcl.Graphics;

const
    BTN_WIDTH = 20;
    BTN_HEIGHT = 20;

{ THelpPopupWindow }

constructor THelpPopupWindow.CreateNew(AOwner: TComponent; Dummy: Integer = 0);
begin
    inherited CreateNew(AOwner, Dummy);
    BorderStyle := bsNone;
    Width := BTN_WIDTH;
    Height := BTN_HEIGHT;
    Color := clWindow;
    AlphaBlend := True;
    AlphaBlendValue := 0;

    FButton := TSpeedButton.Create(Self);
    FButton.Parent := Self;
    FButton.Align := alClient;
    FButton.Caption := '?';
    FButton.Font.Style := [fsBold];
    FButton.Font.Color := $00D77800;
    FButton.Flat := False;
    FButton.Cursor := crHandPoint;
    FButton.OnClick := OnButtonClick;
end;

procedure THelpPopupWindow.CreateParams(var Params: TCreateParams);
begin
    inherited;
    Params.Style := WS_POPUP;
    // Защита от кражи фокуса (NOACTIVATE) и отображение поверх списков (TOPMOST)
    Params.ExStyle := Params.ExStyle or WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE or WS_EX_TOPMOST;
    Params.WndParent := 0;
end;

procedure THelpPopupWindow.CreateWnd;
var
    Rgn: HRGN;
begin
    inherited;
    // Создаем регион (маску) со скругленными углами и применяем его к окну.
    // Ширина/Высота берутся от самой формы (20х20).
    // Последние два параметра (4, 4) - это радиус закругления в пикселях.
    Rgn := CreateRoundRectRgn(0, 0, Width, Height, 4, 4);

    // Передаем регион системе. Важно: удалять (DeleteObject) этот регион не нужно,
    // после успешного вызова SetWindowRgn система берет управление им на себя.
    SetWindowRgn(Handle, Rgn, True);
end;

procedure THelpPopupWindow.WMMouseActivate(var Message: TWMMouseActivate);
begin
    Message.Result := MA_NOACTIVATE; // Блокируем передачу фокуса при клике
end;

procedure THelpPopupWindow.OnButtonClick(Sender: TObject);
begin
    if Assigned(FOnClickEvent) then
        FOnClickEvent(Self);
end;

{ TUIHoverHelpManager }

procedure TUIHoverHelpManager.Configure(Settings: TUISettings);
begin
    FSettings := Settings;
end;

constructor TUIHoverHelpManager.Create(Owner: TComponent);
begin
    inherited Create(Owner);
    FRegistered := TDictionary<TControl, THelpSetup>.Create;
    FHelpState := hsHidden;

    FSharedButton := THelpPopupWindow.CreateNew(nil);
    FSharedButton.OnClickEvent := OnPopupButtonClick;

    // Запускаем высокоточный секундомер
    FStopwatch := TStopwatch.StartNew;
    // Сбрасываем точку мыши, чтобы первый тик гарантированно сработал
    FLastMousePt := Point(-1, -1);

    FTimer := TTimer.Create(Self);
    FTimer.Interval := 15; // 60 FPS
    FTimer.OnTimer := OnTimerTick;
end;

destructor TUIHoverHelpManager.Destroy;
begin
    UnhookTarget;
    FTimer.Free;
    FSharedButton.Free;
    FRegistered.Free;
    inherited;
end;

procedure TUIHoverHelpManager.HookTarget(Target: TControl);
begin
    if Target = FCurrentTarget then Exit;
    UnhookTarget;
    if Assigned(Target) then
    begin
        FCurrentTarget := Target;
        FOldWndProc := FCurrentTarget.WindowProc;
        FCurrentTarget.WindowProc := TargetWndProc;
    end;
end;

procedure TUIHoverHelpManager.Notification(Component: TComponent; Operation: TOperation);
begin
    inherited Notification(Component, Operation);

    // Если какой-то компонент, за которым мы следим, физически уничтожается
    if Operation = opRemove then
    begin
        // 1. Очищаем мертвый кэш
        if Component = FLastHoveredCtrl then
            FLastHoveredCtrl := nil;

        // 2. Если удаляется наш текущий таргет (например, окно закрыли без WM_DESTROY)
        if Component = FCurrentTarget then
        begin
            FOldWndProc := nil; // Не пытаемся восстановить хук на умирающем объекте
            FCurrentTarget := nil;
            FHelpState := hsHidden;
            if Assigned(FSharedButton) and FSharedButton.HandleAllocated then
                ShowWindow(FSharedButton.Handle, SW_HIDE);
        end;

        // 3. Удаляем из регистрации
        if Component is TControl then
            FRegistered.Remove(TControl(Component));
    end;
end;

procedure TUIHoverHelpManager.UnhookTarget;
begin
    if Assigned(FCurrentTarget) and Assigned(FOldWndProc) then
        FCurrentTarget.WindowProc := FOldWndProc;
    FOldWndProc := nil;
    FCurrentTarget := nil;
end;

procedure TUIHoverHelpManager.TargetWndProc(var Message: TMessage);
var
    OldProc: TWndMethod;
begin
    OldProc := FOldWndProc;

    if Message.Msg = WM_DESTROY then
    begin
        UnhookTarget;
        if Assigned(OldProc) then OldProc(Message);
        Exit;
    end;

    // Прячем кнопку мгновенно, если юзер крутит колесо, печатает текст или кликает внутри поля
    if (Message.Msg = WM_VSCROLL) or (Message.Msg = WM_HSCROLL) or
       (Message.Msg = WM_MOUSEWHEEL) or (Message.Msg = WM_KEYDOWN) or
       (Message.Msg = WM_LBUTTONDOWN) then
    begin
        HideButton;
    end;

    if Assigned(OldProc) then
        OldProc(Message);
end;

procedure TUIHoverHelpManager.RegisterControl(Control: TControl; Position: THelpIconPosition; const HelpKey: string; HelpKind: THelpKind = hkCustomForm);
var
    Setup: THelpSetup;
begin
    Setup := Default(THelpSetup);
    Setup.Position := Position;
    Setup.HelpKey := HelpKey;
    Setup.HelpKind := HelpKind;
    FRegistered.AddOrSetValue(Control, Setup);
    // Подписываемся на смерть контрола
    Control.FreeNotification(Self);
end;

procedure TUIHoverHelpManager.UnregisterControl(Control: TControl);
begin
    FRegistered.Remove(Control);
    if FCurrentTarget = Control then
        HideButton;
end;

procedure TUIHoverHelpManager.OnPopupButtonClick(Sender: TObject);
var
    Setup: THelpSetup;
    CachedTarget: TControl;
begin
    if Assigned(FCurrentTarget) and FRegistered.TryGetValue(FCurrentTarget, Setup) then
    begin
        // Сохраняем таргет, так как HideButton полностью сбросит состояние менеджера
        CachedTarget := FCurrentTarget;

        // Мгновенно прячем кнопку. Она не должна маячить поверх диалога.
        HideButton;

        // Безопасно вызываем кастомную форму с сохранённым таргетом
        if Assigned(FOnShowHelp) then
            FOnShowHelp(CachedTarget, Setup.HelpKey, Setup.HelpKind);
    end;
end;

procedure TUIHoverHelpManager.HideButton;
begin
    UnhookTarget;
    FHelpState := hsHidden;
    FSharedButton.AlphaBlendValue := 0;
    ShowWindow(FSharedButton.Handle, SW_HIDE);
end;

procedure TUIHoverHelpManager.OnTimerTick(Sender: TObject);
var
    Pt: TPoint;
    Wnd: HWND;
    HoveredCtrl: TControl;
    Setup: THelpSetup;
    WaitDelay: Integer;
    AnimDuration: Double;
    IsOverButton: Boolean;
    CurrentTime: Int64;
    Elapsed: Int64;
begin
    if (not Assigned(Owner)) or (csDestroying in Owner.ComponentState) then Exit;

    Pt := Mouse.CursorPos;
    Wnd := WindowFromPoint(Pt);
    CurrentTime := FStopwatch.ElapsedMilliseconds;

    if (Pt.X = FLastMousePt.X) and (Pt.Y = FLastMousePt.Y) and (Wnd = FLastWnd) then
        HoveredCtrl := FLastHoveredCtrl // Берем из кэша
    else
    begin
        FLastMousePt := Pt;
        FLastWnd := Wnd;
        IsOverButton := (FHelpState <> hsHidden) and PtInRect(FSharedButton.BoundsRect, Pt);

        if IsOverButton then
        begin
            HoveredCtrl := FCurrentTarget;
        end
        else
        begin
            HoveredCtrl := FindDragTarget(Pt, True);
            if not Assigned(HoveredCtrl) then
            begin
                if Wnd <> 0 then HoveredCtrl := FindControl(Wnd);
            end;
        end;

        // Если мы навелись на новый контрол, переключаем подписку FreeNotification
        if HoveredCtrl <> FLastHoveredCtrl then
        begin
            if Assigned(FLastHoveredCtrl) then
                FLastHoveredCtrl.RemoveFreeNotification(Self);

            FLastHoveredCtrl := HoveredCtrl;

            if Assigned(FLastHoveredCtrl) then
                FLastHoveredCtrl.FreeNotification(Self);
        end;
    end;

    if Assigned(HoveredCtrl) and FRegistered.TryGetValue(HoveredCtrl, Setup) and HoveredCtrl.Enabled then
    begin
        if FCurrentTarget <> HoveredCtrl then
        begin
            HideButton;
            HookTarget(HoveredCtrl);
            FHelpState := hsWaiting;
            FWaitStartTick := CurrentTime;
            UpdateButtonPosition(HoveredCtrl, Setup.Position);
        end
        else
        begin
            if FHelpState = hsHidden then
            begin
                FHelpState := hsWaiting;
                FWaitStartTick := CurrentTime;
                UpdateButtonPosition(FCurrentTarget, Setup.Position);
            end;

            WaitDelay := FSettings.Help.HelpButton.HoverDelay;
            AnimDuration := FSettings.Help.HelpButton.FadeDuration;

            case FHelpState of
                hsWaiting:
                    begin
                        if (CurrentTime - FWaitStartTick) > WaitDelay then
                        begin
                            FHelpState := hsFadingIn;
                            FFadeStartTick := CurrentTime;
                            // Сбрасываем прозрачность, чтобы избежать мигания от предыдущего состояния
                            FSharedButton.AlphaBlendValue := 0;
                            ShowWindow(FSharedButton.Handle, SW_SHOWNOACTIVATE);
                        end;
                    end;
                hsFadingIn:
                    begin
                        Elapsed := CurrentTime - FFadeStartTick;
                        if (AnimDuration <= 0) or (Elapsed >= AnimDuration) then
                        begin
                            FHelpState := hsVisible;
                            FSharedButton.AlphaBlendValue := 255;
                        end
                        else
                        begin
                            var Progress := Elapsed / AnimDuration;
                            FSharedButton.AlphaBlendValue := Round(255 * Sin(Progress * (Pi / 2)));
                        end;
                    end;
            end;
        end;
    end
    else
    begin
        HideButton;
    end;
end;

procedure TUIHoverHelpManager.UpdateButtonPosition(Target: TControl; Pos: THelpIconPosition);
const
    OFFSET_X = -1;
    OFFSET_Y = -1;
var
    Pt: TPoint;
    TargetW, TargetH: Integer;
begin
    TargetW := Target.ClientWidth;
    TargetH := Target.ClientHeight;

    case Pos of
        hipTopLeft:     Pt := Point(OFFSET_X, OFFSET_Y);
        hipTopRight:    Pt := Point(TargetW - BTN_WIDTH - OFFSET_X, OFFSET_Y);
        hipLeftCenter:  Pt := Point(OFFSET_X, (TargetH - BTN_HEIGHT) div 2);
        hipRightCenter: Pt := Point(TargetW - BTN_WIDTH - OFFSET_X, (TargetH - BTN_HEIGHT) div 2);
        hipBottomLeft:  Pt := Point(OFFSET_X, TargetH - BTN_HEIGHT - OFFSET_Y);
        hipBottomRight: Pt := Point(TargetW - BTN_WIDTH - OFFSET_X, TargetH - BTN_HEIGHT - OFFSET_Y);
    end;

    Pt := Target.ClientToScreen(Pt);
    FSharedButton.Left := Pt.X;
    FSharedButton.Top := Pt.Y;
end;

end.
