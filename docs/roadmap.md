# Дорожная карта TPM Lab на 17 недель

Проект выполняется двумя участниками недельными Scrum-спринтами. Каждую неделю команда фиксирует Sprint Goal, план и факт, acceptance criteria, риски, вклад обоих участников, результат review и проверяемое evidence. Видимая работа должна появляться еженедельно: сдача только готового финального проекта не компенсирует пропущенные этапы.

Лаборатория использует реальное выполнение ПО в Ubuntu 24.04 ARM64 внутри UTM/QEMU на macOS Apple Silicon, но TPM 2.0 реализуется программно через `swtpm`. Это не моделирует физическую tamper resistance аппаратного TPM.

## Этап 1 — недели 1–6: Scrum + архитектура и техническая спецификация

Цель этапа: организовать прозрачный Scrum-процесс и подготовить защищаемые архитектуру, требования, спецификацию и проект среды. TPM-функциональность на этом этапе не считается реализованной без фактического запуска и проверки.

### Sprint 01 — Project charter, scope, initial backlog, architecture v0.1

**Sprint Goal:** определить проект, зафиксировать границы и создать первую защищаемую архитектуру и план разработки.

**Candidate tasks:**
- `PM-001` — определить scope, цели и ограничения проекта.
- `PM-002` — сформировать initial backlog на 17 недель.
- `ARCH-001` — подготовить architecture v0.1.
- `DOC-001`, `DOC-002` — создать glossary v0.1 и содержание technical specification.
- `PM-003`, `PM-004` — определить Definition of Done и начальный risk register.

**Ожидаемый demo/artifact:** краткий review структуры документации, цели, архитектурной схемы, backlog и плана Sprint 02; без TPM-команд и вымышленных результатов.

**Exit criteria:**
- scope, out-of-scope и ограничения `swtpm` сформулированы явно;
- backlog покрывает 17 недель и содержит owner/reviewer;
- architecture v0.1 показывает host, VM, software stack и границу эмуляции;
- Sprint 02 имеет согласованный план.

### Sprint 02 — Requirements and technical specification v0.1

**Sprint Goal:** превратить цели проекта в проверяемые требования и technical specification v0.1.

**Candidate tasks:**
- уточнить FR-01–FR-14 и NFR-01–NFR-10;
- задать verification method и target milestone для каждого требования;
- описать компоненты, интерфейсы, error handling и logging;
- связать требования с demo-сценариями и backlog;
- провести взаимный review спецификации.

**Ожидаемый demo/artifact:** requirements baseline и technical specification v0.1 с traceability к демо и этапам.

**Exit criteria:**
- каждое требование однозначно проверяемо;
- MVP и final acceptance criteria разделены;
- неподтверждённые свойства среды отмечены как assumptions;
- замечания взаимного review обработаны.

Фактическая работа Sprint 02 дополнительно провела ARM64 Docker technical spike и simulator research; ТЗ остаётся v0.1. Отчёт: [Sprint 02](sprints/sprint-02.md).

### Sprint 03 — VM architecture and environment design

**Фактически:** Sprint 03 выполнен как comparative spike `ms-tpm-20-ref` по плану, зафиксированному в конце Sprint 02. Отчёт: [Sprint 03](sprints/sprint-03.md). Исходный VM environment design (ARCH-005) переносится на следующий спринт.

**Исходный Sprint Goal:** спроектировать воспроизводимую ARM64-среду до начала развёртывания.

**Candidate tasks:**
- выбрать конфигурацию UTM/QEMU для Ubuntu 24.04 ARM64;
- описать CPU, RAM, storage, networking и способ подключения `swtpm`;
- определить версии и источники пакетов;
- спроектировать reset/re-run и хранение состояния TPM;
- подготовить environment checklist и troubleshooting plan.

**Ожидаемый demo/artifact:** environment design v1 с deployment diagram, configuration matrix и процедурой проверки.

**Exit criteria:**
- все компоненты и границы ответственности описаны;
- ARM64-совместимость запланирована к фактической проверке;
- определены clean state и recovery procedure;
- дизайн прошёл review обоих студентов.

