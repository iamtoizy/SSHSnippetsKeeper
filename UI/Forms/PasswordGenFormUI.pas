unit PasswordGenFormUI;

interface

uses
    Winapi.Windows,
    Winapi.Messages,
    System.SysUtils,
    System.Variants,
    System.Classes,
    Vcl.Graphics,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.Dialogs,
    Vcl.StdCtrls,
    Vcl.Samples.Spin,
    Core.Interfaces,
    PasswordService,
    Vcl.ComCtrls,
    Vcl.Buttons,
    Vcl.Menus;

type
    // Структура для хранения настроек одного пресета
    TPresetState = record
        Length: Integer;
        Unique: Boolean;
    end;

    TPasswordGenForm = class(TForm)
        seLength: TSpinEdit;
        lbLength: TLabel;
        lbEntropy: TLabel;
        lbEntropyValue: TLabel;
        cbPresets: TComboBox;
        lbPresets: TLabel;
        bGenerate: TButton;
        bInsertAndClose: TButton;
        ebPassword: TEdit;
        cbUnique: TCheckBox;
        pcHost: TPageControl;
        tsHistory: TTabSheet;
        tsCustomSettings: TTabSheet;
        lvHistory: TListView;
        cbLower: TCheckBox;
        cbUpper: TCheckBox;
        cbNumbers: TCheckBox;
        cbSymbols: TCheckBox;
        edInclude: TEdit;
        lbInclude: TLabel;
        ldExclude: TLabel;
        edExclude: TEdit;
        bIncludePresets: TSpeedButton;
        bExcludePresets: TSpeedButton;
        pmCharPresets: TPopupMenu;
        tsBulkMode: TTabSheet;
        seBulkCount: TSpinEdit;
        lbBulkCount: TLabel;
        mBulkResult: TMemo;
        bBulkGenerate: TButton;
        pmBulkGeneration: TPopupMenu;
        N1: TMenuItem;
        N2: TMenuItem;
        pbBulkProgress: TProgressBar;
        bExport: TButton;
        SaveDialog: TSaveDialog;
        procedure bBulkGenerateClick(Sender: TObject);
        procedure bExcludePresetsClick(Sender: TObject);
        procedure bIncludePresetsClick(Sender: TObject);
        procedure bGenerateClick(Sender: TObject);
        procedure bInsertAndCloseClick(Sender: TObject);
        procedure cbLowerClick(Sender: TObject);
        procedure cbNumbersClick(Sender: TObject);
        procedure cbPresetsChange(Sender: TObject);
        procedure cbSymbolsClick(Sender: TObject);
        procedure cbUpperClick(Sender: TObject);
        procedure edExcludeChange(Sender: TObject);
        procedure edIncludeChange(Sender: TObject);
        procedure edIncludeKeyPress(Sender: TObject; var Key: Char);
        procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure FormShortCut(var Msg: TWMKey; var Handled: Boolean);
        procedure lvHistoryClick(Sender: TObject);
        procedure lvHistoryDblClick(Sender: TObject);
        procedure N1Click(Sender: TObject);
        procedure pcHostChanging(Sender: TObject; var AllowChange: Boolean);
        procedure seLengthChange(Sender: TObject);
    private
        // Переменная класса, общая для всех инстансов ExecuteGlobal
        class var FCurrentInstance: TPasswordGenForm;
        // Память состояний
        class var FPresetStates: array[TPasswordPreset] of TPresetState;
        class var FStatesInitialized: Boolean; // Флаг первой инициализации
        FUpdatingUI: Boolean; // Флаг блокировки ложных срабатываний событий
        //
        FPasswordService: IPasswordService; // Используем интерфейс для Clean Architecture
        FSelectedPreset: TPasswordPreset;
        FActiveEditForPresets: TEdit;
        FOldEditWindowProc: TWndMethod; // Хранит "родной" обработчик TEdit
        // Преждевременное прерывание bulk-генерации
        FCancellationToken: Boolean;
        FIsGenerating: Boolean;
        FCloseRequested: Boolean;
        //
        FErrorHandler: IUIErrorHandler;
        //
        procedure UpdateEntropyUI;
        procedure SendStringViaInput(const S: string);
        procedure UpdateHistoryUI;
        procedure InitializeUI;
        procedure ResizeHistoryColumns;
        procedure PresetMenuItemClick(Sender: TObject);
        procedure AppendUniqueChars(AEdit: TEdit; const AChars: string);
        procedure SetupPresetsMenu;
        procedure EditWindowProc(var Message: TMessage); // Перехват Ctrl+C
        procedure DoGenerate(BulkGenerate: Boolean = False; BulkCount: Integer = 1; ExportFileName: string = '');
        procedure SetControlsState(Enabled: Boolean);
        function GetCustomSettingsFromUI: TCustomPasswordSettings;
        function BuildCustomDescription(const Settings: TCustomPasswordSettings): string;
        function FindPresetIndex(APreset: TPasswordPreset): Integer;
    protected
        // Перехватываем изменение размеров формы, чтобы мгновенно пересчитывать колонки
        procedure Resize; override;
        procedure CreateParams(var Params: TCreateParams); override;
    public
        // Классный метод для вызова формы из любой точки приложения (даже по глобальному хоткею)
        class procedure ExecuteGlobal(Owner: TComponent; const PasswordService: IPasswordService);
        constructor Create(Owner: TComponent; PasswordService: IPasswordService); reintroduce;
    end;

