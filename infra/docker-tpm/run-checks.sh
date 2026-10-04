#!/usr/bin/env bash

set -u
set -o pipefail

: "${TPM2TOOLS_TCTI:?TPM2TOOLS_TCTI must be set and the TPM must already be running}"

PASS=0
FAIL=0

if [[ -z "${EVIDENCE:-}" ]]; then
    RUN_ID="$(date +%Y%m%d-%H%M%S)"
    EVIDENCE_ROOT="${EVIDENCE_ROOT:-/lab/evidence}"
    EVIDENCE="${EVIDENCE_ROOT}/${RUN_ID}"
    mkdir -p "$EVIDENCE"
fi

line() {
    printf '%s\n' "------------------------------------------------------------"
}

pass() {
    echo "[PASS] $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "[FAIL] $1"
    FAIL=$((FAIL + 1))
}

cleanup_objects() {
    tpm2_flushcontext -t >/dev/null 2>&1 || true
}

cleanup_sessions() {
    tpm2_flushcontext -l >/dev/null 2>&1 || true
    tpm2_flushcontext -s >/dev/null 2>&1 || true
}

cleanup_all() {
    cleanup_sessions
    cleanup_objects
}

get_transient_handles() {
    tpm2_getcap handles-transient 2>/dev/null \
        | awk '/0x[0-9A-Fa-f]+/ {print $2}'
}

get_first_transient_handle() {
    get_transient_handles | head -1
}

get_last_transient_handle() {
    get_transient_handles | tail -1
}

read_pcr16() {
    tpm2_pcrread sha256:16 2>/dev/null \
        | awk '/16:/ {gsub("0x","",$2); print toupper($2)}'
}

finalize() {
    cleanup_all

    cd /lab 2>/dev/null || true

    line
    echo
    echo "======================= FINAL RESULT ========================"
    echo "PASS checks: $PASS"
    echo "FAIL checks: $FAIL"
    echo
    echo "Evidence directory:"
    echo "$EVIDENCE"
    echo

    if [[ "$FAIL" -eq 0 ]]; then
        echo "TPM LAB ARM64 PROTOTYPE: PASS"
        echo "============================================================"
        exit 0
    else
        echo "TPM LAB ARM64 PROTOTYPE: FAIL"
        echo "============================================================"
        exit 1
    fi
}

###############################################################################
# TEST 0 — ARM64 environment
###############################################################################

line
echo "[0] Environment / architecture"

ARCH="$(uname -m)"
echo "Architecture: $ARCH"

if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    pass "Environment is ARM64"
else
    fail "Expected ARM64, got $ARCH"
fi

###############################################################################
# TEST 1 — TPM discovery
###############################################################################

line
echo "[1] TPM discovery"

if tpm2_getcap properties-fixed >"$EVIDENCE/properties-fixed.txt" 2>&1; then
    FAMILY="$(
        grep -A2 TPM2_PT_FAMILY_INDICATOR "$EVIDENCE/properties-fixed.txt" \
        | grep 'value:' \
        | head -1 \
        || true
    )"

    MANUFACTURER="$(
        grep -A2 TPM2_PT_MANUFACTURER "$EVIDENCE/properties-fixed.txt" \
        | grep 'value:' \
        | head -1 \
        || true
    )"

    PCR_COUNT="$(
        grep -A2 TPM2_PT_PCR_COUNT "$EVIDENCE/properties-fixed.txt" \
        | grep 'raw:' \
        | head -1 \
        || true
    )"

    echo "Family:       $FAMILY"
    echo "Manufacturer: $MANUFACTURER"
    echo "PCR count:    $PCR_COUNT"

    tpm2_getcap algorithms >"$EVIDENCE/algorithms.txt" 2>&1 || true
    tpm2_getcap pcrs >"$EVIDENCE/pcr-banks.txt" 2>&1 || true

    if grep -q '"2.0"' "$EVIDENCE/properties-fixed.txt"; then
        pass "TPM 2.0 responds through TPM2-TSS/TCTI"
    else
        fail "TPM responded, but TPM 2.0 was not confirmed"
    fi
