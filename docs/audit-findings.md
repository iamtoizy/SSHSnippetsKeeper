# Аудит кода SSHSnippetsKeeper

Дата: 2026-11-17. Объём: 148 units / 55 649 строк (Core, Automation, Data, Common, UI, MacroEngine), тесты: 43 units / 16 374 строк. Проверка статическая (rg/PowerShell-анализ + чтение кода); динамических тестов на проникновение не проводилось.

Итог: критических уязвимостей не найдено. Найдено: 3 средних, 3 низких, 3 информационных замечания.

## Статус фикс-сессии (2026-11-17)

- **M1, M2, M3 — исправлено.** Единый хелпер `Common\Common.RegexSafety.pas`: пользовательские regex исполняются через прямой PCRE API (`pcre_compile`/`pcre_exec`, `PCRE_EXTRA_MATCH_LIMIT = 500000` вызовов match()) — RTL-перегрузки `TRegEx` с таймаутом отсутствуют, ограничение реализовано через match_limit PCRE. Заменены все 4 точки (include/exclude в `ProcessProfile.pas`, deny `Rule.Pattern`, sanitize в `Common.Settings.pas`, `IsValidRegex` в обоих диалогах). Тесты: `RegexSafety_CatastrophicPattern_TimesOut`, `RegexSafety_InvalidPattern_SilentFalse`, `RegexSafety_TitleGate_ToleratesBrokenInclude` в `TProcessProfileFilterTests`.
- **I2 — выполнено:** `Assets\ExeData\libsqlcipher-0.dll` удалён.
- **L1 — пересмотрено (false positive):** это не дубль. `V001__baseline_core.sql` — исторический baseline (v1..v6, старт миграций), `000_schema_init.sql` — эталон текущей схемы (`PRAGMA user_version = 14`). Разные артефакты; эквивалентность миграционного пути эталону проверяется тестом `MigratedSchema_MatchesBaselineObjects` (`Tests\DbMigrations.pas:199-231`). Действий не требуется.
- **L2 — пересмотрено:** каждый из 4 сайтов уже нейтрализует риск в собственном коде: `SettingsFormUI` блокирует закрытие формы при `FBackupBusy`/`FDbBusy` (`FormCloseQuery`, :2120), `PasswordGenFormUI` — `FBcryptBusy` (:867), `DbConvertProgressUI` — `CanClose := FDone` (:78), `MainForm` проверяет `Application.Terminated` перед UI-вызовом (:1228). Паттерн `FAIThread` (`AddEditSnippetFormUI:1113-1175`) — рекомендация для будущих долгих операций; работающий код не менялся, чтобы не вносить новые гонки.
- **I1 — решено владельцем (2026-11-17): оставлено как есть** — заготовка под будущую локальную AI-интеграцию, код и DLL-поставку не трогаем.
- **I3 — отложено:** декомпозиция god-форм отдельной сессией.
- Верификация: main Debug Win64 — сборка EXIT 0; тесты — **588 passed / 0 failed / ExitCode 0** (585 базовых + 3 новых).

## Сводка

| ID | Severity | Суть |
|----|----------|------|
| M1 | Средний | Пользовательские regex исполняются без таймаута (ReDoS, freeze UI) |
| M2 | Средний | Полная копия `TAITextCleaner` в `UI.Services.AIService` |
| M3 | Средний | Sanity-валидатор regex скопирован трижды |
| L1 | Низкий | Дублирование схемы БД: `000_schema_init.sql` vs `V001__baseline_core.sql` |
| L2 | Низкий | 4 анонимных потока с `FreeOnTerminate=True` в формах |
| L3 | Низкий | Слабая изоляция слоёв: Core/MacroEngine тянут Vcl |
| I1 | Инфо | Мёртвый Python-слой (Python4Delphi под неопределённым `SSK_PYTHON`) |
| I2 | Инфо | Мёртвый бинарный груз: `libsqlcipher-0.dll`, sqlite3.dll в Python-подкаталоге |
| I3 | Инфо | God-формы: MainFormUI 4092 строк, 9 методов > 120 строк |

## Средние

### M1. ReDoS: пользовательские regex без MatchTimeout

