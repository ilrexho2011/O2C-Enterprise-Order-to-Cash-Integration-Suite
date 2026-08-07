/*
 * mapSaltOrderToS4.groovy
 * Kthen XML-in kanonik OrderCreate (nga Salt) në payload JSON OData deep-create
 * për ZRC_IR_ORDER_SRV (CREATE_DEEP_ENTITY). ZINN->CustomerId, saltcode->ProductId.
 */
import com.sap.gateway.ip.core.customdev.util.Message
import groovy.xml.XmlSlurper
import groovy.json.JsonOutput

def Message processData(Message message) {
    def x = new XmlSlurper().parseText(message.getBody(String))
    message.setProperty("orderId", x.Header.CorrelationId.text())   // për monitorim
    message.setProperty("correlationId", x.Header.CorrelationId.text())

    def items = x.Lines.Line.collect { ln ->
        [ ItemNo   : ln.LineNo.text(),
          ProductId: ln.ProductRef.text(),         // saltcode -> PRODUCT_ID
          Quantity : ln.Quantity.text(),
          Unit     : ln.Unit.text(),
          Price    : ln.LineValue.text(),
          Currency : ln.Currency.text() ]
    }

    def payload = [
        CustomerId : x.Buyer.CustomerRef.text(),    // ZINN -> CUSTOMER_ID
        Currency   : x.Summary.Currency.text(),
        TotalAmount: x.Summary.TotalValue.text(),
        Status     : "N",
        ToItems    : items
    ]

    message.setBody(JsonOutput.toJson(payload))
    message.setHeader("Content-Type", "application/json")
    message.setProperty("step", "MAP_TO_S4")
    return message
}
