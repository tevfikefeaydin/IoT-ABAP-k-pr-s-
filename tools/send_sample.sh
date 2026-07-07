#!/usr/bin/env bash
# Send one sample reading to the ABAP endpoint — lets you test the whole
# server side without an ESP32 on the bench.
#
# Usage:
#   export IOT_URL="https://host:44300/sap/ziot/ingest"
#   export IOT_USER="ESP32_USER" IOT_PASS="****" IOT_APIKEY="change-me"
#   ./tools/send_sample.sh                 # random-ish reading, now()
#   ./tools/send_sample.sh 3.7 81.2        # explicit temperature humidity
set -euo pipefail

IOT_URL="${IOT_URL:?set IOT_URL to your endpoint}"
IOT_APIKEY="${IOT_APIKEY:-change-me}"
DEVICE_ID="${DEVICE_ID:-esp32-coldroom-01}"

TEMP="${1:-$(awk 'BEGIN{srand(); printf "%.2f", 2+rand()*6}')}"   # ~2–8 °C
HUM="${2:-$(awk  'BEGIN{srand(); printf "%.2f", 70+rand()*20}')}" # ~70–90 %
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

read -r -d '' BODY <<JSON || true
{"deviceId":"${DEVICE_ID}","sensorType":"DHT22","temperature":${TEMP},"humidity":${HUM},"recordedAt":"${TS}"}
JSON

AUTH=()
if [[ -n "${IOT_USER:-}" ]]; then
  AUTH=(-u "${IOT_USER}:${IOT_PASS:-}")
fi

echo "POST ${IOT_URL}"
echo "  ${BODY}"
curl -sS -k "${AUTH[@]}" \
  -H 'Content-Type: application/json' \
  -H "X-API-Key: ${IOT_APIKEY}" \
  -w '\n-> HTTP %{http_code}\n' \
  -d "${BODY}" \
  "${IOT_URL}"
