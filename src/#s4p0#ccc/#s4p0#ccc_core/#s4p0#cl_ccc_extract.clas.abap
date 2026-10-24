*---------------------------------------------------------------------*
* /S4P0/CL_CCC_EXTRACT
*
* Clean Core Control - layer 1: data extraction.
*
* This layer owns every read against the system: TADIR, SMODILOG,
* E070/E070A/E071, TRDIR/TRDIRT, ENHHEADER/ENHOBJ, ENLFDIR, SEOCLASSTX,
* TLIBT, the repository environment, program sources, and the SAP object
* classification catalog. Layers 2 (metrics) and 3 (weighting) do not
* issue a SELECT of their own.
*
* Nothing here interprets or weights a value; the layer only returns raw
* facts. BUILD_POPULATION is the system-wide collector that used to be
* duplicated - and had drifted apart - inside the local classes of
* /S4P0/CCC_SYSTEM_CHECKRUN and /S4P0/CCC_UPGRADE_DASHBRD.
*---------------------------------------------------------------------*
class /S4P0/CL_CCC_EXTRACT definition
  public
  final
  create public .

public section.

  types TY_R_OBJECT type range of TADIR-OBJECT .
  types TY_R_DEVCLASS type range of TADIR-DEVCLASS .
  types:
    BEGIN OF ty_dependency_key,
        dep_type TYPE /s4p0/de_ccc_dep_type,
        dep_name TYPE /s4p0/de_ccc_dep_name,
      END OF ty_dependency_key .
  types:
    ty_t_dependency_key TYPE SORTED TABLE OF ty_dependency_key
      WITH UNIQUE KEY dep_type dep_name .
  types:
    ty_t_source_line TYPE STANDARD TABLE OF string WITH EMPTY KEY .
  types:
    ty_t_program TYPE SORTED TABLE OF PROGRAM WITH UNIQUE KEY table_line .
  types:
    BEGIN OF ty_api_class,
        object_type    TYPE string,
        object_key     TYPE string,
        tadir_object   TYPE tadir-object,
        tadir_obj_name TYPE tadir-obj_name,
        state          TYPE string,
      END OF ty_api_class .
  types:
    ty_t_api_class TYPE HASHED TABLE OF ty_api_class
      WITH UNIQUE KEY object_type object_key .
  types:
    BEGIN OF ty_copy_candidate,
        object    TYPE tadir-object,
        obj_name  TYPE tadir-obj_name,
        devclass  TYPE tadir-devclass,
        author    TYPE tadir-author,
        srcsystem TYPE tadir-srcsystem,
        reason    TYPE c LENGTH 20,
      END OF ty_copy_candidate .
  types:
    ty_t_copy_candidate TYPE STANDARD TABLE OF ty_copy_candidate WITH EMPTY KEY .
  types:
    ty_t_trkorr TYPE STANDARD TABLE OF e070-trkorr WITH EMPTY KEY .
  types:
    BEGIN OF ty_transport_entry,
        trkorr   TYPE e071-trkorr,
        as4pos   TYPE e071-as4pos,
        pgmid    TYPE e071-pgmid,
        object   TYPE e071-object,
        obj_name TYPE e071-obj_name,
      END OF ty_transport_entry .
  types:
    ty_t_transport_entry TYPE STANDARD TABLE OF ty_transport_entry WITH EMPTY KEY .
  types:
    ty_t_message TYPE STANDARD TABLE OF string WITH EMPTY KEY .
  types:
    BEGIN OF ty_transport_work,
        pgmid                 TYPE tadir-pgmid,
        object                TYPE tadir-object,
        obj_name              TYPE tadir-obj_name,
        source_trkorr         TYPE e070-trkorr,
        source_pgmid          TYPE e071-pgmid,
        source_object         TYPE e071-object,
        source_obj_name       TYPE e071-obj_name,
        transport_entry_count TYPE i,
      END OF ty_transport_work .
  types:
    ty_t_transport_work TYPE SORTED TABLE OF ty_transport_work
      WITH UNIQUE KEY pgmid object obj_name .
  types:
    BEGIN OF ty_transport_skipped,
        trkorr   TYPE e070-trkorr,
        as4pos   TYPE e071-as4pos,
        pgmid    TYPE e071-pgmid,
        object   TYPE e071-object,
        obj_name TYPE e071-obj_name,
        reason   TYPE c LENGTH 60,
      END OF ty_transport_skipped .
  types:
    ty_t_transport_skipped TYPE STANDARD TABLE OF ty_transport_skipped WITH EMPTY KEY .
  types:
    BEGIN OF ty_transport_counts,
        requested_trkorr          TYPE e070-trkorr,
        root_trkorr               TYPE e070-trkorr,
        requested_transport_count TYPE i,
        root_transport_count      TYPE i,
        invalid_transport_count   TYPE i,
        scope_transport_count     TYPE i,
        transport_entry_count     TYPE i,
        repository_entry_count    TYPE i,
        unique_object_count       TYPE i,
        skipped_entry_count       TYPE i,
      END OF ty_transport_counts .

  constants C_R3TR type E071-PGMID value 'R3TR' ##NO_TEXT.
  constants C_LIMU type E071-PGMID value 'LIMU' ##NO_TEXT.
  constants C_SAP type C LENGTH 3 value 'SAP' ##NO_TEXT.
  constants C_NOTE_ATTRIBUTE type E070A-ATTRIBUTE value 'SAPNOTE' ##NO_TEXT.

    " Build the system-wide object population from TADIR and SMODILOG.
    " Replaces the population logic that was duplicated in the check run and
    " the upgrade dashboard.
  class-methods BUILD_POPULATION
    importing
      !IT_OBJECT_RANGE type TY_R_OBJECT optional
      !IT_DEVCLASS_RANGE type TY_R_DEVCLASS optional
      !IV_INCLUDE_TADIR type ABAP_BOOL default ABAP_TRUE
      !IV_INCLUDE_MODS type ABAP_BOOL default ABAP_TRUE
      !IV_EXCLUDE_NOTES type ABAP_BOOL default ABAP_TRUE
      !IV_SOURCE_ONLY type ABAP_BOOL default ABAP_FALSE
      !IV_MAX_OBJECTS type I default 0
    exporting
      !ET_OBJECTS type /S4P0/TT_CCC_OBJECT
      !EV_NOTE_EXCLUDED type I
      !EV_UNRESOLVED type I .
    " Normalize any repository key to its owning R3TR object.
  class-methods NORMALIZE_OBJECT
    importing
      !IV_PGMID type E071-PGMID
      !IV_OBJECT type E071-OBJECT
      !IV_OBJ_NAME type E071-OBJ_NAME
    exporting
      !ES_SOURCE type /S4P0/S_CCC_TADIR
      !EV_NORMALIZED type ABAP_BOOL
      !EV_NO_TADIR type ABAP_BOOL .
    " Main program of a source-carrying object, initial when not supported.
  class-methods GET_MAIN_PROGRAM
    importing
      !IS_SOURCE type /S4P0/S_CCC_TADIR
    returning
      value(RV_PROGRAM) type PROGRAM .
    " A program together with all of its includes. Used for line counting;
    " SCAN ABAP-SOURCE resolves includes itself and only needs the main program.
  class-methods GET_PROGRAM_LIST
    importing
      !IV_PROGRAM type PROGRAM
    returning
      value(RT_PROGRAMS) type TY_T_PROGRAM .
    " Raw source lines of exactly one program.
  class-methods READ_SOURCE
    importing
      !IV_PROGRAM type PROGRAM
    returning
      value(RT_SOURCE) type TY_T_SOURCE_LINE .
    " TRDIR unicode check flag, used to recognize ABAP Cloud enabled objects.
  class-methods GET_PROGRAM_UCCHECK
    importing
      !IV_PROGRAM type PROGRAM
    returning
      value(RV_UCCHECK) type TRDIR-UCCHECK .
    " Repository environment of an object, restricted to Clean Core relevant types.
  class-methods GET_DEPENDENCIES
    importing
      !IS_SOURCE type /S4P0/S_CCC_TADIR
    returning
      value(RT_DEP) type TY_T_DEPENDENCY_KEY .
    " True when the dependency is owned by SAP.
  class-methods IS_SAP_DEPENDENCY
    importing
      !IS_DEP type TY_DEPENDENCY_KEY
    returning
      value(RV_SAP) type ABAP_BOOL .
    " Active SMODILOG modification locations attributable to the object.
  class-methods COUNT_MODIFICATIONS
    importing
      !IV_PGMID type E071-PGMID
      !IV_OBJECT type E071-OBJECT
      !IV_OBJ_NAME type E071-OBJ_NAME
      !IS_SOURCE type /S4P0/S_CCC_TADIR
    returning
      value(RV_COUNT) type I .
    " Active implicit (HOOK_IMPL) enhancements attached to the object.
  class-methods COUNT_IMPLICIT_ENHANCEMENTS
    importing
      !IV_PGMID type E071-PGMID
      !IV_OBJECT type E071-OBJECT
      !IV_OBJ_NAME type E071-OBJ_NAME
      !IS_SOURCE type /S4P0/S_CCC_TADIR
    returning
      value(RV_COUNT) type I .
    " Source-carrying peer objects of a package, used for the blast radius.
  class-methods GET_PACKAGE_SOURCES
    importing
      !IV_DEVCLASS type TADIR-DEVCLASS
    returning
      value(RT_SOURCE) type /S4P0/TT_CCC_TADIR .
    " Possible SAP originals for a customer object (name and short-text signals).
  class-methods GET_COPY_CANDIDATES
    importing
      !IS_SOURCE type /S4P0/S_CCC_TADIR
    returning
      value(RT_CANDIDATES) type TY_T_COPY_CANDIDATE .
    " True for a generated view-maintenance function group (TVDIR).
  class-methods IS_GENERATED_VIEW_MAINT
    importing
      !IV_OBJ_NAME type TADIR-OBJ_NAME
    returning
      value(RV_GENERATED) type ABAP_BOOL .
    " TADIR master record of an R3TR object.
  class-methods READ_TADIR
    importing
      !IV_OBJECT type TADIR-OBJECT
      !IV_OBJ_NAME type TADIR-OBJ_NAME
    exporting
      !ES_TADIR type TADIR
      !EV_FOUND type ABAP_BOOL .
    " E070 header of one request or task.
  class-methods READ_TRANSPORT
    importing
      !IV_TRKORR type E070-TRKORR
    exporting
      !ES_REQUEST type E070
      !EV_FOUND type ABAP_BOOL .
    " Direct tasks below a root request.
  class-methods GET_TRANSPORT_TASKS
    importing
      !IV_TRKORR type E070-TRKORR
    returning
      value(RT_TASKS) type TY_T_TRKORR .
    " Resolve transport requests/tasks into a unique repository population.
    " The transport counterpart of BUILD_POPULATION.
  class-methods BUILD_TRANSPORT_POPULATION
    importing
      !IT_TRKORR type TY_T_TRKORR
      !IV_INCLUDE_TASKS type ABAP_BOOL default ABAP_TRUE
    exporting
      !ET_WORK type TY_T_TRANSPORT_WORK
      !ET_SKIPPED type TY_T_TRANSPORT_SKIPPED
      !ES_COUNTS type TY_TRANSPORT_COUNTS
      !ET_WARNINGS type TY_T_MESSAGE .
    " E071 object-list entries of a transport scope.
  class-methods READ_TRANSPORT_ENTRIES
    importing
      !IT_TRKORR type TY_T_TRKORR
    returning
      value(RT_ENTRIES) type TY_T_TRANSPORT_ENTRY .
    " Load SAP's object classification catalog once per session.
  class-methods LOAD_CLASSIFICATION .
    " Classification entry for one object, initial when unknown.
  class-methods GET_API_CLASS
    importing
      !IV_OBJECT_TYPE type CSEQUENCE
      !IV_OBJECT_KEY type CSEQUENCE
    returning
      value(RS_API_CLASS) type TY_API_CLASS .
  class-methods IS_CLASSIFICATION_LOADED
    returning
      value(RV_LOADED) type ABAP_BOOL .
    " Clear the in-session classification cache.
  class-methods CLEAR_CACHE .

