CLASS zcl_iot_rest_handler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

*"* ---------------------------------------------------------------------
*"  IoT sensor REST ingestion handler (classic on-prem / SICF).
*"
*"  Bind this class to an SICF node (e.g. /sap/ziot/ingest). See the
*"  README in this folder for the step-by-step SICF setup.
*"
*"  POST  → ingest one reading (JSON body) into ZTIOT_SENSOR
*"  GET   → return the most recent readings as a JSON array
*"  OPTIONS → CORS pre-flight (so a browser dashboard can call it)
*" ---------------------------------------------------------------------
  PUBLIC SECTION.
    INTERFACES if_http_extension .

  PROTECTED SECTION.

  PRIVATE SECTION.

    " Shared secret expected in the X-API-Key request header.
    " DEMO ONLY — in production read this from a secured table / SSF,
    " never hard-code it.
    CONSTANTS gc_api_key TYPE string VALUE 'change-me' ##NO_TEXT.

    " Inbound JSON model. /ui2/cl_json maps camelCase <-> UPPER_CASE
    " when pretty_mode = camel_case (deviceId <-> DEVICE_ID ...).
    TYPES:
      BEGIN OF ty_reading,
        device_id   TYPE string,
        sensor_type TYPE string,
        temperature TYPE decfloat16,
        humidity    TYPE decfloat16,
        recorded_at TYPE string,        " ISO-8601, optional
      END OF ty_reading .

    METHODS handle_post
      IMPORTING io_server TYPE REF TO if_http_server .
    METHODS handle_get
      IMPORTING io_server TYPE REF TO if_http_server .
    METHODS is_authorized
      IMPORTING io_server       TYPE REF TO if_http_server
      RETURNING VALUE(rv_ok)    TYPE abap_bool .
    METHODS send_json
      IMPORTING io_server  TYPE REF TO if_http_server
                iv_status  TYPE i
                iv_reason  TYPE string
                iv_body    TYPE string .
    " Convert "2026-07-07T10:20:30Z" (UTC) to a packed TIMESTAMP.
    " Returns 0 when the input can't be parsed.
    METHODS iso8601_to_ts
      IMPORTING iv_iso       TYPE string
      RETURNING VALUE(rv_ts) TYPE timestamp .
ENDCLASS.



