unit TagEditorUI;

interface

uses
    BaseFormUI,
    Core.Interfaces,
    System.Classes,
    System.Generics.Collections,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Menus,
    Vcl.StdCtrls, System.Actions, Vcl.ActnList
    ;

type
    TTagEditAction = (teaAdd, teaRename, teaDelete);

    TTagChange = record
        Action: TTagEditAction;
        TagID: Integer;      // ��� Rename/Delete
        NewName: string;     // ��� Add/Rename
    end;

    TTagEditorForm = class(TBaseForm)
        pBottom: TPanel;
        bOK: TButton;
        bCancel: TButton;
        lvTags: TListView;
        MainMenu: TMainMenu;
        nActions: TMenuItem;
        nTagAdd: TMenuItem;
        nTagDelete: TMenuItem;
        nTagRename: TMenuItem;
    ActionList: TActionList;
    actAddTag: TAction;
    actDeleteTag: TAction;
    actEditTag: TAction;
        procedure actAddTagExecute(Sender: TObject);
        procedure actDeleteTagExecute(Sender: TObject);
        procedure actEditTagExecute(Sender: TObject);
        procedure bOKClick(Sender: TObject);
        procedure bCancelClick(Sender: TObject);
        procedure lvTagsEdited(Sender: TObject; Item: TListItem; var S: string);
        procedure FormCreate(Sender: TObject);
        procedure FormDestroy(Sender: TObject);
    protected
        procedure DoInitialize; override;
    private
        FChanges: TList<TTagChange>;

        procedure ApplyChangesToDB;
        procedure ValidateNoDuplicates;
        procedure RecordChange(Action: TTagEditAction; TagID: Integer; const NewName: string = '');
        procedure RemovePendingAdd(const AName: string);
        procedure DoAddTag;
        procedure DoDeleteTags;
        procedure DoRenameTag;
        procedure RefreshTagList;
    public
    end;

var
    TagEditorForm: TTagEditorForm;

implementation

{$R *.dfm}

uses
    System.SysUtils,
    System.UITypes,
    Tag,
    UI.Helpers,
    UI.StateLoader,
    Vcl.Dialogs,
    Vcl.Forms,
    Winapi.CommCtrl,
    Winapi.Windows
    ;

procedure TTagEditorForm.actAddTagExecute(Sender: TObject);
begin
    DoAddTag;
end;

procedure TTagEditorForm.actDeleteTagExecute(Sender: TObject);
begin
    DoDeleteTags;
end;

procedure TTagEditorForm.actEditTagExecute(Sender: TObject);
begin
    DoRenameTag;
end;

procedure TTagEditorForm.FormCreate(Sender: TObject);
begin
    FChanges := TList<TTagChange>.Create;
    // ��������� ���� ��� �������� �����, ���� ������ ��� �������
end;

procedure TTagEditorForm.FormDestroy(Sender: TObject);
begin
    FChanges.Free;
end;

procedure TTagEditorForm.DoInitialize;
begin
    inherited;
    RefreshTagList;
end;

procedure TTagEditorForm.RefreshTagList;
var
    Tags: TArray<TTagDTO>;
begin
    if Assigned(AppContext.TagService) then
    begin
        Tags := AppContext.TagService.GetAllTags;
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

procedure TTagEditorForm.RemovePendingAdd(const AName: string);
var
    I: Integer;
begin
    for I := FChanges.Count - 1 downto 0 do
        if (FChanges[I].Action = teaAdd) and SameText(FChanges[I].NewName, AName) then
        begin
            FChanges.Delete(I);
            Break;
        end;
end;

procedure TTagEditorForm.ValidateNoDuplicates;
var
    I, J: Integer;
begin
    for I := 0 to lvTags.Items.Count - 1 do
        for J := I + 1 to lvTags.Items.Count - 1 do
            if SameText(lvTags.Items[I].Caption, lvTags.Items[J].Caption) then
                raise Exception.Create(
                    TUIStateLoader.GetMessage('Tag.DuplicateNameError', [lvTags.Items[I].Caption]));
end;

