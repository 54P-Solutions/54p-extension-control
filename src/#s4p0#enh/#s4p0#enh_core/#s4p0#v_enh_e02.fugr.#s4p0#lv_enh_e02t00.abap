*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: /S4P0/V_ENH_E02.................................*
TABLES: /S4P0/V_ENH_E02, */S4P0/V_ENH_E02. "view work areas
CONTROLS: TCTRL_/S4P0/V_ENH_E02
TYPE TABLEVIEW USING SCREEN '0100'.
DATA: BEGIN OF STATUS_/S4P0/V_ENH_E02. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_/S4P0/V_ENH_E02.
* Table for entries selected to show on screen
DATA: BEGIN OF /S4P0/V_ENH_E02_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE /S4P0/V_ENH_E02.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF /S4P0/V_ENH_E02_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF /S4P0/V_ENH_E02_TOTAL OCCURS 0010.
INCLUDE STRUCTURE /S4P0/V_ENH_E02.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF /S4P0/V_ENH_E02_TOTAL.

*.........table declarations:.................................*
TABLES: /S4P0/T_ENH_E02                .
