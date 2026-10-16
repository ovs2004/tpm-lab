# Sprint 04 — QEMU ARM64 virtual TPM

## Sprint goal

Вернуться к целевой среде:

```text
Mac Apple Silicon
 ->
QEMU ARM64 VM
 ->
Ubuntu
 ->
virtual TPM device
 ->
swtpm
```

Обязательный результат — design note ARCH-005: конфигурация VM,
подключение `swtpm`, reset и открытые вопросы. Развёртывание VM
входило в спринт, потому что этого описания достаточно для
повторяемой установки.

Параллельно, не вместо VM: тонкий ESAPI-модуль поверх уже
проверенного simulator socket.

## Planned

* ARCH-005: design note;
* воспроизводимый запуск Ubuntu 24.04 ARM64 в QEMU на Apple Silicon;
* virtual TPM через `swtpm` и устройство в госте;
* reset/re-run;
* тот же набор проверок, что Sprint 02, но через `/dev/tpmrm0`;
* если VM не блокирует остальное — модуль `tpm2-pytss` на сокете.

## Completed

### Design note

[ARCH-005](../labs/qemu-arm64-vtpm.md) фиксирует машину `virt` + HVF,
`tpm-tis-device`, unix socket swtpm и отличие от direct-socket spike:
`TPM2_Startup` делает гость, не флаг `startup-clear`.

UTM 4.6.4 установлен. Лабораторный путь — та же модель QEMU
скриптом, чтобы reset был повторяемым. Apple Virtualization
не используется: у него нет virtual TPM. Устройства `tpm-crb-device`
в QEMU 10.1.0 для aarch64 нет.

### Работающий гость

Прогон `infra/vm/run-lab.sh up` на этом Mac:

```text
Linux tpm-lab 6.8.0-142-generic aarch64
PRETTY_NAME=Ubuntu 24.04.5 LTS
uid=1000(ubuntu) groups=1000(ubuntu),111(tss)
/dev/tpm0    tss:root
/dev/tpmrm0  tss:tss
tpm_tis MSFT0101:00: 2.0 TPM (device-id 0x1, rev-id 1)
```

Discovery через `device:/dev/tpmrm0`:

```text
Family:         value: "2.0"
Manufacturer:   value: "IBM"
PCR count:      raw: 0x18
Revision:       1.83
```

`IBM` / `1.83` — swtpm 0.10.2 на host. Гость ходит в устройство,
не в TCP-сокет simulator.

Общий runner внутри гостя:

```text
PASS checks: 10
FAIL checks: 0

TPM LAB ARM64 PROTOTYPE: PASS
```

PCR Extend совпал с независимым SHA-256. Подпись отвергла
испорченное сообщение. PCR policy отвергла Unseal после Extend.
Коды те же, что на сокете: `0x2DB` и `0x99D`.

Первая попытка signing через resource manager не нашла transient
handle: `/dev/tpmrm0` их не публикует. Runner берёт context file,
если `handles-transient` пуст. Повтор на сокете swtpm после этой
правки: снова 10 PASS / 0 FAIL.

### ESAPI-модуль на сокете

`src/tpm_lab/` вызывает TPM через `tpm2-pytss`, без `tpm2-tools`.
Образ `infra/docker-tpm/Dockerfile.pytss`.

```text
PASS checks: 10
FAIL checks: 0
TPM LAB ESAPI MODULE: PASS
```

В этом прогоне есть две сверки, которых нет у shell runner:
`TPM2_Hash` совпал с `hashlib.sha256`, подпись TPM принял OpenSSL.
Отказы те же: `0x2DB` и `0x99D`. Модуль ходит в сокет и не заменяет
VM.

Запуск:

```bash
docker build -t tpm-lab-pytss -f infra/docker-tpm/Dockerfile.pytss .
docker run --rm tpm-lab-pytss
```

### Одна PCR-операция через ESAPI и FAPI

Секрет `PCR_BOUND_SECRET` запечатан к нулевому PCR 16 дважды.
Запись: [ESAPI, FAPI и ключ Кузнечика](../labs/fapi-esapi-kuznyechik.md).

ESAPI — вызовы в `src/tpm_lab/ops.py`: primary, policy session,
Create/Load, Unseal, flush. После Extend Unseal возвращает `0x99D`.

FAPI на Ubuntu 24.04 — команды `tss2` в `libtss2-fapi`.
Python-привязка FAPI в пакете `python3-tpm2-pytss` отключена.
Команды: provision, import policy, createseal, unseal, pcrextend, unseal.
После Extend TPM отклоняет `PolicyPCR` с `0x1C4`. Секрет не выходит.
Это другой слой ошибки, не другое правило доступа.

