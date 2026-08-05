*&---------------------------------------------------------------------*
*& Class ZCL_ZRC_IR_ORDER_DPC_EXT  (OData Data Provider - redefinition)
*&---------------------------------------------------------------------*
*& Vetem metoda kryesore: CREATE_DEEP_ENTITY -> ZRC_IR_FM_ORDER_SYNC
*&---------------------------------------------------------------------*
METHOD /iwbep/if_mgw_appl_srv_runtime~create_deep_entity.

  TYPES: BEGIN OF ty_deep,
           orderid     TYPE zrc_ir_de_order_id,
           customerid  TYPE zrc_ir_de_customer_id,
           orderdate   TYPE dats,
           status      TYPE zrc_ir_de_order_status,
           totalamount TYPE zrc_ir_order_hdr-total_amount,
           currency    TYPE waers,
           toitems     TYPE STANDARD TABLE OF zrc_ir_ord_item WITH DEFAULT KEY,
         END OF ty_deep.

  DATA: ls_deep   TYPE ty_deep,
        ls_hdr    TYPE zrc_ir_order_hdr,
        ls_out    TYPE zrc_ir_order_hdr,
        lt_items  TYPE STANDARD TABLE OF zrc_ir_ord_item,
        lt_return TYPE bapiret2_t.

* 1) Lexo payload-in e thelle (Header + ToItems)
  io_data_provider->read_entry_data( IMPORTING es_data = ls_deep ).

  MOVE-CORRESPONDING ls_deep TO ls_hdr.
  lt_items = ls_deep-toitems.

* 2) Deleguar te Business API (nje LUW, nje COMMIT)
  CALL FUNCTION 'ZRC_IR_FM_ORDER_SYNC'
    EXPORTING is_header = ls_hdr
    IMPORTING es_header = ls_out
    TABLES    it_items  = lt_items
              et_return = lt_return.

* 3) Perkthe gabimet ne exception OData
  LOOP AT lt_return INTO DATA(ls_ret) WHERE type CA 'EA'.
    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING textid  = /iwbep/cx_mgw_busi_exception=>business_error
                message = ls_ret-message.
  ENDLOOP.

* 4) Kthe entitetin e krijuar (me OrderId e gjeneruar)
  copy_data_to_ref( EXPORTING is_data = ls_out
                    CHANGING  cr_data = er_deep_entity ).
ENDMETHOD.
