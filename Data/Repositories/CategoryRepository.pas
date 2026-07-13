unit CategoryRepository;

interface

uses
    System.Generics.Collections,
    Category,
    Snippet,
    FireDAC.Comp.Client,
    RepositoryBase,
    Core.Interfaces;

type
    TCategoryRepository = class(TRepositoryBase, ICategoryRepository)
    private
    public
        function GetAll(UserID: NativeInt = 0): TArray<TCategoryDTO>;
        function GetByID(ID: NativeInt): TCategoryDTO;
        function GetSnippetsByCategory(const CategoryID: NativeInt): TArray<TSnippetDTO>;
        procedure MoveCategory(ID, NewParentID, Position: NativeInt);
        procedure DeleteCategory(ID: NativeInt);
        function AddCategory(const Name: string; ParentID, UserID: NativeInt): NativeInt;
        procedure UpdateName(ID: NativeInt; const NewName: string);
        function GetUserID(ID: NativeInt): NativeInt;
        function ExistsInParent(const Name: string; ParentID, UserID: NativeInt): Boolean;
    end;

implementation

uses
    Winapi.Windows,
    System.SysUtils,
    FireDAC.Stan.Param,
    Data.DB
    ;

{ TCategoryRepository }

function TCategoryRepository.GetAll(UserID: NativeInt = 0): TArray<TCategoryDTO>;
var
    Query: TFDQuery;
    List: TList<TCategoryDTO>;
    Cat: TCategoryDTO;
begin
    if not FConnection.Connected then Exit(Result);

    List := TList<TCategoryDTO>.Create;
    Query := CreateQuery;
    try
        // sort_order и правильная сортировка
        if UserID > 0 then
            Query.Open('SELECT id, user_id, name, parent_id, sort_order FROM snippet_categories WHERE user_id = ? ORDER BY parent_id, sort_order, name', [UserID])
        else
            Query.Open('SELECT id, user_id, name, parent_id, sort_order FROM snippet_categories ORDER BY parent_id, sort_order, name');

        while not Query.Eof do
        begin
            Cat.ID := Query.FieldByName('id').AsInteger;
            Cat.Name := Query.FieldByName('name').AsString;
            Cat.ParentID := Query.FieldByName('parent_id').AsInteger;
            Cat.SortOrder := Query.FieldByName('sort_order').AsInteger;
            Cat.UserID := Query.FieldByName('user_id').AsInteger;

            List.Add(Cat);
            Query.Next;
        end;
        Result := List.ToArray;
    finally
        List.Free;
        Query.Free;
    end;
end;

function TCategoryRepository.GetByID(ID: NativeInt): TCategoryDTO;
var
    Q: TFDQuery;
begin
    Result := Default(TCategoryDTO);

    if ID <= 0 then Exit;

    Q := CreateQuery;
    try
        Q.SQL.Text := 'SELECT id, user_id, name, parent_id FROM snippet_categories WHERE id = :id';
        Q.ParamByName('id').AsInteger := ID;
        Q.Open;

        if not Q.Eof then
        begin
            Result.ID := Q.FieldByName('id').AsInteger;
            Result.UserID := Q.FieldByName('user_id').AsInteger;
            Result.Name := Q.FieldByName('name').AsString;
            Result.ParentID := Q.FieldByName('parent_id').AsInteger;

            {$IFDEF DEBUG}
            OutputDebugString(PChar(Format('CategoryRepository.GetByID: Found category ID=%d, UserID=%d, Name="%s"',
                [Result.ID, Result.UserID, Result.Name])));
            {$ENDIF}
        end
        else
        begin
            {$IFDEF DEBUG}
            OutputDebugString(PChar(Format('CategoryRepository.GetByID: Category ID=%d not found', [ID])));
            {$ENDIF}
        end;
    finally
        Q.Free;
    end;
end;

function TCategoryRepository.GetSnippetsByCategory(const CategoryID: NativeInt): TArray<TSnippetDTO>;
var
    Query: TFDQuery;
    List: TList<TSnippetDTO>;
    Snip: TSnippetDTO;
