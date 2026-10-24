FUNCTION /s4p0/enh_track_usage .
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_ENHANCEMENT_ID) TYPE  /S4P0/DE_ENH_ID
*"     VALUE(IV_SUB_ENHANCEMENT_ID) TYPE  /S4P0/DE_ENH_SUB_ENH_ID
*"       OPTIONAL
*"     VALUE(IV_FEATURE) TYPE  /S4P0/DE_ENH_FEATURE_ID OPTIONAL
*"----------------------------------------------------------------------
*& Description
*& Enhancement Framework track usage
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

  " Persist usage in an update module so callers can invoke tracking from
  " asynchronous RFC without changing their own database LUW.
  CALL FUNCTION '/S4P0/ENH_TRACK_USAGE_VB'
    EXPORTING
      iv_enhancement_id     = iv_enhancement_id
      iv_sub_enhancement_id = iv_sub_enhancement_id
      iv_feature            = iv_feature.

  " This function runs in its own task from CL_ENH_CORE, so the commit is
  " isolated from the checked business process.
  COMMIT WORK.

ENDFUNCTION.
