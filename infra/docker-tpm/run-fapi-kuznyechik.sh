#!/usr/bin/env bash
set -euo pipefail

export TSS2_TCTI="${TSS2_TCTI:-swtpm:host=127.0.0.1,port=2321}"
export TPM2TOOLS_TCTI="$TSS2_TCTI"
export PYTHONPATH="${PYTHONPATH:-/lab/src}"
python3 -m tpm_lab.run_fapi_kuznyechik
