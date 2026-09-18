# Исследование TPM 2.0 simulator backends и инструментов

## Цель

Перед развёртыванием целевого виртуального TPM-стенда были рассмотрены
разные способы программной реализации TPM 2.0 и взаимодействия с ними.

Цель исследования — выбрать основной simulator/backend для TPM Lab,
определить software stack и спланировать дальнейшее сравнение разных
TPM implementations.

## 1. swtpm

`swtpm` — программная реализация TPM, широко используемая как backend
виртуального TPM в системах виртуализации.

В TPM Lab она может использоваться в двух режимах.

### Direct simulator mode

```text
tpm2-tools
    ->
TPM2-TSS
    ->
TCTI swtpm
    ->
swtpm
```

Этот вариант удобен для быстрых и воспроизводимых экспериментов,
потому что не требует сначала настраивать полноценную VM.

### Virtual TPM mode

```text
Ubuntu ARM64 guest
    ->
/dev/tpm*
    ->
QEMU/UTM virtual TPM frontend
    ->
swtpm backend
```

Этот вариант является более близким к целевой архитектуре проекта:
гостевая ОС взаимодействует уже с TPM device, а не непосредственно
с simulator socket.

### Причины выбора swtpm

Основным TPM simulator/backend проекта выбран `swtpm`.

Причины:

* работает в Linux ARM64;
* доступен в Ubuntu 24.04;
* поддерживает TPM 2.0;
* совместим с TPM2-TSS;
* может использоваться через direct TCTI;
* может использоваться как backend virtual TPM в QEMU;
* позволяет хранить и сбрасывать состояние;
* подходит для автоматизированных positive и negative tests;
* один backend можно использовать на раннем Docker-этапе и позднее
  в VM/vTPM архитектуре.

## 2. Microsoft TPM 2.0 Reference Implementation

`ms-tpm-20-ref` рассматривается как дополнительная reference
implementation TPM 2.0.

Для TPM Lab он интересен не как замена основному `swtpm`, а как второй
независимый software backend.

Цель дальнейшего эксперимента:

* развернуть `ms-tpm-20-ref`;
* подключить `tpm2-tools` через Microsoft simulator protocol / TCTI
  `mssim`;
* повторить минимальный vendor-neutral набор TPM-команд;
* сравнить результаты и особенности simulator lifecycle.

Минимальный обещанный scope следующего исследования:

* TPM Discovery;
* GetRandom;
* PCR Read;
* PCR Extend.

Signing и Seal/Unseal являются stretch goals и не считаются
обязательной частью следующего спринта.

## 3. QEMU virtual TPM

QEMU рассматривается не как отдельная реализация всей TPM logic,
а как слой, который может представить гостевой системе virtual TPM
frontend и передавать TPM-команды backend, например `swtpm`.

Целевая последовательность проекта:

```text
Mac Apple Silicon
    ->
UTM/QEMU
    ->
Ubuntu ARM64
    ->
virtual TPM device
    ->
swtpm
```

## 4. Выбранная стратегия

Проект использует постепенное усложнение стенда.

### Этап A — direct simulator

```text
Mac Apple Silicon
    ->
Docker / Ubuntu ARM64
    ->
tpm2-tools
    ->
TPM2-TSS
    ->
TCTI swtpm
    ->
swtpm
```

Назначение:

* проверить ARM64 compatibility;
* исследовать semantics TPM 2.0;
* реализовать тесты без дополнительной сложности VM;
* сформировать автоматизированный runner.

### Этап B — comparative simulator test

```text
same TPM scenarios
       /        \
    swtpm    ms-tpm-20-ref
```

Назначение:

* проверить переносимость базовых сценариев между software
  implementations.

### Этап C — virtual TPM

```text
Mac
 ->
UTM/QEMU
 ->
Ubuntu ARM64
 ->
TPM device
 ->
swtpm
```

Назначение:

* проверить те же сценарии в более реалистичной виртуализированной
  платформе.

## 5. Библиотеки и CLI

### tpm2-tools

`tpm2-tools` выбран как основной CLI для исследовательских сценариев.

Причины:

* позволяет выполнять отдельные TPM 2.0 operations;
* подходит для shell automation;
* показывает реальные TPM return codes;
* удобен для positive и negative tests;
* позволяет менять transport/backend без изменения смысла
  большинства TPM-команд.

### TPM2-TSS

TPM2-TSS используется как основной software stack.

### TCTI

TCTI отвечает за передачу TPM command/response между software stack
и TPM endpoint.

Текущий стенд:

```text
TPM2TOOLS_TCTI=swtpm:host=127.0.0.1,port=2321
```

Будущие варианты:

```text
mssim -> ms-tpm-20-ref
device -> /dev/tpm0 или /dev/tpmrm0
```

### FAPI и ESAPI

На последующих этапах проекта планируется реализовать эквивалентную
security operation через:

* FAPI — более высокоуровневый интерфейс TPM2-TSS;
* ESAPI — более явный интерфейс с управлением objects, sessions и
  последовательностью TPM operations.

На Sprint 02 FAPI/ESAPI ещё не реализованы.

## Вывод

`swtpm` выбран основным software TPM backend проекта.

`tpm2-tools + TPM2-TSS + TCTI` выбраны основным исследовательским
software stack.

`ms-tpm-20-ref` выбран как дополнительная reference implementation
для следующего сравнительного эксперимента.

QEMU/UTM vTPM остаётся целевой архитектурой стенда, а текущий Docker
direct-TCTI вариант используется как быстрый technical spike.

Связанные документы:

- [ADR-004: TPM simulator strategy](../decisions/ADR-004-simulator-strategy.md)
- [ARM64 Docker + swtpm technical spike](../labs/docker-arm64-swtpm.md)
- [Sprint 02](../sprints/sprint-02.md)
