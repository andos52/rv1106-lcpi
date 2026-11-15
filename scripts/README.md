# Скрипты

## Целевые (Pi4Joy)
- `prepare_radio.sh` — базовый LCPI-профиль для радио (v1.8.0).
- `prepare_joy.sh` — профиль `LCPI_JOY`: USB host/HID, eudev, CMA 32M.
- `build_joy.sh` — полная сборка `lcpi-joy.img`.
  - `--repack-only` — переиспользовать rootfs, только overlay + repack.
  - `--skip-prepare` — не трогать профиль SDK.
- `repack_joy.sh` — совместимая обёртка `build_joy.sh --repack-only`.
- `set_joy_identity.sh` — `node_id=251`, `source=pi4joy` во всех местах.
- `clean_radio_assets.sh` — убрать radio/telemetry из media staging.
- `fix-e2fs-dirs.sh` — обход e2fsprogs/coreutils на Ubuntu 26.04.
- `status.sh` — прогресс сборки и выбранный профиль.
- `check.sh` — синтаксис shell/python и базовые проверки без SDK.
- `joy_replug_test.sh` — замер появления пультов (запускать на плате).
- `lib/common.sh` — общие функции и константы (не запускать напрямую).

## Bring-up и история
Эти файлы оставлены для воспроизводимости bring-up/LTE-экспериментов:
- `build_image.sh`, `prepare_board.sh`, `fetch-sdk.sh`
- `configure_image.py`, `configs/image.example.json`, `overlay/`
- `prepare_bort4g.sh` (LTE/WireGuard, не целевой режим)

## Прошивка
- `flash_usb.ps1` — USB Maskrom (`upgrade_tool`).
- `flash_sd.ps1` — запись microSD с проверкой SHA256.
- `build-status.ps1` / `build-status.cmd` — статус через WSL.

## Переменные
- `SDK_DIR` — путь к SDK (по умолчанию `~/rv1106-sdk/bort4g-radio`).
- `JOY_NODE_ID`, `JOY_SOURCE`, `JOY_IMAGE_NAME` — идентичность образа.
- Секреты не хранятся в git: `firmware/pi4joy/etc/pi4joy/env` в `.gitignore`.
