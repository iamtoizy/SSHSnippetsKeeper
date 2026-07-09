unit UIHelpers;

interface

uses
    Vcl.ComCtrls, System.Masks, Tag, Category, User, System.Generics.Collections;

type
    // Статический контейнер вспомогательных методов для отрисовки UI-контролов.
    // Теперь это "чистые" функции, которые ничего не знают про БД или Сервисы.
    TUIHelpers = record
    public
        // Просто заполняем ListView переданным массивом тегов
        class procedure FillTagList(ListView: TListView; const Tags: TArray<TTagDTO>); static;

        // Заполняем ListView всеми тегами, помечая выбранные
        class procedure FillTagListWithSelection(ListView: TListView; const AllTags, SnippetTags: TArray<TTagDTO>); static;

        // Строим дерево категорий на основе готовых массивов категорий и пользователей
        class procedure BuildCategoryTree(TreeView: TTreeView; const Categories: TArray<TCategoryDTO>;
                                          const Users: TArray<TUserDTO>; FilterUserID: NativeInt;
                                          SelectID: Integer = -1); static;
    end;

implementation

{ TUIHelpers }

class procedure TUIHelpers.FillTagList(ListView: TListView; const Tags: TArray<TTagDTO>);
var
    Tag: TTagDTO;
    Item: TListItem;
begin
    ListView.Items.BeginUpdate;
    try
        ListView.Items.Clear;

        for Tag in Tags do
        begin
            Item := ListView.Items.Add;
            Item.Caption := Tag.Name;
            Item.Data := Pointer(NativeUInt(Tag.ID));
            Item.StateIndex := 0;
        end;
    finally
        ListView.Items.EndUpdate;
    end;
end;

class procedure TUIHelpers.FillTagListWithSelection(ListView: TListView; const AllTags, SnippetTags: TArray<TTagDTO>);
var
    SnippetTagIDs: TDictionary<Integer, Boolean>;
    Tag: TTagDTO;
    Item: TListItem;
begin
    // Строим словарь ID тегов текущего сниппета для быстрого поиска (O(1))
    SnippetTagIDs := TDictionary<Integer, Boolean>.Create;
    try
        for Tag in SnippetTags do
            SnippetTagIDs.AddOrSetValue(Tag.ID, True);

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

class procedure TUIHelpers.BuildCategoryTree(TreeView: TTreeView; const Categories: TArray<TCategoryDTO>;
                                             const Users: TArray<TUserDTO>; FilterUserID: NativeInt;
                                             SelectID: Integer = -1);

    // Вспомогательная рекурсивная процедура для добавления узлов
    procedure AddNodesRecursive(ParentNode: TTreeNode; ParentCatID: NativeInt; const CatMap: TDictionary<NativeInt, TList<TCategoryDTO>>);
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

            if (SelectID > -1) and (SelectID = Cat.ID) then
                Node.Selected := True;

            AddNodesRecursive(Node, Cat.ID, CatMap);
        end;
    end;

    // Внутренняя отрисовка переданного подмножества категорий
    procedure RenderCategories(RootParentNode: TTreeNode; const LocalCats: TList<TCategoryDTO>);
    var
        LocalCatMap: TDictionary<NativeInt, TList<TCategoryDTO>>;
        LocalRoots: TList<TCategoryDTO>;
        Cat: TCategoryDTO;
        Node: TTreeNode;
        List: TList<TCategoryDTO>;
    begin
        LocalCatMap := TDictionary<NativeInt, TList<TCategoryDTO>>.Create;
        LocalRoots := TList<TCategoryDTO>.Create;
        try
            // Группируем категории
            for Cat in LocalCats do
            begin
                if Cat.ParentID = 0 then
                    LocalRoots.Add(Cat)
                else
                begin
                    if not LocalCatMap.TryGetValue(Cat.ParentID, List) then
                    begin
                        List := TList<TCategoryDTO>.Create;
                        LocalCatMap.Add(Cat.ParentID, List);
                    end;
                    List.Add(Cat);
                end;
            end;

            // Добавляем корни и запускаем рекурсию
            for Cat in LocalRoots do
            begin
                Node := TreeView.Items.AddChild(RootParentNode, Cat.Name);
                Node.Data := Pointer(NativeUInt(Cat.ID));
                Node.ImageIndex := 0;
                Node.SelectedIndex := 0;

                if (SelectID > -1) and (SelectID = Cat.ID) then
                    Node.Selected := True;

                AddNodesRecursive(Node, Cat.ID, LocalCatMap);
            end;
        finally
            for List in LocalCatMap.Values do List.Free;
            LocalCatMap.Free;
            LocalRoots.Free;
        end;
    end;

var
    Node: TTreeNode;
    User: TUserDTO;
    UserCats: TList<TCategoryDTO>;
    Cat: TCategoryDTO;
begin
    TreeView.Items.BeginUpdate;
    UserCats := TList<TCategoryDTO>.Create;
    try
        TreeView.Items.Clear;

        // 1. Виртуальные узлы
        Node := TreeView.Items.AddObjectFirst(nil, 'Часто используемые', TObject(-1));
        Node.ImageIndex := 1;
        Node.SelectedIndex := 1;
        if SelectID = -1 then Node.Selected := True;

        Node := TreeView.Items.AddObjectFirst(nil, 'Недавние', TObject(-2));
        Node.ImageIndex := 2;
        Node.SelectedIndex := 2;
        if SelectID = -2 then Node.Selected := True;

        // 2. Группировка
        if FilterUserID = 0 then
        begin
            // === РЕЖИМ "ВСЕ ПРОСТРАНСТВА" ===
            for User in Users do
            begin
                Node := TreeView.Items.Add(nil, User.Name);
                Node.ImageIndex := 3;
                Node.SelectedIndex := 3;

                UserCats.Clear;
                for Cat in Categories do
                    if Cat.UserID = User.ID then
                        UserCats.Add(Cat);

                RenderCategories(Node, UserCats);
            end;
        end
        else
        begin
            // === РЕЖИМ КОНКРЕТНОГО ПРОСТРАНСТВА ===
            UserCats.Clear;
            for Cat in Categories do
                if Cat.UserID = FilterUserID then
                    UserCats.Add(Cat);

            RenderCategories(nil, UserCats);
        end;
    finally
        UserCats.Free;
        TreeView.Items.EndUpdate;
    end;
end;

end.
