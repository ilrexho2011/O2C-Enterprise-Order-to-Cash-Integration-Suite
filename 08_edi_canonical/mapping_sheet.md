# EDI / O2C Mapping Sheet — Salt ERP ↔ Canonical XML ↔ EDIFACT ↔ S/4HANA

Ky dokument përkufizon **shndërrimet e dokumentave** gjatë komunikimeve mes portalit të klientit
(Salt ERP «Albsale Vlora») dhe S/4HANA (ZRC_IR OrderFlow), me SAP CI si middleware. XML-i kanonik
është formati i mesit brenda CI; kolona EDIFACT tregon segmentin standard që i korrespondon (referencë
për një adapter/hartim B2B të mirëfilltë).

## 0. Çelësat e ndërlidhjes (identity mapping)

| Koncept | Salt ERP | S/4HANA (ZRC_IR) | Shënim |
|---------|----------|------------------|--------|
| Klient | `user.ZINN` / `salesorder.ZINN` | `CUSTOMER_ID` (`ZRC_IR_DE_CUSTOMER_ID`) | çelësi kryesor i palës |
| Produkt | `salt.saltcode` / `salesorder.saltcode` | `PRODUCT_ID` (`ZRC_IR_DE_PRODUCT_ID`) | kodi i artikullit |
| Porosi (salt) | `salesorder.idso` | — | referencë e portalit (`SaltOrderRef`) |
| Porosi (S/4) | `salesorder.s4_order_id` | `ORDER_ID` (`ZRC_IR_DE_ORDER_ID`) | gjenerohet nga Number Range |
| Korrelacion | `salesorder.correlation_id` | header `X-Correlation-Id` | ndjek ciklin end-to-end |

## 1. ORDERS — porosia (Salt → CI → S/4)

Drejtimi: `salt/api/integration/send_order.php` → CI (iFlow 03) → OData `CREATE_DEEP_ENTITY` → `ZRC_IR_FM_ORDER_SYNC`.

| Canonical (OrderCreate) | Salt (burim) | EDIFACT ORDERS D.96A | S/4 target |
|-------------------------|--------------|----------------------|-----------|
| `Header/DocumentType=ORDERS` | konstante | `UNH` + `BGM+220` | — |
| `Header/CorrelationId` | `correlation_id` | `RFF+ON` (order ref) | `X-Correlation-Id` |
| `Header/OrderDate` | `NOW()` | `DTM+137` | `ORDER_HDR-ORDER_DATE` |
| `Buyer/CustomerRef` | `salesorder.ZINN` | `NAD+BY` | `ORDER_HDR-CUSTOMER_ID` |
| `Buyer/Name`,`Email` | `user.name/surname/email` | `NAD+BY`, `CTA/COM` | (info) |
| `Line/ProductRef` | `salesorder.saltcode` | `LIN+…+EN` | `ORD_ITEM-PRODUCT_ID` |
| `Line/Quantity` | `salesorder.quantity` | `QTY+21` | `ORD_ITEM-QUANTITY` |
| `Line/Unit` | `salesorder.unit` | `QTY` (unit qualifier) | `ORD_ITEM-UNIT` |
| `Line/LineValue` | `salesorder.value` | `MOA+203` | `ORD_ITEM-PRICE` |
| `Summary/TotalValue` | `salesorder.value` | `MOA+86` | `ORDER_HDR-TOTAL_AMOUNT` |
| `*/Currency` | `salesorder.currency` | `CUX+2` | `*-CURRENCY` (`WAERS`) |

> Në S/4, alternativa e IDoc-ut është **`ORDERS05`** (segmentet `E1EDK01`, `E1EDKA1` partner BY, `E1EDP01`/`E1EDP19` product). CI mund të hartojë kanonik → ORDERS05 ose kanonik → OData deep-create; ne përdorim OData deep-create.

## 2. ORDRSP — konfirmimi (S/4 → CI → Salt)

Drejtimi: S/4 (event/IDoc `ORDRSP`) → CI (iFlow 04) → `salt/api/integration/receive_event.php` (status `CONFIRMED`).

