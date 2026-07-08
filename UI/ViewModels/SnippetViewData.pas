unit SnippetViewData;

interface

type
    TSnippetViewData = class
        ID: Integer;
        Title: string;
        Content: string;
        Comment: string;
    end;

implementation

// TODO: Применить словарь и ленивую загрузку:
//В Item.Data хранить только ID (Integer). Создать словарь FHintCache: TDictionary<Integer, string>.
//В OnInfoTip проверяем: если в кэше нет ключа, загружаем комментарий по ID из БД и сохраняем в словарь.
//При очистке списка очищаем словарь.
//
//procedure TMainForm.ListView1InfoTip(Sender: TObject; Item: TListItem; var InfoTip: string);
//var
//    ID: Integer;
//    Comment: string;
//begin
//    if not Assigned(Item) then Exit;
//    ID := Integer(Item.Data); // храним только ID
//    if not FHintCache.TryGetValue(ID, Comment) then
//    begin
//        Comment := DataModuleCommon.GetSnippetCommentById(ID); // отдельный лёгкий запрос
//        FHintCache.Add(ID, Comment);
//    end;
//    InfoTip := Comment;
//end;

end.
