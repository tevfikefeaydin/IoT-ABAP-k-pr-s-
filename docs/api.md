# REST Sözleşmesi

ESP32 ve ABAP endpoint'i arasındaki anlaşma. Klasik (SICF) ve modern (ABAP Cloud) varyantlar aynı sözleşmeyi kullanır — yalnızca temel URL farklıdır.

## Kimlik doğrulama
- **Basic auth** (SICF logon / communication user) — `Authorization: Basic ...`
- **`X-API-Key`** başlığı — cihaz paylaşımlı sırrı. ABAP handler bunu doğrular.

Her ikisi de geçerli değilse `401 Unauthorized` döner.

## `POST` — okuma gönder

İstek gövdesi (`application/json`, alan adları camelCase):

| Alan | Tip | Zorunlu | Açıklama |
|---|---|:---:|---|
| `deviceId` | string(≤30) | ✓ | Cihaz kimliği |
| `sensorType` | string(≤20) | | Sensör tipi (ör. `DHT22`) |
| `temperature` | number | | °C (2 ondalık) |
| `humidity` | number | | % (2 ondalık) |
| `recordedAt` | string | | UTC ISO-8601 (`2026-07-07T10:20:30Z`). Yoksa sunucu zamanı kullanılır. |

Örnek:
```json
{
  "deviceId": "esp32-coldroom-01",
  "sensorType": "DHT22",
  "temperature": 4.20,
  "humidity": 78.50,
  "recordedAt": "2026-07-07T10:20:30Z"
}
```

### Yanıtlar
| Durum | Gövde | Anlamı |
|---|---|---|
| `201 Created` | `{"status":"ok","readingId":"...","alarms":N}` | Kaydedildi; `N` = bu okumada tetiklenen eşik alarmı sayısı |
| `400 Bad Request` | `{"status":"error","message":"deviceId is required"}` | Eksik alan |
| `401 Unauthorized` | `{"status":"error","message":"unauthorized"}` | Kimlik/anahtar hatalı |
| `405 Method Not Allowed` | `{"status":"error","message":"method not allowed"}` | Desteklenmeyen metod |
| `500 Internal Server Error` | `{"status":"error","message":"db insert failed"}` | DB hatası |

## `GET` — son okumaları getir

Sorgu parametreleri:
| Param | Varsayılan | Açıklama |
|---|---|---|
| `device_id` | (hepsi) | Yalnızca bu cihaz |
| `limit` | 50 | Satır sayısı (1–1000) |
| `type` | `readings` | `alarms` verilirse okumalar yerine son alarmlar döner |

Örnekler:
```
GET /sap/ziot/ingest?device_id=esp32-coldroom-01&limit=20
GET /sap/ziot/ingest?type=alarms&limit=10
```
Yanıt: `200 OK` + JSON dizi (camelCase alanlar). `type=readings` → `ZTIOT_SENSOR` satırları; `type=alarms` → `ZTIOT_ALARM` satırları.

## Eşik alarmları
Her POST kaydedildikten sonra okuma, cihaz eşiklerine (`ZTIOT_THRESH`) göre değerlendirilir; aşımlar `ZTIOT_ALARM`'a yazılır ve yanıttaki `alarms` sayısına yansır. Tam mantık → [`abap/alarm/README.md`](../abap/alarm/README.md).

## `OPTIONS` — CORS (yalnızca klasik handler)
Tarayıcı tabanlı pano için `204 No Content` + CORS başlıkları döner.

## Alan eşleme (JSON ↔ DDIC)
`/ui2/cl_json` `pretty_mode = camel_case` ile: `deviceId ↔ DEVICE_ID`, `sensorType ↔ SENSOR_TYPE`, `recordedAt ↔ RECORDED_AT` … otomatik eşlenir.
