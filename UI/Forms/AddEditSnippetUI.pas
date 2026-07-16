unit AddEditSnippetUI;

interface

uses
    Winapi.Windows,
    Winapi.Messages,
    System.SysUtils,
    System.Classes,
    Snippet,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.Dialogs,
    Vcl.StdCtrls,
    Vcl.ComCtrls,
    HintTextEdit,
    HintTextMemo,
    Vcl.ExtCtrls,
    SynEdit,
    SynThemeAdapter,
    SynHighlighterUNIXShellScript,
    SynEditRegexSearch,
    SynCompletionProposal,
    SynEditTypes,
    CustomBashSyn,
    BashCompletionEngine,
    Core.Interfaces,
    SynEditMiscClasses,
    SynEditHighlighter,
    UI.Interfaces,
    Vcl.WinXCtrls,
    System.Threading,
    AIService,
    SynHighlighterMarkdown,
    Vcl.Menus,
    Settings;

type
    TOriginalSnippet = record
        Title: string;
        Content: string;
        Comment: string;
        Tags: string;
    end;

    TAddEditSnippet = class(TForm)
        pLeft: TPanel;
        lbCaption: TLabel;
        ebTitle: TEdit;
        lbTag: TLabel;
        Label1: TLabel;
        lvSelectedTags: TListView;
        pBottom: TPanel;
        bOK: TButton;
        bCancel: TButton;
        lvAllTags: TListView;
        SynUNIXShellScriptSyn: TSynUNIXShellScriptSyn;
        SynEditRegexSearch: TSynEditRegexSearch;
        SynCompletionProposal: TSynCompletionProposal;
        tmrReloadCommands: TTimer;
        SynMarkdownSyn: TSynMarkdownSyn;
        MainMenu: TMainMenu;
        AI1: TMenuItem;
        nShowAIPrompt: TMenuItem;
        nAISettings: TMenuItem;
        cbIgnoreSecurityChecks: TCheckBox;
        tmrSecurityScan: TTimer;
        sbBottom: TStatusBar;
        pnlClient: TPanel;
        pTop: TPanel;
        bAISettings: TButton;
        cbAIModel: TComboBox;
        cbAIHub: TComboBox;
        pcSnippet: TPageControl;
        tsSnippet: TTabSheet;
        sMiddle: TSplitter;
        pAIOverlay: TPanel;
        pbLoading: TProgressBar;
        mAIPrompt: TSynEdit;
        mComment: TSynEdit;
        tsHelp: TTabSheet;
        mInfo: TMemo;
        spTopLeft: TSplitter;
        mContent: TSynEdit;
        procedure bAISettingsClick(Sender: TObject);
        procedure FormDestroy(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        function GetSnippet: TSnippetDTO;
        procedure FormShow(Sender: TObject);
        procedure ebCategorySearchChange(Sender: TObject);
        procedure bOKClick(Sender: TObject);
        procedure bCancelClick(Sender: TObject);
        procedure cbAIHubChange(Sender: TObject);
        procedure cbAIModelChange(Sender: TObject);
        procedure cbIgnoreSecurityChecksClick(Sender: TObject);
        procedure FormClose(Sender: TObject; var Action: TCloseAction);
        procedure lvAllTagsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
        procedure lvAllTagsDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
        procedure lvAllTagsDragDrop(Sender, Source: TObject; X, Y: Integer);
        procedure lvAllTagsDblClick(Sender: TObject);
        procedure mAIPromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure mContentChange(Sender: TObject);
        procedure mContentKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure mContentProcessCommand(Sender: TObject; var Command: TSynEditorCommand; var Char: WideChar; Data: Pointer);
        procedure nAISettingsClick(Sender: TObject);
        procedure nShowAIPromptClick(Sender: TObject);
        procedure SynCompletionProposalExecute(Kind: SynCompletionType; Sender: TObject; var CurrentInput: string; var x, y: Integer; var CanExecute: Boolean);
        procedure tmrReloadCommandsTimer(Sender: TObject);
        procedure tmrSecurityScanTimer(Sender: TObject);
    protected
        procedure Loaded; override;
    private
        FSnippetService: ISnippetService;
        FTagService: ITagService;
        FIsAICanceled: Boolean;
        FFirstShow: Boolean;

        FSnippet: TSnippetDTO;
        FOriginalSnippet: TOriginalSnippet;
        FCategoryID: Integer;
        FUserID: Integer;
        FIsEditMode: Boolean;
        FBasicCommands: TStringList;
        FBlockEnter: Boolean;
        FCurrentHighlighter: TCustomBashSyn;
        FCompletionEngine: TBashCompletionEngine;
        FErrorHandler: IUIErrorHandler;
        FAIService: IAIService;
        FSettingsManager: ISettingsManager;

        procedure ShowAIOverlay;
        procedure ExecuteAICommand;
        function IsAutocompleteVisible: Boolean;
        function IsSnippetChanged: Boolean;
        procedure SetSyntax;
        procedure PopulateHubs;
        procedure PopulateModels(HubIndex: Integer);
        procedure UpdateSecurityStatusUI(IsSafe: Boolean; const Reason: string);
    public
        procedure Prepare(IsEditMode: Boolean; const ASnippet: TSnippetDTO; ACatID, AUserID: Integer);

        property Snippet: TSnippetDTO read FSnippet write FSnippet;
        property CategoryID: Integer read FCategoryID write FCategoryID;
        property UserID: Integer read FUserID write FUserID;

        constructor Create(Owner: TComponent; AppContext: IAppContext); reintroduce;
    end;

var
    AddEditSnippet: TAddEditSnippet;

implementation

uses
    UIHelpers,
    System.Generics.Collections,
    System.DateUtils,
    MainFormUI,
    Tag,
    SynEditKeyCmds,
    CommonHelpers,
    AITextCleaner,
    Vcl.Graphics,
    Vcl.Styles,
    AISettingsFormUI,
    SecurityScanner,
    System.IOUtils,
    Winapi.ActiveX;

{$R *.dfm}

constructor TAddEditSnippet.Create(Owner: TComponent; AppContext: IAppContext);
begin
    // Инициализируем зависимости до вызова inherited
    FSnippetService := AppContext.SnippetService;
    FTagService := AppContext.TagService;
    FSettingsManager := AppContext.SettingsManager;

    if Assigned(FSettingsManager) then
        FBasicCommands := FSettingsManager.BashAutocomplete;

    // Теперь VCL может безопасно создавать форму и вызывать FormCreate/Loaded
    inherited Create(Owner);

    // Создаем движок автокомплита
    FCompletionEngine := TBashCompletionEngine.Create(FBasicCommands);
    FCompletionEngine.LoadFromJsonFile(TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'extra-commands.json'));

    // Сразу применяем подсветку синтаксиса до показа формы (не ждем таймер!)
    SetSyntax;
