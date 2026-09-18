#!/usr/bin/env bash
set -euo pipefail

TPM_STATE_DIR="${TPM_STATE_DIR:-/tmp/tpmstate}"
TPM_HOST="${TPM_HOST:-127.0.0.1}"
TPM_PORT="${TPM_PORT:-2321}"
TPM_CTRL_PORT="${TPM_CTRL_PORT:-2322}"

export TPM2TOOLS_TCTI="${TPM2TOOLS_TCTI:-swtpm:host=${TPM_HOST},port=${TPM_PORT}}"

# Для воспроизводимого lab run начинаем с чистого software TPM state.
pkill swtpm >/dev/null 2>&1 || true

rm -rf "$TPM_STATE_DIR"
mkdir -p "$TPM_STATE_DIR"

swtpm socket \
  --tpm2 \
  --tpmstate dir="$TPM_STATE_DIR" \
  --server type=tcp,port="$TPM_PORT",bindaddr="$TPM_HOST" \
  --ctrl type=tcp,port="$TPM_CTRL_PORT",bindaddr="$TPM_HOST" \
  --flags not-need-init,startup-clear \
  --daemon

# Ждём готовности TPM, а не используем произвольный sleep.
for _ in $(seq 1 50); do
    if tpm2_getcap properties-fixed >/dev/null 2>&1; then
        echo "[READY] swtpm TPM 2.0 is reachable via $TPM2TOOLS_TCTI"
        exit 0
    fi
    sleep 0.1
done

echo "[ERROR] swtpm did not become ready" >&2
exit 1
