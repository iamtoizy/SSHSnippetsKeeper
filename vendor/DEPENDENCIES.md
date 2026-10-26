# Vendored-зависимости

Дата вендоринга: 2026-10-26.
Источник: `C:\DC\` — рабочие копии git-репозиториев (с несмерженными локальными правками).
Цель: проект собирается и через годы, независимо от доступности апстримов на GitHub и от содержимого `C:\DC\` и глобальных Library path IDE.

Скопированы рабочие деревья без `.git` и `__history`. Скомпилированные артефакты (`.dcu`, `.dll`), попавшие в копию, игнорируются `.gitignore` и в репозиторий не попадают.

## Проvenance

- `provenance.txt` — ветка, URL апстрима и точный HEAD-хэш каждой библиотеки на момент вендоринга.
- `patches\<Библиотека>.patch` — снимок несмерженных локальных правок относительно апстрим-HEAD (`git diff --binary`). Позволяет воспроизвести состояние или перенести правки на новую версию апстрима.

## Библиотеки

| Библиотека | Апстрим | Ветка / HEAD | Вендорено | Локальные правки | Патч |
|---|---|---|---|---|---|
| SynEdit | https://github.com/TurboPack/SynEdit.git | master @ `d2074357e613b05c9b63e8675b5d1115c0735fe4` (2026-06-30, «Checked if Form.CurrentEditor is Assigned.») | `SynEdit\Source\` — включая `Highlighters\` и `Highlighters\Omni Highlighters\` | `Source\SynEdit.pas` — трек отрисовки карточек макросов (MacroCardPlugin) | `patches\SynEdit.patch` |
| HtmlViewer | https://github.com/BerndGabriel/HtmlViewer.git | HtmlViewer-11.10 @ `bd2ffb86d0f127e1da5bb2988180d8900ce836c7` (2023-12-30, «Added: Project Files for Delphi 12») | `HtmlViewer\source\` | `source\Htmlsbs1.pas`, `source\ReadHTML.pas` | `patches\HtmlViewer.patch` |
| FastMM5 | https://github.com/pleriche/FastMM5.git | master @ `13976edfc84f83c3c55e5731d30fd8686ad51f15` (2026-07-01, «#81 Export FastMM_ProcessAllPendingFrees in BorlndMM.dll») | `FastMM5\` — корень репозитория | нет (чистая копия, патч пустой) | `patches\FastMM5.patch` (0 байт) |
| python4delphi | https://github.com/Embarcadero/python4delphi.git | master @ `2757d6b24860bd53bf3e9cd5a9316401cd3ce098` (2026-02-27, «Revert "update"») | `python4delphi\Source\` — включая `Source\vcl\` и `Source\fmx\` | 17 файлов: движок (`PythonEngine.pas`, `MethodCallBack.pas`, `PythonVersions.pas`, `WrapDelphiWindows.pas`), VCL-обёртки (`Source\vcl\Wrap*.pas`, `Vcl.PythonGUIInputOutput.pas`) | `patches\python4delphi.patch` |

Примечания:

- SynEdit: untracked-папка апстрима `Packages\11AndAbove\cpp\` не вендорена — в сборку не входит.
- HtmlViewer: правки пакетных файлов (`package\FrameViewerXE9.*`) не вендорены — пакетные dproj/dpk не используются, компиляция идёт напрямую из `source\`.
- python4delphi: до вендоринга разрешалась через глобальный Library path IDE (`C:\DC\python4delphi\Source...`), теперь пути прописаны явно в `SSHSnippetsKeeper.dproj`. В `Debugger_DebugSourcePath` тоже указан вендоренный путь.
- Правки пакетных файлов python4delphi (`Packages\Delphi\Delphi 10.4+\*.dproj`) в патче есть, но сами пакеты не вендорены (не используются).

## Пути подключения

- `SSHSnippetsKeeper.dproj` (Base): `vendor\SynEdit\Source`, `vendor\SynEdit\Source\Highlighters`, `vendor\SynEdit\Source\Highlighters\Omni Highlighters`, `vendor\HtmlViewer\source`, `vendor\python4delphi\Source`, `vendor\python4delphi\Source\vcl`, `vendor\python4delphi\Source\fmx`.
- `SSHSnippetsKeeper.dproj` (Debug): `vendor\FastMM5`.
- `Tests\SSHSnippetsKeeperTests.dproj` (Base): `..\vendor\SynEdit\Source`, `..\vendor\SynEdit\Source\Highlighters`, `..\vendor\SynEdit\Source\Highlighters\Omni Highlighters`.

## Не являются зависимостями этого проекта

- DUnitX — входит в поставку RAD Studio Enterprise (тесты собираются без внешних путей).
- vcl-styles-utils, llama-cpp-delphi, delphi-detours-library, FastMM4, DUnitX-0.4.1 — другие проекты в `C:\DC\`, этим приложением не используются.
- madExcept (madCollection) — только IDE-эксперт, в код приложения не линкуется.

## Обновление вендоренной библиотеки

1. В апстрим-репозитории `C:DC\<Библиотека>` подтянуть нужную версию.
2. Сверить `patches\<Библиотека>.patch` с новой версией, перенести правки (конфликты разрешить руками).
3. Повторить копию рабочего дерева в `vendor\<Библиотека>` (без `.git`, `__history`).
4. Обновить `provenance.txt` и таблицу выше (ветка, HEAD, дата).
