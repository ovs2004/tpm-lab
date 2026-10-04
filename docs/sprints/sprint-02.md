# Sprint 02 — Simulator research and ARM64 technical spike

## Sprint goal

Проверить выбранный TPM software stack на Apple Silicon / ARM64,
исследовать варианты TPM simulator и получить первые реальные
TPM 2.0 evidence до развёртывания целевой VM.

Sprint 02 не заменяет Architecture v0.1 и ТЗ v0.1.

Он практически валидирует часть их технических предположений.

## Planned

* изучить software TPM implementations;
* обосновать simulator/backend;
* обосновать TPM libraries и CLI;
* проверить ARM64 compatibility;
* развернуть минимальный TPM stand;
* определить дальнейший путь к virtual TPM.

## Completed

### Research

Рассмотрены:

* swtpm;
* Microsoft TPM 2.0 Reference Implementation;
* direct simulator mode;
* QEMU virtual TPM architecture;
* TPM2-TSS;
* TCTI;
* tpm2-tools;
* дальнейшее использование FAPI/ESAPI.

Основным software TPM backend выбран `swtpm`.

`ms-tpm-20-ref` выбран как дополнительная implementation для
следующего сравнительного эксперимента. Фактический отчёт этого
эксперимента: [Sprint 03](sprint-03.md).

Документы:

- [Исследование simulator backends](../research/tpm-simulators-and-tooling.md)
- [Сравнение с TPM Handbook](../research/tpm-handbook-comparison.md)
- [ADR-004: TPM simulator strategy](../decisions/ADR-004-simulator-strategy.md)

### Environment

Развёрнут:

```text
Mac Apple Silicon
 ->
Docker
 ->
Ubuntu 24.04 ARM64
 ->
tpm2-tools
 ->
TPM2-TSS
 ->
TCTI swtpm
 ->
swtpm TPM 2.0
```

Подтверждено:

```text
uname -m -> aarch64
```

Лабораторные материалы:

- [technical spike](../labs/docker-arm64-swtpm.md)
- [полный runbook](../labs/docker-arm64-swtpm-runbook.md)

### TPM experiments

Выполнены:

* TPM 2.0 Discovery;
* GetRandom;
* PCR Read;
* PCR Extend;
* независимый SHA-256 assertion для PCR Extend;
* TPM-backed RSA signing;
* positive signature verification;
* negative tampered-message verification;
* basic Seal/Unseal;
* PCR-bound Seal/Unseal;
* negative PCR-policy test.

### Debugging finding

Во время ранней версии signing scenario получен:

```text
0x902
out of memory for object contexts
```

Через:

```bash
tpm2_getcap handles-transient
```

были обнаружены занятые transient slots.

После:

```bash
tpm2_flushcontext -t
```

и использования transient parent handle object scenario был успешно
выполнен.

### Automated runner

Ручные эксперименты объединены в автоматизированный runner.

Фактический результат успешного запуска:

```text
PASS checks: 10
FAIL checks: 0

TPM LAB ARM64 PROTOTYPE: PASS
```

Runner не симулирует PASS через shell output.

Positive assertions выполняются на реальных результатах TPM commands.

Negative assertions считаются PASS только после реального rejection
операции TPM.

## Evidence highlights

### PCR

Runner сравнил:

```text
Expected PCR
==
Actual TPM PCR
```

после:

```text
SHA256(oldPCR || measurement)
```

### Signing

```text
Original message
-> accepted

Tampered message
-> TPM 0x2DB
-> signature is not valid
```

### PCR-bound secret

Trusted state:

```text
PCR matches policy
-> Unseal
-> PCR_BOUND_SECRET
```

Tampered state:

```text
PCR Extend
-> policy changes
-> Unseal
-> TPM 0x99D
-> policy check failed
```

## Relation to project demos

| Sprint 02 spike      | Project demo           |
| -------------------- | ---------------------- |
| TPM capabilities     | Demo 1 Discovery       |
| PCR Read/Extend      | Demo 2                 |
| RSA Sign/Verify      | Demo 3                 |
| Basic Seal/Unseal    | preparation for Demo 4 |
| PCR-bound policy     | Demo 4 core scenario   |
| automated assertions | future common runner   |

