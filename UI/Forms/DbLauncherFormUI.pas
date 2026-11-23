unit DbLauncherFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    Core.Interfaces.Settings,
    System.Classes,
    System.SysUtils,
    System.Types,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.Graphics,
    Vcl.StdCtrls
    ;

type
    // Одна плитка лаунчера: путь базы и уже вычисленные подписи
    TDbTile = record
        Path: string;
        Name: string;
        DirHint: string;
        Exists: Boolean;
        IsCurrent: Boolean;
    end;

    TDbLauncherForm = class(TBaseForm)
        pnlTop: TPanel;
        ebFilter: TEdit;
        pnlTiles: TPanel;
        sbTiles: TScrollBox;
        pbTiles: TPaintBox;
        pnlBottom: TPanel;
        bAllDatabases: TButton;
        bCancel: TButton;
        procedure FormResize(Sender: TObject);
        procedure ebFilterChange(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure pbTilesPaint(Sender: TObject);
        procedure pbTilesMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
        procedure pbTilesMouseDown(Sender: TObject; Button: TMouseButton;
            Shift: TShiftState; X, Y: Integer);
        procedure pbTilesMouseUp(Sender: TObject; Button: TMouseButton;
            Shift: TShiftState; X, Y: Integer);
        procedure pbTilesClick(Sender: TObject);
        procedure pbTilesMouseLeave(Sender: TObject);
        procedure bAllDatabasesClick(Sender: TObject);
    private const
        TILE_MIN_W = 240;
        TILE_H = 92;
        TILE_GAP = 12;
        AREA_MARGIN = 16;
        COLS_MAX = 4;
        ROWS_MAX_VISIBLE = 4;
        // Палитра тёмной темы: приглушённое индиго в тон карточкам макросов
        // (яркий системный акцент на тёмном фоне режет глаз)
        DARK_ACCENT = $005555A0;
        DARK_CARD = $00303030;
        DARK_CARD_BORDER = $00454545;
        DARK_BACKDROP = $00222222;
        DARK_SEL_FILL = $00453A34;
        DARK_SEL_EDGE = $005555A0;
        DARK_SEL_GUTTER = $005555A0;
        LIGHT_CARD = $00FFFFFF;
        LIGHT_CARD_BORDER = $00E3E3E3;
        LIGHT_BACKDROP = $00F7F7F7;
    private
        FAllTiles: TArray<TDbTile>;
        FVisible: TArray<Integer>;
        FSelected: Integer;
        FHovered: Integer;
        FPressed: Integer;
        FSelectedPath: string;
        FNameFont: TFont;
        FHintFont: TFont;
        procedure Localize;
        procedure BuildTiles;
        procedure ApplyFilter;
        procedure RebuildLayout;
        procedure UpdateSelection(Delta: Integer);
        procedure SelectIndex(Index: Integer);
        procedure ActivateTile(Index: Integer);
        procedure EnsureTileVisible(Index: Integer);
        procedure InvalidateTiles(const Indices: TArray<Integer>);
        function TileRect(Index: Integer): TRect;
        function Columns: Integer;
        function HitTest(X, Y: Integer): Integer;
        procedure EnsureFonts;
        procedure DrawTile(Canvas: TCanvas; const R: TRect; const Tile: TDbTile;
            AHovered, APressed, ASelected: Boolean);
        procedure DrawBadge(Canvas: TCanvas; const R: TRect; const AText: string;
            AMissing: Boolean; const ACardFill: TColor);
        procedure DrawSmoothRoundedRect(Canvas: TCanvas; const R: TRect;
            ARadius: Integer; ABackdrop, AFill, APen: TColor; APenWidth,
            ASupersample: Integer);
        class function AccentBlend(Base, Accent: TColor; Alpha: Byte): TColor; static;
    public
        // Модальный выбор базы плитками; возвращает путь выбранной базы,
        // '' = закрыто без выбора. Скрывает унаследованную процедуру
        // Initialize с тем же смыслом параметра
        function Initialize(const AppContext: IAppContext): string; reintroduce;
        destructor Destroy; override;
    end;

// Модальный лаунчер: плитки известных баз (недавние + профили).
// Возвращает путь для открытия, '' = отмена
function ShowDbLauncherForm(const AppContext: IAppContext): string;

implementation

uses
    Common.Localization,
    Common.Settings,
    AllDatabasesFormUI,
    SynThemeAdapter,
    System.IOUtils,
    System.Math,
    Winapi.Windows,
    Vcl.Themes
    ;

{$R *.dfm}

function ShowDbLauncherForm(const AppContext: IAppContext): string;
var
    Form: TDbLauncherForm;
begin
    Form := TDbLauncherForm.Create(nil);
    try
        Result := Form.Initialize(AppContext);
    finally
        Form.Free;
    end;
end;

function TDbLauncherForm.Initialize(const AppContext: IAppContext): string;
begin
    inherited Initialize(AppContext);
    FSelected := -1;
    FHovered := -1;
    FPressed := -1;
    // Скролл-бокс без собственного буфера даёт erase-flash при каждой
    // перерисовке плиток; буфер убирает мерцание, не трогая прокрутку
    sbTiles.DoubleBuffered := True;
    BuildTiles;
    ApplyFilter;
    Localize;
    WarmUpPaint;
    PrepareGuardedShow;
    ShowModal;
    Result := FSelectedPath;
end;

procedure TDbLauncherForm.Localize;
begin
    Caption := TUIStateLoader.GetMessage('Launcher.Title');
    ebFilter.TextHint := TUIStateLoader.GetMessage('Launcher.FilterHint');
    bAllDatabases.Caption := TUIStateLoader.GetMessage('Launcher.AllDatabases');
    bCancel.Caption := TUIStateLoader.GetMessage('Common.Cancel');
end;

procedure TDbLauncherForm.BuildTiles;
var
    Setts: TAppSettings;
    Paths: TArray<string>;
    ConnParts: TStringList;
    CurrentDb: string;
    I: Integer;
begin
    Setts := AppContext.SettingsManager.Data;
    Paths := GetAllDatabasePaths(Setts);

    // Полный путь открытой базы - для пометки «Открыта» на плитке;
    // список путей нормализован, поэтому и текущий приводим к нему
    CurrentDb := '';
    if Assigned(AppContext.DatabaseManager) and AppContext.DatabaseManager.IsConnected then
    begin
        ConnParts := TStringList.Create;
        try
            ConnParts.Text := AppContext.DatabaseManager.GetConnectionString;
            CurrentDb := NormalizeDbProfilePath(ConnParts.Values['Database']);
        finally
            ConnParts.Free;
        end;
    end;

    SetLength(FAllTiles, Length(Paths));
    for I := 0 to High(Paths) do
    begin
        FAllTiles[I].Path := Paths[I];
        FAllTiles[I].Name := ExtractFileName(Paths[I]);
        FAllTiles[I].DirHint := ExtractFilePath(Paths[I]);
        FAllTiles[I].Exists := TFile.Exists(Paths[I]);
        FAllTiles[I].IsCurrent := SameText(Paths[I], CurrentDb);
    end;
end;

procedure TDbLauncherForm.ApplyFilter;
var
    Query: string;
    I: Integer;
begin
    Query := Trim(ebFilter.Text).ToLower;
    SetLength(FVisible, 0);
    for I := 0 to High(FAllTiles) do
        if (Query = '') or FAllTiles[I].Name.ToLower.Contains(Query) or
            FAllTiles[I].Path.ToLower.Contains(Query) then
        begin
            SetLength(FVisible, Length(FVisible) + 1);
            FVisible[High(FVisible)] := I;
        end;

    // Выбор сбрасываем на первую плитку: Enter сразу открывает самую
    // свежую базу, стрелки уточняют выбор
    FSelected := -1;
    FHovered := -1;
    FPressed := -1;
    SelectIndex(0);
    RebuildLayout;
end;

procedure TDbLauncherForm.RebuildLayout;
var
    Rows, ContentH, ClientH: Integer;
begin
    if Length(FVisible) = 0 then
        Rows := 0
    else
        Rows := (Length(FVisible) + Columns - 1) div Columns;
    ContentH := AREA_MARGIN + Rows * (TILE_H + TILE_GAP);
    ClientH := sbTiles.ClientHeight;
    if ClientH <= 0 then
        ClientH := ROWS_MAX_VISIBLE * (TILE_H + TILE_GAP);
    pbTiles.Width := Max(TILE_MIN_W, sbTiles.ClientWidth - GetSystemMetrics(SM_CXVSCROLL) - 2);
    pbTiles.Height := Max(ClientH, ContentH);
    pbTiles.Invalidate;
end;

function TDbLauncherForm.Columns: Integer;
var
    AvailW: Integer;
begin
    AvailW := sbTiles.ClientWidth;
    if AvailW <= 0 then
        AvailW := COLS_MAX * TILE_MIN_W;
    Result := EnsureRange((AvailW - TILE_GAP) div (TILE_MIN_W + TILE_GAP), 1, COLS_MAX);
end;

procedure TDbLauncherForm.SelectIndex(Index: Integer);
var
    Prev: Integer;
begin
    if Length(FVisible) = 0 then
    begin
        if FSelected <> -1 then
        begin
            Prev := FSelected;
            FSelected := -1;
            InvalidateTiles([Prev]);
        end;
        Exit;
    end;

    Index := EnsureRange(Index, 0, High(FVisible));
    if Index <> FSelected then
    begin
        Prev := FSelected;
        FSelected := Index;
        EnsureTileVisible(Index);
        InvalidateTiles([Prev, Index]);
    end;
end;

procedure TDbLauncherForm.UpdateSelection(Delta: Integer);
begin
    if Length(FVisible) = 0 then
        Exit;
    if FSelected < 0 then
        SelectIndex(0)
    else
        SelectIndex(FSelected + Delta);
end;

procedure TDbLauncherForm.ActivateTile(Index: Integer);
begin
    if (Index < 0) or (Index > High(FVisible)) then
        Exit;
    if not FAllTiles[FVisible[Index]].Exists then
        Exit;
    FSelectedPath := FAllTiles[FVisible[Index]].Path;
    ModalResult := mrOk;
end;

procedure TDbLauncherForm.EnsureTileVisible(Index: Integer);
var
    R: TRect;
begin
    R := TileRect(Index);
    if R.Top < sbTiles.VertScrollBar.Position + AREA_MARGIN then
        sbTiles.VertScrollBar.Position := Max(0, R.Top - AREA_MARGIN)
    else if R.Bottom > sbTiles.VertScrollBar.Position + sbTiles.ClientHeight then
        sbTiles.VertScrollBar.Position := R.Bottom - sbTiles.ClientHeight + TILE_GAP;
end;

function TDbLauncherForm.TileRect(Index: Integer): TRect;
var
    Cols, ColW, Col, Row: Integer;
begin
    Cols := Columns;
    // Плитки растягиваются по ширине области: премиальная сетка без
    // рваных правых краёв
    ColW := (pbTiles.Width - 2 * AREA_MARGIN - (Cols - 1) * TILE_GAP) div Cols;
    Col := Index mod Cols;
    Row := Index div Cols;
    Result := TRect.Create(AREA_MARGIN + Col * (ColW + TILE_GAP),
        AREA_MARGIN + Row * (TILE_H + TILE_GAP),
        AREA_MARGIN + Col * (ColW + TILE_GAP) + ColW,
        AREA_MARGIN + Row * (TILE_H + TILE_GAP) + TILE_H);
end;

// Инвалидирует только затронутые плитки (старую и новую), а не весь
// PaintBox: полная перерисовка на каждое движение мыши давала мерцание
procedure TDbLauncherForm.InvalidateTiles(const Indices: TArray<Integer>);
var
    I: Integer;
    R, Dirty: TRect;
    HasDirty: Boolean;
begin
    Dirty := TRect.Empty;
    HasDirty := False;
    for I := 0 to High(Indices) do
        if (Indices[I] >= 0) and (Indices[I] <= High(FVisible)) then
        begin
            // TILE_GAP запаса: хвосты старого состояния (антиалиас углов
            // предыдущего кадра) не должны оставаться на фоне
            R := TileRect(Indices[I]);
            R.Inflate(TILE_GAP, TILE_GAP);
            if HasDirty then
                Dirty.Union(R)
            else
            begin
                Dirty := R;
                HasDirty := True;
            end;
        end;
    if not HasDirty then
        pbTiles.Invalidate
    else
    begin
        // InvalidateRect адресован родителю (PaintBox неоконный), а
        // TileRect - в координатах pbTiles: при прокрутке контрол сдвинут,
        // dirty-область переводим в координаты родителя
        Dirty.Offset(pbTiles.Left, pbTiles.Top);
        Winapi.Windows.InvalidateRect(pbTiles.Parent.Handle, @Dirty, False);
    end;
end;

function TDbLauncherForm.HitTest(X, Y: Integer): Integer;
var
    I: Integer;
begin
    Result := -1;
    for I := 0 to High(FVisible) do
        if TileRect(I).Contains(TPoint.Create(X, Y)) then
            Exit(I);
end;

procedure TDbLauncherForm.EnsureFonts;
begin
    if FNameFont <> nil then
        Exit;
    FNameFont := TFont.Create;
    FNameFont.Name := 'Segoe UI';
    FNameFont.Size := 11;
    FNameFont.Style := [fsBold];
    FHintFont := TFont.Create;
    FHintFont.Name := 'Segoe UI';
    FHintFont.Size := 8;
end;

// Шрифты создаются лениво в отрисовке плиток и не имеют владельца,
// поэтому без явного освобождения FastMM фиксирует утечку TFont после
// каждого запуска лаунчера
destructor TDbLauncherForm.Destroy;
begin
    FreeAndNil(FNameFont);
    FreeAndNil(FHintFont);
    inherited Destroy;
end;

procedure TDbLauncherForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    // KeyPreview: стрелки и Enter обслуживает форма независимо от того,
    // где фокус (в фильтре, на кнопке или на области плиток); Esc оставлен
    // кнопке Cancel. Enter в фильтре не перехватываем, чтобы не мешать
    // правке текста (открытие - по Enter вне фильтра)
    if (Key = VK_RETURN) and (ActiveControl = ebFilter) then
        Exit;
    case Key of
        VK_DOWN:
            begin
                UpdateSelection(Columns);
                Key := 0;
            end;
        VK_UP:
            begin
                UpdateSelection(-Columns);
                Key := 0;
            end;
        VK_RIGHT:
            begin
                UpdateSelection(1);
                Key := 0;
            end;
        VK_LEFT:
            begin
                UpdateSelection(-1);
                Key := 0;
            end;
        VK_RETURN:
            if FSelected >= 0 then
            begin
                ActivateTile(FSelected);
                Key := 0;
            end;
    end;
end;

procedure TDbLauncherForm.ebFilterChange(Sender: TObject);
begin
    ApplyFilter;
end;

procedure TDbLauncherForm.pbTilesPaint(Sender: TObject);
var
    I, TileIdx: Integer;
    Style: TCustomStyleServices;
    EmptyText: string;
    MidR: TRect;
    Backdrop: TColor;
    ClipR: TRect;
    ClipOn: Boolean;
begin
    EnsureFonts;
    Style := StyleServices;

    // Фон области плиток: тонированная подложка, на которой белые карточки
    // читаются за счёт контраста поверхностей, а не рамок. Заливка явная:
    // PaintBox прозрачен, и под ним просвечивал цвет ScrollBox
    if TSynThemeAdapter.IsDarkTheme(Style.GetSystemColor(clWindow)) then
        Backdrop := DARK_BACKDROP
    else
        Backdrop := LIGHT_BACKDROP;
    pbTiles.Canvas.Brush.Style := bsSolid;
    pbTiles.Canvas.Brush.Color := Backdrop;
    pbTiles.Canvas.FillRect(TRect.Create(0, 0, pbTiles.Width, pbTiles.Height));

    if Length(FVisible) = 0 then
    begin
        if Length(FAllTiles) = 0 then
            EmptyText := TUIStateLoader.GetMessage('Launcher.NoDatabases')
        else
            EmptyText := TUIStateLoader.GetMessage('Launcher.NoMatches');
        pbTiles.Canvas.Font := FHintFont;
        pbTiles.Canvas.Font.Color := Style.GetSystemColor(clGrayText);
        MidR := TRect.Create(0, 0, pbTiles.Width, pbTiles.Height);
        Winapi.Windows.DrawText(pbTiles.Canvas.Handle, EmptyText, Length(EmptyText), MidR,
            DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
        Exit;
    end;

    for I := 0 to High(FVisible) do
    begin
        TileIdx := FVisible[I];
        // Частичная инвалидация: плитки вне dirty-области не трогаем,
        // иначе «хвосты» состояний остаются видны
        ClipR := pbTiles.Canvas.ClipRect;
        ClipOn := ClipR.Left < ClipR.Right;
        if ClipOn and (not ClipR.IntersectsWith(TileRect(I))) then
            Continue;
        DrawTile(pbTiles.Canvas, TileRect(I), FAllTiles[TileIdx],
            I = FHovered, I = FPressed, I = FSelected);
    end;
end;

class function TDbLauncherForm.AccentBlend(Base, Accent: TColor; Alpha: Byte): TColor;
begin
    Result := RGB(
        GetRValue(ColorToRGB(Base)) +
        (GetRValue(ColorToRGB(Accent)) - GetRValue(ColorToRGB(Base))) * Alpha div 255,
        GetGValue(ColorToRGB(Base)) +
        (GetGValue(ColorToRGB(Accent)) - GetGValue(ColorToRGB(Base))) * Alpha div 255,
        GetBValue(ColorToRGB(Base)) +
        (GetBValue(ColorToRGB(Accent)) - GetBValue(ColorToRGB(Base))) * Alpha div 255);
end;

procedure TDbLauncherForm.DrawTile(Canvas: TCanvas; const R: TRect;
    const Tile: TDbTile; AHovered, APressed, ASelected: Boolean);
var
    Style: TCustomStyleServices;
    NameR, HintR: TRect;
    CardFill, CardBorder, Backdrop: TColor;
    Radius: Integer;
    Dark: Boolean;
    Accent, NameColor, HintColor: TColor;
begin
    Style := StyleServices;
    Radius := 8;

    // Два набора поверхностей: карточка на тонированной подложке (светлая
    // тема - белая карточка на сером, тёмная - приподнятая поверхность на
    // глубоком фоне). Выделение выражается тоном и акцентным «корешком»,
    // а не сплошной заливкой акцентом
    Dark := TSynThemeAdapter.IsDarkTheme(Style.GetSystemColor(clWindow));
    if Dark then
    begin
        Accent := DARK_ACCENT;
        Backdrop := DARK_BACKDROP;
        CardFill := DARK_CARD;
        CardBorder := DARK_CARD_BORDER;
    end
    else
    begin
        Accent := Style.GetSystemColor(clHighlight);
        Backdrop := LIGHT_BACKDROP;
        CardFill := LIGHT_CARD;
        CardBorder := LIGHT_CARD_BORDER;
    end;

    // Состояния поверх базовой карточки: мягкая тональная динамика,
    // рамка подсвечивается только там, где нужна реакция на курсор
    if APressed then
        CardFill := AccentBlend(CardFill, Accent, 16)
    else if AHovered then
        CardFill := AccentBlend(CardFill, Accent, 9);

    if ASelected then
        CardBorder := Accent
    else if AHovered and not APressed then
        CardBorder := AccentBlend(CardBorder, Accent, 55);

    // Карточка: суперсэмплинг даёт гладкие скругления без «лесенок»
    DrawSmoothRoundedRect(Canvas, R, Radius, Backdrop, CardFill, CardBorder, 1, 4);

    // Акцентный «корешок» слева на выбранной плитке - как маркер текущего
    // элемента в современных оболочках; рисуется с тем же сглаживанием
    if ASelected then
        DrawSmoothRoundedRect(Canvas,
            TRect.Create(R.Left + 4, R.Top + 14, R.Left + 9, R.Bottom - 14),
            2, CardFill, Accent, Accent, 1, 2);

    // Бейдж рисуем ДО текстов: капсула непрозрачная, и при наложении на
    // длинное имя текст должен остаться поверх
    if not Tile.Exists then
        DrawBadge(Canvas, R, TUIStateLoader.GetMessage('AllDatabases.StatusMissing'),
            True, CardFill)
    else if Tile.IsCurrent then
        DrawBadge(Canvas, R, TUIStateLoader.GetMessage('AllDatabases.StatusOpen'),
            False, CardFill);

    NameR := TRect.Create(R.Left + 16, R.Top + 12, R.Right - 16, R.Top + 36);
    HintR := TRect.Create(R.Left + 16, NameR.Bottom + 4, R.Right - 16, R.Bottom - 12);

    Canvas.Brush.Style := bsClear;
    Canvas.Font := FNameFont;
    if not Tile.Exists then
    begin
        NameColor := Style.GetSystemColor(clGrayText);
        HintColor := NameColor;
    end
    else if ASelected then
    begin
        NameColor := Style.GetSystemColor(clWindowText);
        HintColor := Style.GetSystemColor(clGrayText);
    end
    else
    begin
        NameColor := Style.GetSystemColor(clWindowText);
        HintColor := Style.GetSystemColor(clGrayText);
    end;
    Canvas.Font.Color := NameColor;
    Winapi.Windows.DrawText(Canvas.Handle, Tile.Name, Length(Tile.Name), NameR,
        DT_SINGLELINE or DT_END_ELLIPSIS or DT_VCENTER or DT_NOPREFIX);

    Canvas.Font := FHintFont;
    Canvas.Font.Color := HintColor;
    Winapi.Windows.DrawText(Canvas.Handle, Tile.DirHint, Length(Tile.DirHint), HintR,
        DT_SINGLELINE or DT_PATH_ELLIPSIS or DT_VCENTER or DT_NOPREFIX);
end;

procedure TDbLauncherForm.DrawBadge(Canvas: TCanvas; const R: TRect;
    const AText: string; AMissing: Boolean; const ACardFill: TColor);
var
    Style: TCustomStyleServices;
    Dark: Boolean;
    Accent, Fill, TextColor, Backdrop: TColor;
    BadgeW, BadgeH, Radius: Integer;
    BR: TRect;
begin
    Style := StyleServices;
    Dark := TSynThemeAdapter.IsDarkTheme(Style.GetSystemColor(clWindow));
    if Dark then
    begin
        Accent := DARK_ACCENT;
        Backdrop := DARK_BACKDROP;
    end
    else
    begin
        Accent := Style.GetSystemColor(clHighlight);
        Backdrop := LIGHT_BACKDROP;
    end;

    // «Открыта» - плотная капсула цветом акцента с белым текстом: статус
    // читается мгновенно и на обычной, и на выделенной карточке. «Отсутствует»
    // - нейтральный серый тон в цвет карточки, без ложной тревоги
    if AMissing then
    begin
        Fill := AccentBlend(ACardFill, Backdrop, 45);
        TextColor := Style.GetSystemColor(clGrayText);
    end
    else
    begin
        Fill := Accent;
        TextColor := Style.GetSystemColor(clWindow);
    end;

    Canvas.Font := FHintFont;
    BadgeW := Canvas.TextWidth(AText) + 16;
    BadgeH := Canvas.TextHeight(AText) + 6;
    Radius := BadgeH div 2;
    BR := TRect.Create(R.Right - BadgeW - 12, R.Top + 10,
        R.Right - 12, R.Top + 10 + BadgeH);

    // Сглаженная капсула на подложке карточки: чистый GDI без AntiAlias
    // даёт угловатые углы, суперсэмплинг делает их плавными
    DrawSmoothRoundedRect(Canvas, BR, Radius, ACardFill, Fill, Fill, 1, 4);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := TextColor;
    Winapi.Windows.DrawText(Canvas.Handle, AText, Length(AText), BR,
        DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
end;

procedure TDbLauncherForm.DrawSmoothRoundedRect(Canvas: TCanvas; const R: TRect;
    ARadius: Integer; ABackdrop, AFill, APen: TColor; APenWidth,
    ASupersample: Integer);
const
    SS = 4;
var
    Bmp, Out_2: Vcl.Graphics.TBitmap;
    W, H, I, J, SX, SY: Integer;
    SumR, SumG, SumB: Integer;
    SrcRow, DstRow, TexPtr: PRGBTriple;
begin
    // Сглаженный RoundRect: фигура рисуется в 4-кратном разрешении, затем
    // усреднение блоков SSxSS даёт пиксели целевого канваса. Обязательна
    // предзаливка цветом подложки: без неё углы капсулы содержат мусор из
    // неинициализированной памяти битмапа - это и есть «грязные» пиксели
    // вокруг скруглений на скриншотах. Перо с инсетом: GDI рисует обводку
    // центром линии, и без сдвига она срезается краем битмапа
    W := R.Width * SS;
    H := R.Height * SS;
    if (W <= 0) or (H <= 0) then
        Exit;
    Bmp := Vcl.Graphics.TBitmap.Create;
    try
        // PixelFormat до SetSize: иначе реаллокация, и Scanline вернёт
        // строки не той ширины; DDB у GDI мог бы отдать 32 бита на строку
        Bmp.PixelFormat := pf24bit;
        Bmp.SetSize(W, H);
        with Bmp.Canvas do
        begin
            Brush.Style := bsSolid;
            Brush.Color := ColorToRGB(ABackdrop);
            Pen.Style := psClear;
            FillRect(TRect.Create(0, 0, W, H));
            Brush.Color := ColorToRGB(AFill);
            Pen.Style := psSolid;
            Pen.Color := ColorToRGB(APen);
            Pen.Width := APenWidth * SS;
            Pen.Mode := pmCopy;
            RoundRect(APenWidth * SS, APenWidth * SS,
                W - APenWidth * SS + 1, H - APenWidth * SS + 1,
                ARadius * 2 * SS, ARadius * 2 * SS);
        end;

        // Чистый двухбуфер: усреднение SSxSS читает hi-res строки Bmp и
        // пишет компактные строки в Out_2; запись в те же строки, из которых
        // идёт чтение, давала затемнение и «патчи» на плитках
        Out_2 := Vcl.Graphics.TBitmap.Create;
        try
            Out_2.PixelFormat := pf24bit;
            Out_2.SetSize(R.Width, R.Height);
            for J := 0 to R.Height - 1 do
            begin
                DstRow := PRGBTriple(Out_2.ScanLine[J]);
                for I := 0 to R.Width - 1 do
                begin
                    SumR := 0;
                    SumG := 0;
                    SumB := 0;
                    for SY := 0 to SS - 1 do
                    begin
                        SrcRow := PRGBTriple(Bmp.ScanLine[J * SS + SY]);
                        TexPtr := PRGBTriple(PAnsiChar(SrcRow) +
                            I * SS * SizeOf(TRGBTriple));
                        for SX := 0 to SS - 1 do
                        begin
                            SumR := SumR + TexPtr^.rgbtRed;
                            SumG := SumG + TexPtr^.rgbtGreen;
                            SumB := SumB + TexPtr^.rgbtBlue;
                            Inc(TexPtr);
                        end;
                    end;
                    DstRow^.rgbtRed := SumR div (SS * SS);
                    DstRow^.rgbtGreen := SumG div (SS * SS);
                    DstRow^.rgbtBlue := SumB div (SS * SS);
                    Inc(DstRow);
                end;
            end;
            Canvas.CopyMode := cmSrcCopy;
            Canvas.CopyRect(R, Out_2.Canvas, TRect.Create(0, 0, R.Width, R.Height));
        finally
            Out_2.Free;
        end;
    finally
        Bmp.Free;
    end;
end;

procedure TDbLauncherForm.pbTilesMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
    NewHover: Integer;
    PrevHover: Integer;
begin
    NewHover := HitTest(X, Y);

    // Рука только над плиткой, вне плиток - обычный курсор: раньше
    // crHandPoint стоял статически в DFM на весь PaintBox
    if NewHover >= 0 then
        pbTiles.Cursor := crHandPoint
    else
        pbTiles.Cursor := crDefault;

    if NewHover <> FHovered then
    begin
        PrevHover := FHovered;
        FHovered := NewHover;
        InvalidateTiles([PrevHover, NewHover]);
    end;
end;

procedure TDbLauncherForm.pbTilesMouseDown(Sender: TObject; Button: TMouseButton;
    Shift: TShiftState; X, Y: Integer);
var
    Hit: Integer;
begin
    if Button <> mbLeft then
        Exit;
    Hit := HitTest(X, Y);
    if Hit >= 0 then
    begin
        FPressed := Hit;
        SelectIndex(Hit);
        InvalidateTiles([Hit]);
    end;
end;

procedure TDbLauncherForm.pbTilesMouseUp(Sender: TObject; Button: TMouseButton;
    Shift: TShiftState; X, Y: Integer);
var
    PressedTile, ReleasedOn: Integer;
begin
    if Button <> mbLeft then
        Exit;
    PressedTile := FPressed;
    FPressed := -1;
    ReleasedOn := HitTest(X, Y);
    // Открытие одиночным кликом: нажатие и отпускание на одной и той же
    // плитке (как у кнопки); dblclick больше не нужен
    if (PressedTile >= 0) and (ReleasedOn = PressedTile) then
    begin
        InvalidateTiles([PressedTile]);
        ActivateTile(PressedTile);
        Exit;
    end;
    InvalidateTiles([PressedTile, ReleasedOn]);
end;

procedure TDbLauncherForm.pbTilesMouseLeave(Sender: TObject);
begin
    // Курсор ушёл с области плиток: hover, незавершённое нажатие и рука
    // сбрасываем - без этого курсор-рука «залипает» над пустой областью.
    // Инвалидируем ДО сброса индексов: в dirty-область должны попасть
    // ещё «горячие» плитки
    if (FHovered <> -1) or (FPressed <> -1) then
    begin
        InvalidateTiles([FHovered, FPressed]);
        FHovered := -1;
        FPressed := -1;
    end;
    pbTiles.Cursor := crDefault;
end;

procedure TDbLauncherForm.pbTilesClick(Sender: TObject);
var
    Hit: Integer;
begin
    // Клик уже обработан в MouseUp (открытие плитки): здесь остаётся только
    // выбор по клику вне плиток - сбрасываем выделение
    Hit := HitTest(pbTiles.ScreenToClient(Mouse.CursorPos).X,
        pbTiles.ScreenToClient(Mouse.CursorPos).Y);
    if Hit < 0 then
        SelectIndex(-1);
end;

procedure TDbLauncherForm.FormResize(Sender: TObject);
begin
    RebuildLayout;
end;

procedure TDbLauncherForm.bAllDatabasesClick(Sender: TObject);
var
    Chosen: string;
begin
    Chosen := ShowAllDatabasesForm(AppContext);
    if Chosen <> '' then
    begin
        FSelectedPath := Chosen;
        ModalResult := mrOk;
    end;
end;

end.
