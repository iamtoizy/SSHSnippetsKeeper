unit BaseFormUI;

interface

uses
    Winapi.Messages,
    System.Classes,
    Vcl.Forms,
    Vcl.Controls,
    UI.HoverHelpManager,
    Core.Interfaces,
    CustomHelpFormUI,
    Core.AppContext;

type
    TBaseFormState = (bfsDBConnected, bfsDBDisconnected, bfsDBOpen, bfsSnippetSelected, bfsSnippetDeselected);

    TBaseForm = class(TForm, ILocalizable)
    private
        FHelpManager: TUIHoverHelpManager;
        FCustomHelpForm: TCustomHelpForm;
        procedure DoShowHelp(Target: TControl; const HelpKey: string; HelpKind: THelpKind);
    function GetErrorHandler: IUIMessagesHandler;
    protected
        FAppContext: IAppContext;
        // Хук для дочерних классов. Виртуальный, но пустой по умолчанию.
        // Дочерний класс переопределяет его, ЕСЛИ ему нужно что-то инициализировать у себя.
        procedure DoInitialize; virtual;
        procedure DoShow; override;
        procedure RegisterHelp(Control: TControl; Position: THelpIconPosition; const HelpKey: string; HelpKind: THelpKind = hkCustomForm);
        property MessagesHandler: IUIMessagesHandler read GetErrorHandler;
    public
        constructor Create(Owner: TComponent); override;
        destructor Destroy; override;
        procedure UpdateUI(const State: TBaseFormState); virtual;
        procedure Initialize(AppContext: IAppContext);
        procedure ApplyLanguage; virtual;
    end;

implementation

uses
    Vcl.Dialogs,
    UI.StateLoader,
    System.SysUtils,
    CommonHelpers;

procedure TBaseForm.ApplyLanguage;
begin
    // Автоматически прогоняем все стандартные компоненты через ваш StateLoader
    TUIStateLoader.ApplyTranslations(Self);
end;

constructor TBaseForm.Create(Owner: TComponent);
begin
    inherited Create(Owner);
    FHelpManager := TUIHoverHelpManager.Create(Self);
    FHelpManager.OnShowHelp := DoShowHelp;
    FCustomHelpForm := TCustomHelpForm.Create(Self);
end;

destructor TBaseForm.Destroy;
begin
    if Assigned(FCustomHelpForm) then FCustomHelpForm.Free;
    inherited Destroy;
end;

procedure TBaseForm.RegisterHelp(Control: TControl; Position: THelpIconPosition; const HelpKey: string; HelpKind: THelpKind = hkCustomForm);
begin
    FHelpManager.RegisterControl(Control, Position, HelpKey, HelpKind);
end;

procedure TBaseForm.DoInitialize;
begin
    // По умолчанию пусто — базовой форме нечего добавлять
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

function TBaseForm.GetErrorHandler: IUIMessagesHandler;
begin
    Result := FAppContext.ErrorHandler;
end;

procedure TBaseForm.Initialize(AppContext: IAppContext);
begin
    // Гарантируем, что контекст не пустой
    if not Assigned(AppContext) then
        raise EArgumentNilException.Create('AppContext can not be nil!');

    FAppContext := AppContext;

    // Применяем локализацию
    TUIStateLoader.ApplyTranslations(Self);

    // Гарантированно пробрасываем настройки в HelpManager в одном месте для ВСЕХ форм!
    // Дочерним формам вообще не нужно знать, как устроен менеджер справки внутри базовой.
    FHelpManager.Configure(FAppContext.SettingsManager.Data.UISettings);

    // Вызываем кастомную логику дочерней формы (если она переопределена)
    DoInitialize;
end;

procedure TBaseForm.UpdateUI(const State: TBaseFormState);
begin
//
end;

end.
