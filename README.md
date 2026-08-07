# OrderFlow O2C — Enterprise Order-to-Cash Integration Suite
### From SAP ABAP DDIC to SAP Cloud Integration — with Postgres/SFTP Backup and FastAPI Observability

> **Codename:** `ZRC_IR OrderFlow` · **Author:** Ilirjan Rexho · **Version:** 1.0 · **Date:** 2026-07-26
> **Naming convention:** `ZRC_IR_*` (consistent with the earlier projects `ZRC_IR_QDKEP_CORE`, `ZRC_IR_EMPLOYEE_CORE`).

---

## 0. Executive summary

This project elevates the initial SAP ABAP Data Dictionary mini-project into a **full enterprise Order-to-Cash (O2C) scenario**, where the same business logic is consumed by five channels: ABAP programs, OData, SAP Cloud Integration, On-Premise backup (Postgres + SFTP) and a Fiori/UI5 app. Communication flows **in both directions** through SAP Cloud Integration (CI): inbound (Fiori → CI → S/4HANA) and outbound (S/4HANA → CI → consumers). Every message is **backed up** simultaneously to an SQL Postgres server and an On-Premise SFTP server (both via Cloud Connector), and **every step is monitored** by an independent system built with Python + FastAPI.

The document brings together the analysis, the architectural proposals and the references to the real code artifacts (ABAP, OData, Groovy/iFlow, SQL, Python) delivered in the `OrderFlow-O2C/` folder.

---

## 1. Analysis of the existing platform

### 1.1 What exists (document `Projekt 1 - Assignment From SAP ABAP DDIC to SAP CI.docx`)

The current document is a very well-structured **step-by-step lab guide**. It fully covers the **Foundation Layer** of an Order Management system:

The following objects have been verified directly in the `ZRC_IR_ORDER_CORE` package (Order Management Core Objects):

| DDIC Category | Objects created (real names) | Status |
|---------------|-----------------------------------|---------|
| Database Tables | `ZRC_IR_ORDER_HDR` (Order Header), `ZRC_IR_ORD_ITEM` (Order Item) | ✔ |
| View | `ZRC_IR_V_ORDER` (IR Orders Database View) | ✔ |
| Data Elements | `ZRC_IR_AMOUNT`, `ZRC_IR_DE_CUSTOMER_ID`, `ZRC_IR_DE_ORDER_ID`, `ZRC_IR_DE_ORDER_STATUS`, `ZRC_IR_DE_PRODUCT_ID`, `ZRC_IR_ITEM_NO` | ✔ |
| Domains | `ZRC_IR_AMOUNT`, `ZRC_IR_CUSTOMER_ID`, `ZRC_IR_ITEM_NO`, `ZRC_IR_ORDER_ID`, `ZRC_IR_ORDER_STATUS`, `ZRC_IR_PRODUCT_ID` | ✔ |
| Search Help | `ZRC_IR_SH_ORDER` (IR Order Search Help) | ✔ |
| Lock Objects | `EZRC_IR_ORDER`, `EZRC_IR_ORD_ITEM` | ✔ |
| Function Group | `ZRC_IR_ORDER` (IR Order Function Group) | ✔ |
| Maintenance (TMG / transport def.) | `ZRC_IR_ORDER_HDRS`, `ZRC_IR_ORD_ITEMS` | ✔ |
| Foreign Key | `ORDER_ID` (Item → Header, cardinality 1:CN) | ✔ |
| Message Class | `ZRC_IR_MSG` (messages 001–005; extended with 006–013) | ✔ (extended) |

> **Clarification on monetary amounts.** The `TOTAL_AMOUNT` (Header) and `PRICE` (Item) fields use the Data Element
> `ZRC_IR_AMOUNT` (type **CURR**, length **17**, domain `ZRC_IR_AMOUNT`, Reference Field = `CURRENCY`), not the generic `CURR17` type.
> Note the convention: `ZRC_IR_AMOUNT` and `ZRC_IR_ITEM_NO` do **not** carry the `DE_` prefix, unlike `ZRC_IR_DE_*`.

