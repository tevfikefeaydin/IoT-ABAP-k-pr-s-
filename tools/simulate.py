#!/usr/bin/env python3
"""Simulate an ESP32 cold-room sensor by POSTing readings to the ABAP endpoint.

Useful for demoing the dashboard with a stream of data before (or instead of)
wiring up real hardware. Uses only the Python standard library.

Env / flags:
    IOT_URL      target endpoint (required)
    IOT_USER     basic-auth user (optional)
    IOT_PASS     basic-auth pass (optional)
    IOT_APIKEY   X-API-Key value (default: change-me)

Examples:
    IOT_URL=https://host:44300/sap/ziot/ingest ./tools/simulate.py --count 20 --interval 2
    IOT_URL=... ./tools/simulate.py --device esp32-line-2 --loop
"""
import argparse
import base64
import json
import os
import random
import ssl
import sys
import time
import urllib.request
from datetime import datetime, timezone


def iso_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def build_reading(device: str, temp_base: float) -> dict:
    # Small random walk around a cold-room setpoint.
    temperature = round(temp_base + random.uniform(-1.5, 1.5), 2)
    humidity = round(random.uniform(70, 90), 2)
    return {
        "deviceId": device,
        "sensorType": "DHT22",
        "temperature": temperature,
        "humidity": humidity,
        "recordedAt": iso_now(),
    }


def post(url: str, body: dict, api_key: str, user: str, password: str) -> int:
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("X-API-Key", api_key)
    if user:
        token = base64.b64encode(f"{user}:{password}".encode()).decode()
        req.add_header("Authorization", f"Basic {token}")

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE  # lab convenience; tighten for real use
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
            print(f"  -> {resp.status} {resp.read().decode('utf-8', 'replace')}")
            return resp.status
    except urllib.error.HTTPError as e:
        print(f"  -> {e.code} {e.read().decode('utf-8', 'replace')}")
        return e.code
    except Exception as e:  # noqa: BLE001
        print(f"  -> error: {e}")
        return -1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--device", default="esp32-coldroom-01")
    ap.add_argument("--count", type=int, default=10, help="number of readings (ignored with --loop)")
    ap.add_argument("--interval", type=float, default=1.0, help="seconds between readings")
    ap.add_argument("--setpoint", type=float, default=4.0, help="cold-room setpoint °C")
    ap.add_argument("--loop", action="store_true", help="run forever until Ctrl-C")
    args = ap.parse_args()

    url = os.environ.get("IOT_URL")
    if not url:
        print("IOT_URL environment variable is required", file=sys.stderr)
        return 2
    api_key = os.environ.get("IOT_APIKEY", "change-me")
    user = os.environ.get("IOT_USER", "")
    password = os.environ.get("IOT_PASS", "")

    print(f"Simulating {args.device} -> {url}")
    sent = 0
    try:
        while args.loop or sent < args.count:
            reading = build_reading(args.device, args.setpoint)
            print(f"[{sent + 1}] {json.dumps(reading)}")
            post(url, reading, api_key, user, password)
            sent += 1
            if args.loop or sent < args.count:
                time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\nstopped.")
    print(f"done — {sent} readings sent.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
