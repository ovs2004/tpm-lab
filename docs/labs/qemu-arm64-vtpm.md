# ARCH-005 — QEMU ARM64 virtual TPM

* Status: Accepted, проверено запуском в Sprint 04
* Задача: ARCH-005

## Решение

Целевая среда поднимается так:

```text
Mac Apple Silicon
 ->
QEMU virt + HVF
 ->
Ubuntu 24.04.5 ARM64
 ->
ACPI TPM2 / tpm_tis
 ->
/dev/tpm0 и /dev/tpmrm0
 ->
swtpm на host
```

Скрипт `infra/vm/run-lab.sh` воспроизводит этот стенд.
UTM 4.6.4 на машине установлен и использует тот же QEMU,
но в репозиторий кладётся командная строка QEMU, а не клики в GUI:
её можно повторить и сбросить.

## Почему не другие пути

| Путь | Почему не он |
| --- | --- |
| Docker + TCTI `swtpm` | Уже проверен в Sprint 02. Гость не видит TPM как устройство. |
| UTM на Apple Virtualization | У этого backend нет virtual TPM. |
| `tpm-crb-device` | В QEMU 10.1.0 для `aarch64` такого устройства нет. Есть `tpm-tis-device` и `tpm-tis-i2c`. |
| `startup-clear` у swtpm | В direct-socket spike этот флаг нужен. Здесь `TPM2_Startup` принадлежит firmware и ядру гостя. |

Гипотеза из [ARM64 и x86_64](../research/arm64-vs-x86-tpm.md)
подтвердилась: гость получает sysbus-устройство `tpm-tis-device`.

## Конфигурация

Проверено 16 октября 2026 на этом Mac.

| Компонент | Значение |
| --- | --- |
| Host | macOS 15.7.4, `arm64` |
| QEMU | 10.1.0, accelerator `hvf` |
| Машина | `virt`, `gic-version=3`, `-cpu host` |
| CPU / RAM | 2 / 2048 MiB |
| Firmware | `edk2-aarch64-code.fd`, edk2-stable202408 |
| Диск | Ubuntu cloud image, overlay qcow2 |
| Образ | `noble-server-cloudimg-arm64.img` |
| SHA-256 образа | `1d6bffe64b848468ac97f821d369a4846d983de1800ccf6b5ec8853e85cefc55` |
| Гость | Ubuntu 24.04.5 LTS, kernel `6.8.0-142-generic`, `aarch64` |
| Сеть | user-mode NAT, SSH `127.0.0.1:22222` |
| swtpm | Homebrew 0.10.2, libtpms 0.10.2, unix socket |
| TPM в госте | `tpm2-tools` 5.6, TCTI `device:/dev/tpmrm0` |
| UTM | 4.6.4 установлен, в прогоне не использовался |

Порт 2222 на этом Mac уже слушает `vagrant-vmware-utility`.
Лаборатория берёт 22222.

## Как swtpm подключён

Host запускает swtpm без `startup-clear` и без `not-need-init`.
QEMU сам посылает `CMD_INIT` в control socket:

```text
-chardev socket,id=chrtpm,path=<runtime>/swtpm/swtpm.sock
-tpmdev emulator,id=tpm0,chardev=chrtpm
-device tpm-tis-device,tpmdev=tpm0
```

Гость swtpm не видит. Он видит ACPI-таблицу `TPM2` и устройство
`MSFT0101`. Ядро пишет:

```text
tpm_tis MSFT0101:00: 2.0 TPM (device-id 0x1, rev-id 1)
```

`device-id 0x1` — идентификатор swtpm, не отдельного чипа.
Узлы:

```text
/dev/tpm0     crw-rw---- tss:root
/dev/tpmrm0   crw-rw---- tss:tss
```

Команды идут в resource manager `/dev/tpmrm0`.
Пользователь `ubuntu` добавляется в группу `tss`.
Discovery показал manufacturer `IBM`, family `2.0`, revision `1.83`:
это swtpm, не reference simulator из Sprint 03.

## Reset и повторный запуск

```text
infra/vm/run-lab.sh reset
infra/vm/run-lab.sh up
```

`reset` останавливает QEMU и swtpm и удаляет overlay, состояние TPM,
UEFI vars и evidence. Базовый cloud image остаётся.
`up` создаёт новый overlay и пустой каталог состояния.

Останавливать живой стенд нужно через `run-lab.sh stop` или
`sudo poweroff` в госте. `kill -9` по QEMU оборвал dpkg на первом
прогоне и испортил базу пакетов гостя. После этого помог только
чистый `up`.

## Что проверено одним и тем же runner

`infra/docker-tpm/run-checks.sh` внутри гостя с
`TPM2TOOLS_TCTI=device:/dev/tpmrm0`:

```text
PASS checks: 10
FAIL checks: 0
TPM LAB ARM64 PROTOTYPE: PASS
```

Тот же скрипт на direct socket `swtpm` после правки снова дал
10 PASS / 0 FAIL. PCR после Extend совпал с независимым SHA-256,
отказ подписи — `0x2DB`, отказ policy — `0x99D`.

Первый прогон через `/dev/tpmrm0` упал на signing: resource manager
не показывает transient handles в `tpm2_getcap handles-transient`,
хотя `CreatePrimary` прошёл. Runner теперь берёт context file
(`primary.ctx`), если списка handles нет. На сокете handles по-прежнему
есть, и runner их использует.

## Открытые вопросы

* Отдельный клик-путь в UTM не записан. Командная строка QEMU для этого
  достаточна и совпадает с backend, который UTM вызывает.
* Второй участник ещё не повторил `run-lab.sh up` на своей машине.
* Образ качается как `noble/current` и сверяется с `SHA256SUMS`.
  Со временем `current` сменится; зафиксированный выше хеш относится
  к прогону 16 октября 2026.
* FAPI, ESAPI-сравнение и Quote этим стендом не закрываются.
  Тонкий ESAPI-модуль на сокете описан отдельно и VM не заменяет.

Пошаговый запуск: [runbook](qemu-arm64-vtpm-runbook.md).
