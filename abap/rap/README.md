# (b) Modern — RAP Custom Entity + OData V4 (okuma tarafı)

Yazma tarafını (POST) `abap/cloud` hallediyor. Bu klasör **okuma/görselleştirme** tarafını RAP **unmanaged custom entity** + **OData V4** ile sağlar. Böylece Fiori Elements bir List Report'u kod yazmadan üzerine oturtabilir.

İçindekiler:
- `zc_iot_reading.ddls.asddls` — custom entity (UI anotasyonları dahil).
- `zcl_iot_reading_query.clas.abap` — `IF_RAP_QUERY_PROVIDER` implementasyonu (paging + $count).
- `zui_iot_reading.srvd.asrvdef` — service definition.

## Adımlar (ADT)

1. **Query class:** New > ABAP Class → `ZCL_IOT_READING_QUERY`, içeriği yapıştırın.
2. **Custom entity:** New > Data Definition → `ZC_IOT_READING`, içeriği yapıştırın (aynı sınıfa `@ObjectModel.query.implementedBy` ile bağlı).
3. **Service definition:** New > Service Definition → `ZUI_IOT_READING`, içeriği yapıştırın.
4. **Service binding:** New > Service Binding → `ZUI_IOT_READING_O4`
   - Binding type: **OData V4 - UI**
   - Service definition: `ZUI_IOT_READING`
   - **Activate** edin, ardından `IoTReading` entity'sini seçip **Preview** ile Fiori Elements List Report'u açın.

## OData örnek çağrıları

```
GET .../ZUI_IOT_READING_O4/IoTReading?$top=20&$orderby=ReceivedAt desc
GET .../ZUI_IOT_READING_O4/IoTReading?$filter=DeviceId eq 'esp32-coldroom-01'&$count=true
```

## Neden custom entity (managed CDS view değil)?
- **Unmanaged custom entity** veri getirmeyi tamamen sizin kontrolünüze bırakır (kendi `SELECT`'iniz). IoT ham tablosu için esnek; ileride harici bir kaynağı (ör. zaman serisi DB) aynı entity arkasına koyabilirsiniz.
- Basit bir "tabloyu göster" senaryosunda `ZTIOT_SENSOR` üzerine düz bir CDS view + OData da yeterlidir; custom entity daha çok mülakatta "neden/ne zaman" sorusuna güçlü cevap verir.

## Notlar
- `zc_iot_reading` element adları (ReadingId, DeviceId ...) DB alanlarıyla (READING_ID ...) birebir aynı değil; query sınıfında `SELECT ... AS readingid` alias'ları ile eşleniyor.
- Paging (`$top`/`$skip`) ve `$count` destekli. `$filter`/`$orderby`'yi tam desteklemek için `io_request->get_filter( )` / `get_sort_elements( )` ile `WHERE`/`ORDER BY` üretin.
