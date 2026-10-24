class /S4P0/CL_ENH_UTILS definition
  public
  final
  create public .

public section.

  constants GC_MAX_DEBUG_WAIT_SEC_DEFAULT type /S4P0/DE_ENH_WAIT_SEC value '60' ##NO_TEXT.

  class-methods DEBUG_VIA_LOOP
    importing
      value(IV_DEBUG_AREA) type /S4P0/DE_ENH_DEBUG_AREA .
  class-methods WAIT_UP_TO_MILLISECONDS
    importing
      !IV_MILLISECONDS type I .
  class-methods SHOW_PROTOTYPE_INDICATION .
protected section.
private section.
ENDCLASS.



CLASS /S4P0/CL_ENH_UTILS IMPLEMENTATION.


METHOD debug_via_loop.
*&---------------------------------------------------------------------*
*& Description
*& Create a conditional and limited endless loop to be able to debug
*& e.g. external interfaces via process debugging in SM50 or SM66
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
"Hallo Hermle
  DATA: lv_tstamp_now       TYPE timestamp,
        lv_tstamp_end       TYPE timestamp,
        lv_gui_is_available TYPE boolean.

  GET TIME STAMP FIELD lv_tstamp_now.

  TRANSLATE iv_debug_area TO UPPER CASE.

  " toDo: SELECT *
  SELECT SINGLE * FROM /s4p0/t_enh_debg INTO @DATA(ls_debug_setting)
    WHERE debug_area = @iv_debug_area.
  IF ls_debug_setting IS INITIAL.
    " Create the inactive default record asynchronously so the triggering
    " process does not commit or lock while preparing debug customizing.
    CALL FUNCTION '/S4P0/ENH_DEBUG_DFLT_CREATE'
      DESTINATION 'NONE'
      STARTING NEW TASK 'NEWDEB'
      EXPORTING
        iv_debug_area = iv_debug_area.
    RETURN.
  ENDIF.

  IF ls_debug_setting-valid_to_tstp <= lv_tstamp_now
    OR ls_debug_setting-active = abap_false.
    RETURN.
  ENDIF.

  IF ls_debug_setting-waiting_time_sec < 1.
    " Guard against an invalid maintained wait time causing an immediate
    " exit or an unbounded loop.
    ls_debug_setting-waiting_time_sec = gc_max_debug_wait_sec_default.
  ENDIF.

  CALL FUNCTION 'TIMESTAMP_DURATION_ADD'
    EXPORTING
      timestamp_in    = lv_tstamp_now
      duration        = ls_debug_setting-waiting_time_sec
      unit            = 'S'
    IMPORTING
      timestamp_out   = lv_tstamp_end
    EXCEPTIONS
      timestamp_error = 1
      OTHERS          = 2.
  IF sy-subrc <> 0 OR lv_tstamp_end <= lv_tstamp_now.
    RETURN.
  ENDIF.

  CALL FUNCTION 'GUI_IS_AVAILABLE'
    IMPORTING
      return = lv_gui_is_available.

  WHILE lv_tstamp_now < lv_tstamp_end.
    "WAIT UP TO 1 SECONDS. "wait does not show up in SM66
    GET TIME STAMP FIELD lv_tstamp_now.

    " Break only in the configured dialog user session; background or
    " external sessions just spin until SM50/SM66 debugging attaches.
    IF lv_gui_is_available = abap_true
      AND ls_debug_setting-debug_user = sy-uname.
      BREAK-POINT.
      EXIT.
    ENDIF.
  ENDWHILE.

ENDMETHOD.


METHOD show_prototype_indication.

  DATA lv_msg(100).

  MESSAGE w000 INTO lv_msg.

  CALL FUNCTION 'POPUP_TO_INFORM'
    EXPORTING
      titel = space
      txt1  = lv_msg
      txt2  = space.

ENDMETHOD.


METHOD wait_up_to_milliseconds.
*&---------------------------------------------------------------------*
*& Description
*& As ABAP "WAIT UP TO" only supports seconds, there is the need for lower
*& intervalls
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

  DATA: lv_timestamp_start TYPE tzntstmpl,
        lv_timestamp_curr  TYPE tzntstmpl,
        lv_diff            TYPE p.

  IF iv_milliseconds <= 0.
    RETURN.
  ENDIF.

  GET TIME STAMP FIELD lv_timestamp_start.
  " ABAP WAIT works in seconds; the busy wait is intentional for short
  " millisecond waits where releasing the work process would be too coarse.
  WHILE ( lv_diff < iv_milliseconds ).
    GET TIME STAMP FIELD lv_timestamp_curr.
    lv_diff = ( lv_timestamp_curr - lv_timestamp_start ) * 1000.
  ENDWHILE.

ENDMETHOD.
ENDCLASS.
