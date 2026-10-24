interface /S4P0/IF_CCC_METRICS_CONST
  public .


  constants GC_RUN_STATUS_STARTED type /S4P0/DE_CCC_RUN_STATUS value 'C' ##NO_TEXT.
  constants GC_RUN_STATUS_PROGRESS type /S4P0/DE_CCC_RUN_STATUS value 'P' ##NO_TEXT.
  constants GC_RUN_STATUS_FINISHED_OK type /S4P0/DE_CCC_RUN_STATUS value 'S' ##NO_TEXT.
  constants GC_RUN_STATUS_FINISHED_ERROR type /S4P0/DE_CCC_RUN_STATUS value 'E' ##NO_TEXT.
  constants GC_RUN_TYPE_FULL_SCOPE type /S4P0/DE_CCC_RUN_TYPE value 'F' ##NO_TEXT.
  constants GC_RUN_TYPE_DELTA type /S4P0/DE_CCC_RUN_TYPE value 'D' ##NO_TEXT.
  constants GC_RUN_TYPE_SPECIAL_SEL type /S4P0/DE_CCC_RUN_TYPE value 'S' ##NO_TEXT.
  constants GC_RUN_TYPE_TRANSPORT_BASED type /S4P0/DE_CCC_RUN_TYPE value 'T' ##NO_TEXT.
endinterface.
