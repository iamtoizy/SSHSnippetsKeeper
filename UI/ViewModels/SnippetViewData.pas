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

end.
