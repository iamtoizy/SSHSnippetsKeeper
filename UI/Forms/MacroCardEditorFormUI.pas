unit MacroCardEditorFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    MacroBuilder,
    MacroInputTypes,
    System.Classes,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.StdCtrls
    ;

type
    TMacroCardEditorForm = class(TBaseForm)
        lbTitle: TLabel;
        pnlProps: TPanel;
        lbStepType: TLabel;
        cbStepType: TComboBox;
        lbPropType: TLabel;
        cbPropType: TComboBox;
        lbProp1: TLabel;
        cbProp1: TComboBox;
        lbProp2: TLabel;
        cbProp2: TComboBox;
        lbProp3: TLabel;
        cbProp3: TComboBox;
        pnlButtons: TPanel;
        bCancel: TButton;
        bOK: TButton;
        lbError: TLabel;
        pTop: TPanel;
        procedure FormCreate(Sender: TObject);
        procedure cbStepTypeChange(Sender: TObject);
        procedure PropChanged(Sender: TObject);
        procedure PropTypeChanged(Sender: TObject);
        procedure ComboListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure bOKClick(Sender: TObject);
    private
        FStep: TMacroStep;
        FLoadingProps: Boolean;
        FNextTop: Integer;
        procedure SetComboItems(ACombo: TComboBox; const AItems: array of string);
        procedure AddRow(ALabel: TLabel; AControl: TControl);
        function DateDefaultPresets: TArray<string>;
        function TimeDefaultPresets: TArray<string>;
        function DateTimeDefaultPresets: TArray<string>;
        procedure LoadStepToProps;
        procedure SavePropsToStep;
        function BuildValidationError: string;
        procedure ApplyLiveValidation;
    public
        procedure InitializeCard(const CardText: string);
        function GetCardText: string;
    end;

implementation

uses
    Common.Localization,
    MacroCounters,
    MacroEngine,
    System.DateUtils,
    System.SysUtils,
    Winapi.Windows
    ;

const
    STEP_KINDS: array [0 .. 6] of TMacroStepKind =
        (mskSleep, mskEnter, mskKey, mskInput, mskValue, mskClearLine, mskKeyDelay);

    KEY_NAMES: array [0 .. 6] of string =
        ('StepType.Sleep', 'StepType.Enter', 'StepType.Key',
         'StepType.Input', 'StepType.Value', 'StepType.ClearLine', 'StepType.KeyDelay');

    VALUE_KINDS: array [0 .. 5] of string =
        ('DATETIME', 'UUID', 'RANDOM', 'COUNTER', 'ENV', 'CLIPBOARD');

    MS_PRESETS: array [0 .. 5] of string = ('100', '300', '500', '1000', '2000', '5000');

    KEY_PRESETS: array [0 .. 15] of string =
        ('CTRL+C', 'CTRL+V', 'CTRL+X', 'CTRL+Z', 'CTRL+A', 'ENTER', 'TAB', 'ESC',
         'BACKSPACE', 'DELETE', 'HOME', 'END', 'F2', 'F5', 'SHIFT+ENTER', 'CTRL+SHIFT+T');

    DATETIME_PRESETS: array [0 .. 5] of string =
        ('', 'yyyy-MM-dd', 'dd.MM.yyyy', 'HH:mm', 'yyyy-MM-dd HH:mm', 'yyyy-MM-dd HH:mm:ss');

    RANDOM_LENGTH_PRESETS: array [0 .. 5] of string = ('', '8', '12', '16', '24', '32');

    COUNTER_PARAM_PRESETS: array [0 .. 4] of string =
        ('', 'start=1', 'start=100;step=2;pad=3', 'current', 'volatile');

{$R *.dfm}

function StepTypeName(AKind: TMacroStepKind): string;
var
    I: Integer;
begin
    Result := '';
    for I := Low(STEP_KINDS) to High(STEP_KINDS) do
        if STEP_KINDS[I] = AKind then
            Exit(TUIStateLoader.GetMessage('MacroBuilder.' + KEY_NAMES[I]));
end;

function ValueKindTakesArg(const AValueKind: string): Boolean;
begin
    Result := (AValueKind = 'DATETIME') or (AValueKind = 'RANDOM') or
        (AValueKind = 'ENV') or (AValueKind = 'COUNTER');
end;

procedure TMacroCardEditorForm.FormCreate(Sender: TObject);
var
    I: Integer;
