unit ChooseTerminalWindowUI;

interface

uses
    BaseFormUI,
    System.Classes,
    System.Generics.Collections,
    Vcl.Buttons,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.ImgList,
    Vcl.StdCtrls,
    Winapi.Windows,
    WindowMonitor
    ;

type
    TChooseTerminalWindow = class(TBaseForm)
        pTop: TPanel;
        ebFilter: TEdit;
        pViewButtons: TPanel;
        sbTiles: TSpeedButton;
        sbTable: TSpeedButton;
        lvTerminalList: TListView;
        sbBottom: TStatusBar;
        ilIcons: TImageList;
        ilSmallIcons: TImageList;
        procedure lvTerminalListDblClick(Sender: TObject);
        procedure lvTerminalListColumnClick(Sender: TObject; Column: TListColumn);
        procedure ViewButtonClick(Sender: TObject);
        procedure ebFilterChange(Sender: TObject);
        procedure FormShow(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure FormDestroy(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure FormKeyPress(Sender: TObject; var Key: Char);
    private
        FSelectedWindow: TWindowMonitorInfo;
        FWindows: TArray<TWindowMonitorInfo>;
        FIconCache: TDictionary<string, Integer>;
        FSmallIconCache: TDictionary<string, Integer>;
        FSearchText: string;
        FSearchTick: DWORD;
        FSortColumn: Integer;
        FSortAscending: Boolean;
        procedure PopulateList;
        function ResolveIconIndex(const ExePath: string; ASmall: Boolean): Integer;
        function MatchesFilter(const WindowInfo: TWindowMonitorInfo; const Filter: string): Boolean;
        function CompareWindows(Left, Right: Integer): Integer;
        procedure ConfirmSelection;
        procedure SelectByNumber(Index: Integer);
        procedure ApplyViewStyle(AITableView: Boolean);
        procedure SaveViewSetting(AITableView: Boolean);
        procedure UpdateColumnCaptions;
        procedure UpdateStatusText(AShownCount: Integer);
    public
        property SelectedWindow: TWindowMonitorInfo read FSelectedWindow;
    end;

var
    ChooseTerminalWindowForm: TChooseTerminalWindow;

implementation

uses
    Core.Interfaces.Settings,
    Common.Localization,
    System.Generics.Defaults,
    System.Math,
    System.SysUtils,
    Vcl.Graphics,
    Winapi.ShellAPI
    ;

{$R *.dfm}

procedure TChooseTerminalWindow.FormCreate(Sender: TObject);
begin
    FSelectedWindow.HWND := 0;
    FIconCache := TDictionary<string, Integer>.Create;
    FSmallIconCache := TDictionary<string, Integer>.Create;
    FSortColumn := -1;
    FSortAscending := True;

    // Подписи зависят от языка: заполняем из ресурсов.
    // FAppContext в FormCreate ещё nil (Initialize приходит позже),
    // поэтому настройки читаются в FormShow
    ebFilter.TextHint := TUIStateLoader.GetMessage('Terminal.FilterHint');
    sbTiles.Caption := TUIStateLoader.GetMessage('Terminal.ViewTiles');
    sbTable.Caption := TUIStateLoader.GetMessage('Terminal.ViewTable');
    UpdateColumnCaptions;
end;

procedure TChooseTerminalWindow.FormDestroy(Sender: TObject);
begin
    FreeAndNil(FIconCache);
    FreeAndNil(FSmallIconCache);
end;

procedure TChooseTerminalWindow.FormShow(Sender: TObject);
begin
    // Сохранённый режим отображения (False = плитки, как раньше)
    ApplyViewStyle(FAppContext.SettingsManager.Data.TerminalChooserTableView);
    PopulateList;
    if lvTerminalList.Items.Count > 0 then
        lvTerminalList.SetFocus;
end;

procedure TChooseTerminalWindow.lvTerminalListDblClick(Sender: TObject);
begin
    ConfirmSelection;
end;

procedure TChooseTerminalWindow.ConfirmSelection;
begin
    if lvTerminalList.Selected <> nil then
    begin
        FSelectedWindow := FWindows[Integer(lvTerminalList.Selected.Data)];
        ModalResult := mrOk;
    end;
end;

procedure TChooseTerminalWindow.SelectByNumber(Index: Integer);
begin
    if Index < lvTerminalList.Items.Count then
    begin
        lvTerminalList.ItemIndex := Index;
        FSelectedWindow := FWindows[Integer(lvTerminalList.Items[Index].Data)];
        ModalResult := mrOk;
    end;
end;

procedure TChooseTerminalWindow.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    case Key of
        VK_ESCAPE:
            begin
                Key := 0;
                ModalResult := mrCancel;
            end;
        VK_RETURN:
            begin
                Key := 0;
                if ActiveControl = ebFilter then
                begin
                    // Enter в фильтре: берём первую отфильтрованную строку
                    if lvTerminalList.Items.Count > 0 then
                        SelectByNumber(0);
                end
                else
                    ConfirmSelection;
            end;
        VK_DOWN:
            if ActiveControl = ebFilter then
            begin
                Key := 0;
                if lvTerminalList.Items.Count > 0 then
                    lvTerminalList.ItemIndex := 0;
                lvTerminalList.SetFocus;
            end;
        VK_UP:
            if (ActiveControl = lvTerminalList) and (lvTerminalList.ItemIndex <= 0) then
            begin
                Key := 0;
                ebFilter.SetFocus;
            end;
    end;
end;

procedure TChooseTerminalWindow.FormKeyPress(Sender: TObject; var Key: Char);
var
    Ch: Char;
begin
    // Инкрементальный поиск только при фокусе в списке: набираемое
    // попадает в тот же фильтр, что и поле ebFilter
    if ActiveControl <> lvTerminalList then
        Exit;

    if CharInSet(Key, ['1'..'9']) then
    begin
        SelectByNumber(Ord(Key) - Ord('1'));
        Key := #0;
        Exit;
    end;

    if Key = #8 then
    begin
        Key := #0;
        if FSearchText <> '' then
            SetLength(FSearchText, Length(FSearchText) - 1);
        FSearchTick := GetTickCount;
        ebFilter.Text := FSearchText;
        Exit;
    end;

    if Ord(Key) >= 32 then
    begin
        Ch := Key;
        Key := #0;
        // Пауза больше 800 мс - считаем набранное новой строкой поиска
        if GetTickCount - FSearchTick > DWORD(800) then
            FSearchText := '';
        FSearchText := FSearchText + Ch;
        FSearchTick := GetTickCount;
        ebFilter.Text := FSearchText;
    end;
end;

procedure TChooseTerminalWindow.ebFilterChange(Sender: TObject);
begin
    // Печатает и пользователь в поле, и инкрементальный поиск из списка
    if FSearchText <> ebFilter.Text then
        FSearchText := '';
    PopulateList;
end;

procedure TChooseTerminalWindow.ViewButtonClick(Sender: TObject);
begin
    SaveViewSetting(sbTable.Down);
    ApplyViewStyle(sbTable.Down);
    PopulateList;
end;

procedure TChooseTerminalWindow.ApplyViewStyle(AITableView: Boolean);
begin
    sbTable.Down := AITableView;
    sbTiles.Down := not AITableView;
    if AITableView then
        lvTerminalList.ViewStyle := vsReport
    else
        lvTerminalList.ViewStyle := vsTile;
end;

procedure TChooseTerminalWindow.SaveViewSetting(AITableView: Boolean);
var
    Settings: TAppSettings;
begin
    Settings := FAppContext.SettingsManager.Data;
    Settings.TerminalChooserTableView := AITableView;
    FAppContext.SettingsManager.Data := Settings;
    FAppContext.SettingsManager.Save;
end;

procedure TChooseTerminalWindow.lvTerminalListColumnClick(Sender: TObject; Column: TListColumn);
begin
    if Column.Index = FSortColumn then
        FSortAscending := not FSortAscending
    else
    begin
        FSortColumn := Column.Index;
        FSortAscending := True;
    end;
    UpdateColumnCaptions;
    PopulateList;
end;

procedure TChooseTerminalWindow.UpdateColumnCaptions;
const
    ColumnKeys: array[0..2] of string =
        ('Terminal.ColTitle', 'Terminal.ColProcess', 'Terminal.ColActivated');
var
    I: Integer;
    Caption: string;
begin
    for I := 0 to High(ColumnKeys) do
    begin
        Caption := TUIStateLoader.GetMessage(ColumnKeys[I]);
        if I = FSortColumn then
        begin
            if FSortAscending then
                Caption := Caption + ' ▲'
            else
                Caption := Caption + ' ▼';
        end;
        lvTerminalList.Columns[I].Caption := Caption;
    end;
end;

procedure TChooseTerminalWindow.UpdateStatusText(AShownCount: Integer);
begin
    if AShownCount < 0 then
        sbBottom.SimpleText := TUIStateLoader.GetMessage('Terminal.HistoryEmpty')
    else if AShownCount = 0 then
        sbBottom.SimpleText := TUIStateLoader.GetMessage('Terminal.FilterEmpty')
    else
        sbBottom.SimpleText := Format('%s   ·   %s',
            [TUIStateLoader.GetMessage('Terminal.WindowsCount', [AShownCount]),
             TUIStateLoader.GetMessage('Terminal.KeyboardHint')]);
end;

function TChooseTerminalWindow.MatchesFilter(const WindowInfo: TWindowMonitorInfo; const Filter: string): Boolean;
begin
    if Filter = '' then
        Exit(True);
    Result := (Pos(Filter, WindowInfo.WindowTitle.ToLower) > 0) or
        (Pos(Filter, WindowInfo.ExeName.ToLower) > 0);
end;

function TChooseTerminalWindow.CompareWindows(Left, Right: Integer): Integer;
begin
    case FSortColumn of
        0: Result := CompareText(FWindows[Left].WindowTitle, FWindows[Right].WindowTitle);
        1: Result := CompareText(FWindows[Left].ExeName, FWindows[Right].ExeName);
        2: Result := CompareValue(Double(FWindows[Left].ActivatedAt), Double(FWindows[Right].ActivatedAt));
    else
        Result := 0;
    end;
    if not FSortAscending then
        Result := -Result;
end;

function TChooseTerminalWindow.ResolveIconIndex(const ExePath: string; ASmall: Boolean): Integer;
var
    Info: TSHFileInfo;
    Icon: TIcon;
    Cache: TDictionary<string, Integer>;
    Key: string;
    Flags: Cardinal;
begin
    Key := LowerCase(ExePath);
    if ASmall then
    begin
        Cache := FSmallIconCache;
        Flags := SHGFI_SMALLICON;
    end
    else
    begin
        Cache := FIconCache;
        Flags := SHGFI_LARGEICON;
    end;
    if Cache.TryGetValue(Key, Result) then
        Exit;

    Result := -1;
    Icon := TIcon.Create;
    try
        FillChar(Info, SizeOf(Info), 0);
        // Иконка конкретного процесса - по пути его exe
        if ExePath <> '' then
            SHGetFileInfo(PChar(ExePath), 0, Info, SizeOf(Info), SHGFI_ICON or Flags);

        // Не извлеклась - стандартная иконка exe без чтения файла
        if Info.hIcon = 0 then
            SHGetFileInfo('placeholder.exe', FILE_ATTRIBUTE_NORMAL, Info, SizeOf(Info),
                SHGFI_ICON or Flags or SHGFI_USEFILEATTRIBUTES);

        if Info.hIcon <> 0 then
        begin
            Icon.Handle := Info.hIcon;
            // AddIcon кладёт копию в список, Icon.Free уничтожит оригинал HICON
            if ASmall then
                Result := ilSmallIcons.AddIcon(Icon)
            else
                Result := ilIcons.AddIcon(Icon);
        end;
    finally
        Icon.Free;
    end;

    Cache.AddOrSetValue(Key, Result);
end;

procedure TChooseTerminalWindow.PopulateList;
var
    Order: TArray<Integer>;
    Count: Integer;
    I, K, Index: Integer;
    Item: TListItem;
    WindowInfo: TWindowMonitorInfo;
    Filter: string;
begin
    Filter := Trim(ebFilter.Text).ToLower;

    lvTerminalList.Items.BeginUpdate;
    try
        lvTerminalList.Clear;
        FWindows := GWinMonitor.GetAllowedWindowsHistory;

        if Length(FWindows) = 0 then
        begin
            UpdateStatusText(-1);
            Exit;
        end;

        // Новые окна сверху (от конца истории к началу) + фильтр
        SetLength(Order, Length(FWindows));
        Count := 0;
        for I := Length(FWindows) - 1 downto 0 do
            if MatchesFilter(FWindows[I], Filter) then
            begin
                Order[Count] := I;
                Inc(Count);
            end;
        SetLength(Order, Count);

        // Сортировка по клику на колонку (режим таблицы)
        if (FSortColumn >= 0) and (Count > 1) then
            TArray.Sort<Integer>(Order, TComparer<Integer>.Construct(
                function(const Left, Right: Integer): Integer
                begin
                    Result := CompareWindows(Left, Right);
                end));

        for K := 0 to Count - 1 do
        begin
            Index := Order[K];
            WindowInfo := FWindows[Index];
            Item := lvTerminalList.Items.Add;
            Item.Caption := WindowInfo.WindowTitle;
            // Подпись плитки: процесс и время последней активации
            Item.SubItems.Add(Format('%s  ·  %s',
                [WindowInfo.ExeName, FormatDateTime('hh:nn:ss', WindowInfo.ActivatedAt)]));
            // В таблице - мелкие иконки, в плитках - крупные
            if lvTerminalList.ViewStyle = vsReport then
                Item.ImageIndex := ResolveIconIndex(WindowInfo.ExePath, True)
            else
                Item.ImageIndex := ResolveIconIndex(WindowInfo.ExePath, False);
            Item.Data := Pointer(Index);
        end;

        if Count > 0 then
            lvTerminalList.ItemIndex := 0;
        UpdateStatusText(Count);
    finally
        lvTerminalList.Items.EndUpdate;
    end;
end;

end.
