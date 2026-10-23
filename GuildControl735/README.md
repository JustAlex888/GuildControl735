# Guild Control 735 for UWoW Legion — 0.0.102 TEST
Build: GuildControl735-0.0.102-20261023-01
Provenance: GC735_102_FROM_2F01BD44_LEADER_ONLY_DEFAULT

Fix: when no saved trusted-rank policy exists, only the guild master is selected.
Existing saved rank selections remain unchanged. Only the guild master may edit
the selection; their own rank stays checked and locked. Press Save and share with
guild to apply changes. No settings reset or WTF deletion is required.
Previous bilingual interface, side-tab textures, Issues/Releases links retained.
STATIC_VERIFIED / READY_FOR_TEST. Native102 installation/game check NOT_OBSERVED.
Install with WoW closed; replace addon folder only, preserve WTF.

--- Earlier documentation (historical) ---
# Guild Control 735 for UWoW Legion — 0.0.101 TEST
Build: GuildControl735-0.0.101-20261023-01
Provenance: GC735_101_FROM_4B480F4D_GITHUB_LINKS

Settings: Report a bug gives https://github.com/JustAlex888/GuildControl735/issues
Settings: Download new version gives https://github.com/JustAlex888/GuildControl735/releases
Copy with Ctrl+A / Ctrl+C and open in your browser.
Repository is currently private; other users gain access after public publication.
There are no published GitHub releases yet. This is a TEST build, not a stable release.
Install with WoW closed; replace addon folder only, preserve WTF.

--- Earlier documentation (historical) ---
# Guild Control 735 for UWoW Legion — 0.0.100 TEST
Build: GuildControl735-0.0.100-20261023-01
Provenance: GC735_100_FROM_FEC378AC_SIDE_TAB_LOCALE

Adds English Information and Message of the day side-tab textures.
Select with /gc735 language en, then /reload; ru or auto returns the corresponding language.
Original Russian assets, tab size/anchors/clicks, saved settings and exchange behavior retained.
STATIC_VERIFIED / READY_FOR_TEST. Native100 side-tab render NOT_OBSERVED.
Install with WoW closed; replace addon folder only, preserve WTF.

--- Earlier documentation (historical) ---
# Guild Control 735 for UWoW Legion — 0.0.99 TEST
Build: GuildControl735-0.0.99-20261023-01
Provenance: GC735_099_FROM_6C5F68E2_LANGUAGE_BRAND

Language override for addon UI only, stored locally for this WoW account:
/gc735 language en — English; /gc735 language ru — Russian;
/gc735 language auto — follow client. Use /reload after each change.
The game client locale is not changed or spoofed. Player names, guild rank titles,
notes, zones and other native game data keep their original language/content.
Language applies to main and My card dictionaries and static headers/filter lists
after SavedVariables load, before addon UI creation. Existing settings are retained.
Only the optional interfaceLanguage key is added; auto removes it.
Public title is Guild Control 735 for UWoW Legion. Internal GuildControl735 folder,
SavedVariables, slash commands and protocol IDs are unchanged.
STATIC_VERIFIED / READY_FOR_TEST. Native099 language switching NOT_OBSERVED.
Install with WoW closed; replace addon folder only, preserve WTF.

--- Earlier documentation (historical) ---
## 0.0.98 TEST — 2026-10-23 — Russian / English
Build: GuildControl735-0.0.98-20261023-01
Provenance: GC735_098_FROM_6D5D066C_RURU_ENUS

Complete Russian and English presentation for the current interface: guild data,
My card, analytics, roster actions, settings, network protection and messages.
681 newly externalized English entries;31 Russian technical-report entries.
Russian client uses Russian; enUS/enGB and other clients fall back to English.
Player/guild names, ranks, notes, realm aliases, search folding and saved data
are not translated. No language setting or SavedVariables migration is added.
English and Russian clients use unchanged wire/permission logic. CacheSync097
including its nil-rowID guard is byte-identical. Main079Lua module contract.
STATIC_VERIFIED / READY_FOR_TEST. New098 native RU/EN UI GAME_NOT_OBSERVED.
Existing067 gameplay results belong to097 and are not an exact098 game PASS.
Install with WoW closed; replace addon folder only, preserve WTF/SavedVariables.
Lab020 local generators require097; do not repeat load tests on098 for this UI change.

