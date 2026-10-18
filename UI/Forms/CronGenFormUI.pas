unit CronGenFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.Tools,
    System.Classes,
    System.Types,
    Vcl.CheckLst,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    System.SysUtils,
    Vcl.StdCtrls,
    Winapi.Messages
    ;

type
    // =========================================================================
    // Класс-перехватчик.
    // Лечит внутренний баг Delphi (EListError / ExtractWrapper) путем
    // жесткой блокировки мусорных координат от встроенного автоскролла Windows.
    // =========================================================================
    TCheckListBox = class(Vcl.CheckLst.TCheckListBox)
    private
        FOnBrushReleased: TProc;
        FOnBrushMove: TProc<Integer, Integer>;
    protected
        procedure WndProc(var Message: TMessage); override;
    public
        property OnBrushReleased: TProc read FOnBrushReleased write FOnBrushReleased;
        property OnBrushMove: TProc<Integer, Integer> read FOnBrushMove write FOnBrushMove;
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
        type
            TFieldGroup = record
                rbEvery, rbStep, rbRange, rbSpec: TRadioButton;
                ComboStep, ComboR1, ComboR2: TComboBox;
                CLB: TCheckListBox;
            end;

    private
        FCronService: ICronService;
        FUpdatingUI: Boolean;
        FGroups: TArray<TFieldGroup>;

        // Переменные для умной "кисти" чекбоксов (Через таймер)
        FActiveCLB: TCheckListBox;
        FBrushMode: Integer; // 1 = Check, 2 = Uncheck, 3 = Invert
        FLastBrushIdx: Integer;
        FStartBrushIdx: Integer;
        FBrushItemToggled: Boolean;

        procedure HandleBrushRelease;
        procedure HandleBrushMove(X, Y: Integer);
        procedure ApplyBrushAt(ACL: TCheckListBox; Idx: Integer);

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
        procedure InitFieldGroups;
        function MakeGroup(rbEvery, rbStep, rbRange, rbSpec: TRadioButton; cboStep, cboR1, cboR2: TComboBox; ACLB: TCheckListBox): TFieldGroup;
        function FindGroupByControl(Sender: TObject; out Group: TFieldGroup): Boolean;
        function FindGroupBySpecRadio(Sender: TObject; out Group: TFieldGroup): Boolean;
    public
        procedure DoInitialize; override;
    end;

var
    CronGenForm: TCronGenForm;

implementation

uses
    CommonHelpers,
    CronService,
    UI.HoverHelpManager,
    Common.Localization,
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
        if (Message.Msg = WM_MOUSEMOVE) and
            (TWMMouse(Message).Keys and MK_LBUTTON <> 0) and not MouseCapture then
            SetCapture(Handle);

        if (Message.Msg = WM_MOUSEMOVE) and Assigned(FOnBrushMove) and
            (TWMMouse(Message).Keys and MK_LBUTTON <> 0) then
            FOnBrushMove(TWMMouse(Message).XPos, TWMMouse(Message).YPos);

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
                if (Message.Msg = WM_LBUTTONUP) and Assigned(FOnBrushReleased) then
                    FOnBrushReleased();
                Exit;
            end;
        end;
    end;

    inherited WndProc(Message);
end;

// =========================================================================
// ОСНОВНОЙ КОД ФОРМЫ
// =========================================================================

procedure TCronGenForm.FormCreate(Sender: TObject);
begin
    inherited;

    RegisterHelp(clbMin,  hipBottomRight, 'Help.CronGenForm.CheckListBox', hkCustomForm);
    RegisterHelp(clbHour, hipBottomRight, 'Help.CronGenForm.CheckListBox', hkCustomForm);
    RegisterHelp(clbDom,  hipBottomRight, 'Help.CronGenForm.CheckListBox', hkCustomForm);
    RegisterHelp(clbMon,  hipBottomRight, 'Help.CronGenForm.CheckListBox', hkCustomForm);
    RegisterHelp(clbDow,  hipBottomRight, 'Help.CronGenForm.CheckListBox', hkCustomForm);

    pgcBuilder.DoubleBuffered := True;
end;

procedure TCronGenForm.DoInitialize;
begin
    inherited;

    FCronService := TCronService.Create;
    InitFieldGroups;

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

procedure TCronGenForm.InitFieldGroups;
begin
    FGroups := [
        MakeGroup(rbMinEvery,  rbMinStep,  rbMinRange,  rbMinSpec,  cboMinStep,  cboMinRange1,  cboMinRange2,  clbMin),
        MakeGroup(rbHourEvery, rbHourStep, rbHourRange, rbHourSpec, cboHourStep, cboHourRange1, cboHourRange2, clbHour),
        MakeGroup(rbDomEvery,  rbDomStep,  rbDomRange,  rbDomSpec,  cboDomStep,  cboDomRange1,  cboDomRange2,  clbDom),
        MakeGroup(rbMonEvery,  rbMonStep,  rbMonRange,  rbMonSpec,  cboMonStep,  cboMonRange1,  cboMonRange2,  clbMon),
        MakeGroup(rbDowEvery,  rbDowStep,  rbDowRange,  rbDowSpec,  cboDowStep,  cboDowRange1,  cboDowRange2,  clbDow)
    ];
end;

