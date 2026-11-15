# LCPI-RV1106 Joystick Node

Прошивка для платы **LCPI-RV1106 V1.4** (RV1106G2, 128 МБ RAM, 256 МБ
SPI NAND) как узла USB-джойстиков для НСУ: до 4 пультов → evdev → pi4joy →
Ethernet → `masha-gcs`. 

## Возможности
- 4 слота TX12, фиксированный USB-порт → слот.
- Только USB HID и Ethernet.
- Минимальный rootfs, eudev, SSH, статический `.251`.
- НСУ видит `remote-pi4joy-1..4`, слоты 1–4.
- API-контракт зафиксирован: `docs/03-api-contract.md`.

## Структура
```
board/dts/      LCPI DTS (SPI NAND, USB host)
docs/           описание, API, сборка, прошивка, диагностика
firmware/       pi4joy overlay (бинарник, init, slots, env)
scripts/        prepare/build/repack, status, check, flash
```

## Быстрый старт
```bash
export SDK_DIR=$HOME/rv1106-sdk/bort4g-joy
./scripts/prepare.sh
./scripts/build.sh
```
Прошивка:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  .\scripts\flash_usb.ps1 -Image .\dist\lcpi-joy.img -Force
```

## Статус
| Этап | Статус |
|---|---|
| Плата, Maskrom, UART, Ethernet | готово |
| 4 пульта, слоты, by-path | готово |
| Минимальный образ | готов, требует прошивки |
| API-контракт | зафиксирован |
| Idle-трафик | исправлен, проверяется после прошивки |

## Документация
- `docs/01-плата.md`
- `docs/02-архитектура.md`
- `docs/03-api-contract.md`
- `docs/04-сеть.md`
- `docs/05-чеклист.md`
- `docs/06-диагностика.md`
- `docs/07-сборка.md`
- `docs/08-прошивка.md`
- `docs/09-журнал.md`