--- Earlier documentation (historical) ---
## 0.0.97 TEST — 22.10.2026
CacheSync: check ACK phase and expected rowID before concatenation. Prevents nil rowID exception on early/stale ACK. Wire format and saved data unchanged. STATIC_VERIFIED / READY_FOR_TEST; game NOT_OBSERVED.


## 0.0.96 TEST — 22.10.2026
Подсветка изменяемых границ сетевой таблицы; действия рядом со снятием выбора,
счётчик над ним. Подтверждение бана вдвое уже, компактное и перемещаемое.
Технический отчёт перемещается и открывается поверх таблицы; новый замер и краткая
сводка доступны внутри отчёта. Дубли диагностических кнопок убраны из настроек.
Автоматическая защита включается при обычном запуске, пользовательского OFF нет.
«Остановить запрос» под «Запросить данные» отменяет текущую локальную очередь;
доступна при наличии ожидающей работы. Полученные данные сохраняются.
Исправлена кодировка русских подписей краткой сводки. Сетевые протоколы, лимиты,
права, ручные баны, личные настройки и ранее принятые действия сохранены.
STATIC_VERIFIED / READY_FOR_TEST; новая сборка в игре NOT_OBSERVED.

--- Earlier documentation (historical) ---
# GuildControl735 0.0.96 TEST — 2026-10-22
Build GuildControl735-0.0.96-20261022-01; provenance GC735_096_FROM_36130A4E_SECURITY_UI_REQUEST_STOP.

Сетевая защита: отдельный сохраняемый размер с минимумом общих данных/аналитики,
поиск, классы, звания, обязательные имя/класс/уровень/звание, отключаемые остальные
столбцы, изменение ширины текстовых столбцов, сортировка и прокрутка.
Локальные автоматические срабатывания за скользящие 24 часа и 10 дней.
Режим «Действия с нарушителями»: выбор галочками, предпросмотр списка,
ручной бан на 1/3/6 дней и снятие. Решение принимает только настоящий глава.
Политика передаётся только GUILD непосредственно от главы, привязана к GUID,
применяется атомарно после проверки всего списка. Старые данные сохраняются;
новые данные заблокированного владельца не принимаются и через посредников.
Сохранённая политика действует без главы онлайн; новый клиент без подтверждения
показывает это явно. Автоматическая защита независима. «Всего банов» — число
решений главы, повторы доставки/снятие/истечение его не увеличивают.

Для общего ручного запрета получателям нужна 0.0.96 или новее: старые версии
этот протокол не поддерживают. История автоматических событий локальная;
ранее удалённые метки не восстанавливаются. Принятая политика доверяет настоящему
главе, не является криптографической подписью. Корректно оформленные ложные
карточки доверенного посредника по-прежнему нельзя автоматически отличить от
истинных. Это TEST; модельные проверки не заменяют наблюдение в WoW.
WTF/SavedVariables удалять не нужно. Публичные ссылки Issues/Releases пока
не заданы, перед публикацией обязателен RELEASE_LINK_CHECKLIST.

--- Предыдущая история ---
# GuildControl735 0.0.94 TEST — 2026-10-22
Build GuildControl735-0.0.94-20261022-01; provenance GC735_094_FROM_2E87A7D2_TRUSTED_CACHE_AND_ALERTS.
Trusted newer cache updates stale direct records; owner can still repair relay revision poisoning. Relay origin remains unverified. Local Network Security page, rolling24h incident counts, launcher warning and rate-limited local cyan chat. Recovery stages60/120/300seconds, reset after30minutes without new incident. No remote alerts or interclient WHISPER. UWoW adapters and native guild actions preserved. GAME NOT_OBSERVED.

# GuildControl735 0.0.93 TEST — 2026-10-22
Build GuildControl735-0.0.93-20261022-01; provenance GC735_093_FROM_819C4289_RELAY_BOUNDARY.
Receiver-side relay boundary: cached third-party records cannot replace direct owner records; owner responses can repair relay revision poisoning. Relay origin retained in record metadata, profile API and member-card warning. Offline catch-up retained; relay contents remain unverified and are not owner signatures. Player transport remains GUILD-only; native UWoW server adapters unchanged. Personal settings and native actions unchanged. GAME NOT_OBSERVED. Not an independent security audit or guarantee against all attacks.

