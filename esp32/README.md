# ESP32 Firmware

WiFi + DHT22 + NTP + HTTPS POST → ABAP REST endpoint.

## Desteklenen sensörler

Sensör **derleme zamanında** seçilir (ayrı PlatformIO ortamları). Payload'daki `sensorType` otomatik olarak seçilen modele göre ayarlanır.

| Sensör | Ortam | Ölçüm | Arayüz | Soğuk oda için |
|---|---|---|---|---|
| **DHT22** (varsayılan) | `esp32-dht22` | sıcaklık + nem | tek data pini | ucuz demo; yoğuşmada zayıf |
| **SHT31** | `esp32-sht31` | sıcaklık + nem | I²C | ısıtıcılı, -40…+125°C, önerilen |
| **DS18B20** | `esp32-ds18b20` | yalnızca sıcaklık | 1-Wire | su geçirmez prob; nem göndermez |

DS18B20 nem göndermediğinden payload'da `humidity` alanı atlanır; ABAP tarafı bunu doğru işler (nem alarmı üretmez).

## Donanım bağlantısı

**DHT22** (`DHT_PIN=4`)
| ESP32 | DHT22 | Not |
|---|---|---|
| 3V3 | VCC | DATA↔VCC arası **10 kΩ** pull-up (breakout'ta çoğu zaman dahili) |
| GPIO4 | DATA | |
| GND | GND | |

**SHT31** (I²C)
| ESP32 | SHT31 |
|---|---|
| 3V3 | VIN |
| GPIO21 | SDA |
| GPIO22 | SCL |
| GND | GND / ADDR (0x44) |

**DS18B20** (`DS18B20_PIN=4`, 1-Wire)
| ESP32 | DS18B20 | Not |
|---|---|---|
| 3V3 | VDD (kırmızı) | DATA↔VDD arası **4.7 kΩ** pull-up (zorunlu) |
| GPIO4 | DATA (sarı) | |
| GND | GND (siyah) | |

Soğuk oda uygulamasında elektroniği **oda dışında** tutun; yalnızca sensör probunu kablo rakoruyla içeri alın.

## Kütüphaneler
`platformio.ini` her ortam için gerekli kütüphaneleri pinler (ArduinoJson 7 + seçilen sensörün kütüphanesi). PlatformIO otomatik indirir.

## Kurulum

```bash
cd esp32
cp src/config.example.h src/config.h     # secrets — .gitignore'da
# config.h içinde WiFi, IOT_ENDPOINT, BASIC_AUTH_*, API_KEY doldur

# Sensörüne göre ortam seç:
pio run -e esp32-dht22   -t upload        # DHT22 (varsayılan)
pio run -e esp32-sht31   -t upload        # SHT31
pio run -e esp32-ds18b20 -t upload        # DS18B20
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
- **sensor read failed:** kablo/pull-up kontrol edin. DHT22 için 10 kΩ, DS18B20 için 4.7 kΩ pull-up; SHT31 için doğru I²C adresi (0x44/0x45). Doğru ortamı seçtiğinizden emin olun (`-e esp32-...`).
- **HTTP -1 / connection refused:** host/port ve HTTPS (44300 vb.) doğru mu? ESP32 ve SAP aynı ağdan erişilebilir mi?
- **401 Unauthorized:** SICF logon verisi veya `X-API-Key` yanlış.
- **Zaman senkronu olmuyor:** ağ NTP'ye çıkamıyorsa `recordedAt` boş gider; ABAP sunucu zamanını kullanır (sorun değil).
