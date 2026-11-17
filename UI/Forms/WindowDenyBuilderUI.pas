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
        pPreview: TPanel;
        lvPreview: TListView;
        lbPreviewEmpty: TLabel;
        pBottom: TPanel;
        bOK: TButton;
        bCancel: TButton;
        procedure bAddClick(Sender: TObject);
        procedure bCaptureClick(Sender: TObject);
        procedure bDeleteClick(Sender: TObject);
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
        Instance.FColFitter := TListViewColumnFitter.Create(Instance, Instance.lvPreview);

        if ASingleMode then
        begin
            Instance.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesSingleTitle');
            Instance.lblTitle.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesSingleTitle');
            // Список правил скрывается, блок редактора поднимается наверх
            Instance.pList.Visible := False;
            Instance.pEditor.Top := 32;
            Instance.pPreview.Top := 298;
            Instance.pPreview.Height := Instance.ClientHeight - 41 - 298;
        end
        else
        begin
            Instance.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesTitle');
            Instance.lblTitle.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesTitle');
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
        Instance.bOK.Caption := TUIStateLoader.GetMessage('Common.OK');
        Instance.bCancel.Caption := TUIStateLoader.GetMessage('Common.Cancel');

        if ASingleMode then
            Instance.leText.Text := APattern
        else
        begin
            Instance.FRules := Copy(ARules, 0, Length(ARules));
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
                ARules := Instance.FRules;
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
    Result := True;
    if APattern = '' then
        Exit;

    try
        TRegEx.IsMatch('', APattern);
    except
        Result := False;
    end;
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

    RefreshGenerated;
    RefreshPreview;

    // Живая привязка редактора к выбранному правилу списка
    if (FEditingIndex >= 0) and (FEditingIndex <= High(FRules)) then
    begin
        WriteEditorToRule(FEditingIndex);
        UpdateRuleRow(FEditingIndex);
    end;
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
    PreviewRules: TArray<TGlobalTitleDenyRule>;
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

        // Превью оценивает правило как включённое независимо от chkEnabled:
        // вопрос превью - «что запретит выражение», а не состояние галки
        SetLength(PreviewRules, 1);
        PreviewRules[0] := Default(TGlobalTitleDenyRule);
        PreviewRules[0].Pattern := CurrentPattern;
        PreviewRules[0].CaseSensitive := chkCase.Checked;
        PreviewRules[0].Enabled := True;

        for Info in Raw do
        begin
            if TProcessProfile.EvaluateGlobalDeny(Info.WindowTitle, PreviewRules, MatchedRule) then
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
    RefreshGenerated;
    RefreshPreview;
end;

procedure TWindowDenyBuilderDialog.bCaptureClick(Sender: TObject);
begin
    RefreshPreview;
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