var
    PasswordGenForm: TPasswordGenForm;

implementation

uses
    Winapi.CommCtrl,
    System.Types,
    System.UITypes,
    Vcl.Clipbrd,
    CommonHelpers,
    System.Threading,
    System.Math,
    UI.Interfaces
    ;

const
    VISIBLE_SPACE = Char($2423);

{$R *.dfm}

procedure TPasswordGenForm.AppendUniqueChars(AEdit: TEdit; const AChars: string);
var
    C: Char;
begin
    if not Assigned(AEdit) then Exit;

    for C in AChars do
    begin
        // Добавляем символ только если его еще нет в TEdit
        if Pos(C, AEdit.Text) = 0 then
            AEdit.Text := AEdit.Text + C;
    end;

    // Сразу вызываем пересчет энтропии, т.к. состав изменился
    UpdateEntropyUI;
end;

procedure TPasswordGenForm.bGenerateClick(Sender: TObject);
begin
    DoGenerate;
end;

procedure TPasswordGenForm.bInsertAndCloseClick(Sender: TObject);
begin
    ModalResult := mrOk;
end;

function TPasswordGenForm.BuildCustomDescription(const Settings: TCustomPasswordSettings): string;
begin
    Result := 'Custom (';
    if Settings.UseLower then Result := Result + 'a-z,';
    if Settings.UseUpper then Result := Result + 'A-Z,';
    if Settings.UseNumbers then Result := Result + '0-9,';
    if Settings.UseSymbols then Result := Result + 'spec,';

    if not Settings.IncludeChars.IsEmpty then Result := Result + '+inc,';
    if not Settings.ExcludeChars.IsEmpty then Result := Result + '-exc,';

    // Проверяем наличие уже чистого пробела в настройках, но выводим красивый символ
    if Settings.IncludeChars.Contains(' ') or Settings.ExcludeChars.Contains(' ') then
        Result := Result + VISIBLE_SPACE + ',';

    if Result.EndsWith(',') then
        Delete(Result, Result.Length, 1);

    Result := Result + ')';
end;

procedure TPasswordGenForm.cbPresetsChange(Sender: TObject);
var
    NewPreset: TPasswordPreset;
begin
    if cbPresets.ItemIndex < 0 then Exit;

    NewPreset := TPasswordPreset(Integer(cbPresets.Items.Objects[cbPresets.ItemIndex]));

    // Сохраняем текущие значения UI в старый пресет (уходящий)
    // Системные шаблоны не трогаем, их длины неизменны
    if not (FSelectedPreset in [wpMacAddress, wpUUIDv4]) then
    begin
        FPresetStates[FSelectedPreset].Length := seLength.Value;
        FPresetStates[FSelectedPreset].Unique := cbUnique.Checked;
    end;

    // Переключаем на новый пресет
    FSelectedPreset := NewPreset;

    // Загружаем сохраненные значения нового пресета
    FUpdatingUI := True; // Блокируем OnChange спин-бокса, чтобы он не мешал
    try
        seLength.Value := FPresetStates[FSelectedPreset].Length;
        cbUnique.Checked := FPresetStates[FSelectedPreset].Unique;

        // Правила блокировки
        seLength.Enabled := not (FSelectedPreset in [wpMacAddress, wpUUIDv4]);
        cbUnique.Enabled := not (FSelectedPreset in [wpMacAddress, wpUUIDv4]);

        // Показываем/скрываем панель кастомных настроек
        if (FSelectedPreset = wpCustom) then
        begin
            pcHost.ActivePageIndex := 1;
            tsCustomSettings.TabVisible := True;
        end
        else
        begin
            pcHost.ActivePageIndex := 0;
            tsCustomSettings.TabVisible := False;
        end;
    finally
        FUpdatingUI := False;
    end;

    UpdateEntropyUI;
end;

constructor TPasswordGenForm.Create(Owner: TComponent; PasswordService: IPasswordService);
begin
    // Инициализируем поле ДО inherited, чтобы InitializeUI
    // (вызываемый из DFM/VCL) имел к нему доступ
    FPasswordService := PasswordService;
    FErrorHandler := TVCLErrorHandler.Create;

    inherited Create(Owner);
    InitializeUI;
end;

