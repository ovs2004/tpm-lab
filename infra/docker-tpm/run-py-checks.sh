#!/usr/bin/env bash
set -euo pipefail

start-swtpm
export TSS2_TCTI="${TSS2_TCTI:-swtpm:host=127.0.0.1,port=2321}"
export PYTHONPATH="${PYTHONPATH:-/lab/src}"
python3 -m tpm_lab.run_checks
