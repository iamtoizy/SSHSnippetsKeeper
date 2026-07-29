unit CronGenFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces,
    System.Classes,
    System.Types,
    Vcl.CheckLst,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls,
    Winapi.Messages // Обязательно для TMessage
    ;

type
    // =========================================================================
    // Класс-перехватчик.
    // Лечит внутренний баг Delphi (EListError / ExtractWrapper) путем
    // жесткой блокировки мусорных координат от встроенного автоскролла Windows.
    // =========================================================================
    TCheckListBox = class(Vcl.CheckLst.TCheckListBox)
    protected
        procedure WndProc(var Message: TMessage); override;
    end;

    TCronGenForm = class(TBaseForm)
        pnlTop: TPanel;
        lbTitle: TLabel;
        ebCronExpression: TEdit;
        bCopy: TButton;
        pgcBuilder: TPageControl;

        // Вкладки
        tsMinutes: TTabSheet;
        tsHours: TTabSheet;
        tsDaysOfMonth: TTabSheet;
        tsMonths: TTabSheet;
        tsDaysOfWeek: TTabSheet;

        // Минуты
        rbMinEvery: TRadioButton;
        rbMinStep: TRadioButton;
        cboMinStep: TComboBox;
        rbMinRange: TRadioButton;
        cboMinRange1: TComboBox;
        cboMinRange2: TComboBox;
        rbMinSpec: TRadioButton;
        clbMin: TCheckListBox;

        // Часы
        rbHourEvery: TRadioButton;
        rbHourStep: TRadioButton;
        cboHourStep: TComboBox;
        rbHourRange: TRadioButton;
        cboHourRange1: TComboBox;
        cboHourRange2: TComboBox;
        rbHourSpec: TRadioButton;
        clbHour: TCheckListBox;

        // Дни месяца
        rbDomEvery: TRadioButton;
        rbDomStep: TRadioButton;
        cboDomStep: TComboBox;
        rbDomRange: TRadioButton;
        cboDomRange1: TComboBox;
        cboDomRange2: TComboBox;
        rbDomSpec: TRadioButton;
        clbDom: TCheckListBox;

        // Месяцы
        rbMonEvery: TRadioButton;
        rbMonStep: TRadioButton;
        cboMonStep: TComboBox;
        rbMonRange: TRadioButton;
        cboMonRange1: TComboBox;
        cboMonRange2: TComboBox;
        rbMonSpec: TRadioButton;

        // Дни недели
        rbDowEvery: TRadioButton;
        rbDowStep: TRadioButton;
        cboDowStep: TComboBox;
        rbDowRange: TRadioButton;
        cboDowRange1: TComboBox;
        cboDowRange2: TComboBox;
        rbDowSpec: TRadioButton;
        clbDow: TCheckListBox;
        mHumanText: TMemo;
        clbMon: TCheckListBox;

        procedure FormCreate(Sender: TObject);
        procedure ebCronExpressionChange(Sender: TObject);
        procedure OnBuilderControlChange(Sender: TObject);
        procedure bCopyClick(Sender: TObject);
        procedure FormShow(Sender: TObject);

        // Обработчики Drag-to-Check
        procedure clbMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
        procedure clbMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
        procedure clbClickCheck(Sender: TObject);
    private
        FCronService: ICronService;
        FUpdatingUI: Boolean;

        // Переменные для умной "кисти" чекбоксов (Через таймер)
        FBrushTimer: TTimer;
        FActiveCLB: TCheckListBox;
        FBrushMode: Integer; // 1 = Check, 2 = Uncheck, 3 = Invert
        FLastBrushIdx: Integer;
        FStartBrushIdx: Integer;
        FBrushItemToggled: Boolean;

        procedure OnBrushTimerTick(Sender: TObject);

        procedure PopulateLists;
        procedure FillCheckList(CLB: TCheckListBox; Start, Stop: Integer; const Names: TArray<string> = []);
        procedure FillCombo(CBO: TComboBox; Start, Stop: Integer; const Names: TArray<string> = []);
        function BuildPart(rbEvery, rbStep, rbRange, rbSpec: TRadioButton; cboStep, cboR1, cboR2: TComboBox; clb: TCheckListBox; Offset: Integer = 0): string;
        procedure ParsePartToUI(const Part: string; rbEvery, rbStep, rbRange, rbSpec: TRadioButton; cboStep, cboR1, cboR2: TComboBox; clb: TCheckListBox; Offset: Integer = 0; MaxWrap: Integer = -1);
        procedure UpdateHumanTranslation;
        procedure BuildCronFromUI;
        procedure ParseCronToUI(const Expression: string);

        procedure AssignEvents;
        procedure UpdateCronUI;
    public
        class procedure Execute(AOwner: TComponent; AppContext: IAppContext);
        procedure Initialize(AppContext: IAppContext);
    end;

