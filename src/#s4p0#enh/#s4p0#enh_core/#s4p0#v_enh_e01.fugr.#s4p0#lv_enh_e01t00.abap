*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: /S4P0/V_ENH_E01.................................*
TABLES: /S4P0/V_ENH_E01, */S4P0/V_ENH_E01. "view work areas
CONTROLS: TCTRL_/S4P0/V_ENH_E01
TYPE TABLEVIEW USING SCREEN '0100'.
DATA: BEGIN OF STATUS_/S4P0/V_ENH_E01. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_/S4P0/V_ENH_E01.
* Table for entries selected to show on screen
DATA: BEGIN OF /S4P0/V_ENH_E01_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE /S4P0/V_ENH_E01.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF /S4P0/V_ENH_E01_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF /S4P0/V_ENH_E01_TOTAL OCCURS 0010.
INCLUDE STRUCTURE /S4P0/V_ENH_E01.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF /S4P0/V_ENH_E01_TOTAL.

*.........table declarations:.................................*
TABLES: /S4P0/T_ENH_E01                .
TABLES: /S4P0/T_ENH_E01T               .
