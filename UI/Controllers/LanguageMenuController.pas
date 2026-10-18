unit LanguageMenuController;

interface

uses
    Core.Interfaces.App,
    System.Classes,
    System.SysUtils,
    UI.AppStatusBar,
    Vcl.Menus
    ;

const
    // Индекс панели StatusBar, клик по которой открывает меню языков
    LANG_PANEL_INDEX = TAppStatusBar.SB_PANEL_LANG;

type
    // Меню выбора языка: построение списка из Translation\ui-texts.*.json
    // и переключение языка приложения на лету.
    TLanguageMenuController = class
    private
        FPopupMenu: TPopupMenu;
        FAppStatus: TAppStatusBar;
        FContext: IAppContext;
        FOnLanguageSelected: TNotifyEvent;
    public
        constructor Create(APopupMenu: TPopupMenu; AStatusBar: TAppStatusBar;
            AContext: IAppContext; AOnLanguageSelected: TNotifyEvent);

        procedure BuildMenu;
        procedure SelectLanguage(const LangCode: string);
    end;

implementation

uses
    Common.Localization,
    Common.Helpers,
    Core.Interfaces.Settings,
    Core.Interfaces.UI,
    System.IOUtils,
    Vcl.Forms
    ;

{ TLanguageMenuController }

constructor TLanguageMenuController.Create(APopupMenu: TPopupMenu; AStatusBar: TAppStatusBar;
    AContext: IAppContext; AOnLanguageSelected: TNotifyEvent);
begin
    inherited Create;
    FPopupMenu := APopupMenu;
    FAppStatus := AStatusBar;
    FContext := AContext;
    FOnLanguageSelected := AOnLanguageSelected;
end;

procedure TLanguageMenuController.BuildMenu;
var
    Files: TArray<string>;
    FileName, LangCode, TranslationsDir, CurrentLang: string;
    MI: TMenuItem;
begin
    TranslationsDir := ResolvePath('Translation', True);
    if not TDirectory.Exists(TranslationsDir) then Exit;

    Files := TDirectory.GetFiles(TranslationsDir, 'ui-texts.*.json');

    FPopupMenu.Items.Clear;

    if Assigned(FContext) then
        CurrentLang := FContext.SettingsManager.Data.CurrentLanguage
    else
        CurrentLang := 'ru';

    for FileName in Files do
    begin
        // Извлекаем код языка: ui-texts.en.json -> en
        LangCode := ExtractFileName(FileName);
        LangCode := StringReplace(LangCode, 'ui-texts.', '', [rfIgnoreCase]);
        LangCode := StringReplace(LangCode, '.json', '', [rfIgnoreCase]);

        // Создаем пункт меню
        MI := TMenuItem.Create(FPopupMenu);
        MI.Caption := UpperCase(LangCode); // 'RU', 'EN'
        MI.Hint := LangCode;
        MI.RadioItem := True;
        MI.GroupIndex := 1;
        MI.OnClick := FOnLanguageSelected;

        FPopupMenu.Items.Add(MI);

        // Отмечаем галочкой текущий язык без вызова MI.Click (избегаем рекурсии)
        if SameText(LangCode, CurrentLang) then
        begin
            MI.Checked := True;
            FAppStatus.SetLanguage('🌐 ' + UpperCase(LangCode));
        end;
    end;
end;

procedure TLanguageMenuController.SelectLanguage(const LangCode: string);
var
    I: Integer;
    LocForm: ILocalizable;
begin
    // Обновляем надпись в StatusBar
    FAppStatus.SetLanguage('🌐 ' + UpperCase(LangCode));

    // Сохраняем выбор в настройки
    FContext.SettingsManager.CurrentLanguage := LangCode;
    FContext.SettingsManager.Save;

    // Загружаем новый JSON-файл в память
    TUIStateLoader.LoadLanguageFile(ResolvePath('Translation\ui-texts.' + LangCode + '.json'));

    // Переводим все открытые окна
    for I := 0 to Screen.FormCount - 1 do
    begin
        if Supports(Screen.Forms[I], ILocalizable, LocForm) then
            LocForm.ApplyLanguage;
    end;
end;

end.
