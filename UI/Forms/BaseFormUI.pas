unit BaseFormUI;

interface

uses
    Core.Interfaces.App,
    Core.Interfaces.Services,
    Core.Interfaces.Settings,
    Core.Interfaces.UI,
    CustomHelpFormUI,
    System.Classes,
    System.Generics.Collections,
    System.SysUtils,
    UI.HoverHelpManager,
    Vcl.Controls,
    Vcl.Forms,
    Winapi.Messages
    ;

type
    TForm = class(Vcl.Forms.TForm)
    protected
        procedure DoStyleRecreated; virtual;
        procedure DoShownOnScreen; virtual;
    public
        procedure WndProc(var Message: TMessage); override;
    end;

    TBaseFormState = (
        bfsDBConnected,
        bfsDBDisconnected,
        bfsDBOpen,
        bfsSnippetSelected,
        bfsSnippetDeselected
    );

    TBaseForm = class(TForm, ILocalizable)
    private
        // Глобальный реестр открытых форм (Класс -> Экземпляр)
        class var FInstances: TDictionary<TClass, TBaseForm>;

        FHelpManager: TUIHoverHelpManager;
        FCustomHelpForm: TCustomHelpForm;
        FShowGuardPending: Boolean;
        FGuardCenterRef: TCustomForm;
        procedure DoShowHelp(Target: TControl; const HelpKey: string; HelpKind: THelpKind);
        function GetMessagesHandler: IUIMessagesHandler;

        // Классовые конструктор и деструктор для инициализации словаря
        class constructor CreateClass;
        class destructor DestroyClass;
        function GetAppContext: IAppContext;
    protected
        FAppContext: IAppContext;
        // Хук для дочерних классов. Виртуальный, но пустой по умолчанию.
        // Дочерний класс переопределяет его, ЕСЛИ ему нужно что-то инициализировать у себя.
        // TODO Использовать в дочерних DoInitialize
        procedure DoInitialize; virtual;
        procedure DoShow; override;
        procedure DoShownOnScreen; override;
        procedure RegisterHelp(
            Control: TControl;
            Position: THelpIconPosition;
            const HelpKey: string;
            HelpKind: THelpKind = hkCustomForm;
            OffsetX: Integer = 0;
            OffsetY: Integer = 0);

        // Добавил метод для точечной отписки, на случай если в будущем вы будете
        // динамически удалять контролы с формы в рантайме.
        procedure UnregisterHelp(Control: TControl);

        // Переопределяем закрытие окна в базовом классе
        procedure DoClose(var Action: TCloseAction); override;

        property MessagesHandler: IUIMessagesHandler read GetMessagesHandler;
        property AppContext: IAppContext read GetAppContext;
    public
        constructor Create(Owner: TComponent); override;
        destructor Destroy; override;
        procedure UpdateUI(const State: TBaseFormState); virtual;
        procedure Initialize(AppContext: IAppContext);
        procedure WarmUpPaint;
        procedure PrepareGuardedShow;
        procedure FinishGuardedShow;
        // Показывает кольцо занятости по центру формы на время выполнения AWork
        procedure ShowBusyWhile(const ACaption: string; AWork: TProc);
        procedure ForceForeground;
        procedure ApplyLanguage; virtual;
        // Открыть справку с произвольным HTML-телом (переиспользует FCustomHelpForm)
        procedure ShowCustomHelpHtml(const ATitle, ABodyHtml: string);
        // Для плавающих окон (Калькуляторы, Конвертеры)
        class procedure ExecuteGlobal(Owner: TComponent; AppContext: IAppContext);

        // Для диалогов (Настройки, Менеджер рабочих пространств)
        class function ExecuteModal(Owner: TComponent; AppContext: IAppContext): TModalResult;
    end;

implementation

uses
    Common.Localization,
    SynThemeAdapter,
    UI.BusyIndicator,
    Vcl.Dialogs,
    Vcl.Graphics,
    Winapi.Windows
    ;

procedure TForm.WndProc(var Message: TMessage);
var
    StyleChanged: Boolean;
    ShownNow: Boolean;
