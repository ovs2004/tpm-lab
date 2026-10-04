# ARM64 Docker + ms-tpm-20-ref: полный runbook

## Назначение

Этот документ позволяет с нуля повторить тот же TPM 2.0 стенд, который
уже есть для `swtpm`, но на Microsoft TPM 2.0 Reference Implementation.

Стенд использует:

```text
Mac Apple Silicon
 -> Docker
 -> Ubuntu 24.04 ARM64
 -> tpm2-tools
 -> TPM2-TSS
 -> TCTI mssim
 -> ms-tpm-20-ref
```

Это software TPM laboratory.

Физическая защита аппаратного TPM здесь не моделируется.

Первый стенд сохранён отдельно: [ARM64 Docker + swtpm runbook](docker-arm64-swtpm-runbook.md).

Сводка результатов: [ARM64 Docker + ms-tpm-20-ref technical spike](docker-arm64-mssim.md).

Проверки те же, что у `swtpm`: оба runner вызывают
`infra/docker-tpm/run-checks.sh`.

---

## 1. Сборка Docker image

Все команды этого раздела выполняются в обычном Terminal на macOS,
из корня репозитория.

```bash
docker build \
  -t tpm-lab-mssim \
  -f infra/docker-tpm/Dockerfile.mssim \
  .
```

Что происходит:

1. Docker берёт Ubuntu 24.04.
2. В builder-стадии клонирует `microsoft/ms-tpm-20-ref` на commit
   `ee21db0a941decd3cac67925ea3310873af60ab3`.
3. Собирает `TPMCmd` через `./bootstrap && ./configure && make`.
4. Оставляет в runtime-образе только `tpm2-simulator`.
5. Устанавливает `tpm2-tools` и `libtss2-tcti-mssim0t64`.
6. Копирует `start-mssim` и runner.

Проверить architecture:

```bash
docker run --rm tpm-lab-mssim uname -m
```

Фактический вывод на этом Mac:

```text
aarch64
```

Revision, зашитая в образ:

```text
ee21db0a941decd3cac67925ea3310873af60ab3
```

Образ называется `tpm-lab-mssim`. Образ `tpm-lab-demo` со `swtpm`
этой командой не пересобирается и не удаляется.

---

## 2. Запуск интерактивного контейнера

Для ручных экспериментов:

```bash
docker run \
  --rm \
  -it \
  tpm-lab-mssim
```

После этого prompt меняется примерно на:

```text
root@<container-id>:/lab#
```

С этого момента следующие команды выполняются внутри контейнера.

`--rm` удаляет контейнер после выхода. Evidence нужно копировать на
Mac либо запускать runner с mounted volume, как в разделе TEST 8.

---

## 3. Запуск ms-tpm-20-ref вручную

Готовый скрипт делает чистый state, manufacture, platform signals и
`TPM2_Startup`:

```bash
/usr/local/bin/start-mssim
```

Фактический вывод успешного старта:

```text
[PLATFORM] command 1 ack=0
[PLATFORM] command 11 ack=0
[READY] ms-tpm-20-ref TPM 2.0 is reachable via mssim:host=127.0.0.1,port=2321
[REVISION] ee21db0a941decd3cac67925ea3310873af60ab3
```

Что означают шаги, которые скрипт выполняет сам.

Чистый каталог. Файл NV simulator пишет в текущий каталог процесса,
поэтому каждый лабораторный запуск начинается с нового каталога:

```bash
rm -rf /tmp/mssim-state
mkdir -p /tmp/mssim-state
cd /tmp/mssim-state
```

Сам simulator. `--manufacture` заново инициализирует NV. Процесс
слушает порт `2321` для TPM commands и порт `2322` для platform
signals. Флага daemon у этого бинарника нет, поэтому процесс
уходит в фон:

```bash
nohup /opt/ms-tpm-20-ref/tpm2-simulator --manufacture \
  >/tmp/mssim-state/simulator.log 2>&1 </dev/null &
```

Сообщить `tpm2-tools`, куда слать команды. В этом образе переменная
уже задана, но для ручного сеанса её полезно видеть явно:

