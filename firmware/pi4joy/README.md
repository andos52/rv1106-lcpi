# pi4joy на LCPI-RV1106 V1.4

Overlay для прошивки **lcpi_joy** — узла джойстиков (замена Raspberry Pi 4
с pi4joy). 

## Состав
- `opt/pi4joy/pi4joy` — cross-compiled Go binary (linux/arm, GOARM=7).
- `opt/pi4joy/slots.default.json` — фиксированный mapping USB-портов в слоты.
- `etc/pi4joy/env` — адрес/токен НСУ и source (локальный, не в git).
- `etc/init.d/S41net` — статический адрес `.251`.
- `etc/init.d/S95pi4joy` — запуск pi4joy через start-stop-daemon.

## Сборка бинарника
```powershell
$env:CGO_ENABLED="0"; $env:GOOS="linux"; $env:GOARCH="arm"; $env:GOARM="7"
go build -trimpath -ldflags "-s -w" -o firmware\pi4joy\opt\pi4joy\pi4joy .\cmd\pi4joy
```

## Образ
```bash
./scripts/build.sh            # полная сборка
./scripts/repack.sh           # только перепаковка
```
API и формат данных: `docs/03-api-contract.md`.
