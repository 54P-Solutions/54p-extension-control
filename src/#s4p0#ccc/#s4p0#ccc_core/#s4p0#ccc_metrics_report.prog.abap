*---------------------------------------------------------------------*
* /S4P0/CCC_METRICS_REPORT
*
* ECC/classic ABAP presentation layer for /S4P0/CL_CCC_METRICS.
* All metric determination is encapsulated in the global class.
*---------------------------------------------------------------------*
REPORT /s4p0/ccc_metrics_report.

PARAMETERS:
  p_pgmid TYPE e071-pgmid    DEFAULT 'R3TR' OBLIGATORY,
  p_obj   TYPE e071-object              OBLIGATORY,
  p_name  TYPE e071-obj_name            OBLIGATORY.

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

  DATA(ls_result) = /s4p0/cl_ccc_metrics=>determine(
    iv_pgmid    = p_pgmid
    iv_object   = p_obj
    iv_obj_name = p_name ).

  IF ls_result-metrics-object IS INITIAL.
    FORMAT INTENSIFIED ON.
    WRITE: / 'Object could not be resolved/analyzed:'.
    FORMAT INTENSIFIED OFF.
    WRITE: / p_pgmid, p_obj, p_name.

    IF ls_result-warnings IS NOT INITIAL.
      SKIP.
      WRITE: / 'Warnings:'.
      LOOP AT ls_result-warnings INTO DATA(lv_initial_warning).
        WRITE: / lv_initial_warning.
      ENDLOOP.
    ENDIF.
    RETURN.
  ENDIF.

  PERFORM display_metrics USING ls_result-metrics.
  PERFORM display_dependencies USING ls_result-dependencies.
  PERFORM display_warnings USING ls_result-warnings.


