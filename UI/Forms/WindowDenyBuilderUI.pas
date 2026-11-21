unit WindowDenyBuilderUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    Core.Interfaces.Settings,
    System.Classes,
    System.RegularExpressions,
    System.SysUtils,
    UI.ListViewColumnSizing,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.Graphics,
    Vcl.StdCtrls
    ;

type
    // Режим построения regex из пользовательского текста: литеральные
    // режимы экранируются через TRegEx.Escape, маска переводит * и ?
    TTitlePatternMode = (pmContains, pmStartsWith, pmEndsWith, pmExact, pmWildcard, pmRegex);

    // Конструктор правил глобального запрета ввода: собирает regex
    // заголовка окна из текстовых режимов без ручного написания
    // выражений. Живое превью показывает, какие из открытых окон
    // правило запретит; двойной клик по окну подставляет его заголовок
    TWindowDenyBuilderDialog = class(TBaseForm)
        lblTitle: TLabel;
        pList: TPanel;
        lvRules: TListView;
        pListButtons: TPanel;
        bAdd: TButton;
        bDelete: TButton;
        pEditor: TPanel;
        leName: TLabeledEdit;
        lblMode: TLabel;
        cbMode: TComboBox;
        bCapture: TButton;
        leText: TLabeledEdit;
        chkCase: TCheckBox;
        chkEnabled: TCheckBox;
        lePattern: TLabeledEdit;
        lbHint: TLabel;
        pTemplates: TPanel;
        cbTemplates: TComboBox;
        bSaveTemplate: TButton;
        pPreview: TPanel;
        lvPreview: TListView;
        lbPreviewEmpty: TLabel;
        pBottom: TPanel;
        bOK: TButton;
        bCancel: TButton;
        procedure bAddClick(Sender: TObject);
        procedure bCaptureClick(Sender: TObject);
        procedure bDeleteClick(Sender: TObject);
        procedure bSaveTemplateClick(Sender: TObject);
        procedure cbTemplatesChange(Sender: TObject);
        procedure cbModeChange(Sender: TObject);
        procedure chkCaseClick(Sender: TObject);
        procedure chkEnabledClick(Sender: TObject);
        procedure leNameChange(Sender: TObject);
        procedure leTextChange(Sender: TObject);
        procedure lvPreviewDblClick(Sender: TObject);
        procedure lvRulesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure bOKClick(Sender: TObject);
    private
    FRules: TArray<TGlobalTitleDenyRule>;
    FSingleMode: Boolean;
    FEditingIndex: Integer;
    FUpdating: Boolean;
    FColFitter: TListViewColumnFitter;
    FDirty: Boolean;
    FActiveTemplateName: string;
        function CurrentMode: TTitlePatternMode;
        function CurrentPattern: string;
        function BuildPattern(const AText: string; AMode: TTitlePatternMode): string;
        function WildcardToRegex(const AMask: string): string;
        function RuleDisplayName(const ARule: TGlobalTitleDenyRule): string;
        function IsValidRegex(const APattern: string): Boolean;
        procedure LoadRuleToEditor(const ARule: TGlobalTitleDenyRule);
        procedure WriteEditorToRule(AIndex: Integer);
        procedure UpdateRuleRow(AIndex: Integer);
        procedure RebuildRuleList;
        procedure EditorChanged;
        procedure RefreshGenerated;
        procedure RefreshPreview;
        procedure MarkDirty;
        procedure LoadTemplatesCombo(const ACurrentRules: TArray<TGlobalTitleDenyRule>);
        function HasUnsavedChanges: Boolean;
        function PromptSaveTemplate: Boolean;
        procedure ApplyTemplate(const AName: string);
        procedure SaveActiveTemplateName;
        class function RunDialog(AOwner: TComponent; AppContext: IAppContext;
            ASingleMode: Boolean; const APattern: string;
            var ARules: TArray<TGlobalTitleDenyRule>;
            out ANewPattern: string): Boolean;
    public
        // Редактирование всего deny-набора (раздел настроек)
        class function Execute(AOwner: TComponent; AppContext: IAppContext;
            var ARules: TArray<TGlobalTitleDenyRule>): Boolean;
        // Построение одного выражения (кнопка «построить» в диалоге профиля)
        class function ExecuteSingle(AOwner: TComponent; AppContext: IAppContext;
            const APattern: string; out ANewPattern: string): Boolean;
    end;

