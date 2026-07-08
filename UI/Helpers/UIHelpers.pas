unit UIHelpers;

interface

uses
    Vcl.ComCtrls,
    System.Masks
    ;

type
    // Статический контейнер вспомогательных методов для наполнения UI-контролов данными.
    // Используется как namespace: TUIHelpers.MethodName(...)
    TUIHelpers = record
    private
        // Единая реализация наполнения тегами (не видна вне юнита)
        class procedure InternalFillListView(ListView: TListView; SnippetID: Integer); static;
    public
        class procedure BuildTagList(ListView: TListView); overload; static;
        class procedure BuildTagList(ListView: TListView; SnippetID: Integer); overload; static;
        class procedure BuildCategoryTree(TreeView: TTreeView; FilterUserID: NativeInt; SelectID: Integer = -1); static;
        class procedure BuildTagListWithSelection(ListView: TListView; SnippetID: Integer); static;
    end;

implementation

uses
    DataModule,
    Tag,
    Category,
    User,
    System.Generics.Collections;

const
    DONT_SELECT_ANY_ITEM = -1;

    { TUIHelpers }

class procedure TUIHelpers.InternalFillListView(ListView: TListView; SnippetID: Integer);
var
    Tags: TArray<TTagDTO>;
    Tag: TTagDTO;
    Item: TListItem;
begin
    if (SnippetID = DONT_SELECT_ANY_ITEM) then
        Tags := DataModuleCommon.TagRepository.GetAll
    else
        Tags := DataModuleCommon.TagRepository.GetSnippetTags(SnippetID);

    ListView.Items.BeginUpdate;
    try
        ListView.Items.Clear;

        for Tag in Tags do
        begin
            Item := ListView.Items.Add;
            Item.Caption := Tag.Name;

            // Сохраняем ID тега (не сниппета!) в Data.
            // Это пригодится, если вы захотите реализовать удаление тега
            // или поиск других сниппетов по клику на этот тег.
            Item.Data := Pointer(NativeUInt(Tag.ID));

            Item.StateIndex := 0;
        end;
    finally
        ListView.Items.EndUpdate;
    end;
end;

class procedure TUIHelpers.BuildTagList(ListView: TListView);
begin
    InternalFillListView(ListView, DONT_SELECT_ANY_ITEM);
end;

class procedure TUIHelpers.BuildTagList(ListView: TListView; SnippetID: Integer);
begin
    InternalFillListView(ListView, SnippetID);
end;

class procedure TUIHelpers.BuildTagListWithSelection(ListView: TListView; SnippetID: Integer);
var
    AllTags: TArray<TTagDTO>;
    SnippetTags: TArray<TTagDTO>;
    SnippetTagIDs: TDictionary<Integer, Boolean>;
    Tag: TTagDTO;
    Item: TListItem;
begin
    AllTags := DataModuleCommon.TagRepository.GetAll;

    // Строим словарь ID тегов текущего сниппета
    SnippetTagIDs := TDictionary<Integer, Boolean>.Create;
    try
        if SnippetID > 0 then
        begin
            SnippetTags := DataModuleCommon.TagRepository.GetSnippetTags(SnippetID);
            for Tag in SnippetTags do
                SnippetTagIDs.AddOrSetValue(Tag.ID, True);
        end;

        ListView.Items.BeginUpdate;
        try
            ListView.Items.Clear;

            // 1. СНАЧАЛА привязанные теги (StateIndex = 1)
            for Tag in AllTags do
            begin
                if SnippetTagIDs.ContainsKey(Tag.ID) then
                begin
                    Item := ListView.Items.Add;
                    Item.Caption := Tag.Name;
                    Item.Data := Pointer(NativeUInt(Tag.ID));
                    Item.StateIndex := 1; // Привязан
                end;
            end;

            // 2. ПОТОМ непривязанные теги (StateIndex = 0)
            for Tag in AllTags do
            begin
                if not SnippetTagIDs.ContainsKey(Tag.ID) then
                begin
                    Item := ListView.Items.Add;
                    Item.Caption := Tag.Name;
                    Item.Data := Pointer(NativeUInt(Tag.ID));
                    Item.StateIndex := 0; // Не привязан
                end;
            end;
        finally
            ListView.Items.EndUpdate;
        end;
    finally
        SnippetTagIDs.Free;
    end;
end;

