# JsonSerializer — SPEC (поведенческая спецификация)

Clean-room спецификация сериализатора настроек. Описывает **наблюдаемое
поведение чёрного ящика**, воспроизведение которого обязательно при замене
`ThirdParty\JSONSerializer.pas` (производная DSON, лицензии нет).

Источник фактов: эмпирическая проба — консольная программа `DsonProbe`,
линкующая текущий `ThirdParty\JSONSerializer.pas` и `Core.Interfaces.Settings`,
снята 2026-11-21 (вывод: `docs\JsonSerializer.FIXTURES.txt`). Все утверждения
ниже подтверждены пробой, кроме отмеченных как «гипотеза».

Правило clean-room: воспроизводится поведение и формат данных. Не переносится
выражение оригинала: код, имена (`TDSON`, `TDSONValueReader` и т.п.), структура
классов, комментарии.

## 1. Публичный API

Новый юнит `Common.JsonSerializer` (файл `Common\JsonSerializer.pas`).
Публичный тип — record `TJsonSerializer` со static-методами:

```pascal
class function FromJson<T>(const AJson: string): T; static;
class function ToJson<T>(const AValue: T; const AFormat: Boolean = True): string; static;
```

Больше ничего. Мёртвое API старого юнита не воспроизводится: `fromJson(TStream)`,
`toJsonObject`, атрибуты `SerializedName`/`DefValue`, `IMap/TMap/TMapClass` —
ни один call site их не вызывает.

Используемые инстанциации: `FromJson<TAppSettings>` / `ToJson<TAppSettings>`
(7 call sites). Внутри `T` рекурсивно покрывает вложенные records
(`TUISettings`, `TAIHub`, `TAIItem`, `TAIParams`, …), `TArrayRecord<T>`,
`TArray<T>`, скаляры, `string`.

## 2. ToJson: формат вывода

- `AFormat=True` → `TJSONValue.Format`: indent 4 пробела (подтверждено пробой).
- `AFormat=False` → `TJSONValue.ToJSON`: компактная строка без пробелов.
- Результат — UTF-16 `string`; запись в файл с UTF-8 делает вызывающий код
  (`TFile.WriteAllText(..., TEncoding.UTF8)` в `Common.Settings.pas`).

Порядок членов объекта: сначала declared properties, затем declared fields
типа (в порядке объявления). Для `TAppSettings` это порядок объявления полей
в `Core.Interfaces.Settings.pas`. Round-trip формата стабилен байт-в-байт
(проба: `RE_FROM_FMT` = `ROUNDTRIP_COMPACT`).

## 3. Маппинг типов

| Delphi-тип | JSON |
|---|---|
| `Integer`, `Cardinal` | number |
| `Int64` | number |
| `Boolean` | `true` / `false` |
| `Single`, `Double`, `Extended`, `Currency`, `Comp` | number; Single 0.3 → `0.300000011920929` (через Extended) |
| `string` | string |
| enum (кроме Boolean) | string — имя значения (`GetEnumName`); чтение — `GetEnumValue` |
| set | string — `SetToString(..., Brackets=True)`; чтение — `StringToSet` |
| record | object, рекурсивно |
| `TArray<T>`, статический массив | array, поэлементно |
| class (tkClass) | object: инстанцирование + заполнение (в настройках не используется) |

В `TAppSettings` enum'ов и set'ов нет — ветки нужны для полноты, но не покрыты
фикстурами; при реализации допустимо бросить «unsupported type» вместо
реализации, если решено не поддерживать (решение зафиксировать в коде).

### 3.1 TArrayRecord<T> — критичный special-case

`TArrayRecord<T>` (ThirdParty\ArrayHelper.pas:135): public field
`Items: TArray<T>` + property `Count`/`ItemAt` (вычисляемые из `Length(Items)`).

Запись:
- Непустой → object `{"Items": [...]}`.
- Пустой (`Items = nil`) → `{}` — ключ `Items` не пишется вовсе.
- Property `Count` и `ItemAt` в JSON **не попадают** (проба: в выводе нет `"Count"`).

Чтение:
- Ключ `"Count"` в JSON-объекте **игнорируется**: `{"Count": 5, "Items": [..]}`
  читается с длиной по `Items` (=1), `Count`-property не применяется (проба
  `READ_ARR_WITH_COUNT`).
- Отсутствие `Items` в JSON → поле не трогается (остаётся nil).

Плоские `TArray<T>`-поля (`DenyRuleSets`, `ChmodPresets`, `HistoryUsers`, …):
- Пустые (`nil`) → **вообще не попадают в JSON** (проба: в `ROUNDTRIP_COMPACT`
  нет `DenyRuleSets`, `ChmodPresets`, `HistoryUsers`, `ArchivePresets`,
  `CustomShortCuts`, `DbProfiles` и `RecentDatabases` — все пустые).
  Причина (гипотеза, не блокер): RTTI-чтение nil-динамического массива даёт
  `TValue.Empty`, и член пропускается.
- Непустые → JSON-array.
- Чтение: отсутствующий в JSON array-член остаётся nil.