procedure TPasswordGenForm.bBulkGenerateClick(Sender: TObject);
begin
    if FIsGenerating then
    begin
        FCancellationToken := True;
        bBulkGenerate.Enabled := False;
        Exit;
    end;

    // Вводим разумный лимит для TMemo
    if seBulkCount.Value > 10000 then
    begin
        // Если паролей слишком много, предлагаем сразу писать в файл
        if FErrorHandler.AskConfirmation(
            'Отображение более 10 000 паролей на экране может привести к зависанию интерфейса. ' +
            'Рекомендуется сгенерировать их напрямую в файл. ' + sLineBreak + sLineBreak +
            'Продолжить?'
        ) then begin
            SaveDialog.FileName := Format('Mass_Passwords_%s.txt', [FormatDateTime('yyyymmdd_hhnn', Now)]);
            SaveDialog.Filter := 'Текстовые файлы (*.txt)|*.txt';

            if SaveDialog.Execute then
            begin
                mBulkResult.Clear;
                mBulkResult.Lines.Add('Генерация идет напрямую в файл...');
                mBulkResult.Lines.Add(SaveDialog.FileName);

                // Вызываем генерацию, передавая путь к файлу
                DoGenerate(True, seBulkCount.Value, SaveDialog.FileName);
            end;
        end;
    end
    else
    begin
        // Обычная генерация на экран
        mBulkResult.Clear;
        DoGenerate(True, seBulkCount.Value, '');
    end;
end;

procedure TPasswordGenForm.CreateParams(var Params: TCreateParams);
begin
    inherited CreateParams(Params);

    // Если у формы нет владельца (Owner = nil), отвязываем её от главного приложения.
    // Окно станет полностью независимым на уровне Windows API.
    // Значение 0 означает, что родителем окна выступает сам Рабочий стол (Desktop).
    if not Assigned(Owner) then
        Params.WndParent := 0;
end;

procedure TPasswordGenForm.DoGenerate(BulkGenerate: Boolean = False; BulkCount: Integer = 1; ExportFileName: string = '');
var
    Settings: TCustomPasswordSettings;
    Count: Integer;
begin
    // 1. Читаем UI СТРОГО в главном потоке
    if FSelectedPreset = wpCustom then
        Settings := GetCustomSettingsFromUI();

    if BulkGenerate then Count := BulkCount else Count := 1;

    // 2. Подготовка интерфейса
    FIsGenerating := True;
    FCancellationToken := False;
    FCloseRequested := False;

    SetControlsState(False);
    bBulkGenerate.Enabled := True;
    if BulkGenerate then bBulkGenerate.Caption := 'Отмена';

    pbBulkProgress.Position := 0;
    pbBulkProgress.Max := Count;

    // 3. Запуск фонового потока
    TTask.Run(
        procedure
        var
            I, CapturedI: Integer;
            RawPassword: string;
            TempList: TStringList;
            LastUIUpdate: UInt64;
            Writer: TStreamWriter;
            IsDirectToFile: Boolean;
        begin
            IsDirectToFile := (ExportFileName <> '');
            TempList := nil;
            Writer := nil;
            try
                // Инициализируем либо TStringList (для UI), либо TStreamWriter (для прямого потока на диск)
                if IsDirectToFile then
                    Writer := TStreamWriter.Create(ExportFileName, False, TEncoding.UTF8)
                else
                    TempList := TStringList.Create;

                LastUIUpdate := TThread.GetTickCount; // Запоминаем время старта

                for I := 1 to Count do
                begin
                    // Проверка флага отмены от кнопки или закрытия окна
                    if FCancellationToken then Break;

                    // Генерация сырого пароля
                    if FSelectedPreset = wpCustom then
                        RawPassword := FPasswordService.GenerateCustomPassword(Settings, seLength.Value, cbUnique.Checked)
                    else
                        RawPassword := FPasswordService.GeneratePassword(FSelectedPreset, seLength.Value, cbUnique.Checked);

                    // Запись результата
                    if IsDirectToFile then
                        Writer.WriteLine(RawPassword) // Пишем прямо на диск (ОЗУ не расходуется)
                    else
                    begin
                        if BulkGenerate then
                            TempList.Add(RawPassword)
                        else
                            TempList.Add(StringReplace(RawPassword, ' ', VISIBLE_SPACE, [rfReplaceAll]));
                    end;

                    // Защита от зависания интерфейса.
                    // Отправляем сигнал в UI не чаще 1 раза в 50 миллисекунд (20 FPS)
                    if BulkGenerate and (TThread.GetTickCount - LastUIUpdate > 50) then
                    begin
                        CapturedI := I; // Захватываем текущее значение счетчика
                        LastUIUpdate := TThread.GetTickCount;

                        TThread.Queue(nil,
                            procedure
                            begin
                                pbBulkProgress.Position := CapturedI;
                            end);
                    end;
                end;

                // Финализация потока (Ждем главный поток)
                TThread.Synchronize(nil,
                    procedure
                    var
                        PoolSize: Integer;
                        Entropy: Double;
                    begin
                        pbBulkProgress.Position := Count; // Доводим ползунок до конца

                        if FCancellationToken then
                        begin
                            // Если нажали отмену
                            if BulkGenerate then
                                bBulkGenerate.Enabled := True;
                        end
                        else
                        begin
                            if BulkGenerate then
                            begin
                                if IsDirectToFile then
                                    ShowSimpleToast('Менеджер сниппетов', 'Успешно сохранено в файл')
                            else
                            begin
                                mBulkResult.Lines.BeginUpdate;
                                try
                                    mBulkResult.Text := TempList.Text;
                                finally
                                    mBulkResult.Lines.EndUpdate;
                                end;
                            end;
                            end
                            else
                            begin
                                // Логика одиночного пароля
                                ebPassword.Text := TempList[0];

                                if FSelectedPreset = wpCustom then
                                begin
                                    PoolSize := FPasswordService.GetCustomPoolSize(Settings);
                                    Entropy := FPasswordService.CalculateEntropy(seLength.Value, PoolSize);
                                    FPasswordService.AddToHistoryCustom(RawPassword, BuildCustomDescription(Settings), seLength.Value, Entropy);
                                end
                                else
                                    FPasswordService.AddToHistory(RawPassword, FSelectedPreset, seLength.Value);
                            end;
                        end;

                        // ВОЗВРАЩАЕМ UI К ЖИЗНИ
                        bBulkGenerate.Caption := 'Массовая генерация';
                        SetControlsState(True);
                        FIsGenerating := False;

                        if not BulkGenerate then
                        begin
                            pcHost.ActivePageIndex := 0;
                            UpdateHistoryUI;
                        end;

                        // МАГИЯ: Если пользователь пытался закрыть форму во время генерации,
                        // мы дождались остановки потока и теперь честно её закрываем!
                        if FCloseRequested then
                            Close;
                    end);
            finally
                if Assigned(TempList) then TempList.Free;
                if Assigned(Writer) then Writer.Free;
            end;
        end);
