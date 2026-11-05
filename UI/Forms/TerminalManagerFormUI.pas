unit TerminalManagerFormUI;

interface

uses
    BaseFormUI,
    System.Classes,
    System.SysUtils,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.StdCtrls,
    WindowMonitor
    ;

type
    TTerminalManagerForm = class(TBaseForm)
        pTop: TPanel;
        ebFilter: TEdit;
        bSelectAll: TButton;
        bClearHistory: TButton;
        lvWindows: TListView;
        pBottom: TPanel;
        bApply: TButton;
        bCancel: TButton;
        lbStatus: TLabel;
        procedure FormShow(Sender: TObject);
        procedure ebFilterChange(Sender: TObject);
        procedure bSelectAllClick(Sender: TObject);
        procedure bClearHistoryClick(Sender: TObject);
        procedure bApplyClick(Sender: TObject);
        procedure lvItemDblClick(Sender: TObject);
        procedure lvItemChecked(Sender: TObject; Item: TListItem);
    private
        FOpenWindows: TArray<TWindowMonitorInfo>;
        FHistory: TArray<TWindowMonitorInfo>;
        FPopulating: Boolean;
        function ListViewHelpOffset(LV: TListView): Integer;
        procedure RefreshHistory;
        function FindInHistory(AHWND: THandle; out AInfo: TWindowMonitorInfo): Boolean;
        procedure PopulateList;
        procedure UpdateStatus;
        procedure ApplyChanges;
    protected
        procedure DoInitialize; override;
    end;

var
    TerminalManagerForm: TTerminalManagerForm;

implementation

uses
    Common.Localization,
    System.Math,
    UI.HoverHelpManager,
    Winapi.CommCtrl,
    Winapi.Windows
    ;

{$R *.dfm}

{ Самодокументирование: плавающая кнопка справки при наведении на список.
  Сдвиг вниз - ниже строки заголовков колонок, чтобы не наезжала на неё }
procedure TTerminalManagerForm.DoInitialize;
begin
    inherited;
    RegisterHelp(lvWindows, hipTopRight, 'Help.TerminalManager.lvWindows',
        hkCustomForm, 0, ListViewHelpOffset(lvWindows));
end;

{ Высота строки заголовков ListView в координатах 96 DPI (паттерн
  ChainEditorForm/TagSelectDialog/SequenceOrderDialog) }
function TTerminalManagerForm.ListViewHelpOffset(LV: TListView): Integer;
var
    HeaderWnd: HWND;
    R: TRect;
begin
    Result := 2;
    HeaderWnd := FindWindowEx(LV.Handle, 0, 'SysHeader32', nil);
    if (HeaderWnd = 0) or not GetWindowRect(HeaderWnd, R) then
        Exit;
    Result := Max(1, MulDiv(R.Bottom - R.Top, 96, LV.CurrentPPI)) + 2;
end;

procedure TTerminalManagerForm.FormShow(Sender: TObject);
begin
    // Перечисление делаем в момент показа: снимок открытых окон сессии,
    // история могла измениться с прошлого открытия
    FOpenWindows := GWinMonitor.GetOpenAllowedWindows;
    RefreshHistory;
    PopulateList;
end;

procedure TTerminalManagerForm.ebFilterChange(Sender: TObject);
begin
    PopulateList;
end;

{ Снимок истории на момент открытия: по нему расставляются чекбоксы.
  Перед применением снимок перечитывается - хук мог добавить окна,
  пока диалог был открыт }
procedure TTerminalManagerForm.RefreshHistory;
begin
    FHistory := GWinMonitor.GetAllowedWindowsHistory;
end;

function TTerminalManagerForm.FindInHistory(AHWND: THandle; out AInfo: TWindowMonitorInfo): Boolean;
var
    I: Integer;
begin
    Result := False;
    for I := 0 to High(FHistory) do
        if FHistory[I].HWND = AHWND then
        begin
            AInfo := FHistory[I];
            Exit(True);
        end;
end;