# GuildControl735 0.0.92 TEST
Build GuildControl735-0.0.92-20261022-01; provenance GC735_092_FROM_AABD764A_SECURITY_ADMISSION.
Security first-pass fixes: dynamic current protocol recognition in SpamShield and own outbound accounting; native-roster sender budget before shared work budget; peer version explicitly unverified report with24hour expiry, old unstamped cache ignored. Existing personal settings/native actions preserved. STATIC validation and offline regressions required; game092 NOT_OBSERVED. Release links still placeholders; mandatory checklist retained.

# GuildControl735 0.0.91 TEST
Build GuildControl735-0.0.91-20261022-01; provenance GC735_091_FROM_C5802A88_GUILD_VERSION_NOTICE.
Guild-only version discovery; local pink notice >=120seconds after login, out of combat, at most once24hours per account across characters/reload. Settings installed/discovered versions and two copy-link actions (Issues/Releases) with explicit unpublished placeholders. Links never accepted from peers. TEST only compares TEST. No GitHub publication. Personal settings/queues/trust unchanged090.

# GuildControl735 0.0.90 TEST
Build GuildControl735-0.0.90-20261022-01; provenance GC735_090_FROM_BCAF7EB8_PERSONAL_SETTINGS.
Personal UI settings created once per player GUID at login, fresh defaults without inheriting legacy account UI. Filters, columns, sort, windows, shield independent; general/analytics start minimum1120x490. Later login/reload/update retains saved values. Account data, cards, guild trust, transport and action logic retained. No profile picker. Do not delete WTF/SavedVariables. Old shared preferences retained for rollback. STATIC validation required; GAME090 NOT_OBSERVED.

# GuildControl735 0.0.89 TEST
Build GuildControl735-0.0.89-20261022-01; provenance GC735_089_FROM_650DD6F5_HEIGHT_ONLY.
Both mass previews fixed at440logical width (prior minimum), resize height only with same bottom-right grip. Player card guild membership explicitly on next line under each alt name. Queue/action/family data unchanged088. STATIC checks required; game089 NOT_OBSERVED.

# GuildControl735 0.0.88 TEST
Build GuildControl735-0.0.88-20261022-01; provenance GC735_088_FROM_AF57126C_RESIZABLE_PREVIEWS.
Both mass previews resize by bottom-right corner in width and height. Text wraps and row layout updates; manual dimensions retained during session and state changes, footer anchored, native scrolling retained. Queue logic unchanged087. STATIC checks required; game088 NOT_OBSERVED.

# GuildControl735 0.0.87 TEST — 2026-10-22

Build: GuildControl735-0.0.87-20261022-01
Provenance: GC735_087_FROM_12202F37_CLEAR_PREVIEWS
Parent086 SHA256 12202f373bdc294452756a7b6aeada99d71daef40b126754a3f60d99be19577e.

Упрощены оба предварительных списка: убраны название гильдии, общие счётчики,
дни отсутствия и повторяющиеся технические сообщения. Короткое пояснение сообщает,
что обработка всего списка может потребовать несколько нажатий; при смене звания
переход идёт по одной ступени, число нажатий при повышении/понижении может различаться.
Без технических лимитов и описания внутреннего расчёта.

Нумерация сохранена. Имена окрашены по классу независимо от онлайна. Цвет сохраняется
и после подтверждённого исключения до закрытия/смены списка. Для назначения звания
имя, «Сейчас» и «Цель» помещаются в одну строку, если она подходит по фактической
ширине шрифта. Иначе переход переносится ниже. Для исключения — имя и состояние.

«К выполнению» белое; ожидание подтверждения жёлтое; «Выполнено» зелёное только
после подтверждения результата. Пропуск серый с причиной; неподтверждённое и
остановленное действие выделены отдельно. Реальная причина остановки остаётся видна.
Компактный размер, перетаскивание, прокрутка, «Отмена» сохранены из086.
Очереди, права, команды, подтверждения, лимит255 и ручное продолжение не менялись.
WTF/протокол/хранение не мигрируются. Нет live/sources/старых сборок/GitHub изменений.

STATIC_VERIFIED / READY_FOR_TEST; GAME087 UI NOT_OBSERVED. Только узкий визуальный
GAME_TEST061: прочитать оба списка, без новых исключений/изменений звания.
Принятые058/059 не повторять;086скриншот показывает компактный UI, перетаскивание
и длинная прокрутка отдельно ещё не подтверждались пользователем.