end;

procedure TPasswordGenForm.bExcludePresetsClick(Sender: TObject);
var
    Pt: TPoint;
begin
    FActiveEditForPresets := edExclude; // Запоминаем, куда будем вставлять

    // Показываем меню ровно под нажатой кнопкой
    Pt := bExcludePresets.ClientToScreen(Point(0, bExcludePresets.Height));
    pmCharPresets.Popup(Pt.X, Pt.Y);
end;

procedure TPasswordGenForm.bIncludePresetsClick(Sender: TObject);
var
    Pt: TPoint;
begin
    FActiveEditForPresets := edInclude; // Запоминаем, куда будем вставлять

    // Показываем меню ровно под нажатой кнопкой
    Pt := bIncludePresets.ClientToScreen(Point(bIncludePresets.Width, bIncludePresets.Height));
    pmCharPresets.Alignment := paRight;
    pmCharPresets.Popup(Pt.X, Pt.Y);
end;

procedure TPasswordGenForm.cbLowerClick(Sender: TObject);
begin
    UpdateEntropyUI;
end;

procedure TPasswordGenForm.cbNumbersClick(Sender: TObject);
begin
    UpdateEntropyUI;
end;

procedure TPasswordGenForm.cbSymbolsClick(Sender: TObject);
begin
    UpdateEntropyUI;
end;

procedure TPasswordGenForm.cbUpperClick(Sender: TObject);
begin
    UpdateEntropyUI;
end;

procedure TPasswordGenForm.edExcludeChange(Sender: TObject);
begin
    UpdateEntropyUI;
end;

procedure TPasswordGenForm.edIncludeChange(Sender: TObject);
begin
    UpdateEntropyUI;
end;

procedure TPasswordGenForm.edIncludeKeyPress(Sender: TObject; var Key: Char);
begin
    // Если пользователь нажал обычный пробел, подменяем его на видимый символ
    if Key = ' ' then
    begin
        Key := VISIBLE_SPACE;
    end;
end;

procedure TPasswordGenForm.InitializeUI;
var
    Preset: TPasswordPreset;
