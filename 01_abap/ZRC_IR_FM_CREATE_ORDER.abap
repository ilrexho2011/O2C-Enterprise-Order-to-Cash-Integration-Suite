*&---------------------------------------------------------------------*
*& Function Module  ZRC_IR_FM_CREATE_ORDER
*&---------------------------------------------------------------------*
*& Zemra e aplikacionit - krijon nje rekord ne ZRC_IR_ORDER_HDR
*& Flow: Validate -> Check Duplicate -> Lock -> INSERT -> COMMIT ->
*&       Application Log -> Unlock -> Return (BAPIRET2_T)
*&
*& Interface (kontrata enterprise, e gatshme per OData / SAP CI / RAP):
*&   IMPORTING  VALUE(IS_ORDER)    TYPE ZRC_IR_ORDER_HDR
*&              VALUE(IV_COMMIT)   TYPE ABAP_BOOL DEFAULT 'X'
*&   EXPORTING  VALUE(ES_ORDER)   TYPE ZRC_IR_ORDER_HDR
*&   TABLES     ET_RETURN         STRUCTURE BAPIRET2
*&
*& Properties: Remote-Enabled Module (RFC) -> thirret nga OData DPC & CI
*&---------------------------------------------------------------------*
FUNCTION zrc_ir_fm_create_order.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IS_ORDER) TYPE  ZRC_IR_ORDER_HDR
*"     VALUE(IV_COMMIT) TYPE  ABAP_BOOL DEFAULT 'X'
*"  EXPORTING
*"     VALUE(ES_ORDER) TYPE  ZRC_IR_ORDER_HDR
*"  TABLES
*"     ET_RETURN STRUCTURE  BAPIRET2 OPTIONAL
*"----------------------------------------------------------------------

  DATA: ls_order TYPE zrc_ir_order_hdr,
        lv_next  TYPE zrc_ir_de_order_id.

  CLEAR: es_order, et_return[].
  ls_order = is_order.
  ls_order-mandt = sy-mandt.

* ---------------------------------------------------------------------
* 1) VALIDIMI I INPUT-IT
* ---------------------------------------------------------------------
  IF ls_order-customer_id IS INITIAL.
    PERFORM add_return TABLES et_return
                       USING 'E' '006' ls_order-order_id space space space.
    RETURN.
  ENDIF.

* ---------------------------------------------------------------------
* 2) NUMBER RANGE - nese ORDER_ID vjen bosh, gjenerohet nga SNRO
*    Objekti: ZRC_IR_ORD, interval '01'
* ---------------------------------------------------------------------
  IF ls_order-order_id IS INITIAL.
    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr             = '01'
        object                  = 'ZRC_IR_ORD'
      IMPORTING
        number                  = lv_next
      EXCEPTIONS
        interval_not_found      = 1
        number_range_not_intern = 2
        object_not_found        = 3
        quantity_is_0           = 4
        OTHERS                  = 8.
    IF sy-subrc <> 0.
      PERFORM add_return TABLES et_return
                         USING 'E' '007' space space space space.
      RETURN.
    ENDIF.
    ls_order-order_id = |{ lv_next ALPHA = IN }|.
  ENDIF.

* ---------------------------------------------------------------------
* 3) KONTROLL DUPLIKATI
* ---------------------------------------------------------------------
  SELECT SINGLE order_id FROM zrc_ir_order_hdr
    INTO @DATA(lv_exist)
    WHERE order_id = @ls_order-order_id.
  IF sy-subrc = 0.
    PERFORM add_return TABLES et_return
                       USING 'E' '002' ls_order-order_id space space space.
    RETURN.
  ENDIF.

