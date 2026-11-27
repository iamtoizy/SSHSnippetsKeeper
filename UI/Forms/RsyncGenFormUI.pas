unit RsyncGenFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    Core.Interfaces.Passwords,
    Core.Interfaces.Settings,
    Core.Interfaces.UI,
    System.Classes,
    System.Generics.Collections,
    System.SysUtils,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls
    ;

type
    TRsyncGenForm = class(TBaseForm)
        pnlTop: TPanel;
        lbTitle: TLabel;
        mCommand: TMemo;
        bCopy: TButton;
        cbMultiline: TCheckBox;
        lbValidation: TLabel;
        gbCopyMode: TGroupBox;
        rbLocal: TRadioButton;
        rbPush: TRadioButton;
        rbPull: TRadioButton;
        gbParameters: TGroupBox;
        lbSource: TLabel;
        cbSource: TComboBox;
        lbDest: TLabel;
        cbDest: TComboBox;
        lbUser: TLabel;
        ebUser: TEdit;
        lbHost: TLabel;
        ebHost: TEdit;
        lbPort: TLabel;
        ebSshPort: TEdit;
        lbPresets: TLabel;
        cbPresets: TComboBox;
        bPresetSave: TButton;
        bPresetRename: TButton;
        bPresetDelete: TButton;
        bReset: TButton;
        lbExtra: TLabel;
        ebExtra: TEdit;
        pgcOptions: TPageControl;
        tsMain: TTabSheet;
        tsTransfer: TTabSheet;
        tsDelete: TTabSheet;
        tsFilters: TTabSheet;
        tsPerms: TTabSheet;
        tsSSH: TTabSheet;
        tsLog: TTabSheet;
        tsMisc: TTabSheet;

        // Основное
        cbArchive: TCheckBox;
        cbRecursive: TCheckBox;
        cbLinks: TCheckBox;
        cbPerms: TCheckBox;
        cbTimes: TCheckBox;
        cbGroup: TCheckBox;
        cbOwner: TCheckBox;
        cbDevices: TCheckBox;
        cbSpecials: TCheckBox;
        cbHardLinks: TCheckBox;
        cbAcls: TCheckBox;
        cbXattrs: TCheckBox;
        cbDirs: TCheckBox;
        cbDryRun: TCheckBox;
        cbOmitDirTimes: TCheckBox;

        // Передача
        cbWholeFile: TCheckBox;
        cbChecksum: TCheckBox;
        cbSizeOnly: TCheckBox;
        cbIgnoreTimes: TCheckBox;
        cbModifyWindow: TCheckBox;
        cbAppend: TCheckBox;
        cbAppendVerify: TCheckBox;
        cbUpdate: TCheckBox;
        cbExisting: TCheckBox;
        cbIgnoreExisting: TCheckBox;
        cbBackup: TCheckBox;
        cbBackupDir: TCheckBox;
        cbSuffix: TCheckBox;
        cbRemoveSourceFiles: TCheckBox;
        cbPartial: TCheckBox;

        // Удаление
        cbDelete: TCheckBox;
        cbDeleteBefore: TCheckBox;
        cbDeleteDelay: TCheckBox;
        cbDeleteAfter: TCheckBox;
        cbDeleteExcluded: TCheckBox;
        cbForce: TCheckBox;
        cbIgnoreErrors: TCheckBox;
        cbMaxDelete: TCheckBox;
        cbDelayUpdates: TCheckBox;

        // Фильтры
        cbExclude: TCheckBox;
        mExclude: TMemo;
        cbInclude: TCheckBox;
        mInclude: TMemo;
        cbExcludeFrom: TCheckBox;
        cbIncludeFrom: TCheckBox;
        cbFilter: TCheckBox;
        cbFilesFrom: TCheckBox;
        cbMaxSize: TCheckBox;
        cbMinSize: TCheckBox;
        cbPruneEmptyDirs: TCheckBox;
        cbCvsExclude: TCheckBox;
        cbRelative: TCheckBox;
        cbNoImpliedDirs: TCheckBox;

        // Права и ссылки
        cbChmod: TCheckBox;
        cbNumericIds: TCheckBox;
        cbSuper: TCheckBox;
        cbFakeSuper: TCheckBox;
        cbUsermap: TCheckBox;
        cbGroupmap: TCheckBox;
        cbSafeLinks: TCheckBox;
        cbCopyUnsafeLinks: TCheckBox;
        cbCopyDirlinks: TCheckBox;
        cbKeepDirlinks: TCheckBox;

        // SSH и сеть
        cbCompress: TCheckBox;
        cbCompressLevel: TCheckBox;
        cbRsh: TCheckBox;
        cbTimeout: TCheckBox;
        cbBwlimit: TCheckBox;
        cbIpv4: TCheckBox;
        cbIpv6: TCheckBox;
        cbPasswordFile: TCheckBox;
        cbRsyncPath: TCheckBox;
        cbSshKey: TCheckBox;
        cbSshNoStrict: TCheckBox;

        // Вывод и лог
        cbVerbose: TCheckBox;
        cbQuiet: TCheckBox;
        cbItemize: TCheckBox;
        cbStats: TCheckBox;
        cbHumanReadable: TCheckBox;
        cbProgress: TCheckBox;
        cbListOnly: TCheckBox;
        cbOutFormat: TCheckBox;
        cbLogFile: TCheckBox;
        cbLogFileFormat: TCheckBox;

        // Прочее
        cbSparse: TCheckBox;
        cbInplace: TCheckBox;
        cbIconv: TCheckBox;
        cbCompareDest: TCheckBox;
        cbLinkDest: TCheckBox;
        cbCopyDest: TCheckBox;

        // Параметрические поля
        edModifyWindow: TEdit;
        edBackupDir: TEdit;
        edSuffix: TEdit;
        edMaxDelete: TEdit;
        edExcludeFrom: TEdit;
        edIncludeFrom: TEdit;
        edFilter: TEdit;
        edFilesFrom: TEdit;
        edMaxSize: TEdit;
        edMinSize: TEdit;
        edChmod: TEdit;
        edUsermap: TEdit;
        edGroupmap: TEdit;
        edCompressLevel: TEdit;
        edRsh: TEdit;
        edTimeout: TEdit;
        edBwlimit: TEdit;
        edPasswordFile: TEdit;
        edRsyncPath: TEdit;
        edSshKey: TEdit;
        edOutFormat: TEdit;
        edLogFile: TEdit;
        edLogFileFormat: TEdit;
        edIconv: TEdit;
        edCompareDest: TEdit;
        edLinkDest: TEdit;
        edCopyDest: TEdit;

        procedure FormCreate(Sender: TObject);
        procedure FormDestroy(Sender: TObject);
        procedure OnFlagChange(Sender: TObject);
        procedure bCopyClick(Sender: TObject);
        procedure bResetClick(Sender: TObject);
        procedure cbPresetsChange(Sender: TObject);
        procedure bPresetSaveClick(Sender: TObject);
        procedure bPresetRenameClick(Sender: TObject);
        procedure bPresetDeleteClick(Sender: TObject);
        procedure ebSshPortKeyPress(Sender: TObject; var Key: Char);
        procedure ebSshPortChange(Sender: TObject);
    private
        type
            TFlagSpec = record
                Check: TCheckBox;
                Edit: TEdit;
                Token: string;
            end;

            TRsyncMode = (rmLocal, rmPush, rmPull);

            TPresetData = class
            public
                IsCustom: Boolean;
                OriginalName: string;
                constructor Create(AIsCustom: Boolean; const AName: string = '');
            end;
    private const
        DFM_COL_WIDTH = 300;
        STATE_SECTION = 'rsyncGenerator';
    private
    FFlags: TArray<TFlagSpec>;
    FUpdatingUI: Boolean;
    FStateReady: Boolean;
    FPresetDataList: TObjectList<TPresetData>;
    FDataByItem: TList<TRsyncPreset>;

        procedure AppShowHint(var HintStr: string; var CanShow: Boolean;
            var HintInfo: Vcl.Controls.THintInfo);
        procedure AddFlag(Check: TCheckBox; Edit: TEdit; const Token: string);
        function FindEdit(BaseName: string): TEdit;
        procedure RegisterFlags;
        procedure UpdateCommand;
        function IsModeSsh: Boolean;
        function QuoteArg(const S: string): string;
        function BuildSshToken: string;
        function BuildSidePath(const HostSidePath: string): string;
        function BuildCommand: string;
        procedure BuildCommandList(Strings: TStrings);
        procedure CollectWarnings(Warnings: TStringList);
        procedure ApplyWarnings(const Warnings: TStringList);
        procedure ResetToDefaults;
        function RememberedChecks: TArray<TCheckBox>;
        procedure RestoreControlState;
        procedure SaveControlState;
        procedure LoadHistoryToUI;
        procedure LoadPresetsToComboBox;
        function CapturePresetFlags: string;
        procedure ApplyPresetFlags(const AFlags, AExclude, AInclude, AExtra: string; AMove: Integer);
    public
        procedure DoInitialize; override;
    end;

