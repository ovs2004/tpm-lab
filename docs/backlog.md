# Product Backlog TPM Lab

Backlog покрывает все 17 недель. Зависимость `нет` означает отсутствие обязательной предшествующей backlog-задачи, а не отсутствие внешних условий. Owner выполняет задачу, reviewer независимо проверяет acceptance criteria и evidence. Разрешены только роли `Student A` и `Student B`.

## Sprint 02 — выполненные spike-задачи

Эти задачи закрывают ранний research/spike, а не целевую UTM/QEMU VM и не MVP Demo 1–4.

### SIM-001 — Исследовать TPM simulator backends
- **Status:** Done (Sprint 02)
- **Описание:** Сравнить `swtpm`, `ms-tpm-20-ref` и QEMU virtual TPM, выбрать основной backend и research stack.
- **Acceptance criteria:** Есть обоснование `swtpm` как основного backend и план сравнительного эксперимента с `ms-tpm-20-ref`.
- **Артефакт:** `docs/research/tpm-simulators-and-tooling.md`, `docs/decisions/ADR-004-simulator-strategy.md`.

### SPIKE-001 — ARM64 Docker + swtpm technical spike
- **Status:** Done (Sprint 02)
- **Описание:** Развернуть Ubuntu 24.04 ARM64 container и software TPM 2.0 через Docker Desktop на Apple Silicon.
- **Acceptance criteria:** `uname -m` возвращает `aarch64`; `swtpm` отвечает как TPM 2.0.
- **Артефакт:** `infra/docker-tpm/`, `docs/labs/docker-arm64-swtpm.md`.

### SPIKE-002 — Direct swtpm TCTI test
- **Status:** Done (Sprint 02)
- **Описание:** Подключить `tpm2-tools` к `swtpm` через `TPM2TOOLS_TCTI=swtpm:host=127.0.0.1,port=2321`.
- **Acceptance criteria:** Discovery, GetRandom и PCR Read/Extend выполняются реальными TPM commands.

### SPIKE-003 — Basic automated runner
- **Status:** Done (Sprint 02)
- **Описание:** Собрать positive/negative TPM checks в воспроизводимый runner с evidence.
- **Acceptance criteria:** `PASS` только после реальных assertions; negative tests требуют фактический TPM rejection; exit code 0 только если FAIL=0.
- **Артефакт:** `infra/docker-tpm/run-all.sh`.

### SPIKE-004 — Demo 1–4 feasibility spike
- **Status:** Done (Sprint 02)
- **Описание:** Проверить реализуемость Discovery, PCR Extend, TPM-backed signing и PCR-bound Seal/Unseal в direct-simulator mode.
- **Acceptance criteria:** Automated run даёт 10 PASS / 0 FAIL на реальных TPM operations. Это не закрывает MVP Demo 1–4 в целевой VM.

## Sprint 03 — следующий небольшой backlog

SIM-002, SIM-003 и SIM-004 закрыты фактическим прогоном. ARCH-005 остаётся Planned.

### SIM-002 — Bootstrap ms-tpm-20-ref
- **Status:** Done
- **Описание:** Развернуть Microsoft TPM 2.0 Reference Implementation как второй software backend.
- **Acceptance criteria:** Simulator запускается воспроизводимо; способ старта и initialization задокументированы.
- **Артефакт:** `infra/docker-tpm/Dockerfile.mssim`, `infra/docker-tpm/start-mssim.sh`, `docs/labs/docker-arm64-mssim-runbook.md`.
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### SIM-003 — Подключить mssim / basic transport
- **Status:** Done
- **Описание:** Соединить `tpm2-tools` / TPM2-TSS с `ms-tpm-20-ref` через simulator-compatible TCTI (`mssim` или эквивалент).
- **Acceptance criteria:** Хотя бы одна TPM command проходит; transport и отличия от TCTI `swtpm` описаны.
- **Зависимость:** SIM-002
- **Артефакт:** `docs/labs/docker-arm64-mssim.md`.
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### SIM-004 — Сравнить Discovery / GetRandom / PCR Read / PCR Extend
- **Status:** Done
- **Описание:** Повторить минимальный vendor-neutral набор на `ms-tpm-20-ref` и сравнить со `swtpm`.
- **Acceptance criteria:** Таблица сравнения заполнена фактическими результатами; знаки `?` не заменяются PASS заранее.
- **Зависимость:** SIM-003
- **Артефакт:** таблица в `docs/labs/docker-arm64-mssim.md`. Полный runner дополнительно дал 10 PASS / 0 FAIL.
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### ARCH-005 — QEMU ARM64 vTPM design note
- **Status:** Planned
- **Описание:** Подготовить короткий design note перехода `Mac Apple Silicon -> UTM/QEMU ARM64 VM -> Ubuntu -> virtual TPM device -> swtpm`.
- **Acceptance criteria:** Описаны предполагаемые компоненты, открытые вопросы и критерии будущей validation. Фактическое развёртывание VM не обязательно, если comparative simulator experiment ещё требует отладки.
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

