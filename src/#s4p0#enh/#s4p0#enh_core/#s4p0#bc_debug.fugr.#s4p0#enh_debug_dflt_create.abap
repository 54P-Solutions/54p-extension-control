FUNCTION /s4p0/enh_debug_dflt_create .
*"----------------------------------------------------------------------
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
*& 54P     01.02.2025  Initial Version
*&
*&---------------------------------------------------------------------*

  " Delegate to the update module so the default customizing row can be
  " committed independently of the process requesting debug support.
  CALL FUNCTION '/S4P0/ENH_DEBUG_DFLT_CREA_VB'
    EXPORTING
      iv_debug_area = iv_debug_area.

  COMMIT WORK.

ENDFUNCTION.
