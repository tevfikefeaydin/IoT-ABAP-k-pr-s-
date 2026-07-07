# Bağımsız HTML Pano (viewer)

Tek dosyalık, sıfır bağımlılıklı bir pano. SAP kurmadan **demo modunda** açılır; hazır olduğunuzda ABAP `GET` endpoint'ine bağlanır.

## Aç
`viewer/index.html` dosyasını bir tarayıcıda açın (çift tıklama yeter). İlk açılışta **demo modu** açıktır — örnek okumalar + eşik aşımı alarmları üretilir, böylece arayüzü hemen görürsünüz.

## Gerçek veriye bağlan
1. Üstteki **⚙️ Bağlantı ayarları**'nı açın.
2. Doldurun:
   - **Endpoint (GET) URL:** ör. `https://host:44300/sap/ziot/ingest` (klasik) veya ABAP Cloud servis URL'i.
   - **X-API-Key:** handler'daki değer (varsayılan `change-me`).
   - **Kullanıcı/Parola:** Basic auth gerekiyorsa.
   - **Cihaz filtresi / eşik / limit / oto-yenileme** isteğe bağlı.
3. **Demo modu**'nu kapatın. Pano `?type=readings` ve `?type=alarms` çağrılarını yapar.

Panonun gösterdikleri:
- **Özet kartlar:** toplam okuma, son sıcaklık (eşik üstündeyse kırmızı), son nem, aktif alarm sayısı.
- **Sıcaklık trendi:** son okumaların SVG grafiği + kesikli eşik çizgisi; eşik üstü noktalar kırmızı.
- **Alarm tablosu:** önem (WARN/CRIT) rozetli.
- **Okuma tablosu:** eşik üstü sıcaklıklar vurgulu.

## CORS notu
Klasik SICF handler yanıtlarında `Access-Control-Allow-Origin: *` döner, tarayıcıdan doğrudan çağrı çalışır. ABAP Cloud HTTP service'te tarayıcıdan erişim için CORS'a izin vermeniz (veya panoyu aynı origin'den sunmanız) gerekebilir. Bağlanamazsa hata kutusu çıkar; **Demo modu** ile arayüzü yine inceleyebilirsiniz.

## Güvenlik
Girdiğiniz endpoint/anahtar/parola yalnızca o tarayıcının `localStorage`'ında tutulur, hiçbir yere gönderilmez (yalnızca sizin ABAP endpoint'inize istek atılır). Ortak makinelerde kullanmayın.