---
История предыдущих сборок:

# GuildControl735 0.0.86 TEST — 2026-10-22

Build: GuildControl735-0.0.86-20261022-01
Provenance: GC735_086_FROM_F79865BC_COMPACT_DIALOGS
Parent085 SHA256 f79865bc3ce3535ebc4fe5c8cdbc777a94da0931ac1eea2527d85bdcd7236c0a.

Общее окно массового исключения/назначения звания стало компактнее: ширина620
вместо740, высота подстраивается под текст в пределах240–420 вместо фиксированных
530. Текст начинается сверху, без большой пустой области. Для длинных списков
сохранена прокрутка; кнопки закреплены снизу. Фон плотнее для читаемости.
Оба вида окна перетаскиваются левой кнопкой за заголовок, остаются в пределах
экрана. Положение живёт только в текущем сеансе; новые настройки в WTF не пишутся.

Согласованное название пункта: «Отмена», без неподдерживаемой стрелки. В строке
перехода звания вместо другой стрелки: «Сейчас: ... | Цель: ...».
Отмена выбора звания возвращает к действиям; никаких команд не отправляет.
Очереди, права, макросы, лимит255 и ручное продолжение побайтно сохранены из085.
Ни live-файлы, ни WTF, ни sources, ни старые сборки не менялись. GitHub не публиковался.

STATIC_VERIFIED / READY_FOR_TEST; GAME086 UI NOT_OBSERVED. Узкий GAME_TEST060:
размер/перемещение/прокрутка без выполнения действий. Принятые058–059 не повторять.
Максимум10званий подтверждён пользователем и подходит текущему коду.

---
История предыдущих сборок:

# GuildControl735 0.0.85 TEST — 2026-10-22

Build: GuildControl735-0.0.85-20261022-01
Provenance: GC735_085_FROM_B14A8594_RANK_MENU
Parent084 SHA256 b14a8594cb82551135d9028b0edcaca014f5c365953ba26d9d318b12f86647e1.

Исправлен переход «Действия с выбранными» → «Назначить звание выбранным»:
список званий открывался и сразу закрывался общим завершением нажатия строки.
Для перехода и «Назад» добавлены штатные флаги keepShownOnClick. Сама библиотека
Dropdown и механизм массовой смены званий не меняются. Выбор конечного звания
по-прежнему открывает предварительный список; исключение открывает своё окно.

Новый тест вызывает настоящий OnClick строки, включая завершение после callback:
на старом поведении воспроизводит ошибку, с правкой проходит. Прежний тест
вызывал item.func напрямую и пропускал этот завершающий участок.
STATIC_VERIFIED / READY_FOR_TEST. GAME085 NOT_OBSERVED. В084 массовые звания
ещё не проверены: пользователь не смог открыть выбор звания (GAME_TEST057).
Сначала узкий GAME_TEST058 на открытие меню, без отправки действий.
Порции255, права, очереди, профессии/семья/SV/протокол сохранены из084.
Live/WTF/sources/старые сборки не менялись. GitHub не публиковался.

---
История предыдущих сборок:

# GuildControl735 0.0.84 TEST — 2026-10-22

Build: GuildControl735-0.0.84-20261022-01
Provenance: GC735_084_FROM_F7051B0E_MASS_RANK_TARGET
Parent083 SHA256 f7051b0eb5383d3518bc20ea867f55e152ac9d86c6d30eb06c7df6b88298d830.

По прямому запросу пользователя добавлено массовое назначение ВЫБРАННОГО
КОНЕЧНОГО звания. Выбор галочками → «Действия с выбранными…» → «Назначить
звание выбранным…» → нужное звание → предварительный список → подтверждение.
Тот же пункт доступен через контекстное меню персонажа в режиме выбора.
Одиночные действия меню сохранены.

Как в принятом одиночном окне: если до выбранного звания три ступени, одна
кнопка отправляет три последовательные native slash-команды для этой цели.
Каждому выбранному рассчитывается свой путь: повышение/понижение/уже нужное
звание (пропуск). Перед отправкой проверяются права и ВСЕ промежуточные звания.
Себя/главу/равных и старших не изменяем; передачи главы нет.

