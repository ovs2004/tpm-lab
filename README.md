# TPM Lab

Учебный командный проект по исследованию TPM 2.0 и механизмов hardware root of trust в виртуализированной среде.

## Проблема и учебная цель

TPM объединяет аппаратные концепции, протокол команд и несколько уровней software stack. Из-за этого начинающему трудно связать PCR, ключи, policy и sealing с наблюдаемым поведением системы. Проект должен дать воспроизводимую лабораторию, в которой два студента смогут поэтапно исследовать:

- обнаружение TPM и чтение capabilities;
- чтение и `Extend` регистров PCR;
- создание TPM-backed ключей, подпись и проверку;
- sealing секрета и привязку `Unseal` к PCR policy;
- различия уровней абстракции FAPI и ESAPI.

## Важная граница модели

Лаборатория планируется на реальном Mac с Apple Silicon, с реально исполняемыми Ubuntu ARM64, TPM2-TSS, `tpm2-tools` и будущими программами. Сам TPM 2.0 будет **эмулирован программой `swtpm`**. Это позволяет исследовать интерфейсы и поведение TPM, но **не моделирует физическую tamper resistance, side-channel resistance или стойкость отдельного TPM-чипа к физическим атакам**.

## Планируемая архитектура

```text
macOS Apple Silicon
  -> UTM / QEMU
    -> Ubuntu 24.04 ARM64
      -> TPM Lab Runner
        -> tpm2-tools / будущие FAPI и ESAPI программы
          -> TPM2-TSS
            -> TCTI
              -> swtpm (эмуляция TPM 2.0)
```

Подробности и границы доверия: [архитектура](docs/architecture.md).

## Текущий этап

Выполнены четыре спринта. Целевой путь `Mac -> QEMU -> Ubuntu ARM64 -> /dev/tpmrm0 -> swtpm` поднят и прогнан тем же runner (10 PASS / 0 FAIL). Одна PCR-операция дополнительно сравнена через ESAPI и FAPI. Кузнечик считается программой, ключ запечатан в TPM. Quote и LUKS не реализованы. Встройка Кузнечика в `libtpms` — план следующего шага.

- **Sprint 01** — проектный baseline: charter, Architecture v0.1, ТЗ v0.1, backlog, DoD, risks и ADR по Apple Silicon / Linux VM / `swtpm`.
- **Sprint 02** — ARM64 Docker technical spike с software TPM `swtpm` и общий набор TPM-проверок (10 PASS / 0 FAIL).
- **Sprint 03** — тот же набор на Microsoft TPM 2.0 Reference Implementation (`ms-tpm-20-ref`) через TCTI `mssim` (снова 10 PASS / 0 FAIL).
- **Sprint 04** — QEMU ARM64 VM и virtual TPM (10 PASS / 0 FAIL через `/dev/tpmrm0`). Рядом ESAPI на сокете (10 PASS / 0 FAIL), сравнение ESAPI/FAPI на PCR-seal и Кузнечик с ключом в TPM (8 PASS / 0 FAIL).

Docker-стенды остаются исследовательскими. Демонстрации дальше идут из гостя.

## Current technical spike

Воспроизводимые ARM64 Docker laboratories:

- [ARM64 Docker + swtpm](docs/labs/docker-arm64-swtpm.md) — [runbook](docs/labs/docker-arm64-swtpm-runbook.md) — Sprint 02
- [ARM64 Docker + ms-tpm-20-ref](docs/labs/docker-arm64-mssim.md) — [runbook](docs/labs/docker-arm64-mssim-runbook.md) — Sprint 03
- [QEMU ARM64 + virtual TPM](docs/labs/qemu-arm64-vtpm.md) — [runbook](docs/labs/qemu-arm64-vtpm-runbook.md) — Sprint 04
- [ESAPI, FAPI и ключ Кузнечика](docs/labs/fapi-esapi-kuznyechik.md)
- [Дальше: Кузнечик внутри TPM](docs/labs/kuznyechik-inside-tpm.md)
- [Облачный vTPM](docs/research/cloud-vtpm.md)

