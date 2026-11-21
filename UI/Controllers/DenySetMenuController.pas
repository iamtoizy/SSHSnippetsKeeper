unit DenySetMenuController;

interface

uses
    Core.Interfaces.App,
    Core.Interfaces.Settings,
    System.Classes,
    System.SysUtils,
    UI.AppStatusBar,
    Vcl.Menus
    ;

const
    // Индекс панели StatusBar, клик по которой открывает меню deny-шаблонов
    DENY_PANEL_INDEX = TAppStatusBar.SB_PANEL_DENY;

type
    // Меню шаблонов deny-правил в статус-баре (по образцу языкового меню):
    // «Ничего не запрещено» + шаблоны, галочка у шаблона, чьи правила
    // совпадают с активным набором GlobalTitleDenyRules по значению
    TDenySetMenuController = class
    private
        FPopupMenu: TPopupMenu;
        FAppStatus: TAppStatusBar;
        FContext: IAppContext;
        FOnDenySetApplied: TProc;
        function CurrentRules: TArray<TGlobalTitleDenyRule>;
        function FindActiveSetIndex: Integer;
        procedure DenyItemClick(Sender: TObject);
    public
        constructor Create(APopupMenu: TPopupMenu; AStatusBar: TAppStatusBar;
            AContext: IAppContext; const AOnDenySetApplied: TProc);

        // Перестроить пункты и обновить панель статус-бара
        procedure BuildMenu;
    end;

implementation

uses
    Common.Localization,
    ProcessProfile,
    System.Math
    ;

{ TDenySetMenuController }

constructor TDenySetMenuController.Create(APopupMenu: TPopupMenu;
    AStatusBar: TAppStatusBar; AContext: IAppContext;
    const AOnDenySetApplied: TProc);
begin
    inherited Create;
    FPopupMenu := APopupMenu;
    FAppStatus := AStatusBar;
    FContext := AContext;
    FOnDenySetApplied := AOnDenySetApplied;
end;

function TDenySetMenuController.CurrentRules: TArray<TGlobalTitleDenyRule>;
begin
    Result := FContext.SettingsManager.Data.GlobalTitleDenyRules.Items;
end;

// Шаблон, чьи правила совпадают с активным набором по значению.
// -1 = нет совпадения (ручной набор, не совпадающий ни с одним шаблоном).
// Пустой активный набор подсвечивает пункт «Ничего не запрещено» (см. BuildMenu)
function TDenySetMenuController.FindActiveSetIndex: Integer;
var
    Setts: TAppSettings;
    I: Integer;
    Cur: TArray<TGlobalTitleDenyRule>;
begin
    Result := -1;
    Setts := FContext.SettingsManager.Data;
    Cur := Setts.GlobalTitleDenyRules.Items;

    for I := 0 to High(Setts.DenyRuleSets) do
    begin
        // Пустой шаблон не считается совпадением с пустым набором: пункт
        // «Ничего не запрещено» и так подсвечивается по длине набора
        if Length(Setts.DenyRuleSets[I].Rules) = 0 then
            Continue;
        if TProcessProfile.SameDenyRules(Cur, Setts.DenyRuleSets[I].Rules) then
            Exit(I);
    end;
end;

procedure TDenySetMenuController.DenyItemClick(Sender: TObject);
var
    Setts: TAppSettings;
    MI: TMenuItem;
    SetIndex: Integer;
begin
    MI := Sender as TMenuItem;
    SetIndex := MI.Tag;

    Setts := FContext.SettingsManager.Data;
    if SetIndex >= 0 then
    begin
        // Копия правил шаблона как новый активный набор; имя - «последний
        // применённый» для подсветки в конструкторе deny-правил
        Setts.GlobalTitleDenyRules.Items :=
            Copy(Setts.DenyRuleSets[SetIndex].Rules, 0,
                Length(Setts.DenyRuleSets[SetIndex].Rules));
        Setts.ActiveDenyRuleSet := Setts.DenyRuleSets[SetIndex].Name;
    end
    else
    begin
        // «Ничего не запрещено»: чистый набор
        Setts.GlobalTitleDenyRules.Items := nil;
        Setts.ActiveDenyRuleSet := '';
    end;

    FContext.SettingsManager.Data := Setts;
    FContext.SettingsManager.Save;

    // Гейт блокировки ввода читает правила отсюда: подмена на лету
    GProfileManager.SetGlobalDenyRules(Setts.GlobalTitleDenyRules.Items);

    // Перестроить галочки и текст панели
    BuildMenu;

    if Assigned(FOnDenySetApplied) then
        FOnDenySetApplied();
end;

procedure TDenySetMenuController.BuildMenu;
var
    Setts: TAppSettings;
    MI: TMenuItem;
    I, ActiveIdx: Integer;
    PanelText: string;
begin
    Setts := FContext.SettingsManager.Data;
    ActiveIdx := FindActiveSetIndex;

    FPopupMenu.Items.Clear;

    // «Ничего не запрещено»: галочка при пустом активном наборе
    MI := TMenuItem.Create(FPopupMenu);
    MI.Caption := TUIStateLoader.GetMessage('Settings.DenySetsEmptyItem');
    MI.RadioItem := True;
    MI.GroupIndex := 1;
    MI.Tag := -1;
    MI.OnClick := DenyItemClick;
    FPopupMenu.Items.Add(MI);
    MI.Checked := Length(CurrentRules) = 0;

    for I := 0 to High(Setts.DenyRuleSets) do
    begin
        MI := TMenuItem.Create(FPopupMenu);
        MI.Caption := Setts.DenyRuleSets[I].Name;
        MI.RadioItem := True;
        MI.GroupIndex := 1;
        MI.Tag := I;
        MI.OnClick := DenyItemClick;
        FPopupMenu.Items.Add(MI);
        MI.Checked := (I = ActiveIdx);
    end;

    // Панель статус-бара: совпадающий шаблон / «пользовательский набор» /
    // выключенная защита
    if ActiveIdx >= 0 then
        PanelText := Setts.DenyRuleSets[ActiveIdx].Name
    else if Length(CurrentRules) = 0 then
        PanelText := TUIStateLoader.GetMessage('Settings.DenySetsPanelOff')
    else
        PanelText := TUIStateLoader.GetMessage('Settings.DenySetsPanelCustom');

    FAppStatus.SetDenySet(PanelText);
end;

end.
