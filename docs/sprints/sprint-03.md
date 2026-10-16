# Sprint 03 — ms-tpm-20-ref comparative spike

## Sprint goal

Развернуть Microsoft TPM 2.0 Reference Implementation как второй
software backend на Apple Silicon / ARM64 и повторить тот же
vendor-neutral набор проверок, который Sprint 02 уже прошёл на
`swtpm`.

Sprint 03 не заменяет целевую архитектуру UTM/QEMU + virtual TPM.
Он закрывает Stage B из [ADR-004](../decisions/ADR-004-simulator-strategy.md):
сравнение двух implementations через разные TCTI.

Исходный roadmap описывал Sprint 03 как VM environment design.
Фактически спринт выполнен по плану, зафиксированному в конце
Sprint 02: comparative simulator experiment. Design note перехода
к QEMU vTPM остаётся на следующий спринт.

## Planned

* развернуть `ms-tpm-20-ref` воспроизводимо;
* подключить `tpm2-tools` / TPM2-TSS через TCTI `mssim`;
* повторить Discovery, GetRandom, PCR Read, PCR Extend;
* сравнить старт, transport, initialization, capabilities и
  поведение базовых commands со `swtpm`;
* при готовности основного scope — Sign/Verify, Seal/Unseal и
  общий runner с selectable backend.

## Completed

### Second software TPM backend

Собран Docker-образ Ubuntu 24.04 ARM64 с `ms-tpm-20-ref`
commit `ee21db0a` (reference code TPM 2.0 v183). Бинарник
`tpm2-simulator` собирается в образе; пакета Ubuntu для него нет.

Подключение:

```text
TPM2TOOLS_TCTI=mssim:host=127.0.0.1,port=2321
```

В отличие от `swtpm --flags not-need-init,startup-clear`, reference
simulator после старта ещё не принимает TPM-команды. Перед первой
командой стенд отправляет на platform-порт `2322` сигналы `POWER_ON`
и `NV_ON`, затем `tpm2_startup -c`. Каждый запуск идёт с
`--manufacture` и чистым каталогом состояния.

Лабораторные материалы:

- [technical spike](../labs/docker-arm64-mssim.md)
- [полный runbook](../labs/docker-arm64-mssim-runbook.md)
- [два software TPM на ARM64](../research/two-simulators-arm64.md)

### Shared checks

Тот же `infra/docker-tpm/run-checks.sh` прогнан на втором backend.
Менялись только старт TPM и TCTI.

Фактический automated run `20261002-160428`:

```text
PASS checks: 10
FAIL checks: 0

TPM LAB ARM64 PROTOTYPE: PASS
```

Выполнены:

* ARM64 environment (`uname -m` → `aarch64`);
* TPM 2.0 Discovery;
* GetRandom;
* PCR Read/Extend и независимый SHA-256 assertion;
* TPM-backed RSA signing;
* negative tampered-message verification (`0x2DB`);
* basic Seal/Unseal;
* PCR-bound Seal/Unseal и negative PCR-policy test (`0x99D`).

### Debugging finding

Первая попытка старта отправляла на platform-порт ещё `SESSION_END`
(код 20). Simulator закрыл сокет без ответа. Для лабораторного запуска
этот сигнал не нужен; в рабочем `start-mssim.sh` его нет.

### Comparison table

Знаки `?` из плана Sprint 02 заменены фактическими результатами.

```text
                     swtpm      ms-tpm-20-ref
Discovery             PASS           PASS
GetRandom              PASS           PASS
PCR Read               PASS           PASS
PCR Extend             PASS           PASS
Sign/Verify            PASS           PASS
Seal/Unseal            PASS           PASS
PCR-bound policy       PASS           PASS
Runner            10/0 PASS      10/0 PASS
```

Одинаковые assertions. Различаются transport и identity, которую
сообщает simulator: `swtpm` представляется как IBM / `SW TPM`,
reference code в этом commit — `XYZ ` / `xCG` / `fTPM`, revision
`1.83`. PCR formula и коды `0x2DB` / `0x99D` совпали.

Подробная таблица: [ms-tpm-20-ref spike](../labs/docker-arm64-mssim.md).

### Runner reuse

Проверки вынесены в общий `infra/docker-tpm/run-checks.sh`.
`run-all.sh` и `run-all-mssim.sh` выбирают backend и TCTI, затем
вызывают одни assertions. Это не финальный lab runner и не MVP.

Дизайн дальнейшего runner: [runner-design](../labs/runner-design.md).

## Evidence highlights

### Discovery

```text
Family:         value: "2.0"
Manufacturer:   value: "XYZ "
PCR count:      raw: 0x18
Revision:       1.83
```

### PCR

```text
Expected PCR
==
Actual TPM PCR
```

после `SHA256(oldPCR || measurement)`, посчитанного вне TPM.

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
-> Unseal
-> TPM 0x99D
-> policy check failed
```

## Relation to project demos

| Sprint 03 spike      | Project demo           |
| -------------------- | ---------------------- |
| Discovery на втором backend | устойчивость Demo 1 |
| PCR Read/Extend      | устойчивость Demo 2    |
| RSA Sign/Verify      | устойчивость Demo 3    |
| PCR-bound policy     | устойчивость Demo 4    |
| общий `run-checks.sh` | будущий selectable runner |

Результаты не означают, что финальный MVP завершён. Они показывают,
что проверенные TPM 2.0 semantics не завязаны на один simulator.

## Current limitations

Пока не реализованы:

* UTM/QEMU ARM64 virtual TPM integration;
* `/dev/tpm0` / `/dev/tpmrm0` guest workflow;
* FAPI code;
* ESAPI code;
* Quote / remote attestation;
* LUKS2 integration.

`swtpm` остаётся основным backend для будущего virtual TPM path.

## Next sprint

Вернуться к целевой среде:

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

Обязательный deliverable: environment design / design note
(ARCH-005): конфигурация VM, способ подключения `swtpm`, reset/re-run,
открытые вопросы. Фактическое развёртывание VM — если design достаточен
для воспроизводимой установки.

Параллельно можно начать тонкий программный слой поверх уже проверенного
simulator socket; это не заменяет VM work.

Фактический отчёт следующего спринта: [Sprint 04](sprint-04.md).

## Slide-ready summary

```text
SPRINT 03 · ms-tpm-20-ref COMPARATIVE SPIKE

Развёрнуто
Mac Apple Silicon
→ Docker
→ Ubuntu 24.04 ARM64
→ TPM2-TSS / TCTI mssim
→ ms-tpm-20-ref tpm2-simulator

Проверено тем же runner, что Sprint 02
Discovery · RNG · PCR · Signing · Seal/Unseal · PCR Policy

RESULT
10 PASS · 0 FAIL

Отличие от swtpm
TCTI mssim · POWER_ON/NV_ON · vendor XYZ/fTPM
семантика PCR / 0x2DB / 0x99D совпала

Next
UTM/QEMU ARM64 VM + virtual TPM (swtpm)
```