var
    RsyncGenForm: TRsyncGenForm;

implementation

uses
    Common.AppState,
    Common.Helpers,
    Common.Localization,
    System.JSON,
    UI.HoverHelpManager,
    Vcl.AppEvnts
    ;

{$R *.dfm}

procedure TRsyncGenForm.FormCreate(Sender: TObject);
begin
    inherited;

    TApplicationEvents.Create(Self).OnShowHint := AppShowHint;
    pgcOptions.DoubleBuffered := True;
    FPresetDataList := TObjectList<TPresetData>.Create(True);
    FDataByItem := TList<TRsyncPreset>.Create;

    // Кнопка "Скопировать" - действие по умолчанию на Enter
    bCopy.Default := True;
end;

procedure TRsyncGenForm.AppShowHint(var HintStr: string; var CanShow: Boolean;
    var HintInfo: Vcl.Controls.THintInfo);
begin
    if CanShow and Assigned(HintInfo.HintControl) and
        (GetParentForm(HintInfo.HintControl) = Self) then
        HintInfo.HideTimeout := 10000;
end;

procedure TRsyncGenForm.FormDestroy(Sender: TObject);
begin
    try
        if FStateReady and (AppState <> nil) then
            SaveControlState;
    finally
        FPresetDataList.Free;
        FDataByItem.Free;
        inherited;
    end;
end;

constructor TRsyncGenForm.TPresetData.Create(AIsCustom: Boolean; const AName: string);
begin
    inherited Create;
    IsCustom := AIsCustom;
    OriginalName := AName;
end;

procedure TRsyncGenForm.DoInitialize;
begin
    inherited;

    FUpdatingUI := True;
    try
        RegisterFlags;
        ResetToDefaults;
        LoadPresetsToComboBox;
        LoadHistoryToUI;
        RestoreControlState;
    finally
        FUpdatingUI := False;
    end;

    UpdateCommand;
    FStateReady := True;
