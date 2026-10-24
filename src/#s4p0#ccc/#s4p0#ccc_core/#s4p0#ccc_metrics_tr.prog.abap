*&---------------------------------------------------------------------*
*& Report /S4P0/CCC_METRICS_TR
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT /s4p0/ccc_metrics_tr.

*---------------------------------------------------------------------*
* /S4P0/CCC_METRICS_TR
*
* Runs /S4P0/CL_CCC_METRICS for the combined repository-object list
* of one or more CTS transport requests/tasks.
*
* - Multiple request/task IDs can be entered
* - Root request input: request + direct tasks are included by default
* - Explicit task input: only that task is added for that input ID
* - Duplicate objects across transports are analyzed only once
* - LIMU entries are normalized to their owning R3TR object
* - Duplicate E071 entries are consolidated to one metrics row
* - TABU/VDAT/CDAT and other non-repository entries are skipped
* - Upgrade effort is summed across the unique repository objects
*
* Prerequisite:
*   /S4P0/CL_CCC_METRICS with method DETERMINE_TRANSPORT
*---------------------------------------------------------------------*

TYPE-POOLS: slis.
TABLES: e070.

SELECT-OPTIONS s_trkor FOR e070-trkorr NO INTERVALS OBLIGATORY MATCHCODE OBJECT spak_open_trkorr_coll_shlp.
PARAMETERS p_tasks AS CHECKBOX DEFAULT 'X'.


DATA:
  gs_transport TYPE /s4p0/cl_ccc_metrics=>ty_transport_result,
  gt_output    TYPE /s4p0/tt_ccc_tr_output,
  gt_trkorr    TYPE /s4p0/cl_ccc_metrics=>ty_t_transport_id.

INITIALIZATION.
  /s4p0/cl_enh_utils=>show_prototype_indication( ).

AT SELECTION-SCREEN.
  PERFORM validate_transport_selection.

START-OF-SELECTION.
  IF /s4p0/cl_enh_core=>get_instance(
    iv_enhancement     = /s4p0/if_enh_constants=>gc_enh_ccc
    iv_sub_enhancement = /s4p0/if_enh_constants=>gc_sub_enh_ccc_base )->is_enhancement_active( ) = abap_false.
    MESSAGE 'Product is not active.' TYPE 'E'.
    RETURN.
  ENDIF.

  /s4p0/cl_enh_utils=>show_prototype_indication( ).

  DATA lv_include_tasks TYPE abap_bool.

  PERFORM build_transport_table.

  IF p_tasks = abap_true.
    lv_include_tasks = abap_true.
  ELSE.
    lv_include_tasks = abap_false.
  ENDIF.

  gs_transport = /s4p0/cl_ccc_metrics=>determine_transport(
    it_trkorr        = gt_trkorr
    iv_include_tasks = lv_include_tasks ).

  PERFORM build_output.

  IF gt_output IS INITIAL.
    PERFORM display_text_summary.
  ELSE.
    PERFORM display_alv.
  ENDIF.

*---------------------------------------------------------------------*
* Validate multiple-selection input. The class API takes exact transport IDs.
*---------------------------------------------------------------------*
FORM validate_transport_selection.
  DATA ls_sel LIKE LINE OF s_trkor.

  LOOP AT s_trkor INTO ls_sel.
    IF ls_sel-sign <> 'I' OR ls_sel-option <> 'EQ'.
      MESSAGE 'Enter transport IDs as individual include/equal values only' TYPE 'E'.
    ENDIF.
  ENDLOOP.
ENDFORM.

* Build the internal table passed to /S4P0/CL_CCC_METRICS.
FORM build_transport_table.
  DATA ls_sel LIKE LINE OF s_trkor.
  DATA lv_trkorr TYPE e070-trkorr.

  REFRESH gt_trkorr.
  LOOP AT s_trkor INTO ls_sel WHERE sign = 'I' AND option = 'EQ'.
    lv_trkorr = ls_sel-low.
    IF lv_trkorr IS NOT INITIAL.
      APPEND lv_trkorr TO gt_trkorr.
    ENDIF.
  ENDLOOP.
ENDFORM.