### Sprint 04 — Ubuntu ARM64 VM deployment

**Sprint Goal:** развернуть и доказательно проверить базовую Ubuntu ARM64 VM.

**Candidate tasks:**
- создать Ubuntu 24.04 ARM64 VM в UTM/QEMU;
- проверить архитектуру guest OS и базовую сеть;
- зафиксировать параметры VM и шаги установки;
- выполнить повторную проверку инструкции вторым студентом;
- записать реальные логи и выявленные отклонения.

**Ожидаемый demo/artifact:** загружаемая VM, воспроизводимая инструкция и evidence фактической ARM64-конфигурации.

**Exit criteria:**
- Ubuntu VM стабильно загружается;
- архитектура ARM64 подтверждена реальной командой;
- второй студент воспроизвёл или пошагово проверил процедуру;
- известные проблемы занесены в risk register.

### Sprint 05 — swtpm, TPM2-TSS and tpm2-tools setup

**Sprint Goal:** подключить software TPM stack и подтвердить связность без заявления о готовности функциональных демо.

**Candidate tasks:**
- установить и настроить `swtpm`;
- установить совместимые `TPM2-TSS` и `tpm2-tools`;
- настроить и документировать TCTI;
- проверить жизненный цикл процесса и состояния `swtpm`;
- собрать реальные версии, диагностику подключения и процедуру reset.

**Ожидаемый demo/artifact:** воспроизводимый setup и фактическое evidence доступности software TPM interface.

**Exit criteria:**
- версии компонентов зафиксированы;
- TCTI соединяет tools со `swtpm`;
- clean reset описан и проверен;
- документация не приписывает `swtpm` аппаратную защиту.

### Sprint 06 — Stage 1 stabilization and architecture/TZ review

**Sprint Goal:** стабилизировать документы и среду, закрыть критерии Этапа 1.

**Candidate tasks:**
- провести traceability review требований, архитектуры и backlog;
- устранить замечания к architecture и technical specification;
- повторить environment setup по инструкции;
- оценить Stage 1 DoD и оставшиеся риски;
- подготовить review Этапа 1 и план MVP.

**Ожидаемый demo/artifact:** Stage 1 review package: актуальные архитектура/ТЗ, setup evidence, risk register и план недель 7–12.

**Exit criteria:**
- Scrum evidence доступно для каждой из недель 1–6;
- архитектура и ТЗ согласованы с фактической средой;
- setup воспроизводим либо отклонения явно зафиксированы;
- backlog MVP уточнён и готов к Sprint 07.

## Этап 2 — недели 7–12: Scrum + работающий MVP

Цель этапа: получить воспроизводимый работающий MVP с Demo 1–4, единым запуском и реальной автоматической проверкой успешных и ошибочных сценариев.

### Sprint 07 — Demo 1: TPM discovery

**Sprint Goal:** реализовать и проверить обнаружение TPM, capabilities и properties.

**Candidate tasks:**
- реализовать discovery-сценарий через `tpm2-tools`;
- запросить capabilities, version и properties;
- обработать недоступный TCTI/TPM;
- добавить автоматические проверки реального результата;
- оформить короткое demo evidence.

**Ожидаемый demo/artifact:** Demo 1 с реальным выводом среды и однозначным PASS/FAIL, вычисляемым по результату команд.

**Exit criteria:**
- соединение с `swtpm` подтверждается выполнением;
- capabilities и properties получены и объяснимы;
- негативный сценарий корректно завершается ошибкой;
- второй студент провёл review и повторный запуск.

### Sprint 08 — Demo 2: PCR Read/Extend

**Sprint Goal:** показать реальное чтение и необратимое обновление PCR через Extend.

**Candidate tasks:**
- выбрать PCR bank/index и зафиксировать исходное значение;
- подготовить deterministic measurement;
- выполнить PCR Extend и повторное чтение;
- проверить ожидаемое новое значение независимо;
- добавить reset/re-run и негативные проверки.