The document also **designed** (but did not implement) the upper layers: Function Group `ZRC_IR_ORDER` with five Function Modules, five presentation programs (`ZRC_IR_M10_EX01–EX05`), and a vision for OData, CI, Fiori and RAP.

### 1.2 Quality assessment and the good decisions already made

The platform has several architectural decisions that give the project a strong foundation and that I keep unchanged:

1. **Self-documenting naming** with the `ZRC_IR_*` prefix — consistent and traceable.
2. **Use of standard SAP types** (`WAERS`, `MEINS`, `MENGE_D`, `WAERS`) instead of generic `CHAR` — this brings the model closer to real-world practice.
3. **The decision to use `BAPIRET2` / `BAPIRET2_T`** as the return structure — critical, because it is the contract that CI, OData and RAP recognize natively.
4. **Layered separation** (Presentation → Application/API → Database) — allows the same logic to be reused by any channel.

### 1.3 The gaps this project fills

| Gap | Delivered solution |
|-----------|---------------------|
| The Business API FMs are only skeletons | Complete ABAP code for all 5 FMs + RFC wrapper (`01_abap/`) |
| Messages 006–013 are missing | Completed Message Class (`ZRC_IR_MSG_message_class.txt`) |
| No Number Range | Integration of `NUMBER_GET_NEXT` (object `ZRC_IR_ORD`) in `CREATE_ORDER` |
| OData only a concept | Service `ZRC_IR_ORDER_SRV` + `CREATE_DEEP_ENTITY` (`02_odata/`) |
| CI only diagrams | Two complete iFlows + 5 Groovy scripts (`03_cpi_iflows/`) |
| Backup not mentioned | Postgres schema + SFTP layout (`04_backup_postgres/`, `05_sftp/`) |
| No monitoring | Functional FastAPI application with tests (`06_monitoring_fastapi/`) |

---

## 2. Project title

**OrderFlow O2C — Enterprise Order-to-Cash Integration Suite**
*(subtitle: "From SAP ABAP DDIC to SAP Cloud Integration, with On-Premise Backup & FastAPI Observability")*

Rationale: the name captures the O2C essence, shows the journey from DDIC to CI, and highlights the two differentiators — the On-Premise backup and the observability. Technical codename: `ZRC_IR OrderFlow`.

---

## 3. Proposed architecture (end-to-end)

### 3.1 Layered view

```
┌──────────────────────────────────────────────────────────────────────────┐
│  EXPERIENCE LAYER                                                          │
│  Fiori / UI5 App  (Order List · Detail · Create · Update · Delete)         │
└───────────────┬──────────────────────────────────────────────────────────┘
                │  OData V2 (JSON)
                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  INTEGRATION LAYER  ·  SAP BTP / Integration Suite (SAP CI)               │
│  iFlow 01 INBOUND  : Fiori → CI → S/4 (sync)  + backup async (PG, SFTP)   │
│  iFlow 02 OUTBOUND : S/4 (event) → CI → consumers + backup async          │
│  Cloud Connector: virtual hosts for S/4 OData, Postgres (JDBC), SFTP      │
└───────┬───────────────────────┬───────────────────────┬──────────────────┘
        │ OData (CC)            │ JDBC (CC)              │ SFTP (CC)
        ▼                       ▼                        ▼
┌────────────────┐   ┌────────────────────┐   ┌────────────────────┐
│  S/4HANA On-Prem│   │ Postgres On-Prem    │   │ SFTP On-Prem        │
│  ZRC_IR_ORDER_SRV│   │ schema zrc_ir/mon  │   │ /orders/{in,out,err}│
│  ↓ DPC → FM API │   │ backup + audit      │   │ write-once XML arch.│
│  Function Group │   └────────────────────┘   └────────────────────┘
│  ZRC_IR_ORDER   │
│  ↓              │            ▲ telemetry (HTTP) from each iFlow step
│  ZRC_IR_ORDER_HDR/ITEM│      │
└────────────────┘   ┌────────┴───────────────────────────────────────────┐
                     │  OBSERVABILITY LAYER · Python + FastAPI            │
                     │  /api/v1/events (ingest) · /flows · /stats · /     │
                     │  /health/deep → DB · SFTP(TCP) · S/4 OData          │
                     └────────────────────────────────────────────────────┘
```

