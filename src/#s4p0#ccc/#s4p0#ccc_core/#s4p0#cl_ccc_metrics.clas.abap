*---------------------------------------------------------------------*
* /S4P0/CL_CCC_METRICS
*
* Object-level Clean Core metric analyzer.
* Main API: DETERMINE( PGMID, OBJECT, OBJ_NAME ) -> TY_RESULT
*
* Notes:
* - LIMU inputs are normalized to the owning R3TR object.
* - Source metrics are available for PROG/CLAS/INTF/FUGR.
* - Dependency analysis is static. Dynamic calls and dynamic SQL cannot be
*   resolved reliably by this analyzer.
* - ECC/classic ABAP mode: no S/4/PCE release-info JSON is used.
* - Level B/D classification uses SAP objectClassifications_SAP.json.
* - The SAP classic API catalog is release-independent. Unclassified SAP
*   dependencies are treated as Level C. Level A is not determined in ECC mode.
* - Active modification detection is based on SMODILOG-INACTIVE = SPACE.
* - Copied SAP Standard detection is a lightweight ECC-safe clone heuristic:
*   TADIR ownership + likely SAP counterpart + normalized source similarity.
*   For exhaustive clone analysis SAP Clone Finder (/SDF/CD_CCA) remains preferred.
* - This class does not replace the official SAP Clean Core ATC checks.
*---------------------------------------------------------------------*
class /S4P0/CL_CCC_METRICS definition
  public
  final
  create public .

public section.

  types:
    ty_level          TYPE c LENGTH 1 .
  types:
    ty_classification TYPE c LENGTH 30 .
  types:
    ty_api_state      TYPE c LENGTH 30 .
  types:
    BEGIN OF ty_result,
        metrics      TYPE /S4P0/S_CCC_METRICS,
        evaluation   TYPE /S4P0/S_CCC_EVALUATION,
        dependencies TYPE /S4P0/TT_CCC_DEPENDENCY,
        warnings     TYPE STRINGTAB,
      END OF ty_result .
    " Transport IDs accepted by DETERMINE_TRANSPORT.
    " Duplicate IDs in the input are de-duplicated internally.
  types TY_T_TRANSPORT_ID type /S4P0/CL_CCC_EXTRACT=>TY_T_TRKORR .
  types:
    " Transport-level analysis result. One row represents one unique
    " normalized R3TR repository object, even if several LIMU/E071 entries
    " from one or several transports belong to that object.
    BEGIN OF ty_transport_item,
        source_trkorr         TYPE e070-trkorr,
        source_pgmid          TYPE e071-pgmid,
        source_object         TYPE e071-object,
        source_obj_name       TYPE e071-obj_name,
        transport_entry_count TYPE i,
        result                TYPE ty_result,
      END OF ty_transport_item .
  types:
    ty_t_transport_item TYPE STANDARD TABLE OF ty_transport_item WITH EMPTY KEY .
  types TY_TRANSPORT_SKIPPED type /S4P0/CL_CCC_EXTRACT=>TY_TRANSPORT_SKIPPED .
  types TY_T_TRANSPORT_SKIPPED type /S4P0/CL_CCC_EXTRACT=>TY_T_TRANSPORT_SKIPPED .
  types:
    BEGIN OF ty_transport_summary,
        " Compatibility fields: populated only when exactly one requested/root
        " transport exists in the respective set.
        requested_trkorr              TYPE e070-trkorr,
        root_trkorr                   TYPE e070-trkorr,
        requested_transport_count     TYPE i,
        root_transport_count          TYPE i,
        invalid_transport_count       TYPE i,
        scope_transport_count         TYPE i,
        transport_entry_count         TYPE i,
        repository_entry_count        TYPE i,
        unique_object_count           TYPE i,
        analyzed_object_count         TYPE i,
        skipped_entry_count           TYPE i,
        error_count                   TYPE i,
        code_lines                    TYPE i,
        statement_count               TYPE i,
        sap_dependencies              TYPE i,
        classic_api_dependencies      TYPE i,
        internal_sap_dependencies     TYPE i,
        not_recommended_dependencies TYPE i,
        unreleased_api_dependencies   TYPE i,
        level_a                       TYPE i,
        level_b                       TYPE i,
        level_c                       TYPE i,
        level_d                       TYPE i,
        direct_sap_table_reads        TYPE i,
        direct_sap_table_writes       TYPE i,
        modification_count            TYPE i,
        modified_object_count         TYPE i,
        tmp_object_count              TYPE i,
        copied_sap_standard_count     TYPE i,
        implicit_enhancements         TYPE i,
        clean_core_findings           TYPE i,
        ESTIM_effort_minutes        TYPE i,
        ESTIM_effort_low_minutes    TYPE i,
        ESTIM_effort_high_minutes   TYPE i,
        worst_level                   TYPE ty_level,
      END OF ty_transport_summary .
  types:
    BEGIN OF ty_transport_result,
        summary         TYPE ty_transport_summary,
        objects         TYPE ty_t_transport_item,
        skipped_entries TYPE ty_t_transport_skipped,
        warnings        TYPE STRINGTAB,
      END OF ty_transport_result .

  constants C_LEVEL_A type TY_LEVEL value 'A' ##NO_TEXT.
  constants C_LEVEL_B type TY_LEVEL value 'B' ##NO_TEXT.
  constants C_LEVEL_C type TY_LEVEL value 'C' ##NO_TEXT.
  constants C_LEVEL_D type TY_LEVEL value 'D' ##NO_TEXT.
  constants C_COPY_SIMILARITY_HIGH type DECFLOAT34 value '95' ##NO_TEXT.
  constants C_COPY_SIMILARITY_MEDIUM type DECFLOAT34 value '85' ##NO_TEXT.
  constants C_COPY_SIMILARITY_NAME type DECFLOAT34 value '80' ##NO_TEXT.

    " Main API. PGMID/OBJECT/OBJ_NAME can be taken directly from E071.
    " LIMU keys are normalized to their owning R3TR object.
  class-methods DETERMINE
    importing
      !IV_PGMID type E071-PGMID
      !IV_OBJECT type E071-OBJECT
      !IV_OBJ_NAME type E071-OBJ_NAME
    returning
      value(RS_RESULT) type TY_RESULT .
    " Analyze repository objects contained in one or more CTS requests/tasks.
    " IT_TRKORR accepts transport IDs. Duplicates are ignored. For every root
    " request and IV_INCLUDE_TASKS = X, its direct tasks are added to the scope.
    " If an input ID is itself a task, only that task is added for that input.
    " Duplicate repository objects across transports are analyzed only once.
  class-methods DETERMINE_TRANSPORT
    importing
      !IT_TRKORR type TY_T_TRANSPORT_ID
      !IV_INCLUDE_TASKS type ABAP_BOOL default ABAP_TRUE
    returning
      value(RS_TRANSPORT) type TY_TRANSPORT_RESULT .
    " Clears the in-session cache for SAP's classicAPI/noAPI catalog.
  class-methods CLEAR_CACHE .
  class-methods PROGRESS_INDICATOR
    importing
      !IV_CURRENT type I
      !IV_TOTAL type I
      !IV_TEXT type CSEQUENCE .
  class-methods ACTIVATE_METRICS_PERSISTENCE
    importing
      !IO_METRICS_DB type ref to /S4P0/CL_CCC_METRICS_DB .
  class-methods IS_METRICS_PERSISTENCE_ACTIVE
    returning
      value(RV_ACTIVE) type BOOLE_D .