implementation

uses
    Common.Localization,
    Common.RegexSafety,
    ProcessProfile,
    WindowMonitor
    ;

{$R *.dfm}

const
    MODE_KEY_NAMES: array[TTitlePatternMode] of string = (
        'Settings.DenyRulesModeContains',
        'Settings.DenyRulesModeStartsWith',
        'Settings.DenyRulesModeEndsWith',
        'Settings.DenyRulesModeExact',
        'Settings.DenyRulesModeWildcard',
        'Settings.DenyRulesModeRegex');

class function TWindowDenyBuilderDialog.Execute(AOwner: TComponent;
    AppContext: IAppContext; var ARules: TArray<TGlobalTitleDenyRule>): Boolean;
var
    NewPattern: string;
begin
    Result := RunDialog(AOwner, AppContext, False, '', ARules, NewPattern);
end;

class function TWindowDenyBuilderDialog.ExecuteSingle(AOwner: TComponent;
    AppContext: IAppContext; const APattern: string;
    out ANewPattern: string): Boolean;
var
    Rules: TArray<TGlobalTitleDenyRule>;
begin
    Result := RunDialog(AOwner, AppContext, True, APattern, Rules, ANewPattern);
end;

class function TWindowDenyBuilderDialog.RunDialog(AOwner: TComponent;
    AppContext: IAppContext; ASingleMode: Boolean; const APattern: string;
    var ARules: TArray<TGlobalTitleDenyRule>;
    out ANewPattern: string): Boolean;
var
    Instance: TWindowDenyBuilderDialog;
    Mode: TTitlePatternMode;
begin
    Result := False;
    ANewPattern := '';

    Instance := TWindowDenyBuilderDialog.Create(AOwner);
    try
        Instance.Initialize(AppContext);
        Instance.FSingleMode := ASingleMode;
        Instance.FEditingIndex := -1;
        Instance.FDirty := False;
        Instance.FColFitter := TListViewColumnFitter.Create(Instance, Instance.lvPreview);

        if ASingleMode then
        begin
            Instance.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesSingleTitle');
            Instance.lblTitle.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesSingleTitle');
            // Список правил и панель шаблонов скрываются, редактор поднимается наверх
            Instance.pTemplates.Visible := False;
            Instance.pList.Visible := False;
            Instance.pEditor.Top := 32;
            Instance.pPreview.Top := 298;
            Instance.pPreview.Height := Instance.ClientHeight - 41 - 298;
        end
        else
        begin
            Instance.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesTitle');
            Instance.lblTitle.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesTitle');
            Instance.pList.Top := 62;
            Instance.pEditor.Top := 204;
            Instance.pPreview.Top := 470;
        end;

        Instance.leName.EditLabel.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesName');
        Instance.lblMode.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesMode');
        for Mode := Low(TTitlePatternMode) to High(TTitlePatternMode) do
            Instance.cbMode.Items.Add(TUIStateLoader.GetMessage(MODE_KEY_NAMES[Mode]));
        Instance.cbMode.ItemIndex := 0;
        Instance.bCapture.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesCapture');
        Instance.leText.EditLabel.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesText');
        Instance.chkCase.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesCase');
        Instance.chkEnabled.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesEnabled');
        Instance.chkEnabled.Checked := True;
        Instance.lePattern.EditLabel.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesGenerated');
        Instance.lbHint.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesCaptureHint');
        Instance.bAdd.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesAdd');
        Instance.bDelete.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesDelete');
        Instance.lvRules.Columns[0].Caption := TUIStateLoader.GetMessage('Settings.DenyRulesColName');
        Instance.lvRules.Columns[1].Caption := TUIStateLoader.GetMessage('Settings.DenyRulesColPattern');
        Instance.lvRules.Columns[2].Caption := TUIStateLoader.GetMessage('Settings.DenyRulesColEnabled');
        Instance.lvPreview.Columns[0].Caption := TUIStateLoader.GetMessage('Settings.DenyRulesPreviewColTitle');
        Instance.lvPreview.Columns[1].Caption := TUIStateLoader.GetMessage('Settings.DenyRulesPreviewColStatus');
        Instance.bSaveTemplate.Caption := TUIStateLoader.GetMessage('Settings.DenySetsSaveBtn');
        Instance.bOK.Caption := TUIStateLoader.GetMessage('Common.OK');
        Instance.bCancel.Caption := TUIStateLoader.GetMessage('Common.Cancel');

        if ASingleMode then
        begin
            Instance.leText.Text := APattern;
            Instance.pTemplates.Visible := False;
        end
        else
        begin
            Instance.FRules := Copy(ARules, 0, Length(ARules));
            Instance.LoadTemplatesCombo(ARules);
            Instance.RebuildRuleList;
            if Length(Instance.FRules) > 0 then
                Instance.lvRules.ItemIndex := 0;
        end;

        Instance.RefreshGenerated;
        Instance.RefreshPreview;

        Instance.WarmUpPaint;
        Instance.PrepareGuardedShow;

        if Instance.ShowModal = mrOk then
        begin
            if ASingleMode then
                ANewPattern := Instance.CurrentPattern
            else
            begin
                ARules := Instance.FRules;
                // Запоминаем, какой шаблон был активен при закрытии: при
                // следующем открытии диалога комбо подсветит его
                Instance.SaveActiveTemplateName;
            end;
            Result := True;
        end;
    finally
        Instance.Free;
    end;