*---------------------------------------------------------------------*
* Build flat ALV output
*---------------------------------------------------------------------*
FORM build_output.
  DATA ls_item TYPE /s4p0/cl_ccc_metrics=>ty_transport_item.
  DATA ls_metrics TYPE /s4p0/s_ccc_metrics.
  DATA ls_evaluation TYPE /s4p0/s_ccc_evaluation.
  DATA ls_output TYPE /s4p0/s_ccc_tr_output.
  DATA lv_warning TYPE string.

  REFRESH gt_output.

  LOOP AT gs_transport-objects INTO ls_item.
    CLEAR: ls_output, ls_metrics, ls_evaluation, lv_warning.
    ls_metrics    = ls_item-result-metrics.
    ls_evaluation = ls_item-result-evaluation.

    ls_output-source_trkorr     = ls_item-source_trkorr.
    ls_output-transport_entries = ls_item-transport_entry_count.
    ls_output-source_pgmid      = ls_item-source_pgmid.
    ls_output-source_object     = ls_item-source_object.
    ls_output-source_obj_name   = ls_item-source_obj_name.

    " The output row includes the metric and evaluation structures,
    " so no field-by-field mapping is needed.
    MOVE-CORRESPONDING ls_metrics TO ls_output.
    MOVE-CORRESPONDING ls_evaluation TO ls_output.

    IF ls_metrics-object IS INITIAL.
      ls_output-metric_status = 'ERROR'.
    ELSE.
      ls_output-metric_status = 'OK'.
    ENDIF.

    READ TABLE ls_item-result-warnings INDEX 1 INTO lv_warning.
    IF sy-subrc = 0.
      ls_output-message = lv_warning.
    ENDIF.

    APPEND ls_output TO gt_output.
  ENDLOOP.
ENDFORM.

*---------------------------------------------------------------------*
* Text summary if no ALV rows are available
*---------------------------------------------------------------------*
FORM display_text_summary.
  DATA ls_summary TYPE /s4p0/cl_ccc_metrics=>ty_transport_summary.
  DATA lv_warning TYPE string.

  ls_summary = gs_transport-summary.

  FORMAT INTENSIFIED ON.
  WRITE: / 'Clean Core Transport Metrics'.
  FORMAT INTENSIFIED OFF.
  ULINE.
  WRITE: / 'Requested transport IDs      :', ls_summary-requested_transport_count.
  WRITE: / 'Root requests                 :', ls_summary-root_transport_count.
  WRITE: / 'Invalid transport IDs         :', ls_summary-invalid_transport_count.
  WRITE: / 'Transports/tasks in scope     :', ls_summary-scope_transport_count.
  IF ls_summary-requested_trkorr IS NOT INITIAL.
    WRITE: / 'Single requested transport    :', ls_summary-requested_trkorr.
  ENDIF.
  IF ls_summary-root_trkorr IS NOT INITIAL.
    WRITE: / 'Single root request            :', ls_summary-root_trkorr.
  ENDIF.
  WRITE: / 'E071 object-list entries     :', ls_summary-transport_entry_count.
  WRITE: / 'Repository entries           :', ls_summary-repository_entry_count.
  WRITE: / 'Unique repository objects    :', ls_summary-unique_object_count.
  WRITE: / 'Skipped non-repository       :', ls_summary-skipped_entry_count.
  WRITE: / 'Analysis errors              :', ls_summary-error_count.

  IF gs_transport-warnings IS NOT INITIAL.
    SKIP.
    WRITE: / 'Warnings:'.
    LOOP AT gs_transport-warnings INTO lv_warning.
      WRITE: / lv_warning.
    ENDLOOP.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------------*
* ALV display
*---------------------------------------------------------------------*
FORM display_alv.
  DATA lt_fieldcat TYPE lvc_t_fcat.
  DATA ls_layout TYPE lvc_s_layo.

  SORT gt_output BY estim_effort_minutes DESCENDING
                    worst_level DESCENDING
                    object obj_name.

  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name       = '/S4P0/S_CCC_TR_OUTPUT'
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
      i_callback_program     = sy-repid
      i_callback_top_of_page = 'TOP_OF_PAGE'
      is_layout_lvc          = ls_layout
      it_fieldcat_lvc        = lt_fieldcat
      i_save                 = 'A'
    TABLES
      t_outtab               = gt_output
    EXCEPTIONS
      program_error          = 1
      OTHERS                 = 2.

  IF sy-subrc <> 0.
    MESSAGE 'ALV display failed' TYPE 'S'.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------------*