var
    CronGenForm: TCronGenForm;

implementation

uses
    CommonHelpers,
    CronService,
    System.SysUtils,
    UI.HoverHelpManager,
    UI.StateLoader,
    Vcl.Clipbrd,
    Vcl.Graphics,
    Winapi.Windows
    ;

{$R *.dfm}

// =========================================================================
// Реализация перехватчика TCheckListBox
// =========================================================================
procedure TCheckListBox.WndProc(var Message: TMessage);
var
    X, Y: SmallInt;
begin
    // Перехватываем системные сообщения движения мыши и отпускания кнопки
    if (Message.Msg = WM_MOUSEMOVE) or (Message.Msg = WM_LBUTTONUP) then
    begin
        // Если левая кнопка зажата (или это сообщение об её отпускании)
        if (Message.Msg = WM_LBUTTONUP) or (TWMMouse(Message).Keys and MK_LBUTTON <> 0) then
        begin
            X := TWMMouse(Message).XPos;
            Y := TWMMouse(Message).YPos;

            // Если координаты вылетели за границы клиентской части контрола
            if (X < 0) or (Y < 0) or (X > ClientWidth) or (Y > ClientHeight) then
            begin
                // Корректно снимаем системный захват (чтобы мышь не "залипла")
                if (Message.Msg = WM_LBUTTONUP) and MouseCapture then
                    ReleaseCapture;

                // БЛОКИРУЕМ ПЕРЕДАЧУ СООБЩЕНИЯ ДАЛЬШЕ.
                // VCL никогда не узнает, что мы вышли за границы, и не запустит
                // багованную функцию, приводящую к EListError (-5, -8, -18).
                Message.Result := 0;
                Exit;
            end;
        end;
    end;

    inherited WndProc(Message);
end;

// =========================================================================
// ОСНОВНОЙ КОД ФОРМЫ
// =========================================================================

class procedure TCronGenForm.Execute(AOwner: TComponent; AppContext: IAppContext);
var
    Frm: TCronGenForm;
begin
    Frm := TCronGenForm.Create(AOwner);
    try
        Frm.Initialize(AppContext);
        Frm.ShowModal;
    finally
        Frm.Free;
    end;
end;

procedure TCronGenForm.FormCreate(Sender: TObject);
begin
    inherited;

    RegisterHelp(clbMin,  hipBottomRight, 'Help.CronGenForm.CheckListBox', hkCustomForm);
    RegisterHelp(clbHour, hipBottomRight, 'Help.CronGenForm.CheckListBox', hkCustomForm);
    RegisterHelp(clbDom,  hipBottomRight, 'Help.CronGenForm.CheckListBox', hkCustomForm);
    RegisterHelp(clbMon,  hipBottomRight, 'Help.CronGenForm.CheckListBox', hkCustomForm);
    RegisterHelp(clbDow,  hipBottomRight, 'Help.CronGenForm.CheckListBox', hkCustomForm);

    FCronService := TCronService.Create;

    pgcBuilder.DoubleBuffered := True;

    // Таймер для надежной аппаратной кисти
    FBrushTimer := TTimer.Create(Self);
    FBrushTimer.Interval := 15;
    FBrushTimer.Enabled := False;
    FBrushTimer.OnTimer := OnBrushTimerTick;

    FUpdatingUI := True;
    try
        PopulateLists;
        AssignEvents;
        ParseCronToUI('*/15 2,4 * * 1-5');
    finally
        FUpdatingUI := False;
    end;

    UpdateCronUI;
    UpdateHumanTranslation;
end;

