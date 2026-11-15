# 11. Анализ проекта masha (bort4g)

> Историко-аналитический документ. В нём разобраны две генерации masha:
> радио-ветка (v1.8.0, целевая) и поздняя `bort4g` HEAD с LTE/WireGuard
> (не используется). Итоговое решение — в разделе 7: радио + AR9271.

Дата: 2026-11-15.

## 1. Что найдено в WSL
- `/home/yoy70/masha` — симлинк на `/home/yoy70/bort4g`.
- Ветка `grom4-board`, commit `2f729df3c2`
  («board: persist settings and finish camera/uplink control»).
- Это SDK **LuckFox Pico Ultra** (RV1106G3, 256 МБ RAM, eMMC) с production-
  payload борта ГРОМ-4. Именно им прошивался прежний Luckfox.
- Внутри: `media/out` (готовые бинарники), `deploy/board` и
  `deploy/scripts` (сервисы), `configs/board` (конфиги), `docs/BOARD.md`.

## 2. Как устроен борт в bort4g HEAD (LTE/WG) — не наш режим
| Сервис | Роль |
|---|---|
| `camd.py` | владелец камеры и профиля, UDP 5603; CAM1 = MIPI `/dev/video14`, CAM2 = USB `/dev/video0` |
| `vcpd` | H.264/H.265 → станция; в HEAD **`--transport ip --raw`** |
| `ctrld` | MAVLink ↔ полётный контроллер (MSPv2/CRSF) |
| `boardctld.py` | HTTP `10.10.10.4:8081`: аплинк, модемы, `/api/system` |
| `linkstatusd.py` | LTE/сигнал → станция UDP 5602 |
| `vcpd-guard.py` | fail-safe по feedback UDP 5604 |
| `wg-udp-relay.py` | relay видео/управления через текущий аплинк |

Порядок загрузки: `S40settings-restore → S41eth0-static → S42uplink →
S88tunnel → S89usb-stable/S89modem-up → S90wireguard → S91lte → S92rkaiq/
S92ctrld → S93camd/S93vcpd → S94linkstatus → S95link-health → S96uplink-api →
S97vcpd-guard → S98settings-save`.

### Видеотракт HEAD (raw IP, не ULAMA)
`configs/board/vcpd.conf`:
```
VCPD_ARGS="--transport ip --peer 10.10.10.2:5600 --listen 0.0.0.0:5601 \
  --source /dev/video14 --raw --width 80 --height 60 --fps 1 --gop 1 \
  --idri-ms 1000 --bitrate 5 --frag-mtu 1200 --codec h264 --fec false \
  --kf-extra-copies 1 --pf-extra-copies 0 --autostart"
```
- Станция: WireGuard-хаб `10.10.10.2`; борт: `10.10.10.4`.
- Видео — plain UDP-фрагменты с magic `0x56` на `:5600`, UVCP/1 на `:5601`.
- В этом тракте нет ULAMA/`0xA5` и портов `5000`.
- Стартовый профиль 80×60@1, 5 кбит/с all-IDR; ABR затем поднимает fps
  и разрешение. `camd` меняет профиль (`PROFILE w h fps kbps`).

### Аплинк и Wi-Fi
- Приоритет: LAN (через станцию) → USB LTE-модем; Wi-Fi на борту в
  production **не используется**.
- AR9271 (`0cf3:9271`) стоит **на станции**; борт получает интернет по LAN
  или через модем. Board-side Wi-Fi — экспериментальный режим
  (`ath9ku` + RTL8192EU/AR9271, `WIFI_ENABLED=0`).
- WireGuard: `CONFIG_WIREGUARD=y`, пакет `wireguard-tools`; API борта
  слушает только туннель.

## 3. Три состояния: цель, HEAD и текущий bring-up
| Что | Радио masha v1.8.0 (цель) | bort4g HEAD (не используется) | Bring-up (прошит) |
|---|---|---|---|
| База | тег `5e7ad171c3` | `grom4-board` | `usalko/luxfox` |
| Транспорт видео | `radiod` + ULAMA/UNOW | raw IP, magic `0x56` | ULAMA/UDP-заглушка |
| Приёмник | `radiod`/`ulama-gw` на НСУ | WG `10.10.10.2:5600` | нет |
| Wi-Fi | AR9271 на борту, `mon0` ch6 | на станции; борт LAN/LTE | STA-скрипт без `wpa_supplicant` |
| Payload | `radiod`,`ctrld`,`vcpd`,`ushd` | `camd`,`boardctld`,uplink,WG | только vcpd |
| Носитель | SPI NAND 256 МБ / 128 МБ RAM | eMMC / 256 МБ RAM | SPI NAND / 128 МБ |

Радио-профиль v1.8.0 укладывается в разделы (rootfs 210 МБ, oem 30 МБ),
но 128 МБ RAM — риск, поэтому CMA уменьшен до 32 МБ.

### Риски для 128 МБ RAM (радио-профиль)
- Старые профили ставят `RK_BOOTARGS_CMA_SIZE="66M"`; для G2 target-профиль
  использует **32 МБ**, иначе Linux остаётся слишком мало.
- Радио-payload — C-сервисы (`radiod`, `ctrld`, `vcpd`, `ushd`), без
  Python; но MPP + радиостек всё равно требуют замера RSS.
- `RK_ENABLE_ROCKCHIP_TEST=y` раздувает rootfs; в LCPI-профиле выключен.

### Камера
- В masha CAM1 — MIPI `/dev/video14` через `rkaiq`; CAM2 — USB `/dev/video0`.
- Наша плата: SC3336 3MP; IQ-файл `sc3336_CMK-OT2119-PC1_30IRC-F16.json`
  уже включён в профиль. Номер video-узла нужно проверить на железе.

## 4. Вывод
Текущий образ — **bring-up**, а не замена прежнему борту. Для замены нужна
радио-ветка masha **v1.8.0** с нашим SPI-NAND-профилем LCPI; `bort4g` HEAD
(LTE/WG) не подходит.

## 5. План адаптации (радио)
1. Worktree тега `v1.8.0` → `~/rv1106-sdk/bort4g-radio`.
2. `scripts/prepare_radio.sh`: профиль SPI NAND, CMA 32 МБ, DTS LCPI,
   `RK_APP_TYPE=`, `ROCKCHIP_TEST=n`, vendor Wi-Fi off.
3. `./build.sh allsave`; после исправления Buildroot получить `update.img`.
4. Прошить, проверить UART, камеру, `S39wifi`/`mon0`, `S96radiod`.
5. Проверить видео на НСУ и восстановление после reboot.

## 6. Что делать с текущим образом
Он годится для проверки загрузки, NAND, Ethernet и камеры. После сборки
радио-образа его место занимает v1.8.0; перепрошивка через Maskrom отработана.

## 7. Решение (2026-11-15, корректировка): радио-режим masha
После уточнения требований вариант A (bort4g + LTE/WireGuard) **отменён**.
Целевой режим — радио-вариант masha:
- на борту **USB-стик AR9271** (ath9k_htc/ath9ku), `mon0` канал 6;
- `radiod` + `ulama`/`unow` + `vcpd --transport radiod`;
- видео уходит на НСУ по 802.11; приём видео на борт не нужен;
- база — тег **v1.8.0** (`5e7ad171c3`), где радиостек ещё цел;
- профиль `LCPI_RV1106`: SPI NAND 256 МБ, 128 МБ RAM, CMA 32 МБ.

Сборка bort4g HEAD (LTE/WG) остановлена; она остаётся только как
bring-up-референс.
