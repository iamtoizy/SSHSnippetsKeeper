unit WindowClassPickerDialogUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    System.Classes,
    System.Generics.Collections,
    System.Generics.Defaults,
    System.SysUtils,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls
    ;

type
    TWindowClassEntry = record
        ExeName: string;
        WindowClass: string;
        WindowTitle: string;
    end;

    // Пикер классов окон всех видимых окон системы: пользователь выбирает
    // классы галочками, не выясняя их сторонними утилитами
    TWindowClassPickerDialog = class(TBaseForm)
        pTop: TPanel;
        ebFilter: TEdit;
        lvClasses: TListView;
        pBottom: TPanel;
        bAdd: TButton;
        bCancel: TButton;
        lbStatus: TLabel;
        procedure FormShow(Sender: TObject);
        procedure ebFilterChange(Sender: TObject);
        procedure lvItemDblClick(Sender: TObject);
    private
        FEntries: TArray<TWindowClassEntry>;
        procedure PopulateList(const AFilter: string);
        procedure UpdateStatus;
        function CollectCheckedClasses: TArray<string>;
    public
        class function Execute(AOwner: TComponent; AppContext: IAppContext): TArray<string>;
    end;

var
    WindowClassPickerDialog: TWindowClassPickerDialog;

implementation

uses
    Common.Localization,
    WindowMonitor
    ;

{$R *.dfm}

class function TWindowClassPickerDialog.Execute(AOwner: TComponent; AppContext: IAppContext): TArray<string>;
var
    Instance: TWindowClassPickerDialog;
begin
    Result := nil;
    Instance := TWindowClassPickerDialog.Create(AOwner);
    try
        Instance.Initialize(AppContext);
        Instance.WarmUpPaint;
        Instance.PrepareGuardedShow;
        if Instance.ShowModal = mrOk then
            Result := Instance.CollectCheckedClasses;
    finally
        Instance.Free;
    end;
end;

procedure TWindowClassPickerDialog.FormShow(Sender: TObject);
var
    Raw: TArray<TWindowMonitorInfo>;
    Known: TDictionary<string, Boolean>;
    I: Integer;
    Info: TWindowMonitorInfo;
    Key: string;
begin
    Caption := TUIStateLoader.GetMessage('WindowClassPicker.Title');
    ebFilter.TextHint := TUIStateLoader.GetMessage('WindowClassPicker.FilterHint');
    lvClasses.Columns[0].Caption := TUIStateLoader.GetMessage('WindowClassPicker.ColumnProcess');
    lvClasses.Columns[1].Caption := TUIStateLoader.GetMessage('WindowClassPicker.ColumnClass');
    lvClasses.Columns[2].Caption := TUIStateLoader.GetMessage('WindowClassPicker.ColumnTitle');
    bAdd.Caption := TUIStateLoader.GetMessage('WindowClassPicker.AddChecked');
    bCancel.Caption := TUIStateLoader.GetMessage('Common.Cancel');

    FEntries := nil;
    if Assigned(GWinMonitor) then
    begin
        Raw := GWinMonitor.GetVisibleWindowsInfo;
        Known := TDictionary<string, Boolean>.Create;
        try
            for I := 0 to High(Raw) do
            begin
                Info := Raw[I];
                Key := Info.WindowClass.ToLower + '|' + Info.ExeName.ToLower;
                if Known.ContainsKey(Key) then
                    Continue;
                Known.Add(Key, True);

                SetLength(FEntries, Length(FEntries) + 1);
                FEntries[High(FEntries)].ExeName := Info.ExeName;
                FEntries[High(FEntries)].WindowClass := Info.WindowClass;
                FEntries[High(FEntries)].WindowTitle := Info.WindowTitle;
            end;
        finally
            Known.Free;
        end;
    end;

    // Стабильный порядок: процесс, затем класс окна
    TArray.Sort<TWindowClassEntry>(FEntries, TComparer<TWindowClassEntry>.Construct(
        function(const L, R: TWindowClassEntry): Integer
        begin
            Result := CompareText(L.ExeName, R.ExeName);
            if Result = 0 then
                Result := CompareText(L.WindowClass, R.WindowClass);
        end));

    PopulateList('');
    UpdateStatus;
end;

procedure TWindowClassPickerDialog.ebFilterChange(Sender: TObject);
begin
    PopulateList(LowerCase(ebFilter.Text));
    UpdateStatus;
end;

procedure TWindowClassPickerDialog.PopulateList(const AFilter: string);
var
    I: Integer;
    Entry: TWindowClassEntry;
    Item: TListItem;
begin
    lvClasses.Items.BeginUpdate;
    try
        lvClasses.Items.Clear;

        for I := 0 to High(FEntries) do
        begin
            Entry := FEntries[I];

            if (AFilter <> '')
                and (Pos(AFilter, Entry.ExeName.ToLower) = 0)
                and (Pos(AFilter, Entry.WindowClass.ToLower) = 0)
                and (Pos(AFilter, Entry.WindowTitle.ToLower) = 0) then
                Continue;

            Item := lvClasses.Items.Add;
            Item.Caption := Entry.ExeName;
            Item.SubItems.Add(Entry.WindowClass);
            Item.SubItems.Add(Entry.WindowTitle);
            Item.Data := Pointer(I);
        end;
    finally
        lvClasses.Items.EndUpdate;
    end;

    // LVSCW_AUTOSIZE_USEHEADER: заголовок - по содержимому, последний - до края
    for I := 0 to lvClasses.Columns.Count - 1 do
        lvClasses.Columns[I].Width := -2;
end;

procedure TWindowClassPickerDialog.lvItemDblClick(Sender: TObject);
var
    LV: TListView;
begin
    LV := Sender as TListView;
    if LV.Selected <> nil then
        LV.Selected.Checked := not LV.Selected.Checked;
end;

procedure TWindowClassPickerDialog.UpdateStatus;
begin
    lbStatus.Caption := TUIStateLoader.GetMessage('WindowClassPicker.Found', [Length(FEntries)]);
end;

function TWindowClassPickerDialog.CollectCheckedClasses: TArray<string>;
var
    I: Integer;
    Known: TDictionary<string, Boolean>;
    C, Key: string;
begin
    Result := nil;
    Known := TDictionary<string, Boolean>.Create;
    try
        for I := 0 to lvClasses.Items.Count - 1 do
            if lvClasses.Items[I].Checked then
            begin
                C := FEntries[Integer(lvClasses.Items[I].Data)].WindowClass;
                Key := C.ToLower;
                if not Known.ContainsKey(Key) then
                begin
                    Known.Add(Key, True);
                    SetLength(Result, Length(Result) + 1);
                    Result[High(Result)] := C;
                end;
            end;
    finally
        Known.Free;
    end;
end;

end.
