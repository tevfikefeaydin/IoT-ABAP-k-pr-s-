# abap2UI5 Pano

`ZTIOT_SENSOR` tablosundaki son okumaları saf ABAP ile bir UI5 tablosunda gösteren pano. BSP/transport gerektirmez — UI mantığı tek ABAP sınıfında.

## Ön koşul
[abap2UI5](https://github.com/abap2UI5/abap2UI5) framework'ünün sisteme kurulu olması (abapGit ile). Kurulumdan sonra abap2UI5 index/launchpad handler'ı üzerinden uygulama sınıflarını çalıştırabilirsiniz.

## Kurulum
1. `ZCL_IOT_DASHBOARD` sınıfını oluşturup `zcl_iot_dashboard.clas.abap` içeriğini yapıştırın, aktive edin.
2. abap2UI5 başlatıcısında uygulama olarak `ZCL_IOT_DASHBOARD` verin (ör. `.../z2ui5?app=ZCL_IOT_DASHBOARD` — sizin kurulumunuzdaki URL kalıbına göre).

## Görünüm
- Üstte **Yenile** butonu.
- Tablo sütunları: Cihaz, Sensör, Sıcaklık (°C), Nem (%), Alınma zamanı.
- `Yenile` tabloyu yeniden sorgular.

## Sürüm notu
abap2UI5'in akıcı (fluent) API'si sürümler arasında ufak farklar gösterebilir (`view_model_update` vs `model_update`, `object_number` imzası vb.). Kod güncel bir sürümü hedefler; sizin sürümünüzde bir metod adı farklıysa yalnızca o çağrıyı uyarlayın — genel yapı (view factory → page → table → columns/cells) aynıdır.

## Alternatif: Fiori Elements
Görselleştirmeyi Fiori ile yapmak isterseniz `abap/rap` altındaki OData V4 servisini kullanın; List Report otomatik gelir (kod yazmadan). abap2UI5 ise hızlı, bağımsız bir pano için idealdir.
