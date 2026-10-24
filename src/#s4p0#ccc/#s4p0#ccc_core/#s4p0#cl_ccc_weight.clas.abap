*---------------------------------------------------------------------*
* /S4P0/CL_CCC_WEIGHT
*
* Clean Core Control - layer 3: weighting.
*
* Turns measured metrics (layer 2) into an effort estimate and a grade.
* This layer performs no database access and no measurement of its own;
* it only weights values that layer 2 has already determined.
*
* Two models live here:
*   1. The per-object upgrade effort model (ECC_V1). Its weights are
*      centralized as constants so they can be calibrated against measured
*      upgrade projects later.
*   2. The capacity/grade model used by the upgrade dashboard: planned
*      capacity in minutes, the resulting aiming point in percent, and the
*      A..G readiness grade derived from it.
*---------------------------------------------------------------------*
class /S4P0/CL_CCC_WEIGHT definition
  public
  final
  create public .

public section.

  constants C_EFFORT_MODEL type /S4P0/DE_CCC_EFF_MODEL value 'ECC_V1' ##NO_TEXT.

  " Capacity model: one available developer day equals eight hours.
  constants C_MINUTES_PER_DAY type I value 480 ##NO_TEXT.
  " The dashboard gauge has a fixed 0..120% visual scale.
  constants C_GAUGE_MAX_PCT type I value 120 ##NO_TEXT.
  " Returned when effort exists but no capacity was planned at all.
  constants C_TARGET_PCT_NO_CAPACITY type I value 999 ##NO_TEXT.

  constants C_GRADE_A type /S4P0/DE_CCC_GRADE value 'A' ##NO_TEXT.
  constants C_GRADE_B type /S4P0/DE_CCC_GRADE value 'B' ##NO_TEXT.
  constants C_GRADE_C type /S4P0/DE_CCC_GRADE value 'C' ##NO_TEXT.
  constants C_GRADE_D type /S4P0/DE_CCC_GRADE value 'D' ##NO_TEXT.
  constants C_GRADE_E type /S4P0/DE_CCC_GRADE value 'E' ##NO_TEXT.
  constants C_GRADE_F type /S4P0/DE_CCC_GRADE value 'F' ##NO_TEXT.
  constants C_GRADE_G type /S4P0/DE_CCC_GRADE value 'G' ##NO_TEXT.

    " Weight one measured object into an upgrade effort estimate.
  class-methods EVALUATE_OBJECT
    importing
      !IS_METRICS type /S4P0/S_CCC_METRICS
    returning
      value(RS_EVALUATION) type /S4P0/S_CCC_EVALUATION .
    " Planned capacity in developer minutes for the given FTE and days.
  class-methods CALCULATE_CAPACITY
    importing
      !IV_FTE type P
      value(IV_DAYS) type I
    returning
      value(RV_MINUTES) type I .
    " Aiming point: estimated effort as a percentage of planned capacity.
    " 100% means an exact match. The value may exceed 100%.
  class-methods CALCULATE_TARGET_PCT
    importing
      value(IV_EFFORT_MINUTES) type I
      value(IV_CAPACITY_MINUTES) type I
    returning
      value(RV_TARGET_PCT) type /S4P0/DE_CCC_TARGET_PCT .
    " Share of the estimated effort that the planned capacity covers.
  class-methods CALCULATE_COVERAGE_PCT
    importing
      value(IV_EFFORT_MINUTES) type I
      value(IV_CAPACITY_MINUTES) type I
    returning
      value(RV_COVERAGE_PCT) type /S4P0/DE_CCC_TARGET_PCT .
    " A..G readiness grade for an aiming point in percent.
  class-methods DETERMINE_GRADE
    importing
      value(IV_TARGET_PCT) type /S4P0/DE_CCC_TARGET_PCT
    exporting
      !EV_GRADE type /S4P0/DE_CCC_GRADE
      !EV_GRADE_TEXT type /S4P0/DE_CCC_GRADE_TEXT
      !EV_GRADE_COLOR type STRING .

