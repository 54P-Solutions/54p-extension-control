*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: /S4P0/V_ENH_E01C................................*
TABLES: /S4P0/V_ENH_E01C, */S4P0/V_ENH_E01C. "view work areas
CONTROLS: TCTRL_/S4P0/V_ENH_E01C
TYPE TABLEVIEW USING SCREEN '0100'.
DATA: BEGIN OF STATUS_/S4P0/V_ENH_E01C. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_/S4P0/V_ENH_E01C.
* Table for entries selected to show on screen
DATA: BEGIN OF /S4P0/V_ENH_E01C_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE /S4P0/V_ENH_E01C.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF /S4P0/V_ENH_E01C_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF /S4P0/V_ENH_E01C_TOTAL OCCURS 0010.
INCLUDE STRUCTURE /S4P0/V_ENH_E01C.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF /S4P0/V_ENH_E01C_TOTAL.

*.........table declarations:.................................*
TABLES: /S4P0/T_ENH_E01                .
TABLES: /S4P0/T_ENH_E01C               .
TABLES: /S4P0/T_ENH_E01T               .
