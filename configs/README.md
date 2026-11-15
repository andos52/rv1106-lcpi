# Конфиги bring-up образа (не финальные)

`image.example.json`, `image.json` и `scripts/configure_image.py` относятся
только к **bring-up** образу из `usalko/luxfox`:

- генерируют ULAMA/UDP-заглушку (`10.0.0.254:5000`, UVCP `5002`);
- Wi-Fi STA-скрипт без `wpa_supplicant`;
- нужны были для проверки загрузки/NAND/SSH.

Финальный радио-образ masha v1.8.0 **не использует** эти файлы:
у него свои `/etc/vcpd.conf` (`transport=radiod`), `/etc/radiod.conf` и
`S39wifi` (mon0/AR9271). Не переносите поля `network.*` в радио-образ.
