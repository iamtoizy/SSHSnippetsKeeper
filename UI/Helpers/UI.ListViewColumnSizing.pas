unit UI.ListViewColumnSizing;

interface

uses
    System.Classes,
    Vcl.ComCtrls,
    Vcl.Controls,
    Winapi.CommCtrl,
    Winapi.Messages,
    Winapi.Windows
    ;

type
    // Автоподбор ширин колонок vsReport-списка без горизонтальной прокрутки:
    // первые N-1 колонок - по содержимому и заголовку, последняя добирает
    // остаток клиента; при нехватке ширины колонки пропорционально сжимаются
    // до минимумов. Ручное растяжение колонки пользователем (HDN_ITEMCHANGED
    // вне программных обновлений) отключает автоподбор до ForgetUserResize.
    // Замеры кэшируются: распределение из кэша (ApplyCached) не пересканирует
    // содержимое на тиках ресайза
    TListViewColumnFitter = class(TComponent)
    private
        FLV: TListView;
        FDefListProc: TWndMethod;
        FUserResized: Boolean;
        FInternalUpdate: Boolean;
        FDesiredValid: Boolean;
        FDesired: TArray<Integer>;
        FColumnMinWidth: Integer;
        FLastColumnMinWidth: Integer;
        procedure ListWndProc(var Message: TMessage);
        procedure Measure;
        procedure Apply;
    public
        constructor Create(AOwner: TComponent; const ALV: TListView;
            ALastColumnMinWidth: Integer = 90;
            AColumnMinWidth: Integer = 48); reintroduce;
        destructor Destroy; override;
        procedure Notification(AComponent: TComponent;
            Operation: TOperation); override;
        // Замерить содержимое и распределить ширины
        procedure Fit;
        // Распределить из кэша последнего замера (тики ресайза окна)
        procedure ApplyCached;
        // Вернуть автоподбор после ручных правок колонок
        procedure ForgetUserResize;
        property UserResized: Boolean read FUserResized;
    end;

implementation

constructor TListViewColumnFitter.Create(AOwner: TComponent; const ALV: TListView;
    ALastColumnMinWidth, AColumnMinWidth: Integer);
begin
    inherited Create(AOwner);
    FLV := ALV;
    FLastColumnMinWidth := ALastColumnMinWidth;
    FColumnMinWidth := AColumnMinWidth;
    if ALV <> nil then
    begin
        // Контролы формы уничтожаются раньше owned-компонентов: без
        // уведомления деструктор восстанавливал бы WindowProc уже
        // освобождённому ListView (use-after-free, ловится FastMM
        // как modified-after-free при рециклии блока)
        ALV.FreeNotification(Self);
        FDefListProc := ALV.WindowProc;
        ALV.WindowProc := ListWndProc;
    end;
end;

destructor TListViewColumnFitter.Destroy;
begin
    if (FLV <> nil) and Assigned(FDefListProc) then
        FLV.WindowProc := FDefListProc;
    inherited;
end;

procedure TListViewColumnFitter.Notification(AComponent: TComponent;
    Operation: TOperation);
begin
    inherited;
    if (Operation = opRemove) and (AComponent = FLV) then
    begin
        // Хук снят самим уничтожаемым ListView не будет - снимаем до его
        // смерти, чтобы никто не вызвал ListWndProc по висячему Self/FLV
        if Assigned(FDefListProc) then
            FLV.WindowProc := FDefListProc;
        FDefListProc := nil;
        FLV := nil;
    end;
end;

procedure TListViewColumnFitter.ListWndProc(var Message: TMessage);
var
    Notify: PHDNotify;
begin
    // Двойная защита: после Notification FLV=nil, сюда больше не попадаем
    if FLV = nil then
        Exit;
    // Пользовательское изменение ширины колонки отключает автоподбор.
    // HDN_ITEMCHANGED с шириной приходит и от программных изменений -
    // их отсекает FInternalUpdate
    if (not FInternalUpdate) and (Message.Msg = CN_NOTIFY) then
    begin
        Notify := PHDNotify(Message.LParam);
        if (Notify <> nil) and (Notify^.Hdr.hwndFrom = FLV.Handle)
            and (Notify^.Hdr.code = HDN_ITEMCHANGED)
            and (Notify^.PItem <> nil)
            and (Notify^.PItem^.mask and HDI_WIDTH <> 0)
            and (Notify^.PItem^.cxy > 0) then
            FUserResized := True;
    end;
    FDefListProc(Message);
end;

procedure TListViewColumnFitter.Measure;
var
    I, N, Sum: Integer;
    Col: TLVColumn;
begin
    FDesiredValid := False;
    if (FLV = nil) or (FLV.ViewStyle <> vsReport) or (not FLV.HandleAllocated) then
        Exit;

    N := FLV.Columns.Count;
    if N < 2 then
        Exit;

    SetLength(FDesired, N - 1);
    Sum := 0;
    for I := 0 to N - 2 do
    begin
        ListView_SetColumnWidth(FLV.Handle, I, LVSCW_AUTOSIZE_USEHEADER);
        FillChar(Col, SizeOf(Col), 0);
        Col.mask := LVCF_WIDTH;
        if ListView_GetColumn(FLV.Handle, I, Col) then
            FDesired[I] := Col.cx
        else
            FDesired[I] := ListView_GetColumnWidth(FLV.Handle, I);
        Inc(Sum, FDesired[I]);
    end;
    FDesiredValid := Sum > 0;
end;

procedure TListViewColumnFitter.Apply;
var
    I, N, Sum, Avail, W, Rest: Integer;
    K: Double;
begin
    if FUserResized then
        Exit;
    if (FLV = nil) or (FLV.ViewStyle <> vsReport) or (not FLV.HandleAllocated) then
        Exit;

    N := FLV.Columns.Count;
    if N = 0 then
        Exit;

    FInternalUpdate := True;
    try
        if N = 1 then
        begin
            ListView_SetColumnWidth(FLV.Handle, 0, LVSCW_AUTOSIZE_USEHEADER);
            Exit;
        end;

        if (not FDesiredValid) or (Length(FDesired) < N - 1) then
            Exit;

        Sum := 0;
        for I := 0 to N - 2 do
            Inc(Sum, FDesired[I]);

        Avail := FLV.ClientWidth;
        if Sum + FLastColumnMinWidth <= Avail then
        begin
            // Места хватает: колонки по содержимому, последняя - весь остаток
            for I := 0 to N - 2 do
                ListView_SetColumnWidth(FLV.Handle, I, FDesired[I]);
            ListView_SetColumnWidth(FLV.Handle, N - 1, Avail - Sum);
        end
        else
        begin
            // Узко: пропорциональное сжатие с минимумами, скролл - крайний случай
            K := (Avail - FLastColumnMinWidth) / Sum;
            Rest := 0;
            for I := 0 to N - 2 do
            begin
                W := Round(FDesired[I] * K);
                if W < FColumnMinWidth then
                    W := FColumnMinWidth;
                ListView_SetColumnWidth(FLV.Handle, I, W);
                Inc(Rest, W);
            end;
            W := Avail - Rest;
            if W < FLastColumnMinWidth then
                W := FLastColumnMinWidth;
            ListView_SetColumnWidth(FLV.Handle, N - 1, W);
        end;
    finally
        FInternalUpdate := False;
    end;
end;

procedure TListViewColumnFitter.Fit;
begin
    Measure;
    Apply;
end;

procedure TListViewColumnFitter.ApplyCached;
begin
    Apply;
end;

procedure TListViewColumnFitter.ForgetUserResize;
begin
    FUserResized := False;
end;

end.
