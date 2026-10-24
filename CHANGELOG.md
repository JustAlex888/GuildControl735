# Changelog

## 0.0.103 TEST — 2026-10-24

Cooperative automatic survey: 30-minute passes, 8-hour successful-owner suppression, one active collector and trusted-peer queue/result synchronization with takeover. Ordinary members refresh saved copies every 2 hours. A pass has a 15-minute budget; remaining work is reconsidered at the next pass. Settings and saved data are preserved.

Совместный автоматический опрос: проходы раз в 30 минут, пропуск успешно опрошенных на 8 часов, один ведущий и передача очереди/результатов доверенным клиентам. Рядовые обновляют сохранённую копию раз в 2 часа. Лимит прохода — 15 минут; оставшиеся кандидаты рассматриваются на следующем проходе. Настройки и накопленные данные сохраняются.

Validation: production two-client automatic exchange confirmed from supplied game logs. Separate two-computer LAB confirmed late join, collector takeover after 40/60 and convergence to identical 60/60 marks. LAB uses synthetic owners/private transport; this is not a 60-player production load test. One cache timeout recovered. Large-guild real throughput remains unmeasured.

## 0.0.102 TEST — 2026-10-23

First public pre-release of Guild Control 735 for UWoW Legion.
Initial trusted-rank selection is guild-master-only when no policy is saved.
Existing selections are retained. Russian/English interface and project links included.
Full user guides and annotated screenshots accompany the repository.

Первый публичный предварительный выпуск Guild Control 735 for UWoW Legion.
При отсутствии сохранённой настройки в доверенных званиях выбран только глава.
Прежний выбор сохраняется. Включены русский/английский интерфейс и ссылки проекта.
В репозитории размещены полные руководства и подготовленные иллюстрации.