**Ожидаемый demo/artifact:** Demo 2: before/measurement/after с проверкой изменения PCR.

**Exit criteria:**
- PCR читается до и после Extend;
- ожидаемый digest вычисляется, а не подменяется;
- изменение PCR доказано реальным результатом;
- повторный запуск начинается из документированного состояния.

### Sprint 09 — TPM object/key creation

**Sprint Goal:** создать TPM-backed key и документировать жизненный цикл объекта.

**Candidate tasks:**
- выбрать key hierarchy, algorithm и attributes;
- создать primary/object key;
- сохранить только допустимые public/private object blobs;
- реализовать load/cleanup и диагностику ошибок;
- проверить свойства объекта и воспроизводимость.

**Ожидаемый demo/artifact:** key lifecycle artifact с командами, metadata и evidence успешной загрузки объекта.

**Exit criteria:**
- ключ создаётся и загружается через TPM stack;
- private key не представлен как обычный plaintext key file;
- параметры и cleanup документированы;
- реализацию и evidence проверил второй студент.

### Sprint 10 — Demo 3: signing and verification

**Sprint Goal:** подписать данные TPM-backed key и проверить подпись независимым шагом.

**Candidate tasks:**
- подготовить deterministic test message;
- выполнить hashing/signing через TPM-backed key;
- экспортировать public key в подходящем формате;
- проверить валидную подпись;
- проверить отказ на изменённых сообщении или подписи.

**Ожидаемый demo/artifact:** Demo 3 с успешной verification и реальным отрицательным тестом.

**Exit criteria:**
- valid signature проходит verification;
- изменённые данные не проходят verification;
- статусы выводятся из exit code/проверок, без fake PASS;
- оба студента могут объяснить хранение private material.

### Sprint 11 — Demo 4: sealing and PCR policy

**Sprint Goal:** связать доступ к secret с PCR policy и показать реальный policy failure.

**Candidate tasks:**
- зафиксировать известное PCR state и построить policy digest;
- создать sealed object с тестовым secret;
- выполнить успешный Unseal в исходном состоянии;
- изменить PCR через Extend;
- подтвердить отказ Unseal из-за policy validation;
- добавить безопасный cleanup и rerun.

**Ожидаемый demo/artifact:** Demo 4: успешный Unseal до изменения PCR и фактический отказ после изменения.

**Exit criteria:**
- secret восстанавливается только при подходящем PCR state;
- после PCR Extend TPM/TSS возвращает реальную ошибку policy;
- скрипт не имитирует отказ собственной условной веткой;
- процедура объяснима и повторяема.

### Sprint 12 — Integrated automated MVP

**Sprint Goal:** объединить Demo 1–4 в воспроизводимый MVP с единым runner.

**Candidate tasks:**
- реализовать единые команды запуска отдельных и всех демо;
- нормализовать logging, exit codes и machine-readable status;
- добавить preflight, reset и cleanup;
- выполнить end-to-end и rerun tests;
- обновить MVP runbook и собрать demo evidence.

**Ожидаемый demo/artifact:** автоматический MVP, запускающий discovery, PCR, signing и sealing последовательно.

**Exit criteria:**
- Demo 1–4 проходят в поддерживаемой среде;
- обязательный отрицательный policy test действительно завершается отказом;
- runner возвращает корректный итоговый exit code;
- другой студент воспроизводит запуск по документации;
- Scrum evidence доступно для недель 7–12.

## Этап 3 — недели 13–17: Scrum + завершённое качество

Цель этапа: сравнить FAPI и ESAPI, повысить тестируемость и воспроизводимость, завершить документацию и подготовить совместную защиту.

### Sprint 13 — FAPI implementation

**Sprint Goal:** реализовать выбранную security-relevant операцию через высокоуровневый FAPI.

**Candidate tasks:**
- подготовить FAPI configuration и provisioning;
- выбрать операцию, сопоставимую с ESAPI-вариантом;
- реализовать FAPI workflow и cleanup;
- обработать ошибки и добавить проверки;
- документировать abstractions и состояние keystore.

