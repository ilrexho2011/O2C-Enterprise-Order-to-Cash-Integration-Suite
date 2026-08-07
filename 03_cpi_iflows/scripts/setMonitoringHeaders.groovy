/*
 * setMonitoringHeaders.groovy
 * Vendos header-at e monitorimit ne fillim te cdo iFlow.
 * Krijon nje CorrelationId stabel qe ndjek porosine ne te gjitha deget.
 */
import com.sap.gateway.ip.core.customdev.util.Message
import java.util.UUID

def Message processData(Message message) {
    def props   = message.getProperties()
    def headers = message.getHeaders()

    // CorrelationId: perdor MPL messageGuid nese ekziston, perndryshe gjenero
    def corrId = headers.get("SAP_MessageProcessingLogID") ?: UUID.randomUUID().toString()

    message.setHeader("X-Correlation-Id", corrId)
    message.setProperty("correlationId", corrId)
    message.setProperty("scenarioId", props.get("scenarioId") ?: "INBOUND_CREATE_ORDER")
    message.setProperty("receivedAt", new Date().format("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", TimeZone.getTimeZone("UTC")))
    message.setProperty("step", "RECEIVED")
    message.setProperty("status", "IN_PROGRESS")

    return message
}
