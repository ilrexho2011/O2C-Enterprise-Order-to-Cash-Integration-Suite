# iFlow 04 — `IR45_IF04_ZRC_IR_IFL_S4_OUTBOUND_O2C_CYCLE`
**Drejtimi:** S/4HANA (IDoc/event) → **SAP CI** → Salt ERP (ORDRSP / DESADV / INVOIC)
**Package:** `45 - ZRC_IR_OrderFlow_Enterprise_O2C`
**Trigger:** S/4 dërgon IDoc (ORDRSP / DELVRY-DESADV / INVOIC02) ose HTTP event te CI.

## 1. Sender & Receivers
| Rol | Adapter | Detaje |
|-----|---------|--------|
| Sender | **IDoc / HTTPS** | IDoc adapter (ORDRSP/DESADV/INVOIC) ose `/http/s4/o2c-events` |
| Receiver R1 | **HTTP** | Salt `receive_event.php` (X-Inbound-Token) |
| Receiver R2 | **JDBC** | Postgres `zrc_ir_bkp_order_event` (audit) |
| Receiver R3 | **SFTP** | On-Prem `/orders/outbound/...` (arkiv, edhe EDIFACT) |
| Receiver R4 | **HTTP** | Monitor FastAPI `/api/v1/events` |

## 2. Rrjedha
```
[Sender: IDoc ORDRSP / DESADV / INVOIC02]
   |
(1) setMonitoringHeaders.groovy  (scenarioId=SALT_EVENT_OUTBOUND)
   |
(2) Router sipas tipit të IDoc-ut/message-it
   |-- ORDRSP -> mapIdocToCanonical.groovy(mode=ORDRSP)   -> OrderEvent/Confirmation
   |-- DESADV -> mapIdocToCanonical.groovy(mode=DESADV)   -> OrderEvent/Despatch
   |-- INVOIC -> mapIdocToCanonical.groovy(mode=INVOIC)   -> OrderEvent/Invoice
   |
(3) Validim ndaj skemës (canonical.xsd :: OrderEvent)
   |
(4) Multicast:
   |-- A: -> [HTTP R1]  Salt receive_event.php  (përditëson statusin e klientit)
   |-- B: mapToPgEvent.groovy -> [JDBC R2]      (audit i eventit)
   |-- C: buildSftpFileName.groovy + (opsional) toEdifact.groovy -> [SFTP R3]
   |-- D: postToMonitor.groovy -> [HTTP R4]
   |
(5) ACK 200 -> S/4 (ndryshe IDoc mbetet për riprocesim BD87)
```

## 3. Hartimi i tipit → statusi në Salt
| IDoc / message | Canonical DocumentType | Status në Salt |
|----------------|------------------------|----------------|
| ORDRSP | `ORDRSP` | `CONFIRMED` |
| DELVRY / DESADV | `DESADV` | `DELIVERED` |
| INVOIC02 | `INVOIC` | `INVOICED` |

## 4. Error handling & garanci
- Nëse Salt (R1) s'përgjigjet me 2xx, dega A shënohet `PARTIAL`, ruhet payload te SFTP `/error/`, dhe ri-dërgohet nga JMS retry (idempotente me `CorrelationId`).
- Nga ana S/4, WE02/WE05 monitorojnë IDoc-un; BD87 riproceson dështimet.
- Externalized: `SALT_EVENT_URL`, `SALT_INBOUND_TOKEN`, `PG_JDBC_ALIAS`, `SFTP_DIR`, `MONITOR_URL`.
