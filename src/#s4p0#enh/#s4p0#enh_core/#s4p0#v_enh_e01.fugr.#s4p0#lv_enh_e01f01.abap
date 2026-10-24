*----------------------------------------------------------------------*
***INCLUDE /S4P0/LV_ENH_E01F01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form SHOW_CLASS_WHERE_USED
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_class_where_used .

  DATA:
    lv_visible_line TYPE i,
    lv_field        TYPE dynfnam,
    lv_extract_line TYPE sy-tabix,
    ls_view         TYPE /s4p0/v_enh_e01,
    lv_value        TYPE /s4p0/sh_enh-attvalue,
    lv_classname    TYPE seoclsname,
    lv_attribute    TYPE seocmpname.

  "Current row in Table Control
  GET CURSOR FIELD lv_field LINE lv_visible_line.

  IF lv_visible_line IS INITIAL.
    MESSAGE 'Bitte eine Klasse auswählen' "TODO
      TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "Position im EXTRACT bestimmen
  lv_extract_line = firstline + lv_visible_line - 1.

  READ TABLE extract INDEX lv_extract_line.

  IF sy-subrc <> 0.
    MESSAGE 'Die ausgewählte Zeile konnte nicht ermittelt werden' "TODO
      TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "TMG-Daten in echte View-Struktur konvertieren
  ls_view = <vim_extract_struc>.

  CLEAR lv_value.
  lv_value = |'{ ls_view-enhancement }'|.
  SELECT SINGLE * FROM /s4p0/sh_enh INTO @DATA(ls_enh) "TODO: handling of multiple entries needed
    WHERE attvalue = @lv_value.

  CASE lv_field.
    WHEN '/S4P0/V_ENH_E01-ENHANCEMENT'.

      lv_classname = ls_enh-clsname.
      lv_attribute = ls_enh-cmpname.

    WHEN '/S4P0/V_ENH_E01-SUB_ENHANCEMENT'.

      lv_value = |'{ ls_view-sub_enhancement }'|.
      SELECT SINGLE * FROM /s4p0/sh_enh_sub INTO @DATA(ls_enh_sub) "TODO: handling of multiple entries needed
        WHERE attvalue = @lv_value
          AND clsname  = @ls_enh-clsname.
      lv_classname = ls_enh_sub-clsname.
      lv_attribute = ls_enh_sub-cmpname.

    WHEN '/S4P0/V_ENH_E01-FEATURE'.

      lv_value = |'{ ls_view-feature }'|.
      SELECT SINGLE * FROM /s4p0/sh_enh_fea INTO @DATA(ls_enh_feature) "TODO: handling of multiple entries needed
        WHERE attvalue = @lv_value
          AND clsname  = @ls_enh-clsname.
      lv_classname = ls_enh_feature-clsname.
      lv_attribute = ls_enh_feature-cmpname.

    WHEN OTHERS.
      MESSAGE 'Bitte eine relevante Spalte auswählen' "TODO
        TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDCASE.

  IF lv_classname IS INITIAL OR lv_attribute IS INITIAL.
    MESSAGE 'Für diese Zeile ist keine Klasse gepflegt'"TODO
      TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "Start Where-Used for interface/class
*  CALL FUNCTION 'RS_TOOL_ACCESS'
*    EXPORTING
*      operation           = 'CROSSREF'
*      object_name         = lv_classname
*      object_type         = 'CLAS'
*    EXCEPTIONS
*      not_executed        = 1
*      invalid_object_type = 2
*      OTHERS              = 3.

  "Start Where-Used for interface/class and attribute
  CALL FUNCTION 'RS_TOOL_ACCESS'
    EXPORTING
      operation        = 'CROSSREF'
      object_name      = lv_attribute
      object_type      = swbm_c_type_cls_attribute
      enclosing_object = lv_classname.

  IF sy-subrc <> 0.
    MESSAGE 'Verwendungsnachweis konnte nicht gestartet werden'"TODO
      TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.
