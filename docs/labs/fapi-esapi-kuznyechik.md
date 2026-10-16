# ESAPI, FAPI и ключ Кузнечика

Одна и та же операция на свежем `swtpm`: секрет запечатан к PCR 16.
Пока PCR нулевой, Unseal возвращает секрет. После Extend TPM секрет не отдаёт.

Запуск из корня репозитория:

```bash
docker build -t tpm-lab-pytss -f infra/docker-tpm/Dockerfile.pytss .
docker run --rm --entrypoint /lab/run-fapi-kuznyechik.sh tpm-lab-pytss
```

Успех: `PASS checks: 8` и `FAPI ESAPI KUZNYECHIK: PASS`.

## ESAPI

Код в `src/tpm_lab/ops.py`. Вызовы видны: primary, trial-session, policy digest, Create/Load, policy-session, Unseal, flush.

Доверенный PCR отдаёт тот же секрет. После Extend Unseal возвращает `0x99D`.

## FAPI

Пакет `python3-tpm2-pytss` на Ubuntu 24.04 собран без Python-привязки FAPI. Вызов идёт в `libtss2-fapi` через `tss2`:

```text
tss2 provision
tss2 import policy POLICYPCR
tss2 createseal
tss2 unseal
tss2 pcrextend
tss2 unseal
```

Session и flush делает FAPI, не наш код. Для simulator в конфиге стоит `ek_cert_less`, потому что у swtpm нет сертификата EK.

Доверенный PCR отдаёт тот же секрет. После Extend отказ другой, чем у ESAPI: FAPI выполняет сохранённую policy, и TPM отклоняет `PolicyPCR` с `0x1C4`. Секрет при этом не возвращается. Это разница слоя ошибки, не разница правила доступа.

## Кузнечик

`tpm2_getcap algorithms` на этом swtpm содержит AES и Camellia. Кузнечика, Streebog и ГОСТ-подписи там нет, поэтому блок шифруется нашим кодом по ГОСТ Р 34.12-2015 / RFC 7801.

Контрольный вектор RFC совпадает:

```text
7f679d90bebc24305a468d42b9d4edcd
```

Ключ 32 байта берётся из `TPM2_GetRandom` и сразу seal к PCR 16. Расшифровать блок можно только после Unseal. После Extend тот же объект отвечает `0x99D`, ключ не выходит.

Так Кузнечик связан с TPM частично: алгоритм считает программа, ключ держит TPM.

Встроить шифр в `libtpms` рядом с AES и Camellia — отдельный следующий шаг: [Кузнечик внутри TPM](kuznyechik-inside-tpm.md).
