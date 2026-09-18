# ADR-003: `swtpm` как программный TPM

## Status

Proposed — требует review Student B и последующей проверки ARM64/Linux-интеграции.

## Context

Учебной лаборатории нужен управляемый TPM 2.0 endpoint для изучения команд, объектов, PCR, sealing и связанных workflows. Доступ к отдельному hardware TPM на Apple Silicon host не предполагается, а эксперименты должны быть повторяемыми и не затрагивать host security state. Программная реализация позволяет создавать и сбрасывать состояние в контролируемой guest-среде.

## Decision

Использовать `swtpm` как программную реализацию TPM 2.0 для будущей виртуализированной Linux-лаборатории. Его state, параметры запуска и интерфейс подключения к guest должны быть воспроизводимо описаны и изолированы в рамках лаборатории.

`swtpm` **не обеспечивает физическую tamper resistance и не считается эквивалентом hardware TPM**. Результаты лаборатории подтверждают работу с TPM-интерфейсами и моделируемым состоянием, но не доказывают аппаратную защиту ключей, устойчивость к физическим атакам или эквивалентный hardware-backed trust.

## Rationale

- `swtpm` поддерживает TPM 2.0-oriented эксперименты без отдельного физического модуля.
- Управляемый state облегчает повторение сценариев, reset и диагностику.
- Программный TPM подходит для обучения API, командным последовательностям и интеграции tooling.
- Решение совместимо с архитектурным разделением macOS host и Linux guest при условии будущей проверки конкретной интеграции.

## Alternatives considered

- **Hardware TPM на отдельной Linux-системе:** ближе к production hardware properties, но требует дополнительного оборудования и усложняет безопасный reset.
- **TPM, предоставляемый cloud VM:** может быть доступен как managed feature, но добавляет внешние зависимости, стоимость и ограничения провайдера.
- **Mock/stub API:** прост для unit tests, но слишком мало воспроизводит поведение TPM state machine и стандартных tools.
- **Использование только Apple platform security facilities:** не предоставляет требуемую Linux TPM 2.0 laboratory interface и решает другую задачу.

## Consequences

- Потребуются version pinning, конфигурация persistent state и процедура reset.
- Необходимо определить transport/interface между `swtpm`, hypervisor и Linux guest.
- Threat model обязан рассматривать host и файлы состояния `swtpm` как часть trusted computing base лаборатории.
- Секреты в software-backed state защищены только в пределах свойств host, VM и файловых permissions; аппаратная изоляция не подразумевается.
- Выводы и демонстрации должны явно маркироваться как результаты программной эмуляции.

## Limitations

- Отсутствуют физическая tamper resistance, hardware-backed key isolation и доказанная устойчивость к side-channel или invasive attacks.
- `swtpm` не эквивалентен hardware TPM по security guarantees, timing, firmware behavior и интеграции с platform boot chain.
- ADR не задает версию `swtpm`, команды установки, параметры запуска или формат VM-конфигурации.
- Функциональная совместимость с выбранным ARM64 guest и hypervisor пока не проверена.
