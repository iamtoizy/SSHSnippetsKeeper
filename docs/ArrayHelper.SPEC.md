# TArrayRecord — SPEC (поведенческая спецификация)

Clean-room спецификация замены `ThirdParty\ArrayHelper.pas`. Описывает
**наблюдаемое поведение чёрного ящика**, воспроизведение которого обязательно.

Источник фактов: эмпирическая проба — консольные программы `ArrayProbe`,
`ArrayProbe2`, линкующие текущий `ThirdParty\ArrayHelper.pas`, снята
2026-11-21 (вывод: `%TEMP%\rufp\dsonprobe\out_arr_old.txt`,
`out_arr2_old.txt`). Все утверждения подтверждены пробой, кроме отмеченных
как «гипотеза».

Правило clean-room: воспроизводится поведение и RTTI-форма данных. Не
переносится выражение оригинала: код, имена (`TArrayHelper`,
`Test_All_Helper_Functions` и т.п.), структура, комментарии, мёртвое API.

## 1. Публичный API

Новый юнит `Common.ArrayRecord` (файл `Common\Common.ArrayRecord.pas`).
Единственный публичный тип — generic record:

```pascal
type
  TArrayRecord<T> = record
  public
    Items: TArray<T>;
    property Count: Integer read GetCount write SetCount;
    property ItemAt[Index: Integer]: T read GetItemAt write SetItemAt; default;
    constructor Create(ACapacity: Integer);
    constructor Create(const AValues: array of T);
    procedure Clear;
    function Add(const Value: T): Integer;
    procedure Delete(Index: Integer);
    procedure Insert(Index: Integer; Value: T);
    function Remove(const AItem: T): Boolean;
    function AddIfNotContains(const AItem: T): Boolean;
    function IndexOf(const Item: T): Integer;
    function Contains(const Item: T): Boolean;
    function GetEnumerator: TEnumerator;  // for-in поддержка
  end;
```

Мёртвое API оригинала не воспроизводится (нет ни одного call site в
проекте): `TArrayHelper` (class helper для `TArray`), `SetItems`,
`AddRange`, `InsertRange`, `IndexOfMax`/`IndexOfMin`, `Compare`,
`ForEach`/`Find`/`Map`/`Convert`, `Sort`/`BinarySearch`, `Unsort`/
`Shuffle`/`Unique`/`CopyArray`, операторы `Equal`/`NotEqual`,
`Test_All_Helper_Functions`, перегрузки с `IComparer<T>`.

Используемые инстанциации в проекте:
- `TArrayRecord<string>` — `RecentDatabases`, `FAllowedProcesses`;
- `TArrayRecord<TAIItem>` (`AISettings`), `TArrayRecord<TAllowedApplicationsItem>`,
  `TArrayRecord<TGlobalTitleDenyRule>` (`GlobalTitleDenyRules`),
  `TArrayRecord<TDbSecurityProfile>` (`DbProfiles`),
  `TArrayRecord<TWindowMonitorInfo>` (`FAllowedWindowHistory`).

## 2. Состояние и инициализация

- Единственное хранилище — public field `Items: TArray<T>`. `Count` —
  тонкая обёртка над `Length(Items)`; отдельного счётчика нет.
- Свежая запись (`Default(TArrayRecord<T>)`) имеет `Items = nil`,
  `Count = 0` (проба: `default-count=0`, `default-items-len=0`).
- Форма записи в RTTI: **ровно один** declared field — `Items`
  (`TRttiRecordField`), declared properties — пусто
  (проба `rtti-view`; свойство `Count` в RTTI записи не экспортируется).
  Это контрактообразующий факт: `Common.JsonSerializer` сериализует
  `TArrayRecord` по полям, пустой массив → `"Field": {}` (см. SPEC
  JsonSerializer §3.1); любое добавление public-поля или published-
  свойства сломает золотые JSON-фикстуры.
- `Create(ACapacity)`: `SetLength(Items, ACapacity)` — Count сразу равен
  capacity, элементы дефолтны (проба: `cap5:count=5`,
  `cap5.items-len=5`, элементы `''`). Параметр никуда не «резервируется».
- `Create(const AValues: array of T)`: копия массива, `Count = Length`.
- Конструкторы можно не вызывать: record-семантика Delphi делает
  `Default`-инициализацию рабочей.

## 3. Операции (наблюдаемое поведение)

| Операция | Поведение |
|---|---|
| `Add(Value): Integer` | аппенд; возвращает индекс добавленного (0, 1, …) |
| `Count := N` (write) | `SetLength(Items, N)`; рост — новые элементы дефолтны; усечение — хвост теряется. `N < 0` → `ERangeError` (проба 2: `setcount-negative`) |
| `ItemAt[I]` (default) | чтение/запись элемента; **чтение за границей — не проверяется**: `A[5]` при Count=1 возвращает дефолт `T` молча (проба 1: `get(5)=`). Запись — гипотеза: тоже без проверки (как у обычного динамического массива; за границей записи в probe нет) |
| `Delete(Index)` | удаляет элемент со сдвигом хвоста; `Index < 0` или `>= Count` → `EArgumentOutOfRangeException`, состояние не меняется (проба 2) |
| `Insert(Index, Value)` | вставка со сдвигом; `Index < 0` или `> Count` → `EArgumentOutOfRangeException` (проба 2); `Index = Count` — аппенд |
| `Remove(Item): Boolean` | удаляет **первое** вхождение; True если нашлось; иначе False, состояние не меняется |
| `Contains(Item): Boolean` | наличие; для string — case-sensitive (проба: `has-BETA` по `['alpha','beta','gamma']` → не проверено напрямую, но `IndexOf('BETA')=-1`) |
| `IndexOf(Item): Integer` | индекс первого вхождения или -1; case-sensitive для string (проба: `idx-BETA=-1`) |
| `AddIfNotContains(Item): Boolean` | True + аппенд, если нет дубликата; False без изменений (проба 2: `ain-a=False`, `ain-c=True`) |
| `Clear` | `Items := nil` (не `SetLength(0)`): `items-nil=True` (проба 1) |
| `for-in` | порядок слева направо, все элементы |

Семантика сравнения — дженерик-равенство `TEqualityComparer<T>.Default`
(для строк — case-sensitive, бинарное). Гипотеза (поведение совпадает с
эталонным `IndexOf` в probe, реализация не видна).

## 4. Требования к замене

1. RTTI-форма записи: public field `Items` + метод-свойства вне RTTI.
   Никаких новых public-полей.
2. Точное воспроизведение таблицы §3, включая исключения
   `EArgumentOutOfRangeException` (Delete/Insert) и `ERangeError`
   (Count < 0), молчаливое чтение за границей.
3. `Add` возвращает индекс нового элемента.
4. Enumerator совместим с `for-in` и не создаёт утечек (Managed record
   — достаточно полей; класс-энумератор освобождать не требуется, но
   память не течёт только при отсутствии внешних ссылок).
5. Утечек памяти нет (FastMM Debug-отчёт).

## 5. Проверка замены

- Probe-сравнение байт-в-байт: `out_arr_old.txt` / `out_arr2_old.txt`
  против пробы на новой реализации (`out_arr_new.txt` / `out_arr2_new.txt`).
- Золотые тесты `Tests.ArrayRecord` (новый юнит) — по фикстурам обеих проб.
- Обязательный полный прогон `Tests.JsonSerializer` (17 тестов): золотые
  JSON-фикстуры зависят от RTTI-формы `TArrayRecord`.
- Полный прогон всех тестов Debug + Release, 0 утечек.