```bash
export TPM2TOOLS_TCTI="mssim:host=127.0.0.1,port=2321"
```

Без этой переменной `tpm2` 5.6 выбирает `tcti-device` и ищет
TPM device, которого в контейнере нет.

Platform port — это отличие от `swtpm`. `swtpm` в нашем первом стенде
сам выполняет init и startup. Reference simulator после запуска ещё
выключен. На порт `2322` уходит команда из одного big-endian `uint32`,
ответ — такой же `uint32`, `0` значит, что сигнал принят.

| Код | Сигнал |
| --- | --- |
| 1 | `TPM_SIGNAL_POWER_ON` |
| 11 | `TPM_SIGNAL_NV_ON` |

Их отправляет `start-mssim`. В успешном прогоне оба ack были `0`.

Затем обычная TPM-команда:

```bash
tpm2_startup -c
```

`-c` — это `TPM2_Startup(CLEAR)`.

Проверка:

```bash
tpm2_getcap properties-fixed
```

Если команда печатает properties, transport работает.

### Наблюдение про SESSION_END

Первая попытка старта дополнительно слала на порт `2322` код `20`
(`TPM_SESSION_END`). Simulator закрыл соединение без ack:

```text
[PLATFORM] command 1 ack=0
[PLATFORM] command 11 ack=0
[ERROR] short platform ack for command 20: b''
[FATAL] Unable to start ms-tpm-20-ref simulator
```

`POWER_ON` и `NV_ON` к этому моменту уже прошли. `SESSION_END` для
лабораторного старта не нужен: сокет просто закрывается. Рабочий
`start-mssim` этот код не посылает.

---

# TEST 1. TPM Discovery

## Цель

Проверить:

- доступен ли TPM;
- TPM 2.0 ли это;
- какую identity сообщает эта сборка reference code;
- сколько PCR.

Короткий вывод:

```bash
echo "=== TPM VERSION ==="
tpm2_getcap properties-fixed \
  | grep -A2 TPM2_PT_FAMILY_INDICATOR

echo
echo "=== REVISION ==="
tpm2_getcap properties-fixed \
  | grep -A2 TPM2_PT_REVISION

echo
echo "=== MANUFACTURER ==="
tpm2_getcap properties-fixed \
  | grep -A2 TPM2_PT_MANUFACTURER

echo
echo "=== PCR COUNT ==="
tpm2_getcap properties-fixed \
  | grep -A2 TPM2_PT_PCR_COUNT
```

Фактический вывод automated run:

```text
Family:         value: "2.0"
Manufacturer:   value: "XYZ "
PCR count:      raw: 0x18
```

Из того же `properties-fixed.txt`:

```text
TPM2_PT_REVISION:
  raw: 0xB7
  value: 1.83
TPM2_PT_MANUFACTURER:
  raw: 0x58595A20
  value: "XYZ "
TPM2_PT_VENDOR_STRING_1:
  value: "xCG"
TPM2_PT_VENDOR_STRING_2:
  value: "fTPM"
```

`0x18` = 24 PCR. `1.83` совпадает с pinned source v183.

`XYZ ` — строка из этой software сборки. Её не нужно читать как
производителя физического чипа. На стенде `swtpm` в том же поле было
`IBM` / `SW TPM`.

PCR banks:

```bash
tpm2_getcap pcrs
```

Фактический список:

```text
sha256: 0..23
sha384: 0..23
```

SHA-1 bank в этом ответе пустой.

> Команды прошли через TPM2-TSS и TCTI `mssim` до reference simulator.
> Реализация отвечает как TPM 2.0.

---

# TEST 2. TPM GetRandom

## Цель

Выполнить ещё одну TPM command и получить 16 random bytes.

```bash
tpm2_getrandom --hex 16
```

Фактический вывод automated run:

```text
Random: b3e3f67f3d058dda5ae791f872aa18e2
```

Это 32 hex-символа, то есть 16 bytes. Следующий вызов даст другую
строку: assertion проверяет длину и алфавит, а не конкретное значение.

> Это software RNG reference implementation, не физический random source.

---

# TEST 3. PCR Read / Extend

## 3.1 Сброс лабораторного PCR 16

