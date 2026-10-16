"""TPM operations through tpm2-pytss ESAPI, without tpm2-tools."""

from __future__ import annotations

import hashlib
import os
from dataclasses import dataclass

from tpm2_pytss import (
    ESAPI,
    ESYS_TR,
    TPM2_ALG,
    TPM2_RH,
    TPM2_SE,
    TPM2_ST,
    TPM2_SU,
    TPM2B_DIGEST,
    TPM2B_PUBLIC,
    TPM2B_SENSITIVE_CREATE,
    TPM2B_SENSITIVE_DATA,
    TPML_DIGEST_VALUES,
    TPML_PCR_SELECTION,
    TPMS_SENSITIVE_CREATE,
    TPMT_HA,
    TPMT_PUBLIC,
    TPMT_SIG_SCHEME,
    TPMT_SYM_DEF,
    TPMT_TK_HASHCHECK,
    TPMU_HA,
    TSS2_Exception,
)

def _bytes(value) -> bytes:
    if isinstance(value, (bytes, bytearray)):
        return bytes(value)
    buffer = getattr(value, "buffer", None)
    if buffer is not None:
        return _bytes(buffer)
    return bytes(value)


PCR16 = ESYS_TR.PCR16
OWNER_ATTRS = (
    "restricted|decrypt|fixedtpm|fixedparent|"
    "sensitivedataorigin|userwithauth"
)
SIGN_ATTRS = "sign|fixedtpm|fixedparent|sensitivedataorigin|userwithauth"
SEAL_ATTRS = "fixedtpm|fixedparent|userwithauth"


@dataclass
class Signature:
    """TPM RSASSA signature plus the PEM public key that verifies it."""

    signature: bytes
    public_pem: bytes
    digest: bytes


def open_esapi(tcti: str | None = None) -> ESAPI:
    """Open ESAPI. ``tcti`` defaults to ``TSS2_TCTI``."""

    chosen = tcti if tcti is not None else os.environ.get("TSS2_TCTI")
    if not chosen:
        raise RuntimeError("TSS2_TCTI is not set and no TCTI was passed")
    ectx = ESAPI(tcti=chosen)
    try:
        ectx.startup(TPM2_SU.CLEAR)
    except TSS2_Exception as exc:
        # Direct-socket swtpm is often already started with startup-clear.
        text = f"{exc} {getattr(exc, 'rc', ''):#x}" if hasattr(exc, "rc") else str(exc)
        if "initialize" not in text.lower() and "0x100" not in text.lower():
            raise
    return ectx


def random_bytes(ectx: ESAPI, n: int) -> bytes:
    blob = ectx.get_random(n)
    return _bytes(blob)[:n]


def hash_sha256(ectx: ESAPI, data: bytes) -> bytes:
    digest, _ticket = ectx.hash(data, TPM2_ALG.SHA256, ESYS_TR.NULL)
    return _bytes(digest)


def _pcr_selection(index: int) -> TPML_PCR_SELECTION:
    return TPML_PCR_SELECTION.parse(f"sha256:{index}")


def read_pcr(ectx: ESAPI, index: int = 16) -> bytes:
    _update, _selected, values = ectx.pcr_read(_pcr_selection(index))
    return _bytes(values[0])


def extend_pcr(ectx: ESAPI, index: int, measurement: bytes) -> bytes:
    """Extend ``sha256(measurement)`` into the PCR and return the new digest."""

    measured = hashlib.sha256(measurement).digest()
    digest_value = TPMT_HA(
        hashAlg=TPM2_ALG.SHA256,
        digest=TPMU_HA(sha256=measured),
    )
    ectx.pcr_extend(_pcr_handle(index), TPML_DIGEST_VALUES([digest_value]))
    return read_pcr(ectx, index)


def reset_pcr16(ectx: ESAPI) -> None:
    ectx.pcr_reset(PCR16)


def _pcr_handle(index: int):
    if index == 16:
        return PCR16
    return ESYS_TR.PCR0 + index


def _rsa_public(alg: str, attributes: str) -> TPM2B_PUBLIC:
    return TPM2B_PUBLIC(
        publicArea=TPMT_PUBLIC.parse(alg=alg, objectAttributes=attributes)
    )


def _create_primary(ectx: ESAPI):
    handle, _public, _data, _hash, _ticket = ectx.create_primary(
        TPM2B_SENSITIVE_CREATE(),
        _rsa_public("rsa2048", OWNER_ATTRS),
    )
    return handle


def _null_ticket() -> TPMT_TK_HASHCHECK:
    # Unrestricted signing keys accept an external hash with a null ticket.
    # The hierarchy is TPM2_RH.NULL, not an ESYS_TR handle.
    return TPMT_TK_HASHCHECK(tag=TPM2_ST.HASHCHECK, hierarchy=TPM2_RH.NULL)


def _rsassa_scheme() -> TPMT_SIG_SCHEME:
    scheme = TPMT_SIG_SCHEME(scheme=TPM2_ALG.RSASSA)
    scheme.details.any.hashAlg = TPM2_ALG.SHA256
    return scheme


