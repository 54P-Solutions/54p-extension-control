*---------------------------------------------------------------------*
* /S4P0/CCC_SYSTEM_CHECKRUN
*
* Presentation layer for a system-wide Clean Core metric run.
*
* The report itself only builds the selection, drives the three Clean
* Core Control layers and displays the result:
*   layer 1  /S4P0/CL_CCC_EXTRACT  - builds the object population
*   layer 2  /S4P0/CL_CCC_METRICS  - determines the metrics
*   layer 3  /S4P0/CL_CCC_WEIGHT   - weights them into an effort estimate
*
* Population (built by layer 1):
*   1. All non-SAP R3TR repository objects from TADIR
*   2. All active modifications from SMODILOG
*      - SAP Note corrections are excluded
*      - duplicate objects are merged
*
* Designed for ECC / classic ABAP. No += operator is used.
*---------------------------------------------------------------------*
REPORT /s4p0/ccc_system_checkrun.

TABLES: tadir.

*---------------------------------------------------------------------*
* Selection screen
*---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
PARAMETERS:
  p_tadir AS CHECKBOX DEFAULT 'X',
  p_mod   AS CHECKBOX DEFAULT 'X',
  p_note  AS CHECKBOX DEFAULT 'X'.
SELECT-OPTIONS:
  s_obj  FOR tadir-object,
  s_devc FOR tadir-devclass.
PARAMETERS:
  p_src AS CHECKBOX DEFAULT ' ',
  p_max TYPE i DEFAULT 0.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
PARAMETERS:
  p_runmrx RADIOBUTTON GROUP run DEFAULT 'X',
  p_objdis RADIOBUTTON GROUP run.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
PARAMETERS:
  p_save   AS CHECKBOX DEFAULT 'X',
  p_saveid TYPE /s4p0/de_ccc_run_id DEFAULT 'Run_{SY-SYSID}_{SY-DATUM}{SY-UZEIT}'.
SELECTION-SCREEN END OF BLOCK b3.

DATA:
  gt_objects       TYPE /s4p0/tt_ccc_object,
  gt_output        TYPE /s4p0/tt_ccc_output,
  gv_note_excluded TYPE i,
  gv_unresolved    TYPE i.

*---------------------------------------------------------------------*
* Selection validation
*---------------------------------------------------------------------*
AT SELECTION-SCREEN.
  IF p_tadir IS INITIAL AND p_mod IS INITIAL.
    MESSAGE 'Select TADIR objects, modifications, or both' TYPE 'E'.
  ENDIF.

INITIALIZATION.
  /s4p0/cl_enh_utils=>show_prototype_indication( ).

START-OF-SELECTION.
  IF /s4p0/cl_enh_core=>get_instance(
    iv_enhancement     = /s4p0/if_enh_constants=>gc_enh_ccc
    iv_sub_enhancement = /s4p0/if_enh_constants=>gc_sub_enh_ccc_base )->is_enhancement_active( ) = abap_false.
    MESSAGE 'Product is not active.' TYPE 'E'.
    RETURN.
  ENDIF.

  /s4p0/cl_enh_utils=>show_prototype_indication( ).

  PERFORM collect_population.

  IF gt_objects IS INITIAL.
    MESSAGE 'No objects selected for the Clean Core check run' TYPE 'S'.
    RETURN.
  ENDIF.

  IF p_runmrx = abap_true.
    PERFORM run_metrics.
  ELSE.
    PERFORM list_population.
  ENDIF.

  PERFORM show_summary.
  PERFORM show_alv.

*&---------------------------------------------------------------------*
*& Build the object population through the extraction layer.
*&---------------------------------------------------------------------*
FORM collect_population.

  /s4p0/cl_ccc_extract=>build_population(
    EXPORTING
      it_object_range   = s_obj[]
      it_devclass_range = s_devc[]
      iv_include_tadir  = p_tadir
      iv_include_mods   = p_mod
      iv_exclude_notes  = p_note
      iv_source_only    = p_src
      iv_max_objects    = p_max
    IMPORTING
      et_objects        = gt_objects
      ev_note_excluded  = gv_note_excluded
      ev_unresolved     = gv_unresolved ).

ENDFORM.

