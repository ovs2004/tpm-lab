# Automated TPM Verification Runner: структура и доказательство реальных тестов

## Назначение

`run-all.sh` — автоматизированный проверочный runner раннего ARM64 TPM-стенда TPM Lab.

Его задача — не просто последовательно вызвать `tpm2-tools`, а проверить, что каждая TPM-операция дала ожидаемый результат, включая отрицательные security-сценарии.

Основной файл:

```text
infra/docker-tpm/run-all.sh
```

Запуск software TPM:

```text
infra/docker-tpm/start-swtpm.sh
```

Стенд:

```text
Mac Apple Silicon
    ->
Docker
    ->
Ubuntu 24.04 ARM64
    ->
tpm2-tools
    ->
TPM2-TSS
    ->
TCTI swtpm
    ->
swtpm TPM 2.0
```

---

## 1. Главный принцип runner

Runner работает по схеме:

```text
TPM operation
    ↓
real TPM result / return code
    ↓
assertion
    ↓
PASS / FAIL
    ↓
raw evidence
```

`PASS` не выводится сразу после команды.

Положительный тест:

```bash
if <TPM operation succeeded AND result is expected>; then
    pass "..."
else
    fail "..."
fi
```

Отрицательный тест:

```bash
if <operation unexpectedly succeeds>; then
    fail "Security condition was not enforced"
elif <TPM returned expected rejection>; then
    pass "Expected rejection observed"
else
    fail "Operation failed for another reason"
fi
```

То есть обычная ошибка команды сама по себе не считается успешным security test.

---

## 2. Почему это не scripted demo

Плохой вариант выглядел бы так:

```bash
tpm2_pcrextend ...
echo "[PASS] PCR changed"
```

Такой script не проверяет результат.

В TPM Lab логика другая:

```text
1. Получить состояние до операции.
2. Выполнить реальную TPM-команду.
3. Получить состояние после операции.
4. Сформировать или независимо вычислить expected result.
5. Сравнить actual и expected.
6. Только после этого вывести PASS.
```

Для negative test:

```text
1. Проверить корректный state.
2. Доказать, что операция разрешена.
3. Изменить защищаемое состояние или данные.
4. Повторить security-sensitive operation.
5. Проверить, что отказ пришёл от TPM.
6. Проверить ожидаемый return code / error semantics.
7. Только после этого считать test успешным.
```

---

## 3. Структура `run-all.sh`

```text
run-all.sh
│
├── start swtpm
│
├── TEST 0 — ARM64 environment
├── TEST 1 — TPM Discovery
├── TEST 2 — TPM GetRandom
├── TEST 3 — PCR Read / Extend
│   └── independent SHA-256 assertion
├── TEST 4 — TPM-backed RSA signing
│   ├── positive verification
│   └── tampered-message negative test
├── TEST 5 — Basic Seal / Unseal
├── TEST 6 — PCR-bound Seal / Unseal
│   ├── trusted PCR state
│   ├── PCR modification
│   └── tampered-state negative test
└── Final summary
    ├── PASS count
    ├── FAIL count
    └── evidence path
```

Подтверждённый результат Sprint 02:

```text
PASS checks: 10
FAIL checks: 0

TPM LAB ARM64 PROTOTYPE: PASS
```

---

## 4. Запуск TPM и проверка готовности

`start-swtpm.sh` поднимает новый software TPM state и настраивает:

```bash
TPM2TOOLS_TCTI=swtpm:host=127.0.0.1,port=2321
```

После запуска готовность проверяется реальной TPM-командой:

```bash
tpm2_getcap properties-fixed
```

Если TPM endpoint не отвечает, тестовый прогон не продолжается как успешный.

---

## 5. PASS / FAIL contract

Runner ведёт счётчики:

```text
PASS
FAIL
```

Каждая проверка заканчивается одним из вариантов:

```text
expected positive result     -> PASS
expected security rejection  -> PASS
unexpected result            -> FAIL
```

Финальный exit code:

```text
FAIL == 0 -> exit 0
FAIL > 0  -> exit 1
```

Это позволяет отличить успешный прогон не только по красивому тексту, но и по process exit code.

---

## 6. TEST 0 — ARM64 environment

Команда:

```bash
uname -m
```

Assertion:

```text
aarch64 / arm64 -> PASS
anything else   -> FAIL
```

Это подтверждает, что лабораторный Linux environment действительно работает как ARM64, что важно для Apple Silicon.

---

