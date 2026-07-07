@EndUserText.label : 'IoT Threshold Alarms'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztiot_alarm {
  key client   : abap.clnt not null;
  key alarm_id  : abap.char(32) not null;
  reading_id   : abap.char(32);
  device_id    : abap.char(30);
  alarm_type   : abap.char(20);
  severity     : abap.char(8);
  measured     : abap.dec(9,2);
  threshold    : abap.dec(9,2);
  message      : abap.char(255);
  created_at   : timestamp;
  acknowledged : abap.char(1);
}
