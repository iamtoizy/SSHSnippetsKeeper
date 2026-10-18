unit TagListController;

interface

uses
    Core.Entities.Snippet,
    Core.Entities.Tag,
    Core.Interfaces.App,
    Core.Interfaces.Services,
    Core.Interfaces.Settings,
    Core.Interfaces.UI,
    System.Classes,
    System.SysUtils,
    Vcl.ComCtrls,
    Vcl.Controls,
    Winapi.Messages
    ;

type
    // Список тегов: CRUD, инлайн-переименование, фильтр сниппетов по тегам.
    // Форма владеет TListView и DFM-обработчиками и делегирует сюда.
    TTagListController = class
    private
        FListView: TListView;
        FStatusBar: TStatusBar;
        FContext: IAppContext;
        FFilterByTagIDs: TArray<Integer>;
        FCurrentSnippetID: Integer;
        FOnFilterCleared: TProc;
        FOnUpdateMenuState: TProc;
        FOnDataChanged: TProc;
        FOnShowSnippets: TProc<TArray<TSnippetDTO>>;
        procedure ApplyFilter(const TagIDs: TArray<Integer>; const TagNames: string);
        procedure ClearTagSelection;
    public
        constructor Create(AListView: TListView; AStatusBar: TStatusBar; AContext: IAppContext;
            const AOnFilterCleared: TProc; const AOnUpdateMenuState: TProc;
            const AOnDataChanged: TProc; const AOnShowSnippets: TProc<TArray<TSnippetDTO>>);

        procedure AddTag;
        procedure DeleteTag;
        procedure StartRename;
        procedure HandleEdited(Item: TListItem; var S: string);
        procedure HandleClick;
        procedure HandleMouseDown(Button: TMouseButton; X, Y: Integer);
        procedure ClearFilter;
        // Сброс состояния фильтра без уведомлений и без статуса (при смене категории)
        procedure ResetFilterState;

        // ID тегов активного фильтра (пустой массив = фильтр не активен)
        property FilterTagIDs: TArray<Integer> read FFilterByTagIDs;
        // Сниппет, чьи теги сейчас показаны (0 = выбранного сниппета нет)
        property CurrentSnippetID: Integer read FCurrentSnippetID write FCurrentSnippetID;
    end;

implementation

uses
    Common.Localization,
    System.Types,
    UI.Helpers,
    Winapi.Windows
    ;

{ TTagListController }

constructor TTagListController.Create(AListView: TListView; AStatusBar: TStatusBar;
    AContext: IAppContext; const AOnFilterCleared: TProc; const AOnUpdateMenuState: TProc;
    const AOnDataChanged: TProc; const AOnShowSnippets: TProc<TArray<TSnippetDTO>>);
begin
    inherited Create;
    FListView := AListView;
    FStatusBar := AStatusBar;
    FContext := AContext;
    FOnFilterCleared := AOnFilterCleared;
    FOnUpdateMenuState := AOnUpdateMenuState;
    FOnDataChanged := AOnDataChanged;
    FOnShowSnippets := AOnShowSnippets;
    FCurrentSnippetID := 0;
end;

procedure TTagListController.AddTag;
var
    NewName: string;
    NewID: Integer;
begin
    if not FContext.MessagesHandler.AskInput(
        TUIStateLoader.GetMessage('Tag.NewDefaultName'),
        TUIStateLoader.GetMessage('Tag.NewPrompt'),
        NewName
    ) then Exit;

    NewName := Trim(NewName);
    if NewName = '' then
        Exit;

    try
        NewID := FContext.TagService.CreateTag(NewName);

        with FListView.Items.Add do
        begin
            Caption := NewName;
            Data := Pointer(NewID);
            StateIndex := 0;
            Selected := True;
            MakeVisible(False);
        end;
        FStatusBar.Panels[0].Text := TUIStateLoader.GetMessage('Tag.AddedMsg', [NewName]);
        if Assigned(FOnDataChanged) then
            FOnDataChanged();
    except
        on E: Exception do
            FContext.MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('Tag.AddError', [E.Message])
            );
    end;
end;

procedure TTagListController.DeleteTag;
var
    Item: TListItem;
    TagID: Integer;
    FilteredID: Integer;
