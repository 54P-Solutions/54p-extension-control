class /S4P0/CL_CCC_METRICS_DB definition
  public
  final
  create public .

public section.

  types T_COMMIT_HANDLING type CHAR10 .
  types T_USAGE_MODE type CHAR20 .

  constants GC_USAGE_MODE_CREATE_NEW_RUN type T_USAGE_MODE value 'CREATE' ##NO_TEXT.
  constants GC_USAGE_MODE_USE_EXISTING_RUN type T_USAGE_MODE value 'READ' ##NO_TEXT.
  constants GC_USAGE_MODE_ON_THE_FLY type T_USAGE_MODE value 'NO_PERSISTENCE' ##NO_TEXT.
  constants GC_COMMIT_HANDLING_OUTSIDE type T_COMMIT_HANDLING value 'OUTSIDE' ##NO_TEXT.
  constants GC_COMMIT_HANDLING_INSIDE type T_COMMIT_HANDLING value 'INSIDE' ##NO_TEXT.

  class-methods GET_INSTANCE
    importing
      !IV_USAGE_MODE type T_USAGE_MODE default GC_USAGE_MODE_USE_EXISTING_RUN
      !IV_RUN_UUID type SYSUUID_X16 optional
      !IV_RUN_TYPE type /S4P0/DE_CCC_RUN_TYPE optional
      !IV_RUN_ID type /S4P0/DE_CCC_RUN_ID optional
      !IV_COMMIT_HANDLING type T_COMMIT_HANDLING default GC_COMMIT_HANDLING_INSIDE
    returning
      value(RO_INSTANCE) type ref to /S4P0/CL_CCC_METRICS_DB .
  class-methods DETERMINE_LATEST_RUN
    importing
      !IV_RUN_TYPE type /S4P0/DE_CCC_RUN_TYPE default 'F'
    returning
      value(RV_RUN_UUID) type SYSUUID_X16 .
  methods CONSTRUCTOR
    importing
      !IV_USAGE_MODE type T_USAGE_MODE
      !IV_RUN_UUID type SYSUUID_X16 .
  methods SET_RUN_STATUS
    importing
      !IV_RUN_STATUS type /S4P0/DE_CCC_RUN_STATUS .
  methods GET_COMMIT_HANDLING
    returning
      value(RV_COMMIT_HANDLING) type T_COMMIT_HANDLING .
  methods SAVE_SINGLE_OBJECT_METRICS
    importing
      !IS_METRICS type /S4P0/S_CCC_METRICS
      !IT_DEPENDENCIES type /S4P0/TT_CCC_DEPENDENCY
      !IT_WARNINGS type STRINGTAB .
  class-methods CONVERT_RUN_ID
    importing
      !IV_RUN_ID type /S4P0/DE_CCC_RUN_ID
    returning
      value(RV_RUN_ID_CONVERTED) type /S4P0/DE_CCC_RUN_ID .
  methods USE_METRICS_FROM_BUFFER
    importing
      !IS_METRICS_KEY type /S4P0/S_CCC_KEY
    returning
      value(RV_USE_METRICS_FROM_BUFFER) type BOOLE_D .
  methods READ_SINGLE_OBJECT_METRICS
    importing
      !IS_METRICS_KEY type /S4P0/S_CCC_KEY
    exporting
      !ES_METRICS type /S4P0/S_CCC_METRICS
      !ET_DEPENDENCIES type /S4P0/TT_CCC_DEPENDENCY
      !ET_WARNINGS type STRINGTAB .
protected section.
private section.

  data GV_USAGE_MODE type T_USAGE_MODE .
  data GV_RUN_UUID type SYSUUID_X16 .
  data GV_COMMIT_HANDLING type T_COMMIT_HANDLING .
  data GT_METRICS_METADATA type DFIES_TABLE .

  methods IS_COMMIT_INSIDE
    returning
      value(RV_COMMIT_INSIDE) type BOOLE_D .
  methods CREATE_METRICS_RUN
    importing
      !IV_RUN_TYPE type /S4P0/DE_CCC_RUN_TYPE
      !IV_RUN_ID type /S4P0/DE_CCC_RUN_ID .
  methods COMMIT .
ENDCLASS.



CLASS /S4P0/CL_CCC_METRICS_DB IMPLEMENTATION.


METHOD commit.

  IF is_commit_inside( ) = abap_true.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = abap_true.
  ENDIF.

ENDMETHOD.


