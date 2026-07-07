CLASS zcl_iot_dashboard DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

*"* ---------------------------------------------------------------------
*"  abap2UI5 dashboard for the IoT readings.
*"
*"  Pure-ABAP UI5 app (no BSP/transport of UI artifacts): lists the most
*"  recent rows from ZTIOT_SENSOR with a refresh button.
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
        humidity    TYPE ztiot_sensor-humidity,
        received_at TYPE ztiot_sensor-received_at,
      END OF ty_row .

    DATA mt_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY .

  PRIVATE SECTION.
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

      DATA(tab) = page->table( items = client->_bind( mt_rows ) ).

      tab->columns(
        )->column( )->text( 'Cihaz'         )->get_parent(
        )->column( )->text( 'Sensör'        )->get_parent(
        )->column( )->text( 'Sıcaklık (°C)' )->get_parent(
        )->column( )->text( 'Nem (%)'       )->get_parent(
        )->column( )->text( 'Alınma (UTC)'  ).

      DATA(cells) = tab->items( )->column_list_item( )->cells( ).
      cells->text( '{DEVICE_ID}' ).
      cells->text( '{SENSOR_TYPE}' ).
      cells->object_number( number = '{TEMPERATURE}' unit = '°C' ).
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
    SELECT device_id, sensor_type, temperature, humidity, received_at
      FROM ztiot_sensor
      ORDER BY received_at DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @mt_rows
      UP TO 100 ROWS.
  ENDMETHOD.

ENDCLASS.