begin
    // Инициализируем массив памяти только один раз за время жизни приложения
    if not FStatesInitialized then
    begin
        for Preset := Low(TPasswordPreset) to High(TPasswordPreset) do
        begin
            FPresetStates[Preset].Length := 32;    // Стандартная длина
            FPresetStates[Preset].Unique := False; // Галочка выключена
        end;

        // Задаем индивидуальные разумные длины для специфичных шаблонов
        FPresetStates[wpPinCode].Length := 4;
        FPresetStates[wpActiveDirectory].Length := 12;
        FPresetStates[wpWebStandard].Length := 16;
        FPresetStates[wpMacAddress].Length := 17;
        FPresetStates[wpUUIDv4].Length := 36;

        FStatesInitialized := True;
    end;

    // Подготовка компонентов
    cbPresets.Items.BeginUpdate;
    try
        cbPresets.Clear;
        for Preset := Low(TPasswordPreset) to High(TPasswordPreset) do
            cbPresets.Items.AddObject(FPasswordService.GetPresetDescription(Preset), TObject(Integer(Preset)));
    finally
        cbPresets.Items.EndUpdate;
    end;

    SetupPresetsMenu;

    // Начальные настройки для кастомной панели
    cbLower.Checked := True;
    cbUpper.Checked := True;
    cbNumbers.Checked := True;
    cbSymbols.Checked := True;

    // Адаптируем кнопку под контекст вызова
    if Assigned(Owner) then
        bInsertAndClose.Caption := 'Скопировать и закрыть'
    else
        bInsertAndClose.Caption := 'Вставить и закрыть';

    // Подменяем оконную процедуру поля ebPassword
    FOldEditWindowProc := ebPassword.WindowProc;
    ebPassword.WindowProc := EditWindowProc;

    pcHost.ActivePage := tsHistory;

    // Выбор стартового пресета и загрузка его состояния
    if cbPresets.Items.Count > 0 then
    begin
        cbPresets.ItemIndex := 0;
        // Здесь мы НЕ вызываем cbPresetsChange вручную, а делаем всё аккуратно
        FSelectedPreset := TPasswordPreset(Integer(cbPresets.Items.Objects[0]));

        FUpdatingUI := True;
        try
            seLength.Value := FPresetStates[FSelectedPreset].Length;
            cbUnique.Checked := FPresetStates[FSelectedPreset].Unique;
        finally
            FUpdatingUI := False;
        end;
    end;

    UpdateEntropyUI;
    UpdateHistoryUI;
end;

procedure TPasswordGenForm.EditWindowProc(var Message: TMessage);
var
    TextToCopy, CleanText: string;
begin
    // Ловим сообщение копирования (срабатывает и на Ctrl+C, и на меню ПКМ -> Копировать)
    if Message.Msg = WM_COPY then
    begin
        // Если текст выделен мышью - берем выделенное.
        // Если ничего не выделено - берем весь пароль (улучшенный UX!)
        if ebPassword.SelLength > 0 then
            TextToCopy := ebPassword.SelText
        else
            TextToCopy := ebPassword.Text;

        if TextToCopy <> '' then
        begin
            // Очищаем от видимых символов
            CleanText := StringReplace(TextToCopy, VISIBLE_SPACE, ' ', [rfReplaceAll]);

            // Кладем в буфер обмена чистый пароль
            Vcl.Clipbrd.Clipboard.AsText := CleanText;
        end;

        // ВАЖНО: Мы НЕ вызываем FOldEditWindowProc(Message).
        // Тем самым мы блокируем стандартный механизм копирования TEdit,
        // чтобы он не перезаписал наш правильный пароль своими "видимыми" пробелами.
    end
    else
    begin
        // Все остальные сотни сообщений (отрисовка, клики, фокус)
        // послушно передаем родному обработчику TEdit
        FOldEditWindowProc(Message);
    end;
end;

class procedure TPasswordGenForm.ExecuteGlobal(Owner: TComponent; const PasswordService: IPasswordService);
var
    TargetWnd: HWND;
    PasswordToType: string;
begin
    if Assigned(FCurrentInstance) then
    begin
        if FCurrentInstance.WindowState = wsMinimized then
            FCurrentInstance.WindowState := wsNormal;

        // Форсируем выход на передний план уже открытого окна
        SetForegroundWindow(FCurrentInstance.Handle);
        FCurrentInstance.BringToFront;
        Exit;
    end;

    // Передаем исходный Owner (nil или MainForm)
    FCurrentInstance := TPasswordGenForm.Create(Owner, PasswordService);
    try
        TargetWnd := GetForegroundWindow;

        // Если форма независимая (Owner = nil), форсируем StayOnTop, чтобы она гарантированно
        // выскочила поверх стороннего активного приложения (терминала, браузера)
//        if not Assigned(Owner) then
            FCurrentInstance.FormStyle := fsStayOnTop;

        // Заставляем Windows передать фокус нашей форме
        SetForegroundWindow(FCurrentInstance.Handle);

        if FCurrentInstance.ShowModal = mrOk then
        begin
            // Получаем чистый пароль без визуальных пробелов
            PasswordToType := StringReplace(FCurrentInstance.ebPassword.Text, VISIBLE_SPACE, ' ', [rfReplaceAll]);

            if not Assigned(Owner) then
            begin
                if (TargetWnd <> 0) and IsWindow(TargetWnd) then
                begin
                    // Перед возвратом фокуса терминалу нужно снять блокировку StayOnTop,
                    // иначе DWM Windows может запутаться с Z-Order при эмуляции ввода
                    FCurrentInstance.FormStyle := fsNormal;

                    SetForegroundWindow(TargetWnd);
                    Sleep(100);
                    FCurrentInstance.SendStringViaInput(PasswordToType);
                end;
            end
            else
            begin
                // 2. ЛОГИКА ДЛЯ ГЛАВНОГО МЕНЮ (Только копирование)
                if PasswordToType <> '' then
                    Vcl.Clipbrd.Clipboard.AsText := PasswordToType;
            end;
        end;
    finally
        // Безопасное зануление ссылки интерфейса перед уничтожением формы
        if Assigned(FCurrentInstance) then
            FCurrentInstance.FPasswordService := nil;
        FreeAndNil(FCurrentInstance);
    end;