### 3.2 Layers and responsibilities

**Experience Layer (Fiori/UI5).** Consumes `ZRC_IR_ORDER_SRV` through CI. Contains no business logic — only CRUD and `Order → ToItems` navigation.

**Integration Layer (SAP CI).** The heart of the bidirectional communication. Each iFlow makes one main call (to S/4 or to the consumer) and a **parallel fan-out (Multicast)** for backup to Postgres and SFTP, plus telemetry to FastAPI. Cloud Connector exposes the three On-Prem systems as virtual hosts.

**S/4HANA (Application + Database).** The OData DPC delegates to the Business API (Function Modules). The same logic (validation, lock, insert, commit, log, return `BAPIRET2`) serves ABAP programs, OData and CI. This is the concrete realization of the layered separation that the original document had proposed.

**Backup Layer (On-Prem).** Postgres keeps a relational copy + audit (queries, reports); SFTP keeps an immutable XML archive (recovery, downstream systems). Two independent mechanisms → resilience against data loss.

**Observability Layer (FastAPI).** Independent of the SAP runtime. It receives events from CI, aggregates them by `CorrelationId`, and provides an end-to-end view + infrastructure health checks.

### 3.3 Why this pattern (Sync + Async backup)

Order creation must give Fiori an immediate response with an `OrderId` → therefore the Fiori→CI→S/4 call is **synchronous**. The Postgres/SFTP backup must not block or endanger the main transaction → therefore it is done **asynchronously (Multicast)**. If S/4 is OK but one backup branch fails, the order is **not** rolled back; the event is marked `PARTIAL` and re-sent from a retry queue (idempotent via `CorrelationId`). This is the realistic trade-off between consistency and availability.

---

## 4. Communication flows (both directions)

### 4.1 INBOUND — Fiori → SAP CI → S/4HANA (`iFlow 01`)

1. Fiori sends `POST /http/zrc_ir/orders` (JSON: Header + Items).
2. CI sets the monitoring headers (`setMonitoringHeaders.groovy`), validates the schema.
3. **Request-Reply** to S/4 OData `CREATE_DEEP_ENTITY` → `ZRC_IR_FM_ORDER_SYNC` → a single LUW (Header + Items) → `COMMIT` → returns `OrderId` + `BAPIRET2`.
4. **Parallel Multicast:** (A) `mapToPostgresInsert.groovy` → JDBC INSERT into `zrc_ir_bkp_order`; (B) `buildSftpFileName.groovy` → SFTP `/orders/inbound/...xml`; (C) `postToMonitor.groovy` → FastAPI.
5. Gather → response to Fiori: `{ OrderId, status, messages[] }`.

### 4.2 OUTBOUND — S/4HANA → SAP CI → consumers (`iFlow 02`)

1. In S/4, `ZRC_IR_FM_ORDER_EVENT_OUT` performs an `HTTP POST` to CI when an order is created/changed (SM59 destination `ZRC_IR_CPI_OUT`).
2. CI optionally enriches the payload with `GET /OrderSet('..')?$expand=ToItems`.
3. **Multicast:** audit to Postgres (`zrc_ir_bkp_order_event`), archive to SFTP `/orders/outbound/...`, notification to Fiori/consumer, telemetry to FastAPI.
4. An HTTP 200 ACK is returned to S/4; otherwise the event remains `PENDING` in `ZRC_IR_EVENT_OUTBOX` and is re-sent (at-least-once).

