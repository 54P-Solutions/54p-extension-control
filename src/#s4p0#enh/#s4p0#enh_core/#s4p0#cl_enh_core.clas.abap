class /S4P0/CL_ENH_CORE definition
  public
  create public .

public section.

  class-methods GET_INSTANCE
    importing
      !IV_ENHANCEMENT type /S4P0/DE_ENH_ID
      !IV_SUB_ENHANCEMENT type /S4P0/DE_ENH_SUB_ENH_ID optional
      !IV_FEATURE type /S4P0/DE_ENH_FEATURE_ID optional
    returning
      value(RO_INSTANCE) type ref to /S4P0/CL_ENH_CORE .
  methods IS_ENHANCEMENT_ACTIVE
    returning
      value(RV_ACTIVE) type LAW2_ACTIVE .
  methods GET_ENH_PARAMS_ALL
    returning
      value(RT_PARAMETERS) type /S4P0/TT_ENH_PARAMETER .
  methods GET_ENH_PARAM_SINGLE
    importing
      !IV_PARAM_NAME type /S4P0/DE_ENH_PARAM_NAME
      !IV_PARAM_ORG1 type /S4P0/DE_ENH_ORG1 optional
      !IV_PARAM_ORG2 type /S4P0/DE_ENH_ORG2 optional
      !IV_PARAM_FREE_KEY type /S4P0/DE_ENH_FREE_KEY optional
    returning
      value(RS_PARAMETER) type /S4P0/S_ENH_PARAMETER .
  methods CONSTRUCTOR
    importing
      !IV_ENHANCEMENT type /S4P0/DE_ENH_ID
      !IV_SUB_ENHANCEMENT type /S4P0/DE_ENH_SUB_ENH_ID optional
      !IV_FEATURE type /S4P0/DE_ENH_FEATURE_ID optional .
protected section.

  data GS_ENH_HEADER type /S4P0/T_ENH_E01 .
  data GS_ENH_PRODUCT type TBE24 .
  data GT_ENH_PARAMETER type /S4P0/TT_ENH_PARAMETER .

  methods TRACK_USAGE .
  methods CREATE_AS_RANGE
    importing
      !IV_PARAM_NAME type /S4P0/DE_ENH_PARAM_NAME
      !IV_PARAM_ORG1 type /S4P0/DE_ENH_ORG1 optional
      !IV_PARAM_ORG2 type /S4P0/DE_ENH_ORG2 optional
      !IV_PARAM_FREE_KEY type /S4P0/DE_ENH_FREE_KEY optional
    returning
      value(RT_PARAMETER_RAN) type /S4P0/TT_ENH_RANGETAB .
private section.
ENDCLASS.



CLASS /S4P0/CL_ENH_CORE IMPLEMENTATION.


METHOD constructor.
*&---------------------------------------------------------------------*
*& Description
*& Enhancement Framework read and compile customizing
*&
*& Developer
*& 54P; support@54p.eu
*&
*& Consultant (internal contact)
*&
*&---------------------------------------------------------------------*
*& Changelog
*& Username    Date     #Ticket: Description of change
*& 54P     01.02.2025  Initial Version
*&
*&---------------------------------------------------------------------*

  DATA: lv_tabix     TYPE syst-tabix,
        lv_timestamp TYPE timestamp,
        lv_is_shadow TYPE abap_bool,
        ls_enh_param LIKE LINE OF gt_enh_parameter,
        lt_bname_ran TYPE RANGE OF /s4p0/t_enh_e03c-bname.

  CALL FUNCTION 'UPG_IS_SHADOW_SYSTEM'
    IMPORTING
      ev_shadow = lv_is_shadow.

  " Suppress enhancement logic during upgrade shadow runs to keep SPAU/SPDD
  " preparation independent from project-specific switches.
  CHECK lv_is_shadow IS INITIAL.

  " Resolve the most specific customizing first, then fall back from feature
  " to sub-enhancement and finally to the enhancement-wide default.
  " toDo: SELECT *
  SELECT SINGLE * FROM /s4p0/t_enh_e01 INTO @gs_enh_header
    WHERE enhancement     = @iv_enhancement
      AND sub_enhancement = @iv_sub_enhancement
      AND feature         = @iv_feature.

  IF gs_enh_header IS INITIAL.
    " toDo: SELECT *
    SELECT SINGLE * FROM /s4p0/t_enh_e01 INTO @gs_enh_header
      WHERE enhancement     = @iv_enhancement
        AND sub_enhancement = @iv_sub_enhancement
        AND feature         = @space.
  ENDIF.

  IF gs_enh_header IS INITIAL.
    " toDo: SELECT *
    SELECT SINGLE * FROM /s4p0/t_enh_e01 INTO @gs_enh_header
      WHERE enhancement     = @iv_enhancement
        AND sub_enhancement = @space
        AND feature         = @space.
  ENDIF.

  CHECK gs_enh_header IS NOT INITIAL.

  " If a product switch is assigned, the enhancement is active only while
  " the SAP product switch is active as well.
  IF gs_enh_header-prdkt IS NOT INITIAL.
    " toDo: SELECT *
    SELECT SINGLE * FROM tbe24 INTO @gs_enh_product
      WHERE prdkt = @gs_enh_header-prdkt.

    IF gs_enh_product-aktiv IS INITIAL.
      CLEAR gs_enh_header-active.
    ENDIF.
  ENDIF.

