"""Small TPM operations on top of TPM2-TSS ESAPI.

The TCTI comes from the caller (``TSS2_TCTI`` or an explicit string),
so the same functions can talk to ``swtpm`` or ``mssim``.
"""

from tpm_lab.ops import (
    extend_pcr,
    hash_sha256,
    open_esapi,
    random_bytes,
    seal,
    sign_message,
    unseal,
)

__all__ = [
    "extend_pcr",
    "hash_sha256",
    "open_esapi",
    "random_bytes",
    "seal",
    "sign_message",
    "unseal",
]