end;

procedure TPasswordGenForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
    if FIsGenerating then
    begin
        // Если идет генерация, запрещаем закрытие!
        CanClose := False;

        // Командуем потоку остановиться и запоминаем, что хотели закрыть окно
        FCancellationToken := True;
        FCloseRequested := True;

        Caption := 'Остановка генератора, ожидайте...';
        bBulkGenerate.Enabled := False;
    end
    else
        CanClose := True; // Если генерации нет, закрываемся свободно
end;

procedure TPasswordGenForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    case Key of
        VK_F5:
        begin
            bGenerateClick(Self);
            Key := 0;
        end;
    end;

end;

function TPasswordGenForm.GetCustomSettingsFromUI: TCustomPasswordSettings;
begin
    Result.UseLower := cbLower.Checked;
    Result.UseUpper := cbUpper.Checked;
    Result.UseNumbers := cbNumbers.Checked;
    Result.UseSymbols := cbSymbols.Checked;

    // Сразу заменяем VISIBLE_SPACE на реальный пробел
    Result.IncludeChars := StringReplace(edInclude.Text, VISIBLE_SPACE, ' ', [rfReplaceAll]);
    Result.ExcludeChars := StringReplace(edExclude.Text, VISIBLE_SPACE, ' ', [rfReplaceAll]);
end;

procedure TPasswordGenForm.lvHistoryClick(Sender: TObject);
begin
   if Assigned(lvHistory.Selected) and (lvHistory.Selected.SubItems.Count > 1) then
    begin
        // Текст в таблице уже содержит VISIBLE_SPACE,
        // поэтому просто переносим его в поле ввода.
        ebPassword.Text := lvHistory.Selected.SubItems[1];
    end;
end;

procedure TPasswordGenForm.lvHistoryDblClick(Sender: TObject);
begin
    if Assigned(lvHistory.Selected) then
    begin
        // "Нажимаем" строку за пользователя (для надёжности, нельзя полагаться на VCL)
        lvHistoryClick(lvHistory);
        // Нажать кнопку "Вставить и закрыть" за пользователя
        bInsertAndCloseClick(Self);
    end;
end;

procedure TPasswordGenForm.N1Click(Sender: TObject);
begin
    if mBulkResult.Lines.Count = 0 then Exit;
    Clipboard.AsText := mBulkResult.Text;
    ShowSimpleToast('Менеджер сниппетов', 'Сгенерированные пароли скопированы в буфер обмена.');
end;

procedure TPasswordGenForm.pcHostChanging(Sender: TObject; var AllowChange: Boolean);
begin
    // Если идет процесс генерации, мы просто запрещаем смену вкладки
    if FIsGenerating then
        AllowChange := False
end;

procedure TPasswordGenForm.PresetMenuItemClick(Sender: TObject);
var
    MenuItem: TMenuItem;
    CharsToAdd: string;
begin
    if not (Sender is TMenuItem) then Exit;
    MenuItem := TMenuItem(Sender);

    // Мы сохраним сами символы в свойство Hint пункта меню при его создании
    CharsToAdd := MenuItem.Hint;

    // Вставляем символы в тот TEdit, кнопка которого была нажата
    AppendUniqueChars(FActiveEditForPresets, CharsToAdd);
end;

procedure TPasswordGenForm.Resize;
begin
    inherited;
    // Срабатывает при любом изменении размеров формы (включая первое появление на экране)
    ResizeHistoryColumns;
end;

procedure TPasswordGenForm.ResizeHistoryColumns;
var
    TotalClientWidth: Integer;
    FixedWidthSum: Integer;
    SharedRemainingWidth: Integer;
begin
    if (lvHistory.Columns.Count < 5) or not lvHistory.HandleAllocated then
        Exit;

    lvHistory.Items.BeginUpdate;
    try
        // 1. Для колонок 0 и 1 (они не последние) константа USEHEADER (-2) работает идеально
        lvHistory.Columns[0].Width := LVSCW_AUTOSIZE_USEHEADER;
        lvHistory.Columns[1].Width := LVSCW_AUTOSIZE_USEHEADER;

        // 2. Для колонки Энтропии (она ПОСЛЕДНЯЯ) применяем просто AUTOSIZE (-1).
        // Это запретит Windows принудительно растягивать её до правого края окна.
        lvHistory.Columns[4].Width := LVSCW_AUTOSIZE;

        // Страховка: если таблица пуста, AUTOSIZE вернет 0.
        // Зададим жесткий минимум, чтобы слово "Энтропия" всегда помещалось.
        if lvHistory.Columns[4].Width < 70 then
            lvHistory.Columns[4].Width := 70;

        // 3. Добавляем паддинги, чтобы цифры не слипались с границами
        lvHistory.Columns[0].Width := lvHistory.Columns[0].Width + 2;
        lvHistory.Columns[1].Width := lvHistory.Columns[1].Width + 2;
        lvHistory.Columns[4].Width := lvHistory.Columns[4].Width + 4;

        // 4. Берем чистую клиентскую ширину (без учета скроллбара)
        TotalClientWidth := lvHistory.ClientWidth;

        // 5. Вычисляем, сколько места заняли Дата, Время и Энтропия
        FixedWidthSum := lvHistory.Columns[0].Width + lvHistory.Columns[1].Width + lvHistory.Columns[4].Width;

        // 6. Всё оставшееся место честно и поровну делим между Паролем (2) и Шаблоном (3)
        if TotalClientWidth > FixedWidthSum then
        begin
            SharedRemainingWidth := (TotalClientWidth - FixedWidthSum) div 2;

            // Минимальная ширина для Пароля и Шаблона
            if SharedRemainingWidth < 90 then
                SharedRemainingWidth := 90;

            lvHistory.Columns[2].Width := SharedRemainingWidth;
            lvHistory.Columns[3].Width := SharedRemainingWidth;
        end;
    finally
        lvHistory.Items.EndUpdate;
    end;
