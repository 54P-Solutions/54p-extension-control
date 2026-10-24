FUNCTION /S4P0/ENH_TRACK_USAGE_VB .
*"----------------------------------------------------------------------
*"*"Update Function Module:
*"
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_ENHANCEMENT_ID) TYPE  /S4P0/DE_ENH_ID
*"     VALUE(IV_SUB_ENHANCEMENT_ID) TYPE  /S4P0/DE_ENH_SUB_ENH_ID
*"       OPTIONAL
*"     VALUE(IV_FEATURE) TYPE  /S4P0/DE_ENH_FEATURE_ID OPTIONAL
*"----------------------------------------------------------------------
*& Description
*& Enhancement Framework track usage update module
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

  DATA ls_usage_tracker TYPE /S4P0/t_enh_euse.

  ls_usage_tracker-enhancement     = iv_enhancement_id.
  ls_usage_tracker-sub_enhancement = iv_sub_enhancement_id.
  ls_usage_tracker-feature         = iv_feature.

  GET TIME STAMP FIELD ls_usage_tracker-enh_used_at_tstp.
  GET TIME.
  ls_usage_tracker-enh_used_at_date = sy-datum.

  " A generated GUID keeps repeated checks in the same second as distinct
  " detail rows for later cumulation.
  CALL FUNCTION 'SYSTEM_UUID_CREATE'
    IMPORTING
      uuid = ls_usage_tracker-guid.

  INSERT /S4P0/t_enh_euse FROM ls_usage_tracker.

ENDFUNCTION.




