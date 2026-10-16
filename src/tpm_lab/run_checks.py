#!/usr/bin/env python3
"""Assertions for the ESAPI module. PASS only after a real TPM result."""

from __future__ import annotations

import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path

from tpm2_pytss import TSS2_Exception

from tpm_lab.ops import (
    exception_rc,
    extend_pcr,
    hash_sha256,
    open_esapi,
    random_bytes,
    read_pcr,
    reset_pcr16,
    seal,
    sign_and_keep,
    unseal,
    verify_loaded,
)

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


def matches_code(exc: BaseException, needle: str) -> bool:
    rc = exception_rc(exc)
    text = str(exc).lower()
    if needle.lower() in text:
        return True
    if rc is None:
        return False
    return needle.lower().lstrip("0x") in f"{rc:#x}"


def check_random(ectx) -> None:
    line()
    print("[1] GetRandom")
    data = random_bytes(ectx, 16)
    print(f"length={len(data)} hex={data.hex()}")
    if len(data) == 16 and data != bytes(16):
        ok("TPM returned 16 random bytes")
    else:
        bad("Unexpected TPM random output")


def check_hash(ectx) -> None:
    line()
    print("[2] TPM2_Hash vs hashlib.sha256")
    payload = b"TPM Lab hash comparison"
    tpm_digest = hash_sha256(ectx, payload)
    local = hashlib.sha256(payload).digest()
    print(f"tpm   ={tpm_digest.hex()}")
    print(f"local ={local.hex()}")
    if tpm_digest == local:
        ok("TPM2_Hash matches hashlib.sha256")
    else:
        bad("TPM2_Hash does not match hashlib.sha256")


def check_pcr(ectx) -> None:
    line()
    print("[3] PCR Extend")
    reset_pcr16(ectx)
    before = read_pcr(ectx, 16)
    measurement = b"TPM Lab deterministic PCR measurement"
    measured = hashlib.sha256(measurement).digest()
    expected = hashlib.sha256(before + measured).digest()
    after = extend_pcr(ectx, 16, measurement)
    print(f"before  ={before.hex()}")
    print(f"expected={expected.hex()}")
    print(f"after   ={after.hex()}")
    if after == expected and after != before:
        ok("PCR Extend matches independent SHA-256 calculation")
    else:
        bad("PCR value does not match independent calculation")


def check_sign(ectx) -> None:
    line()
    print("[4] TPM sign, TPM verify, OpenSSL verify")
    message = b"TPM Lab signing test"
    tampered = b"TPM Lab signing test TAMPERED"
    primary, key, signature = sign_and_keep(ectx, message)
    try:
        verify_loaded(ectx, key, message, signature)
        ok("Original message signature is valid")
        try:
            verify_loaded(ectx, key, tampered, signature)
        except TSS2_Exception as exc:
            print(f"tampered rc={exception_rc(exc):#x}" if exception_rc(exc) is not None else exc)
            if matches_code(exc, "2db"):
                ok("Tampered message rejected by TPM as expected")
            else:
                bad(f"Tampered test failed for an unexpected reason: {exc}")
        else:
            bad("Tampered message was incorrectly accepted")
        openssl_verify(message, signature, tampered)
    finally:
        ectx.flush_context(key)
        ectx.flush_context(primary)


def openssl_verify(message: bytes, signature, tampered: bytes) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        pub = root / "key.pem"
        sig = root / "sig.bin"
        msg = root / "msg"
        bad_msg = root / "bad"
        pub.write_bytes(signature.public_pem)
        sig.write_bytes(signature.signature)
        msg.write_bytes(message)
        bad_msg.write_bytes(tampered)
        good = subprocess.run(
            ["openssl", "dgst", "-sha256", "-verify", str(pub), "-signature", str(sig), str(msg)],
            capture_output=True,
            text=True,
        )
        print(good.stdout.strip() or good.stderr.strip())
        if good.returncode == 0:
            ok("OpenSSL accepted the TPM signature")
        else:
            bad(f"OpenSSL rejected a valid TPM signature: {good.stderr.strip()}")
        rejected = subprocess.run(
            ["openssl", "dgst", "-sha256", "-verify", str(pub), "-signature", str(sig), str(bad_msg)],
            capture_output=True,
            text=True,
        )
        if rejected.returncode != 0:
            ok("OpenSSL rejected the tampered message")
        else:
            bad("OpenSSL accepted the tampered message")


def check_seal(ectx) -> None:
    line()
    print("[5] Seal / Unseal")
    secret = b"SUPER_SECRET_TPM_LAB"
    primary, handle = seal(ectx, secret)
    try:
        opened = unseal(ectx, handle)
        if opened == secret:
            ok("Secret sealed and unsealed successfully")
        else:
            bad("Unsealed data does not match original secret")
    finally:
        ectx.flush_context(handle)
        ectx.flush_context(primary)


def check_policy(ectx) -> None:
    line()
    print("[6] PCR-bound policy")
    reset_pcr16(ectx)
    secret = b"PCR_BOUND_SECRET"
    primary, handle = seal(ectx, secret, pcr_index=16)
    try:
        opened = unseal(ectx, handle, pcr_index=16)
        if opened == secret:
            ok("Trusted PCR state allows Unseal")
        else:
            bad("Trusted PCR state did not release secret")
        extend_pcr(ectx, 16, b"TAMPERED PLATFORM STATE")
        try:
            unseal(ectx, handle, pcr_index=16)
        except TSS2_Exception as exc:
            shown = exception_rc(exc)
            print(f"policy rc={shown:#x}" if shown is not None else exc)
            if matches_code(exc, "99d"):
                ok("Tampered PCR state rejected by TPM policy")
            else:
                bad(f"Unseal failed, but not because of expected PCR policy rejection: {exc}")
        else:
            bad("Tampered PCR state incorrectly released secret")
    finally:
        ectx.flush_context(handle)
        ectx.flush_context(primary)


def main() -> int:
    print("TPM LAB ESAPI MODULE")
    ectx = open_esapi()
    try:
        check_random(ectx)
        check_hash(ectx)
        check_pcr(ectx)
        check_sign(ectx)
        check_seal(ectx)
        check_policy(ectx)
    finally:
        ectx.close()
    line()
    print(f"PASS checks: {PASS}")
    print(f"FAIL checks: {FAIL}")
    if FAIL == 0:
        print("TPM LAB ESAPI MODULE: PASS")
        return 0
    print("TPM LAB ESAPI MODULE: FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
