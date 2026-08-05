*&---------------------------------------------------------------------*
*& Function Module  ZRC_IR_FM_ADD_ITEM
*&---------------------------------------------------------------------*
*& Shton nje Item ne ZRC_IR_ORD_ITEM (kontrollon Header + Foreign Key)
*&---------------------------------------------------------------------*
FUNCTION zrc_ir_fm_add_item.
*"----------------------------------------------------------------------
*"  IMPORTING  VALUE(IS_ITEM)  TYPE  ZRC_IR_ORD_ITEM
*"             VALUE(IV_COMMIT) TYPE ABAP_BOOL DEFAULT 'X'
*"  TABLES     ET_RETURN STRUCTURE  BAPIRET2 OPTIONAL
*"----------------------------------------------------------------------
  DATA: ls_item TYPE zrc_ir_ord_item.
  CLEAR et_return[].
  ls_item = is_item.
  ls_item-mandt = sy-mandt.

* 1) Header duhet te ekzistoje (integriteti O2C)
  SELECT SINGLE order_id FROM zrc_ir_order_hdr
    INTO @DATA(lv_hdr)
    WHERE order_id = @ls_item-order_id.
  IF sy-subrc <> 0.
    PERFORM add_return TABLES et_return
                       USING 'E' '003' ls_item-order_id space space space.
    RETURN.
  ENDIF.

* 2) Item nuk duhet te ekzistoje
  SELECT SINGLE item_no FROM zrc_ir_ord_item
    INTO @DATA(lv_it)
    WHERE order_id = @ls_item-order_id
      AND item_no  = @ls_item-item_no.
  IF sy-subrc = 0.
    PERFORM add_return TABLES et_return
                       USING 'E' '004' ls_item-item_no space space space.
    RETURN.
  ENDIF.

* 3) Lock i itemit + INSERT
  CALL FUNCTION 'ENQUEUE_EZRC_IR_ORD_ITEM'
    EXPORTING
      mandt    = sy-mandt
      order_id = ls_item-order_id
      item_no  = ls_item-item_no
    EXCEPTIONS
      foreign_lock = 1
      OTHERS       = 2.
  IF sy-subrc <> 0.
    PERFORM add_return TABLES et_return
                       USING 'E' '008' ls_item-order_id space space space.
    RETURN.
  ENDIF.

  INSERT zrc_ir_ord_item FROM ls_item.
  IF sy-subrc <> 0.
    CALL FUNCTION 'DEQUEUE_EZRC_IR_ORD_ITEM'
      EXPORTING mandt = sy-mandt order_id = ls_item-order_id item_no = ls_item-item_no.
    PERFORM add_return TABLES et_return
                       USING 'E' '009' ls_item-order_id space space space.
    RETURN.
  ENDIF.

  IF iv_commit = abap_true.
    COMMIT WORK AND WAIT.
  ENDIF.

  CALL FUNCTION 'DEQUEUE_EZRC_IR_ORD_ITEM'
    EXPORTING mandt = sy-mandt order_id = ls_item-order_id item_no = ls_item-item_no.

  PERFORM add_return TABLES et_return
                     USING 'S' '010' ls_item-item_no ls_item-order_id space space.
ENDFUNCTION.
