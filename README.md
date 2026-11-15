# RV1106 — бортовая камера masha на LCPI-RV1106 V1.4

Плата **LC Technology LCPI-RV1106 V1.4** (Rockchip **RV1106G2**, 128 МБ RAM,
256 МБ SPI NAND, SC3336 3MP, 100M Ethernet) как полевой узел masha:
камера → H.265 (MPP) → `vcpd` → `radiod`/ULAMA → USB **AR9271** → НСУ
(`masha-gcs`). Приём видео на борт не требуется; только видео вверх и
управление/телеметрия вниз.

```
камера CSI → RV1106G2 (MPP HEVC) → vcpd → radiod → mon0 (AR9271, ch6)
        → ULAMA/UNOW по 802.11 → radiod/ulama-gw на НСУ → cascade-core → UI
UVCP READY/STOP/PING идёт по тому же radio-линку
```

LTE-модем и WireGuard из ветки `bort4g` HEAD **не используются**.

## Две прошивки
| Профиль | Назначение | Приоритет |
|---|---|---|
| `lcpi_joy` | замена Pi4Joy: USB-джойстики → Ethernet → НСУ | **сейчас** |
| `lcpi_radio` | дрон: камера → AR9271 → `radiod`/ULAMA | отложен |

Общая база — LCPI SPI NAND, DTS и разделы; различаются overlay,
сервисы и kernel config.

## Текущее состояние (2026-11-15)
- Плата определяется в Maskrom (`VID_2207/PID_110C`) и прошивается.
- Приборный (bring-up) образ **прошит и проверен по UART**: Linux
  5.10.160, `root/luckfox`, NAND/разделы OK. SSH по Ethernet ещё не
  проверен (нет линка). Это не радио-образ.
- Выявлено: RAM всего 54 МБ из-за `rk_dma_heap_cma=66M`; USB-хост не
  поднят (`/sys/bus/usb/devices` пуст); камеры `/dev/video*` нет.
- Целевая радио-сборка — из тега masha **v1.8.0** (`5e7ad171c3`),
  worktree `~/rv1106-sdk/bort4g-radio`.
- Радио-сборка **остановилась** на rootfs из-за отсутствия исходника
  Buildroot; source восстановлен, сборка перезапущена (не завершена).
- Камера/`/dev/video*`, `mon0`, `radiod` и видео на НСУ ещё не проверены.

## Быстрый старт (радио-сборка)
```bash
# worktree уже создан: ~/rv1106-sdk/bort4g-radio (v1.8.0)
# профиль LCPI:
SDK_DIR=$HOME/rv1106-sdk/bort4g-radio ./scripts/prepare_radio.sh

# после исправления Buildroot:
cd ~/rv1106-sdk/bort4g-radio
CMAKE_POLICY_VERSION_MINIMUM=3.5 ./build.sh allsave
ls output/image/update.img
```
Прошивка:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\flash_usb.ps1 -Image <update.img> -Force
```

## Структура
```
board/dts/      LCPI DTS (Pro Max-база, RV1106G2, SPI NAND)
configs/        image.example.json — только для bring-up (не радио)
docs/           актуальная документация
overlay/        bring-up overlay (Wi-Fi STA/vcpd), не используется в радио
scripts/        prepare/build/flash, status, check, lib/common.sh
```

Проверка репозитория без SDK и платы:
```bash
./scripts/check.sh
```

## Статус
| Этап | Статус |
|---|---|
| Идентификация платы и памяти | готово |
| Maskrom и первая прошивка | готово; boot, UART (115200), NAND подтверждены |
| Документация | обновлена под радио и Pi4Joy |
| Радио-сборка masha v1.8.0 | `dist/lcpi-radio.img` собран, не прошит |
| Pi4Joy (`lcpi_joy`) | **работает**: TX12 online, НСУ видит `remote-pi4joy-1` |
| USB-хост | подтверждён; хаб не подхватил стик, напрямую — OK |
| Камера/`mon0`/видео | не проверено |

## Документация
- `docs/01-плата.md` — плата и память
- `docs/02-прошивка.md` — варианты и источники образа
- `docs/03-чеклист.md` — проверки bring-up и радио
- `docs/04-существующие-инструменты.md` — SDK, worktree, инструменты
- `docs/05-требования.md` — требования радио-режима
- `docs/06-архитектура.md` — радио-тракт, ULAMA, UVCP
- `docs/07-сборка.md` — сборка v1.8.0 под LCPI
- `docs/08-прошивка.md` — прошивка и восстановление
- `docs/09-план.md` — этапы, вопросы, риски
- `docs/10-журнал.md` — хронология bring-up
- `docs/11-анализ-masha.md` — разбор masha/bort4g и почему не LTE
- `docs/12-pi4joy.md` — прошивка-замена Pi4Joy (приоритет)
- `docs/13-измерения.md` — измерения UART/RAM/NAND/USB
- `docs/14-сеть-адреса.md` — IP НСУ/Pi4Joy/бортов