private section.

  types:
    BEGIN OF ty_note_request,
        trkorr TYPE e070-trkorr,
      END OF ty_note_request .
  types:
    ty_t_note_request TYPE SORTED TABLE OF ty_note_request
      WITH UNIQUE KEY trkorr .
  " The merge needs a keyed access path. The public table type stays a plain
  " standard table because that is what the consuming reports and ALV want.
  types:
    ty_t_object_sorted TYPE SORTED TABLE OF /s4p0/s_ccc_object
      WITH UNIQUE KEY pgmid object obj_name .
  types:
    BEGIN OF ty_task,
        trkorr  TYPE e070-trkorr,
        strkorr TYPE e070-strkorr,
      END OF ty_task .
  types:
    BEGIN OF ty_mod,
        obj_type  TYPE smodilog-obj_type,
        obj_name  TYPE smodilog-obj_name,
        sub_type  TYPE smodilog-sub_type,
        sub_name  TYPE smodilog-sub_name,
        int_type  TYPE smodilog-int_type,
        int_name  TYPE smodilog-int_name,
        operation TYPE smodilog-operation,
        mod_name  TYPE smodilog-mod_name,
        trkorr    TYPE smodilog-trkorr,
        pre_corr  TYPE smodilog-pre_corr,
      END OF ty_mod .
  types:
    ty_t_mod TYPE STANDARD TABLE OF ty_mod WITH EMPTY KEY .
  types:
    BEGIN OF ty_json_successor,
        tadir_object   TYPE string,
        tadir_obj_name TYPE string,
        object_type    TYPE string,
        object_key     TYPE string,
      END OF ty_json_successor .
  types:
    ty_t_json_successor TYPE STANDARD TABLE OF ty_json_successor WITH EMPTY KEY .
  types:
    ty_t_json_string TYPE STANDARD TABLE OF string WITH EMPTY KEY .
  types:
    BEGIN OF ty_json_item,
        tadir_object          TYPE string,
        tadir_obj_name        TYPE string,
        object_type           TYPE string,
        object_key            TYPE string,
        software_component    TYPE string,
        application_component TYPE string,
        state                 TYPE string,
        successors            TYPE ty_t_json_successor,
        labels                TYPE ty_t_json_string,
      END OF ty_json_item .
  types:
    ty_t_json_item TYPE STANDARD TABLE OF ty_json_item WITH EMPTY KEY .
  types:
    BEGIN OF ty_json_root,
        format_version          TYPE string,
        object_classifications  TYPE ty_t_json_item,
      END OF ty_json_root .

  constants C_CLASSIFICATION_URL type STRING
    value 'https://raw.githubusercontent.com/SAP/abap-atc-cr-cv-s4hc/main/src/objectClassifications_SAP.json' ##NO_TEXT.

  class-data MT_API_CLASS type TY_T_API_CLASS .
  class-data MV_CLASSIFICATION_LOADED type ABAP_BOOL .
  class-data MV_CLASSIFICATION_TRIED type ABAP_BOOL .

  class-methods LOAD_JSON_FROM_HTTP
    importing
      !IV_URL type STRING
    returning
      value(RV_JSON) type STRING .
    " Transport requests and tasks created by the Note Assistant.
  class-methods BUILD_NOTE_REQUEST_CACHE
    returning
      value(RT_NOTES) type TY_T_NOTE_REQUEST .
  class-methods IS_NOTE_MODIFICATION
    importing
      !IS_MOD type TY_MOD
      !IT_NOTES type TY_T_NOTE_REQUEST
    returning
      value(RV_NOTE) type ABAP_BOOL .
  class-methods NORMALIZE_MODIFICATION
    importing
      !IS_MOD type TY_MOD
    exporting
      !ES_TADIR type TADIR
      !EV_FOUND type ABAP_BOOL .
  class-methods ADD_OR_MERGE_OBJECT
    importing
      !IS_TADIR type TADIR
      !IV_FROM_TADIR type ABAP_BOOL
      !IV_FROM_MOD type ABAP_BOOL
    changing
      !CT_OBJECTS type TY_T_OBJECT_SORTED .
    " True when the object type carries scannable ABAP source.
  class-methods IS_SOURCE_TYPE
    importing
      !IV_OBJECT type TADIR-OBJECT
    returning
      value(RV_SOURCE) type ABAP_BOOL .
  class-methods ADD_COPY_CANDIDATE
    importing
      !IS_SOURCE type /S4P0/S_CCC_TADIR
      !IV_NAME type TADIR-OBJ_NAME
      !IV_REASON type CSEQUENCE
    changing
      !CT_CANDIDATES type TY_T_COPY_CANDIDATE .
  class-methods SET_ENVIRONMENT_FLAG
    importing
      !IV_NAME type CSEQUENCE
    changing
      !CS_TYPES type ENVI_TYPES .
