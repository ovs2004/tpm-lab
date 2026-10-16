# VM

Воспроизводимый стенд Sprint 04: QEMU `virt` на Apple Silicon, Ubuntu 24.04 ARM64 и virtual TPM.

```bash
infra/vm/run-lab.sh up
```

Design note: [ARCH-005](../../docs/labs/qemu-arm64-vtpm.md).
Пошагово: [runbook](../../docs/labs/qemu-arm64-vtpm-runbook.md).

Образ, диск, SSH-ключ и логи остаются в `runtime/` и в git не коммитятся.