| Canonical (OrderEvent) | S/4 (burim) | EDIFACT ORDRSP | Salt target |
|------------------------|-------------|----------------|-------------|
| `Header/DocumentType=ORDRSP` | konstante | `BGM+231` | `order_status_history.event_type` |
| `Header/S4OrderId` | `ORDER_ID` | `RFF+ON` / `BGM` | `salesorder.s4_order_id` |
| `Reference/CustomerRef` | `CUSTOMER_ID` | `NAD+BY` | (match) |
| `Reference/SaltOrderRef` | `X-Correlation-Id`→idso | `RFF+CR` | `salesorder.idso` |
| `Confirmation/Status` | derived | `BGM` code | `salesorder.order_status=CONFIRMED` |
| `Confirmation/ConfirmedQuantity` | `ORD_ITEM-QUANTITY` | `QTY+113` | `salesorder.confirmed_qty` |
| `Confirmation/ConfirmedDeliveryDate` | plan | `DTM+2` | (info) |

## 3. DESADV — njoftimi i dërgesës (S/4 → CI → Salt)

Drejtimi: S/4 (delivery, IDoc `DELVRY`/`DESADV`) → CI (iFlow 04) → Salt (status `DELIVERED`).

| Canonical | S/4 (burim) | EDIFACT DESADV | Salt target |
|-----------|-------------|----------------|-------------|
| `Header/DocumentType=DESADV` | konstante | `BGM+351` | `event_type` |
| `Despatch/DeliveryNo` | Delivery `VBELN` | `RFF+DQ` / `BGM` | `salesorder.delivery_no` |
| `Despatch/DespatchDate` | goods issue date | `DTM+11` | (info) |
| `Despatch/DeliveredQuantity` | LIPS `LFIMG` | `QTY+12` | (info) |
| `Despatch/Status=DELIVERED` | derived | — | `salesorder.order_status=DELIVERED` |

## 4. INVOIC — fatura (S/4 → CI → Salt)

Drejtimi: S/4 (billing, IDoc `INVOIC02`) → CI (iFlow 04) → Salt (status `INVOICED`).

| Canonical | S/4 (burim) | EDIFACT INVOIC | Salt target |
|-----------|-------------|----------------|-------------|
| `Header/DocumentType=INVOIC` | konstante | `BGM+380` | `event_type` |
| `Invoice/InvoiceNo` | Billing `VBELN` | `BGM` doc no | `salesorder.invoice_no` |
| `Invoice/InvoiceDate` | billing date | `DTM+3` | (info) |
| `Invoice/NetAmount` | `E1EDS01` net | `MOA+125` | (info) |
| `Invoice/TaxAmount` | tax | `MOA+124` / `TAX` | (info) |
| `Invoice/GrossAmount` | gross | `MOA+128` | (info) |
| `Invoice/PaymentTerms` | terms | `PAT`/`ALC` | (info) |
| `Invoice/Status=INVOICED` | derived | — | `salesorder.order_status=INVOICED` |

## 5. Rrjedha e statusit në Salt ERP

```
NEW  --(send_order.php)-->  SENT
SENT --(ORDRSP)-->          CONFIRMED
CONFIRMED --(DESADV)-->     DELIVERED
DELIVERED --(INVOIC)-->     INVOICED
(çdo hap mund të kalojë në REJECTED nëse S/4 kthen refuzim)
```

## 6. Konfigurimi S/4 për outbound IDoc (nga dokumenti EDI)

Për dokumentet dalëse (ORDRSP/DESADV/INVOIC) përmes IDoc→CI, zbatohen hapat e dokumentit
«EDI Scenario Communication»: **BD54** (logical system `ZS4CLNT100`), **SCC4**, **SM59** (RFC/HTTP
te CI), **WE21** (port), **WE20** (partner profile — partneri = middleware/klienti), **WE81/WE82**
(message types), **WE57/WE41** (process code), **NACE + VV11** (Output Determination / condition
records), **WE02/WE05** (monitorim), **BD87** (riprocesim). Trigger-i është **NAST** (Output
Determination), jo ALE Change Pointers.

## Traceability
- Salt outbound: `salt/api/integration/send_order.php`, `salt/lib/canonical.php`
- Salt inbound: `salt/api/integration/receive_event.php`
- CI: `03_cpi_iflows/iFlow_03_Salt_Inbound_Order.md`, `iFlow_04_S4_Outbound_O2C_Cycle.md`
- Mostra: `08_edi_canonical/samples/*.xml`