endclass.



class /S4P0/CL_CCC_EXTRACT implementation.
METHOD is_source_type.

  rv_source = xsdbool( iv_object = 'PROG' OR iv_object = 'CLAS'
                    OR iv_object = 'INTF' OR iv_object = 'FUGR' ).

ENDMETHOD.

METHOD build_note_request_cache.

  DATA:
    lt_roots TYPE STANDARD TABLE OF ty_note_request,
    ls_root  TYPE ty_note_request,
    lt_tasks TYPE STANDARD TABLE OF ty_task,
    ls_task  TYPE ty_task.

  " Note Assistant flags its transport request with E070A-ATTRIBUTE SAPNOTE.
  SELECT trkorr
    INTO TABLE lt_roots
    FROM e070a
    WHERE attribute = c_note_attribute.

  LOOP AT lt_roots INTO ls_root.
    INSERT ls_root INTO TABLE rt_notes.
  ENDLOOP.

  IF lt_roots IS INITIAL.
    RETURN.
  ENDIF.

  " Add all tasks below Note requests, because SMODILOG-TRKORR may contain
  " either the request or a task number.
  SELECT trkorr strkorr
    INTO TABLE lt_tasks
    FROM e070
    FOR ALL ENTRIES IN lt_roots
    WHERE strkorr = lt_roots-trkorr.

  LOOP AT lt_tasks INTO ls_task.
    CLEAR ls_root.
    ls_root-trkorr = ls_task-trkorr.
    INSERT ls_root INTO TABLE rt_notes.
  ENDLOOP.

ENDMETHOD.

METHOD is_note_modification.

  DATA ls_note TYPE ty_note_request.

  CLEAR rv_note.

  " Direct Note Assistant modification log entry.
  IF is_mod-operation = 'NOTE'.
    rv_note = abap_true.
    RETURN.
  ENDIF.

  " PRE_CORR explicitly describes installation mode for corrections to a Note.
  IF is_mod-pre_corr IS NOT INITIAL.
    rv_note = abap_true.
    RETURN.
  ENDIF.

  " SAP Modification Analysis excludes NEW standard function modules because
  " those are typically introduced by SAP Note correction instructions.
  IF is_mod-operation = 'NEW'.
    rv_note = abap_true.
    RETURN.
  ENDIF.

  " Request/task belongs to a transport created by Note Assistant.
  IF is_mod-trkorr IS NOT INITIAL.
    READ TABLE it_notes
      WITH TABLE KEY trkorr = is_mod-trkorr
      INTO ls_note.
    IF sy-subrc = 0.
      rv_note = abap_true.
    ENDIF.
  ENDIF.

ENDMETHOD.

METHOD normalize_modification.

  DATA:
    ls_e071  TYPE e071,
    ls_owner TYPE tadir.

  CLEAR: es_tadir, ev_found.

  " Most SMODILOG entries already contain the owning R3TR type/name.
  SELECT SINGLE *
    INTO es_tadir
    FROM tadir
    WHERE pgmid    = c_r3tr
      AND object   = is_mod-obj_type
      AND obj_name = is_mod-obj_name.

  IF sy-subrc = 0.
    ev_found = abap_true.
    RETURN.
  ENDIF.

  " Try the logged subobject first (REPS, METH, FUNC, ...).
  IF is_mod-sub_type IS NOT INITIAL AND
     is_mod-sub_name IS NOT INITIAL.
    CLEAR: ls_e071, ls_owner.
    ls_e071-pgmid    = c_limu.
    ls_e071-object   = is_mod-sub_type.
    ls_e071-obj_name = is_mod-sub_name.

    CALL FUNCTION 'TR_CHECK_TYPE'
      EXPORTING
        wi_e071  = ls_e071
      IMPORTING
        we_tadir = ls_owner.

    IF ls_owner-object IS NOT INITIAL AND
       ls_owner-obj_name IS NOT INITIAL.
      SELECT SINGLE *
        INTO es_tadir
        FROM tadir
        WHERE pgmid    = c_r3tr
          AND object   = ls_owner-object
          AND obj_name = ls_owner-obj_name.
      IF sy-subrc = 0.
        ev_found = abap_true.
        RETURN.
      ENDIF.
    ENDIF.
  ENDIF.

  " Fallback: some older logs keep a LIMU-like type in OBJ_TYPE/OBJ_NAME.
  CLEAR: ls_e071, ls_owner.
  ls_e071-pgmid    = c_limu.
  ls_e071-object   = is_mod-obj_type.
  ls_e071-obj_name = is_mod-obj_name.

  CALL FUNCTION 'TR_CHECK_TYPE'
    EXPORTING
      wi_e071  = ls_e071
    IMPORTING
      we_tadir = ls_owner.

  IF ls_owner-object IS NOT INITIAL AND
     ls_owner-obj_name IS NOT INITIAL.
    SELECT SINGLE *
      INTO es_tadir
      FROM tadir
      WHERE pgmid    = c_r3tr
        AND object   = ls_owner-object
        AND obj_name = ls_owner-obj_name.
    IF sy-subrc = 0.
      ev_found = abap_true.
    ENDIF.
  ENDIF.

ENDMETHOD.

METHOD add_or_merge_object.

  FIELD-SYMBOLS <ls_object> TYPE /s4p0/s_ccc_object.
  DATA ls_object TYPE /s4p0/s_ccc_object.

  READ TABLE ct_objects ASSIGNING <ls_object>
    WITH TABLE KEY
      pgmid    = c_r3tr
      object   = is_tadir-object
      obj_name = is_tadir-obj_name.


  IF sy-subrc <> 0.
    CLEAR ls_object.
    ls_object-pgmid     = c_r3tr.
    ls_object-object    = is_tadir-object.
    ls_object-obj_name  = is_tadir-obj_name.
    ls_object-devclass  = is_tadir-devclass.
    ls_object-author    = is_tadir-author.
    ls_object-srcsystem = is_tadir-srcsystem.
    ls_object-from_tadir        = iv_from_tadir.
    ls_object-from_modification = iv_from_mod.
    IF iv_from_mod = abap_true.
      ls_object-modification_logs = 1.
    ENDIF.
    INSERT ls_object INTO TABLE ct_objects.
    RETURN.
  ENDIF.

  IF iv_from_tadir = abap_true.
    <ls_object>-from_tadir = abap_true.
  ENDIF.
  IF iv_from_mod = abap_true.
    <ls_object>-from_modification = abap_true.
    ADD 1 TO <ls_object>-modification_logs.
  ENDIF.

ENDMETHOD.

