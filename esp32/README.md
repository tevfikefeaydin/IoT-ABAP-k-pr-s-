# ESP32 Firmware

WiFi + DHT22 + NTP + HTTPS POST → ABAP REST endpoint.

## Donanım

| ESP32 pini | DHT22 pini | Not |
|---|---|---|
| 3V3 | VCC (1) | 3.3V besleme |
| GPIO4 | DATA (2) | `DHT_PIN` (config.h'te değiştirilebilir) |
| — | NC (3) | bağlanmaz |
| GND | GND (4) | ortak toprak |

DATA ile VCC arasına **10 kΩ pull-up** direnç ekleyin (çoğu DHT22 breakout kartında dahili). Soğuk oda uygulamasında sensörü prob/gövde içine alıp kabloyu dışarı çıkarın.

## Kütüphaneler
`platformio.ini` içinde pinlenmiştir: ArduinoJson 7, Adafruit DHT + Unified Sensor. PlatformIO bunları otomatik indirir.

## Kurulum

```bash
cd esp32
cp src/config.example.h src/config.h     # secrets — .gitignore'da
# config.h içinde WiFi, IOT_ENDPOINT, BASIC_AUTH_*, API_KEY doldur
pio run -t upload
pio device monitor                        # 115200 baud
```

Seri monitörde beklenen çıktı:
```
[boot] ESP32 → ABAP IoT bridge
[wifi] connected, ip=192.168.1.42
[send] {"deviceId":"esp32-coldroom-01","sensorType":"DHT22","temperature":4.20,"humidity":78.50,"recordedAt":"2026-07-07T10:20:30Z"}
[http] 201  resp={"status":"ok","readingId":"..."}
```

## TLS
- İlk denemede `INSECURE_TLS 1` ile sertifika doğrulaması atlanabilir (yalnızca lab).
- Üretim için `INSECURE_TLS 0` yapın ve `ROOT_CA_PEM` alanına SAP host'unuzun kök CA sertifikasını (PEM) yapıştırın. SICF'te self-signed sertifika kullanıyorsanız o sertifikayı gömün.

## Sık sorunlar
- **DHT read failed:** kablo/pull-up kontrol edin; okuma aralığı ≥ 2 sn olmalı (bu firmware'de 60 sn).
- **HTTP -1 / connection refused:** host/port ve HTTPS (44300 vb.) doğru mu? ESP32 ve SAP aynı ağdan erişilebilir mi?
- **401 Unauthorized:** SICF logon verisi veya `X-API-Key` yanlış.
- **Zaman senkronu olmuyor:** ağ NTP'ye çıkamıyorsa `recordedAt` boş gider; ABAP sunucu zamanını kullanır (sorun değil).
