#!/usr/bin/env bash

set -u
set -o pipefail

export TPM2TOOLS_TCTI="${TPM2TOOLS_TCTI:-mssim:host=127.0.0.1,port=2321}"

RUN_ID="$(date +%Y%m%d-%H%M%S)"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-/lab/evidence}"
EVIDENCE="${EVIDENCE_ROOT}/${RUN_ID}"

mkdir -p "$EVIDENCE"
export RUN_ID EVIDENCE EVIDENCE_ROOT

echo
echo "============================================================"
echo "             TPM LAB — ARM64 TECHNICAL SPIKE"
echo "============================================================"
echo "Run:      $RUN_ID"
echo "Backend:  ms-tpm-20-ref"
echo "TCTI:     $TPM2TOOLS_TCTI"
echo "Evidence: $EVIDENCE"
echo

if ! /usr/local/bin/start-mssim >"$EVIDENCE/start-mssim.log" 2>&1; then
    cat "$EVIDENCE/start-mssim.log"
    echo "[FATAL] Unable to start ms-tpm-20-ref simulator"
    exit 1
fi

cat "$EVIDENCE/start-mssim.log"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run-checks.sh"
