/*
 * errorHandler.groovy  (Exception Subprocess)
 * Normalizon gabimin, e shenon per monitorim dhe pergatit body-n per SFTP /error/.
 */
import com.sap.gateway.ip.core.customdev.util.Message

def Message processData(Message message) {
    def ex = message.getProperty("CamelExceptionCaught")
    def errText = ex ? ex.getMessage() : "Unknown error"

    message.setProperty("status", "FAILED")
    message.setProperty("step", "ERROR")
    message.setProperty("errorText", errText.take(900))
    message.setHeader("CamelFileName",
        "/orders/error/ERR_${message.getProperty('correlationId')}_${System.currentTimeMillis()}.xml")
    return message
}