begin
    StyleChanged := Message.Msg = CM_CUSTOMSTYLECHANGED;
    ShownNow := (Message.Msg = WM_WINDOWPOSCHANGED) and (PWindowPos(Message.LParam) <> nil)
        and ((PWindowPos(Message.LParam).flags and SWP_SHOWWINDOW) <> 0);
    if StyleChanged then
        ActiveControl := nil;
    inherited WndProc(Message);
    if StyleChanged then
        DoStyleRecreated;
    if ShownNow then
        DoShownOnScreen;
end;

procedure TForm.DoStyleRecreated;
begin
end;

procedure TForm.DoShownOnScreen;
begin
end;

procedure TBaseForm.ApplyLanguage;
begin
    // Автоматически прогоняем все стандартные компоненты через StateLoader
    TUIStateLoader.ApplyTranslations(Self);
end;

constructor TBaseForm.Create(Owner: TComponent);
begin
    inherited Create(Owner);
    FHelpManager := TUIHoverHelpManager.Create(Self);
    FHelpManager.OnShowHelp := DoShowHelp;
    FCustomHelpForm := TCustomHelpForm.Create(Self);
end;

class constructor TBaseForm.CreateClass;
begin
    FInstances := TDictionary<TClass, TBaseForm>.Create;
end;

destructor TBaseForm.Destroy;
begin
    // 1. Менеджер справки уничтожаем первым: его всплывающая кнопка
    // является самостоятельным окном и иначе переживёт разрушение формы.
    if Assigned(FHelpManager) then
        FreeAndNil(FHelpManager);

    // 2. Безопасное удаление дочерних форм
    if Assigned(FCustomHelpForm) then
        FreeAndNil(FCustomHelpForm);

    inherited Destroy;
end;

class destructor TBaseForm.DestroyClass;
begin
    FInstances.Free;
end;

procedure TBaseForm.RegisterHelp(
            Control: TControl;
            Position: THelpIconPosition;
            const HelpKey: string;
            HelpKind: THelpKind = hkCustomForm;
            OffsetX: Integer = 0;
            OffsetY: Integer = 0);
begin
    if Assigned(FHelpManager) then
        FHelpManager.RegisterControl(Control, Position, HelpKey, HelpKind, OffsetX, OffsetY);
end;

procedure TBaseForm.UnregisterHelp(Control: TControl);
begin
    // Обертка на случай, вам понадобится снять хелп с конкретного контрола.
    if Assigned(FHelpManager) then
        FHelpManager.UnregisterControl(Control);
end;

procedure TBaseForm.ShowCustomHelpHtml(const ATitle, ABodyHtml: string);
begin
    if csDestroying in ComponentState then Exit;

    if FCustomHelpForm = nil then
        FCustomHelpForm := TCustomHelpForm.Create(Self);
    FCustomHelpForm.SetContentHtml(ATitle, ABodyHtml);
    FCustomHelpForm.ShowModal;
end;

procedure TBaseForm.DoClose(var Action: TCloseAction);
begin
    inherited DoClose(Action); // Вызываем стандартную логику VCL и события OnClose

    // Проверяем: если форма открыта МОДАЛЬНО, мы НЕ делаем ей caFree,
    // так как блок try..finally в ExecuteModal сам сделает Instance.Free.
    if fsModal in FormState then
    begin
        Action := caHide; // Оставляем удаление на совести вызывающего
    end
    else
    begin
        // Если форма плавающая (ExecuteGlobal), она уничтожает себя сама
        Action := caFree;

        // И удаляет себя из реестра открытых окон
        if FInstances.ContainsKey(Self.ClassType) then
            FInstances.Remove(Self.ClassType);
    end;
end;

procedure TBaseForm.DoInitialize;
begin
    // По умолчанию пусто - базовому классу нечего добавлять
end;

procedure TBaseForm.DoShow;
begin
    // Если форма выводится на экран, а контекста нет - это грубейшая ошибка разработчика
    Assert(
        Assigned(FAppContext),
        Format('We forgot to call the Initialize method for the %s form after it was created!', [Self.ClassName])
    );
    inherited;
end;

procedure TBaseForm.DoShowHelp(Target: TControl; const HelpKey: string; HelpKind: THelpKind);
var
    TaskDlg: TTaskDialog;
    Title, MainText, ExpText: string;