end;

function TWindowDenyBuilderDialog.CurrentMode: TTitlePatternMode;
begin
    if cbMode.ItemIndex < 0 then
        Exit(pmContains);
    Result := TTitlePatternMode(cbMode.ItemIndex);
end;

function TWindowDenyBuilderDialog.CurrentPattern: string;
begin
    Result := BuildPattern(Trim(leText.Text), CurrentMode);
end;

function TWindowDenyBuilderDialog.BuildPattern(const AText: string;
    AMode: TTitlePatternMode): string;
begin
    case AMode of
        pmContains: Result := '.*' + TRegEx.Escape(AText) + '.*';
        pmStartsWith: Result := '^' + TRegEx.Escape(AText);
        pmEndsWith: Result := TRegEx.Escape(AText) + '$';
        pmExact: Result := '^' + TRegEx.Escape(AText) + '$';
        pmWildcard: Result := WildcardToRegex(AText);
    else
        Result := AText;
    end;
end;

function TWindowDenyBuilderDialog.WildcardToRegex(const AMask: string): string;
var
    SB: TStringBuilder;
    Ch: Char;
begin
    SB := TStringBuilder.Create(Length(AMask) * 2);
    try
        for Ch in AMask do
            case Ch of
                '*': SB.Append('.*');
                '?': SB.Append('.');
            else
                SB.Append(TRegEx.Escape(Ch));
            end;
        Result := SB.ToString;
    finally
        SB.Free;
    end;
end;

function TWindowDenyBuilderDialog.RuleDisplayName(const ARule: TGlobalTitleDenyRule): string;
begin
    if Trim(ARule.Name) = '' then
        Result := TUIStateLoader.GetMessage('Settings.DenyRulesUnnamed')
    else
        Result := Trim(ARule.Name);
end;

function TWindowDenyBuilderDialog.IsValidRegex(const APattern: string): Boolean;
begin
    Result := TRegexSafety.PatternIsValid(APattern);
end;

procedure TWindowDenyBuilderDialog.LoadRuleToEditor(const ARule: TGlobalTitleDenyRule);
begin
    FUpdating := True;
    try
        leName.Text := ARule.Name;
        cbMode.ItemIndex := Ord(pmRegex);
        leText.Text := ARule.Pattern;
        chkCase.Checked := ARule.CaseSensitive;
        chkEnabled.Checked := ARule.Enabled;
    finally
        FUpdating := False;
    end;
    RefreshGenerated;
    RefreshPreview;
end;

procedure TWindowDenyBuilderDialog.WriteEditorToRule(AIndex: Integer);
var
    Rule: TGlobalTitleDenyRule;
