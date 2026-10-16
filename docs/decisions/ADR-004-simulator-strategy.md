# ADR-004: TPM simulator strategy

* Status: Accepted
* Sprint: 02

## Context

TPM Lab разрабатывается на Mac с Apple Silicon.

Целевая архитектура проекта предполагает Ubuntu ARM64 VM с virtual TPM,
но ранняя настройка полноценной UTM/QEMU integration добавляет
инфраструктурную сложность до того, как проверены сами TPM software
interfaces и security scenarios.

Кроме того, проекту полезно отделить:

1. semantics TPM 2.0;
2. transport к TPM;
3. virtualization integration.

## Decision

Основным software TPM backend проекта выбран `swtpm`.

Работа проводится поэтапно.

### Stage A — direct simulator

```text
tpm2-tools
 ->
TPM2-TSS
 ->
TCTI swtpm
 ->
swtpm
```

Этот режим используется для быстрых ARM64 experiments и automated
tests.

### Stage B — second implementation comparison

`ms-tpm-20-ref` будет использован как дополнительная reference
implementation.

Минимальный сравнительный набор:

* Discovery;
* GetRandom;
* PCR Read;
* PCR Extend.

### Stage C — virtual TPM

```text
Ubuntu ARM64 guest
 ->
TPM device
 ->
QEMU/UTM
 ->
swtpm backend
```

Те же сценарии будут повторены через TPM device внутри VM.

## Rationale

Пошаговый подход:

* уменьшает инфраструктурный риск;
* позволяет сначала проверить TPM semantics;
* даёт быстрый feedback;
* обеспечивает native ARM64 workflow;
* позволяет повторно использовать одни тесты на разных transports;
* делает проблемы VM integration независимыми от проблем TPM logic.

## Alternatives considered

- **Сразу собирать целевой UTM/QEMU ARM64 vTPM стенд:** ближе к Architecture v0.1, но смешивает риски виртуализации с проверкой TPM semantics.
- **Сразу использовать только `ms-tpm-20-ref`:** полезен как независимая reference implementation, но хуже стыкуется с будущим QEMU virtual TPM backend.
- **Mock/stub TPM API:** быстрее для unit tests, но не даёт реальных TPM return codes и PCR semantics.

## Consequences

Преимущества:

* reproducible experiments;
* automated positive/negative tests;
* один основной backend для direct и virtual modes;
* раннее обнаружение проблем object/session management.

Ограничения:

* Docker direct-TCTI стенд не моделирует аппаратный trust boundary;
* direct socket access не эквивалентен TPM device в guest OS;
* physical tamper resistance не моделируется;
* QEMU/UTM integration всё ещё требует отдельной практической проверки.

Stage B после принятия этого ADR выполнен: тот же automated набор
прогнан на `ms-tpm-20-ref` через TCTI `mssim`. Результат и отличия
транспорта записаны в [ARM64 Docker + ms-tpm-20-ref](../labs/docker-arm64-mssim.md).
Решение оставить `swtpm` основным backend не меняется.

Stage C начат в Sprint 04: Ubuntu ARM64 в QEMU видит этот `swtpm`
как `tpm-tis-device` и `/dev/tpmrm0`. Запись: [ARCH-005](../labs/qemu-arm64-vtpm.md).
