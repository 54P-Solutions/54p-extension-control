*----------------------------------------------------------------------*
***INCLUDE /S4P0/LV_ENH_E02F01.
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
    ls_view         TYPE /s4p0/v_enh_e02,
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

  lv_value = |'{ ls_view-param_name }'|.
  SELECT SINGLE * FROM /s4p0/sh_enh_par INTO @DATA(ls_enh_param) "TODO: handling of multiple entries needed
    WHERE attvalue = @lv_value
      AND clsname  = @ls_enh-clsname.
  lv_classname = ls_enh_param-clsname.
  lv_attribute = ls_enh_param-cmpname.

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