function TCronGenForm.MakeGroup(rbEvery, rbStep, rbRange, rbSpec: TRadioButton; cboStep, cboR1, cboR2: TComboBox; ACLB: TCheckListBox): TFieldGroup;
begin
    Result.rbEvery := rbEvery;
    Result.rbStep := rbStep;
    Result.rbRange := rbRange;
    Result.rbSpec := rbSpec;
    Result.ComboStep := cboStep;
    Result.ComboR1 := cboR1;
    Result.ComboR2 := cboR2;
    Result.CLB := ACLB;
end;

function TCronGenForm.FindGroupByControl(Sender: TObject; out Group: TFieldGroup): Boolean;
var
    G: TFieldGroup;
begin
    for G in FGroups do
        if (Sender = G.ComboStep) or (Sender = G.ComboR1) or
            (Sender = G.ComboR2) or (Sender = G.CLB) then
        begin
            Group := G;
            Exit(True);
        end;
    Result := False;
end;

function TCronGenForm.FindGroupBySpecRadio(Sender: TObject; out Group: TFieldGroup): Boolean;
var
    G: TFieldGroup;
begin
    for G in FGroups do
        if Sender = G.rbSpec then
        begin
            Group := G;
            Exit(True);
        end;
    Result := False;
end;

procedure TCronGenForm.HandleBrushRelease;
begin
    if (FBrushMode <> 0) and Assigned(FActiveCLB) then
        clbMouseUp(FActiveCLB, mbLeft, [], 0, 0);
end;

procedure TCronGenForm.HandleBrushMove(X, Y: Integer);
var
    Idx: Integer;
begin
    if not Assigned(FActiveCLB) or (FBrushMode = 0) then
        Exit;

    Idx := FActiveCLB.ItemAtPos(Point(X, Y), True);

    if (Idx >= 0) and (Idx < FActiveCLB.Items.Count) and (Idx <> FLastBrushIdx) then
    begin
        if not FBrushItemToggled then
        begin
            ApplyBrushAt(FActiveCLB, FStartBrushIdx);
            FBrushItemToggled := True;
        end;

        FLastBrushIdx := Idx;
        ApplyBrushAt(FActiveCLB, Idx);
        OnBuilderControlChange(FActiveCLB);
    end;
end;

procedure TCronGenForm.ApplyBrushAt(ACL: TCheckListBox; Idx: Integer);
begin
    if (Idx < 0) or (Idx >= ACL.Items.Count) then
        Exit;
    if FBrushMode = 3 then
        ACL.Checked[Idx] := not ACL.Checked[Idx]
    else
        ACL.Checked[Idx] := (FBrushMode = 1);
end;

procedure TCronGenForm.AssignEvents;
begin
    clbMin.OnBrushReleased  := HandleBrushRelease;
    clbMin.OnBrushMove      := HandleBrushMove;
    clbHour.OnBrushReleased := HandleBrushRelease;
    clbHour.OnBrushMove     := HandleBrushMove;
    clbDom.OnBrushReleased  := HandleBrushRelease;
    clbDom.OnBrushMove      := HandleBrushMove;
    clbMon.OnBrushReleased  := HandleBrushRelease;
    clbMon.OnBrushMove      := HandleBrushMove;
    clbDow.OnBrushReleased  := HandleBrushRelease;
    clbDow.OnBrushMove      := HandleBrushMove;

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
    Group: TFieldGroup;

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

    for Group in FGroups do
    begin
        SyncState(Group.rbEvery, []);
        SyncState(Group.rbStep,  [Group.ComboStep]);
        SyncState(Group.rbRange, [Group.ComboR1, Group.ComboR2]);
        SyncState(Group.rbSpec,  [Group.CLB]);
    end;
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
    I: Integer;
    MonthNames, DowNames: TArray<string>;
begin
    SetLength(MonthNames, 12);
    for I := 1 to 12 do
        MonthNames[I - 1] := TCronService.MonthName(I);

    SetLength(DowNames, 7);
    for I := 0 to 6 do
        DowNames[I] := TCronService.DowName(I);

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
var
    Group: TFieldGroup;
begin
    if FUpdatingUI then Exit;

    FUpdatingUI := True;
    try
        if FindGroupByControl(Sender, Group) then
        begin
            if Sender = Group.CLB then
            begin
                Group.rbSpec.Checked := True;
                if Group.CLB.ItemIndex < 0 then Group.CLB.ItemIndex := 0;
            end
            else if (Sender = Group.ComboR1) or (Sender = Group.ComboR2) then
                Group.rbRange.Checked := True
            else
                Group.rbStep.Checked := True;
        end;

        if FindGroupBySpecRadio(Sender, Group) and Group.CLB.CanFocus then
        begin
            Group.CLB.SetFocus;
            if Group.CLB.ItemIndex < 0 then Group.CLB.ItemIndex := 0;
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
    end;
end;

procedure TCronGenForm.clbMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
    if (Button = mbLeft) and (FBrushMode <> 0) and Assigned(FActiveCLB) then
    begin
        if not FBrushItemToggled then
            if (FStartBrushIdx >= 0) and (FStartBrushIdx < FActiveCLB.Items.Count) then
            begin
                ApplyBrushAt(FActiveCLB, FStartBrushIdx);
                FBrushItemToggled := True;
                OnBuilderControlChange(FActiveCLB);
            end;

        FBrushMode := 0;
        FActiveCLB := nil;
    end;
end;

end.
