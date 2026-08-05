# iFlow 01 — `IR45_IF01_ZRC_IR_IFL_INBOUND_CREATE_ORDER`
**Drejtimi:** Fiori/UI5 → **SAP CI** → S/4HANA OData (përmes Cloud Connector)
**Package:** `45 - ZRC_IR_OrderFlow_Enterprise_O2C`
**Pattern:** Sync request→reply te S/4, + fan-out **async** backup te Postgres & SFTP.

## 1. Sender & Receivers
| Rol | Adapter | Detaje |
|-----|---------|--------|
| Sender | **HTTPS** | Endpoint `/http/zrc_ir/orders`, ClientCert / OAuth2 nga Fiori |
| Receiver R1 | **OData V2** | S/4 `ZRC_IR_ORDER_SRV`, `POST OrderSet` (deep). Location ID = Cloud Connector |
| Receiver R2 | **JDBC** | Postgres On-Prem (backup), përmes Cloud Connector (TCP) |
| Receiver R3 | **SFTP** | On-Prem SFTP (backup XML/JSON), përmes Cloud Connector |
| Receiver R4 | **HTTP** | Monitor FastAPI `/api/v1/events` (telemetri) |

## 2. Rrjedha (integration process)

```
[HTTPS Sender]
     |
     v
(1) Content Modifier  -> vendos header monitorimi (setMonitoringHeaders.groovy)
     |                    CorrelationId, ScenarioId=INBOUND_CREATE_ORDER, ReceivedAt
     v
(2) JSON to XML / Validim skeme  (schema OrderCreate.xsd)
     |
     v
(3) Request-Reply --> [OData V2 Receiver R1] --> S/4 CREATE_DEEP_ENTITY
     |                    <-- OrderId i gjeneruar + BAPIRET2
     v
(4) Router  (a eshte sukses response nga S/4?)
     |  \
   SUKSES  GABIM --> (Exception Subprocess, shih §4)
     |
     v
(5) Multicast (parallel)  ---- garancia e backup-it ----
     |-- Branch A: mapToPostgresInsert.groovy -> [JDBC R2]  INSERT INTO zrc_ir_bkp_order
     |-- Branch B: buildSftpFileName.groovy   -> [SFTP R3]  /orders/inbound/YYYY/MM/<file>
     |-- Branch C: postToMonitor.groovy       -> [HTTP R4]  status=SUCCESS
     v
(6) Gather -> Response mapping -> kthe te Fiori: { OrderId, status, messages[] }
```

## 3. Monitorimi (MPL → FastAPI)
Në çdo degë, skripti `postToMonitor.groovy` dërgon te FastAPI një ngjarje me:
`messageGuid` (MPL), `correlationId`, `scenarioId`, `step`, `status`, `payloadRef`, `timestamp`.
Kjo lejon rindërtimin e plotë të rrugës edhe kur një degë backup dështon por porosia në S/4 u krijua.

## 4. Error handling (Exception Subprocess)
- Kap `HTTP 5xx`/timeout nga S/4 → status `FAILED`, `postToMonitor` me error text → HTTP 502 te Fiori.
- **Backup i pavarur nga transaksioni kryesor:** nëse S/4 ishte OK por Postgres/SFTP dështoi,
  porosia NUK rrollback-ohet; ngjarja shënohet `PARTIAL` dhe vendoset në **retry queue** (JMS)
  për ri-ekzekutim vetëm të degës backup (idempotent me `CorrelationId`).

## 5. Externalized parameters
`S4_LOCATION_ID`, `S4_ADDRESS`, `PG_JDBC_ALIAS`, `SFTP_HOST`, `SFTP_DIR`, `MONITOR_URL`, `MONITOR_TOKEN`.
