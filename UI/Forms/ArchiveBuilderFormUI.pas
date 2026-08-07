unit ArchiveBuilderFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces,
    System.Classes,
    System.Generics.Collections,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.Mask,
    Vcl.Samples.Spin,
    Vcl.StdCtrls
    ;

type
    TArchiveFormat = (afZip, afTarGz, afTarBz2, afTarXz, afTarZst, afTarLz4, af7z);
    TExtractFormat = (efAuto, efZip, efTar, ef7z);

    TArchiveService = class
    public
        class function BuildCompressCommand(
            ArchiveFmt: TArchiveFormat;
            const Source, Dest, ExcludeStr, Password, SplitSize: string;
            MaxCompression, RelativePath, SplitArchive: Boolean
        ): string;

        class function BuildExtractCommand(
            ExtractFmt: TExtractFormat;
            const Source, Dest, Password: string;
            ListOnly: Boolean
        ): string;
    end;

    TArchiveBuilderForm = class(TBaseForm)
        pcMain: TPageControl;
        tsCreate: TTabSheet;
        tsExtract: TTabSheet;
        cbSourcePath: TComboBox;
        cbDestPath: TComboBox;
        mExclude: TMemo;
        cbFormatCreate: TComboBox;
        cbMaxCompression: TCheckBox;
        cbRelativePath: TCheckBox;
        cbSplit: TCheckBox;
        seSplitSize: TSpinEdit;
        ebPassword: TEdit;
        cbPresets: TComboBox;
        bSavePreset: TButton;
        bDeletePreset: TButton;
        lbSourcePath: TLabel;
        lbDestPath: TLabel;
        lbExclude: TLabel;
        lbFormat: TLabel;
        lbPresets: TLabel;
        lbPassword: TLabel;
        cbSourceExtract: TComboBox;
        cbDestExtract: TComboBox;
        cbFormatExtract: TComboBox;
        ebExtPassword: TEdit;
        cbListOnly: TCheckBox;
        lbExtSourcePath: TLabel;
        lbExtDestPath: TLabel;
        lbExtFormat: TLabel;
        lbExtPassword: TLabel;
        pnBottom: TPanel;
        ebCommand: TLabeledEdit;
        bCopyCommand: TButton;

        procedure FormCreate(Sender: TObject);
        procedure FormDestroy(Sender: TObject);
        procedure OnUIChange(Sender: TObject);
        procedure pcMainChange(Sender: TObject);
        procedure bCopyCommandClick(Sender: TObject);
        procedure cbPresetsChange(Sender: TObject);
        procedure bSavePresetClick(Sender: TObject);
        procedure bDeletePresetClick(Sender: TObject);
        procedure cbFormatCreateChange(Sender: TObject);
        procedure cbDestPathChange(Sender: TObject);
        procedure seSplitSizeChange(Sender: TObject);
    private
        type
            TPresetData = class
                FArchiveFormat: TArchiveFormat;
                FExcludeMask: string;
                FMaxComp: Boolean;
                FIsCustom: Boolean;
                FOriginalName: string;
                constructor Create(Fmt: TArchiveFormat; const Excl: string; MaxC, IsCust: Boolean; const Name: string = '');
            end;
    private
        FUpdatingUI: Boolean;
        FPresetDataList: TObjectList<TPresetData>;

        procedure LoadPresetsToComboBox;
        procedure LoadHistoryToUI;
        procedure UpdateCommand;
        procedure UpdatePasswordState;
        procedure ForceFormatExtensionSync;
    public
        procedure DoInitialize; override;
    end;

implementation

uses
    CommonHelpers,
    System.SysUtils,
    UI.HoverHelpManager,
    UI.StateLoader,
    Vcl.Clipbrd
    ;

{$R *.dfm}

{ TArchiveService }

class function TArchiveService.BuildCompressCommand(
    ArchiveFmt: TArchiveFormat;
    const Source, Dest, ExcludeStr, Password, SplitSize: string;
    MaxCompression, RelativePath, SplitArchive: Boolean): string;