procedure TCronGenForm.AssignEvents;
begin
    cboMinStep.OnEnter    := OnBuilderControlChange;
    cboMinRange1.OnEnter  := OnBuilderControlChange;
    cboMinRange2.OnEnter  := OnBuilderControlChange;
    cboHourStep.OnEnter   := OnBuilderControlChange;
    cboHourRange1.OnEnter := OnBuilderControlChange;
    cboHourRange2.OnEnter := OnBuilderControlChange;
    cboDomStep.OnEnter    := OnBuilderControlChange;
    cboDomRange1.OnEnter  := OnBuilderControlChange;
    cboDomRange2.OnEnter  := OnBuilderControlChange;
    cboMonStep.OnEnter    := OnBuilderControlChange;
    cboMonRange1.OnEnter  := OnBuilderControlChange;
    cboMonRange2.OnEnter  := OnBuilderControlChange;
    cboDowStep.OnEnter    := OnBuilderControlChange;
    cboDowRange1.OnEnter  := OnBuilderControlChange;
    cboDowRange2.OnEnter  := OnBuilderControlChange;

    clbMin.OnEnter        := OnBuilderControlChange;
    clbMin.OnMouseDown    := clbMouseDown;
    clbMin.OnMouseUp      := clbMouseUp;
    clbMin.OnClickCheck   := clbClickCheck;

    clbHour.OnEnter       := OnBuilderControlChange;
    clbHour.OnMouseDown   := clbMouseDown;
    clbHour.OnMouseUp     := clbMouseUp;
    clbHour.OnClickCheck  := clbClickCheck;

    clbDom.OnEnter        := OnBuilderControlChange;
    clbDom.OnMouseDown    := clbMouseDown;
    clbDom.OnMouseUp      := clbMouseUp;
    clbDom.OnClickCheck   := clbClickCheck;

    clbMon.OnEnter        := OnBuilderControlChange;
    clbMon.OnMouseDown    := clbMouseDown;
    clbMon.OnMouseUp      := clbMouseUp;
    clbMon.OnClickCheck   := clbClickCheck;

    clbDow.OnEnter        := OnBuilderControlChange;
    clbDow.OnMouseDown    := clbMouseDown;
    clbDow.OnMouseUp      := clbMouseUp;
    clbDow.OnClickCheck   := clbClickCheck;
end;

procedure TCronGenForm.UpdateCronUI;
var
    InactiveColor: TColor;

    procedure SyncState(RB: TRadioButton; const Ctrls: array of TControl);
    var
        I: Integer;
        C: TControl;
        IsActive: Boolean;
        TargetColor: TColor;
    begin
        IsActive := RB.Checked;
        if IsActive then
        begin
            RB.Font.Style := [fsBold];
            TargetColor := clWindow;
        end
        else
        begin
            RB.Font.Style := [];
            TargetColor := InactiveColor;
        end;

        for I := Low(Ctrls) to High(Ctrls) do
        begin
            C := Ctrls[I];
            if C is TComboBox then
                TComboBox(C).Color := TargetColor
            else if C is TCheckListBox then
                TCheckListBox(C).Color := TargetColor;
        end;
    end;

begin
    InactiveColor := $00F0F0F0;

    SyncState(rbMinEvery,  []);
    SyncState(rbMinStep,   [cboMinStep]);
    SyncState(rbMinRange,  [cboMinRange1,  cboMinRange2]);
    SyncState(rbMinSpec,   [clbMin]);

    SyncState(rbHourEvery, []);
    SyncState(rbHourStep,  [cboHourStep]);
    SyncState(rbHourRange, [cboHourRange1, cboHourRange2]);
    SyncState(rbHourSpec,  [clbHour]);

    SyncState(rbDomEvery,  []);
    SyncState(rbDomStep,   [cboDomStep]);
    SyncState(rbDomRange,  [cboDomRange1,  cboDomRange2]);
    SyncState(rbDomSpec,   [clbDom]);

    SyncState(rbMonEvery,  []);
    SyncState(rbMonStep,   [cboMonStep]);
    SyncState(rbMonRange,  [cboMonRange1,  cboMonRange2]);
    SyncState(rbMonSpec,   [clbMon]);

    SyncState(rbDowEvery,  []);
    SyncState(rbDowStep,   [cboDowStep]);
    SyncState(rbDowRange,  [cboDowRange1,  cboDowRange2]);
    SyncState(rbDowSpec,   [clbDow]);
end;

procedure TCronGenForm.FillCheckList(CLB: TCheckListBox; Start, Stop: Integer; const Names: TArray<string> = []);
var
    I: Integer;
