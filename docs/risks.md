# Реестр рисков

Шкала: Probability и Impact принимают значения `Low`, `Medium`, `High`. Владелец риска проверяет Trigger на каждом Sprint review.

| ID | Risk | Probability | Impact | Mitigation | Trigger |
|---|---|---:|---:|---|---|
| R-01 | Проблемы интеграции vTPM между UTM/QEMU и `swtpm` | High | High | На неделе 3 проверить поддерживаемую схему подключения; документировать точные параметры и диагностический fallback | VM работает, но Ubuntu не видит TPM endpoint или TCTI не соединяется |
| R-02 | ARM64-несовместимость package, tool или примера | Medium | High | Проверять `aarch64` availability до фиксации версий; предусмотреть воспроизводимую сборку или замену | Package отсутствует для Ubuntu ARM64 либо работает только на x86_64 |
| R-03 | Состояние `swtpm` делает demo неповторяемым | High | High | Изолировать state, определить clean reset и проверять два последовательных clean run | Повторный запуск зависит от старых objects, handles или PCR state |
| R-04 | PCR demo становится недетерминированным | High | High | Зафиксировать bank/index, deterministic measurement и начальное состояние; независимо вычислять ожидаемый digest | Одинаковая процедура даёт необъяснимо разные результаты или не восстанавливает baseline |
| R-05 | Ошибочно предполагается, что emulator обеспечивает hardware protection | Medium | High | Во всех документах и защите разделять REAL/EMULATED/NOT MODELED; проводить review security claims | `swtpm` назван hardware TPM либо ему приписана физическая tamper resistance |
| R-06 | Сложность FAPI configuration и provisioning | High | Medium | Начать отдельный spike на неделе 13, фиксировать profile, keystore, TCTI и reset procedure | FAPI не provisioned, не находит keystore/profile или не выполняет выбранную operation |
| R-07 | Сложность ESAPI resource/session lifecycle | High | High | Ограничить сценарий эквивалентной операцией; проектировать cleanup и error paths до реализации | Утечки context/handle, неустойчивый повторный запуск или непрозрачные TSS errors |
| R-08 | Scope creep угрожает обязательному MVP | High | High | Приоритизировать Demo 1–4 и runner; Demo 6 оставить optional; новые идеи вести отдельно | Optional work начата до закрытия обязательного Sprint exit criteria |
| R-09 | Один участник становится единственным техническим contributor | Medium | High | Чередовать technical ownership, назначать второго reviewer и хранить evidence вклада каждую неделю | Большинство technical commits/demo запускает только Student A или только Student B |
| R-10 | Live demo не работает на семинаре | Medium | High | Использовать preflight, clean reset, rehearsal и диагностический план; не подменять live result записью | Preflight не проходит, demo превышает лимит или зависит от незаписанного ручного шага |
| R-11 | Исчерпание transient TPM object contexts без resource manager | Medium | High | Явно читать `handles-transient`, вызывать `tpm2_flushcontext`, не полагаться на неявные context files | Появляется `0x902` / `TPM_RC_OBJECT_MEMORY` / `out of memory for object contexts` |

## Sprint 02 status

| ID | Status after Sprint 02 |
|---|---|
| R-01 | Остаётся открытым: UTM/QEMU virtual TPM integration ещё не проверялась. |
| R-02 | Снижен / частично validated: Docker Ubuntu 24.04 ARM64 spike работал как `aarch64`; пакеты `swtpm`, `tpm2-tools` и `libtss2-tcti-swtpm0t64` установились и использовались. |
| R-03 | Частично снижен в Docker spike: каждый automated run поднимает чистый `swtpm` state. Для целевой VM процедура reset ещё не validated. |
| R-04 | Частично снижен: PCR 16 reset + независимый SHA-256 assertion прошли в direct-simulator runner. Детерминизм classroom VM demo ещё не проверен. |
| R-05 | Без изменения: документы продолжают отделять software TPM от hardware protection. |
| R-06 | Без изменения: FAPI не реализован. |
| R-07 | Без изменения: ESAPI не реализован. |
| R-08 | Без изменения: Docker spike не расширяет MVP до LUKS/Quote/FAPI. |
| R-09 | Без изменения: формальный human review вклада участников здесь не фиксируется. |
| R-10 | Частично снижен для spike: есть автоматизированный runner и runbook. Live seminar на целевой VM ещё не репетировался. |
| R-11 | Добавлен по факту Sprint 02: ошибка `0x902` исследована; runner использует dynamic transient handles и `tpm2_flushcontext`. |

## Sprint 04 status

| ID | Status after Sprint 04 |
|---|---|
| R-01 | Снижен для QEMU `virt`: гость видит `tpm_tis` и проходит 10/0 через `/dev/tpmrm0`. Отдельный UTM GUI-профиль не проверялся. |
| R-02 | Без нового сигнала: гостевые `tpm2-tools` 5.6 на Ubuntu 24.04.5 arm64 отвечают. |
| R-03 | Процедура reset есть: `infra/vm/run-lab.sh reset && up`. `kill -9` по QEMU портит гостевой dpkg, это не clean reset. |
| R-04 | PCR 16 через устройство совпал с тем же независимым SHA-256, что и на сокете. |
| R-11 | Дополнение: `/dev/tpmrm0` не показывает transient handles. Runner использует context file, если `getcap` пуст. |