## 4. FromJson: семантика чтения

1. Вход парсится `TJSONObject.ParseJSONValue(AJson)`.
2. **Невалидный JSON** (`ParseJSONValue = nil`) → **без исключения**, возвращается
   `Default(T)` (проба `READ_INVALID_JSON`: `'not json'` → `Default(TAppSettings)`).
   Именно поэтому pre-валидация в `Common.Settings.pas:990-993` обязательна и
   остаётся (см. §6).
3. Top-level `null` → `Default(T)` без исключения.
4. Top-level не-объект для record-типа (`5`, `"s"`, `[]`) → исключение
   «Json value is not object» / «Json value is not array».
5. Чтение всегда начинается с `Default(T)` — «целевого экземпляра» нет.
   Отсутствующие в JSON члены = значения Default.

### 4.1 Механика на члене object'а

Итерируются RTTI-члены типа (properties, затем fields; public/published;
только записываемые). Для каждого:
- Ключ отсутствует в JSON → член не присваивается (остаётся как был).
- Значение ключа `null` → член не присваивается (проба `READ_NULL_MEMBER`:
  `"CurrentLanguage": null` → `""`).
  **Осознанное отклонение от старого локального DSON**: тот на null в
  Boolean/Integer-члене бросал `EJSONException` (файл → .corrupt); новая
  реализация пропускает null-член любого типа. Приложение никогда не пишет
  null (writer не порождает null), поэтому различие живёт только в битых
  вручную файлах; skip-семантика устойчивее и совпадает с апстримным DSON.
  Покрыто тестом.
- Ключ неизвестен (`"NoSuchKey": 42`) → игнорируется молча.
- Тип совпадает → присваивается.
- Тип не совпадает — направление конверсии задаёт System.JSON:
  - JSON string → Integer-член: **исключение** (`EJSONException: TJSONString
    ('str') is not a valid Integer value...`; проба `READ_WRONG_TYPE_MEMBER`).
  - JSON number → string-член: конвертируется, `42` → `"42"` (проба
    `READ_WRONG_FIELD_TYPE`).

### 4.2 Вложенные значения

- Ожидается record/object, в JSON не объект → исключение
  «Json value is not object».
- Ожидается массив, в JSON не массив (`{"AllowedApplications": {"Items": 5}}`)
  → исключение «Json value is not array» (проба `READ_BAD_ARRAY_EL`).
- Элемент массива с отсутствующими полями → отсутствующие поля = Default
  (проба `READ_PARTIAL_ITEM`: `{"ExeName": "a.exe"}` → `Enabled=False`,
  `WindowClasses` пуст).
- Дубли ключей в JSON-объекте → побеждает последний (семантика
  `TJSONObject.GetValue`).

## 5. Исключения

Новый класс `EJsonSerializerException = class(Exception)`. Условия бросания:
1. Top-level не-объект для record/class-типа.
2. Значение-не-объект там, где ожидается record/class.
3. Значение-не-массив там, где ожидается массив.
4. Неизвестный RTTI-тип (kind вне поддерживаемых) — с именем типа.

Нюанс: конверсии скаляров выполняются `TJSONValue.GetValue<T>`, который на
несовместимой паре бросает `EJSONException` (System.JSON). Выбор реализации:
`EJSONException` пробрасывается как есть (не оборачивается) — call sites
ловят `Exception`, различие класса не наблюдаемо. Покрыто тестом
(тест-ожидание: `EJSONException`).

## 6. Контракты с call sites

- `Common.Settings.pas:990-993` (pre-валидация `ParseJSONValue = nil → raise`)
  **обязана остаться**: сериализатор на невалидном JSON молча возвращает
  `Default(T)` (§4.2), а поток `.corrupt` + шаблон должен срабатывать на битом
  файле. Комментарий по этому месту обновить (упоминание DSON → Common.JsonSerializer).
- `Common.Settings.pas:995-998` — комментарий про «DSON.fromJson затирает
  массивы»: фактическая семантика — отсутствующий в JSON массив остаётся nil,
  потому что `FromJson` стартует с `Default(T)` (§4). Комментарий переписать
  по SPEC.
- `Test_Hotfix_ToggleCryptoKeys` (Tests.Settings.pas:431) и тесты
  Tests.SecurityReport.pas:393,407 — обычные call sites, меняется только имя юнита.

## 7. RTTI-требования

- Проба подтвердила: `{$WEAKLINKRTTI ON}` + `{$RTTI EXPLICIT
  METHODS([]) PROPERTIES([]) FIELDS([])}` из `SSHSnippetsKeeper.dpr:29,35`
  **не влияют** на сериализацию — вывод идентичен сборке без директив
  (расхождение только в адресе указателя внутри текста одного исключения).
  Директивы действуют на юнит dpr, юниты проекта компилируются с дефолтной
  RTTI-конфигурацией.
- Требование к реализации: не добавлять `{$RTTI EXPLICIT ... FIELDS([])}`-
  отключающие директивы в `Core.Interfaces.Settings.pas`, `ThirdParty\ArrayHelper.pas`
  и новый `Common.JsonSerializer.pas`.
