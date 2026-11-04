unit ListViewEx;

interface

uses
    Vcl.ComCtrls
    ;

type
    // =========================================================================
    // Класс-перехватчик.
    // При разрушении окна (DestroyWnd - в том числе каскад RecreateWnd при
    // переключении стиля) VCL очищает строки без OnDeletion и не освобождает
    // Item.Data - объекты в данных строк осиротевают (утечка при выходе).
    // Списки с OwnsItemData=True освобождают данные строк до inherited.
    // =========================================================================
    TListView = class(Vcl.ComCtrls.TListView)
    private
        FOwnsItemData: Boolean;
    protected
        procedure DestroyWnd; override;
    public
        // Форма помечает списки, чьи Item.Data - объекты, требующие освобождения
        property OwnsItemData: Boolean read FOwnsItemData write FOwnsItemData;
    end;

implementation

procedure TListView.DestroyWnd;
var
    I: Integer;
begin
    if FOwnsItemData then
        for I := 0 to Items.Count - 1 do
            if Assigned(Items[I].Data) then
            begin
                TObject(Items[I].Data).Free;
                // Обнуляем, чтобы возможный OnDeletion не освободил указатель повторно
                Items[I].Data := nil;
            end;
    inherited DestroyWnd;
end;

end.