METHOD constructor.

  DATA ls_metrics_data TYPE /s4p0/s_ccc_metrics_data."where-used

  me->gv_run_uuid   = iv_run_uuid.
  me->gv_usage_mode = iv_usage_mode.

  " determine metrics catalogue
  CALL FUNCTION 'DDIF_FIELDINFO_GET'
    EXPORTING
      tabname   = '/S4P0/S_CCC_METRICS_DATA'
    TABLES
      dfies_tab = gt_metrics_metadata
    EXCEPTIONS
      OTHERS    = 1.
  IF sy-subrc <> 0 OR gt_metrics_metadata[] IS INITIAL.
    "TODO: error handling
  ENDIF.

ENDMETHOD.


METHOD convert_run_id.

  rv_run_id_converted = iv_run_id.

  REPLACE ALL OCCURRENCES OF: '{SY-SYSID}' IN rv_run_id_converted WITH sy-sysid,
                              '{SY-DATUM}' IN rv_run_id_converted WITH sy-datum,
                              '{SY-UZEIT}' IN rv_run_id_converted WITH sy-uzeit.

ENDMETHOD.


METHOD create_metrics_run.

  DATA: ls_repo_run_db TYPE /s4p0/t_repo_run,
        lv_tstmppack   TYPE tzonref-tstamps.

  GET TIME.
  GET TIME STAMP FIELD lv_tstmppack.

  ls_repo_run_db-run_uuid = gv_run_uuid.
  ls_repo_run_db-run_type = iv_run_type.
  MOVE lv_tstmppack TO ls_repo_run_db-run_at_tstp.
  ls_repo_run_db-run_at_date = sy-datum.
  ls_repo_run_db-run_at_time = sy-uzeit.
  ls_repo_run_db-run_by = sy-uname.
  ls_repo_run_db-run_id = convert_run_id( iv_run_id ).
  ls_repo_run_db-run_status = /s4p0/if_ccc_metrics_const=>gc_run_status_started.

  INSERT /s4p0/t_repo_run FROM ls_repo_run_db.

  commit( ).

ENDMETHOD.


METHOD determine_latest_run.

  SELECT run_uuid
    FROM /s4p0/t_repo_run
    WHERE run_type   = @iv_run_type
      AND run_status = @/s4p0/if_ccc_metrics_const=>gc_run_status_finished_ok
    ORDER BY run_at_tstp DESCENDING
    INTO @rv_run_uuid
    UP TO 1 ROWS.
  ENDSELECT.

ENDMETHOD.


METHOD get_commit_handling.

  rv_commit_handling = gv_commit_handling.

ENDMETHOD.


METHOD get_instance.

  DATA: lv_run_uuid   TYPE /s4p0/t_repo_run-run_uuid,
        lv_usage_mode LIKE iv_usage_mode.

  lv_usage_mode = iv_usage_mode.

  CASE lv_usage_mode.
    WHEN gc_usage_mode_use_existing_run.
      IF iv_run_uuid IS NOT INITIAL.
        SELECT SINGLE run_uuid FROM /s4p0/t_repo_run
          INTO @lv_run_uuid
          WHERE run_uuid = @iv_run_uuid.
      ELSE.
        lv_run_uuid = determine_latest_run( ).
      ENDIF.

    WHEN gc_usage_mode_create_new_run.
      IF lv_run_uuid IS INITIAL.
        TRY.
            lv_run_uuid = cl_system_uuid=>if_system_uuid_static~create_uuid_x16( ).
          CATCH cx_uuid_error.
            "todo
        ENDTRY.
      ENDIF.

    WHEN OTHERS.
      "TODO

  ENDCASE.

  IF lv_run_uuid IS INITIAL.
    lv_usage_mode = gc_usage_mode_on_the_fly.
  ENDIF.

  ro_instance = NEW /s4p0/cl_ccc_metrics_db( iv_usage_mode = lv_usage_mode iv_run_uuid = lv_run_uuid ).

  IF lv_usage_mode = gc_usage_mode_create_new_run.
    ro_instance->create_metrics_run(
      EXPORTING iv_run_type = iv_run_type
                iv_run_id   = iv_run_id ).
  ENDIF.

ENDMETHOD.


METHOD is_commit_inside.

  IF gv_commit_handling = gc_commit_handling_inside.
    rv_commit_inside = abap_true.
  ENDIF.

ENDMETHOD.


