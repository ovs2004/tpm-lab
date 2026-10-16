#!/usr/bin/env python3
"""Одна PCR-операция через ESAPI и FAPI, затем ключ Кузнечика в TPM."""

from __future__ import annotations

import os
import subprocess
import sys

from tpm2_pytss import TSS2_Exception

from tpm_lab.fapi_lab import pcr_bound_unseal
from tpm_lab.kuznyechik import RFC_CIPHER, decrypt_block, encrypt_block, rfc_vector_matches
from tpm_lab.ops import (
    exception_rc,
    extend_pcr,
    open_esapi,
    random_bytes,
    reset_pcr16,
    seal,
    unseal,
)

SECRET = b"PCR_BOUND_SECRET"
PLAIN = b"Kuznyechik-block"  # ровно 16 байт, один блок ГОСТ
PASS = 0
FAIL = 0


def line() -> None:
    print("-" * 60)


def ok(message: str) -> None:
    global PASS
    print(f"[PASS] {message}")
    PASS += 1


def bad(message: str) -> None:
    global FAIL
    print(f"[FAIL] {message}")
    FAIL += 1


def restart_swtpm() -> None:
    subprocess.run(["start-swtpm"], check=True)


def esapi_pcr() -> None:
    line()
    print("[ESAPI] PCR-bound seal/unseal")
    print("calls:")
    for name in (
        "create_primary",
        "start_auth_session TRIAL",
        "policy_pcr",
        "policy_get_digest",
        "flush_context",
        "create",
        "load",
        "start_auth_session POLICY",
        "policy_pcr",
        "unseal",
        "flush_context",
        "pcr_reset / pcr_extend",
        "start_auth_session POLICY",
        "policy_pcr",
        "unseal -> expected TPM rejection",
    ):
        print(f"  esapi.{name}")
    ectx = open_esapi()
    try:
        reset_pcr16(ectx)
        primary, handle = seal(ectx, SECRET, pcr_index=16)
        try:
            if unseal(ectx, handle, pcr_index=16) == SECRET:
                ok("ESAPI trusted PCR releases the same secret")
            else:
                bad("ESAPI trusted unseal mismatch")
            extend_pcr(ectx, 16, b"TAMPERED PLATFORM STATE")
            try:
                unseal(ectx, handle, pcr_index=16)
            except TSS2_Exception as exc:
                rc = exception_rc(exc)
                print(f"ESAPI tamper rc={rc:#x}" if rc is not None else exc)
                if rc is not None and (rc & 0xFFF) == 0x99D:
                    ok("ESAPI tampered PCR returns 0x99D")
                else:
                    bad(f"ESAPI tamper is not 0x99D: {exc}")
            else:
                bad("ESAPI tampered PCR released the secret")
        finally:
            ectx.flush_context(handle)
            ectx.flush_context(primary)
    finally:
        ectx.close()


def fapi_pcr() -> None:
    line()
    print("[FAPI] PCR-bound seal/unseal via tss2")
    result = pcr_bound_unseal(SECRET)
    print("calls:")
    for call in result["calls"]:
        print(f"  {call}")
    if result["trusted_ok"]:
        ok("FAPI trusted PCR releases the same secret")
    else:
        bad("FAPI trusted unseal failed")
        print(result["reject_text"])
        return
    print(result["reject_text"].splitlines()[-1] if result["reject_text"] else "no error text")
    if result["rejected"] and result["reject_code"] == "0x1C4":
        ok("FAPI tampered PCR rejected by PolicyPCR 0x1C4")
    elif result["rejected"]:
        bad("FAPI rejected unseal, but not with 0x1C4")
    else:
        bad("FAPI tampered PCR released the secret")


def algorithm_list() -> None:
    line()
    print("[TPM] symmetric algorithms")
    listed = subprocess.run(
        ["tpm2_getcap", "algorithms"],
        check=False,
        capture_output=True,
        text=True,
    )
    names = [
        line.strip().rstrip(":")
        for line in listed.stdout.splitlines()
        if line.endswith(":") and not line.startswith(" ")
    ]
    # tpm2_getcap prints "aes:" at column 0.
    algorithms = [item for item in names if item]
    print(" ".join(algorithms))
    folded = " ".join(algorithms).lower()
    if "kuznyechik" in folded or "gost" in folded or "streebog" in folded:
        bad("TPM reports a GOST algorithm; the lab assumption is stale")
    elif "aes" in folded and "camellia" in folded:
        ok("TPM symmetric set is AES and Camellia, not Kuznyechik")
    else:
        bad(f"unexpected algorithm list: {algorithms}")


def kuznyechik_sealed() -> None:
    line()
    print("[Kuznyechik] cipher outside TPM, key sealed inside")
    if rfc_vector_matches():
        ok(f"RFC 7801 vector matches {RFC_CIPHER.hex()}")
    else:
        bad("RFC 7801 Kuznyechik vector failed")
        return
    if len(PLAIN) != 16:
        bad("lab plaintext must be one block")
        return
    ectx = open_esapi()
    try:
        reset_pcr16(ectx)
        key = random_bytes(ectx, 32)
        primary, handle = seal(ectx, key, pcr_index=16)
        ciphertext = encrypt_block(key, PLAIN)
        del key
        print(f"ciphertext={ciphertext.hex()}")
        try:
            opened = unseal(ectx, handle, pcr_index=16)
            if decrypt_block(opened, ciphertext) == PLAIN:
                ok("Unsealed TPM key decrypts the Kuznyechik block")
            else:
                bad("Unsealed key did not decrypt the block")
            del opened
            extend_pcr(ectx, 16, b"TAMPERED PLATFORM STATE")
            try:
                unseal(ectx, handle, pcr_index=16)
            except TSS2_Exception as exc:
                rc = exception_rc(exc)
                print(f"key unseal rc={rc:#x}" if rc is not None else exc)
                if rc is not None and (rc & 0xFFF) == 0x99D:
                    ok("After PCR Extend the Kuznyechik key stays sealed")
                else:
                    bad(f"key unseal failed for another reason: {exc}")
            else:
                bad("PCR change released the Kuznyechik key")
        finally:
            ectx.flush_context(handle)
            ectx.flush_context(primary)
    finally:
        ectx.close()


def main() -> int:
    os.environ.setdefault("TSS2_TCTI", "swtpm:host=127.0.0.1,port=2321")
    os.environ["TPM2TOOLS_TCTI"] = os.environ["TSS2_TCTI"]
    print("FAPI / ESAPI / KUZNYECHIK")
    restart_swtpm()
    esapi_pcr()
    restart_swtpm()
    fapi_pcr()
    restart_swtpm()
    algorithm_list()
    restart_swtpm()
    kuznyechik_sealed()
    line()
    print(f"PASS checks: {PASS}")
    print(f"FAIL checks: {FAIL}")
    if FAIL == 0:
        print("FAPI ESAPI KUZNYECHIK: PASS")
        return 0
    print("FAPI ESAPI KUZNYECHIK: FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