Порция ограничена255 байтами включая UTF8/команды/переводы строк. Если длинный
путь не помещается, он разбивается по границе полных команд. Сначала подтверждаем
достигнутое звание этой порции; продолжение — только СЛЕДУЮЩИМ ручным нажатием.
Промежуточное звание не отмечается окончательным успехом, галочка остаётся до
конечного результата. Нет автоматического продолжения или повтора.

Подтверждение — по GUID/имени/запрошенному званию в актуальном полном составе.
Потеря цели/прав, внешнее изменение звания, неизвестный результат/тайм-аут
не запускают повтор. Блокировки по-прежнему останавливают новые порции.
Имена для понижения — по уже принятому правилу одиночного действия.

STATIC_VERIFIED / READY_FOR_TEST. GAME084 NOT_OBSERVED; узкий GAME_TEST057 впереди.
Принятые профессии, семейный фильтр/счётчики, выбор и исключение сохранены;
WTF/протокол021/права/хранение не мигрируются. Не повторять старый полный чеклист.
Live-файлы, WTF, sources и старые сборки не менялись. GitHub не публиковался.

---
История предыдущих сборок:

# GuildControl735 0.0.83 TEST — 2026-10-22

Build: GuildControl735-0.0.83-20261022-01
Provenance: GC735_083_FROM_9E3CD3C3_FULL255
Parent 082 SHA256 9e3cd3c3a8accce6364af70605e9de251930670087a901f7ba9ff2284f77113a.

По прямому разрешению пользователя после GAME_TEST_055 восстановлен предел
255 байт на одну порцию исключения. Включены байты локализованной команды,
полных UTF-8 имён и переводов строк. Число целей не фиксировано. Каждая
следующая порция запускается отдельным ручным нажатием после подтверждения
предыдущей; автоматического продолжения или повтора нет.

Из рабочего кода изменён только лимит Services/MassActions.lua. Профессии,
обработка ошибок/блокировок, галочки выбора, семейный фильтр и счётчик сохранены
из082. Массовое повышение званий не добавлено. WTF/протокол/права не меняются.

082 GAME_TEST_055: оба исключения 2+2 подтверждены журналом; профессии при
выключенной галочке видны и открывают рецепты по скриншотам/сообщению пользователя.
083: STATIC_VERIFIED / READY_FOR_TEST; игровой прогон полного лимита NOT_OBSERVED.
Не повторять прежний полный чеклист. Установка: только папка аддона, WTF сохранить.
Live-файлы/старые сборки/sources не изменялись. GitHub не публиковался.

---
История предыдущих сборок:

# GuildControl735 0.0.82 TEST — 2026-10-22

Build: GuildControl735-0.0.82-20261022-01
Provenance: GC735_082_FROM_F3271234_PROFESSIONS_QUEUE_ERRORS
Parent: 0.0.81 TEST; SHA256 f32712345f13e75ee201941ef01d7684225fba1aeb2fc0351a2a0c6671c97c5e.
WoW Legion 7.3.5 / Interface 70300.

Две правки по GAME_TEST_054:
1. Профессии читаются с временно включённым показом отсутствующих; исходная
   галочка Blizzard и свёрнутые заголовки восстанавливаются. Повторные события
   после восстановления не запускают бесконечное переключение. Данные только
   в памяти; новых сетевых сообщений и постоянного кэша нет. Если данные ещё
   не пришли с сервера, используйте «Обновить состав» после их получения.
2. Постороннее UI_ERROR_MESSAGE больше не останавливает очередь исключения.
   Ошибки прав/гильдии сравниваются с локализованными константами клиента;
   сообщения об отсутствующем игроке/высоком звании — с именем текущей цели.
   Настоящие ADDON_ACTION_BLOCKED/FORBIDDEN по-прежнему останавливают очередь.
   Журнал сохраняет тип/номер/текст события, окно — причину остановки, кнопка
   после завершения наблюдения явно сообщает «Очередь остановлена».

Точная причина первой остановки в 054 не установлена: прежняя ветка её не
записывала. Исправлен доказанный слишком широкий обработчик, GAME082 ещё
NOT_OBSERVED. Статические модели не доказывают исправление исходного зависания.