procedure TTagEditorForm.DoAddTag;
var
    NewName: string;
    Item: TListItem;
begin
    if InputQuery(
        TUIStateLoader.GetMessage('TagEditorForm.InputQueryTitle'),
        TUIStateLoader.GetMessage('TagEditorForm.InputQueryPrompt'),
        NewName) and (Trim(NewName) <> '') then
    begin
        NewName := Trim(NewName);

        // ���������� ����������
        Item := lvTags.Items.Add;
        Item.Caption := NewName;
        Item.Data := Pointer(0); // ID ���� ���, ����� �������� ��� ���������� � ApplyChangesToDB
        Item.Selected := True;
        Item.MakeVisible(False);
        Item.StateIndex := 0;

        // ���������� � ����� ���������
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

    // TODO: � ��������� �����, �����!
    Dlg := CreateMessageDialog(
        TUIStateLoader.GetMessage('TagEditorForm.DeleteConfirmFormat', [lvTags.SelCount]),
        mtConfirmation, [mbYes, mbNo]
    );
    try
        Dlg.Caption := TUIStateLoader.GetMessage('TagEditorForm.DeleteConfirmTitle');
        if Dlg.ShowModal <> mrYes then
            Exit;
    finally
        Dlg.Free;
    end;

    // �������� � �����, ����� ������� �� ��������
    for I := lvTags.Items.Count - 1 downto 0 do
    begin
        if lvTags.Items[I].Selected then
        begin
            TagID := Integer(lvTags.Items[I].Data);
            if TagID > 0 then
                RecordChange(teaDelete, TagID)
            else
                RemovePendingAdd(lvTags.Items[I].Caption);
            lvTags.Items.Delete(I);
        end;
    end;

    // �������������� ������������ ������������ ������
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

procedure TTagEditorForm.lvTagsEdited(Sender: TObject; Item: TListItem; var S: string);
var
    TagID: Integer;
    I: Integer;
    Change: TTagChange;
begin
    S := Trim(S);

    // ���� ��� ������ ��� �� ���������� - ����������
    if (S = '') or (S = Item.Caption) then
    begin
        S := Item.Caption;
        Exit;
    end;

    TagID := Integer(Item.Data);

    // ���������� �������������� � ����� ������ ���� ��� ��� ���� � ��
    if TagID > 0 then
        RecordChange(teaRename, TagID, S)
    else
        for I := FChanges.Count - 1 downto 0 do
            if (FChanges[I].Action = teaAdd) and SameText(FChanges[I].NewName, Item.Caption) then
            begin
                Change := FChanges[I];
                Change.NewName := S;
                FChanges[I] := Change;
                Break;
            end;

    // ��������� Caption ��������� �������������
end;

procedure TTagEditorForm.bOKClick(Sender: TObject);
begin
    try
        ApplyChangesToDB;
        ModalResult := mrOk;
    except
        on E: Exception do
            MessageDlg(TUIStateLoader.GetMessage('TagEditorForm.SaveErrorFormat', [E.Message]), mtError, [mbOK], 0);
    end;
end;

procedure TTagEditorForm.bCancelClick(Sender: TObject);
begin
    // ������ ���������, FChanges ����������� � FormDestroy ��� ����������
    ModalResult := mrCancel;
end;

procedure TTagEditorForm.ApplyChangesToDB;
var
    I: Integer;
    Change: TTagChange;
begin
    ValidateNoDuplicates;

    I := 0;
    while I < FChanges.Count do
    begin
        Change := FChanges[I];
        try
        case Change.Action of
            teaAdd:
                // ������ ��� �������� ������������ � ������� �����
                AppContext.TagService.CreateTag(Change.NewName);

            teaRename:
                // �������� ID (� ����������� �����) � ����� ���
                AppContext.TagService.RenameTag(Integer(Change.TagID), Change.NewName);

            teaDelete:
                AppContext.TagService.DeleteTag(Integer(Change.TagID));
        end;
        except
            on E: Exception do
            begin
                FChanges.DeleteRange(0, I);
                raise;
            end;
        end;
        Inc(I);
    end;

    FChanges.Clear;
end;

end.

