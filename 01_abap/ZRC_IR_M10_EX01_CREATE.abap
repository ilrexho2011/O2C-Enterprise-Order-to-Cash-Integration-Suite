*&---------------------------------------------------------------------*
*& Report ZRC_IR_M10_EX01  (Presentation Layer - Create Order)
*&---------------------------------------------------------------------*
*& Thirr VETEM Business API (Function Module). Nuk ka SQL direkt.
*&---------------------------------------------------------------------*
REPORT zrc_ir_m10_ex01.

PARAMETERS: p_cust  TYPE zrc_ir_de_customer_id OBLIGATORY,
            p_curr  TYPE waers DEFAULT 'EUR',
            p_total TYPE zrc_ir_order_hdr-total_amount.

START-OF-SELECTION.
  DATA: ls_order TYPE zrc_ir_order_hdr,
        ls_out   TYPE zrc_ir_order_hdr,
        lt_ret   TYPE bapiret2_t.

  ls_order-customer_id  = p_cust.
  ls_order-currency     = p_curr.
  ls_order-total_amount = p_total.
* ORDER_ID lihet bosh -> gjenerohet nga Number Range brenda FM-it.

  CALL FUNCTION 'ZRC_IR_FM_CREATE_ORDER'
    EXPORTING  is_order  = ls_order
    IMPORTING  es_order  = ls_out
    TABLES     et_return = lt_ret.

  LOOP AT lt_ret INTO DATA(ls_ret).
    WRITE: / ls_ret-type, ls_ret-message.
  ENDLOOP.
  IF line_exists( lt_ret[ type = 'S' ] ).
    WRITE: / 'Order ID i krijuar:', ls_out-order_id.
  ENDIF.