begin
    if (AIndex < 0) or (AIndex > High(FRules)) then
        Exit;

    Rule := FRules[AIndex];
    Rule.Name := Trim(leName.Text);
    Rule.Pattern := CurrentPattern;
    Rule.CaseSensitive := chkCase.Checked;
    Rule.Enabled := chkEnabled.Checked;
    FRules[AIndex] := Rule;
end;

procedure TWindowDenyBuilderDialog.UpdateRuleRow(AIndex: Integer);
var
    Item: TListItem;
begin
    if (AIndex < 0) or (AIndex > High(FRules)) or (AIndex >= lvRules.Items.Count) then
        Exit;

    Item := lvRules.Items[AIndex];
    Item.Caption := RuleDisplayName(FRules[AIndex]);
    Item.SubItems.BeginUpdate;
    try
        if Item.SubItems.Count > 0 then
            Item.SubItems[0] := FRules[AIndex].Pattern;
        if Item.SubItems.Count > 1 then
        begin
            if FRules[AIndex].Enabled then
                Item.SubItems[1] := TUIStateLoader.GetMessage('Settings.DenyRulesOn')
            else
                Item.SubItems[1] := TUIStateLoader.GetMessage('Settings.DenyRulesOff');
        end;
    finally
        Item.SubItems.EndUpdate;
    end;
end;

procedure TWindowDenyBuilderDialog.RebuildRuleList;
var
    I: Integer;
    Item: TListItem;
begin
    lvRules.Items.BeginUpdate;
    try
        lvRules.Items.Clear;
        for I := 0 to High(FRules) do
        begin
            Item := lvRules.Items.Add;
            Item.Caption := RuleDisplayName(FRules[I]);
            Item.SubItems.Add(FRules[I].Pattern);
            if FRules[I].Enabled then
                Item.SubItems.Add(TUIStateLoader.GetMessage('Settings.DenyRulesOn'))
            else
                Item.SubItems.Add(TUIStateLoader.GetMessage('Settings.DenyRulesOff'));
        end;
    finally
        lvRules.Items.EndUpdate;
    end;
end;

procedure TWindowDenyBuilderDialog.EditorChanged;
begin
    if FUpdating then
        Exit;

    // Живая привязка редактора к выбранному правилу списка - до превью,
    // иначе превью увидит устаревшее состояние набора (выражение и галка)
    if (FEditingIndex >= 0) and (FEditingIndex <= High(FRules)) then
    begin
        WriteEditorToRule(FEditingIndex);
        UpdateRuleRow(FEditingIndex);
    end;

    MarkDirty;
    RefreshGenerated;
    RefreshPreview;
end;

procedure TWindowDenyBuilderDialog.MarkDirty;
begin
    FDirty := True;
end;

procedure TWindowDenyBuilderDialog.RefreshGenerated;
var
    Pattern: string;
begin
    Pattern := CurrentPattern;
    lePattern.Text := Pattern;

    // Битый regex подсвечивается красным ещё на вводе: валидация по OK
    // не должна быть первым местом, где это видно
    if IsValidRegex(Pattern) then
        lePattern.Font.Color := clWindowText
    else
        lePattern.Font.Color := clRed;
end;

procedure TWindowDenyBuilderDialog.RefreshPreview;
var
    Raw: TArray<TWindowMonitorInfo>;
    Info: TWindowMonitorInfo;
    EvaluateRules: TArray<TGlobalTitleDenyRule>;
    MatchedRule: string;
    Item: TListItem;
    StatusText: string;