*&---------------------------------------------------------------------*
*& Population only - no metric determination was requested.
*&---------------------------------------------------------------------*
FORM list_population.

  DATA ls_object TYPE /s4p0/s_ccc_object.
  DATA ls_output TYPE /s4p0/s_ccc_output.

  LOOP AT gt_objects INTO ls_object.
    CLEAR ls_output.
    MOVE-CORRESPONDING ls_object TO ls_output.
    ls_output-metric_status = 'NOT_RUN'.
    APPEND ls_output TO gt_output.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Determine and weight the metrics for every collected object.
*&---------------------------------------------------------------------*
FORM run_metrics.

  DATA:
    ls_object  TYPE /s4p0/s_ccc_object,
    ls_output  TYPE /s4p0/s_ccc_output,
    lv_total   TYPE i,
    lv_current TYPE i.

  DESCRIBE TABLE gt_objects LINES lv_total.

  IF p_save = abap_true.
    DATA(lo_metrics_db) = /s4p0/cl_ccc_metrics_db=>get_instance(
      EXPORTING
        iv_usage_mode = /s4p0/cl_ccc_metrics_db=>gc_usage_mode_create_new_run
        iv_run_type   = /s4p0/if_ccc_metrics_const=>gc_run_type_full_scope
        iv_run_id     = p_saveid ).
    /s4p0/cl_ccc_metrics=>activate_metrics_persistence(
      EXPORTING io_metrics_db = lo_metrics_db ).
  ENDIF.

  LOOP AT gt_objects INTO ls_object.
    ADD 1 TO lv_current.
    /s4p0/cl_ccc_metrics=>progress_indicator(
      iv_current = lv_current
      iv_total   = lv_total
      iv_text    = 'Determining Clean Core metrics' ).

    CLEAR ls_output.
    MOVE-CORRESPONDING ls_object TO ls_output.

    PERFORM fill_metrics USING ls_object CHANGING ls_output.

    APPEND ls_output TO gt_output.
  ENDLOOP.

  lo_metrics_db->set_run_status( /s4p0/if_ccc_metrics_const=>gc_run_status_finished_ok ).

ENDFORM.

