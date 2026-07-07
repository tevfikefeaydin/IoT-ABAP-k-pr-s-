@EndUserText.label : 'IoT Alarm Thresholds (per device)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table ztiot_thresh {
  key client   : abap.clnt not null;
  key device_id : abap.char(30) not null;   -- '*' = default row
  temp_min     : abap.dec(9,2);
  temp_max     : abap.dec(9,2);
  hum_min      : abap.dec(9,2);
  hum_max      : abap.dec(9,2);
  description  : abap.char(60);
}
