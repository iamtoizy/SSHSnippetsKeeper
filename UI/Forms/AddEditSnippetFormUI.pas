unit AddEditSnippetFormUI;

interface

uses
    UI.Services.AIService,
    BaseFormUI,
    Core.BashCompletionEngine,
    Core.Entities.Snippet,
    Core.Interfaces.App,
    Core.Interfaces.Services,
    Core.Interfaces.Settings,
    Core.Interfaces.UI,
    CustomBashSyn,
    MacroCardController,
    MacroCardPlugin,
    SynCompletionProposal,
    SynEdit,
    SynEditHighlighter,
    SynEditMiscClasses,
    SynEditRegexSearch,
    SynEditTypes,
    SynHighlighterMarkdown,
    SynHighlighterUNIXShellScript,
    System.Classes,
    System.Types,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.Menus,
    Vcl.StdCtrls,
    // Подцепляем последним:
    HintTextEdit,
    System.Actions,
    Vcl.ActnList
    ;

type
    TOriginalSnippet = record
        Title: string;
        Content: string;
        Comment: string;
        Tags: string;
    end;

    TAddEditSnippetForm = class(TBaseForm)
        pLeft: TPanel;
        lbCaption: TLabel;
        ebTitle: TEdit;
        lbAllTags: TLabel;
        lbSelectedTags: TLabel;
        lvSelectedTags: TListView;
        pBottom: TPanel;
        bOK: TButton;
        bCancel: TButton;
        bHistory: TButton;
        lvAllTags: TListView;
        SynUNIXShellScriptSyn: TSynUNIXShellScriptSyn;
        SynEditRegexSearch: TSynEditRegexSearch;
        SynCompletionProposal: TSynCompletionProposal;
        tmrReloadCommands: TTimer;
        SynMarkdownSyn: TSynMarkdownSyn;
        MainMenu: TMainMenu;
        nAI: TMenuItem;
        nShowAIPrompt: TMenuItem;
        nAISettings: TMenuItem;
        cbIgnoreSecurityChecks: TCheckBox;
        tmrSecurityScan: TTimer;
        sbBottom: TStatusBar;
        pClient: TPanel;
        pnlTop: TPanel;
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
        tsMacros: TTabSheet;
        mInfo: TMemo;
        bMacroInsert: TButton;
        pmMacroCard: TPopupMenu;
        pmMacroInsert: TPopupMenu;
        spTopLeft: TSplitter;
        mContent: TSynEdit;
        ActionList: TActionList;
        actShowAIForm: TAction;
        actConfigureAI: TAction;
        procedure actConfigureAIExecute(Sender: TObject);
        procedure actShowAIFormExecute(Sender: TObject);
        procedure bAISettingsClick(Sender: TObject);
        procedure bHistoryClick(Sender: TObject);
        procedure FormDestroy(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        function GetSnippet: TSnippetDTO;
        procedure FormShow(Sender: TObject);
        procedure ebCategorySearchChange(Sender: TObject);
        procedure bOKClick(Sender: TObject);
        procedure bCancelClick(Sender: TObject);
        procedure cbAIHubChange(Sender: TObject);
        procedure cbAIModelChange(Sender: TObject);
        procedure cbIgnoreSecurityChecksClick(Sender: TObject);
        procedure FormClose(Sender: TObject; var Action: TCloseAction);
        procedure FormCloseQueryAI(Sender: TObject; var CanClose: Boolean);
        procedure lvAllTagsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
        procedure lvAllTagsDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
        procedure lvAllTagsDragDrop(Sender, Source: TObject; X, Y: Integer);
        procedure lvAllTagsDblClick(Sender: TObject);
        procedure mAIPromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure mContentChange(Sender: TObject);
        procedure mContentKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure mContentProcessCommand(Sender: TObject; var Command: TSynEditorCommand; var Char: WideChar; Data: Pointer);
        procedure mContentStatusChange(Sender: TObject; Changes: TSynStatusChanges);
        procedure mContentMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
        procedure mContentMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
        procedure mContentMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
        procedure mContentDblClick(Sender: TObject);
        procedure bMacroInsertClick(Sender: TObject);
        procedure bMacroHelpClick(Sender: TObject);
        procedure miCardEditClick(Sender: TObject);
        procedure miCardDuplicateClick(Sender: TObject);
        procedure miCardDeleteClick(Sender: TObject);
        procedure miCardCopyClick(Sender: TObject);
        procedure miEditCopyClick(Sender: TObject);
        procedure miEditCutClick(Sender: TObject);
        procedure miEditPasteClick(Sender: TObject);
        procedure miInsTemplateClick(Sender: TObject);
        procedure SynCompletionProposalExecute(Kind: SynCompletionType; Sender: TObject; var CurrentInput: string; var x, y: Integer; var CanExecute: Boolean);
        procedure tmrReloadCommandsTimer(Sender: TObject);
        procedure tmrSecurityScanTimer(Sender: TObject);
    protected
        procedure Loaded; override;
    private
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
        FAIService: IAIService;
        FAIThread: TThread;
        FAIInProgress: Boolean;
        FWasSecuritySafe: Boolean;
        FRestoredInDB: Boolean;
        FMacroCards: TMacroCardController;
        FCardPlugin: TMacroCardPlugin;
        FInsertTemplates: TStringList;
        FSecurityStatusText: string;
        FDragCard: Integer;
        FDragActive: Boolean;
        FDragDropOffset: Integer;

        procedure ShowAIOverlay;
        procedure ExecuteAICommand;
        function IsAutocompleteVisible: Boolean;
        function IsSnippetChanged: Boolean;
        procedure SetSyntax;
        procedure PopulateHubs;
        procedure PopulateModels(HubIndex: Integer);
        procedure UpdateSecurityStatusUI(IsSafe: Boolean; const Reason: string);
        procedure AIThreadTerminated(Sender: TObject);
        procedure SetupMacroCards;
        procedure UpdateMacroCardMenuVisibility(AOnCard: Boolean);
        procedure UpdateSelectedCard;
        procedure UpdateStatusBar;
        procedure GotoMacroCard(CardPos: Integer);
        function CardPosAtCaret: Integer;
        function CardInsideAtCaret: Integer;
        procedure EditMacroCard(CardPos: Integer);
        procedure FinishCardDrag;
        procedure InsertMacroTemplate(const Template: string);
    public
        procedure Prepare(IsEditMode: Boolean; const Snippet: TSnippetDTO; CatID, UserID: Integer);

        property Snippet: TSnippetDTO read FSnippet write FSnippet;
        property CategoryID: Integer read FCategoryID write FCategoryID;
        property UserID: Integer read FUserID write FUserID;
        property Restored: Boolean read FRestoredInDB;

        constructor Create(Owner: TComponent); override;
        procedure DoInitialize; override;

        class function ExecuteAdd(Owner: TComponent; AppContext: IAppContext; CategoryID, UserID: Integer): Boolean;
        class function ExecuteEdit(Owner: TComponent; AppContext: IAppContext; var SnippetToEdit: TSnippetDTO): Boolean;
    end;

implementation

uses
    UI.Services.AITextCleaner,
    AISettingsFormUI,
    Common.Consts,
    Common.Localization,
    Common.Settings,
    Common.Helpers,
    Core.Entities.Tag,
    HistoryFormUI,
    MainFormUI,
    MacroCardEditorFormUI,
    MacroEngine,
    SecurityScanner,
    SynEditKeyCmds,
    SynThemeAdapter,
    System.DateUtils,
    System.Generics.Collections,
    System.SysUtils,
    UI.BusyIndicator,
    UI.Helpers,
    UI.HoverHelpManager,
    Winapi.ActiveX,
    Winapi.Windows
    ;

{$R *.dfm}

constructor TAddEditSnippetForm.Create(Owner: TComponent);
begin
    inherited Create(Owner);
//    if Assigned(FSettingsManager) then
//        FBasicCommands := FSettingsManager.BashAutocomplete;
//
//    // Теперь VCL может безопасно создавать форму и вызывать FormCreate/Loaded
//    inherited Create(Owner);
//
//    // Создаем движок автокомплита
//    FCompletionEngine := TBashCompletionEngine.Create(FBasicCommands);
//    FCompletionEngine.LoadFromJsonFile(ResolvePath('extra-commands.json'));
//
//    // Сразу применяем подсветку синтаксиса до показа формы (не ждем таймер)
//    SetSyntax;
end;

procedure TAddEditSnippetForm.actConfigureAIExecute(Sender: TObject);
begin
    bAISettingsClick(bAISettings);
end;

procedure TAddEditSnippetForm.actShowAIFormExecute(Sender: TObject);
begin
    ShowAIOverlay;
end;

procedure TAddEditSnippetForm.AIThreadTerminated(Sender: TObject);
begin
    // Этот код выполняется в главном потоке, когда фоновый поток завершился сам
    if Sender = FAIThread then
        FreeAndNil(FAIThread);
end;

procedure TAddEditSnippetForm.bAISettingsClick(Sender: TObject);
begin
    TAISettingsForm.ExecuteGlobal(Application, AppContext);
    PopulateHubs;
end;

procedure TAddEditSnippetForm.bHistoryClick(Sender: TObject);
var
    Ver: TSnippetVersionDTO;
begin
    if FSnippet.ID <= 0 then
        Exit;

    Ver := Default(TSnippetVersionDTO);
    if THistoryForm.Execute(Self, AppContext, FSnippet.ID, Ver) then
    begin
        ebTitle.Text := Ver.Title;
        mContent.Text := Ver.Content;
        mComment.Text := Ver.Comment;

        FOriginalSnippet.Title := Ver.Title;
        FOriginalSnippet.Content := Ver.Content;
        FOriginalSnippet.Comment := Ver.Comment;
        FRestoredInDB := True;
    end;
end;

procedure TAddEditSnippetForm.FormDestroy(Sender: TObject);
begin
    // Исправление утечки TSynDropTarget:
    // Принудительно отключаем OLE Drag&Drop до того, как уничтожатся Handle окон.
    if mContent.HandleAllocated then RevokeDragDrop(mContent.Handle);
    if mComment.HandleAllocated then RevokeDragDrop(mComment.Handle);
    if mAIPrompt.HandleAllocated then RevokeDragDrop(mAIPrompt.Handle);

    FreeAndNil(FCardPlugin);
    FreeAndNil(FMacroCards);
    FreeAndNil(FInsertTemplates);

    if Assigned(FCurrentHighlighter) then
        FCurrentHighlighter.Free;

    if Assigned(FCompletionEngine) then
        FCompletionEngine.Free;

    FIsAICanceled := True; // Сигнал потоку остановиться

    if Assigned(FAIThread) then
    begin
        // Отвязываем событие, чтобы оно не "выстрелило" после ручного удаления потока
        FAIThread.OnTerminate := nil;

        // ВАЖНО: Если у FAIService есть метод прерывания HTTP-запроса
        // (например, Abort, Disconnect или Cancel), обязательно вызвать его здесь!
        // Иначе WaitFor заморозит форму, пока не истечет таймаут сети.
        // FAIService.Abort;

        // Очищаем очередь UI-задач (Queue) этого потока,
        // чтобы они не попытались обратиться к уничтоженным контролам.
        TThread.RemoveQueuedEvents(FAIThread);

        // Дожидаемся корректного завершения и освобождаем память
        FAIThread.WaitFor;
        FreeAndNil(FAIThread);
    end;
end;

procedure TAddEditSnippetForm.DoInitialize;
begin
    FBasicCommands := AppContext.SettingsManager.BashAutocomplete;

    // Создаем движок автокомплита
    FCompletionEngine := TBashCompletionEngine.Create(FBasicCommands);
    FCompletionEngine.LoadFromJsonFile(ResolvePath('bash.autocomplete.json'));

    // Сразу применяем подсветку синтаксиса до показа формы (не ждем таймер)
    SetSyntax;

    // Карточки макросов в mContent
    SetupMacroCards;

    // Регистрация подсказок
    RegisterHelp(mContent, hipTopRight, 'Help.AddEditSnippet.mContent', hkCustomForm);
    RegisterHelp(mComment, hipTopRight, 'Help.AddEditSnippet.mComment', hkCustomForm);
    RegisterHelp(lvAllTags, hipTopRight, 'Help.AddEditSnippet.lvAllTags', hkCustomForm);
    RegisterHelp(lvSelectedTags, hipTopRight, 'Help.AddEditSnippet.lvAllTags', hkCustomForm);
end;

function TAddEditSnippetForm.IsAutocompleteVisible: Boolean;
begin
    Result := Assigned(SynCompletionProposal.Form) and SynCompletionProposal.Form.Visible;
end;

function TAddEditSnippetForm.IsSnippetChanged: Boolean;
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

procedure TAddEditSnippetForm.bCancelClick(Sender: TObject);
begin
    if FIsEditMode and
        IsSnippetChanged and
        (Application.MessageBox(
            PChar(TUIStateLoader.GetMessage('AddEditSnippet.CloseConfirmText')),
            PChar(TUIStateLoader.GetMessage('Common.Warning')),
            MB_YESNO) = IDNO ) then Exit;

    ModalResult := mrCancel;
end;

procedure TAddEditSnippetForm.bOKClick(Sender: TObject);
var
    Snippet: TSnippetDTO;
    TagIDs: TList<Integer>;
    I: Integer;
    TagArr: TArray<Integer>;
    UnixText: string;
begin
    if Trim(ebTitle.Text) = '' then
    begin
        MessagesHandler.ShowInfo(TUIStateLoader.GetMessage('Snippet.TitleEmptyError'));
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
            AppContext.SnippetService.UpdateSnippet(Snippet, TagArr);
            ModalResult := mrOk;
        end
        else
        begin
            Snippet.CreatedAt := DateTimeToUnix(Now);
            Snippet.UpdatedAt := 0;

            // Передаем TagArr вместо пустых скобок []
            AppContext.SnippetService.CreateSnippet(Snippet, TagArr);
            ModalResult := mrOk;
        end;
    except
        on E: Exception do
        begin
            MessagesHandler.ShowError(TUIStateLoader.GetMessage('Snippet.SaveError', [E.Message]));
            ModalResult := mrNone;
        end;
    end;
end;

procedure TAddEditSnippetForm.cbAIHubChange(Sender: TObject);
var
    SelectedHubIndex: Integer;
begin
    if cbAIHub.ItemIndex < 0 then
        Exit;

    // Получаем индекс хаба, который мы сохранили, и обновляем второй список
    SelectedHubIndex := Integer(IntPtr(cbAIHub.Items.Objects[cbAIHub.ItemIndex]));
    PopulateModels(SelectedHubIndex);
end;

procedure TAddEditSnippetForm.cbAIModelChange(Sender: TObject);
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
    SelectedAI := AppContext.SettingsManager.Data.AISettings[HubIdx].Items[ModIdx];

    // Сюда можно добавить код обновления UI. Например:
    // lbAIInfo.Caption := Format('Лимит: %d токенов, Temp: %0.1f',
    //   [SelectedAI.Params.MaxOutputTokens, SelectedAI.Params.Temperature]);
end;

procedure TAddEditSnippetForm.cbIgnoreSecurityChecksClick(Sender: TObject);
begin
    // Если пользователь снимает галочку, нам подтверждение не нужно — просто выходим
    if not cbIgnoreSecurityChecks.Checked then
        Exit;

    // Если пользователь выбрал "Нет" (отказался):
    if not MessagesHandler.AskWarning(
        TUIStateLoader.GetMessage('AddEditSnippet.SecurityWarningText'),
        TUIStateLoader.GetMessage('Common.Warning')
    ) then begin
        // Возвращаем состояние компонента назад без вызова зацикливания
        cbIgnoreSecurityChecks.Checked := False;
    end else begin
        bOK.Enabled := True;
    end;

    // После валидации чекбокса принудительно пересчитываем статус кнопок
    tmrSecurityScanTimer(nil);
end;

procedure TAddEditSnippetForm.PopulateHubs;
var
    I: Integer;
begin
    cbAIHub.Items.BeginUpdate;
    try
        cbAIHub.Clear;
        for I := 0 to AppContext.SettingsManager.Data.AISettings.Count - 1 do
        begin
            // Сохраняем индекс хаба прямо в объект (без выделения памяти)
            cbAIHub.Items.AddObject(AppContext.SettingsManager.Data.AISettings[I].Name, TObject(IntPtr(I)));
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

procedure TAddEditSnippetForm.ebCategorySearchChange(Sender: TObject);
begin
    if (Length((Sender as TEdit).Text) < 3) then
        Exit;
end;

class function TAddEditSnippetForm.ExecuteAdd(Owner: TComponent; AppContext: IAppContext; CategoryID, UserID: Integer): Boolean;
var
    Frm: TAddEditSnippetForm;
    NewSnippet: TSnippetDTO;
begin
    // Индикатор с момента клика и до фактического показа формы
    // (скрывается в TBaseForm.DoShownOnScreen при первом показе)
    TUIBusyIndicator.Show(Owner as TCustomForm, TUIStateLoader.GetMessage('Common.PreparingForm'));
    try
        // Используем локальную переменную Frm, а не глобальную форму!
        Frm := TAddEditSnippetForm.Create(Owner);
        try
            Frm.Initialize(AppContext);
            Frm.CategoryID := CategoryID;
            Frm.UserID := UserID;

            NewSnippet := Default(TSnippetDTO);
            Frm.Prepare(False, NewSnippet, CategoryID, UserID);

            Frm.WarmUpPaint;
            Frm.PrepareGuardedShow;

            Result := (Frm.ShowModal = mrOk);
        finally
            Frm.Free;
        end;
    finally
        TUIBusyIndicator.Hide;
    end;
end;

procedure TAddEditSnippetForm.ExecuteAICommand;
var
    Instruction, CodeContext: string;
    IsSelection: Boolean;
    HubIdx, ModIdx: Integer;
    SelectedAI: TAIItem;
    KeyBytes: TBytes;
    KeyText: string;
begin
    Instruction := string(mAIPrompt.Text).Trim;
    if Instruction.IsEmpty then Exit;

    if (cbAIHub.ItemIndex < 0) or (cbAIModel.ItemIndex < 0) then
    begin
        MessagesHandler.ShowError(TUIStateLoader.GetMessage('AddEditSnippet.AIChooseModelError'));
        Exit;
    end;

    // Получаем реальные индексы из структуры
    HubIdx := Integer(IntPtr(cbAIHub.Items.Objects[cbAIHub.ItemIndex]));
    ModIdx := Integer(IntPtr(cbAIModel.Items.Objects[cbAIModel.ItemIndex]));

    // Берем нужную модель из настроек
    SelectedAI := AppContext.SettingsManager.Data.AISettings[HubIdx].Items[ModIdx];

    KeyBytes := UnprotectSecretToBytes(SelectedAI.APIKey);
    try
        KeyText := TEncoding.UTF8.GetString(KeyBytes);
    finally
        WipeSecretBytes(KeyBytes);
    end;

    // Создаем сервис с её параметрами
    FAIService := TYandexAIService.Create(
        KeyText,
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
    FAIInProgress := True;

    FAIThread := TThread.CreateAnonymousThread(
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
                     FAIInProgress := False;

                     if FIsAICanceled then Exit;

                     pbLoading.Visible := False;
                    mAIPrompt.Enabled := True;
                    pAIOverlay.Visible := False;

                    if ErrorMsg <> '' then
                        MessagesHandler.ShowError(TUIStateLoader.GetMessage('Common.GeneralError', [ErrorMsg]))
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
        end);
    // 3. Отключаем автоматическое удаление
    FAIThread.FreeOnTerminate := False;

    // 4. Назначаем обработчик для штатного завершения
    FAIThread.OnTerminate := AIThreadTerminated;

    // 5. Теперь запускаем
    FAIThread.Start;
end;

class function TAddEditSnippetForm.ExecuteEdit(Owner: TComponent; AppContext: IAppContext; var SnippetToEdit: TSnippetDTO): Boolean;
var
    Frm: TAddEditSnippetForm;
begin
    // Индикатор с момента клика и до фактического показа формы
    // (скрывается в TBaseForm.DoShownOnScreen при первом показе)
    TUIBusyIndicator.Show(Owner as TCustomForm, TUIStateLoader.GetMessage('Common.PreparingForm'));
    try
        Frm := TAddEditSnippetForm.Create(Owner);
        try
            Frm.LockDrawing;  // Попытка уменьшить мерцание формы со стилями VCL
            try
                Frm.Initialize(AppContext);
                Frm.Prepare(True, SnippetToEdit, SnippetToEdit.CategoryID, SnippetToEdit.UserID);
            finally
                Frm.UnlockDrawing;  // Попытка уменьшить мерцание формы со стилями VCL
            end;
            Frm.WarmUpPaint;
            Frm.PrepareGuardedShow;

            Result := (Frm.ShowModal = mrOk) or Frm.Restored;
        finally
            Frm.Free;
        end;
    finally
        TUIBusyIndicator.Hide;
    end;
end;

procedure TAddEditSnippetForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
    // Сигнализируем фоновому потоку, что форма закрывается и UI трогать нельзя
    FIsAICanceled := True;
end;

procedure TAddEditSnippetForm.FormCloseQueryAI(Sender: TObject; var CanClose: Boolean);
begin
    // Фоновый AI-поток захватывает Self и через Synchronize трогает контролы:
    // закрытие формы во время запроса = обращение к освобождённой форме
    CanClose := not FAIInProgress;
    if not CanClose then
        MessageBeep(MB_ICONWARNING);
end;

procedure TAddEditSnippetForm.FormCreate(Sender: TObject);
begin
    FFirstShow := True;
    FWasSecuritySafe := True;
    KeyPreview := True;
    OnKeyDown := FormKeyDown;

    ebTitle.EnableHintText := True;
    ebTitle.HintText := TUIStateLoader.GetMessage('AddEditSnippet.EnterSnippetTextHere');

    FIsEditMode := False;
    FSnippet := Default(TSnippetDTO);

    lvSelectedTags.StateImages := MainFormUI.MainForm.vilTags;
    lvAllTags.StateImages := MainFormUI.MainForm.vilTags;

    SynCompletionProposal.Options := SynCompletionProposal.Options + [scoUseInsertList];

    // Закрытие блокируется, пока выполняется AI-запрос (см. FormCloseQueryAI)
    OnCloseQuery := FormCloseQueryAI;
end;

procedure TAddEditSnippetForm.FormShow(Sender: TObject);
begin
    // Вся тяжелая работа уже выполнена в памяти
    tmrReloadCommands.Enabled := True;
    ebTitle.SetFocus;
end;

function TAddEditSnippetForm.GetSnippet: TSnippetDTO;
begin
    Result := FSnippet;
end;

procedure TAddEditSnippetForm.Loaded;
begin
    inherited;
end;

procedure TAddEditSnippetForm.lvAllTagsDblClick(Sender: TObject);
var
    SrcLV, DstLV: TListView;
    Item, NewItem: TListItem;
begin
    SrcLV := Sender as TListView;
    if SrcLV = lvAllTags then
        DstLV := lvSelectedTags
    else
        DstLV := lvAllTags;

    if (DstLV = lvSelectedTags) and (lvSelectedTags.Items.Count >= MAX_SNIPPET_TAGS) then
    begin
        MessagesHandler.ShowWarning(
            TUIStateLoader.GetMessage('Tag.MaxSnippetTagsReached', [MAX_SNIPPET_TAGS]));
        Exit;
    end;

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

procedure TAddEditSnippetForm.lvAllTagsDragDrop(Sender, Source: TObject; X, Y: Integer);
var
    SrcLV, DstLV: TListView;
    Item, NewItem: TListItem;
    I: Integer;
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

        if (DstLV = lvSelectedTags)
            and (DstLV.Items.Count + ItemsToMove.Count > MAX_SNIPPET_TAGS) then
        begin
            MessagesHandler.ShowWarning(
                TUIStateLoader.GetMessage('Tag.MaxSnippetTagsReached', [MAX_SNIPPET_TAGS]));
            Exit;
        end;

        SrcLV.Items.BeginUpdate;
        DstLV.Items.BeginUpdate;
        try
            for Item in ItemsToMove do
            begin
                NewItem := DstLV.Items.Add;
                NewItem.Caption := Item.Caption;
                NewItem.Data := Item.Data;
                if DstLV = lvSelectedTags then
                    NewItem.StateIndex := 1
                else
                    NewItem.StateIndex := 0;
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

procedure TAddEditSnippetForm.lvAllTagsDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
    Accept := (Source = lvAllTags) or (Source = lvSelectedTags);
    if Sender = Source then
        Accept := False;
end;

procedure TAddEditSnippetForm.lvAllTagsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
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

procedure TAddEditSnippetForm.mAIPromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
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

procedure TAddEditSnippetForm.mContentChange(Sender: TObject);
begin
    // Сбрасываем таймер при каждом изменении текста.
    // Сканер сработает только когда пользователь остановится на 400 мс.
    tmrSecurityScan.Enabled := False;
    tmrSecurityScan.Enabled := True;

    if Assigned(FMacroCards) then
    begin
        FMacroCards.Rescan;
        if Assigned(FCardPlugin) then
            FCardPlugin.SelectedCard := FMacroCards.TokenAtBufferPos(mContent.CaretXY);
    end;

    UpdateStatusBar;
end;

procedure TAddEditSnippetForm.mContentStatusChange(Sender: TObject; Changes: TSynStatusChanges);
begin
    if Changes * [scAll, scCaretX, scCaretY] <> [] then
        UpdateSelectedCard;
end;

procedure TAddEditSnippetForm.mContentMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
    DC: TDisplayCoord;
    BP: TBufferCoord;
    OnCard: Boolean;
    ScreenPt: TPoint;
begin
    if Button = mbLeft then
    begin
        if FDragActive then
        begin
            FinishCardDrag;
            mContent.Invalidate;
        end;
        mContent.SuppressMouseSelection := False;
        FDragActive := False;
        FDragCard := -1;
        FDragDropOffset := -1;
        Exit;
    end;

    if Button <> mbRight then
        Exit;
    if not Assigned(FMacroCards) then
        Exit;

    DC := mContent.PixelsToNearestRowColumn(X, Y);
    BP := mContent.DisplayToBufferPos(DC);
    OnCard := FMacroCards.TokenAtBufferPos(BP) >= 0;

    if OnCard then
        mContent.CaretXY := BP;

    UpdateMacroCardMenuVisibility(OnCard);

    ScreenPt := mContent.ClientToScreen(Point(X, Y));
    pmMacroCard.Popup(ScreenPt.X, ScreenPt.Y);
end;

procedure TAddEditSnippetForm.mContentMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
    BP: TBufferCoord;
begin
    FDragActive := False;
    FDragCard := -1;
    FDragDropOffset := -1;
    mContent.SuppressMouseSelection := False;
    if Assigned(FCardPlugin) then
        FCardPlugin.DragActive := False;
    if (Button <> mbLeft) or (not Assigned(FMacroCards)) then
        Exit;

    BP := mContent.DisplayToBufferPos(mContent.PixelsToNearestRowColumn(X, Y));
    FDragCard := FMacroCards.TokenAtBufferPos(BP);
    if (FDragCard >= 0) and (ssCtrl in Shift) then
    begin
        FDragActive := True;
        if Assigned(FCardPlugin) then
            FCardPlugin.DragActive := True;
        mContent.SuppressMouseSelection := True;
        if mContent.CanFocus then
            mContent.SetFocus;
    end;
end;

procedure TAddEditSnippetForm.mContentMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
    BP: TBufferCoord;
    DropOffset: Integer;
begin
    if (not Assigned(FMacroCards)) or (not Assigned(FCardPlugin)) then
        Exit;

    if not FDragActive then
        Exit;

    // Кнопку или Ctrl отпустили вне окна - отменяем перенос
    if [ssLeft, ssCtrl] * Shift <> [ssLeft, ssCtrl] then
    begin
        FDragActive := False;
        FDragCard := -1;
        FDragDropOffset := -1;
        FCardPlugin.DropOffset := -1;
        FCardPlugin.DragActive := False;
        mContent.Invalidate;
        Exit;
    end;

    BP := mContent.DisplayToBufferPos(mContent.PixelsToNearestRowColumn(X, Y));
    DropOffset := FMacroCards.SnapOffsetFromBufferPos(BP);
    FDragDropOffset := DropOffset;
    if FCardPlugin.DropOffset <> DropOffset then
    begin
        FCardPlugin.DropOffset := DropOffset;
        FCardPlugin.DropValid := FMacroCards.CardMoveDropValid(FDragCard, DropOffset);
        mContent.Invalidate;
    end;
end;

procedure TAddEditSnippetForm.FinishCardDrag;
var
    Move: TMacroCardMove;
    SrcStart, SrcEnd: TBufferCoord;
    NewCardPos: Integer;
begin
    if Assigned(FCardPlugin) then
    begin
        FCardPlugin.DropOffset := -1;
        FCardPlugin.DragActive := False;
    end;

    if (not Assigned(FMacroCards)) or (FDragCard < 0) or (FDragDropOffset < 0) then
        Exit;

    Move := FMacroCards.PrepareCardMove(FDragCard, FDragDropOffset);
    if not Move.Valid then
        Exit;

    // Координаты удаления - в исходном тексте
    SrcStart := FMacroCards.BufferPosFromOffset(Move.SrcOffset);
    SrcEnd := FMacroCards.BufferPosFromOffset(Move.SrcOffset + Move.TokenLen);

    mContent.BeginUndoBlock;
    try
        mContent.BlockBegin := SrcStart;
        mContent.BlockEnd := SrcEnd;
        mContent.SelText := '';
        // Позиция вставки - уже в тексте после удаления
        mContent.CaretXY := mContent.CharIndexToRowCol(Move.InsertOffset, #10);
        mContent.SelText := Move.TokenText;
    finally
        mContent.EndUndoBlock;
    end;

    FMacroCards.Rescan;
    NewCardPos := FMacroCards.TokenAtOffset(Move.InsertOffset);
    if NewCardPos >= 0 then
        GotoMacroCard(NewCardPos);
end;

procedure TAddEditSnippetForm.mContentDblClick(Sender: TObject);
begin
    if not Assigned(FMacroCards) then
        Exit;

    if FMacroCards.TokenAtBufferPos(mContent.CaretXY) >= 0 then
        EditMacroCard(FMacroCards.TokenAtBufferPos(mContent.CaretXY));
end;

procedure TAddEditSnippetForm.SetupMacroCards;

    procedure AddCardItem(const MsgKey: string; AHandler: TNotifyEvent; AShortCut: TShortCut; AOnCardOnly: Boolean);
    var
        Item: TMenuItem;
    begin
        Item := TMenuItem.Create(pmMacroCard);
        Item.Caption := TUIStateLoader.GetMessage(MsgKey);
        Item.ShortCut := AShortCut;
        Item.OnClick := AHandler;
        Item.Tag := Ord(AOnCardOnly);
        pmMacroCard.Items.Add(Item);
    end;

    procedure AddInsertItem(const MsgKey, Template: string);
    var
        Item: TMenuItem;
    begin
        Item := TMenuItem.Create(pmMacroInsert);
        Item.Caption := TUIStateLoader.GetMessage(MsgKey);
        Item.OnClick := miInsTemplateClick;
        Item.Tag := FInsertTemplates.Add(Template);
        pmMacroInsert.Items.Add(Item);
    end;

begin
    FMacroCards := TMacroCardController.Create(mContent.Lines);
    FCardPlugin := TMacroCardPlugin.Create(mContent, FMacroCards);
    FInsertTemplates := TStringList.Create;

    pmMacroCard.Items.Clear;
    AddCardItem('Macro.CardEdit', miCardEditClick, ShortCut(VK_F2, []), True);
    AddCardItem('Macro.CardDuplicate', miCardDuplicateClick, ShortCut(Ord('D'), [ssCtrl, ssShift]), True);
    AddCardItem('Macro.CardDelete', miCardDeleteClick, ShortCut(VK_DELETE, [ssCtrl]), True);
    AddCardItem('Macro.CardCopy', miCardCopyClick, ShortCut(Ord('C'), [ssCtrl, ssShift]), True);
    AddCardItem('Macro.CardPaste', miEditPasteClick, ShortCut(Ord('V'), [ssCtrl, ssShift]), True);
    AddCardItem('Common.Copy', miEditCopyClick, ShortCut(Ord('C'), [ssCtrl]), False);
    AddCardItem('Common.Cut', miEditCutClick, ShortCut(Ord('X'), [ssCtrl]), False);
    AddCardItem('Common.Paste', miEditPasteClick, ShortCut(Ord('V'), [ssCtrl]), False);

    pmMacroInsert.Items.Clear;
    AddInsertItem('Macro.InsertSleep', '{SLEEP 500}');
    AddInsertItem('Macro.InsertEnter', '{ENTER}');
    AddInsertItem('Macro.InsertKey', '{SENDKEY CTRL+C}');
    AddInsertItem('Macro.InsertInput', Format('{INPUT %s}', [TUIStateLoader.GetMessage('MacroBuilder.DefaultParamName')]));
    AddInsertItem('Macro.InsertValue', '{DATETIME}');
    AddInsertItem('Macro.InsertClearLine', '{CLEAR_LINE}');
    AddInsertItem('Macro.InsertKeyDelay', '{KEYDELAY 100}');

    mContent.OnStatusChange := mContentStatusChange;
    mContent.OnMouseDown := mContentMouseDown;
    mContent.OnMouseMove := mContentMouseMove;
    mContent.OnMouseUp := mContentMouseUp;
    mContent.OnDblClick := mContentDblClick;

    FDragCard := -1;
    FDragActive := False;
    FDragDropOffset := -1;

    FMacroCards.Rescan;
    FCardPlugin.SelectedCard := -1;
end;

procedure TAddEditSnippetForm.UpdateSelectedCard;
var
    NewSel: Integer;
begin
    if not Assigned(FMacroCards) then
        Exit;

    FMacroCards.Rescan;
    NewSel := FMacroCards.TokenAtBufferPos(mContent.CaretXY);
    if Assigned(FCardPlugin) and (FCardPlugin.SelectedCard <> NewSel) then
    begin
        FCardPlugin.SelectedCard := NewSel;
        mContent.Invalidate;
    end;
    UpdateStatusBar;
end;

procedure TAddEditSnippetForm.UpdateStatusBar;
var
    Count, CardPos: Integer;
    Counter: string;
begin
    if not Assigned(FMacroCards) then
    begin
        sbBottom.SimpleText := FSecurityStatusText;
        Exit;
    end;

    Count := FMacroCards.CardCount;
    CardPos := FMacroCards.TokenAtBufferPos(mContent.CaretXY);

    if (Count > 0) and (CardPos >= 0) then
        Counter := TUIStateLoader.GetMessage('AddEditSnippet.MacroCounterSel', [CardPos + 1, Count])
    else
        Counter := TUIStateLoader.GetMessage('AddEditSnippet.MacroCounter', [Count]);

    if FSecurityStatusText = '' then
        sbBottom.SimpleText := Counter
    else
        sbBottom.SimpleText := FSecurityStatusText + '   |   ' + Counter;
end;

procedure TAddEditSnippetForm.GotoMacroCard(CardPos: Integer);
var
    Token: TMacroToken;
    StartPos: TBufferCoord;
begin
    if CardPos < 0 then
        Exit;

    Token := FMacroCards.CardToken(CardPos);
    StartPos := FMacroCards.BufferPosFromOffset(Token.StartOffset - 1);
    mContent.CaretXY := StartPos;
    mContent.BlockBegin := StartPos;
    mContent.BlockEnd := FMacroCards.BufferPosFromOffset(Token.StartOffset - 1 + Token.Length);
    mContent.EnsureCursorPosVisible;
end;

procedure TAddEditSnippetForm.InsertMacroTemplate(const Template: string);
var
    Caret, TokenPos: TBufferCoord;
    CardPos: Integer;
begin
    mContent.BeginUndoBlock;
    try
        mContent.SelText := Template;
    finally
        mContent.EndUndoBlock;
    end;

    Caret := mContent.CaretXY;
    TokenPos := Caret;
    if TokenPos.Char > 1 then
        Dec(TokenPos.Char);

    CardPos := FMacroCards.TokenAtBufferPos(TokenPos);
    if CardPos >= 0 then
        EditMacroCard(CardPos);
end;

procedure TAddEditSnippetForm.bMacroInsertClick(Sender: TObject);
var
    Pt: TPoint;
begin
    Pt := bMacroInsert.ClientToScreen(Point(0, bMacroInsert.Height));
    pmMacroInsert.Popup(Pt.X, Pt.Y);
end;

procedure TAddEditSnippetForm.bMacroHelpClick(Sender: TObject);
begin
    ShowCustomHelpHtml(
        TUIStateLoader.GetMessage('MacroDoc.Title'),
        TUIStateLoader.GetMessage('MacroDoc.Body'));
end;

procedure TAddEditSnippetForm.miCardEditClick(Sender: TObject);
var
    Caret: TBufferCoord;
    CardPos: Integer;
begin
    if not Assigned(FMacroCards) then
        Exit;

    Caret := mContent.CaretXY;
    CardPos := FMacroCards.TokenAtBufferPos(Caret);
    if CardPos < 0 then
    begin
        if Caret.Char > 1 then
            Dec(Caret.Char);
        CardPos := FMacroCards.TokenAtBufferPos(Caret);
    end;

    if CardPos < 0 then
        Exit;

    EditMacroCard(CardPos);
end;

procedure TAddEditSnippetForm.EditMacroCard(CardPos: Integer);
var
    Token: TMacroToken;
    CardText, NewText: string;
    Editor: TMacroCardEditorForm;
begin
    Token := FMacroCards.CardToken(CardPos);
    CardText := Copy(mContent.Lines.Text, Token.StartOffset, Token.Length);

    Editor := TMacroCardEditorForm.Create(nil);
    try
        Editor.Initialize(AppContext);
        Editor.InitializeCard(CardText);

        if Editor.ShowModal = mrOk then
        begin
            NewText := Editor.GetCardText;
            if NewText <> CardText then
            begin
                mContent.BeginUndoBlock;
                try
                    mContent.BlockBegin := FMacroCards.BufferPosFromOffset(Token.StartOffset - 1);
                    mContent.BlockEnd := FMacroCards.BufferPosFromOffset(Token.StartOffset - 1 + Token.Length);
                    mContent.SelText := NewText;
                finally
                    mContent.EndUndoBlock;
                end;
            end;
        end;
    finally
        Editor.Free;
    end;

    UpdateSelectedCard;
    if mContent.CanFocus then
        mContent.SetFocus;
end;

procedure TAddEditSnippetForm.miCardDuplicateClick(Sender: TObject);
var
    CardPos: Integer;
    NewCardPos: Integer;
    Token: TMacroToken;
begin
    CardPos := FMacroCards.TokenAtBufferPos(mContent.CaretXY);
    if CardPos < 0 then
        Exit;

    Token := FMacroCards.CardToken(CardPos);

    mContent.BeginUndoBlock;
    try
        mContent.CaretXY := FMacroCards.BufferPosFromOffset(Token.StartOffset - 1 + Token.Length);
        mContent.SelText := Copy(mContent.Lines.Text, Token.StartOffset, Token.Length);
    finally
        mContent.EndUndoBlock;
    end;

    FMacroCards.Rescan;
    NewCardPos := FMacroCards.TokenAtOffset(Token.StartOffset - 1 + Token.Length);
    if NewCardPos >= 0 then
        GotoMacroCard(NewCardPos);
end;

procedure TAddEditSnippetForm.miCardDeleteClick(Sender: TObject);
var
    CardPos: Integer;
    Token: TMacroToken;
begin
    CardPos := FMacroCards.TokenAtBufferPos(mContent.CaretXY);
    if CardPos < 0 then
        Exit;

    Token := FMacroCards.CardToken(CardPos);

    mContent.BeginUndoBlock;
    try
        mContent.BlockBegin := FMacroCards.BufferPosFromOffset(Token.StartOffset - 1);
        mContent.BlockEnd := FMacroCards.BufferPosFromOffset(Token.StartOffset - 1 + Token.Length);
        mContent.SelText := '';
    finally
        mContent.EndUndoBlock;
    end;
end;

procedure TAddEditSnippetForm.miCardCopyClick(Sender: TObject);
var
    CardPos: Integer;
    Token: TMacroToken;
    Caret: TBufferCoord;
begin
    CardPos := FMacroCards.TokenAtBufferPos(mContent.CaretXY);
    if CardPos < 0 then
        Exit;

    Token := FMacroCards.CardToken(CardPos);
    Caret := mContent.CaretXY;

    mContent.BlockBegin := FMacroCards.BufferPosFromOffset(Token.StartOffset - 1);
    mContent.BlockEnd := FMacroCards.BufferPosFromOffset(Token.StartOffset - 1 + Token.Length);
    mContent.CopyToClipboard;

    mContent.CaretXY := Caret;
end;

procedure TAddEditSnippetForm.miEditCopyClick(Sender: TObject);
begin
    mContent.CopyToClipboard;
end;

procedure TAddEditSnippetForm.miEditCutClick(Sender: TObject);
begin
    mContent.CutToClipboard;
end;

procedure TAddEditSnippetForm.miEditPasteClick(Sender: TObject);
begin
    mContent.PasteFromClipboard;
end;

procedure TAddEditSnippetForm.miInsTemplateClick(Sender: TObject);
var
    Idx: Integer;
begin
    if not (Sender is TMenuItem) then
        Exit;

    Idx := (Sender as TMenuItem).Tag;
    if (Idx < 0) or (Idx >= FInsertTemplates.Count) then
        Exit;

    InsertMacroTemplate(FInsertTemplates[Idx]);
end;

procedure TAddEditSnippetForm.mContentKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if (Key = VK_RETURN) and IsAutocompleteVisible then
    begin
        FBlockEnter := True;
        Exit;
    end;
end;

procedure TAddEditSnippetForm.UpdateMacroCardMenuVisibility(AOnCard: Boolean);
var
    I: Integer;
begin
    for I := 0 to pmMacroCard.Items.Count - 1 do
        pmMacroCard.Items[I].Visible := (pmMacroCard.Items[I].Tag <> 0) = AOnCard;
end;

function TAddEditSnippetForm.CardPosAtCaret: Integer;
var
    Caret: TBufferCoord;
begin
    Result := FMacroCards.TokenAtBufferPos(mContent.CaretXY);
    if (Result < 0) and (mContent.CaretXY.Char > 1) then
    begin
        Caret := mContent.CaretXY;
        Dec(Caret.Char);
        Result := FMacroCards.TokenAtBufferPos(Caret);
    end;
end;

function TAddEditSnippetForm.CardInsideAtCaret: Integer;
var
    Caret, Prev: TBufferCoord;
begin
    Result := -1;
    if not Assigned(FMacroCards) then
        Exit;

    Caret := mContent.CaretXY;
    if Caret.Char <= 1 then
        Exit;

    Result := FMacroCards.TokenAtBufferPos(Caret);
    if Result < 0 then
        Exit;

    Prev := Caret;
    Dec(Prev.Char);
    if FMacroCards.TokenAtBufferPos(Prev) <> Result then
        Result := -1;
end;

procedure TAddEditSnippetForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
    CardPos: Integer;
    GoEdit, GoDuplicate, GoDelete, GoCopy, GoPaste: Boolean;
begin
    if not Assigned(FMacroCards) or IsAutocompleteVisible then
        Exit;

    GoEdit := (Shift = []) and (Key = VK_F2);
    GoDuplicate := (Shift = [ssCtrl, ssShift]) and (Key = Ord('D'));
    GoDelete := (Shift = [ssCtrl]) and (Key = VK_DELETE);
    GoCopy := (Shift = [ssCtrl, ssShift]) and (Key = Ord('C'));
    GoPaste := (Shift = [ssCtrl, ssShift]) and (Key = Ord('V'));

    if not (GoEdit or GoDuplicate or GoDelete or GoCopy or GoPaste) then
        Exit;

    if ActiveControl <> mContent then
        Exit;

    CardPos := CardPosAtCaret;
    if CardPos < 0 then
        Exit;

    Key := 0;
    mContent.CaretXY := FMacroCards.BufferPosFromOffset(FMacroCards.CardToken(CardPos).StartOffset - 1);

    if GoEdit then
        miCardEditClick(Sender)
    else if GoDuplicate then
        miCardDuplicateClick(Sender)
    else if GoDelete then
        miCardDeleteClick(Sender)
    else if GoCopy then
        miCardCopyClick(Sender)
    else if GoPaste then
        miEditPasteClick(Sender);
end;

procedure TAddEditSnippetForm.mContentProcessCommand(Sender: TObject; var Command: TSynEditorCommand; var Char: WideChar; Data: Pointer);
var
    CardPos: Integer;
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

    // Enter на карточке макроса открывает редактор вместо перевода строки
    if (Command = ecLineBreak) or ((Command = ecChar) and (Char = #13)) then
    begin
        CardPos := CardInsideAtCaret;
        if CardPos >= 0 then
        begin
            Command := ecNone;
            Char := #0;
            EditMacroCard(CardPos);
            Exit;
        end;
    end;

    if IsAutocompleteVisible then
    begin
        if (Command = ecUp) or (Command = ecDown) or (Command = ecPageUp) or (Command = ecPageDown) then
        begin
            Command := ecNone;
        end;
    end;

    if Assigned(FMacroCards) and (FMacroCards.CardCount > 0) then
    begin
        case Command of
            ecWordRight:
            begin
                Command := ecNone;
                GotoMacroCard(FMacroCards.Navigate(FCardPlugin.SelectedCard, 1));
            end;
            ecWordLeft:
            begin
                Command := ecNone;
                GotoMacroCard(FMacroCards.Navigate(FCardPlugin.SelectedCard, -1));
            end;
            ecScrollDown:
            begin
                Command := ecNone;
                GotoMacroCard(FMacroCards.NavigateLine(FCardPlugin.SelectedCard, 1));
            end;
            ecScrollUp:
            begin
                Command := ecNone;
                GotoMacroCard(FMacroCards.NavigateLine(FCardPlugin.SelectedCard, -1));
            end;
        end;
    end;
end;

procedure TAddEditSnippetForm.PopulateModels(HubIndex: Integer);
var
    I: Integer;
begin
    cbAIModel.Items.BeginUpdate;
    try
        // Берем модели только из выбранного провайдера
        for I := 0 to AppContext.SettingsManager.Data.AISettings[HubIndex].Items.Count - 1 do
        begin
            cbAIModel.Items.AddObject(AppContext.SettingsManager.Data.AISettings[HubIndex].Items[I].Name, TObject(IntPtr(I)));
        end;
    finally
        cbAIModel.Items.EndUpdate;
    end;

    if cbAIModel.Items.Count > 0 then
        cbAIModel.ItemIndex := 0;
end;

procedure TAddEditSnippetForm.Prepare(IsEditMode: Boolean; const Snippet: TSnippetDTO; CatID, UserID: Integer);
var
    I: Integer;
    SnippetTags: TArray<TTagDTO>;
    AllTags: TArray<TTagDTO>;
    Tag: TTagDTO;
begin
    // 1. Принимаем входящие данные
    FIsEditMode := IsEditMode;
    FSnippet := Snippet;
    FCategoryID := CatID;
    FUserID := UserID;
    bHistory.Visible := IsEditMode;

    FIsAICanceled := False;

    // 2. Применяем темы ДО показа на экране
    TSynThemeAdapter.ApplyTheme(mContent);
    TSynThemeAdapter.ApplyTheme(mComment);
    TSynThemeAdapter.ApplyTheme(mAIPrompt);

    // 3. Заполняем комбобоксы ДО показа (Никаких белых вспышек)
    PopulateHubs;

    // 4. Заполняем теги и списки
    lvAllTags.Items.BeginUpdate;
    lvSelectedTags.Items.BeginUpdate;
    try
        if Assigned(AppContext.TagService) then
        begin
            AllTags := AppContext.TagService.GetAllTags;
            TUIHelpers.FillTagList(lvAllTags, AllTags);
        end;
        lvSelectedTags.Items.Clear;

        if FIsEditMode then
        begin
            Caption := TUIStateLoader.GetMessage('Snippet.CaptionEdit');

            FOriginalSnippet.Title := FSnippet.Title;
            FOriginalSnippet.Content := FSnippet.Content;
            FOriginalSnippet.Comment := FSnippet.Comment;
            FOriginalSnippet.Tags := '';

            ebTitle.Text := FSnippet.Title;
            mContent.Text := FSnippet.Content;
            mComment.Text := FSnippet.Comment;

            if Assigned(AppContext.TagService) then
            begin
                SnippetTags := AppContext.TagService.GetSnippetTags(FSnippet.ID);
                for Tag in SnippetTags do
                begin
                    for i := lvAllTags.Items.Count - 1 downto 0 do
                    begin
                        if Integer(lvAllTags.Items[i].Data) = Tag.ID then
                        begin
                            var Item := lvSelectedTags.Items.Add;
                            Item.Caption := Tag.Name;
                            Item.Data := Pointer(Integer(Tag.ID));
                            Item.StateIndex := 1;
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
            Caption := TUIStateLoader.GetMessage('Snippet.CaptionAdd');
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

procedure TAddEditSnippetForm.SetSyntax;
begin
    if Assigned(FCurrentHighlighter) then
        FreeAndNil(FCurrentHighlighter);

    FCurrentHighlighter := TCustomBashSyn.Create(nil);

    if Assigned(FBasicCommands) then
        TCustomBashSyn(FCurrentHighlighter).ExtraKeywords.AddStrings(FBasicCommands);

    if Assigned(FCompletionEngine) then
        FCompletionEngine.ExportKeywords(FCurrentHighlighter.ExtraKeywords);

    mContent.Highlighter := FCurrentHighlighter;
end;

procedure TAddEditSnippetForm.ShowAIOverlay;
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

procedure TAddEditSnippetForm.SynCompletionProposalExecute(Kind: SynCompletionType; Sender: TObject; var CurrentInput: string; var x, y: Integer; var CanExecute: Boolean);
var
    LineText: string;
begin
    LineText := Copy(mContent.LineText, 1, mContent.CaretX - 1);
    FCompletionEngine.FillProposals(LineText, SynCompletionProposal.ItemList, SynCompletionProposal.InsertList, CanExecute);
end;

procedure TAddEditSnippetForm.tmrReloadCommandsTimer(Sender: TObject);
begin
    if FCompletionEngine.CheckForUpdates then
    begin
        ShowSimpleToast(TUIStateLoader.GetMessage('AddEditSnippet.AutocompleteUpdated'));
        SetSyntax;
    end;
end;

procedure TAddEditSnippetForm.tmrSecurityScanTimer(Sender: TObject);
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

procedure TAddEditSnippetForm.UpdateSecurityStatusUI(IsSafe: Boolean; const Reason: string);
begin
    // Если стоит галочка "Игнорировать", то UI всегда разрешает сохранение
    if cbIgnoreSecurityChecks.Checked then
    begin
        FSecurityStatusText := TUIStateLoader.GetMessage('AddEditSnippet.SecurityDisabledStatus');
        bOK.Enabled := True;
        UpdateStatusBar;
        Exit;
    end;

    if IsSafe then
    begin
        FSecurityStatusText := TUIStateLoader.GetMessage('AddEditSnippet.SecuritySafeStatus');
        bOK.Enabled := True;
    end
    else
    begin
        // Найдена угроза, а исключение не настроено
        FSecurityStatusText := TUIStateLoader.GetMessage('AddEditSnippet.SecurityThreatStatus', [Reason]);
        if FWasSecuritySafe then
            ShowSimpleToast(
                TUIStateLoader.GetMessage('AddEditSnippet.SecurityToastFound', [Reason]),
                TUIStateLoader.GetMessage('AddEditSnippet.SecurityToastTitle')
            );
        // Блокируем кнопку сохранения.
        bOK.Enabled := False;
    end;

    FWasSecuritySafe := IsSafe;
    UpdateStatusBar;
end;

end.
