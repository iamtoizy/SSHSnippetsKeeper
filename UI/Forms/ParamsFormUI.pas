unit ParamsFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    MacroInputTypes,
    System.Classes,
    System.Types,
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
        FRowLabels: TArray<TLabel>;
        FResultValues: TArray<string>;
        FStatusText: string;
        function DpiScale(AValue: Integer): Integer;
        function TargetWorkArea: TRect;
        function MaxLabelWidth: Integer;
        procedure BuildRows;
        procedure PlaceRows(AControlLeft: Integer);
        procedure AdjustLayout;
        procedure SetStatusText(const AText: string);
        procedure ApplyStatusText;
        procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        function RowValue(Index: Integer): string;
        function ValidateRows(out BadIndex: Integer): Boolean;
    protected
        procedure DoAfterMonitorDpiChanged(OldDPI, NewDPI: Integer); override;
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
    System.SysUtils,
    Winapi.Windows
    ;

const
    SP_PREFIX = '⏵ ';
    SP_POSTFIX = ', ⏎';
    ELLIPSIS = '…';
    ROW_HEIGHT = 30;
    ROW_TOP0 = 8;
    ROW_BOTTOM_PAD = 8;
    LABEL_LEFT = 8;
    LABEL_TOP_OFFSET = 3;
    LABEL_GAP = 12;
    CONTROL_LEFT = 164;
    CONTROL_WIDTH = 260;
    MIN_CONTROL_WIDTH = 120;
    CONTROL_RIGHT_PAD = 8;
    MIN_ROWS_HEIGHT = 100;
    BUTTON_AREA = 45;
    WORKAREA_MARGIN = 24;
    STATUS_LEFT_PAD = 8;

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
    SetStatusText(SP_PREFIX + TUIStateLoader.GetMessage('ParamsForm.Hint') + SP_POSTFIX);
    AdjustLayout;
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
    SetLength(FRowLabels, Length(FParams));

    for I := 0 to High(FParams) do
    begin
        RowLabel := TLabel.Create(Self);
        RowLabel.Parent := sbRows;
        RowLabel.Caption := FParams[I].Name;
        FRowLabels[I] := RowLabel;

        if FParams[I].InputType = mitSelect then
        begin
            RowCombo := TComboBox.Create(Self);
            RowCombo.Parent := sbRows;
            RowCombo.Style := csDropDownList;
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
            RowEdit.Text := FParams[I].DefaultValue;
            if FParams[I].InputType = mitPassword then
                RowEdit.PasswordChar := '*';
            RowEdit.Tag := I;
            RowEdit.OnKeyDown := EditKeyDown;
            FInputs[I] := RowEdit;
        end;
    end;
end;

function TParamsForm.DpiScale(AValue: Integer): Integer;
begin
    Result := MulDiv(AValue, CurrentPPI, 96);
end;

function TParamsForm.TargetWorkArea: TRect;
var
    Ref: TCustomForm;
begin
    Ref := Screen.ActiveCustomForm;
    if (Ref <> nil) and (Ref <> Self) and Ref.Visible and (Ref.Monitor <> nil) then
        Result := Ref.Monitor.WorkareaRect
    else
        Result := Screen.WorkAreaRect;
end;

function TParamsForm.MaxLabelWidth: Integer;
var
    I: Integer;
begin
    Result := 0;
    for I := 0 to High(FRowLabels) do
        Result := Max(Result, Canvas.TextWidth(FRowLabels[I].Caption));
end;

procedure TParamsForm.PlaceRows(AControlLeft: Integer);
var
    I, RowTop, ControlWidth, LabelSpace, BoxWidth, ContentH: Integer;