end;

procedure TAddEditSnippet.bAISettingsClick(Sender: TObject);
begin
    // Вызываем модальную форму редактора структуры ИИ
    if TAISettingsForm.Execute(FSettingsManager) then
    begin
        // Если пользователь сохранил настройки — обновляем выпадающие списки
        // на форме редактирования сниппета, чтобы новые модели сразу появились!
        PopulateHubs;
    end;
end;

procedure TAddEditSnippet.FormDestroy(Sender: TObject);
begin
    // ИСПРАВЛЕНИЕ УТЕЧКИ TSynDropTarget:
    // Принудительно отключаем OLE Drag&Drop до того, как уничтожатся Handle окон.
    if mContent.HandleAllocated then RevokeDragDrop(mContent.Handle);
    if mComment.HandleAllocated then RevokeDragDrop(mComment.Handle);
    if mAIPrompt.HandleAllocated then RevokeDragDrop(mAIPrompt.Handle);

    if Assigned(FCurrentHighlighter) then
        FCurrentHighlighter.Free;

    if Assigned(FCompletionEngine) then
        FCompletionEngine.Free;
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

    Result :=
        (ebTitle.Text <> FOriginalSnippet.Title) or
        (mContent.Text <> FOriginalSnippet.Content) or
        (mComment.Text <> FOriginalSnippet.Comment) or
        (TagsStr <> FOriginalSnippet.Tags);
