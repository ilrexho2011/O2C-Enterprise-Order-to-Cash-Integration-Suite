/*
 * buildSftpFileName.groovy
 * Ndertol emrin dhe path-in e file-it per SFTP receiver (backup i pandryshueshem).
 * Konvencion: /orders/<direction>/<YYYY>/<MM>/ORD_<orderId>_<corr>_<ts>.xml
 */
import com.sap.gateway.ip.core.customdev.util.Message

def Message processData(Message message) {
    def p         = message.getProperties()
    def direction = (p.get("scenarioId")?.startsWith("OUTBOUND")) ? "outbound" : "inbound"
    def orderId   = (p.get("orderId") ?: "UNKNOWN").toString().replaceAll("[^A-Za-z0-9_-]", "")
    def corr      = (p.get("correlationId") ?: "nocorr").toString().take(8)
    def now       = new Date()
    def yyyy      = now.format("yyyy")
    def mm        = now.format("MM")
    def ts        = now.format("yyyyMMdd_HHmmss_SSS")

    def dir  = "/orders/${direction}/${yyyy}/${mm}"
    def file = "ORD_${orderId}_${corr}_${ts}.xml"

    message.setHeader("CamelFileName", "${dir}/${file}".toString())
    message.setProperty("payloadRef", "sftp://${dir}/${file}".toString())
    message.setProperty("step", "SFTP_BACKUP")
    return message
}
