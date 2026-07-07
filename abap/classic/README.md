# (a) Klasik — On-Prem SICF handler

ABAP Platform **Docker trial** (veya herhangi bir on-prem AS ABAP 7.52+) üzerinde çalışır.

İçindekiler:
- `ztiot_sensor.tabl.xml` — okuma tablosu (transparent).
- `zcl_iot_rest_handler.clas.abap` / `.clas.xml` — `IF_HTTP_EXTENSION` handler.

## Nasıl import edilir?

İki yol var — **abapGit** (hızlı) veya **elle** (bağımlılıksız).

### Yol 1 — abapGit
1. `ZABAPGIT` (standalone) raporunu kurun/çalıştırın.
2. Bu repoyu "online" veya "offline" olarak bağlayın, `abap/classic` klasöründeki nesneleri bir `$TMP` / paket içine pull edin.
3. `ZTIOT_SENSOR` aktive edin, ardından `ZCL_IOT_REST_HANDLER` aktive edin.

> Not: abapGit XML'i geniş uyumluluk için verilmiştir. Sizin release'inizde DDIC import'ta ufak bir uyarı çıkarsa, aşağıdaki elle yöntemle tabloyu 2 dakikada oluşturabilirsiniz.

### Yol 2 — Elle (SE11 + SE24)

**Tablo `ZTIOT_SENSOR` (SE11 → Database table):**

| Alan | Key | Data element / Type | Uzunluk | Açıklama |
|---|:---:|---|---|---|
| MANDT | ✓ | MANDT | | Client |
| READING_ID | ✓ | CHAR | 32 | Reading UUID |
| DEVICE_ID | | CHAR | 30 | Cihaz kimliği |
| SENSOR_TYPE | | CHAR | 20 | Sensör tipi |
| TEMPERATURE | | DEC | 9,2 | Sıcaklık (°C) |
| HUMIDITY | | DEC | 9,2 | Nem (%) |
| RECORDED_AT | | TIMESTAMP | | Cihaz zamanı (UTC) |
| RECEIVED_AT | | TIMESTAMP | | Sunucu zamanı (UTC) |
| RAW_PAYLOAD | | STRING | | Ham JSON |

Delivery class `A`, Data class `APPL1`, Size category `0`. Aktive edin.

**Class `ZCL_IOT_REST_HANDLER` (SE24 / ADT):** `zcl_iot_rest_handler.clas.abap` içeriğini yapıştırın, aktive edin.

## SICF servisini oluşturma (`SICF`)

1. `SICF` işlem kodunu açın → **Execute**.
2. `default_host/sap` altında yeni bir hiyerarşi düğümü oluşturun, örn. `default_host/sap/ziot` → altında `ingest`.
   (Sonuç URL: `/sap/ziot/ingest`.)
3. **Handler List** sekmesine `ZCL_IOT_REST_HANDLER` ekleyin.
4. **Logon Data** sekmesinde:
   - Prosedürü "Standard" bırakın (Basic auth).
   - İsterseniz sabit bir teknik/servis kullanıcısı atayın (ESP32'nin kullanacağı).
5. Servisi **Activate** edin (sağ tık → Activate Service).

Test:
```bash
curl -k -u ESP32_USER:'****' \
  -H 'Content-Type: application/json' \
  -H 'X-API-Key: change-me' \
  -d '{"deviceId":"esp32-coldroom-01","sensorType":"DHT22","temperature":4.2,"humidity":78.5,"recordedAt":"2026-07-07T10:20:30Z"}' \
  https://<host>:44300/sap/ziot/ingest
# → 201 {"status":"ok","readingId":"..."}

curl -k -u ESP32_USER:'****' -H 'X-API-Key: change-me' \
  'https://<host>:44300/sap/ziot/ingest?limit=10'
# → 200 [ ... son okumalar ... ]
```

Verinin geldiğini `SE16` / `SE16N` ile `ZTIOT_SENSOR` üzerinde doğrulayın.

## Güvenlik
- `gc_api_key` sabiti demo içindir. Üretimde güvenli bir tabloda/SSF'de saklayıp cihaz başına anahtar tutun.
- HTTPS (port 443xx) kullanın; ICM'de SSL host tanımlı olmalı.