var
    Cmd, Src, Dst, Ex: string;
    Excludes: TArray<string>;
    SplitPipe: string;
    SafeSize: Integer;
begin
    // 1. Явная инициализация для защиты от неверного каста Enum из UI
    Cmd := '';
    SplitPipe := '';

    Src := Source.Trim;
    Dst := Dest.Trim;
    if Src = '' then Src := '<source>';
    if Dst = '' then Dst := '<archive>';

    Excludes := ExcludeStr.Trim.Split([#13, #10, ' '], TStringSplitOptions.ExcludeEmpty);

    // 2. Безопасный парсинг размера тома (Fallback)
    SafeSize := StrToIntDef(SplitSize, 2048);
    if SafeSize <= 0 then
        SafeSize := 2048; // Защита от ввода нуля, отрицательных чисел или мусора

    case ArchiveFmt of
        afZip:
            begin
                if RelativePath then Cmd := 'cd ' + Src + ' && zip -r' else Cmd := 'zip -r';

                if MaxCompression then Cmd := Cmd + ' -9';
                if Password <> '' then Cmd := Cmd + ' -P "' + Password + '"';

                // 3. Добавлена поддержка разбивки на тома для ZIP
                if SplitArchive then Cmd := Cmd + ' -s ' + SafeSize.ToString + 'm';

                if RelativePath then Cmd := Cmd + ' ' + Dst + ' .' else Cmd := Cmd + ' ' + Dst + ' ' + Src;

                if Length(Excludes) > 0 then
                begin
                    Cmd := Cmd + ' -x';
                    for Ex in Excludes do Cmd := Cmd + ' "' + Ex + '"';
                end;
            end;

        afTarGz, afTarBz2, afTarXz, afTarZst, afTarLz4: // Семейство TAR
            begin
                if MaxCompression then
                begin
                    case ArchiveFmt of
                        afTarGz:  Cmd := 'env GZIP=-9 ';
                        afTarBz2: Cmd := 'env BZIP2=-9 ';
                        afTarXz:  Cmd := 'env XZ_OPT=-9 ';
                        afTarZst: Cmd := 'env ZSTD_CLEVEL=19 ';
                        afTarLz4: Cmd := 'env LZ4_OPTS="-9" ';
                    end;
                end;

                Cmd := Cmd + 'tar ';
                case ArchiveFmt of
                    afTarGz:  Cmd := Cmd + '-cz';
                    afTarBz2: Cmd := Cmd + '-cj';
                    afTarXz:  Cmd := Cmd + '-cJ';
                    afTarZst: Cmd := Cmd + '-c --zstd';
                    afTarLz4: Cmd := Cmd + '-c -I lz4';
                end;

                // 4. Используем безопасный SafeSize вместо сырой строки SplitSize
                if SplitArchive then
                begin
                    Cmd := Cmd + 'v - ';
                    SplitPipe := ' | split -b ' + SafeSize.ToString + 'M - ' + Dst + '.part_';
                end
                else
                    Cmd := Cmd + 'vf ' + Dst + ' ';

                for Ex in Excludes do Cmd := Cmd + ' --exclude="' + Ex + '"';

                if RelativePath then Cmd := Cmd + ' -C ' + Src + ' .' else Cmd := Cmd + ' ' + Src;

                Cmd := Cmd + SplitPipe;
            end;

        af7z:
            begin
                if RelativePath then Cmd := 'cd ' + Src + ' && 7z a' else Cmd := '7z a';

                if MaxCompression then Cmd := Cmd + ' -mx=9';
                if Password <> '' then Cmd := Cmd + ' -p"' + Password + '"';

                // Используем безопасный SafeSize
                if SplitArchive then Cmd := Cmd + ' -v' + SafeSize.ToString + 'm';

                if RelativePath then Cmd := Cmd + ' ' + Dst + ' .' else Cmd := Cmd + ' ' + Dst + ' ' + Src;

                for Ex in Excludes do Cmd := Cmd + ' -xr!"' + Ex + '"';
            end;
    end;

    Result := Cmd;
end;

class function TArchiveService.BuildExtractCommand(
    ExtractFmt: TExtractFormat;
    const Source, Dest, Password: string; ListOnly: Boolean): string;
var
    Src, Dst, Cmd: string;
    ResolvedFormat: TExtractFormat;
begin
    Cmd := '';
    Src := Source.Trim;
    Dst := Dest.Trim;
    if Src = '' then Src := '<archive>';

    ResolvedFormat := ExtractFmt;

    // Автоопределение по расширению
    if ResolvedFormat = efAuto then
    begin
        if Src.EndsWith('.zip', True) then ResolvedFormat := efZip
        else if Src.EndsWith('.7z', True) then ResolvedFormat := ef7z
        else ResolvedFormat := efTar;
    end;

    case ResolvedFormat of
        efZip:
            begin
                if ListOnly then Cmd := 'unzip -l ' + Src
                else
                begin
                    Cmd := 'unzip ';
                    if Password <> '' then Cmd := Cmd + '-P "' + Password + '" ';
                    Cmd := Cmd + Src;
                    if Dst <> '' then Cmd := Cmd + ' -d ' + Dst;
                end;
            end;
        efTar:
            begin
                if ListOnly then Cmd := 'tar -tvf ' + Src
                else
                begin
                    Cmd := 'tar -xvf ' + Src;
                    if Dst <> '' then Cmd := Cmd + ' -C ' + Dst;
                end;
            end;
        ef7z:
            begin
                if ListOnly then Cmd := '7z l ' + Src
                else
                begin
                    Cmd := '7z x ';
                    if Password <> '' then Cmd := Cmd + '-p"' + Password + '" ';
                    Cmd := Cmd + Src;
                    if Dst <> '' then Cmd := Cmd + ' -o"' + Dst + '"';
                end;
            end;
    end;

    Result := Cmd;
end;

{ TArchiveBuilderForm.TPresetData }

constructor TArchiveBuilderForm.TPresetData.Create(Fmt: TArchiveFormat; const Excl: string; MaxC, IsCust: Boolean; const Name: string);
begin
    FArchiveFormat := Fmt;
    FExcludeMask := Excl;
    FMaxComp := MaxC;
    FIsCustom := IsCust;
    FOriginalName := Name;
end;

{ TArchiveBuilderForm }

procedure TArchiveBuilderForm.FormCreate(Sender: TObject);
begin
    inherited;
    FPresetDataList := TObjectList<TPresetData>.Create(True);
    pcMain.ActivePage := tsCreate;
end;

procedure TArchiveBuilderForm.FormDestroy(Sender: TObject);
begin
    FPresetDataList.Free;
end;

procedure TArchiveBuilderForm.DoInitialize;
var
    Setts: TAppSettings;
begin
    LoadPresetsToComboBox;
    LoadHistoryToUI;

    if Assigned(bDeletePreset) then
        bDeletePreset.Enabled := False;

    // Загрузка сохраненного состояния
    Setts := AppContext.SettingsManager.Data;

    // Блокируем UI, чтобы OnChange у поля ввода не перебил наши настройки
    FUpdatingUI := True;
    try
        // Если ArchiveSplitSize = 0, значит программа запущена впервые
        if Setts.ArchiveSplitSize = 0 then
        begin
            cbRelativePath.Checked := True;
            seSplitSize.Text := '2048';
            cbSplit.Checked := False; // Явно отключаем при первом запуске
            cbFormatCreate.ItemIndex := 1;  // tar.gz
        end
        else
        begin
            cbRelativePath.Checked := Setts.ArchiveRelativePath;
            cbMaxCompression.Checked := Setts.ArchiveMaxCompression;

            // Сначала пишем текст, затем ставим состояние галочки
            seSplitSize.Text := Setts.ArchiveSplitSize.ToString;
            cbSplit.Checked := Setts.ArchiveSplit;

            if (Setts.ArchiveLastFormat >= 0) and (Setts.ArchiveLastFormat < cbFormatCreate.Items.Count) then
                cbFormatCreate.ItemIndex := Setts.ArchiveLastFormat;
        end;
    finally
        FUpdatingUI := False;
    end;

    // Заполнение списка форматов для распаковки
    cbFormatExtract.Items.Add(TUIStateLoader.GetMessage('ArchiveBuilderForm.FormatPresets.AutoDetect'));
    cbFormatExtract.Items.Add(TUIStateLoader.GetMessage('ArchiveBuilderForm.FormatPresets.zip'));
    cbFormatExtract.Items.Add(TUIStateLoader.GetMessage('ArchiveBuilderForm.FormatPresets.tar'));
    cbFormatExtract.Items.Add(TUIStateLoader.GetMessage('ArchiveBuilderForm.FormatPresets.7z'));
    cbFormatExtract.ItemIndex := 0;

    // Синхронизируем UI после загрузки данных
    UpdatePasswordState;
    ForceFormatExtensionSync;
    UpdateCommand;
end;

procedure TArchiveBuilderForm.LoadHistoryToUI;
var
    Setts: TAppSettings;
    procedure FillCB(CB: TComboBox; const Hist: TArray<THistoryItem>);
    var Item: THistoryItem;
    begin
        CB.Items.BeginUpdate;
        try
            CB.Items.Clear;
            for Item in Hist do CB.Items.Add(Item.Value);
        finally
            CB.Items.EndUpdate;
        end;
    end;
begin
    Setts := AppContext.SettingsManager.Data;

    // Вкладка "Создать архив"
    // Что архивируем (путь к директории/файлу) -> берем из истории путей
    FillCB(cbSourcePath, Setts.HistoryArchivePaths);
    // Имя архива (backup.tar.gz) -> берем из истории архивов
    FillCB(cbDestPath, Setts.HistoryArchiveDests);

    // Вкладка "Распаковать"
    // Путь к архиву (backup.tar.gz) -> берем из истории архивов
    FillCB(cbSourceExtract, Setts.HistoryArchiveDests);
    // Куда распаковать (путь к директории) -> берем из истории путей
    FillCB(cbDestExtract, Setts.HistoryArchivePaths);
end;

procedure TArchiveBuilderForm.LoadPresetsToComboBox;
var
    Setts: TAppSettings;
    UserPreset: TArchivePreset;

    procedure AddPreset(const DisplayName: string; Fmt: TArchiveFormat; const Excl: string; Max, IsCust: Boolean; const Orig: string = '');
    var Data: TPresetData;
    begin
        Data := TPresetData.Create(Fmt, Excl, Max, IsCust, Orig);
        FPresetDataList.Add(Data);
        cbPresets.Items.AddObject(DisplayName, Data);
    end;
begin
    FPresetDataList.Clear;
    cbPresets.Items.BeginUpdate;
    try
        cbPresets.Items.Clear;

        // Пресеты
        AddPreset(TUIStateLoader.GetMessage('ArchiveBuilderForm.DefaultPresets.BitrixSite'),
            afTarGz,
            'bitrix/cache/*'#13#10'bitrix/managed_cache/*'#13#10'bitrix/html_pages/*'#13#10'upload/resize_cache/*',
            True,
            False
        );
        AddPreset(TUIStateLoader.GetMessage('ArchiveBuilderForm.DefaultPresets.BitrixCore'),
            afTarGz,
            'upload/*'#13#10'bitrix/backup/*',
            True,
            False
        );
        AddPreset(TUIStateLoader.GetMessage('ArchiveBuilderForm.DefaultPresets.Logs'),
            afTarGz,
            '*.gz',
            True,
            False
        );
        AddPreset(TUIStateLoader.GetMessage('ArchiveBuilderForm.DefaultPresets.FastZstd'),
            afTarZst,
            '',
            False,
            False
        );
        AddPreset(TUIStateLoader.GetMessage('ArchiveBuilderForm.DefaultPresets.NodeJs'),
            afTarGz,
            'node_modules/*'#13#10'.git/*'#13#10'.next/*'#13#10'dist/*',
            True,
            False
        );
        AddPreset(TUIStateLoader.GetMessage('ArchiveBuilderForm.DefaultPresets.Laravel'),
            afTarGz,
            'vendor/*'#13#10'var/cache/*'#13#10'var/log/*'#13#10'.git/*',
            True,
            False
        );
        AddPreset(TUIStateLoader.GetMessage('ArchiveBuilderForm.DefaultPresets.CleanSource'),
            afZip,
            '.git/*'#13#10'.idea/*'#13#10'.vscode/*'#13#10'*.DS_Store',
            True,
            False
        );
        AddPreset(TUIStateLoader.GetMessage('ArchiveBuilderForm.DefaultPresets.SqlDumps'),
            afTarXz,
            '',
            True,
            False
        );

        Setts := AppContext.SettingsManager.Data;
        if Length(Setts.ArchivePresets) > 0 then
        begin
            cbPresets.Items.AddObject(TUIStateLoader.GetMessage('ArchiveBuilderForm.DefaultPresets.CustomDivider'), nil);
            for UserPreset in Setts.ArchivePresets do
            begin
                // Кастуем сохраненный в JSON индекс обратно в Enum
                AddPreset(UserPreset.Name, TArchiveFormat(UserPreset.FormatIndex), UserPreset.ExcludeMask, UserPreset.MaxCompression, True, UserPreset.Name);
            end;
        end;
        cbPresets.ItemIndex := -1;
    finally
        cbPresets.Items.EndUpdate;
    end;
end;

procedure TArchiveBuilderForm.UpdatePasswordState;
var
    CanPassword: Boolean;
begin
    CanPassword := (cbFormatCreate.ItemIndex = 0) or (cbFormatCreate.ItemIndex = 6);

    if not CanPassword then
    begin
        FUpdatingUI := True;
        try
            ebPassword.Text := '';
        finally
            FUpdatingUI := False;
        end;
    end;

    ebPassword.Enabled := CanPassword;
end;

procedure TArchiveBuilderForm.OnUIChange(Sender: TObject);
begin
    if FUpdatingUI then Exit;

    // Сбрасываем пресет, только если UI меняет пользователь
    cbPresets.ItemIndex := -1;
    bDeletePreset.Enabled := False;

    UpdatePasswordState;
    UpdateCommand;
end;

procedure TArchiveBuilderForm.seSplitSizeChange(Sender: TObject);
var
    Sz: Integer;
begin
    if FUpdatingUI then Exit;

    FUpdatingUI := True;
    try
        if TryStrToInt(seSplitSize.Text, Sz) and (Sz > 0) then
            cbSplit.Checked := True
        else
            cbSplit.Checked := False;
    finally
        FUpdatingUI := False;
    end;

    OnUIChange(Sender);
end;

procedure TArchiveBuilderForm.pcMainChange(Sender: TObject);
begin
    UpdateCommand;
end;

procedure TArchiveBuilderForm.UpdateCommand;
begin
    // Защита от пустого результата или сброшенного UI
    if (pcMain.ActivePage = tsCreate) and (cbFormatCreate.ItemIndex < 0) then
    begin
        ebCommand.Text := '';
        Exit;
    end;

    if (pcMain.ActivePage = tsExtract) and (cbFormatExtract.ItemIndex < 0) then
    begin
        ebCommand.Text := '';
        Exit;
    end;

    // Безопасный вызов сервисов
    if pcMain.ActivePage = tsCreate then
        ebCommand.Text := TArchiveService.BuildCompressCommand(
            TArchiveFormat(cbFormatCreate.ItemIndex),
            cbSourcePath.Text, cbDestPath.Text,
            mExclude.Text, ebPassword.Text, seSplitSize.Text,
            cbMaxCompression.Checked, cbRelativePath.Checked, cbSplit.Checked)
    else
        ebCommand.Text := TArchiveService.BuildExtractCommand(
            TExtractFormat(cbFormatExtract.ItemIndex),
            cbSourceExtract.Text, cbDestExtract.Text,
            ebExtPassword.Text, cbListOnly.Checked);
end;

procedure TArchiveBuilderForm.cbPresetsChange(Sender: TObject);
var
    Data: TPresetData;
begin
    if cbPresets.ItemIndex < 0 then Exit;
    Data := TPresetData(cbPresets.Items.Objects[cbPresets.ItemIndex]);
    if not Assigned(Data) then Exit; // Разделитель

    FUpdatingUI := True;
    try
        // Ord() Enum -> порядковый номер (0, 1, 2...)
        cbFormatCreate.ItemIndex := Ord(Data.FArchiveFormat);
        mExclude.Text := Data.FExcludeMask;
        cbMaxCompression.Checked := Data.FMaxComp;

        ForceFormatExtensionSync; // Синхронизируем расширение файла безопасно
    finally
        FUpdatingUI := False;
    end;

    bDeletePreset.Enabled := Data.FIsCustom;
    UpdatePasswordState;
    UpdateCommand;
end;

procedure TArchiveBuilderForm.ForceFormatExtensionSync;
var
    DestName, NewExt: string;
begin
    DestName := string(cbDestPath.Text).Trim;
    if DestName = '' then Exit;

    if DestName.EndsWith('.tar.gz', True) then DestName := DestName.Substring(0, DestName.Length - 7)
    else if DestName.EndsWith('.tar.bz2', True) then DestName := DestName.Substring(0, DestName.Length - 8)
    else if DestName.EndsWith('.tar.xz', True) then DestName := DestName.Substring(0, DestName.Length - 7)
    else if DestName.EndsWith('.tar.zst', True) then DestName := DestName.Substring(0, DestName.Length - 8)
    else if DestName.EndsWith('.tar.lz4', True) then DestName := DestName.Substring(0, DestName.Length - 8)
    else if DestName.EndsWith('.zip', True) then DestName := DestName.Substring(0, DestName.Length - 4)
    else if DestName.EndsWith('.7z', True) then DestName := DestName.Substring(0, DestName.Length - 3)
    else if DestName.EndsWith('.tar', True) then DestName := DestName.Substring(0, DestName.Length - 4);

    case TArchiveFormat(cbFormatCreate.ItemIndex) of
        afZip:    NewExt := '.zip';
        afTarGz:  NewExt := '.tar.gz';
        afTarBz2: NewExt := '.tar.bz2';
        afTarXz:  NewExt := '.tar.xz';
        afTarZst: NewExt := '.tar.zst';
        afTarLz4: NewExt := '.tar.lz4';
        af7z:     NewExt := '.7z';
    else
        NewExt := '';
    end;

    cbDestPath.Text := DestName + NewExt;
end;

procedure TArchiveBuilderForm.cbFormatCreateChange(Sender: TObject);
begin
    if FUpdatingUI then Exit;

    FUpdatingUI := True;
    try
        ForceFormatExtensionSync;
    finally
        FUpdatingUI := False;
    end;

    OnUIChange(Sender);
end;

procedure TArchiveBuilderForm.cbDestPathChange(Sender: TObject);
var
    Dest: string;
    NewFmt: TArchiveFormat;
    HasMatch: Boolean;
begin
    if FUpdatingUI then Exit;

    Dest := string(cbDestPath.Text).Trim.ToLower;
    HasMatch := True;

    // Авто-смена формата при ручном вводе расширения
    if Dest.EndsWith('.zip') then NewFmt := afZip
    else if Dest.EndsWith('.tar.gz') or Dest.EndsWith('.tgz') then NewFmt := afTarGz
    else if Dest.EndsWith('.tar.bz2') or Dest.EndsWith('.tbz2') then NewFmt := afTarBz2
    else if Dest.EndsWith('.tar.xz') or Dest.EndsWith('.txz') then NewFmt := afTarXz
    else if Dest.EndsWith('.tar.zst') then NewFmt := afTarZst
    else if Dest.EndsWith('.tar.lz4') then NewFmt := afTarLz4
    else if Dest.EndsWith('.7z') then NewFmt := af7z
    else begin HasMatch := False; NewFmt := afZip; end;

    if HasMatch and (cbFormatCreate.ItemIndex <> Ord(NewFmt)) then
    begin
        FUpdatingUI := True;
        try
            cbFormatCreate.ItemIndex := Ord(NewFmt);
        finally
            FUpdatingUI := False;
        end;
    end;

    OnUIChange(Sender);
end;

procedure TArchiveBuilderForm.bSavePresetClick(Sender: TObject);
var
    PresetName: string;
    Setts: TAppSettings;
    NewPreset: TArchivePreset;
begin
    if MessagesHandler.AskInput(
        TUIStateLoader.GetMessage('ArchiveBuilder.Messages.SavePresetTitle'),
        TUIStateLoader.GetMessage('ArchiveBuilder.Messages.SavePresetPrompt'),
        PresetName) then
    begin
        PresetName := PresetName.Trim;
        if PresetName = '' then Exit;

        NewPreset.Name := PresetName;
        NewPreset.FormatIndex := cbFormatCreate.ItemIndex;
        NewPreset.ExcludeMask := mExclude.Text;
        NewPreset.MaxCompression := cbMaxCompression.Checked;

        Setts := AppContext.SettingsManager.Data;
        SetLength(Setts.ArchivePresets, Length(Setts.ArchivePresets) + 1);
        Setts.ArchivePresets[High(Setts.ArchivePresets)] := NewPreset;

        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;

        LoadPresetsToComboBox;
        ShowSimpleToast(TUIStateLoader.GetMessage('ArchiveBuilder.Messages.PresetSaved'));
    end;
end;

procedure TArchiveBuilderForm.bDeletePresetClick(Sender: TObject);
var
    Data: TPresetData;
    Setts: TAppSettings;
    I, IndexToRemove: Integer;
begin
    if cbPresets.ItemIndex < 0 then Exit;
    Data := TPresetData(cbPresets.Items.Objects[cbPresets.ItemIndex]);
    if not Assigned(Data) or not Data.FIsCustom then Exit;

    if not MessagesHandler.AskConfirmation(
        Format(TUIStateLoader.GetMessage('ArchiveBuilder.Messages.DeletePresetConfirm'), [Data.FOriginalName]),
        TUIStateLoader.GetMessage('ArchiveBuilder.Messages.DeleteTitle')
    ) then Exit;

    Setts := AppContext.SettingsManager.Data;
    IndexToRemove := -1;
    for I := Low(Setts.ArchivePresets) to High(Setts.ArchivePresets) do
    begin
        if Setts.ArchivePresets[I].Name = Data.FOriginalName then
        begin
            IndexToRemove := I;
            Break;
        end;
    end;

    if IndexToRemove >= 0 then
    begin
        Delete(Setts.ArchivePresets, IndexToRemove, 1);
        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;
        LoadPresetsToComboBox;
        bDeletePreset.Enabled := False;
    end;
end;

procedure TArchiveBuilderForm.bCopyCommandClick(Sender: TObject);
var
    Setts: TAppSettings;
begin
    if ebCommand.Text <> '' then
    begin
        Clipboard.AsText := ebCommand.Text;
        ShowSimpleToast(TUIStateLoader.GetMessage('Common.CopiedToClipboard'));

        Setts := AppContext.SettingsManager.Data;

        if pcMain.ActivePage = tsCreate then
        begin
            THistoryHelper.Add(Setts.HistoryArchivePaths, cbSourcePath.Text); // Сохраняем путь
            THistoryHelper.Add(Setts.HistoryArchiveDests, cbDestPath.Text);   // Сохраняем имя архива

            // Сохраняем состояние галочек
            Setts.ArchiveRelativePath := cbRelativePath.Checked;
            Setts.ArchiveMaxCompression := cbMaxCompression.Checked;
            Setts.ArchiveSplit := cbSplit.Checked;
            Setts.ArchiveSplitSize := StrToIntDef(seSplitSize.Text, 2048);
            Setts.ArchiveLastFormat := cbFormatCreate.ItemIndex;
        end
        else
        begin
            THistoryHelper.Add(Setts.HistoryArchiveDests, cbSourceExtract.Text); // Сохраняем имя архива
            if cbDestExtract.Text <> '' then
                THistoryHelper.Add(Setts.HistoryArchivePaths, cbDestExtract.Text); // Сохраняем путь извлечения
        end;

        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;
        LoadHistoryToUI;
    end;
end;

end.