begin
    FLoadingProps := False;
    FStep := Default(TMacroStep);
    FStep.Kind := mskText;

    cbStepType.OnKeyDown := ComboListKeyDown;
    cbPropType.OnKeyDown := ComboListKeyDown;
    cbPropType.OnChange := PropTypeChanged;

    cbStepType.Items.BeginUpdate;
    try
        cbStepType.Items.Clear;
        for I := Low(STEP_KINDS) to High(STEP_KINDS) do
            cbStepType.Items.Add(StepTypeName(STEP_KINDS[I]));
        cbStepType.ItemIndex := 0;
    finally
        cbStepType.Items.EndUpdate;
    end;

    LoadStepToProps;
end;

procedure TMacroCardEditorForm.InitializeCard(const CardText: string);
var
    Steps: TArray<TMacroStep>;
begin
    Steps := StepsFromMacroText(CardText);

    if Length(Steps) > 0 then
        FStep := Steps[0]
    else
    begin
        FStep := Default(TMacroStep);
        FStep.Kind := mskText;
        FStep.Text := CardText;
    end;

    LoadStepToProps;

    ApplyLiveValidation;

    if cbProp1.Visible then
        ActiveControl := cbProp1
    else if cbPropType.Visible then
        ActiveControl := cbPropType
    else
        ActiveControl := cbStepType;
end;

function TMacroCardEditorForm.GetCardText: string;
begin
    SavePropsToStep;
    Result := StepToMacro(FStep);
end;

procedure TMacroCardEditorForm.SetComboItems(ACombo: TComboBox; const AItems: array of string);
var
    S: string;
begin
    ACombo.Items.BeginUpdate;
    try
        ACombo.Items.Clear;
        for S in AItems do
            ACombo.Items.Add(S);
    finally
        ACombo.Items.EndUpdate;
    end;
end;

procedure TMacroCardEditorForm.AddRow(ALabel: TLabel; AControl: TControl);
begin
    ALabel.Left := 10;
    ALabel.Top := FNextTop;
    ALabel.Visible := True;

    AControl.Left := 10;
    AControl.Top := FNextTop + 16;
    AControl.Width := pnlProps.ClientWidth - 20;
    AControl.Visible := True;

    Inc(FNextTop, 47);
end;

function TMacroCardEditorForm.DateDefaultPresets: TArray<string>;
var
    Today: TDateTime;
begin
    // Пусто / локальная дата / ISO
    Today := Date;
    Result := TArray<string>.Create('',
        DateToStr(Today),
        FormatDateTime('yyyy-mm-dd', Today));
end;

function TMacroCardEditorForm.TimeDefaultPresets: TArray<string>;
begin
    // Пусто / ЧЧ:ММ / ЧЧ:ММ:СС
    Result := TArray<string>.Create('',
        FormatDateTime('hh:nn', Now),
        FormatDateTime('hh:nn:ss', Now));
end;

function TMacroCardEditorForm.DateTimeDefaultPresets: TArray<string>;
var
    Stamp: TDateTime;
begin
    // Подсказки - готовые значения в разных форматах: локальные дата/время
    // и ISO-варианты; "_" вместо пробела - для терминала, где пробел
    // разбивает аргументы. Все значения проходят TryParseDateTimeValue
    Stamp := Now;
    Result := TArray<string>.Create('',
        DateToStr(DateOf(Stamp)),
        DateToStr(DateOf(Stamp)) + ' ' + FormatDateTime('hh:nn', Stamp),
        DateToStr(DateOf(Stamp)) + '_' + FormatDateTime('hh:nn', Stamp),
        FormatDateTime('yyyy-mm-dd', Stamp),
        FormatDateTime('yyyy-mm-dd hh:nn', Stamp),
        FormatDateTime('yyyy-mm-dd_hh:nn', Stamp),
        FormatDateTime('yyyy-mm-dd hh:nn:ss', Stamp),
        FormatDateTime('yyyy-mm-dd"T"hh:nn', Stamp));
end;

procedure TMacroCardEditorForm.LoadStepToProps;
var
    I, KindIdx: Integer;