end;

procedure TAddEditSnippet.bCancelClick(Sender: TObject);
begin
    if FIsEditMode and
        IsSnippetChanged and
        (Application.MessageBox(
            'Обнаружены изменения, которые потеряются в случае закрытия этого окна.' + sLineBreak + sLineBreak +
            'Закрыть окно без сохранения изменений?', 'Внимание', MB_YESNO) = IDNO
        ) then Exit;

    ModalResult := mrCancel;
end;

procedure TAddEditSnippet.bOKClick(Sender: TObject);
var
    Snippet: TSnippetDTO;
    TagIDs: TList<Integer>;
    i: Integer;
    TagArr: TArray<Integer>;
    UnixText: string;
begin
    if Trim(ebTitle.Text) = '' then
    begin
        FErrorHandler.ShowInfo('Введи заголовок сниппета.');
        ModalResult := mrNone;
        Exit;
    end;

    TagIDs := TList<Integer>.Create;
    try
        for i := 0 to lvSelectedTags.Items.Count - 1 do
        begin
            var TagID := Integer(lvSelectedTags.Items[i].Data);
            if TagID > 0 then
                TagIDs.Add(TagID);
        end;
        TagArr := TagIDs.ToArray;
    finally
        TagIDs.Free;
    end;

    UnixText := StringReplace(mContent.Text, #13#10, #10, [rfReplaceAll]);

    Snippet := Default(TSnippetDTO);
    Snippet.UserID := FUserID;
    Snippet.CategoryID := FCategoryID;
    Snippet.Title := ebTitle.Text;
    Snippet.Content := UnixText;
    Snippet.Comment := mComment.Text;
    Snippet.IsSecurityCheckIgnored := cbIgnoreSecurityChecks.Checked;

    try
        if FIsEditMode then
        begin
            Snippet.ID := FSnippet.ID;
            Snippet.CreatedAt := FSnippet.CreatedAt;
            Snippet.UpdatedAt := DateTimeToUnix(Now);

            // Передаем TagArr вместо пустых скобок []
            FSnippetService.UpdateSnippet(Snippet, TagArr);
            ModalResult := mrOk;
        end
        else
        begin
            Snippet.CreatedAt := DateTimeToUnix(Now);
            Snippet.UpdatedAt := 0;

            // Передаем TagArr вместо пустых скобок []
            FSnippetService.CreateSnippet(Snippet, TagArr);
            ModalResult := mrOk;
        end;
    except
        on E: Exception do
        begin
            FErrorHandler.ShowError('Ошибка сохранения сниппета: ' + E.Message);
            ModalResult := mrNone;
        end;
    end;
end;

procedure TAddEditSnippet.cbAIHubChange(Sender: TObject);
var
    SelectedHubIndex: Integer;
begin
    if cbAIHub.ItemIndex < 0 then
        Exit;

    // Получаем индекс хаба, который мы сохранили, и обновляем второй список
    SelectedHubIndex := Integer(IntPtr(cbAIHub.Items.Objects[cbAIHub.ItemIndex]));
    PopulateModels(SelectedHubIndex);
end;

procedure TAddEditSnippet.cbAIModelChange(Sender: TObject);
var
    HubIdx, ModIdx: Integer;
    SelectedAI: TAIItem;
begin
    if (cbAIHub.ItemIndex < 0) or (cbAIModel.ItemIndex < 0) then
        Exit;

    // Получаем индексы
    HubIdx := Integer(IntPtr(cbAIHub.Items.Objects[cbAIHub.ItemIndex]));
    ModIdx := Integer(IntPtr(cbAIModel.Items.Objects[cbAIModel.ItemIndex]));

    // Вытаскиваем выбранную модель
    SelectedAI := FSettingsManager.Data.AISettings[HubIdx].Items[ModIdx];

    // Сюда можно добавить код обновления UI. Например:
    // lbAIInfo.Caption := Format('Лимит: %d токенов, Temp: %0.1f',
    //   [SelectedAI.Params.MaxOutputTokens, SelectedAI.Params.Temperature]);
end;

procedure TAddEditSnippet.cbIgnoreSecurityChecksClick(Sender: TObject);
var
    WarningMsg: string;
begin
    // Если пользователь снимает галочку, нам подтверждение не нужно — просто выходим
    if not cbIgnoreSecurityChecks.Checked then
        Exit;

    WarningMsg :=
        'Активация этого параметра отключит автоматические проверки данного сниппета на безопасность, такие как:' + sLineBreak + sLineBreak +
        '• Инфраструктурные ключи и API-токены' + sLineBreak +
        '• Веб-токены и заголовки авторизации' + sLineBreak +
        '• Пароли и строки подключения к БД' + sLineBreak +
        '• Приватная криптография (SSH/RSA)' + sLineBreak +
        '• Математический анализ энтропии (случайности строк)' + sLineBreak + sLineBreak  +
        'Уверен, что хочешь добавить этот сниппет в исключения сканера?';

    // Если пользователь выбрал "Нет" (отказался):
    if not FErrorHandler.AskWarning(WarningMsg) then
    begin
        // Возвращаем состояние компонента назад без вызова зацикливания
        cbIgnoreSecurityChecks.Checked := False;
    end else begin
        bOK.Enabled := True;
    end;

    // После валидации чекбокса принудительно пересчитываем статус кнопок
    tmrSecurityScanTimer(nil);
end;

procedure TAddEditSnippet.PopulateHubs;
var
    I: Integer;
begin
    cbAIHub.Items.BeginUpdate;
    try
        cbAIHub.Clear;
        for I := 0 to FSettingsManager.Data.AISettings.Count - 1 do
        begin
            // Сохраняем индекс хаба прямо в объект (без выделения памяти)
            cbAIHub.Items.AddObject(FSettingsManager.Data.AISettings[I].Name, TObject(IntPtr(I)));
        end;
    finally
        cbAIHub.Items.EndUpdate;
    end;

    // Если хабы есть, выбираем первый и сразу заполняем список моделей для него
    if cbAIHub.Items.Count > 0 then
    begin
        cbAIHub.ItemIndex := 0;
        PopulateModels(0);
    end;
end;

procedure TAddEditSnippet.ebCategorySearchChange(Sender: TObject);
begin
    if (Length((Sender as TEdit).Text) < 3) then
        Exit;
end;

procedure TAddEditSnippet.ExecuteAICommand;
var
    Instruction, CodeContext: string;
    IsSelection: Boolean;
    HubIdx, ModIdx: Integer;
    SelectedAI: TAIItem;
begin
    Instruction := string(mAIPrompt.Text).Trim;
    if Instruction.IsEmpty then Exit;

    if (cbAIHub.ItemIndex < 0) or (cbAIModel.ItemIndex < 0) then
    begin
        ShowMessage('Выберите провайдера и модель ИИ!');
        Exit;
    end;

    // Получаем реальные индексы из структуры
    HubIdx := Integer(IntPtr(cbAIHub.Items.Objects[cbAIHub.ItemIndex]));
    ModIdx := Integer(IntPtr(cbAIModel.Items.Objects[cbAIModel.ItemIndex]));

    // Берем нужную модель из настроек
    SelectedAI := FSettingsManager.Data.AISettings[HubIdx].Items[ModIdx];

    // Создаем сервис с её параметрами
    FAIService := TYandexAIService.Create(
        SelectedAI.APIKey,
        SelectedAI.Folder,
        SelectedAI.Model,
        SelectedAI.Agent
    );

    IsSelection := mContent.SelText <> '';
    if IsSelection then
        CodeContext := mContent.SelText
    else
        CodeContext := mContent.Text;

    pbLoading.Visible := True;
    mAIPrompt.Enabled := False;
    FIsAICanceled := False; // Сброс перед стартом

    TThread.CreateAnonymousThread(
        procedure
        var
            NewCode: string;
            ErrorMsg: string;
        begin
            try
                NewCode := FAIService.AskAssistant(Instruction, CodeContext);
                NewCode := TAITextCleaner.ExtractPureCode(NewCode);
            except
                on E: Exception do
                    ErrorMsg := E.Message;
            end;

            if FIsAICanceled then Exit;

            TThread.Synchronize(nil, TThreadProcedure(
                procedure
                begin
                    if FIsAICanceled then Exit;

                    pbLoading.Visible := False;
                    mAIPrompt.Enabled := True;
                    pAIOverlay.Visible := False;

                    if ErrorMsg <> '' then
                        ShowMessage('Ошибка: ' + ErrorMsg)
                    else
                    begin
                        mContent.BeginUpdate;
                        try
                            if IsSelection then
                            begin
                                // Если было выделение — заменяем его
                                mContent.SelText := NewCode;
                            end
                            else
                            begin
                                // КАСКАДНЫЙ ЗАПРОС (Вставка в позицию курсора):
                                // Если мы вставляем в существующий текст, добавим красивые отступы,
                                // чтобы новый код не слипался со старым
                                if (mContent.Text <> '') and (mContent.CaretX > 1) then
                                    NewCode := sLineBreak + NewCode;

                                mContent.SelText := NewCode;
                            end;
                        finally
                            mContent.EndUpdate;
                        end;
                    end;
                    mContent.SetFocus;
                end));
        end).Start;
end;

procedure TAddEditSnippet.FormClose(Sender: TObject; var Action: TCloseAction);
begin
    // Сигнализируем фоновому потоку, что форма закрывается и UI трогать нельзя
    FIsAICanceled := True;
end;

procedure TAddEditSnippet.FormCreate(Sender: TObject);
begin
    FFirstShow := True;
    FErrorHandler := TVCLErrorHandler.Create;

    ebTitle.EnableHintText := True;
    ebTitle.HintText := 'Здесь введи имя сниппета...';

    FIsEditMode := False;
    FSnippet := Default(TSnippetDTO);

    lvSelectedTags.StateImages := MainFormUI.MainForm.vilTags;
    lvAllTags.StateImages := MainFormUI.MainForm.vilTags;

    SynCompletionProposal.Options := SynCompletionProposal.Options + [scoUseInsertList];
end;

procedure TAddEditSnippet.FormShow(Sender: TObject);
begin
    // Вся тяжелая работа уже выполнена в памяти
    tmrReloadCommands.Enabled := True;
    ebTitle.SetFocus;
end;

function TAddEditSnippet.GetSnippet: TSnippetDTO;
begin
    Result := FSnippet;
end;

procedure TAddEditSnippet.Loaded;
begin
    inherited;

//    FCompletionEngine := TBashCompletionEngine.Create(FBasicCommands);
//    FCompletionEngine.LoadFromJsonFile(TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'extra-commands.json'));
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
        for i := 0 to SrcLV.Items.Count - 1 do
            if SrcLV.Items[i].Selected then
                ItemsToMove.Add(SrcLV.Items[i]);

        SrcLV.Items.BeginUpdate;
        DstLV.Items.BeginUpdate;
        try
            for Item in ItemsToMove do
            begin
                NewItem := DstLV.Items.Add;
                NewItem.Caption := Item.Caption;
                NewItem.Data := Item.Data;
                NewItem.StateIndex := Item.StateIndex;
            end;

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
    Accept := (Source = lvAllTags) or (Source = lvSelectedTags);
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
            if not Item.Selected then
            begin
                if not (ssCtrl in Shift) then
                    LV.ClearSelection;
                Item.Selected := True;
            end;
            LV.BeginDrag(False, 5);
        end;
    end;
end;

procedure TAddEditSnippet.mAIPromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if Key = VK_ESCAPE then
    begin
        pAIOverlay.Visible := False;
        mContent.SetFocus;
        Key := 0;
    end
    else if Key = VK_RETURN then
    begin
        ExecuteAICommand;
        Key := 0;
    end;
end;

procedure TAddEditSnippet.mContentChange(Sender: TObject);
begin
    // Сбрасываем таймер при каждом изменении текста.
    // Сканер сработает только когда пользователь остановится на 400 мс.
    tmrSecurityScan.Enabled := False;
    tmrSecurityScan.Enabled := True;
end;

procedure TAddEditSnippet.mContentKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if (Key = VK_RETURN) and IsAutocompleteVisible then
    begin
        FBlockEnter := True;
        Exit;
    end;
end;

procedure TAddEditSnippet.mContentProcessCommand(Sender: TObject; var Command: TSynEditorCommand; var Char: WideChar; Data: Pointer);
begin
    if FBlockEnter then
    begin
        if (Command = ecLineBreak) or ((Command = ecChar) and (Char = #13)) then
        begin
            Command := ecNone;
            Char := #0;
        end;
        FBlockEnter := False;
        Exit;
    end;

    if IsAutocompleteVisible then
    begin
        if (Command = ecUp) or (Command = ecDown) or (Command = ecPageUp) or (Command = ecPageDown) then
        begin
            Command := ecNone;
        end;
    end;
end;

procedure TAddEditSnippet.nAISettingsClick(Sender: TObject);
begin
    bAISettingsClick(bAISettings);
end;

procedure TAddEditSnippet.nShowAIPromptClick(Sender: TObject);
begin
    ShowAIOverlay;
end;

procedure TAddEditSnippet.PopulateModels(HubIndex: Integer);
var
    I: Integer;
begin
    cbAIModel.Items.BeginUpdate;
    try
        // Берем модели только из выбранного провайдера
        for I := 0 to FSettingsManager.Data.AISettings[HubIndex].Items.Count - 1 do
        begin
            cbAIModel.Items.AddObject(FSettingsManager.Data.AISettings[HubIndex].Items[I].Name, TObject(IntPtr(I)));
        end;
    finally
        cbAIModel.Items.EndUpdate;
    end;

    if cbAIModel.Items.Count > 0 then
        cbAIModel.ItemIndex := 0;
end;

procedure TAddEditSnippet.Prepare(IsEditMode: Boolean; const ASnippet: TSnippetDTO; ACatID, AUserID: Integer);
var
    i: Integer;
    SnippetTags: TArray<TTagDTO>;
    AllTags: TArray<TTagDTO>;
    Tag: TTagDTO;
begin
    // 1. Принимаем входящие данные
    FIsEditMode := IsEditMode;
    FSnippet := ASnippet;
    FCategoryID := ACatID;
    FUserID := AUserID;

    FIsAICanceled := False;

    // 2. Применяем темы ДО показа на экране
    TSynThemeAdapter.ApplyTheme(mContent);
    TSynThemeAdapter.ApplyTheme(mComment);
    TSynThemeAdapter.ApplyTheme(mAIPrompt);

    // 3. Заполняем комбобоксы ДО показа (Никаких белых вспышек!)
    PopulateHubs;

    // 4. Заполняем теги и списки
    lvAllTags.Items.BeginUpdate;
    lvSelectedTags.Items.BeginUpdate;
    try
        if Assigned(FTagService) then
        begin
            AllTags := FTagService.GetAllTags;
            TUIHelpers.FillTagList(lvAllTags, AllTags);
        end;
        lvSelectedTags.Items.Clear;

        if FIsEditMode then
        begin
            Caption := 'Редактирование сниппета';

            FOriginalSnippet.Title := FSnippet.Title;
            FOriginalSnippet.Content := FSnippet.Content;
            FOriginalSnippet.Comment := FSnippet.Comment;
            FOriginalSnippet.Tags := '';

            ebTitle.Text := FSnippet.Title;
            mContent.Text := FSnippet.Content;
            mComment.Text := FSnippet.Comment;

            if Assigned(FTagService) then
            begin
                SnippetTags := FTagService.GetSnippetTags(FSnippet.ID);
                for Tag in SnippetTags do
                begin
                    for i := lvAllTags.Items.Count - 1 downto 0 do
                    begin
                        if Integer(lvAllTags.Items[i].Data) = Tag.ID then
                        begin
                            var Item := lvSelectedTags.Items.Add;
                            Item.Caption := Tag.Name;
                            Item.Data := Pointer(Integer(Tag.ID));
                            Item.StateIndex := 0;
                            lvAllTags.Items.Delete(i);

                            FOriginalSnippet.Tags := FOriginalSnippet.Tags + ';' + Tag.Name;
                            Break;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Caption := 'Добавление сниппета';
            FOriginalSnippet.Title := '';
            FOriginalSnippet.Content := '';
            FOriginalSnippet.Comment := '';
            FOriginalSnippet.Tags := '';

            ebTitle.Text := '';
            mContent.Text := '';
            mComment.Text := '';
        end;
    finally
        lvSelectedTags.Items.EndUpdate;
        lvAllTags.Items.EndUpdate;
    end;
end;

procedure TAddEditSnippet.SetSyntax;
begin
    if Assigned(FCurrentHighlighter) then
        FreeAndNil(FCurrentHighlighter);

    FCurrentHighlighter := TCustomBashSyn.Create(nil);

    if Assigned(FBasicCommands) then
        TCustomBashSyn(FCurrentHighlighter).ExtraKeywords.AddStrings(FBasicCommands);

    if Assigned(FCompletionEngine) then
        FCompletionEngine.ExportKeywords(FCurrentHighlighter.ExtraKeywords);

    mContent.Highlighter := FCurrentHighlighter;

//    TSynThemeAdapter.ApplyTheme(mContent);
//    TSynThemeAdapter.ApplyTheme(mComment);
//    TSynThemeAdapter.ApplyTheme(mAIPrompt);
end;

procedure TAddEditSnippet.ShowAIOverlay;
begin
    // Устанавливаем стиль прогресс-бара для красоты
    pbLoading.Style := pbstMarquee;
    pbLoading.MarqueeInterval := 30; // Скорость бара
    pbLoading.Visible := False;

    // Просто показываем панель, она уже привязана к форме
    pAIOverlay.Visible := True;
    pAIOverlay.BringToFront;
    mAIPrompt.SetFocus;
end;

procedure TAddEditSnippet.SynCompletionProposalExecute(Kind: SynCompletionType; Sender: TObject; var CurrentInput: string; var x, y: Integer; var CanExecute: Boolean);
var
    LineText: string;
begin
    LineText := Copy(mContent.LineText, 1, mContent.CaretX - 1);
    FCompletionEngine.FillProposals(LineText, SynCompletionProposal.ItemList, SynCompletionProposal.InsertList, CanExecute);
end;

procedure TAddEditSnippet.tmrReloadCommandsTimer(Sender: TObject);
begin
    if FCompletionEngine.CheckForUpdates then
    begin
        ShowSimpleToast('Новая конфигурация', 'Файл автозаполнения обновлён. Содержимое будет перезагружено.');
        SetSyntax;
    end;
end;

procedure TAddEditSnippet.tmrSecurityScanTimer(Sender: TObject);
var
    Security: ISecurityScanner;
    WarningReason: string;
    IsSafe: Boolean;
begin
    tmrSecurityScan.Enabled := False; // Выключаем таймер, чтобы он не циклил

    Security := TSecurityScanner.Create;
    // Проверяем текст из нашего Memo
    IsSafe := not Security.HasSensitiveData(mContent.Text, WarningReason);

    // Обновляем визуальное состояние UI
    UpdateSecurityStatusUI(IsSafe, WarningReason);
end;

procedure TAddEditSnippet.UpdateSecurityStatusUI(IsSafe: Boolean; const Reason: string);
begin
    // Если стоит галочка "Игнорировать", то UI всегда разрешает сохранение
    if cbIgnoreSecurityChecks.Checked then
    begin
        sbBottom.SimpleText := 'ℹ️ Проверки безопасности отключены пользователем.';
        bOK.Enabled := True;
        Exit;
    end;

    if IsSafe then
    begin
        sbBottom.SimpleText := '✅ Текст проверен, угроз безопасности не обнаружено.';
        bOK.Enabled := True;
    end
    else
    begin
        // Найдена угроза, а исключение не настроено
        sbBottom.SimpleText := '⚠ Угроза: ' + Reason + ' (Сохранение заблокировано)';
        ShowSimpleToast('⚠ Угроза безопасности', 'Найдено: ' + Reason);
        // Блокируем кнопку сохранения.
        bOK.Enabled := False;
    end;
end;

end.
