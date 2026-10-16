#!/usr/bin/env bash
# Reproducible Apple Silicon lab:
#   macOS -> QEMU virt (HVF) -> Ubuntu 24.04 ARM64 -> /dev/tpmrm0 -> swtpm
#
# Runtime files stay in infra/vm/runtime and are not committed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNTIME="${RUNTIME:-$ROOT/infra/vm/runtime}"
BASE_DIR="$RUNTIME/base"
IMAGE_NAME="noble-server-cloudimg-arm64.img"
IMAGE_URL="${IMAGE_URL:-https://cloud-images.ubuntu.com/noble/current/${IMAGE_NAME}}"
SUMS_URL="${SUMS_URL:-https://cloud-images.ubuntu.com/noble/current/SHA256SUMS}"

SSH_PORT="${SSH_PORT:-22222}"
SSH_USER="ubuntu"
MEM_MB="${MEM_MB:-2048}"
SMP="${SMP:-2}"

FIRMWARE="${FIRMWARE:-/opt/homebrew/share/qemu/edk2-aarch64-code.fd}"
QEMU="${QEMU:-qemu-system-aarch64}"

BASE_IMG="$BASE_DIR/$IMAGE_NAME"
OVERLAY="$RUNTIME/disk.qcow2"
SEED_ISO="$RUNTIME/seed.iso"
VARS="$RUNTIME/edk2-vars.fd"
SSH_DIR="$RUNTIME/ssh"
SSH_KEY="$SSH_DIR/id_ed25519"
SWTPM_DIR="$RUNTIME/swtpm"
SWTPM_SOCK="$SWTPM_DIR/swtpm.sock"
SWTPM_PID="$RUNTIME/swtpm.pid"
QEMU_PID="$RUNTIME/qemu.pid"
CONSOLE_LOG="$RUNTIME/console.log"
EVIDENCE="$RUNTIME/evidence"

mkdir -p "$BASE_DIR" "$RUNTIME" "$SSH_DIR" "$SWTPM_DIR" "$EVIDENCE"

log() {
    printf '[vm] %s\n' "$*"
}

