unit NetworkFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces,
    NetworkCalcService,
    System.Classes,
    System.SysUtils,
    System.Variants,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.Dialogs,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.Graphics,
    Vcl.Mask,
    Vcl.Samples.Spin,
    Vcl.StdCtrls,
    Winapi.Messages,
    Winapi.Windows,
    // Последним модулем:
    HintTextEdit
    ;

type
    TNetworkForm = class(TBaseForm)
        gbTop: TGroupBox;
        seMask: TSpinEdit;
        pcMain: TPageControl;
        tsInfo: TTabSheet;
        tsVLSM: TTabSheet;
        pnlVLSMTop: TPanel;
        lbVLSMMask: TLabel;
        seVLSM: TSpinEdit;
        lvVLSM: TListView;
        ledNetworkAddress: TLabeledEdit;
        ledHostRange: TLabeledEdit;
        ledBroadcastAddress: TLabeledEdit;
        ledUsableHosts: TLabeledEdit;
        ledNetmask: TLabeledEdit;
        ledWildcardMask: TLabeledEdit;
        ledNetworkType: TLabeledEdit;
        ledBinaryView: TLabeledEdit;
        bCopyNetworkAddress: TButton;
        bCopyHostRange: TButton;
        bCopyBroadcastAddress: TButton;
        bCopyTotalhosts: TButton;
        bCopyNetmask: TButton;
        bCopyWildcardMask: TButton;
        bCopyNetworkType: TButton;
        bCopyBinaryView: TButton;
        tmrEraseStatusBar: TTimer;
        bCopyAll: TButton;
        cbIPInput: TComboBox;
        sbBottom: TStatusBar;
        lbVLSMHostCount: TLabel;
        bCopyVLSM: TButton;
        procedure bCopyAllClick(Sender: TObject);
        procedure bCopyNetworkAddressClick(Sender: TObject);
        procedure bCopyVLSMClick(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure cbIPInputChange(Sender: TObject);
        procedure cbIPInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure cbIPInputExit(Sender: TObject);
        procedure cbIPInputKeyPress(Sender: TObject; var Key: Char);
        procedure FormClose(Sender: TObject; var Action: TCloseAction);
        procedure lvVLSMKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure lvVLSMResize(Sender: TObject);
        procedure pcMainChange(Sender: TObject);
        procedure seMaskChange(Sender: TObject);
        procedure tmrEraseStatusBarTimer(Sender: TObject);
        procedure seVLSMChange(Sender: TObject);
    private
        FLastStatusBarText: string;
        FAutoSaveTimer: TTimer;
        class var FCurrentInstance: TNetworkForm;

        procedure UpdateCalculations;
        procedure UpdateVLSM(Net: TIPv4Network);
        procedure ClearFields;
        procedure SaveToHistory;
        procedure OnAutoSaveTimerTick(Sender: TObject);
        function GetNetworkTypeName(NetType: TIPNetworkType): string;
        function GetDefaultTextColor: TColor;
        procedure ResizeVLSMColumns;
        procedure CopyVLSMToClipboard(OnlySelected: Boolean);

        // НОВЫЙ МЕТОД: Централизованное управление статус-баром
        procedure ShowStatusMessage(const Msg: string);
    public
        class procedure ExecuteGlobal(Owner: TComponent; AppContext: IAppContext);
        procedure Initialize(AppContext: IAppContext);
    end;

var
    NetworkForm: TNetworkForm;

implementation

uses
    CommonHelpers,
    System.StrUtils,
    UI.HoverHelpManager,
    UI.StateLoader,
    Vcl.Clipbrd,
    Vcl.Themes,
    Winapi.CommCtrl
    ;

{$R *.dfm}

var
    SessionIPHistory: TStringList;

function TNetworkForm.GetDefaultTextColor: TColor;
begin
    if StyleServices.Enabled then
    begin
        Result := StyleServices.GetStyleFontColor(sfEditBoxTextNormal);
        if (Result = clNone) or (Result = clDefault) then
            Result := StyleServices.GetSystemColor(clWindowText);
    end
    else
        Result := clWindowText;
end;

// ЦЕНТРАЛИЗОВАННАЯ ФУНКЦИЯ ДЛЯ СТАТУС-БАРА
procedure TNetworkForm.ShowStatusMessage(const Msg: string);
begin
    sbBottom.SimpleText := Msg;
    FLastStatusBarText := Msg;

    // Всегда сбрасываем таймер перед новым запуском
    tmrEraseStatusBar.Enabled := False;

    // Запускаем очистку только если сообщение не пустое
    if Msg <> '' then
        tmrEraseStatusBar.Enabled := True;
end;

procedure TNetworkForm.bCopyAllClick(Sender: TObject);
var
    Sb: TStringBuilder;
begin
    if ledNetworkAddress.Text = '' then
    begin
        ShowStatusMessage(TUIStateLoader.GetMessage('Common.NoDataToCopy'));
        Exit;
    end;

    Sb := TStringBuilder.Create;
    try
        Sb.AppendLine('--- IP Calculator Results ---');
        Sb.AppendLine(Format('Input: %s / %d', [cbIPInput.Text, seMask.Value]));
        Sb.AppendLine('Network: ' + ledNetworkAddress.Text);
        Sb.AppendLine('Host Range: ' + ledHostRange.Text);
        Sb.AppendLine('Broadcast: ' + ledBroadcastAddress.Text);
        Sb.AppendLine('Netmask: ' + ledNetmask.Text);
        Sb.AppendLine('Wildcard: ' + ledWildcardMask.Text);
        Sb.AppendLine('Usable Hosts: ' + ledUsableHosts.Text);
        Sb.AppendLine('Type: ' + ledNetworkType.Text);

        Clipboard.AsText := Sb.ToString;

        ShowStatusMessage(TUIStateLoader.GetMessage('Common.CopiedToClipboard'));
    finally
        Sb.Free;
    end;
end;

procedure TNetworkForm.bCopyNetworkAddressClick(Sender: TObject);
const
    TAG_COPY_NET_ADDR     = 0;
    TAG_COPY_HOST_RANGE   = 1;
    TAG_COPY_BROADCAST    = 2;
    TAG_COPY_USABLE_HOSTS = 3;
    TAG_COPY_NETMASK      = 4;
    TAG_COPY_WILDCARD     = 5;
    TAG_COPY_NET_TYPE     = 6;
    TAG_COPY_BINARY       = 7;
var
    TargetText: string;
    BtnTag: Integer;
begin
    BtnTag := (Sender as TComponent).Tag;
    TargetText := '';

    case BtnTag of
        TAG_COPY_NET_ADDR:     TargetText := ledNetworkAddress.Text + '/' + seMask.Value.ToString;
        TAG_COPY_HOST_RANGE:   TargetText := ledHostRange.Text;
        TAG_COPY_BROADCAST:    TargetText := ledBroadcastAddress.Text;
        TAG_COPY_USABLE_HOSTS: TargetText := ledUsableHosts.Text;
        TAG_COPY_NETMASK:      TargetText := ledNetmask.Text;
        TAG_COPY_WILDCARD:     TargetText := ledWildcardMask.Text;
        TAG_COPY_NET_TYPE:     TargetText := ledNetworkType.Text;
        TAG_COPY_BINARY:       TargetText := ledBinaryView.Text;
    end;

    if (TargetText <> '') then
    begin
        Clipboard.AsText := TargetText;
        ShowStatusMessage(TUIStateLoader.GetMessage('Common.CopiedToClipboard'));
    end;
end;

procedure TNetworkForm.bCopyVLSMClick(Sender: TObject);
begin
    CopyVLSMToClipboard(False);
end;

procedure TNetworkForm.FormCreate(Sender: TObject);
begin
    seMask.MinValue  := 0;
    seMask.MaxValue  := 32;
    seMask.Value     := 24;
    seMask.MaxLength := 2;
    seMask.OnChange := seMaskChange;

    seVLSM.MinValue := 0;
    seVLSM.MaxValue := 32;
    seVLSM.Value    := 26;
    seVLSM.MaxLength := 2;
    seVLSM.OnChange := seVLSMChange;

    ledNetworkAddress.ReadOnly   := True;
    ledHostRange.ReadOnly        := True;
    ledBroadcastAddress.ReadOnly := True;
    ledUsableHosts.ReadOnly      := True;
    ledNetmask.ReadOnly          := True;
    ledWildcardMask.ReadOnly     := True;
    ledNetworkType.ReadOnly      := True;
    ledBinaryView.ReadOnly       := True;

    ledBinaryView.Font.Name := 'Consolas';

    cbIPInput.StyleElements := cbIPInput.StyleElements - [seFont];
    cbIPInput.Font.Color := GetDefaultTextColor;

    FAutoSaveTimer := TTimer.Create(Self);
    FAutoSaveTimer.Interval := 2000;
    FAutoSaveTimer.Enabled := False;
    FAutoSaveTimer.OnTimer := OnAutoSaveTimerTick;

    pcMain.ActivePage := tsInfo;

    cbIPInput.Items.Assign(SessionIPHistory);
end;

procedure TNetworkForm.cbIPInputChange(Sender: TObject);
begin
    UpdateCalculations;
end;

procedure TNetworkForm.cbIPInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if Key = VK_RETURN then
    begin
        SaveToHistory;
        Key := 0;
    end;
end;

procedure TNetworkForm.cbIPInputExit(Sender: TObject);
begin
    SaveToHistory;
end;

procedure TNetworkForm.cbIPInputKeyPress(Sender: TObject; var Key: Char);
begin
    if Key = ',' then
        Key := '.';

    if CharInSet(Key, [#1, #3, #8, #22, #24, #26]) then
        Exit;

    if Key = '/' then
    begin
        if Pos('/', cbIPInput.Text) > 0 then
            Key := #0;
        Exit;
    end;

    if not CharInSet(Key, ['0'..'9', '.']) then
        Key := #0;
end;

class procedure TNetworkForm.ExecuteGlobal(Owner: TComponent; AppContext: IAppContext);
begin
    if Assigned(FCurrentInstance) then
    begin
        if FCurrentInstance.WindowState = wsMinimized then
            FCurrentInstance.WindowState := wsNormal;
        SetForegroundWindow(FCurrentInstance.Handle);
        FCurrentInstance.BringToFront;
        Exit;
    end;

    FCurrentInstance := TNetworkForm.Create(Application);
    FCurrentInstance.Initialize(AppContext);
    FCurrentInstance.FormStyle := fsStayOnTop;
    FCurrentInstance.Show;
end;

procedure TNetworkForm.seMaskChange(Sender: TObject);
var
    OldStart: Integer;
begin
    OldStart := seMask.SelStart;

    if (seMask.Value < 0) then
    begin
        seMask.Value := 0;
        seMask.SelStart := OldStart;
        seMask.SelLength := 0;
    end
    else if (seMask.Value > 32) then
    begin
        seMask.Value := 32;
        seMask.SelStart := OldStart;
        seMask.SelLength := 0;
    end;

    if seVLSM.Value < seMask.Value then
    begin
        seVLSM.OnChange := nil;
        try
            seVLSM.Value := seMask.Value;
        finally
            seVLSM.OnChange := seVLSMChange;
        end;
    end;

    UpdateCalculations;
end;

procedure TNetworkForm.seVLSMChange(Sender: TObject);
var
    OldStart: Integer;
begin
    OldStart := seVLSM.SelStart;

    if (seVLSM.Value < 0) then
    begin
        seVLSM.Value := 0;
        seVLSM.SelStart := OldStart;
        seVLSM.SelLength := 0;
    end
    else if (seVLSM.Value > 32) then
    begin
        seVLSM.Value := 32;
        seVLSM.SelStart := OldStart;
        seVLSM.SelLength := 0;
    end;

    UpdateCalculations;
end;

procedure TNetworkForm.ClearFields;
begin
    ledNetworkAddress.Text   := '';
    ledBroadcastAddress.Text := '';
    ledNetmask.Text          := '';
    ledWildcardMask.Text     := '';
    ledUsableHosts.Text      := '';
    ledHostRange.Text        := '';
    ledNetworkType.Text      := '';
    ledBinaryView.Text       := '';
    lvVLSM.Items.Clear;
end;

procedure TNetworkForm.CopyVLSMToClipboard(OnlySelected: Boolean);
var
    Sb: TStringBuilder;
    I, J: Integer;
    Item: TListItem;
    HasData: Boolean;
begin
    if lvVLSM.Items.Count = 0 then Exit;

    Sb := TStringBuilder.Create;
    try
        Sb.AppendLine('№' + #9 + 'Subnet' + #9 + 'Hosts range' + #9 + 'Broadcast');

        HasData := False;
        for I := 0 to lvVLSM.Items.Count - 1 do
        begin
            Item := lvVLSM.Items[I];

            if OnlySelected and not Item.Selected then
                Continue;

            HasData := True;

            Sb.Append(Item.Caption);
            for J := 0 to Item.SubItems.Count - 1 do
                Sb.Append(#9 + Item.SubItems[J]);

            Sb.AppendLine;
        end;

        if HasData then
        begin
            Clipboard.AsText := Sb.ToString;
            ShowStatusMessage(TUIStateLoader.GetMessage('Common.CopiedToClipboard'));
        end;
    finally
        Sb.Free;
    end;
end;

procedure TNetworkForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
    Action := caFree;
    if FCurrentInstance = Self then
        FCurrentInstance := nil;
end;

function TNetworkForm.GetNetworkTypeName(NetType: TIPNetworkType): string;
begin
    case NetType of
        ntPublic:    Result := 'Public IP';
        ntPrivate:   Result := 'Private (RFC 1918)';
        ntLoopback:  Result := 'Loopback (Localhost)';
        ntLinkLocal: Result := 'Link-Local (APIPA)';
        ntMulticast: Result := 'Multicast';
        ntBroadcast: Result := 'Broadcast';
    else
        Result := 'Unknown';
    end;
end;

procedure TNetworkForm.Initialize(AppContext: IAppContext);
begin
    inherited Initialize(AppContext);

    RegisterHelp(cbIPInput,           hipRightCenter, 'Help.NetworkForm.cbIPInput', hkCustomForm, -2);
    RegisterHelp(seMask,              hipRightCenter, 'Help.NetworkForm.seMask');
    RegisterHelp(ledNetworkAddress,   hipTopRight,    'Help.NetworkForm.ledNetworkAddress');
    RegisterHelp(ledHostRange,        hipTopRight,    'Help.NetworkForm.ledHostRange');
    RegisterHelp(ledBroadcastAddress, hipTopRight,    'Help.NetworkForm.ledBroadcastAddress');
    RegisterHelp(ledUsableHosts,      hipTopRight,    'Help.NetworkForm.ledUsableHosts');
    RegisterHelp(ledNetmask,          hipTopRight,    'Help.NetworkForm.ledNetmask');
    RegisterHelp(ledWildcardMask,     hipTopRight,    'Help.NetworkForm.ledWildcardMask');
    RegisterHelp(ledNetworkType,      hipTopRight,    'Help.NetworkForm.ledNetworkType');
    RegisterHelp(ledBinaryView,       hipTopRight,    'Help.NetworkForm.ledBinaryView');
    RegisterHelp(lvVLSM,              hipBottomRight, 'Help.NetworkForm.lvVLSM', hkCustomForm, 0, 0);
end;

procedure TNetworkForm.lvVLSMKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if (Key = Ord('C')) and (ssCtrl in Shift) then
    begin
        CopyVLSMToClipboard(lvVLSM.SelCount > 0);
        Key := 0;
    end;
end;

procedure TNetworkForm.lvVLSMResize(Sender: TObject);
begin
    ResizeVLSMColumns;
end;

procedure TNetworkForm.tmrEraseStatusBarTimer(Sender: TObject);
begin
    // Вызывается по истечении таймера - очищаем статус-бар
    tmrEraseStatusBar.Enabled := False;
    if (sbBottom.SimpleText = FLastStatusBarText) then
    begin
        FLastStatusBarText  := '';
        sbBottom.SimpleText := '';
    end;
end;

procedure TNetworkForm.OnAutoSaveTimerTick(Sender: TObject);
begin
    FAutoSaveTimer.Enabled := False;
    SaveToHistory;
end;

procedure TNetworkForm.pcMainChange(Sender: TObject);
begin
    // Пересчитываем сети только в момент перехода на вкладку VLSM
    if pcMain.ActivePage = tsVLSM then
        UpdateCalculations;
end;

procedure TNetworkForm.SaveToHistory;
var
    InputText, OldText: string;
    Idx, OldStart, OldLen: Integer;
    DummyIP: Cardinal;
    DummyMask: Byte;
begin
    InputText := Trim(cbIPInput.Text);

    if (InputText = '') or not TIPv4Network.TryParseInput(InputText, seMask.Value, DummyIP, DummyMask) then
        Exit;

    Idx := cbIPInput.Items.IndexOf(InputText);
    if Idx = 0 then Exit;

    OldText := cbIPInput.Text;
    OldStart := cbIPInput.SelStart;
    OldLen := cbIPInput.SelLength;

    if Idx > 0 then
        cbIPInput.Items.Delete(Idx);

    cbIPInput.Items.Insert(0, InputText);

    while cbIPInput.Items.Count > 10 do
        cbIPInput.Items.Delete(cbIPInput.Items.Count - 1);

    SessionIPHistory.Assign(cbIPInput.Items);

    if cbIPInput.Text <> OldText then
        cbIPInput.Text := OldText;

    cbIPInput.SelStart := OldStart;
    cbIPInput.SelLength := OldLen;
end;

procedure TNetworkForm.UpdateVLSM(Net: TIPv4Network);
var
    TargetMask: Byte;
    SubnetCount: UInt64;
    BlockSize, CurrentIP: Cardinal;
    I: Integer;
    Subnet: TIPv4Network;
    LI: TListItem;
begin
    TargetMask := seVLSM.Value;

    if TargetMask <= Net.MaskBits then
    begin
        lvVLSM.Items.Clear;
        lbVLSMHostCount.Caption := '';
        Exit;
    end;

    SubnetCount := UInt64(1) shl (TargetMask - Net.MaskBits);

    Subnet := TIPv4Network.Create(TIPv4Network.IPToStr(Net.Network), TargetMask);
    lbVLSMHostCount.Caption := TUIStateLoader.GetMessage('NetworkForm.HostsPerSubnet', [Subnet.HostsCount]);

    if SubnetCount > 4096 then
    begin
        lvVLSM.Items.BeginUpdate;
        try
            lvVLSM.Items.Clear;

            LI := lvVLSM.Items.Add;
            LI.Caption := '❌';
            LI.SubItems.Add(TUIStateLoader.GetMessage('Common.Error'));
            LI.SubItems.Add(TUIStateLoader.GetMessage('NetworkForm.TooManySubnets'));
            LI.SubItems.Add(Format('> %d', [SubnetCount]));
        finally
            lvVLSM.Items.EndUpdate;
        end;
        ResizeVLSMColumns;
        Exit;
    end;

    if TargetMask = 32 then
        BlockSize := 1
    else
        BlockSize := Cardinal(1) shl (32 - TargetMask);

    lvVLSM.Items.BeginUpdate;
    try
        lvVLSM.Items.Clear;
        CurrentIP := Net.Network;

        for I := 0 to SubnetCount - 1 do
        begin
            Subnet := TIPv4Network.Create(TIPv4Network.IPToStr(CurrentIP), TargetMask);

            LI := lvVLSM.Items.Add;
            LI.Caption := IntToStr(I + 1);
            LI.SubItems.Add(TIPv4Network.IPToStr(Subnet.Network) + '/' + IntToStr(TargetMask));

            if Subnet.HostsCount > 0 then
                LI.SubItems.Add(Format('%s - %s', [TIPv4Network.IPToStr(Subnet.FirstHost), TIPv4Network.IPToStr(Subnet.LastHost)]))
            else
                LI.SubItems.Add('N/A');

            LI.SubItems.Add(TIPv4Network.IPToStr(Subnet.Broadcast));

            if I < SubnetCount - 1 then
                CurrentIP := CurrentIP + BlockSize;
        end;
    finally
        lvVLSM.Items.EndUpdate;
    end;

    ResizeVLSMColumns;
end;

procedure TNetworkForm.UpdateCalculations;
var
    Net: TIPv4Network;
    InputText: string;
    ParsedIP: Cardinal;
    ParsedMask: Byte;
    IsValid: Boolean;
begin
    InputText := Trim(cbIPInput.Text);

    if InputText = '' then
    begin
        cbIPInput.Font.Color := GetDefaultTextColor;
        ClearFields;
        ShowStatusMessage(''); // Очищаем статус-бар
        if Assigned(FAutoSaveTimer) then
            FAutoSaveTimer.Enabled := False;
        Exit;
    end;

    IsValid := TIPv4Network.TryParseInput(InputText, seMask.Value, ParsedIP, ParsedMask);

    if not IsValid then
    begin
        cbIPInput.Font.Color := RGB(255, 128, 0);
        ClearFields;

        // Выводим сообщение об ошибке через новую функцию
        ShowStatusMessage(TUIStateLoader.GetMessage('NetworkForm.InvalidFormat'));

        if Assigned(FAutoSaveTimer) then
            FAutoSaveTimer.Enabled := False;
        Exit;
    end;

    ShowStatusMessage(''); // Очищаем статус-бар
    cbIPInput.Font.Color := GetDefaultTextColor;

    Net := TIPv4Network.Create(ParsedIP, ParsedMask);

    if seMask.Value <> Net.MaskBits then
    begin
        seMask.OnChange := nil;
        try
            seMask.Value := Net.MaskBits;
        finally
            seMask.OnChange := seMaskChange;
        end;
    end;

    ledNetworkAddress.Text   := TIPv4Network.IPToStr(Net.Network);
    ledBroadcastAddress.Text := TIPv4Network.IPToStr(Net.Broadcast);
    ledNetmask.Text          := TIPv4Network.IPToStr(Net.Netmask);
    ledWildcardMask.Text     := TIPv4Network.IPToStr(Net.Wildcard);
    ledUsableHosts.Text      := Net.HostsCount.ToString;
    ledNetworkType.Text      := GetNetworkTypeName(Net.GetNetworkType);
    ledBinaryView.Text       := TIPv4Network.ToBinaryStr(Net.IP, Net.MaskBits);

    if Net.HostsCount > 0 then
        ledHostRange.Text := Format('%s - %s', [TIPv4Network.IPToStr(Net.FirstHost), TIPv4Network.IPToStr(Net.LastHost)])
    else
        ledHostRange.Text := 'N/A';

    if pcMain.ActivePage = tsVLSM then
        UpdateVLSM(Net);

    if Assigned(FAutoSaveTimer) then
    begin
        FAutoSaveTimer.Enabled := False;
        FAutoSaveTimer.Enabled := True;
    end;
end;

procedure TNetworkForm.ResizeVLSMColumns;
var
    TotalClientWidth, FixedWidthSum, RangeWidth: Integer;
begin
    if (lvVLSM.Columns.Count < 4) or not lvVLSM.HandleAllocated then Exit;

    lvVLSM.Items.BeginUpdate;
    try
        lvVLSM.Columns[0].Width := 38;
        lvVLSM.Columns[1].Width := 125;
        lvVLSM.Columns[3].Width := 115;

        TotalClientWidth := lvVLSM.ClientWidth;

        FixedWidthSum := lvVLSM.Columns[0].Width +
                         lvVLSM.Columns[1].Width +
                         lvVLSM.Columns[3].Width;

        RangeWidth := TotalClientWidth - FixedWidthSum;

        if RangeWidth < 150 then
            RangeWidth := 150;

        lvVLSM.Columns[2].Width := RangeWidth;
    finally
        lvVLSM.Items.EndUpdate;
    end;
end;

initialization
    SessionIPHistory := TStringList.Create;
finalization
    SessionIPHistory.Free;
end.
