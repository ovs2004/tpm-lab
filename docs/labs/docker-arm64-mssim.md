# ARM64 Docker + ms-tpm-20-ref technical spike

## Статус

Выполнено в Sprint 03.

Это второй software backend того же раннего стенда. Основным backend
проекта остаётся `swtpm`. Документы первого стенда не заменяются:

* [ARM64 Docker + swtpm technical spike](docker-arm64-swtpm.md);
* [полный runbook swtpm](docker-arm64-swtpm-runbook.md).

Пошаговые команды этого стенда: [полный runbook](docker-arm64-mssim-runbook.md).

## Цель

Повторить на Microsoft TPM 2.0 Reference Implementation тот же набор,
который уже прошёл на `swtpm`:

* Ubuntu 24.04 ARM64 в Docker на Apple Silicon;
* реальный путь `tpm2-tools -> TPM2-TSS -> TCTI -> software TPM`;
* Discovery, GetRandom, PCR Read/Extend;
* TPM-backed RSA signing и отказ на изменённом сообщении;
* Seal/Unseal и PCR-bound policy, включая реальный policy failure;
* те же assertions, что в `infra/docker-tpm/run-checks.sh`.

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
tpm2-tools 5.6
        |
        v
TPM2-TSS
        |
        v
TCTI mssim
        |
        v
ms-tpm-20-ref tpm2-simulator
```

`swtpm` в этот образ не входит. Оба симулятора слушают TCP `2321`,
поэтому они поднимаются отдельными контейнерами, а не одним процессом.

## Подтверждённое окружение

Host:

* Apple Silicon Mac.

Container:

* Ubuntu 24.04;
* architecture: `aarch64`.

TPM stack:

* `ms-tpm-20-ref` commit `ee21db0a941decd3cac67925ea3310873af60ab3`
  (reference code TPM 2.0 v183);
* бинарник `/opt/ms-tpm-20-ref/tpm2-simulator`, собранный в образе из
  этого commit через autotools и OpenSSL 3;
* `tpm2-tools` `5.6-1build4`;
* `libtss2-tcti-mssim0t64` `4.0.1-7.1ubuntu5.1`.

## Подключение TPM

Software TPM использует:

* TPM command port: `2321`;
* platform/control port: `2322`.

`TPM2TOOLS_TCTI`:

```bash
mssim:host=127.0.0.1,port=2321
```

В отличие от `swtpm --flags not-need-init,startup-clear`, reference
simulator после старта ещё не принимает TPM-команды. Перед первой
командой стенд отправляет на порт `2322` сигналы `POWER_ON` и `NV_ON`,
затем `tpm2_startup -c`.

Каждый запуск начинается с чистого каталога состояния и флага
`--manufacture`.

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

Фактический automated run `20261002-160428`:

```text
PASS checks: 10
FAIL checks: 0

TPM LAB ARM64 PROTOTYPE: PASS
```

## Сравнение со swtpm

Одинаковые assertions. Отличаются transport и identity, которую
сообщает simulator.

| Наблюдение | swtpm | ms-tpm-20-ref |
| --- | --- | --- |
| Architecture | `aarch64` | `aarch64` |
| TCTI | `swtpm:host=127.0.0.1,port=2321` | `mssim:host=127.0.0.1,port=2321` |
| Startup | `not-need-init,startup-clear` | platform `POWER_ON` + `NV_ON`, затем `tpm2_startup -c` |
| TPM family | `2.0` | `2.0` |
| Reported revision | software TPM IBM | `1.83` |
| Manufacturer string | `IBM` | `XYZ ` (`raw: 0x58595A20`) |
| Vendor string | `SW TPM` | `xCG` + `fTPM` |
| PCR count | `0x18` = 24 | `0x18` = 24 |
| PCR 16 reset, затем SHA-256 extend | совпал с независимым SHA-256 | совпал с независимым SHA-256 |
| Изменённая подпись | `0x2DB` | `0x2DB` |
| PCR policy после Extend | `0x99D` | `0x99D` |
| Runner | 10 PASS / 0 FAIL | 10 PASS / 0 FAIL |

`XYZ ` и `xCG fTPM` — строки, которые эта сборка reference code
возвращает в `TPM2_GetCapability`. Это не физический TPM и не
идентификатор установленного в машине чипа.

Активные PCR banks в этом прогоне: SHA-256 и SHA-384, индексы 0..23.
SHA-1 bank в capability list пустой.

## Основные результаты

### TPM Discovery

```text
Family:         value: "2.0"
Manufacturer:   value: "XYZ "
PCR count:      raw: 0x18
```

Revision из того же ответа: `1.83`.

### PCR Read / Extend

Лабораторный PCR 16 был сброшен и изменён через PCR Extend.

```text
PCR before : 0000000000000000000000000000000000000000000000000000000000000000
Measurement: 3DEA03DC3C090590A8C02DEE0B3E48BFFE45EF0D1C8F5BD43888BF1F13E99D88
Expected   : 1D3224D51365587C3F5A3247630EF892C14B673AF376E61703C15115223232D2
PCR after  : 1D3224D51365587C3F5A3247630EF892C14B673AF376E61703C15115223232D2
```

`expected` посчитан вне TPM как `SHA256(oldPCR || measurement)` и совпал
с значением, которое вернул simulator.

### TPM-backed signing

Исходное сообщение прошло `tpm2_verifysignature`.

То же signature на изменённом сообщении simulator отверг:

```text
ERROR: Esys_VerifySignature(0x2DB) - tpm:parameter(2):the signature is not valid
```

### Basic Seal / Unseal

Secret `SUPER_SECRET_TPM_LAB` был помещён в TPM object и получен обратно
той же строкой.

### PCR-bound Seal / Unseal

Secret `PCR_BOUND_SECRET` открылся в trusted PCR state.

После PCR Extend тот же object вернул:

```text
ERROR: Esys_Unseal(0x99D) - tpm:session(1):a policy check failed
```

## Что отличается от стенда swtpm

* Пакет `swtpm` из apt заменён сборкой `tpm2-simulator`.
* TCTI называется `mssim`, а не `swtpm`. Протокол кадра другой: у
  Microsoft simulator отдельный platform port.
* `tpm2-tools` в образе по умолчанию выбирает `tcti-device`. Без
  `TPM2TOOLS_TCTI=mssim:...` команды пойдут не в simulator.
* Имя производителя и vendor string другие. Семантика проверенных
  команд совпала: PCR formula, `0x2DB`, `0x99D`.

## Что данный стенд доказывает

* reference implementation собирается и отвечает на ARM64;
* тот же `tpm2-tools` stack доходит до неё через TCTI `mssim`;
* набор Demo 1–4, уже показанный на `swtpm`, проходит и здесь;
* negative tests получают те же TPM return codes.

## Что данный стенд НЕ доказывает

Он не моделирует physical tamper resistance, side-channel resistance
и hardware Root of Trust. Direct TCTI socket по-прежнему не равен
`/dev/tpm0` внутри гостевой VM.

`swtpm` остаётся основным backend для будущего virtual TPM path.

Разбор двух прогонов, ARM и того, что писать поверх сокета своим
кодом:

* [два software TPM на ARM64](../research/two-simulators-arm64.md);
* [ARM64 и x86_64](../research/arm64-vs-x86-tpm.md);
* [программы поверх simulator](../research/programs-over-simulator.md).
