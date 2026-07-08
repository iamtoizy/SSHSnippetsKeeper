unit TagEditorUI;

interface

uses
    Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
    Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus,
    System.Generics.Collections;

type
    TTagEditAction = (teaAdd, teaRename, teaDelete);

    TTagChange = record
        Action: TTagEditAction;
        TagID: NativeUInt;   // Для Rename/Delete
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
        procedure lvTagsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure lvTagsEdited(Sender: TObject; Item: TListItem; var S: string);
        procedure FormCreate(Sender: TObject);
        procedure FormDestroy(Sender: TObject);
    private
        FChanges: TList<TTagChange>;
        procedure ApplyChangesToDB;
        procedure RecordChange(AAction: TTagEditAction; ATagID: NativeUInt; const ANewName: string = '');
        procedure DoAddTag;
        procedure DoDeleteTags;
        procedure DoRenameTag;
    public
        { Public declarations }
    end;

var
    TagEditorForm: TTagEditorForm;

implementation

{$R *.dfm}

uses
    Tag,
    DataModule,
    UIHelpers,
    TagRepository,
    System.UITypes,
    Winapi.CommCtrl
    ;

procedure TTagEditorForm.FormCreate(Sender: TObject);
begin
    FChanges := TList<TTagChange>.Create;
    // Загружаем теги при создании формы
    TUIHelpers.BuildTagList(lvTags);
end;

procedure TTagEditorForm.FormDestroy(Sender: TObject);
begin
    FChanges.Free;
end;

procedure TTagEditorForm.RecordChange(AAction: TTagEditAction; ATagID: NativeUInt; const ANewName: string);
var
    Change: TTagChange;
begin
    Change.Action := AAction;
    Change.TagID := ATagID;
    Change.NewName := ANewName;
    FChanges.Add(Change);
end;

//
// Обработчики действий (общие для меню и клавиатуры)
//
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
        Item.Data := Pointer(0); // ID пока нет, будет присвоен при сохранении
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
begin
    if lvTags.SelCount = 0 then Exit;

    Dlg := CreateMessageDialog(
        Format('Удалить выбранные теги (%d шт.)?', [lvTags.SelCount]),
        mtConfirmation,
        [mbYes, mbNo]
    );
    try
        Dlg.Caption := 'Подтверждение удаления';
        if Dlg.ShowModal <> mrYes then
            Exit;
    finally
        Dlg.Free;
    end;

    // Удаление с конца, чтобы индексы не съезжали
    for var I := lvTags.Items.Count - 1 downto 0 do
    begin
        if lvTags.Items[I].Selected then
        begin
            var TagID := NativeUInt(lvTags.Items[I].Data);
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

    lvTags.Selected.EditCaption;

    if (lvTags.Selected <> nil) then
        lvTags.Selected.EditCaption;
end;

// --- Привязка кнопок и меню к общим методам ---

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

//
// Горячие клавиши ListView ---
//
procedure TTagEditorForm.lvTagsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    case Key of
        VK_INSERT:
            begin
                DoAddTag;
                Key := 0;
            end;
        VK_DELETE:
            begin
                DoDeleteTags;
                Key := 0;
            end;
        VK_F2:
            begin
                DoRenameTag;
                Key := 0;
            end;
    end;
end;

//
// Завершение редактирования имени (F2)
//
procedure TTagEditorForm.lvTagsEdited(Sender: TObject; Item: TListItem; var S: string);
var
    TagID: NativeUInt;
begin
    S := Trim(S);

    // Если имя пустое или не изменилось - откатываем
    if (S = '') or (S = Item.Caption) then
    begin
        S := Item.Caption;
        Exit;
    end;

    TagID := NativeUInt(Item.Data);

    // Записываем переименование в буфер только если тег уже есть в БД
    if TagID > 0 then
        RecordChange(teaRename, TagID, S);

    // Визуально Caption обновится автоматически
end;

//
//  Сохранение всех изменений по ОК
//
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
    TagDTO: TTagDTO;
begin
    for Change in FChanges do
    begin
        case Change.Action of
            teaAdd:
                begin
                    // Создаём DTO и передаём в Add
                    TagDTO.ID := 0;
                    TagDTO.Name := Change.NewName;
                    DataModuleCommon.TagRepository.Add(TagDTO);
                end;

            teaRename:
                begin
                    // Заполняем DTO и используем универсальный Update
                    TagDTO.ID := Integer(Change.TagID);
                    TagDTO.Name := Change.NewName;
                    DataModuleCommon.TagRepository.Update(TagDTO);
                end;

            teaDelete:
                begin
                    // Приводим NativeUInt к Integer
                    DataModuleCommon.TagRepository.Delete(Integer(Change.TagID));
                end;
        end;
    end;

    FChanges.Clear;
end;

end.
