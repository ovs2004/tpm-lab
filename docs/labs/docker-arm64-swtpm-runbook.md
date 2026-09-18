# ARM64 Docker + swtpm: полный runbook

## Назначение

Этот документ позволяет с нуля воспроизвести исследовательский TPM 2.0
стенд на Mac с Apple Silicon.

Стенд использует:

```text
Mac Apple Silicon
 -> Docker
 -> Ubuntu 24.04 ARM64
 -> tpm2-tools
 -> TPM2-TSS
 -> TCTI swtpm
 -> swtpm
```

Это software TPM laboratory.

Физическая защита аппаратного TPM здесь не моделируется.

Сводка результатов: [ARM64 Docker + swtpm technical spike](docker-arm64-swtpm.md).

---

## 1. Сборка Docker image

Все команды этого раздела выполняются в обычном Terminal на macOS,
из корня репозитория.

```bash
docker build \
  -t tpm-lab-demo \
  -f infra/docker-tpm/Dockerfile \
  .
```

Что происходит:

1. Docker берёт Ubuntu 24.04.
2. Устанавливает `swtpm`.
3. Устанавливает `tpm2-tools`.
4. Устанавливает TPM2-TSS TCTI для swtpm.
5. Добавляет Python и вспомогательные CLI.
6. Копирует автоматизированный runner.

Проверить architecture:

```bash
docker run --rm tpm-lab-demo uname -m
```

На Apple Silicon ожидается:

```text
aarch64
```

Это подтверждает, что лабораторный Linux environment работает как
ARM64, а не как x86_64 container.

---

## 2. Запуск интерактивного контейнера

Для ручных экспериментов:

```bash
docker run \
  --rm \
  -it \
  --name tpm-demo \
  tpm-lab-demo
```

После этого prompt меняется примерно на:

```text
root@<container-id>:/lab#
```

С этого момента следующие команды выполняются ВНУТРИ контейнера.

Обрати внимание:

`--rm` означает, что контейнер будет удалён после выхода.

Поэтому важные evidence нужно либо копировать на Mac, либо запускать
автоматический runner с mounted volume.

---

## 3. Запуск swtpm вручную

Создать каталог состояния:

```bash
mkdir -p /tmp/tpmstate
```

Запустить TPM:

```bash
swtpm socket \
  --tpm2 \
  --tpmstate dir=/tmp/tpmstate \
  --server type=tcp,port=2321,bindaddr=127.0.0.1 \
  --ctrl type=tcp,port=2322,bindaddr=127.0.0.1 \
  --flags not-need-init,startup-clear \
  --daemon
```

Параметры:

* `--tpm2` — TPM 2.0;
* `--tpmstate` — каталог внутреннего состояния software TPM;
* port `2321` — TPM command channel;
* port `2322` — control channel;
* `startup-clear` — лабораторный startup state;
* `--daemon` — процесс остаётся работать в фоне.

Теперь сообщить `tpm2-tools`, куда отправлять TPM commands:

```bash
export TPM2TOOLS_TCTI="swtpm:host=127.0.0.1,port=2321"
```

Проверить:

```bash
tpm2_getcap properties-fixed
```

Если TPM отвечает — transport работает.

---

# TEST 1. TPM Discovery

## Цель

Проверить:

* доступен ли TPM;
* TPM 2.0 ли это;
* какие свойства сообщает simulator;
* сколько PCR;
* какие algorithms/PCR banks доступны.

### Короткий вывод

```bash
echo "=== TPM VERSION ==="
tpm2_getcap properties-fixed \
  | grep -A2 TPM2_PT_FAMILY_INDICATOR

echo

echo "=== MANUFACTURER ==="
tpm2_getcap properties-fixed \
  | grep -A2 TPM2_PT_MANUFACTURER

echo

echo "=== PCR COUNT ==="
tpm2_getcap properties-fixed \
  | grep -A2 TPM2_PT_PCR_COUNT
```

Ожидаемо:

```text
TPM family: 2.0
Manufacturer: IBM
PCR count: 0x18
```

`0x18` в decimal = `24`.

Это software implementation, поэтому Manufacturer не нужно
интерпретировать как наличие физического IBM TPM chip.

Полные capabilities:

```bash
tpm2_getcap properties-fixed
```

Algorithms:

```bash
tpm2_getcap algorithms
```

PCR banks:

```bash
tpm2_getcap pcrs
```

В нашем стенде были доступны PCR 0..23 в нескольких hash banks,
включая SHA-256.

### Что сказать преподавателю

> Проверили коммуникацию через TPM2-TSS/TCTI до software TPM.
> Реализация отвечает как TPM 2.0 и сообщает стандартные capabilities.

