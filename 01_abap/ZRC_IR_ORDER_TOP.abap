*&---------------------------------------------------------------------*
*& Include          ZRC_IR_ORDER_TOP  (Function Group ZRC_IR_ORDER)
*&---------------------------------------------------------------------*
*& OrderFlow O2C - Business API TOP include
*& Author : Ilirjan Rexho (ZRC_IR_*)
*& Layer  : APPLICATION / BUSINESS API
*&---------------------------------------------------------------------*
FUNCTION-POOL zrc_ir_order.

* Global types reused by all Function Modules of the API
TYPES: BEGIN OF ty_order_key,
         mandt    TYPE mandt,
         order_id TYPE zrc_ir_de_order_id,
       END OF ty_order_key.

* Event envelope serialized to JSON for the outbound CI notifier
TYPES: BEGIN OF ty_event,
         event    TYPE string,
         order_id TYPE zrc_ir_de_order_id,
         header   TYPE zrc_ir_order_hdr,
         items    TYPE STANDARD TABLE OF zrc_ir_ord_item WITH EMPTY KEY,
       END OF ty_event.

* Return table type (BAPIRET2_T) - the enterprise contract for CI/OData/RAP
DATA: gt_return TYPE bapiret2_t.

* Message class used across the whole API
CONSTANTS: gc_msgid TYPE symsgid VALUE 'ZRC_IR_MSG'.

* Status domain fixed values (mirror of domain ZRC_IR_ORDER_STATUS)
CONSTANTS: gc_status_new       TYPE zrc_ir_de_order_status VALUE 'N',
           gc_status_processing TYPE zrc_ir_de_order_status VALUE 'P',
           gc_status_completed  TYPE zrc_ir_de_order_status VALUE 'C',
           gc_status_cancelled  TYPE zrc_ir_de_order_status VALUE 'X'.