### 4.3 Delivery guarantees

| Risk | Protective mechanism |
|---------|--------------------|
| Loss of an outbound event | `ZRC_IR_EVENT_OUTBOX` + retry job (at-least-once) |
| Duplicate in backup | Unique `CorrelationId` + `UNIQUE` constraint in Postgres (`ON CONFLICT DO NOTHING`) |
| Backup fails, order OK | `PARTIAL` status + retry queue only for the backup branch |
| S/4 unavailable | Sync error → HTTP 502 to Fiori + `FAILED` telemetry; SFTP `/error/` |

---

## 5. Delivered artifacts (source map)

| Folder | Artifacts | Role in the architecture |
|--------|-----------|---------------------|
| `01_abap/` | `ZRC_IR_ORDER_TOP`, `FM_CREATE_ORDER`, `FM_ADD_ITEM`, `FM_GET_UPD_DEL`, `FM_ORDER_SYNC_RFC`, `M10_EX01`, message class | Business API + Presentation |
| `02_odata/` | `ZRC_IR_ORDER_SRV_definition.md`, `ZCL_..._DPC_EXT.abap` | OData exposure / deep create |
| `03_cpi_iflows/` | `iFlow_01_Inbound`, `iFlow_02_Outbound` + 5 Groovy scripts | Bidirectional integration + backup + telemetry |
| `04_backup_postgres/` | `01_schema.sql` (zrc_ir + mon + view) | Relational backup + audit |
| `05_sftp/` | `SFTP_layout.md` | Immutable archive |
| `06_monitoring_fastapi/` | `app/*`, `tests/*`, `requirements.txt`, `README.md` | Observability |

---

## 6. Data model (reference)

**S/4 (DDIC):** `ZRC_IR_ORDER_HDR` (ORDER_ID `ZRC_IR_DE_ORDER_ID`, CUSTOMER_ID `ZRC_IR_DE_CUSTOMER_ID`, ORDER_DATE `DATS`, STATUS `ZRC_IR_DE_ORDER_STATUS`, TOTAL_AMOUNT `ZRC_IR_AMOUNT` CURR 17 ref CURRENCY, CURRENCY `WAERS`) 1:CN `ZRC_IR_ORD_ITEM` (ORDER_ID `ZRC_IR_DE_ORDER_ID`, ITEM_NO `ZRC_IR_ITEM_NO`, PRODUCT_ID `ZRC_IR_DE_PRODUCT_ID`, QUANTITY `MENGE_D` ref UNIT, UNIT `MEINS`, PRICE `ZRC_IR_AMOUNT` ref CURRENCY, CURRENCY `WAERS`).

**Postgres backup:** `zrc_ir.zrc_ir_bkp_order`, `zrc_ir.zrc_ir_bkp_order_event`, `mon.message_event` (+ view `mon.v_message_flow`).

**Statuses:** `N` New · `P` Processing · `C` Completed · `X` Cancelled (mirrors the `ZRC_IR_ORDER_STATUS` domain).

---

## 7. Security and Cloud Connector

- The three On-Prem systems (S/4 OData, Postgres, SFTP) are exposed **only** as virtual hosts with their respective `Location ID`; no direct port.
- CI → FastAPI is protected with the `X-Ingest-Token` header (externalized parameter).
- Credentials in CI are stored as **Security Material** (deployed credentials), not in the script.
- FastAPI reads every secret from environment variables (`.env`), no secret in code.
- SFTP with a dedicated SSH key, `rwx` permissions only on `/orders`.

---

## 8. Implementation plan (recommended order)