---

# TEST 2. TPM GetRandom

## Цель

Выполнить ещё одну реальную TPM command и получить 16 random bytes.

```bash
tpm2_getrandom --hex 16
```

Чтобы показать несколько вызовов:

```bash
for i in {1..5}; do
    tpm2_getrandom --hex 16
    echo
done
```

Каждая строка содержит:

```text
32 hex characters = 16 bytes
```

### Что этот тест НЕ означает

Поскольку используется software TPM, нельзя утверждать, что
исследуется физический аппаратный random source.

### Что сказать преподавателю

> Дополнительно проверили GetRandom через тот же TPM command stack.

---

# TEST 3. PCR Read / Extend

## 3.1 Сброс лабораторного PCR 16

```bash
tpm2_pcrreset 16
```

В данном swtpm lab PCR 16 используется как resettable PCR для
воспроизводимых экспериментов.

Проверить:

```bash
tpm2_pcrread sha256:16
```

Ожидаем начальное значение из нулей:

```text
0000000000000000000000000000000000000000000000000000000000000000
```

Не следует из этого делать вывод, что любые PCR реального TPM можно
произвольно reset.

## 3.2 Создать measurement

```bash
MEASUREMENT="$(
  echo -n "TPM Lab Sprint 02" \
  | sha256sum \
  | awk '{print $1}'
)"

echo "$MEASUREMENT"
```

Measurement — это SHA-256 выбранной нами строки.

В реальной measured platform measurements могут соответствовать
firmware, bootloader, configuration и другим компонентам.

## 3.3 Выполнить PCR Extend

До:

```bash
tpm2_pcrread sha256:16
```

Extend:

```bash
tpm2_pcrextend "16:sha256=$MEASUREMENT"
```

После:

```bash
tpm2_pcrread sha256:16
```

PCR должен измениться.

PCR Extend имеет смысл:

```text
PCR_new = SHA256(PCR_old || measurement)
```

Это не обычная запись:

```text
PCR = measurement
```

## 3.4 Независимо проверить результат

Сначала сохранить значения вручную либо использовать automated runner.

Пример Python:

```bash
python3 - <<'PY'
import hashlib

old = bytes.fromhex(
    "0000000000000000000000000000000000000000000000000000000000000000"
)

measurement = bytes.fromhex(
    "PUT_MEASUREMENT_HEX_HERE"
)

expected = hashlib.sha256(old + measurement).hexdigest().upper()

print(expected)
PY
```

Для ручной работы удобнее использовать automated runner, который
подставляет значения сам.

### Что сказать преподавателю

> PCR Extend проверяется не только exit code. Мы отдельно считаем
> SHA256(oldPCR || measurement) и сравниваем его с фактическим TPM PCR.

---

# TEST 4. TPM transient objects и troubleshooting

Перед object-based experiments полезно посмотреть:

```bash
tpm2_getcap handles-transient
```

Если накопилось несколько objects и получена ошибка:

```text
0x902
out of memory for object contexts
```

очистить transient objects:

```bash
tpm2_flushcontext -t
```

Проверить:

```bash
tpm2_getcap handles-transient
```

Вывод должен быть пустым.

### Что произошло во время Sprint 02

В ранней версии signing test прямое использование context files
привело к заполнению ограниченных transient object slots.

После явной очистки и использования уже загруженного parent handle
signing scenario заработал.

Это не является искусственным PASS — это отдельное наблюдение о
TPM resource/context management.

---

# TEST 5. TPM-backed RSA Sign / Verify

Сначала очистить objects:

```bash
tpm2_flushcontext -t >/dev/null 2>&1 || true
```

Создать рабочую директорию:

```bash
mkdir -p /lab/signing
cd /lab/signing
rm -f ./*
```

## 5.1 Primary Object

```bash
tpm2_createprimary \
  -C o \
  -G rsa \
  -c primary.ctx
```

Посмотреть handle:

```bash
tpm2_getcap handles-transient
```

Сохранить его автоматически:

```bash
PRIMARY_HANDLE="$(
  tpm2_getcap handles-transient \
  | awk '/0x/ {print $2}' \
  | head -1
)"

echo "$PRIMARY_HANDLE"
```

Primary Object — parent, под которым создаётся signing object.

## 5.2 Signing object

```bash
tpm2_create \
  -C "$PRIMARY_HANDLE" \
  -G rsa \
  -u signing.pub \
  -r signing.priv \
  -a "sign|fixedtpm|fixedparent|sensitivedataorigin|userwithauth"
```

`signing.pub` содержит public portion.