- `Automation\ProcessProfile.pas:164`, `:169` — include/exclude паттерны профилей окон; `:216` — deny-правила (`Rule.Pattern`). Все через `TRegEx.IsMatch(..., [roIgnoreCase])` без таймаута.
- `MatchTimeout` в кодовой базе не встречается ни разу (проверка rg по всем слоям).
- Исполняется на UI-потоке: гейт видимости окон (`Automation\WindowMonitor.pas` → `MatchesWindow`) и живое превью `WindowProfileDialogUI` (пересчёт на `leClassesChange`).
- Смягчение уже есть: паттерны валидируются на компилируемость при вводе/санитайзе (`WindowProfileDialogUI.pas:369`, `WindowDenyBuilderUI.pas:278`, `Common\Common.Settings.pas:779`) — битые шаблоны отсекаются, но экспоненциальные валидны.
- Вектор: чужой/импортированный `settings.json` с патологическим паттерном → зависание UI при каждом сканировании окон.
- **Статус: исправлено** — см. блок «Статус фикс-сессии»: `TRegexSafety` (PCRE match_limit), 4 точки замены, 3 теста.
- Рекомендация (исходная): единый хелпер с ограничением времени исполнения для всех пользовательских паттернов; тот же хелпер закрыть M3.

### M2. Копия TAITextCleaner в AIService

- `UI\Services\UI.Services.AIService.pas:50-59` (`CleanInlineMarkdown`) и `:61-118` (`ExtractPureCode`) — дословная копия `UI\Services\UI.Services.AITextCleaner.pas:23-118`. `uses` AIService юнит `UI.Services.AITextCleaner` не подключает.
- Признак расползания: комментарий в AITextCleaner про «границу слова `[^|\s]`» не соответствует коду ни в одной из копий (везде `(.*?)`).
- **Статус: исправлено** — копия удалена из AIService, `uses UI.Services.AITextCleaner` подключён (одна каноническая реализация).

### M3. Тройная копия sanity-валидатора regex

- Идентичные `try TRegEx.IsMatch('', APattern) except`:
  - `Common\Common.Settings.pas:776-783` (санитайзер, с логом),
  - `UI\Forms\WindowProfileDialogUI.pas:365-373`,
  - `UI\Forms\WindowDenyBuilderUI.pas:274-281`.
- **Статус: исправлено** — все три на `TRegexSafety.PatternIsValid`/`TryCompile`; диалоговые валидаторы теперь совпадают с исполнением (один движок и лимит).

## Низкие

### L1. Дублирование схемы БД — ПЕРЕСМОТРЕНО: не дубль

- Изначальная гипотеза «`000_schema_init.sql` == тело `V001__baseline_core.sql`» опровергнута полным Compare-Object (144 строки только в schema_init, 25 — только в V001) и контекстом: `V001__baseline_core.sql` — **исторический baseline** (v1..v6, до начала миграций), `000_schema_init.sql` — **эталон текущего состояния схемы** (`PRAGMA user_version = 14`). Это разные по назначению артефакты.
- Связка гарантирована тестом `Tests\DbMigrations.pas:199-231` (`MigratedSchema_MatchesBaselineObjects`): объекты БД, собранной миграциями, сверяются с эталоном schema_init.
- Действий не требуется. (fc.exe в первичном прогоне дал артефактный «no differences» — кодировка/обрезка вывода; для сравнения SQL-эталонов использовать Compare-Object по строкам.)

### L2. Анонимные потоки с FreeOnTerminate=True в формах — ПЕРЕСМОТРЕНО: защита уже в коде

- `UI\Forms\MainFormUI.pas:1205` (автобэкап), `UI\Forms\SettingsFormUI.pas:743` (ручной бэкап), `UI\Forms\PasswordGenFormUI.pas:1219` (bcrypt), `UI\Forms\DbConvertProgressUI.pas:89` (конверсия шифрования БД).
- При детальном чтении каждый сайт оказался защищён собственным механизмом, исключающим Synchronize в уничтоженную форму:
  - `SettingsFormUI`: закрытие формы блокируется в `FormCloseQuery` при `FBackupBusy or FDbBusy` (:2120) — форма жива до завершения фона;
  - `PasswordGenFormUI`: та же блокировка через `FBcryptBusy` (:867), данные в лямбде переносятся в локальные переменные (:1224-1229);
  - `DbConvertProgressUI`: модальное окно держится `CanClose := FDone` (:78);
  - `MainFormUI`: перед UI-вызовом проверяется `Application.Terminated` (:1228), флаг сбрасывается всегда.
