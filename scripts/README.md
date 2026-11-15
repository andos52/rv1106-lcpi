# Скрипты

## Сборка
- `prepare.sh` — профиль `LCPI_JOY`: USB host/HID, eudev, CMA 32M.
- `build.sh` — полная сборка `lcpi-joy.img` (prepare + allsave + inject + repack).
  - `--repack-only` — только overlay + repack без allsave.
  - `--skip-prepare` — не трогать профиль SDK.
- `repack.sh` — обёртка `build.sh --repack-only`.
- `configure-identity.sh` — выставить `PI4JOY_NSU_SOURCE=pi4joy`.
- `strip-non-joy.sh` — убрать лишние сервисы из staging.
- `fix-e2fs-dirs.sh` — обход e2fsprogs/coreutils на Ubuntu 26.04.
- `status.sh` — прогресс сборки и выбранный профиль.
- `check.sh` — синтаксис shell и обязательные документы (без SDK).
- `test-replug.sh` — замер появления пультов (запускать на плате).
- `lib/common.sh` — общие функции (не запускать напрямую).

## Прошивка
- `flash_usb.ps1` — USB Maskrom (`upgrade_tool`).
- `flash_sd.ps1` — запись microSD с проверкой SHA256.
- `build-status.ps1` / `build-status.cmd` — статус через WSL.

## Переменные
- `SDK_DIR` — SDK (по умолчанию `~/rv1106-sdk/bort4g-joy`).
- `IMAGE_NAME` — имя образа (по умолчанию `lcpi-joy.img`).
- `SOURCE` — источник для НСУ (по умолчанию `pi4joy`).
- `NODE_IP` / `NODE_PREFIX` — адрес узла (`.251/24`).
- Секреты не в git: `firmware/pi4joy/etc/pi4joy/env` в `.gitignore`.
