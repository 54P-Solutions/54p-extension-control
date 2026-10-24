interface /S4P0/IF_ENH_CONSTANTS
  public .


  interfaces /S4P0/IF_ENH_CONSTANT_BASE .

  constants GC_ENH_PARAM_TYPE_TVARVC type /S4P0/DE_ENH_PARAM_TYPE value 'TVARVC' ##NO_TEXT.
  constants GC_TVARVC_PARAM_TYPE_SELOPT type /S4P0/DE_ENH_RSSCR_KIND value 'S' ##NO_TEXT.
  constants GC_TVARVC_PARAM_TYPE_PARAM type /S4P0/DE_ENH_RSSCR_KIND value 'P' ##NO_TEXT.
  constants GC_ENH_CLNT_ACTIVE_USER_BASED type /S4P0/DE_ENH_ACTIVE value 'U' ##NO_TEXT.
  constants GC_ENH_CCC type /S4P0/DE_ENH_ID value '/S4P0/CCC' ##NO_TEXT.
  constants GC_SUB_ENH_CCC_BASE type /S4P0/DE_ENH_SUB_ENH_ID value '/S4P0/CCC_BASE' ##NO_TEXT.
endinterface.
