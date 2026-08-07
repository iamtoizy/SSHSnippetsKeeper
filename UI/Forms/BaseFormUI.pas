unit BaseFormUI;

interface

uses
    Core.Interfaces,
    CustomHelpFormUI,
    System.Classes,
    System.Generics.Collections,
    UI.HoverHelpManager,
    Vcl.Controls,
    Vcl.Forms
    ;

type
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
        procedure ApplyLanguage; virtual;
        // Для плавающих окон (Калькуляторы, Конвертеры)
        class procedure ExecuteGlobal(Owner: TComponent; AppContext: IAppContext);

        // Для диалогов (Настройки, Менеджер рабочих пространств)
        class function ExecuteModal(Owner: TComponent; AppContext: IAppContext): TModalResult;
    end;

implementation

uses
    System.SysUtils,
    UI.StateLoader,
    Vcl.Dialogs,
    Winapi.Windows
    ;

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
    // Запрашиваем все три поля одним вызовом
    TUIStateLoader.GetHelpTexts(HelpKey, Title, MainText, ExpText);

    case HelpKind of
        // Отображение через кастомную форму
        hkCustomForm:
            begin
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
    // В методах класса (class procedure) слово Self указывает на ТИП класса,
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

    Instance.Initialize(AppContext);
    Instance.FormStyle := fsStayOnTop;
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
        Result := Instance.ShowModal;
    finally
        Instance.Free;
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
        raise EArgumentNilException.Create('AppContext can not be nil!');

    FAppContext := AppContext;

    // Применяем локализацию
    TUIStateLoader.ApplyTranslations(Self);

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