*&---------------------------------------------------------------------*
*& All above transportable next section is none transportable logic
*&---------------------------------------------------------------------*
  " Client-local activation settings intentionally override transportable
  " customizing, so operations can disable a feature without a transport.
*  SELECT SINGLE active FROM /s4p0/t_enh_e01c INTO @gs_enh_header-active

  GET TIME STAMP FIELD lv_timestamp.

  SELECT SINGLE * FROM /s4p0/t_enh_e01c INTO @DATA(ls_client_enh)
    WHERE enhancement     = @gs_enh_header-enhancement
      AND sub_enhancement = @gs_enh_header-sub_enhancement
      AND feature         = @gs_enh_header-feature
      AND ( valid_to_tstp = @space OR valid_to_tstp >= @lv_timestamp ).

  IF ls_client_enh IS NOT INITIAL.

    CASE ls_client_enh-active.
      WHEN abap_true.
        gs_enh_header-active = abap_true.

      WHEN abap_false.
        gs_enh_header-active = abap_false.

      WHEN /s4p0/if_enh_constants=>gc_enh_clnt_active_user_based.

        SELECT
               @if_salv_bs_c_filter=>operator_cp     AS option,
               @if_salv_bs_c_filter=>sign_including  AS sign,
               bname AS low FROM /s4p0/t_enh_e03c INTO CORRESPONDING FIELDS OF TABLE @lt_bname_ran
          WHERE enhancement     = @gs_enh_header-enhancement
            AND sub_enhancement = @gs_enh_header-sub_enhancement
            AND feature         = @gs_enh_header-feature
            AND ( valid_to_tstp = @space OR valid_to_tstp >= @lv_timestamp ).

        IF lt_bname_ran[] IS NOT INITIAL AND sy-uname IN lt_bname_ran.
          gs_enh_header-active = abap_true.
        ELSE.
          gs_enh_header-active = abap_false.
        ENDIF.

      WHEN OTHERS.
        " This should never happen ;)
    ENDCASE.
  ENDIF.

