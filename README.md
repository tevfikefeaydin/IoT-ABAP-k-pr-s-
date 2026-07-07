# ESP32 → ABAP REST IoT Köprüsü

**ESP32 sensörlerinden gelen JSON verisini bir ABAP REST endpoint'ine yazan, SAP tarafında tabloya kaydeden ve abap2UI5 / Fiori ile görselleştiren uç-uca (end-to-end) IoT + ERP entegrasyon projesi.**

> Endüstriyel IoT (soğuk oda / üretim sıcaklık-nem izleme) ile kurumsal SAP ABAP dünyasını tek bir köprüde birleştirir. Donanım → ağ → REST → veri tabanı → arayüz zincirinin tamamını kapsar.

---

## Neden bu proje?

Donanım/IoT ve kurumsal ABAP birlikte nadiren bulunan bir kombinasyondur. Bir üretim/soğutma firması bağlamında (soğuk oda, kompresör, hat sıcaklığı) bu proje:

- **Gerçek bir problemi** çözer: sahadaki ölçümleri otomatik olarak SAP'ye taşımak.
- **İki farklı ABAP yaklaşımını** gösterir: klasik on-prem (SICF) ve modern ABAP Cloud / RAP.
- Uçtan uca bir **hikâye** sunar: lehim/PCB → ESP32 firmware → WiFi → HTTPS POST → ABAP → DDIC tablo → OData/abap2UI5.

## Mimari

```
 ┌──────────┐   HTTPS POST (JSON)    ┌─────────────────────────────┐
 │  ESP32   │ ─────────────────────▶ │  ABAP REST Endpoint         │
 │  + DHT22 │   X-API-Key header     │  ┌───────────────────────┐  │
 │ (soğuk   │                        │  │ Klasik: SICF +        │  │
 │  oda)    │ ◀───────────────────── │  │ IF_HTTP_EXTENSION     │  │
 └──────────┘   201 Created / JSON   │  │ + /ui2/cl_json        │  │
                                     │  ├───────────────────────┤  │
                                     │  │ Modern: ABAP Cloud    │  │
                                     │  │ IF_HTTP_SERVICE_EXT   │  │
                                     │  │ + RAP Custom Entity   │  │
                                     │  └──────────┬────────────┘  │
                                     │             ▼               │
                                     │      ┌─────────────┐        │
                                     │      │ ZTIOT_SENSOR│ (DDIC) │
                                     │      └──────┬──────┘        │
                                     └─────────────┼───────────────┘
                                                   ▼
                                    ┌──────────────────────────────┐
                                    │ Görselleştirme               │
                                    │ • abap2UI5 pano (tablo/kart)  │
                                    │ • Fiori Elements (OData V4)   │
                                    └──────────────────────────────┘
```

## İki varyant

| | (a) Klasik — On-Prem | (b) Modern — ABAP Cloud / BTP |
|---|---|---|
| Endpoint | SICF servisi + `IF_HTTP_EXTENSION` | HTTP Service + `IF_HTTP_SERVICE_EXTENSION` |
| JSON | `/ui2/cl_json` | `/ui2/cl_json` veya `XCO` |
| Depolama | Transparent tablo `ZTIOT_SENSOR` | Aynı tablo (DDL ile) |
| Okuma API | Handler `GET` → JSON | RAP unmanaged **custom entity** + **OData V4** |
| UI | abap2UI5 | Fiori Elements List Report + abap2UI5 |
| Ortam | ABAP Platform **Docker trial** | **BTP ABAP Environment (Steampunk)** |

İkisi de aynı veri modelini ve aynı ESP32 firmware'ini paylaşır — yalnızca hedef URL değişir.

## Repo yapısı

```
.
├── esp32/                     ESP32 firmware (PlatformIO / Arduino)
│   ├── platformio.ini
│   ├── src/main.cpp           WiFi + DHT22 + NTP + HTTPS POST
│   ├── src/config.example.h   Kopyalayıp config.h yapın
│   └── README.md              Donanım bağlantısı ve flash adımları
├── abap/
│   ├── classic/               (a) SICF handler + DDIC tablo
│   │   ├── zcl_iot_rest_handler.clas.abap
│   │   ├── zcl_iot_rest_handler.clas.xml
│   │   ├── ztiot_sensor.tabl.xml
│   │   └── README.md          SICF kurulum adımları
│   ├── cloud/                 (b) ABAP Cloud HTTP service
│   │   ├── zcl_iot_http_service.clas.abap
│   │   └── README.md
│   ├── rap/                   (b) Custom entity + OData V4 (okuma)
│   │   ├── zc_iot_reading.ddls.asddls
│   │   ├── zcl_iot_reading_query.clas.abap
│   │   └── README.md
│   └── abap2ui5/              Pano (görselleştirme)
│       ├── zcl_iot_dashboard.clas.abap
│       └── README.md
├── tools/                     ESP32 olmadan test için
│   ├── send_sample.sh         curl ile örnek POST
│   └── simulate.py            Rastgele okuma üreten simülatör
├── docs/
│   ├── architecture.md
│   └── api.md                 REST sözleşmesi (payload/response)
└── README.md
```

## Hızlı başlangıç

### 1. ABAP tarafı
- **Klasik:** `abap/classic/README.md` → tablo + handler class + SICF node oluştur.
- **Modern:** `abap/cloud/README.md` → HTTP service; `abap/rap/README.md` → OData servisi.

### 2. Endpoint'i ESP32 olmadan test et
```bash
# Klasik SICF örneği
export IOT_URL="https://<host>:<port>/sap/ziot/ingest"
export IOT_USER="ESP32_USER" IOT_PASS="******" IOT_APIKEY="degistir-beni"
./tools/send_sample.sh
```
Beklenen yanıt: `201 Created` + `{"status":"ok","readingId":"..."}`.

### 3. ESP32'yi flash'la
```bash
cd esp32
cp src/config.example.h src/config.h   # WiFi + endpoint + API key doldur
pio run -t upload && pio device monitor
```

### 4. Görselleştir
- abap2UI5: `abap/abap2ui5/README.md`
- Fiori Elements: `abap/rap/README.md` (OData V4 service binding)

## REST sözleşmesi (özet)

`POST` gövdesi (camelCase):
```json
{
  "deviceId": "esp32-coldroom-01",
  "sensorType": "DHT22",
  "temperature": 4.2,
  "humidity": 78.5,
  "recordedAt": "2026-07-07T10:20:30Z"
}
```
Tam sözleşme için → [`docs/api.md`](docs/api.md).

## Güvenlik notları
- Cihaz kimlik doğrulaması: SICF logon + ek `X-API-Key` başlığı (cihaz sırrı SAP'den bağımsız döndürülebilir).
- Üretimde HTTPS zorunlu; ESP32 tarafında CA sertifikası pinlenmeli (örnek firmware'de anlatılıyor).
- API anahtarını demo dışında koda gömmeyin — güvenli bir tabloda/SSF'de saklayın.

## Lisans
MIT — bkz. [LICENSE](LICENSE).
