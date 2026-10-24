FUNCTION /s4p0/enh_shlp_exit_parameter.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  TABLES
*"      SHLP_TAB TYPE  SHLP_DESCT
*"      RECORD_TAB STRUCTURE  SEAHLPRES
*"  CHANGING
*"     VALUE(SHLP) TYPE  SHLP_DESCR
*"     VALUE(CALLCONTROL) LIKE  DDSHF4CTRL STRUCTURE  DDSHF4CTRL
*"----------------------------------------------------------------------

  TYPES:
    BEGIN OF ty_result,
      attvalue  TYPE /s4p0/sh_enh-attvalue,
      parameter TYPE /s4p0/de_enh_param_name,
    END OF ty_result.

  DATA: lt_result          TYPE STANDARD TABLE OF ty_result,
        lv_value           TYPE /s4p0/sh_enh-attvalue,

        lt_enh_ran         TYPE RANGE OF /s4p0/sh_enh-attvalue,
        ls_enh_ran         LIKE LINE OF lt_enh_ran,
        lt_sub_enh_ran     TYPE RANGE OF /s4p0/sh_enh-attvalue,
        ls_sub_enh_ran     LIKE LINE OF lt_sub_enh_ran,
        lt_feature_ran     TYPE RANGE OF /s4p0/sh_enh-attvalue,
        ls_feature_ran     LIKE LINE OF lt_feature_ran,
        lt_param_ran       TYPE RANGE OF /s4p0/sh_enh-attvalue,
        ls_param_ran       LIKE LINE OF lt_param_ran,

        lt_clsname_ran     TYPE RANGE OF /s4p0/sh_enh-clsname,
        lt_clsname_tmp_ran LIKE lt_clsname_ran[],
        ls_clsname_ran     LIKE LINE OF lt_clsname_ran.

  IF callcontrol-step = 'SELECT'.
    " Derive from Enhancement the Interface-Name
    LOOP AT shlp-selopt ASSIGNING FIELD-SYMBOL(<fs_selopt>)
      WHERE shlpfield = 'ENHANCEMENT'.

      CLEAR ls_enh_ran.

      MOVE-CORRESPONDING <fs_selopt> TO ls_enh_ran.
      IF <fs_selopt>-low  IS NOT INITIAL. ls_enh_ran-low  = |'{ <fs_selopt>-low }'|. ENDIF.
      IF <fs_selopt>-high IS NOT INITIAL. ls_enh_ran-high = |'{ <fs_selopt>-high }'|. ENDIF.
      APPEND ls_enh_ran TO lt_enh_ran.
    ENDLOOP.

    IF lt_enh_ran[] IS NOT INITIAL.
      SELECT * FROM /s4p0/sh_enh INTO @DATA(ls_sh_enh)
        WHERE attvalue IN @lt_enh_ran.

        CLEAR ls_clsname_ran.
        ls_clsname_ran-sign = if_salv_bs_c_filter=>sign_including.
        ls_clsname_ran-option = if_salv_bs_c_filter=>operator_eq.
        ls_clsname_ran-low = ls_sh_enh-clsname.
        APPEND ls_clsname_ran TO lt_clsname_ran.
      ENDSELECT.

      IF lt_clsname_ran[] IS INITIAL.
        "nothing found to selection
        RETURN.
      ENDIF.
    ELSE.
      CLEAR ls_clsname_ran.
      ls_clsname_ran-sign = if_salv_bs_c_filter=>sign_including.
      ls_clsname_ran-option = if_salv_bs_c_filter=>operator_cp.
      ls_clsname_ran-low = '*'.
      APPEND ls_clsname_ran TO lt_clsname_ran.
    ENDIF.

    " Derive from Sub-Enhancement the Interface-Name
    LOOP AT shlp-selopt ASSIGNING <fs_selopt>
      WHERE shlpfield = 'SUB_ENHANCEMENT'.

      CLEAR ls_sub_enh_ran.

      MOVE-CORRESPONDING <fs_selopt> TO ls_sub_enh_ran.
      IF <fs_selopt>-low  IS NOT INITIAL. ls_sub_enh_ran-low  = |'{ <fs_selopt>-low }'|. ENDIF.
      IF <fs_selopt>-high IS NOT INITIAL. ls_sub_enh_ran-high = |'{ <fs_selopt>-high }'|. ENDIF.
      APPEND ls_sub_enh_ran TO lt_sub_enh_ran.
    ENDLOOP.

    IF lt_sub_enh_ran[] IS NOT INITIAL.
      lt_clsname_tmp_ran[] = lt_clsname_ran[].
      CLEAR lt_clsname_ran[].

      SELECT * FROM /s4p0/sh_enh_sub INTO @DATA(ls_sh_sub_enh)
        WHERE attvalue IN @lt_sub_enh_ran
          AND clsname  IN @lt_clsname_tmp_ran.

        CLEAR ls_clsname_ran.
        ls_clsname_ran-sign = if_salv_bs_c_filter=>sign_including.
        ls_clsname_ran-option = if_salv_bs_c_filter=>operator_eq.
        ls_clsname_ran-low = ls_sh_enh-clsname.
        APPEND ls_clsname_ran TO lt_clsname_ran.
      ENDSELECT.

      IF lt_clsname_ran[] IS INITIAL.
        "nothing found to selection
        RETURN.
      ENDIF.
    ELSE.
      IF lt_clsname_ran[] IS INITIAL.
        CLEAR ls_clsname_ran.
        ls_clsname_ran-sign = if_salv_bs_c_filter=>sign_including.
        ls_clsname_ran-option = if_salv_bs_c_filter=>operator_cp.
        ls_clsname_ran-low = '*'.
        APPEND ls_clsname_ran TO lt_clsname_ran.
      ENDIF.
    ENDIF.

    " Derive from Feature the Interface-Name
    LOOP AT shlp-selopt ASSIGNING <fs_selopt>
      WHERE shlpfield = 'FEATURE'.

      CLEAR ls_feature_ran.

      MOVE-CORRESPONDING <fs_selopt> TO ls_feature_ran.
      IF <fs_selopt>-low  IS NOT INITIAL. ls_feature_ran-low  = |'{ <fs_selopt>-low }'|. ENDIF.
      IF <fs_selopt>-high IS NOT INITIAL. ls_feature_ran-high = |'{ <fs_selopt>-high }'|. ENDIF.
      APPEND ls_feature_ran TO lt_feature_ran.
    ENDLOOP.

    IF lt_feature_ran[] IS NOT INITIAL.
      lt_clsname_tmp_ran[] = lt_clsname_ran[].
      CLEAR lt_clsname_ran[].

      SELECT * FROM /s4p0/sh_enh_fea INTO @DATA(ls_sh_enh_feature)
        WHERE attvalue IN @lt_feature_ran
          AND clsname  IN @lt_clsname_ran.

        CLEAR ls_clsname_ran.
        ls_clsname_ran-sign = if_salv_bs_c_filter=>sign_including.
        ls_clsname_ran-option = if_salv_bs_c_filter=>operator_eq.
        ls_clsname_ran-low = ls_sh_enh-clsname.
        APPEND ls_clsname_ran TO lt_clsname_ran.
      ENDSELECT.

      IF lt_clsname_ran[] IS INITIAL.
        "nothing found to selection
        RETURN.
      ENDIF.
    ELSE.
      IF lt_clsname_ran[] IS INITIAL.
        CLEAR ls_clsname_ran.
        ls_clsname_ran-sign = if_salv_bs_c_filter=>sign_including.
        ls_clsname_ran-option = if_salv_bs_c_filter=>operator_cp.
        ls_clsname_ran-low = '*'.
        APPEND ls_clsname_ran TO lt_clsname_ran.
      ENDIF.
    ENDIF.

    DELETE lt_clsname_ran
      WHERE sign   = if_salv_bs_c_filter=>sign_including
        AND option = if_salv_bs_c_filter=>operator_cp
        AND low    = '*'.

    " collected class/interface names used as constraint for F4
    IF lt_clsname_ran[] IS NOT INITIAL.
      " Preselected enh/sub-enh/feature given
      SELECT * FROM /s4p0/sh_enh_par INTO @DATA(ls_sh_enh_param)
        WHERE clsname IN @lt_clsname_ran.

        APPEND INITIAL LINE TO shlp-selopt ASSIGNING FIELD-SYMBOL(<fs_selopt_new>).
        <fs_selopt_new>-shlpfield = 'CLSNAME'.
        <fs_selopt_new>-sign = if_salv_bs_c_filter=>sign_including.
        <fs_selopt_new>-option = if_salv_bs_c_filter=>operator_eq.
        <fs_selopt_new>-low = ls_sh_enh_param-clsname.
      ENDSELECT.

      IF sy-dbcnt = 0.
        " Preselection given, but nothing found for that constraint, so exit with 0 hits
        callcontrol-step = 'DISP'.
        RETURN.
      ENDIF.
    ENDIF.

    " Parameter
    LOOP AT shlp-selopt ASSIGNING <fs_selopt>
      WHERE shlpfield = 'PARAMETER'.

      APPEND INITIAL LINE TO shlp-selopt ASSIGNING <fs_selopt_new>.
      <fs_selopt_new>-shlpfield = 'ATTVALUE'.
      <fs_selopt_new>-sign      = <fs_selopt>-sign.
      <fs_selopt_new>-option    = <fs_selopt>-option.
      IF <fs_selopt>-low  IS NOT INITIAL. <fs_selopt_new>-low  = |'{ <fs_selopt>-low }'|.  ENDIF.
      IF <fs_selopt>-high IS NOT INITIAL. <fs_selopt_new>-high = |'{ <fs_selopt>-high }'|. ENDIF.
    ENDLOOP.

    RETURN.

  ENDIF.

  IF callcontrol-step = 'DISP'.

    "Get CLSNAME from the already selected search help result
    CALL FUNCTION 'F4UT_PARAMETER_VALUE_GET'
      EXPORTING
        parameter         = 'ATTVALUE'
        fieldname         = 'ATTVALUE'
      TABLES
        shlp_tab          = shlp_tab
        record_tab        = record_tab
        results_tab       = lt_result
      CHANGING
        shlp              = shlp
        callcontrol       = callcontrol
      EXCEPTIONS
        parameter_unknown = 1
        OTHERS            = 2.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    "Enrich the result
    LOOP AT lt_result ASSIGNING FIELD-SYMBOL(<fs_result>).
      lv_value = <fs_result>-attvalue.
      REPLACE ALL OCCURRENCES OF '''' IN lv_value WITH space.
      CONDENSE lv_value NO-GAPS.
      <fs_result>-parameter = lv_value.
    ENDLOOP.

    "Put ADDITIONAL back into the search help result
    CALL FUNCTION 'F4UT_PARAMETER_RESULTS_PUT'
      EXPORTING
        parameter         = 'PARAMETER'
        fieldname         = 'PARAMETER'
      TABLES
        shlp_tab          = shlp_tab
        record_tab        = record_tab
        source_tab        = lt_result
      CHANGING
        shlp              = shlp
        callcontrol       = callcontrol
      EXCEPTIONS
        parameter_unknown = 1
        OTHERS            = 2.
  ENDIF.

ENDFUNCTION.