### Кузнечик снаружи TPM

`tpm2_getcap algorithms` на этом swtpm показывает AES и Camellia.
Кузнечика в списке нет. Блок считает `src/tpm_lab/kuznyechik.py`
по ГОСТ Р 34.12-2015. Вектор RFC 7801 совпал:
`7f679d90bebc24305a468d42b9d4edcd`.

Ключ на 32 байта берётся из `TPM2_GetRandom` и seal к PCR 16.
После Extend ключ не выходит, код `0x99D`.

Общий прогон этих трёх частей:

```text
PASS checks: 8
FAIL checks: 0
FAPI ESAPI KUZNYECHIK: PASS
```

```bash
docker run --rm --entrypoint /lab/run-fapi-kuznyechik.sh tpm-lab-pytss
```

## Evidence highlights

### Устройство

```text
ACPI: TPM2
tpm_tis MSFT0101:00: 2.0 TPM (device-id 0x1, rev-id 1)
```

### PCR через /dev/tpmrm0

```text
Expected   : 1D3224D51365587C3F5A3247630EF892C14B673AF376E61703C15115223232D2
PCR after  : 1D3224D51365587C3F5A3247630EF892C14B673AF376E61703C15115223232D2
```

### Policy

```text
Trusted PCR state allows Unseal
Tampered PCR state rejected by TPM policy
```

## Current limitations

* UTM GUI-профиль не экспортирован. Повторяется командная строка QEMU.
* Второй студент ещё не прогнал `run-lab.sh up` у себя.
* Кузнечик не является командой TPM. Шифр считает программа.
* Quote и LUKS не делались.
* `kill -9` по QEMU портит гостевой `dpkg`. Остановка — `run-lab.sh stop`.
* Образ диска, ключ SSH и состояние swtpm в git не входят. Их создаёт `run-lab.sh`.

## Next sprint

План встройки Кузнечика в эмулятор, рядом с AES и Camellia:
[Кузнечик внутри TPM](../labs/kuznyechik-inside-tpm.md).

Отдельно разобрано, что можно взять в облаке. Google Shielded VM, Azure Trusted Launch и AWS NitroTPM дают виртуальный TPM 2.0 у машины, не отдельный чип. Туда переносится discovery и, если PCR доступен, тот же seal. Свой шифр в облачный TPM не вставляется. Запись: [облачный TPM](../research/cloud-vtpm.md).

Рядом остаётся закрытие Stage 1:

* второй участник повторяет `infra/vm/run-lab.sh up`;
* architecture v0.1 и ТЗ сверяются с фактическими версиями и TCTI
  `device:/dev/tpmrm0`.

## Slide-ready summary

```text
SPRINT 04 · QEMU ARM64 VIRTUAL TPM

Развёрнуто
Mac Apple Silicon
→ QEMU virt / HVF
→ Ubuntu 24.04.5 ARM64
→ /dev/tpmrm0
→ swtpm 0.10.2

Проверено тем же runner
Discovery · RNG · PCR · Signing · Seal/Unseal · PCR Policy

RESULT
10 PASS · 0 FAIL

Отличие от Docker spike
устройство tpm-tis · TCTI device · Startup делает гость
семантика PCR / 0x2DB / 0x99D совпала

Рядом
ESAPI на сокете · 10 PASS / 0 FAIL
ESAPI и FAPI, один PCR-seal · 0x99D и 0x1C4
Кузнечик снаружи, ключ в TPM

Дальше
Кузнечик внутри libtpms, как AES и Camellia
Облако: vTPM у VM, не отдельный чип
```

## Что публикуется

В git входят инструкции, скрипты и исходники. Образ диска VM, SSH-ключ, состояние `swtpm` и логи прогона остаются в `infra/vm/runtime/` и в `.gitignore`.

Преподавателю достаточно этих путей:

* `docs/sprints/sprint-04.md`
* `docs/demo-notes/sprint-04-defense.md`
* `docs/labs/qemu-arm64-vtpm.md` и `docs/labs/qemu-arm64-vtpm-runbook.md`
* `infra/vm/run-lab.sh`, `infra/vm/guest-discover.sh`
* `docs/labs/fapi-esapi-kuznyechik.md`
* `src/tpm_lab/`
* `infra/docker-tpm/Dockerfile.pytss`, `run-py-checks.sh`, `run-fapi-kuznyechik.sh`
* `docs/labs/kuznyechik-inside-tpm.md` — план, не результат
* `docs/research/cloud-vtpm.md` — исследование, стенд в облаке не поднимался