begin
    CLB.Items.BeginUpdate;
    try
        CLB.Items.Clear;
        for I := Start to Stop do
        begin
            if Length(Names) > 0 then
                CLB.Items.Add(Names[I - Start])
            else
                CLB.Items.Add(I.ToString);
        end;
    finally
        CLB.Items.EndUpdate;
    end;
end;

procedure TCronGenForm.FillCombo(CBO: TComboBox; Start, Stop: Integer; const Names: TArray<string> = []);
var
    I: Integer;
begin
    CBO.Items.BeginUpdate;
    try
        CBO.Items.Clear;
        for I := Start to Stop do
        begin
            if Length(Names) > 0 then
                CBO.Items.Add(Names[I - Start])
            else
                CBO.Items.Add(I.ToString);
        end;
        if CBO.Items.Count > 0 then
            CBO.ItemIndex := 0;
    finally
        CBO.Items.EndUpdate;
    end;
end;

procedure TCronGenForm.PopulateLists;
var
    MonthNames, DowNames: TArray<string>;
begin
    MonthNames := [
        TUIStateLoader.GetMessage('Cron.Month-1'),
        TUIStateLoader.GetMessage('Cron.Month-2'),
        TUIStateLoader.GetMessage('Cron.Month-3'),
        TUIStateLoader.GetMessage('Cron.Month-4'),
        TUIStateLoader.GetMessage('Cron.Month-5'),
        TUIStateLoader.GetMessage('Cron.Month-6'),
        TUIStateLoader.GetMessage('Cron.Month-7'),
        TUIStateLoader.GetMessage('Cron.Month-8'),
        TUIStateLoader.GetMessage('Cron.Month-9'),
        TUIStateLoader.GetMessage('Cron.Month-10'),
        TUIStateLoader.GetMessage('Cron.Month-11'),
        TUIStateLoader.GetMessage('Cron.Month-12')
    ];

    DowNames := [
        TUIStateLoader.GetMessage('Cron.Dow-0'),
        TUIStateLoader.GetMessage('Cron.Dow-1'),
        TUIStateLoader.GetMessage('Cron.Dow-2'),
        TUIStateLoader.GetMessage('Cron.Dow-3'),
        TUIStateLoader.GetMessage('Cron.Dow-4'),
        TUIStateLoader.GetMessage('Cron.Dow-5'),
        TUIStateLoader.GetMessage('Cron.Dow-6')
    ];

    clbMin.Columns  := 10;
    clbHour.Columns := 6;
    clbDom.Columns  := 7;
    clbMon.Columns  := 4;
    clbDow.Columns  := 4;

    FillCombo(cboMinStep,    1, 59);
    cboMinStep.ItemIndex := 14;
    FillCombo(cboMinRange1,  0, 59);
    FillCombo(cboMinRange2,  0, 59);
    FillCheckList(clbMin,    0, 59);

    FillCombo(cboHourStep,   1, 23);
    cboHourStep.ItemIndex := 1;
    FillCombo(cboHourRange1, 0, 23);
    FillCombo(cboHourRange2, 0, 23);
    FillCheckList(clbHour,   0, 23);

    FillCombo(cboDomStep,    1, 31);
    FillCombo(cboDomRange1,  1, 31);
    FillCombo(cboDomRange2,  1, 31);
    FillCheckList(clbDom,    1, 31);

    FillCombo(cboMonStep,    1, 12);
    FillCombo(cboMonRange1,  1, 12, MonthNames);
    FillCombo(cboMonRange2,  1, 12, MonthNames);
    FillCheckList(clbMon,    1, 12, MonthNames);

    FillCombo(cboDowStep,    1, 7);
    FillCombo(cboDowRange1,  0, 6, DowNames);
    FillCombo(cboDowRange2,  0, 6, DowNames);
    FillCheckList(clbDow,    0, 6, DowNames);
end;

function TCronGenForm.BuildPart(rbEvery, rbStep, rbRange, rbSpec: TRadioButton; cboStep, cboR1, cboR2: TComboBox; clb: TCheckListBox; Offset: Integer): string;
var
    I: Integer;
    Sb: TStringBuilder;
begin
    if rbEvery.Checked then
        Exit('*');
    if rbStep.Checked then
        Exit('*/' + cboStep.Text);
    if rbRange.Checked then
        Exit((cboR1.ItemIndex + Offset).ToString + '-' + (cboR2.ItemIndex + Offset).ToString);

    if rbSpec.Checked then
    begin
        Sb := TStringBuilder.Create;
        try
            for I := 0 to clb.Items.Count - 1 do
                if clb.Checked[I] then
                begin
                    if Sb.Length > 0 then
                        Sb.Append(',');
                    Sb.Append((I + Offset).ToString);
                end;
            if Sb.Length = 0 then
                Exit('*');
            Exit(Sb.ToString);
        finally
            Sb.Free;
        end;
    end;
    Result := '*';
