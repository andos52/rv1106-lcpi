# 03. API-контракт

Контракт обязателен для прошивки pi4joy и НСУ. Ломающие изменения — только
с повышением версии протокола и одновременным обновлением обеих сторон.

## 1. Локальный API pi4joy
По умолчанию слушает **127.0.0.1:8090** (наружу не выставлен).
Если задан `PI4JOY_TOKEN`, запросы `/api/v1/*`, `/state`, `/ws` требуют
`Authorization: Bearer <token>`.

| Метод | Путь | Ответ |
|---|---|---|
| GET | `/healthz` | `{"status":"ok","slots":4,"online":N,"build":"..."}` |
| GET | `/api/v1/slots` | `{"count":4,"fixed":true,"assignments":[{"slot":1,"connected":true,"id":"...","name":"...","path":"/dev/input/by-path/..."}]}` |
| GET | `/state` | полный snapshot для локального UI |
| WS | `/ws` | snapshot/изменения для локального UI |

`id` — стабильный by-path ID, `path` — фактический evdev-путь.

## 2. Интеграция с НСУ
- URL: `ws://192.168.127.250/api/v1/ws/joystick-input?source=pi4joy`
- Auth: `Authorization: Bearer <CASCADE_JOYSTICK_INPUT_TOKEN>`
- Один WS на устройство, исходящий с борта.

### hello (первый кадр)
```json
{"type":"hello","version":"dev","name":"pi4joy","slots":4}
```

### state
```json
{"type":"state","seq":42,"ts":"2026-11-15T12:00:00Z","slots":[
  {"slot":1,"connected":true,
   "rc":[1500,1500,1000,1500,1000,1500,1500,1500,1500,1500,1500,1500,1500,1500,1500,1500],
   "control":{"throttle":0,"roll":1,"pitch":2,"yaw":3,"aux1":4}},
  {"slot":2,"connected":false},
  {"slot":3,"connected":false},
  {"slot":4,"connected":false}
]}
```

### Инварианты
- `type` — `hello` или `state`; `hello` всегда первый.
- Ровно **4 слота**, `slot` = 1..4, без повторов.
- `rc` — ровно **16** целых `uint16`, значения **1000..2000** мкс;
  отсутствующие каналы = 1500.
- `connected=false` — без `rc`/`control`.
- `seq` монотонно растёт в рамках соединения; `ts` — RFC3339 UTC.
- `control` опционален; поля `throttle,roll,pitch,yaw,aux1` — индексы.
- Каналы: CH1 throttle, CH2 roll, CH3 pitch, CH4 yaw, CH5 ARM,
  CH6–CH8 aux, CH9–CH11 кнопки; остальные резерв.
- Частота: 50 Гц при изменениях, 5 Гц keepalive в покое.
- При разрыве — переподключение с backoff; после реконнекта снова `hello`.

## 3. Сторона НСУ
| Метод | Путь | Назначение |
|---|---|---|
| GET | `/api/v1/joysticks` | список устройств, `AssignedDroneID` |
| POST | `/api/v1/joysticks/{id}/assign` | `{"drone_id":N}` / `-1` |
| GET | `/api/v1/drones/{id}/rc-status` | последние `throttle`,`arm` |
| POST | `/api/v1/kiosk/control` | `{"action":"restart"}` |

Устройства: `remote-pi4joy-1..4`. Привязка sticky; смена слота не должна
менять номер борта без явного assign.

## 4. Проверка контракта
```bash
# pi4joy
go test ./internal/nsu ./...
# НСУ
go test ./core/internal/api -run Joystick
```
Golden-тесты: `pi4joy/internal/nsu/protocol_golden_test.go`,
`masha-gcs/core/internal/api/joystick_input_ws_test.go`.
Перед деплоем обе стороны должны проходить эти тесты.

## 5. Изменения
1. Добавлять поля можно (backward-compatible), удалять/переименовывать — нельзя
   без версии `hello.version`.
2. Новые каналы/слоты — только с обновлением обоих репозиториев и UI.
3. Этот файл — источник истины для полей, частот и единиц.
