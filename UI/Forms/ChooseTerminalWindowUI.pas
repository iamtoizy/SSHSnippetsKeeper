unit ChooseTerminalWindowUI;

interface

uses
    BaseFormUI,
    Core.Interfaces,
    System.Classes,
    Vcl.ComCtrls,
    Vcl.Controls,
    WindowMonitor
    ;

type
    TChooseTerminalWindow = class(TBaseForm)
        lvTerminalList: TListView;
        sbBottom: TStatusBar;
        procedure lvTerminalListDblClick(Sender: TObject);
        procedure FormShow(Sender: TObject);
        procedure FormCreate(Sender: TObject);
    private
        FSelectedWindow: TWindowMonitorInfo;
        FWindows: TArray<TWindowMonitorInfo>;
        procedure PopulateList;
    public
        procedure Initialize(AppContext: IAppContext);
        property SelectedWindow: TWindowMonitorInfo read FSelectedWindow;
    end;

var
    ChooseTerminalWindow: TChooseTerminalWindow;

implementation

uses
    System.SysUtils,
    UI.StateLoader
    ;

{$R *.dfm}

procedure TChooseTerminalWindow.FormCreate(Sender: TObject);
begin
    FSelectedWindow.HWND := 0;
end;

procedure TChooseTerminalWindow.FormShow(Sender: TObject);
begin
    PopulateList;
    if lvTerminalList.Items.Count > 0 then
    begin
        lvTerminalList.ItemIndex := 0;
        lvTerminalList.SetFocus;
    end;
end;

procedure TChooseTerminalWindow.Initialize(AppContext: IAppContext);
begin
    inherited;
    FAppContext := AppContext;
end;

procedure TChooseTerminalWindow.lvTerminalListDblClick(Sender: TObject);
var
    Index: Integer;
begin
    // Подтверждение выбора здесь...
    if lvTerminalList.Selected <> nil then
    begin
        Index := Integer(lvTerminalList.Selected.Data);
        FSelectedWindow := FWindows[Index];
        ModalResult := mrOk;
    end;
end;

procedure TChooseTerminalWindow.PopulateList;
var
    I: Integer;
    Item: TListItem;
    WindowInfo: TWindowMonitorInfo;
begin
    lvTerminalList.Clear;
    FWindows := WinMonitor.GetAllowedWindowsHistory;

    if Length(FWindows) = 0 then
    begin
        sbBottom.SimpleText := TUIStateLoader.GetMessage('Terminal.HistoryEmpty');
        Exit;
    end;

    sbBottom.SimpleText := TUIStateLoader.GetMessage('Terminal.WindowsFound', [Length(FWindows)]);

    // Заполняем список (от новых к старым)
    for I := Length(FWindows) - 1 downto 0 do
    begin
        WindowInfo := FWindows[I];
        Item := lvTerminalList.Items.Add;
        Item.Caption := WindowInfo.WindowTitle;
        Item.SubItems.Add(WindowInfo.ExeName);
        Item.SubItems.Add(FormatDateTime('hh:nn:ss', WindowInfo.ActivatedAt));
        Item.Data := Pointer(I);  // Сохраняем индекс для быстрого доступа
    end;
end;

end.