else
    fail "Cannot communicate with TPM"
fi

###############################################################################
# TEST 2 — TPM RNG
###############################################################################

line
echo "[2] TPM random generator"

RANDOM_HEX="$(
    tpm2_getrandom --hex 16 \
        2>"$EVIDENCE/random.err" \
        | tr -d '\n\r '
)"

echo "Random: $RANDOM_HEX"

if [[ "$RANDOM_HEX" =~ ^[0-9a-fA-F]{32}$ ]]; then
    pass "TPM returned 16 random bytes"
else
    fail "Unexpected TPM random output"
fi

###############################################################################
# TEST 3 — PCR Extend + independent verification
###############################################################################

line
echo "[3] PCR Read / Extend"

if ! tpm2_pcrreset 16 >"$EVIDENCE/pcr-reset.out" 2>"$EVIDENCE/pcr-reset.err"; then
    fail "PCR 16 could not be reset in this simulator"
else
    PCR_BEFORE="$(read_pcr16)"

    MEASUREMENT="$(
        echo -n "TPM Lab deterministic PCR measurement" \
        | sha256sum \
        | awk '{print toupper($1)}'
    )"

    echo "PCR before : $PCR_BEFORE"
    echo "Measurement: $MEASUREMENT"

    EXPECTED="$(
python3 - "$PCR_BEFORE" "$MEASUREMENT" <<'PY'
import hashlib
import sys

old = bytes.fromhex(sys.argv[1])
measurement = bytes.fromhex(sys.argv[2])

print(hashlib.sha256(old + measurement).hexdigest().upper())
PY
)"

    if tpm2_pcrextend "16:sha256=$MEASUREMENT" \
        >"$EVIDENCE/pcr-extend.out" \
        2>"$EVIDENCE/pcr-extend.err"; then

        PCR_AFTER="$(read_pcr16)"

        echo "Expected   : $EXPECTED"
        echo "PCR after  : $PCR_AFTER"

        {
            echo "before=$PCR_BEFORE"
            echo "measurement=$MEASUREMENT"
            echo "expected=$EXPECTED"
            echo "after=$PCR_AFTER"
        } >"$EVIDENCE/pcr-test.txt"

        if [[ "$PCR_AFTER" == "$EXPECTED" && "$PCR_AFTER" != "$PCR_BEFORE" ]]; then
            pass "PCR Extend matches independent SHA-256 calculation"
        else
            fail "PCR value does not match independent calculation"
        fi
    else
        fail "PCR Extend command failed"
    fi
fi

###############################################################################
# TEST 4 — TPM-backed signing
###############################################################################

line
echo "[4] TPM-backed RSA signing"

cleanup_all

SIGN_DIR="$EVIDENCE/signing"
mkdir -p "$SIGN_DIR"
cd "$SIGN_DIR"

if ! tpm2_createprimary \
        -C o \
        -G rsa \
        -c primary.ctx \
        >createprimary.log 2>&1; then

    fail "Signing: failed to create Primary Object"

