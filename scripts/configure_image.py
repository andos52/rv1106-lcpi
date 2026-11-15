#!/usr/bin/env python3
"""Generate firmware overlay files from the image config.

The script is intentionally dependency-free: it runs on Windows (Python 3)
and inside WSL/Linux, and is used by both configure and build pipelines.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import sys

DEFAULTS = {
    "ctrlPort": 5000,
    "uvcpPort": 5002,
    "ulamaPort": 5000,
    "prefix": 24,
    "gateway": "10.0.0.254",
    "nsuHost": "10.0.0.254",
    "wifiDev": "wlan0",
    "country": "RU",
    "sensor": "unknown",
    "streamId": 1,
    "dstNode": 254,
    "autostart": False,
    "codec": "h265",
    "bitrateKbps": 2000,
    "gop": 25,
    "idrIntervalMs": 1000,
    "width": 640,
    "height": 480,
    "fps": 25,
    "device": "/dev/video0",
    "rootPasswordHash": "",
    "ssh": True,
}


def fail(message: str) -> None:
    print(f"configure-image: ERROR: {message}", file=sys.stderr)
    raise SystemExit(2)


def warn(message: str) -> None:
    print(f"configure-image: WARN: {message}", file=sys.stderr)


def get(obj: dict, path: str, default=None):
    cur = obj
    for part in path.split("."):
        if not isinstance(cur, dict) or part not in cur:
            if default is not None:
                return default
            fail(f"missing config field: {path}")
        cur = cur[part]
    return cur


def as_int(value, name: str, lo: int, hi: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        if isinstance(value, str) and value.isdigit():
            value = int(value)
        else:
            fail(f"{name} must be an integer, got {value!r}")
    if not lo <= value <= hi:
        fail(f"{name} out of range {lo}..{hi}: {value}")
    return value


def as_str(value, name: str, min_len: int = 0, max_len: int = 4096) -> str:
    if not isinstance(value, str):
        fail(f"{name} must be a string")
    if not min_len <= len(value) <= max_len:
        fail(f"{name} length must be {min_len}..{max_len}, got {len(value)}")
    if "\n" in value or "\r" in value:
        fail(f"{name} must not contain newlines")
    return value


def load_config(path: str) -> dict:
    try:
        with open(path, "r", encoding="utf-8-sig") as fh:
            cfg = json.load(fh)
    except FileNotFoundError:
        fail(f"config not found: {path}")
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in {path}: {exc}")
    if not isinstance(cfg, dict):
        fail("config root must be an object")
    return cfg


def canonical_sha256(cfg: dict) -> str:
    raw = json.dumps(cfg, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def q(value: str) -> str:
    """Escape a value for a wpa_supplicant quoted string."""
    return value.replace("\\", "\\\\").replace('"', '\\"')


def write_text(path: str, text: str) -> None:
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default="configs/image.json")
    parser.add_argument("--out", default="build/image-overlay")
    parser.add_argument("--check", action="store_true", help="validate only")
    parser.add_argument("--print-name", action="store_true", help="print image name")
    args = parser.parse_args()

    cfg = load_config(args.config)

    node_id = as_int(get(cfg, "node.id"), "node.id", 1, 250)
    callsign = as_str(get(cfg, "node.callsign", f"C-{node_id:03d}"), "node.callsign", 1, 32)

    network = get(cfg, "network")
    if not isinstance(network, dict):
        fail("network must be an object")
    wifi_dev = as_str(network.get("wifiDev", DEFAULTS["wifiDev"]), "network.wifiDev", 1, 15)
    ssid = as_str(network.get("ssid"), "network.ssid", 1, 32)
    psk = as_str(network.get("psk"), "network.psk", 8, 64)
    country = as_str(network.get("country", DEFAULTS["country"]), "network.country", 2, 2)
    ip = as_str(network.get("ip"), "network.ip", 7, 15)
    prefix = as_int(network.get("prefix", DEFAULTS["prefix"]), "network.prefix", 8, 32)
    gateway = as_str(network.get("gateway", DEFAULTS["gateway"]), "network.gateway", 7, 15)
    nsu_host = as_str(network.get("nsuHost", DEFAULTS["nsuHost"]), "network.nsuHost", 7, 15)
    ctrl_port = as_int(network.get("ctrlPort", DEFAULTS["ctrlPort"]), "network.ctrlPort", 1, 65535)
    uvcp_port = as_int(network.get("uvcpPort", DEFAULTS["uvcpPort"]), "network.uvcpPort", 1, 65535)
    ulama_port = as_int(network.get("ulamaPort", DEFAULTS["ulamaPort"]), "network.ulamaPort", 1, 65535)

    if ip != f"10.0.0.{node_id}":
        fail(f"network.ip must be 10.0.0.{node_id} (board address law), got {ip}")
    if ctrl_port == uvcp_port:
        fail("network.ctrlPort and network.uvcpPort must differ")
    if ulama_port == uvcp_port:
        fail("network.ulamaPort and network.uvcpPort must differ")

    camera = get(cfg, "camera")
    if not isinstance(camera, dict):
        fail("camera must be an object")
    device = as_str(camera.get("device", DEFAULTS["device"]), "camera.device", 1, 64)
    sensor = as_str(camera.get("sensor", DEFAULTS["sensor"]), "camera.sensor", 1, 32)
    width = as_int(camera.get("width", DEFAULTS["width"]), "camera.width", 16, 2560)
    height = as_int(camera.get("height", DEFAULTS["height"]), "camera.height", 16, 1440)
    fps = as_int(camera.get("fps", DEFAULTS["fps"]), "camera.fps", 1, 60)
    if width % 2 or height % 2:
        fail("camera.width/height must be even")

    video = get(cfg, "video")
    if not isinstance(video, dict):
        fail("video must be an object")
    codec = as_str(video.get("codec", DEFAULTS["codec"]), "video.codec", 3, 4).lower()
    if codec not in ("h265", "h264"):
        fail("video.codec must be h265 or h264")
    bitrate = as_int(video.get("bitrateKbps", DEFAULTS["bitrateKbps"]), "video.bitrateKbps", 64, 20000)
    gop = as_int(video.get("gop", DEFAULTS["gop"]), "video.gop", 1, 300)
    idr_ms = as_int(video.get("idrIntervalMs", DEFAULTS["idrIntervalMs"]), "video.idrIntervalMs", 100, 60000)
    stream_id = as_int(video.get("streamId", DEFAULTS["streamId"]), "video.streamId", 0, 255)
    dst_node = as_int(video.get("dstNode", DEFAULTS["dstNode"]), "video.dstNode", 1, 255)
    autostart = bool(video.get("autostart", DEFAULTS["autostart"]))
    if gop > fps:
        warn(f"video.gop={gop} > camera.fps={fps}; vcpd clamps GOP to fps")
    if idr_ms > 1000:
        warn(f"video.idrIntervalMs={idr_ms} > 1000; vcpd clamps IDR interval to 1000 ms")

    image = get(cfg, "image", {})
    if not isinstance(image, dict):
        fail("image must be an object")
    hostname = as_str(image.get("hostname", f"rv1106-{node_id:03d}"), "image.hostname", 1, 63)
    root_hash = as_str(image.get("rootPasswordHash", DEFAULTS["rootPasswordHash"]), "image.rootPasswordHash", 0, 256)
    ssh = bool(image.get("ssh", DEFAULTS["ssh"]))

    image_name = f"rv1106-node{node_id:03d}.img"
    if args.print_name:
        print(image_name)
        return 0
    if args.check:
        print(f"configure-image: OK node={node_id} ip={ip} ssid={ssid!r} image={image_name}")
        return 0

    out = os.path.abspath(args.out)
    vcpd_conf = f"""# Generated by configure_image.py from {os.path.basename(args.config)}