end;

function TRsyncGenForm.RememberedChecks: TArray<TCheckBox>;
begin
    Result := [cbMultiline, cbCompress, cbVerbose, cbItemize, cbStats,
        cbHumanReadable, cbProgress];
end;

procedure TRsyncGenForm.RestoreControlState;
var
    Section, Value: TJSONValue;
    Check: TCheckBox;
    I: Integer;
begin
    Section := AppState.ReadSection(STATE_SECTION);
    try
        if not (Section is TJSONObject) then
            Exit;

        Value := TJSONObject(Section).GetValue('mode');
        if Value is TJSONString then
        begin
            if Value.Value = 'push' then
                rbPush.Checked := True
            else if Value.Value = 'pull' then
                rbPull.Checked := True;
        end;

        Value := TJSONObject(Section).GetValue('activePage');
        if Value is TJSONString then
            for I := 0 to pgcOptions.PageCount - 1 do
                if pgcOptions.Pages[I].TabVisible and
                    (pgcOptions.Pages[I].Name = Value.Value) then
                begin
                    pgcOptions.ActivePage := pgcOptions.Pages[I];
                    Break;
                end;

        for Check in RememberedChecks do
        begin
            Value := TJSONObject(Section).GetValue(Check.Name);
            if Value is TJSONBool then
                Check.Checked := TJSONBool(Value).AsBoolean;
        end;
    finally
        Section.Free;
    end;
end;

procedure TRsyncGenForm.SaveControlState;
var
    Section: TJSONObject;
    Check: TCheckBox;
    Mode: string;
begin
    if rbPush.Checked then
        Mode := 'push'
    else if rbPull.Checked then
        Mode := 'pull'
    else
        Mode := 'local';

    Section := TJSONObject.Create;
    try
        Section.AddPair('mode', Mode);
        if pgcOptions.ActivePage <> nil then
            Section.AddPair('activePage', pgcOptions.ActivePage.Name);
        for Check in RememberedChecks do
            Section.AddPair(Check.Name, Check.Checked);
    except
        Section.Free;
        raise;
    end;
    AppState.WriteSection(STATE_SECTION, Section);
end;

// =========================================================================
// Регистрация флагов: единый список в порядке вывода в команду
// =========================================================================

procedure TRsyncGenForm.AddFlag(Check: TCheckBox; Edit: TEdit; const Token: string);
var
    N: Integer;
begin
    N := Length(FFlags);
    SetLength(FFlags, N + 1);
    FFlags[N].Check := Check;
    FFlags[N].Edit := Edit;
    FFlags[N].Token := Token;
end;

function TRsyncGenForm.FindEdit(BaseName: string): TEdit;
begin
    // Имя едита совпадает с чекбоксом с заменой префикса cb -> ed
    Result := TEdit(FindComponent('ed' + BaseName.Substring(2)));
end;

procedure TRsyncGenForm.RegisterFlags;
    procedure F(Check: TCheckBox; const Token: string);
    begin
        AddFlag(Check, nil, Token);
    end;
    procedure FV(Check: TCheckBox; const Token: string);
    begin
        AddFlag(Check, FindEdit(Check.Name), Token);
    end;
begin
    // Основное
    FV(cbArchive, '-a');
    F(cbRecursive, '-r');
    F(cbLinks, '-l');
    F(cbPerms, '-p');
    F(cbTimes, '-t');
    F(cbGroup, '-g');
    F(cbOwner, '-o');
    F(cbDevices, '-D');
    F(cbSpecials, '-s');
    F(cbHardLinks, '-H');
    F(cbAcls, '-A');
    F(cbXattrs, '-X');
    F(cbDirs, '-d');
    F(cbDryRun, '-n');
    F(cbOmitDirTimes, '-O');

    // Передача
    F(cbWholeFile, '-W');
    F(cbChecksum, '-c');
    F(cbSizeOnly, '--size-only');
    F(cbIgnoreTimes, '-I');
    FV(cbModifyWindow, '--modify-window=');
    F(cbAppend, '--append');
    F(cbAppendVerify, '--append-verify');
    F(cbUpdate, '-u');
    F(cbExisting, '--existing');
    F(cbIgnoreExisting, '--ignore-existing');
    F(cbBackup, '--backup');
    FV(cbBackupDir, '--backup-dir=');
    FV(cbSuffix, '--suffix=');
    F(cbRemoveSourceFiles, '--remove-source-files');
    F(cbPartial, '--partial');

    // Удаление
    F(cbDelete, '--delete');
    F(cbDeleteBefore, '--delete-before');
    F(cbDeleteDelay, '--delete-delay');
    F(cbDeleteAfter, '--delete-after');
    F(cbDeleteExcluded, '--delete-excluded');
    F(cbForce, '--force');
    F(cbIgnoreErrors, '--ignore-errors');
    FV(cbMaxDelete, '--max-delete=');
    F(cbDelayUpdates, '--delay-updates');

    // Фильтры (кроме exclude/include - обрабатываются отдельно)
    FV(cbExcludeFrom, '--exclude-from=');
    FV(cbIncludeFrom, '--include-from=');
    FV(cbFilter, '--filter=');
    FV(cbFilesFrom, '--files-from=');
    FV(cbMaxSize, '--max-size=');
    FV(cbMinSize, '--min-size=');
    F(cbPruneEmptyDirs, '-m');
    F(cbCvsExclude, '-C');
    F(cbRelative, '-R');
    F(cbNoImpliedDirs, '--no-implied-dirs');

    // Права и ссылки
    FV(cbChmod, '--chmod=');
    F(cbNumericIds, '--numeric-ids');
    F(cbSuper, '--super');
    F(cbFakeSuper, '--fake-super');
    FV(cbUsermap, '--usermap=');
    FV(cbGroupmap, '--groupmap=');
    F(cbSafeLinks, '--safe-links');
    F(cbCopyUnsafeLinks, '--copy-unsafe-links');
    F(cbCopyDirlinks, '--copy-dirlinks');
    F(cbKeepDirlinks, '-k');

    // SSH и сеть
    F(cbCompress, '-z');
    FV(cbCompressLevel, '--compress-level=');
    FV(cbRsh, '--rsh=');
    FV(cbTimeout, '--timeout=');
    FV(cbBwlimit, '--bwlimit=');
    F(cbIpv4, '-4');
    F(cbIpv6, '-6');
    FV(cbPasswordFile, '--password-file=');
    FV(cbRsyncPath, '--rsync-path=');
    // cbSshKey/cbSshNoStrict обрабатываются отдельно в BuildSshToken

    // Вывод и лог
    F(cbVerbose, '-v');
    F(cbQuiet, '-q');
    F(cbItemize, '-i');
    F(cbStats, '--stats');
    F(cbHumanReadable, '-h');
    F(cbProgress, '--progress');
    F(cbListOnly, '--list-only');
    FV(cbOutFormat, '--out-format=');
    FV(cbLogFile, '--log-file=');
    FV(cbLogFileFormat, '--log-file-format=');

    // Прочее
    F(cbSparse, '-S');
    F(cbInplace, '--inplace');
    FV(cbIconv, '--iconv=');
    FV(cbCompareDest, '--compare-dest=');
    FV(cbLinkDest, '--link-dest=');
    FV(cbCopyDest, '--copy-dest=');