protected section.
private section.

  " Upgrade-effort model ECC_V1. These weights are deliberately centralized
  " for later calibration against measured upgrade effort.
  "
  " Factor                                      Estimated effort
  " Clean object without relevant findings       0 min
  " Base handling if findings exist              5 min
  " Unsupported/non-source object with findings  15 min
  " Size                                         1 min / 100 statements, max 30
  " Level B / classic APIs                       1 min / 4 dependencies
  " Level C / internal SAP dependency            5 min each
  " Level D / noAPI dependency                   15 min each
  " Direct SAP table read                        +2 min each, max 40
  " Direct SAP table write                       +10 min each, max 90
  " Implicit enhancement                         +45 min each
  " Unreleased extension point                   +15 min each
  " Blast radius                                 +1 min/add. consumer, max 30
  " Copied SAP Standard                          +90 min + 1 min/20 stmt, max 300
  " Modification                                 +30 min + 90 min per modification
  " $TMP object                                  +30 min
  constants C_EFF_BASE_MIN type I value 5 ##NO_TEXT.
  constants C_EFF_UNKNOWN_BASE_MIN type I value 15 ##NO_TEXT.
  constants C_EFF_STMT_BLOCK type I value 100 ##NO_TEXT.
  constants C_EFF_STMT_BLOCK_MIN type I value 1 ##NO_TEXT.
  constants C_EFF_SIZE_CAP_MIN type I value 30 ##NO_TEXT.
  constants C_EFF_LEVEL_B_GROUP type I value 4 ##NO_TEXT.
  constants C_EFF_LEVEL_C_MIN type I value 5 ##NO_TEXT.
  constants C_EFF_LEVEL_D_MIN type I value 15 ##NO_TEXT.
  constants C_EFF_DEPRECATED_MIN type I value 10 ##NO_TEXT.
  constants C_EFF_DB_READ_MIN type I value 2 ##NO_TEXT.
  constants C_EFF_DB_READ_CAP_MIN type I value 40 ##NO_TEXT.
  constants C_EFF_DB_WRITE_MIN type I value 10 ##NO_TEXT.
  constants C_EFF_DB_WRITE_CAP_MIN type I value 90 ##NO_TEXT.
  constants C_EFF_IMPLICIT_ENH_MIN type I value 45 ##NO_TEXT.
  constants C_EFF_UNREL_EXT_MIN type I value 15 ##NO_TEXT.
  constants C_EFF_BLAST_CONSUMER_MIN type I value 1 ##NO_TEXT.
  constants C_EFF_BLAST_CAP_MIN type I value 30 ##NO_TEXT.
  constants C_EFF_COPY_BASE_MIN type I value 90 ##NO_TEXT.
  constants C_EFF_COPY_STMT_DIVISOR type I value 20 ##NO_TEXT.
  constants C_EFF_COPY_CAP_MIN type I value 300 ##NO_TEXT.
  constants C_EFF_MOD_BASE_MIN type I value 30 ##NO_TEXT.
  constants C_EFF_MOD_EACH_MIN type I value 90 ##NO_TEXT.
  constants C_EFF_TMP_PENALTY_MIN type I value 30 ##NO_TEXT.

  " Spread of the low/high bounds around the estimate, in percent.
  constants C_SPREAD_LOW_PCT type I value 70 ##NO_TEXT.
  constants C_SPREAD_HIGH_PCT type I value 150 ##NO_TEXT.
  " Widened spread once a clone or a modification was detected.
  constants C_SPREAD_WIDE_LOW_PCT type I value 60 ##NO_TEXT.
  constants C_SPREAD_WIDE_HIGH_PCT type I value 180 ##NO_TEXT.
  constants C_SPREAD_MIN_LOW type I value 5 ##NO_TEXT.
  constants C_SPREAD_MIN_DELTA type I value 10 ##NO_TEXT.

  " Upper bounds of the effort classes, in minutes.
  constants C_CLASS_LOW_MAX type I value 15 ##NO_TEXT.
  constants C_CLASS_MEDIUM_MAX type I value 60 ##NO_TEXT.
  constants C_CLASS_HIGH_MAX type I value 180 ##NO_TEXT.

  " Upper bounds of the readiness grades, in percent of capacity.
  constants C_GRADE_A_MAX_PCT type I value 10 ##NO_TEXT.
  constants C_GRADE_B_MAX_PCT type I value 30 ##NO_TEXT.
  constants C_GRADE_C_MAX_PCT type I value 50 ##NO_TEXT.
  constants C_GRADE_D_MAX_PCT type I value 80 ##NO_TEXT.
  constants C_GRADE_E_MAX_PCT type I value 100 ##NO_TEXT.
  constants C_GRADE_F_MAX_PCT type I value 120 ##NO_TEXT.

    " Findings that justify generic base and size effort for an object.
  class-methods COUNT_RISK_FINDINGS
    importing
      !IS_METRICS type /S4P0/S_CCC_METRICS
    returning
      value(RV_FINDINGS) type I .
