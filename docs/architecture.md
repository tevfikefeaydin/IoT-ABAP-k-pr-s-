# Mimari

## Uçtan uca akış

```
 Sensör (DHT22)          ESP32                 Ağ            ABAP AS                DB              UI
 ────────────    ┌───────────────────┐    ───────────    ┌──────────────┐    ┌───────────┐   ┌─────────┐
  sıcaklık/nem →  │ oku → JSON kur →  │ →  HTTPS POST  →  │ handler:     │ →  │ INSERT    │ → │ abap2UI5│
                  │ NTP zaman damgası │    X-API-Key      │ auth + parse │    │ ZTIOT_    │   │ / Fiori │
                  └───────────────────┘                   │ + validate   │    │ SENSOR    │   │ (OData) │
                        60 sn'de bir                       └──────────────┘    └───────────┘   └─────────┘
```

## Katmanlar

### 1. Edge — ESP32
- **Framework:** Arduino (PlatformIO).
- **Sensör:** DHT22 (sıcaklık + nem). Soğuk oda / hat izleme için uygun.
- **Ağ:** WiFi STA; kopunca yeniden bağlanır.
- **Zaman:** NTP ile UTC senkronu → gerçek `recordedAt`. Senkron olmazsa alan atlanır, ABAP kendi zamanını kullanır.
- **Aktarım:** `WiFiClientSecure` + `HTTPClient` ile HTTPS POST. `X-API-Key` + opsiyonel Basic auth.
- **Format:** ArduinoJson ile küçük camelCase gövde.

### 2. Ingestion — ABAP handler
İki eşdeğer implementasyon, tek sözleşme:

| | Klasik | Modern |
|---|---|---|
| Arayüz | `IF_HTTP_EXTENSION` | `IF_HTTP_SERVICE_EXTENSION` |
| Bağlama | SICF node | HTTP Service (service binding) |
| İstek gövdesi | `request->get_cdata( )` | `request->get_text( )` |
| Yanıt | `response->set_cdata( )` | `response->set_text( )` |

Ortak mantık: **auth → parse (`/ui2/cl_json`) → validate (`deviceId`) → UUID üret → `INSERT` → JSON yanıt**. Cihaz saati yoksa sunucu zaman damgası yetkilidir.

### 3. Kalıcılık — `ZTIOT_SENSOR`
Transparent tablo. `reading_id` (UUID) PK. Ham JSON `raw_payload`'da saklanır (denetim/yeniden işleme için). `received_at` sunucu, `recorded_at` cihaz zamanı.

### 4. Sunum
- **abap2UI5:** saf ABAP pano; hızlı, bağımsız.
- **Fiori Elements:** RAP unmanaged custom entity (`ZC_IOT_READING`) + OData V4 service binding → List Report otomatik.

## Tasarım kararları
- **İki varyant bilinçli:** biri on-prem/Docker (klasik ICF), diğeri BTP/ABAP Cloud (RAP). Aynı model, taşınabilir hikâye.
- **Sunucu-yetkili zaman:** ucuz IoT cihazlarında saat güvenilmezdir; `received_at` her zaman doludur.
- **Ham payload saklanır:** şema evrilirse geçmiş yeniden işlenebilir.
- **Katmanlı auth:** SICF logon + `X-API-Key` → cihaz sırrı SAP kullanıcısından bağımsız döndürülebilir.

## Genişletme fikirleri
- Eşik aşımında (ör. soğuk oda > 8 °C) alarm/iş akışı tetikleme (workflow / e-posta / Business Event).
- Zaman serisi toplama (saatlik ortalama) için ikinci tablo + job.
- mTLS ile cihaz kimliği (sertifika tabanlı).
- Birden çok sensör tipi (basınç, kapı kontağı) için `sensor_type` genişletme.