protected section.
private section.

  types:
    BEGIN OF ty_transport_key,
        pgmid    TYPE e071-pgmid,
        object   TYPE e071-object,
        obj_name TYPE e071-obj_name,
      END OF ty_transport_key .
  types TY_SOURCE type /S4P0/S_CCC_TADIR .
  types TY_T_SOURCE type /S4P0/TT_CCC_TADIR .
  types TY_DEP type /S4P0/CL_CCC_EXTRACT=>TY_DEPENDENCY_KEY .
  types TY_T_DEP type /S4P0/CL_CCC_EXTRACT=>TY_T_DEPENDENCY_KEY .
  types:
    BEGIN OF ty_touch,
        dep_type TYPE c LENGTH 20,
        dep_name TYPE c LENGTH 180,
      END OF ty_touch .
  types:
    ty_t_touch TYPE SORTED TABLE OF ty_touch WITH UNIQUE KEY dep_type dep_name .
  types TY_COPY_CANDIDATE type /S4P0/CL_CCC_EXTRACT=>TY_COPY_CANDIDATE .
  types TY_T_COPY_CANDIDATE type /S4P0/CL_CCC_EXTRACT=>TY_T_COPY_CANDIDATE .
  types:
    BEGIN OF ty_token_count,
        token TYPE c LENGTH 255,
        count TYPE i,
      END OF ty_token_count .
  types:
    ty_t_token_count TYPE HASHED TABLE OF ty_token_count WITH UNIQUE KEY token .
  types:
    BEGIN OF ty_blast_counter,
        dep_type  TYPE c LENGTH 20,
        dep_name  TYPE c LENGTH 180,
        consumers TYPE i,
      END OF ty_blast_counter .
  types:
    ty_t_blast_counter TYPE HASHED TABLE OF ty_blast_counter
        WITH UNIQUE KEY dep_type dep_name .

  class-data GO_METRICS_DB type ref to /S4P0/CL_CCC_METRICS_DB .
  class-data GV_METRICS_PERSISTENCE_ON type BOOLE_D .
    " Upgrade-effort model ECC_V1. These weights are deliberately centralized
    " for later calibration against measured upgrade effort.
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

  methods ANALYZE
    importing
      !IV_PGMID type E071-PGMID
      !IV_OBJECT type E071-OBJECT
      !IV_OBJ_NAME type E071-OBJ_NAME
    returning
      value(RS_RESULT) type TY_RESULT .
  methods CLASSIFY_DEPENDENCY
    importing
      !IS_DEP type TY_DEP
    exporting
      !EV_LEVEL type TY_LEVEL
      !EV_CLASS type TY_CLASSIFICATION
      !EV_API_STATE type TY_API_STATE
      !EV_RELEASED type ABAP_BOOL
      !EV_DEPRECATED type ABAP_BOOL .
  methods GET_JSON_STATE
    importing
      !IS_DEP type TY_DEP
    returning
      value(RV_STATE) type CHAR20 .
  methods ANALYZE_SOURCE_CODE
    importing
      !IS_SOURCE type TY_SOURCE
    changing
      !CS_METRICS type /S4P0/S_CCC_METRICS
      !CT_DEPENDENCIES type /S4P0/TT_CCC_DEPENDENCY.
  methods TOUCH_TABLE
    importing
      !IV_WRITE type ABAP_BOOL
      !IT_TOUCH type TY_T_TOUCH
    changing
      !CT_DEPENDENCIES type /S4P0/TT_CCC_DEPENDENCY.
  methods FINALIZE_DEPENDENCY_METRICS
    changing
      !CS_METRICS type /S4P0/S_CCC_METRICS
      !CT_DEPENDENCIES type /S4P0/TT_CCC_DEPENDENCY .
  methods CALCULATE_BLAST_RADIUS
    importing
      !IS_SOURCE type TY_SOURCE
    changing
      !CS_METRICS type /S4P0/S_CCC_METRICS
      !CT_DEPENDENCIES type /S4P0/TT_CCC_DEPENDENCY .
  methods DETECT_COPIED_SAP_STANDARD
    importing
      !IS_SOURCE type TY_SOURCE
    changing
      !CS_METRICS type /S4P0/S_CCC_METRICS
      !CT_WARNINGS type STRINGTAB.
  methods GET_TOKEN_COUNTS
    importing
      !IS_SOURCE type TY_SOURCE
    exporting
      !ET_COUNTS type TY_T_TOKEN_COUNT
      !EV_TOTAL type I .
  methods CALCULATE_TOKEN_SIMILARITY
    importing
      !IT_A type TY_T_TOKEN_COUNT
      !IV_TOTAL_A type I
      !IT_B type TY_T_TOKEN_COUNT
      !IV_TOTAL_B type I
    returning
      value(RV_SIMILARITY) type DECFLOAT34 .
  methods GET_WORSE_LEVEL
    importing
      !IV_A type TY_LEVEL
      !IV_B type TY_LEVEL
    returning
      value(RV_LEVEL) type TY_LEVEL .
  methods IS_EXTENSION_TYPE
    importing
      !IV_TYPE type CSEQUENCE
    returning
      value(RV_YES) type ABAP_BOOL .
  methods ADD_WARNING
    importing
      !IV_TEXT type STRING
    changing
      !CT_WARNINGS type STRINGTAB.
ENDCLASS.



CLASS /S4P0/CL_CCC_METRICS IMPLEMENTATION.


METHOD activate_metrics_persistence.

  go_metrics_db = io_metrics_db.
  gv_metrics_persistence_on = abap_true.

ENDMETHOD.


  METHOD add_warning.
    IF iv_text IS NOT INITIAL.
      APPEND iv_text TO ct_warnings.
    ENDIF.
  ENDMETHOD.