Отчёты спринтов:

- [Sprint 01](docs/sprints/sprint-01.md)
- [Sprint 02](docs/sprints/sprint-02.md)
- [Sprint 03](docs/sprints/sprint-03.md)
- [Sprint 04](docs/sprints/sprint-04.md)

## План на 17 недель

- недели 1–6: charter, requirements, architecture, technical specification и воспроизводимый дизайн среды;
- недели 7–12: обязательные demo и интегрированный MVP;
- недели 13–17: FAPI/ESAPI, тестирование, стабилизация, документация и совместная защита.

Детальный план: [roadmap](docs/roadmap.md), [backlog](docs/backlog.md) и [demo roadmap](docs/demo-roadmap.md).

## Структура репозитория

```text
README.md                  — точка входа для преподавателя
docs/
  project-charter.md       — цели, scope и критерии успеха
  requirements.md          — функциональные и нефункциональные требования
  technical-specification.md — техническая спецификация v0.1
  architecture.md          — deployment, software stack и demo flow
  glossary.md              — краткий словарь терминов
  sprints/                 — еженедельные Sprint records
  demo-notes/              — сценарии и материалы защиты
  research/                — исследования simulator backends и сравнение с Handbook
  labs/                    — лабораторные стенды и runbook
infra/
  docker-tpm/              — ARM64 Docker + swtpm и ms-tpm-20-ref technical spikes
  vm/                      — QEMU ARM64 + swtpm, Sprint 04
  setup/                   — указатель на setup целевой среды
demos/                     — будущие автоматизированные демонстрации
src/                       — ESAPI-модуль поверх simulator socket; FAPI ещё нет
tests/                     — будущие автоматические проверки
scripts/                   — будущие setup/reset/run scripts
```

Каталоги целевой VM/FAPI/ESAPI реализации содержат поясняющие README. Исполняемые Docker spikes Sprint 02 (`swtpm`) и Sprint 03 (`ms-tpm-20-ref`) находятся в `infra/docker-tpm/` и не являются финальным MVP.

## Как организуется еженедельная работа

Каждая из 17 недель — отдельный Sprint с явными Sprint Goal, задачами, владельцем и reviewer, acceptance criteria, фактически завершённой работой, demo evidence, рисками и планом следующего Sprint. Student A и Student B должны поочерёдно выполнять и проверять технические задачи; документация не закрепляется только за одним участником.

Процесс готовности описывает [Definition of Done](docs/definition-of-done.md), риски — [risk register](docs/risks.md), рекомендуемую доску — [GitHub Projects setup](docs/github-projects.md).

## Основные документы

- [Project Charter](docs/project-charter.md)
- [Requirements](docs/requirements.md)
- [Technical Specification v0.1](docs/technical-specification.md)
- [Architecture](docs/architecture.md)
- [Glossary](docs/glossary.md)
- [17-week Roadmap](docs/roadmap.md)
- [Backlog](docs/backlog.md)
- [Demo Roadmap](docs/demo-roadmap.md)
- [Definition of Done](docs/definition-of-done.md)
- [Risks](docs/risks.md)
- [GitHub Projects setup](docs/github-projects.md)
- [Sprint 01](docs/sprints/sprint-01.md)
- [Sprint 01 defense notes](docs/demo-notes/sprint-01-defense.md)
- [Sprint 02](docs/sprints/sprint-02.md)
- [Sprint 03](docs/sprints/sprint-03.md)
- [Sprint 04](docs/sprints/sprint-04.md)
- [Sprint 04 defense notes](docs/demo-notes/sprint-04-defense.md)
- [ADR-004: TPM simulator strategy](docs/decisions/ADR-004-simulator-strategy.md)
- [Исследование TPM simulators](docs/research/tpm-simulators-and-tooling.md)
- [Сравнение с TPM Handbook](docs/research/tpm-handbook-comparison.md)
- [ARM64 Docker + ms-tpm-20-ref](docs/labs/docker-arm64-mssim.md)
- [Дизайн runner](docs/labs/runner-design.md)
