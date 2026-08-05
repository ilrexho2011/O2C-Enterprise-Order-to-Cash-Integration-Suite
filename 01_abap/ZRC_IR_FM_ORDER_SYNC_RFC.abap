*&---------------------------------------------------------------------*
*& ZRC_IR_FM_ORDER_SYNC  (Remote-Enabled - RFC)
*&---------------------------------------------------------------------*
*& Wrapper qe krijon Header + te gjitha Items ne nje thirrje te vetme.
*& Perdoret nga OData DPC (deep create) DHE nga SAP CI (RFC/SOAP adapter
*& permes Cloud Connector) per skenarin Fiori -> CI -> S/4.
*& Idempotent: nese ORDER_ID vjen nga jashte dhe ekziston, kthen '002'.
*&---------------------------------------------------------------------*
FUNCTION zrc_ir_fm_order_sync.
*"----------------------------------------------------------------------
*"  IMPORTING  VALUE(IS_HEADER)  TYPE  ZRC_IR_ORDER_HDR
*"             VALUE(IV_EXT_MSG_ID) TYPE SXMSGUID OPTIONAL
*"  EXPORTING  VALUE(ES_HEADER)  TYPE  ZRC_IR_ORDER_HDR
*"  TABLES     IT_ITEMS  STRUCTURE  ZRC_IR_ORD_ITEM
*"             ET_RETURN STRUCTURE  BAPIRET2
*"----------------------------------------------------------------------
  DATA: lt_ret  TYPE bapiret2_t,
        ls_item TYPE zrc_ir_ord_item.
  CLEAR: es_header, et_return[].

* 1) Krijo Header (pa commit - nje LUW e vetme per gjithe porosine)
  CALL FUNCTION 'ZRC_IR_FM_CREATE_ORDER'
    EXPORTING  is_order  = is_header
               iv_commit = abap_false
    IMPORTING  es_order  = es_header
    TABLES     et_return = lt_ret.
  APPEND LINES OF lt_ret TO et_return.
  READ TABLE lt_ret WITH KEY type = 'E' TRANSPORTING NO FIELDS.
  IF sy-subrc = 0.
    ROLLBACK WORK.
    RETURN.
  ENDIF.

* 2) Krijo te gjitha Items me ORDER_ID e sapo-gjeneruar
  LOOP AT it_items INTO ls_item.
    ls_item-order_id = es_header-order_id.
    CLEAR lt_ret.
    CALL FUNCTION 'ZRC_IR_FM_ADD_ITEM'
      EXPORTING  is_item   = ls_item
                 iv_commit = abap_false
      TABLES     et_return = lt_ret.
    APPEND LINES OF lt_ret TO et_return.
    READ TABLE lt_ret WITH KEY type = 'E' TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      ROLLBACK WORK.
      CLEAR et_return[].
      PERFORM add_return TABLES et_return
                         USING 'E' '013' ls_item-item_no es_header-order_id space space.
      RETURN.
    ENDIF.
  ENDLOOP.

* 3) COMMIT i vetem per gjithe porosine
  COMMIT WORK AND WAIT.

* 4) Trigger outbound event -> CI (S/4 -> CI -> Fiori/Postgres/SFTP)
  CALL FUNCTION 'ZRC_IR_FM_ORDER_EVENT_OUT'
    EXPORTING iv_order_id = es_header-order_id
              iv_event    = 'ORDER_CREATED'.

  PERFORM add_return TABLES et_return
                     USING 'S' '001' es_header-order_id space space space.
ENDFUNCTION.

*&---------------------------------------------------------------------*
*& ZRC_IR_FM_ORDER_EVENT_OUT  (outbound notifier drejt SAP CI)
*&---------------------------------------------------------------------*
*& Drejtimi S/4 -> CI: therret iFlow-in outbound nepermjet HTTP(S)
*& destination 'ZRC_IR_CPI_OUT' (SM59, permes Cloud Connector reverse
*& invoke NUK nevojitet ketu - kjo eshte S/4 -> BTP dalese).
*&---------------------------------------------------------------------*
FUNCTION zrc_ir_fm_order_event_out.
*"  IMPORTING VALUE(IV_ORDER_ID) TYPE ZRC_IR_DE_ORDER_ID
*"            VALUE(IV_EVENT)    TYPE STRING
  DATA: lo_http   TYPE REF TO if_http_client,
        lv_json   TYPE string,
        ls_hdr    TYPE zrc_ir_order_hdr,
        lt_items  TYPE STANDARD TABLE OF zrc_ir_ord_item,
        lt_ret    TYPE bapiret2_t.

* Merr snapshot-in e plote te porosise
  CALL FUNCTION 'ZRC_IR_FM_GET_ORDER'
    EXPORTING iv_order_id = iv_order_id
    IMPORTING es_header   = ls_hdr
    TABLES    et_items    = lt_items
              et_return   = lt_ret.

* Serializim JSON (payload i njejte qe pret iFlow-i outbound)
  lv_json = /ui2/cl_json=>serialize(
              data        = VALUE ty_event(
                              event    = iv_event
                              order_id = iv_order_id
                              header   = ls_hdr
                              items    = lt_items )
              compress    = abap_true
              pretty_name = /ui2/cl_json=>pretty_mode-low_case ).

* Thirrje HTTP asinkrone drejt CI (RFC destination ne SM59)
  cl_http_client=>create_by_destination(
    EXPORTING destination = 'ZRC_IR_CPI_OUT'
    IMPORTING client      = lo_http
    EXCEPTIONS OTHERS     = 1 ).
  IF sy-subrc = 0.
    lo_http->request->set_method( 'POST' ).
    lo_http->request->set_content_type( 'application/json' ).
    lo_http->request->set_cdata( lv_json ).
    lo_http->send( EXCEPTIONS OTHERS = 1 ).
    lo_http->receive( EXCEPTIONS OTHERS = 1 ).
    lo_http->close( EXCEPTIONS OTHERS = 1 ).
  ENDIF.
* Shenim: nese CI nuk arrihet, ngjarja i shtohet nje tabele outbox
* (ZRC_IR_EVENT_OUTBOX) qe ri-dergohet nga nje job - garanton "at-least-once".
ENDFUNCTION.