*&---------------------------------------------------------------------*
*& Parameter handling starts here
*&---------------------------------------------------------------------*

  SELECT DISTINCT enhancement, sub_enhancement, feature, param_name, param_org1, param_org2, param_free_key
    FROM /s4p0/t_enh_e02
    INTO CORRESPONDING FIELDS OF TABLE @gt_enh_parameter
    WHERE enhancement     = @gs_enh_header-enhancement
      AND sub_enhancement = @gs_enh_header-sub_enhancement
      AND feature         = @gs_enh_header-feature.
  LOOP AT gt_enh_parameter ASSIGNING FIELD-SYMBOL(<fs_enh_parameter>).
    SELECT param_type, param_value_xml, param_value1, param_value2, param_value3, param_tvarvc_name, param_tvarvc_type, param_descr
      FROM /s4p0/t_enh_e02
      INTO CORRESPONDING FIELDS OF TABLE @<fs_enh_parameter>-as_value
      WHERE enhancement     = @<fs_enh_parameter>-enhancement
        AND sub_enhancement = @<fs_enh_parameter>-sub_enhancement
        AND feature         = @<fs_enh_parameter>-feature
        AND param_name      = @<fs_enh_parameter>-param_name
        AND param_org1      = @<fs_enh_parameter>-param_org1
        AND param_org2      = @<fs_enh_parameter>-param_org2
        AND param_free_key  = @<fs_enh_parameter>-param_free_key.
  ENDLOOP.

  DATA lt_enh_param_2 LIKE gt_enh_parameter[].
  SELECT DISTINCT enhancement, sub_enhancement, feature, param_name, param_org1, param_org2, param_free_key
    FROM /s4p0/t_enh_e02c
    INTO CORRESPONDING FIELDS OF TABLE @lt_enh_param_2
    WHERE enhancement     = @gs_enh_header-enhancement
      AND sub_enhancement = @gs_enh_header-sub_enhancement
      AND feature         = @gs_enh_header-feature.
  LOOP AT lt_enh_param_2 ASSIGNING <fs_enh_parameter>.
    SELECT param_type, param_value_xml, param_value1, param_value2, param_value3, param_tvarvc_name, param_tvarvc_type, param_descr
      FROM /s4p0/t_enh_e02c
      INTO CORRESPONDING FIELDS OF TABLE @<fs_enh_parameter>-as_value
      WHERE enhancement     = @<fs_enh_parameter>-enhancement
        AND sub_enhancement = @<fs_enh_parameter>-sub_enhancement
        AND feature         = @<fs_enh_parameter>-feature
        AND param_name      = @<fs_enh_parameter>-param_name
        AND param_org1      = @<fs_enh_parameter>-param_org1
        AND param_org2      = @<fs_enh_parameter>-param_org2
        AND param_free_key  = @<fs_enh_parameter>-param_free_key.
  ENDLOOP.

  " Overlay local parameter records after transportable customizing; new
  " local records are appended below to behave like maintained parameters.
  LOOP AT gt_enh_parameter ASSIGNING <fs_enh_parameter>.
    LOOP AT lt_enh_param_2 INTO DATA(ls_enh_param_2)
      WHERE enhancement     = <fs_enh_parameter>-enhancement
        AND sub_enhancement = <fs_enh_parameter>-sub_enhancement
        AND feature         = <fs_enh_parameter>-feature
        AND param_name      = <fs_enh_parameter>-param_name
        AND param_org1      = <fs_enh_parameter>-param_org1
        AND param_org2      = <fs_enh_parameter>-param_org2
        AND param_free_key  = <fs_enh_parameter>-param_free_key.

      lv_tabix = sy-tabix.

      <fs_enh_parameter>-as_value[] = ls_enh_param_2-as_value[].

      DELETE lt_enh_param_2 INDEX lv_tabix.
      EXIT.
    ENDLOOP.
  ENDLOOP.

  LOOP AT lt_enh_param_2 INTO ls_enh_param_2.
    MOVE-CORRESPONDING ls_enh_param_2 TO ls_enh_param.
    APPEND ls_enh_param TO gt_enh_parameter.
  ENDLOOP.

  " Resolve TVARVC parameter values eagerly for type P. Select-options stay
  " as ranges and are normalized in create_as_range.
  LOOP AT gt_enh_parameter ASSIGNING <fs_enh_parameter>.
    LOOP AT <fs_enh_parameter>-as_value ASSIGNING FIELD-SYMBOL(<fs_param_as_value>)
      WHERE param_type        = /s4p0/if_enh_constants=>gc_enh_param_type_tvarvc
        AND param_tvarvc_type = /s4p0/if_enh_constants=>gc_tvarvc_param_type_param."only Parameters support for non ranges

      SELECT SINGLE low FROM tvarvc INTO <fs_param_as_value>-param_value1
        WHERE name = <fs_param_as_value>-param_tvarvc_name
          AND type = <fs_param_as_value>-param_tvarvc_type.
    ENDLOOP.
  ENDLOOP.

  " Prebuild range tables once so callers can consume parameters without
  " repeating TVARVC and value-field normalization.
  LOOP AT gt_enh_parameter ASSIGNING <fs_enh_parameter>.
    <fs_enh_parameter>-as_range[] = me->create_as_range(
       iv_param_name     = <fs_enh_parameter>-param_name
       iv_param_org1     = <fs_enh_parameter>-param_org1
       iv_param_org2     = <fs_enh_parameter>-param_org2
       iv_param_free_key = <fs_enh_parameter>-param_free_key ).
  ENDLOOP.

  " Usage tracking is deliberately best-effort and only runs for active
  " enhancements that opted into tracking.
  IF is_enhancement_active( ) = abap_true
    AND gs_enh_header-track_usage = abap_true.
    me->track_usage( ).
  ENDIF.