## EPIC-01 Project Management

### PM-001 — Определить scope проекта
- **Epic:** EPIC-01 Project Management
- **Описание:** Зафиксировать цель, in scope, out of scope, ограничения виртуальной лаборатории и критерии успеха.
- **Acceptance criteria:** Scope охватывает Demo 1–5; Demo 6 отмечено optional; явно сказано, что `swtpm` не даёт physical tamper resistance.
- **Target week:** 1
- **Зависимость:** нет
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### PM-002 — Создать initial backlog
- **Epic:** EPIC-01 Project Management
- **Описание:** Декомпозировать работу на эпики и проверяемые задачи для 17 спринтов.
- **Acceptance criteria:** Все недели и обязательные результаты покрыты; у каждой задачи есть owner, reviewer, dependency и acceptance criteria.
- **Target week:** 1
- **Зависимость:** PM-001
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### PM-003 — Определить Definition of Done
- **Epic:** EPIC-01 Project Management
- **Описание:** Установить DoD для task, sprint, MVP и final project.
- **Acceptance criteria:** DoD требует review вторым студентом, реального evidence и запрещает fake PASS.
- **Target week:** 1
- **Зависимость:** PM-001
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### PM-004 — Создать initial risk register
- **Epic:** EPIC-01 Project Management
- **Описание:** Описать технические, организационные и demo-риски с mitigation и trigger.
- **Acceptance criteria:** Включены ARM64, vTPM integration, state, PCR determinism, API complexity, contribution balance и live demo.
- **Target week:** 1
- **Зависимость:** PM-001
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### PM-005 — Провести Stage 1 review
- **Epic:** EPIC-01 Project Management
- **Описание:** Сверить Scrum evidence, архитектуру, ТЗ и готовность backlog MVP.
- **Acceptance criteria:** Для недель 1–6 есть review record; открытые отклонения имеют owner и новый target.
- **Target week:** 6
- **Зависимость:** ARCH-004, INFRA-005
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### PM-006 — Закрыть Final DoD
- **Epic:** EPIC-01 Project Management
- **Описание:** Провести итоговую проверку качества и совместного владения результатом.
- **Acceptance criteria:** Final DoD оценён по evidence; blocker/critical defects отсутствуют или явно не позволяют релиз.
- **Target week:** 17
- **Зависимость:** DEMO-004, TEST-005
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

## EPIC-02 Architecture

### ARCH-001 — Создать architecture v0.1
- **Epic:** EPIC-02 Architecture
- **Описание:** Описать deployment и software stack от macOS/UTM до TCTI/`swtpm`.
- **Acceptance criteria:** Есть схемы компонентов и интерфейсов; REAL, EMULATED и NOT MODELED разделены.
- **Target week:** 1
- **Зависимость:** PM-001
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### ARCH-002 — Спроектировать VM environment
- **Epic:** EPIC-02 Architecture
- **Описание:** Определить ресурсы VM, networking, storage, TPM state и lifecycle.
- **Acceptance criteria:** Конфигурация ARM64 однозначна; reset, persistence и recovery описаны.
- **Target week:** 3
- **Зависимость:** ARCH-001, DOC-002
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### ARCH-003 — Описать интерфейсы TPM stack
- **Epic:** EPIC-02 Architecture
- **Описание:** Зафиксировать границы runner, tools/API, TPM2-TSS, TCTI и `swtpm`.
- **Acceptance criteria:** Для каждого интерфейса указаны входы, выходы и основные error paths.
- **Target week:** 3
- **Зависимость:** ARCH-001
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### ARCH-004 — Стабилизировать архитектуру Этапа 1
- **Epic:** EPIC-02 Architecture
- **Описание:** Согласовать architecture baseline с фактически развёрнутой средой.
- **Acceptance criteria:** Неподтверждённые assumptions устранены или помечены; изменения после review внесены.
- **Target week:** 6
- **Зависимость:** ARCH-002, ARCH-003, INFRA-004
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