begin
    List := TList<TSnippetDTO>.Create;
    Query := CreateQuery;
    try
        Query.SQL.Text :=
            'SELECT id, user_id, title, content, category_id, created_at, updated_at ' +
            'FROM snippets WHERE category_id = :category_id ORDER BY title';
        Query.ParamByName('category_id').AsInteger := CategoryID;
        Query.Open;

        while not Query.Eof do
        begin
            Snip.ID := Query.FieldByName('id').AsInteger;
            Snip.UserID := Query.FieldByName('user_id').AsInteger;
            Snip.Title := Query.FieldByName('title').AsString;
            Snip.Content := Query.FieldByName('content').AsString;
            Snip.CategoryID := Query.FieldByName('category_id').AsInteger;
            Snip.CreatedAt := Query.FieldByName('created_at').AsLargeInt;
            Snip.UpdatedAt := Query.FieldByName('updated_at').AsLargeInt;

            List.Add(Snip);
            Query.Next;
        end;

        Result := List.ToArray;
    finally
        List.Free;
        Query.Free;
    end;
end;

procedure TCategoryRepository.MoveCategory(ID, NewParentID, Position: NativeInt);
var
    QGetOwner, QGetSiblings, QUpd: TFDQuery;
    SourceUserID, TargetUserID: NativeInt;
    SiblingIDs: TList<NativeInt>;
    i, CurrentPos: NativeInt;
begin
    // === 1. Проверка владельца исходной категории ===
    QGetOwner := CreateQuery;
    try
        QGetOwner.SQL.Text := 'SELECT user_id FROM snippet_categories WHERE id = :id';
        QGetOwner.ParamByName('id').AsInteger := ID;
        QGetOwner.Open;
        if QGetOwner.Eof then
            raise Exception.Create('Исходная категория не найдена');
        SourceUserID := QGetOwner.FieldByName('user_id').AsInteger;
    finally
        QGetOwner.Free;
    end;

    // === 2. Проверка владельца нового родителя (если указан) ===
    if NewParentID > 0 then
    begin
        QGetOwner := CreateQuery;
        try
            QGetOwner.SQL.Text := 'SELECT user_id FROM snippet_categories WHERE id = :id';
            QGetOwner.ParamByName('id').AsInteger := NewParentID;
            QGetOwner.Open;
            if QGetOwner.Eof then
                raise Exception.Create('Категория-родитель не найдена');
            TargetUserID := QGetOwner.FieldByName('user_id').AsInteger;
        finally
            QGetOwner.Free;
        end;

        // Критичная проверка: пространства
        if SourceUserID <> TargetUserID then
            raise Exception.Create('Нельзя переместить категорию в другое пространство');
    end
    else
    begin
        // NewParentID = 0 — перемещение в корень.
        // Корень не имеет владельца, поэтому проверка не требуется.
        // Но мы всё равно должны сохранить user_id исходной категории
        // (он не меняется при перемещении).
    end;

    // === 3. Получаем список siblings в НОВОЙ позиции ===
    SiblingIDs := TList<NativeInt>.Create;
    QGetSiblings := CreateQuery;
    try
        if NewParentID = 0 then
            QGetSiblings.SQL.Text :=
                'SELECT id FROM snippet_categories ' +
                'WHERE parent_id IS NULL AND user_id = :uid AND id <> :self_id ' +
                'ORDER BY sort_order, id'
        else
        begin
            QGetSiblings.SQL.Text :=
                'SELECT id FROM snippet_categories ' +
                'WHERE parent_id = :pid AND id <> :self_id ' +
                'ORDER BY sort_order, id';
            QGetSiblings.ParamByName('pid').AsInteger := NewParentID;
        end;
        QGetSiblings.ParamByName('uid').DataType := ftInteger;
        if NewParentID = 0 then
            QGetSiblings.ParamByName('uid').AsInteger := SourceUserID;
        QGetSiblings.ParamByName('self_id').AsInteger := ID;
        QGetSiblings.Open;

        while not QGetSiblings.Eof do
        begin
            SiblingIDs.Add(QGetSiblings.FieldByName('id').AsInteger);
            QGetSiblings.Next;
        end;
    finally
        QGetSiblings.Free;
    end;

    // === 4. Вставляем ID в нужную позицию ===
    if Position < 0 then
        CurrentPos := SiblingIDs.Count
    else if Position > SiblingIDs.Count then
        CurrentPos := SiblingIDs.Count
    else
        CurrentPos := Position;

    SiblingIDs.Insert(CurrentPos, ID);

    // === 5. Обновляем parent_id и sort_order в транзакции ===
    QUpd := CreateQuery;
    try
        FConnection.StartTransaction;
        try
            QUpd.SQL.Text := 'UPDATE snippet_categories SET parent_id = :pid, sort_order = :ord WHERE id = :id';

            for i := 0 to SiblingIDs.Count - 1 do
            begin
                // parent_id
                QUpd.ParamByName('pid').DataType := ftInteger;
                if NewParentID = 0 then
                    QUpd.ParamByName('pid').Clear
                else
                    QUpd.ParamByName('pid').AsInteger := NewParentID;

                QUpd.ParamByName('ord').AsInteger := i;
                QUpd.ParamByName('id').AsInteger := SiblingIDs[i];
                QUpd.ExecSQL;
            end;
            FConnection.Commit;
        except
            FConnection.Rollback;
            raise;
        end;
    finally
        QUpd.Free;
        SiblingIDs.Free;
    end;
