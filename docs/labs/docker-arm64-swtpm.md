# ARM64 Docker + swtpm technical spike

## Статус

Выполнено в Sprint 02.

Это ранний исследовательский стенд, а не финальная архитектура проекта.

Пошаговые команды: [полный runbook](docker-arm64-swtpm-runbook.md).

## Цель

До развёртывания целевой UTM/QEMU ARM64 VM проверить:

* совместимость TPM software stack с ARM64;
* запуск software TPM 2.0;
* взаимодействие `tpm2-tools -> TPM2-TSS -> TCTI -> swtpm`;
* основные запланированные TPM scenarios;
* возможность автоматизированных positive и negative tests;
* возможность сохранять raw evidence.

## Архитектура

```text
Mac Apple Silicon
        |
        v
Docker Desktop
        |
        v
Ubuntu 24.04 ARM64
        |
        v
tpm2-tools
        |
        v
TPM2-TSS
        |
        v
TCTI swtpm
        |
        v
swtpm TPM 2.0
```

## Подтверждённое окружение

Host:

* Apple Silicon Mac.

Container:

* Ubuntu 24.04;
* architecture: `aarch64`.

TPM stack:

* swtpm;
* swtpm-tools;
* tpm2-tools;
* TPM2-TSS;
* TCTI swtpm (`libtss2-tcti-swtpm0t64`).

Вспомогательные инструменты:

* Python 3;
* OpenSSL;
* jq;
* xxd.

## Подключение TPM

Software TPM использует:

* TPM command port: `2321`;
* control port: `2322`.

`TPM2TOOLS_TCTI`:

```bash
swtpm:host=127.0.0.1,port=2321
```

## Выполненные проверки

| Проверка                          | Результат |
| --------------------------------- | --------- |
| ARM64 environment                 | PASS      |
| TPM 2.0 discovery                 | PASS      |
| TPM GetRandom                     | PASS      |
| PCR Read/Extend                   | PASS      |
| Independent PCR SHA-256 assertion | PASS      |
| TPM-backed RSA signing            | PASS      |
| Tampered message rejection        | PASS      |
| Basic Seal/Unseal                 | PASS      |
| PCR-bound trusted Unseal          | PASS      |
| Tampered PCR policy rejection     | PASS      |

Финальный automated run:

```text
PASS checks: 10
FAIL checks: 0

TPM LAB ARM64 PROTOTYPE: PASS
```

## Основные результаты

### TPM Discovery

TPM отвечает как TPM 2.0.

В software implementation наблюдались:

```text
TPM family: 2.0
Manufacturer: IBM
Vendor string: SW TPM
PCR count: 0x18 = 24
```

Это не означает использование физического IBM TPM chip.

### PCR Read / Extend

Лабораторный PCR 16 был прочитан, затем изменён через TPM PCR Extend.

Результат независимо проверялся:

```text
expected = SHA256(oldPCR || measurement)
```

В автоматизированном запуске `expected` совпал с фактическим новым
значением PCR.

### TPM-backed signing

Был создан RSA signing object.

Положительный сценарий:

```text
original message + signature -> valid
```

Negative scenario:

```text
modified message + original signature
-> TPM rejects verification
```

Реально наблюдавшийся return code:

```text
0x2DB
the signature is not valid
```

### Basic Seal / Unseal

Test secret:

```text
SUPER_SECRET_TPM_LAB
```

был помещён в TPM object и успешно получен через Unseal.

### PCR-bound Seal / Unseal

Test secret:

```text
PCR_BOUND_SECRET
```

был связан с PCR policy.

При trusted state Unseal выполнялся успешно.

После PCR Extend состояние изменилось, policy session больше не
совпадала с authorization policy объекта.

Реально наблюдавшийся TPM error:

```text
0x99D
a policy check failed
```

### TPM object context limitation

Во время ранней ручной версии signing scenario был получен:

```text
0x902
out of memory for object contexts
```

Проверка:

```bash
tpm2_getcap handles-transient
```

показала несколько загруженных transient objects.

После явного:

```bash
tpm2_flushcontext -t
```

и использования уже загруженного parent handle сценарий был успешно
выполнен.

Это наблюдение учтено в automated runner.

## Что данный стенд доказывает

Docker technical spike показывает:

* ARM64 software stack жизнеспособен;
* swtpm работает на выбранной platform architecture;
* базовые TPM 2.0 semantics доступны;
* сценарии Demo 1-4 практически реализуемы;
* negative tests можно строить на реальных TPM return codes;
* test runner может автоматически проверять результат.

## Что данный стенд НЕ доказывает

Он не моделирует:

* physical tamper resistance;
* side-channel resistance;
* аппаратную независимость TPM от host administrator;
* полноценный hardware Root of Trust boundary;
* Secure Boot;
* полный Measured Boot;
* сертификацию коммерческого TPM.

Также direct TCTI socket пока не эквивалентен ситуации, когда гостевая
Linux VM видит `/dev/tpm0` или `/dev/tpmrm0`.

Эта граница является причиной следующего перехода к virtual TPM
architecture.

Тот же набор проверок после этого стенда повторён на втором software
backend: [ARM64 Docker + ms-tpm-20-ref](docker-arm64-mssim.md).
`swtpm` остаётся основным backend.
