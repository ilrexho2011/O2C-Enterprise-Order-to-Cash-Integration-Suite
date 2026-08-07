# iFlow 02 — `IR45_IF02_ZRC_IR_IFL_OUTBOUND_ORDER_EVENT`
**Drejtimi:** S/4HANA (event) → **SAP CI** → Fiori / Postgres / SFTP
**Package:** `45 - ZRC_IR_OrderFlow_Enterprise_O2C`
**Trigger:** `ZRC_IR_FM_ORDER_EVENT_OUT` bën `HTTP POST` te CI kur krijohet/ndryshohet një porosi.

## 1. Sender & Receivers
| Rol | Adapter | Detaje |
|-----|---------|--------|
| Sender | **HTTPS** | Endpoint `/http/zrc_ir/order-events` (nga S/4 SM59 dest. `ZRC_IR_CPI_OUT`) |
| Receiver R1 | **OData V2 / HTTP** | Fiori push-back ose SAP Build Work Zone tile refresh (opsionale) |
| Receiver R2 | **JDBC** | Postgres On-Prem — `zrc_ir_bkp_order_event` (audit i plotë i eventeve) |
| Receiver R3 | **SFTP** | On-Prem SFTP — arkiv XML i eventit për sistemet downstream (WMS/CRM) |
| Receiver R4 | **HTTP** | Monitor FastAPI `/api/v1/events` |

## 2. Rrjedha
```
[HTTPS Sender: ORDER_CREATED / ORDER_UPDATED]
     |
     v
(1) setMonitoringHeaders.groovy  (ScenarioId=OUTBOUND_ORDER_EVENT)
     |
     v
(2) Content Enricher (opsionale): GET /OrderSet('..')?$expand=ToItems  (nese payload-i eshte i pjesshem)
     |
     v
(3) Multicast (parallel):
     |-- Branch A -> [JDBC R2]  INSERT event (audit)
     |-- Branch B -> [SFTP R3]  /orders/outbound/YYYY/MM/EVT_<order>_<ts>.xml
     |-- Branch C -> [HTTP R1]  njofto Fiori/consumer
     |-- Branch D -> postToMonitor.groovy -> [HTTP R4]
     v
(4) Gather -> HTTP 200 kthehet te S/4 (ACK)
```

## 3. Garancia "at-least-once"
- S/4 mban `ZRC_IR_EVENT_OUTBOX`; nëse CI kthen jo-200, eventi qëndron `PENDING`
  dhe ri-dërgohet nga një background job (RFC/HTTP retry me backoff).
- CI de-duplikon me `CorrelationId = <order_id>|<event>|<change_seq>` para INSERT-it në Postgres.

## 4. Error handling
- Exception Subprocess → `postToMonitor` me `status=FAILED`, ruan payload-in në SFTP `/error/`
  për riprocesim manual; kthen HTTP 500 → S/4 e mban eventin PENDING (nuk humbet).