Принятые в 081 повторный выбор без reload, семейный фильтр после ухода исходного
персонажа и счётчик 4из4→2из4 сохранены. Порог 70 байт с поправкой на локальную
команду сохранён; массовых повышений и возврата 255 байт нет. Формат WTF,
протокол 021, одиночные действия, архив и семейные связи не менялись.

STATIC_VERIFIED / READY_FOR_TEST. Установка: заменить только папку аддона.
WTF не удалять. Ни live-файлы игры, ни старые сборки не изменялись.
All Rights Reserved. No GitHub publication.

---
История предыдущих сборок:

# GuildControl7350.0.81 TEST — 2026-10-21

Build: GuildControl735-0.0.81-20261021-01
Provenance: GC735_081_FROM_DE384372_SELECTION_FAMILY_VIEW
Parent080 SHA256 de384372a69cfdb29e43ef326568631d6ab00283bb456bac9920c22569954ee1.
WoW Legion7.3.5 / Interface70300.

Только три точечные правки после тестирования080:
1. Снятие галочки при подтверждённом исключении выполняется один раз на запись
   очереди. Старый завершённый/остановленный список не снимает новые галочки
   при повторном ручном выборе или Выбрать показанных; reload не требуется.
2. Семейный отбор может найти исходного ушедшего персонажа в сохранённой
   90-дневной истории. В таблице по-прежнему только действующие участники;
   сохранённые ушедшие доступны лишь как сведения о семье. Пустой отбор при
   уходе его исходного персонажа больше не должен скрывать оставшихся.
3. Над таблицей отдельно: В гильдии:N изM. Если другие фильтры скрывают часть
   действующих участников, дополнительно показано:K изN. Ушедшие не называются
   скрытыми фильтрами. При уходе всей семьи: В гильдии:0 изM.

Из функциональных файлов изменены толькоUI/MassRoster.lua иUI/Presentation.lua.
Алгоритмы исключения/подтверждения/прав, хранение90дней, протокол021, назначение
основы и принятая одиночная смена званий сохранены побайтно. Recorder service
имеет только новый provenance label. Диагностика и сетевые правила не менялись.

TEST-порог порции сохранён из080:70байт для/gremove с поправкой на длину
локализованной команды. Для согласованных четырёх имён2+2, для других имён
число целей зависит от полной длины UTF8-команд. Возврат255байт и массовое
повышение в081не включены. MAIN не восстанавливается автоматически.

STATIC_VERIFIED / READY_FOR_TEST. GAME081 NOT_OBSERVED. Обновление заменяет
только папку аддона, WTF не удалять. Не повторять принятые смену званий,
запись/автостоп диагностики, clipboard и настройки ширин без новой причины.
All Rights Reserved. No GitHub publication/live install performed.

---
История предыдущих сборок:

# GuildControl7350.0.80 TEST — 2026-10-21

Build: GuildControl735-0.0.80-20261021-01
Provenance: GC735_080_FROM_69C4931F_RETENTION_ROSTER_ACK
Parent079 SHA256:69c4931fb78de912ee918f3073f47f26363b7712954f82a1845ac0ab3aa2dfab.
WoW Legion7.3.5 / Interface70300.

Пакет после игровых прогонов079:
- Очередь перечитывает полный нативный состав каждые0.5с во время ожидания,
  запрашивает обновление не чаще раза в3с с общим ограничителем запросов.
  Для подтверждения нужны два совпадающих полных снимка минимум через0.25с,
  в которых GUID отправленных целей отсутствуют. Ожидание ограничено45с.
  Команды исключения автоматически не повторяются; следующая порция ручная.
- Подготовленные GUID не зависят от исчезновения семейного отображения.
  Перед следующей порцией сохраняются проверки членства/имени/ранга/онлайна/
  прав/контекста. Ручная смена фильтра отменяет будущие порции.
- При видимых Общих данных проверка состава раз в10с вместо60с; интерфейс
  перечитывает доступный нативный кэш. Частоту сервера это не гарантирует.
- Профили и полученные семейные сведения ушедших сохраняются90дней с
  подтверждённого выхода в отдельном guild-local departedHistory. В активных
  таблицах ушедшие отсутствуют. PvP/Mythic+/рейдовые кэши очищаются как раньше.
  Семейные декларации оставшихся не переписываются и не удаляются из-за ссылки
  на ушедшего. Для карточки используются ранее взаимно подтверждённые связи,
  но этот исторический граф не передаётся как новое сетевое утверждение.
