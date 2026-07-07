# Soğuk Oda Eşik Alarmı

Gelen her okuma, kaydedildikten hemen sonra yapılandırılabilir eşiklere göre değerlendirilir. Aşım varsa `ZTIOT_ALARM` tablosuna bir alarm kaydı yazılır ve POST yanıtına alarm sayısı eklenir (`{"status":"ok","readingId":"...","alarms":2}`). ESP32 bu sayıyı okuyup LED/buzzer yakabilir.

## Nesneler
| Nesne | Amaç |
|---|---|
| `ztiot_thresh` (tablo) | Cihaz başına eşikler (`'*'` = varsayılan satır) |
| `ztiot_alarm` (tablo) | Oluşan alarm kayıtları |
| `zcl_iot_alarm_check` (sınıf) | Ortak değerlendirici — hem klasik hem cloud handler çağırır |

Tablolar iki formatta verilmiştir: `*.tabl.xml` (klasik/abapGit, SE11) ve `*.tabl.asddls` (ABAP Cloud, DDL). Sınıf release-neutral'dır, aynı kaynak her iki sisteme deploy edilir.

## Değerlendirme mantığı
Eşik önceliği: **cihaza özel satır → `'*'` varsayılan satır → gömülü fallback** (soğuk oda: temp -5…+8 °C, nem %30…%95).

| Aşım | Alarm tipi | Önem |
|---|---|---|
| temp > max | `HIGH_TEMP` | max+2°C üzerinde ise `CRIT`, değilse `WARN` |
| temp < min | `LOW_TEMP` | min-2°C altında ise `CRIT`, değilse `WARN` |
| nem > max | `HIGH_HUM` | `WARN` |
| nem < min | `LOW_HUM` | `WARN` |

## Kurulum
1. `ZTIOT_THRESH` ve `ZTIOT_ALARM` tablolarını oluşturun (klasik: XML import/SE11; cloud: DDL).
2. `ZCL_IOT_ALARM_CHECK` sınıfını oluşturun.
3. Handler'lar bu sınıfı zaten çağırıyor (bkz. `abap/classic` ve `abap/cloud`) — yeniden aktive edin.

## Örnek eşik verisi
Cihaza özel bir soğuk oda kuralı (ABAP raporu veya SE16N ile):
```abap
INSERT ztiot_thresh FROM @( VALUE #(
  device_id   = 'esp32-coldroom-01'
  temp_min    = '0.00'   temp_max = '8.00'
  hum_min     = '40.00'  hum_max  = '90.00'
  description = 'Soguk oda 1 (0-8 C)' ) ).
COMMIT WORK.
```
Genel varsayılan satır:
```abap
INSERT ztiot_thresh FROM @( VALUE #(
  device_id = '*'
  temp_min  = '-5.00'  temp_max = '8.00'
  hum_min   = '30.00'  hum_max  = '95.00'
  description = 'Varsayilan' ) ).
COMMIT WORK.
```

## Test
`temperature`'ı bilerek eşik üstüne gönderin:
```bash
./tools/send_sample.sh 12.5 85     # 12.5 °C > 8 °C  → HIGH_TEMP
# yanıt: 201 {"status":"ok","readingId":"...","alarms":1}

# Son alarmları çek:
curl -sS -k -u "$IOT_USER:$IOT_PASS" -H "X-API-Key: $IOT_APIKEY" \
  "${IOT_URL}?type=alarms&limit=10"
```
Simülatörle akış: `./tools/simulate.py --setpoint 9 --count 15` (setpoint eşik üstünde → alarm üretir).

## Bildirim (opsiyonel genişletme)
Alarm oluştuğunda e-posta/iş akışı tetiklemek isterseniz `zcl_iot_alarm_check`'te `INSERT ztiot_alarm` sonrasına bir bildirim adımı ekleyin:

- **Klasik (on-prem):** `CL_BCS` ile e-posta (SCOT/SMTP tanımı gerekir).
- **ABAP Cloud:** `cl_bcs_mail_message` (outbound e-posta) veya bir **RAP Business Event** yayınlayıp abonelikle işleyin.

Değerlendirici bilinçli olarak yalnızca tespit + kalıcılık yapar; bildirim I/O'su ort­ama göre değiştiği için ayrı tutulmuştur. Bu, mülakatta "sorumlulukların ayrılması" için iyi bir noktadır.
