unit WindowProfileDialogUI;

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
    Vcl.Graphics,
    Vcl.StdCtrls
    ;

type
    // Профиль окна разрешённого приложения: классы окон и regex заголовков.
    // Список внизу - живое превью: как фильтры заголовков применятся
    // к открытым сейчас окнам этого процесса
    TWindowProfileDialog = class(TBaseForm)
        lblAppName: TLabel;
        leInclude: TLabeledEdit;
        bBuildInclude: TButton;
        leExclude: TLabeledEdit;
        bBuildExclude: TButton;
        leClasses: TLabeledEdit;
        bPickClass: TButton;
        lbHint: TLabel;
        lvPreview: TListView;
        lblPreviewStats: TLabel;
        lbPreviewEmpty: TLabel;
        pBottom: TPanel;
        bOK: TButton;
        bCancel: TButton;
        procedure bOKClick(Sender: TObject);
        procedure bPickClassClick(Sender: TObject);
        procedure bBuildIncludeClick(Sender: TObject);
        procedure bBuildExcludeClick(Sender: TObject);
        procedure leIncludeChange(Sender: TObject);
        procedure leExcludeChange(Sender: TObject);
        procedure leClassesChange(Sender: TObject);
        procedure lvPreviewCustomDrawItem(Sender: TCustomListView; Item: TListItem;
            State: TCustomDrawState; var DefaultDraw: Boolean);
    private
        FExeName: string;
        FColFitter: TListViewColumnFitter;
        procedure ApplyToProfile(var AProfile: TAllowedApplicationsItem);
        function ClassesTextToClasses: TArray<string>;
        function IsValidRegex(const APattern: string): Boolean;
        procedure AppendPickedClasses(const APicked: TArray<string>);
        procedure RefreshPreview;
    public
        class function Execute(AOwner: TComponent; AppContext: IAppContext; const AExeName: string; var AProfile: TAllowedApplicationsItem): Boolean;
    end;

var
    WindowProfileDialog: TWindowProfileDialog;

implementation

uses
    Common.Localization,
    Common.RegexSafety,
    ProcessProfile,
    WindowClassPickerDialogUI,
    WindowDenyBuilderUI,
    WindowMonitor
    ;

{$R *.dfm}

class function TWindowProfileDialog.Execute(AOwner: TComponent; AppContext: IAppContext; const AExeName: string; var AProfile: TAllowedApplicationsItem): Boolean;
var
    Instance: TWindowProfileDialog;
    C: string;
    SB: TStringBuilder;
begin
    Result := False;
    Instance := TWindowProfileDialog.Create(AOwner);
    try
        Instance.Initialize(AppContext);

        Instance.FExeName := AExeName;
        Instance.Caption := TUIStateLoader.GetMessage('Settings.ApplicationsProfileTitle', [AExeName]);
        Instance.lblAppName.Caption := AExeName;
        Instance.leInclude.EditLabel.Caption := TUIStateLoader.GetMessage('Settings.ApplicationsProfileInclude');
        Instance.leExclude.EditLabel.Caption := TUIStateLoader.GetMessage('Settings.ApplicationsProfileExclude');
        Instance.leClasses.EditLabel.Caption := TUIStateLoader.GetMessage('Settings.ApplicationsProfileClasses');
        Instance.lbHint.Caption := TUIStateLoader.GetMessage('Settings.ApplicationsProfileHint');
        Instance.bPickClass.Caption := TUIStateLoader.GetMessage('Settings.ProfilePickClassesButton');
        Instance.bBuildInclude.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesProfileBuildButton');
        Instance.bBuildExclude.Caption := TUIStateLoader.GetMessage('Settings.DenyRulesProfileBuildButton');
        Instance.bCancel.Caption := TUIStateLoader.GetMessage('Common.Cancel');
        Instance.lvPreview.Columns[0].Caption := TUIStateLoader.GetMessage('Settings.ProfilePreviewColumnTitle');
        Instance.lvPreview.Columns[1].Caption := TUIStateLoader.GetMessage('Settings.ProfilePreviewColumnClass');
        Instance.lvPreview.Columns[2].Caption := TUIStateLoader.GetMessage('Settings.ProfilePreviewColumnStatus');
        Instance.FColFitter := TListViewColumnFitter.Create(Instance, Instance.lvPreview);

        Instance.leInclude.Text := AProfile.TitleIncludeRegex;
        Instance.leExclude.Text := AProfile.TitleExcludeRegex;

        SB := TStringBuilder.Create;
        try
            for C in AProfile.WindowClasses do
            begin
                if SB.Length > 0 then
                    SB.Append(', ');
                SB.Append(C);
            end;
            Instance.leClasses.Text := SB.ToString;
        finally
            SB.Free;
        end;

        // Пустые фильтры не вызывают OnChange - первичное превью строим явно
        Instance.RefreshPreview;

        Instance.WarmUpPaint;
        Instance.PrepareGuardedShow;

        if Instance.ShowModal = mrOk then
        begin
            Instance.ApplyToProfile(AProfile);
            Result := True;
        end;
    finally
        Instance.Free;
    end;
