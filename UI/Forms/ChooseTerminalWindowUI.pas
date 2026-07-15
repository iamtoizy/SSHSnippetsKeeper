unit ChooseTerminalWindowUI;

interface

uses
    System.SysUtils,
    System.Classes,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.ComCtrls,
    WindowMonitor;

type
    TChooseTerminalWindow = class(TForm)
        lvTerminalList: TListView;
        sbBottom: TStatusBar;
        procedure lvTerminalListDblClick(Sender: TObject);
        procedure FormShow(Sender: TObject);
        procedure FormCreate(Sender: TObject);
    private
        { Private declarations }
        FSelectedWindow: TWindowMonitorInfo;
        FWindows: TArray<TWindowMonitorInfo>;
        procedure PopulateList;
    public
        { Public declarations }
        property SelectedWindow: TWindowMonitorInfo read FSelectedWindow;
    end;

var
    ChooseTerminalWindow: TChooseTerminalWindow;

implementation

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
        sbBottom.SimpleText := 'История пуста. Сначала активируйте окно терминала.';
        Exit;
    end;

    sbBottom.SimpleText := Format('Найдено %d окон терминала. Выберите целевое окно:', [Length(FWindows)]);

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