- Паттерн `FAIThread` (`AddEditSnippetFormUI:1113-1175`, поле + `FreeOnTerminate=False` + `OnTerminate`) — рекомендация для будущих **долгих/отменяемых** операций (как AI-запрос до 60 с). Для коротких фоновых работ с блокировкой закрытия существующий дизайн безопасен; перевод на другой паттерн без реальной пользы только добавил бы WaitFor-риски при завершении приложения. Код не менялся.

### L3. Слабая изоляция слоёв (Vcl в не-UI)

- `Common\Common.Helpers.pas` (Clipbrd/ComCtrls/Controls/Menus/StdCtrls), `Common\Common.Localization.pas` (ComCtrls/Forms), `Core\Services\HotkeyService.pas` (ActnList/Menus), `MacroEngine\MacroThread.pas` (Forms), `Common\Common.VCLStyleService.pas` (по назначению).
- Обосновано функционально (буфер обмена, ShortCut, локализация контролов), но связывает Core/MacroEngine с VCL.
- Рекомендация: развязать интерфейсами при следующем касании этих юнитов; отдельным приоритетом не делать.

## Информационные

### I1. Мёртвый Python-слой — оставлен по решению владельца

- `Core\Core.LocalAIService.pas` — Python4Delphi-ветки целиком под `{$IFDEF SSK_PYTHON}`; дефайн не задан ни в `SSHSnippetsKeeper.dproj`, ни в тестовом dproj → код мёртв во всех текущих конфигурациях. `Assets\ExeData\Python\` (6 DLL, ~11 MB) поставляется, но не активируется.
- **Статус: оставлено как есть** (решение владельца, 2026-11-17) — слой рассматривается как заготовка под будущую локальную AI-интеграцию. Код и поставка Python-DLL не трогаются.

### I2. Мёртвый бинарный груз — выполнено

- `Assets\ExeData\libsqlcipher-0.dll` (1.5 MB) — ссылок нет ни в коде, ни в dproj (движок — `sqlite3mc_x64.dll`, `Data\Data.Database.Security.pas:93`). **Статус: удалён (2026-11-17).**
- `Assets\ExeData\Python\sqlite3.dll` (plain) — не загружается приложением (VendorLib абсолютный, изолирован подкаталогом), балласт; судьба зависит от решения по I1.

### I3. God-формы и длинные методы — отложено (отдельная сессия)

Топ размеров: `MainFormUI` 4092, `AddEditSnippetFormUI` 2387, `SettingsFormUI` 2212, `ChooseTerminalWindowUI` 1338, `PasswordGenFormUI` 1332, `SnippetRepository` 1215, `Common.Settings` 1121, `Data.Database.Migrations` 1076, `MacroEngine` 1001.

Методы > 120 строк:

| Строк | Метод | Место |
|-------|-------|-------|
| 282 | `bDbApplyClick` | SettingsFormUI.pas:1080 |
| 187 | `bDbImportClick` | SettingsFormUI.pas:1445 |
| 173 | `DoGenerate` | PasswordGenFormUI.pas:402 |
| 166 | `OpenDatabaseFile` | MainFormUI.pas:664 |
| 145 | `ExecuteAICommand` | AddEditSnippetFormUI.pas:1062 |
| 143 | `InitializeUI` | PasswordGenFormUI.pas:714 |
| 136 | `PopulateList` | ChooseTerminalWindowUI.pas:1186 |
| 127 | `Prepare` | AddEditSnippetFormUI.pas:2118 |
| 122 | `FillSnippetListView` | MainFormUI.pas:2665 |

Контроллеры уже применяются (`SearchController`, `SyncController`, `SecurityScanController`, `SnippetRunner`, `CategoryTreeController`) — продолжать вынос логики из форм по этому паттерну. Первые кандидаты: `bDbApplyClick`, `DoGenerate`.

## Проверено, проблем не найдено

- SQL: параметризация тотальна (`?`/named); LIKE через `EscapeLike` (`Data\Repositories\UserRepository.pas:99`, `TagRepository.pas:99`); FTS MATCH параметризован (`SnippetRepository.pas:95, 728, 831`); конкатенации — только константное сложение строк запроса.
- Секреты: в git нет бд/ключей/бэкапов (`.gitignore`: `*.sqlite`, `*.bak`, `Binary/`, `Python/`, `settings.json`; `git ls-files` — чисто). Ключ БД и APIKey хранятся только под DPAPI-блобами (`Common.Settings:122-123` `SECRET_PREFIX='dpapi:'`; константная энтропия — задокументированный трейдофф, `Core.Interfaces.Settings.pas:147-181`). В исходниках — только плейсхолдеры и тестовые константы.
- DLL-загрузка: VendorLib — абсолютный путь от exe (`Data\Database.Security.pas:157-162`, `TPath.Combine(GetDirectoryName(ParamStr(0)), ...)`) — hijack через CWD/PATH исключён; `SetDllDirectory`/`LoadLibrary` в коде не используются.
- Сеть: единственная точка `TNetHTTPClient` (`UI.Services.AIService.pas:40-41, 146`), таймауты 15 с/60 с (`:151-152`), Bearer поверх HTTPS.
- Хуки: глобальных нет; `RegisterHotKey` (`UI\Controllers\GlobalHotkeyManager.pas:92`); `GetAsyncKeyState` — только кнопки мыши (`QuickSearchFormUI.pas:383-385`, `UI\Helpers\UI.HoverHelpManager.pas:443`).
- Реестр: только `KEY_READ` (`Automation\AppEnumerator.pas:151`, `Core\CompletionProviders.pas:270`).
- ShellExecute: только http/https из HTMLViewer (`UI\Forms\CustomHelpFormUI.pas:308-315`) с toast при ошибке.
- Печать сниппетов: `Automation\WindowHelper.pas` — `TInterlocked` на контексте (`:281-321, 410-627`), полный lifecycle (`AbortMacro`, `ReapAbandoned`, `Shutdown`).
- Потоки/синхронизация: `TMonitor` (`CompletionProviders:319`, `Common.AppState:153`), `TCriticalSection` (`Localization:77-83`, `Common.Helpers:84`); `SyncController.WaitForCompletion` (`:105-116`) — busy-wait с `CheckSynchronize(10)` до 10 с: допустимо, атомарность чтений прокомментирована; кандидату на событие вместо поллинга — низкий приоритет.
- Маркеры: TODO/FIXME/HACK — 2 вхождения (`UI\ViewModels\SnippetViewData.pas:22`, `UI\Forms\BaseFormUI.pas:60`); `OutputDebugString` — 29 вхождений (отладочный вывод, при желании собрать под `{$IFDEF DEBUG}` — косметика).
- Дубли ListView-колонок уже вынесены в `TListViewColumnFitter` (предыдущий коммит); повторяющиеся имена методов форм — стандартные VCL-хуки (`DoInitialize` x24 — базовый паттерн `BaseFormUI`), копипаст-дублей сверх M2/M3 не выявлено.

## Рекомендуемый порядок работ

1. ~~M1+M3 — единый regex-хелпер~~ — **выполнено** (`Common.RegexSafety`, PCRE match_limit, 3 теста, 588 passed).
2. ~~M2 — удалить копию `TAITextCleaner`~~ — **выполнено**.
3. ~~L2 — перевести 4 анонимных потока~~ — **закрыто пересмотром**: защита уже реализована блокировкой закрытия/проверкой `Application.Terminated`.
4. ~~I2 — удалить `libsqlcipher-0.dll`~~ — **выполнено**.
5. ~~L1 — генерация одного скрипта из другого~~ — **снято**: артефакты разные (baseline истории vs эталон текущей схемы), эквивалентность покрывает тест.
6. ~~I1 — решение по Python-слою~~ — **решено владельцем: оставить как есть** (заготовка под будущую интеграцию).
7. I3 — поэтапная декомпозиция `bDbApplyClick`/`DoGenerate` — **отложено** в отдельную сессию.
