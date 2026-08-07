/*
 * mapIdocToCanonical.groovy
 * Kthen IDoc-un dalës të S/4 (ORDRSP / DESADV / INVOIC02) në XML kanonik OrderEvent.
 * Mode-i përcaktohet nga property 'ediMode' (vendoset nga Router-i i iFlow 04).
 * Shënim: hartimet e segmenteve janë të thjeshtëzuara; për IDoc real lidh E1EDK*/E1EDP*.
 */
import com.sap.gateway.ip.core.customdev.util.Message
import groovy.xml.XmlSlurper
import groovy.xml.MarkupBuilder

def Message processData(Message message) {
    def p    = message.getProperties()
    def mode = p.get("ediMode") ?: "ORDRSP"
    def x    = new XmlSlurper().parseText(message.getBody(String))

    // Fusha të përbashkëta nga IDoc-u (segmentet reale ndryshojnë sipas tipit)
    def find = { name -> x.'**'.find { it.name() == name }?.text() ?: "" }
    def corr   = find('CorrelationId') ?: p.get('correlationId') ?: ""
    def s4ord  = find('OrderId') ?: find('BELNR') ?: ""
    def zinn   = find('CustomerId') ?: find('PARTN') ?: ""
    def idso   = corr.tokenize('-').with { it.size() > 2 ? it[2] as Integer : 0 }

    def sw = new StringWriter()
    def mb = new MarkupBuilder(sw)
    mb.OrderEvent(xmlns: 'urn:albsale:o2c:canonical:1.0') {
        Header { DocumentType(mode); CorrelationId(corr); S4OrderId(s4ord); Message("${mode} from S/4") }
        Reference { CustomerRef(zinn); SaltOrderRef(idso) }
        if (mode == 'ORDRSP') {
            Confirmation { Status('CONFIRMED'); ConfirmedQuantity(find('QUANTITY') ?: '0'); Unit('Ton') }
        } else if (mode == 'DESADV') {
            Despatch {
                Status('DELIVERED'); DeliveryNo(find('VBELN') ?: find('DeliveryNo'))
                DespatchDate(find('DespatchDate') ?: ''); DeliveredQuantity(find('LFIMG') ?: '0'); Unit('Ton')
            }
        } else if (mode == 'INVOIC') {
            Invoice {
                Status('INVOICED'); InvoiceNo(find('VBELN') ?: find('InvoiceNo'))
                NetAmount(find('NetAmount') ?: '0'); TaxAmount(find('TaxAmount') ?: '0')
                GrossAmount(find('GrossAmount') ?: '0'); Currency(find('Currency') ?: 'EU'); PaymentTerms('NET30')
            }
        }
    }
    message.setBody(sw.toString())
    message.setProperty("orderId", corr)
    message.setProperty("step", "IDOC_TO_CANONICAL_${mode}")
    return message
}