## 7. TEST 1 — TPM Discovery

TPM operation:

```bash
tpm2_getcap properties-fixed
```

Runner сохраняет:

```text
properties-fixed.txt
algorithms.txt
pcr-banks.txt
```

Проверяется, что TPM реально сообщает:

```text
TPM family = 2.0
```

Также в evidence выводятся manufacturer и PCR count.

Если `swtpm` не запущен, TCTI настроен неверно или TPM не отвечает, тест завершается `FAIL`.

---

## 8. TEST 2 — TPM GetRandom

TPM operation:

```bash
tpm2_getrandom --hex 16
```

Assertion:

```text
16 bytes == 32 hex characters
```

Формат проверяется как hexadecimal string.

Этот тест подтверждает выполнение отдельной TPM command через тот же TPM2-TSS/TCTI stack.

Он не доказывает свойства физического аппаратного RNG, так как используется software TPM.

---

## 9. TEST 3 — PCR Read / Extend

Это один из ключевых тестов.

### 9.1 Исходное состояние

```bash
tpm2_pcrreset 16
tpm2_pcrread sha256:16
```

Runner получает:

```text
PCR_BEFORE
```

PCR 16 используется как лабораторный resettable PCR в текущем `swtpm` стенде.

### 9.2 Measurement

Создаётся deterministic measurement:

```text
MEASUREMENT = SHA256("TPM Lab deterministic PCR measurement")
```

### 9.3 Реальный TPM Extend

```bash
tpm2_pcrextend "16:sha256=$MEASUREMENT"
```

После этого снова считывается:

```text
PCR_AFTER
```

### 9.4 Независимый expected result

Runner отдельно через Python вычисляет:

```text
EXPECTED = SHA256(PCR_BEFORE || MEASUREMENT)
```

TPM сам не сообщает runner ожидаемое значение.

### 9.5 Assertion

PASS возможен только если одновременно:

```text
PCR_AFTER == EXPECTED
PCR_AFTER != PCR_BEFORE
```

Схема:

```text
TPM PCR_Extend
      ↓
Actual TPM PCR
      ↓
    compare
      ↑
Independent Python SHA-256
      ↓
PASS / FAIL
```

Этот тест проверяет не только exit code, но и семантику PCR Extend:

```text
PCR_new = SHA256(PCR_old || measurement)
```

---

## 10. TEST 4 — TPM-backed RSA Sign / Verify

### 10.1 Управление объектами

Перед тестом transient TPM objects очищаются.

Создаётся Primary Object:

```bash
tpm2_createprimary
```

Реальный transient handle определяется через:

```bash
tpm2_getcap handles-transient
```

Runner не обязан заранее считать handle равным `0x80000000`: он получает его из TPM state.

Это решение появилось после реального troubleshooting ошибки:

```text
0x902
out of memory for object contexts
```

### 10.2 Создание signing object

```bash
tpm2_create
tpm2_load
```

Используются атрибуты:

```text
sign
fixedtpm
fixedparent
sensitivedataorigin
userwithauth
```

После загрузки signing handle также определяется по текущему TPM state.

### 10.3 Positive test

```bash
tpm2_sign
tpm2_verifysignature
```

Только если подпись создана и оригинальное сообщение реально прошло Verify:

```text
[PASS] Original message signature is valid
```

---

## 11. Negative signing test

Создаётся изменённое сообщение, но используется та же `signature.bin`.

Снова вызывается:

```bash
tpm2_verifysignature
```

Runner не считает любой non-zero exit code успешным.

Он проверяет ожидаемый signature rejection:

```text
0x2DB
```

или:

```text
the signature is not valid
```

Логика:

```text
original message
+ signature
-> accepted

modified message
+ same signature
-> TPM rejects
-> expected rejection = PASS
```

Если TPM недоступен, handle неверен или операция упала по другой причине — это `FAIL`.

---

## 12. TEST 5 — Basic Seal / Unseal

Runner создаёт secret:

```text
SUPER_SECRET_TPM_LAB
```

Далее:

```text
secret
  ↓
tpm2_create
  ↓
sealed TPM object
  ↓
tpm2_load
  ↓
tpm2_unseal
  ↓
UNSEALED
```

Assertion:

```text
UNSEALED == "SUPER_SECRET_TPM_LAB"
```

Успешный exit code `tpm2_unseal` сам по себе недостаточен: содержимое тоже сравнивается.

---

## 13. TEST 6 — PCR-bound Seal / Unseal