end;

// =========================================================================
// Сборка команды
// =========================================================================

function TRsyncGenForm.QuoteArg(const S: string): string;
begin
    // Значение без спецсимволов оставляем как есть; иначе одинарные кавычки
    // с экранированием внутренних одинарных (POSIX shell quoting)
    if S = '' then
        Exit('');

    if S.IndexOfAny([' ', '"', '''', '\', '$', '&', '|', '<', '>', ';', '(', ')', '*', '?', '[', ']', '#', '~']) >= 0 then
        Result := #39 + S.Replace(#39, #39#92#39#39) + #39
    else
        Result := S;
end;

function TRsyncGenForm.IsModeSsh: Boolean;
begin
    Result := not rbLocal.Checked;
end;

function TRsyncGenForm.BuildSshToken: string;
var
    Port: Integer;
    SshCmd: string;
begin
    Result := '';

    // Явный --rsh имеет приоритет над встроенной сборкой SSH
    if cbRsh.Checked and (Trim(edRsh.Text) <> '') then
    begin
        Result := '--rsh=' + QuoteArg(Trim(edRsh.Text));
        Exit;
    end;

    if not IsModeSsh then
        Exit;

    SshCmd := 'ssh';

    if cbSshKey.Checked and (Trim(edSshKey.Text) <> '') then
        SshCmd := SshCmd + ' -i ' + Trim(edSshKey.Text);

    if cbSshNoStrict.Checked then
        SshCmd := SshCmd + ' -o StrictHostKeyChecking=accept-new';

    if Trim(ebSshPort.Text) <> '' then
    begin
        if TryStrToInt(Trim(ebSshPort.Text), Port) then
            SshCmd := SshCmd + ' -p ' + Port.ToString;
    end;

    // Кавычки нужны только если строка стала составной
    if SshCmd.Contains(' ') then
        Result := '-e ' + QuoteArg(SshCmd)
    else
        Result := '-e ' + SshCmd;
end;

function TRsyncGenForm.BuildSidePath(const HostSidePath: string): string;
var
    User, Host: string;
begin
    // Собирает user@host:/path из полей SSH и пути удалённой стороны
    Host := Trim(ebHost.Text);
    User := Trim(ebUser.Text);

    if User <> '' then
        Result := User + '@' + Host + ':' + HostSidePath
    else
        Result := Host + ':' + HostSidePath;

    if (Result.IndexOfAny([' ']) >= 0) then
        Result := QuoteArg(Result);
end;

procedure TRsyncGenForm.CollectWarnings(Warnings: TStringList);
var
    DeleteModes: Integer;
begin
    DeleteModes := Ord(cbDelete.Checked) + Ord(cbDeleteBefore.Checked) +
        Ord(cbDeleteDelay.Checked) + Ord(cbDeleteAfter.Checked);
    if DeleteModes > 1 then
        Warnings.Add(TUIStateLoader.GetMessage('RsyncGenForm.Warnings.MultipleDeleteModes'));

    if (Ord(cbMaxDelete.Checked) > 0) and (DeleteModes = 0) then
        Warnings.Add(TUIStateLoader.GetMessage('RsyncGenForm.Warnings.MaxDeleteWithoutDelete'));

    if cbDryRun.Checked and cbRemoveSourceFiles.Checked then
        Warnings.Add(TUIStateLoader.GetMessage('RsyncGenForm.Warnings.DryRunWithRemoveSourceFiles'));

    if cbAppend.Checked and cbAppendVerify.Checked then
        Warnings.Add(TUIStateLoader.GetMessage('RsyncGenForm.Warnings.ConflictingAppendModes'));

    if Ord(cbCompareDest.Checked) + Ord(cbLinkDest.Checked) + Ord(cbCopyDest.Checked) > 1 then
        Warnings.Add(TUIStateLoader.GetMessage('RsyncGenForm.Warnings.ConflictingDestModes'));

    if IsModeSsh and (Trim(ebHost.Text) = '') then
        Warnings.Add(TUIStateLoader.GetMessage('RsyncGenForm.Warnings.MissingSshHost'));
end;

procedure TRsyncGenForm.ApplyWarnings(const Warnings: TStringList);
begin
    if Warnings.Count > 0 then
    begin
        lbValidation.Caption := Trim(Warnings.Text);
        lbValidation.Font.Color := $0028A0E8; // оранжево-красный (BGR)
    end
    else
    begin
        lbValidation.Caption := '';
    end;
end;

procedure TRsyncGenForm.BuildCommandList(Strings: TStrings);
var
    Spec: TFlagSpec;
    Shorts: TStringList;
    Val: string;
begin
    Shorts := TStringList.Create;
    try
        // 1. Короткие флаги сливаем в одну группу -avz
        for Spec in FFlags do
        begin
            if not Spec.Check.Checked then Continue;
            if (Spec.Token.StartsWith('-')) and (not Spec.Token.StartsWith('--')) then
                Shorts.Add(Spec.Token.Substring(1));
        end;

        if Shorts.Count > 0 then
            Strings.Add('-' + Shorts.Text.Replace(#13#10, '').Trim);

        // 2. Длинные и параметрические флаги
        for Spec in FFlags do
        begin
            if not Spec.Check.Checked then Continue;

            if (Spec.Token.StartsWith('--')) then
            begin
                if Spec.Edit <> nil then
                begin
                    Val := Trim(Spec.Edit.Text);
                    if Val = '' then Continue;
                    Strings.Add(Spec.Token + QuoteArg(Val));
                end
                else
                    Strings.Add(Spec.Token);
            end;
        end;

        // 3. --exclude / --include из многострочных полей
        if cbExclude.Checked then
            for Val in mExclude.Lines do
                if Val.Trim <> '' then
                    Strings.Add('--exclude=' + QuoteArg(Val.Trim));

        if cbInclude.Checked then
            for Val in mInclude.Lines do
                if Val.Trim <> '' then
                    Strings.Add('--include=' + QuoteArg(Val.Trim));

        // 4. Транспорт
        Val := BuildSshToken;
        if Val <> '' then
            Strings.Add(Val);

        // 5. Дополнительные аргументы
        Val := Trim(ebExtra.Text);
        if Val <> '' then
            Strings.Add(Val);
    finally
        Shorts.Free;
    end;
end;

function TRsyncGenForm.BuildCommand: string;
var
    Tokens: TStringList;
    Src, Dst: string;
    I: Integer;
    Sb: TStringBuilder;
begin
    Tokens := TStringList.Create;
    Sb := TStringBuilder.Create;
    try
        BuildCommandList(Tokens);

        Src := Trim(cbSource.Text);
        Dst := Trim(cbDest.Text);

        if rbLocal.Checked then
        begin
            if Src = '' then Src := '<source>';
            if Dst = '' then Dst := '<dest>';
            Src := QuoteArg(Src);
            Dst := QuoteArg(Dst);
        end
        else if rbPush.Checked then
        begin
            if Src = '' then Src := '<source>';
            if Src <> '<source>' then Src := QuoteArg(Src);
            if Dst = '' then Dst := BuildSidePath('<dest>') else Dst := BuildSidePath(Dst);
        end
        else
        begin
            if Src = '' then Src := BuildSidePath('<source>') else Src := BuildSidePath(Src);
            if Dst = '' then Dst := '<dest>';
            if Dst <> '<dest>' then Dst := QuoteArg(Dst);
        end;

        if cbMultiline.Checked then
        begin
            Sb.Append('rsync');
            if Tokens.Count > 0 then
            begin
                Sb.Append(' ');
                Sb.Append(Tokens[0]);
                for I := 1 to Tokens.Count - 1 do
                begin
                    Sb.Append(' \'#13#10'    ');
                    Sb.Append(Tokens[I]);
                end;
                Sb.Append(' \');
            end;
            Sb.Append(#13#10);
            Sb.Append(Src + ' ' + Dst);
        end
        else
        begin
            Sb.Append('rsync');
            for I := 0 to Tokens.Count - 1 do
                Sb.Append(' ').Append(Tokens[I]);
            Sb.Append(' ').Append(Src).Append(' ').Append(Dst);
        end;

        Result := Sb.ToString;
    finally
        Tokens.Free;
        Sb.Free;
    end;
end;

procedure TRsyncGenForm.UpdateCommand;
var
    Warnings: TStringList;
begin
    if FUpdatingUI then Exit;

    mCommand.Text := BuildCommand;

    Warnings := TStringList.Create;
    try
        CollectWarnings(Warnings);
        ApplyWarnings(Warnings);
    finally
        Warnings.Free;
    end;
end;

procedure TRsyncGenForm.OnFlagChange(Sender: TObject);
begin
    // Сбрасываем выбор пресета, но OnChange у комбобокса не сработает
    // (ItemIndex := -1 без смены пользователем не генерирует OnChange после ApplyPreset:
    // защита через FUpdatingUI в cbPresetsChange)
    if cbPresets.ItemIndex >= 0 then
    begin
        if Sender <> cbPresets then
            cbPresets.ItemIndex := -1;
    end;

    UpdateCommand;
end;

// =========================================================================
// Кнопки и пресеты
// =========================================================================

procedure TRsyncGenForm.bCopyClick(Sender: TObject);
var
    Setts: TAppSettings;
begin
    if mCommand.Text <> '' then
    begin
        CopyToClipboardSecure(mCommand.Text);
        ShowSimpleToast(TUIStateLoader.GetMessage('Common.CopiedToClipboard'));

        Setts := AppContext.SettingsManager.Data;
        THistoryHelper.Add(Setts.HistoryArchivePaths, cbSource.Text, HISTORY_SOURCE_RSYNC);
        THistoryHelper.Add(Setts.HistoryArchivePaths, cbDest.Text, HISTORY_SOURCE_RSYNC);
        AppContext.SettingsManager.Data := Setts;
        AppContext.SettingsManager.Save;
        LoadHistoryToUI;
    end;
end;

procedure TRsyncGenForm.bResetClick(Sender: TObject);
begin
    FUpdatingUI := True;
    try
        ResetToDefaults;
    finally
        FUpdatingUI := False;
    end;
    UpdateCommand;
end;

procedure TRsyncGenForm.ebSshPortKeyPress(Sender: TObject; var Key: Char);
begin
    // Только цифры, backspace и вставка из буфера (Ctrl+V пропускаем -
    // контроль числа происходит в TryStrToInt при сборке команды)
    if not CharInSet(Key, ['0'..'9', #8, #24]) then
    begin
        Key := #0;
        Exit;
    end;
end;

procedure TRsyncGenForm.ebSshPortChange(Sender: TObject);
begin
    OnFlagChange(Sender);
end;

procedure TRsyncGenForm.ResetToDefaults;
var
    Spec: TFlagSpec;
begin
    rbLocal.Checked := True;
    cbSource.Text := '';
    cbDest.Text := '';
    ebUser.Text := '';
    ebHost.Text := '';
    ebSshPort.Text := '';
    ebExtra.Text := '';
    cbMultiline.Checked := False;
    mExclude.Clear;
    mInclude.Clear;

    for Spec in FFlags do
    begin
        Spec.Check.Checked := False;
        if Spec.Edit <> nil then
            Spec.Edit.Clear;
    end;

    cbArchive.Checked := True;
    edModifyWindow.Text := '1';
    edSuffix.Text := '~';
    edMaxDelete.Text := '500';
    edMaxSize.Text := '100M';
    edMinSize.Text := '1M';
    edCompressLevel.Text := '6';
    edTimeout.Text := '300';
    edBwlimit.Text := '10000';
    edIconv.Text := 'utf8,cp1251';
end;

procedure TRsyncGenForm.LoadHistoryToUI;
var
    Paths: TArray<THistoryItem>;

    procedure FillCB(CB: TComboBox; const Hist: TArray<THistoryItem>);
    var
        Idx: Integer;
    begin
        CB.Items.BeginUpdate;
        try
            CB.Items.Clear;
            for Idx := 0 to High(Hist) do
                CB.Items.Add(Hist[Idx].Value);
        finally
            CB.Items.EndUpdate;
        end;
    end;
begin
    Paths := THistoryHelper.FilterBySource(AppContext.SettingsManager.Data.HistoryArchivePaths,
        HISTORY_SOURCE_RSYNC);
    FillCB(cbSource, Paths);
    FillCB(cbDest, Paths);
end;

procedure TRsyncGenForm.LoadPresetsToComboBox;
var
    Setts: TAppSettings;
    I: Integer;

    procedure AddBuiltin(const ADisplayName: string; const AFlags, AEx, AInc: string; AMode: Integer);
    var
        Data: TPresetData;
        Rec: TRsyncPreset;
    begin
        Data := TPresetData.Create(False);
        FPresetDataList.Add(Data);
        Rec.Name := ADisplayName;
        Rec.Mode := AMode;
        Rec.Flags := AFlags;
        Rec.Exclude := AEx;
        Rec.Include := AInc;
        Rec.Extra := '';
        cbPresets.Items.AddObject(ADisplayName, Data);
        FDataByItem.Add(Rec);
    end;
begin
    FPresetDataList.Clear;
    cbPresets.Items.BeginUpdate;
    try
        cbPresets.Items.Clear;
        FDataByItem.Clear;

        // Встроенные сценарии: сверху самые ходовые
        AddBuiltin(TUIStateLoader.GetMessage('RsyncGenForm.Builtins.Mirror'),
            '-z;--delete;--stats;--progress', '', '', 2);
        AddBuiltin(TUIStateLoader.GetMessage('RsyncGenForm.Builtins.Backup'),
            '-z;--delete-delay;--backup;--stats', '', '', 1);
        AddBuiltin(TUIStateLoader.GetMessage('RsyncGenForm.Builtins.DryRun'),
            '-v;-i;-n;--delete', '', '', 1);
        AddBuiltin(TUIStateLoader.GetMessage('RsyncGenForm.Builtins.UpdateOnly'),
            '--progress;--update', '', '', 1);
        AddBuiltin(TUIStateLoader.GetMessage('RsyncGenForm.Builtins.MissingOnly'),
            '--progress;--ignore-existing', '', '', 1);
        AddBuiltin(TUIStateLoader.GetMessage('RsyncGenForm.Builtins.Incremental'),
            '--link-dest=/var/backup/current;--stats', '', '', 0);
        AddBuiltin(TUIStateLoader.GetMessage('RsyncGenForm.Builtins.BwLimit'),
            '--bwlimit=10000;--partial;-z;--progress', '', '', 1);
        AddBuiltin(TUIStateLoader.GetMessage('RsyncGenForm.Builtins.BigFiles'),
            '--min-size=100M;--progress', '', '', 1);
        AddBuiltin(TUIStateLoader.GetMessage('RsyncGenForm.Builtins.HardBackup'),
            '-H;--numeric-ids;--stats', '', '', 1);
        AddBuiltin(TUIStateLoader.GetMessage('RsyncGenForm.Builtins.ExcludeVcs'),
            '-z;--delete', '*.git;;*.svn;*.hg', '', 1);
        AddBuiltin(TUIStateLoader.GetMessage('RsyncGenForm.Builtins.Logs'),
            '--stats;--partial', '', '', 1);

        // Пользовательские предустановки из настроек
        Setts := AppContext.SettingsManager.Data;
        if Length(Setts.RsyncPresets) > 0 then
        begin
            cbPresets.Items.AddObject(
                TUIStateLoader.GetMessage('RsyncGenForm.Presets-Divider'), nil);

            for I := 0 to High(Setts.RsyncPresets) do
            begin
                FPresetDataList.Add(TPresetData.Create(True, Setts.RsyncPresets[I].Name));
                cbPresets.Items.AddObject(Setts.RsyncPresets[I].Name,
                    FPresetDataList.Last);
            end;
        end;
    finally
        cbPresets.Items.EndUpdate;
    end;
    cbPresets.ItemIndex := -1;
end;

procedure TRsyncGenForm.cbPresetsChange(Sender: TObject);
var
    Data: TPresetData;
    Setts: TAppSettings;
    I: Integer;
begin
    if FUpdatingUI then Exit;
    if cbPresets.ItemIndex < 0 then Exit;

    Data := TPresetData(cbPresets.Items.Objects[cbPresets.ItemIndex]);
    if not Assigned(Data) then Exit;

    if not Data.IsCustom then
    begin
        // Встроенная: параметры лежат в FDataByItem по порядку добавления
        ApplyPresetFlags(FDataByItem[cbPresets.ItemIndex].Flags,
            FDataByItem[cbPresets.ItemIndex].Exclude,
            FDataByItem[cbPresets.ItemIndex].Include, '',
            FDataByItem[cbPresets.ItemIndex].Mode);
        Exit;
    end;

    // Пользовательская: восстанавливаем сохранённое состояние
    Setts := AppContext.SettingsManager.Data;
    for I := 0 to High(Setts.RsyncPresets) do
        if Setts.RsyncPresets[I].Name = Data.OriginalName then
        begin
            ApplyPresetFlags(Setts.RsyncPresets[I].Flags,
                Setts.RsyncPresets[I].Exclude, Setts.RsyncPresets[I].Include,
                Setts.RsyncPresets[I].Extra, Setts.RsyncPresets[I].Mode);
            Exit;
        end;
end;

function TRsyncGenForm.CapturePresetFlags: string;
var
    Spec: TFlagSpec;
    Sb: TStringBuilder;
    Val: string;
begin
    Sb := TStringBuilder.Create;
    try
        for Spec in FFlags do
        begin
            if not Spec.Check.Checked then Continue;
            if Spec.Edit <> nil then
            begin
                Val := Trim(Spec.Edit.Text);
                if Val = '' then Continue;
                Sb.Append(Spec.Token + Val);
            end
            else
                Sb.Append(Spec.Token);
            Sb.Append(';');
        end;

        // Списки exclude/include привязаны к своим чекбоксам
        if cbExclude.Checked then
            Sb.Append('--exclude-list=' + StringReplace(mExclude.Text, #13#10, '\n', [rfReplaceAll]) + ';');
        if cbInclude.Checked then
            Sb.Append('--include-list=' + StringReplace(mInclude.Text, #13#10, '\n', [rfReplaceAll]) + ';');

        Result := Sb.ToString.TrimRight([';']);
    finally
        Sb.Free;
    end;
end;

procedure TRsyncGenForm.ApplyPresetFlags(const AFlags, AExclude, AInclude,
    AExtra: string; AMove: Integer);
var
    Spec: TFlagSpec;
    TokenList: TArray<string>;
    Token: string;
    P: Integer;

    function Normalize(const T: string): string;
    begin
        // '--opt=v' -> '--opt=' для сравнения с Spec.Token
        P := Pos('=', T);
        if P > 0 then
            Result := Copy(T, 1, P)
        else
            Result := T;
    end;
begin
    FUpdatingUI := True;
    try
        for Spec in FFlags do
        begin
            Spec.Check.Checked := False;
            if Spec.Edit <> nil then
                Spec.Edit.Clear;
        end;
        mExclude.Clear;
        mInclude.Clear;
        cbExclude.Checked := False;
        cbInclude.Checked := False;
        cbArchive.Checked := True;

        case AMove of
            1: rbPush.Checked := True;
            2: rbPull.Checked := True;
        else
            rbLocal.Checked := True;
        end;

        TokenList := AFlags.Split([';'], TStringSplitOptions.ExcludeEmpty);
        for Token in TokenList do
        begin
            if Token.StartsWith('--exclude-list=') then
            begin
                cbExclude.Checked := True;
                mExclude.Text := Token.Substring(15).Replace('\n', #13#10);
                Continue;
            end;
            if Token.StartsWith('--include-list=') then
            begin
                cbInclude.Checked := True;
                mInclude.Text := Token.Substring(15).Replace('\n', #13#10);
                Continue;
            end;

            for Spec in FFlags do
            begin
                if Normalize(Token) <> Spec.Token then Continue;
                Spec.Check.Checked := True;
                if Spec.Edit <> nil then
                begin
                    P := Pos('=', Token);
                    if P > 0 then
                        Spec.Edit.Text := Copy(Token, P + 1, MaxInt);
                end;
                Break;
            end;
        end;

        ebExtra.Text := AExtra;
        if AExclude <> '' then
        begin
            cbExclude.Checked := True;
            mExclude.Text := AExclude;
        end;
        if AInclude <> '' then
        begin
            cbInclude.Checked := True;
            mInclude.Text := AInclude;
        end;
    finally
        FUpdatingUI := False;
    end;

    UpdateCommand;
end;

procedure TRsyncGenForm.bPresetSaveClick(Sender: TObject);
var
    PresetName: string;
    Setts: TAppSettings;
    NewPreset: TRsyncPreset;
    I, ExistingIdx: Integer;
begin
    PresetName := '';

    if not MessagesHandler.AskInput(
        TUIStateLoader.GetMessage('RsyncGenForm.Messages.SavePresetTitle'),
        TUIStateLoader.GetMessage('RsyncGenForm.Messages.SavePresetPrompt'),
        PresetName) then
        Exit;

    PresetName := Trim(PresetName);
    if PresetName = '' then Exit;

    NewPreset.Name := PresetName;
    if rbPush.Checked then
        NewPreset.Mode := 1
    else if rbPull.Checked then
        NewPreset.Mode := 2
    else
        NewPreset.Mode := 0;
    NewPreset.Flags := CapturePresetFlags;
    NewPreset.Exclude := '';
    NewPreset.Include := '';
    NewPreset.Extra := Trim(ebExtra.Text);

    Setts := AppContext.SettingsManager.Data;

    // Повторное сохранение под существующим именем перезаписывает предустановку
    ExistingIdx := -1;
    for I := 0 to High(Setts.RsyncPresets) do
        if Setts.RsyncPresets[I].Name = PresetName then
        begin
            ExistingIdx := I;
            Break;
        end;

    if ExistingIdx >= 0 then
        Setts.RsyncPresets[ExistingIdx] := NewPreset
    else
    begin
        SetLength(Setts.RsyncPresets, Length(Setts.RsyncPresets) + 1);
        Setts.RsyncPresets[High(Setts.RsyncPresets)] := NewPreset;
    end;

    AppContext.SettingsManager.Data := Setts;
    AppContext.SettingsManager.Save;

    LoadPresetsToComboBox;
    ShowSimpleToast(TUIStateLoader.GetMessage('RsyncGenForm.Messages.PresetSaved'));
end;

procedure TRsyncGenForm.bPresetRenameClick(Sender: TObject);
var
    Data: TPresetData;
    Setts: TAppSettings;
    I: Integer;
    NewName: string;
begin
    if cbPresets.ItemIndex < 0 then Exit;
    Data := TPresetData(cbPresets.Items.Objects[cbPresets.ItemIndex]);
    if not Assigned(Data) or not Data.IsCustom then Exit;

    NewName := Data.OriginalName;
    if not MessagesHandler.AskInput(
        TUIStateLoader.GetMessage('RsyncGenForm.Messages.RenamePresetTitle'),
        TUIStateLoader.GetMessage('RsyncGenForm.Messages.RenamePresetPrompt'),
        NewName) then
        Exit;

    NewName := Trim(NewName);
    if (NewName = '') or (NewName = Data.OriginalName) then Exit;

    Setts := AppContext.SettingsManager.Data;
    for I := 0 to High(Setts.RsyncPresets) do
        if Setts.RsyncPresets[I].Name = Data.OriginalName then
        begin
            Setts.RsyncPresets[I].Name := NewName;
            Break;
        end;

    AppContext.SettingsManager.Data := Setts;
    AppContext.SettingsManager.Save;

    LoadPresetsToComboBox;
    ShowSimpleToast(TUIStateLoader.GetMessage('RsyncGenForm.Messages.PresetRenamed'));
end;

procedure TRsyncGenForm.bPresetDeleteClick(Sender: TObject);
var
    Data: TPresetData;
    Setts: TAppSettings;
    I, IdxToRemove: Integer;
begin
    if cbPresets.ItemIndex < 0 then Exit;
    Data := TPresetData(cbPresets.Items.Objects[cbPresets.ItemIndex]);
    if not Assigned(Data) or not Data.IsCustom then Exit;

    if not MessagesHandler.AskConfirmation(
        Format(TUIStateLoader.GetMessage('RsyncGenForm.Messages.DeleteConfirmFormat'),
            [Data.OriginalName]),
        TUIStateLoader.GetMessage('RsyncGenForm.Messages.DeleteTitle')) then
        Exit;

    Setts := AppContext.SettingsManager.Data;
    IdxToRemove := -1;
    for I := 0 to High(Setts.RsyncPresets) do
        if Setts.RsyncPresets[I].Name = Data.OriginalName then
        begin
            IdxToRemove := I;
            Break;
        end;

    if IdxToRemove < 0 then Exit;

    for I := IdxToRemove to High(Setts.RsyncPresets) - 1 do
        Setts.RsyncPresets[I] := Setts.RsyncPresets[I + 1];
    SetLength(Setts.RsyncPresets, Length(Setts.RsyncPresets) - 1);

    AppContext.SettingsManager.Data := Setts;
    AppContext.SettingsManager.Save;

    LoadPresetsToComboBox;
    ShowSimpleToast(TUIStateLoader.GetMessage('RsyncGenForm.Messages.PresetDeleted'));
end;

end.