begin
    FLoadingProps := True;
    try
        cbProp1.Text := '';
        cbProp2.Text := '';
        cbProp3.Text := '';

        lbStepType.Visible := False;
        cbStepType.Visible := False;
        lbPropType.Visible := False;
        cbPropType.Visible := False;
        lbProp1.Visible := False;
        cbProp1.Visible := False;
        lbProp2.Visible := False;
        cbProp2.Visible := False;
        lbProp3.Visible := False;
        cbProp3.Visible := False;

        KindIdx := -1;
        for I := Low(STEP_KINDS) to High(STEP_KINDS) do
            if STEP_KINDS[I] = FStep.Kind then
                KindIdx := I;
        cbStepType.ItemIndex := KindIdx;

        lbTitle.Caption := StepToMacro(FStep);
        lbTitle.Hint := lbTitle.Caption;

        FNextTop := 10;
        AddRow(lbStepType, cbStepType);

        case FStep.Kind of
            mskSleep, mskKeyDelay:
            begin
                lbProp1.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropMs');
                SetComboItems(cbProp1, MS_PRESETS);
                AddRow(lbProp1, cbProp1);
                cbProp1.Text := IntToStr(FStep.Num);
            end;

            mskKey:
            begin
                lbProp1.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropKey');
                SetComboItems(cbProp1, KEY_PRESETS);
                AddRow(lbProp1, cbProp1);
                cbProp1.Text := FStep.Text;
            end;

            mskInput:
            begin
                lbPropType.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropInputType');
                SetComboItems(cbPropType, INPUT_TYPE_NAMES);
                cbPropType.ItemIndex := IndexOfInputType(FStep.InputType);
                AddRow(lbPropType, cbPropType);

                lbProp1.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropName');
                SetComboItems(cbProp1, []);
                AddRow(lbProp1, cbProp1);
                cbProp1.Text := FStep.Text;

                lbProp2.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropDefault');
                case FStep.InputType of
                    mitDateTime:
                        SetComboItems(cbProp2, DateTimeDefaultPresets);
                    mitDate:
                        SetComboItems(cbProp2, DateDefaultPresets);
                    mitTime:
                        SetComboItems(cbProp2, TimeDefaultPresets);
                else
                    SetComboItems(cbProp2, []);
                end;
                AddRow(lbProp2, cbProp2);
                cbProp2.Text := FStep.Default;

                if FStep.InputType = mitSelect then
                begin
                    lbProp3.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropOptions');
                    SetComboItems(cbProp3, []);
                    AddRow(lbProp3, cbProp3);
                    cbProp3.Text := FStep.Default;
                end;
            end;

            mskValue:
            begin
                lbPropType.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropValueType');
                SetComboItems(cbPropType, VALUE_KINDS);
                cbPropType.ItemIndex := 0;
                for I := Low(VALUE_KINDS) to High(VALUE_KINDS) do
                    if VALUE_KINDS[I] = FStep.ValueKind then
                        cbPropType.ItemIndex := I;
                AddRow(lbPropType, cbPropType);

                if not ValueKindTakesArg(FStep.ValueKind) then
                    FStep.Text := ''
                else
                begin
                    lbProp1.Caption := TUIStateLoader.GetMessage('MacroBuilder.PropArg');
                    if FStep.ValueKind = 'DATETIME' then
                        SetComboItems(cbProp1, DATETIME_PRESETS)
                    else if FStep.ValueKind = 'RANDOM' then
                        SetComboItems(cbProp1, RANDOM_LENGTH_PRESETS)
                    else if FStep.ValueKind = 'COUNTER' then
                        SetComboItems(cbProp1, COUNTER_PARAM_PRESETS)
                    else
                        SetComboItems(cbProp1, []);
                    AddRow(lbProp1, cbProp1);
                    cbProp1.Text := FStep.Text;
                end;
            end;
        end;

        ClientHeight := lbTitle.Height + 8 + FNextTop + 2 + pnlButtons.Height;
    finally
        FLoadingProps := False;
    end;
end;

procedure TMacroCardEditorForm.SavePropsToStep;
begin
    if FLoadingProps then
        Exit;

    case FStep.Kind of
        mskKey:
            FStep.Text := Trim(cbProp1.Text);

        mskValue:
        begin
            if cbPropType.ItemIndex >= 0 then
                FStep.ValueKind := VALUE_KINDS[cbPropType.ItemIndex];
            if ValueKindTakesArg(FStep.ValueKind) then
                FStep.Text := Trim(cbProp1.Text)
            else
                FStep.Text := '';
        end;

        mskSleep, mskKeyDelay:
            FStep.Num := StrToIntDef(Trim(cbProp1.Text), 0);

        mskInput:
        begin
            if cbPropType.ItemIndex >= 0 then
                FStep.InputType := INPUT_TYPE_VALUES[cbPropType.ItemIndex];
            FStep.Text := cbProp1.Text;
            if FStep.InputType = mitSelect then
                FStep.Default := cbProp3.Text
            else
                FStep.Default := cbProp2.Text;
        end;
    end;

    lbTitle.Caption := StepToMacro(FStep);
    lbTitle.Hint := lbTitle.Caption;
end;

procedure TMacroCardEditorForm.cbStepTypeChange(Sender: TObject);
var
    NewKind: TMacroStepKind;
