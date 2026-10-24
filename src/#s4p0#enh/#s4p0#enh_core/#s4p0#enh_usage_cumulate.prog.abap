*&---------------------------------------------------------------------*
*& Report /S4P0/BC_ENH_USAGE_CUMULATE
*&---------------------------------------------------------------------*
*& Description
*& Cumlate usage counts of enhancements
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
REPORT /s4p0/bc_enh_usage_cumulate.

DATA: lv_dats      TYPE dats,
      ls_usage_cum TYPE /s4p0/t_enh_eusm.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.
PARAMETERS p_days TYPE /s4p0/de_enh_days_numb DEFAULT 10.
SELECTION-SCREEN END OF BLOCK b01.

START-OF-SELECTION.
  GET TIME.
  " Keep recent detail rows for troubleshooting; only older usage entries
  " are collapsed into monthly totals.
  lv_dats = sy-datum - p_days.

  " toDo: SELECT *
  SELECT * FROM /s4p0/t_enh_euse INTO TABLE @DATA(lt_usages)
    WHERE enh_used_at_date <= @lv_dats.

  LOOP AT lt_usages INTO DATA(ls_usage).
    CLEAR ls_usage_cum.

    " Cumulation keeps the enhancement key and stores usage by calendar
    " year/month to reduce detail-table growth.
    ls_usage_cum-enhancement     = ls_usage-enhancement.
    ls_usage_cum-sub_enhancement = ls_usage-sub_enhancement.
    ls_usage_cum-feature         = ls_usage-feature.
    ls_usage_cum-usage_year      = ls_usage-enh_used_at_date(4).
    ls_usage_cum-usage_month     = ls_usage-enh_used_at_date+4(2).

    SELECT SINGLE usage_total_count FROM /s4p0/t_enh_eusm
      INTO ls_usage_cum-usage_total_count
      WHERE enhancement     = ls_usage_cum-enhancement
        AND sub_enhancement = ls_usage_cum-sub_enhancement
        AND feature         = ls_usage_cum-feature
        AND usage_year      = ls_usage_cum-usage_year
        AND usage_month     = ls_usage_cum-usage_month.

    ADD 1 TO ls_usage_cum-usage_total_count.

    MODIFY /s4p0/t_enh_eusm FROM ls_usage_cum.
    DELETE /s4p0/t_enh_euse FROM ls_usage.
    " Commit per source row so a long-running cleanup does not roll back
    " all prior cumulations if one later row fails.
    COMMIT WORK AND WAIT.
  ENDLOOP.
