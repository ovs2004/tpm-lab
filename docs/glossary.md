# Глоссарий TPM Lab

Краткие определения для подготовки к лабораторной работе и защите.

## TPM

**Trusted Platform Module** — компонент с определённым набором команд для ключей, измерений, policy и других security operations. TPM может быть дискретным чипом, firmware implementation или software emulator; свойства защищённости у этих вариантов различаются.

## TPM 2.0

Современное семейство спецификаций Trusted Computing Group для TPM commands, data structures, algorithms, authorization и platform integration.

## Root of Trust

Минимальная часть системы, которой доверяют как исходной точке для измерения, хранения или проверки. Если она неверна, построенная на ней цепочка доверия также ненадёжна.

## Hardware Root of Trust

Root of Trust, чья security boundary опирается на hardware. В проекте изучаются её концепции, но `swtpm` остаётся software emulator и не создаёт физическую hardware trust boundary.

## PCR

**Platform Configuration Register** — регистр TPM для накопления measurements. Обычно новое значение получают через `Extend`, а не произвольной записью.

## PCR Extend

Операция обновления PCR по схеме `newPCR = Hash(oldPCR || measurementDigest)`. Порядок measurements влияет на итог.

## Measurement

Digest некоторого компонента, конфигурации или события, добавляемый в цепочку измерений. Measurement сообщает, *что было измерено*, но сам по себе не доказывает безопасность объекта.

## Hash

Функция, преобразующая данные произвольной длины в digest фиксированной длины. Криптографический hash предназначен для обнаружения изменений и устойчивости к поиску коллизий в рамках свойств алгоритма.

## Asymmetric key pair

Связанные private key и public key. Private key выполняет закрытую операцию, а public key позволяет проверять подпись или выполнять другую открытую операцию в зависимости от scheme.

## Private key

Секретная часть asymmetric key pair. Для TPM-backed key приложение обычно работает с TPM object, а не использует private key как обычный plaintext key file.

## Public key

Открытая часть asymmetric key pair. Её можно распространять для проверки signatures или иных операций, предусмотренных key scheme.

## Signing

Создание digital signature с помощью private key над данными или их digest. Подпись связывает key и подписанное значение, но не шифрует данные.

## Verification

Проверка digital signature соответствующим public key. Успех означает соответствие подписи, ключа и входных данных, но не устанавливает личность владельца без дополнительной модели доверия.

## Seal

Создание TPM object с данными, доступ к которым ограничен authorization/policy. В лаборатории secret планируется связать с PCR state.

## Unseal

Получение данных из sealed object после успешного выполнения authorization policy. При несовпадении policy TPM должен отклонить операцию.

## Policy

Формализованное условие TPM authorization: например, требование конкретного PCR state. Policy digest строится из последовательности policy commands.

## Measured Boot

Boot process, при котором measurements компонентов загрузки записываются в PCR и обычно сопровождаются event log. Он фиксирует наблюдаемое состояние, но сам по себе не блокирует запуск.

## Secure Boot

Механизм, разрешающий загрузку только доверенных по signature/policy компонентов. Secure Boot контролирует допуск, а Measured Boot регистрирует measurements; это разные механизмы.

## TSS

**TPM Software Stack** — software layers и API, через которые приложения взаимодействуют с TPM.

## TPM2-TSS

Open-source implementation TPM 2.0 Software Stack: libraries, API layers и TCTI components для доступа к TPM 2.0.

## FAPI

**Feature API** — высокоуровневый API TPM2-TSS с profiles и управляемым lifecycle объектов. Скрывает многие низкоуровневые шаги.

## ESAPI

**Enhanced System API** — API TPM2-TSS, предоставляющий более явное управление handles, sessions, authorization и TPM operations, чем FAPI.

## SAPI

**System API** — более низкий слой TPM2-TSS для подготовки команд и обработки ответов. Требует от приложения больше деталей протокола, чем ESAPI.

## TCTI

**TPM Command Transmission Interface** — transport abstraction, передающая TPM commands между software stack и конкретным TPM endpoint.

## swtpm

Software implementation/emulator TPM. Он реально исполняет TPM commands, но не является физическим TPM и не обеспечивает physical tamper resistance.

## QEMU

Open-source machine emulator и virtualizer. В проекте он служит runtime для ARM64 virtual machine и её virtual devices/connections.

## UTM

macOS application/frontend для управления виртуальными машинами на основе QEMU и Apple virtualization capabilities. Упрощает конфигурацию и запуск Ubuntu ARM64 guest.

## Ключевое различие лаборатории

- **Реально исполняется:** Mac, virtualization runtime, Ubuntu guest и весь software stack.
- **Эмулируется:** TPM 2.0 посредством `swtpm`.
- **Не моделируется:** физическая tamper/side-channel/chip-attack resistance.