`signing.priv` — TPM private blob, а не обычный plaintext PEM private
key.

Загрузить object:

```bash
tpm2_load \
  -C "$PRIMARY_HANDLE" \
  -u signing.pub \
  -r signing.priv \
  -c signing.ctx
```

Получить signing handle:

```bash
SIGNING_HANDLE="$(
  tpm2_getcap handles-transient \
  | awk '/0x/ {print $2}' \
  | tail -1
)"

echo "$SIGNING_HANDLE"
```

## 5.3 Positive test

```bash
echo "TPM Lab signing test" > message.txt
```

Подписать:

```bash
tpm2_sign \
  -c "$SIGNING_HANDLE" \
  -g sha256 \
  -o signature.bin \
  message.txt
```

Проверить:

```bash
if tpm2_verifysignature \
    -c "$SIGNING_HANDLE" \
    -g sha256 \
    -s signature.bin \
    -m message.txt; then
    echo "[PASS] Original message signature is valid"
else
    echo "[FAIL] Original message verification failed"
fi
```

## 5.4 Negative test

Создать изменённое сообщение:

```bash
echo "TPM Lab signing test TAMPERED" > tampered.txt
```

Использовать ту же подпись:

```bash
if tpm2_verifysignature \
    -c "$SIGNING_HANDLE" \
    -g sha256 \
    -s signature.bin \
    -m tampered.txt; then
    echo "[FAIL] Tampered message was accepted"
else
    echo "[PASS] Tampered message rejected as expected"
fi
```

Во время реального Sprint 02 TPM вернул:

```text
0x2DB
the signature is not valid
```

Ошибка TPM здесь является ожидаемым результатом negative test.

### Что сказать преподавателю

> Ключ используется через TPM object. Оригинальное сообщение проходит
> проверку, а изменённое сообщение с той же подписью TPM отвергает.

После test:

```bash
tpm2_flushcontext -t >/dev/null 2>&1 || true
```

---

# TEST 6. Basic Seal / Unseal

```bash
mkdir -p /lab/sealing
cd /lab/sealing
rm -f ./*
```

Primary:

```bash
tpm2_createprimary \
  -C o \
  -G rsa \
  -c primary.ctx
```

Handle:

```bash
PRIMARY_HANDLE="$(
  tpm2_getcap handles-transient \
  | awk '/0x/ {print $2}' \
  | head -1
)"
```

Secret:

```bash
echo -n "SUPER_SECRET_TPM_LAB" > secret.txt
```

Создать sealed object:

```bash
tpm2_create \
  -C "$PRIMARY_HANDLE" \
  -i secret.txt \
  -u sealed.pub \
  -r sealed.priv
```

Load:

```bash
tpm2_load \
  -C "$PRIMARY_HANDLE" \
  -u sealed.pub \
  -r sealed.priv \
  -c sealed.ctx
```

Handle sealed object:

```bash
SEALED_HANDLE="$(
  tpm2_getcap handles-transient \
  | awk '/0x/ {print $2}' \
  | tail -1
)"
```

Unseal:

```bash
tpm2_unseal -c "$SEALED_HANDLE"
```

Ожидаемый secret:

```text
SUPER_SECRET_TPM_LAB
```

### Что сказать преподавателю

> Сначала отдельно проверили базовый Seal/Unseal, прежде чем добавлять
> зависимость от PCR policy.

После:

```bash
tpm2_flushcontext -t >/dev/null 2>&1 || true
```

---

# TEST 7. PCR-bound Seal / Unseal

Это основной policy experiment.

```bash
mkdir -p /lab/pcr-sealing
cd /lab/pcr-sealing
rm -f ./*
```

Reset laboratory PCR:

```bash
tpm2_pcrreset 16
```

Trusted state:

```bash
tpm2_pcrread sha256:16
```

## 7.1 Создать parent

```bash
tpm2_createprimary \
  -C o \
  -G rsa \
  -c primary.ctx
```

```bash
PRIMARY_HANDLE="$(
  tpm2_getcap handles-transient \
  | awk '/0x/ {print $2}' \
  | head -1
)"
```

## 7.2 Сохранить trusted PCR

```bash
tpm2_pcrread \
  -o pcr.dat \
  sha256:16
```

## 7.3 Создать PCR policy

```bash
tpm2_createpolicy \
  --policy-pcr \
  -l sha256:16 \
  -f pcr.dat \
  -L pcr.policy
```

Во время Sprint 02 для нулевого PCR 16 был получен policy digest:

```text
bff2d58e9813f97cefc14f72ad8133bc7092d652b7c877959254af140c841f36
```