die() {
    printf '[vm] ERROR: %s\n' "$*" >&2
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

stop_pidfile() {
    local pidfile="$1"
    local name="$2"
    if [[ -f "$pidfile" ]]; then
        local pid
        pid="$(cat "$pidfile")"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log "stopping $name pid $pid"
            kill "$pid" 2>/dev/null || true
            for _ in $(seq 1 30); do
                kill -0 "$pid" 2>/dev/null || break
                sleep 0.2
            done
            kill -9 "$pid" 2>/dev/null || true
        fi
        rm -f "$pidfile"
    fi
}

stop_lab() {
    if [[ -f "$QEMU_PID" ]]; then
        stop_pidfile "$QEMU_PID" qemu
    fi
    stop_pidfile "$SWTPM_PID" swtpm
    rm -f "$SWTPM_SOCK"
}

image_checksum_ok() {
    local line
    line="$(grep -E "[ *]${IMAGE_NAME}$" "$BASE_DIR/SHA256SUMS" || true)"
    [[ -n "$line" ]] || return 1
    [[ -f "$BASE_IMG" ]] || return 1
    (cd "$BASE_DIR" && printf '%s\n' "$line" | shasum -a 256 -c -)
}

fetch_image() {
    need curl
    need shasum
    if [[ ! -f "$BASE_DIR/SHA256SUMS" ]]; then
        curl -fsSL -o "$BASE_DIR/SHA256SUMS" "$SUMS_URL"
    fi
    if image_checksum_ok; then
        log "base image already matches SHA256SUMS"
        return
    fi
    log "downloading cloud image"
    curl -fsSL -o "$BASE_DIR/SHA256SUMS" "$SUMS_URL"
    curl -fL --retry 3 -o "$BASE_IMG.partial" "$IMAGE_URL"
    mv "$BASE_IMG.partial" "$BASE_IMG"
    image_checksum_ok || die "downloaded image failed SHA256 check"
}

make_ssh_key() {
    if [[ ! -f "$SSH_KEY" ]]; then
        ssh-keygen -t ed25519 -N "" -C "tpm-lab-vm" -f "$SSH_KEY" >/dev/null
    fi
}

make_seed() {
    need xorriso
    make_ssh_key
    local src pub
    src="$RUNTIME/cidata"
    rm -rf "$src"
    mkdir -p "$src"
    pub="$(cat "$SSH_KEY.pub")"
    cat >"$src/meta-data" <<EOF
instance-id: tpm-lab-vtpm
local-hostname: tpm-lab
EOF
    cat >"$src/user-data" <<EOF
#cloud-config
hostname: tpm-lab
users:
  - name: ${SSH_USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - ${pub}
ssh_pwauth: false
package_update: true
packages:
  - tpm2-tools
  - openssh-server
runcmd:
  - [bash, -lc, "modprobe tpm_tis || true; usermod -aG tss ubuntu || true; exit 0"]
EOF
    rm -f "$SEED_ISO"
    xorriso -as mkisofs \
        -output "$SEED_ISO" \
        -volid cidata \
        -joliet \
        -rock \
        "$src/user-data" \
        "$src/meta-data"
}

make_overlay() {
    need qemu-img
    rm -f "$OVERLAY"
    qemu-img create -f qcow2 -b "$BASE_IMG" -F qcow2 "$OVERLAY" 16G
}

make_vars() {
    if [[ -s "$VARS" ]]; then
        return
    fi
    # EDK2 variable store is erased flash: 0xFF, same size as the code image.
    python3 - "$VARS" "$FIRMWARE" <<'PY'
import pathlib, sys
dest = pathlib.Path(sys.argv[1])
size = pathlib.Path(sys.argv[2]).stat().st_size
dest.write_bytes(b"\xff" * size)
PY
}

start_swtpm() {
    need swtpm
    rm -rf "$SWTPM_DIR"
    mkdir -p "$SWTPM_DIR"
    # QEMU sends CMD_INIT. Guest firmware/kernel owns TPM2_Startup.
    # Do not pass startup-clear: that flag belongs to the direct-socket spike.
    swtpm socket \
        --tpm2 \
        --tpmstate "dir=$SWTPM_DIR" \
        --ctrl "type=unixio,path=$SWTPM_SOCK" \
        --log "file=$RUNTIME/swtpm.log,level=20" \
        --pid "file=$SWTPM_PID" \
        --daemon
    for _ in $(seq 1 50); do
        [[ -S "$SWTPM_SOCK" ]] && return
        sleep 0.1
    done
    die "swtpm socket did not appear: $SWTPM_SOCK"
}

boot_qemu() {
    need "$QEMU"
    [[ -f "$FIRMWARE" ]] || die "UEFI firmware not found: $FIRMWARE"
    if ! python3 - "$SSH_PORT" <<'PY'
import socket, sys
s = socket.socket()
try:
    s.bind(("127.0.0.1", int(sys.argv[1])))
except OSError:
    raise SystemExit(1)
finally:
    s.close()
PY
    then
        die "TCP port $SSH_PORT is already in use"
    fi
    make_vars
    local cmd=(
        "$QEMU"
        -machine "virt,accel=hvf,gic-version=3"
        -cpu host
        -smp "$SMP"
        -m "$MEM_MB"
        -drive "if=pflash,format=raw,unit=0,readonly=on,file=$FIRMWARE"
        -drive "if=pflash,format=raw,unit=1,file=$VARS"
        -drive "if=virtio,format=qcow2,file=$OVERLAY"
        -drive "if=virtio,format=raw,file=$SEED_ISO"
        -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22"
        -device virtio-net-pci,netdev=net0
        -device virtio-rng-pci
        -chardev "socket,id=chrtpm,path=$SWTPM_SOCK"
        -tpmdev emulator,id=tpm0,chardev=chrtpm
        -device tpm-tis-device,tpmdev=tpm0
        -nographic
        -serial mon:stdio
    )
    printf '%q ' "${cmd[@]}" >"$RUNTIME/qemu-command.txt"
    printf '\n' >>"$RUNTIME/qemu-command.txt"
    : >"$CONSOLE_LOG"
    # Double-fork so QEMU survives when this shell exits.
    python3 - "$QEMU_PID" "$CONSOLE_LOG" -- "${cmd[@]}" <<'PY'
import os
import sys

pidfile = sys.argv[1]
logpath = sys.argv[2]
cmd = sys.argv[sys.argv.index("--") + 1 :]
if os.fork() > 0:
    os._exit(0)
os.setsid()
grandchild = os.fork()
if grandchild > 0:
    with open(pidfile, "w", encoding="utf-8") as handle:
        handle.write(str(grandchild))
    os._exit(0)
log = os.open(logpath, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)
os.dup2(log, 1)
os.dup2(log, 2)
devnull = os.open(os.devnull, os.O_RDONLY)
os.dup2(devnull, 0)
os.execvp(cmd[0], cmd)
PY
    for _ in $(seq 1 50); do
        [[ -s "$QEMU_PID" ]] && break
        sleep 0.1
    done
    [[ -s "$QEMU_PID" ]] || die "qemu pid file was not written"
    log "qemu pid $(cat "$QEMU_PID"), console $CONSOLE_LOG"
}

ssh_cmd() {
    ssh \
        -i "$SSH_KEY" \
        -p "$SSH_PORT" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o IdentitiesOnly=yes \
        -o ConnectTimeout=5 \
        -o LogLevel=ERROR \
        "${SSH_USER}@127.0.0.1" \
        "$@"
}

wait_ssh() {
    local tries="${1:-180}"
    log "waiting for ssh on port $SSH_PORT"
    for _ in $(seq 1 "$tries"); do
        if ssh_cmd true 2>/dev/null; then
            log "ssh is up"
            return
        fi
        if [[ -f "$QEMU_PID" ]] && ! kill -0 "$(cat "$QEMU_PID")" 2>/dev/null; then
            die "qemu exited before ssh. See $CONSOLE_LOG"
        fi
        sleep 5
    done
    die "ssh did not become ready. See $CONSOLE_LOG"
}

run_guest() {
    log "waiting for cloud-init"
    # A failed runcmd (for example modprobe when the driver is built-in)
    # must not hide later TPM checks. tpm2-tools being installed is the gate.
    ssh_cmd 'cloud-init status --wait || true'
    ssh_cmd 'command -v tpm2_getcap >/dev/null'
    log "guest discovery"
    ssh_cmd 'bash -s' <"$ROOT/infra/vm/guest-discover.sh" | tee "$EVIDENCE/discover.txt"
    log "copying shared checks"
    scp \
        -i "$SSH_KEY" \
        -P "$SSH_PORT" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o IdentitiesOnly=yes \
        -o LogLevel=ERROR \
        "$ROOT/infra/docker-tpm/run-checks.sh" \
        "${SSH_USER}@127.0.0.1:/tmp/run-checks.sh"
    log "running shared checks through /dev/tpmrm0"
    ssh_cmd 'sudo mkdir -p /var/tmp/tpm-evidence && sudo TPM2TOOLS_TCTI=device:/dev/tpmrm0 EVIDENCE_ROOT=/var/tmp/tpm-evidence bash /tmp/run-checks.sh' \
        | tee "$EVIDENCE/run-checks.txt"
    ssh_cmd 'sudo tar -C /var/tmp -czf - tpm-evidence' >"$EVIDENCE/guest-evidence.tar.gz" || true
}

usage() {
    cat <<EOF
Usage: $0 {up|resume|checks|stop|reset}

  up      download image if needed, boot a clean VM, run checks, leave it running
  resume  boot the existing overlay against the current swtpm state and run checks
  checks  re-run guest checks against an already running VM
  stop    stop qemu and swtpm, keep disk and TPM state
  reset   stop and delete overlay, TPM state, evidence (base image stays)
EOF
}

cmd="${1:-up}"
case "$cmd" in
    up)
        need "$QEMU"
        fetch_image
        stop_lab
        make_seed
        make_overlay
        start_swtpm
        boot_qemu
        wait_ssh
        run_guest
        log "VM left running. SSH:"
        log "ssh -i $SSH_KEY -p $SSH_PORT ${SSH_USER}@127.0.0.1"
        log "Stop: $0 stop"
        ;;
    resume)
        [[ -f "$OVERLAY" ]] || die "no overlay; run $0 up first"
        [[ -S "$SWTPM_SOCK" ]] || die "swtpm socket missing; run $0 up first"
        if [[ -f "$QEMU_PID" ]] && kill -0 "$(cat "$QEMU_PID")" 2>/dev/null; then
            die "qemu is already running"
        fi
        rm -f "$QEMU_PID"
        mkdir -p "$EVIDENCE"
        if [[ -s "$CONSOLE_LOG" ]]; then
            cp "$CONSOLE_LOG" "$EVIDENCE/console-first-boot.log"
        fi
        boot_qemu
        wait_ssh
        run_guest
        log "VM left running. SSH:"
        log "ssh -i $SSH_KEY -p $SSH_PORT ${SSH_USER}@127.0.0.1"
        ;;
    checks)
        run_guest
        ;;
    stop)
        stop_lab
        log "stopped"
        ;;
    reset)
        stop_lab
        rm -rf "$OVERLAY" "$SWTPM_DIR" "$EVIDENCE" "$VARS" "$RUNTIME/cidata" "$SEED_ISO" \
            "$RUNTIME/swtpm.log" "$CONSOLE_LOG" "$RUNTIME/qemu-command.txt"
        mkdir -p "$EVIDENCE"
        log "reset complete (base image kept)"
        ;;
    *)
        usage
        exit 2
        ;;
esac