ENDCLASS.



CLASS /S4P0/CL_CCC_WEIGHT IMPLEMENTATION.


METHOD calculate_capacity.

  rv_minutes = iv_fte * iv_days * c_minutes_per_day.

ENDMETHOD.


METHOD calculate_coverage_pct.

  " With no effort to cover, the planned capacity trivially covers everything.
  IF iv_effort_minutes <= 0.
    rv_coverage_pct = 100.
    RETURN.
  ENDIF.

  rv_coverage_pct = iv_capacity_minutes * 100 / iv_effort_minutes.

ENDMETHOD.


METHOD calculate_target_pct.

  IF iv_effort_minutes <= 0.
    rv_target_pct = 0.
    RETURN.
  ENDIF.

  " Without any planned capacity the aiming point is undefined; a fixed
  " sentinel keeps the gauge usable instead of dividing by zero.
  IF iv_capacity_minutes > 0.
    rv_target_pct = iv_effort_minutes * 100 / iv_capacity_minutes.
  ELSE.
    rv_target_pct = c_target_pct_no_capacity.
  ENDIF.

ENDMETHOD.


METHOD count_risk_findings.

  rv_findings = is_metrics-level_b.

  IF is_metrics-generated_source = abap_true.
    ADD is_metrics-level_c TO rv_findings.
    ADD is_metrics-level_d TO rv_findings.
    ADD is_metrics-deprecated_api_usage TO rv_findings.
  ELSE.
    ADD is_metrics-level_c TO rv_findings.
    ADD is_metrics-level_d TO rv_findings.
    ADD is_metrics-deprecated_api_usage TO rv_findings.
    ADD is_metrics-direct_sap_table_reads TO rv_findings.
    ADD is_metrics-direct_sap_table_writes TO rv_findings.
    ADD is_metrics-implicit_enhancements TO rv_findings.
    ADD is_metrics-unreleased_extension_points TO rv_findings.
    ADD is_metrics-modification_count TO rv_findings.
    ADD is_metrics-copied_sap_standard TO rv_findings.
  ENDIF.

ENDMETHOD.


METHOD determine_grade.

  CLEAR: ev_grade, ev_grade_text, ev_grade_color.

  IF iv_target_pct <= c_grade_a_max_pct.
    ev_grade = c_grade_a.
    ev_grade_color = '#1fa64a'.
    ev_grade_text = 'Exemplary'.
  ELSEIF iv_target_pct <= c_grade_b_max_pct.
    ev_grade = c_grade_b.
    ev_grade_color = '#4bb33a'.
    ev_grade_text = 'Very good'.
  ELSEIF iv_target_pct <= c_grade_c_max_pct.
    ev_grade = c_grade_c.
    ev_grade_color = '#a8cf2a'.
    ev_grade_text = 'Solid'.
  ELSEIF iv_target_pct <= c_grade_d_max_pct.
    ev_grade = c_grade_d.
    ev_grade_color = '#f2d126'.
    ev_grade_text = 'Acceptable'.
  ELSEIF iv_target_pct <= c_grade_e_max_pct.
    ev_grade = c_grade_e.
    ev_grade_color = '#f7a51a'.
    ev_grade_text = 'Critical'.
  ELSEIF iv_target_pct <= c_grade_f_max_pct.
    ev_grade = c_grade_f.
    ev_grade_color = '#f0521f'.
    ev_grade_text = 'Severe'.
  ELSE.
    ev_grade = c_grade_g.
    ev_grade_color = '#dc2e2e'.
    ev_grade_text = 'Unacceptable'.
  ENDIF.

ENDMETHOD.


