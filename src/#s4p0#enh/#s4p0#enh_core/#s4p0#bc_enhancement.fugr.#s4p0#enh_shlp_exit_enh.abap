FUNCTION /s4p0/enh_shlp_exit_enh.
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
      attvalue    TYPE /s4p0/sh_enh-attvalue,
      enhancement TYPE /s4p0/de_enh_id,
    END OF ty_result.

  DATA: lt_result TYPE STANDARD TABLE OF ty_result,
        lv_value  TYPE /s4p0/sh_enh-attvalue.

  IF callcontrol-step = 'SELECT'.
    LOOP AT shlp-selopt ASSIGNING FIELD-SYMBOL(<fs_selopt>)
      WHERE shlpfield = 'ENHANCEMENT'.

      APPEND INITIAL LINE TO shlp-selopt ASSIGNING FIELD-SYMBOL(<fs_selopt_new>).
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
      <fs_result>-enhancement = lv_value.
    ENDLOOP.

    "Put ADDITIONAL back into the search help result
    CALL FUNCTION 'F4UT_PARAMETER_RESULTS_PUT'
      EXPORTING
        parameter         = 'ENHANCEMENT'
        fieldname         = 'ENHANCEMENT'
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
