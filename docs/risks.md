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
