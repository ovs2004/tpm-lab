# Sprint 04 — виртуальная машина и два уровня API

## Цель

До этого спринта TPM отвечал только по сети из Docker: программа
`tpm2-tools` открывала TCP-сокет `swtpm`. В архитектуре проекта гость
должен видеть TPM как устройство. Sprint 04 это и проверяет.

Цепочка:

```text
Mac Apple Silicon
 -> QEMU, машина virt, ускоритель HVF
 -> Ubuntu 24.04.5 ARM64
 -> /dev/tpm0 и /dev/tpmrm0
 -> swtpm на Mac
```

`QEMU` запускает гостевую систему. `HVF` — аппаратная виртуализация
Apple, гость ARM64 идёт без эмуляции x86. `swtpm` — программа,
которая отвечает на команды TPM 2.0 и хранит состояние в каталоге
на Mac. `libtpms` — библиотека внутри `swtpm`, в ней считаются AES,
Camellia, RSA и PCR.

Рядом с машиной, на старом сокетном стенде, те же операции записаны
своим кодом. `ESAPI` — уровень TPM2-TSS, где видны primary, session
и flush. `FAPI` — уровень выше: те же действия занимают несколько
команд `tss2`, session библиотека ведёт сама.

## Что планировали

* Записку ARCH-005: как собрана VM, как подключён `swtpm`, как сбросить состояние.
* Загрузку Ubuntu 24.04 ARM64 и устройство TPM в госте.
* Тот же набор проверок, что в Sprint 02, но через `/dev/tpmrm0`.
* Если машина не займёт весь спринт — вызовы TPM из своего кода, без оболочки над `tpm2`.

## Что получилось

### Машина

Записка и команды: [ARCH-005](../labs/qemu-arm64-vtpm.md),
[runbook](../labs/qemu-arm64-vtpm-runbook.md). Скрипт
`infra/vm/run-lab.sh up` на этом Mac поднял гостя. Повтор с нуля
делается так: `run-lab.sh reset`, затем снова `up`. Образ диска и
ключ SSH скрипт создаёт локально, в `infra/vm/runtime/`, в репозиторий
они не входят.

UTM 4.6.4 на Mac установлен. Это графическая оболочка над тем же
QEMU. В репозитории лежит командная строка, её можно сбросить и
сравнить. Встроенная виртуализация Apple отдельного TPM гостю не
отдаёт, поэтому стенд идёт через QEMU. У QEMU 10.1 для aarch64 нет
устройства `tpm-crb` (так TPM вешают на x86). Есть `tpm-tis-device`:
регистры TPM, которые Linux находит по таблице ACPI.

Гость после загрузки:

```text
Linux tpm-lab 6.8.0-142-generic aarch64
Ubuntu 24.04.5 LTS
группы пользователя: ubuntu, tss
/dev/tpm0    tss:root
/dev/tpmrm0  tss:tss
tpm_tis MSFT0101:00: 2.0 TPM (device-id 0x1, rev-id 1)
```

`/dev/tpm0` — само устройство. `/dev/tpmrm0` — resource manager ядра:
через него несколько программ делят один TPM, не занимая устройство
монопольно. Группа `tss` нужна, чтобы пользователь `ubuntu` мог
открыть эти узлы. `MSFT0101` — имя TPM 2.0 в ACPI. `device-id 0x1` —
так представляется `swtpm`.

Discovery, то есть чтение свойств TPM, шло с
`TPM2TOOLS_TCTI=device:/dev/tpmrm0`. TCTI — транспорт TPM2-TSS: куда
уходит байтовый кадр команды. Здесь это файл устройства, не адрес
`127.0.0.1`.

```text
Family:         2.0
Manufacturer:   IBM
PCR count:      24
Revision:       1.83
```

`IBM` и ревизия `1.83` — это `swtpm` 0.10.2. В Sprint 03 reference
simulator называл себя `XYZ`. Набор команд тот же, имя реализации
другое.

Общий `infra/docker-tpm/run-checks.sh` внутри гостя:

```text
PASS checks: 10
FAIL checks: 0
TPM LAB ARM64 PROTOTYPE: PASS
```

PCR — регистр конфигурации. Extend не записывает новое значение
поверх старого, а считает `SHA-256(старый PCR || измерение)`. Хеш,
посчитанный в госте отдельно от TPM, совпал с регистром после Extend.
Подпись исходного сообщения прошла. Подпись испорченного TPM отверг
с кодом `0x2DB` (подпись не сходится). Секрет, запечатанный к PCR,
после Extend не открылся: код `0x99D`, проверка policy не прошла.

Первый запуск подписи через `/dev/tpmrm0` не нашёл transient handle.
Resource manager не показывает временные объекты в
`tpm2_getcap handles-transient`, хотя `CreatePrimary` уже прошёл.
Runner в этом случае берёт файл контекста `primary.ctx`. На сокете
Docker handles по-прежнему видны как `0x80000000`, и там runner
по-прежнему пользуется ими. Повтор сокета после правки: снова
10 PASS / 0 FAIL.

`TPM2_Startup` в этой схеме посылают прошивка и ядро гостя. Флаг
`startup-clear`, которым поднимали сокет в Docker, здесь не ставится:
иначе старт выполнился бы дважды.

Останавливать QEMU нужно через `run-lab.sh stop` или `poweroff` в
госте. `kill -9` оборвал `dpkg` на первом прогоне, база пакетов на
том же диске уже не чинилась. Помог только новый `up`.

### Свой код на сокете: ESAPI