end;

function TCategoryRepository.AddCategory(const Name: string; ParentID, UserID: NativeInt): NativeInt;
var
    Q, QMax: TFDQuery;
    MaxOrder: Integer;
begin
    QMax := CreateQuery;
    try
        if ParentID = 0 then
            QMax.SQL.Text := 'SELECT COALESCE(MAX(sort_order), -1) FROM snippet_categories WHERE parent_id IS NULL'
        else begin
            QMax.SQL.Text := 'SELECT COALESCE(MAX(sort_order), -1) FROM snippet_categories WHERE parent_id = :pid';
            QMax.ParamByName('pid').AsInteger := ParentID;
        end;
        QMax.Open;
        MaxOrder := QMax.Fields[0].AsInteger + 1;
    finally
        QMax.Free;
    end;

    Q := CreateQuery;
    try
        Q.SQL.Text := 'INSERT INTO snippet_categories (user_id, name, parent_id, sort_order) VALUES (:uid, :name, :pid, :ord)';
        Q.ParamByName('uid').AsInteger := UserID;
        Q.ParamByName('name').AsString := Name;
        Q.ParamByName('pid').DataType := ftInteger;
        if ParentID = 0 then
            Q.ParamByName('pid').Clear
        else
            Q.ParamByName('pid').AsInteger := ParentID;

        Q.ParamByName('ord').AsInteger := MaxOrder;
        Q.ExecSQL;
    finally
        Q.Free;
    end;

    // Получаем ID только что созданной записи
    Q := CreateQuery;
    try
        Q.Open('SELECT last_insert_rowid()');
        Result := Q.Fields[0].AsInteger;
    finally
        Q.Free;
    end;
end;

procedure TCategoryRepository.UpdateName(ID: NativeInt; const NewName: string);
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        Q.SQL.Text := 'UPDATE snippet_categories SET name = :name WHERE id = :id';
        Q.ParamByName('name').AsString := NewName;
        Q.ParamByName('id').AsInteger := ID;
        Q.ExecSQL;
    finally
        Q.Free;
    end;
end;

procedure TCategoryRepository.DeleteCategory(ID: NativeInt);
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        // Благодаря ON DELETE CASCADE в БД, удалятся вложенные категории и сниппеты
        Q.SQL.Text := 'DELETE FROM snippet_categories WHERE id = :id';
        Q.ParamByName('id').AsInteger := ID;
        Q.ExecSQL;
    finally
        Q.Free;
    end;
end;

function TCategoryRepository.GetUserID(ID: NativeInt): NativeInt;
var
    Query: TFDQuery;
begin
    Result := -1; // -1 означает "не найдено"
    Query := CreateQuery;
    try
        Query.SQL.Text := 'SELECT user_id FROM snippet_categories WHERE id = :id';
        Query.ParamByName('id').AsInteger := ID;
        Query.Open;

        if not Query.Eof then
            Result := Query.FieldByName('user_id').AsInteger;
    finally
        Query.Free;
    end;
end;

function TCategoryRepository.ExistsInParent(const Name: string; ParentID, UserID: NativeInt): Boolean;
var
    Q: TFDQuery;
begin
    Q := CreateQuery;
    try
        if ParentID = 0 then
        begin
            Q.SQL.Text :=
                'SELECT COUNT(*) FROM snippet_categories ' +
                'WHERE name = :name AND parent_id IS NULL AND user_id = :uid';
        end
        else
        begin
            Q.SQL.Text :=
                'SELECT COUNT(*) FROM snippet_categories ' +
                'WHERE name = :name AND parent_id = :pid AND user_id = :uid';
            Q.ParamByName('pid').AsInteger := ParentID;
        end;
        Q.ParamByName('name').AsString := Name;
        Q.ParamByName('uid').AsInteger := UserID;
        Q.Open;
        Result := Q.Fields[0].AsInteger > 0;
    finally
        Q.Free;
    end;
end;

end.