* ---------------------------------------------------------------------
* 4) LOCK (ENQUEUE)
* ---------------------------------------------------------------------
  CALL FUNCTION 'ENQUEUE_EZRC_IR_ORDER'
    EXPORTING
      mode_zrc_ir_order_hdr = 'E'
      mandt                 = sy-mandt
      order_id              = ls_order-order_id
    EXCEPTIONS
      foreign_lock          = 1
      system_failure        = 2
      OTHERS                = 3.
  IF sy-subrc <> 0.
    PERFORM add_return TABLES et_return
                       USING 'E' '008' ls_order-order_id space space space.
    RETURN.
  ENDIF.

* ---------------------------------------------------------------------
* 5) DEFAULT VALUES + INSERT
* ---------------------------------------------------------------------
  IF ls_order-status IS INITIAL.
    ls_order-status = gc_status_new.
  ENDIF.
  IF ls_order-order_date IS INITIAL.
    ls_order-order_date = sy-datum.
  ENDIF.

  INSERT zrc_ir_order_hdr FROM ls_order.
  IF sy-subrc <> 0.
    CALL FUNCTION 'DEQUEUE_EZRC_IR_ORDER'
      EXPORTING
        mandt    = sy-mandt
        order_id = ls_order-order_id.
    PERFORM add_return TABLES et_return
                       USING 'E' '009' ls_order-order_id space space space.
    RETURN.
  ENDIF.

* ---------------------------------------------------------------------
* 6) COMMIT
* ---------------------------------------------------------------------
  IF iv_commit = abap_true.
    COMMIT WORK AND WAIT.
  ENDIF.

* ---------------------------------------------------------------------
* 7) APPLICATION LOG (BAL) - SLG1 object ZRC_IR_ORDER
* ---------------------------------------------------------------------
  PERFORM write_appl_log USING 'CREATE' ls_order-order_id.

* ---------------------------------------------------------------------
* 8) DEQUEUE
* ---------------------------------------------------------------------
  CALL FUNCTION 'DEQUEUE_EZRC_IR_ORDER'
    EXPORTING
      mandt    = sy-mandt
      order_id = ls_order-order_id.

* ---------------------------------------------------------------------
* 9) RETURN SUCCESS
* ---------------------------------------------------------------------
  es_order = ls_order.
  PERFORM add_return TABLES et_return
                     USING 'S' '001' ls_order-order_id space space space.

ENDFUNCTION.

*&---------------------------------------------------------------------*
*&      Form  ADD_RETURN  (ndihmes - mbush nje rresht BAPIRET2)
*&---------------------------------------------------------------------*
FORM add_return TABLES ct_return STRUCTURE bapiret2
                USING  iv_type   TYPE bapi_mtype
                       iv_number TYPE symsgno
                       iv_v1     TYPE any
                       iv_v2     TYPE any
                       iv_v3     TYPE any
                       iv_v4     TYPE any.
  DATA: ls_ret TYPE bapiret2.
  ls_ret-type       = iv_type.
  ls_ret-id         = gc_msgid.
  ls_ret-number     = iv_number.
  ls_ret-message_v1 = iv_v1.
  ls_ret-message_v2 = iv_v2.
  ls_ret-message_v3 = iv_v3.
  ls_ret-message_v4 = iv_v4.
  MESSAGE ID gc_msgid TYPE iv_type NUMBER iv_number
          WITH iv_v1 iv_v2 iv_v3 iv_v4 INTO ls_ret-message.
  APPEND ls_ret TO ct_return.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  WRITE_APPL_LOG (BAL wrapper - i thjeshtezuar)
*&---------------------------------------------------------------------*
FORM write_appl_log USING iv_action   TYPE string
                          iv_order_id TYPE zrc_ir_de_order_id.
* Prodhim: BAL_LOG_CREATE / BAL_LOG_MSG_ADD / BAL_DB_SAVE.
* Ketu mbahet placeholder qe FM-t te mbeten te testueshem pa varesi BAL.
  DATA(lv_txt) = |{ iv_action } order { iv_order_id } by { sy-uname }|.
* CALL FUNCTION 'BAL_LOG_CREATE' ... (shih dokumentacionin Faza 4)
ENDFORM.