## EPIC-03 Environment

### INFRA-001 — Подготовить ARM64 VM deployment plan
- **Epic:** EPIC-03 Environment
- **Описание:** Описать установку Ubuntu 24.04 ARM64 в UTM/QEMU на Apple Silicon.
- **Acceptance criteria:** Указаны image, параметры VM, последовательность установки и verification commands.
- **Target week:** 3
- **Зависимость:** ARCH-002
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### INFRA-002 — Развернуть Ubuntu ARM64 VM
- **Epic:** EPIC-03 Environment
- **Описание:** Создать guest OS и проверить архитектуру, сеть и базовую стабильность.
- **Acceptance criteria:** VM загружается; ARM64 и версия ОС подтверждены реальным выводом; параметры зафиксированы.
- **Target week:** 4
- **Зависимость:** INFRA-001
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### INFRA-003 — Подключить swtpm
- **Epic:** EPIC-03 Environment
- **Описание:** Настроить software TPM process/interface и изолированное хранилище состояния.
- **Acceptance criteria:** Lifecycle запуска/остановки и путь state воспроизводимы; граница эмуляции документирована.
- **Target week:** 5
- **Зависимость:** INFRA-002
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### INFRA-004 — Установить TPM2-TSS и tpm2-tools
- **Epic:** EPIC-03 Environment
- **Описание:** Установить ARM64-совместимые packages и настроить TCTI.
- **Acceptance criteria:** Версии зафиксированы; tools реально соединяются с `swtpm`; ошибки подключения диагностируются.
- **Target week:** 5
- **Зависимость:** INFRA-003
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### INFRA-005 — Проверить clean reset и повторную установку
- **Epic:** EPIC-03 Environment
- **Описание:** Валидировать reset/re-run и воспроизводимость setup другим участником.
- **Acceptance criteria:** Повторная процедура выполнена по инструкции; остаточное TPM state не влияет на контрольный запуск.
- **Target week:** 6
- **Зависимость:** INFRA-004
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

## EPIC-04 TPM Discovery

### TPM-001 — Реализовать TPM discovery
- **Epic:** EPIC-04 TPM Discovery
- **Описание:** Получить доступность TPM, capabilities, version и properties через `tpm2-tools`.
- **Acceptance criteria:** Данные получены фактическими командами и проверены по exit code/структуре результата.
- **Target week:** 7
- **Зависимость:** INFRA-005
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### TPM-002 — Обработать недоступность TPM/TCTI
- **Epic:** EPIC-04 TPM Discovery
- **Описание:** Добавить диагностируемый negative path для ошибки соединения.
- **Acceptance criteria:** При недоступном endpoint процесс завершается non-zero и не печатает PASS.
- **Target week:** 7
- **Зависимость:** TPM-001
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### TPM-003 — Автоматизировать Demo 1
- **Epic:** EPIC-04 TPM Discovery
- **Описание:** Собрать discovery checks в повторяемый сценарий.
- **Acceptance criteria:** Сценарий проверяет connectivity и properties и выдаёт machine-readable итог на основе реальных проверок.
- **Target week:** 7
- **Зависимость:** TPM-001, TPM-002
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

## EPIC-05 PCR

### PCR-001 — Реализовать PCR Read
- **Epic:** EPIC-05 PCR
- **Описание:** Читать выбранный PCR bank/index и сохранять нормализованное исходное значение.
- **Acceptance criteria:** Bank/index заданы явно; digest получен от TPM и валидирован по формату.
- **Target week:** 8
- **Зависимость:** TPM-003
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### PCR-002 — Реализовать deterministic PCR Extend
- **Epic:** EPIC-05 PCR
- **Описание:** Выполнить Extend с известным measurement и независимо вычислить ожидаемый digest.
- **Acceptance criteria:** PCR после Extend совпадает с вычисленным значением и отличается от исходного.
- **Target week:** 8
- **Зависимость:** PCR-001
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### PCR-003 — Автоматизировать Demo 2
- **Epic:** EPIC-05 PCR
- **Описание:** Объединить read-before, measurement, extend и read-after.
- **Acceptance criteria:** Demo показывает реальные before/after и падает при несовпадении ожидаемого digest.
- **Target week:** 8
- **Зависимость:** PCR-002
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### PCR-004 — Добавить PCR reset/rerun strategy
- **Epic:** EPIC-05 PCR
- **Описание:** Исключить недетерминированность повторных classroom runs.
- **Acceptance criteria:** Начальное состояние восстанавливается документированной процедурой; два последовательных clean runs сопоставимы.
- **Target week:** 8
- **Зависимость:** PCR-003, INFRA-005
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

