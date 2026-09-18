# Сравнение с существующим TPM Handbook

## Источник сравнения

В качестве reference point было изучено предоставленное описание
учебного проекта `TPM Handbook`.

По доступному README проект состоит из двух основных частей:

1. Работа с `ms-tpm-20-ref`.
2. QEMU vTPM на базе `swtpm` и приложение `tpm-vault` через TPM2-TSS FAPI.

Основным прикладным сценарием Handbook является LUKS2 disk encryption
с хранением/sealing ключа в TPM и PCR policy.

TPM Lab не ставит целью повторить Handbook один в один.

## Сравнение подходов

| Аспект                     | TPM Handbook                                    | TPM Lab                                    |
| -------------------------- | ----------------------------------------------- | ------------------------------------------ |
| Основная CPU architecture  | x86_64                                          | ARM64 / Apple Silicon                      |
| Базовая Linux environment  | Ubuntu 22.04                                    | Ubuntu 24.04 ARM64                         |
| Reference simulator        | ms-tpm-20-ref                                   | планируется как второй backend             |
| Основной текущий simulator | swtpm используется в QEMU vTPM                  | swtpm используется уже в direct-TCTI spike |
| Virtualization             | QEMU/KVM, включая nested VM сценарий            | сейчас Docker spike, далее UTM/QEMU ARM64  |
| Начальный transport        | simulator / далее vTPM                          | TPM2-TSS TCTI swtpm                        |
| Основной use case          | LUKS2 encrypted disk + sealed key               | набор независимых TPM security mechanisms  |
| PCR                        | часть disk unlock policy                        | отдельный Read/Extend experiment           |
| Signing                    | не основной демонстрируемый сценарий            | самостоятельный TPM-backed RSA test        |
| Seal/Unseal                | LUKS key                                        | basic + PCR-bound secret                   |
| Negative tests             | PCR mismatch блокирует доступ к ключу           | tampered signature + tampered PCR policy   |
| Automation                 | сценарий ориентирован на прикладную лабораторию | PASS/FAIL runner + evidence                |
| FAPI                       | используется приложением tpm-vault              | запланировано                              |
| ESAPI                      | не основной фокус README                        | запланировано отдельное сравнение          |
| Attestation                | не основной сценарий README                     | optional future extension                  |

## Что TPM Lab может добавить к существующей базе знаний

Наиболее полезный дополнительный материал TPM Lab — альтернативный
быстрый ARM64/Apple Silicon путь.

### 1. ARM64 Docker quickstart

```text
Mac Apple Silicon
 ->
Docker
 ->
Ubuntu 24.04 ARM64
 ->
TPM2-TSS/TCTI
 ->
swtpm
```

Этот сценарий позволяет исследовать TPM 2.0 без предварительной
настройки nested virtualization или x86_64 VM.

### 2. Direct swtpm TCTI laboratory

Отдельное описание прямого подключения `tpm2-tools` к `swtpm`
через TCTI.

### 3. Независимый PCR assertion

PCR Extend проверяется не только отсутствием ошибки, но и независимым
расчётом:

```text
PCR_new = SHA256(PCR_old || measurement)
```

### 4. Positive и negative tests

TPM Lab уже содержит:

* valid signature -> accepted;
* modified message -> signature rejected;
* trusted PCR -> Unseal allowed;
* changed PCR -> policy rejection.

### 5. Transient-context troubleshooting

Во время direct-TCTI работы была получена ошибка:

```text
0x902
out of memory for object contexts
```

После анализа transient handles было добавлено явное управление
TPM contexts.

Этот опыт полезен как отдельная troubleshooting note для software
TPM laboratory.

## Что не требуется повторять

TPM Lab не обязан полностью повторять:

* LUKS2 disk encryption;
* готовую x86_64 VM;
* nested virtualization workflow;
* приложение tpm-vault.

Эти решения используются как reference, а проект сохраняет собственный
фокус:

* Apple Silicon / ARM64;
* воспроизводимый TPM test bench;
* независимые security mechanisms;
* автоматизированные positive/negative tests;
* последующее сравнение FAPI и ESAPI.

## Дальнейшая связь с Handbook

Следующий небольшой эксперимент — использовать `ms-tpm-20-ref` как
второй backend и повторить на нём минимальный набор базовых TPM 2.0
operations.

После этого планируется переход к ARM64 VM/vTPM и повторное выполнение
уже готовых тестов через TPM device.

Это сравнение основано на предоставленном README/описании TPM Handbook
и не является полным аудитом внешнего репозитория.