**Ожидаемый demo/artifact:** работающий FAPI-сценарий с реальным результатом и объяснением скрываемых уровней.

**Exit criteria:**
- FAPI operation выполняется повторяемо;
- конфигурация и provisioning воспроизводимы;
- success/failure проверяются автоматически;
- второй студент провёл code и demo review.

### Sprint 14 — ESAPI implementation

**Sprint Goal:** реализовать эквивалентную операцию через низкоуровневый ESAPI.

**Candidate tasks:**
- спроектировать resource/session lifecycle;
- реализовать ESAPI initialization и TCTI integration;
- выполнить эквивалентную security-relevant операцию;
- добавить cleanup и error-path handling;
- сопоставить шаги ESAPI с FAPI.

**Ожидаемый demo/artifact:** работающий ESAPI-сценарий и техническая карта вызовов/resources.

**Exit criteria:**
- ESAPI operation даёт проверяемый эквивалентный результат;
- handles, contexts и память корректно освобождаются;
- ошибки содержат диагностический контекст;
- реализация проверена другим студентом.

### Sprint 15 — Demo 5: FAPI vs ESAPI comparison and tests

**Sprint Goal:** объективно сравнить уровни abstraction на одной операции и расширить regression suite.

**Candidate tasks:**
- унифицировать входы и ожидаемый результат FAPI/ESAPI;
- добавить positive и negative comparison tests;
- сравнить setup, lifecycle, объём контроля и error handling;
- автоматизировать Demo 5;
- обновить requirements traceability.

**Ожидаемый demo/artifact:** Demo 5 и evidence-основанная сравнительная записка FAPI vs ESAPI.

**Exit criteria:**
- сравниваются одинаковые или явно эквивалентные операции;
- обе реализации имеют автоматические проверки;
- выводы подтверждаются кодом и запуском;
- ограничения сравнения сформулированы явно.

### Sprint 16 — Bug fixing, reproducibility, documentation, rehearsal

**Sprint Goal:** устранить дефекты, подтвердить clean-room воспроизводимость и отрепетировать финальное демо.

**Candidate tasks:**
- выполнить полный regression run и исправить критичные дефекты;
- проверить развёртывание из clean state;
- завершить user, architecture и troubleshooting docs;
- проверить timing и fallback финального демо;
- провести взаимную репетицию и сверить Final DoD.

**Ожидаемый demo/artifact:** release candidate, reproducibility report и rehearsal log.

**Exit criteria:**
- обязательные demo/tests проходят на чистой поддерживаемой среде;
- отсутствуют открытые blocker/critical defects;
- документация достаточна для повторения третьим лицом;
- финальное демо укладывается в лимит времени.

### Sprint 17 — Final demo and joint presentation

**Sprint Goal:** представить завершённую лабораторию и доказать совместное владение архитектурой и реализацией.

**Candidate tasks:**
- выполнить финальный preflight и зафиксировать release;
- провести Demo 1–5 и показать ключевой negative path;
- представить архитектуру, ограничения и FAPI/ESAPI comparison;
- показать недельную историю Scrum и вклад обоих студентов;
- собрать итоговые замечания и закрыть Final DoD.

**Ожидаемый demo/artifact:** финальный live demo и совместная защита; презентация является опциональной возможностью получить до +10 баллов при общем лимите 80.

**Exit criteria:**
- обязательные сценарии показаны реальным исполнением без fake output;
- оба студента объясняют архитектуру и собственные технические решения;
- ограничения `swtpm` и границы модели безопасности названы явно;
- Scrum evidence доступно за все 17 недель;
- final release и документация согласованы.

## Правило еженедельной видимости

В конце каждого спринта команда сохраняет: Sprint Goal; planned/completed tasks; acceptance evidence; demo или проверяемый artifact; обновлённые risks; план следующего спринта; вклад Student A и Student B; reviewer decision. Незавершённая задача не помечается Done, а переносится с причиной и новым target week.
