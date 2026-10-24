*&---------------------------------------------------------------------*
*& Report /S4P0/CCC_UPGRADE_DASHBRD
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT /s4p0/ccc_upgrade_dashbrd.

*---------------------------------------------------------------------*
* /S4P0/CCC_UPGRADE_DASHBRD
*
* Graphical upgrade-capacity dashboard for ECC / classic ABAP.
*
* Prerequisite:
*   /S4P0/CL_CCC_METRICS from the Clean Core metric implementation.
*
* Inputs:
*   P_FTE  = FTE available for the upgrade correction work
*   P_DAYS = working days available
*
* Capacity model:
*   Available minutes = FTE * days * 8 hours * 60 minutes
*
* Dashboard target:
*   Target remaining workload % =
*     MAX( 0, (estimated upgrade minutes - capacity minutes)
*             / estimated upgrade minutes * 100 )
*
* Thus 0% is the best possible target; 100% means no remediation
* capacity is available. The gauge deliberately runs from green (0%)
* to red (120%) in the style of the supplied Clean Core Control graphic.
*
* Population:
*   - all non-SAP R3TR objects from TADIR
*   - all active modifications from SMODILOG
*   - SAP Note corrections excluded
*   - duplicates normalized/merged on R3TR level
*
* Compatibility:
*   - no += operator
*   - no S/4 release-info structures/tables
*---------------------------------------------------------------------*

TABLES: tadir.

PARAMETERS:
  p_fte   TYPE p LENGTH 5 DECIMALS 1 DEFAULT '2.0' OBLIGATORY,
  p_days  TYPE i DEFAULT 20 OBLIGATORY,
  p_buffr TYPE boole_d DEFAULT abap_true.

SELECT-OPTIONS:
  s_devcls FOR tadir-devclass.

DATA:
  gt_objects          TYPE /s4p0/tt_ccc_object,
  gv_note_excluded    TYPE i,
  gv_unresolved       TYPE i,
  gv_metric_errors    TYPE i,
  gv_risk_objects     TYPE i,
  gv_clone_objects    TYPE i,
  gv_tmp_objects      TYPE i,
  gv_mod_objects      TYPE i,
  gv_customer_objects TYPE i,
  gv_effort_min       TYPE i,
  gv_effort_low       TYPE i,
  gv_effort_high      TYPE i.

INITIALIZATION.
  /s4p0/cl_enh_utils=>show_prototype_indication( ).

AT SELECTION-SCREEN.
  IF p_fte <= 0.
    MESSAGE 'FTE must be greater than zero' TYPE 'E'.
  ENDIF.
  IF p_days <= 0.
    MESSAGE 'Available upgrade days must be greater than zero' TYPE 'E'.
  ENDIF.

START-OF-SELECTION.

START-OF-SELECTION.

  IF /s4p0/cl_enh_core=>get_instance(
    iv_enhancement     = /s4p0/if_enh_constants=>gc_enh_ccc
    iv_sub_enhancement = /s4p0/if_enh_constants=>gc_sub_enh_ccc_base )->is_enhancement_active( ) = abap_false.
    MESSAGE 'Product is not active.' TYPE 'E'.
    RETURN.
  ENDIF.

  /s4p0/cl_enh_utils=>show_prototype_indication( ).

  " Layer 1 builds the population. The dashboard always scores the whole
  " non-SAP repository plus all active modifications.
  /s4p0/cl_ccc_extract=>build_population(
    EXPORTING
      it_devclass_range = s_devcls[]
      iv_include_tadir  = abap_true
      iv_include_mods   = abap_true
      iv_exclude_notes  = abap_true
    IMPORTING
      et_objects        = gt_objects
      ev_note_excluded  = gv_note_excluded
      ev_unresolved     = gv_unresolved ).

  IF gt_objects IS INITIAL.
    MESSAGE 'No repository objects found for the upgrade scope' TYPE 'S'.
    RETURN.
  ENDIF.

  PERFORM execute_metrics.
  PERFORM display_dashboard.

