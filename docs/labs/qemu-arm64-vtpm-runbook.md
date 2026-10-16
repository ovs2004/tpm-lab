# Runbook: QEMU ARM64 + swtpm

Стенд Sprint 04. Design note: [ARCH-005](qemu-arm64-vtpm.md).

Команды выполняются на Mac из корня репозитория.

## Что нужно на host

* macOS Apple Silicon
* Homebrew `qemu` и `swtpm`
* `xorriso` (для cloud-init ISO)
* около 8 ГБ свободно под образ и overlay

Проверено с QEMU 10.1.0 и swtpm 0.10.2.

## Запуск

```bash
infra/vm/run-lab.sh up
```

Скрипт:

1. скачивает `noble-server-cloudimg-arm64.img`, если хеш не совпал;
2. делает SSH-ключ и cloud-init ISO с меткой `cidata`;
3. создаёт чистый overlay и пустое состояние swtpm;
4. запускает QEMU `virt` с `tpm-tis-device`;
5. ждёт SSH на порту 22222;
6. прогоняет discovery и общий `run-checks.sh` через `/dev/tpmrm0`.

Успех:

```text
PASS checks: 10
FAIL checks: 0
TPM LAB ARM64 PROTOTYPE: PASS
```

Машина остаётся запущенной. Войти:

```bash
ssh -i infra/vm/runtime/ssh/id_ed25519 -p 22222 ubuntu@127.0.0.1
```

Повторить только проверки:

```bash
infra/vm/run-lab.sh checks
```

Остановить, не удаляя диск:

```bash
infra/vm/run-lab.sh stop
```

Чистый повтор:

```bash
infra/vm/run-lab.sh reset
infra/vm/run-lab.sh up
```

Не завершать QEMU через `kill -9`. Незавершённый `dpkg` в госте
после такого убийства не чинится поверх того же overlay.

## Куда смотреть, если не поднялось

| Симптом | Куда смотреть |
| --- | --- |
| QEMU сразу вышел | `infra/vm/runtime/console.log` |
| Нет SSH | тот же лог, порт 22222, cloud-init |
| Нет `/dev/tpm0` | `dmesg` на строку `tpm_tis` |
| `Permission denied` на TPM | пользователь должен быть в группе `tss` |
| `handles-transient` пустой | это норма для `/dev/tpmrm0`; runner использует `*.ctx` |

Локальные образ, ключ, диск и логи лежат в `infra/vm/runtime/` и в git не коммитятся. В репозиторий входят скрипт `infra/vm/run-lab.sh`, `guest-discover.sh` и эта инструкция. Машину на другом Mac создаёт `run-lab.sh up`, готовый диск не переносится.
