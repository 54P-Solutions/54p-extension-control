*----------------------------------------------------------------------*
***INCLUDE /S4P0/LV_ENH_E01I01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Module  /S4P0/ENH_E01_USR_CMD  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE /s4p0/enh_e02_usr_cmd INPUT.

  CASE function.

    WHEN '9WUL'.

      "Prevent that Standard-TMG is processing that FCODE
      CLEAR function.

      PERFORM show_class_where_used.

  ENDCASE.

ENDMODULE.