end;

procedure TCronGenForm.ParsePartToUI(const Part: string; rbEvery, rbStep, rbRange, rbSpec: TRadioButton; cboStep, cboR1, cboR2: TComboBox; clb: TCheckListBox; Offset: Integer; MaxWrap: Integer);
var
    I, Val: Integer;
    Arr: TArray<string>;
begin
    for I := 0 to clb.Items.Count - 1 do
        clb.Checked[I] := False;

    if (Part = '*') or (Part = '*/1') then
        rbEvery.Checked := True
    else if Part.StartsWith('*/') then
    begin
        rbStep.Checked := True;
        Val := StrToIntDef(Part.Substring(2), 1);
        if Val <= cboStep.Items.Count then
            cboStep.ItemIndex := Val - 1;
    end
    else if Part.Contains('-') and not Part.Contains(',') then
    begin
        rbRange.Checked := True;
        Arr := Part.Split(['-']);

        Val := StrToIntDef(Arr[0], Offset);
        if (MaxWrap > 0) and (Val = MaxWrap) then Val := 0;
        if (Val - Offset >= 0) and (Val - Offset < cboR1.Items.Count) then
            cboR1.ItemIndex := Val - Offset;

        Val := StrToIntDef(Arr[1], Offset);
        if (MaxWrap > 0) and (Val = MaxWrap) then Val := 0;
        if (Val - Offset >= 0) and (Val - Offset < cboR2.Items.Count) then
            cboR2.ItemIndex := Val - Offset;
    end
    else
    begin
        rbSpec.Checked := True;
        Arr := Part.Split([',']);
        for I := 0 to High(Arr) do
        begin
            Val := StrToIntDef(Arr[I], -1);
            if (MaxWrap > 0) and (Val = MaxWrap) then Val := 0;

            if (Val - Offset >= 0) and (Val - Offset < clb.Items.Count) then
                clb.Checked[Val - Offset] := True;
        end;
    end;
end;

procedure TCronGenForm.ParseCronToUI(const Expression: string);
var
    Parts: TArray<string>;
begin
    Parts := Expression.Trim.Split([' '], TStringSplitOptions.ExcludeEmpty);
    if Length(Parts) <> 5 then
        Exit;

    ParsePartToUI(Parts[0], rbMinEvery,  rbMinStep,  rbMinRange,  rbMinSpec,  cboMinStep,  cboMinRange1,  cboMinRange2,  clbMin,  0);
    ParsePartToUI(Parts[1], rbHourEvery, rbHourStep, rbHourRange, rbHourSpec, cboHourStep, cboHourRange1, cboHourRange2, clbHour, 0);
    ParsePartToUI(Parts[2], rbDomEvery,  rbDomStep,  rbDomRange,  rbDomSpec,  cboDomStep,  cboDomRange1,  cboDomRange2,  clbDom,  1);
    ParsePartToUI(Parts[3], rbMonEvery,  rbMonStep,  rbMonRange,  rbMonSpec,  cboMonStep,  cboMonRange1,  cboMonRange2,  clbMon,  1);
    ParsePartToUI(Parts[4], rbDowEvery,  rbDowStep,  rbDowRange,  rbDowSpec,  cboDowStep,  cboDowRange1,  cboDowRange2,  clbDow,  0, 7);

    ebCronExpression.Text := Expression;
end;

procedure TCronGenForm.BuildCronFromUI;
begin
    if FUpdatingUI then Exit;

    FUpdatingUI := True;
    try
        ebCronExpression.Text := Format('%s %s %s %s %s', [
            BuildPart(rbMinEvery,  rbMinStep,  rbMinRange,  rbMinSpec,  cboMinStep,  cboMinRange1,  cboMinRange2,  clbMin,  0),
            BuildPart(rbHourEvery, rbHourStep, rbHourRange, rbHourSpec, cboHourStep, cboHourRange1, cboHourRange2, clbHour, 0),
            BuildPart(rbDomEvery,  rbDomStep,  rbDomRange,  rbDomSpec,  cboDomStep,  cboDomRange1,  cboDomRange2,  clbDom,  1),
            BuildPart(rbMonEvery,  rbMonStep,  rbMonRange,  rbMonSpec,  cboMonStep,  cboMonRange1,  cboMonRange2,  clbMon,  1),
            BuildPart(rbDowEvery,  rbDowStep,  rbDowRange,  rbDowSpec,  cboDowStep,  cboDowRange1,  cboDowRange2,  clbDow,  0)
        ]);

        UpdateHumanTranslation;
    finally
        FUpdatingUI := False;
    end;
