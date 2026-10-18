unit HintTextEdit;

interface

uses
    System.Classes,
    Vcl.StdCtrls
    ;

type
    TEdit = class(Vcl.StdCtrls.TEdit)
    private
        FEnableHintText: Boolean;
        FMaskedStr: string;
        procedure PrepareMaskStr;
        procedure SetEnableHintText(const Value: Boolean);
        function GetHintText: string;
        procedure SetHintText(const Value: string);
    protected
        // Переопределяем встроенный метод Change вместо хуков в WndProc
        procedure Change; override;
    published
        property EnableHintText: Boolean read FEnableHintText write SetEnableHintText;
        property HintText: string read GetHintText write SetHintText;
    public
        constructor Create(Owner: TComponent); override;
        function MaskMatchesWith(InputStr: string): Boolean;
        property MaskText: string read FMaskedStr;
    end;

implementation

uses
    System.Masks,
    System.SysUtils
    ;

constructor TEdit.Create(Owner: TComponent);
begin
    inherited Create(Owner);
    FEnableHintText := False;
    FMaskedStr := '';
    // Используем встроенное свойство VCL для отображения подсказок (Cue Banner API)
    Self.TextHint := 'Type here... ("*", "?" wildcards are supported)';
end;

procedure TEdit.Change;
begin
    inherited Change; // Вызывает стандартный OnChange (безопасно)
    if FEnableHintText then
        PrepareMaskStr;
end;

procedure TEdit.SetEnableHintText(const Value: Boolean);
begin
    FEnableHintText := Value;
    if FEnableHintText then
        PrepareMaskStr
    else
        FMaskedStr := '';
end;

function TEdit.GetHintText: string;
begin
    Result := Self.TextHint; // Читаем из нативного свойства
end;

procedure TEdit.SetHintText(const Value: string);
begin
    Self.TextHint := Value; // Пишем в нативное свойство
end;

procedure TEdit.PrepareMaskStr;
begin
    if FEnableHintText then
        FMaskedStr := UpperCase('*' + Text + '*', loUserLocale);
end;

function TEdit.MaskMatchesWith(InputStr: string): Boolean;
begin
    if not FEnableHintText then
        Exit(False);

    if FMaskedStr = '' then
        Exit(True);

    InputStr := UpperCase(InputStr, loUserLocale);
    Result := MatchesMask(InputStr, FMaskedStr);
end;

end.
