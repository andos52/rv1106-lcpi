# 12. Прошивка Pi4Joy (приоритет)

## 1. Две прошивки из одной платы
| Профиль | Назначение | Статус |
|---|---|---|
| `lcpi_radio` | дрон: камера → AR9271 → `radiod`/ULAMA → НСУ | отложен |
| `lcpi_joy` | замена Pi4Joy: USB-джойстики → Ethernet → НСУ | **приоритет** |

Общие: плата LCPI-RV1106 V1.4, SPI NAND 256 МБ, DTS LCPI, разделы
env/idblock/uboot/boot/oem/userdata/rootfs. Различаются overlay, набором
сервисов и kernel config (камера/радио vs USB HID).

## 2. Что делает Pi4Joy
`pi4joy` — Go-сервис:
1. читает до 4 USB-джойстиков из evdev `/dev/input/by-path/*-event-joystick`;
2. нормализует оси/кнопки по профилям, слоты 1..4;
3. отдаёт локальный WS `:8090/ws` и `/healthz`;
4. сам подключается к НСУ `ws://<НСУ>/api/v1/ws/joystick-input?source=...`
   с Bearer-токеном и шлёт RC-каналы 16×1000..2000 мкс на 50 Гц;
5. при обрыве НСУ гасит слоты по watchdog (750 мс).

Сеть — **Ethernet**, Wi-Fi не нужен. Видео/камера не нужны.

## 3. Что портировать на RV1106
| Задача | Детали |
|---|---|
| Cross-build | `GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0` (не arm64); бинарник ~7–8 МБ |
| **32-бит evdev** | Сейчас код жёстко читает `input_event` = 24 байта (64-бит). На ARMv7 структура **16 байт** (timeval 8 + type 2 + code 2 + value 4). Без патча джойстики не работают |
| `/dev/input/by-path` | Нужен eudev (создаёт by-path) или патч сканера на `/dev/input/event*` + sysfs |
| Kernel | `CONFIG_INPUT_EVDEV=y` уже есть; добавить USB host/DWC3 host, `CONFIG_USB_HID`, `CONFIG_HID_GENERIC` |
| Init | Вместо systemd — `S95pi4joy` (start-stop-daemon), env `/etc/pi4joy/env` |
| Данные | `-data-dir /userdata/pi4joy` (slots.json), profiles `/opt/pi4joy/profiles` |
| Сеть | DHCP (S41dhcpcd) или static; НСУ в том же L2 |
| Питание/USB | Type-C один: нужен **powered USB hub** для 4 джойстиков |

## 4. Профиль сборки `lcpi_joy`
- База: masha v1.8.0 SDK (тот же SPI NAND/DTS), но:
  - `RK_APP_TYPE=` (без rkipc), без `radiod`/`vcpd`/`S39wifi`;
  - `BR2_PACKAGE_EUDEV=y` (by-path) или патч pi4joy;
  - USB HID/evdev в kernel;
  - overlay: `/opt/pi4joy/pi4joy`, `/etc/pi4joy/env`, `S95pi4joy`;
  - rootfs меньше, чем радио-образ; 128 МБ RAM достаточно.
- Сборка: отдельный worktree/копия SDK или переключение `.BoardConfig.mk`
  на `LCPI_JOY` после радио-сборки.

## 5. Конфиг
`/etc/pi4joy/env`:
```sh
PI4JOY_NSU_URL=ws://192.168.127.250
PI4JOY_NSU_TOKEN=<токен НСУ>
PI4JOY_NSU_SOURCE=pi4joy-rv1106
PI4JOY_NSU_RATE=50
PI4JOY_TOKEN=<локальный токен, опционально>
```
Слоты: `/userdata/pi4joy/slots.json`; профили — `/opt/pi4joy/profiles`
(или встроенные Radiomaster/EdgeTX/геймпад).

## 6. Критерии приёмки
- В системе видны `/dev/input/by-path/*-event-joystick` для каждого стика.
- `curl http://<ip>:8090/healthz` отвечает.
- НСУ видит `remote-pi4joy-rv1106-1..4`, каналы двигаются, 50 Гц.
- Переподключение стика/кабеля восстанавливается; после reboot слоты те же.
- Обрыв Ethernet → НСУ гасит слоты по таймауту 750 мс.

## 7. Сделано (2026-11-15)
- pi4joy пропатчен: `input_event` 16 байт на 32-бит, собран
  `firmware/pi4joy/opt/pi4joy/pi4joy` (ELF 32-bit ARM, static).
- `prepare_joy.sh`: DTS `dr_mode=host`, `CONFIG_USB_DWC3_HOST=y`,
  `USB_HID`/`HID_GENERIC`/`EVDEV`, eudev (`by-path`), CMA 32M,
  профиль `LCPI_JOY`.
- Overlay: `S95pi4joy`, `/etc/pi4joy/env`, `/opt/pi4joy`.
- Чистый образ: `dist/lcpi-joy.img` (SHA256 `345815c1…63cf544`),
  `node_id=251` (IP `.251`), `source=pi4joy`, слоты запечены,
  radio/gadget/camera-сервисы убраны.
- **Проверено:** TX12 напрямую → `online:1`; НСУ видит
  `remote-pi4joy-1`, `AssignedDroneID=1`.
- Через питаемый хаб стик не определялся — нужен data-порт/кабель.

## 8. Осталось и риски
1. Type-C по CC может остаться device-портом: если powered hub не даст
   host — нужен OTG/пайка/модификация.
2. Заполнить `PI4JOY_NSU_URL`/`PI4JOY_NSU_TOKEN` реальными значениями.
3. Проверить `by-path` (eudev) и 4 стика через хаб.
4. Проверить, что хаб питает плату и стики (5 В, достаточный ток).
