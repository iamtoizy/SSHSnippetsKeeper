# ThirdParty — зависимости

Состояние: 2026-11-21.

Каталог содержит локальные .pas-файлы стороннего происхождения, не оформленные
как vendor-каталоги. Файлы ищутся через `DCC_UnitSearchPath` обоих dproj
(`ThirdParty` / `..\ThirdParty`).

| Файл | Происхождение | Лицензия | Изменения | Статус |
|---|---|---|---|---|
| `Bcrypt.pas` | Delphi-порт bcrypt (внутренние комментар­ии указывают на перевод с C) | Проверить при следующем аудите | Не менялся в этой задаче | Используется прод-кодом |

## Удалённые

- `JSONSerializer.pas` — производная DSON (github.com/AlexDeww/DSON), лицензии
  у апстрима нет (all rights reserved). Удалён 2026-11-21 в рамках clean-room
  замены: собственный сериализатор живёт в `Common\Common.JsonSerializer.pas`,
  поведение зафиксировано `docs\JsonSerializer.SPEC.md`, золотые фикстуры —
  `docs\JsonSerializer.FIXTURES.txt` и `Tests\JsonSerializer.pas`. Апстрим
  DSON сохранён вне репозитория (`%TEMP%\rufp\uDSON_upstream.pas`) только для
  справки.
- `ArrayHelper.pas` — Willi Commer (github.com/WilliCommer/ArrayHelper),
  шапка «Licence GNU» (вариант не уточнён). Удалён 2026-11-21 в рамках
  clean-room замены: используется только `TArrayRecord<T>`, собственная
  реализация живёт в `Common\Common.ArrayRecord.pas`, поведение
  зафиксировано `docs\ArrayHelper.SPEC.md`, золотые фикстуры —
  `docs\ArrayHelper.FIXTURES.txt` и `Tests\ArrayRecord.pas`. Апстрим
  сохранён вне репозитория (`%TEMP%\rufp\dsonprobe\ArrayProbe*.dpr`
  ссылаются на удалённую копию через junction `C:\temp-links\ssk`
  только для справки).

## Связанные документы

- `vendor\DEPENDENCIES.md` — vendor-каталоги (SynEdit, HtmlViewer, FastMM5,
  python4delphi, SQLite3MultipleCiphers) с provenance и патчами.
- `docs\JsonSerializer.SPEC.md` — поведенческая спецификация собственного
  сериализатора.
- `docs\ArrayHelper.SPEC.md` — поведенческая спецификация `TArrayRecord<T>`.
