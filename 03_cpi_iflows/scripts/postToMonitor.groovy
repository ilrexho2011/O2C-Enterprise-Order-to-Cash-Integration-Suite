/*
 * postToMonitor.groovy
 * Ndertol nje ngjarje telemetrie dhe e vendos si body per HTTP receiver -> FastAPI.
 * Thirret ne cdo hap kritik (RECEIVED, S4_CREATED, PG_BACKUP, SFTP_BACKUP, DONE, FAILED).
 */
import com.sap.gateway.ip.core.customdev.util.Message
import groovy.json.JsonOutput

def Message processData(Message message) {
    def p = message.getProperties()

    def event = [
        messageGuid   : message.getHeaders().get("SAP_MessageProcessingLogID"),
        correlationId : p.get("correlationId"),
        scenarioId    : p.get("scenarioId"),
        iflowName     : p.get("SAP_IFLOW_NAME") ?: p.get("scenarioId"),
        step          : p.get("step") ?: "UNKNOWN",
        status        : p.get("status") ?: "IN_PROGRESS",
        orderId       : p.get("orderId"),
        errorText     : p.get("errorText"),
        payloadRef    : p.get("payloadRef"),
        timestamp     : new Date().format("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", TimeZone.getTimeZone("UTC"))
    ]

    message.setBody(JsonOutput.toJson(event))
    message.setHeader("Content-Type", "application/json")
    // token per FastAPI vendoset si externalized parameter ne HTTP receiver header
    return message
}