METHOD read_single_object_metrics.

  DATA: ls_repo_h    TYPE /s4p0/t_repo_h,
        lt_repo_i    TYPE TABLE OF /s4p0/t_repo_i,
        lv_timestamp TYPE timestamp.

  FIELD-SYMBOLS: <fs_any>    TYPE any,
                 <fs_repo_i> LIKE LINE OF lt_repo_i.

  CHECK is_metrics_key IS NOT INITIAL.

  SELECT SINGLE * FROM /s4p0/t_repo_h INTO @ls_repo_h
    WHERE run_uuid = @gv_run_uuid.
  CHECK ls_repo_h-repo_uuid IS NOT INITIAL.

  SELECT * FROM /s4p0/t_repo_i APPENDING TABLE @lt_repo_i
    WHERE repo_uuid = @ls_repo_h-repo_uuid.
  CHECK lt_repo_i[] IS NOT INITIAL.

  LOOP AT gt_metrics_metadata ASSIGNING FIELD-SYMBOL(<fs_metric_metadata>).
    UNASSIGN: <fs_any>, <fs_repo_i>.

    ASSIGN COMPONENT <fs_metric_metadata>-fieldname OF STRUCTURE es_metrics-data TO <fs_any>.
    CHECK <fs_any> IS ASSIGNED.

    READ TABLE lt_repo_i ASSIGNING <fs_repo_i>
      WITH KEY metric_name = <fs_metric_metadata>-fieldname.
    CHECK <fs_repo_i> IS ASSIGNED.

    IF <fs_metric_metadata>-datatype = 'CHAR'.
      <fs_any> = <fs_repo_i>-metric_char_value.
    ELSE.
      <fs_any> = <fs_repo_i>-metric_numb_value.
    ENDIF.
  ENDLOOP.

ENDMETHOD.


METHOD save_single_object_metrics.

  DATA: ls_repo_h    TYPE /s4p0/t_repo_h,
        ls_repo_i    TYPE /s4p0/t_repo_i,
        lv_timestamp TYPE timestamp.

  FIELD-SYMBOLS <fs_any> TYPE any.

  CHECK is_metrics-key IS NOT INITIAL.

  set_run_status( /s4p0/if_ccc_metrics_const=>gc_run_status_progress ).

  GET TIME.
  GET TIME STAMP FIELD lv_timestamp.

  ls_repo_h-run_uuid = gv_run_uuid.
  MOVE-CORRESPONDING is_metrics-key TO ls_repo_h.

  TRY.
      ls_repo_h-repo_uuid = cl_system_uuid=>if_system_uuid_static~create_uuid_x16( ).
    CATCH cx_uuid_error.
      "todo
  ENDTRY.

  ls_repo_h-collected_at_tstp = lv_timestamp.
  ls_repo_h-collected_at_date = sy-datum.

  INSERT /s4p0/t_repo_h FROM ls_repo_h.

  LOOP AT gt_metrics_metadata ASSIGNING FIELD-SYMBOL(<fs_metric_metadata>).
    CLEAR ls_repo_i.
    UNASSIGN <fs_any>.

    ASSIGN COMPONENT <fs_metric_metadata>-fieldname OF STRUCTURE is_metrics TO <fs_any>.
    CHECK <fs_any> IS NOT INITIAL.

    ls_repo_i-repo_uuid = ls_repo_h-repo_uuid.

    TRY.
        ls_repo_i-metric_uuid = cl_system_uuid=>if_system_uuid_static~create_uuid_x16( ).
      CATCH cx_uuid_error.
        "todo
    ENDTRY.

    ls_repo_i-metric_name = <fs_metric_metadata>-fieldname.

    IF <fs_metric_metadata>-datatype = 'CHAR'.
      ls_repo_i-metric_char_value = <fs_any>.
    ELSE.
      MOVE <fs_any> TO ls_repo_i-metric_numb_value.
    ENDIF.

    INSERT /s4p0/t_repo_i FROM ls_repo_i.
  ENDLOOP.

  commit( ).

ENDMETHOD.


METHOD set_run_status.

  CHECK gv_run_uuid IS NOT INITIAL.

  UPDATE /s4p0/t_repo_run SET run_status = @iv_run_status
    WHERE run_uuid = @gv_run_uuid.
  commit( ).

ENDMETHOD.


METHOD use_metrics_from_buffer.

  IF gv_usage_mode = gc_usage_mode_use_existing_run.
    rv_use_metrics_from_buffer = abap_true.
  ENDIF.

ENDMETHOD.
ENDCLASS.