```bash
tpm2_pcrreset 16
tpm2_pcrread sha256:16
```

В этом simulator PCR 16 resettable с locality 0. Runner использует его
так же, как на `swtpm`: как лабораторный PCR, который можно вернуть
в известное состояние.

Фактическое значение до Extend — 32 нулевых байта:

```text
0000000000000000000000000000000000000000000000000000000000000000
```

Это не значит, что PCR 0..15 реального TPM можно сбросить из userspace.

## 3.2 Measurement и Extend

Measurement в runner — SHA-256 строки
`TPM Lab deterministic PCR measurement`.

```bash
tpm2_pcrextend "16:sha256=$MEASUREMENT"
tpm2_pcrread sha256:16
```

Смысл операции:

```text
PCR_new = SHA256(PCR_old || measurement)
```

## 3.3 Независимая проверка

Runner считает expected в Python и сравнивает с ответом TPM.
Фактический прогон:

```text
PCR before : 0000000000000000000000000000000000000000000000000000000000000000
Measurement: 3DEA03DC3C090590A8C02DEE0B3E48BFFE45EF0D1C8F5BD43888BF1F13E99D88
Expected   : 1D3224D51365587C3F5A3247630EF892C14B673AF376E61703C15115223232D2
PCR after  : 1D3224D51365587C3F5A3247630EF892C14B673AF376E61703C15115223232D2
[PASS] PCR Extend matches independent SHA-256 calculation
```

> PASS поставлен после сравнения, а не сразу после exit code `tpm2_pcrextend`.

---

# TEST 4. TPM-backed RSA Sign / Verify

Сначала очистить transient objects. На reference simulator слотов
мало, тот же приём уже был нужен на `swtpm` после `0x902`:

```bash
tpm2_flushcontext -t
```

Дальше те же команды, что в первом runbook.

Primary:

```bash
mkdir -p /lab/signing
cd /lab/signing

tpm2_createprimary \
  -C o \
  -G rsa \
  -c primary.ctx
```

Signing key:

```bash
tpm2_create \
  -C 0x80000000 \
  -G rsa \
  -u signing.pub \
  -r signing.priv \
  -a "sign|fixedtpm|fixedparent|sensitivedataorigin|userwithauth"

tpm2_load \
  -C 0x80000000 \
  -u signing.pub \
  -r signing.priv \
  -c signing.ctx
```

Handle в чистом automated run были:

```text
Primary handle: 0x80000000
Signing handle: 0x80000001
```

Ниже эти номера подставлены из того прогона. Если в ручной сессии
уже есть другие transient objects, handle нужно взять из
`tpm2_getcap handles-transient`, как это делает runner.

Сообщение и подпись:

```bash
echo "TPM Lab signing test" > message.txt
tpm2_sign -c 0x80000001 -g sha256 -o signature.bin message.txt
tpm2_verifysignature -c 0x80000001 -g sha256 -s signature.bin -m message.txt
```

Фактический результат положительного сценария:

```text
[PASS] Original message signature is valid
```

Испорченное сообщение с той же подписью:

```bash
echo "TPM Lab signing test TAMPERED" > tampered.txt
tpm2_verifysignature -c 0x80000001 -g sha256 -s signature.bin -m tampered.txt
```

Фактический stderr:

```text
WARNING:esys:src/tss2-esys/api/Esys_VerifySignature.c:302:Esys_VerifySignature_Finish() Received TPM Error
ERROR:esys:src/tss2-esys/api/Esys_VerifySignature.c:103:Esys_VerifySignature() Esys Finish ErrorCode (0x000002db)
ERROR: Esys_VerifySignature(0x2DB) - tpm:parameter(2):the signature is not valid
ERROR: Verify signature failed!
ERROR: Unable to run tpm2_verifysignature
```

Runner считает это PASS только потому, что отказ пришёл как invalid
signature (`0x2DB`). Другая ошибка была бы FAIL.

```text
[PASS] Tampered message rejected by TPM as expected
```

Код `0x2DB` совпал со стендом `swtpm`.

---

# TEST 5. Basic Seal / Unseal

