# Sprint 01

## Sprint Goal

Define the project, establish scope and create the first defensible architecture and development plan.

## Planned Tasks

- **PM-001 — Определить scope проекта.** Зафиксировать цель, in scope, out of scope, ограничения и ожидаемый результат.
- **PM-002 — Создать initial backlog.** Разбить 17-недельную работу на Epics и проверяемые backlog items с dependencies, owner и reviewer.
- **ARCH-001 — Создать architecture v0.1.** Описать deployment, logical stack, demo flow и границу между реальным и эмулированным.
- **DOC-001 — Создать glossary v0.1.** Дать короткие и технически корректные определения основных TPM-терминов.
- **DOC-002 — Создать technical specification v0.1.** Зафиксировать компоненты, интерфейсы, сценарии, проверки, ограничения и критерии приёмки этапов.
- **PM-003 — Определить Definition of Done.** Установить проверяемые условия завершения Task, Sprint, MVP и Final Project.
- **PM-004 — Создать initial risk register.** Зафиксировать риски, probability, impact, mitigation и trigger.

## Owners and Reviewers

- **Student A:** owner для PM-001, DOC-001 и PM-003; reviewer для PM-002, ARCH-001, DOC-002 и PM-004.
- **Student B:** owner для PM-002, ARCH-001, DOC-002 и PM-004; reviewer для PM-001, DOC-001 и PM-003.
- Решения считаются принятыми только после взаимного review: автор не утверждает собственный результат единолично.

## Acceptance Criteria

- Sprint Goal приведен без смысловых изменений и согласован с границами спринта.
- Все семь planned task ID присутствуют ровно один раз в плане и имеют проверяемый результат.
- Определены scope, out of scope, последовательность дальнейшей работы, owners и независимые reviewers.
- ADR-001 фиксирует Apple Silicon/ARM64, ADR-002 — виртуализированный Linux, ADR-003 — `swtpm`; документы не противоречат друг другу.
- У каждого ADR есть Status, Context, Decision, Rationale, Alternatives considered, Consequences и Limitations.
- В документации отсутствуют заявления о наличии готовой лаборатории, установленного ПО или проведенных runtime-тестов.
- Все относительные ссылки разрешаются, а набор файлов соответствует документированной инициализации.

## Completed Tasks

- **PM-001 — artifact подготовлен:** scope, ограничения и критерии успеха зафиксированы в Project Charter.
- **PM-002 — artifact подготовлен:** создан backlog из 13 Epics с ownership, review, dependencies и target weeks.
- **ARCH-001 — artifact подготовлен:** создана architecture v0.1 и три ADR.
- **DOC-001 — artifact подготовлен:** создан beginner-friendly glossary v0.1.
- **DOC-002 — artifact подготовлен:** создана technical specification v0.1.
- **PM-003 — artifact подготовлен:** определён Definition of Done для Task, Sprint, MVP и Final Project.
- **PM-004 — artifact подготовлен:** создан risk register R-01–R-10.

Все artifacts прошли автоматическую проверку наличия и Markdown-ссылок. Формальный cross-review Student A/Student B и Sprint Review с преподавателем ещё не проведены, поэтому Sprint пока не закрыт по Definition of Done.

## Demo / Review Plan

Продолжительность: **3–5 минут**. Показать:

1. структуру репозитория;
2. цель проекта и границы Sprint 01;
3. architecture diagram и различие real/emulated/not modeled;
4. функциональные и нефункциональные требования;
5. 17-week roadmap и backlog;
6. план Sprint 02.

## Test / Validation Results

- **Наличие файлов — PASS:** все запланированные Sprint 01 documents и каталоги существуют.
- **Markdown-ссылки — PASS:** локальные ссылки разрешаются в существующие файлы.
- **Согласованность roadmap — PASS:** 17 недель, Stage 1–3, обязательный MVP и финальная FAPI/ESAPI-работа разделены.
- **Границы модели — PASS:** `swtpm` везде описан как software implementation без physical tamper resistance.
- **Границы Sprint 01 — PASS:** implementation source files, TPM commands, install scripts, VM images, runtime configuration и fake demo outputs отсутствуют.
- **Role balance — PASS на уровне плана:** Student A и Student B имеют технические owner/reviewer roles; фактический человеческий review ещё не проведён.

## Problems / Risks

- ARM64-совместимость отдельных TPM-инструментов и guest images еще не подтверждена практическим тестом.
- Виртуализация добавляет зависимость от выбранного hypervisor и способа подключения виртуального TPM.
- `swtpm` воспроизводит интерфейсы и часть поведения TPM, но не свойства аппаратной защиты.
- Недостаточно конкретные use cases могут привести к преждевременной реализации неподходящей лаборатории.
- Документационный статус решения не является доказательством работоспособности будущей конфигурации.

## Decisions

- [ADR-001: Apple Silicon/ARM64 как host baseline](../decisions/ADR-001-apple-silicon-arm64.md).
- [ADR-002: Виртуализированный Linux как guest-среда](../decisions/ADR-002-virtualized-linux.md).
- [ADR-003: `swtpm` как программный TPM для лаборатории](../decisions/ADR-003-swtpm.md).

## Next Sprint

Sprint 02 уточнит stakeholder needs, use cases, functional и non-functional requirements, threat assumptions, версии компонентов, интерфейсы host/guest/TPM и измеримые критерии валидации. Результатом должна стать reviewable specification и план минимального proof of concept; полная лаборатория в Sprint 02 не реализуется.

Фактический отчёт следующего спринта: [Sprint 02](sprint-02.md).