METHOD build_population.

  DATA:
    lt_objects TYPE ty_t_object_sorted,
    lt_notes TYPE ty_t_note_request,
    lt_tadir TYPE STANDARD TABLE OF tadir,
    ls_tadir TYPE tadir,
    lt_mod   TYPE ty_t_mod,
    ls_mod   TYPE ty_mod,
    ls_owner TYPE tadir,
    lv_found TYPE abap_bool,
    lv_lines TYPE i.

  CLEAR: et_objects, ev_note_excluded, ev_unresolved.

  IF iv_include_mods = abap_true AND iv_exclude_notes = abap_true.
    lt_notes = build_note_request_cache( ).
  ENDIF.

  " --- population 1: non-SAP repository objects -----------------------
  " Non-SAP means neither the responsible author nor the source system is SAP.
  " This intentionally includes customer namespaces and third-party add-ons.
  IF iv_include_tadir = abap_true.
    SELECT *
      INTO TABLE lt_tadir
      FROM tadir
      WHERE pgmid     = c_r3tr
        AND object    IN it_object_range
        AND devclass  IN it_devclass_range
        AND author    <> c_sap
        AND srcsystem <> c_sap.

    LOOP AT lt_tadir INTO ls_tadir.
      IF iv_source_only = abap_true AND is_source_type( ls_tadir-object ) = abap_false.
        CONTINUE.
      ENDIF.

      add_or_merge_object(
        EXPORTING
          is_tadir      = ls_tadir
          iv_from_tadir = abap_true
          iv_from_mod   = abap_false
        CHANGING
          ct_objects    = lt_objects ).
    ENDLOOP.
  ENDIF.

  " --- population 2: active modifications -----------------------------
  IF iv_include_mods = abap_true.
    " Only active modification log entries.
    SELECT obj_type obj_name sub_type sub_name int_type int_name
           operation mod_name trkorr pre_corr
      INTO TABLE lt_mod
      FROM smodilog
      WHERE inactive = space.

    LOOP AT lt_mod INTO ls_mod.
      IF iv_exclude_notes = abap_true.
        IF is_note_modification( is_mod = ls_mod it_notes = lt_notes ) = abap_true.
          ADD 1 TO ev_note_excluded.
          CONTINUE.
        ENDIF.
      ENDIF.

      normalize_modification(
        EXPORTING is_mod   = ls_mod
        IMPORTING es_tadir = ls_owner
                  ev_found = lv_found ).

      IF lv_found = abap_false.
        ADD 1 TO ev_unresolved.
        CONTINUE.
      ENDIF.

      IF it_object_range IS NOT INITIAL.
        CHECK ls_owner-object IN it_object_range.
      ENDIF.
      IF it_devclass_range IS NOT INITIAL.
        CHECK ls_owner-devclass IN it_devclass_range.
      ENDIF.

      IF iv_source_only = abap_true AND is_source_type( ls_owner-object ) = abap_false.
        CONTINUE.
      ENDIF.

      add_or_merge_object(
        EXPORTING
          is_tadir      = ls_owner
          iv_from_tadir = abap_false
          iv_from_mod   = abap_true
        CHANGING
          ct_objects    = lt_objects ).
    ENDLOOP.
  ENDIF.

  " --- throttle -------------------------------------------------------
  IF iv_max_objects > 0.
    DESCRIBE TABLE lt_objects LINES lv_lines.
    WHILE lv_lines > iv_max_objects.
      DELETE lt_objects INDEX lv_lines.
      SUBTRACT 1 FROM lv_lines.
    ENDWHILE.
  ENDIF.

  et_objects = lt_objects.

ENDMETHOD.

METHOD normalize_object.

  DATA ls_tadir_key TYPE tadir.
  DATA ls_tadir     TYPE tadir.
  DATA ls_e071      TYPE e071.

  CLEAR: es_source, ev_normalized, ev_no_tadir.

  IF iv_pgmid = c_r3tr.
    SELECT SINGLE *
      FROM tadir
      WHERE pgmid    = @iv_pgmid
        AND object   = @iv_object
        AND obj_name = @iv_obj_name
      INTO @ls_tadir.

    IF sy-subrc = 0.
      es_source = CORRESPONDING #( ls_tadir ).
      RETURN.
    ENDIF.
  ENDIF.

  " Map LIMU/subobjects (REPS, METH, FUNC, ...) to their owning R3TR object.
  ls_e071-pgmid    = iv_pgmid.
  ls_e071-object   = iv_object.
  ls_e071-obj_name = iv_obj_name.

  CALL FUNCTION 'TR_CHECK_TYPE'
    EXPORTING
      wi_e071  = ls_e071
    IMPORTING
      we_tadir = ls_tadir_key.

  IF ls_tadir_key-object IS NOT INITIAL AND
     ls_tadir_key-obj_name IS NOT INITIAL.
    SELECT SINGLE *
      FROM tadir
      WHERE pgmid    = @c_r3tr
        AND object   = @ls_tadir_key-object
        AND obj_name = @ls_tadir_key-obj_name
      INTO @ls_tadir.

    IF sy-subrc = 0.
      es_source = CORRESPONDING #( ls_tadir ).
      ev_normalized = xsdbool(
           iv_pgmid <> es_source-pgmid
        OR iv_object <> es_source-object
        OR iv_obj_name <> es_source-obj_name ).
      RETURN.
    ENDIF.
  ENDIF.

  " Last chance for uncommon R3TR types that have no TADIR row visible
  " through the initial exact select but were still supplied as R3TR.
  " The caller decides how to report the missing master record.
  IF iv_pgmid = c_r3tr.
    es_source-pgmid    = c_r3tr.
    es_source-object   = iv_object.
    es_source-obj_name = iv_obj_name.
    ev_no_tadir = abap_true.
  ENDIF.

ENDMETHOD.

METHOD get_main_program.

  CASE is_source-object.
    WHEN 'PROG'.
      rv_program = is_source-obj_name.

    WHEN 'CLAS'.
      rv_program = cl_oo_classname_service=>get_classpool_name(
        CONV seoclsname( is_source-obj_name ) ).

    WHEN 'INTF'.
      rv_program = cl_oo_classname_service=>get_interfacepool_name(
        CONV seoclsname( is_source-obj_name ) ).

    WHEN 'FUGR'.
      DATA lv_area TYPE rs38l-area.
      lv_area = is_source-obj_name.
      CALL FUNCTION 'FUNCTION_INCLUDE_CONCATENATE'
        CHANGING
          program       = rv_program
          complete_area = lv_area
        EXCEPTIONS
          OTHERS        = 1.
      IF sy-subrc <> 0.
        CLEAR rv_program.
      ENDIF.
  ENDCASE.

ENDMETHOD.

METHOD get_program_list.

  DATA lt_includes TYPE STANDARD TABLE OF program WITH EMPTY KEY.
  DATA lv_include  TYPE program.

  IF iv_program IS INITIAL.
    RETURN.
  ENDIF.

  INSERT iv_program INTO TABLE rt_programs.

  CALL FUNCTION 'RS_GET_ALL_INCLUDES'
    EXPORTING
      program    = iv_program
    TABLES
      includetab = lt_includes
    EXCEPTIONS
      OTHERS     = 0.

  LOOP AT lt_includes INTO lv_include.
    INSERT lv_include INTO TABLE rt_programs.
  ENDLOOP.

ENDMETHOD.

METHOD read_source.

  IF iv_program IS INITIAL.
    RETURN.
  ENDIF.

  READ REPORT iv_program INTO rt_source.
  IF sy-subrc <> 0.
    CLEAR rt_source.
  ENDIF.

ENDMETHOD.

METHOD get_program_uccheck.

  SELECT SINGLE uccheck
    FROM trdir
    WHERE name = @iv_program
    INTO @rv_uccheck.

  IF sy-subrc <> 0.
    CLEAR rv_uccheck.
  ENDIF.

ENDMETHOD.