- В карточке семьи рядом с именами: В гильдии/Не в гильдии. При подтверждённом
  возвращении профили/семейные сведения восстанавливаются без запроса. Новые
  сведения не затираются более старой историей. MAIN/офицерская метка не
  восстанавливается. После90дней история перестаёт отображаться и очищается
  при следующей подтверждённой сверке состава. Новый выход начинает новый срок.
- Локальный отправитель передаёт текущую часть своего семейного списка вместо
  отказа от всей секции при наличии ушедшего. Получатель сохраняет проверку
  взаимности, права и формат протокола021. FAMILY_APPLIED записывает GUIDы
  частями в существующий ограниченный журнал; ARCHIVE_* — переходы хранения,
  MASS_ROSTER_* — причины ожидания и повторные запросы состава.
- Кнопка: Управление составом гильдии. Выбрано:N отдельно над Выбрать показанных.
  Подтверждённые исключённые цели снимаются с галочек/счётчика.

Одиночная смена званий/права/доверие/офицерские заметки/метка основы сохранены.
Никакого массового повышения, встроенного BugGrabber или передачи руководства.
Прежние названия вкладок, размеры и принятые предупреждения основы сохранены.

TEST byte budget remains reduced:70 for /gremove, adjusted by actual localized
slash byte length as in079. Four agreed targets still2+2. Other names can differ.
Normal255-byte budget restoration remains future separate step. No saved macro
slots, protected direct API calls or automatic clicks. All Rights Reserved.

STATIC_VERIFIED / READY_FOR_TEST. Lua5.1/LuaJIT models do not prove real game
timing/secure execution. GAME080 NOT_OBSERVED. Do not repeat accepted rank,
old diagnostic recorder, clipboard or column reset tests unnecessarily.
Install by replacing only addon folder, preservingWTF. No live installation
or GitHub publication performed by the agent.

---
История предыдущих сборок:

# GuildControl735 0.0.79 TEST — 2026-10-21

Build: GuildControl735-0.0.79-20261021-01
Provenance: GC735_079_FROM_B56670A8_GENERAL_SELECTION_TWO_BATCH_TEST
Parent: exact078TEST SHA256 b56670a89e2ba6a62a2923714ec735a3b99e64f74a9ccb5ef5e70d94819d37e0.
Interface70300 / WoW Legion7.3.5.

Вернулись четыре вкладки и их размеры/шрифт из0.0.77: Общие данные,
Моя визитка, Аналитика, Настройки. Отдельная вкладка управления убрана.
В Общих данных внизу появилась кнопка «Выбор участников». В этом режиме
доступны галочки, «Выбрать показанных», «Снять выбор», «Исключить выбранных…».
Таблица, карточка игрока и отбор «Персонажи игрока» используются существующие.
Обычный левый щелчок по имени сохраняет карточку, по заметке/профессии —
принятые окна. Выбор галочкой самостоятельный. Остальные кнопки Общих данных
сохранены. Размеры таблицы и карточки не уменьшены.

Для исключения нужны предварительный список и отдельное нажатие
«Исключить следующую порцию». Каждое нажатие запускает одну порцию,
следующая доступна после подтверждения состава. Смена фильтра, включая
отбор персонажей игрока, сбрасывает выбор и останавливает будущие порции.
Изменение ширин, видимости и сортировки столбцов не сбрасывает выбор.
Переключение страницы/закрытие/выход из режима убирает выбор и подтверждение.
Escape в окне подтверждения закрывает только его. Выбор и очередь не сохраняются.