begin
    if csDestroying in ComponentState then Exit;

    // Запрашиваем все три поля одним вызовом
    TUIStateLoader.GetHelpTexts(HelpKey, Title, MainText, ExpText);

    case HelpKind of
        // Отображение через кастомную форму
        hkCustomForm:
            begin
                if FCustomHelpForm = nil then
                    FCustomHelpForm := TCustomHelpForm.Create(Self);
                with FCustomHelpForm do
                begin
                    SetContent(Title, MainText, ExpText);
                    ShowModal;
                end;
            end;

        // Отображение через стандартный TTaskDialog
        hkTaskDialog:
            begin
                TaskDlg := TTaskDialog.Create(Self);
                try
                    TaskDlg.Caption := TUIStateLoader.GetMessage('Common.Help');
                    TaskDlg.Title := Title;
                    TaskDlg.Text := MainText;

                    if ExpText <> '' then
                    begin
                        TaskDlg.ExpandedText := ExpText;
                        TaskDlg.ExpandButtonCaption := TUIStateLoader.GetMessage('Common.MoreInfo');
                    end;

                    TaskDlg.MainIcon := tdiInformation;
                    TaskDlg.CommonButtons := [tcbClose];
                    TaskDlg.Execute;
                finally
                    TaskDlg.Free;
                end;
            end;
    end;
end;

class procedure TBaseForm.ExecuteGlobal(Owner: TComponent; AppContext: IAppContext);
var
    Instance: TBaseForm;
begin
    // В методах класса (class procedure) Self указывает на ТИП класса,
    // из которого был вызван метод (например, TChmodForm или TNetworkForm).

    // Проверяем, открыта ли уже форма такого класса
    if FInstances.TryGetValue(Self, Instance) then
    begin
        if Instance.WindowState = wsMinimized then
            Instance.WindowState := wsNormal;

        SetForegroundWindow(Instance.Handle);
        Instance.BringToFront;
        Exit;
    end;

    // Вызываем виртуальный конструктор Create. Delphi поймет, что нужно
    // создать именно дочерний класс (например, TChmodForm), а не TBaseForm.
    Instance := Self.Create(Application) as TBaseForm;

    // Регистрируем экземпляр в словаре ДО вызова Initialize,
    // на случай если внутри Initialize форма попытается обратиться к синглтону
    FInstances.Add(Self, Instance);


    Instance.LockDrawing; // Попытка уменьшить мерцание формы со стилями VCL
    try
        Instance.Initialize(AppContext);
        Instance.FormStyle := fsStayOnTop;
    finally
        Instance.UnlockDrawing;   // Попытка уменьшить мерцание формы со стилями VCL
    end;
    Instance.WarmUpPaint;
    Instance.PrepareGuardedShow;
    Instance.Show;
end;

class function TBaseForm.ExecuteModal(Owner: TComponent; AppContext: IAppContext): TModalResult;
var
    Instance: TBaseForm;
begin
    // Для модальных окон нам не нужен реестр FInstances.
    // Просто создаем, инициализируем, показываем с блокировкой и уничтожаем.
    Instance := Self.Create(Owner) as TBaseForm;
    try
        Instance.Initialize(AppContext);
        Instance.WarmUpPaint;
        Instance.PrepareGuardedShow;
        Result := Instance.ShowModal;
    finally
        Instance.Free;
    end;
end;

procedure TBaseForm.WarmUpPaint;

    procedure PaintTree(Control: TWinControl; DC: HDC);
    var
        I: Integer;
        Child: TControl;
    begin
        if Control <> Self then
        begin
            Control.HandleNeeded;
            Control.Perform(WM_PAINT, DC, 0);
        end;

        for I := 0 to Control.ControlCount - 1 do
        begin
            Child := Control.Controls[I];
            if Child is TWinControl then
                PaintTree(TWinControl(Child), DC);
        end;
    end;

var
    Bmp: Vcl.Graphics.TBitmap;
begin
    if not HandleAllocated then
        Exit;

    Bmp := Vcl.Graphics.TBitmap.Create;
    try
        Bmp.SetSize(Width, Height);
        PaintTree(Self, Bmp.Canvas.Handle);
        Perform(WM_PRINT, Bmp.Canvas.Handle, PRF_CHILDREN or PRF_CLIENT or PRF_ERASEBKGND or PRF_NONCLIENT);
    finally
        Bmp.Free;
    end;
end;

procedure TBaseForm.PrepareGuardedShow;
var
    ExStyle: LONG;
    R: TRect;