*&---------------------------------------------------------------------*
*& Analyze one object and map the result onto the output row.
*&---------------------------------------------------------------------*
FORM fill_metrics USING    is_object TYPE /s4p0/s_ccc_object
                  CHANGING cs_output TYPE /s4p0/s_ccc_output.

  DATA:
    ls_result     TYPE /s4p0/cl_ccc_metrics=>ty_result,
    ls_metrics    TYPE /s4p0/s_ccc_metrics,
    ls_evaluation TYPE /s4p0/s_ccc_evaluation,
    lv_message    TYPE string,
    lx_root       TYPE REF TO cx_root.

  TRY.
      ls_result = /s4p0/cl_ccc_metrics=>determine(
        iv_pgmid    = is_object-pgmid
        iv_object   = is_object-object
        iv_obj_name = CONV #( is_object-obj_name ) ).

      ls_metrics = ls_result-metrics.

      " Use the driver population's note-excluded SMODILOG count for the
      " modification KPI shown by this system checkrun. The metric class may
      " intentionally use a broader SMODILOG definition.
      ls_metrics-modification_count = is_object-modification_logs.
      ls_metrics-modifications      = is_object-modification_logs.
      IF is_object-modification_logs > 0.
        ls_metrics-modification_detected = abap_true.
      ELSE.
        CLEAR ls_metrics-modification_detected.
      ENDIF.
      IF ls_metrics-statement_count > 0.
        ls_metrics-modification_density =
          is_object-modification_logs * 1000 / ls_metrics-statement_count.
      ELSE.
        CLEAR ls_metrics-modification_density.
      ENDIF.

      " Recalculate the effort model with the driver's SAP-Note-excluded
      " modification count so the penalty matches this checkrun population.
      ls_evaluation = /s4p0/cl_ccc_weight=>evaluate_object( ls_metrics ).

      " The output row includes both structures, so no field-by-field
      " mapping is needed any more.
      MOVE-CORRESPONDING ls_metrics TO cs_output.
      MOVE-CORRESPONDING ls_evaluation TO cs_output.

      " MOVE-CORRESPONDING overwrote the population key/origin fields with
      " the normalized values; restore the collector's own origin data.
      cs_output-author            = is_object-author.
      cs_output-srcsystem         = is_object-srcsystem.
      cs_output-from_tadir        = is_object-from_tadir.
      cs_output-from_modification = is_object-from_modification.
      cs_output-modification_logs = is_object-modification_logs.

      cs_output-metric_status = 'OK'.

      " Surface the first analyzer warning in the overview.
      READ TABLE ls_result-warnings INDEX 1 INTO lv_message.
      IF sy-subrc = 0.
        cs_output-message = lv_message.
      ENDIF.

    CATCH cx_root INTO lx_root.
      cs_output-metric_status = 'ERROR'.
      cs_output-message = lx_root->get_text( ).
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Classic list summary shown before the ALV.
*&---------------------------------------------------------------------*
FORM show_summary.

  DATA:
    lv_total        TYPE i,
    lv_custom       TYPE i,
    lv_mod          TYPE i,
    lv_clone        TYPE i,
    lv_effort_min   TYPE i,
    lv_effort_low   TYPE i,
    lv_effort_high  TYPE i,
    lv_effort_hours TYPE decfloat34,
    lv_effort_days  TYPE decfloat34,
    ls_object       TYPE /s4p0/s_ccc_object,
    ls_output       TYPE /s4p0/s_ccc_output.

  DESCRIBE TABLE gt_objects LINES lv_total.

  LOOP AT gt_objects INTO ls_object.
    IF ls_object-from_tadir = abap_true.
      ADD 1 TO lv_custom.
    ENDIF.
    IF ls_object-from_modification = abap_true.
      ADD 1 TO lv_mod.
    ENDIF.
  ENDLOOP.

  FORMAT INTENSIFIED ON.
  WRITE: / 'Clean Core system check run'.
  FORMAT INTENSIFIED OFF.
  ULINE.
  WRITE: / 'Unique repository objects          :', lv_total.
  WRITE: / 'Non-SAP TADIR objects              :', lv_custom.
  WRITE: / 'Objects with active modifications  :', lv_mod.

  LOOP AT gt_output INTO ls_output.
    IF ls_output-copied_sap_standard_detected = abap_true.
      ADD 1 TO lv_clone.
    ENDIF.
    ADD ls_output-estim_effort_minutes TO lv_effort_min.
    ADD ls_output-estim_effort_low_minutes TO lv_effort_low.
    ADD ls_output-estim_effort_high_minutes TO lv_effort_high.
  ENDLOOP.

  IF lv_effort_min > 0.
    lv_effort_hours = CONV decfloat34( lv_effort_min ) / 60.
    lv_effort_days = CONV decfloat34( lv_effort_min ) / 480.
  ENDIF.

  WRITE: / 'Copied SAP Standard objects        :', lv_clone.
  WRITE: / 'Estimated effort (minutes):', lv_effort_min.
  WRITE: / 'Estimate lower bound (minutes)    :', lv_effort_low.
  WRITE: / 'Estimate upper bound (minutes)    :', lv_effort_high.
  WRITE: / 'Estimated developer hours         :', lv_effort_hours DECIMALS 1.
  WRITE: / 'Estimated person-days (8h)        :', lv_effort_days DECIMALS 1.
  WRITE: / 'SAP Note log entries excluded      :', gv_note_excluded.
  WRITE: / 'Modification logs not normalized   :', gv_unresolved.
  SKIP.

ENDFORM.

*&---------------------------------------------------------------------*
*& ALV overview. The field catalog is derived from the DDIC structure,
*& so the column headers come from the data element labels.
*&---------------------------------------------------------------------*
FORM show_alv.

  DATA:
    lt_fieldcat     TYPE lvc_t_fcat,
    ls_layout       TYPE lvc_s_layo,
    ls_output_struc TYPE /s4p0/s_ccc_output. "for where-used

  SORT gt_output BY estim_effort_minutes DESCENDING
                    worst_level DESCENDING
                    from_modification DESCENDING
                    object obj_name.

  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name       = '/S4P0/S_CCC_OUTPUT'
    CHANGING
      ct_fieldcat            = lt_fieldcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.

  IF sy-subrc <> 0.
    MESSAGE 'Field catalog could not be derived' TYPE 'S'.
    RETURN.
  ENDIF.

  ls_layout-zebra = abap_true.
  ls_layout-cwidth_opt = abap_true.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program = sy-repid
      is_layout_lvc      = ls_layout
      it_fieldcat_lvc    = lt_fieldcat
      i_save             = 'A'
    TABLES
      t_outtab           = gt_output
    EXCEPTIONS
      program_error      = 1
      OTHERS             = 2.

  IF sy-subrc <> 0.
    MESSAGE 'ALV display failed' TYPE 'S'.
  ENDIF.

ENDFORM.
