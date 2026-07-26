unit PasswordGenFormUI;

interface

uses
    Winapi.Windows,
    Winapi.Messages,
    System.SysUtils,
    System.Variants,
    System.Classes,
    Vcl.Graphics,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.Dialogs,
    Vcl.StdCtrls,
    Vcl.Samples.Spin,
    Core.Interfaces,
    PasswordService,
    Vcl.ComCtrls,
    Vcl.Buttons,
    Vcl.ExtCtrls,
    Vcl.Menus,
    BaseFormUI,
    System.Hash;

type
    TPresetState = record
        Length: Integer;
        Unique: Boolean;
    end;

    TPasswordGenForm = class(TBaseForm)
        seLength: TSpinEdit;
        lbLength: TLabel;
        lbEntropy: TLabel;
        lbEntropyValue: TLabel;
        cbPresets: TComboBox;
        lbPresets: TLabel;
        bGenerate: TButton;
        bInsertAndClose: TButton;
        ebPassword: TEdit;
        cbUnique: TCheckBox;
        pcHost: TPageControl;
        tsHistory: TTabSheet;
        tsCustomSettings: TTabSheet;
        lvHistory: TListView;
        cbLowercase: TCheckBox;
        cbUppercase: TCheckBox;
        cbNumbers: TCheckBox;
        cbSymbols: TCheckBox;
        edInclude: TEdit;
        lbInclude: TLabel;
        ldExclude: TLabel;
        edExclude: TEdit;
        bIncludePresets: TSpeedButton;
        bExcludePresets: TSpeedButton;
        pmCharPresets: TPopupMenu;
        tsBulkMode: TTabSheet;
        seBulkCount: TSpinEdit;
        lbBulkCount: TLabel;
        mBulkResult: TMemo;
        bBulkGenerate: TButton;
        pmBulkGeneration: TPopupMenu;
        nCopyToClipboard: TMenuItem;
        nSaveToFile: TMenuItem;
        pbBulkProgress: TProgressBar;
        bExport: TButton;
        SaveDialog: TSaveDialog;

        tmrClipboard: TTimer;
        bClearHistory: TButton;
        sbBottom: TStatusBar;

        procedure bBulkGenerateClick(Sender: TObject);
        procedure FormDestroy(Sender: TObject);
        procedure bClearHistoryClick(Sender: TObject);
        procedure bExcludePresetsClick(Sender: TObject);
        procedure bIncludePresetsClick(Sender: TObject);
        procedure bGenerateClick(Sender: TObject);
        procedure bInsertAndCloseClick(Sender: TObject);

        procedure cbLowercaseClick(Sender: TObject);
        procedure cbNumbersClick(Sender: TObject);
        procedure cbPresetsChange(Sender: TObject);
        procedure cbSymbolsClick(Sender: TObject);
        procedure cbUppercaseClick(Sender: TObject);
        procedure edExcludeChange(Sender: TObject);
        procedure edIncludeChange(Sender: TObject);
        procedure edIncludeKeyPress(Sender: TObject; var Key: Char);
        procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
        procedure FormHide(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure FormShortCut(var Msg: TWMKey; var Handled: Boolean);
        procedure FormShow(Sender: TObject);
        procedure lvHistoryClick(Sender: TObject);
        procedure lvHistoryDblClick(Sender: TObject);
        procedure nCopyToClipboardClick(Sender: TObject);
        procedure pcHostChanging(Sender: TObject; var AllowChange: Boolean);
        procedure sbBottomResize(Sender: TObject);
        procedure seLengthChange(Sender: TObject);
        procedure tmrClipboardTimer(Sender: TObject);
    private
        class var FCurrentInstance: TPasswordGenForm;
        class var FPresetStates: array[TPasswordPreset] of TPresetState;
        class var FStatesInitialized: Boolean;
        FUpdatingUI: Boolean;
        FProgressBar: TProgressBar;
        FinalCleanPassword: string;

        FPasswordService: IPasswordService;
        FSelectedPreset: TPasswordPreset;
        FActiveEditForPresets: TEdit;
        FOldEditWindowProc: TWndMethod;

        FCancellationToken: Boolean;
        FIsGenerating: Boolean;
        FCloseRequested: Boolean;

        // Для KeePass таймера
        FClipboardCountdown: Integer;
        FLastCopiedText: string;

        procedure UpdateEntropyUI;
        procedure SendStringViaInput(const S: string);
        procedure UpdateHistoryUI;
        procedure InitializeUI;
        procedure ResizeHistoryColumns;
        procedure PresetMenuItemClick(Sender: TObject);
        procedure AppendUniqueChars(AEdit: TEdit; const AChars: string);
        procedure SetupPresetsMenu;
        procedure EditWindowProc(var Message: TMessage);
        procedure DoGenerate(BulkGenerate: Boolean = False; BulkCount: Integer = 1; ExportFileName: string = '');
        procedure SetControlsState(Enabled: Boolean);

        procedure StartClipboardTimer(const CopiedText: string);

        function GetCustomSettingsFromUI: TCustomPasswordSettings;
        function BuildCustomDescription(const Settings: TCustomPasswordSettings): string;
        function FindPresetIndex(APreset: TPasswordPreset): Integer;
    protected
        procedure Resize; override;
        procedure CreateParams(var Params: TCreateParams); override;
    public
        class procedure ExecuteGlobal(Owner: TComponent; const PasswordService: IPasswordService; AppContext: IAppContext);
        constructor Create(Owner: TComponent; PasswordService: IPasswordService); reintroduce;
        procedure Initialize(AppContext: IAppContext);
        procedure ApplyLanguage; override;
    end;

var
    PasswordGenForm: TPasswordGenForm;

implementation

uses
    Winapi.CommCtrl,
    System.Types,
    System.UITypes,
    CommonHelpers,
    Vcl.Clipbrd,
    System.Threading,
    System.Math,
    UI.HoverHelpManager,
    UI.StateLoader, Settings;

const
    VISIBLE_SPACE = Char($2423);
    CLIPBOARD_TIMEOUT_MS = 15000; // 15 секунд в стиле KeePass

{$R *.dfm}

// Фоновая очистка в отдельном потоке
procedure ClearClipboardAfterDelay(const TargetText: string; DelayMS: Integer);
var
    ExpectedHash: string;
begin
    if TargetText = '' then Exit;

    // Превращаем пароль в SHA-256 хэш. Сам пароль фоновому потоку не нужен.
    ExpectedHash := THashSHA2.GetHashString(TargetText);

    TTask.Run(procedure
    begin
        Sleep(DelayMS);

        // Обращение к буферу обмена должно быть строго в главном потоке (Queue)
        TThread.Queue(nil, procedure
        var
            CurrentClipText: string;
        begin
            try
                CurrentClipText := Vcl.Clipbrd.Clipboard.AsText;

                // Сравниваем ХЭШИ, а не открытые строки
                if THashSHA2.GetHashString(CurrentClipText) = ExpectedHash then
                begin
                    Vcl.Clipbrd.Clipboard.AsText := ' ';
                    Vcl.Clipbrd.Clipboard.Clear;
                end;
            finally
                // Безопасно уничтожаем прочитанный из буфера текст
                WipeString(CurrentClipText);
            end;
        end);
    end);
end;

procedure TPasswordGenForm.StartClipboardTimer(const CopiedText: string);
begin
    FLastCopiedText := CopiedText;
    FClipboardCountdown := CLIPBOARD_TIMEOUT_MS div 100;

    FProgressBar.Max := FClipboardCountdown;
    FProgressBar.Position := FClipboardCountdown;
    FProgressBar.Visible := True;

    tmrClipboard.Interval := 100;
    tmrClipboard.Enabled := True;
end;

procedure TPasswordGenForm.tmrClipboardTimer(Sender: TObject);
begin
    Dec(FClipboardCountdown);
    FProgressBar.Position := FClipboardCountdown;

    if FClipboardCountdown <= 0 then
    begin
        tmrClipboard.Enabled := False;
        FProgressBar.Visible := False;

        try
            ClearClipboardAfterDelay(FLastCopiedText, 0);
        except end;

        // Безопасно удаляем пароль с экрана
        WipeVCLControlText(ebPassword);
        ShowSimpleToast(TUIStateLoader.GetMessage('ClipboardCleared.MemoryCleared'));
    end;
end;

procedure TPasswordGenForm.EditWindowProc(var Message: TMessage);
var
    TextToCopy, CleanText: string;
begin
    if Message.Msg = WM_COPY then
    begin
        try
            if ebPassword.SelLength > 0 then
                TextToCopy := ebPassword.SelText
            else
                TextToCopy := ebPassword.Text;

            if TextToCopy <> '' then
            begin
                CleanText := StringReplace(TextToCopy, VISIBLE_SPACE, ' ', [rfReplaceAll]);
                CopyToClipboardSecure(CleanText);
                StartClipboardTimer(CleanText);
                ShowSimpleToast('Пароль скопирован. Буфер будет очищен через 15 сек.');
            end;
        finally
            // БЕЗОПАСНО УНИЧТОЖАЕМ СЛЕДЫ
            WipeString(TextToCopy);
            WipeString(CleanText);
        end;
    end
    else
        FOldEditWindowProc(Message);
end;

procedure TPasswordGenForm.nCopyToClipboardClick(Sender: TObject);
begin
    if mBulkResult.Lines.Count = 0 then
        Exit;

    CopyToClipboardSecure(mBulkResult.Text);

    StartClipboardTimer(mBulkResult.Text);

    ShowSimpleToast(TUIStateLoader.GetMessage('PasswordGenForm.HistoryCopyToast'));
end;

procedure TPasswordGenForm.UpdateEntropyUI;
var
    PoolSize: Integer;
    Entropy: Double;
    Settings: TCustomPasswordSettings;
begin
    if not Assigned(FPasswordService) then Exit;

    if FSelectedPreset = wpCustom then
    begin
        Settings.UseLower := cbLowercase.Checked;
        Settings.UseUpper := cbUppercase.Checked;
        Settings.UseNumbers := cbNumbers.Checked;
        Settings.UseSymbols := cbSymbols.Checked;
        Settings.IncludeChars := StringReplace(edInclude.Text, VISIBLE_SPACE, ' ', [rfReplaceAll]);
        Settings.ExcludeChars := StringReplace(edExclude.Text, VISIBLE_SPACE, ' ', [rfReplaceAll]);
        PoolSize := FPasswordService.GetCustomPoolSize(Settings);
    end
    else
        PoolSize := FPasswordService.GetPoolSize(FSelectedPreset);

    Entropy := FPasswordService.CalculateEntropy(seLength.Value, PoolSize);
    lbEntropyValue.Caption := Format('%.1f bit', [Entropy]);
end;

procedure TPasswordGenForm.UpdateHistoryUI;
var
    History: TArray<TPasswordHistoryItem>;
    Item: TPasswordHistoryItem;
    LI: TListItem;
    VisiblePassword: string;
begin
    if not Assigned(FPasswordService) then Exit;

    lvHistory.Items.BeginUpdate;
    try
        lvHistory.Items.Clear;
        History := FPasswordService.GetHistory;

        for Item in History do
        begin
            LI := lvHistory.Items.Add;
            LI.Caption := FormatDateTime('dd:mm:yyyy', Item.CreatedAt);
            LI.SubItems.Add(FormatDateTime('hh:nn:ss', Item.CreatedAt));

            VisiblePassword := StringReplace(Item.Password, ' ', VISIBLE_SPACE, [rfReplaceAll]);
            LI.SubItems.Add(VisiblePassword);

            LI.SubItems.Add(Item.PresetName);
            LI.SubItems.Add(Format('%.0f bit', [Item.Entropy]));
        end;
    finally
        lvHistory.Items.EndUpdate;
    end;

    ResizeHistoryColumns;
end;

procedure TPasswordGenForm.DoGenerate(BulkGenerate: Boolean = False; BulkCount: Integer = 1; ExportFileName: string = '');
var
    Settings: TCustomPasswordSettings;
    Count: Integer;
begin
    if FSelectedPreset = wpCustom then
        Settings := GetCustomSettingsFromUI();

    if BulkGenerate then Count := BulkCount else Count := 1;

    FIsGenerating := True;
    FCancellationToken := False;
    FCloseRequested := False;

    SetControlsState(False);
    bBulkGenerate.Enabled := True;
    if BulkGenerate then bBulkGenerate.Caption := TUIStateLoader.GetMessage('Common.Cancel');

    pbBulkProgress.Position := 0;
    pbBulkProgress.Max := Count;
    pbBulkProgress.Visible := True;

    TTask.Run(
        procedure
        var
            I, CapturedI: Integer;
            RawPassword: string;
            TempList: TStringList;
            LastUIUpdate: UInt64;
            Writer: TStreamWriter;
            IsDirectToFile: Boolean;
        begin
            IsDirectToFile := (ExportFileName <> '');
            TempList := nil;
            Writer := nil;
            try
                if IsDirectToFile then
                    Writer := TStreamWriter.Create(ExportFileName, False, TEncoding.UTF8)
                else
                    TempList := TStringList.Create;

                LastUIUpdate := TThread.GetTickCount;

                for I := 1 to Count do
                begin
                    if FCancellationToken then Break;

                    if FSelectedPreset = wpCustom then
                        RawPassword := FPasswordService.GenerateCustomPassword(Settings, seLength.Value, cbUnique.Checked)
                    else
                        RawPassword := FPasswordService.GeneratePassword(FSelectedPreset, seLength.Value, cbUnique.Checked);

                    if IsDirectToFile then
                        Writer.WriteLine(RawPassword)
                    else
                    begin
                        if BulkGenerate then
                            TempList.Add(RawPassword)
                        else
                            TempList.Add(StringReplace(RawPassword, ' ', VISIBLE_SPACE, [rfReplaceAll]));
                    end;

                    // Если это была запись в файл, сразу убиваем пароль в RAM.
                    if IsDirectToFile then WipeString(RawPassword);
                    // (Если запись в TempList, мы очистим его позже, в finally)

                    if BulkGenerate and (TThread.GetTickCount - LastUIUpdate > 50) then
                    begin
                        CapturedI := I;
                        LastUIUpdate := TThread.GetTickCount;
                        TThread.Queue(nil, procedure
                        begin
                            if Assigned(pbBulkProgress) and not (csDestroying in pbBulkProgress.ComponentState) then
                                pbBulkProgress.Position := CapturedI;
                        end);
                    end;
                end;

                TThread.Synchronize(nil,
                    procedure
                    var
                        PoolSize: Integer;
                        Entropy: Double;
                    begin
                        pbBulkProgress.Position := Count;

                        if FCancellationToken then
                        begin
                            if BulkGenerate then bBulkGenerate.Enabled := True;
                        end
                        else
                        begin
                            if BulkGenerate then
                            begin
                                if IsDirectToFile then
                                    ShowSimpleToast(TUIStateLoader.GetMessage('PasswordGenForm.BulkSaveSuccessToast'))
                                else
                                begin
                                    mBulkResult.Lines.BeginUpdate;
                                    try mBulkResult.Text := TempList.Text; finally mBulkResult.Lines.EndUpdate; end;
                                end;
                            end
                            else
                            begin
                                ebPassword.Text := TempList[0];

                                if FSelectedPreset = wpCustom then
                                begin
                                    PoolSize := FPasswordService.GetCustomPoolSize(Settings);
                                    Entropy := FPasswordService.CalculateEntropy(seLength.Value, PoolSize);
                                    FPasswordService.AddToHistoryCustom(RawPassword, BuildCustomDescription(Settings), seLength.Value, Entropy);
                                end
                                else
                                    FPasswordService.AddToHistory(RawPassword, FSelectedPreset, seLength.Value);
                            end;
                        end;

                        bBulkGenerate.Caption := TUIStateLoader.GetMessage('PasswordGenForm.MassGenerationCaption');
                        SetControlsState(True);
                        FIsGenerating := False;

                        if not BulkGenerate then pbBulkProgress.Visible := False;

                        if not BulkGenerate then
                        begin
                            pcHost.ActivePageIndex := 0;
                            UpdateHistoryUI;
                        end;

                        if FCloseRequested then Close;
                    end);
            finally
                if Assigned(TempList) then
                begin
                    // Безопасная очистка всего списка паролей
                    for I := 0 to TempList.Count - 1 do
                    begin
                        RawPassword := TempList[I]; // Получаем ссылку
                        WipeString(RawPassword);    // Затираем память
                    end;
                    TempList.Free; // Уничтожаем сам объект списка
                end;
                if Assigned(Writer) then Writer.Free;
            end;
        end);
end;

procedure TPasswordGenForm.AppendUniqueChars(AEdit: TEdit; const AChars: string);
var C: Char;
begin
    if not Assigned(AEdit) then Exit;
    for C in AChars do
        if Pos(C, AEdit.Text) = 0 then AEdit.Text := AEdit.Text + C;
    UpdateEntropyUI;
end;

procedure TPasswordGenForm.bGenerateClick(Sender: TObject);
begin
    DoGenerate;
end;

procedure TPasswordGenForm.bInsertAndCloseClick(Sender: TObject);
begin
    // Сохраняем пароль ДО того, как сработает FormHide и уничтожит данные
    FinalCleanPassword := StringReplace(ebPassword.Text, VISIBLE_SPACE, ' ', [rfReplaceAll]);
    ModalResult := mrOk;
end;

function TPasswordGenForm.BuildCustomDescription(const Settings: TCustomPasswordSettings): string;
begin
    Result := 'Custom (';
    if Settings.UseLower then Result := Result + 'a-z,';
    if Settings.UseUpper then Result := Result + 'A-Z,';
    if Settings.UseNumbers then Result := Result + '0-9,';
    if Settings.UseSymbols then Result := Result + 'spec,';
    if not Settings.IncludeChars.IsEmpty then Result := Result + '+inc,';
    if not Settings.ExcludeChars.IsEmpty then Result := Result + '-exc,';
    if Settings.IncludeChars.Contains(' ') or Settings.ExcludeChars.Contains(' ') then Result := Result + VISIBLE_SPACE + ',';
    if Result.EndsWith(',') then Delete(Result, Result.Length, 1);
    Result := Result + ')';
end;

procedure TPasswordGenForm.cbPresetsChange(Sender: TObject);
var NewPreset: TPasswordPreset;
begin
    if cbPresets.ItemIndex < 0 then Exit;
    NewPreset := TPasswordPreset(Integer(cbPresets.Items.Objects[cbPresets.ItemIndex]));
    if not (FSelectedPreset in [wpMacAddress, wpUUIDv4]) then
    begin
        FPresetStates[FSelectedPreset].Length := seLength.Value;
        FPresetStates[FSelectedPreset].Unique := cbUnique.Checked;
    end;
    FSelectedPreset := NewPreset;

    FUpdatingUI := True;
    try
        seLength.Value := FPresetStates[FSelectedPreset].Length;
        cbUnique.Checked := FPresetStates[FSelectedPreset].Unique;
        seLength.Enabled := not (FSelectedPreset in [wpMacAddress, wpUUIDv4]);
        cbUnique.Enabled := not (FSelectedPreset in [wpMacAddress, wpUUIDv4]);
        if (FSelectedPreset = wpCustom) then
        begin
            pcHost.ActivePageIndex := 1;
            tsCustomSettings.TabVisible := True;
        end
        else
        begin
            pcHost.ActivePageIndex := 0;
            tsCustomSettings.TabVisible := False;
        end;
    finally
        FUpdatingUI := False;
    end;
    UpdateEntropyUI;
end;

constructor TPasswordGenForm.Create(Owner: TComponent; PasswordService: IPasswordService);
begin
    FPasswordService := PasswordService;
    inherited Create(Owner);

    FProgressBar := TProgressBar.Create(sbBottom);
    FProgressBar.Parent := sbBottom;
    FProgressBar.Visible := False;

    InitializeUI;
end;

procedure TPasswordGenForm.FormDestroy(Sender: TObject);
begin
    // Если пользователь скопировал пароль, таймер пошел, но окно было закрыто
    // до истечения 15 секунд - делегируем очистку фоновому потоку
    if tmrClipboard.Enabled then
    begin
        ClearClipboardAfterDelay(FLastCopiedText, FClipboardCountdown * 100);
    end;

    // На всякий случай дублируем вызов скрытия, если форма уничтожается
    // минуя обычный цикл скрытия
    FormHide(Self);

    if Assigned(FProgressBar) then
        FProgressBar.Free;
end;

procedure TPasswordGenForm.CreateParams(var Params: TCreateParams);
begin
    inherited CreateParams(Params);
    if not Assigned(Owner) then Params.WndParent := 0;
end;

procedure TPasswordGenForm.bExcludePresetsClick(Sender: TObject);
var Pt: TPoint;
begin
    FActiveEditForPresets := edExclude;
    Pt := bExcludePresets.ClientToScreen(Point(bExcludePresets.Width, bExcludePresets.Height));
    pmCharPresets.Alignment := paRight;
    pmCharPresets.Popup(Pt.X, Pt.Y);
end;

procedure TPasswordGenForm.bIncludePresetsClick(Sender: TObject);
var Pt: TPoint;
begin
    FActiveEditForPresets := edInclude;
    Pt := bIncludePresets.ClientToScreen(Point(bIncludePresets.Width, bIncludePresets.Height));
    pmCharPresets.Alignment := paRight;
    pmCharPresets.Popup(Pt.X, Pt.Y);
end;

procedure TPasswordGenForm.cbLowercaseClick(Sender: TObject); begin UpdateEntropyUI; end;
procedure TPasswordGenForm.cbNumbersClick(Sender: TObject);   begin UpdateEntropyUI; end;
procedure TPasswordGenForm.cbSymbolsClick(Sender: TObject);   begin UpdateEntropyUI; end;
procedure TPasswordGenForm.cbUppercaseClick(Sender: TObject); begin UpdateEntropyUI; end;
procedure TPasswordGenForm.edExcludeChange(Sender: TObject);  begin UpdateEntropyUI; end;
procedure TPasswordGenForm.edIncludeChange(Sender: TObject);  begin UpdateEntropyUI; end;

procedure TPasswordGenForm.edIncludeKeyPress(Sender: TObject; var Key: Char);
begin
    if Key = ' ' then Key := VISIBLE_SPACE;
end;

procedure TPasswordGenForm.Initialize(AppContext: IAppContext);
begin
    inherited Initialize(AppContext);
    RegisterHelp(lvHistory, hipBottomRight, 'Help.PasswordGenForm.lvHistory', hkCustomForm);
end;

procedure TPasswordGenForm.InitializeUI;
var Preset: TPasswordPreset;
begin
    if not FStatesInitialized then
    begin
        for Preset := Low(TPasswordPreset) to High(TPasswordPreset) do
        begin
            FPresetStates[Preset].Length := 32;
            FPresetStates[Preset].Unique := False;
        end;
        FPresetStates[wpPinCode].Length         := 4;
        FPresetStates[wpActiveDirectory].Length := 12;
        FPresetStates[wpWebStandard].Length     := 16;
        FPresetStates[wpMacAddress].Length      := 17;
        FPresetStates[wpUUIDv4].Length          := 36;
        FStatesInitialized := True;
    end;

    cbPresets.Items.BeginUpdate;
    try
        cbPresets.Clear;
        for Preset := Low(TPasswordPreset) to High(TPasswordPreset) do
            cbPresets.Items.AddObject(FPasswordService.GetPresetDescription(Preset), TObject(Integer(Preset)));
    finally
        cbPresets.Items.EndUpdate;
    end;

    SetupPresetsMenu;

    cbLowercase.Checked := True;
    cbUppercase.Checked := True;
    cbNumbers.Checked := True;
    cbSymbols.Checked := True;

    if Assigned(Owner) then
        bInsertAndClose.Caption := TUIStateLoader.GetMessage('PasswordGenForm.CopyBtn')
    else
        bInsertAndClose.Caption := TUIStateLoader.GetMessage('PasswordGenForm.InsertAndCloseBtn');

    FOldEditWindowProc := ebPassword.WindowProc;
    ebPassword.WindowProc := EditWindowProc;

    pcHost.ActivePage := tsHistory;

    if cbPresets.Items.Count > 0 then
    begin
        cbPresets.ItemIndex := 0;
        FSelectedPreset := TPasswordPreset(Integer(cbPresets.Items.Objects[0]));

        FUpdatingUI := True;
        try
            seLength.Value   := FPresetStates[FSelectedPreset].Length;
            cbUnique.Checked := FPresetStates[FSelectedPreset].Unique;
        finally
            FUpdatingUI := False;
        end;
    end;

    UpdateEntropyUI;
    UpdateHistoryUI;
end;

class procedure TPasswordGenForm.ExecuteGlobal(Owner: TComponent; const PasswordService: IPasswordService; AppContext: IAppContext);
var
    TargetWnd: HWND;
    PasswordToType: string;
begin
    if Assigned(FCurrentInstance) then
    begin
        if FCurrentInstance.WindowState = wsMinimized then FCurrentInstance.WindowState := wsNormal;
        SetForegroundWindow(FCurrentInstance.Handle);
        FCurrentInstance.BringToFront;
        Exit;
    end;

    FCurrentInstance := TPasswordGenForm.Create(Owner, PasswordService);
    try
        FCurrentInstance.Initialize(AppContext);
        TargetWnd := GetForegroundWindow;
        FCurrentInstance.FormStyle := fsStayOnTop;
        SetForegroundWindow(FCurrentInstance.Handle);

        if FCurrentInstance.ShowModal = mrOk then
        begin
            // Извлекаем пароль
            PasswordToType := FCurrentInstance.FinalCleanPassword;

            // Убиваем копию внутри формы
            WipeString(FCurrentInstance.FinalCleanPassword);

            try
                if not Assigned(Owner) then
                begin
                    if (TargetWnd <> 0) and IsWindow(TargetWnd) then
                    begin
                        FCurrentInstance.FormStyle := fsNormal;
                        SetForegroundWindow(TargetWnd);
                        Sleep(100);
                        FCurrentInstance.SendStringViaInput(PasswordToType);
                    end;
                end
                else
                begin
                    if PasswordToType <> '' then
                    begin
                        CopyToClipboardSecure(PasswordToType);
                        // Фоновый поток получит строку, сделает из нее хэш и отпустит
                        ClearClipboardAfterDelay(PasswordToType, CLIPBOARD_TIMEOUT_MS);
                    end;
                end;
            finally
                // Физически убиваем локальную переменную в памяти перед выходом из метода
                WipeString(PasswordToType);
            end;
        end;
    finally
        if Assigned(FCurrentInstance) then FCurrentInstance.FPasswordService := nil;
        FreeAndNil(FCurrentInstance);
    end;
end;

procedure TPasswordGenForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
    if FIsGenerating then
    begin
        CanClose := False;
        FCancellationToken := True;
        FCloseRequested := True;
        Caption := TUIStateLoader.GetMessage('PasswordGenForm.StopGeneratorCaption');
        bBulkGenerate.Enabled := False;
    end
    else CanClose := True;
end;

procedure TPasswordGenForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if Key = VK_F5 then begin bGenerateClick(Self); Key := 0; end;
end;

function TPasswordGenForm.GetCustomSettingsFromUI: TCustomPasswordSettings;
begin
    Result.UseLower     := cbLowercase.Checked;
    Result.UseUpper     := cbUppercase.Checked;
    Result.UseNumbers   := cbNumbers.Checked;
    Result.UseSymbols   := cbSymbols.Checked;
    Result.IncludeChars := StringReplace(edInclude.Text, VISIBLE_SPACE, ' ', [rfReplaceAll]);
    Result.ExcludeChars := StringReplace(edExclude.Text, VISIBLE_SPACE, ' ', [rfReplaceAll]);
end;

procedure TPasswordGenForm.lvHistoryClick(Sender: TObject);
begin
   if Assigned(lvHistory.Selected) and (lvHistory.Selected.SubItems.Count > 1) then
        ebPassword.Text := lvHistory.Selected.SubItems[1];
end;

procedure TPasswordGenForm.lvHistoryDblClick(Sender: TObject);
begin
    if Assigned(lvHistory.Selected) then
    begin
        lvHistoryClick(lvHistory);
        bInsertAndCloseClick(Self);
    end;
end;

procedure TPasswordGenForm.pcHostChanging(Sender: TObject; var AllowChange: Boolean);
begin
    if FIsGenerating then AllowChange := False
end;

procedure TPasswordGenForm.PresetMenuItemClick(Sender: TObject);
var MenuItem: TMenuItem; CharsToAdd: string;
begin
    if not (Sender is TMenuItem) then Exit;
    MenuItem := TMenuItem(Sender);
    CharsToAdd := MenuItem.Hint;
    AppendUniqueChars(FActiveEditForPresets, CharsToAdd);
end;

procedure TPasswordGenForm.Resize;
begin
    inherited;
    ResizeHistoryColumns;
    sbBottomResize(Self); // Принудительно ставим Progressbar на место при ресайзе формы
end;

procedure TPasswordGenForm.ResizeHistoryColumns;
var
    TotalClientWidth, FixedWidthSum, SharedRemainingWidth: Integer;
begin
    if (lvHistory.Columns.Count < 5) or not lvHistory.HandleAllocated then Exit;

    lvHistory.Items.BeginUpdate;
    try
        lvHistory.Columns[0].Width := LVSCW_AUTOSIZE_USEHEADER;
        lvHistory.Columns[1].Width := LVSCW_AUTOSIZE_USEHEADER;
        lvHistory.Columns[4].Width := LVSCW_AUTOSIZE;

        if lvHistory.Columns[4].Width < 70 then lvHistory.Columns[4].Width := 70;

        lvHistory.Columns[0].Width := lvHistory.Columns[0].Width + 2;
        lvHistory.Columns[1].Width := lvHistory.Columns[1].Width + 2;
        lvHistory.Columns[4].Width := lvHistory.Columns[4].Width + 4;

        TotalClientWidth := lvHistory.ClientWidth;
        FixedWidthSum := lvHistory.Columns[0].Width + lvHistory.Columns[1].Width + lvHistory.Columns[4].Width;

        if TotalClientWidth > FixedWidthSum then
        begin
            SharedRemainingWidth := (TotalClientWidth - FixedWidthSum) div 2;
            if SharedRemainingWidth < 90 then
                SharedRemainingWidth := 90;
            lvHistory.Columns[2].Width := SharedRemainingWidth;
            lvHistory.Columns[3].Width := SharedRemainingWidth;
        end;
    finally
        lvHistory.Items.EndUpdate;
    end;
end;

procedure TPasswordGenForm.seLengthChange(Sender: TObject);
begin
    if FUpdatingUI then Exit;
    UpdateEntropyUI;
end;

procedure TPasswordGenForm.SendStringViaInput(const S: string);
var Inputs: array of TInput; I, Index: Integer;
begin
    SetLength(Inputs, Length(S) * 2);
    for I := 1 to Length(S) do
    begin
        Index := (I - 1) * 2;
        Inputs[Index].Itype          := INPUT_KEYBOARD;
        Inputs[Index].ki.wVk         := 0;
        Inputs[Index].ki.wScan       := Ord(S[I]);
        Inputs[Index].ki.dwFlags     := KEYEVENTF_UNICODE;
        Inputs[Index + 1].Itype      := INPUT_KEYBOARD;
        Inputs[Index + 1].ki.wVk     := 0;
        Inputs[Index + 1].ki.wScan   := Ord(S[I]);
        Inputs[Index + 1].ki.dwFlags := KEYEVENTF_UNICODE or KEYEVENTF_KEYUP;
    end;
    if Length(Inputs) > 0 then SendInput(Length(Inputs), Inputs[0], SizeOf(TInput));
end;

procedure TPasswordGenForm.SetControlsState(Enabled: Boolean);
begin
    bGenerate.Enabled := Enabled;
    bBulkGenerate.Enabled := True;
    bInsertAndClose.Enabled := Enabled;
    cbPresets.Enabled := Enabled;
    seLength.Enabled := Enabled;
    bExport.Enabled := Enabled;
    ebPassword.Enabled := Enabled;
    cbUnique.Enabled := Enabled;
    tsHistory.Enabled := Enabled;
    seBulkCount.Enabled := Enabled;
    seLength.Enabled := Enabled and not (FSelectedPreset in [wpMacAddress, wpUUIDv4]);
    cbUnique.Enabled := Enabled and not (FSelectedPreset in [wpMacAddress, wpUUIDv4]);
    cbLowercase.Enabled := Enabled;
    cbUppercase.Enabled := Enabled;
    cbNumbers.Enabled := Enabled;
    cbSymbols.Enabled := Enabled;
    edInclude.Enabled := Enabled;
    edExclude.Enabled := Enabled;
end;

procedure TPasswordGenForm.SetupPresetsMenu;
    procedure AddItem(const ACaption, AChars: string);
    var MI: TMenuItem;
    begin
        MI := TMenuItem.Create(pmCharPresets);
        MI.Caption := ACaption + '  [' + AChars + ']';
        MI.Hint := AChars;
        MI.OnClick := PresetMenuItemClick;
        pmCharPresets.Items.Add(MI);
    end;
begin
    pmCharPresets.Items.Clear;
    AddItem(TUIStateLoader.GetMessage('PasswordGenForm.PresetSimilar'),     'Il1O0');
    AddItem(TUIStateLoader.GetMessage('PasswordGenForm.PresetBrackets'),    '[]{}()');
    AddItem(TUIStateLoader.GetMessage('PasswordGenForm.PresetPunctuation'), '.,:;');
    AddItem(TUIStateLoader.GetMessage('PasswordGenForm.PresetBashSQL'),     '$\`!&|<>');
    AddItem(TUIStateLoader.GetMessage('PasswordGenForm.PresetQuotes'),      '''"');
    AddItem(TUIStateLoader.GetMessage('PasswordGenForm.PresetSpace'),       VISIBLE_SPACE);
    AddItem(TUIStateLoader.GetMessage('PasswordGenForm.PresetURL'),         '&?=#%');
    AddItem(TUIStateLoader.GetMessage('PasswordGenForm.PresetPathJSON'),    '\/');
    AddItem(TUIStateLoader.GetMessage('PasswordGenForm.PresetMath'),        '+-*/%=^~');
end;

function TPasswordGenForm.FindPresetIndex(APreset: TPasswordPreset): Integer;
var I: Integer;
begin
    Result := -1;
    for I := 0 to cbPresets.Items.Count - 1 do
        if TPasswordPreset(Integer(cbPresets.Items.Objects[I])) = APreset then Exit(I);
end;

procedure TPasswordGenForm.FormShortCut(var Msg: TWMKey; var Handled: Boolean);
var ShiftState: TShiftState; TargetIndex: Integer;
begin
    Handled := False;
    ShiftState := KeyDataToShiftState(Msg.KeyData);
    if ShiftState = [ssAlt] then
    begin
        TargetIndex := -1;
        case Msg.CharCode of
            Ord('1'): TargetIndex := FindPresetIndex(wpWebStandard);
            Ord('2'): TargetIndex := FindPresetIndex(wpActiveDirectory);
            Ord('3'): TargetIndex := FindPresetIndex(wpStrictAlphaNumeric);
            Ord('4'): TargetIndex := FindPresetIndex(wpMacAddress);
            Ord('5'): TargetIndex := FindPresetIndex(wpUUIDv4);
            Ord('6'): TargetIndex := FindPresetIndex(wpBase64Key);
            Ord('7'): TargetIndex := FindPresetIndex(wpBashSafe);
            Ord('8'): TargetIndex := FindPresetIndex(wpDockerEnvSafe);
            Ord('9'): TargetIndex := FindPresetIndex(wpBitrixDb);
            Ord('0'): TargetIndex := FindPresetIndex(wpPinCode);
            Ord('C'): TargetIndex := FindPresetIndex(wpCustom);
            Ord('H'): TargetIndex := FindPresetIndex(wpHexToken);
            Ord('U'): TargetIndex := FindPresetIndex(wpUrlSafe);
            Ord('O'): TargetIndex := FindPresetIndex(wpOracleSafe);
        end;
        if TargetIndex >= 0 then
        begin
            cbPresets.ItemIndex := TargetIndex;
            cbPresetsChange(cbPresets);
            Handled := True;
        end;
    end;
end;

procedure TPasswordGenForm.ApplyLanguage;
var Preset: TPasswordPreset;
begin
    inherited;
    cbPresets.Items.BeginUpdate;
    try
        cbPresets.Clear;
        for Preset := Low(TPasswordPreset) to High(TPasswordPreset) do
            cbPresets.Items.AddObject(FPasswordService.GetPresetDescription(Preset), TObject(Integer(Preset)));
        cbPresets.ItemIndex := FindPresetIndex(FSelectedPreset);
    finally
        cbPresets.Items.EndUpdate;
    end;
end;

procedure TPasswordGenForm.bBulkGenerateClick(Sender: TObject);
begin
    if FIsGenerating then
    begin
        FCancellationToken := True;
        bBulkGenerate.Enabled := False;
        Exit;
    end;

    if seBulkCount.Value > 10000 then
    begin
        if FAppContext.ErrorHandler.AskConfirmation(
            TUIStateLoader.GetMessage('PasswordGenForm.BulkLimitWarning'),
            TUIStateLoader.GetMessage('Common.Warning'),
            MB_YESNO or MB_ICONQUESTION
        ) then begin
            SaveDialog.InitialDir := GetDefaultDataDir;
            SaveDialog.FileName := Format('Mass_Passwords_%s.txt', [FormatDateTime('yyyymmdd_hhnn', Now)]);
            SaveDialog.Filter := '(*.txt)|*.txt';

            if SaveDialog.Execute then
            begin
                mBulkResult.Clear;
                mBulkResult.Lines.Add(TUIStateLoader.GetMessage('PasswordGenForm.BulkGenerationToFile'));
                mBulkResult.Lines.Add(SaveDialog.FileName);
                DoGenerate(True, seBulkCount.Value, SaveDialog.FileName);
            end;
        end;
    end
    else
    begin
        WipeVCLControlText(mBulkResult);
        DoGenerate(True, seBulkCount.Value, '');
    end;
end;

procedure TPasswordGenForm.bClearHistoryClick(Sender: TObject);
begin
    if FAppContext.ErrorHandler.AskConfirmation(
        TUIStateLoader.GetMessage('PasswordGenForm.MemoryClearConfirm'),
        TUIStateLoader.GetMessage('Common.Security'),
        MB_YESNO or MB_ICONQUESTION
    ) then
    begin
        // Чистим зашифрованную RAM
        FPasswordService.ClearHistory;
        // Безопасно стираем таблицу с экрана и из памяти
        WipeListViewPasswords(lvHistory);
        // Безопасно чистим поле ввода
        WipeVCLControlText(ebPassword);
        ShowSimpleToast(TUIStateLoader.GetMessage('PasswordGenForm.MemoryCleared'));
    end;
end;

procedure TPasswordGenForm.FormHide(Sender: TObject);
begin
    if not (csDestroying in ComponentState) then
    begin
        // Физически затираем текст в полях ввода VCL
        WipeVCLControlText(ebPassword);
        WipeVCLControlText(mBulkResult);
        WipeListViewPasswords(lvHistory);
    end;

    // Главное: Очищаем сам крипто-буфер истории в сервисе.
    // Поскольку сервис живет дольше формы, мы должны принудительно
    // попросить его забыть пароли при скрытии окна.
    if Assigned(FPasswordService) then
    begin
        FPasswordService.ClearHistory;
        ShowSimpleToast(TUIStateLoader.GetMessage('PasswordGenForm.MemoryCleared'));
    end;
end;

procedure TPasswordGenForm.FormShow(Sender: TObject);
begin
    pcHost.ActivePage := tsHistory;
end;

// =========================================================================
// ИДЕАЛЬНОЕ ВПИСЫВАНИЕ PROGRESSBAR В STATUSBAR БЕЗ МЕРЦАНИЯ
// =========================================================================
procedure TPasswordGenForm.sbBottomResize(Sender: TObject);
var
    R: TRect;
begin
    sbBottom.Panels[0].Width := sbBottom.ClientWidth - sbBottom.Panels[1].Width;

    if Assigned(FProgressBar) then
    begin
        // Спрашиваем у Windows точные координаты 2-й панели (индекс 1)
        SendMessage(sbBottom.Handle, SB_GETRECT, 1, NativeInt(@R));
        InflateRect(R, -1, -1); // Чуть сжимаем, чтобы не перекрывать границы панели
        FProgressBar.BoundsRect := R;
    end;
end;

end.