else
    PRIMARY_HANDLE="$(get_first_transient_handle)"

    echo "Primary handle: $PRIMARY_HANDLE"

    if [[ -z "$PRIMARY_HANDLE" ]]; then
        fail "Signing: Primary transient handle was not found"

    elif ! tpm2_create \
            -C "$PRIMARY_HANDLE" \
            -G rsa \
            -u signing.pub \
            -r signing.priv \
            -a "sign|fixedtpm|fixedparent|sensitivedataorigin|userwithauth" \
            >create-key.log 2>&1; then

        fail "Signing: failed to create signing key"

    elif ! tpm2_load \
            -C "$PRIMARY_HANDLE" \
            -u signing.pub \
            -r signing.priv \
            -c signing.ctx \
            >load-key.log 2>&1; then

        fail "Signing: failed to load signing key"

    else
        SIGNING_HANDLE="$(get_last_transient_handle)"

        echo "Signing handle: $SIGNING_HANDLE"

        echo "TPM Lab signing test" >message.txt
        echo "TPM Lab signing test TAMPERED" >tampered.txt

        if tpm2_sign \
                -c "$SIGNING_HANDLE" \
                -g sha256 \
                -o signature.bin \
                message.txt \
                >sign.log 2>&1 \
           && tpm2_verifysignature \
                -c "$SIGNING_HANDLE" \
                -g sha256 \
                -s signature.bin \
                -m message.txt \
                >verify-original.log 2>&1; then

            pass "Original message signature is valid"
        else
            fail "Original message signature verification failed"
        fi

        if tpm2_verifysignature \
                -c "$SIGNING_HANDLE" \
                -g sha256 \
                -s signature.bin \
                -m tampered.txt \
                >verify-tampered.out \
                2>verify-tampered.err; then

            fail "Tampered message was incorrectly accepted"

        elif grep -Eqi \
            "signature is not valid|Verify signature failed|0x.*2db" \
            verify-tampered.err; then

            pass "Tampered message rejected by TPM as expected"
        else
            fail "Tampered test failed for an unexpected reason"
            cat verify-tampered.err
        fi
    fi
fi

cleanup_all

###############################################################################
# TEST 5 — Basic Seal / Unseal
###############################################################################

line
echo "[5] Seal / Unseal"

SEAL_DIR="$EVIDENCE/sealing"
mkdir -p "$SEAL_DIR"
cd "$SEAL_DIR"

SECRET="SUPER_SECRET_TPM_LAB"
echo -n "$SECRET" >secret.txt

if ! tpm2_createprimary \
        -C o \
        -G rsa \
        -c primary.ctx \
        >createprimary.log 2>&1; then

    fail "Sealing: failed to create Primary Object"

else
    PRIMARY_HANDLE="$(get_first_transient_handle)"

    if [[ -z "$PRIMARY_HANDLE" ]]; then
        fail "Sealing: Primary transient handle was not found"

    elif ! tpm2_create \
            -C "$PRIMARY_HANDLE" \
            -i secret.txt \
            -u sealed.pub \
            -r sealed.priv \
            >create-sealed.log 2>&1; then

        fail "Sealing: failed to create sealed object"

    elif ! tpm2_load \
            -C "$PRIMARY_HANDLE" \
            -u sealed.pub \
            -r sealed.priv \
            -c sealed.ctx \
            >load-sealed.log 2>&1; then

        fail "Sealing: failed to load sealed object"

    else
        SEALED_HANDLE="$(get_last_transient_handle)"

        UNSEALED="$(
            tpm2_unseal \
                -c "$SEALED_HANDLE" \
                2>unseal.err
        )"

        if [[ "$UNSEALED" == "$SECRET" ]]; then
            pass "Secret sealed and unsealed successfully"
        else
            fail "Unsealed data does not match original secret"
        fi
    fi
fi

cleanup_all

###############################################################################
# TEST 6 — PCR-bound secret
###############################################################################

line
echo "[6] PCR-bound policy — trusted vs tampered state"

POLICY_DIR="$EVIDENCE/pcr-policy"
mkdir -p "$POLICY_DIR"
cd "$POLICY_DIR"

if ! tpm2_pcrreset 16 >pcr-reset.out 2>pcr-reset.err; then
    fail "PCR policy: unable to reset PCR 16"