end;

procedure TCronGenForm.ebCronExpressionChange(Sender: TObject);
begin
    if FUpdatingUI then Exit;

    FUpdatingUI := True;
    try
        ParseCronToUI(ebCronExpression.Text);
        UpdateCronUI;
        UpdateHumanTranslation;
    finally
        FUpdatingUI := False;
    end;
end;


procedure TCronGenForm.UpdateHumanTranslation;
begin
    mHumanText.Text := FCronService.ExpressionToHumanText(ebCronExpression.Text);
end;

procedure TCronGenForm.bCopyClick(Sender: TObject);
begin
    Clipboard.AsText := ebCronExpression.Text;
    ShowSimpleToast(TUIStateLoader.GetMessage('CronGenForm.CopiedToClipboardToast'));
end;

procedure TCronGenForm.OnBuilderControlChange(Sender: TObject);
begin
    if FUpdatingUI then Exit;

    FUpdatingUI := True;
    try
        if Sender = cboMinStep then rbMinStep.Checked := True
        else if (Sender = cboMinRange1) or (Sender = cboMinRange2) then rbMinRange.Checked := True
        else if Sender = clbMin then
        begin
            rbMinSpec.Checked := True;
            if clbMin.ItemIndex < 0 then clbMin.ItemIndex := 0;
        end
        else if Sender = cboHourStep then rbHourStep.Checked := True
        else if (Sender = cboHourRange1) or (Sender = cboHourRange2) then rbHourRange.Checked := True
        else if Sender = clbHour then
        begin
            rbHourSpec.Checked := True;
            if clbHour.ItemIndex < 0 then clbHour.ItemIndex := 0;
        end
        else if Sender = cboDomStep then rbDomStep.Checked := True
        else if (Sender = cboDomRange1) or (Sender = cboDomRange2) then rbDomRange.Checked := True
        else if Sender = clbDom then
        begin
            rbDomSpec.Checked := True;
            if clbDom.ItemIndex < 0 then clbDom.ItemIndex := 0;
        end
        else if Sender = cboMonStep then rbMonStep.Checked := True
        else if (Sender = cboMonRange1) or (Sender = cboMonRange2) then rbMonRange.Checked := True
        else if Sender = clbMon then
        begin
            rbMonSpec.Checked := True;
            if clbMon.ItemIndex < 0 then clbMon.ItemIndex := 0;
        end
        else if Sender = cboDowStep then rbDowStep.Checked := True
        else if (Sender = cboDowRange1) or (Sender = cboDowRange2) then rbDowRange.Checked := True
        else if Sender = clbDow then
        begin
            rbDowSpec.Checked := True;
            if clbDow.ItemIndex < 0 then clbDow.ItemIndex := 0;
        end;

        if (Sender = rbMinSpec) and clbMin.CanFocus then
        begin
            clbMin.SetFocus;
            if clbMin.ItemIndex < 0 then clbMin.ItemIndex := 0;
        end
        else if (Sender = rbHourSpec) and clbHour.CanFocus then
        begin
            clbHour.SetFocus;
            if clbHour.ItemIndex < 0 then clbHour.ItemIndex := 0;
        end
        else if (Sender = rbDomSpec) and clbDom.CanFocus then
        begin
            clbDom.SetFocus;
            if clbDom.ItemIndex < 0 then clbDom.ItemIndex := 0;
        end
        else if (Sender = rbMonSpec) and clbMon.CanFocus then
        begin
            clbMon.SetFocus;
            if clbMon.ItemIndex < 0 then clbMon.ItemIndex := 0;
        end
        else if (Sender = rbDowSpec) and clbDow.CanFocus then
        begin
            clbDow.SetFocus;
            if clbDow.ItemIndex < 0 then clbDow.ItemIndex := 0;
        end;

    finally
        FUpdatingUI := False;
    end;

    UpdateCronUI;
    BuildCronFromUI;
