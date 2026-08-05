*&---------------------------------------------------------------------*
*& ZRC_IR_FM_GET_ORDER / UPDATE_ORDER / DELETE_ORDER
*& Tre FM-t e mbetur te Business API (Function Group ZRC_IR_ORDER)
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& ZRC_IR_FM_GET_ORDER  - Lexon Header + Items (per ALV / OData / CI GET)
*&---------------------------------------------------------------------*
FUNCTION zrc_ir_fm_get_order.
*"  IMPORTING VALUE(IV_ORDER_ID) TYPE ZRC_IR_DE_ORDER_ID
*"  EXPORTING VALUE(ES_HEADER)   TYPE ZRC_IR_ORDER_HDR
*"  TABLES    ET_ITEMS  STRUCTURE ZRC_IR_ORD_ITEM OPTIONAL
*"            ET_RETURN STRUCTURE BAPIRET2 OPTIONAL
  CLEAR: es_header, et_items[], et_return[].

  SELECT SINGLE * FROM zrc_ir_order_hdr
    INTO CORRESPONDING FIELDS OF es_header
    WHERE order_id = iv_order_id.
  IF sy-subrc <> 0.
    PERFORM add_return TABLES et_return
                       USING 'E' '003' iv_order_id space space space.
    RETURN.
  ENDIF.

  SELECT * FROM zrc_ir_ord_item
    INTO CORRESPONDING FIELDS OF TABLE et_items
    WHERE order_id = iv_order_id.

  PERFORM add_return TABLES et_return
                     USING 'S' '011' iv_order_id space space space.
ENDFUNCTION.

*&---------------------------------------------------------------------*
*& ZRC_IR_FM_UPDATE_ORDER - perditeson status/currency/total me lock
*&---------------------------------------------------------------------*
FUNCTION zrc_ir_fm_update_order.
*"  IMPORTING VALUE(IS_ORDER) TYPE ZRC_IR_ORDER_HDR
*"            VALUE(IV_COMMIT) TYPE ABAP_BOOL DEFAULT 'X'
*"  TABLES    ET_RETURN STRUCTURE BAPIRET2 OPTIONAL
  DATA: ls_db TYPE zrc_ir_order_hdr.
  CLEAR et_return[].

  SELECT SINGLE * FROM zrc_ir_order_hdr INTO ls_db
    WHERE order_id = is_order-order_id.
  IF sy-subrc <> 0.
    PERFORM add_return TABLES et_return
                       USING 'E' '003' is_order-order_id space space space.
    RETURN.
  ENDIF.

  CALL FUNCTION 'ENQUEUE_EZRC_IR_ORDER'
    EXPORTING mandt = sy-mandt order_id = is_order-order_id
    EXCEPTIONS foreign_lock = 1 OTHERS = 2.
  IF sy-subrc <> 0.
    PERFORM add_return TABLES et_return
                       USING 'E' '008' is_order-order_id space space space.
    RETURN.
  ENDIF.

  ls_db-status       = is_order-status.
  ls_db-currency     = is_order-currency.
  ls_db-total_amount = is_order-total_amount.

  UPDATE zrc_ir_order_hdr FROM ls_db.
  IF iv_commit = abap_true.
    COMMIT WORK AND WAIT.
  ENDIF.

  CALL FUNCTION 'DEQUEUE_EZRC_IR_ORDER'
    EXPORTING mandt = sy-mandt order_id = is_order-order_id.

  PERFORM add_return TABLES et_return
                     USING 'S' '012' is_order-order_id space space space.
ENDFUNCTION.

*&---------------------------------------------------------------------*
*& ZRC_IR_FM_DELETE_ORDER - fshin Items pastaj Header brenda nje LUW
*&---------------------------------------------------------------------*
FUNCTION zrc_ir_fm_delete_order.
*"  IMPORTING VALUE(IV_ORDER_ID) TYPE ZRC_IR_DE_ORDER_ID
*"            VALUE(IV_COMMIT) TYPE ABAP_BOOL DEFAULT 'X'
*"  TABLES    ET_RETURN STRUCTURE BAPIRET2 OPTIONAL
  CLEAR et_return[].

  SELECT SINGLE order_id FROM zrc_ir_order_hdr INTO @DATA(lv_x)
    WHERE order_id = @iv_order_id.
  IF sy-subrc <> 0.
    PERFORM add_return TABLES et_return
                       USING 'E' '003' iv_order_id space space space.
    RETURN.
  ENDIF.

  CALL FUNCTION 'ENQUEUE_EZRC_IR_ORDER'
    EXPORTING mandt = sy-mandt order_id = iv_order_id
    EXCEPTIONS foreign_lock = 1 OTHERS = 2.
  IF sy-subrc <> 0.
    PERFORM add_return TABLES et_return
                       USING 'E' '008' iv_order_id space space space.
    RETURN.
  ENDIF.

  DELETE FROM zrc_ir_ord_item  WHERE order_id = iv_order_id.
  DELETE FROM zrc_ir_order_hdr WHERE order_id = iv_order_id.

  IF iv_commit = abap_true.
    COMMIT WORK AND WAIT.
  ENDIF.

  CALL FUNCTION 'DEQUEUE_EZRC_IR_ORDER'
    EXPORTING mandt = sy-mandt order_id = iv_order_id.

  PERFORM add_return TABLES et_return
                     USING 'S' '005' iv_order_id space space space.
ENDFUNCTION.