METHOD set_environment_flag.

  FIELD-SYMBOLS <lv_flag> TYPE any.

  " Dynamic component assignment keeps this tolerant of ENVI_TYPES
  " differences between ABAP releases.
  ASSIGN COMPONENT iv_name OF STRUCTURE cs_types TO <lv_flag>.
  IF sy-subrc = 0.
    <lv_flag> = abap_true.
  ENDIF.

ENDMETHOD.

METHOD get_dependencies.

  DATA ls_types TYPE envi_types.
  DATA lt_env   TYPE STANDARD TABLE OF senvi WITH EMPTY KEY.

  " Application/API objects
  set_environment_flag( EXPORTING iv_name = 'CLAS' CHANGING cs_types = ls_types ).
  set_environment_flag( EXPORTING iv_name = 'INTF' CHANGING cs_types = ls_types ).
  set_environment_flag( EXPORTING iv_name = 'FUNC' CHANGING cs_types = ls_types ).
  set_environment_flag( EXPORTING iv_name = 'PROG' CHANGING cs_types = ls_types ).

  " Persistence / CDS / RAP
  set_environment_flag( EXPORTING iv_name = 'TABL' CHANGING cs_types = ls_types ).
  set_environment_flag( EXPORTING iv_name = 'VIEW' CHANGING cs_types = ls_types ).
  set_environment_flag( EXPORTING iv_name = 'DDLS' CHANGING cs_types = ls_types ).
  set_environment_flag( EXPORTING iv_name = 'STOB' CHANGING cs_types = ls_types ).
  set_environment_flag( EXPORTING iv_name = 'BDEF' CHANGING cs_types = ls_types ).

  " Enhancement-related types.
  set_environment_flag( EXPORTING iv_name = 'BADI' CHANGING cs_types = ls_types ).
  set_environment_flag( EXPORTING iv_name = 'ENHS' CHANGING cs_types = ls_types ).

  CALL FUNCTION 'REPOSITORY_ENVIRONMENT_SET'
    EXPORTING
      obj_type          = CONV euobj-id( is_source-object )
      object_name       = is_source-obj_name
      environment_types = ls_types
      online_force      = 'X'
    TABLES
      environment       = lt_env
    EXCEPTIONS
      batch             = 1
      batchjob_error    = 2
      not_executed      = 3
      OTHERS            = 4.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  LOOP AT lt_env INTO DATA(ls_env).
    DATA(lv_type) = to_upper( CONV string( ls_env-type ) ).
    DATA(lv_name) = to_upper( CONV string( ls_env-object ) ).
    CONDENSE lv_name.

    IF lv_type IS INITIAL OR lv_name IS INITIAL.
      CONTINUE.
    ENDIF.

    " Restrict to dependencies that can materially express Clean Core coupling.
    IF lv_type <> 'CLAS' AND
       lv_type <> 'INTF' AND
       lv_type <> 'FUNC' AND
       lv_type <> 'TABL' AND
       lv_type <> 'VIEW' AND
       lv_type <> 'PROG' AND
       lv_type <> 'DDLS' AND
       lv_type <> 'STOB' AND
       lv_type <> 'BDEF' AND
       lv_type <> 'BADI' AND
       lv_type <> 'ENHS'.
      CONTINUE.
    ENDIF.

    INSERT VALUE ty_dependency_key(
      dep_type = lv_type
      dep_name = lv_name ) INTO TABLE rt_dep.
  ENDLOOP.

ENDMETHOD.

METHOD is_sap_dependency.

  DATA lv_tadir_type TYPE tadir-object.
  DATA lv_tadir_name TYPE tadir-obj_name.
  DATA ls_tadir      TYPE tadir.
  DATA ls_e071       TYPE e071.
  DATA ls_owner      TYPE tadir.

  lv_tadir_type = CONV tadir-object( is_dep-dep_type ).
  lv_tadir_name = CONV tadir-obj_name( is_dep-dep_name ).

  CASE is_dep-dep_type.
    WHEN 'FUNC'.
      SELECT SINGLE area
        FROM enlfdir
        WHERE funcname = @lv_tadir_name
        INTO @DATA(lv_group).
      IF sy-subrc = 0.
        lv_tadir_type = 'FUGR'.
        lv_tadir_name = lv_group.
      ENDIF.

    WHEN 'STOB'.
      " STOB is normally a CDS entity/subobject; let TR_CHECK_TYPE resolve it below.
      CLEAR lv_tadir_type.
  ENDCASE.

  IF lv_tadir_type IS NOT INITIAL.
    SELECT SINGLE *
      FROM tadir
      WHERE pgmid    = @c_r3tr
        AND object   = @lv_tadir_type
        AND obj_name = @lv_tadir_name
      INTO @ls_tadir.

    IF sy-subrc = 0.
      rv_sap = xsdbool( ls_tadir-author = c_sap OR ls_tadir-srcsystem = c_sap ).
      RETURN.
    ENDIF.
  ENDIF.

  " Some environment dependency types are LIMU-like subobjects (BADI, STOB, ...).
  " Resolve the owning TADIR object and inspect its origin.
  ls_e071-pgmid    = c_limu.
  ls_e071-object   = CONV e071-object( is_dep-dep_type ).
  ls_e071-obj_name = CONV e071-obj_name( is_dep-dep_name ).

  CALL FUNCTION 'TR_CHECK_TYPE'
    EXPORTING
      wi_e071  = ls_e071
    IMPORTING
      we_tadir = ls_owner.

  IF ls_owner-object IS INITIAL OR ls_owner-obj_name IS INITIAL.
    RETURN.
  ENDIF.

  SELECT SINGLE *
    FROM tadir
    WHERE pgmid    = @c_r3tr
      AND object   = @ls_owner-object
      AND obj_name = @ls_owner-obj_name
    INTO @ls_tadir.

  IF sy-subrc = 0.
    rv_sap = xsdbool( ls_tadir-author = c_sap OR ls_tadir-srcsystem = c_sap ).
  ENDIF.

ENDMETHOD.

METHOD count_modifications.

  TYPES:
    BEGIN OF ty_hit,
      obj_type TYPE smodilog-obj_type,
      obj_name TYPE smodilog-obj_name,
      sub_type TYPE smodilog-sub_type,
      sub_name TYPE smodilog-sub_name,
      int_type TYPE smodilog-int_type,
      int_name TYPE smodilog-int_name,
    END OF ty_hit,
    ty_t_raw TYPE STANDARD TABLE OF ty_hit WITH EMPTY KEY,
    ty_t_hit TYPE SORTED TABLE OF ty_hit
      WITH UNIQUE KEY obj_type obj_name sub_type sub_name int_type int_name.

  DATA lt_mod TYPE ty_t_raw.
  DATA lt_hit TYPE ty_t_hit.
  DATA ls_owner TYPE tadir.

  " SAP Modification Analysis defines an active modification as an
  " SMODILOG record whose INACTIVE field is initial. Values such as
  " 1/R/D/X represent inactive/reset/deleted/obsolete records and are
  " deliberately excluded here.
  SELECT obj_type, obj_name, sub_type, sub_name, int_type, int_name
    FROM smodilog
    WHERE inactive = @space
    INTO TABLE @lt_mod.

  LOOP AT lt_mod INTO DATA(ls_mod).
    " Direct match covers R3TR-level modification log entries and also
    " callers that supplied the same lower-level key as SMODILOG.
    IF ( ls_mod-obj_type = iv_object AND
         ls_mod-obj_name = iv_obj_name ) OR
       ( ls_mod-obj_type = is_source-object AND
         ls_mod-obj_name = is_source-obj_name ).
      INSERT ls_mod INTO TABLE lt_hit.
      CONTINUE.
    ENDIF.

    " SMODILOG can hold a lower-level repository object (for example
    " method/include). Normalize it to its owning R3TR object before
    " comparing it with the analyzed object.
    DATA(ls_e071) = VALUE e071(
      pgmid    = c_limu
      object   = ls_mod-obj_type
      obj_name = CONV e071-obj_name( ls_mod-obj_name ) ).

    CALL FUNCTION 'TR_CHECK_TYPE'
      EXPORTING
        wi_e071  = ls_e071
      IMPORTING
        we_tadir = ls_owner.

    IF ls_owner-object = is_source-object AND
       ls_owner-obj_name = is_source-obj_name.
      INSERT ls_mod INTO TABLE lt_hit.
    ENDIF.
  ENDLOOP.

  " Count distinct active modification locations. The complete SAP
  " business-modification methodology applies additional exclusion rules;
  " this KPI intentionally represents active SMODILOG modifications that
  " can be attributed to the analyzed repository object.
  rv_count = lines( lt_hit ).