FORM display_metrics
  USING is_metrics TYPE /s4p0/s_ccc_metrics.

  FORMAT INTENSIFIED ON.
  WRITE: / 'Clean Core Metrics'.
  FORMAT INTENSIFIED OFF.
  ULINE.

  WRITE: / 'Input PGMID                      :', is_metrics-input_pgmid.
  WRITE: / 'Input OBJECT                     :', is_metrics-input_object.
  WRITE: / 'Input OBJ_NAME                   :', is_metrics-input_obj_name.
  WRITE: / 'Normalized PGMID                 :', is_metrics-pgmid.
  WRITE: / 'Normalized OBJECT                :', is_metrics-object.
  WRITE: / 'Normalized OBJ_NAME              :', is_metrics-obj_name.
  WRITE: / 'Package                          :', is_metrics-devclass.
  WRITE: / 'Normalized from LIMU             :', is_metrics-normalized_from_limu.

  SKIP.
  FORMAT INTENSIFIED ON.
  WRITE: / 'Footprint'.
  FORMAT INTENSIFIED OFF.
  WRITE: / 'Code lines                       :', is_metrics-code_lines.
  WRITE: / 'Statement count                  :', is_metrics-statement_count.
  WRITE: / 'Source scan supported            :', is_metrics-source_scan_supported.

  SKIP.
  FORMAT INTENSIFIED ON.
  WRITE: / 'SAP dependencies / Clean Core levels'.
  FORMAT INTENSIFIED OFF.
  WRITE: / 'SAP dependencies                 :', is_metrics-sap_dependencies.
  WRITE: / 'Released APIs (ECC: n/a)         :', is_metrics-released_api_dependencies.
  WRITE: / 'Unreleased API dependencies      :', is_metrics-unreleased_api_dependencies.
  WRITE: / 'Classic API dependencies         :', is_metrics-classic_api_dependencies.
  WRITE: / 'Internal SAP dependencies        :', is_metrics-internal_sap_dependencies.
  WRITE: / 'Not-recommended dependencies     :', is_metrics-not_recommended_dependencies.
  WRITE: / 'Level A (ECC: n/a)               :', is_metrics-level_a.
  WRITE: / 'Level B                          :', is_metrics-level_b.
  WRITE: / 'Level C                          :', is_metrics-level_c.
  WRITE: / 'Level D                          :', is_metrics-level_d.
  WRITE: / 'Deprecated released APIs (n/a)  :', is_metrics-deprecated_api_usage.

  SKIP.
  FORMAT INTENSIFIED ON.
  WRITE: / 'Database coupling'.
  FORMAT INTENSIFIED OFF.
  WRITE: / 'Direct SAP table reads           :', is_metrics-direct_sap_table_reads.
  WRITE: / 'Direct SAP table writes          :', is_metrics-direct_sap_table_writes.

  SKIP.
  FORMAT INTENSIFIED ON.
  WRITE: / 'Modifications / enhancements'.
  FORMAT INTENSIFIED OFF.
  WRITE: / 'Modification detected            :', is_metrics-modification_detected.
  WRITE: / 'Active modification count        :', is_metrics-modification_count.
  WRITE: / 'Modifications (compat. alias)    :', is_metrics-modifications.
  WRITE: / 'Modification density / KStmt     :', is_metrics-modification_density DECIMALS 2.
  WRITE: / 'Implicit enhancements            :', is_metrics-implicit_enhancements.
  WRITE: / 'Released extension points        :', is_metrics-released_extension_points.
  WRITE: / 'Unreleased extension points      :', is_metrics-unreleased_extension_points.

  SKIP.
  FORMAT INTENSIFIED ON.
  WRITE: / 'Copied SAP Standard / clone'.
  FORMAT INTENSIFIED OFF.
  WRITE: / 'Copied SAP Standard KPI (0/1)     :', is_metrics-copied_sap_standard.
  WRITE: / 'Clone detected                    :', is_metrics-copied_sap_standard_detected.
  WRITE: / 'Probable SAP original type        :', is_metrics-copied_sap_original_object.
  WRITE: / 'Probable SAP original name        :', is_metrics-copied_sap_original_name.
  WRITE: / 'Source similarity (%)             :', is_metrics-copied_sap_similarity_pct DECIMALS 1.
  WRITE: / 'Confidence                        :', is_metrics-copied_sap_confidence.
  WRITE: / 'Detection method                  :', is_metrics-copied_sap_detection_method.
  WRITE: / 'SAP candidates compared           :', is_metrics-copied_sap_candidate_count.
  WRITE: / 'Detection available               :', is_metrics-copied_sap_detection_available.

  SKIP.
  FORMAT INTENSIFIED ON.
  WRITE: / 'Architecture / normalized KPIs'.
  FORMAT INTENSIFIED OFF.
  WRITE: / 'ABAP Cloud                       :', is_metrics-abap_cloud.
  WRITE: / 'ABAP Cloud share (%)             :', is_metrics-abap_cloud_share DECIMALS 1.
  WRITE: / 'Non-released dep. density/KStmt  :', is_metrics-nonreleased_dep_density DECIMALS 2.
  WRITE: / 'Max dependency blast radius      :', is_metrics-max_dependency_blast_radius.
  WRITE: / 'Blast-radius scope               :', is_metrics-blast_radius_scope.
  WRITE: / 'Encapsulation ratio              :', is_metrics-encapsulation_ratio DECIMALS 2.
  WRITE: / 'Encapsulation ratio available    :', is_metrics-encapsulation_ratio_available.

  SKIP.
  FORMAT INTENSIFIED ON.
  WRITE: / 'Findings / result'.
  FORMAT INTENSIFIED OFF.
  WRITE: / 'Analyzer Clean Core findings     :', is_metrics-clean_core_findings.
  WRITE: / 'ATC Clean Core findings          :', is_metrics-atc_clean_core_findings.
  WRITE: / 'ATC findings available           :', is_metrics-atc_findings_available.
  WRITE: / 'Worst Clean Core level           :', is_metrics-worst_level.
  WRITE: / 'Release catalog used (ECC: no)  :', is_metrics-release_catalog_loaded.
  WRITE: / 'Classic API catalog loaded       :', is_metrics-classification_loaded.

ENDFORM.


FORM display_dependencies
  USING it_dependencies TYPE /s4p0/tt_ccc_dependency.

  IF it_dependencies IS INITIAL.
    RETURN.
  ENDIF.

  SKIP 2.
  FORMAT INTENSIFIED ON.
  WRITE: / 'SAP dependency details'.
  FORMAT INTENSIFIED OFF.
  ULINE.

  WRITE: / 'Type',
           8 'Dependency',
           70 'Lvl',
           76 'Classification',
           108 'API state',
           140 'Read',
           148 'Write',
           157 'Blast'.
  ULINE.

  LOOP AT it_dependencies INTO DATA(ls_dependency).
    WRITE: / ls_dependency-dep_type,
             8 ls_dependency-dep_name,
             70 ls_dependency-level,
             76 ls_dependency-classification,
             108 ls_dependency-api_state,
             140 ls_dependency-read_count,
             148 ls_dependency-write_count,
             157 ls_dependency-blast_radius_package.
  ENDLOOP.

ENDFORM.


FORM display_warnings
  USING it_warnings TYPE stringtab.

  IF it_warnings IS INITIAL.
    RETURN.
  ENDIF.

  SKIP 2.
  FORMAT INTENSIFIED ON.
  WRITE: / 'Warnings / limitations'.
  FORMAT INTENSIFIED OFF.
  ULINE.

  LOOP AT it_warnings INTO DATA(lv_warning).
    WRITE: / lv_warning.
  ENDLOOP.

ENDFORM.
