# Sprint 04 Defense Notes

## 1. What we did this sprint

Собрали целевую цепочку, которая до этого была только схемой:
Mac, QEMU, Ubuntu ARM64, virtual TPM, swtpm. Тот же набор проверок,
что на Docker-стенде, прошёл через `/dev/tpmrm0`: 10 PASS / 0 FAIL.

Рядом на сокете: ESAPI без `tpm2-tools` (10 PASS / 0 FAIL), та же
PCR-операция через FAPI/`tss2`, и Кузнечик, у которого ключ запечатан
в TPM, а блок считает программа. Это не команда TPM, как AES.

## 2. What changed relative to Sprint 03

Sprint 03 сравнивал два simulator по TCP. Гость там не участвовал.
Сейчас гость видит TPM как устройство. Команды те же, транспорт другой.

## 3. Architecture in one picture

```text
macOS
  QEMU virt, accelerator HVF
    Ubuntu 24.04.5 aarch64
      tpm2-tools
        TCTI device:/dev/tpmrm0
          ядро, драйвер tpm_tis
            QEMU tpm-tis-device
              swtpm на Mac
```

swtpm по-прежнему программа на host. Гость не открывает его сокет.

## 4. Why this QEMU line, not a click-path in UTM

UTM 4.6.4 стоит на машине и умеет звать QEMU. В репозиторий положен
скрипт `infra/vm/run-lab.sh`, потому что его можно повторить и
сбросить. Backend Apple Virtualization не используется: virtual TPM
там нет. В QEMU 10.1 для aarch64 нет `tpm-crb-device`, есть
`tpm-tis-device`. Его и подключили.

## 5. What the guest actually saw

```text
tpm_tis MSFT0101:00: 2.0 TPM (device-id 0x1, rev-id 1)
Manufacturer: IBM
Family: 2.0
Revision: 1.83
```

`MSFT0101` — ACPI-имя TPM 2.0. `device-id 0x1` и `IBM` — это swtpm,
не физический чип и не reference simulator из прошлого спринта.

## 6. What is real and what is emulated

Реально исполняются QEMU, Ubuntu, tpm2-tools и swtpm. Реальны PCR,
подпись, коды `0x2DB` и `0x99D`.

Эмулируется само TPM-устройство: это процесс swtpm.
Аппаратной tamper resistance нет. Владелец Mac видит файл состояния.

## 7. One bug worth telling

Первый signing через `/dev/tpmrm0` не нашёл transient handle.
Resource manager ядра не показывает их в `tpm2_getcap handles-transient`,
хотя ключ создался. Runner теперь использует context file.
После этого гость дал 10 PASS / 0 FAIL, и сокетный прогон тоже.

## 8. 60-second defense script

«В этом спринте мы впервые подняли целевую среду. На Mac работает QEMU,
внутри Ubuntu 24.04 ARM64. swtpm запущен на host и подключён к виртуальной
машине как устройство tpm-tis. Гость видит /dev/tpm0 и /dev/tpmrm0 и
ходит в TPM обычным TCTI device, не в TCP-сокет. Discovery показал TPM 2.0
производителя IBM: так представляется swtpm. Тот же runner, что на Docker,
прошёл десять проверок из десяти: PCR совпал с независимым SHA-256,
испорченная подпись получила 0x2DB, Unseal после Extend получил 0x99D.
Это по-прежнему программный TPM. Физической защиты чипа мы не заявляем.
Рядом на старом сокете заработал короткий модуль на ESAPI, он VM не заменяет.»

## 9. Likely questions

1. Почему это ещё не аппаратный TPM?
2. Зачем виртуальная машина, если Docker уже давал 10 PASS?
3. Почему `tpm-tis-device`, а не CRB?
4. Кто выполняет `TPM2_Startup`?
5. Почему manufacturer IBM, а в Sprint 03 был XYZ?
6. Что такое `/dev/tpmrm0`?
7. Почему первый signing упал?
8. Можно ли повторить стенд с нуля?
9. Где UTM?
10. Что не сделано?

## 10. Short answers

1. swtpm — программа. Она отвечает на команды TPM 2.0 и хранит state в файле на Mac. От хозяина машины это state не защищено.
2. Docker проверял семантику команд. VM проверяет другой транспорт: устройство в госте. Это и есть целевая архитектура.
3. В QEMU 10.1 для aarch64 CRB-устройства нет. Linux на Ubuntu связался с `tpm_tis` и ACPI-таблицей TPM2.
4. Firmware и ядро гостя. Поэтому swtpm запущен без флага `startup-clear`, которым пользовался Docker-стенд.
5. Это разные backend. Сейчас подключён swtpm, он сообщает IBM. XYZ был у `ms-tpm-20-ref`.
6. Узел resource manager в ядре. Через него tpm2-tools делят один TPM, не открывая `/dev/tpm0` напрямую.
7. Resource manager не отдаёт transient handles в `getcap`. Объект при этом был. Runner переключился на context file.
8. `infra/vm/run-lab.sh reset`, затем `up`. Образ сверяется по SHA-256. QEMU нельзя убивать `kill -9`: так рвётся dpkg гостя.
9. UTM установлен и является GUI над тем же QEMU. В репозитории зафиксирована командная строка, её проще проверять.
10. Повтор вторым участником, сверка ТЗ с этой VM, FAPI и сравнение с ESAPI. Quote и LUKS не входят в этот спринт.