*&---------------------------------------------------------------------*
*& Determine and weight the metrics, accumulating the dashboard KPIs.
*&---------------------------------------------------------------------*
FORM execute_metrics.
  DATA:
    ls_object     TYPE /s4p0/s_ccc_object,
    ls_result     TYPE /s4p0/cl_ccc_metrics=>ty_result,
    ls_metrics    TYPE /s4p0/s_ccc_metrics,
    ls_evaluation TYPE /s4p0/s_ccc_evaluation,
    lv_total      TYPE i,
    lv_current    TYPE i,
    lx_root       TYPE REF TO cx_root.

  " Use buffer
  IF p_buffr = abap_true.
    DATA(lo_metrics_db) = /s4p0/cl_ccc_metrics_db=>get_instance(
      EXPORTING
        iv_usage_mode = /s4p0/cl_ccc_metrics_db=>gc_usage_mode_use_existing_run ).
    /s4p0/cl_ccc_metrics=>activate_metrics_persistence(
      EXPORTING io_metrics_db = lo_metrics_db ).
  ELSE.
    lo_metrics_db = /s4p0/cl_ccc_metrics_db=>get_instance(
      EXPORTING
        iv_usage_mode = /s4p0/cl_ccc_metrics_db=>gc_usage_mode_on_the_fly ).
  ENDIF.

  DESCRIBE TABLE gt_objects LINES lv_total.

  CLEAR: gv_metric_errors,
         gv_risk_objects,
         gv_clone_objects,
         gv_tmp_objects,
         gv_mod_objects,
         gv_customer_objects,
         gv_effort_min,
         gv_effort_low,
         gv_effort_high.

  LOOP AT gt_objects INTO ls_object.

    ADD 1 TO lv_current.
    /s4p0/cl_ccc_metrics=>progress_indicator(
      iv_current = lv_current
      iv_total   = lv_total
      iv_text    = 'Estimating upgrade adjustment effort' ).

    IF ls_object-from_tadir = abap_true.
      ADD 1 TO gv_customer_objects.
    ENDIF.
    IF ls_object-from_modification = abap_true.
      ADD 1 TO gv_mod_objects.
    ENDIF.

    TRY.
        ls_result = /s4p0/cl_ccc_metrics=>determine(
          iv_pgmid    = ls_object-pgmid
          iv_object   = ls_object-object
          iv_obj_name = CONV #( ls_object-obj_name ) ).

        ls_metrics = ls_result-metrics.
        ls_evaluation = ls_result-evaluation.

        "Use the dashboard population's SAP-Note-excluded modification count.
        ls_metrics-modification_count = ls_object-modification_logs.
        ls_metrics-modifications      = ls_object-modification_logs.
        IF ls_object-modification_logs > 0.
          ls_metrics-modification_detected = abap_true.
        ELSE.
          CLEAR ls_metrics-modification_detected.
        ENDIF.

        ls_evaluation = /s4p0/cl_ccc_weight=>evaluate_object( ls_metrics ).

        ADD ls_evaluation-estim_effort_minutes TO gv_effort_min.
        ADD ls_evaluation-estim_effort_low_minutes TO gv_effort_low.
        ADD ls_evaluation-estim_effort_high_minutes TO gv_effort_high.

        IF ls_evaluation-estim_effort_minutes > 0.
          ADD 1 TO gv_risk_objects.
        ENDIF.
        IF ls_metrics-copied_sap_standard_detected = abap_true.
          ADD 1 TO gv_clone_objects.
        ENDIF.
        IF ls_metrics-tmp_object = abap_true.
          ADD 1 TO gv_tmp_objects.
        ENDIF.

      CATCH cx_root INTO lx_root.
        ADD 1 TO gv_metric_errors.
    ENDTRY.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Render the quick-indication dashboard as HTML.
*&---------------------------------------------------------------------*
FORM display_dashboard.
  DATA:
    lv_html              TYPE string,
    lv_line              TYPE string,
    lv_title             TYPE cl_abap_browser=>title,
    lv_total_objects     TYPE i,
    lv_capacity_min      TYPE p LENGTH 16 DECIMALS 1,
    lv_capacity_hours    TYPE p LENGTH 16 DECIMALS 1,
    lv_effort_hours      TYPE p LENGTH 16 DECIMALS 1,
    lv_remaining_min     TYPE p LENGTH 16 DECIMALS 1,
    lv_remaining_hours   TYPE p LENGTH 16 DECIMALS 1,
    lv_coverage_pct      TYPE p LENGTH 8 DECIMALS 1,
    lv_target_pct        TYPE p LENGTH 8 DECIMALS 1,
    lv_target_left       TYPE p LENGTH 8 DECIMALS 1,
    lv_current_left      TYPE p LENGTH 8 DECIMALS 1,
    lv_grade             TYPE c LENGTH 1,
    lv_grade_color       TYPE string,
    lv_grade_text        TYPE /s4p0/de_ccc_grade_text,
    lv_status_text       TYPE string,
    lv_fte_text          TYPE string,
    lv_days_text         TYPE string,
    lv_total_text        TYPE string,
    lv_risk_text         TYPE string,
    lv_effort_text       TYPE string,
    lv_effort_h_text     TYPE string,
    lv_capacity_text     TYPE string,
    lv_capacity_h_text   TYPE string,
    lv_remaining_text    TYPE string,
    lv_remaining_h_text  TYPE string,
    lv_target_text       TYPE string,
    lv_coverage_text     TYPE string,
    lv_target_left_text  TYPE string,
    lv_current_left_text TYPE string,
    lv_low_text          TYPE string,
    lv_high_text         TYPE string,
    lv_mod_text          TYPE string,
    lv_tmp_text          TYPE string,
    lv_clone_text        TYPE string,
    lv_error_text        TYPE string,
    lv_line_c            TYPE char255,
    " Typed to the weighting layer's parameters. ABAP converts on
    " assignment but requires compatibility when passing parameters.
    lv_capacity_i        TYPE i,
    lv_target_pct_dec    TYPE /s4p0/de_ccc_target_pct.

  DESCRIBE TABLE gt_objects LINES lv_total_objects.

  lv_capacity_i = /s4p0/cl_ccc_weight=>calculate_capacity(
    iv_fte  = p_fte
    iv_days = p_days ).
  lv_capacity_min = lv_capacity_i.
  lv_capacity_hours = lv_capacity_min / 60.
  lv_effort_hours = gv_effort_min / 60.

  "Upgrade load / aiming point. 100% means exact capacity match.
  "Unlike remaining-work %, this ratio can exceed 100/120%.
  lv_coverage_pct = /s4p0/cl_ccc_weight=>calculate_coverage_pct(
    iv_effort_minutes   = gv_effort_min
    iv_capacity_minutes = lv_capacity_i ).
  lv_target_pct = /s4p0/cl_ccc_weight=>calculate_target_pct(
    iv_effort_minutes   = gv_effort_min
    iv_capacity_minutes = lv_capacity_i ).

  IF gv_effort_min > 0.
    lv_remaining_min = gv_effort_min - lv_capacity_min.
    IF lv_remaining_min < 0.
      lv_remaining_min = 0.
    ENDIF.
    lv_remaining_hours = lv_remaining_min / 60.
  ELSE.
    lv_remaining_min = 0.
    lv_remaining_hours = 0.
  ENDIF.

  "Gauge has a 0..120% visual scale. Grade G (>120%) is pinned at the
  "right edge while the actual percentage is still shown numerically.
  IF lv_target_pct > 120.
    lv_target_left = '98.5'.
  ELSE.
    lv_target_left = lv_target_pct * 100 / 120.
  ENDIF.
  lv_current_left = 100 * 100 / 120.

  "Prevent the circular marker from being clipped at the exact left edge.
  IF lv_target_left < '1.5'.
    lv_target_left = '1.5'.
  ENDIF.

  lv_target_pct_dec = lv_target_pct.
  /s4p0/cl_ccc_weight=>determine_grade(
    EXPORTING iv_target_pct  = lv_target_pct_dec
    IMPORTING ev_grade       = lv_grade
              ev_grade_text  = lv_grade_text
              ev_grade_color = lv_grade_color ).

  IF gv_effort_min = 0.
    lv_status_text = 'No upgrade adjustment effort detected by the metric model'.
  ELSEIF lv_target_pct = 0.
    lv_status_text = 'Planned capacity covers the complete estimated upgrade effort'.
  ELSE.
    lv_status_text = 'Aiming point after applying the planned upgrade capacity'.
  ENDIF.

  DATA lv_text_c TYPE char255.

  WRITE p_fte TO lv_text_c DECIMALS 1.
  lv_fte_text = lv_text_c.
  WRITE p_days TO lv_text_c.
  lv_days_text = lv_text_c.
  WRITE lv_total_objects TO lv_text_c.
  lv_total_text = lv_text_c.
  WRITE gv_risk_objects TO lv_text_c .
  lv_risk_text = lv_text_c.
  WRITE gv_effort_min TO lv_text_c .
  lv_effort_text = lv_text_c.
  WRITE lv_effort_hours TO lv_text_c DECIMALS 1 .
  lv_effort_h_text = lv_text_c.
  WRITE lv_capacity_min TO lv_text_c DECIMALS 0 .
  lv_capacity_text = lv_text_c.
  WRITE lv_capacity_hours TO lv_text_c DECIMALS 1 .
  lv_capacity_h_text = lv_text_c.
  WRITE lv_remaining_min TO lv_text_c DECIMALS 0 .
  lv_remaining_text = lv_text_c.
  WRITE lv_remaining_hours TO lv_text_c DECIMALS 1 .
  lv_remaining_h_text = lv_text_c.
  WRITE lv_target_pct TO lv_text_c DECIMALS 0 .
  lv_target_text = lv_text_c.
  WRITE lv_coverage_pct TO lv_text_c DECIMALS 0 .
  lv_coverage_text = lv_text_c.
  WRITE lv_target_left TO lv_text_c DECIMALS 1 .
  lv_target_left_text = lv_text_c.
  WRITE lv_current_left TO lv_text_c DECIMALS 1 .
  lv_current_left_text = lv_text_c.
  WRITE gv_effort_low TO lv_text_c .
  lv_low_text = lv_text_c.
  WRITE gv_effort_high TO lv_text_c .
  lv_high_text = lv_text_c.
  WRITE gv_mod_objects TO lv_text_c .
  lv_mod_text = lv_text_c.
  WRITE gv_tmp_objects TO lv_text_c .
  lv_tmp_text = lv_text_c.
  WRITE gv_clone_objects TO lv_text_c .
  lv_clone_text = lv_text_c.
  WRITE gv_metric_errors TO lv_text_c .
  lv_error_text = lv_text_c.

  "CSS requires a dot as decimal separator regardless of user locale.
  REPLACE ALL OCCURRENCES OF ',' IN lv_target_left_text WITH '.'.
  REPLACE ALL OCCURRENCES OF ',' IN lv_current_left_text WITH '.'.

  lv_html = lv_html && '<!DOCTYPE html><html><head><meta http-equiv="X-UA-Compatible" content="IE=edge" />'.
  lv_html = lv_html && '<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />'.
  lv_html = lv_html && '<style type="text/css">'.
  lv_html = lv_html && 'body{font-family:Arial,Helvetica,sans-serif;background:#ffffff;color:#20244f;margin:0;padding:18px 24px 26px 24px;}'.
  lv_html = lv_html && '.title{font-family:Georgia,Times New Roman,serif;font-size:28px;color:#171a45;margin:0 0 48px 0;}'.
  lv_html = lv_html && '.hero{display:table;width:100%;margin-bottom:44px;}.badgecell{display:table-cell;width:170px;vertical-align:middle;}'.
  lv_html = lv_html && '.badge{width:142px;height:142px;border-radius:24px;text-align:center;line-height:142px;font-family:Georgia,serif;font-size:72px;font-weight:bold;color:#20204e;}'.
  lv_html = lv_html && '.scorecell{display:table-cell;vertical-align:middle;padding-left:10px;}.score{font-family:Georgia,serif;font-size:58px;font-weight:bold;color:#181a48;line-height:1;}'.
  lv_html = lv_html && '.subtitle{font-size:20px;color:#35406e;margin-top:18px;}.status{font-size:13px;color:#6b6f8d;margin-top:8px;}'.
  lv_html = lv_html && '.gaugewrap{position:relative;margin-top:6px;margin-bottom:8px;height:58px;}.bar{position:absolute;left:0;right:0;top:14px;height:18px;border-radius:12px;background:#26a64a;'.
  lv_html = lv_html && 'background:-webkit-linear-gradient(left,#20a14a 0%,#76c431 28%,#d8dc20 48%,#ffbe26 70%,#df342f 100%);background:linear-gradient(to right,#20a14a 0%,#76c431 28%,#d8dc20 48%,#ffbe26 70%,#df342f 100%);}'.
  lv_html = lv_html && '.marker{position:absolute;top:5px;width:28px;height:28px;border-radius:50%;margin-left:-14px;box-sizing:border-box;}.current{background:#20244f;border:4px solid white;box-shadow:0 0 0 1px #c9cad5;}'.
  lv_html = lv_html && '.target{background:rgba(120,150,120,.55);border:3px dashed #c4ccd0;width:36px;height:36px;top:1px;margin-left:-18px;}.scale{position:relative;height:24px;font-size:13px;color:#6c7196;}'.
  lv_html = lv_html && '.scale span{position:absolute;transform:translateX(-50%);}.scale .s0{left:0%;transform:none}.scale .s30{left:25%}.scale .s50{left:41.667%}.scale .s80{left:66.667%}.scale .s120{right:0;left:auto;transform:none}'.
  lv_html = lv_html && '.legend{margin-top:14px;font-size:16px;color:#394163;}.legenditem{display:inline-block;margin-right:30px;}.dot{display:inline-block;width:11px;height:11px;border-radius:50%;margin-right:10px;vertical-align:1px;}'.
  lv_html = lv_html && '.dot.currentdot{background:#20244f}.dot.targetdot{width:15px;height:15px;background:rgba(120,150,120,.55);border:2px dashed #c4ccd0;vertical-align:-2px;}'.
  lv_html = lv_html && '.cards{display:table;width:100%;margin-top:34px;border-spacing:10px 10px;table-layout:fixed;}.card{display:table-cell;border:1px solid #ececf2;border-radius:12px;padding:16px 18px;background:#fafafd;}'.
  lv_html = lv_html && '.cardlabel{font-size:12px;text-transform:uppercase;letter-spacing:.6px;color:#7a7e99;margin-bottom:7px}.cardvalue{font-size:22px;font-weight:bold;color:#20244f}.cardsub{font-size:12px;color:#777d96;margin-top:5px}'.
  lv_html = lv_html && '.foot{margin-top:24px;font-size:11px;color:#8a8da3;line-height:1.45}.warn{color:#a64b00;font-weight:bold}'.
  lv_html = lv_html && '</style></head><body>'.

  lv_html = lv_html && '<div class="title">Clean Core Control - Quick Indication</div>'.
  CONCATENATE '<div class="hero"><div class="badgecell"><div class="badge" style="background:' lv_grade_color ';">' lv_grade '</div></div>' INTO lv_line.
  lv_html = lv_html && lv_line.
  CONCATENATE '<div class="scorecell"><div class="score">' lv_target_text '%</div>' INTO lv_line.
  lv_html = lv_html && lv_line.
  CONCATENATE '<div class="subtitle">' lv_total_text ' repository objects in upgrade scope</div>' INTO lv_line.
  lv_html = lv_html && lv_line.
  CONCATENATE '<div class="status">' lv_status_text '</div></div></div>' INTO lv_line.
  lv_html = lv_html && lv_line.

  lv_html = lv_html && '<div class="gaugewrap"><div class="bar"></div>'.
  CONCATENATE '<div class="marker target" style="left:' lv_target_left_text '%"></div>' INTO lv_line.
  lv_html = lv_html && lv_line.
  CONCATENATE '<div class="marker current" style="left:' lv_current_left_text '%"></div></div>' INTO lv_line.
  lv_html = lv_html && lv_line.

  lv_html = lv_html && '<div class="scale"><span class="s0">0%</span><span class="s30">30%</span><span class="s50">50%</span><span class="s80">80%</span><span class="s120">120%</span></div>'.
  CONCATENATE '<div class="legend"><span class="legenditem"><span class="dot currentdot"></span>Capacity limit 100%</span><span class="legenditem"><span class="dot targetdot"></span>Aiming point ' lv_target_text '%</span></div>' INTO lv_line.
  lv_html = lv_html && lv_line.

  lv_html = lv_html && '<div class="cards">'.
  CONCATENATE '<div class="card"><div class="cardlabel">Estimated upgrade effort</div><div class="cardvalue">' lv_effort_text ' min</div><div class="cardsub">' lv_effort_h_text ' developer hours; model range ' lv_low_text ' - '
    lv_high_text ' min</div></div>' INTO lv_line.
  lv_html = lv_html && lv_line.
  CONCATENATE '<div class="card"><div class="cardlabel">Available capacity</div><div class="cardvalue">' lv_capacity_text ' min</div><div class="cardsub">' lv_fte_text ' FTE x ' lv_days_text ' days = '
    lv_capacity_h_text ' hours</div></div>' INTO lv_line.
  lv_html = lv_html && lv_line.
  CONCATENATE '<div class="card"><div class="cardlabel">Residual adjustment work</div><div class="cardvalue">' lv_remaining_text ' min</div><div class="cardsub">' lv_remaining_h_text ' hours remaining; capacity coverage '
    lv_coverage_text '%</div></div></div>' INTO lv_line.
  lv_html = lv_html && lv_line.

  lv_html = lv_html && '<div class="cards">'.
  CONCATENATE '<div class="card"><div class="cardlabel">Upgrade-relevant objects</div><div class="cardvalue">' lv_risk_text '</div><div class="cardsub">Objects with estimated adjustment effort &gt; 0</div></div>' INTO lv_line.
  lv_html = lv_html && lv_line.
  CONCATENATE '<div class="card"><div class="cardlabel">Special penalties</div><div class="cardvalue">' lv_mod_text ' modifications</div><div class="cardsub">' lv_tmp_text ' $TMP objects; '
    lv_clone_text ' probable SAP-standard copies</div></div>' INTO lv_line.
  lv_html = lv_html && lv_line.
  CONCATENATE '<div class="card"><div class="cardlabel">Scope quality</div><div class="cardvalue">' lv_error_text ' metric errors</div><div class="cardsub">' INTO lv_line.
  lv_html = lv_html && lv_line.
  WRITE gv_note_excluded TO lv_line_c.
  CONCATENATE lv_line_c ' SAP Note modification logs excluded; ' INTO lv_line.
  CONDENSE lv_line.

  lv_html = lv_html && lv_line.
  WRITE gv_unresolved TO lv_line_c.
  CONCATENATE lv_line_c ' modification logs could not be normalized</div></div></div>' INTO lv_line.
  CONDENSE lv_line.

  lv_html = lv_html && lv_line.

  lv_html = lv_html && '<div class="foot">The aiming point is a workload target to allow Clean Core Control, not an official SAP Clean Core Score. It expresses the percentage of ' &&
    ' the currently estimated upgrade-adjustment effort that remains after the entered FTE capacity is consumed. Grade thresholds: A &le;10%, B &le;25%, C &le;50%, D &le;75%, E &gt;75% remaining effort.</div>'.
  lv_html = lv_html && '</body></html>'.

  lv_title = 'Clean Core Upgrade Target'.

  CALL METHOD cl_abap_browser=>show_html
    EXPORTING
      html_string = lv_html
      title       = lv_title
      size        = cl_abap_browser=>large
      format      = cl_abap_browser=>landscape.
ENDFORM.