1. **DDIC hardening** (completed): Lock Objects → Message Class (complete 006–013) → Table Types → Number Range `ZRC_IR_ORD`.
2. **Business API**: implement all 5 FMs (`01_abap/`) and test with SE37.
3. **Presentation**: `ZRC_IR_M10_EX01–EX05` that call only the FMs.
4. **Enterprise features**: Application Log (BAL/SLG1), Exception Class `ZCX_IR_ORDER`, Authority-Check.
5. **OData**: `ZRC_IR_ORDER_SRV` + `CREATE_DEEP_ENTITY` (`02_odata/`), register with `/IWFND/MAINT_SERVICE`.
6. **Cloud Connector**: virtual hosts for S/4, Postgres, SFTP.
7. **SAP CI**: import the `ZRC_IR_OrderFlow_O2C` package, deploy iFlow 01 & 02 (`03_cpi_iflows/`).
8. **Backup**: create the Postgres schema (`04_backup_postgres/01_schema.sql`), prepare the SFTP structure.
9. **Observability**: deploy FastAPI (`06_monitoring_fastapi/`), wire `MONITOR_URL` into the iFlow.
10. **Fiori/UI5**: app on top of the same OData service.
11. **RAP (optional, future)**: migration Tables → CDS → Behavior → Service Binding → Fiori Elements.

---

## 9. Testing and verification

- **ABAP**: SE37 single-record test + the lock scenario with two sessions (Object is locked).
- **OData**: Postman deep-create + `$expand=ToItems`.
- **CI**: MPL trace for both directions + verification of the three backup branches.
- **FastAPI**: `pytest` (5 tests: health, auth, ingest+query, validation, dashboard) — **all pass**; SQL is validated with a Postgres parser.
- **End-to-end**: create an order from Fiori → verify a row in S/4, a row in Postgres, a file in SFTP, and a `SUCCESS` flow in the dashboard.

---

## 10. Risks and open points

- **Number Range idempotency vs. external ID**: when the order arrives from CI with a supplied `OrderId`, the FM respects it; when it arrives empty, it generates one. Agreement is needed on who "owns" the ID.
- **Ordering of outbound events**: `change_seq` in the audit helps, but strict ordering requires a queue (JMS/Event Mesh).
- **Sync vs. async backup performance**: under load, the backup must remain async; monitor the latency of the branches.
- **`/health/deep` with `verify=False`** on S/4: for dev only; in prod use a trust store.

---

## 11. Traceability / Source Map

| Requirement (instructions) | Where it is addressed |
|--------------------------|--------------|
| ABAP DDIC | Original document + §1.1 |
| Function Groups & Modules | `01_abap/` (Function Group `ZRC_IR_ORDER`) |
| ABAP Programs | `ZRC_IR_M10_EX01_CREATE.abap` (+ EX02–05 following the same model) |
| UI5/Fiori API | §3.2 Experience Layer + OData service |
| S4H OData ↔ SAP CI via Cloud Connector | `02_odata/` + `03_cpi_iflows/` + §7 |
| SAP Cloud Integration (both directions) | `iFlow 01` & `iFlow 02` |
| SQL Postgres On-Prem via Cloud Connector | `04_backup_postgres/01_schema.sql`, JDBC receiver |
| SFTP On-Prem via Cloud Connector | `05_sftp/SFTP_layout.md`, SFTP receiver |
| Python + FastAPI monitoring | `06_monitoring_fastapi/` |
| Customer channel (Salt ERP) + EDI | §12, `salt/*`, `08_edi_canonical/*` |

---

## 12. Customer channel — Salt ERP (Albsale Vlora) + EDI O2C transformations

This section adds **the point where the customer places orders and views their own information**: the
**Salt ERP (Albsale Vlora)** portal — PHP + UI5 over MariaDB `albsale-vlora`. In the O2C chain, Salt ERP
is the **customer self-service front-end**, while S/4HANA (`ZRC_IR OrderFlow`) remains the backend.
SAP CI performs the **document transformations** (canonical ↔ OData/IDoc, with an EDIFACT reference), exactly
as described in the *«EDI Scenario Communication»* document (SAP → Middleware → Customer).

### 12.1 Extended view