def sign_message(ectx: ESAPI, message: bytes) -> Signature:
    """Create a TPM-backed RSA key, sign ``message``, return signature and PEM."""

    import hashlib

    primary = _create_primary(ectx)
    try:
        private, public, *_rest = ectx.create(
            primary,
            TPM2B_SENSITIVE_CREATE(),
            _rsa_public("rsa2048:rsassa:null", SIGN_ATTRS),
        )
        key = ectx.load(primary, private, public)
        try:
            digest = hashlib.sha256(message).digest()
            scheme = _rsassa_scheme()
            signature = ectx.sign(key, digest, scheme, _null_ticket())
            sig_bytes = _bytes(signature.signature.rsassa.sig)
            pem = public.to_pem()
            if isinstance(pem, str):
                pem = pem.encode()
            return Signature(signature=sig_bytes, public_pem=pem, digest=digest)
        finally:
            ectx.flush_context(key)
    finally:
        ectx.flush_context(primary)


def verify_loaded(ectx: ESAPI, key, message: bytes, signature: Signature) -> None:
    import hashlib

    digest = hashlib.sha256(message).digest()
    scheme_sig = _signature_from_bytes(signature.signature)
    ectx.verify_signature(key, TPM2B_DIGEST(buffer=digest), scheme_sig)


def _signature_from_bytes(raw: bytes):
    from tpm2_pytss import TPMT_SIGNATURE

    sig = TPMT_SIGNATURE(sigAlg=TPM2_ALG.RSASSA)
    sig.signature.rsassa.hash = TPM2_ALG.SHA256
    sig.signature.rsassa.sig = raw
    return sig


def sign_and_keep(ectx: ESAPI, message: bytes):
    """Sign and return ``(primary, key, signature)``. Caller flushes both handles."""

    import hashlib

    primary = _create_primary(ectx)
    private, public, *_rest = ectx.create(
        primary,
        TPM2B_SENSITIVE_CREATE(),
        _rsa_public("rsa2048:rsassa:null", SIGN_ATTRS),
    )
    key = ectx.load(primary, private, public)
    digest = hashlib.sha256(message).digest()
    scheme = _rsassa_scheme()
    signature = ectx.sign(key, digest, scheme, _null_ticket())
    sig_bytes = _bytes(signature.signature.rsassa.sig)
    pem = public.to_pem()
    if isinstance(pem, str):
        pem = pem.encode()
    return primary, key, Signature(signature=sig_bytes, public_pem=pem, digest=digest)


def seal(ectx: ESAPI, secret: bytes, pcr_index: int | None = None):
    """Seal ``secret`` under the owner hierarchy.

    When ``pcr_index`` is set, the object auth policy is bound to the
    current value of that PCR. Returns ``(primary, handle)``.
    """

    primary = _create_primary(ectx)
    public = TPM2B_PUBLIC(
        publicArea=TPMT_PUBLIC.parse(alg="keyedhash", objectAttributes=SEAL_ATTRS)
    )
    if pcr_index is not None:
        policy = _policy_pcr_digest(ectx, pcr_index)
        public.publicArea.authPolicy = policy
    sensitive = TPM2B_SENSITIVE_CREATE(
        sensitive=TPMS_SENSITIVE_CREATE(data=TPM2B_SENSITIVE_DATA(buffer=secret))
    )
    private, out_public, *_rest = ectx.create(primary, sensitive, public)
    handle = ectx.load(primary, private, out_public)
    return primary, handle


def unseal(ectx: ESAPI, handle, pcr_index: int | None = None) -> bytes:
    if pcr_index is None:
        data = ectx.unseal(handle)
    else:
        session = _policy_session(ectx, pcr_index)
        try:
            data = ectx.unseal(handle, session1=session)
        finally:
            ectx.flush_context(session)
    return _bytes(data)


def _policy_session(ectx: ESAPI, pcr_index: int):
    session = ectx.start_auth_session(
        ESYS_TR.NONE,
        ESYS_TR.NONE,
        TPM2_SE.POLICY,
        TPMT_SYM_DEF(algorithm=TPM2_ALG.NULL),
        TPM2_ALG.SHA256,
    )
    ectx.policy_pcr(session, b"", _pcr_selection(pcr_index))
    return session


def _policy_pcr_digest(ectx: ESAPI, pcr_index: int) -> bytes:
    session = ectx.start_auth_session(
        ESYS_TR.NONE,
        ESYS_TR.NONE,
        TPM2_SE.TRIAL,
        TPMT_SYM_DEF(algorithm=TPM2_ALG.NULL),
        TPM2_ALG.SHA256,
    )
    try:
        ectx.policy_pcr(session, b"", _pcr_selection(pcr_index))
        digest = ectx.policy_get_digest(session)
    finally:
        ectx.flush_context(session)
    return _bytes(digest)


def exception_rc(exc: BaseException) -> int | None:
    rc = getattr(exc, "rc", None)
    if isinstance(rc, int):
        return rc
    error = getattr(exc, "error", None)
    if isinstance(error, int):
        return error
    return None
