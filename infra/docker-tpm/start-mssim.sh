#!/usr/bin/env bash
set -euo pipefail

TPM_STATE_DIR="${TPM_STATE_DIR:-/tmp/mssim-state}"
TPM_HOST="${TPM_HOST:-127.0.0.1}"
TPM_PORT="${TPM_PORT:-2321}"
TPM_PLATFORM_PORT="${TPM_PLATFORM_PORT:-2322}"
SIMULATOR="${SIMULATOR:-/opt/ms-tpm-20-ref/tpm2-simulator}"
PID_FILE="${PID_FILE:-/tmp/mssim.pid}"

export TPM2TOOLS_TCTI="${TPM2TOOLS_TCTI:-mssim:host=${TPM_HOST},port=${TPM_PORT}}"

if [[ ! -x "$SIMULATOR" ]]; then
    echo "[ERROR] Simulator binary is missing: $SIMULATOR" >&2
    exit 1
fi

if [[ -f "$PID_FILE" ]]; then
    old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "${old_pid}" ]]; then
        kill "$old_pid" >/dev/null 2>&1 || true
    fi
fi
pkill -x tpm2-simulator >/dev/null 2>&1 || true
sleep 0.2

rm -rf "$TPM_STATE_DIR"
mkdir -p "$TPM_STATE_DIR"

# NVChip is created in the process working directory. A fresh directory is a
# fresh software TPM, then --manufacture initializes it explicitly.
(
    cd "$TPM_STATE_DIR"
    nohup "$SIMULATOR" --manufacture \
        >"$TPM_STATE_DIR/simulator.log" 2>&1 </dev/null &
    echo $! >"$PID_FILE"
)

sim_pid="$(cat "$PID_FILE")"

if ! python3 - "$TPM_HOST" "$TPM_PORT" "$sim_pid" <<'PY'
import socket
import sys
import time

host = sys.argv[1]
port = int(sys.argv[2])
pid = int(sys.argv[3])

def alive():
    try:
        import os
        os.kill(pid, 0)
        return True
    except OSError:
        return False

for _ in range(100):
    if not alive():
        sys.exit(2)
    try:
        sock = socket.create_connection((host, port), timeout=0.2)
        sock.close()
        sys.exit(0)
    except OSError:
        time.sleep(0.1)
sys.exit(1)
PY
then
    echo "[ERROR] ms-tpm-20-ref simulator did not open port ${TPM_PORT}" >&2
    cat "$TPM_STATE_DIR/simulator.log" >&2 || true
    exit 1
fi

python3 - "$TPM_HOST" "$TPM_PLATFORM_PORT" <<'PY'
import socket
import struct
import sys

host = sys.argv[1]
port = int(sys.argv[2])

# Microsoft simulator control port. Each signal is one big-endian uint32.
# Ack is one big-endian uint32; 0 means the platform accepted the signal.
# SESSION_END closes the socket without an ack, so it is not sent here.
POWER_ON = 1
NV_ON = 11

sock = socket.create_connection((host, port), timeout=5)

def send(code):
    sock.sendall(struct.pack(">I", code))
    data = sock.recv(4)
    if len(data) != 4:
        raise SystemExit(f"[ERROR] short platform ack for command {code}: {data!r}")
    ack = struct.unpack(">I", data)[0]
    print(f"[PLATFORM] command {code} ack={ack}")
    if ack != 0:
        raise SystemExit(f"[ERROR] platform command {code} failed with ack {ack}")

send(POWER_ON)
send(NV_ON)
sock.close()
PY

if ! tpm2_startup -c >"$TPM_STATE_DIR/startup.log" 2>&1; then
    echo "[ERROR] TPM2_Startup(CLEAR) failed" >&2
    cat "$TPM_STATE_DIR/startup.log" >&2 || true
    cat "$TPM_STATE_DIR/simulator.log" >&2 || true
    exit 1
fi

for _ in $(seq 1 50); do
    if tpm2_getcap properties-fixed >/dev/null 2>&1; then
        echo "[READY] ms-tpm-20-ref TPM 2.0 is reachable via $TPM2TOOLS_TCTI"
        if [[ -f /opt/ms-tpm-20-ref/REVISION ]]; then
            echo "[REVISION] $(cat /opt/ms-tpm-20-ref/REVISION)"
        fi
        exit 0
    fi
    sleep 0.1
done

echo "[ERROR] ms-tpm-20-ref simulator did not become ready" >&2
cat "$TPM_STATE_DIR/simulator.log" >&2 || true
exit 1