`src/tpm_lab/` ходит в тот же `swtpm` через библиотеку `tpm2-pytss`,
без вызова `tpm2_sign` и остальных команд `tpm2`. Образ
`infra/docker-tpm/Dockerfile.pytss`.

```bash
docker build -t tpm-lab-pytss -f infra/docker-tpm/Dockerfile.pytss .
docker run --rm tpm-lab-pytss
```

```text
PASS checks: 10
FAIL checks: 0
TPM LAB ESAPI MODULE: PASS
```

Две сверки shell-runner не делает. `TPM2_Hash` совпал с
`hashlib.sha256` на тех же байтах: в этой роли TPM считает обычный
SHA-256. Подпись, снятую в TPM, проверил OpenSSL по выгруженному
открытому ключу. Отказы те же: `0x2DB` и `0x99D`.

### Та же policy через FAPI

Секрет `PCR_BOUND_SECRET` запечатан к нулевому PCR 16 и через ESAPI,
и через FAPI. Запись прогона:
[ESAPI, FAPI и ключ Кузнечика](../labs/fapi-esapi-kuznyechik.md).

В ESAPI в `src/tpm_lab/ops.py` видны шаги: primary, пробная session
для digest policy, Create, Load, рабочая policy session, Unseal,
flush. Пока PCR 16 нулевой, секрет возвращается. После Extend —
`0x99D`.

FAPI на Ubuntu 24.04 вызывается командами `tss2`. Они идут в
`libtss2-fapi`. Python-модуль FAPI в пакете `python3-tpm2-pytss`
выключен: сборка пакета не нашла в себе версию библиотеки и
отказывается импортироваться. Поэтому сравнение идёт по командам,
которые эта библиотека реально выполняет:

```text
tss2 provision
tss2 import        policy POLICYPCR на PCR 16
tss2 createseal
tss2 unseal
tss2 pcrextend
tss2 unseal
```

`provision` готовит иерархии и хранилище ключей FAPI. У учебного
`swtpm` нет сертификата EK (ключ подтверждения, который есть у
платформенного TPM), поэтому в конфиге стоит `ek_cert_less`.
Session и flush в этих шести командах снаружи не видны: их делает
FAPI.

Доверенный PCR отдаёт тот же секрет. После Extend отказ приходит
раньше, чем у ESAPI. FAPI пытается выполнить сохранённую policy, и
TPM отклоняет саму команду `PolicyPCR` с кодом `0x1C4`: значение PCR
уже не то, которое записано в policy. Секрет в ответ не попадает.
Правило доступа одно. Наружу выходит ошибка другого шага.

### Кузнечик

`tpm2_getcap algorithms` на этом `swtpm` перечисляет AES (`0x0006`) и
Camellia (`0x0026`). Это номера из реестра TCG. Кузнечика
(ГОСТ Р 34.12-2015, блок 128 бит, ключ 256 бит) в списке нет, в
обычном OpenSSL его тоже нет. `libtpms` вызывает AES и Camellia оттуда.

Блок считает `src/tpm_lab/kuznyechik.py`. Контрольный пример из
RFC 7801 совпал: `7f679d90bebc24305a468d42b9d4edcd`. Ключ на 32 байта
берётся командой `TPM2_GetRandom` и сразу seal к PCR 16. Открыть его
и расшифровать блок можно после Unseal. После Extend тот же объект
отвечает `0x99D`, ключ остаётся в TPM.

Три части одним запуском:

```bash
docker run --rm --entrypoint /lab/run-fapi-kuznyechik.sh tpm-lab-pytss
```

```text
PASS checks: 8
FAIL checks: 0
FAPI ESAPI KUZNYECHIK: PASS
```

Шифрование блока при этом выполняет процесс Python. В список
алгоритмов TPM Кузнечик не попал. Как поставить его рядом с AES,
записано отдельно: [Кузнечик внутри TPM](../labs/kuznyechik-inside-tpm.md).

## Ограничения

* Графический профиль UTM не сохранён. Повторяется командная строка QEMU.
* Второй участник ещё не прогнал `run-lab.sh up` на своей машине.
* Quote (TPM подписывает выбранные PCR) и LUKS не делались.
* Облачный стенд не поднимался. Что там можно взять, разобрано в
  [записке про vTPM](../research/cloud-vtpm.md): это тоже виртуальный
  TPM у машины, не отдельный чип в аренду.

## Дальше

* Кузнечик в `libtpms`, тем же путём, которым туда входит Camellia.
  Критерий: номер виден в `tpm2_getcap algorithms`, один блок
  `TPM2_EncryptDecrypt` совпадает с вектором RFC 7801.
* Одна Ubuntu в Google Shielded VM или Azure Trusted Launch, чтобы
  повторить discovery через `/dev/tpm0` уже не на своём QEMU.
* Второй участник повторяет локальный `run-lab.sh up`.
* Architecture v0.1 и ТЗ сверяются с версиями этого прогона и с TCTI
  `device:/dev/tpmrm0`.

## Кратко

```text
Mac → QEMU virt / HVF → Ubuntu 24.04.5 aarch64
    → /dev/tpmrm0 → swtpm 0.10.2

Гость, тот же runner, что в Sprint 02: 10 PASS / 0 FAIL
PCR совпал с отдельным SHA-256, подпись 0x2DB, policy 0x99D

Сокет: ESAPI 10 PASS / 0 FAIL
ESAPI и FAPI, один seal к PCR 16: 0x99D и 0x1C4
Кузнечик: вектор RFC совпал, ключ после Extend не выходит
```