```bash
tpm2_flushcontext -t
mkdir -p /lab/sealing
cd /lab/sealing

echo -n "SUPER_SECRET_TPM_LAB" > secret.txt

tpm2_createprimary -C o -G rsa -c primary.ctx

tpm2_create \
  -C 0x80000000 \
  -i secret.txt \
  -u sealed.pub \
  -r sealed.priv

tpm2_load \
  -C 0x80000000 \
  -u sealed.pub \
  -r sealed.priv \
  -c sealed.ctx

tpm2_unseal -c 0x80000001
```

Фактический результат:

```text
[PASS] Secret sealed and unsealed successfully
```

Unseal вернул ровно `SUPER_SECRET_TPM_LAB`.

---

# TEST 6. PCR-bound Seal / Unseal

Снова известный PCR 16, policy на его значение, затем тот же object
после Extend.

```bash
tpm2_pcrreset 16
tpm2_pcrread -o pcr.dat sha256:16

tpm2_createpolicy \
  --policy-pcr \
  -l sha256:16 \
  -f pcr.dat \
  -L pcr.policy

echo -n "PCR_BOUND_SECRET" > secret.txt

tpm2_create \
  -C 0x80000000 \
  -L pcr.policy \
  -i secret.txt \
  -u sealed.pub \
  -r sealed.priv

tpm2_load \
  -C 0x80000000 \
  -u sealed.pub \
  -r sealed.priv \
  -c sealed.ctx
```

Trusted state:

```bash
tpm2_startauthsession --policy-session -S trusted-session.ctx
tpm2_policypcr -S trusted-session.ctx -l sha256:16 -f pcr.dat
tpm2_unseal -c 0x80000001 -p session:trusted-session.ctx
```

Фактический прогон:

```text
Trusted PCR: 0000000000000000000000000000000000000000000000000000000000000000
Trusted policy digest: bff2d58e9813f97cefc14f72ad8133bc7092d652b7c877959254af140c841f36
[PASS] Trusted PCR state allows Unseal
```

Tamper — реальный PCR Extend, не подмена файла:

```bash
tpm2_pcrextend "16:sha256=<sha256 of TAMPERED PLATFORM STATE>"
tpm2_startauthsession --policy-session -S tampered-session.ctx
tpm2_policypcr -S tampered-session.ctx -l sha256:16
tpm2_unseal -c 0x80000001 -p session:tampered-session.ctx
```

Фактический вывод:

```text
Tampered PCR: 004A4BA3E0B0C25FDF42989282DA4821C5F821BCBFD3F15723C5153EFDCD1049
[PASS] PCR changed after tampering
Tampered policy digest: 3d5ddd4e3b812605c2bd6436821a88674bf888e395026aa47772810b404f9f1c
```

Stderr отказа:

```text
WARNING:esys:src/tss2-esys/api/Esys_Unseal.c:295:Esys_Unseal_Finish() Received TPM Error
ERROR:esys:src/tss2-esys/api/Esys_Unseal.c:98:Esys_Unseal() Esys Finish ErrorCode (0x0000099d)
ERROR: Esys_Unseal(0x99D) - tpm:session(1):a policy check failed
ERROR: Unable to run tpm2_unseal
```

```text
[PASS] Tampered PCR state rejected by TPM policy
```

Код `0x99D` совпал со стендом `swtpm`.

---

# TEST 7. Полностью автоматизированный runner

Ручные команды выше нужны, чтобы видеть шаги. Для повторного запуска
достаточно runner.

Выйти из интерактивного container:

```bash
exit
```

Команды снова выполняются на macOS из корня repo.

```bash
mkdir -p evidence

docker run --rm \
  -v "$PWD/evidence:/evidence" \
  -e EVIDENCE_ROOT=/evidence \
  tpm-lab-mssim \
  /lab/run-all-mssim.sh
```

Runner сам:

1. поднимает чистый `tpm2-simulator` с `--manufacture`;
2. шлёт `POWER_ON` и `NV_ON`;
3. выполняет `tpm2_startup -c`;
4. запускает те же 10 assertions, что `tpm-lab-demo` / `run-all.sh`.

