# Source

`tpm_lab/` — операции TPM через TPM2-TSS ESAPI (`tpm2-pytss`), без вызова `tpm2-tools`.

Модуль читает TCTI из `TSS2_TCTI` и на текущем сокетном стенде проходит те же проверки, что shell runner, плюс сверку `TPM2_Hash` с `hashlib` и проверку подписи через OpenSSL.

Рядом `run_fapi_kuznyechik.py`: та же PCR-операция через ESAPI и через FAPI (`tss2`), и ключ Кузнечика, запечатанный в TPM. Кузнечик не входит в алгоритмы этого `swtpm`.

Сборка и запуск: `infra/docker-tpm/Dockerfile.pytss`.

Это не FAPI и не код внутри гостевой VM. Сравнение FAPI/ESAPI остаётся отдельным треком.