- Остаточный риск закрывается Release-проверкой (todo: сборка Release main+tests,
  прогон тест-бинарём Release).

## 8. Золотые фикстуры

Канон: `docs\JsonSerializer.FIXTURES.txt` (копия вывода пробы Debug). Сценарии:

1. **ROUNDTRIP_FMT / ROUNDTRIP_COMPACT / RE_FROM_FMT**: `TAppSettings` с
   заполненными UISettings (5 полей), WindowHelper (3), AllowedApplications
   (1 элемент, все 5 полей, WindowClasses=['PuTTY']), GlobalTitleDenyRules
   (1 элемент, 4 поля), AISettings (1 hub → 1 item → Params, все поля),
   CurrentLanguage='ru', TagsMatchAll=True.
   Утверждения:
   - `ToJson(S, True)` = строка ROUNDTRIP_FMT (сравнение строка-в-строку;
     заодно фиксирует trailing-newline поведение `Format`);
   - `ToJson(S, False)` = строка ROUNDTRIP_COMPACT;
   - `FromJson(ROUNDTRIP_COMPACT)` → `ToJson(S2, False)` = та же строка.
2. **READ_LEGACY**: `{"TagsMatchAll": true}` → только `TagsMatchAll=True`,
   остальные члены Default (проверить репрезентативные: `CurrentLanguage=''`,
   `AllowedApplications` пуст, `UISettings.Help.HelpButton.HoverDelay=0`).
3. **READ_NULL_MEMBER**: `{"CurrentLanguage": null}` → `CurrentLanguage=''`.
4. **READ_UNKNOWN_MEMBER**: `{"NoSuchKey": 42}` → всё Default, без исключения.
5. **READ_MISSING_ARRAY**: JSON без `RecentDatabases` → `Length(Items)=0`.
6. **READ_ARR_WITH_COUNT**: `{"AllowedApplications": {"Count": 5, "Items":
   [{"ExeName": "a.exe", "Enabled": true}]}}` → длина 1, `ExeName='a.exe'`.
7. **READ_PARTIAL_ITEM**: элемент с одним полем → остальные Default.
8. **Ошибки**: `not json` → Default без исключения; `'5'` → исключение;
   `'[]'` → исключение; `{"ArchiveLastFormat": "str"}` → исключение;
   `{"AllowedApplications": {"Items": 5}}` → исключение;
   `{"TagsMatchAll": null}` → пропуск (False), без исключения;
   `{"AllowedApplications": {"Items": [{"ExeName": 42}]}}` → `ExeName='42'`,
   без исключения.

## 9. Критерий замены (Definition of Done)

1. `Common\JsonSerializer.pas` реализует §1–§5; код написан по этому SPEC,
   не по исходнику DSON.
2. `Tests\JsonSerializer.pas` (тест-юнит) покрывает фикстуры §8; зарегистрирован
   в `Tests\SSHSnippetsKeeperTests.dpr`.
3. Переключены uses (4 файла): `Common.Settings.pas:112`,
   `Tests.Tests.DenyRuleSets.pas:10`, `Tests.Tests.Settings.pas:163`,
   `Tests.Tests.SecurityReport.pas:11`; все 7 call sites на
   `TJsonSerializer.FromJson/ToJson`.
4. `SSHSnippetsKeeper.dpr`: `JSONSerializer in 'ThirdParty\JSONSerializer.pas'`
   → `Common.JsonSerializer in 'Common\JsonSerializer.pas'`. Оба dproj:
   DCCReference обновлён.
5. Сборка Debug main + tests, полный прогон: 636 существующих + новые зелёные,
   0 утечек (FastMM).
6. Сборка Release main + tests, прогон тест-бинарём Release (§7).
7. `ThirdParty\JSONSerializer.pas` удалён; `ThirdParty\DEPENDENCIES.md`
   обновлён (запись о DSON удалена; отдельная строка: собственный
   `Common.JsonSerializer`, внешних зависимостей нет).
8. Гарантия отсутствия регрессии схемы: существующие `settings.json`
   пользователей читаются (покрыто READ_LEGACY + полными round-trip
   фикстурами; живой `settings.json` проекта — дополнительная smoke-проверка
   в тесте: файл существует → читается без исключения).

## Приложение A. Материалы пробы

- `docs\JsonSerializer.FIXTURES.txt` — полный вывод Debug-пробы (канон фикстур).
- Probe-проект `DsonProbe.dpr` (консольная программа, линковавшая прод-юниты
  старой сборки) и RTTI-вариант `DsonProbeRtti.dpr` (дал идентичный JSON)
  выполняли разовую роль при снятии фикстур 2026-11-21; сами исходники проб
  и апстрим-копия DSON не сохранялись — артефактами замены являются только
  зафиксированные в репозитории SPEC, фикстуры и золотые тесты. Отличия
  локальной производной от апстрима (добавлен параметр `Format` в `toJson`,
  отключена null-проверка в reader'е, переработан float-reader (Currency/Comp),
  локальные имена/форматирование) на поведение замены не влияют: SPEC
  описывает локальное наблюдаемое поведение.
