# ThirdParty — зависимости

Состояние: 2026-11-21.

Каталог содержит локальные .pas-файлы стороннего происхождения, не оформленные
как vendor-каталоги. Файлы ищутся через `DCC_UnitSearchPath` обоих dproj
(`ThirdParty` / `..\ThirdParty`).

| Файл | Происхождение | Лицензия | Изменения | Статус |
|---|---|---|---|---|
| `ArrayHelper.pas` | Willi Kuhnle /ToArrayRecord-хелперы/, из состава стороннего репозитория (точный источник не зафиксирован) | «Licence GNU» (вариант не уточнён) | Используется только `TArrayRecord<T>` (несущий тип настроек) | Внимание: лицензия неоднозначна; вопрос уточнения у автора — отдельная задача, в этой замене не трогался |
| `Bcrypt.pas` | Delphi-порт bcrypt (внутренние комментар­ии указывают на перевод с C) | Проверить при следующем аудите | Не менялся в этой задаче | Используется прод-кодом |

## Удалённые

- `JSONSerializer.pas` — производная DSON (github.com/AlexDeww/DSON), лицензии
  у апстрима нет (all rights reserved). Удалён 2026-11-21 в рамках clean-room
  замены: собственный сериализатор живёт в `Common\Common.JsonSerializer.pas`,
  поведение зафиксировано `docs\JsonSerializer.SPEC.md`, золотые фикстуры —
  `docs\JsonSerializer.FIXTURES.txt` и `Tests\JsonSerializer.pas`. Апстрим
  DSON сохранён вне репозитория (`%TEMP%\rufp\uDSON_upstream.pas`) только для
  справки.

## Связанные документы

- `vendor\DEPENDENCIES.md` — vendor-каталоги (SynEdit, HtmlViewer, FastMM5,
  python4delphi, SQLite3MultipleCiphers) с provenance и патчами.
- `docs\JsonSerializer.SPEC.md` — поведенческая спецификация собственного
  сериализатора.