end;

procedure TWindowProfileDialog.leIncludeChange(Sender: TObject);
begin
    RefreshPreview;
end;

procedure TWindowProfileDialog.leExcludeChange(Sender: TObject);
begin
    RefreshPreview;
end;

procedure TWindowProfileDialog.leClassesChange(Sender: TObject);
begin
    RefreshPreview;
end;

procedure TWindowProfileDialog.lvPreviewCustomDrawItem(Sender: TCustomListView;
    Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
begin
    // Блокируемые фильтрами строки красным: причина видна без чтения статуса
    if (Item <> nil) and (TWindowFilterResult(NativeUInt(Item.Data)) <> wfrPass) then
        Sender.Canvas.Font.Color := clRed
    else
        Sender.Canvas.Font.Color := clWindowText;
end;

procedure TWindowProfileDialog.RefreshPreview;
var
    Raw: TArray<TWindowMonitorInfo>;
    Info: TWindowMonitorInfo;
    Item: TListItem;
    IncludePattern, ExcludePattern, StatusText, StatsText: string;
    Classes: TArray<string>;
    Res: TWindowFilterResult;
    MatchedCount, PassCount, BlockedByInclude, BlockedByExclude, BlockedByClass: Integer;
begin
    IncludePattern := Trim(leInclude.Text);
    ExcludePattern := Trim(leExclude.Text);
    Classes := ClassesTextToClasses;

    // Некорректный regex на вводе: превью оставляем предыдущим,
    // ошибку покажет валидация по OK
    if (not IsValidRegex(IncludePattern)) or (not IsValidRegex(ExcludePattern)) then
        Exit;

    MatchedCount := 0;
    PassCount := 0;
    BlockedByInclude := 0;
    BlockedByExclude := 0;
    BlockedByClass := 0;

    lvPreview.Items.BeginUpdate;
    try
        lvPreview.Items.Clear;

        if Assigned(GWinMonitor) then
            Raw := GWinMonitor.GetVisibleWindowsInfo
        else
            Raw := nil;

        for Info in Raw do
        begin
            if not SameText(Info.ExeName, FExeName) then
                Continue;

            // Превью показывает эффект фильтров независимо от вкл/выкл профиля
            Res := TProcessProfile.EvaluateWindowFilters(True,
                IncludePattern, ExcludePattern, Classes,
                Info.WindowClass, Info.WindowTitle);

            Inc(MatchedCount);
            case Res of
                wfrPass:
                begin
                    Inc(PassCount);
                    StatusText := TUIStateLoader.GetMessage('Settings.ProfilePreviewPass');
                end;
                wfrBlockedByInclude:
                begin
                    Inc(BlockedByInclude);
                    StatusText := TUIStateLoader.GetMessage('Settings.ProfilePreviewBlockedInclude');
                end;
                wfrBlockedByExclude:
                begin
                    Inc(BlockedByExclude);
                    StatusText := TUIStateLoader.GetMessage('Settings.ProfilePreviewBlockedExclude');
                end;
            else
                begin
                    // wfrBlockedByClass (wfrDisabled в превью не возникает)
                    Inc(BlockedByClass);
                    StatusText := TUIStateLoader.GetMessage('Settings.ProfilePreviewBlockedClass');
                end;
            end;

            Item := lvPreview.Items.Add;
            Item.Caption := Info.WindowTitle;
            Item.SubItems.Add(Info.WindowClass);
            Item.SubItems.Add(StatusText);
            // Вердикт строки для раскраски (lvPreviewCustomDrawItem)
            Item.Data := Pointer(NativeUInt(Res));
        end;
    finally
        lvPreview.Items.EndUpdate;
    end;

    // Автоподбор ширин: колонки по содержимому, последняя до края,
    // без горизонтальной прокрутки
    FColFitter.Fit;

    // Счётчик: сколько окон процесса открыто и сколько пройдёт фильтры
    StatsText := TUIStateLoader.GetMessage('Settings.ProfilePreviewStats', [MatchedCount, PassCount]);
    if MatchedCount > PassCount then
        StatsText := StatsText + TUIStateLoader.GetMessage('Settings.ProfilePreviewStatsBlocked',
            [BlockedByInclude, BlockedByExclude, BlockedByClass]);
    lblPreviewStats.Caption := StatsText;

    // Ни одно из открытых окон не пройдёт - красным: макросу будет некуда вводить
    if (MatchedCount > 0) and (PassCount = 0) then
        lblPreviewStats.Font.Color := clRed
    else
        lblPreviewStats.Font.Color := clWindowText;

    // Нет окон процесса - превью недоступно; ни одно окно не проходит -
    // предупреждение: макросу будет некуда вводить
    lbPreviewEmpty.Visible := (MatchedCount = 0) or (PassCount = 0);

    if lbPreviewEmpty.Visible then
    begin
        if MatchedCount = 0 then
            lbPreviewEmpty.Caption := TUIStateLoader.GetMessage('Settings.ProfilePreviewNoWindows')
        else
            lbPreviewEmpty.Caption := TUIStateLoader.GetMessage('Settings.ProfilePreviewBlocksAll');
    end;
end;

procedure TWindowProfileDialog.bOKClick(Sender: TObject);
var
    Pattern: string;
begin
    Pattern := Trim(leInclude.Text);
    if not IsValidRegex(Pattern) then
    begin
        MessagesHandler.ShowError(TUIStateLoader.GetMessage('Settings.ApplicationsProfileInvalidRegex', [Pattern]));
        leInclude.SetFocus;
        Exit;
    end;

    Pattern := Trim(leExclude.Text);
    if not IsValidRegex(Pattern) then
    begin
        MessagesHandler.ShowError(TUIStateLoader.GetMessage('Settings.ApplicationsProfileInvalidRegex', [Pattern]));
        leExclude.SetFocus;
        Exit;
    end;

    ModalResult := mrOk;
end;

procedure TWindowProfileDialog.bPickClassClick(Sender: TObject);
begin
    AppendPickedClasses(TWindowClassPickerDialog.Execute(Self, AppContext));
end;

procedure TWindowProfileDialog.bBuildIncludeClick(Sender: TObject);
var
    NewPattern: string;
begin
    if TWindowDenyBuilderDialog.ExecuteSingle(Self, AppContext, leInclude.Text, NewPattern) then
    begin
        leInclude.Text := NewPattern;
        RefreshPreview;
    end;
end;

procedure TWindowProfileDialog.bBuildExcludeClick(Sender: TObject);
var
    NewPattern: string;
begin
    if TWindowDenyBuilderDialog.ExecuteSingle(Self, AppContext, leExclude.Text, NewPattern) then
    begin
        leExclude.Text := NewPattern;
        RefreshPreview;
    end;
end;

procedure TWindowProfileDialog.AppendPickedClasses(const APicked: TArray<string>);
var
    Merged: TArray<string>;
    SB: TStringBuilder;
    C, M: string;
    Exists: Boolean;
begin
    if Length(APicked) = 0 then
        Exit;

    Merged := ClassesTextToClasses;
    for C in APicked do
    begin
        Exists := False;
        for M in Merged do
            if SameText(M, C) then
            begin
                Exists := True;
                Break;
            end;

        if not Exists then
        begin
            SetLength(Merged, Length(Merged) + 1);
            Merged[High(Merged)] := C;
        end;
    end;

    SB := TStringBuilder.Create;
    try
        for C in Merged do
        begin
            if SB.Length > 0 then
                SB.Append(', ');
            SB.Append(C);
        end;
        leClasses.Text := SB.ToString;
    finally
        SB.Free;
    end;
end;

function TWindowProfileDialog.IsValidRegex(const APattern: string): Boolean;
begin
    Result := TRegexSafety.PatternIsValid(APattern);
end;

function TWindowProfileDialog.ClassesTextToClasses: TArray<string>;
var
    S, Token: string;
    P, SepP, Count: Integer;
begin
    SetLength(Result, 0);
    Count := 0;
    S := leClasses.Text;

    while S <> '' do
    begin
        P := Pos(',', S);
        SepP := Pos(';', S);
        if (SepP > 0) and ((P = 0) or (SepP < P)) then
            P := SepP;

        if P = 0 then
        begin
            Token := Trim(S);
            S := '';
        end
        else
        begin
            Token := Trim(Copy(S, 1, P - 1));
            Delete(S, 1, P);
        end;

        if Token <> '' then
        begin
            Inc(Count);
            SetLength(Result, Count);
            Result[Count - 1] := Token;
        end;
    end;
end;

procedure TWindowProfileDialog.ApplyToProfile(var AProfile: TAllowedApplicationsItem);
begin
    AProfile.TitleIncludeRegex := Trim(leInclude.Text);
    AProfile.TitleExcludeRegex := Trim(leExclude.Text);
    AProfile.WindowClasses := ClassesTextToClasses;
end;

end.