Фактический вывод прогона `20261002-160428`:

```text
============================================================
             TPM LAB — ARM64 TECHNICAL SPIKE
============================================================
Run:      20261002-160428
Backend:  ms-tpm-20-ref
TCTI:     mssim:host=127.0.0.1,port=2321
Evidence: /evidence/20261002-160428

[PLATFORM] command 1 ack=0
[PLATFORM] command 11 ack=0
[READY] ms-tpm-20-ref TPM 2.0 is reachable via mssim:host=127.0.0.1,port=2321
[REVISION] ee21db0a941decd3cac67925ea3310873af60ab3
------------------------------------------------------------
[0] Environment / architecture
Architecture: aarch64
[PASS] Environment is ARM64
------------------------------------------------------------
[1] TPM discovery
Family:         value: "2.0"
Manufacturer:   value: "XYZ "
PCR count:      raw: 0x18
[PASS] TPM 2.0 responds through TPM2-TSS/TCTI
------------------------------------------------------------
[2] TPM random generator
Random: b3e3f67f3d058dda5ae791f872aa18e2
[PASS] TPM returned 16 random bytes
------------------------------------------------------------
[3] PCR Read / Extend
PCR before : 0000000000000000000000000000000000000000000000000000000000000000
Measurement: 3DEA03DC3C090590A8C02DEE0B3E48BFFE45EF0D1C8F5BD43888BF1F13E99D88
Expected   : 1D3224D51365587C3F5A3247630EF892C14B673AF376E61703C15115223232D2
PCR after  : 1D3224D51365587C3F5A3247630EF892C14B673AF376E61703C15115223232D2
[PASS] PCR Extend matches independent SHA-256 calculation
------------------------------------------------------------
[4] TPM-backed RSA signing
Primary handle: 0x80000000
Signing handle: 0x80000001
[PASS] Original message signature is valid
[PASS] Tampered message rejected by TPM as expected
------------------------------------------------------------
[5] Seal / Unseal
[PASS] Secret sealed and unsealed successfully
------------------------------------------------------------
[6] PCR-bound policy — trusted vs tampered state
Trusted PCR: 0000000000000000000000000000000000000000000000000000000000000000
Trusted policy digest: bff2d58e9813f97cefc14f72ad8133bc7092d652b7c877959254af140c841f36
[PASS] Trusted PCR state allows Unseal
Tampered PCR: 004A4BA3E0B0C25FDF42989282DA4821C5F821BCBFD3F15723C5153EFDCD1049
[PASS] PCR changed after tampering
Tampered policy digest: 3d5ddd4e3b812605c2bd6436821a88674bf888e395026aa47772810b404f9f1c
[PASS] Tampered PCR state rejected by TPM policy
------------------------------------------------------------

======================= FINAL RESULT ========================
PASS checks: 10
FAIL checks: 0

Evidence directory:
/evidence/20261002-160428

TPM LAB ARM64 PROTOTYPE: PASS
============================================================
```

Evidence остаётся на host:

```bash
ls evidence/20261002-160428
```

Там лежат `properties-fixed.txt`, `pcr-test.txt`, логи signing и
`pcr-policy/tampered-unseal.err` с `0x99D`.

---

# Быстрый запуск

Из корня repo, когда нужно поднять именно второй simulator:

```bash
docker build \
  -t tpm-lab-mssim \
  -f infra/docker-tpm/Dockerfile.mssim \
  .

mkdir -p evidence

docker run --rm \
  -v "$PWD/evidence:/evidence" \
  -e EVIDENCE_ROOT=/evidence \
  tpm-lab-mssim \
  /lab/run-all-mssim.sh
```

Первый simulator по-прежнему поднимается своим образом:

```bash
docker build \
  -t tpm-lab-demo \
  -f infra/docker-tpm/Dockerfile \
  .

docker run --rm \
  -v "$PWD/evidence:/evidence" \
  -e EVIDENCE_ROOT=/evidence \
  tpm-lab-demo \
  /lab/run-all.sh
```

Оба контейнера одновременно на порту `2321` не нужны: каждый слушает
`127.0.0.1` внутри своего network namespace.
