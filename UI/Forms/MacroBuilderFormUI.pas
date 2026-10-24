unit MacroBuilderFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    MacroBuilder,
    MacroInputTypes,
    SynEdit,
    System.Classes,
    System.Generics.Collections,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls
    ;

type
    TMacroBuilderForm = class(TBaseForm)
        pnlSteps: TPanel;
        lbHint: TLabel;
        lvSteps: TListView;
        pnlProps: TPanel;
        lbPropType: TLabel;
        cbPropType: TComboBox;
        lbProp1: TLabel;
        ebProp1: TEdit;
        lbProp2: TLabel;
        ebProp2: TEdit;
        lbProp3: TLabel;
        ebProp3: TEdit;
        lbPropsEmpty: TLabel;
        pnlAdd: TPanel;
        lbAddType: TLabel;
        cbStepType: TComboBox;
        bAddStep: TButton;
        bStepUp: TButton;
        bStepDown: TButton;
        bStepDelete: TButton;
        pnlPreview: TPanel;
        lbPreview: TLabel;
        sePreview: TSynEdit;
        pnlButtons: TPanel;
        bCancel: TButton;
        bApply: TButton;
        procedure FormCreate(Sender: TObject);
        procedure lvStepsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
        procedure lvStepsDblClick(Sender: TObject);
        procedure bAddStepClick(Sender: TObject);
        procedure bStepUpClick(Sender: TObject);
        procedure bStepDownClick(Sender: TObject);
        procedure bStepDeleteClick(Sender: TObject);
        procedure PropChanged(Sender: TObject);
        procedure bApplyClick(Sender: TObject);
    private
        FSteps: TList<TMacroStep>;
        FLoadingProps: Boolean;
        procedure ShowProp(ALabel: TLabel; AEdit: TEdit; AVisible: Boolean);
        procedure RefreshList;
        procedure RefreshPreview;
        procedure LoadStepToProps(Index: Integer);
        procedure SavePropsToStep;
        function SelectedIndex: Integer;
        function StepTypeName(AKind: TMacroStepKind): string;
        function StepSummary(const Step: TMacroStep): string;
        function ValidateSteps(out ErrorText: string): Boolean;
    public
        procedure InitializeBuilder(const MacroText: string);
        function GetMacroText: string;
    end;

var
    MacroBuilderForm: TMacroBuilderForm;

implementation

uses
    Common.Localization,
    MacroEngine,
    MacroSyn,
    SynThemeAdapter,
    System.SysUtils,
    Winapi.Windows
    ;

const
    STEP_KINDS: array [0 .. 7] of TMacroStepKind =
        (mskText, mskSleep, mskEnter, mskKey, mskInput, mskValue, mskClearLine, mskKeyDelay);

    KEY_NAMES: array [0 .. 7] of string =
        ('StepType.Text', 'StepType.Sleep', 'StepType.Enter', 'StepType.Key',
         'StepType.Input', 'StepType.Value', 'StepType.ClearLine', 'StepType.KeyDelay');

    VALUE_KINDS: array [0 .. 5] of string =
        ('DATETIME', 'UUID', 'RANDOM', 'COUNTER', 'ENV', 'CLIPBOARD');

    NEWLINE_MARK = #$00B6;

{$R *.dfm}

