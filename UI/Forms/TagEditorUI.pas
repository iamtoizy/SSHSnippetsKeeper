unit TagEditorUI;

interface

uses
    Winapi.Windows,
    System.SysUtils,
    System.Classes,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.Dialogs,
    Vcl.ComCtrls,
    Vcl.StdCtrls,
    Vcl.ExtCtrls,
    Vcl.Menus,
    System.Generics.Collections,
    Core.Interfaces;

type
    TTagEditAction = (teaAdd, teaRename, teaDelete);

    TTagChange = record
        Action: TTagEditAction;
        TagID: Integer;   // Для Rename/Delete
        NewName: string;     // Для Add/Rename
    end;

    TTagEditorForm = class(TForm)
        pBottom: TPanel;
        bOK: TButton;
        bCancel: TButton;
        lvTags: TListView;
        MainMenu: TMainMenu;
        nActions: TMenuItem;
        nAdd: TMenuItem;
        nDelete: TMenuItem;
        nRename: TMenuItem;
        procedure bOKClick(Sender: TObject);
        procedure bCancelClick(Sender: TObject);
        procedure nAddClick(Sender: TObject);
        procedure nDeleteClick(Sender: TObject);
        procedure nRenameClick(Sender: TObject);
        procedure lvTagsEdited(Sender: TObject; Item: TListItem; var S: string);
        procedure FormCreate(Sender: TObject);
        procedure FormDestroy(Sender: TObject);
    private
        FTagService: ITagService;
        FChanges: TList<TTagChange>;

        procedure ApplyChangesToDB;
        procedure RecordChange(Action: TTagEditAction; TagID: Integer; const NewName: string = '');
        procedure DoAddTag;
        procedure DoDeleteTags;
        procedure DoRenameTag;
        procedure RefreshTagList;
    public
        // Внедрение зависимости (Dependency Injection) через конструктор
        constructor Create(Owner: TComponent; TagService: ITagService); reintroduce;
    end;

var
    TagEditorForm: TTagEditorForm;

implementation

{$R *.dfm}

uses
    Tag,
    UIHelpers,
    System.UITypes,
    Winapi.CommCtrl;

constructor TTagEditorForm.Create(Owner: TComponent; TagService: ITagService);
begin
    inherited Create(Owner);
    FTagService := TagService;
end;

procedure TTagEditorForm.FormCreate(Sender: TObject);
begin
    FChanges := TList<TTagChange>.Create;
    // Загружаем теги при создании формы, если сервис уже передан
    RefreshTagList;
end;

procedure TTagEditorForm.FormDestroy(Sender: TObject);
begin
    FChanges.Free;
end;

procedure TTagEditorForm.RefreshTagList;
var
    Tags: TArray<TTagDTO>;
begin
    if Assigned(FTagService) then
    begin
        Tags := FTagService.GetAllTags;
        TUIHelpers.FillTagList(lvTags, Tags);
    end;
end;

procedure TTagEditorForm.RecordChange(Action: TTagEditAction; TagID: Integer; const NewName: string);
var
    Change: TTagChange;
begin
    Change.Action := Action;
    Change.TagID := TagID;
    Change.NewName := NewName;
    FChanges.Add(Change);
end;

procedure TTagEditorForm.DoAddTag;
var
    NewName: string;
    Item: TListItem;
begin
    if InputQuery('Новый тег', 'Введите имя тега:', NewName) and (Trim(NewName) <> '') then
    begin
        NewName := Trim(NewName);

        // Визуальное добавление
        Item := lvTags.Items.Add;
        Item.Caption := NewName;
        Item.Data := Pointer(0); // ID пока нет, будет присвоен при сохранении в ApplyChangesToDB
        Item.Selected := True;
        Item.MakeVisible(False);
        Item.StateIndex := 0;

        // Записываем в буфер изменений
        RecordChange(teaAdd, 0, NewName);
    end;
end;

procedure TTagEditorForm.DoDeleteTags;
var
    Dlg: TForm;
    I: Integer;
    TagID: Integer;
begin
    if lvTags.SelCount = 0 then
        Exit;

    Dlg := CreateMessageDialog(Format('Удалить выбранные теги (%d шт.)?', [lvTags.SelCount]), mtConfirmation, [mbYes, mbNo]);
    try
        Dlg.Caption := 'Подтверждение удаления';
        if Dlg.ShowModal <> mrYes then
            Exit;
    finally
        Dlg.Free;
    end;

    // Удаление с конца, чтобы индексы не съезжали
    for I := lvTags.Items.Count - 1 downto 0 do
    begin
        if lvTags.Items[I].Selected then
        begin
            TagID := Integer(lvTags.Items[I].Data);
            if TagID > 0 then
                RecordChange(teaDelete, TagID);
            lvTags.Items.Delete(I);
        end;
    end;

    // Принудительное перестроение расположения иконок
    SendMessage(lvTags.Handle, LVM_ARRANGE, LVA_DEFAULT, 0);
end;

procedure TTagEditorForm.DoRenameTag;
begin
    if (lvTags.SelCount <> 1) then
    begin
        MessageBeep(MB_ICONWARNING);
        Exit;
    end;

    if (lvTags.Selected <> nil) then
        lvTags.Selected.EditCaption;
end;

procedure TTagEditorForm.nAddClick(Sender: TObject);
begin
    DoAddTag;
end;

procedure TTagEditorForm.nDeleteClick(Sender: TObject);
begin
    DoDeleteTags;
end;

procedure TTagEditorForm.nRenameClick(Sender: TObject);
begin
    DoRenameTag;
end;

procedure TTagEditorForm.lvTagsEdited(Sender: TObject; Item: TListItem; var S: string);
var
    TagID: Integer;
begin
    S := Trim(S);

    // Если имя пустое или не изменилось - откатываем
    if (S = '') or (S = Item.Caption) then
    begin
        S := Item.Caption;
        Exit;
    end;

    TagID := Integer(Item.Data);

    // Записываем переименование в буфер только если тег уже есть в БД
    if TagID > 0 then
        RecordChange(teaRename, TagID, S);

    // Визуально Caption обновится автоматически
end;

procedure TTagEditorForm.bOKClick(Sender: TObject);
begin
    try
        ApplyChangesToDB;
        ModalResult := mrOk;
    except
        on E: Exception do
            MessageDlg('Ошибка сохранения тегов: ' + E.Message, mtError, [mbOK], 0);
    end;
end;

procedure TTagEditorForm.bCancelClick(Sender: TObject);
begin
    // Просто закрываем, FChanges уничтожится в FormDestroy без применения
    ModalResult := mrCancel;
end;

procedure TTagEditorForm.ApplyChangesToDB;
var
    Change: TTagChange;
begin
    if not Assigned(FTagService) then
        raise Exception.Create('Сервис тегов не инициализирован!');

    for Change in FChanges do
    begin
        case Change.Action of
            teaAdd:
                // Сервис сам проверит уникальность и пустоту имени
                FTagService.CreateTag(Change.NewName, '');

            teaRename:
                // Передаем ID (с приведением типов) и новое имя
                FTagService.RenameTag(Integer(Change.TagID), Change.NewName);

            teaDelete:
                FTagService.DeleteTag(Integer(Change.TagID));
        end;
    end;

    FChanges.Clear;
end;

end.

