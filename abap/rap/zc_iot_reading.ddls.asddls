@EndUserText.label: 'IoT Sensor Reading (Custom Entity)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_IOT_READING_QUERY'
@UI.headerInfo: {
  typeName: 'Reading',
  typeNamePlural: 'Readings',
  title: { value: 'DeviceId' }
}
define root custom entity ZC_IOT_READING
{
      @UI.facet: [ { id: 'General', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Reading', position: 10 } ]

      @UI: { lineItem: [ { position: 10 } ], identification: [ { position: 10 } ] }
  key ReadingId    : abap.char(32);

      @UI: { lineItem: [ { position: 20 } ], identification: [ { position: 20 } ], selectionField: [ { position: 10 } ] }
      DeviceId     : abap.char(30);

      @UI: { lineItem: [ { position: 30 } ], identification: [ { position: 30 } ] }
      SensorType   : abap.char(20);

      @UI: { lineItem: [ { position: 40 } ], identification: [ { position: 40 } ] }
      @Semantics.quantity.unitOfMeasure: 'TemperatureUnit'
      Temperature  : abap.dec(9,2);

      @UI: { lineItem: [ { position: 50 } ], identification: [ { position: 50 } ] }
      Humidity     : abap.dec(9,2);

      @UI: { lineItem: [ { position: 60 } ], identification: [ { position: 60 } ] }
      RecordedAt   : timestamp;

      @UI: { lineItem: [ { position: 70 } ], identification: [ { position: 70 } ] }
      ReceivedAt   : timestamp;
}
