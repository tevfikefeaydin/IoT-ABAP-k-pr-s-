@EndUserText.label : 'IoT Sensor Readings'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztiot_sensor {
  key client      : abap.clnt not null;
  key reading_id  : abap.char(32) not null;
  device_id       : abap.char(30);
  sensor_type     : abap.char(20);
  temperature     : abap.dec(9,2);
  humidity        : abap.dec(9,2);
  recorded_at     : timestamp;
  received_at     : timestamp;
  raw_payload     : abap.string(0);
}
