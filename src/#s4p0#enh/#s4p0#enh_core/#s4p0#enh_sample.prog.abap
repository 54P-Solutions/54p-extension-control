*&---------------------------------------------------------------------*
*& Report /S4P0/ENH_SAMPLE
*&---------------------------------------------------------------------*
*& Description
*& Sample for demonstrate the use of enhancement control framework
*&
*& Developer
*& 54P; support@54p.eu
*&
*& Consultant (internal contact)
*&
*&---------------------------------------------------------------------*
*& Changelog
*& Username    Date     #Ticket: Description of change
*& 54P         20260101 Initial Version
*&
*&---------------------------------------------------------------------*
REPORT /s4p0/enh_sample.

START-OF-SELECTION.

  DATA(lr_enh_frw) = /s4p0/cl_enh_core=>get_instance(
    iv_enhancement     = /s4p0/if_enh_sample_constants=>gc_enh_sample
    iv_sub_enhancement = /s4p0/if_enh_sample_constants=>gc_sub_enh_sample
    iv_feature         = /s4p0/if_enh_sample_constants=>gc_feature_sample ).

  IF lr_enh_frw->is_enhancement_active( ) = abap_true.
    WRITE / 'Enhancement is active'.

    LOOP AT lr_enh_frw->get_enh_params_all( ) INTO DATA(ls_enh_params).
      LOOP AT ls_enh_params-as_value INTO DATA(ls_param).
        WRITE: / 'Parameter Name: ', ls_enh_params-param_name,
               / 'Parameter Value 1: ', ls_param-param_value1,
               / 'Parameter Value 2: ', ls_param-param_value2,
               / 'Parameter Value 3: ', ls_param-param_value3.
      ENDLOOP.
    ENDLOOP.
  ELSE.
    WRITE / 'Enhancement is not active'.
  ENDIF.