begin
    if FLoadingProps then
        Exit;
    if cbStepType.ItemIndex < 0 then
        Exit;

    NewKind := STEP_KINDS[cbStepType.ItemIndex];
    if NewKind = FStep.Kind then
        Exit;

    FStep := Default(TMacroStep);
    FStep.Kind := NewKind;

    case NewKind of
        mskSleep:
            FStep.Num := 500;
        mskKey:
            FStep.Text := 'CTRL+C';
        mskInput:
        begin
            FStep.InputType := mitString;
            FStep.Text := TUIStateLoader.GetMessage('MacroBuilder.DefaultParamName');
        end;
        mskValue:
            FStep.ValueKind := 'DATETIME';
        mskKeyDelay:
            FStep.Num := 100;
    end;

    LoadStepToProps;
    ApplyLiveValidation;
end;

procedure TMacroCardEditorForm.PropChanged(Sender: TObject);
begin
    SavePropsToStep;
    ApplyLiveValidation;
end;

procedure TMacroCardEditorForm.PropTypeChanged(Sender: TObject);
var
    NewValueKind: string;
begin
    if FLoadingProps then
        Exit;

    case FStep.Kind of
        mskValue:
        begin
            if cbPropType.ItemIndex >= 0 then
            begin
                NewValueKind := VALUE_KINDS[cbPropType.ItemIndex];
                if NewValueKind <> FStep.ValueKind then
                begin
                    FStep.ValueKind := NewValueKind;
                    FStep.Text := '';
                end;
            end;
            LoadStepToProps;
        end;

        mskInput:
        begin
            if cbPropType.ItemIndex >= 0 then
                FStep.InputType := INPUT_TYPE_VALUES[cbPropType.ItemIndex];
            LoadStepToProps;
        end;
    end;

    ApplyLiveValidation;
end;

procedure TMacroCardEditorForm.ComboListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if (Sender is TComboBox) and (not TComboBox(Sender).DroppedDown) and
        (Key in [VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT]) then
        Key := 0;
end;

function TMacroCardEditorForm.BuildValidationError: string;
var
    Key, Modifiers: Integer;
    KeyText: string;
    Ms, Len: Integer;
begin
    Result := '';

    if (FStep.Kind = mskKey) and (not TryParseSendKeyEx(FStep.Text, Key, Modifiers, KeyText)) then
        Exit(TUIStateLoader.GetMessage('MacroBuilder.Error.BadKey', [FStep.Text]));

    if FStep.Kind = mskValue then
    begin
        if (FStep.ValueKind = 'ENV') and (Trim(FStep.Text) = '') then
            Exit(TUIStateLoader.GetMessage('MacroBuilder.Error.EnvEmpty'));

        if (FStep.ValueKind = 'RANDOM') and
            ((not TryStrToInt(Trim(cbProp1.Text), Len)) or (Len < 1)) then
            Exit(TUIStateLoader.GetMessage('MacroBuilder.Error.BadRandom'));

        if (FStep.ValueKind = 'COUNTER') and (Trim(FStep.Text) <> '') and
            (not IsCounterParamsValid(Trim(FStep.Text))) then
            Exit(TUIStateLoader.GetMessage('MacroBuilder.Error.BadCounter'));
    end;

    if (FStep.Kind in [mskSleep, mskKeyDelay]) and
        ((not TryStrToInt(Trim(cbProp1.Text), Ms)) or (Ms < 0)) then
        Exit(TUIStateLoader.GetMessage('MacroBuilder.Error.BadMs'));

    if FStep.Kind = mskInput then
    begin
        if (FStep.InputType = mitSelect) and (Trim(FStep.Default) = '') then
            Exit(TUIStateLoader.GetMessage('MacroBuilder.Error.BadOptions'));

        if (Trim(FStep.Default) <> '') and
            (not IsMacroValueValid(Trim(FStep.Default), FStep.InputType)) then
            Exit(TUIStateLoader.GetMessage('MacroBuilder.Error.BadDefault',
                [InputTypeTokenName(FStep.InputType)]));
    end;
end;

procedure TMacroCardEditorForm.ApplyLiveValidation;
var
    ErrorText: string;
begin
    ErrorText := BuildValidationError;
    lbError.Caption := ErrorText;
    lbError.Hint := ErrorText;
    lbError.Visible := ErrorText <> '';
    lbError.ShowHint := ErrorText <> '';
    bOK.Enabled := ErrorText = '';
end;

procedure TMacroCardEditorForm.bOKClick(Sender: TObject);
var
    ErrorText: string;
begin
    SavePropsToStep;

    ErrorText := BuildValidationError;
    if ErrorText <> '' then
    begin
        MessagesHandler.ShowInfo(ErrorText);
        ModalResult := mrNone;
        Exit;
    end;

    ModalResult := mrOk;
end;

end.