function TextToDisplay(const S: string): string;
begin
    Result := StringReplace(S, #13#10, NEWLINE_MARK, [rfReplaceAll]);
    Result := StringReplace(Result, #13, NEWLINE_MARK, [rfReplaceAll]);
    Result := StringReplace(Result, #10, NEWLINE_MARK, [rfReplaceAll]);
end;

function DisplayToText(const S: string): string;
begin
    Result := StringReplace(S, NEWLINE_MARK, #10, [rfReplaceAll]);
end;

procedure TMacroBuilderForm.FormCreate(Sender: TObject);
var
    I: Integer;
begin
    FSteps := TList<TMacroStep>.Create;
    FLoadingProps := False;

    lvSteps.Columns[0].Width := 34;
    lvSteps.Columns[1].Width := 110;
    lvSteps.Columns[2].Width := 310;

    sePreview.Highlighter := TMacroSyn.Create(Self);
    TSynThemeAdapter.ApplyTheme(sePreview);

    cbStepType.Items.BeginUpdate;
    try
        for I := Low(STEP_KINDS) to High(STEP_KINDS) do
            cbStepType.Items.Add(StepTypeName(STEP_KINDS[I]));
        cbStepType.ItemIndex := 0;
    finally
        cbStepType.Items.EndUpdate;
    end;
end;

procedure TMacroBuilderForm.InitializeBuilder(const MacroText: string);
var
    Loaded: TArray<TMacroStep>;
    I: Integer;
begin
    Loaded := StepsFromMacroText(MacroText);
    FSteps.Clear;
    for I := 0 to High(Loaded) do
        FSteps.Add(Loaded[I]);

    RefreshList;
    RefreshPreview;

    if lvSteps.Items.Count > 0 then
    begin
        lvSteps.Items[0].Selected := True;
        lvSteps.Items[0].Focused := True;
    end
    else
        LoadStepToProps(-1);
end;

function TMacroBuilderForm.GetMacroText: string;
begin
    Result := StepsToMacro(FSteps.ToArray);
end;

function TMacroBuilderForm.StepTypeName(AKind: TMacroStepKind): string;
var
    I: Integer;
begin
    Result := '';
    for I := Low(STEP_KINDS) to High(STEP_KINDS) do
        if STEP_KINDS[I] = AKind then
            Exit(TUIStateLoader.GetMessage('MacroBuilder.' + KEY_NAMES[I]));
end;

function TMacroBuilderForm.StepSummary(const Step: TMacroStep): string;
begin
    // Показываем шаг ровно тем кодом, который он даст в сниппете -
    // так строка в списке читается так же, как в исходнике
    Result := TextToDisplay(StepToMacro(Step));
    if Length(Result) > 70 then
        Result := Copy(Result, 1, 69) + #$2026;
end;

procedure TMacroBuilderForm.RefreshList;
var
    I: Integer;
    Item: TListItem;
    Sel: Integer;
begin
    Sel := SelectedIndex;
    lvSteps.Items.BeginUpdate;
    try
        lvSteps.Items.Clear;
        for I := 0 to FSteps.Count - 1 do
        begin
            Item := lvSteps.Items.Add;
            Item.Caption := IntToStr(I + 1);
            Item.SubItems.Add(StepTypeName(FSteps[I].Kind));
            Item.SubItems.Add(StepSummary(FSteps[I]));
        end;
    finally
        lvSteps.Items.EndUpdate;
    end;

    if (Sel >= 0) and (Sel < lvSteps.Items.Count) then
    begin
        lvSteps.Items[Sel].Selected := True;
        lvSteps.Items[Sel].Focused := True;
    end;
end;

procedure TMacroBuilderForm.RefreshPreview;
begin
    sePreview.Text := GetMacroText;
end;

function TMacroBuilderForm.SelectedIndex: Integer;
begin
    if Assigned(lvSteps.Selected) then
        Result := lvSteps.Selected.Index
    else
        Result := -1;
end;

procedure TMacroBuilderForm.lvStepsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
    if Selected then
        LoadStepToProps(Item.Index);
end;

procedure TMacroBuilderForm.lvStepsDblClick(Sender: TObject);
begin
    if (SelectedIndex >= 0) and ebProp1.Visible and ebProp1.CanFocus then
        ebProp1.SetFocus;
end;

procedure TMacroBuilderForm.LoadStepToProps(Index: Integer);
var
    Step: TMacroStep;
    I: Integer;
begin
    FLoadingProps := True;
    try
        ebProp1.Text := '';
        ebProp2.Text := '';
        ebProp3.Text := '';

        lbProp1.Visible := False;
        ebProp1.Visible := False;
        lbProp2.Visible := False;
        ebProp2.Visible := False;
        lbProp3.Visible := False;
        ebProp3.Visible := False;
        lbPropType.Visible := False;
        cbPropType.Visible := False;

        if (Index < 0) or (Index >= FSteps.Count) then
        begin
            lbPropsEmpty.Visible := True;
            Exit;
        end;
        lbPropsEmpty.Visible := False;

        Step := FSteps[Index];

        case Step.Kind of
            mskText:
            begin
                lbProp1.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropText');
                lbProp1.Visible := True;
                ebProp1.Visible := True;
                ebProp1.Text := TextToDisplay(Step.Text);
            end;

            mskSleep, mskKeyDelay:
            begin
                lbProp1.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropMs');
                lbProp1.Visible := True;
                ebProp1.Visible := True;
                ebProp1.Text := IntToStr(Step.Num);
            end;

            mskKey:
            begin
                lbProp1.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropKey');
                lbProp1.Visible := True;
                ebProp1.Visible := True;
                ebProp1.Text := Step.Text;
            end;

            mskInput:
            begin
                lbPropType.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropInputType');
                cbPropType.Items.BeginUpdate;
                try
                    cbPropType.Items.Clear;
                    for I := 0 to High(INPUT_TYPE_NAMES) do
                        cbPropType.Items.Add(INPUT_TYPE_NAMES[I]);
                    cbPropType.ItemIndex := IndexOfInputType(Step.InputType);
                finally
                    cbPropType.Items.EndUpdate;
                end;
                lbPropType.Visible := True;
                cbPropType.Visible := True;

                lbProp1.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropName');
                ShowProp(lbProp1, ebProp1, True);
                ebProp1.Text := Step.Text;

                lbProp2.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropDefault');
                ShowProp(lbProp2, ebProp2, True);
                ebProp2.Text := Step.Default;

                lbProp3.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropOptions');
                ShowProp(lbProp3, ebProp3, Step.InputType = mitSelect);
                ebProp3.Text := Step.Default;
            end;

            mskValue:
            begin
                lbPropType.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropValueType');
                cbPropType.Items.BeginUpdate;
                try
                    cbPropType.Items.Clear;
                    for I := Low(VALUE_KINDS) to High(VALUE_KINDS) do
                        cbPropType.Items.Add(VALUE_KINDS[I]);
                    cbPropType.ItemIndex := 0;
                    for I := Low(VALUE_KINDS) to High(VALUE_KINDS) do
                        if VALUE_KINDS[I] = Step.ValueKind then
                            cbPropType.ItemIndex := I;
                finally
                    cbPropType.Items.EndUpdate;
                end;
                lbPropType.Visible := True;
                cbPropType.Visible := True;

                lbProp1.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropArg');
                lbProp1.Visible := True;
                ebProp1.Visible := True;
                ebProp1.Text := Step.Text;
            end;
        end;
    finally
        FLoadingProps := False;
    end;
end;

procedure TMacroBuilderForm.ShowProp(ALabel: TLabel; AEdit: TEdit; AVisible: Boolean);
begin
    ALabel.Visible := AVisible;
    AEdit.Visible := AVisible;
end;

procedure TMacroBuilderForm.SavePropsToStep;
var
    Index: Integer;
    Step: TMacroStep;
begin
    if FLoadingProps then
        Exit;

    Index := SelectedIndex;
    if (Index < 0) or (Index >= FSteps.Count) then
        Exit;

    Step := FSteps[Index];

    case Step.Kind of
        mskText:
            Step.Text := DisplayToText(ebProp1.Text);

        mskKey:
            Step.Text := ebProp1.Text;

        mskValue:
        begin
            Step.Text := ebProp1.Text;
            if cbPropType.ItemIndex >= 0 then
                Step.ValueKind := VALUE_KINDS[cbPropType.ItemIndex];
        end;

        mskSleep, mskKeyDelay:
            Step.Num := StrToIntDef(Trim(ebProp1.Text), 0);

        mskInput:
        begin
            if cbPropType.ItemIndex >= 0 then
                Step.InputType := INPUT_TYPE_VALUES[cbPropType.ItemIndex];
            Step.Text := ebProp1.Text;
            if Step.InputType = mitSelect then
                Step.Default := ebProp3.Text
            else
                Step.Default := ebProp2.Text;
        end;
    end;

    FSteps[Index] := Step;

    if Index < lvSteps.Items.Count then
    begin
        lvSteps.Items[Index].SubItems[0] := StepTypeName(Step.Kind);
        lvSteps.Items[Index].SubItems[1] := StepSummary(Step);
    end;

    RefreshPreview;
end;

procedure TMacroBuilderForm.bAddStepClick(Sender: TObject);
var
    Step: TMacroStep;
begin
    if cbStepType.ItemIndex < 0 then
        Exit;

    Step := Default(TMacroStep);
    Step.Kind := STEP_KINDS[cbStepType.ItemIndex];

    case Step.Kind of
        mskSleep:
            Step.Num := 500;
        mskKey:
            Step.Text := 'CTRL+C';
        mskInput:
        begin
            Step.InputType := mitString;
            Step.Text := TUIStateLoader.GetMessage('MacroBuilder.DefaultParamName');
        end;
        mskValue:
            Step.ValueKind := 'DATETIME';
        mskKeyDelay:
            Step.Num := 100;
    end;

    FSteps.Add(Step);
    RefreshList;
    RefreshPreview;

    if lvSteps.Items.Count > 0 then
    begin
        lvSteps.Items[lvSteps.Items.Count - 1].Selected := True;
        lvSteps.Items[lvSteps.Items.Count - 1].Focused := True;
        if ebProp1.Visible and ebProp1.CanFocus then
            ebProp1.SetFocus;
    end;
end;

procedure TMacroBuilderForm.bStepUpClick(Sender: TObject);
var
    Index: Integer;
    Step: TMacroStep;
begin
    Index := SelectedIndex;
    if Index <= 0 then
        Exit;

    Step := FSteps[Index];
    FSteps[Index] := FSteps[Index - 1];
    FSteps[Index - 1] := Step;

    RefreshList;
    RefreshPreview;
    if (Index - 1 < lvSteps.Items.Count) then
    begin
        lvSteps.Items[Index - 1].Selected := True;
        lvSteps.Items[Index - 1].Focused := True;
    end;
end;

procedure TMacroBuilderForm.bStepDownClick(Sender: TObject);
var
    Index: Integer;
    Step: TMacroStep;
begin
    Index := SelectedIndex;
    if (Index < 0) or (Index >= FSteps.Count - 1) then
        Exit;

    Step := FSteps[Index];
    FSteps[Index] := FSteps[Index + 1];
    FSteps[Index + 1] := Step;

    RefreshList;
    RefreshPreview;
    if (Index + 1 < lvSteps.Items.Count) then
    begin
        lvSteps.Items[Index + 1].Selected := True;
        lvSteps.Items[Index + 1].Focused := True;
    end;
end;

procedure TMacroBuilderForm.bStepDeleteClick(Sender: TObject);
var
    Index: Integer;
begin
    Index := SelectedIndex;
    if Index < 0 then
        Exit;

    FSteps.Delete(Index);
    RefreshList;
    RefreshPreview;
    LoadStepToProps(SelectedIndex);
end;

procedure TMacroBuilderForm.PropChanged(Sender: TObject);
begin
    SavePropsToStep;
end;

function TMacroBuilderForm.ValidateSteps(out ErrorText: string): Boolean;
var
    I: Integer;
    Key, Modifiers: Integer;
    KeyText: string;
begin
    Result := True;
    ErrorText := '';

    for I := 0 to FSteps.Count - 1 do
    begin
        if FSteps[I].Kind = mskKey then
        begin
            if not TryParseSendKeyEx(FSteps[I].Text, Key, Modifiers, KeyText) then
            begin
                ErrorText := TUIStateLoader.GetMessage('MacroBuilder.Error.BadKey', [FSteps[I].Text]);
                Exit(False);
            end;
        end
        else if (FSteps[I].Kind = mskValue) and (FSteps[I].ValueKind = 'ENV') and (Trim(FSteps[I].Text) = '') then
        begin
            ErrorText := TUIStateLoader.GetMessage('MacroBuilder.Error.EnvEmpty');
            Exit(False);
        end;
    end;
end;

procedure TMacroBuilderForm.bApplyClick(Sender: TObject);
var
    ErrorText: string;
begin
    if not ValidateSteps(ErrorText) then
    begin
        MessagesHandler.ShowInfo(ErrorText);
        ModalResult := mrNone;
        Exit;
    end;

    ModalResult := mrOk;
end;

end.