METHOD analyze.

  DATA(ls_input) = VALUE ty_transport_key(
    pgmid    = iv_pgmid
    object   = iv_object
    obj_name = iv_obj_name ).

  rs_result-metrics-input_pgmid    = iv_pgmid.
  rs_result-metrics-input_object   = iv_object.
  rs_result-metrics-input_obj_name = iv_obj_name.

  /s4p0/cl_ccc_extract=>normalize_object(
    EXPORTING
      iv_pgmid      = ls_input-pgmid
      iv_object     = ls_input-object
      iv_obj_name   = ls_input-obj_name
    IMPORTING
      es_source     = DATA(ls_source)
      ev_normalized = rs_result-metrics-normalized_from_limu
      ev_no_tadir   = DATA(lv_no_tadir) ).

  IF lv_no_tadir = abap_true.
    add_warning(
      EXPORTING iv_text = |No TADIR entry found for { iv_pgmid } { iv_object } { iv_obj_name }; package and SAP/customer ownership checks may be incomplete.|
      CHANGING  ct_warnings = rs_result-warnings ).
  ENDIF.

  IF ls_source-object IS INITIAL OR ls_source-obj_name IS INITIAL.
    add_warning(
      EXPORTING iv_text = |Object { iv_pgmid } { iv_object } { iv_obj_name } could not be resolved to an R3TR repository object.|
      CHANGING  ct_warnings = rs_result-warnings ).
    RETURN.
  ENDIF.

  MOVE-CORRESPONDING ls_source to rs_result-metrics-key.

  IF is_metrics_persistence_active( ) = abap_true.
    DATA(lv_use_metrics_from_buffer) = go_metrics_db->use_metrics_from_buffer(
      is_metrics_key = rs_result-metrics-key ).
  ENDIF.

  IF lv_use_metrics_from_buffer = abap_true.
    go_metrics_db->read_single_object_metrics(
      EXPORTING
        is_metrics_key  = rs_result-metrics-key
      IMPORTING
        es_metrics      = rs_result-metrics
        et_dependencies = rs_result-dependencies
        et_warnings     = rs_result-warnings ).
  ELSE.

    "TODO: refactor to new method analyze_metrics
    IF rs_result-metrics-devclass = '$TMP'.
      rs_result-metrics-tmp_object = abap_true.
    ENDIF.

    rs_result-metrics-worst_level          = c_level_a.
    rs_result-metrics-blast_radius_scope   = 'PACKAGE'.
    rs_result-metrics-encapsulation_ratio  = -1.

    /s4p0/cl_ccc_extract=>load_classification( ).
    " ECC/classic ABAP mode deliberately does not consume the S/4/PCE
    " S/4 release-info catalogs. Therefore Level A/released/deprecated
    " metrics are not determined and remain zero.
    rs_result-metrics-release_catalog_loaded = abap_false.
    rs_result-metrics-classification_loaded  = /s4p0/cl_ccc_extract=>is_classification_loaded( ).

    add_warning(
      EXPORTING iv_text = 'ECC mode: no S/4/PCE release-info catalog is used. Level A, RELEASED_API_DEPENDENCIES and DEPRECATED_API_USAGE remain zero. classicAPI maps to Level B, noAPI to Level D, and internal/unclassified SAP dependencies to Level C.'
      CHANGING  ct_warnings = rs_result-warnings ).

    IF /s4p0/cl_ccc_extract=>is_classification_loaded( ) = abap_false.
      add_warning(
        EXPORTING iv_text = 'SAP objectClassifications_SAP.json could not be loaded. Level B/classicAPI and Level D/noAPI cannot be separated reliably; unreleased SAP dependencies default to Level C.'
        CHANGING  ct_warnings = rs_result-warnings ).
    ENDIF.

    DATA(lt_dep) = /s4p0/cl_ccc_extract=>get_dependencies( ls_source ).

    LOOP AT lt_dep INTO DATA(ls_dep).
      IF /s4p0/cl_ccc_extract=>is_sap_dependency( ls_dep ) = abap_false.
        CONTINUE.
      ENDIF.

      classify_dependency(
        EXPORTING
          is_dep        = ls_dep
        IMPORTING
          ev_level      = DATA(lv_level)
          ev_class      = DATA(lv_class)
          ev_api_state  = DATA(lv_api_state)
          ev_released   = DATA(lv_released)
          ev_deprecated = DATA(lv_deprecated) ).

      APPEND VALUE /s4p0/s_ccc_dependency(
        dep_type           = ls_dep-dep_type
        dep_name           = ls_dep-dep_name
        level              = lv_level
        classification     = lv_class
        api_state          = lv_api_state
        released           = lv_released
        deprecated         = lv_deprecated
        is_extension_point = is_extension_type( ls_dep-dep_type ) )
        TO rs_result-dependencies.
    ENDLOOP.

    analyze_source_code(
      EXPORTING
        is_source       = ls_source
      CHANGING
        cs_metrics      = rs_result-metrics
        ct_dependencies = rs_result-dependencies ).

    " A TABL/VIEW dependency caused only by typing (for example TYPE MARA-MATNR)
    " is not a direct database access and must not become a Clean Core finding.
    DELETE rs_result-dependencies
      WHERE ( dep_type = 'TABL' OR dep_type = 'VIEW' )
        AND read_count = 0
        AND write_count = 0.

    finalize_dependency_metrics(
      CHANGING
        cs_metrics      = rs_result-metrics
        ct_dependencies = rs_result-dependencies ).

    rs_result-metrics-modification_count = /s4p0/cl_ccc_extract=>count_modifications(
      iv_pgmid    = ls_input-pgmid
      iv_object   = ls_input-object
      iv_obj_name = ls_input-obj_name
      is_source   = ls_source ).

    " Backwards-compatible alias plus explicit detection/density metrics.
    rs_result-metrics-modifications         = rs_result-metrics-modification_count.
    rs_result-metrics-modification_detected = xsdbool( rs_result-metrics-modification_count > 0 ).

    IF rs_result-metrics-statement_count > 0.
      rs_result-metrics-modification_density =
        CONV decfloat34( rs_result-metrics-modification_count )
        * 1000 / rs_result-metrics-statement_count.
    ENDIF.

    rs_result-metrics-implicit_enhancements = /s4p0/cl_ccc_extract=>count_implicit_enhancements(
      iv_pgmid    = ls_input-pgmid
      iv_object   = ls_input-object
      iv_obj_name = ls_input-obj_name
      is_source   = ls_source ).

    detect_copied_sap_standard(
      EXPORTING
        is_source   = ls_source
      CHANGING
        cs_metrics  = rs_result-metrics
        ct_warnings = rs_result-warnings ).

    " Direct DB writes, modifications, implicit source enhancements and a
    " detected SAP-standard clone are treated as Level D in this metric model.
    " This is an analyzer policy, not an official SAP A/B/C/D classification.
    IF rs_result-metrics-generated_source = abap_true.
      rs_result-metrics-worst_level = c_level_a.
    ELSE.
      IF rs_result-metrics-direct_sap_table_writes > 0 OR
         rs_result-metrics-modification_count > 0 OR
         rs_result-metrics-implicit_enhancements > 0 OR
         rs_result-metrics-copied_sap_standard_detected = abap_true.
        rs_result-metrics-worst_level = c_level_d.
      ENDIF.
    ENDIF.

    calculate_blast_radius(
      EXPORTING
        is_source       = ls_source
      CHANGING
        cs_metrics      = rs_result-metrics
        ct_dependencies = rs_result-dependencies ).

    " Estimate probable manual analysis/correction time for the next upgrade.
    " The public method can be called again by a driver after metric overrides.
    rs_result-evaluation = /s4p0/cl_ccc_weight=>evaluate_object( rs_result-metrics ).

    rs_result-metrics-clean_core_findings =
        rs_result-metrics-level_b
      + rs_result-metrics-level_c
      + rs_result-metrics-level_d
      + rs_result-metrics-modification_count
      + rs_result-metrics-implicit_enhancements
      + rs_result-metrics-copied_sap_standard.

    " No ATC variant is an input of this API. Therefore this class deliberately
    " does not start an ATC run and does not pretend that its findings are ATC findings.
    rs_result-metrics-atc_findings_available  = abap_false.
    rs_result-metrics-atc_clean_core_findings = 0.

    add_warning(
      EXPORTING iv_text = 'ATC Clean Core finding count is not populated because no ATC check variant is part of the three-input API. CLEAN_CORE_FINDINGS contains this analyzer''s dependency/enhancement findings, not official ATC results.'
      CHANGING  ct_warnings = rs_result-warnings ).

    " Encapsulation cannot be calculated without defining which customer
    " packages/classes are approved wrappers around non-released SAP APIs.
    rs_result-metrics-encapsulation_ratio_available = abap_false.
    rs_result-metrics-encapsulation_ratio = -1.

    add_warning(
      EXPORTING iv_text = 'ENCAPSULATION_RATIO is not calculated: an approved wrapper/package convention is required to determine it without unreliable naming heuristics.'
      CHANGING  ct_warnings = rs_result-warnings ).

    IF is_metrics_persistence_active( ) = abap_true.
      go_metrics_db->save_single_object_metrics(
        EXPORTING
          is_metrics      = rs_result-metrics
          it_dependencies = rs_result-dependencies
          it_warnings     = rs_result-warnings ).
    ENDIF.
  ENDIF.

  SORT rs_result-dependencies BY level DESCENDING dep_type dep_name.