METHOD evaluate_object.

  DATA lv_total TYPE i.
  DATA lv_size_basis TYPE i.
  DATA lv_copy_variable TYPE i.
  DATA lv_mod_variable TYPE i.
  DATA lv_write_effort TYPE i.
  DATA lv_risk_findings TYPE i.
  DATA lv_low_pct TYPE i.
  DATA lv_high_pct TYPE i.

  lv_low_pct = c_spread_low_pct.
  lv_high_pct = c_spread_high_pct.

  rs_evaluation-estim_effort_model = c_effort_model.

  " Only objects with upgrade-relevant findings receive generic base/size
  " effort. This is essential for system-wide estimates: a clean custom object
  " should not create manual effort merely because it exists in TADIR.
  lv_risk_findings = count_risk_findings( is_metrics ).

  IF lv_risk_findings > 0.
    " Base handling/retest effort. Unsupported source object types get a larger
    " base because LOC/statements cannot be used to size the correction work.
    IF is_metrics-source_scan_supported = abap_true.
      rs_evaluation-estim_effort_base_min = c_eff_base_min.
    ELSE.
      rs_evaluation-estim_effort_base_min = c_eff_unknown_base_min.
    ENDIF.

    " Size component. Prefer statements; use LOC as fallback. One minute per
    " 100 statements, capped so size does not dominate architectural risk.
    lv_size_basis = is_metrics-statement_count.
    IF lv_size_basis = 0.
      lv_size_basis = is_metrics-code_lines.
    ENDIF.
    IF lv_size_basis > 0.
      rs_evaluation-estim_effort_size_min =
        ( ( lv_size_basis + c_eff_stmt_block - 1 ) DIV c_eff_stmt_block )
        * c_eff_stmt_block_min.
      IF rs_evaluation-estim_effort_size_min > c_eff_size_cap_min.
        rs_evaluation-estim_effort_size_min = c_eff_size_cap_min.
      ENDIF.
    ENDIF.
  ENDIF.

  " API/dependency risk. Classic APIs are intentionally almost neutral in an
  " ECC upgrade: one review minute per four Level-B dependencies. Internal and
  " noAPI dependencies get progressively higher probable correction effort.
  IF is_metrics-level_b > 0.
    rs_evaluation-estim_effort_api_min =
      ( is_metrics-level_b + c_eff_level_b_group - 1 ) DIV c_eff_level_b_group.
  ENDIF.
  lv_mod_variable = is_metrics-level_c * c_eff_level_c_min.
  ADD lv_mod_variable TO rs_evaluation-estim_effort_api_min.
  lv_mod_variable = is_metrics-level_d * c_eff_level_d_min.
  ADD lv_mod_variable TO rs_evaluation-estim_effort_api_min.
  lv_mod_variable = is_metrics-deprecated_api_usage * c_eff_deprecated_min.
  ADD lv_mod_variable TO rs_evaluation-estim_effort_api_min.

  " Direct DB access gets an additional correction/test premium because table
  " semantics and writes are especially sensitive to release changes.
  rs_evaluation-estim_effort_db_min =
      is_metrics-direct_sap_table_reads * c_eff_db_read_min.
  IF rs_evaluation-estim_effort_db_min > c_eff_db_read_cap_min.
    rs_evaluation-estim_effort_db_min = c_eff_db_read_cap_min.
  ENDIF.
  lv_write_effort = is_metrics-direct_sap_table_writes * c_eff_db_write_min.
  IF lv_write_effort > c_eff_db_write_cap_min.
    lv_write_effort = c_eff_db_write_cap_min.
  ENDIF.
  ADD lv_write_effort TO rs_evaluation-estim_effort_db_min.

  " Enhancements usually require explicit retrofit/verification after upgrade.
  rs_evaluation-estim_effort_enhancement_min =
      is_metrics-implicit_enhancements * c_eff_implicit_enh_min
    + is_metrics-unreleased_extension_points * c_eff_unrel_ext_min.

  " Blast radius is a coordination/regression-test premium, capped because the
  " same shared dependency should not be fully charged to every consumer.
  IF is_metrics-max_dependency_blast_radius > 1.
    rs_evaluation-estim_effort_blast_min =
      ( is_metrics-max_dependency_blast_radius - 1 )
      * c_eff_blast_consumer_min.
    IF rs_evaluation-estim_effort_blast_min > c_eff_blast_cap_min.
      rs_evaluation-estim_effort_blast_min = c_eff_blast_cap_min.
    ENDIF.
  ENDIF.

  " Copied SAP standard is penalized because the new SAP original must be
  " compared/merged and the custom clone regression-tested. The variable part
  " scales with object size but is capped.
  IF is_metrics-copied_sap_standard_detected = abap_true.
    lv_copy_variable = is_metrics-statement_count DIV c_eff_copy_stmt_divisor.
    rs_evaluation-estim_effort_cpy_penalty_min =
      c_eff_copy_base_min + lv_copy_variable.
    IF rs_evaluation-estim_effort_cpy_penalty_min > c_eff_copy_cap_min.
      rs_evaluation-estim_effort_cpy_penalty_min = c_eff_copy_cap_min.
    ENDIF.
    lv_low_pct = c_spread_wide_low_pct.
    lv_high_pct = c_spread_wide_high_pct.
  ENDIF.

  " Explicit modification penalty. One modification starts at 120 minutes
  " (30 minute SPAU/impact overhead + 90 minutes per active location).
  IF is_metrics-modification_count > 0.
    rs_evaluation-estim_effort_mod_penalty_min = c_eff_mod_base_min.
    lv_mod_variable = is_metrics-modification_count * c_eff_mod_each_min.
    ADD lv_mod_variable TO rs_evaluation-estim_effort_mod_penalty_min.
    lv_low_pct = c_spread_wide_low_pct.
    lv_high_pct = c_spread_wide_high_pct.
  ENDIF.

  " $TMP is deliberately penalized: local objects first need ownership/package
  " clarification and often package/transport cleanup before controlled retrofit.
  IF is_metrics-tmp_object = abap_true.
    rs_evaluation-estim_effort_tmp_penalty_min = c_eff_tmp_penalty_min.
  ENDIF.

  lv_total = rs_evaluation-estim_effort_base_min.
  ADD rs_evaluation-estim_effort_size_min TO lv_total.
  ADD rs_evaluation-estim_effort_api_min TO lv_total.
  ADD rs_evaluation-estim_effort_db_min TO lv_total.
  ADD rs_evaluation-estim_effort_enhancement_min TO lv_total.
  ADD rs_evaluation-estim_effort_blast_min TO lv_total.
  ADD rs_evaluation-estim_effort_cpy_penalty_min TO lv_total.
  ADD rs_evaluation-estim_effort_mod_penalty_min TO lv_total.
  ADD rs_evaluation-estim_effort_tmp_penalty_min TO lv_total.

  " reduce penalty for generated source
  IF is_metrics-generated_source = abap_true.
    lv_total = lv_total DIV 15.
  ENDIF.

  rs_evaluation-estim_effort_minutes = lv_total.
  IF lv_total = 0.
    rs_evaluation-estim_effort_low_minutes = 0.
    rs_evaluation-estim_effort_high_minutes = 0.
    rs_evaluation-estim_effort_class = 'NONE'.
  ELSE.
    rs_evaluation-estim_effort_low_minutes = lv_total * lv_low_pct DIV 100.
    rs_evaluation-estim_effort_high_minutes = lv_total * lv_high_pct DIV 100.
    IF rs_evaluation-estim_effort_low_minutes < c_spread_min_low.
      rs_evaluation-estim_effort_low_minutes = c_spread_min_low.
    ENDIF.
    IF rs_evaluation-estim_effort_high_minutes <= lv_total.
      rs_evaluation-estim_effort_high_minutes = lv_total + c_spread_min_delta.
    ENDIF.

    IF lv_total <= c_class_low_max.
      rs_evaluation-estim_effort_class = 'LOW'.
    ELSEIF lv_total <= c_class_medium_max.
      rs_evaluation-estim_effort_class = 'MEDIUM'.
    ELSEIF lv_total <= c_class_high_max.
      rs_evaluation-estim_effort_class = 'HIGH'.
    ELSE.
      rs_evaluation-estim_effort_class = 'VERY_HIGH'.
    ENDIF.
  ENDIF.

  " Until the model is calibrated with actual upgrade work, MEDIUM is the
  " highest confidence claimed. Missing source/catalog data lowers it to LOW.
  IF is_metrics-source_scan_supported = abap_true AND
     is_metrics-classification_loaded = abap_true.
    rs_evaluation-estim_effort_confidence = 'MEDIUM'.
  ELSE.
    rs_evaluation-estim_effort_confidence = 'LOW'.
  ENDIF.

ENDMETHOD.
ENDCLASS.
