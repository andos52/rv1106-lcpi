# pi4joy на RV1106 (LCPI-RV1106 V1.4)

Этот overlay — для прошивки **lcpi_joy** (замена Raspberry Pi 4 с pi4joy),
не для радио-образа дрона.

## Состав
- `opt/pi4joy/pi4joy` — cross-compiled Go binary (linux/arm, GOARM=7).
- `etc/pi4joy/env` — адрес/токен НСУ и source.
- `etc/init.d/S95pi4joy` — запуск через start-stop-daemon.
- `opt/pi4joy/profiles/` — профили `joystick-*.yaml` (можно пусто:
  используются встроенные).

## Сборка бинарника
```powershell
$env:CGO_ENABLED="0"; $env:GOOS="linux"; $env:GOARCH="arm"; $env:GOARM="7"
go build -trimpath -ldflags "-s -w" -o firmware\pi4joy\opt\pi4joy\pi4joy .\cmd\pi4joy
```

## Обязательно перед сборкой образа
1. Пропатчить 32-битный `input_event` (16 байт вместо 24) в pi4joy.
2. Включить eudev (by-path) **или** патч сканера на sysfs.
3. Включить USB host/HID в kernel.
4. Положить env с реальными `PI4JOY_NSU_URL`/`PI4JOY_NSU_TOKEN`.
