CLASS zcl_iot_http_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

*"* ---------------------------------------------------------------------
*"  IoT sensor REST ingestion handler (ABAP Cloud / BTP ABAP Environment).
*"
*"  Exposed via an "HTTP Service" (ADT: New > HTTP Service), which creates
*"  the service binding and a handler class stub. Point the stub at this
*"  class, or paste this logic into the generated one.
*"
*"  POST → ingest one reading into ZTIOT_SENSOR
*"  GET  → return recent readings as JSON
*" ---------------------------------------------------------------------
  PUBLIC SECTION.
    INTERFACES if_http_service_extension .

  PRIVATE SECTION.

    CONSTANTS gc_api_key TYPE string VALUE 'change-me' ##NO_TEXT.

    TYPES:
      BEGIN OF ty_reading,
        device_id   TYPE string,
        sensor_type TYPE string,
        temperature TYPE decfloat16,
        humidity    TYPE decfloat16,
        recorded_at TYPE string,
      END OF ty_reading .

    METHODS handle_post
      IMPORTING request  TYPE REF TO if_web_http_request
                response TYPE REF TO if_web_http_response .
    METHODS handle_get
      IMPORTING request  TYPE REF TO if_web_http_request
                response TYPE REF TO if_web_http_response .
    METHODS is_authorized
      IMPORTING request      TYPE REF TO if_web_http_request
      RETURNING VALUE(rv_ok) TYPE abap_bool .
    METHODS iso8601_to_ts
      IMPORTING iv_iso       TYPE string
      RETURNING VALUE(rv_ts) TYPE timestamp .
ENDCLASS.