ENDMETHOD.

METHOD count_implicit_enhancements.

  DATA lt_enh TYPE STANDARD TABLE OF enhheader-enhname WITH EMPTY KEY.

  " If the analyzed repository object itself is an enhancement implementation,
  " check whether it is an implicit source enhancement implementation.
  IF is_source-object = 'ENHO'.
    SELECT DISTINCT enhname
      FROM enhheader
      WHERE enhname     = @is_source-obj_name
        AND version     = 'A'
        AND enhtooltype = 'HOOK_IMPL'
      INTO TABLE @lt_enh.
  ENDIF.

  " Also find active implicit enhancements attached to the supplied/master object.
  SELECT DISTINCT h~enhname
    FROM enhheader AS h
    INNER JOIN enhobj AS o
      ON  o~enhname = h~enhname
      AND o~version = h~version
    WHERE h~version     = 'A'
      AND h~enhtooltype = 'HOOK_IMPL'
      AND o~state       = 'A'
      AND ( ( o~pgmid    = @iv_pgmid
              AND o~obj_type = @iv_object
              AND o~obj_name = @iv_obj_name )
         OR ( o~main_type = @is_source-object
              AND o~main_name = @is_source-obj_name ) )
    APPENDING TABLE @lt_enh.

  SORT lt_enh BY table_line.
  DELETE ADJACENT DUPLICATES FROM lt_enh COMPARING table_line.
  rv_count = lines( lt_enh ).

ENDMETHOD.

METHOD get_package_sources.

  IF iv_devclass IS INITIAL.
    RETURN.
  ENDIF.

  SELECT pgmid, object, obj_name, devclass, author, srcsystem
    FROM tadir
    WHERE pgmid    = @c_r3tr
      AND devclass = @iv_devclass
      AND object   IN ( 'PROG', 'CLAS', 'INTF', 'FUGR' )
    INTO TABLE @rt_source.

  " Do not analyze INCLUDE programs independently; their source is counted
  " through the owning report/class/function group.
  LOOP AT rt_source ASSIGNING FIELD-SYMBOL(<source>) WHERE object = 'PROG'.
    SELECT SINGLE subc
      FROM trdir
      WHERE name = @<source>-obj_name
      INTO @DATA(lv_subc).
    IF sy-subrc = 0 AND lv_subc = 'I'.
      <source>-object = '----'.
    ENDIF.
  ENDLOOP.

  DELETE rt_source WHERE object = '----'.

ENDMETHOD.

METHOD add_copy_candidate.

  DATA ls_tadir    TYPE tadir.
  DATA ls_existing TYPE ty_copy_candidate.
  DATA lv_reason   TYPE c LENGTH 20.
  FIELD-SYMBOLS <candidate> TYPE ty_copy_candidate.

  IF iv_name IS INITIAL OR iv_name = is_source-obj_name.
    RETURN.
  ENDIF.

  READ TABLE ct_candidates INTO ls_existing WITH KEY obj_name = iv_name.
  IF sy-subrc = 0.
    " Upgrade TEXT candidate to NAME+TEXT when both signals exist.
    IF ls_existing-reason = 'TEXT' AND iv_reason = 'NAME'.
      LOOP AT ct_candidates ASSIGNING <candidate>
        WHERE obj_name = iv_name.
        <candidate>-reason = 'NAME+TEXT'.
        EXIT.
      ENDLOOP.
    ELSEIF ls_existing-reason = 'NAME' AND iv_reason = 'TEXT'.
      LOOP AT ct_candidates ASSIGNING <candidate>
        WHERE obj_name = iv_name.
        <candidate>-reason = 'NAME+TEXT'.
        EXIT.
      ENDLOOP.
    ENDIF.
    RETURN.
  ENDIF.

  SELECT SINGLE * INTO ls_tadir
    FROM tadir
    WHERE pgmid = c_r3tr
      AND object = is_source-object
      AND obj_name = iv_name.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  " Only SAP originals are meaningful counterparts for a clone check.
  IF ls_tadir-author <> c_sap AND ls_tadir-srcsystem <> c_sap.
    RETURN.
  ENDIF.

  lv_reason = iv_reason.
  APPEND VALUE ty_copy_candidate(
    object    = ls_tadir-object
    obj_name  = ls_tadir-obj_name
    devclass  = ls_tadir-devclass
    author    = ls_tadir-author
    srcsystem = ls_tadir-srcsystem
    reason    = lv_reason ) TO ct_candidates.

ENDMETHOD.

