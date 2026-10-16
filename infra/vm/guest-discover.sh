#!/usr/bin/env bash
# Runs inside the Ubuntu guest. Prints the environment facts used as evidence.
set -u

echo "===== uname ====="
uname -a
echo "===== os-release ====="
. /etc/os-release
printf 'PRETTY_NAME=%s\n' "$PRETTY_NAME"
printf 'VERSION_ID=%s\n' "$VERSION_ID"
echo "===== identity ====="
id
echo "===== tpm nodes ====="
ls -l /dev/tpm0 /dev/tpmrm0 2>&1 || true
echo "===== tpm dmesg ====="
sudo dmesg | grep -i -E 'tpm|tis' || true
echo "===== tcti ====="
export TPM2TOOLS_TCTI="${TPM2TOOLS_TCTI:-device:/dev/tpmrm0}"
printf 'TPM2TOOLS_TCTI=%s\n' "$TPM2TOOLS_TCTI"
if ! command -v tpm2_getcap >/dev/null 2>&1; then
    echo "tpm2_getcap is not installed"
    exit 1
fi
# /dev/tpmrm0 is group tss. Root can open it before the lab user is in that group.
if ! sudo TPM2TOOLS_TCTI="$TPM2TOOLS_TCTI" tpm2_getcap properties-fixed > /tmp/tpm-lab-properties.txt 2>/tmp/tpm-lab-properties.err; then
    cat /tmp/tpm-lab-properties.err
    exit 1
fi
awk '
    /TPM2_PT_FAMILY_INDICATOR|TPM2_PT_MANUFACTURER|TPM2_PT_REVISION|TPM2_PT_PCR_COUNT/ {show=1}
    show {print}
    show && /value:/ {show=0}
' /tmp/tpm-lab-properties.txt
echo "===== getrandom ====="
sudo TPM2TOOLS_TCTI="$TPM2TOOLS_TCTI" tpm2_getrandom -o /tmp/tpm-lab-random.bin 8
sudo wc -c /tmp/tpm-lab-random.bin
sudo od -An -tx1 /tmp/tpm-lab-random.bin