else
    TRUSTED_PCR="$(read_pcr16)"
    echo "Trusted PCR: $TRUSTED_PCR"

    if ! tpm2_createprimary \
            -C o \
            -G rsa \
            -c primary.ctx \
            >createprimary.log 2>&1; then

        fail "PCR policy: failed to create Primary Object"

    else
        PRIMARY_HANDLE="$(get_first_transient_handle)"

        tpm2_pcrread \
            -o pcr.dat \
            sha256:16 \
            >pcr-read.log 2>&1

        TRUSTED_POLICY="$(
            tpm2_createpolicy \
                --policy-pcr \
                -l sha256:16 \
                -f pcr.dat \
                -L pcr.policy \
                2>createpolicy.err \
            | tr -d '\n\r '
        )"

        echo "Trusted policy digest: $TRUSTED_POLICY"

        echo -n "PCR_BOUND_SECRET" >secret.txt

        if ! tpm2_create \
                -C "$PRIMARY_HANDLE" \
                -L pcr.policy \
                -i secret.txt \
                -u sealed.pub \
                -r sealed.priv \
                >create-sealed.log 2>&1; then

            fail "PCR policy: failed to create policy-bound object"

        elif ! tpm2_load \
                -C "$PRIMARY_HANDLE" \
                -u sealed.pub \
                -r sealed.priv \
                -c sealed.ctx \
                >load-sealed.log 2>&1; then

            fail "PCR policy: failed to load policy-bound object"

        else
            SEALED_HANDLE="$(get_last_transient_handle)"

            ###################################################################
            # Trusted state
            ###################################################################

            if ! tpm2_startauthsession \
                    --policy-session \
                    -S trusted-session.ctx \
                    >trusted-session.log 2>&1; then

                fail "PCR policy: unable to start trusted policy session"

            elif ! tpm2_policypcr \
                    -S trusted-session.ctx \
                    -l sha256:16 \
                    -f pcr.dat \
                    >trusted-policy.log 2>&1; then

                fail "PCR policy: trusted PCR policy could not be satisfied"

            else
                TRUSTED_SECRET="$(
                    tpm2_unseal \
                        -c "$SEALED_HANDLE" \
                        -p session:trusted-session.ctx \
                        2>trusted-unseal.err
                )"

                if [[ "$TRUSTED_SECRET" == "PCR_BOUND_SECRET" ]]; then
                    pass "Trusted PCR state allows Unseal"
                else
                    fail "Trusted PCR state did not release secret"
                fi
            fi

            tpm2_flushcontext trusted-session.ctx >/dev/null 2>&1 || true

            ###################################################################
            # Tampered state
            ###################################################################

            TAMPER_MEASUREMENT="$(
                echo -n "TAMPERED PLATFORM STATE" \
                | sha256sum \
                | awk '{print toupper($1)}'
            )"

            if ! tpm2_pcrextend \
                    "16:sha256=$TAMPER_MEASUREMENT" \
                    >tamper-extend.log 2>&1; then

                fail "PCR policy: unable to modify PCR"

            else
                TAMPERED_PCR="$(read_pcr16)"

                echo "Tampered PCR: $TAMPERED_PCR"

                if [[ "$TAMPERED_PCR" == "$TRUSTED_PCR" ]]; then
                    fail "PCR did not change after tampering"
                else
                    pass "PCR changed after tampering"
                fi

                if ! tpm2_startauthsession \
                        --policy-session \
                        -S tampered-session.ctx \
                        >tampered-session.log 2>&1; then

                    fail "PCR policy: unable to start tampered policy session"

                else
                    TAMPERED_POLICY="$(
                        tpm2_policypcr \
                            -S tampered-session.ctx \
                            -l sha256:16 \
                            2>tampered-policy.err \
                        | tr -d '\n\r '
                    )"

                    echo "Tampered policy digest: $TAMPERED_POLICY"

                    if tpm2_unseal \
                            -c "$SEALED_HANDLE" \
                            -p session:tampered-session.ctx \
                            >tampered-secret.out \
                            2>tampered-unseal.err; then

                        fail "Tampered PCR state incorrectly released secret"

                    elif grep -Eqi \
                        "policy check failed|0x.*99d" \
                        tampered-unseal.err; then

                        pass "Tampered PCR state rejected by TPM policy"
                    else
                        fail "Unseal failed, but not because of expected PCR policy rejection"
                        cat tampered-unseal.err
                    fi

                    tpm2_flushcontext tampered-session.ctx >/dev/null 2>&1 || true

                    {
                        echo "trusted_pcr=$TRUSTED_PCR"
                        echo "tampered_pcr=$TAMPERED_PCR"
                        echo "trusted_policy=$TRUSTED_POLICY"
                        echo "tampered_policy=$TAMPERED_POLICY"
                    } >policy-evidence.txt
                fi
            fi
        fi
    fi
fi

finalize
