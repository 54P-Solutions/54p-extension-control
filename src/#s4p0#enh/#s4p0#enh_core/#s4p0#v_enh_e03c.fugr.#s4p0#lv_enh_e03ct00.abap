*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: /S4P0/V_ENH_E03C..................................*
TABLES: /S4P0/V_ENH_E03C, */S4P0/V_ENH_E03C. "view work areas
CONTROLS: TCTRL_/S4P0/V_ENH_E03C
TYPE TABLEVIEW USING SCREEN '0100'.
DATA: BEGIN OF STATUS_/S4P0/V_ENH_E03C. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_/S4P0/V_ENH_E03C.
* Table for entries selected to show on screen
DATA: BEGIN OF /S4P0/V_ENH_E03C_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE /S4P0/V_ENH_E03C.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF /S4P0/V_ENH_E03C_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF /S4P0/V_ENH_E03C_TOTAL OCCURS 0010.
INCLUDE STRUCTURE /S4P0/V_ENH_E03C.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF /S4P0/V_ENH_E03C_TOTAL.

*.........table declarations:.................................*
TABLES: /S4P0/T_ENH_E03C                 .
