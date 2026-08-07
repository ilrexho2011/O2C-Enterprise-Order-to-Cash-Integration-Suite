/*
 * mapToPostgresInsert.groovy
 * Kthen payload-in e porosise (XML nga S/4 pergjigjja) ne nje mesazh XML
 * qe JDBC receiver-i i CI-t e ekzekuton si INSERT (format standard i JDBC adapter).
 * Idempotent: perdor CorrelationId si celes natyral (ON CONFLICT DO NOTHING behet nga DB).
 */
import com.sap.gateway.ip.core.customdev.util.Message
import groovy.xml.XmlSlurper
import groovy.xml.MarkupBuilder

def Message processData(Message message) {
    def p    = message.getProperties()
    def body = message.getBody(String)
    def x    = new XmlSlurper().parseText(body)

    def orderId  = x.'**'.find { it.name() == 'OrderId' }?.text() ?: p.get("orderId")
    def customer = x.'**'.find { it.name() == 'CustomerId' }?.text() ?: ""
    def total    = x.'**'.find { it.name() == 'TotalAmount' }?.text() ?: "0"
    def currency = x.'**'.find { it.name() == 'Currency' }?.text() ?: ""
    def status   = x.'**'.find { it.name() == 'Status' }?.text() ?: "N"

    def sw = new StringWriter()
    def mb = new MarkupBuilder(sw)
    // Format XML i JDBC Receiver: root -> StatementName -> table (action=INSERT)
    mb.'root' {
        'statement' {
            'zrc_ir_bkp_order'(action: 'INSERT') {
                'table'('zrc_ir_bkp_order')
                'access' {
                    'correlation_id'(p.get("correlationId"))
                    'order_id'(orderId)
                    'customer_id'(customer)
                    'total_amount'(total)
                    'currency'(currency)
                    'status'(status)
                    'source_system'('S4H')
                    'scenario_id'(p.get("scenarioId"))
                    'payload_json'(body)
                    'created_at'(new Date().format("yyyy-MM-dd HH:mm:ss"))
                }
            }
        }
    }
    message.setBody(sw.toString())
    message.setProperty("step", "PG_BACKUP")
    return message
}
