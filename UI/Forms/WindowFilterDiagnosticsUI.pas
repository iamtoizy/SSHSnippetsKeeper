unit WindowFilterDiagnosticsUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    Core.Interfaces.Settings,
    System.Classes,
    System.SysUtils,
    UI.ListViewColumnSizing,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls,
    Winapi.Windows,
    WindowMonitor
    ;

type
    // Диагностика фильтров окон: как черновик настроек (профили включённых
    // приложений + deny-набор) применится к открытым сейчас окнам.
    // Показывает слой, на котором окно отсеется, чтобы «пропавшие
    // терминалы» находились без экспериментов
    TWindowFilterDiagnosticsDialog = class(TBaseForm)
        lblTitle: TLabel;
        lbHint: TLabel;
        pList: TPanel;
        lvTable: TListView;
        lbTableEmpty: TLabel;
        pListButtons: TPanel;
        bRefresh: TButton;
        lbSummary: TLabel;
        chkAllProcesses: TCheckBox;
        ttAutoRefresh: TTimer;
        procedure bRefreshClick(Sender: TObject);
        procedure chkAllProcessesClick(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure ttAutoRefreshTimer(Sender: TObject);
        procedure lvTableDblClick(Sender: TObject);
        procedure lvTableCustomDrawItem(Sender: TCustomListView; Item: TListItem;
            State: TCustomDrawState; var DefaultDraw: Boolean);
    private
        FApps: TArray<TAllowedApplicationsItem>;
        FDenyRules: TArray<TGlobalTitleDenyRule>;
        FColFitter: TListViewColumnFitter;
        FLastSignature: string;
        function RowVerdict(const AInfo: TWindowMonitorInfo;
            out AStatus: string): Integer;
        procedure BuildTable(AForce: Boolean);
        procedure RefreshTable;
    public
        // Черновик настроек: профили включённых приложений и deny-набор
        // в том виде, в каком их сохранит форма настроек
        class function Execute(AOwner: TComponent; AppContext: IAppContext;
            const AApps: TArray<TAllowedApplicationsItem>;
            const ADenyRules: TArray<TGlobalTitleDenyRule>): Boolean;
    end;

implementation

uses
    Common.Localization,
    ProcessProfile,
    Vcl.Graphics,
    WindowProfileDialogUI
    ;

{$R *.dfm}

class function TWindowFilterDiagnosticsDialog.Execute(AOwner: TComponent;
    AppContext: IAppContext;
    const AApps: TArray<TAllowedApplicationsItem>;
    const ADenyRules: TArray<TGlobalTitleDenyRule>): Boolean;
var
    Instance: TWindowFilterDiagnosticsDialog;
begin
    Instance := TWindowFilterDiagnosticsDialog.Create(AOwner);
    try
        Instance.Initialize(AppContext);
        Instance.FApps := Copy(AApps, 0, Length(AApps));
        Instance.FDenyRules := Copy(ADenyRules, 0, Length(ADenyRules));

        Instance.Caption := TUIStateLoader.GetMessage('Settings.DiagTitle');
        Instance.lblTitle.Caption := TUIStateLoader.GetMessage('Settings.DiagTitle');
        Instance.lbHint.Caption := TUIStateLoader.GetMessage('Settings.DiagHint');
        Instance.bRefresh.Caption := TUIStateLoader.GetMessage('Settings.DiagRefresh');
        Instance.lvTable.Columns[0].Caption := TUIStateLoader.GetMessage('Settings.DiagColApp');
        Instance.lvTable.Columns[1].Caption := TUIStateLoader.GetMessage('Settings.DiagColTitle');
        Instance.lvTable.Columns[2].Caption := TUIStateLoader.GetMessage('Settings.DiagColClass');
        Instance.lvTable.Columns[3].Caption := TUIStateLoader.GetMessage('Settings.ProfilePreviewColumnStatus');
        Instance.chkAllProcesses.Caption := TUIStateLoader.GetMessage('Settings.DiagShowAll');
        Instance.FColFitter := TListViewColumnFitter.Create(Instance, Instance.lvTable);

        Instance.RefreshTable;

        Instance.WarmUpPaint;
        Instance.PrepareGuardedShow;

        Instance.ShowModal;
        Result := True;
    finally
        Instance.Free;
    end;
end;

function TWindowFilterDiagnosticsDialog.RowVerdict(const AInfo: TWindowMonitorInfo;
    out AStatus: string): Integer;
var
    AppIndex, I: Integer;
    MatchedRule: string;
    Res: TWindowFilterResult;
begin
    Result := -1;

    // Окно включённого приложения из черновика настроек; остальные
    // отсеиваются whitelist'ом процессов и показываются только
    // в режиме «все процессы»
    AppIndex := -1;
    for I := 0 to High(FApps) do
        if FApps[I].Enabled and SameText(FApps[I].ExeName, AInfo.ExeName) then
        begin
            AppIndex := I;
            Break;
        end;

    if AppIndex < 0 then
    begin
        if not chkAllProcesses.Checked then
            Exit;
        AStatus := TUIStateLoader.GetMessage('Settings.DiagStatusNotWhitelisted');
        Exit(2);
    end;

    // Гейт: глобальный запрет проверяется первым
    if TProcessProfile.EvaluateGlobalDeny(AInfo.WindowTitle, FDenyRules, MatchedRule) then
    begin
        AStatus := TUIStateLoader.GetMessage('Settings.DiagStatusDenyRule', [MatchedRule]);
        Exit(1);
    end;

    Res := TProcessProfile.EvaluateWindowFilters(True,
        FApps[AppIndex].TitleIncludeRegex,
        FApps[AppIndex].TitleExcludeRegex,
        FApps[AppIndex].WindowClasses,
        AInfo.WindowClass, AInfo.WindowTitle);

    case Res of
        wfrPass, wfrDisabled:
            begin
                AStatus := TUIStateLoader.GetMessage('Settings.ProfilePreviewPass');
                Result := 0;
            end;
        wfrBlockedByInclude:
            begin
                AStatus := TUIStateLoader.GetMessage('Settings.ProfilePreviewBlockedInclude');
                Result := 1;
            end;
        wfrBlockedByExclude:
            begin
                AStatus := TUIStateLoader.GetMessage('Settings.ProfilePreviewBlockedExclude');
                Result := 1;
            end;
    else
        begin
            AStatus := TUIStateLoader.GetMessage('Settings.ProfilePreviewBlockedClass');
            Result := 1;
        end;
    end;
end;

procedure TWindowFilterDiagnosticsDialog.BuildTable(AForce: Boolean);
var
    Raw: TArray<TWindowMonitorInfo>;
    Info: TWindowMonitorInfo;
    Item: TListItem;
    StatusText: string;
    Verdict: Integer;
    I, Total, Blocked: Integer;
    SelExe, SelTitle, Signature: string;
    SB: TStringBuilder;
begin
    if Assigned(GWinMonitor) then
        Raw := GWinMonitor.GetVisibleWindowsInfo
    else
        Raw := nil;

    // Подпись состояния: окна и вердикты не менялись - пересборка не нужна,
    // выбор и скролл списка остаются нетронутыми
    SB := TStringBuilder.Create;
    try
        for Info in Raw do
        begin
            Verdict := RowVerdict(Info, StatusText);
            if Verdict < 0 then
                Continue;
            SB.Append(Info.ExeName).Append(#1).Append(Info.WindowTitle).Append(#1)
                .Append(Info.WindowClass).Append(#1).Append(StatusText).Append(#2);
        end;
        Signature := BoolToStr(chkAllProcesses.Checked, True) + '|' + SB.ToString;
        if (not AForce) and (Signature = FLastSignature) then
            Exit;
        FLastSignature := Signature;
    finally
        SB.Free;
    end;

    // Выбор запоминаем и восстанавливаем после пересборки
    SelExe := '';
    SelTitle := '';
    if lvTable.Selected <> nil then
    begin
        SelExe := lvTable.Selected.Caption;
        SelTitle := lvTable.Selected.SubItems[0];
    end;

    Total := 0;
    Blocked := 0;

    lvTable.Items.BeginUpdate;
    try
        lvTable.Items.Clear;

        for Info in Raw do
        begin
            Verdict := RowVerdict(Info, StatusText);
            if Verdict < 0 then
                Continue;

            Inc(Total);
            if Verdict = 1 then
                Inc(Blocked);

            Item := lvTable.Items.Add;
            Item.Caption := Info.ExeName;
            Item.SubItems.Add(Info.WindowTitle);
            Item.SubItems.Add(Info.WindowClass);
            Item.SubItems.Add(StatusText);
            Item.Data := Pointer(Verdict);
        end;
    finally
        lvTable.Items.EndUpdate;
    end;

    if SelTitle <> '' then
        for I := 0 to lvTable.Items.Count - 1 do
            if SameText(lvTable.Items[I].Caption, SelExe)
                and (lvTable.Items[I].SubItems[0] = SelTitle) then
            begin
                lvTable.Items[I].Selected := True;
                lvTable.Items[I].MakeVisible(False);
                Break;
            end;

    // Автоподбор ширин: колонки по содержимому, последняя до края,
    // без горизонтальной прокрутки
    FColFitter.Fit;

    lbSummary.Caption := TUIStateLoader.GetMessage('Settings.DiagSummary', [Total, Blocked]);

    lbTableEmpty.Visible := Total = 0;
    if lbTableEmpty.Visible then
        lbTableEmpty.Caption := TUIStateLoader.GetMessage('Settings.DiagNoWindows');
end;

procedure TWindowFilterDiagnosticsDialog.RefreshTable;
begin
    BuildTable(True);
end;

procedure TWindowFilterDiagnosticsDialog.bRefreshClick(Sender: TObject);
begin
    RefreshTable;
end;

procedure TWindowFilterDiagnosticsDialog.chkAllProcessesClick(Sender: TObject);
begin
    BuildTable(True);
end;

procedure TWindowFilterDiagnosticsDialog.FormKeyDown(Sender: TObject;
    var Key: Word; Shift: TShiftState);
begin
    // Отдельной кнопки закрытия нет: Esc закрывает экран
    if Key = VK_ESCAPE then
        ModalResult := mrCancel;
end;

procedure TWindowFilterDiagnosticsDialog.ttAutoRefreshTimer(Sender: TObject);
begin
    BuildTable(False);
end;

procedure TWindowFilterDiagnosticsDialog.lvTableDblClick(Sender: TObject);
var
    Item: TListItem;
    AppProfile: TAllowedApplicationsItem;
    I, AppIndex: Integer;
begin
    Item := lvTable.Selected;
    if Item = nil then
        Exit;

    // Серые строки (процесс вне whitelist'а) отсюда не редактируются
    AppIndex := -1;
    for I := 0 to High(FApps) do
        if FApps[I].Enabled and SameText(FApps[I].ExeName, Item.Caption) then
        begin
            AppIndex := I;
            Break;
        end;
    if AppIndex < 0 then
        Exit;

    AppProfile := FApps[AppIndex];
    if TWindowProfileDialog.Execute(Self, AppContext, AppProfile.ExeName, AppProfile) then
    begin
        FApps[AppIndex] := AppProfile;
        BuildTable(True);
    end;
end;

procedure TWindowFilterDiagnosticsDialog.lvTableCustomDrawItem(Sender: TCustomListView;
    Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
begin
    // Красным - отсеянные фильтрами, серым - процессы вне whitelist'а
    case NativeUInt(Item.Data) of
        1: Sender.Canvas.Font.Color := clRed;
        2: Sender.Canvas.Font.Color := clGrayText;
    else
        Sender.Canvas.Font.Color := clWindowText;
    end;
end;

end.
