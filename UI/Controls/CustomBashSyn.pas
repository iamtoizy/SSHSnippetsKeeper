unit CustomBashSyn;

interface

uses
    System.Classes,
    SynHighlighterUNIXShellScript,
    SynEditHighlighter;

type
  // Наш умный хайлайтер с поддержкой динамического словаря
    TCustomBashSyn = class(TSynUNIXShellScriptSyn)
    private
        FExtraKeywords: TStringList;
    public
        constructor Create(Owner: TComponent); override;
        destructor Destroy; override;
        // Этот метод SynEdit вызывает для КАЖДОГО слова, чтобы узнать его цвет
        function GetTokenAttribute: TSynHighlighterAttributes; override;

        // Сюда мы загрузим наш bash_commands.txt
        property ExtraKeywords: TStringList read FExtraKeywords;
    end;

implementation

{ TCustomBashSyn }

constructor TCustomBashSyn.Create(Owner: TComponent);
begin
    inherited Create(Owner);
    FExtraKeywords := TStringList.Create;

    // КРИТИЧНО для Linux: команды чувствительны к регистру (Docker != docker)
    FExtraKeywords.CaseSensitive := True;

    // Включаем сортировку для мгновенного бинарного поиска (чтобы редактор не тормозил)
    FExtraKeywords.Sorted := True;
end;

destructor TCustomBashSyn.Destroy;
begin
    FExtraKeywords.Free;
    inherited Destroy;
end;

function TCustomBashSyn.GetTokenAttribute: TSynHighlighterAttributes;
begin
  // Сначала спрашиваем стандартный хайлайтер
  Result := inherited GetTokenAttribute;

  // Затем проверяем: если текущее слово есть в нашем словаре...
  // (FExtraKeywords.IndexOf работает за наносекунды благодаря Sorted=True)
  if FExtraKeywords.IndexOf(GetToken) >= 0 then
  begin
    // ...плевать, что думает базовый класс, МЫ решаем, что это ключевое слово!
    Result := KeyAttri;
  end;
end;

end.