begin
    lvPreview.Items.BeginUpdate;
    try
        lvPreview.Items.Clear;

        if Assigned(GWinMonitor) then
            Raw := GWinMonitor.GetVisibleWindowsInfo
        else
            Raw := nil;

        if (not FSingleMode) and (Length(FRules) > 0) then
        begin
            // Полный режим: превью показывает фактическое поведение набора -
            // выключенное правило сразу перестаёт блокировать окна
            EvaluateRules := FRules;
        end
        else
        begin
            // Одиночный режим и пустой набор: вопрос превью - «что запретит
            // выражение из редактора», галка ни на что не влияет
            SetLength(EvaluateRules, 1);
            EvaluateRules[0] := Default(TGlobalTitleDenyRule);
            EvaluateRules[0].Pattern := CurrentPattern;
            EvaluateRules[0].CaseSensitive := chkCase.Checked;
            EvaluateRules[0].Enabled := True;
        end;

        for Info in Raw do
        begin
            if TProcessProfile.EvaluateGlobalDeny(Info.WindowTitle, EvaluateRules, MatchedRule) then
                StatusText := TUIStateLoader.GetMessage('Settings.DenyRulesPreviewBlocked')
            else
                StatusText := TUIStateLoader.GetMessage('Settings.DenyRulesPreviewPass');

            Item := lvPreview.Items.Add;
            Item.Caption := Info.WindowTitle;
            Item.SubItems.Add(StatusText);
        end;
    finally
        lvPreview.Items.EndUpdate;
    end;

    // Автоподбор ширин: колонки по содержимому, последняя до края,
    // без горизонтальной прокрутки
    FColFitter.Fit;

    lbPreviewEmpty.Visible := Length(Raw) = 0;
    if lbPreviewEmpty.Visible then
        lbPreviewEmpty.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesPreviewNoWindows');
end;

procedure TWindowDenyBuilderDialog.leNameChange(Sender: TObject);
begin
    EditorChanged;
end;

procedure TWindowDenyBuilderDialog.leTextChange(Sender: TObject);
begin
    EditorChanged;
end;

procedure TWindowDenyBuilderDialog.cbModeChange(Sender: TObject);
begin
    EditorChanged;
end;

procedure TWindowDenyBuilderDialog.chkCaseClick(Sender: TObject);
begin
    EditorChanged;
end;

procedure TWindowDenyBuilderDialog.chkEnabledClick(Sender: TObject);
begin
    EditorChanged;
end;

procedure TWindowDenyBuilderDialog.lvRulesSelectItem(Sender: TObject;
    Item: TListItem; Selected: Boolean);
begin
    if (not Selected) or FUpdating then
        Exit;
    if (Item.Index < 0) or (Item.Index > High(FRules)) then
        Exit;

    FEditingIndex := Item.Index;
    LoadRuleToEditor(FRules[Item.Index]);
end;

procedure TWindowDenyBuilderDialog.bAddClick(Sender: TObject);
var
    Rule: TGlobalTitleDenyRule;
    NewIndex: Integer;
begin
    if Trim(leText.Text) = '' then
    begin
        MessagesHandler.ShowError(TUIStateLoader.GetMessage('Settings.DenyRulesEmptyText'));
        leText.SetFocus;
        Exit;
    end;

    if not IsValidRegex(CurrentPattern) then
    begin
        MessagesHandler.ShowError(TUIStateLoader.GetMessage('Settings.ApplicationsProfileInvalidRegex', [CurrentPattern]));
        leText.SetFocus;
        Exit;
    end;

    Rule := Default(TGlobalTitleDenyRule);
    Rule.Name := Trim(leName.Text);
    Rule.Pattern := CurrentPattern;
    Rule.CaseSensitive := chkCase.Checked;
    Rule.Enabled := chkEnabled.Checked;

    NewIndex := Length(FRules);
    SetLength(FRules, NewIndex + 1);
    FRules[NewIndex] := Rule;

    FUpdating := True;
    try
        RebuildRuleList;
        lvRules.ItemIndex := NewIndex;
    finally
        FUpdating := False;
    end;
    FEditingIndex := NewIndex;
    MarkDirty;
end;

procedure TWindowDenyBuilderDialog.bDeleteClick(Sender: TObject);
var
    Index, I: Integer;
begin
    if lvRules.ItemIndex >= 0 then
        Index := lvRules.ItemIndex
    else if FEditingIndex <= High(FRules) then
        Index := FEditingIndex
    else
        Index := -1;

    if (Index < 0) or (Index > High(FRules)) then
        Exit;

    for I := Index to High(FRules) - 1 do
        FRules[I] := FRules[I + 1];
    SetLength(FRules, Length(FRules) - 1);

    FEditingIndex := -1;
    RebuildRuleList;
    MarkDirty;
    RefreshGenerated;
    RefreshPreview;
