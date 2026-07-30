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
    Vcl.StdCtrls,
    Winapi.Messages,
    Winapi.Windows;

type
    THelpIconPosition = (
        hipTopLeft,
        hipTopCenter,
        hipTopRight,
        hipLeftCenter,
        hipRightCenter,
        hipBottomLeft,
        hipBottomCenter,
        hipBottomRight
    );
    THelpKind = (hkCustomForm, hkTaskDialog);
    THelpState = (hsHidden, hsWaiting, hsFadingIn, hsVisible);

    THelpSetup = record
        Position: THelpIconPosition;
        HelpKey: string;
        HelpKind: THelpKind;
        OffsetX: Integer;
        OffsetY: Integer;
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
        FLastWnd: HWND;
        FStopwatch: TStopwatch;
        FLastMousePt: TPoint;
        FLastHoveredCtrl: TControl;
        FCurrentTarget: TControl;
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
        procedure UpdateButtonPosition(Target: TControl; const Setup: THelpSetup);
        procedure HideButton;
    protected
        procedure Notification(Component: TComponent; Operation: TOperation); override;
    public
        constructor Create(Owner: TComponent); override;
        destructor Destroy; override;

        procedure RegisterControl(
            Control: TControl;
            Position: THelpIconPosition;
            const HelpKey: string;
            HelpKind: THelpKind = hkCustomForm;
            OffsetX: Integer = 0;
            OffsetY: Integer = 0
        );
        procedure UnregisterControl(Control: TControl);
        procedure UnregisterAllForOwner(AOwner: TComponent);
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
    Params.ExStyle := Params.ExStyle or WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE or WS_EX_TOPMOST;
    Params.WndParent := 0;
end;

procedure THelpPopupWindow.CreateWnd;
var
    Rgn: HRGN;
begin
    inherited;
    Rgn := CreateRoundRectRgn(0, 0, Width, Height, 4, 4);
    SetWindowRgn(Handle, Rgn, True);
end;

procedure THelpPopupWindow.WMMouseActivate(var Message: TWMMouseActivate);
begin
    Message.Result := MA_NOACTIVATE;
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

    FStopwatch := TStopwatch.StartNew;
    FLastMousePt := Point(-1, -1);

    FTimer := TTimer.Create(Self);
    FTimer.Interval := 15;
    FTimer.OnTimer := OnTimerTick;
end;

destructor TUIHoverHelpManager.Destroy;
begin
    UnhookTarget;
    FTimer.Free;
    FSharedButton.Free;
    FRegistered.Free;
    inherited Destroy;
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

    if Operation = opRemove then
    begin
        if Component = FLastHoveredCtrl then
            FLastHoveredCtrl := nil;

        if Component = FCurrentTarget then
            HideButton;

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

    if (Message.Msg = WM_VSCROLL) or (Message.Msg = WM_HSCROLL) or
       (Message.Msg = WM_MOUSEWHEEL) or (Message.Msg = WM_KEYDOWN) or
       (Message.Msg = WM_LBUTTONDOWN) then
    begin
        HideButton;
    end;

    if Assigned(OldProc) then
        OldProc(Message);
end;

procedure TUIHoverHelpManager.RegisterControl(
    Control: TControl;
    Position: THelpIconPosition;
    const HelpKey: string;
    HelpKind: THelpKind;
    OffsetX: Integer;
    OffsetY: Integer);
var
    Setup: THelpSetup;
begin
    Setup := Default(THelpSetup);
    Setup.Position := Position;
    Setup.HelpKey := HelpKey;
    Setup.HelpKind := HelpKind;
    Setup.OffsetX := OffsetX;
    Setup.OffsetY := OffsetY;

    FRegistered.AddOrSetValue(Control, Setup);
    Control.FreeNotification(Self);
end;

procedure TUIHoverHelpManager.UnregisterControl(Control: TControl);
begin
    FRegistered.Remove(Control);
    if FCurrentTarget = Control then
        HideButton;
end;

procedure TUIHoverHelpManager.UnregisterAllForOwner(AOwner: TComponent);
var
    Ctrl: TControl;
    KeysArray: TArray<TControl>;
begin
    if not Assigned(AOwner) then Exit;

    // 1. Создаем статичную копию ключей (массив).
    // Теперь нам не страшны любые модификации словаря FRegistered
    // ни из нашего кода, ни из асинхронных вызовов Notification.
    KeysArray := FRegistered.Keys.ToArray;

    for Ctrl in KeysArray do
    begin
        // 2. Обязательно проверяем, что контрол всё ещё жив и не находится в процессе удаления
        if Assigned(Ctrl) and not (csDestroying in Ctrl.ComponentState) then
        begin
            if (Ctrl.Owner = AOwner) or
               ((AOwner is TCustomForm) and (GetParentForm(Ctrl) = AOwner)) then
            begin
                // Безопасно отписываем.
                // Даже если внутри сработает FRegistered.Remove, наш массив KeysArray не пострадает.
                UnregisterControl(Ctrl);
            end;
        end;
    end;
end;

procedure TUIHoverHelpManager.OnPopupButtonClick(Sender: TObject);
var
    Setup: THelpSetup;
    CachedTarget: TControl;
begin
    if Assigned(FCurrentTarget) and FRegistered.TryGetValue(FCurrentTarget, Setup) then
    begin
        CachedTarget := FCurrentTarget;
        HideButton;

        if Assigned(FOnShowHelp) then
            FOnShowHelp(CachedTarget, Setup.HelpKey, Setup.HelpKind);
    end;