## EPIC-06 TPM Keys

### KEY-001 — Спроектировать TPM key profile
- **Epic:** EPIC-06 TPM Keys
- **Описание:** Выбрать hierarchy, algorithm, attributes и lifecycle TPM-backed key.
- **Acceptance criteria:** Параметры обоснованы; private material не трактуется как plaintext private-key file.
- **Target week:** 9
- **Зависимость:** TPM-003
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### KEY-002 — Реализовать создание и загрузку ключа
- **Epic:** EPIC-06 TPM Keys
- **Описание:** Создать primary/object key и управлять object blobs/contexts.
- **Acceptance criteria:** Объект создаётся, загружается и имеет ожидаемые public attributes.
- **Target week:** 9
- **Зависимость:** KEY-001
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### KEY-003 — Реализовать cleanup key lifecycle
- **Epic:** EPIC-06 TPM Keys
- **Описание:** Добавить повторяемое удаление временных contexts и artifacts.
- **Acceptance criteria:** Повторный clean run не зависит от leftovers; ошибки cleanup видимы.
- **Target week:** 9
- **Зависимость:** KEY-002
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

## EPIC-07 Signing

### SIGN-001 — Реализовать подпись TPM-backed key
- **Epic:** EPIC-07 Signing
- **Описание:** Подписать digest детерминированного сообщения ранее созданным ключом.
- **Acceptance criteria:** Signature создаётся TPM operation; command failure корректно распространяется.
- **Target week:** 10
- **Зависимость:** KEY-003
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### SIGN-002 — Реализовать verification и negative test
- **Epic:** EPIC-07 Signing
- **Описание:** Проверить подпись public key и отказ для изменённых данных.
- **Acceptance criteria:** Валидная пара проходит; tampered message или signature гарантированно не проходит.
- **Target week:** 10
- **Зависимость:** SIGN-001
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### SIGN-003 — Автоматизировать Demo 3
- **Epic:** EPIC-07 Signing
- **Описание:** Объединить key usage, signing, verification и cleanup.
- **Acceptance criteria:** Demo выдаёт итог только из результатов операций и объясняет модель хранения private material.
- **Target week:** 10
- **Зависимость:** SIGN-002
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

## EPIC-08 Sealing and Policy

### SEAL-001 — Построить PCR policy
- **Epic:** EPIC-08 Sealing and Policy
- **Описание:** Зафиксировать известное PCR state и получить policy digest.
- **Acceptance criteria:** Policy привязана к явно указанным bank/index/value; шаги воспроизводимы.
- **Target week:** 11
- **Зависимость:** PCR-004
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### SEAL-002 — Реализовать Seal и успешный Unseal
- **Epic:** EPIC-08 Sealing and Policy
- **Описание:** Запечатать тестовый secret под PCR policy и восстановить его в допустимом состоянии.
- **Acceptance criteria:** Unsealed bytes равны исходному secret; значение не выводится без необходимости в logs.
- **Target week:** 11
- **Зависимость:** SEAL-001
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### SEAL-003 — Реализовать реальный policy failure
- **Epic:** EPIC-08 Sealing and Policy
- **Описание:** Изменить PCR через Extend и повторить Unseal.
- **Acceptance criteria:** Отказ возвращён TPM/TSS policy validation; custom wrapper не имитирует ошибку.
- **Target week:** 11
- **Зависимость:** SEAL-002
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### SEAL-004 — Автоматизировать Demo 4
- **Epic:** EPIC-08 Sealing and Policy
- **Описание:** Объединить success path, PCR mutation, expected failure и reset.
- **Acceptance criteria:** Demo считает ожидаемый отказ успешной проверкой только при подтверждённой policy error.
- **Target week:** 11
- **Зависимость:** SEAL-003
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

