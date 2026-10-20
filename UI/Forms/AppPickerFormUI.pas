unit AppPickerFormUI;

interface

uses
    AppEnumerator,
    BaseFormUI,
    Core.Interfaces.App,
    System.Classes,
    System.SysUtils,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.StdCtrls
    ;

type
    TAppPickerForm = class(TBaseForm)
        pTop: TPanel;
        ebFilter: TEdit;
        pcSources: TPageControl;
        tsRunning: TTabSheet;
        lvRunning: TListView;
        tsRecent: TTabSheet;
        lvRecent: TListView;
        pBottom: TPanel;
        bAdd: TButton;
        bCancel: TButton;
        lbStatus: TLabel;
        procedure FormShow(Sender: TObject);
        procedure ebFilterChange(Sender: TObject);
        procedure pcSourcesChange(Sender: TObject);
        procedure lvItemDblClick(Sender: TObject);
    private
        FRunning: TArray<TAppEntry>;
        FRecent: TArray<TAppEntry>;
        procedure PopulateList(AList: TListView; const AEntries: TArray<TAppEntry>; const AFilter: string; const AUseLastRun: Boolean);
        procedure UpdateStatus;
        function CollectChecked: TArray<TAppEntry>;
    public
        class function Execute(AOwner: TComponent; AppContext: IAppContext): TArray<TAppEntry>;
    end;

var
    AppPickerForm: TAppPickerForm;

implementation

uses
    Common.Localization,
    System.Generics.Collections
    ;

{$R *.dfm}

class function TAppPickerForm.Execute(AOwner: TComponent; AppContext: IAppContext): TArray<TAppEntry>;
var
    Instance: TAppPickerForm;
begin
    Result := nil;
    Instance := TAppPickerForm.Create(AOwner);
    try
        Instance.Initialize(AppContext);
        Instance.WarmUpPaint;
        Instance.PrepareGuardedShow;
        if Instance.ShowModal = mrOk then
            Result := Instance.CollectChecked;
    finally
        Instance.Free;
    end;
end;

procedure TAppPickerForm.FormShow(Sender: TObject);
begin
    FRunning := GetRunningApplications;
    FRecent := GetRecentApplications;
    PopulateList(lvRunning, FRunning, '', False);
    PopulateList(lvRecent, FRecent, '', True);
    UpdateStatus;
end;

procedure TAppPickerForm.ebFilterChange(Sender: TObject);
var
    Filter: string;
begin
    Filter := LowerCase(ebFilter.Text);
    PopulateList(lvRunning, FRunning, Filter, False);
    PopulateList(lvRecent, FRecent, Filter, True);
    UpdateStatus;
end;

procedure TAppPickerForm.pcSourcesChange(Sender: TObject);
begin
    UpdateStatus;
end;

procedure TAppPickerForm.PopulateList(AList: TListView; const AEntries: TArray<TAppEntry>; const AFilter: string; const AUseLastRun: Boolean);
var
    I: Integer;
    Entry: TAppEntry;
    Item: TListItem;
begin
    AList.Items.BeginUpdate;
    try
        AList.Items.Clear;

        for I := 0 to High(AEntries) do
        begin
            Entry := AEntries[I];

            if (AFilter <> '')
                and (Pos(AFilter, Entry.ExeName.ToLower) = 0)
                and (Pos(AFilter, Entry.WindowTitle.ToLower) = 0)
                and (Pos(AFilter, Entry.FullPath.ToLower) = 0) then
                Continue;

            Item := AList.Items.Add;
            Item.Caption := Entry.ExeName;

            if AUseLastRun then
                Item.SubItems.Add(FormatDateTime('dd.mm.yyyy hh:nn', Entry.LastRun))
            else if Entry.WindowTitle <> '' then
                Item.SubItems.Add(Entry.WindowTitle)
            else
                Item.SubItems.Add(Entry.FullPath);

            Item.Data := Pointer(I);
        end;
    finally
        AList.Items.EndUpdate;
    end;
end;

procedure TAppPickerForm.UpdateStatus;
var
    IsRunning: Boolean;
    Count: Integer;
begin
    IsRunning := pcSources.ActivePage = tsRunning;

    if IsRunning then
        Count := Length(FRunning)
    else
        Count := Length(FRecent);

    if Count = 0 then
    begin
        if IsRunning then
            lbStatus.Caption := TUIStateLoader.GetMessage('AppPicker.RunningEmpty')
        else
            lbStatus.Caption := TUIStateLoader.GetMessage('AppPicker.RecentEmpty');
    end
    else
    begin
        if IsRunning then
            lbStatus.Caption := TUIStateLoader.GetMessage('AppPicker.RunningFound', [Count])
        else
            lbStatus.Caption := TUIStateLoader.GetMessage('AppPicker.RecentFound', [Count]);
    end;
end;

procedure TAppPickerForm.lvItemDblClick(Sender: TObject);
var
    LV: TListView;
begin
    LV := Sender as TListView;
    if LV.Selected <> nil then
        LV.Selected.Checked := not LV.Selected.Checked;
end;

function TAppPickerForm.CollectChecked: TArray<TAppEntry>;
var
    List: TList<TAppEntry>;
    Known: TDictionary<string, Boolean>;

    procedure TakeFrom(const AEntries: TArray<TAppEntry>; AList: TListView);
    var
        J: Integer;
        Key: string;
    begin
        for J := 0 to AList.Items.Count - 1 do
            if AList.Items[J].Checked then
            begin
                Key := AEntries[Integer(AList.Items[J].Data)].ExeName.ToLower;
                if not Known.ContainsKey(Key) then
                begin
                    Known.Add(Key, True);
                    List.Add(AEntries[Integer(AList.Items[J].Data)]);
                end;
            end;
    end;

begin
    List := TList<TAppEntry>.Create;
    Known := TDictionary<string, Boolean>.Create;
    try
        TakeFrom(FRunning, lvRunning);
        TakeFrom(FRecent, lvRecent);
        Result := List.ToArray;
    finally
        Known.Free;
        List.Free;
    end;
end;

end.