METHOD get_copy_candidates.

  DATA lv_name TYPE string.
  DATA lv_candidate TYPE tadir-obj_name.
  DATA lv_offset TYPE i.
  DATA lv_tail_start TYPE i.
  DATA lv_tail TYPE string.
  DATA lv_prog_text TYPE trdirt-text.
  DATA lv_class_text TYPE seoclasstx-descript.
  DATA lv_fugr_text TYPE tlibt-areat.
  DATA lt_program_names TYPE STANDARD TABLE OF trdirt-name WITH EMPTY KEY.
  DATA lt_class_names TYPE STANDARD TABLE OF seoclasstx-clsname WITH EMPTY KEY.
  DATA lt_fugr_names TYPE STANDARD TABLE OF tlibt-area WITH EMPTY KEY.
  DATA lv_program_name TYPE trdirt-name.
  DATA lv_class_name TYPE seoclasstx-clsname.
  DATA lv_fugr_name TYPE tlibt-area.

  lv_name = is_source-obj_name.

  " Strong name signals: Z/Y prefix removed. This covers common copies such
  " as ZRSUSR003 -> RSUSR003 and ZCL_FOO -> CL_FOO.
  IF lv_name CP 'Z*' OR lv_name CP 'Y*'.
    IF strlen( lv_name ) > 1.
      lv_candidate = lv_name+1.
      add_copy_candidate(
        EXPORTING is_source = is_source iv_name = lv_candidate iv_reason = 'NAME'
        CHANGING  ct_candidates = rt_candidates ).
    ENDIF.

    IF lv_name CP 'Z_*' OR lv_name CP 'Y_*'.
      IF strlen( lv_name ) > 2.
        lv_candidate = lv_name+2.
        add_copy_candidate(
          EXPORTING is_source = is_source iv_name = lv_candidate iv_reason = 'NAME'
          CHANGING  ct_candidates = rt_candidates ).
      ENDIF.
    ENDIF.
  ENDIF.

  " Customer namespace: /ABC/RSUSR003 -> RSUSR003. Also try removing a
  " leading Z/Y from the namespace-local tail.
  IF lv_name CP '/*/*'.
    FIND FIRST OCCURRENCE OF '/' IN lv_name+1 MATCH OFFSET lv_offset.
    IF sy-subrc = 0.
      lv_tail_start = lv_offset + 2.
      IF lv_tail_start < strlen( lv_name ).
        lv_tail = lv_name+lv_tail_start.
        lv_candidate = lv_tail.
        add_copy_candidate(
          EXPORTING is_source = is_source iv_name = lv_candidate iv_reason = 'NAME'
          CHANGING  ct_candidates = rt_candidates ).
        IF lv_tail CP 'Z*' OR lv_tail CP 'Y*'.
          IF strlen( lv_tail ) > 1.
            lv_candidate = lv_tail+1.
            add_copy_candidate(
              EXPORTING is_source = is_source iv_name = lv_candidate iv_reason = 'NAME'
              CHANGING  ct_candidates = rt_candidates ).
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDIF.

  " Short text is a useful secondary signal because copied objects often keep
  " the SAP description even when the customer object was renamed.
  CASE is_source-object.
    WHEN 'PROG'.
      SELECT SINGLE text INTO lv_prog_text
        FROM trdirt
        WHERE name = is_source-obj_name
          AND sprsl = sy-langu.
      IF sy-subrc = 0 AND lv_prog_text IS NOT INITIAL.
        SELECT name INTO TABLE lt_program_names
          FROM trdirt
          UP TO 20 ROWS
          WHERE sprsl = sy-langu
            AND text = lv_prog_text.
        LOOP AT lt_program_names INTO lv_program_name.
          lv_candidate = lv_program_name.
          add_copy_candidate(
            EXPORTING is_source = is_source iv_name = lv_candidate iv_reason = 'TEXT'
            CHANGING  ct_candidates = rt_candidates ).
        ENDLOOP.
      ENDIF.

    WHEN 'CLAS' OR 'INTF'.
      SELECT SINGLE descript INTO lv_class_text
        FROM seoclasstx
        WHERE clsname = is_source-obj_name
          AND langu = sy-langu.
      IF sy-subrc = 0 AND lv_class_text IS NOT INITIAL.
        SELECT clsname INTO TABLE lt_class_names
          FROM seoclasstx
          UP TO 20 ROWS
          WHERE langu = sy-langu
            AND descript = lv_class_text.
        LOOP AT lt_class_names INTO lv_class_name.
          lv_candidate = lv_class_name.
          add_copy_candidate(
            EXPORTING is_source = is_source iv_name = lv_candidate iv_reason = 'TEXT'
            CHANGING  ct_candidates = rt_candidates ).
        ENDLOOP.
      ENDIF.

    WHEN 'FUGR'.
      SELECT SINGLE areat INTO lv_fugr_text
        FROM tlibt
        WHERE area = is_source-obj_name
          AND spras = sy-langu.
      IF sy-subrc = 0 AND lv_fugr_text IS NOT INITIAL.
        SELECT area INTO TABLE lt_fugr_names
          FROM tlibt
          UP TO 20 ROWS
          WHERE spras = sy-langu
            AND areat = lv_fugr_text.
        LOOP AT lt_fugr_names INTO lv_fugr_name.
          lv_candidate = lv_fugr_name.
          add_copy_candidate(
            EXPORTING is_source = is_source iv_name = lv_candidate iv_reason = 'TEXT'
            CHANGING  ct_candidates = rt_candidates ).
        ENDLOOP.
      ENDIF.
  ENDCASE.

ENDMETHOD.

METHOD is_generated_view_maint.

  SELECT SINGLE @abap_true FROM tvdir INTO @rv_generated
    WHERE area = @iv_obj_name.

  IF sy-subrc <> 0.
    rv_generated = abap_false.
  ENDIF.

ENDMETHOD.

METHOD read_tadir.

  CLEAR: es_tadir, ev_found.

  SELECT SINGLE *
    INTO es_tadir
    FROM tadir
    WHERE pgmid    = c_r3tr
      AND object   = iv_object
      AND obj_name = iv_obj_name.

  ev_found = xsdbool( sy-subrc = 0 ).

ENDMETHOD.

METHOD read_transport.

  CLEAR: es_request, ev_found.

  SELECT SINGLE *
    INTO es_request
    FROM e070
    WHERE trkorr = iv_trkorr.

  ev_found = xsdbool( sy-subrc = 0 ).

ENDMETHOD.

METHOD get_transport_tasks.

  SELECT trkorr
    INTO TABLE rt_tasks
    FROM e070
    WHERE strkorr = iv_trkorr.

  IF sy-subrc <> 0.
    CLEAR rt_tasks.
  ENDIF.

ENDMETHOD.