begin
    Item := FListView.Selected;
    if Item = nil then
        Exit;

    TagID := Integer(IntPtr(Item.Data));
    if not FContext.MessagesHandler.AskConfirmation(
        TUIStateLoader.GetMessage('Tag.DeleteConfirm', [Item.Caption]),
        TUIStateLoader.GetMessage('Common.Confirmation'),
        MB_YESNO or MB_ICONQUESTION or MB_DEFBUTTON2
    ) then Exit;

    try
        FContext.TagService.DeleteTag(TagID);
        Item.Delete;

        // Если удаленный тег участвовал в фильтре - сбрасываем фильтр
        for FilteredID in FFilterByTagIDs do
            if FilteredID = TagID then
            begin
                ClearFilter;
                Break;
            end;

        if (FCurrentSnippetID > 0) and (Length(FFilterByTagIDs) = 0) then
            TUIHelpers.FillTagListWithSelection(
                FListView,
                FContext.TagService.GetAllTags,
                FContext.TagService.GetSnippetTags(FCurrentSnippetID)
            );

        FStatusBar.Panels[0].Text := TUIStateLoader.GetMessage('Tag.DeletedMsg');
        if Assigned(FOnDataChanged) then
            FOnDataChanged();
    except
        on E: Exception do
            FContext.MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('Tag.DeleteError', [E.Message])
            );
    end;
end;

procedure TTagListController.StartRename;
begin
    if FListView.Selected <> nil then
        FListView.Selected.EditCaption;
end;

procedure TTagListController.HandleEdited(Item: TListItem; var S: string);
var
    TagID: Integer;
    OldName: string;
begin
    OldName := Item.Caption;
    S := Trim(S);
    if (S = '') or (S = OldName) then
    begin
        S := OldName;
        Exit;
    end;

    try
        TagID := Integer(IntPtr(Item.Data));
        FContext.TagService.RenameTag(TagID, S);
        FStatusBar.Panels[0].Text := TUIStateLoader.GetMessage('Tag.RenamedMsg', [OldName, S]);
        if Assigned(FOnDataChanged) then
            FOnDataChanged();
    except
        on E: Exception do
        begin
            FContext.MessagesHandler.ShowError(
                TUIStateLoader.GetMessage('Tag.RenameError', [E.Message])
            );
            S := OldName;
        end;
    end;
end;

procedure TTagListController.HandleClick;
var
    I: Integer;
    TagIDs: TArray<Integer>;
    TagNames: TStringList;
begin
    if Assigned(FOnUpdateMenuState) then
        FOnUpdateMenuState();

    if FListView.SelCount = 0 then
    begin
        ClearFilter;
        Exit;
    end;

    TagNames := TStringList.Create;
    try
        for I := 0 to FListView.Items.Count - 1 do
        begin
            if FListView.Items[I].Selected then
            begin
                SetLength(TagIDs, Length(TagIDs) + 1);
                TagIDs[High(TagIDs)] := Integer(IntPtr(FListView.Items[I].Data));
                TagNames.Add(FListView.Items[I].Caption);
            end;
        end;

        // Передаем массив ID и строку с названиями через запятую (например, "Delphi, SQL, Python")
        ApplyFilter(TagIDs, TagNames.CommaText);
    finally
        TagNames.Free;
    end;
end;

procedure TTagListController.HandleMouseDown(Button: TMouseButton; X, Y: Integer);
begin
    if Button <> mbLeft then
        Exit;

    if (FListView.GetItemAt(X, Y) = nil) and
        ((FListView.SelCount > 0) or (Length(FFilterByTagIDs) > 0)) then
        ClearFilter;
end;

procedure TTagListController.ClearFilter;
begin
    ClearTagSelection;

    if Assigned(FOnFilterCleared) then
        FOnFilterCleared();

    SetLength(FFilterByTagIDs, 0);
    FStatusBar.Panels[0].Text := TUIStateLoader.GetMessage('Tag.FilterReset');
end;

procedure TTagListController.ResetFilterState;
begin
    SetLength(FFilterByTagIDs, 0);
    ClearTagSelection;
end;

procedure TTagListController.ApplyFilter(const TagIDs: TArray<Integer>; const TagNames: string);
begin
    FFilterByTagIDs := TagIDs;

    // MatchAll: True - сниппеты, содержащие ВСЕ выбранные теги; False - ЛЮБОЙ из тегов (настройка, вкладка "Общие")
    if Assigned(FOnShowSnippets) then
        FOnShowSnippets(FContext.SnippetService.GetSnippetsByTags(TagIDs, FContext.SettingsManager.Data.TagsMatchAll));

    if FContext.SettingsManager.Data.TagsMatchAll then
        FStatusBar.Panels[0].Text := TUIStateLoader.GetMessage('Tag.FilterPrefixAll', [TagNames])
    else
        FStatusBar.Panels[0].Text := TUIStateLoader.GetMessage('Tag.FilterPrefixAny', [TagNames]);
end;

procedure TTagListController.ClearTagSelection;
var
    I: Integer;
begin
    for I := 0 to FListView.Items.Count - 1 do
        FListView.Items[I].Selected := False;
end;

end.
