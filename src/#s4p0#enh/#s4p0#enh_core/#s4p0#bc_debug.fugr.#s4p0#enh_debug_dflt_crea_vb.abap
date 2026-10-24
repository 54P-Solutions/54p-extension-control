FUNCTION /S4P0/ENH_DEBUG_DFLT_CREA_VB .
*"----------------------------------------------------------------------
*"*"Update Function Module:
*"
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_DEBUG_AREA) TYPE  /S4P0/DE_ENH_DEBUG_AREA
*"----------------------------------------------------------------------
*& Description
*& Creates the empty entry of a conditional and limited endless loop
*& to be able to debug e.g. external interfaces via process debugging
*& in SM50 or SM66. This fm is called in a separate LUW to not interfere
*& with the process that creates it.
*& Setup for breakpoints needs to be done in SM30 /S4P0/V_ENH_DEBG
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

  DATA: ls_debug_setting TYPE /S4P0/t_enh_debg,
        lv_timestamp     TYPE timestamp.

  ls_debug_setting-debug_area = iv_debug_area.
  ls_debug_setting-waiting_time_sec = /S4P0/cl_enh_utils=>gc_max_debug_wait_sec_default.
  GET TIME STAMP FIELD lv_timestamp.
  MOVE lv_timestamp TO ls_debug_setting-valid_to_tstp.
  ls_debug_setting-debug_user = space.
  ls_debug_setting-active = abap_false.

  " The default row is inactive and already expired; an administrator must
  " deliberately maintain it before any process enters the debug wait loop.
  INSERT /S4P0/t_enh_debg FROM ls_debug_setting.

ENDFUNCTION.