METHOD build_transport_population.

  TYPES:
    BEGIN OF ty_scope,
      trkorr TYPE e070-trkorr,
    END OF ty_scope,
    ty_t_scope TYPE SORTED TABLE OF ty_scope WITH UNIQUE KEY trkorr.

  DATA ls_request TYPE e070.
  DATA lt_requested TYPE ty_t_scope.
  DATA lt_roots TYPE ty_t_scope.
  DATA lt_scope TYPE ty_t_scope.
  DATA ls_scope TYPE ty_scope.
  DATA lt_tasks TYPE ty_t_trkorr.
  DATA lv_requested TYPE e070-trkorr.
  DATA lv_task TYPE e070-trkorr.
  DATA lt_entries TYPE ty_t_transport_entry.
  DATA ls_entry TYPE ty_transport_entry.
  DATA ls_work TYPE ty_transport_work.
  DATA ls_source TYPE /s4p0/s_ccc_tadir.
  DATA ls_tadir TYPE tadir.
  FIELD-SYMBOLS <work> TYPE ty_transport_work.

  CLEAR: et_work, et_skipped, es_counts, et_warnings.


  " Normalize the caller input first: ignore blank and duplicate transport IDs.
  LOOP AT it_trkorr INTO lv_requested.
    IF lv_requested IS INITIAL.
      CONTINUE.
    ENDIF.
    CLEAR ls_scope.
    ls_scope-trkorr = lv_requested.
    INSERT ls_scope INTO TABLE lt_requested.
  ENDLOOP.

  DESCRIBE TABLE lt_requested LINES es_counts-requested_transport_count.

  IF lt_requested IS INITIAL.
    APPEND 'No transport IDs were supplied to DETERMINE_TRANSPORT.'
      TO et_warnings.
    RETURN.
  ENDIF.

  " Retain the old scalar field only for the unambiguous single-input case.
  IF es_counts-requested_transport_count = 1.
    READ TABLE lt_requested INDEX 1 INTO ls_scope.
    IF sy-subrc = 0.
      es_counts-requested_trkorr = ls_scope-trkorr.
    ENDIF.
  ENDIF.

  " Build one de-duplicated E071 scope across all requested requests/tasks.
  LOOP AT lt_requested INTO ls_scope.
    lv_requested = ls_scope-trkorr.
    CLEAR: ls_request, lt_tasks.

    read_transport(
      EXPORTING iv_trkorr  = lv_requested
      IMPORTING es_request = ls_request
                ev_found   = DATA(lv_tr_found) ).

    IF lv_tr_found = abap_false.
      ADD 1 TO es_counts-invalid_transport_count.
      APPEND |Transport/request { lv_requested } does not exist in E070.|
        TO et_warnings.
      CONTINUE.
    ENDIF.

    " Store the root request for summary purposes.
    CLEAR ls_scope.
    IF ls_request-strkorr IS INITIAL.
      ls_scope-trkorr = lv_requested.
    ELSE.
      ls_scope-trkorr = ls_request-strkorr.
    ENDIF.
    INSERT ls_scope INTO TABLE lt_roots.

    " Always include the exact transport ID supplied by the caller.
    CLEAR ls_scope.
    ls_scope-trkorr = lv_requested.
    INSERT ls_scope INTO TABLE lt_scope.

    " A root request normally keeps repository entries in its tasks. Include
    " its direct tasks when requested. An explicitly supplied task does not
    " pull in sibling tasks.
    IF ls_request-strkorr IS INITIAL AND iv_include_tasks = abap_true.
      lt_tasks = get_transport_tasks( lv_requested ).

      LOOP AT lt_tasks INTO lv_task.
        CLEAR ls_scope.
        ls_scope-trkorr = lv_task.
        INSERT ls_scope INTO TABLE lt_scope.
      ENDLOOP.
    ENDIF.
  ENDLOOP.

  DESCRIBE TABLE lt_roots LINES es_counts-root_transport_count.
  DESCRIBE TABLE lt_scope LINES es_counts-scope_transport_count.

  " Retain ROOT_TRKORR only when the complete input resolves to one root.
  IF es_counts-root_transport_count = 1.
    READ TABLE lt_roots INDEX 1 INTO ls_scope.
    IF sy-subrc = 0.
      es_counts-root_trkorr = ls_scope-trkorr.
    ENDIF.
  ENDIF.

  IF lt_scope IS INITIAL.
    APPEND 'None of the supplied transport IDs could be resolved in E070.'
      TO et_warnings.
    RETURN.
  ENDIF.

  DATA lt_scope_ids TYPE ty_t_trkorr.
  LOOP AT lt_scope INTO ls_scope.
    APPEND ls_scope-trkorr TO lt_scope_ids.
  ENDLOOP.

  lt_entries = read_transport_entries( lt_scope_ids ).

  DESCRIBE TABLE lt_entries LINES es_counts-transport_entry_count.

  IF lt_entries IS INITIAL.
    APPEND 'No E071 object-list entries found for the selected transport scope.'
      TO et_warnings.
    RETURN.
  ENDIF.


  LOOP AT lt_entries INTO ls_entry.
    CLEAR: ls_source, ls_tadir.

    normalize_object(
      EXPORTING
        iv_pgmid    = ls_entry-pgmid
        iv_object   = ls_entry-object
        iv_obj_name = ls_entry-obj_name
      IMPORTING
        es_source   = ls_source ).

    " Only actual repository objects with a TADIR master are sent to the
    " metric engine. TABU/VDAT/CDAT and other customizing/object-list entries
    " remain visible in SKIPPED_ENTRIES but are not misinterpreted as code.
    IF ls_source-object IS INITIAL OR ls_source-obj_name IS INITIAL.
      APPEND VALUE ty_transport_skipped(
        trkorr   = ls_entry-trkorr
        as4pos   = ls_entry-as4pos
        pgmid    = ls_entry-pgmid
        object   = ls_entry-object
        obj_name = ls_entry-obj_name
        reason   = 'Could not normalize to an R3TR repository object' )
        TO et_skipped.
      ADD 1 TO es_counts-skipped_entry_count.
      CONTINUE.
    ENDIF.

    read_tadir(
      EXPORTING iv_object   = ls_source-object
                iv_obj_name = ls_source-obj_name
      IMPORTING es_tadir    = ls_tadir
                ev_found    = DATA(lv_tadir_found) ).

    IF lv_tadir_found = abap_false.
      APPEND VALUE ty_transport_skipped(
        trkorr   = ls_entry-trkorr
        as4pos   = ls_entry-as4pos
        pgmid    = ls_entry-pgmid
        object   = ls_entry-object
        obj_name = ls_entry-obj_name
        reason   = 'No TADIR master after normalization' )
        TO et_skipped.
      ADD 1 TO es_counts-skipped_entry_count.
      CONTINUE.
    ENDIF.

    ADD 1 TO es_counts-repository_entry_count.

    READ TABLE et_work ASSIGNING <work>
      WITH TABLE KEY
        pgmid    = ls_tadir-pgmid
        object   = ls_tadir-object
        obj_name = ls_tadir-obj_name.

    IF sy-subrc = 0.
      ADD 1 TO <work>-transport_entry_count.
    ELSE.
      CLEAR ls_work.
      ls_work-pgmid                 = ls_tadir-pgmid.
      ls_work-object                = ls_tadir-object.
      ls_work-obj_name              = ls_tadir-obj_name.
      ls_work-source_trkorr         = ls_entry-trkorr.
      ls_work-source_pgmid          = ls_entry-pgmid.
      ls_work-source_object         = ls_entry-object.
      ls_work-source_obj_name       = ls_entry-obj_name.
      ls_work-transport_entry_count = 1.
      INSERT ls_work INTO TABLE et_work.
    ENDIF.
  ENDLOOP.

  DESCRIBE TABLE et_work LINES es_counts-unique_object_count.

  IF et_work IS INITIAL.
    APPEND 'The selected transports contain no analyzable TADIR repository objects.'
      TO et_warnings.
    RETURN.
  ENDIF.

ENDMETHOD.

METHOD read_transport_entries.

  IF it_trkorr IS INITIAL.
    RETURN.
  ENDIF.

  SELECT trkorr as4pos pgmid object obj_name
    INTO TABLE rt_entries
    FROM e071
    FOR ALL ENTRIES IN it_trkorr
    WHERE trkorr = it_trkorr-table_line.

  IF sy-subrc <> 0.
    CLEAR rt_entries.
  ENDIF.

ENDMETHOD.

METHOD load_json_from_http.

  DATA lo_http TYPE REF TO if_http_client.

  cl_http_client=>create_by_url(
    EXPORTING
      url    = iv_url
    IMPORTING
      client = lo_http
    EXCEPTIONS
      OTHERS = 1 ).

  IF sy-subrc <> 0 OR lo_http IS NOT BOUND.
    RETURN.
  ENDIF.

  lo_http->request->set_method( if_http_request=>co_request_method_get ).
  lo_http->request->set_header_field(
    name  = 'Accept'
    value = 'application/json' ).

  lo_http->send( EXCEPTIONS OTHERS = 1 ).
  IF sy-subrc <> 0.
    lo_http->close( ).
    RETURN.
  ENDIF.

  lo_http->receive( EXCEPTIONS OTHERS = 1 ).
  IF sy-subrc = 0.
    lo_http->response->get_status(
      IMPORTING
        code = DATA(lv_status) ).
    IF lv_status >= 200 AND lv_status < 300.
      rv_json = lo_http->response->get_cdata( ).
    ENDIF.
  ENDIF.

  lo_http->close( ).

ENDMETHOD.

METHOD load_classification.

  IF mv_classification_tried = abap_true.
    RETURN.
  ENDIF.

  mv_classification_tried = abap_true.
  CLEAR: mt_api_class, mv_classification_loaded.

  TRY.
      DATA(lv_json) = load_json_from_http( c_classification_url ).
      IF lv_json IS INITIAL.
        RETURN.
      ENDIF.

      DATA ls_root TYPE ty_json_root.
      /ui2/cl_json=>deserialize(
        EXPORTING
          json        = lv_json
          pretty_name = /ui2/cl_json=>pretty_mode-camel_case
        CHANGING
          data        = ls_root ).

      LOOP AT ls_root-object_classifications INTO DATA(ls_item).
        DATA(lv_type)  = to_upper( ls_item-object_type ).
        DATA(lv_key)   = to_upper( ls_item-object_key ).
        DATA(lv_state) = to_upper( ls_item-state ).

        IF lv_type IS INITIAL OR lv_key IS INITIAL.
          CONTINUE.
        ENDIF.

        INSERT VALUE ty_api_class(
          object_type    = lv_type
          object_key     = lv_key
          tadir_object   = CONV tadir-object( to_upper( ls_item-tadir_object ) )
          tadir_obj_name = CONV tadir-obj_name( to_upper( ls_item-tadir_obj_name ) )
          state          = lv_state )
          INTO TABLE mt_api_class.
      ENDLOOP.

      mv_classification_loaded = xsdbool( mt_api_class IS NOT INITIAL ).

    CATCH cx_root.
      CLEAR mv_classification_loaded.
  ENDTRY.

ENDMETHOD.

METHOD get_api_class.

  load_classification( ).

  READ TABLE mt_api_class
    WITH TABLE KEY object_type = to_upper( CONV string( iv_object_type ) )
                   object_key  = to_upper( CONV string( iv_object_key ) )
    INTO rs_api_class.

ENDMETHOD.

METHOD is_classification_loaded.

  rv_loaded = mv_classification_loaded.

ENDMETHOD.

METHOD clear_cache.

  CLEAR: mt_api_class, mv_classification_loaded, mv_classification_tried.

ENDMETHOD.
endclass.