# Video: raw Annex-B access units, fragmented into ULAMA VIDEO frames over UDP.
source={device}
bitrate={bitrate}
width={width}
height={height}
fps={fps}
gop={min(gop, fps)}
smartp=false
intra_refresh_rows=0
idr_interval_ms={min(idr_ms, 1000)}
redundancy=0
transport=udp
peer={nsu_host}:{ulama_port}
listen=0.0.0.0:{uvcp_port}
node={node_id}
dst_node={dst_node}
stream_id={stream_id}
autostart={'true' if autostart else 'false'}
verbose=false
"""

    wpa_conf = f"""# Generated by configure_image.py
ctrl_interface=/var/run/wpa_supplicant
update_config=0
country={country}

network={{
    ssid="{q(ssid)}"
    psk="{q(psk)}"
    key_mgmt=WPA-PSK
    scan_ssid=1
}}
"""

    network_conf = f"""# Generated by configure_image.py
WIFI_DEV={wifi_dev}
WIFI_IP={ip}
WIFI_PREFIX={prefix}
WIFI_GW={gateway}
NSU_HOST={nsu_host}
UVCP_PORT={uvcp_port}
CTRL_PORT={ctrl_port}
ULAMA_PORT={ulama_port}
"""

    runtime_cfg = json.dumps(
        {
            "project": cfg.get("project", {}),
            "board": cfg.get("board", {}),
            "node": {"id": node_id, "callsign": callsign},
            "network": {
                "wifiDev": wifi_dev,
                "ssid": ssid,
                "country": country,
                "ip": ip,
                "prefix": prefix,
                "gateway": gateway,
                "nsuHost": nsu_host,
                "ctrlPort": ctrl_port,
                "uvcpPort": uvcp_port,
                "ulamaPort": ulama_port,
            },
            "camera": {"device": device, "sensor": sensor, "width": width, "height": height, "fps": fps},
            "video": {
                "codec": codec,
                "bitrateKbps": bitrate,
                "gop": min(gop, fps),
                "idrIntervalMs": min(idr_ms, 1000),
                "streamId": stream_id,
                "dstNode": dst_node,
                "autostart": autostart,
            },
            "image": {"hostname": hostname, "ssh": ssh},
        },
        indent=2,
        ensure_ascii=False,
    )

    write_text(os.path.join(out, "etc", "vcpd.conf"), vcpd_conf)
    write_text(os.path.join(out, "etc", "wpa_supplicant.conf"), wpa_conf)
    write_text(os.path.join(out, "etc", "rv1106.network"), network_conf)
    write_text(os.path.join(out, "etc", "hostname"), hostname + "\n")
    write_text(os.path.join(out, "etc", "rv1106-image.json"), runtime_cfg + "\n")

    manifest = {
        "generatedAt": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "image": image_name,
        "configFile": os.path.abspath(args.config),
        "configSha256": canonical_sha256(cfg),
        "nodeId": node_id,
        "callsign": callsign,
        "board": cfg.get("board", {}),
        "network": {"ip": ip, "nsuHost": nsu_host, "uvcpPort": uvcp_port, "ulamaPort": ulama_port},
        "video": {"codec": codec, "width": width, "height": height, "fps": fps, "bitrateKbps": bitrate},
    }
    write_text(
        os.path.join(out, "manifest.json"),
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
    )

    print(f"configure-image: generated {out}")
    print(f"  node={node_id} callsign={callsign} ip={ip} nsu={nsu_host}:{ulama_port}")
    print(f"  video={width}x{height}@{fps} {codec} {bitrate}kbps gop={min(gop, fps)}")
    print(f"  image={image_name} configSha256={manifest['configSha256'][:12]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
