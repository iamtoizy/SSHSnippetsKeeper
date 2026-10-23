unit ParamsFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    MacroInputTypes,
    System.Classes,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls
    ;

type
    TParamsForm = class(TBaseForm)
        pnlMain: TPanel;
        lbPrompt: TLabel;
        sbRows: TScrollBox;
        bOK: TButton;
        bCancel: TButton;
        sbBottom: TStatusBar;
        procedure FormCreate(Sender: TObject);
        procedure bOKClick(Sender: TObject);
        procedure bCancelClick(Sender: TObject);
    private
        FParams: TArray<TMacroParamDescriptor>;
        FInputs: TArray<TWinControl>;
        FResultValues: TArray<string>;
        procedure BuildRows;
        procedure AdjustHeight;
        procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        function RowValue(Index: Integer): string;
        function ValidateRows(out BadIndex: Integer): Boolean;
    public
        procedure InitializeParams(const Params: TArray<TMacroParamDescriptor>);
        function CollectedValues: TArray<string>;
    end;

function ShowParamsForm(const Params: TArray<TMacroParamDescriptor>; const AppContext: IAppContext; var Values: TArray<string>): Boolean;

var
    ParamsForm: TParamsForm;

implementation

uses
    Common.Localization,
    InputFormUI,
    System.Math,
    System.SysUtils
    ;

const
    SP_PREFIX = '⏵ ';
    SP_POSTFIX = ', ⏎';
    ROW_HEIGHT = 30;
    ROW_TOP0 = 8;
    ROW_BOTTOM_PAD = 8;
    LABEL_LEFT = 8;
    LABEL_TOP_OFFSET = 3;
    CONTROL_LEFT = 164;
    CONTROL_WIDTH = 260;
    MIN_ROWS_HEIGHT = 100;
    TOP_AREA = 27;
    BUTTON_AREA = 45;
    MAX_FORM_CLIENT_HEIGHT = 520;

{$R *.dfm}

function ShowParamsFormModal(const Params: TArray<TMacroParamDescriptor>; const AppContext: IAppContext; var Values: TArray<string>): Boolean;
var
    Form: TParamsForm;
begin
    Form := TParamsForm.Create(nil);
    try
        Form.Initialize(AppContext);
        Form.InitializeParams(Params);
        Form.WarmUpPaint;
        Form.PrepareGuardedShow;

        Result := Form.ShowModal = mrOk;
        if Result then
            Values := Form.CollectedValues;
    finally
        Form.Free;
    end;
end;

function ShowParamsForm(const Params: TArray<TMacroParamDescriptor>; const AppContext: IAppContext; var Values: TArray<string>): Boolean;
var
    ModalOk: Boolean;
    ModalValues: TArray<string>;
begin
    ModalOk := False;
    ModalValues := nil;

    if TThread.CurrentThread.ThreadID = MainThreadID then
        ModalOk := ShowParamsFormModal(Params, AppContext, ModalValues)
    else
        TThread.Synchronize(nil,
            procedure
            begin
                ModalOk := ShowParamsFormModal(Params, AppContext, ModalValues);
            end);

    Result := ModalOk;
    if Result then
        Values := ModalValues;
end;

procedure TParamsForm.FormCreate(Sender: TObject);
begin
    FResultValues := nil;
end;

procedure TParamsForm.InitializeParams(const Params: TArray<TMacroParamDescriptor>);
begin
    FParams := Params;
    BuildRows;
    AdjustHeight;
    sbBottom.SimpleText := SP_PREFIX + TUIStateLoader.GetMessage('ParamsForm.Hint') + SP_POSTFIX;
end;

procedure TParamsForm.BuildRows;
var
    I: Integer;
    RowLabel: TLabel;
    RowEdit: TEdit;
    RowCombo: TComboBox;
    Option: string;