ТОЛЬКО ЭТА TEST-СБОРКА: уменьшен байтовый бюджет порции. Для /gremove это
70байт; для локализованной команды добавляется двойная разница длины её
UTF-8-представления. Формула min(255,70+2*(#command-8)). Считаются команда,
пробел, полное имя и переводы строк; ограничения по числу целей нет.
Четыре согласованных имени: Абырвал-plusx1, Рукисила-plusx1,
Задранец-plusx1, Кокосинка-plusx1 — должны делиться2+2 в любом порядке.
Для других имён количество может отличаться. В дальнейшей обычной сборке
возвратить штатные255байт; этот TEST-порог не объявлять постоянным лимитом.

Самого себя/главу/недоступные по нативным правам цели служба пропускает.
Перед каждой порцией перепроверяются GUID/имя/ранг/онлайн/фильтр/права/контекст.
Ошибка, бой или отсутствие подтверждения прекращают дальнейшие порции.
Автоматического повтора нет. Остановка не отменяет уже отправленные команды.
Сохранённые личные/общие макросы не создаются, их свободные слоты не нужны.

Принятые смена званий, заметки, права/доверие, сеть, аналитика, визитка,
журналы и диагностика сохранены. BugGrabber не включён. GitHub не публиковался.
WTF/формат SavedVariables не менялся; старые management-настройки оставлены
нетронутыми и больше не используются. Лицензия All Rights Reserved, см.LICENSE.txt.

STATIC_VERIFIED / READY_FOR_TEST. Lua5.1/LuaJIT2.1 и моделируемые события
не равны игровому движку. Две реальные порции079 пока NOT_OBSERVED.
078: пользователь показал успешное исключение четырёх персонажей одной
порцией; это USER_REPORTED_GAME_VERIFIED/GAME_TEST051, без независимого
чтения установленных файлов и сырых логов. Подробности в инженерном отчёте.

---
История предыдущих сборок:

# GuildControl735 0.0.78 TEST — 2026-10-21

Build: GuildControl735-0.0.78-20261021-01
Provenance: GC735_078_FROM_588C773F_MODULAR_MASS_ROSTER
Base: exact077TEST SHA256588c773f5a62917fdd9a83130a69523d2e3b6193f527be3420314e7427c4f507.
Interface70300 / WoW Legion7.3.5.

Добавлена отдельная вкладка «Управление составом» между «Аналитикой» и
«Настройками». Все пять вкладок уплотнены под прежнюю ширину780 страниц
«Моя визитка»/«Настройки»; эти страницы не увеличены. Принятая косметика
окна ссылки077не менялась, отменённый черновик её изменения не включён.

Новый модуль имеет собственную таблицу, поиск/классы/звания/неактивность,
уровни/онлайн/профессии/состояния аддона, сортировку, восемь дополнительных
столбцов при четырёх обязательных, ширины и прокрутку. Его настройки отделены
от Общих данных; очередь и выбор не сохраняются после reload/выхода.
Карточки справа и трёх кнопок напоминаний/запроса аддона здесь нет.
Обновление нативного состава и приглашение используют существующие службы.

Первая версия массового действия — только исключение. Отбор фильтром сам
ничего не исполняет: нужны явный выбор, предварительный список и нажатие
«Исключить следующую порцию». Не запускайте исключение ради проверки внешнего
вида. Каждое физическое нажатие выполняет одну подготовленную порцию штатных
команд; следующая порция требует нового нажатия после подтверждения состава.
Сохранённые личные/общие макросы и бинды не создаются.

Права проверяются по актуальным нативным данным, а не по доверенным званиям
нашего протокола. Свой персонаж/глава/недоступные цели будут пропущены.
Перед отправкой перепроверяются GUID/имя/звание/онлайн/фильтр/права/контекст.
При ошибке, отсутствии подтверждения, смене фильтров, закрытии или бое
оставшиеся порции останавливаются. Автоматического повтора нет.
Остановка не отменяет строки уже запущенной порции. В отчёте различаются
отправлено/подтверждено отсутствием GUID/пропущено/не подтверждено/остановлено.

Принятая одиночная смена званий, заметки, права, доверие, сеть, аналитика,
визитка и сбор диагностических журналов сохранены. Встроенный BugGrabber не
возвращён. All Rights Reserved, см.LICENSE.txt; прежние GPL-права не отменены.

STATIC_VERIFIED / READY_FOR_TEST. В078действия в реальной игре НЕ наблюдались:
серверные ограничения UWoW/массовое исключение остаются NOT_OBSERVED.
Стенд проверяет Lua5.1/LuaJIT2.1, UI-модель и обработку очереди, а не защищённый
движок игры. Прежнюю принятую смену званий/диагностику повторять не требуется.

Установка при полностью закрытой WoW: заменить только папку GuildControl735,
сохранив WTF/SavedVariables. Точная077сборка сохранена для отката.
GitHub не публиковался; liveWoW/WTF агентом не менялись.