begin
    FGuardCenterRef := Screen.ActiveCustomForm;
    FShowGuardPending := True;
    Position := poDesigned;

    if (FGuardCenterRef <> nil) and FGuardCenterRef.Visible then
        R := FGuardCenterRef.BoundsRect
    else
        R := Screen.WorkAreaRect;

    Left := R.Left + (R.Width - Width) div 2;
    Top := R.Top + (R.Height - Height) div 2;
    if Left + Width > Screen.WorkAreaLeft + Screen.WorkAreaWidth then
        Left := Screen.WorkAreaLeft;
    if Top + Height > Screen.WorkAreaTop + Screen.WorkAreaHeight then
        Top := Screen.WorkAreaTop;
    if Left < Screen.WorkAreaLeft then
        Left := Screen.WorkAreaLeft;
    if Top < Screen.WorkAreaTop then
        Top := Screen.WorkAreaTop;

    ExStyle := GetWindowLong(Handle, GWL_EXSTYLE);
    if (ExStyle and WS_EX_LAYERED) = 0 then
        SetWindowLong(Handle, GWL_EXSTYLE, ExStyle or WS_EX_LAYERED);
    SetLayeredWindowAttributes(Handle, 0, 1, LWA_ALPHA);
end;

procedure TBaseForm.FinishGuardedShow;
begin
    FShowGuardPending := False;

    RedrawWindow(Handle, nil, 0,
        RDW_INVALIDATE or RDW_ERASE or RDW_FRAME or RDW_ALLCHILDREN or RDW_UPDATENOW);

    SetLayeredWindowAttributes(Handle, 0, 255, LWA_ALPHA);
end;

procedure TBaseForm.ShowBusyWhile(const ACaption: string; AWork: TProc);
begin
    TUIBusyIndicator.Run(Self, ACaption, AWork);
end;

procedure TBaseForm.DoShownOnScreen;
begin
    inherited;

    if FShowGuardPending then
        FinishGuardedShow;

    // Индикатор занятости живёт до фактического показа подготовленной формы
    TUIBusyIndicator.Hide;
end;

procedure TBaseForm.ForceForeground;
var
    ForeWnd: HWND;
    ForeThread, ThisThread: DWORD;
    Attached: Boolean;
begin
    if not HandleAllocated then
        Exit;

    ForeWnd := GetForegroundWindow;
    if ForeWnd = Handle then
        Exit;

    Attached := False;
    ThisThread := GetCurrentThreadId;
    ForeThread := 0;
    if ForeWnd <> 0 then
        ForeThread := GetWindowThreadProcessId(ForeWnd, nil);

    if (ForeThread <> 0) and (ForeThread <> ThisThread) then
        Attached := AttachThreadInput(ThisThread, ForeThread, True);
    try
        SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0,
            SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
        SetWindowPos(Handle, HWND_NOTOPMOST, 0, 0, 0, 0,
            SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
        SetForegroundWindow(Handle);
    finally
        if Attached then
            AttachThreadInput(ThisThread, ForeThread, False);
    end;
end;

function TBaseForm.GetAppContext: IAppContext;
begin
    Result := FAppContext;
end;

function TBaseForm.GetMessagesHandler: IUIMessagesHandler;
begin
    Result := FAppContext.MessagesHandler;
end;

procedure TBaseForm.Initialize(AppContext: IAppContext);
begin
    // Гарантируем, что контекст не пустой
    if not Assigned(AppContext) then
        raise EArgumentNilException.Create('AppContext can not be nil!');  // TODO: Локализовать!

    FAppContext := AppContext;

    // Применяем локализацию
    TUIStateLoader.ApplyTranslations(Self);

    TSynThemeAdapter.ThemeFormControls(Self);

    // Гарантированно пробрасываем настройки в HelpManager в одном месте для ВСЕХ форм.
    // Дочерним формам вообще не нужно знать, как устроен менеджер справки внутри базовой.
    FHelpManager.Configure(FAppContext.SettingsManager.Data.UISettings);

    // Автоматически применяем горячие клавиши для дочерней формы.
    if Assigned(FAppContext.HotkeyService) then
        FAppContext.HotkeyService.ApplySettingsToForm(Self);

    // Вызываем кастомную логику дочерней формы (если она переопределена)
    DoInitialize;
end;

procedure TBaseForm.UpdateUI(const State: TBaseFormState);
begin
//
end;

end.
