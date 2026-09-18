# TPM Lab — техническая спецификация v0.1

**Версия:** 0.1  
**Статус:** проектный baseline, Sprint 01  
**Назначение версии:** определить проверяемый технический контракт до реализации

Эта спецификация описывает целевую систему. Наличие здесь command names и interfaces не означает, что они реализованы или испытаны.

## 1. Назначение

TPM Lab должен предоставлять воспроизводимые учебные demo TPM 2.0: discovery/capabilities, PCR Read/Extend, TPM-backed signing, PCR-bound sealing и сравнение FAPI/ESAPI. Система должна показывать не только успешные операции, но и проверяемые security-relevant отказы.

Целевой пользователь — студент или преподаватель, знакомый с Linux CLI, но начинающий изучать hardware security. Основной режим — live classroom demo и повторение лаборатории по документации.

## 2. System context

Система выполняется внутри Ubuntu ARM64 VM на Mac Apple Silicon. Пользователь запускает TPM Lab Runner в guest OS. Runner обращается к `tpm2-tools` или будущим FAPI/ESAPI applications. Эти clients используют TPM2-TSS и выбранный TCTI для обмена с `swtpm`.

Внешние actors и зависимости:

- **оператор:** выбирает demo, наблюдает evidence и объясняет результат;
- **macOS host:** предоставляет реальные CPU, memory, storage и virtualization runtime;
- **UTM/QEMU:** запускает ARM64 guest и соединяет её с virtual TPM endpoint;
- **package sources/build toolchain:** нужны для воспроизводимой установки;
- **course repository:** хранит source, tests, docs и Sprint artifacts.

Trust boundary проходит между guest components и `swtpm` process/state, но это программная граница, а не эквивалент физической границы TPM-чипа.

## 3. Host platform

- macOS на Apple Silicon/ARM64;
- UTM как пользовательский frontend и/или QEMU как virtualization runtime;
- ARM64-native virtualization предпочтительнее x86 emulation;
- версии macOS, UTM и QEMU должны фиксироваться в environment evidence;
- host-specific setup не должен заявляться рабочим до фактического smoke test.

## 4. Guest platform

- Ubuntu 24.04 ARM64;
- архитектура guest: `aarch64/arm64`;
- runtime, build dependencies и packages фиксируются в setup documentation;
- операции TPM выполняются внутри guest;
- VM state должен иметь документированный lifecycle: create, start, stop, reset lab state и recovery.

## 5. TPM implementation

Целевая TPM 2.0 implementation — `swtpm`. Это реально исполняемое software, которое обрабатывает TPM commands и хранит эмулированное TPM state. Оно подходит для изучения command semantics и software integration.

`swtpm` **не является физическим TPM** и не предоставляет доказанную physical tamper resistance, side-channel resistance или защиту от физического извлечения state. Результаты лаборатории нельзя переносить на физическую стойкость hardware TPM.

Configuration contract должен позднее определить:

- способ запуска/подключения `swtpm`;
- persistence path и permissions его state;
- TPM 2.0 mode;
- transport endpoint;
- процедуру initialization и clean reset;
- связь endpoint с TCTI внутри guest.

## 6. TPM software stack

Снизу вверх:

1. **swtpm** — эмулирует TPM 2.0 command processor и state;
2. **TCTI** — транспортный interface между TPM2-TSS clients и TPM endpoint;
3. **TPM2-TSS** — стандартные libraries и API;
4. **SAPI/ESAPI/FAPI** — разные уровни API (в проекте напрямую сравниваются FAPI и ESAPI);
5. **tpm2-tools** — CLI clients поверх TPM2-TSS;
6. **TPM Lab Runner** — orchestration, validation, cleanup и machine-readable status.

Конкретные package versions и выбранный TCTI будут зафиксированы после environment spike, а не предполагаются в v0.1.

## 7. Основные компоненты

### 7.1 TPM Lab Runner

Планируемая единая точка запуска:

```text
./tpm-lab status
./tpm-lab demo discovery
./tpm-lab demo pcr
./tpm-lab demo signing
./tpm-lab demo sealing
./tpm-lab demo all
```

Это conceptual CLI contract, не реализация Sprint 01. Runner должен валидировать preconditions, вызывать реальные tools/programs, проверять outputs и exit codes, управлять temporary artifacts и возвращать process status.