* ALV header / transport aggregation
*---------------------------------------------------------------------*
FORM top_of_page.
  DATA lt_header TYPE slis_t_listheader.
  DATA ls_header TYPE slis_listheader.
  DATA ls_summary TYPE /s4p0/cl_ccc_metrics=>ty_transport_summary.
  DATA lv_info TYPE c LENGTH 200.
  DATA lv_hours TYPE p LENGTH 12 DECIMALS 1.
  DATA lv_days TYPE p LENGTH 12 DECIMALS 1.
  DATA lv_warning TYPE string.

  ls_summary = gs_transport-summary.

  CLEAR ls_header.
  ls_header-typ = 'H'.
  ls_header-info = 'Clean Core Transport Metrics'.
  APPEND ls_header TO lt_header.

  CLEAR lv_info.
  lv_info = |Requested: { ls_summary-requested_transport_count }  Roots: { ls_summary-root_transport_count }  Scope incl. tasks: { ls_summary-scope_transport_count }  Invalid: { ls_summary-invalid_transport_count }|.
  CLEAR ls_header.
  ls_header-typ = 'S'.
  ls_header-key = 'Transport scope'.
  ls_header-info = lv_info.
  APPEND ls_header TO lt_header.

  IF ls_summary-requested_trkorr IS NOT INITIAL.
    CLEAR ls_header.
    ls_header-typ = 'S'.
    ls_header-key = 'Single transport'.
    ls_header-info = ls_summary-requested_trkorr.
    APPEND ls_header TO lt_header.
  ENDIF.

  CLEAR lv_info.
  lv_info = |E071: { ls_summary-transport_entry_count }  Repository: { ls_summary-repository_entry_count }  Unique: { ls_summary-unique_object_count }  Skipped: { ls_summary-skipped_entry_count }  Errors: { ls_summary-error_count }|.
  CLEAR ls_header.
  ls_header-typ = 'S'.
  ls_header-key = 'Object list'.
  ls_header-info = lv_info.
  APPEND ls_header TO lt_header.

  CLEAR lv_info.
  lv_info = |Level B: { ls_summary-level_b }  Level C: { ls_summary-level_c }  Level D: { ls_summary-level_d }  DB reads: { ls_summary-direct_sap_table_reads }  DB writes: { ls_summary-direct_sap_table_writes }|.
  CLEAR ls_header.
  ls_header-typ = 'S'.
  ls_header-key = 'Coupling'.
  ls_header-info = lv_info.
  APPEND ls_header TO lt_header.

  CLEAR lv_info.
  lv_info = |Modified objects: { ls_summary-modified_object_count }  Modifications: { ls_summary-modification_count }  $TMP: { ls_summary-tmp_object_count }  SAP copies: { ls_summary-copied_sap_standard_count }  Implicit enh.: {
ls_summary-implicit_enhancements }|.
  CLEAR ls_header.
  ls_header-typ = 'S'.
  ls_header-key = 'Special risk'.
  ls_header-info = lv_info.
  APPEND ls_header TO lt_header.

  lv_hours = ls_summary-ESTIM_effort_minutes / 60.
  lv_days  = ls_summary-ESTIM_effort_minutes / 480.
  CLEAR lv_info.
  lv_info = |Estimate: { ls_summary-ESTIM_effort_minutes } min  Range: { ls_summary-ESTIM_effort_low_minutes }-{ ls_summary-ESTIM_effort_high_minutes } min  Hours: { lv_hours }  Person-days: { lv_days }|.
  CLEAR ls_header.
  ls_header-typ = 'S'.
  ls_header-key = 'Estimated effort'.
  ls_header-info = lv_info.
  APPEND ls_header TO lt_header.

  CLEAR ls_header.
  ls_header-typ = 'S'.
  ls_header-key = 'Worst level'.
  ls_header-info = ls_summary-worst_level.
  APPEND ls_header TO lt_header.

  READ TABLE gs_transport-warnings INDEX 1 INTO lv_warning.
  IF sy-subrc = 0.
    CLEAR ls_header.
    ls_header-typ = 'A'.
    ls_header-info = lv_warning.
    APPEND ls_header TO lt_header.
  ENDIF.

  CALL FUNCTION 'REUSE_ALV_COMMENTARY_WRITE'
    EXPORTING
      it_list_commentary = lt_header.
ENDFORM.

*---------------------------------------------------------------------*
* Field catalog
*---------------------------------------------------------------------*
