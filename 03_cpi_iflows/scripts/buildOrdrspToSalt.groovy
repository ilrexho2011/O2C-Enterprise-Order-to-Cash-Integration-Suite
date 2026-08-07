/*
 * buildOrdrspToSalt.groovy
 * Pas deep-create sinkron në S/4, ndërton dokumentin kanonik ORDRSP (OrderEvent)
 * dhe e përgatit për HTTP receiver -> salt/api/integration/receive_event.php.
 */
import com.sap.gateway.ip.core.customdev.util.Message
import groovy.xml.XmlSlurper
import groovy.xml.MarkupBuilder

def Message processData(Message message) {
    def p = message.getProperties()
    // pergjigjja e OData permban OrderId + (opsional) items; lexojme OrderId
    def resp = message.getBody(String)
    def s4OrderId = ""
    try { s4OrderId = new XmlSlurper().parseText(resp).'**'.find { it.name()=='OrderId' }?.text() ?: "" } catch(e){}
    if (!s4OrderId) s4OrderId = p.get("s4OrderId") ?: ""

    // idso nxirret nga CorrelationId: SALT-<ZINN>-<idso6>-<rnd>
    def corr = p.get("correlationId") ?: ""
    def parts = corr.tokenize('-')
    def zinn  = parts.size() > 1 ? parts[1] : ""
    def idso  = parts.size() > 2 ? (parts[2] as Integer) : 0

    def sw = new StringWriter()
    def mb = new MarkupBuilder(sw)
    mb.OrderEvent(xmlns: 'urn:albsale:o2c:canonical:1.0') {
        Header {
            DocumentType('ORDRSP'); CorrelationId(corr); S4OrderId(s4OrderId); Message('Order confirmed')
        }
        Reference { CustomerRef(zinn); SaltOrderRef(idso) }
        Confirmation { Status('CONFIRMED'); ConfirmedQuantity(p.get('confirmedQty') ?: '0'); Unit('Ton') }
    }
    message.setBody(sw.toString())
    message.setHeader("Content-Type", "application/xml")
    message.setHeader("X-Inbound-Token", "{{SALT_INBOUND_TOKEN}}")   // externalized
    message.setProperty("step", "ORDRSP_TO_SALT")
    return message
}