end;

procedure TPasswordGenForm.seLengthChange(Sender: TObject);
begin
    if FUpdatingUI then Exit; // Защита от срабатывания во время смены пресета
    UpdateEntropyUI;
end;

procedure TPasswordGenForm.SendStringViaInput(const S: string);
var
    Inputs: array of TInput;
    I, Index: Integer;
begin
    SetLength(Inputs, Length(S) * 2);

    for I := 1 to Length(S) do
    begin
        Index := (I - 1) * 2;
        // Нажатие клавиши в UNICODE (работает независимо от текущей раскладки ОС)
        Inputs[Index].Itype := INPUT_KEYBOARD;
        Inputs[Index].ki.wVk := 0;
        Inputs[Index].ki.wScan := Ord(S[I]);
        Inputs[Index].ki.dwFlags := KEYEVENTF_UNICODE;

        // Отпускание клавиши
        Inputs[Index + 1].Itype := INPUT_KEYBOARD;
        Inputs[Index + 1].ki.wVk := 0;
        Inputs[Index + 1].ki.wScan := Ord(S[I]);
        Inputs[Index + 1].ki.dwFlags := KEYEVENTF_UNICODE or KEYEVENTF_KEYUP;
    end;

    if Length(Inputs) > 0 then
        SendInput(Length(Inputs), Inputs[0], SizeOf(TInput));
end;

procedure TPasswordGenForm.SetControlsState(Enabled: Boolean);
begin
    bGenerate.Enabled := Enabled;
    bBulkGenerate.Enabled := True;

    bInsertAndClose.Enabled := Enabled;
    cbPresets.Enabled := Enabled;
    seLength.Enabled := Enabled;
    bExport.Enabled := Enabled;
    ebPassword.Enabled := Enabled;
    cbUnique.Enabled := Enabled;
    tsHistory.Enabled := Enabled;

    // Блокируем настройки внутри вкладок вместо самих вкладок
    seBulkCount.Enabled := Enabled;

    // Учитываем специфику шаблонов при разблокировке!
    seLength.Enabled := Enabled and not (FSelectedPreset in [wpMacAddress, wpUUIDv4]);
    cbUnique.Enabled := Enabled and not (FSelectedPreset in [wpMacAddress, wpUUIDv4]);

    // Настройки кастомного режима тоже лучше заморозить
    cbLower.Enabled := Enabled;
    cbUpper.Enabled := Enabled;
    cbNumbers.Enabled := Enabled;
    cbSymbols.Enabled := Enabled;
    edInclude.Enabled := Enabled;
    edExclude.Enabled := Enabled;
end;

procedure TPasswordGenForm.SetupPresetsMenu;
    procedure AddItem(const ACaption, AChars: string);
    var
        MI: TMenuItem;
    begin
        MI := TMenuItem.Create(pmCharPresets);
        MI.Caption := ACaption + '  [' + AChars + ']';
        MI.Hint := AChars; // Прячем сами символы в Hint
        MI.OnClick := PresetMenuItemClick;
        pmCharPresets.Items.Add(MI);
    end;
