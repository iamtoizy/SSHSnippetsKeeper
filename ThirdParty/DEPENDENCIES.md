# ThirdParty — зависимости

Состояние: 2026-11-21.

Каталог содержит локальные .pas-файлы стороннего происхождения, не оформленные
как vendor-каталоги. Файлы ищутся через `DCC_UnitSearchPath` обоих dproj
(`ThirdParty` / `..\ThirdParty`).

| Файл | Происхождение | Лицензия | Изменения | Статус |
|---|---|---|---|---|
| `Bcrypt.pas` | github.com/JackTrapper/bcrypt-for-delphi (форк chinshou/bcrypt-for-delphi; первичный автор Ian Boyd, 2012; v1.18, 2024-11-22) | Unlicense (public domain; полный текст в хвосте файла) | Не менялся в этой задаче | Аудит 2026-11-22: лицензия подтверждена (Unlicense, без требований атрибуции); допустимо в закрытых сборках |

## Удалённые

- `JSONSerializer.pas` — производная DSON (github.com/AlexDeww/DSON), лицензии
  у апстрима нет (all rights reserved). Удалён 2026-11-21 в рамках clean-room
  замены: собственный сериализатор живёт в `Common\Common.JsonSerializer.pas`,
  поведение зафиксировано `docs\JsonSerializer.SPEC.md`, золотые фикстуры —
  `docs\JsonSerializer.FIXTURES.txt` и `Tests\JsonSerializer.pas`.
- `ArrayHelper.pas` — Willi Commer (github.com/WilliCommer/ArrayHelper),
  шапка «Licence GNU» (вариант не уточнён). Удалён 2026-11-21 в рамках
  clean-room замены: используется только `TArrayRecord<T>`, собственная
  реализация живёт в `Common\Common.ArrayRecord.pas`, поведение
  зафиксировано `docs\ArrayHelper.SPEC.md`, золотые фикстуры —
  `docs\ArrayHelper.FIXTURES.txt` и `Tests\ArrayRecord.pas`. Прежние копии
  удалённых файлов и probe-артефакты уничтожены (последний коммит с их
  содержимым: `0ece22b^`; эталон для сверки при необходимости извлекается
  из git-истории).

## Связанные документы

- `vendor\DEPENDENCIES.md` — vendor-каталоги (SynEdit, HtmlViewer, FastMM5,
  python4delphi, SQLite3MultipleCiphers) с provenance и патчами.
- `docs\JsonSerializer.SPEC.md` — поведенческая спецификация собственного
  сериализатора.
- `docs\ArrayHelper.SPEC.md` — поведенческая спецификация `TArrayRecord<T>`.
