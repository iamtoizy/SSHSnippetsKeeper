unit AddEditSnippetUI;

interface

uses
    Winapi.Windows,
    Winapi.Messages,
    System.SysUtils,
    System.Variants,
    System.Classes,
    Vcl.Graphics,
    DataModule,
    Snippet,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.Dialogs,
    Vcl.StdCtrls,
    Vcl.ComCtrls,
    HintTextEdit,
    HintTextMemo,
    Vcl.ExtCtrls,
    UITreeViewSearchHelper,
    SynEdit,
    SynThemeAdapter,
    SynEditHighlighter,
    SynHighlighterUNIXShellScript,
    SynEditMiscClasses,
    SynEditRegexSearch,
    SynCompletionProposal,
    SynEditTypes,
    CustomBashSyn,
    BashCompletionEngine;

type
    TOriginalSnippet = record
        Title: string;
        Content: string;
        Comment: string;
        Tags: string;
    end;

    TAddEditSnippet = class(TForm)
        pcSnippet: TPageControl;
        tsSnippet: TTabSheet;
        pLeft: TPanel;
        lbCaption: TLabel;
        ebTitle: TEdit;
        lbTag: TLabel;
        Label1: TLabel;
        lvSelectedTags: TListView;
        pBottom: TPanel;
        bOK: TButton;
        bCancel: TButton;
        tsHelp: TTabSheet;
        lvAllTags: TListView;
        sMiddle: TSplitter;
        mInfo: TMemo;
        mSnippet: TSynEdit;
        mComment: TSynEdit;
        SynUNIXShellScriptSyn: TSynUNIXShellScriptSyn;
        SynEditRegexSearch: TSynEditRegexSearch;
        SynCompletionProposal: TSynCompletionProposal;
        tmrReloadCommands: TTimer;
        procedure FormDestroy(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        function GetSnippet: TSnippetDTO;
        procedure FormShow(Sender: TObject);
        procedure ebCategorySearchChange(Sender: TObject);
        procedure bOKClick(Sender: TObject);
        procedure bCancelClick(Sender: TObject);
        procedure lvAllTagsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
        procedure lvAllTagsDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
        procedure lvAllTagsDragDrop(Sender, Source: TObject; X, Y: Integer);
        procedure lvAllTagsDblClick(Sender: TObject);
        procedure mSnippetKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure mSnippetProcessCommand(Sender: TObject; var Command: TSynEditorCommand; var AChar: WideChar; Data: Pointer);
        procedure SynCompletionProposalExecute(Kind: SynCompletionType; Sender: TObject; var CurrentInput: string; var x, y: Integer; var CanExecute: Boolean);
        procedure tmrReloadCommandsTimer(Sender: TObject);
    protected
        // Блок управления стилями
        procedure Loaded; override;
        procedure CMStyleChanged(var Message: TMessage); message CM_STYLECHANGED;
    private
        { Private declarations }
        FSnippet: TSnippetDTO;
        FOriginalSnippet: TOriginalSnippet;
        FCategoryID: NativeInt;
        FUserID: NativeInt;
        FIsEditMode: Boolean;
        FBasicCommands: TStringList;
        FBlockEnter: Boolean;
        FCurrentHighlighter: TCustomBashSyn;
        //
        FCompletionEngine: TBashCompletionEngine;
        function IsAutocompleteVisible: Boolean;
        function IsSnippetChanged: Boolean;
        //
        procedure InitBashAutocomplete;
        procedure SetSyntax;
    public
        { Public declarations }
        property Snippet: TSnippetDTO read FSnippet write FSnippet;
        property CategoryID: NativeInt read FCategoryID write FCategoryID;
        property UserID: NativeInt read FUserID write FUserID;
    end;

var
    AddEditSnippet: TAddEditSnippet;

implementation

uses
    Vcl.Styles,
    Vcl.Themes,
    System.Hash,
    UIHelpers,
    Settings,
    System.Generics.Collections,
    System.DateUtils,
    MainFormUI,
    Tag,
    SynEditKeyCmds,
    CommonHelpers;

{$R *.dfm}

procedure TAddEditSnippet.FormDestroy(Sender: TObject);
begin
    if Assigned(FCurrentHighlighter) then
        FCurrentHighlighter.Free;

    if Assigned(FCompletionEngine) then
        FCompletionEngine.Free;
end;

//Если в методе добавления категории ты делаешь что-то вроде Query.ParamByName('parent_id').AsInteger := ParentID;
//и передаешь туда 0 для корневой категории, ты получишь ту же самую ошибку FOREIGN KEY constraint failed.
//В коде сохранения новой категории тебе нужно использовать ту же логику:
//
//if Category.ParentID = 0 then
//    Query.ParamByName('parent_id').Clear // Записываем NULL
//else
//    Query.ParamByName('parent_id').AsInteger := Category.ParentID;

procedure TAddEditSnippet.InitBashAutocomplete;
begin
    SynCompletionProposal.ItemList.Clear;

    // Добавляем ключевые слова Bash
    SynCompletionProposal.ItemList.Add('echo');
    SynCompletionProposal.ItemList.Add('export');
    SynCompletionProposal.ItemList.Add('grep');
    SynCompletionProposal.ItemList.Add('awk');
    SynCompletionProposal.ItemList.Add('sed');

    // Добавляем DevOps-инструментарий
    SynCompletionProposal.ItemList.Add('docker run');
    SynCompletionProposal.ItemList.Add('docker-compose');
    SynCompletionProposal.ItemList.Add('kubectl get pods');
    SynCompletionProposal.ItemList.Add('systemctl restart');



    // Настройка компонента
    SynCompletionProposal.Options := SynCompletionProposal.Options + [scoUseInsertList];
    // Включаем автовызов при печати
    SynCompletionProposal.Options := SynCompletionProposal.Options + [scoUseBuiltInTimer];
end;

function TAddEditSnippet.IsAutocompleteVisible: Boolean;
begin
    Result := Assigned(SynCompletionProposal.Form) and SynCompletionProposal.Form.Visible;
end;

function TAddEditSnippet.IsSnippetChanged: Boolean;
var
    TagsStr: string;
    I: Integer;
begin
    TagsStr := '';
    for I := 0 to lvSelectedTags.Items.Count - 1 do
        TagsStr := TagsStr + ';' + lvSelectedTags.Items[I].Caption;

    Result := (ebTitle.Text <> FOriginalSnippet.Title) or (mSnippet.Text <> FOriginalSnippet.Content) or (mComment.Text <> FOriginalSnippet.Comment) or (TagsStr <> FOriginalSnippet.Tags);
end;

procedure TAddEditSnippet.bCancelClick(Sender: TObject);
begin
    if FIsEditMode and IsSnippetChanged and (Application.MessageBox('Обнаружены изменения, которые потеряются в случае закрытия этого окна.' + sLineBreak + sLineBreak + 'Закрыть окно без сохранения изменений?', 'Внимание', MB_YESNO) = IDNO) then
        Exit;

    ModalResult := mrCancel;
end;

procedure TAddEditSnippet.bOKClick(Sender: TObject);
var
    Snippet: TSnippetDTO;
    TagIDs: TList<NativeInt>;
    i: Integer;
    TagArr: TArray<NativeInt>;
    UnixText: string;
begin
    if Trim(ebTitle.Text) = '' then
    begin
        ShowMessage('Введи заголовок сниппета.');
        ModalResult := mrNone;
        Exit;
    end;

    TagIDs := TList<NativeInt>.Create;
    try
        for i := 0 to lvSelectedTags.Items.Count - 1 do
        begin
            var TagID := NativeInt(lvSelectedTags.Items[i].Data);
            if TagID > 0 then
                TagIDs.Add(TagID);
        end;
        TagArr := TagIDs.ToArray;
    finally
        TagIDs.Free;
    end;

    UnixText := StringReplace(mSnippet.Text, #13#10, #10, [rfReplaceAll]);
    // Обязательно сохраняем в UTF-8 без BOM, как любит Linux
//    TFile.WriteAllText(FileName, UnixText, TEncoding.UTF8);

    Snippet := Default(TSnippetDTO);
    Snippet.UserID := FUserID;
    Snippet.CategoryID := FCategoryID;
    Snippet.Title := ebTitle.Text;
    Snippet.Content := UnixText;
    Snippet.Comment := mComment.Text;

    try
        if FIsEditMode then
        begin
            Snippet.ID := FSnippet.ID;
            Snippet.CreatedAt := FSnippet.CreatedAt;
            Snippet.UpdatedAt := DateTimeToUnix(Now);

            DataModuleCommon.SnippetRepository.Update(Snippet);
            if Length(TagArr) > 0 then
                DataModuleCommon.SnippetRepository.UpdateTags(FSnippet.ID, TagArr);

            ModalResult := mrOk;
        end
        else
        begin
            Snippet.CreatedAt := DateTimeToUnix(Now);
            Snippet.UpdatedAt := 0;

            DataModuleCommon.SnippetRepository.Add(Snippet, TagArr);
            ModalResult := mrOk;
        end;
    except
        on E: Exception do
        begin
            ShowMessage('Ошибка сохранения сниппета: ' + E.Message);
            ModalResult := mrNone;
        end;
    end;
end;

procedure TAddEditSnippet.CMStyleChanged(var Message: TMessage);
begin
    TSynThemeAdapter.ApplyTheme(mSnippet);
    TSynThemeAdapter.ApplyTheme(mComment);
end;

procedure TAddEditSnippet.ebCategorySearchChange(Sender: TObject);
begin
    if (Length((Sender as TEdit).Text) < 3) then
        Exit;
end;

procedure TAddEditSnippet.FormCreate(Sender: TObject);
begin
  ebTitle.EnableHintText := True;
  ebTitle.HintText := 'Здесь введи имя сниппета...';

  FIsEditMode := False;
  FSnippet := Default(TSnippetDTO);

  lvSelectedTags.StateImages := MainFormUI.MainForm.vilTags;
  lvAllTags.StateImages := MainFormUI.MainForm.vilTags;

  // Настройка компонента автодополнения (списки теперь чистые, они заполняются на лету)
  SynCompletionProposal.Options := SynCompletionProposal.Options + [scoUseInsertList];
end;

procedure TAddEditSnippet.FormShow(Sender: TObject);
var
    i: Integer;
    TagIDs: TArray<TTagDTO>;
    Tag: TTagDTO;
begin
    if FSnippet.ID > 0 then
    begin
        // Режим редактирования
        FIsEditMode := True;
        Caption := 'Редактирование сниппета';

        FOriginalSnippet.Title := FSnippet.Title;
        FOriginalSnippet.Content := FSnippet.Content;
        FOriginalSnippet.Comment := FSnippet.Comment;
        FOriginalSnippet.Tags := '';

        ebTitle.Text := FSnippet.Title;
        mSnippet.Text := FSnippet.Content;
        mComment.Text := FSnippet.Comment;

        // Загружаем и отмечаем теги сниппета
        TagIDs := DataModuleCommon.SnippetRepository.GetSnippetTags(FSnippet.ID);
        for Tag in TagIDs do
        begin
            // Ищем тег в lvAllTags и добавляем в lvSelectedTags
            for i := 0 to lvAllTags.Items.Count - 1 do
            begin
                if Integer(lvAllTags.Items[i].Data) = Tag.ID then
                begin
                    // Добавляем в список выбранных
                    var Item := lvSelectedTags.Items.Add;
                    Item.Caption := Tag.Name;
                    Item.Data := Pointer(NativeUInt(Tag.ID));
                    Item.StateIndex := 0;
                    lvAllTags.Items.Delete(i);
                    FOriginalSnippet.Tags := FOriginalSnippet.Tags + ';' + Tag.Name;
                    Break;
                end;
            end;
        end;
    end
    else
    begin
        // Режим добавления
        FIsEditMode := False;
        Caption := 'Добавление сниппета';
        FOriginalSnippet.Title := '';
        FOriginalSnippet.Content := '';
        FOriginalSnippet.Comment := '';
        FOriginalSnippet.Tags := '';
    end;

    tmrReloadCommands.Enabled := True;
end;

function TAddEditSnippet.GetSnippet: TSnippetDTO;
begin
    Result := FSnippet;
end;

procedure TAddEditSnippet.Loaded;
begin
  inherited;

  // 1. СОЗДАЕМ движок ПЕРЕД тем, как настраивать синтаксис
  FBasicCommands := Settings.BashAutocomplete;
  FCompletionEngine := TBashCompletionEngine.Create(FBasicCommands);

  // 2. Загружаем файл
  FCompletionEngine.LoadFromJsonFile(ExtractFilePath(Application.ExeName) + 'extra-commands.json');

  // 3. Безопасно применяем цвета до появления формы на экране
  TSynThemeAdapter.ApplyTheme(mSnippet);
  TSynThemeAdapter.ApplyTheme(mComment);

  // 4. Теперь SetSyntax отработает без ошибок
  SetSyntax;
end;

procedure TAddEditSnippet.lvAllTagsDblClick(Sender: TObject);
var
    SrcLV, DstLV: TListView;
    Item, NewItem: TListItem;
begin
    SrcLV := Sender as TListView;
    if SrcLV = lvAllTags then
        DstLV := lvSelectedTags
    else
        DstLV := lvAllTags;

    Item := SrcLV.Selected;
    if Assigned(Item) then
    begin
        SrcLV.Items.BeginUpdate;
        DstLV.Items.BeginUpdate;
        try
            NewItem := DstLV.Items.Add;
            NewItem.Caption := Item.Caption;
            NewItem.Data := Item.Data;
            NewItem.StateIndex := Item.StateIndex;
            Item.Delete;
        finally
            SrcLV.Items.EndUpdate;
            DstLV.Items.EndUpdate;
        end;
    end;
end;

procedure TAddEditSnippet.lvAllTagsDragDrop(Sender, Source: TObject; X, Y: Integer);
var
    SrcLV, DstLV: TListView;
    Item, NewItem: TListItem;
    i: Integer;
    ItemsToMove: TList<TListItem>;
begin
    SrcLV := Source as TListView;
    DstLV := Sender as TListView;

    if SrcLV = DstLV then
        Exit;

    ItemsToMove := TList<TListItem>.Create;
    try
        // Собираем все выделенные элементы (поддерживается множественный выбор!)
        for i := 0 to SrcLV.Items.Count - 1 do
            if SrcLV.Items[i].Selected then
                ItemsToMove.Add(SrcLV.Items[i]);

        SrcLV.Items.BeginUpdate;
        DstLV.Items.BeginUpdate;
        try
            // Копируем в целевой список
            for Item in ItemsToMove do
            begin
                NewItem := DstLV.Items.Add;
                NewItem.Caption := Item.Caption;
                NewItem.Data := Item.Data;
                NewItem.StateIndex := Item.StateIndex;
            end;

            // Удаляем из исходного списка (идём с конца, чтобы индексы не поехали)
            for i := ItemsToMove.Count - 1 downto 0 do
                ItemsToMove[i].Delete;
        finally
            SrcLV.Items.EndUpdate;
            DstLV.Items.EndUpdate;
        end;
    finally
        ItemsToMove.Free;
    end;
end;

procedure TAddEditSnippet.lvAllTagsDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
    // Принимаем перетаскивание только из наших списков тегов
    Accept := (Source = lvAllTags) or (Source = lvSelectedTags);

    // Запрещаем дропать в тот же самый список
    if Sender = Source then
        Accept := False;
end;

procedure TAddEditSnippet.lvAllTagsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
    LV: TListView;
    Item: TListItem;
begin
    if Button = mbLeft then
    begin
        LV := Sender as TListView;
        Item := LV.GetItemAt(X, Y);
        if Assigned(Item) then
        begin
            // Если клик по невыделенному элементу без Ctrl - сбрасываем остальное выделение
            if not Item.Selected then
            begin
                if not (ssCtrl in Shift) then
                    LV.ClearSelection;
                Item.Selected := True;
            end;
            // Начинаем перетаскивание (порог 5 пикселей)
            LV.BeginDrag(False, 5);
        end;
    end;
end;

procedure TAddEditSnippet.mSnippetKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if (Key = VK_RETURN) and IsAutocompleteVisible then
    begin
        FBlockEnter := True;
    end;
end;

procedure TAddEditSnippet.mSnippetProcessCommand(Sender: TObject; var Command: TSynEditorCommand; var AChar: WideChar; Data: Pointer);
begin
    if FBlockEnter then
    begin
        if (Command = ecLineBreak) or ((Command = ecChar) and (AChar = #13)) then
        begin
            Command := ecNone;
            AChar := #0;
        end;
        FBlockEnter := False;
        Exit;
    end;

  // Использование хелпера делает этот код максимально понятным
    if IsAutocompleteVisible then
    begin
        if (Command = ecUp) or (Command = ecDown) or (Command = ecPageUp) or (Command = ecPageDown) then
        begin
            Command := ecNone;
        end;
    end;
end;

procedure TAddEditSnippet.SetSyntax;
begin
    FBasicCommands := Settings.BashAutocomplete;
    if Assigned(FCurrentHighlighter) then
        FreeAndNil(FCurrentHighlighter);

    FCurrentHighlighter := TCustomBashSyn.Create(nil);

  // 1. ИСПОЛЬЗУЕМ AddStrings вместо Assign!
  // Это сохранит сортировку и бинарный поиск нашего кастомного класса.
    if Assigned(FBasicCommands) then
        TCustomBashSyn(FCurrentHighlighter).ExtraKeywords.AddStrings(FBasicCommands);

  // 2. Загружаем слова из движка
    FCompletionEngine.ExportKeywords(TCustomBashSyn(FCurrentHighlighter).ExtraKeywords);

    mSnippet.Highlighter := FCurrentHighlighter;
    TSynThemeAdapter.ApplyTheme(mSnippet);
end;

procedure TAddEditSnippet.SynCompletionProposalExecute(Kind: SynCompletionType; Sender: TObject; var CurrentInput: string; var x, y: Integer; var CanExecute: Boolean);
var
    LineText: string;
begin
    // Берем текст от начала строки до курсора
    LineText := Copy(mSnippet.LineText, 1, mSnippet.CaretX - 1);

    // Всю грязную работу по анализу контекста и заполнению списков теперь делает движок
    FCompletionEngine.FillProposals(LineText, SynCompletionProposal.ItemList, SynCompletionProposal.InsertList, CanExecute);
end;

procedure TAddEditSnippet.tmrReloadCommandsTimer(Sender: TObject);
begin
    // Если движок обнаружил изменения на диске и пересобрал дерево
    if FCompletionEngine.CheckForUpdates then
    begin
        // Вызываем пересборку хайлайтера, чтобы новые слова сразу подсвечивались
        ShowSimpleToast('Новая конфигурация', 'Файл автозаполнения обновлён. Содержимое будет перезагружено.');
        SetSyntax;
    end;
end;

end.

