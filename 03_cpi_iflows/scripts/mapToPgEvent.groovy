/*
 * mapToPgEvent.groovy
 * Kthen OrderEvent-in kanonik në XML për JDBC receiver -> zrc_ir_bkp_order_event (audit).
 */
import com.sap.gateway.ip.core.customdev.util.Message
import groovy.xml.XmlSlurper
import groovy.xml.MarkupBuilder

def Message processData(Message message) {
    def p    = message.getProperties()
    def body = message.getBody(String)
    def x    = new XmlSlurper().parseText(body)

    def sw = new StringWriter()
    def mb = new MarkupBuilder(sw)
    mb.'root' {
        'statement' {
            'zrc_ir_bkp_order_event'(action: 'INSERT') {
                'table'('zrc_ir_bkp_order_event')
                'access' {
                    'correlation_id'(x.Header.CorrelationId.text())
                    'order_id'(x.Header.S4OrderId.text())
                    'event_type'(x.Header.DocumentType.text())
                    'payload_xml'(body)
                    'created_at'(new Date().format("yyyy-MM-dd HH:mm:ss"))
                }
            }
        }
    }
    message.setBody(sw.toString())
    message.setProperty("step", "PG_EVENT_AUDIT")
    return message
}