class procedure TUIHelpers.BuildCategoryTree(TreeView: TTreeView; FilterUserID: NativeInt; SelectID: Integer = -1);
    // Вспомогательная рекурсивная процедура для добавления узлов категорий
    procedure AddNodesRecursive(ParentNode: TTreeNode; ParentCatID: NativeInt;
        const CatMap: TDictionary<NativeInt, TList<TCategoryDTO>>);
    var
        Children: TList<TCategoryDTO>;
        Cat: TCategoryDTO;
        Node: TTreeNode;
    begin
        if not CatMap.TryGetValue(ParentCatID, Children) then Exit;

        for Cat in Children do
        begin
            Node := TreeView.Items.AddChild(ParentNode, Cat.Name);
            Node.Data := Pointer(NativeUInt(Cat.ID));
            Node.ImageIndex := 0;
            Node.SelectedIndex := 0;

            // Выделение нужного узла
            if (SelectID > DONT_SELECT_ANY_ITEM) and (SelectID = Cat.ID) then
                Node.Selected := True;

            // Рекурсия для детей
            AddNodesRecursive(Node, Cat.ID, CatMap);
        end;
    end;

    // Процедура для отрисовки дерева одного конкретного пользователя
    procedure RenderUserCategories(UserID: NativeInt; RootParentNode: TTreeNode);
    var
        UserCats: TArray<TCategoryDTO>;
        LocalCatMap: TDictionary<NativeInt, TList<TCategoryDTO>>;
        LocalRoots: TList<TCategoryDTO>;
        Cat: TCategoryDTO;
        Node: TTreeNode;
    begin
        UserCats := DataModuleCommon.CategoryRepository.GetAll(UserID);

        LocalCatMap := TDictionary<NativeInt, TList<TCategoryDTO>>.Create;
        LocalRoots := TList<TCategoryDTO>.Create;
        try
            // Строим локальную карту категорий этого пользователя
            for Cat in UserCats do
            begin
                if Cat.ParentID = 0 then
                    LocalRoots.Add(Cat)
                else
                begin
                    if not LocalCatMap.ContainsKey(Cat.ParentID) then
                        LocalCatMap.Add(Cat.ParentID, TList<TCategoryDTO>.Create);
                    LocalCatMap[Cat.ParentID].Add(Cat);
                end;
            end;

            // Добавляем корневые категории
            for Cat in LocalRoots do
            begin
                Node := TreeView.Items.AddChild(RootParentNode, Cat.Name);
                Node.Data := Pointer(NativeUInt(Cat.ID));
                Node.ImageIndex := 0;
                Node.SelectedIndex := 0;

                if (SelectID > DONT_SELECT_ANY_ITEM) and (SelectID = Cat.ID) then
                    Node.Selected := True;

                AddNodesRecursive(Node, Cat.ID, LocalCatMap);
            end;
        finally
            for var List in LocalCatMap.Values do List.Free;
            LocalCatMap.Free;
            LocalRoots.Free;
        end;
    end;

var
    Users: TArray<TUserDTO>;
    User: TUserDTO;
    Node: TTreeNode;
begin
    TreeView.Items.BeginUpdate;
    try
        TreeView.Items.Clear;

        // 1. Виртуальные узлы (всегда сверху)
        Node := TreeView.Items.AddObjectFirst(nil, 'Часто используемые', TObject(-1));
        Node.ImageIndex := 1;
        Node.SelectedIndex := 1;
        if SelectID = -1 then Node.Selected := True;

        Node := TreeView.Items.AddObjectFirst(nil, 'Недавние', TObject(-2));
        Node.ImageIndex := 2;
        Node.SelectedIndex := 2;
        if SelectID = -2 then Node.Selected := True;

        // 2. Основная логика в зависимости от фильтра
        if FilterUserID = 0 then
        begin
            // === РЕЖИМ "ВСЕ ПРОСТРАНСТВА" ===
            // Группируем категории по пользователям
            Users := DataModuleCommon.UserRepository.GetAll;

            for User in Users do
            begin
                // Создаем узел-разделитель для пространства
                Node := TreeView.Items.Add(nil, User.Name);
                // Можно сделать жирным шрифтом или с другой иконкой, если нужно
//                Node.FontStyle := [fsBold];
                Node.ImageIndex := 3;
                Node.SelectedIndex := 3;

                // Рендерим категории этого пользователя внутрь узла
                RenderUserCategories(User.ID, Node);
            end;
        end
        else
        begin
            // === РЕЖИМ КОНКРЕТНОГО ПРОСТРАНСТВА ===
            // Плоский список категорий выбранного пользователя
            RenderUserCategories(FilterUserID, nil);
        end;

    finally
        TreeView.Items.EndUpdate;
    end;
end;

end.
