CLASS zcl_iot_dashboard DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

*"* ---------------------------------------------------------------------
*"  abap2UI5 dashboard for the IoT readings + threshold alarms.
*"
*"  Pure-ABAP UI5 app (no BSP/transport of UI artifacts):
*"    - top: most recent alarms (severity coloured)
*"    - bottom: recent readings, temperature coloured when out of range
*"  with a refresh button.
*"
*"  Requires the abap2UI5 framework installed (github.com/abap2UI5).
*"  Run it via the abap2UI5 launchpad / index handler, class name
*"  ZCL_IOT_DASHBOARD.
*"
*"  NOTE: the abap2UI5 fluent API evolves between releases. This targets a
*"  recent version; if a method name differs in yours, adjust accordingly
*"  (the shape — view factory > page > table > columns/cells — is stable).
*" ---------------------------------------------------------------------
  PUBLIC SECTION.
    INTERFACES z2ui5_if_app .

    TYPES:
      BEGIN OF ty_row,
        device_id   TYPE ztiot_sensor-device_id,
        sensor_type TYPE ztiot_sensor-sensor_type,
        temperature TYPE ztiot_sensor-temperature,
        temp_state  TYPE string,        " sap.ui.core.ValueState: Error/Warning/None
        humidity    TYPE ztiot_sensor-humidity,
        received_at TYPE ztiot_sensor-received_at,
      END OF ty_row,

      BEGIN OF ty_alarm_row,
        created_at TYPE ztiot_alarm-created_at,
        device_id  TYPE ztiot_alarm-device_id,
        alarm_type TYPE ztiot_alarm-alarm_type,
        severity   TYPE ztiot_alarm-severity,
        state      TYPE string,          " ObjectStatus state
        message    TYPE ztiot_alarm-message,
      END OF ty_alarm_row.

    DATA mt_rows   TYPE STANDARD TABLE OF ty_row       WITH EMPTY KEY .
    DATA mt_alarms TYPE STANDARD TABLE OF ty_alarm_row WITH EMPTY KEY .

  PRIVATE SECTION.
    " Display fallback max temperature (mirrors the alarm evaluator's
    " built-in cold-room default); used only to colour the readings table.
    CONSTANTS gc_disp_temp_max TYPE p LENGTH 5 DECIMALS 2 VALUE '8.00' ##NO_TEXT.
    METHODS load_data .
ENDCLASS.



CLASS zcl_iot_dashboard IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    " First render.
    IF client->check_on_navigated( ).
      load_data( ).

      DATA(view) = z2ui5_cl_xml_view=>factory( ).
      DATA(page) = view->shell(
        )->page(
             title         = 'IoT Sensör Panosu'
             shownavbutton = abap_false ).

      page->header_content(
        )->button( text = 'Yenile' press = client->_event( 'REFRESH' ) ).

      " --- recent alarms ---------------------------------------------
      DATA(alarm_tab) = page->table(
        items       = client->_bind( mt_alarms )
        headertext  = 'Aktif / Son Alarmlar' ).
      alarm_tab->columns(
        )->column( )->text( 'Zaman'    )->get_parent(
        )->column( )->text( 'Cihaz'    )->get_parent(
        )->column( )->text( 'Tip'      )->get_parent(
        )->column( )->text( 'Önem'     )->get_parent(
        )->column( )->text( 'Mesaj'    ).
      DATA(acells) = alarm_tab->items( )->column_list_item( )->cells( ).
      acells->text( '{CREATED_AT}' ).
      acells->text( '{DEVICE_ID}' ).
      acells->text( '{ALARM_TYPE}' ).
      acells->object_status( text = '{SEVERITY}' state = '{STATE}' ).
      acells->text( '{MESSAGE}' ).

      " --- recent readings -------------------------------------------
      DATA(tab) = page->table(
        items       = client->_bind( mt_rows )
        headertext  = 'Son Okumalar' ).
      tab->columns(
        )->column( )->text( 'Cihaz'         )->get_parent(
        )->column( )->text( 'Sensör'        )->get_parent(
        )->column( )->text( 'Sıcaklık (°C)' )->get_parent(
        )->column( )->text( 'Nem (%)'       )->get_parent(
        )->column( )->text( 'Alınma (UTC)'  ).
      DATA(cells) = tab->items( )->column_list_item( )->cells( ).
      cells->text( '{DEVICE_ID}' ).
      cells->text( '{SENSOR_TYPE}' ).
      cells->object_number( number = '{TEMPERATURE}' unit = '°C' state = '{TEMP_STATE}' ).
      cells->object_number( number = '{HUMIDITY}'    unit = '%'  ).
      cells->text( '{RECEIVED_AT}' ).

      client->view_display( view->stringify( ) ).
      RETURN.
    ENDIF.

    " Subsequent events.
    CASE client->get( )-event.
      WHEN 'REFRESH'.
        load_data( ).
        client->view_model_update( ).
    ENDCASE.

  ENDMETHOD.


  METHOD load_data.

    " Readings.
    DATA lt_sensor TYPE STANDARD TABLE OF ztiot_sensor.
    SELECT * FROM ztiot_sensor
      ORDER BY received_at DESCENDING
      INTO TABLE @lt_sensor
      UP TO 100 ROWS.

    CLEAR mt_rows.
    LOOP AT lt_sensor INTO DATA(ls_s).
      APPEND VALUE #(
        device_id   = ls_s-device_id
        sensor_type = ls_s-sensor_type
        temperature = ls_s-temperature
        humidity    = ls_s-humidity
        received_at = ls_s-received_at
        temp_state  = COND #( WHEN ls_s-temperature > gc_disp_temp_max THEN 'Error' ELSE 'None' )
      ) TO mt_rows.
    ENDLOOP.

    " Alarms.
    DATA lt_alarm TYPE STANDARD TABLE OF ztiot_alarm.
    SELECT * FROM ztiot_alarm
      ORDER BY created_at DESCENDING
      INTO TABLE @lt_alarm
      UP TO 50 ROWS.

    CLEAR mt_alarms.
    LOOP AT lt_alarm INTO DATA(ls_a).
      APPEND VALUE #(
        created_at = ls_a-created_at
        device_id  = ls_a-device_id
        alarm_type = ls_a-alarm_type
        severity   = ls_a-severity
        message    = ls_a-message
        state      = COND #( WHEN ls_a-severity = 'CRIT' THEN 'Error' ELSE 'Warning' )
      ) TO mt_alarms.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