end;

procedure TWindowDenyBuilderDialog.bCaptureClick(Sender: TObject);
begin
    RefreshPreview;
end;

procedure TWindowDenyBuilderDialog.LoadTemplatesCombo(
    const ACurrentRules: TArray<TGlobalTitleDenyRule>);
var
    Setts: TAppSettings;
    I, SelIdx: Integer;
begin
    // Подсветка активного шаблона по совпадению правил с текущим набором
    // (ARules - источник истины), а не по имени из настроек: набор мог быть
    // отредактирован вручную и ни с каким шаблоном не совпадать - тогда
    // комбо остаётся на «Ничего не запрещено» (SelIdx := 0)
    cbTemplates.Items.BeginUpdate;
    try
        cbTemplates.Clear;
        cbTemplates.Items.AddObject(
            TUIStateLoader.GetMessage('Settings.DenySetsEmptyItem'), TObject(0));
        Setts := AppContext.SettingsManager.Data;
        SelIdx := 0;
        for I := 0 to High(Setts.DenyRuleSets) do
        begin
            cbTemplates.Items.AddObject(Setts.DenyRuleSets[I].Name,
                TObject(I + 1));
            if (SelIdx = 0) and TProcessProfile.SameDenyRules(ACurrentRules,
                Setts.DenyRuleSets[I].Rules) and
                (Length(Setts.DenyRuleSets[I].Rules) > 0) then
                SelIdx := I + 1;
        end;
        cbTemplates.ItemIndex := SelIdx;
    finally
        cbTemplates.Items.EndUpdate;
    end;
end;

function TWindowDenyBuilderDialog.HasUnsavedChanges: Boolean;
begin
    Result := FDirty;
end;

function TWindowDenyBuilderDialog.PromptSaveTemplate: Boolean;
var
    Setts: TAppSettings;
    NewName: string;
    ExistingIdx, I: Integer;
    NewSet: TDenyRuleSet;
begin
    Result := False;

    NewName := '';
    if not MessagesHandler.AskInput(
        TUIStateLoader.GetMessage('Settings.DenySetsSaveTitle'),
        TUIStateLoader.GetMessage('Settings.DenySetsSavePrompt'),
        NewName) then
        Exit;

    NewName := Trim(NewName);
    if NewName = '' then
        Exit;

    Setts := AppContext.SettingsManager.Data;

    // Повторное сохранение под существующим именем = перезапись шаблона
    ExistingIdx := -1;
    for I := 0 to High(Setts.DenyRuleSets) do
        if SameText(Setts.DenyRuleSets[I].Name, NewName) then
        begin
            ExistingIdx := I;
            Break;
        end;

    NewSet := Default(TDenyRuleSet);
    NewSet.Name := NewName;
    // Копия правил: шаблон - снимок, не ссылка на живой набор
    NewSet.Rules := Copy(FRules, 0, Length(FRules));

    if ExistingIdx >= 0 then
        Setts.DenyRuleSets[ExistingIdx] := NewSet
    else
    begin
        SetLength(Setts.DenyRuleSets, Length(Setts.DenyRuleSets) + 1);
        Setts.DenyRuleSets[High(Setts.DenyRuleSets)] := NewSet;
    end;

    Setts.ActiveDenyRuleSet := NewName;
    AppContext.SettingsManager.Data := Setts;
    AppContext.SettingsManager.Save;

    FActiveTemplateName := NewName;
    FDirty := False;
    LoadTemplatesCombo(FRules);
    Result := True;
end;

procedure TWindowDenyBuilderDialog.ApplyTemplate(const AName: string);
var
    Setts: TAppSettings;
    I, SetIdx: Integer;