begin
    ContentH := DpiScale(ROW_TOP0) + Length(FParams) * DpiScale(ROW_HEIGHT) + DpiScale(ROW_BOTTOM_PAD);
    BoxWidth := sbRows.ClientWidth;
    if ContentH > sbRows.ClientHeight then
        Dec(BoxWidth, GetSystemMetrics(SM_CXVSCROLL));

    ControlWidth := Min(DpiScale(CONTROL_WIDTH), BoxWidth - AControlLeft - DpiScale(CONTROL_RIGHT_PAD));
    ControlWidth := Max(ControlWidth, DpiScale(MIN_CONTROL_WIDTH));
    LabelSpace := Max(AControlLeft - DpiScale(LABEL_LEFT) - DpiScale(LABEL_GAP), DpiScale(24));

    for I := 0 to High(FInputs) do
    begin
        RowTop := DpiScale(ROW_TOP0) + I * DpiScale(ROW_HEIGHT);
        FRowLabels[I].Left := DpiScale(LABEL_LEFT);
        FRowLabels[I].Top := RowTop + DpiScale(LABEL_TOP_OFFSET);
        if Canvas.TextWidth(FRowLabels[I].Caption) > LabelSpace then
        begin
            FRowLabels[I].AutoSize := False;
            FRowLabels[I].Width := LabelSpace;
            FRowLabels[I].EllipsisPosition := epEndEllipsis;
        end
        else
            FRowLabels[I].AutoSize := True;

        FInputs[I].Left := AControlLeft;
        FInputs[I].Top := RowTop;
        FInputs[I].Width := ControlWidth;
    end;
end;

procedure TParamsForm.AdjustLayout;
var
    Work: TRect;
    MaxW, MaxH, ControlLeft, RowsHeight, AvailableRowsH, NeededW, NeededH: Integer;
begin
    Work := TargetWorkArea;
    MaxW := Work.Width - DpiScale(WORKAREA_MARGIN);
    MaxH := Work.Height - DpiScale(WORKAREA_MARGIN);

    ControlLeft := Max(DpiScale(CONTROL_LEFT), DpiScale(LABEL_LEFT) + MaxLabelWidth + DpiScale(LABEL_GAP));

    RowsHeight := DpiScale(ROW_TOP0) + Length(FParams) * DpiScale(ROW_HEIGHT) + DpiScale(ROW_BOTTOM_PAD);
    RowsHeight := Max(RowsHeight, DpiScale(MIN_ROWS_HEIGHT));

    NeededW := sbRows.Left + ControlLeft + DpiScale(CONTROL_WIDTH) + DpiScale(CONTROL_RIGHT_PAD);
    NeededW := Max(NeededW, ClientWidth);
    NeededW := Min(NeededW, MaxW);

    NeededH := sbRows.Top + RowsHeight + DpiScale(BUTTON_AREA) + sbBottom.Height;
    NeededH := Min(NeededH, MaxH);

    ClientWidth := NeededW;
    ClientHeight := NeededH;

    AvailableRowsH := Max(ClientHeight - sbRows.Top - DpiScale(BUTTON_AREA) - sbBottom.Height, DpiScale(16));
    sbRows.Height := Min(RowsHeight, AvailableRowsH);

    PlaceRows(ControlLeft);
    ApplyStatusText;
end;

procedure TParamsForm.SetStatusText(const AText: string);
begin
    FStatusText := AText;
    ApplyStatusText;
end;

procedure TParamsForm.ApplyStatusText;
var
    S: string;
    MaxW: Integer;
begin
    S := FStatusText;
    MaxW := sbBottom.ClientWidth - DpiScale(STATUS_LEFT_PAD);
    if (S <> '') and (sbBottom.Canvas.TextWidth(S) > MaxW) then
    begin
        while (Length(S) > 1) and (sbBottom.Canvas.TextWidth(S + ELLIPSIS) > MaxW) do
            Delete(S, Length(S), 1);
        S := S + ELLIPSIS;
    end;
    sbBottom.SimpleText := S;
end;

procedure TParamsForm.DoAfterMonitorDpiChanged(OldDPI, NewDPI: Integer);
begin
    inherited;
    if Length(FInputs) > 0 then
        AdjustLayout;
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
        SetStatusText(TUIStateLoader.GetMessage('ParamsForm.Error.Invalid', [FParams[BadIndex].Name]));
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