ENDMETHOD.


METHOD create_as_range.
*&---------------------------------------------------------------------*
*& Description
*& Enhancement Framework return selected enhancement parameters
*&
*& Developer
*& 54P; support@54p.eu
*&
*&---------------------------------------------------------------------*
*& Changelog
*& Username    Date     #Ticket: Description of change
*& 54P     01.02.2025  Initial Version
*&
*&---------------------------------------------------------------------*

  FIELD-SYMBOLS <fs_param_ran> LIKE LINE OF rt_parameter_ran.

  LOOP AT gt_enh_parameter ASSIGNING FIELD-SYMBOL(<fs_enh_parameter>)
    WHERE param_name     = iv_param_name
      AND param_org1     = iv_param_org1
      AND param_org2     = iv_param_org2
      AND param_free_key = iv_param_free_key.
    LOOP AT <fs_enh_parameter>-as_value ASSIGNING FIELD-SYMBOL(<fs_param_as_value>).
      CASE <fs_param_as_value>-param_type.
        WHEN space.
          " Plain value parameters are exposed as include/equal range rows
          " so downstream checks can use a single IN expression.
          IF <fs_param_as_value>-param_value1 IS NOT INITIAL.
            APPEND INITIAL LINE TO rt_parameter_ran ASSIGNING <fs_param_ran>.
            <fs_param_ran>-option = 'EQ'.
            <fs_param_ran>-sign   = 'I'.
            <fs_param_ran>-low    = <fs_param_as_value>-param_value1.
          ENDIF.

          IF <fs_param_as_value>-param_value2 IS NOT INITIAL.
            APPEND INITIAL LINE TO rt_parameter_ran ASSIGNING <fs_param_ran>.
            <fs_param_ran>-option = 'EQ'.
            <fs_param_ran>-sign   = 'I'.
            <fs_param_ran>-low    = <fs_param_as_value>-param_value2.
          ENDIF.

          IF <fs_param_as_value>-param_value3 IS NOT INITIAL.
            APPEND INITIAL LINE TO rt_parameter_ran ASSIGNING <fs_param_ran>.
            <fs_param_ran>-option = 'EQ'.
            <fs_param_ran>-sign   = 'I'.
            <fs_param_ran>-low    = <fs_param_as_value>-param_value3.
          ENDIF.

        WHEN /s4p0/if_enh_constants=>gc_enh_param_type_tvarvc.
          " TVARVC entries may already be select-options; plain parameters
          " are completed below with include/equal semantics.
          IF <fs_param_as_value>-param_tvarvc_type IS INITIAL.
            SELECT sign opti AS option low high FROM tvarvc
              APPENDING TABLE rt_parameter_ran
              WHERE name = <fs_param_as_value>-param_tvarvc_name.
          ELSE.
            SELECT sign opti AS option low high FROM tvarvc
              APPENDING TABLE rt_parameter_ran
              WHERE name = <fs_param_as_value>-param_tvarvc_name
                AND type = <fs_param_as_value>-param_tvarvc_type.
          ENDIF.

          " Fill missing SIGN/OPTION for TVARVC parameter rows.
          LOOP AT rt_parameter_ran ASSIGNING <fs_param_ran>
            WHERE option EQ space.
            <fs_param_ran>-sign   = 'I'.
            <fs_param_ran>-option = 'EQ'.
          ENDLOOP.

        WHEN OTHERS.
          RETURN.
      ENDCASE.
    ENDLOOP.
  ENDLOOP.