begin
    Setts := AppContext.SettingsManager.Data;
    SetIdx := -1;
    for I := 0 to High(Setts.DenyRuleSets) do
        if SameText(Setts.DenyRuleSets[I].Name, AName) then
        begin
            SetIdx := I;
            Break;
        end;
    if SetIdx < 0 then
        Exit;

    // Копия правил шаблона в редактор; активное имя запоминаем, чтобы
    // bOK мог сохранить выбор ActiveDenyRuleSet
    FRules := Copy(Setts.DenyRuleSets[SetIdx].Rules, 0,
        Length(Setts.DenyRuleSets[SetIdx].Rules));
    FActiveTemplateName := Setts.DenyRuleSets[SetIdx].Name;
    FEditingIndex := -1;

    FUpdating := True;
    try
        RebuildRuleList;
        if Length(FRules) > 0 then
            lvRules.ItemIndex := 0;
    finally
        FUpdating := False;
    end;

    FDirty := False;
    RefreshGenerated;
    RefreshPreview;
end;

procedure TWindowDenyBuilderDialog.bSaveTemplateClick(Sender: TObject);
begin
    PromptSaveTemplate;
end;

procedure TWindowDenyBuilderDialog.SaveActiveTemplateName;
var
    Setts: TAppSettings;
begin
    Setts := AppContext.SettingsManager.Data;
    Setts.ActiveDenyRuleSet := FActiveTemplateName;
    AppContext.SettingsManager.Data := Setts;
    AppContext.SettingsManager.Save;
end;

procedure TWindowDenyBuilderDialog.cbTemplatesChange(Sender: TObject);
var
    Name: string;
    Idx: Integer;
    Confirmed: Boolean;
begin
    if FUpdating then
        Exit;
    if cbTemplates.ItemIndex < 0 then
        Exit;

    Idx := Integer(IntPtr(cbTemplates.Items.Objects[cbTemplates.ItemIndex]));

    // Пункт 0 - «Ничего не запрещено»: очистка списка правил
    if Idx = 0 then
        Name := ''
    else
        Name := cbTemplates.Items[cbTemplates.ItemIndex];

    // Переключение с несохранёнными правками требует подтверждения:
    // текущий набор не записан в шаблон и будет потерян
    if HasUnsavedChanges then
    begin
        Confirmed := MessagesHandler.AskWarning(
            TUIStateLoader.GetMessage('Settings.DenySetsSwitchConfirm'),
            TUIStateLoader.GetMessage('Common.Warning'));
        if not Confirmed then
        begin
            FUpdating := True;
            try
                LoadTemplatesCombo(FRules);
            finally
                FUpdating := False;
            end;
            Exit;
        end;
    end;

    if Name = '' then
    begin
        FRules := nil;
        FActiveTemplateName := '';
        FEditingIndex := -1;
        FUpdating := True;
        try
            RebuildRuleList;
        finally
            FUpdating := False;
        end;
        FDirty := False;
        RefreshGenerated;
        RefreshPreview;
    end
    else
        ApplyTemplate(Name);
end;

procedure TWindowDenyBuilderDialog.lvPreviewDblClick(Sender: TObject);
var
    Item: TListItem;
begin
    Item := lvPreview.Selected;
    if Item = nil then
        Exit;
    leText.Text := Item.Caption;
end;

procedure TWindowDenyBuilderDialog.bOKClick(Sender: TObject);
var
    I: Integer;
begin
    if FSingleMode then
    begin
        if Trim(leText.Text) = '' then
        begin
            MessagesHandler.ShowError(TUIStateLoader.GetMessage('Settings.DenyRulesEmptyText'));
            leText.SetFocus;
            Exit;
        end;

        if not IsValidRegex(CurrentPattern) then
        begin
            MessagesHandler.ShowError(TUIStateLoader.GetMessage('Settings.ApplicationsProfileInvalidRegex', [CurrentPattern]));
            leText.SetFocus;
            Exit;
        end;

        ModalResult := mrOk;
        Exit;
    end;

    // Правило, которое не может сработать, не имеет права выглядеть
    // активным: на OK проверяется весь набор
    for I := 0 to High(FRules) do
        if (Trim(FRules[I].Pattern) = '') or (not IsValidRegex(FRules[I].Pattern)) then
        begin
            MessagesHandler.ShowError(TUIStateLoader.GetMessage('Settings.DenyRulesBadPattern',
                [RuleDisplayName(FRules[I]), FRules[I].Pattern]));
            if I < lvRules.Items.Count then
                lvRules.ItemIndex := I;
            Exit;
        end;

    ModalResult := mrOk;
end;

end.