ENDMETHOD.


  METHOD analyze_source_code.
    DATA(lv_main) = /s4p0/cl_ccc_extract=>get_main_program( is_source ).

    IF lv_main IS INITIAL.
      cs_metrics-source_scan_supported = abap_false.
      RETURN.
    ENDIF.

    cs_metrics-source_scan_supported = abap_true.

    " ABAP for Cloud Development. UCCHECK = 5 is the internal TRDIR language version.
    DATA(lv_uccheck) = /s4p0/cl_ccc_extract=>get_program_uccheck( lv_main ).

    cs_metrics-abap_cloud = xsdbool( lv_uccheck = '5' ).
    cs_metrics-abap_cloud_share = COND decfloat34(
      WHEN cs_metrics-abap_cloud = abap_true THEN 100 ELSE 0 ).

    " Count physical source lines across the owning program and all includes.
    DATA(lt_programs) = /s4p0/cl_ccc_extract=>get_program_list( lv_main ).

    LOOP AT lt_programs INTO DATA(lv_prog).
      DATA(lt_lines) = /s4p0/cl_ccc_extract=>read_source( lv_prog ).
      IF lt_lines IS INITIAL.
        CONTINUE.
      ENDIF.

      LOOP AT lt_lines INTO DATA(lv_line).
        DATA(lv_trim) = lv_line.
        SHIFT lv_trim LEFT DELETING LEADING space.
        IF lv_trim IS INITIAL.
          CONTINUE.
        ENDIF.
        IF lv_trim(1) = '*' OR lv_trim(1) = '"'.
          CONTINUE.
        ENDIF.
        ADD 1 TO cs_metrics-code_lines.
      ENDLOOP.
    ENDLOOP.

    " Tokenize main source together with includes.
    DATA lt_token  TYPE STANDARD TABLE OF stoken WITH EMPTY KEY.
    DATA lt_stmt   TYPE STANDARD TABLE OF sstmnt WITH EMPTY KEY.
    DATA lt_level  TYPE STANDARD TABLE OF slevel WITH EMPTY KEY.

    DATA(lt_source) = /s4p0/cl_ccc_extract=>read_source( lv_main ).
    IF lt_source IS INITIAL.
      RETURN.
    ENDIF.

    SCAN ABAP-SOURCE lt_source
      TOKENS     INTO lt_token
      STATEMENTS INTO lt_stmt
      LEVELS     INTO lt_level
      WITH INCLUDES.

    IF sy-subrc > 1.
      RETURN.
    ENDIF.

    cs_metrics-statement_count = lines( lt_stmt ).

    " Build the SAP DB dependency lookup once.
    DATA lt_dbdeps TYPE HASHED TABLE OF ty_touch
      WITH UNIQUE KEY dep_type dep_name.

    LOOP AT ct_dependencies INTO DATA(ls_dbdep)
      WHERE dep_type = 'TABL' OR dep_type = 'VIEW'.
      INSERT VALUE ty_touch(
        dep_type = ls_dbdep-dep_type
        dep_name = ls_dbdep-dep_name ) INTO TABLE lt_dbdeps.
    ENDLOOP.

    LOOP AT lt_stmt INTO DATA(ls_stmt).
      READ TABLE lt_token INDEX ls_stmt-from INTO DATA(ls_first).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(lv_first) = to_upper( CONV string( ls_first-str ) ).
      DATA(lv_is_write) = xsdbool(
           lv_first = 'UPDATE'
        OR lv_first = 'INSERT'
        OR lv_first = 'MODIFY'
        OR lv_first = 'DELETE' ).

      DATA(lv_has_select) = abap_false.
      DATA lt_touch TYPE ty_t_touch.

      LOOP AT lt_token INTO DATA(ls_tok) FROM ls_stmt-from TO ls_stmt-to.
        DATA(lv_tok) = to_upper( CONV string( ls_tok-str ) ).

        IF lv_tok = 'SELECT'.
          lv_has_select = abap_true.
        ENDIF.

        READ TABLE lt_dbdeps
          WITH TABLE KEY dep_type = 'TABL' dep_name = lv_tok
          TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          INSERT VALUE ty_touch( dep_type = 'TABL' dep_name = lv_tok )
            INTO TABLE lt_touch.
        ENDIF.

        READ TABLE lt_dbdeps
          WITH TABLE KEY dep_type = 'VIEW' dep_name = lv_tok
          TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          INSERT VALUE ty_touch( dep_type = 'VIEW' dep_name = lv_tok )
            INTO TABLE lt_touch.
        ENDIF.
      ENDLOOP.

      IF lt_touch IS INITIAL.
        CONTINUE.
      ENDIF.

      IF lv_is_write = abap_true.
        touch_table(
          EXPORTING
            iv_write       = abap_true
            it_touch       = lt_touch
          CHANGING
            ct_dependencies = ct_dependencies ).
      ELSEIF lv_has_select = abap_true.
        touch_table(
          EXPORTING
            iv_write       = abap_false
            it_touch       = lt_touch
          CHANGING
            ct_dependencies = ct_dependencies ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD calculate_blast_radius.
    IF ct_dependencies IS INITIAL OR is_source-devclass IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_counter TYPE ty_t_blast_counter.

    LOOP AT ct_dependencies INTO DATA(ls_dep).
      INSERT VALUE ty_blast_counter(
        dep_type = ls_dep-dep_type
        dep_name = ls_dep-dep_name ) INTO TABLE lt_counter.
    ENDLOOP.

    DATA(lt_sources) = /s4p0/cl_ccc_extract=>get_package_sources( is_source-devclass ).
    DATA lt_peer_db      TYPE /S4P0/TT_CCC_DEPENDENCY.
    DATA ls_peer_metrics TYPE /S4P0/S_CCC_METRICS.

    LOOP AT lt_sources INTO DATA(ls_peer).
      CLEAR: lt_peer_db, ls_peer_metrics.
      DATA(lt_peer_dep) = /s4p0/cl_ccc_extract=>get_dependencies( ls_peer ).

      LOOP AT lt_peer_dep INTO DATA(ls_peer_dep).
        READ TABLE lt_counter ASSIGNING FIELD-SYMBOL(<counter>)
          WITH TABLE KEY
            dep_type = ls_peer_dep-dep_type
            dep_name = ls_peer_dep-dep_name.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.

        IF ls_peer_dep-dep_type = 'TABL' OR ls_peer_dep-dep_type = 'VIEW'.
          " A repository dependency on a table can be caused by TYPE references.
          " Let the source scanner prove that the peer really accesses the DB object.
          APPEND VALUE /S4P0/s_CCC_DEPENDENCY(
            dep_type = ls_peer_dep-dep_type
            dep_name = ls_peer_dep-dep_name ) TO lt_peer_db.
        ELSE.
          ADD 1 TO <counter>-consumers.
        ENDIF.
      ENDLOOP.

      IF lt_peer_db IS NOT INITIAL.
        analyze_source_code(
          EXPORTING
            is_source       = ls_peer
          CHANGING
            cs_metrics      = ls_peer_metrics
            ct_dependencies = lt_peer_db ).

        LOOP AT lt_peer_db INTO DATA(ls_peer_db)
          WHERE read_count > 0 OR write_count > 0.
          READ TABLE lt_counter ASSIGNING <counter>
            WITH TABLE KEY
              dep_type = ls_peer_db-dep_type
              dep_name = ls_peer_db-dep_name.
          IF sy-subrc = 0.
            ADD 1 TO <counter>-consumers.
          ENDIF.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

    LOOP AT ct_dependencies ASSIGNING FIELD-SYMBOL(<dep>).
      READ TABLE lt_counter
        WITH TABLE KEY dep_type = <dep>-dep_type dep_name = <dep>-dep_name
        INTO DATA(ls_counter).
      IF sy-subrc = 0.
        <dep>-blast_radius_package = ls_counter-consumers.
        IF ls_counter-consumers > cs_metrics-max_dependency_blast_radius.
          cs_metrics-max_dependency_blast_radius = ls_counter-consumers.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD calculate_token_similarity.
    DATA ls_a TYPE ty_token_count.
    DATA ls_b TYPE ty_token_count.
    DATA lv_common TYPE i.
    DATA lv_min TYPE i.
    DATA lv_denominator TYPE decfloat34.

    CLEAR rv_similarity.
    IF iv_total_a = 0 OR iv_total_b = 0.
      RETURN.
    ENDIF.

    LOOP AT it_a INTO ls_a.
      READ TABLE it_b INTO ls_b WITH TABLE KEY token = ls_a-token.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      IF ls_a-count < ls_b-count.
        lv_min = ls_a-count.
      ELSE.
        lv_min = ls_b-count.
      ENDIF.
      ADD lv_min TO lv_common.
    ENDLOOP.

    lv_denominator = iv_total_a + iv_total_b.
    IF lv_denominator > 0.
      rv_similarity = CONV decfloat34( lv_common ) * 200 / lv_denominator.
    ENDIF.
  ENDMETHOD.


  METHOD classify_dependency.
    DATA lv_json_state TYPE c LENGTH 20.

    CLEAR: ev_level,
           ev_class,
           ev_api_state,
           ev_released,
           ev_deprecated.

    " A TABL/VIEW repository dependency alone is not yet a Clean Core finding.
    " It may come from typing such as TYPE MARA-MATNR. The source scanner below
    " upgrades an actual SQL read to C and an SQL write to D. Untouched TABL/VIEW
    " dependencies are removed before the metrics are finalized.
    IF is_dep-dep_type = 'TABL' OR is_dep-dep_type = 'VIEW'.
      CLEAR ev_level.
      ev_class = 'SAP_DB_OBJECT'.
      RETURN.
    ENDIF.

    " ECC does not have a release-specific Level-A catalog comparable with
    " S/4HANA Cloud/PCE. Use SAP's release-independent classic API catalog.
    lv_json_state = get_json_state( is_dep ).
    ev_api_state = lv_json_state.

    CASE lv_json_state.
      WHEN 'CLASSICAPI'.
        ev_level = c_level_b.
        ev_class = 'CLASSIC_API'.
      WHEN 'NOAPI'.
        ev_level = c_level_d.
        ev_class = 'NO_API'.
      WHEN 'INTERNALAPI'.
        ev_level = c_level_c.
        ev_class = 'INTERNAL'.
      WHEN OTHERS.
        ev_level = c_level_c.
        ev_class = 'UNCLASSIFIED'.
    ENDCASE.

    " These flags intentionally stay initial in ECC mode because there is no
    " ECC release contract catalog behind this analyzer.
    ev_released   = abap_false.
    ev_deprecated = abap_false.
  ENDMETHOD.


  METHOD clear_cache.
    " The catalog is owned by the extraction layer.
    /s4p0/cl_ccc_extract=>clear_cache( ).
  ENDMETHOD.


  METHOD detect_copied_sap_standard.
    DATA lt_candidates TYPE ty_t_copy_candidate.
    DATA lt_custom_tokens TYPE ty_t_token_count.
    DATA lt_sap_tokens TYPE ty_t_token_count.
    DATA lv_custom_total TYPE i.
    DATA lv_sap_total TYPE i.
    DATA lv_similarity TYPE decfloat34.
    DATA lv_best_similarity TYPE decfloat34.
    DATA ls_best TYPE ty_copy_candidate.
    DATA ls_candidate TYPE ty_copy_candidate.
    DATA ls_candidate_source TYPE ty_source.

    CLEAR: cs_metrics-copied_sap_standard,
           cs_metrics-copied_sap_standard_detected,
           cs_metrics-copied_sap_original_object,
           cs_metrics-copied_sap_original_name,
           cs_metrics-copied_sap_similarity_pct,
           cs_metrics-copied_sap_confidence,
           cs_metrics-copied_sap_detection_method,
           cs_metrics-copied_sap_candidate_count,
           cs_metrics-copied_sap_detection_available.

    " A SAP-owned object is the original/modification, not a customer clone.
    IF is_source-author = 'SAP' OR is_source-srcsystem = 'SAP'.
      RETURN.
    ENDIF.

    " The lightweight in-class detector only works for source-code objects.
    IF is_source-object <> 'PROG' AND
       is_source-object <> 'CLAS' AND
       is_source-object <> 'INTF' AND
       is_source-object <> 'FUGR'.
      RETURN.
    ENDIF.

    " Do not run a similiar detection for generated function groups
    IF is_source-object = 'FUGR'.
      cs_metrics-generated_source =
        /s4p0/cl_ccc_extract=>is_generated_view_maint( is_source-obj_name ).

      IF cs_metrics-generated_source = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    cs_metrics-copied_sap_detection_available = abap_true.
    cs_metrics-copied_sap_detection_method = 'TADIR+SOURCE'.

    lt_candidates = /s4p0/cl_ccc_extract=>get_copy_candidates( is_source ).
    cs_metrics-copied_sap_candidate_count = lines( lt_candidates ).

    IF lt_candidates IS INITIAL.
      add_warning(
        EXPORTING
          iv_text = 'Copied SAP Standard check: no likely SAP counterpart was found by name/short-text preselection. Arbitrarily renamed clones require SAP Clone Finder (/SDF/CD_CCA) for exhaustive detection.'
        CHANGING
          ct_warnings = ct_warnings ).
      RETURN.
    ENDIF.

    get_token_counts(
      EXPORTING
        is_source = is_source
      IMPORTING
        et_counts = lt_custom_tokens
        ev_total  = lv_custom_total ).

    IF lv_custom_total = 0.
      RETURN.
    ENDIF.

    LOOP AT lt_candidates INTO ls_candidate.
      CLEAR: ls_candidate_source, lt_sap_tokens, lv_sap_total, lv_similarity.
      ls_candidate_source-pgmid     = 'R3TR'.
      ls_candidate_source-object    = ls_candidate-object.
      ls_candidate_source-obj_name  = ls_candidate-obj_name.
      ls_candidate_source-devclass  = ls_candidate-devclass.
      ls_candidate_source-author    = ls_candidate-author.
      ls_candidate_source-srcsystem = ls_candidate-srcsystem.

      get_token_counts(
        EXPORTING
          is_source = ls_candidate_source
        IMPORTING
          et_counts = lt_sap_tokens
          ev_total  = lv_sap_total ).

      IF lv_sap_total = 0.
        CONTINUE.
      ENDIF.

      lv_similarity = calculate_token_similarity(
        it_a       = lt_custom_tokens
        iv_total_a = lv_custom_total
        it_b       = lt_sap_tokens
        iv_total_b = lv_sap_total ).

      IF lv_similarity > lv_best_similarity.
        lv_best_similarity = lv_similarity.
        ls_best = ls_candidate.
      ENDIF.
    ENDLOOP.

    IF ls_best-obj_name IS INITIAL.
      RETURN.
    ENDIF.

    cs_metrics-copied_sap_original_object = ls_best-object.
    cs_metrics-copied_sap_original_name   = ls_best-obj_name.
    cs_metrics-copied_sap_similarity_pct  = lv_best_similarity.

    " Confidence is intentionally conservative. A strong name-derived candidate
    " may be accepted from 80%; title-only candidates require at least 85%.
    IF lv_best_similarity >= c_copy_similarity_high.
      cs_metrics-copied_sap_confidence = 'HIGH'.
      cs_metrics-copied_sap_standard_detected = abap_true.
    ELSEIF lv_best_similarity >= c_copy_similarity_medium.
      cs_metrics-copied_sap_confidence = 'MEDIUM'.
      cs_metrics-copied_sap_standard_detected = abap_true.
    ELSEIF lv_best_similarity >= c_copy_similarity_name AND
           ls_best-reason CS 'NAME'.
      cs_metrics-copied_sap_confidence = 'MEDIUM'.
      cs_metrics-copied_sap_standard_detected = abap_true.
    ELSE.
      cs_metrics-copied_sap_confidence = 'LOW'.
    ENDIF.

    IF cs_metrics-copied_sap_standard_detected = abap_true.
      cs_metrics-copied_sap_standard = 1.
    ENDIF.
  ENDMETHOD.


  METHOD determine.
    rs_result = NEW /s4p0/cl_ccc_metrics( )->analyze(
      iv_pgmid    = iv_pgmid
      iv_object   = iv_object
      iv_obj_name = iv_obj_name ).
  ENDMETHOD.


  METHOD determine_transport.

    DATA lt_work TYPE /s4p0/cl_ccc_extract=>ty_t_transport_work.
    DATA ls_work TYPE /s4p0/cl_ccc_extract=>ty_transport_work.
    DATA ls_counts TYPE /s4p0/cl_ccc_extract=>ty_transport_counts.
    DATA lt_pop_warnings TYPE /s4p0/cl_ccc_extract=>ty_t_message.
    DATA lo_analyzer TYPE REF TO /s4p0/cl_ccc_metrics.
    DATA ls_item TYPE ty_transport_item.
    DATA ls_metrics TYPE /S4P0/S_CCC_METRICS.
    DATA ls_evaluation TYPE /S4P0/S_CCC_EVALUATION.
    DATA lv_count TYPE i.
    DATA lv_error_text TYPE string.

    CLEAR rs_transport.

    " Layer 1 resolves the transports into a unique repository population.
    /s4p0/cl_ccc_extract=>build_transport_population(
      EXPORTING
        it_trkorr        = it_trkorr
        iv_include_tasks = iv_include_tasks
      IMPORTING
        et_work          = lt_work
        et_skipped       = rs_transport-skipped_entries
        es_counts        = ls_counts
        et_warnings      = lt_pop_warnings ).

    MOVE-CORRESPONDING ls_counts TO rs_transport-summary.
    APPEND LINES OF lt_pop_warnings TO rs_transport-warnings.

    IF lt_work IS INITIAL.
      RETURN.
    ENDIF.

    CREATE OBJECT lo_analyzer.


    rs_transport-summary-worst_level = c_level_a.

    LOOP AT lt_work INTO ls_work.

      /s4p0/cl_ccc_metrics=>progress_indicator(
        iv_current = sy-tabix
        iv_total   = lines( lt_work[] )
        iv_text    = 'Determining Clean Core metrics' ).

      CLEAR: ls_item, ls_metrics, ls_evaluation.
      ls_item-source_trkorr          = ls_work-source_trkorr.
      ls_item-source_pgmid           = ls_work-source_pgmid.
      ls_item-source_object          = ls_work-source_object.
      ls_item-source_obj_name        = ls_work-source_obj_name.
      ls_item-transport_entry_count  = ls_work-transport_entry_count.

      TRY.
          ls_item-result = lo_analyzer->analyze(
            iv_pgmid    = ls_work-pgmid
            iv_object   = ls_work-object
            iv_obj_name = CONV #( ls_work-obj_name ) ).
        CATCH cx_root INTO data(lx_root).
          lv_error_text = lx_root->get_text( ).
          APPEND lv_error_text TO ls_item-result-warnings.
      ENDTRY.

      ls_metrics = ls_item-result-metrics.
      ls_evaluation = ls_item-result-evaluation.

      IF ls_metrics-object IS INITIAL.
        ADD 1 TO rs_transport-summary-error_count.
      ELSE.
        ADD 1 TO rs_transport-summary-analyzed_object_count.
        ADD ls_metrics-code_lines TO rs_transport-summary-code_lines.
        ADD ls_metrics-statement_count TO rs_transport-summary-statement_count.
        ADD ls_metrics-sap_dependencies TO rs_transport-summary-sap_dependencies.
        ADD ls_metrics-classic_api_dependencies TO rs_transport-summary-classic_api_dependencies.
        ADD ls_metrics-internal_sap_dependencies TO rs_transport-summary-internal_sap_dependencies.
        ADD ls_metrics-not_recommended_dependencies TO rs_transport-summary-not_recommended_dependencies.
        ADD ls_metrics-unreleased_api_dependencies TO rs_transport-summary-unreleased_api_dependencies.
        ADD ls_metrics-level_a TO rs_transport-summary-level_a.
        ADD ls_metrics-level_b TO rs_transport-summary-level_b.
        ADD ls_metrics-level_c TO rs_transport-summary-level_c.
        ADD ls_metrics-level_d TO rs_transport-summary-level_d.
        ADD ls_metrics-direct_sap_table_reads TO rs_transport-summary-direct_sap_table_reads.
        ADD ls_metrics-direct_sap_table_writes TO rs_transport-summary-direct_sap_table_writes.
        ADD ls_metrics-modification_count TO rs_transport-summary-modification_count.
        ADD ls_metrics-implicit_enhancements TO rs_transport-summary-implicit_enhancements.
        ADD ls_metrics-clean_core_findings TO rs_transport-summary-clean_core_findings.
        ADD ls_evaluation-estim_effort_minutes TO rs_transport-summary-ESTIM_effort_minutes.
        ADD ls_evaluation-estim_effort_low_minutes TO rs_transport-summary-ESTIM_effort_low_minutes.
        ADD ls_evaluation-estim_effort_high_minutes TO rs_transport-summary-ESTIM_effort_high_minutes.

        IF ls_metrics-modification_count > 0.
          ADD 1 TO rs_transport-summary-modified_object_count.
        ENDIF.
        IF ls_metrics-tmp_object = abap_true.
          ADD 1 TO rs_transport-summary-tmp_object_count.
        ENDIF.
        IF ls_metrics-copied_sap_standard_detected = abap_true.
          ADD 1 TO rs_transport-summary-copied_sap_standard_count.
        ENDIF.

        rs_transport-summary-worst_level = lo_analyzer->get_worse_level(
          iv_a = rs_transport-summary-worst_level
          iv_b = ls_metrics-worst_level ).
      ENDIF.

      APPEND ls_item TO rs_transport-objects.
    ENDLOOP.

    IF rs_transport-summary-analyzed_object_count = 0.
      CLEAR rs_transport-summary-worst_level.
    ENDIF.

    IF rs_transport-summary-skipped_entry_count > 0.
      lv_count = rs_transport-summary-skipped_entry_count.
      APPEND |{ lv_count } E071 entries are non-repository/unresolved and were skipped by the metric engine.| TO rs_transport-warnings.
    ENDIF.

    IF rs_transport-summary-invalid_transport_count > 0.
      lv_count = rs_transport-summary-invalid_transport_count.
      APPEND |{ lv_count } requested transport IDs were not found in E070.| TO rs_transport-warnings.
    ENDIF.

    IF rs_transport-summary-error_count > 0.
      lv_count = rs_transport-summary-error_count.
      APPEND |Metric determination failed for { lv_count } normalized repository objects.| TO rs_transport-warnings.
    ENDIF.
  ENDMETHOD.


  METHOD finalize_dependency_metrics.
    CLEAR:
      cs_metrics-sap_dependencies,
      cs_metrics-released_api_dependencies,
      cs_metrics-classic_api_dependencies,
      cs_metrics-internal_sap_dependencies,
      cs_metrics-not_recommended_dependencies,
      cs_metrics-unreleased_api_dependencies,
      cs_metrics-level_a,
      cs_metrics-level_b,
      cs_metrics-level_c,
      cs_metrics-level_d,
      cs_metrics-deprecated_api_usage,
      cs_metrics-direct_sap_table_reads,
      cs_metrics-direct_sap_table_writes,
      cs_metrics-released_extension_points,
      cs_metrics-unreleased_extension_points,
      cs_metrics-nonreleased_dep_density.

    cs_metrics-worst_level = c_level_a.

    LOOP AT ct_dependencies INTO DATA(ls_dep).
      ADD 1 TO cs_metrics-sap_dependencies.
      ADD ls_dep-read_count TO cs_metrics-direct_sap_table_reads.
      ADD ls_dep-write_count TO cs_metrics-direct_sap_table_writes.

      IF ls_dep-deprecated = abap_true.
        ADD 1 TO cs_metrics-deprecated_api_usage.
      ENDIF.

      CASE ls_dep-level.
        WHEN c_level_a.
          ADD 1 TO cs_metrics-level_a.
          ADD 1 TO cs_metrics-released_api_dependencies.

        WHEN c_level_b.
          ADD 1 TO cs_metrics-level_b.
          ADD 1 TO cs_metrics-classic_api_dependencies.
          ADD 1 TO cs_metrics-unreleased_api_dependencies.

        WHEN c_level_c.
          ADD 1 TO cs_metrics-level_c.
          ADD 1 TO cs_metrics-internal_sap_dependencies.
          ADD 1 TO cs_metrics-unreleased_api_dependencies.

        WHEN c_level_d.
          ADD 1 TO cs_metrics-level_d.
          ADD 1 TO cs_metrics-not_recommended_dependencies.
          ADD 1 TO cs_metrics-unreleased_api_dependencies.
      ENDCASE.

      IF ls_dep-is_extension_point = abap_true.
        IF ls_dep-released = abap_true.
          ADD 1 TO cs_metrics-released_extension_points.
        ELSE.
          ADD 1 TO cs_metrics-unreleased_extension_points.
        ENDIF.
      ENDIF.

      cs_metrics-worst_level = get_worse_level(
        iv_a = cs_metrics-worst_level
        iv_b = ls_dep-level ).
    ENDLOOP.

    IF cs_metrics-statement_count > 0.
      cs_metrics-nonreleased_dep_density =
        CONV decfloat34( cs_metrics-unreleased_api_dependencies )
        * 1000 / cs_metrics-statement_count.
    ENDIF.
  ENDMETHOD.


  METHOD get_json_state.
    DATA(lv_type) = to_upper( CONV string( is_dep-dep_type ) ).
    DATA(lv_key)  = to_upper( CONV string( is_dep-dep_name ) ).

    " In the SAP classification file CDS entities are normally represented as STOB.
    IF lv_type = 'DDLS'.
      DATA(ls_ddls) = /s4p0/cl_ccc_extract=>get_api_class(
        iv_object_type = 'DDLS'
        iv_object_key  = lv_key ).
      IF ls_ddls-object_key IS NOT INITIAL.
        rv_state = ls_ddls-state.
        RETURN.
      ENDIF.
      lv_type = 'STOB'.
    ENDIF.

    DATA(ls_class) = /s4p0/cl_ccc_extract=>get_api_class(
      iv_object_type = lv_type
      iv_object_key  = lv_key ).
    rv_state = ls_class-state.
  ENDMETHOD.


  METHOD get_token_counts.
    DATA lv_main TYPE program.
    DATA lt_source TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    DATA lt_token TYPE STANDARD TABLE OF stoken WITH EMPTY KEY.
    DATA lt_stmt TYPE STANDARD TABLE OF sstmnt WITH EMPTY KEY.
    DATA lt_level TYPE STANDARD TABLE OF slevel WITH EMPTY KEY.
    DATA ls_token TYPE stoken.
    DATA lv_token_string TYPE string.
    DATA lv_token TYPE c LENGTH 255.
    FIELD-SYMBOLS <count> TYPE ty_token_count.

    CLEAR: et_counts, ev_total.
    lv_main = /s4p0/cl_ccc_extract=>get_main_program( is_source ).
    IF lv_main IS INITIAL.
      RETURN.
    ENDIF.

    lt_source = /s4p0/cl_ccc_extract=>read_source( lv_main ).
    IF lt_source IS INITIAL.
      RETURN.
    ENDIF.

    SCAN ABAP-SOURCE lt_source
      TOKENS INTO lt_token
      STATEMENTS INTO lt_stmt
      LEVELS INTO lt_level
      WITH INCLUDES.
    IF sy-subrc > 1.
      RETURN.
    ENDIF.

    LOOP AT lt_token INTO ls_token.
      lv_token_string = to_upper( CONV string( ls_token-str ) ).
      IF lv_token_string IS INITIAL.
        CONTINUE.
      ENDIF.

      " Normalize the object's own name so that a renamed clone does not lose
      " similarity just because REPORT/CLASS/FUNCTION-POOL names differ.
      IF lv_token_string = to_upper( CONV string( is_source-obj_name ) ) OR
         lv_token_string = to_upper( CONV string( lv_main ) ).
        lv_token_string = '#SELF#'.
      ENDIF.

      lv_token = lv_token_string.
      READ TABLE et_counts ASSIGNING <count>
        WITH TABLE KEY token = lv_token.
      IF sy-subrc = 0.
        ADD 1 TO <count>-count.
      ELSE.
        INSERT VALUE ty_token_count( token = lv_token count = 1 )
          INTO TABLE et_counts.
      ENDIF.
      ADD 1 TO ev_total.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_worse_level.
    rv_level = iv_a.
    IF rv_level IS INITIAL.
      rv_level = c_level_a.
    ENDIF.

    CASE iv_b.
      WHEN c_level_d.
        rv_level = c_level_d.
      WHEN c_level_c.
        IF rv_level <> c_level_d.
          rv_level = c_level_c.
        ENDIF.
      WHEN c_level_b.
        IF rv_level <> c_level_d AND rv_level <> c_level_c.
          rv_level = c_level_b.
        ENDIF.
      WHEN c_level_a.
        IF rv_level IS INITIAL.
          rv_level = c_level_a.
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD is_extension_type.
    DATA(lv_type) = to_upper( CONV string( iv_type ) ).
    rv_yes = xsdbool( lv_type = 'BADI' OR lv_type = 'ENHS' ).
  ENDMETHOD.


METHOD is_metrics_persistence_active.

  rv_active = gv_metrics_persistence_on.

ENDMETHOD.


METHOD progress_indicator.
  DATA:
    lv_percentage TYPE i,
    lv_text       TYPE c LENGTH 80.

  IF iv_total <= 0.
    RETURN.
  ENDIF.

  lv_percentage = iv_current * 100 / iv_total.
  WRITE iv_text TO lv_text.

  CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
    EXPORTING
      percentage = lv_percentage
      text       = lv_text.
ENDMETHOD.


  METHOD touch_table.
    LOOP AT it_touch INTO DATA(ls_touch).
      LOOP AT ct_dependencies ASSIGNING FIELD-SYMBOL(<dep>)
        WHERE dep_type = ls_touch-dep_type
          AND dep_name = ls_touch-dep_name.

        IF iv_write = abap_true.
          ADD 1 TO <dep>-write_count.
          <dep>-level          = c_level_d.
          <dep>-classification = 'DIRECT_DB_WRITE'.
        ELSE.
          ADD 1 TO <dep>-read_count.
          IF <dep>-level <> c_level_d.
            <dep>-level          = c_level_c.
            <dep>-classification = 'DIRECT_DB_READ'.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