CLASS zcl_iot_rest_handler IMPLEMENTATION.

  METHOD if_http_extension~handle_request.

    DATA(lv_method) = to_upper( server->request->get_header_field( name = '~request_method' ) ).

    " CORS pre-flight — answer before auth so browsers get their headers.
    IF lv_method = 'OPTIONS'.
      server->response->set_header_field( name = 'Access-Control-Allow-Origin'  value = '*' ).
      server->response->set_header_field( name = 'Access-Control-Allow-Methods' value = 'GET, POST, OPTIONS' ).
      server->response->set_header_field( name = 'Access-Control-Allow-Headers' value = 'Content-Type, X-API-Key, Authorization' ).
      server->response->set_status( code = 204 reason = 'No Content' ).
      RETURN.
    ENDIF.

    IF is_authorized( server ) = abap_false.
      server->response->set_header_field( name = 'WWW-Authenticate' value = 'Basic realm="IoT"' ).
      send_json( io_server = server iv_status = 401 iv_reason = 'Unauthorized'
                 iv_body = `{"status":"error","message":"unauthorized"}` ).
      RETURN.
    ENDIF.

    CASE lv_method.
      WHEN 'POST'.
        handle_post( server ).
      WHEN 'GET'.
        handle_get( server ).
      WHEN OTHERS.
        send_json( io_server = server iv_status = 405 iv_reason = 'Method Not Allowed'
                   iv_body = `{"status":"error","message":"method not allowed"}` ).
    ENDCASE.

  ENDMETHOD.


  METHOD handle_post.

    DATA ls_reading TYPE ty_reading.
    DATA ls_db      TYPE ztiot_sensor.

    DATA(lv_body) = io_server->request->get_cdata( ).

    /ui2/cl_json=>deserialize(
      EXPORTING json        = lv_body
                pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING  data        = ls_reading ).

    IF ls_reading-device_id IS INITIAL.
      send_json( io_server = io_server iv_status = 400 iv_reason = 'Bad Request'
                 iv_body = `{"status":"error","message":"deviceId is required"}` ).
      RETURN.
    ENDIF.

    TRY.
        ls_db-reading_id = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        " Fallback: timestamp-based id (still unique enough for a demo).
        GET TIME STAMP FIELD DATA(lv_fallback).
        ls_db-reading_id = |{ lv_fallback }{ sy-uzeit }|.
    ENDTRY.

    ls_db-device_id   = ls_reading-device_id.
    ls_db-sensor_type = ls_reading-sensor_type.
    ls_db-temperature = ls_reading-temperature.
    ls_db-humidity    = ls_reading-humidity.

    GET TIME STAMP FIELD ls_db-received_at.
    ls_db-recorded_at = iso8601_to_ts( ls_reading-recorded_at ).
    IF ls_db-recorded_at IS INITIAL.
      ls_db-recorded_at = ls_db-received_at.   " device had no clock
    ENDIF.

    ls_db-raw_payload = lv_body.

    INSERT ztiot_sensor FROM ls_db.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      send_json( io_server = io_server iv_status = 500 iv_reason = 'Internal Server Error'
                 iv_body = `{"status":"error","message":"db insert failed"}` ).
      RETURN.
    ENDIF.

    " Evaluate cold-room thresholds; any breach is persisted to ZTIOT_ALARM
    " and committed together with the reading below.
    DATA(lt_alarm) = zcl_iot_alarm_check=>check_reading(
      iv_reading_id  = ls_db-reading_id
      iv_device_id   = ls_db-device_id
      iv_temperature = ls_db-temperature
      iv_humidity    = ls_db-humidity ).

    COMMIT WORK.

    DATA(lv_alarms) = lines( lt_alarm ).
    send_json( io_server = io_server iv_status = 201 iv_reason = 'Created'
               iv_body = |\{"status":"ok","readingId":"{ ls_db-reading_id }","alarms":{ lv_alarms }\}| ).

  ENDMETHOD.


  METHOD handle_get.

    DATA lv_limit TYPE i VALUE 50.
    DATA lt_data  TYPE STANDARD TABLE OF ztiot_sensor.

    DATA(lv_device)  = io_server->request->get_form_field( 'device_id' ).
    DATA(lv_type)    = io_server->request->get_form_field( 'type' ).
    DATA(lv_limit_c) = condense( io_server->request->get_form_field( 'limit' ) ).
    " Only convert when it is purely numeric and short enough to fit an i;
    " a non-numeric value like ?limit=abc must not raise a conversion dump.
    IF lv_limit_c IS NOT INITIAL AND lv_limit_c CO '0123456789' AND strlen( lv_limit_c ) <= 4.
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
      send_json( io_server = io_server iv_status = 200 iv_reason = 'OK'
                 iv_body = /ui2/cl_json=>serialize(
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

    send_json( io_server = io_server iv_status = 200 iv_reason = 'OK' iv_body = lv_json ).

  ENDMETHOD.


  METHOD is_authorized.
    " SICF already enforces the SAP logon (Basic auth). On top of that we
    " verify a per-device shared secret so credentials can be rotated
    " independently of the SAP user.
    DATA(lv_key) = io_server->request->get_header_field( name = 'X-API-Key' ).
    IF lv_key = gc_api_key.
      rv_ok = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD send_json.
    io_server->response->set_status( code = iv_status reason = iv_reason ).
    io_server->response->set_content_type( 'application/json; charset=utf-8' ).
    io_server->response->set_header_field( name = 'Access-Control-Allow-Origin' value = '*' ).
    io_server->response->set_cdata( iv_body ).
  ENDMETHOD.


  METHOD iso8601_to_ts.
    " Accepts e.g. 2026-07-07T10:20:30Z (UTC). Strips separators and keeps the
    " leading 14 digits -> yyyymmddhhmmss, a valid packed TIMESTAMP value.
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