end;

procedure TCronGenForm.FormShow(Sender: TObject);
begin
    pgcBuilder.ActivePage := tsMinutes;
end;

procedure TCronGenForm.Initialize(AppContext: IAppContext);
begin
    inherited Initialize(AppContext);
end;

// =========================================================================
// Машина состояний для выделения чекбоксов (Надежная реализация через Таймер)
// =========================================================================

procedure TCronGenForm.clbClickCheck(Sender: TObject);
begin
    FBrushItemToggled := True;
    OnBuilderControlChange(Sender);
end;

procedure TCronGenForm.clbMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
    Idx: Integer;
begin
    if Button <> mbLeft then Exit;
    if not (Sender is TCheckListBox) then Exit;

    FActiveCLB := TCheckListBox(Sender);

    if (X < 0) or (Y < 0) or (X > FActiveCLB.ClientWidth) or (Y > FActiveCLB.ClientHeight) then
    begin
        FActiveCLB := nil;
        Exit;
    end;

    Idx := FActiveCLB.ItemAtPos(Point(X, Y), True);

    if (Idx >= 0) and (Idx < FActiveCLB.Items.Count) then
    begin
        if ssShift in Shift then
            FBrushMode := 2
        else if ssCtrl in Shift then
            FBrushMode := 1
        else if ssAlt in Shift then
            FBrushMode := 3
        else
        begin
            if FActiveCLB.Checked[Idx] then
                FBrushMode := 2
            else
                FBrushMode := 1;
        end;

        FLastBrushIdx := Idx;
        FStartBrushIdx := Idx;
        FBrushItemToggled := False;

        FBrushTimer.Enabled := True;
    end;
end;

procedure TCronGenForm.OnBrushTimerTick(Sender: TObject);
var
    Pt: TPoint;
    Idx: Integer;
begin
    if not Assigned(FActiveCLB) or (FBrushMode = 0) then
    begin
        FBrushTimer.Enabled := False;
        Exit;
    end;

    // Функция возвращает отрицательное число (< 0), если кнопка зажата.
    // Если результат >= 0, значит кнопка отпущена (юзер бросил мышку).
    if GetAsyncKeyState(VK_LBUTTON) >= 0 then
    begin
        clbMouseUp(FActiveCLB, mbLeft, [], 0, 0);
        Exit;
    end;

    Pt := FActiveCLB.ScreenToClient(Mouse.CursorPos);

    if (Pt.X < 0) or (Pt.Y < 0) or (Pt.X > FActiveCLB.ClientWidth) or (Pt.Y > FActiveCLB.ClientHeight) then
        Exit;

    Idx := FActiveCLB.ItemAtPos(Pt, True);

    if (Idx >= 0) and (Idx < FActiveCLB.Items.Count) and (Idx <> FLastBrushIdx) then
    begin
        if not FBrushItemToggled then
        begin
            if FBrushMode = 3 then
                FActiveCLB.Checked[FStartBrushIdx] := not FActiveCLB.Checked[FStartBrushIdx]
            else
                FActiveCLB.Checked[FStartBrushIdx] := (FBrushMode = 1);
            FBrushItemToggled := True;
        end;

        FLastBrushIdx := Idx;

        if FBrushMode = 3 then
            FActiveCLB.Checked[Idx] := not FActiveCLB.Checked[Idx]
        else
            FActiveCLB.Checked[Idx] := (FBrushMode = 1);

        OnBuilderControlChange(FActiveCLB);
    end;
end;

procedure TCronGenForm.clbMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
    if (Button = mbLeft) and (FBrushMode <> 0) and Assigned(FActiveCLB) then
    begin
        FBrushTimer.Enabled := False;

        if not FBrushItemToggled then
        begin
            if (FStartBrushIdx >= 0) and (FStartBrushIdx < FActiveCLB.Items.Count) then
            begin
                if FBrushMode = 3 then
                    FActiveCLB.Checked[FStartBrushIdx] := not FActiveCLB.Checked[FStartBrushIdx]
                else
                    FActiveCLB.Checked[FStartBrushIdx] := (FBrushMode = 1);

                FBrushItemToggled := True;
                OnBuilderControlChange(FActiveCLB);
            end;
        end;

        FBrushMode := 0;
        FActiveCLB := nil;
    end;
end;

end.