## EPIC-09 FAPI

### FAPI-001 — Настроить FAPI provisioning
- **Epic:** EPIC-09 FAPI
- **Описание:** Подготовить FAPI config, profiles и keystore для лабораторной среды.
- **Acceptance criteria:** Provisioning повторяем; paths и связь с TCTI документированы; clean reset проверен.
- **Target week:** 13
- **Зависимость:** INFRA-005, TEST-003
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### FAPI-002 — Реализовать FAPI operation
- **Epic:** EPIC-09 FAPI
- **Описание:** Выполнить выбранную security-relevant операцию через FAPI.
- **Acceptance criteria:** Результат автоматически проверяется; error path и cleanup реализованы.
- **Target week:** 13
- **Зависимость:** FAPI-001
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### FAPI-003 — Описать FAPI abstractions
- **Epic:** EPIC-09 FAPI
- **Описание:** Связать FAPI workflow с нижележащими concepts и состоянием.
- **Acceptance criteria:** Явно описано, что FAPI скрывает, чем управляет приложение и какие ограничения остаются.
- **Target week:** 13
- **Зависимость:** FAPI-002
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

## EPIC-10 ESAPI

### ESAPI-001 — Спроектировать ESAPI resource lifecycle
- **Epic:** EPIC-10 ESAPI
- **Описание:** Определить TCTI/ESYS initialization, handles, sessions и cleanup.
- **Acceptance criteria:** Все приобретаемые resources имеют owner и гарантированный release path.
- **Target week:** 14
- **Зависимость:** FAPI-002
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### ESAPI-002 — Реализовать эквивалентную ESAPI operation
- **Epic:** EPIC-10 ESAPI
- **Описание:** Выполнить через ESAPI ту же или явно эквивалентную FAPI operation.
- **Acceptance criteria:** Результат проверяется тем же oracle; ошибки содержат TSS diagnostic context.
- **Target week:** 14
- **Зависимость:** ESAPI-001
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### ESAPI-003 — Проверить error paths и cleanup
- **Epic:** EPIC-10 ESAPI
- **Описание:** Протестировать частичные отказы и освобождение ESYS/TCTI resources.
- **Acceptance criteria:** Нет известных resource leaks на проверенных путях; повторный запуск не зависит от старого context.
- **Target week:** 14
- **Зависимость:** ESAPI-002
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

## EPIC-11 Testing

### TEST-001 — Определить test strategy
- **Epic:** EPIC-11 Testing
- **Описание:** Разделить unit-like checks, integration, negative, end-to-end и reproducibility tests.
- **Acceptance criteria:** Каждый FR связан минимум с одним verification method; запрещены hard-coded PASS.
- **Target week:** 2
- **Зависимость:** DOC-003
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### TEST-002 — Добавить общие проверки exit status
- **Epic:** EPIC-11 Testing
- **Описание:** Унифицировать оценку реального результата команд и API.
- **Acceptance criteria:** Non-zero не маскируется; expected failure проверяет конкретный класс ошибки.
- **Target week:** 10
- **Зависимость:** TPM-003, PCR-003
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### TEST-003 — Выполнить integrated MVP tests
- **Epic:** EPIC-11 Testing
- **Описание:** Проверить Demo 1–4, preflight, cleanup и повторный запуск.
- **Acceptance criteria:** Есть фактический отчёт по каждому сценарию; обязательные negative paths выполнены.
- **Target week:** 12
- **Зависимость:** SIGN-003, SEAL-004
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### TEST-004 — Сравнить FAPI и ESAPI тестами
- **Epic:** EPIC-11 Testing
- **Описание:** Применить общий input/oracle к обеим реализациям.
- **Acceptance criteria:** Positive и negative результаты сопоставимы; различия объяснены, а не скрыты.
- **Target week:** 15
- **Зависимость:** FAPI-002, ESAPI-003
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### TEST-005 — Выполнить clean-room regression
- **Epic:** EPIC-11 Testing
- **Описание:** Проверить release candidate из чистого состояния по опубликованной инструкции.
- **Acceptance criteria:** Обязательные демо проходят либо дефект зарегистрирован; timing и evidence сохранены.
- **Target week:** 16
- **Зависимость:** TEST-004, DOC-005
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

## EPIC-12 Documentation