begin
    SetLength(FInputs, Length(FParams));

    for I := 0 to High(FParams) do
    begin
        RowLabel := TLabel.Create(Self);
        RowLabel.Parent := sbRows;
        RowLabel.Left := LABEL_LEFT;
        RowLabel.Top := ROW_TOP0 + I * ROW_HEIGHT + LABEL_TOP_OFFSET;
        RowLabel.Caption := FParams[I].Name;

        if FParams[I].InputType = mitSelect then
        begin
            RowCombo := TComboBox.Create(Self);
            RowCombo.Parent := sbRows;
            RowCombo.Style := csDropDownList;
            RowCombo.Left := CONTROL_LEFT;
            RowCombo.Top := ROW_TOP0 + I * ROW_HEIGHT;
            RowCombo.Width := CONTROL_WIDTH;
            for Option in FParams[I].DefaultValue.Split(['|']) do
                if Trim(Option) <> '' then
                    RowCombo.Items.Add(Trim(Option));
            if RowCombo.Items.Count > 0 then
                RowCombo.ItemIndex := 0;
            RowCombo.Tag := I;
            RowCombo.OnKeyDown := EditKeyDown;
            FInputs[I] := RowCombo;
        end
        else
        begin
            RowEdit := TEdit.Create(Self);
            RowEdit.Parent := sbRows;
            RowEdit.Left := CONTROL_LEFT;
            RowEdit.Top := ROW_TOP0 + I * ROW_HEIGHT;
            RowEdit.Width := CONTROL_WIDTH;
            RowEdit.Text := FParams[I].DefaultValue;
            if FParams[I].InputType = mitPassword then
                RowEdit.PasswordChar := '*';
            RowEdit.Tag := I;
            RowEdit.OnKeyDown := EditKeyDown;
            FInputs[I] := RowEdit;
        end;
    end;
end;

procedure TParamsForm.AdjustHeight;
var
    RowsHeight: Integer;
begin
    RowsHeight := ROW_TOP0 + Length(FParams) * ROW_HEIGHT + ROW_BOTTOM_PAD;
    if RowsHeight < MIN_ROWS_HEIGHT then
        RowsHeight := MIN_ROWS_HEIGHT;

    sbRows.Height := RowsHeight;
    ClientHeight := Min(TOP_AREA + RowsHeight + BUTTON_AREA + sbBottom.Height, MAX_FORM_CLIENT_HEIGHT);
end;

procedure TParamsForm.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    case Key of
        13:
            bOKClick(Self);
        27:
            ModalResult := mrCancel;
    end;
end;

function TParamsForm.RowValue(Index: Integer): string;
begin
    if FInputs[Index] is TComboBox then
    begin
        if TComboBox(FInputs[Index]).ItemIndex >= 0 then
            Result := TComboBox(FInputs[Index]).Items[TComboBox(FInputs[Index]).ItemIndex]
        else
            Result := '';
    end
    else
        Result := Trim(TEdit(FInputs[Index]).Text);
end;

function TParamsForm.ValidateRows(out BadIndex: Integer): Boolean;
var
    I: Integer;
begin
    BadIndex := -1;
    Result := True;

    for I := 0 to High(FInputs) do
    begin
        if not IsMacroValueValid(RowValue(I), FParams[I].InputType) then
        begin
            BadIndex := I;
            Result := False;
            Exit;
        end;
    end;
end;

procedure TParamsForm.bOKClick(Sender: TObject);
var
    BadIndex: Integer;
    I: Integer;
begin
    if not ValidateRows(BadIndex) then
    begin
        sbBottom.SimpleText := TUIStateLoader.GetMessage('ParamsForm.Error.Invalid', [FParams[BadIndex].Name]);
        if FInputs[BadIndex].CanFocus then
            FInputs[BadIndex].SetFocus;
        Exit;
    end;

    SetLength(FResultValues, Length(FInputs));
    for I := 0 to High(FInputs) do
        FResultValues[I] := RowValue(I);

    ModalResult := mrOk;
end;

procedure TParamsForm.bCancelClick(Sender: TObject);
begin
    ModalResult := mrCancel;
end;

function TParamsForm.CollectedValues: TArray<string>;
begin
    Result := FResultValues;
end;

end.
