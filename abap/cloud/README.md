# (b) Modern — ABAP Cloud HTTP Service

BTP **ABAP Environment (Steampunk)** veya ABAP Platform (embedded Steampunk) üzerinde çalışır. Tüm nesneler ADT (Eclipse) ile oluşturulur — SE11/SE80 yoktur.

İçindekiler:
- `ztiot_sensor.tabl.asddls` — DDL ile tanımlı database table (klasik ile aynı model).
- `zcl_iot_http_service.clas.abap` — `IF_HTTP_SERVICE_EXTENSION` handler.

## Adımlar (ADT)

1. **Paket:** ABAP Cloud tipinde bir paket oluşturun (örn. `ZIOT`).
2. **Tablo:** New > Other > Dictionary > **Database Table** → adı `ZTIOT_SENSOR`. `ztiot_sensor.tabl.asddls` içeriğini yapıştırıp aktive edin.
3. **Sınıf:** New > ABAP Class → `ZCL_IOT_HTTP_SERVICE`. `zcl_iot_http_service.clas.abap` içeriğini yapıştırın.
4. **HTTP Service:** New > Other ABAP Repository Object > Connectivity > **HTTP Service**
   - Adı: `ZIOT_INGEST`, URL path otomatik atanır (örn. `/sap/bc/http/sap/ziot_ingest` benzeri).
   - Oluşturulan handler class stub'ını `ZCL_IOT_HTTP_SERVICE`'e yönlendirin (ya da stub'a bu mantığı taşıyın).
5. Aktive edin. Service binding üzerinden URL'i "Properties" veya çalışma zamanı üzerinden görebilirsiniz.

## Test

```bash
# Kullanıcı: iletişim kullanıcısı (communication user) veya dev kullanıcınız
curl -u '<user>:<pass>' \
  -H 'Content-Type: application/json' \
  -H 'X-API-Key: change-me' \
  -d '{"deviceId":"esp32-coldroom-01","sensorType":"DHT22","temperature":4.2,"humidity":78.5,"recordedAt":"2026-07-07T10:20:30Z"}' \
  'https://<tenant>.abap.<region>.hana.ondemand.com/sap/bc/http/sap/ziot_ingest'
# → 201 {"status":"ok","readingId":"..."}
```

## JSON kütüphanesi notu
Kod `/ui2/cl_json` kullanır (güncel ABAP Cloud katmanlarında released). Sizin ortamınızda erişim kısıtlıysa, `handle_post` içindeki deserialize'ı XCO ile değiştirin:

```abap
DATA(lo_json) = xco_cp_json=>data->from_string( lv_body ).
ls_reading-device_id = lo_json->get_member( 'deviceId' )->get_string_value( ).
" ... diğer alanlar ...
```

## Cihaz kimlik doğrulaması
Üretim IoT senaryosunda ESP32 için bir **Communication Arrangement + Communication User** (Basic veya mTLS) tanımlayıp SICF/servis yetkisini ona verin. `X-API-Key` başlığı ek katman olarak kalır.