### DOC-001 — Создать glossary v0.1
- **Epic:** EPIC-12 Documentation
- **Описание:** Дать краткие технически корректные определения TPM/TSS/API concepts.
- **Acceptance criteria:** Термины понятны начинающим; аппаратные свойства не приписаны `swtpm`.
- **Target week:** 1
- **Зависимость:** PM-001
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### DOC-002 — Создать technical specification skeleton/content
- **Epic:** EPIC-12 Documentation
- **Описание:** Подготовить структуру ТЗ и первичное содержание компонентов, интерфейсов и критериев.
- **Acceptance criteria:** Разделы system context, interfaces, demos, errors, tests, limitations и milestones заполнены на уровне v0.1.
- **Target week:** 1
- **Зависимость:** ARCH-001
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### DOC-003 — Уточнить requirements и ТЗ v0.1
- **Epic:** EPIC-12 Documentation
- **Описание:** Описать FR/NFR с verification method и target milestone.
- **Acceptance criteria:** FR-01–FR-14 и NFR-01–NFR-10 проверяемы и имеют traceability.
- **Target week:** 2
- **Зависимость:** DOC-002, PM-002
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### DOC-004 — Подготовить MVP runbook
- **Epic:** EPIC-12 Documentation
- **Описание:** Описать setup, preflight, запуск Demo 1–4, reset и troubleshooting.
- **Acceptance criteria:** Второй студент выполняет runbook без устных скрытых шагов; реальные outputs отделены от примеров.
- **Target week:** 12
- **Зависимость:** TEST-003
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### DOC-005 — Завершить final documentation
- **Epic:** EPIC-12 Documentation
- **Описание:** Синхронизировать architecture, API comparison, tests, risks и demo guide с release candidate.
- **Acceptance criteria:** Ссылки и команды актуальны; limitations и known issues видимы; документация прошла reciprocal review.
- **Target week:** 16
- **Зависимость:** TEST-004, DEMO-002
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

## EPIC-13 Final Demo

### DEMO-001 — Интегрировать единый MVP runner
- **Epic:** EPIC-13 Final Demo
- **Описание:** Предоставить единый entry point для отдельных Demo 1–4 и полного запуска.
- **Acceptance criteria:** Runner выполняет preflight, возвращает итоговый exit code и не создаёт fake success output.
- **Target week:** 12
- **Зависимость:** TPM-003, PCR-003, SIGN-003, SEAL-004
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### DEMO-002 — Подготовить Demo 5 FAPI vs ESAPI
- **Epic:** EPIC-13 Final Demo
- **Описание:** Автоматизировать сравнение одинаковой или эквивалентной операции двух API.
- **Acceptance criteria:** Видны общий input/result, различия abstraction и реальные результаты проверок.
- **Target week:** 15
- **Зависимость:** TEST-004
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

### DEMO-003 — Провести final rehearsal
- **Epic:** EPIC-13 Final Demo
- **Описание:** Отрепетировать полный показ, распределение объяснений и fallback.
- **Acceptance criteria:** Timing зафиксирован; оба студента запускают технические части и отвечают по архитектуре; blocker defects зарегистрированы.
- **Target week:** 16
- **Зависимость:** TEST-005, DOC-005
- **Suggested owner role:** Student A
- **Reviewer role:** Student B

### DEMO-004 — Провести финальный demo и совместную презентацию
- **Epic:** EPIC-13 Final Demo
- **Описание:** Показать Demo 1–5, реальные negative paths, ограничения `swtpm` и Scrum evidence.
- **Acceptance criteria:** Обязательные сценарии показаны фактическим выполнением; вклад обоих участников видим; optional presentation не выдаётся за обязательную часть MVP.
- **Target week:** 17
- **Зависимость:** DEMO-003
- **Suggested owner role:** Student B
- **Reviewer role:** Student A

## Баланс ролей

Student A владеет техническими задачами по VM deployment, TPM discovery, PCR Extend, key profile/lifecycle, signature verification, PCR policy/failure, FAPI operation, ESAPI lifecycle, test automation и runner. Student B владеет техническими задачами по `swtpm`, key creation, PCR read/demo, signing, Seal/Unseal, FAPI provisioning, ESAPI operation, integrated/regression tests и Demo 5. Review во всех задачах взаимный: owner и reviewer всегда разные.