```
CUSTOMER PORTAL (Salt ERP · Albsale Vlora, PHP/UI5/MariaDB)
  myorders.php (My Orders by ZINN) · salesorder.php (Order form)
        |  ORDERS (canonical XML)                   ^ ORDRSP/DESADV/INVOIC
        v  send_order.php                           |  receive_event.php
INTEGRATION LAYER · SAP CI
  iFlow 03 SALT_INBOUND  : Salt -> CI -> S/4 (deep-create) + ORDRSP return
  iFlow 04 S4_OUTBOUND   : S/4 (IDoc) -> CI -> Salt (ORDRSP/DESADV/INVOIC)
  + backup async (Postgres, SFTP) + telemetry (FastAPI)
        |  OData (CC)                               ^ IDoc/HTTP (NAST)
        v                                           |
S/4HANA · ZRC_IR_ORDER_SRV -> ZRC_IR_FM_ORDER_SYNC -> ORDER_HDR/ITEM
```

### 12.2 Correlation keys

`ZINN` (Salt) → `CUSTOMER_ID` (S/4) · `saltcode` → `PRODUCT_ID` · `idso` ↔ `s4_order_id` via
`CorrelationId` (`SALT-<ZINN>-<idso>-<rnd>`). Details: `08_edi_canonical/mapping_sheet.md`.

### 12.3 The complete document cycle (ORDERS → ORDRSP → DESADV → INVOIC)

| Doc. | Direction | Canonical | Effect in Salt |
|------|----------|---------|----------------|
| ORDERS | Salt → S/4 | `OrderCreate` | creates the order in S/4, status `SENT` |
| ORDRSP | S/4 → Salt | `OrderEvent/Confirmation` | `CONFIRMED` + `s4_order_id`, `confirmed_qty` |
| DESADV | S/4 → Salt | `OrderEvent/Despatch` | `DELIVERED` + `delivery_no` |
| INVOIC | S/4 → Salt | `OrderEvent/Invoice` | `INVOICED` + `invoice_no` |

### 12.4 Changes in Salt ERP (real code)

- **Outbound** `salt/api/integration/send_order.php` — builds the canonical XML (`lib/canonical.php`), stores it in `integration_outbox` (at-least-once) and sends it to CI.
- **Inbound** `salt/api/integration/receive_event.php` — accepts ORDRSP/DESADV/INVOIC, updates `salesorder` + writes `order_status_history`.
- **Self-service** `salt/myorders.php` + `salt/api/order/read_by_customer.php` — the «My Orders» view filtered by `ZINN`, with a «Send to SAP» button.
- **DB** `salt/sql/salt_integration.sql` — status fields in `salesorder` + the `order_status_history`, `integration_outbox` tables + view `v_customer_orders`.

### 12.5 EDIFACT transformations (reference)

CI maps the canonical form to EDIFACT segments for a genuine B2B scenario: ORDERS (`BGM+220`,
`NAD+BY`, `LIN`, `QTY+21`, `MOA`), ORDRSP (`BGM+231`), DESADV (`BGM+351`, `RFF+DQ`), INVOIC
(`BGM+380`, `MOA+125/124/128`). On the S/4 side, outbound documents are generated as IDocs with
**Output Determination (NAST)** — configuration: BD54, SCC4, SM59, WE21, WE20, WE81/82, NACE, VV11
(see `08_edi_canonical/mapping_sheet.md §6`).

### 12.6 Interface Catalog

The complete interface catalog: `07_docs/Integration_Catalog_Salt_O2C.md`
(`ZRC_IR_IFL_SALT_INBOUND_ORDER`, `ZRC_IR_IFL_S4_OUTBOUND_O2C_CYCLE`).

### 12.7 Risks (new)

- The IDoc→canonical mapping is simplified; a real IDoc requires the `E1EDK*/E1EDP*` segments.
- Ordering of outbound events: strict ordering requires a queue (JMS/Event Mesh).
