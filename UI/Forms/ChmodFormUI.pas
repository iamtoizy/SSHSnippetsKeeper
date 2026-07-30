unit ChmodFormUI;

interface

uses
    BaseFormUI,
    ChmodService,
    Core.Interfaces,
    System.Classes,
    System.Generics.Collections,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.StdCtrls, Vcl.Mask, Vcl.ExtCtrls
    ;

type
    TChmodForm = class(TBaseForm)
        gbOwner: TGroupBox;
        cbUr: TCheckBox;
        cbUw: TCheckBox;
        cbUx: TCheckBox;
        gbGroup: TGroupBox;
        cbGr: TCheckBox;
        cbGw: TCheckBox;
        cbGx: TCheckBox;
        gbPublic: TGroupBox;
        cbOr: TCheckBox;
        cbOw: TCheckBox;
        cbOx: TCheckBox;
        gbSpecialBits: TGroupBox;
        cbSuid: TCheckBox;
        cbSgid: TCheckBox;
        cbSticky: TCheckBox;
        gbCommand: TGroupBox;
        ebOctal: TLabeledEdit;
        ebSymbolic: TLabeledEdit;
        ebCommand: TLabeledEdit;
        bCopyCommand: TButton;
        cbIsDir: TCheckBox;
        cbRecursive: TCheckBox;
        cbUser: TComboBox;
        cbGroup: TComboBox;
        cbFileName: TComboBox;
        lbUser: TLabel;
        lbGroup: TLabel;
        lbFilename: TLabel;
        cbPresets: TComboBox;
        bSavePreset: TButton;
        bDeletePreset: TButton;
        lbPresets: TLabel;
        cbSudo: TCheckBox;
        cbSmartExecute: TCheckBox;
        cbSeparateMode: TCheckBox;
        procedure FormDestroy(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure OnCheckboxChange(Sender: TObject);
        procedure edOctalChange(Sender: TObject);
        procedure edOctalExit(Sender: TObject);
        procedure edSymbolicChange(Sender: TObject);
        procedure edSymbolicExit(Sender: TObject);
        procedure cbPresetsChange(Sender: TObject);
        procedure bSavePresetClick(Sender: TObject);
        procedure bDeletePresetClick(Sender: TObject);
        procedure bCopyCommandClick(Sender: TObject);
        procedure cbRecursiveClick(Sender: TObject);
        procedure cbSeparateModeClick(Sender: TObject);
        procedure cbSmartExecuteClick(Sender: TObject);
        procedure OnChownOrFlagChange(Sender: TObject);
    private
        type
            TPresetData = class
                FOctalBits: Integer;
                FIsDir: Boolean;
                FIsCustom: Boolean;       // Можно ли его удалять
                FOriginalName: string;    // Точное имя для поиска при удалении
                constructor Create(Octal: Integer; IsDir, IsCustom: Boolean; const Name: string = '');
            end;
    private
        FUpdatingUI: Boolean;
        FCheckboxes: array[0..11] of TCheckBox;
        FPresetDataList: TObjectList<TPresetData>;

        procedure LoadPresetsToComboBox;
        function GetBitsFromUI: TChmodBits;
        procedure SetBitsToUI(const Bits: TChmodBits);
        procedure UpdateOutputs(const Bits: TChmodBits);
        procedure LoadHistoryToUI;
    public
        procedure DoInitialize; override;
    end;

implementation

uses
    CommonHelpers,
    System.SysUtils,
    UI.HoverHelpManager,
    UI.StateLoader,
    Vcl.Clipbrd,
    Vcl.Dialogs,
    Winapi.Windows
    ;

{$R *.dfm}

{ TPresetData }
constructor TChmodForm.TPresetData.Create(Octal: Integer; IsDir, IsCustom: Boolean; const Name: string);
begin
    FOctalBits := Octal;
    FIsDir := IsDir;
    FIsCustom := IsCustom;
    FOriginalName := Name;
end;

procedure TChmodForm.FormDestroy(Sender: TObject);
begin
    FPresetDataList.Free;
end;

{ TChmodForm }

procedure TChmodForm.FormCreate(Sender: TObject);
var
    I: Integer;
begin
    inherited;

    FPresetDataList := TObjectList<TPresetData>.Create(True);

    FCheckboxes[TChmodService.BIT_O_X] := cbOx;
    FCheckboxes[TChmodService.BIT_O_W] := cbOw;
    FCheckboxes[TChmodService.BIT_O_R] := cbOr;
    FCheckboxes[TChmodService.BIT_G_X] := cbGx;
    FCheckboxes[TChmodService.BIT_G_W] := cbGw;
    FCheckboxes[TChmodService.BIT_G_R] := cbGr;
    FCheckboxes[TChmodService.BIT_U_X] := cbUx;
    FCheckboxes[TChmodService.BIT_U_W] := cbUw;
    FCheckboxes[TChmodService.BIT_U_R] := cbUr;
    FCheckboxes[TChmodService.BIT_STICKY] := cbSticky;
    FCheckboxes[TChmodService.BIT_SGID] := cbSgid;
    FCheckboxes[TChmodService.BIT_SUID] := cbSuid;

    for I := Low(FCheckboxes) to High(FCheckboxes) do
    begin
        if Assigned(FCheckboxes[I]) then
            FCheckboxes[I].OnClick := OnCheckboxChange;
    end;

    ebOctal.OnChange := edOctalChange;
    ebOctal.OnExit   := edOctalExit;
    ebSymbolic.OnChange := edSymbolicChange;
    ebSymbolic.OnExit   := edSymbolicExit;

    cbUser.OnChange := OnChownOrFlagChange;
    cbGroup.OnChange := OnChownOrFlagChange;
    cbFileName.OnChange := OnChownOrFlagChange;
    cbIsDir.OnClick := OnChownOrFlagChange;
    cbRecursive.OnClick := OnChownOrFlagChange;

    bCopyCommand.OnClick := bCopyCommandClick;
    cbPresets.OnChange := cbPresetsChange;

    bSavePreset.OnClick := bSavePresetClick;
    if Assigned(bDeletePreset) then
        bDeletePreset.OnClick := bDeletePresetClick;

    SetBitsToUI(TChmodService.OctalToBits('0644'));
end;

// =========================================================================
// Загрузка пресетов
// =========================================================================
procedure TChmodForm.LoadPresetsToComboBox;
var
    Setts: TAppSettings;
    UserPreset: TChmodPreset;

    procedure AddPreset(const ADisplayName: string; AOctal: Integer; AIsDir, AIsCustom: Boolean; const AOriginalName: string = '');
    var
        Data: TPresetData;
    begin
        Data := TPresetData.Create(AOctal, AIsDir, AIsCustom, AOriginalName);
        FPresetDataList.Add(Data);
        cbPresets.Items.AddObject(ADisplayName, Data);
    end;

begin
    FPresetDataList.Clear;
    cbPresets.Items.BeginUpdate;
    try
        cbPresets.Items.Clear;

        // 1. Стандартные пресеты (Захардкожены, IsCustom = False)
        AddPreset(TUIStateLoader.GetMessage('ChmodForm.Presets-WebDir'),        755, True,  False);
        AddPreset(TUIStateLoader.GetMessage('ChmodForm.Presets-WebFile'),       644, False, False);
        AddPreset(TUIStateLoader.GetMessage('ChmodForm.Presets-SshDir'),        700, True,  False);
        AddPreset(TUIStateLoader.GetMessage('ChmodForm.Presets-SshPrivateKey'), 600, False, False);
        AddPreset(TUIStateLoader.GetMessage('ChmodForm.Presets-SshPublicKey'),  644, False, False);
        AddPreset(TUIStateLoader.GetMessage('ChmodForm.Presets-Script'),        755, False, False);

        // 2. Пользовательские пресеты из настроек (IsCustom = True)
        Setts := AppContext.SettingsManager.Data;
        if Length(Setts.ChmodPresets) > 0 then
        begin
            cbPresets.Items.AddObject(TUIStateLoader.GetMessage('ChmodForm.Presets-Divider'), nil);

            for UserPreset in Setts.ChmodPresets do
            begin
                AddPreset(
                    Format('%s (%d)', [UserPreset.Name, UserPreset.OctalBits]),
                    UserPreset.OctalBits,
                    UserPreset.IsDir,
                    True, // Это кастомный пресет!
                    UserPreset.Name
                );
            end;
        end;

        cbPresets.ItemIndex := -1;
    finally
        cbPresets.Items.EndUpdate;
    end;
end;

procedure TChmodForm.cbPresetsChange(Sender: TObject);
var
    Data: TPresetData;
begin
    if cbPresets.ItemIndex < 0 then Exit;

    Data := TPresetData(cbPresets.Items.Objects[cbPresets.ItemIndex]);
    if not Assigned(Data) then Exit; // Кликнули по разделителю

    // Отключаем обновление пресетов на момент установки UI
    FUpdatingUI := True;
    try
        cbIsDir.Checked := Data.FIsDir;
    finally
        FUpdatingUI := False;
    end;

    SetBitsToUI(TChmodService.OctalToBits(IntToStr(Data.FOctalBits)));

    // Обновляем состояние кнопки "Удалить" в зависимости от того, кастомный ли пресет
    if Assigned(bDeletePreset) then
        bDeletePreset.Enabled := Data.FIsCustom;
end;

// =========================================================================
// Сохранение и Удаление пресетов
// =========================================================================
procedure TChmodForm.bSavePresetClick(Sender: TObject);
var
    PresetName: string;
    Setts: TAppSettings;
    NewPreset: TChmodPreset;
begin
    PresetName := '';

    if MessagesHandler.AskInput(
        TUIStateLoader.GetMessage('ChmodForm.InputQueryTitle'),
        TUIStateLoader.GetMessage('ChmodForm.InputQueryPrompt'),
        PresetName
    ) then
    begin
        PresetName := PresetName.Trim;
        if PresetName = '' then Exit;

        NewPreset.Name := PresetName;
        NewPreset.OctalBits := StrToIntDef(ebOctal.Text, 0);
        NewPreset.IsDir := cbIsDir.Checked;

        Setts := AppContext.SettingsManager.Data;
        SetLength(Setts.ChmodPresets, Length(Setts.ChmodPresets) + 1);
        Setts.ChmodPresets[High(Setts.ChmodPresets)] := NewPreset;

        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;

        LoadPresetsToComboBox;
        ShowSimpleToast(TUIStateLoader.GetMessage('ChmodForm.PresetSaved'));
    end;
end;

procedure TChmodForm.bDeletePresetClick(Sender: TObject);
var
    Data: TPresetData;
    Setts: TAppSettings;
    I, IndexToRemove: Integer;
begin
    if cbPresets.ItemIndex < 0 then Exit;

    Data := TPresetData(cbPresets.Items.Objects[cbPresets.ItemIndex]);
    if not Assigned(Data) or not Data.FIsCustom then Exit;

    if not MessagesHandler.AskConfirmation(
        Format(TUIStateLoader.GetMessage('ChmodForm.DeleteConfirmFormat'), [Data.FOriginalName]),
        TUIStateLoader.GetMessage('ChmodForm.DeleteTitle')) then
        Exit;

    Setts := AppContext.SettingsManager.Data;
    IndexToRemove := -1;

    // Ищем пресет по оригинальному имени
    for I := Low(Setts.ChmodPresets) to High(Setts.ChmodPresets) do
    begin
        if Setts.ChmodPresets[I].Name = Data.FOriginalName then
        begin
            IndexToRemove := I;
            Break;
        end;
    end;

    // Удаляем из массива
    if IndexToRemove >= 0 then
    begin
        Delete(Setts.ChmodPresets, IndexToRemove, 1); // Стандартная функция Delphi для динамических массивов
        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;

        LoadPresetsToComboBox;
        if Assigned(bDeletePreset) then bDeletePreset.Enabled := False;
    end;
end;

// =========================================================================
// Синхронизация UI
// =========================================================================

function TChmodForm.GetBitsFromUI: TChmodBits;
var
    I: Integer;
begin
    Result := [];
    for I := Low(FCheckboxes) to High(FCheckboxes) do
        if Assigned(FCheckboxes[I]) and FCheckboxes[I].Checked then
            Include(Result, I);
end;

procedure TChmodForm.SetBitsToUI(const Bits: TChmodBits);
var
    I: Integer;
begin
    if FUpdatingUI then Exit;

    FUpdatingUI := True;
    try
        for I := Low(FCheckboxes) to High(FCheckboxes) do
            if Assigned(FCheckboxes[I]) then
                FCheckboxes[I].Checked := (I in Bits);
    finally
        FUpdatingUI := False;
    end;

    UpdateOutputs(Bits);
end;

procedure TChmodForm.UpdateOutputs(const Bits: TChmodBits);
var
    OctalStr, SymStr, CmdStr: string;
begin
    if FUpdatingUI then Exit;

    FUpdatingUI := True;
    try
        OctalStr := TChmodService.BitsToOctal(Bits);
        SymStr := TChmodService.BitsToSymbolic(Bits, cbIsDir.Checked);

        CmdStr := TChmodService.BuildCommand(
            OctalStr,
            cbUser.Text,
            cbGroup.Text,
            cbFileName.Text,
            cbIsDir.Checked,
            cbRecursive.Checked,
            cbSudo.Checked,         // Sudo
            cbSmartExecute.Checked, // Smart X
            cbSeparateMode.Checked  // Separate Mode
        );

        if not ebOctal.Focused and (ebOctal.Text <> OctalStr) then
            ebOctal.Text := OctalStr;

        if not ebSymbolic.Focused and (ebSymbolic.Text <> SymStr) then
            ebSymbolic.Text := SymStr;

        ebCommand.Text := CmdStr;
    finally
        FUpdatingUI := False;
    end;
end;

// При любом ручном изменении сбрасываем выбор пресета
procedure TChmodForm.OnCheckboxChange(Sender: TObject);
begin
    if not FUpdatingUI then
    begin
        cbPresets.ItemIndex := -1; // Сброс визуального отображения пресета
        if Assigned(bDeletePreset) then bDeletePreset.Enabled := False;
        UpdateOutputs(GetBitsFromUI());
    end;
end;

procedure TChmodForm.edOctalChange(Sender: TObject);
begin
    if FUpdatingUI then Exit;
    cbPresets.ItemIndex := -1;
    if Assigned(bDeletePreset) then bDeletePreset.Enabled := False;
    SetBitsToUI(TChmodService.OctalToBits(ebOctal.Text));
end;

procedure TChmodForm.edOctalExit(Sender: TObject);
begin
    if not FUpdatingUI then
        ebOctal.Text := TChmodService.BitsToOctal(GetBitsFromUI());
end;

procedure TChmodForm.edSymbolicChange(Sender: TObject);
var
    SymStr: string;
begin
    if FUpdatingUI then Exit;

    SymStr := Trim(ebSymbolic.Text);

    // Синхронизация галочки "Это директория" по первому символу
    if SymStr <> '' then
    begin
        // Блокируем FUpdatingUI, чтобы изменение галочки не вызвало цепную реакцию
        FUpdatingUI := True;
        try
            cbIsDir.Checked := SameText(SymStr[1], 'd');
        finally
            FUpdatingUI := False;
        end;
    end;

    // Сбрасываем пользовательские пресеты
    cbPresets.ItemIndex := -1;
    if Assigned(bDeletePreset) then
        bDeletePreset.Enabled := False;

    // Обновляем матрицу чекбоксов
    SetBitsToUI(TChmodService.SymbolicToBits(SymStr));
end;

procedure TChmodForm.edSymbolicExit(Sender: TObject);
begin
    if not FUpdatingUI then
        ebSymbolic.Text := TChmodService.BitsToSymbolic(GetBitsFromUI(), cbIsDir.Checked);
end;

procedure TChmodForm.OnChownOrFlagChange(Sender: TObject);
begin
    if not FUpdatingUI then
    begin
        cbPresets.ItemIndex := -1;
        if Assigned(bDeletePreset) then bDeletePreset.Enabled := False;
        UpdateOutputs(GetBitsFromUI());
    end;
end;

procedure TChmodForm.bCopyCommandClick(Sender: TObject);
var
    Setts: TAppSettings;
begin
    if ebCommand.Text <> '' then
    begin
        // 1. Копируем в буфер
        Clipboard.AsText := ebCommand.Text;
//        MessagesHandler.ShowInfo(TUIStateLoader.GetMessage('Common.CopiedToClipboard'));
        ShowSimpleToast(TUIStateLoader.GetMessage('Common.CopiedToClipboard'));
        // 2. Сохраняем "умную" историю (MRU)
        Setts := AppContext.SettingsManager.Data;

        THistoryHelper.Add(Setts.HistoryUsers, cbUser.Text);
        THistoryHelper.Add(Setts.HistoryGroups, cbGroup.Text);
        THistoryHelper.Add(Setts.HistoryFiles, cbFileName.Text);

        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;

        // 3. Сразу обновляем списки в UI, чтобы новые слова появились в выпадающем меню
        LoadHistoryToUI;
    end;
end;

procedure TChmodForm.cbRecursiveClick(Sender: TObject);
begin
    // Если включили "Рекурсивно", то это 100% директория
    if cbRecursive.Checked then
        cbIsDir.Checked := True;

    // Обязательно вызываем общий метод обновления, чтобы перестроилась строка
    OnChownOrFlagChange(Sender);
end;

procedure TChmodForm.cbSeparateModeClick(Sender: TObject);
begin
    if cbSeparateMode.Checked then
    begin
        // Раздельный режим имеет смысл только при рекурсии
        cbRecursive.Checked := True;
        cbIsDir.Checked := True;
        // Умный X и Раздельный режим несовместимы
        cbSmartExecute.Checked := False;
    end;
    OnChownOrFlagChange(Sender);
end;

procedure TChmodForm.cbSmartExecuteClick(Sender: TObject);
begin
    if cbSmartExecute.Checked then
    begin
        // Умный X обычно применяется рекурсивно к директориям
        cbRecursive.Checked := True;
        cbIsDir.Checked := True;
        cbSeparateMode.Checked := False; // Взаимоисключение
    end;
    OnChownOrFlagChange(Sender);
end;

procedure TChmodForm.DoInitialize;
begin
    LoadPresetsToComboBox;

    if Assigned(bDeletePreset) then
        bDeletePreset.Enabled := False;

    RegisterHelp(gbCommand, hipTopRight, 'Help.ChmodForm.gbCommand', hkCustomForm, -2, 10);

    LoadHistoryToUI;
end;

procedure TChmodForm.LoadHistoryToUI;
var
    Setts: TAppSettings;

    procedure FillCB(CB: TComboBox; const Hist: TArray<THistoryItem>);
    var
        Item: THistoryItem;
    begin
        CB.Items.BeginUpdate;
        try
            CB.Items.Clear;
            for Item in Hist do
                // Добавляем только само значение, без веса в скобках!
                CB.Items.Add(Item.Value);
        finally
            CB.Items.EndUpdate;
        end;
    end;

begin
    Setts := AppContext.SettingsManager.Data;

    FillCB(cbUser, Setts.HistoryUsers);
    FillCB(cbGroup, Setts.HistoryGroups);
    FillCB(cbFileName, Setts.HistoryFiles);
end;

end.
