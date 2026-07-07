CLASS zcl_iot_reading_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

*"* ---------------------------------------------------------------------
*"  Query implementation for the ZC_IOT_READING unmanaged custom entity.
*"
*"  Reads from ZTIOT_SENSOR and serves it through OData V4. Supports
*"  paging ($top/$skip), $count and a DeviceId filter (selection field /
*"  $filter=DeviceId eq '...') translated into the DB query.
*" ---------------------------------------------------------------------
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider .
ENDCLASS.



CLASS zcl_iot_reading_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA lt_result TYPE STANDARD TABLE OF zc_iot_reading.
    DATA lr_device TYPE RANGE OF ztiot_sensor-device_id.

    " Translate the requested filter (selection field or $filter) into a
    " DeviceId range so the DB queries below are actually restricted. An
    " empty range means "no restriction" (device_id IN () returns all rows),
    " which preserves the unfiltered behaviour when no filter is sent.
    TRY.
        DATA(lt_ranges) = io_request->get_filter( )->get_as_ranges( ).
        LOOP AT lt_ranges REFERENCE INTO DATA(lr_pair).
          IF lr_pair->name = 'DEVICEID'.
            ASSIGN lr_pair->range->* TO FIELD-SYMBOL(<lt_dev>).
            IF <lt_dev> IS ASSIGNED.
              lr_device = CORRESPONDING #( <lt_dev> ).
            ENDIF.
          ENDIF.
        ENDLOOP.
      CATCH cx_rap_query_filter_no_range.
        " Filter can't be expressed as ranges -> fall back to unfiltered.
    ENDTRY.

    IF io_request->is_data_requested( ).

      DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).
      DATA(lv_skip) = io_request->get_paging( )->get_offset( ).
      IF lv_top <= 0 OR lv_top = if_rap_query_paging=>page_size_unlimited.
        lv_top = 1000.
      ENDIF.

      " Column aliases map DB field names to the custom entity element names.
      SELECT reading_id  AS readingid,
             device_id   AS deviceid,
             sensor_type AS sensortype,
             temperature AS temperature,
             humidity    AS humidity,
             recorded_at AS recordedat,
             received_at AS receivedat
        FROM ztiot_sensor
        WHERE device_id IN @lr_device
        ORDER BY received_at DESCENDING
        INTO CORRESPONDING FIELDS OF TABLE @lt_result
        UP TO @lv_top ROWS
        OFFSET @lv_skip.

      io_response->set_data( lt_result ).

    ENDIF.

    IF io_request->is_total_numb_of_rec_requested( ).
      SELECT COUNT( * ) FROM ztiot_sensor
        WHERE device_id IN @lr_device
        INTO @DATA(lv_count).
      io_response->set_total_number_of_records( lv_count ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