Эти результаты не означают, что финальный MVP уже завершён.

Они подтверждают реализуемость сценариев в раннем direct-simulator
environment.

Далее сценарии должны быть перенесены в целевой VM/vTPM stand.

## Comparison with existing knowledge base

Изученный TPM Handbook ориентирован на:

* Ubuntu/x86_64;
* ms-tpm-20-ref;
* QEMU/KVM;
* swtpm vTPM;
* LUKS2;
* FAPI application.

TPM Lab сохраняет другой фокус:

* Apple Silicon / ARM64;
* direct simulator technical spike;
* независимые TPM mechanisms;
* explicit positive/negative tests;
* common automated runner;
* последующий перенос одних тестов между backends/transports.

Подробное сравнение:

`docs/research/tpm-handbook-comparison.md`.

## Current limitations

Пока не реализованы:

* UTM/QEMU ARM64 virtual TPM integration;
* `/dev/tpm0` / `/dev/tpmrm0` guest workflow;
* ms-tpm-20-ref comparative run (закрыто в Sprint 03);
* FAPI code;
* ESAPI code;
* Quote / remote attestation;
* LUKS2 integration.

## Next sprint

### Required scope

Развернуть `ms-tpm-20-ref` как второй TPM 2.0 software implementation.

Подключить TPM tooling через simulator-compatible transport/TCTI.

Повторить минимальный vendor-neutral набор:

1. TPM Discovery.
2. GetRandom.
3. PCR Read.
4. PCR Extend.

Сравнить:

* способ запуска;
* transport;
* initialization;
* capabilities;
* поведение базовых commands;
* пригодность существующего runner к повторному использованию.

### Deliverable

Короткая сравнительная таблица:

```text
                     swtpm      ms-tpm-20-ref
Discovery             PASS           ?
GetRandom              PASS           ?
PCR Read               PASS           ?
PCR Extend             PASS           ?
```

Знаки `?` являются будущей работой и не должны заранее заменяться PASS.

### Stretch goals

Только если основной scope завершён:

* Sign/Verify на ms-tpm-20-ref;
* Seal/Unseal;
* адаптация runner для selectable backend.

### Parallel design task

Подготовить простой проект следующего перехода:

```text
Mac Apple Silicon
 ->
UTM/QEMU ARM64 VM
 ->
Ubuntu
 ->
virtual TPM device
 ->
swtpm
```

Фактическое развёртывание этой VM не является обязательным deliverable
следующего спринта, если comparative simulator experiment ещё требует
отладки.

Фактический отчёт следующего спринта: [Sprint 03](sprint-03.md).

## Slide-ready summary

```text
SPRINT 02 · ARM64 TPM TECHNICAL SPIKE

Исследовано
swtpm · ms-tpm-20-ref · TCTI · QEMU vTPM

Выбрано
swtpm — основной TPM backend
tpm2-tools + TPM2-TSS — test stack

Развёрнуто
Mac Apple Silicon
→ Docker
→ Ubuntu 24.04 ARM64
→ TPM2-TSS/TCTI
→ swtpm

Проверено
Discovery · RNG · PCR · Signing · Seal/Unseal · PCR Policy

RESULT
10 PASS · 0 FAIL

Next
ms-tpm-20-ref:
Discovery · RNG · PCR Read/Extend
```

```text
REFERENCE HANDBOOK              TPM LAB

x86_64                          ARM64 / Apple Silicon
ms-tpm-20-ref                   swtpm direct TCTI
QEMU/KVM                        Docker spike → UTM/QEMU
LUKS2 use case                  independent TPM mechanisms
FAPI app                        tpm2-tools now → FAPI/ESAPI later

НАШ ДОПОЛНИТЕЛЬНЫЙ ВКЛАД
ARM64 quickstart
automated positive/negative tests
PCR independent assertion
transient-context troubleshooting
```
