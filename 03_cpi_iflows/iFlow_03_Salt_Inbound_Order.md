# iFlow 03 — `IR45_IF03_ZRC_IR_IFL_SALT_INBOUND_ORDER`
**Drejtimi:** Salt ERP (Kundenportal) → **SAP CI** → S/4HANA (ORDERS)
**Package:** `45 - ZRC_IR_OrderFlow_Enterprise_O2C`
**Dokumenti:** `ORDERS` (XML kanonik `OrderCreate`) → OData deep-create në S/4.

## 1. Sender & Receivers
| Rol | Adapter | Detaje |
|-----|---------|--------|
| Sender | **HTTPS** | `/http/salt/orders` (nga `salt/api/integration/send_order.php`), token Bearer |
| Receiver R1 | **OData V2** | S/4 `ZRC_IR_ORDER_SRV` `POST OrderSet` (deep), Location ID = Cloud Connector |
| Receiver R2 | **JDBC** | Postgres On-Prem `zrc_ir_bkp_order` (backup) |
| Receiver R3 | **SFTP** | On-Prem `/orders/inbound/...` (arkiv) |
| Receiver R4 | **HTTP** | Monitor FastAPI `/api/v1/events` |
| Receiver R5 | **HTTP** | Salt `receive_event.php` (ORDRSP kthyese) |

## 2. Rrjedha
```
[HTTPS: OrderCreate canonical XML]
   |
(1) setMonitoringHeaders.groovy  (scenarioId=SALT_ORDER_INBOUND, orderId=CorrelationId)
   |
(2) Validim ndaj skemës  (canonical.xsd :: OrderCreate)
   |
(3) mapSaltOrderToS4.groovy   -> ndërton payload-in OData deep (ZINN->CustomerId, saltcode->ProductId)
   |
(4) Request-Reply -> [OData R1]  CREATE_DEEP_ENTITY -> ZRC_IR_FM_ORDER_SYNC -> OrderId + BAPIRET2
   |
(5) Router: sukses?
   |  \
 SUKSES  GABIM -> errorHandler.groovy -> postToMonitor(FAILED) -> HTTP 502 te Salt
   |
(6) Multicast:
   |-- A: mapToPostgresInsert.groovy -> [JDBC R2]
   |-- B: buildSftpFileName.groovy   -> [SFTP R3]
   |-- C: postToMonitor.groovy       -> [HTTP R4]  status=SUCCESS
   |-- D: buildOrdrspToSalt.groovy   -> [HTTP R5]  ORDRSP (S4OrderId, CONFIRMED)
   |
(7) Response -> Salt: { s4OrderId, correlationId, status }
```

## 3. Shënime
- **Idempotenca:** `CorrelationId` nga Salt përcillet te S/4 dhe te backup; ri-dërgimet nuk krijojnë duplikat (UNIQUE në Postgres, kontroll duplikati në FM).
- **ORDRSP i menjëhershëm (hap 6-D):** meqë deep-create është sinkron, konfirmimi i parë kthehet menjëherë te Salt (statusi `SENT`→`CONFIRMED`). DESADV/INVOIC vijnë më vonë përmes iFlow 04.
- **Externalized:** `S4_LOCATION_ID`, `PG_JDBC_ALIAS`, `SFTP_DIR`, `MONITOR_URL`, `SALT_EVENT_URL`, `SALT_INBOUND_TOKEN`.
