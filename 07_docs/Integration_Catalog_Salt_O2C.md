# Integration Catalog — Salt ERP ⇄ S/4HANA O2C (Package `ZRC_IR_OrderFlow_O2C`)

> Catalog Doc sipas Route B. Fushat shënohen `source-backed` (nga skedarë realë) ose `derived`/`assumption`.
> Identifikuesit ruhen ekzaktësisht si në kod.

## 1. Konteksti i interfaceve

Portali i klientit **Salt ERP (Albsale Vlora)** është pika ku klienti (i identifikuar me `ZINN`)
vendos porosi dhe sheh informacionin e vet. S/4HANA (`ZRC_IR OrderFlow`) është backend-i. SAP CI
kryen shndërrimin e dokumentave (kanonik ↔ OData/IDoc, referencë EDIFACT).

## 2. Interface Inventory

| ID (iFlow) | Drejtimi | Dokument | Sender → Receiver | Evidencë |
|-----------|----------|----------|-------------------|----------|
| `ZRC_IR_IFL_SALT_INBOUND_ORDER` | Salt → S/4 | ORDERS | HTTPS → OData `ZRC_IR_ORDER_SRV` | `iFlow_03_*.md`, `send_order.php` — source-backed |
| `ZRC_IR_IFL_S4_OUTBOUND_O2C_CYCLE` | S/4 → Salt | ORDRSP/DESADV/INVOIC | IDoc/HTTPS → HTTP `receive_event.php` | `iFlow_04_*.md`, `receive_event.php` — source-backed |

## 3. Data Contract (source-backed)

- Kanonik: `08_edi_canonical/canonical.xsd` (`OrderCreate`, `OrderEvent`).
- Mostra të validuara: `08_edi_canonical/samples/0{1..4}_*.xml` (validojnë ndaj XSD).
- Mapping i plotë fushë-për-fushë: `08_edi_canonical/mapping_sheet.md`.

## 4. Endpoints & Adapters

| Komponent | Adapter/Teknologji | Referencë |
|-----------|--------------------|-----------|
| Salt outbound | PHP + cURL POST (application/xml) | `salt/api/integration/send_order.php` |
| Salt inbound | PHP endpoint (X-Inbound-Token) | `salt/api/integration/receive_event.php` |
| Salt self-service | PHP view + JS fetch | `salt/myorders.php`, `salt/api/order/read_by_customer.php` |
| CI → S/4 | OData V2 deep-create (Cloud Connector) | `02_odata/ZRC_IR_ORDER_SRV_definition.md` |
| S/4 → CI | IDoc (ORDRSP/DESADV/INVOIC) / HTTP, NAST | dokumenti EDI + `mapping_sheet.md §6` |

## 5. Business Rules

- `ZINN` (Salt) = `CUSTOMER_ID` (S/4); `saltcode` = `PRODUCT_ID`; `idso` ↔ `s4_order_id` përmes `CorrelationId`.
- Cikli i statusit në Salt: `NEW → SENT → CONFIRMED → DELIVERED → INVOICED` (ose `REJECTED`).
- Një artikull për porosi në modelin aktual të `salesorder` (i zgjerueshëm te shumë rreshta).

## 6. Error handling & Reliability

- Salt outbound: tabela `integration_outbox` (`PENDING/SENT/FAILED`, `UNIQUE(correlation_id)`) → at-least-once.
- CI: Multicast me backup Postgres+SFTP; degët backup ridërgohen me JMS retry (idempotente me `CorrelationId`).
- S/4 outbound IDoc: WE02/WE05 monitorim, BD87 riprocesim.

## 7. Security

- Salt → CI: `Authorization: Bearer` (token nga `config/integration.php`, env `CPI_TOKEN`).
- CI → Salt: header `X-Inbound-Token` (env `SALT_INBOUND_TOKEN`), krahasim me `hash_equals`.
- Cloud Connector: virtual hosts për S/4/Postgres/SFTP; asnjë ekspozim direkt.
- **Rrezik i identifikuar:** `salt/config/Database.php` ka kredenciale të hardkoduara — rekomandohet kalimi te variabla mjedisi.

## 8. Observability

Telemetria te FastAPI me `scenarioId ∈ { SALT_ORDER_INBOUND, SALT_EVENT_OUTBOUND }`;
`correlationId` lidh porosinë Salt ↔ S/4 ↔ backup ↔ event.

## 9. Test Strategy

- Kanonik: `xmllint --schema canonical.xsd samples/*.xml` (kalon).
- Salt: `php -l` për endpoint-et; test manual `send_order.php` → verifiko `outbox=SENT` dhe status `SENT`.
- End-to-end: porosi nga `myorders.php` → OrderId në S/4 → ORDRSP → status `CONFIRMED` në portal.

## 10. Risks & Open Points

- Kredenciale të hardkoduara në Salt (shih §7).
- IDoc real (ORDRSP/DESADV/INVOIC) kërkon lidhjen e segmenteve `E1EDK*/E1EDP*`; mapping-u aktual është i thjeshtëzuar (`derived`).
- Renditja e eventeve outbound: për renditje strikte nevojitet queue (JMS/Event Mesh).

## 11. Source Map / Traceability

`salt/*` (source-backed) · `03_cpi_iflows/iFlow_03,04 + scripts` · `08_edi_canonical/*` · `02_odata/*` · `EDI Scenario Communicatiom.docx`.