begin
    pmCharPresets.Items.Clear;
    AddItem('Похожие символы', 'Il1O0');
    AddItem('Скобки', '[]{}()');
    AddItem('Знаки препинания', '.,:;');
    AddItem('Опасные для Bash/SQL', '$\`!&|<>');
    AddItem('Кавычки', '''"');
    AddItem('Пробел', VISIBLE_SPACE);
    AddItem('Разделители URL / Веб', '&?=#%');
    AddItem('Символы путей / JSON', '\/');
    AddItem('Математические знаки', '+-*/%=^~');
end;

procedure TPasswordGenForm.UpdateEntropyUI;
var
    PoolSize: Integer;
    Entropy: Double;
    Settings: TCustomPasswordSettings;
begin
    if not Assigned(FPasswordService) then
        Exit;

    if FSelectedPreset = wpCustom then
    begin
        Settings.UseLower := cbLower.Checked;
        Settings.UseUpper := cbUpper.Checked;
        Settings.UseNumbers := cbNumbers.Checked;
        Settings.UseSymbols := cbSymbols.Checked;
        Settings.IncludeChars := edInclude.Text;
        Settings.ExcludeChars := edExclude.Text;
        // Переводим символ в пробел для честного расчета размера пула бэкендом
        Settings.IncludeChars := StringReplace(edInclude.Text, VISIBLE_SPACE, ' ', [rfReplaceAll]);
        Settings.ExcludeChars := StringReplace(edExclude.Text, VISIBLE_SPACE, ' ', [rfReplaceAll]);
        PoolSize := FPasswordService.GetCustomPoolSize(Settings);
    end
    else
        PoolSize := FPasswordService.GetPoolSize(FSelectedPreset);

    Entropy := FPasswordService.CalculateEntropy(seLength.Value, PoolSize);
    lbEntropyValue.Caption := Format('%.1f бит', [Entropy]);
end;

procedure TPasswordGenForm.UpdateHistoryUI;
var
    History: TArray<TPasswordHistoryItem>;
    Item: TPasswordHistoryItem;
    LI: TListItem;
    VisiblePassword: string;
begin
    if not Assigned(FPasswordService) then
        Exit;

    lvHistory.Items.BeginUpdate;
    try
        lvHistory.Items.Clear;
        History := FPasswordService.GetHistory;

        for Item in History do
        begin
            LI := lvHistory.Items.Add;
            LI.Caption := FormatDateTime('dd:mm:yyyy', Item.CreatedAt);
            LI.SubItems.Add(FormatDateTime('hh:nn:ss', Item.CreatedAt));

            // Заменяем пробел визуальным символом перед выводом в таблицу
            VisiblePassword := StringReplace(Item.Password, ' ', VISIBLE_SPACE, [rfReplaceAll]);
            LI.SubItems.Add(VisiblePassword);

            LI.SubItems.Add(Item.PresetName);
            LI.SubItems.Add(Format('%.0f бит', [Item.Entropy]));
        end;
    finally
        lvHistory.Items.EndUpdate;
    end;

    ResizeHistoryColumns;
end;

function TPasswordGenForm.FindPresetIndex(APreset: TPasswordPreset): Integer;
var
    I: Integer;
begin
    Result := -1;
    for I := 0 to cbPresets.Items.Count - 1 do
    begin
        if TPasswordPreset(Integer(cbPresets.Items.Objects[I])) = APreset then
        begin
            Result := I;
            Exit;
        end;
    end;
end;

procedure TPasswordGenForm.FormShortCut(var Msg: TWMKey; var Handled: Boolean);
var
    ShiftState: TShiftState;
    TargetIndex: Integer;
begin
    Handled := False; // По умолчанию говорим, что событие не обработано

    // Извлекаем состояние управляющих клавиш (Alt, Ctrl, Shift) из параметров сообщения Windows
    ShiftState := KeyDataToShiftState(Msg.KeyData);

    // Срабатывает только если зажат строго ALT (без Ctrl и Shift)
    if ShiftState = [ssAlt] then
    begin
        TargetIndex := -1;

        // Msg.CharCode содержит Virtual Key Code физической клавиши.
        // Физическая клавиша 'C' всегда возвращает Ord('C') (код 67),
        // независимо от текущей раскладки Windows (русская или английская)!
        case Msg.CharCode of
            Ord('1'): TargetIndex := FindPresetIndex(wpWebStandard);
            Ord('2'): TargetIndex := FindPresetIndex(wpActiveDirectory);
            Ord('3'): TargetIndex := FindPresetIndex(wpStrictAlphaNumeric);
            Ord('4'): TargetIndex := FindPresetIndex(wpMacAddress);
            Ord('5'): TargetIndex := FindPresetIndex(wpUUIDv4);
            Ord('6'): TargetIndex := FindPresetIndex(wpBase64Key);
            Ord('7'): TargetIndex := FindPresetIndex(wpBashSafe);
            Ord('8'): TargetIndex := FindPresetIndex(wpDockerEnvSafe);
            Ord('9'): TargetIndex := FindPresetIndex(wpBitrixDb);
            Ord('0'): TargetIndex := FindPresetIndex(wpPinCode);
            Ord('C'): TargetIndex := FindPresetIndex(wpCustom);
            Ord('H'): TargetIndex := FindPresetIndex(wpHexToken);
            Ord('U'): TargetIndex := FindPresetIndex(wpUrlSafe);
            Ord('O'): TargetIndex := FindPresetIndex(wpOracleSafe);
        end;

        // Если нашли совпадение по горячей клавише
        if TargetIndex >= 0 then
        begin
            cbPresets.ItemIndex := TargetIndex;
            cbPresetsChange(cbPresets); // Вызываем синхронизацию

            Handled := True; // Сообщаем VCL, что событие перехвачено и обработано
        end;
    end;
end;

end.