end;

procedure TUIHoverHelpManager.HideButton;
begin
    UnhookTarget;
    FHelpState := hsHidden;
    FLastHoveredCtrl := nil;
    FLastMousePt := Point(-1, -1);
    FLastWnd := 0;

    if Assigned(FSharedButton) and FSharedButton.HandleAllocated then
    begin
        FSharedButton.AlphaBlendValue := 0;
        ShowWindow(FSharedButton.Handle, SW_HIDE);
    end;
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
        HoveredCtrl := FLastHoveredCtrl
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

        FLastHoveredCtrl := HoveredCtrl;
    end;

    if Assigned(HoveredCtrl) and FRegistered.TryGetValue(HoveredCtrl, Setup) and HoveredCtrl.Enabled then
    begin
        if FCurrentTarget <> HoveredCtrl then
        begin
            HideButton;
            HookTarget(HoveredCtrl);
            FHelpState := hsWaiting;
            FWaitStartTick := CurrentTime;
            UpdateButtonPosition(HoveredCtrl, Setup);
        end
        else
        begin
            if FHelpState = hsHidden then
            begin
                FHelpState := hsWaiting;
                FWaitStartTick := CurrentTime;
                UpdateButtonPosition(FCurrentTarget, Setup);
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
                            FSharedButton.AlphaBlendValue := 0;

                            // [ИСПРАВЛЕНИЕ БАГА Z-ORDER]
                            // Принудительно размещаем кнопку ПОВЕРХ ВСЕХ окон.
                            // Это необходимо для форм со свойством fsStayOnTop,
                            // иначе после закрытия модального окна они перекрывают кнопку.
                            SetWindowPos(FSharedButton.Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);

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
        HideButton;
end;

procedure TUIHoverHelpManager.UpdateButtonPosition(Target: TControl; const Setup: THelpSetup);
const
    BASE_OFFSET_X = -1;
    BASE_OFFSET_Y = -1;
var
    Pt: TPoint;
    TargetW, TargetH: Integer;
    RightPadding: Integer;
    CurrentDPI: Integer;
    ScaledOffsetX, ScaledOffsetY: Integer;
    ActualBtnW, ActualBtnH: Integer;
begin
    TargetW := Target.ClientWidth;
    TargetH := Target.ClientHeight;
    RightPadding := 0;

    // 1. Определяем текущий масштаб (DPI) контрола, над которым мы находимся.
    // В Delphi 10.3 Rio или новее у TControl есть CurrentPPI
    {$IF CompilerVersion >= 33.0}
    CurrentDPI := Target.CurrentPPI;
    {$ELSE}
    CurrentDPI := Screen.PixelsPerInch;
    {$ENDIF}

    // 2. Берем реальную ширину и высоту кнопки (VCL может сама отмасштабировать THelpPopupWindow)
    // Это безопаснее, чем использовать константы BTN_WIDTH
    ActualBtnW := FSharedButton.Width;
    ActualBtnH := FSharedButton.Height;

    // 3. Масштабируем ручные оффсеты под текущий DPI монитора.
    // Если на 100% масштабе (96 DPI) OffsetX был -10, то на 200% (192 DPI) он станет -20
    ScaledOffsetX := MulDiv(Setup.OffsetX, CurrentDPI, 96);
    ScaledOffsetY := MulDiv(Setup.OffsetY, CurrentDPI, 96);

    // Автоматически вычисляем ширину встроенных кнопок (стрелочек)
    if (Target is TCustomComboBox) or (Target.ClassName = 'TSpinEdit') then
    begin
        // Масштабируем и системную метрику для HighDPI
        RightPadding := MulDiv(GetSystemMetrics(SM_CXVSCROLL), CurrentDPI, 96);
    end;

    // Вычитаем RightPadding из позиций, привязанных к праавому краю (Right)
    case Setup.Position of
        hipTopLeft:      Pt := Point(BASE_OFFSET_X, BASE_OFFSET_Y);
        hipTopCenter:    Pt := Point((TargetW - ActualBtnW) div 2, BASE_OFFSET_Y);
        hipTopRight:     Pt := Point(TargetW - RightPadding - ActualBtnW - BASE_OFFSET_X, BASE_OFFSET_Y);

        hipLeftCenter:   Pt := Point(BASE_OFFSET_X, (TargetH - ActualBtnH) div 2);
        hipRightCenter:  Pt := Point(TargetW - RightPadding - ActualBtnW - BASE_OFFSET_X, (TargetH - ActualBtnH) div 2);

        hipBottomLeft:   Pt := Point(BASE_OFFSET_X, TargetH - ActualBtnH - BASE_OFFSET_Y);
        hipBottomCenter: Pt := Point((TargetW - ActualBtnW) div 2, TargetH - ActualBtnH - BASE_OFFSET_Y);
        hipBottomRight:  Pt := Point(TargetW - RightPadding - ActualBtnW - BASE_OFFSET_X, TargetH - ActualBtnH - BASE_OFFSET_Y);
    end;

    // Применяем отмасштабированные ручные смещения
    Pt.X := Pt.X + ScaledOffsetX;
    Pt.Y := Pt.Y + ScaledOffsetY;

    Pt := Target.ClientToScreen(Pt);

    // Перемещаем кнопку и выводим на передний план
    SetWindowPos(FSharedButton.Handle, HWND_TOPMOST, Pt.X, Pt.Y, ActualBtnW, ActualBtnH, SWP_NOACTIVATE);
end;

end.