ENDMETHOD.


METHOD get_enh_params_all.
*&---------------------------------------------------------------------*
*& Description
*& Enhancement Framework return all enhancement parameters
*&
*& Developer
*& 54P; support@54p.eu
*&
*& Consultant (internal contact)
*&
*&---------------------------------------------------------------------*
*& Changelog
*& Username    Date     #Ticket: Description of change
*& 54P     01.02.2025  Initial Version
*&
*&---------------------------------------------------------------------*

  rt_parameters[] = gt_enh_parameter[].

ENDMETHOD.


METHOD get_enh_param_single.
*&---------------------------------------------------------------------*
*& Description
*& Enhancement Framework return selected enhancement parameters
*&
*& Developer
*& 54P; support@54p.eu
*&
*& Consultant (internal contact)
*&
*&---------------------------------------------------------------------*
*& Changelog
*& Username    Date     #Ticket: Description of change
*& 54P     01.02.2025  Initial Version
*&
*&---------------------------------------------------------------------*

  LOOP AT gt_enh_parameter INTO rs_parameter
    WHERE param_name = iv_param_name
      AND param_org1 = iv_param_org1
      AND param_org2 = iv_param_org2
      AND param_free_key = iv_param_free_key.
    EXIT.
  ENDLOOP.

ENDMETHOD.


METHOD get_instance.
*&---------------------------------------------------------------------*
*& Description
*& Enhancement Framework Factory
*&
*& Developer
*& 54P; support@54p.eu
*&
*& Consultant (internal contact)
*&
*&---------------------------------------------------------------------*
*& Changelog
*& Username    Date     #Ticket: Description of change
*& 54P     01.02.2025  Initial Version
*&
*&---------------------------------------------------------------------*
  " No user-based buffer is used; the customizing tables are buffered and
  " user restrictions are evaluated inside the constructed instance.
  CREATE OBJECT ro_instance
    EXPORTING
      iv_enhancement     = iv_enhancement
      iv_sub_enhancement = iv_sub_enhancement
      iv_feature         = iv_feature.

ENDMETHOD.


METHOD is_enhancement_active.
*&---------------------------------------------------------------------*
*& Description
*& Enhancement Framework Check if enhancement is active
*&
*& Developer
*& 54P; support@54p.eu
*&
*& Consultant (internal contact)
*&
*&---------------------------------------------------------------------*
*& Changelog
*& Username    Date     #Ticket: Description of change
*& 54P		 01.02.2025  Initial Version
*&
*&---------------------------------------------------------------------*

  rv_active = gs_enh_header-active.

ENDMETHOD.


METHOD track_usage.
*&---------------------------------------------------------------------*
*& Description
*& Enhancement Framework track usage (if tracking is active)
*&
*& Developer
*& 54P; support@54p.eu
*&
*& Consultant (internal contact)
*&
*&---------------------------------------------------------------------*
*& Changelog
*& Username    Date     #Ticket: Description of change
*& 54P     01.02.2025  Initial Version
*&
*&---------------------------------------------------------------------*

  CHECK gs_enh_header-track_usage = abap_true.

  TRY.
      " Put tracking in a separate LUW to avoid commits and interruptions
      " in the business process that merely checked the enhancement.
      CALL FUNCTION '/S4P0/ENH_TRACK_USAGE'
        DESTINATION 'NONE'
        STARTING NEW TASK 'NEW'
        EXPORTING
          iv_enhancement_id     = gs_enh_header-enhancement
          iv_sub_enhancement_id = gs_enh_header-sub_enhancement
          iv_feature            = gs_enh_header-feature
        EXCEPTIONS
          communication_failure = 1
          system_failure        = 2
          OTHERS                = 3.

    CATCH cx_root.
      " Tracking must never affect the protected business flow.
  ENDTRY.

ENDMETHOD.
ENDCLASS.
