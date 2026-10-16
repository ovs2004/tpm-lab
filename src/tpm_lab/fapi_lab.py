"""PCR-bound seal через FAPI.

На Ubuntu 24.04 пакет python3-tpm2-pytss собран без FAPI-привязки:
проверка версии ищет tss2-fapi в своём списке и не находит её.
Рабочий FAPI здесь — команды tss2, они вызывают libtss2-fapi.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path


def _config(root: Path) -> Path:
    for name in ("user", "system", "log"):
        (root / name).mkdir(parents=True, exist_ok=True)
    path = root / "fapi-config.json"
    tcti = os.environ.get("TSS2_TCTI", "swtpm:host=127.0.0.1,port=2321")
    path.write_text(
        "{\n"
        '  "profile_name": "P_RSA2048SHA256",\n'
        '  "profile_dir": "/etc/tpm2-tss/fapi-profiles/",\n'
        f'  "user_dir": "{root / "user"}",\n'
        f'  "system_dir": "{root / "system"}",\n'
        f'  "tcti": "{tcti}",\n'
        '  "system_pcrs": [],\n'
        f'  "log_dir": "{root / "log"}",\n'
        '  "firmware_log_file": "/dev/null",\n'
        '  "ima_log_file": "/dev/null",\n'
        '  "ek_cert_less": "yes"\n'
        "}\n",
        encoding="utf-8",
    )
    return path


def _run(config: Path, *args: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["TSS2_FAPICONF"] = str(config)
    return subprocess.run(
        ["tss2", *args],
        check=False,
        capture_output=True,
        text=True,
        env=env,
    )


def pcr_bound_unseal(secret: bytes) -> dict:
    """Seal к нулевому PCR 16, Unseal, Extend, повторный Unseal.

    Возвращает фактические коды. Ключ и секрет в результат не кладутся,
    только совпало ли значение.
    """

    if shutil.which("tss2") is None:
        raise RuntimeError("tss2 is not installed")

    calls: list[str] = []
    with tempfile.TemporaryDirectory(prefix="fapi-lab-") as raw:
        root = Path(raw)
        config = _config(root)
        policy = root / "pcr16.json"
        data = root / "secret.bin"
        opened = root / "opened.bin"
        tamper = root / "tamper.bin"
        policy.write_text(
            '{"description":"PCR 16 zero","policy":[{"type":"POLICYPCR",'
            '"pcrs":[{"pcr":16,"hashAlg":"TPM2_ALG_SHA256","digest":"'
            + ("00" * 32)
            + '"}]}]}',
            encoding="utf-8",
        )
        data.write_bytes(secret)
        tamper.write_bytes(b"TAMPERED PLATFORM STATE")

        def call(*args: str) -> subprocess.CompletedProcess[str]:
            shown = []
            for arg in args:
                if "=" in arg and arg.split("=", 1)[0] in {
                    "--importData",
                    "--data",
                }:
                    shown.append(arg.split("=", 1)[0] + "=<file>")
                else:
                    shown.append(arg)
            calls.append("tss2 " + " ".join(shown))
            return _run(config, *args)

        provision = call("provision")
        if provision.returncode != 0:
            return _failed("provision", provision, calls)
        imported = call("import", "--path=/policy/pcr16", f"--importData={policy}")
        if imported.returncode != 0:
            return _failed("import", imported, calls)
        sealed = call(
            "createseal",
            "--path=HS/SRK/seal16",
            "--policyPath=/policy/pcr16",
            "--authValue=",
            f"--data={data}",
        )
        if sealed.returncode != 0:
            return _failed("createseal", sealed, calls)
        trusted = call("unseal", "--path=HS/SRK/seal16", f"--data={opened}")
        trusted_ok = trusted.returncode == 0 and opened.read_bytes() == secret
        extended = call("pcrextend", "--pcr=16", f"--data={tamper}")
        rejected = call("unseal", "--path=HS/SRK/seal16", f"--data={opened}")
        text = rejected.stderr + rejected.stdout
        return {
            "calls": calls,
            "trusted_ok": trusted_ok,
            "extend_ok": extended.returncode == 0,
            "rejected": rejected.returncode != 0,
            "reject_text": text.strip(),
            "reject_code": "0x1C4" if "0x000001c4" in text.lower() or "0x1c4" in text.lower() else "",
        }


def _failed(step: str, result: subprocess.CompletedProcess[str], calls: list[str]) -> dict:
    return {
        "calls": calls,
        "trusted_ok": False,
        "extend_ok": False,
        "rejected": False,
        "reject_text": f"{step} failed: {result.stderr.strip() or result.stdout.strip()}",
        "reject_code": "",
    }
