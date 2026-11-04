unit EditEx;

interface

uses
    System.Classes,
    Vcl.StdCtrls
    ;

type
    // =========================================================================
    // Класс-перехватчик.
    // Стандартный TEdit не поддерживает Ctrl+Backspace / Ctrl+Delete (удаление
    // слова от курсора) и Ctrl+A (выделить всё): Ctrl+Backspace вставляет
    // символ #127, а Ctrl+A перехватывается хоткеями формы.
    // Перехватывается только Ctrl+BS/Ctrl+Del/Ctrl+A (Key := 0, без inherited),
    // остальной ввод и OnKeyDown форм работают как раньше.
    // Подключать в uses форм сразу после Vcl.StdCtrls ("подцепляем последним").
    // =========================================================================
    TEdit = class(Vcl.StdCtrls.TEdit)
    private
        function IsWordChar(C: Char): Boolean;
        procedure DeleteWordByCursor(ToRight: Boolean);
    protected
        procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    end;

implementation

uses
    System.Character,
    Winapi.Messages,
    Winapi.Windows
    ;

function TEdit.IsWordChar(C: Char): Boolean;
begin
    // "Слово" - буквы и цифры (включая кириллицу) плюс подчёркивание
    Result := C.IsLetterOrDigit or (C = '_');
end;

procedure TEdit.DeleteWordByCursor(ToRight: Boolean);
var
    Caret, I, Len: Integer;
begin
    // На read-only удаление невозможно, а EM_SETSEL оставил бы выделение
    if ReadOnly then
        Exit;

    Len := Length(Text);
    Caret := SelStart;

    if SelLength > 0 then
    begin
        // Есть выделение - клавиши просто стирают его (как в системных полях)
        SendMessage(Handle, EM_REPLACESEL, 1, LPARAM(PChar('')));
        Exit;
    end;

    I := Caret;
    if ToRight then
    begin
        // Пропускаем разделители вправо, затем стираем слово
        while (I < Len) and not IsWordChar(Text[I + 1]) do
            Inc(I);
        while (I < Len) and IsWordChar(Text[I + 1]) do
            Inc(I);
        SendMessage(Handle, EM_SETSEL, Caret, I);
    end
    else
    begin
        // Пропускаем разделители влево, затем стираем слово
        while (I > 0) and not IsWordChar(Text[I]) do
            Dec(I);
        while (I > 0) and IsWordChar(Text[I]) do
            Dec(I);
        SendMessage(Handle, EM_SETSEL, I, Caret);
    end;

    // EM_REPLACESEL вместо присвоения Text сохраняет Undo (Ctrl+Z)
    SendMessage(Handle, EM_REPLACESEL, 1, LPARAM(PChar('')));
end;

procedure TEdit.KeyDown(var Key: Word; Shift: TShiftState);
begin
    if Shift = [ssCtrl] then
        case Key of
            VK_BACK:
                begin
                    Key := 0;
                    DeleteWordByCursor(False);
                end;
            VK_DELETE:
                begin
                    Key := 0;
                    DeleteWordByCursor(True);
                end;
            Ord('A'):
                begin
                    Key := 0;
                    SelectAll;
                end;
        else
            inherited KeyDown(Key, Shift);
        end
    else
        inherited KeyDown(Key, Shift);
end;

end.