Проверяемое security property:

```text
secret доступен только при ожидаемом PCR state
```

Тест содержит две части:

```text
trusted state   -> must succeed
tampered state  -> must be rejected
```

---

## 14. Trusted PCR scenario

### 14.1 Trusted state

PCR 16 сбрасывается и считывается:

```text
TRUSTED_PCR
```

Состояние сохраняется в `pcr.dat`.

### 14.2 PCR policy

Создаётся:

```bash
tpm2_createpolicy --policy-pcr
```

Получаем:

```text
TRUSTED_POLICY
```

### 14.3 Policy-bound secret

В TPM object запечатывается:

```text
PCR_BOUND_SECRET
```

с authorization policy, соответствующей trusted PCR state.

### 14.4 Реальная policy session

```bash
tpm2_startauthsession --policy-session
tpm2_policypcr
tpm2_unseal
```

Assertion:

```text
unsealed result == "PCR_BOUND_SECRET"
```

Только тогда:

```text
[PASS] Trusted PCR state allows Unseal
```

---

## 15. Tampered PCR scenario

После успешного trusted scenario runner реально меняет PCR:

```bash
tpm2_pcrextend
```

После этого снова считывает:

```text
TAMPERED_PCR
```

### Отдельный assertion

Сначала проверяется:

```text
TAMPERED_PCR != TRUSTED_PCR
```

Если PCR не изменился — `FAIL`.

То есть negative policy test не опирается на предположение, что state поменялся: runner это отдельно доказывает.

---

## 16. Policy rejection после изменения PCR

Создаётся новая policy session:

```bash
tpm2_startauthsession --policy-session
tpm2_policypcr
```

Затем runner пытается выполнить:

```bash
tpm2_unseal
```

для того же sealed object.

Ожидаемый security result:

```text
0x99D
a policy check failed
```

Negative assertion:

```text
Unseal unexpectedly returned secret
-> FAIL

TPM rejected specifically because policy failed
-> PASS

command failed for another reason
-> FAIL
```

Проверяемое свойство:

```text
trusted PCR
    ↓
Unseal allowed

PCR Extend
    ↓
state changed
    ↓
same sealed object
    ↓
Unseal denied by TPM
```

---

## 17. Evidence после запуска

Для каждого запуска создаётся:

```text
evidence/<timestamp>/
```

Типовая структура:

```text
evidence/<timestamp>/
├── start-swtpm.log
├── properties-fixed.txt
├── algorithms.txt
├── pcr-banks.txt
├── pcr-test.txt
│
├── signing/
│   ├── createprimary.log
│   ├── create-key.log
│   ├── load-key.log
│   ├── sign.log
│   ├── verify-original.log
│   └── verify-tampered.err
│
├── sealing/
│   ├── createprimary.log
│   ├── create-sealed.log
│   ├── load-sealed.log
│   └── unseal.err
│
└── pcr-policy/
    ├── pcr-read.log
    ├── trusted-policy.log
    ├── tamper-extend.log
    ├── tampered-policy.err
    ├── tampered-unseal.err
    └── policy-evidence.txt
```

Конкретные имена могут немного меняться вместе с runner, но принцип остаётся:

```text
summary PASS/FAIL
+
raw TPM output
+
TPM errors
+
PCR/policy values
```

---

## 18. Что показывает `policy-evidence.txt`

Для PCR policy scenario сохраняются ключевые значения:

```text
trusted_pcr=...
tampered_pcr=...
trusted_policy=...
tampered_policy=...
```

Это позволяет после запуска показать:

```text
trusted PCR != tampered PCR
trusted policy != tampered policy
```

без повторения эксперимента.

---

## 19. Почему negative tests особенно важны

Для security mechanism одного positive test недостаточно.

Нужно проверить:

```text
правильные данные / правильный state
-> operation allowed

нарушение защищаемого условия
-> operation denied
```

В runner есть как минимум две такие пары.

### Signature integrity

```text
original message
-> valid

modified message
-> TPM 0x2DB
```

### Platform-state policy

```text
trusted PCR
-> secret available

modified PCR
-> TPM 0x99D
```

Именно positive + negative pair показывает security property, а не только работоспособность команды.

---

## 20. Почему `ERROR` в negative test может означать PASS

Например:

```text
ERROR: ... 0x99D
a policy check failed
```

В обычном application log это ошибка.

Но ожидаемое свойство теста сформулировано заранее:

```text
После изменения PCR TPM должен запретить Unseal.
```