CLASS zcl_iot_http_service IMPLEMENTATION.

  METHOD if_http_service_extension~handle_request.

    IF is_authorized( request ) = abap_false.
      response->set_status( i_code = 401 i_reason = 'Unauthorized' ).
      response->set_text( `{"status":"error","message":"unauthorized"}` ).
      RETURN.
    ENDIF.

    CASE request->get_method( ).
      WHEN if_web_http_request=>co_request_method-post.
        handle_post( request = request response = response ).
      WHEN if_web_http_request=>co_request_method-get.
        handle_get( request = request response = response ).
      WHEN OTHERS.
        response->set_status( i_code = 405 i_reason = 'Method Not Allowed' ).
        response->set_text( `{"status":"error","message":"method not allowed"}` ).
    ENDCASE.

  ENDMETHOD.


  METHOD handle_post.

    DATA ls_reading TYPE ty_reading.
    DATA ls_db      TYPE ztiot_sensor.

    DATA(lv_body) = request->get_text( ).

    " /ui2/cl_json is available (released) on current ABAP Cloud tiers.
    " If your tier blocks it, swap this for the XCO JSON reader:
    "   DATA(lo) = xco_cp_json=>data->from_string( lv_body ).
    /ui2/cl_json=>deserialize(
      EXPORTING json        = lv_body
                pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING  data        = ls_reading ).

    IF ls_reading-device_id IS INITIAL.
      response->set_status( i_code = 400 i_reason = 'Bad Request' ).
      response->set_text( `{"status":"error","message":"deviceId is required"}` ).
      RETURN.
    ENDIF.

    TRY.
        ls_db-reading_id = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        RETURN.
    ENDTRY.

    ls_db-device_id   = ls_reading-device_id.
    ls_db-sensor_type = ls_reading-sensor_type.
    ls_db-temperature = ls_reading-temperature.
    ls_db-humidity    = ls_reading-humidity.
    GET TIME STAMP FIELD ls_db-received_at.
    ls_db-recorded_at = iso8601_to_ts( ls_reading-recorded_at ).
    IF ls_db-recorded_at IS INITIAL.
      ls_db-recorded_at = ls_db-received_at.
    ENDIF.
    ls_db-raw_payload = lv_body.

    INSERT ztiot_sensor FROM @ls_db.
    IF sy-subrc <> 0.
      response->set_status( i_code = 500 i_reason = 'Internal Server Error' ).
      response->set_text( `{"status":"error","message":"db insert failed"}` ).
      RETURN.
    ENDIF.

    " Evaluate cold-room thresholds; breaches are persisted to ZTIOT_ALARM
    " and committed together with the reading below.
    DATA(lt_alarm) = zcl_iot_alarm_check=>check_reading(
      iv_reading_id  = ls_db-reading_id
      iv_device_id   = ls_db-device_id
      iv_temperature = ls_db-temperature
      iv_humidity    = ls_db-humidity ).

    COMMIT WORK.

    DATA(lv_alarms) = lines( lt_alarm ).
    response->set_status( i_code = 201 i_reason = 'Created' ).
    response->set_content_type( 'application/json' ).
    response->set_text( |\{"status":"ok","readingId":"{ ls_db-reading_id }","alarms":{ lv_alarms }\}| ).

  ENDMETHOD.


  METHOD handle_get.

    DATA lv_limit TYPE i VALUE 50.
    DATA lt_data  TYPE STANDARD TABLE OF ztiot_sensor.

    DATA(lv_device)  = request->get_form_field( 'device_id' ).
    DATA(lv_type)    = request->get_form_field( 'type' ).
    DATA(lv_limit_c) = request->get_form_field( 'limit' ).
    IF lv_limit_c IS NOT INITIAL.
      lv_limit = lv_limit_c.
    ENDIF.
    IF lv_limit <= 0 OR lv_limit > 1000.
      lv_limit = 50.
    ENDIF.

    " GET ...?type=alarms → most recent alarms instead of readings.
    IF lv_type = 'alarms'.
      DATA lt_alarm TYPE STANDARD TABLE OF ztiot_alarm.
      IF lv_device IS INITIAL.
        SELECT * FROM ztiot_alarm
          ORDER BY created_at DESCENDING
          INTO TABLE @lt_alarm
          UP TO @lv_limit ROWS.
      ELSE.
        SELECT * FROM ztiot_alarm
          WHERE device_id = @lv_device
          ORDER BY created_at DESCENDING
          INTO TABLE @lt_alarm
          UP TO @lv_limit ROWS.
      ENDIF.
      response->set_status( i_code = 200 i_reason = 'OK' ).
      response->set_content_type( 'application/json' ).
      response->set_text( /ui2/cl_json=>serialize(
        data        = lt_alarm
        pretty_name = /ui2/cl_json=>pretty_mode-camel_case
        compress    = abap_false ) ).
      RETURN.
    ENDIF.

    IF lv_device IS INITIAL.
      SELECT * FROM ztiot_sensor
        ORDER BY received_at DESCENDING
        INTO TABLE @lt_data
        UP TO @lv_limit ROWS.
    ELSE.
      SELECT * FROM ztiot_sensor
        WHERE device_id = @lv_device
        ORDER BY received_at DESCENDING
        INTO TABLE @lt_data
        UP TO @lv_limit ROWS.
    ENDIF.

    DATA(lv_json) = /ui2/cl_json=>serialize(
        data        = lt_data
        pretty_name = /ui2/cl_json=>pretty_mode-camel_case
        compress    = abap_false ).

    response->set_status( i_code = 200 i_reason = 'OK' ).
    response->set_content_type( 'application/json' ).
    response->set_text( lv_json ).

  ENDMETHOD.


  METHOD is_authorized.
    DATA(lv_key) = request->get_header_field( 'x-api-key' ).
    IF lv_key = gc_api_key.
      rv_ok = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD iso8601_to_ts.
    DATA lv TYPE string.
    lv = iv_iso.
    REPLACE ALL OCCURRENCES OF `-` IN lv WITH ``.
    REPLACE ALL OCCURRENCES OF `:` IN lv WITH ``.
    REPLACE ALL OCCURRENCES OF `T` IN lv WITH ``.
    REPLACE ALL OCCURRENCES OF `Z` IN lv WITH ``.
    CONDENSE lv NO-GAPS.
    IF strlen( lv ) >= 14 AND lv(14) CO '0123456789'.
      rv_ts = lv(14).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
