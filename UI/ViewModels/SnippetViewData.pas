unit SnippetViewData;

interface

type
    TSnippetViewData = class
        ID: Integer;
        UserID: Integer;
        CategoryID: Integer;
        Title: string;
        Content: string;
        Comment: string;
        Language: string;
        LanguageLocked: Boolean; // True = язык выбран вручную, автодетект отключён
        IsFavorite: Boolean;
        FavoriteSlot: Integer; // 0..8 = слоты клавиш 1..9, 9 = клавиша 0, -1 = вне слотов
    end;

implementation

// TODO: Применить словарь и ленивую загрузку:
// В Item.Data хранить только ID (Integer). Создать словарь FHintCache: TDictionary<Integer, string>.
// В OnInfoTip проверяем: если в кэше нет ключа, загружаем комментарий по ID из БД и сохраняем в словарь.
// При очистке списка очищаем словарь.

end.