procedure TTerminalManagerForm.PopulateList;
var
    I: Integer;
    Filter: string;
    Info, HistInfo: TWindowMonitorInfo;
    Item: TListItem;
begin
    Filter := Trim(ebFilter.Text).ToLower;

    lvWindows.Items.BeginUpdate;
    FPopulating := True;
    try
        lvWindows.Items.Clear;

        for I := 0 to High(FOpenWindows) do
        begin
            Info := FOpenWindows[I];

            if (Filter <> '')
                and (Pos(Filter, Info.WindowTitle.ToLower) = 0)
                and (Pos(Filter, Info.ExeName.ToLower) = 0) then
                Continue;

            Item := lvWindows.Items.Add;
            Item.Caption := Info.WindowTitle;
            Item.SubItems.Add(Info.ExeName);

            if FindInHistory(Info.HWND, HistInfo) then
            begin
                Item.Checked := True;
                Item.SubItems.Add(FormatDateTime('hh:nn:ss', HistInfo.ActivatedAt));
            end
            else
            begin
                Item.Checked := False;
                Item.SubItems.Add('-');
            end;

            Item.Data := Pointer(I);
        end;
    finally
        FPopulating := False;
        lvWindows.Items.EndUpdate;
    end;

    // Для последней колонки LVSCW_AUTOSIZE_USEHEADER означает "заполнить
    // весь остаток клиентской области" (паттерн диалога выбора терминала)
    if lvWindows.HandleAllocated and (lvWindows.Columns.Count > 0) then
        ListView_SetColumnWidth(lvWindows.Handle,
            lvWindows.Columns.Count - 1, LVSCW_AUTOSIZE_USEHEADER);

    UpdateStatus;
end;

procedure TTerminalManagerForm.UpdateStatus;
var
    I, Remembered: Integer;
begin
    if Length(FOpenWindows) = 0 then
        lbStatus.Caption := TUIStateLoader.GetMessage('TermManager.NoOpenWindows')
    else
    begin
        Remembered := 0;
        for I := 0 to lvWindows.Items.Count - 1 do
            if lvWindows.Items[I].Checked then
                Inc(Remembered);

        lbStatus.Caption := TUIStateLoader.GetMessage('TermManager.Status',
            [lvWindows.Items.Count, Remembered]);
    end;
end;

procedure TTerminalManagerForm.lvItemDblClick(Sender: TObject);
var
    LV: TListView;
begin
    LV := Sender as TListView;
    if LV.Selected <> nil then
        LV.Selected.Checked := not LV.Selected.Checked;
end;

procedure TTerminalManagerForm.lvItemChecked(Sender: TObject; Item: TListItem);
begin
    if not FPopulating then
        UpdateStatus;
end;

procedure TTerminalManagerForm.bSelectAllClick(Sender: TObject);
var
    I: Integer;
begin
    for I := 0 to lvWindows.Items.Count - 1 do
        lvWindows.Items[I].Checked := True;
end;

procedure TTerminalManagerForm.bClearHistoryClick(Sender: TObject);
begin
    // Немедленное действие: снимок истории сбрасывается сразу,
    // чекбоксы в списке обновляются
    GWinMonitor.ClearHistory;
    RefreshHistory;
    PopulateList;
end;

{ Дифф по списку: чекбокс снят - окно забывается, поставлен -
  регистрируется (с повторной валидацией: окно могли закрыть,
  пока диалог был открыт) }
procedure TTerminalManagerForm.ApplyChanges;
var
    I: Integer;
    Info, HistInfo: TWindowMonitorInfo;
begin
    RefreshHistory;

    for I := 0 to lvWindows.Items.Count - 1 do
    begin
        Info := FOpenWindows[Integer(lvWindows.Items[I].Data)];

        if lvWindows.Items[I].Checked then
        begin
            if not FindInHistory(Info.HWND, HistInfo) then
                GWinMonitor.RegisterWindow(Info.HWND);
        end
        else
            GWinMonitor.RemoveWindow(Info.HWND);
    end;
end;

procedure TTerminalManagerForm.bApplyClick(Sender: TObject);
begin
    ApplyChanges;
end;

end.
