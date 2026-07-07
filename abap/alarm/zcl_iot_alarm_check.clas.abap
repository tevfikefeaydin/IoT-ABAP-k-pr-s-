CLASS zcl_iot_alarm_check DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

*"* ---------------------------------------------------------------------
*"  Cold-room threshold alarm evaluator (shared by both handler variants).
*"
*"  Given one reading, compares it against the configured thresholds
*"  (ZTIOT_THRESH, per device with a '*' default and a built-in cold-room
*"  fallback) and persists any breach into ZTIOT_ALARM.
*"
*"  Release-neutral: uses only plain ABAP SQL + system UUID + timestamp,
*"  so the same source deploys to the classic (SICF) and the ABAP Cloud
*"  systems. Call it from the handler right after INSERTing the reading
*"  and before COMMIT WORK, so reading and alarms commit together.
*" ---------------------------------------------------------------------
  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_alarm,
        alarm_type TYPE ztiot_alarm-alarm_type,
        severity   TYPE ztiot_alarm-severity,
        measured   TYPE ztiot_alarm-measured,
        threshold  TYPE ztiot_alarm-threshold,
        message    TYPE ztiot_alarm-message,
      END OF ty_alarm,
      tt_alarm TYPE STANDARD TABLE OF ty_alarm WITH EMPTY KEY.

    "! Evaluate one reading, persist breaches into ZTIOT_ALARM and return
    "! them. Returns an empty table when the reading is within limits.
    CLASS-METHODS check_reading
      IMPORTING iv_reading_id   TYPE ztiot_sensor-reading_id
                iv_device_id    TYPE ztiot_sensor-device_id
                iv_temperature  TYPE ztiot_sensor-temperature
                iv_humidity     TYPE ztiot_sensor-humidity
      RETURNING VALUE(rt_alarm) TYPE tt_alarm .

  PRIVATE SECTION.

    " Margin (above the limit) at which a WARN escalates to CRIT.
    CONSTANTS gc_crit_margin TYPE p LENGTH 5 DECIMALS 2 VALUE '2.00' ##NO_TEXT.

    TYPES:
      BEGIN OF ty_thresh,
        temp_min TYPE ztiot_thresh-temp_min,
        temp_max TYPE ztiot_thresh-temp_max,
        hum_min  TYPE ztiot_thresh-hum_min,
        hum_max  TYPE ztiot_thresh-hum_max,
      END OF ty_thresh .

    CLASS-METHODS read_threshold
      IMPORTING iv_device_id     TYPE ztiot_sensor-device_id
      RETURNING VALUE(rs_thresh) TYPE ty_thresh .
ENDCLASS.



CLASS zcl_iot_alarm_check IMPLEMENTATION.

  METHOD check_reading.

    DATA(ls_t) = read_threshold( iv_device_id ).

    " --- temperature ---------------------------------------------------
    IF iv_temperature > ls_t-temp_max.
      APPEND VALUE #(
        alarm_type = 'HIGH_TEMP'
        severity   = COND #( WHEN iv_temperature > ls_t-temp_max + gc_crit_margin THEN 'CRIT' ELSE 'WARN' )
        measured   = iv_temperature
        threshold  = ls_t-temp_max
        message    = |Temperature { iv_temperature } above maximum { ls_t-temp_max }| ) TO rt_alarm.
    ELSEIF iv_temperature < ls_t-temp_min.
      APPEND VALUE #(
        alarm_type = 'LOW_TEMP'
        severity   = COND #( WHEN iv_temperature < ls_t-temp_min - gc_crit_margin THEN 'CRIT' ELSE 'WARN' )
        measured   = iv_temperature
        threshold  = ls_t-temp_min
        message    = |Temperature { iv_temperature } below minimum { ls_t-temp_min }| ) TO rt_alarm.
    ENDIF.

    " --- humidity ------------------------------------------------------
    IF iv_humidity > ls_t-hum_max.
      APPEND VALUE #(
        alarm_type = 'HIGH_HUM'
        severity   = 'WARN'
        measured   = iv_humidity
        threshold  = ls_t-hum_max
        message    = |Humidity { iv_humidity } above maximum { ls_t-hum_max }| ) TO rt_alarm.
    ELSEIF iv_humidity < ls_t-hum_min.
      APPEND VALUE #(
        alarm_type = 'LOW_HUM'
        severity   = 'WARN'
        measured   = iv_humidity
        threshold  = ls_t-hum_min
        message    = |Humidity { iv_humidity } below minimum { ls_t-hum_min }| ) TO rt_alarm.
    ENDIF.

    IF rt_alarm IS INITIAL.
      RETURN.
    ENDIF.

    " --- persist -------------------------------------------------------
    DATA lt_db TYPE STANDARD TABLE OF ztiot_alarm.
    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT rt_alarm INTO DATA(ls_a).
      DATA ls_db TYPE ztiot_alarm.
      CLEAR ls_db.
      TRY.
          ls_db-alarm_id = cl_system_uuid=>create_uuid_c32_static( ).
        CATCH cx_uuid_error.
          CONTINUE.
      ENDTRY.
      ls_db-reading_id   = iv_reading_id.
      ls_db-device_id    = iv_device_id.
      ls_db-alarm_type   = ls_a-alarm_type.
      ls_db-severity     = ls_a-severity.
      ls_db-measured     = ls_a-measured.
      ls_db-threshold    = ls_a-threshold.
      ls_db-message      = ls_a-message.
      ls_db-created_at   = lv_now.
      ls_db-acknowledged = abap_false.
      APPEND ls_db TO lt_db.
    ENDLOOP.

    IF lt_db IS NOT INITIAL.
      INSERT ztiot_alarm FROM TABLE @lt_db.
    ENDIF.

  ENDMETHOD.


  METHOD read_threshold.
    " Device-specific config wins; then the '*' default row; then a
    " built-in cold-room fallback so an unconfigured system still alarms.
    SELECT SINGLE temp_min, temp_max, hum_min, hum_max
      FROM ztiot_thresh
      WHERE device_id = @iv_device_id
      INTO @rs_thresh.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    SELECT SINGLE temp_min, temp_max, hum_min, hum_max
      FROM ztiot_thresh
      WHERE device_id = '*'
      INTO @rs_thresh.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    rs_thresh-temp_min = '-5.00'.
    rs_thresh-temp_max = '8.00'.
    rs_thresh-hum_min  = '30.00'.
    rs_thresh-hum_max  = '95.00'.
  ENDMETHOD.

ENDCLASS.
