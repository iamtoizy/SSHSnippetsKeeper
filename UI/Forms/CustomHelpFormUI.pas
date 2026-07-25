unit CustomHelpFormUI;

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
    Vcl.Themes,
    HTMLUn2,
    HtmlView,
    HtmlGlobals,
    Vcl.ExtCtrls;

type
    TCustomHelpForm = class(TForm)
        HtmlViewer: THtmlViewer;
        procedure FormCreate(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure FormShow(Sender: TObject);
        procedure HtmlViewerHotSpotClick(Sender: TObject; const SRC: ThtString; var Handled: Boolean);
    private
        FFocusCatcher: TButton;
        function ColorToHtmlHex(AColor: TColor): string;
        function GetHtmlTemplate(const BgColor, TxtColor, AccentColor, PreBgColor, BorderColor: string): string;
    public
        procedure SetContent(Title, MainText, ExpandedText: string);
    end;

var
    CustomHelpForm: TCustomHelpForm;

implementation

uses
    Vcl.Clipbrd,
    CommonHelpers,
    System.RegularExpressions,
    UI.StateLoader
    ;

{$R *.dfm}

procedure TCustomHelpForm.FormCreate(Sender: TObject);
begin
    // Убираем рамку вокруг HTML-вьювера, чтобы он сливался с формой
    HtmlViewer.BorderStyle := htNone;
    // Синхронизируем базовый цвет компонента с цветом формы VCL-стиля
    HtmlViewer.DefBackground := StyleServices.GetSystemColor(clBtnFace);
    // Запрещаем компоненту получать фокус при случайном нажатии клавиши TAB
    HtmlViewer.TabStop := False;

    // --- СОЗДАЕМ ГРОМООТВОД ДЛЯ ФОКУСА ---
    FFocusCatcher := TButton.Create(Self);
    FFocusCatcher.Parent := Self;
    // Прячем кнопку далеко за пределами экрана (в координатах -1000)
    FFocusCatcher.SetBounds(-1000, -1000, 10, 10);
    // Делаем её первой в очереди на получение фокуса
    FFocusCatcher.TabOrder := 0;
end;

{ TCustomHelpForm }

function TCustomHelpForm.ColorToHtmlHex(AColor: TColor): string;
var
    RGBColor: Longint;
begin
    RGBColor := ColorToRGB(AColor);
    Result := Format('#%.2x%.2x%.2x', [GetRValue(RGBColor), GetGValue(RGBColor), GetBValue(RGBColor)]);
end;

procedure TCustomHelpForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if Key = VK_ESCAPE then
    begin
        Key := 0;
        Close;
    end;
end;

procedure TCustomHelpForm.FormShow(Sender: TObject);
begin
    // При появлении формы, VCL захочет кому-то отдать фокус.
    // Мы жестко перенаправляем этот удар на невидимую кнопку
    ActiveControl := FFocusCatcher;
end;

procedure TCustomHelpForm.SetContent(Title, MainText, ExpandedText: string);
var
    VclBg, VclText, VclAccent, VclPreBg, VclBorder: string;
    BodyContent, FinalHtml: string;
begin
    // Вместо clWindow берем clBtnFace, чтобы фон совпал с формой
    VclBg := ColorToHtmlHex(StyleServices.GetSystemColor(clBtnFace));
    VclText := ColorToHtmlHex(StyleServices.GetSystemColor(clWindowText));
    VclAccent := ColorToHtmlHex(StyleServices.GetSystemColor(clHighlight));

    // --- НАСТРОЙКА КОНТРАСТА ЗАГОВОРОВ И БЛОКОВ ПОД ТЕМЫ ---
    if StyleServices.IsSystemStyle then
    begin
        // СВЕТЛАЯ ТЕМА
        VclAccent := '#005A9E';  // Красивый глубокий синий (хорошо виден на светлом фоне)
        VclPreBg := '#F3F4F6';   // Светло-серый фон для кода
        VclBorder := '#D1D5DB';  // Контрастная серая граница
    end
    else
    begin
        // ТЁМНАЯ ТЕМА
        VclAccent := '#56B6C2';  // Приятный пастельный бирюзовый (отлично читается в темноте)
        VclPreBg := '#252526';   // Глубокий темно-серый фон для кода
        VclBorder := '#3F3F46';  // Серая граница
    end;
    // -------------------------------------------------------

    // Явно перекрашиваем сам компонент, чтобы при рендеринге не было старых артефактов
    HtmlViewer.DefBackground := StyleServices.GetSystemColor(clBtnFace);

    // Формируем чистое тело (Body) страницы блоками
    BodyContent := '<h2>' + Title + '</h2>';
    BodyContent := BodyContent + '<p>' + MainText + '</p>';

    if ExpandedText <> '' then
    begin
        // Если текст многострочный, оборачиваем в <pre> для сохранения форматирования
        BodyContent := BodyContent + '<pre>' + ExpandedText + '</pre>';
    end;

    BodyContent := TRegEx.Replace(
        BodyContent, '<code>(.*?)</code>',
        '<a href="copy:$1" class="copy-cmd" title="Click to copy"><code class="copyable">$1</code></a>'
    );

    // Собираем финальный HTML, внедряя контент CSS-шаблон
    FinalHtml := Format(GetHtmlTemplate(VclBg, VclText, VclAccent, VclPreBg, VclBorder), [BodyContent]);

    // Загружаем в память
    HtmlViewer.LoadFromString(FinalHtml);
end;

function TCustomHelpForm.GetHtmlTemplate(const BgColor, TxtColor, AccentColor, PreBgColor, BorderColor: string): string;
begin
  Result :=
    '<!DOCTYPE html><html><head><meta charset="utf-8"><style>' +
    '  body {' +
    '    font-family: "Segoe UI", Tahoma, Arial, sans-serif;' +
    '    font-size: 10pt; line-height: 1.5; padding: 15px; margin: 0;' +
    '    background-color: ' + BgColor + '; color: ' + TxtColor + ';' +
    '  }' +
    '  h2 {' +
    '    font-size: 14pt; font-weight: 600; color: ' + AccentColor + ';' +
    '    margin-top: 0; margin-bottom: 12px; padding-bottom: 6px;' +
    '    border-bottom: 1px solid ' + BorderColor + ';' +
    '  }' +
    '  p { margin-top: 0; margin-bottom: 12px; text-align: left; }' +

    // --- ИСПРАВЛЕННЫЙ БЛОК PRE С АВТОПЕРЕНОСОМ ---
    '  pre {' +
    '    background-color: ' + PreBgColor + '; color: ' + TxtColor + ';' +
    '    padding: 12px; border-radius: 4px; border: 1px solid ' + BorderColor + ';' +
    '    font-family: "Consolas", "Courier New", monospace; font-size: 10pt;' +
    '    margin-top: 10px; margin-bottom: 10px; line-height: 1.4;' +
    '    white-space: pre-wrap;' +       // <--- Магия CSS: сохраняет пробелы, но переносит строки!
    '    word-wrap: break-word;' +       // <--- Дополнительно: разбивает длинные монолитные слова/токены
    '  }' +
    // ----------------------------------------------

    // ... ваш остальной CSS-код без изменений (a.copy-cmd, code.copyable, blockquote и т.д.) ...
    '  a.copy-cmd, a.copy-cmd:link, a.copy-cmd:visited, a.copy-cmd:active, a.copy-cmd:focus {' +
    '    text-decoration: none;' +
    '    color: ' + TxtColor + ';' +
    '    outline: none;' +
    '  }' +
    '  code.copyable {' +
    '    background-color: ' + PreBgColor + ';' +
    '    color: ' + AccentColor + ';' +
    '    padding: 2px 5px; border-radius: 3px; border: 1px solid ' + BorderColor + ';' +
    '    font-family: "Consolas", monospace; font-size: 10pt;' +
    '    cursor: pointer;' +
    '  }' +
    '  a.copy-cmd:hover code.copyable {' +
    '    background-color: ' + AccentColor + '; color: #ffffff;' +
    '  }' +
    '  blockquote {' +
    '    margin: 15px 0; padding: 10px 15px;' +
    '    background-color: ' + PreBgColor + ';' +
    '    border-left: 4px solid ' + AccentColor + '; border-radius: 0 4px 4px 0;' +
    '  }' +
    '  ul, ol { margin-top: 0; margin-bottom: 12px; padding-left: 20px; }' +
    '  li { margin-bottom: 4px; }' +
    '</style></head><body>%s</body></html>';
end;

procedure TCustomHelpForm.HtmlViewerHotSpotClick(Sender: TObject; const SRC: ThtString; var Handled: Boolean);
var
    TextToCopy: string;
begin
    // Если ссылка начинается с префикса 'copy:'
    if SRC.StartsWith('copy:') then
    begin
        TextToCopy := SRC.Substring(5); // Отрезаем слово 'copy:'

        // На случай, если движок заменит пробелы на веб-формат
        TextToCopy := TextToCopy.Replace('%20', ' ');

        // Кладем в буфер обмена Windows
        Clipboard.AsText := TextToCopy;
        Handled := True; // Говорим компоненту, что клик успешно обработан

        // Даем пользователю понять, что копирование прошло успешно (системный звук)
        // Можно заменить на ShowSimpleToast
        MessageBeep(MB_OK);
        ShowSimpleToast(TUIStateLoader.GetMessage('Common.CopiedToClipboard'));

        // После клика тоже забираем фокус у HTMLViewer'а и прячем на кнопку
        ActiveControl := FFocusCatcher;
    end;
end;

end.