### 7.2 Demo modules

- Discovery: connectivity и capabilities;
- PCR: deterministic measurement, Read, Extend и independent expected-value check;
- Signing: key lifecycle, sign и positive/negative verify;
- Sealing: policy, valid Unseal и реальный policy rejection после PCR change;
- API comparison: FAPI и ESAPI implementation одной или эквивалентной операции.

### 7.3 API applications

Будущие FAPI и ESAPI programs должны быть малыми, reviewable и сфокусированными на сравнении abstraction levels. Они не создаются в Sprint 01.

### 7.4 Validation/tests

Tests должны отличать command success, expected security rejection, infrastructure error и validation mismatch. Текст `PASS` не является evidence без соответствующих фактов.

### 7.5 Documentation

Setup guide, requirements traceability, architecture, demo notes, troubleshooting, risks и Sprint records являются частью продукта.

## 8. Интерфейсы между компонентами

- **Operator → Runner:** CLI arguments; stdout для читаемого журнала, stderr для диагностики, process exit code для automation.
- **Runner → tpm2-tools:** subprocess invocation с явными arguments/environment и проверкой exit code.
- **Runner → FAPI/ESAPI apps:** стабильные CLI contracts; structured result либо однозначные artifacts и exit code.
- **Clients → TPM2-TSS:** соответствующие FAPI/ESAPI/SAPI library calls.
- **TPM2-TSS → TCTI:** TCTI ABI и configuration string/environment.
- **TCTI → swtpm:** поддерживаемый endpoint/transport, выбранный после environment validation.
- **Runner → filesystem:** отдельный workspace на demo, controlled paths, no implicit reuse, cleanup по documented policy.

Секретные учебные данные не должны случайно попадать в verbose logs. Все interfaces обязаны передавать реальные ошибки вверх без замены на synthetic success.

## 9. Demo scenarios

### Demo 1 — Discovery

Проверить соединение с TPM, прочитать capabilities/version properties и объяснить путь команды через stack.

### Demo 2 — PCR

Прочитать PCR, вычислить deterministic measurement, выполнить `Extend`, повторно прочитать PCR и независимо проверить новый digest.

### Demo 3 — TPM-backed signing

Создать TPM object/key, подписать deterministic message/digest, проверить подпись public key и подтвердить отказ для altered input.

### Demo 4 — PCR-bound sealing

Подготовить известный PCR state, создать policy и sealed object, выполнить успешный `Unseal`, изменить PCR реальной `Extend` operation и получить фактический policy rejection.

### Demo 5 — FAPI vs ESAPI

Выполнить одну или эквивалентную security-relevant операцию двумя API, сравнить количество явных шагов, resource/session management и error handling.

### Optional Demo 6 — Attestation/Quote

Не входит в MVP и берётся только после выполнения обязательных требований.

## 10. Принципы обработки ошибок

- Fail closed: неопределённый результат не считается успехом.
- Любой неожиданный non-zero exit или API return code прекращает текущий demo и даёт `FAIL`.
- Expected failure считается успешной проверкой только при выполнении подготовительного действия и получении ожидаемого класса ошибки; «любая ошибка» недостаточна.
- Infrastructure failures (нет TPM endpoint, неверный TCTI) отделяются от policy/crypto failures.
- Диагностика включает stage, operation, sanitized error и recovery hint.
- Cleanup errors журналируются; если они нарушают повторяемость, итог demo — `FAIL`.
- Runner не маскирует signal/timeout и не печатает `PASS` заранее.

## 11. Требования воспроизводимости

- фиксировать совместимые versions host/runtime/guest/packages;
- хранить setup и configuration как versioned text/scripts, когда они появятся;
- использовать deterministic inputs там, где случайность не является объектом теста;
- фиксировать hash algorithm, PCR index и policy inputs;
- не зависеть от необъявленного pre-existing TPM state;
- предоставить idempotent либо явно staged setup;
- описать clean reset/re-run и последствия сброса;
- проверять процедуру вторым студентом на clean state;
- отмечать host-specific deviations и timestamps evidence.

## 12. Требования к logging/output

Human-readable output должен показывать:

- demo и шаг;
- проверяемую precondition;
- вызываемую операцию без раскрытия чувствительных значений;
- фактический тип результата;
- expected vs actual для проверяемых digest/verification;
- итог и recovery guidance.

Machine-readable output должен иметь стабильную schema как минимум с полями `demo`, `status` (`PASS`/`FAIL`), `checks`, `failed_check` и `error_class`; окончательный формат выбирается до MVP. Process exit code `0` разрешён только для общего `PASS`. Raw command output может сохраняться как evidence, но не подменяет assertion.

Логи не должны утверждать, что `swtpm` обеспечивает hardware-grade security.

## 13. Test strategy

Уровни проверки:

1. **Documentation/link checks:** структура, ссылки, IDs и milestone consistency.
2. **Environment smoke tests:** guest architecture, packages, TCTI connectivity и TPM response.
3. **Component tests:** parsing, digest calculation, status aggregation и cleanup.
4. **Integration tests:** реальный путь runner → client → TPM2-TSS → TCTI → `swtpm`.
5. **Positive tests:** expected operations завершаются и данные совпадают.
6. **Negative tests:** altered message, changed PCR, missing endpoint и invalid object дают ожидаемый тип отказа.
7. **Reset/re-run tests:** повтор demo после documented reset.
8. **Classroom rehearsal:** timing, readability и recovery.

Mocks могут применяться в узких unit tests parser/orchestration, но не засчитываются как evidence выполнения TPM requirement.

## 14. Security limitations лаборатории

В лаборатории реальны Mac hardware, virtualization runtime, Linux guest и выполнение software. TPM 2.0 эмулируется `swtpm`; его state находится под контролем host software и storage.

Не моделируются:

- physical tamper resistance;
- side-channel resistance;
- resistance to chip probing, bus attacks или decapsulation;
- независимая сертифицированная hardware trust boundary;
- production-grade protection от администратора host.

Следовательно, лаборатория демонстрирует TPM semantics и integration, а не доказывает физическую безопасность или эквивалентность discrete/firmware TPM.

## 15. Acceptance criteria Stage 1 — недели 1–6

Stage 1 принят, если:

- Project Charter, requirements, architecture и technical specification согласованы и прошли peer review;
- 17-week roadmap, backlog, Definition of Done и risk register существуют и согласованы;
- ARM64 deployment design и ключевые ADR оформлены;
- Ubuntu ARM64 + `swtpm` + TPM2-TSS + `tpm2-tools` environment либо фактически развернут и smoke-tested к неделе 6, либо blocker честно зафиксирован с evidence и recovery plan;
- reproducibility procedure v0.1 описана;
- нет fake TPM output или заявлений о physical protection;
- weekly Sprint artifacts показывают вклад обоих студентов;
- instructor review может проследить requirements до будущих demos.

Stage 1 не требует готовых TPM demo.

## 16. Acceptance criteria MVP — недели 7–12

MVP принят, если:

- Demo 1–4 выполняются в целевой Ubuntu ARM64 environment;
- discovery/capabilities подтверждены реальным TPM response;
- PCR expected value проверяется независимо;
- signing имеет positive и altered-input negative verification;
- `Unseal` проходит при valid PCR policy и реально отклоняется после PCR change;
- единый runner запускает demo по отдельности и вместе;
- machine-readable `PASS`/`FAIL` основан на assertions и exit codes;
- environment имеет clean reset/re-run;
- automated integration checks и reproducibility walkthrough проходят;
- результаты не интерпретируются как physical tamper resistance.

FAPI/ESAPI comparison не является обязательным условием MVP недели 12.

## 17. Acceptance criteria финального проекта — недели 13–17

Финальный проект принят, если:

- выполнены и сохранены все MVP criteria;
- FAPI и ESAPI реализуют одну или эквивалентную операцию и технически сопоставлены;
- обязательные Demo 1–5 автоматизированы, стабильны и укладываются в classroom timing;
- positive, negative, recovery и repeatability tests проходят на зафиксированной environment;
- errors классифицируются и не маскируются;
- документация позволяет третьему лицу повторить лабораторию;
- optional Quote чётко отделён, если реализован;
- risks/limitations и distinction REAL/EMULATED/NOT MODELED отражены в demo;
- Student A и Student B оба демонстрируют технический вклад и объясняют stack;
- финальный результат основан на фактических запусках, а не fake output.