Следовательно:

```text
TPM разрешил Unseal
-> FAIL

TPM отказал именно из-за policy
-> PASS
```

То же относится к:

```text
0x2DB
the signature is not valid
```

для изменённого сообщения.

---

## 21. Управление TPM state

Object-based TPM scenarios зависят от внутреннего state.

Поэтому runner очищает transient objects/sessions между тестами.

Основная команда:

```bash
tpm2_flushcontext -t
```

Это появилось после реального наблюдения:

```text
0x902
out of memory for object contexts
```

То есть cleanup — результат реального troubleshooting, а не декоративная часть script.

---

## 22. Что backend-neutral, а что пока swtpm-specific

Большая часть проверяемых механизмов относится к TPM 2.0:

```text
GetCapability
GetRandom
PCR_Read
PCR_Extend
Create
Load
Sign
VerifySignature
Unseal
PolicyPCR
```

Например assertion:

```text
PCR_after == SHA256(PCR_before || measurement)
```

проверяет TPM semantics, а не конкретный vendor string.

Но текущий runner содержит и стенд-специфичные предположения:

- `TPM2TOOLS_TCTI=swtpm:...`;
- startup через `swtpm`;
- PCR 16 используется как resettable laboratory PCR;
- тексты ошибок соответствуют текущему stack;
- object/session lifecycle может отличаться при resource manager.

Поэтому запуск на `ms-tpm-20-ref` проверялся отдельно, а не объявлялся PASS заранее.

Повтор тех же assertions через `run-checks.sh` на reference simulator выполнен. Transport другой: TCTI `mssim`, platform port `2322`, явный `TPM2_Startup(CLEAR)`. Итог этого прогона — 10 PASS / 0 FAIL, коды отказа `0x2DB` и `0x99D` совпали. Запись прогона: [ARM64 Docker + ms-tpm-20-ref](docker-arm64-mssim.md).

---

## 23. Связь runner с Demo 1–4

| Runner test | Project demo |
|---|---|
| TPM Discovery | Demo 1 |
| PCR Read/Extend | Demo 2 |
| TPM-backed RSA Sign/Verify | Demo 3 |
| tampered signature | negative test Demo 3 |
| Basic Seal/Unseal | подготовка Demo 4 |
| PCR-bound secret | Demo 4 |
| changed PCR -> deny | negative test Demo 4 |

Runner — это автоматизированная форма проверки основных проектных сценариев.

---

## 24. Короткое объяснение преподавателю

> Runner не просто вызывает `tpm2-tools` и печатает PASS.
>
> В PCR test мы независимо считаем ожидаемый PCR через Python и сравниваем его с реальным значением TPM.
>
> В signing test сначала доказываем, что исходное сообщение проходит Verify, затем меняем сообщение и проверяем, что TPM отвергает ту же подпись именно как invalid signature.
>
> В PCR-policy test сначала доказываем successful Unseal при trusted state, потом реально меняем PCR через Extend и проверяем, что тот же объект TPM уже не раскрывает, возвращая policy check failed.
>
> Помимо summary runner сохраняет raw outputs и TPM errors каждого запуска.

---

## 25. Slide-ready схема

```text
                 AUTOMATED TPM RUNNER

TPM operation
     |
     v
Real TPM result / return code
     |
     v
Assertion
     |
     +----------------------+
     |                      |
 expected                unexpected
     |                      |
     v                      v
   PASS                    FAIL
     |
     v
raw evidence/
```

Representative examples:

```text
PCR
TPM Extend
-> actual PCR
-> compare with independent SHA-256
-> PASS / FAIL
```

```text
SIGNING
original -> Verify OK
tampered -> TPM 0x2DB
-> expected deny = PASS
```

```text
PCR POLICY
trusted PCR -> Unseal OK
PCR Extend
-> same object
-> TPM 0x99D
-> expected deny = PASS
```

---

## 26. Итог

Runner проверяет не факт запуска shell-команд, а конкретные свойства TPM 2.0:

```text
PCR semantics
signature integrity
sealing correctness
PCR-bound authorization
```

При этом:

- positive scenarios должны реально завершаться успехом;
- negative scenarios должны реально блокироваться TPM;
- неожиданный тип ошибки считается `FAIL`;
- raw outputs сохраняются как evidence;
- process exit code отражает общий результат.

Поэтому:

```text
PASS checks: 10
FAIL checks: 0
```

— это сводка реально выполненных assertions, а не вручную заданная строка.