## 7.4 Создать policy-bound object

```bash
echo -n "PCR_BOUND_SECRET" > secret.txt
```

```bash
tpm2_create \
  -C "$PRIMARY_HANDLE" \
  -L pcr.policy \
  -i secret.txt \
  -u sealed.pub \
  -r sealed.priv
```

Load:

```bash
tpm2_load \
  -C "$PRIMARY_HANDLE" \
  -u sealed.pub \
  -r sealed.priv \
  -c sealed.ctx
```

```bash
SEALED_HANDLE="$(
  tpm2_getcap handles-transient \
  | awk '/0x/ {print $2}' \
  | tail -1
)"
```

## 7.5 Trusted policy session

```bash
tpm2_startauthsession \
  --policy-session \
  -S trusted-session.ctx
```

```bash
tpm2_policypcr \
  -S trusted-session.ctx \
  -l sha256:16 \
  -f pcr.dat
```

Unseal:

```bash
tpm2_unseal \
  -c "$SEALED_HANDLE" \
  -p session:trusted-session.ctx
```

Ожидаемо:

```text
PCR_BOUND_SECRET
```

Flush policy session:

```bash
tpm2_flushcontext trusted-session.ctx
```

## 7.6 Изменить PCR

Создать artificial measurement:

```bash
MEASUREMENT="$(
  echo -n "TAMPERED PLATFORM STATE" \
  | sha256sum \
  | awk '{print $1}'
)"
```

Показать до:

```bash
tpm2_pcrread sha256:16
```

Extend:

```bash
tpm2_pcrextend "16:sha256=$MEASUREMENT"
```

Показать после:

```bash
tpm2_pcrread sha256:16
```

Во время Sprint 02 после данного measurement наблюдалось:

```text
004A4BA3E0B0C25FDF42989282DA4821C5F821BCBFD3F15723C5153EFDCD1049
```

## 7.7 Tampered policy session

```bash
tpm2_startauthsession \
  --policy-session \
  -S tampered-session.ctx
```

```bash
tpm2_policypcr \
  -S tampered-session.ctx \
  -l sha256:16
```

Во время Sprint 02 policy digest стал:

```text
3d5ddd4e3b812605c2bd6436821a88674bf888e395026aa47772810b404f9f1c
```

Попытка Unseal:

```bash
tpm2_unseal \
  -c "$SEALED_HANDLE" \
  -p session:tampered-session.ctx
```

Ожидаемый security result:

```text
TPM rejects operation
```

Во время Sprint 02:

```text
0x99D
a policy check failed
```

### Что сказать преподавателю

> Один и тот же sealed object можно открыть в trusted PCR state.
> После реального PCR Extend TPM policy больше не удовлетворяется,
> поэтому уже TPM сам запрещает Unseal.

---

# TEST 8. Полностью автоматизированный runner

Для обычного повторного запуска ручные команды выше не нужны.

Выйти из интерактивного container:

```bash
exit
```

Команды снова выполняются на macOS из корня repo.

Создать host evidence directory:

```bash
mkdir -p evidence
```

Запустить:

```bash
docker run --rm \
  -v "$PWD/evidence:/evidence" \
  -e EVIDENCE_ROOT=/evidence \
  tpm-lab-demo \
  /lab/run-all.sh
```

Runner сам:

1. поднимает чистый swtpm;
2. проверяет ARM64;
3. проверяет TPM Discovery;
4. вызывает GetRandom;
5. делает PCR Extend;
6. независимо рассчитывает expected PCR;
7. создаёт TPM-backed RSA key;
8. проверяет original signature;
9. проверяет rejection tampered message;
10. делает Seal/Unseal;
11. строит PCR policy;
12. проверяет trusted Unseal;
13. меняет PCR;
14. проверяет реальный TPM policy rejection;
15. сохраняет raw evidence.

Успешный результат:

```text
PASS checks: 10
FAIL checks: 0

TPM LAB ARM64 PROTOTYPE: PASS
```

Evidence остаётся на host:

```bash
ls -R evidence
```

В отличие от файлов только внутри `docker run --rm`, эти данные не
исчезнут после удаления container.

---

# Быстрый запуск перед демонстрацией

Из корня repo:

```bash
docker build \
  -t tpm-lab-demo \
  -f infra/docker-tpm/Dockerfile \
  .

mkdir -p evidence

docker run --rm \
  -v "$PWD/evidence:/evidence" \
  -e EVIDENCE_ROOT=/evidence \
  tpm-lab-demo \
  /lab/run-all.sh
```

Этого достаточно для повторения полного Sprint 02 technical spike.
