# OData Service `ZRC_IR_ORDER_SRV` (SEGW)

Shtresa e ekspozimit të Business API-t si REST/OData V2, e konsumueshme nga **SAP CI (përmes Cloud Connector)**, **Fiori/UI5** dhe **Postman**.

## 1. Data Model (SEGW)

| Entity Type | Source (DDIC) | Key |
|-------------|---------------|-----|
| `Order`     | `ZRC_IR_ORDER_HDR` | `OrderId` |
| `Item`      | `ZRC_IR_ORD_ITEM`  | `OrderId`, `ItemNo` |

**Entity Sets:** `OrderSet`, `ItemSet`
**Association:** `Order_Items` (1 : N) → **Navigation Property** `ToItems` on `Order`.

### Order (properties)
`OrderId` (Edm.String, key), `CustomerId`, `OrderDate` (Edm.DateTime), `Status`, `TotalAmount` (Edm.Decimal), `Currency`.

### Item (properties)
`OrderId` (key), `ItemNo` (key), `ProductId`, `Quantity` (Edm.Decimal), `Unit`, `Price` (Edm.Decimal), `Currency`.

## 2. Operations të implementuara (redefinition në DPC_EXT)

| HTTP + OData | Metoda DPC | Business API i thirrur |
|-------------|-----------|------------------------|
| `POST /OrderSet` (deep insert me `ToItems`) | `/IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_DEEP_ENTITY` | `ZRC_IR_FM_ORDER_SYNC` |
| `GET /OrderSet('...')?$expand=ToItems` | `ORDERSET_GET_ENTITY` + `ITEMSET_GET_ENTITYSET` | `ZRC_IR_FM_GET_ORDER` |
| `GET /OrderSet` | `ORDERSET_GET_ENTITYSET` | `SELECT` (list, me `$filter`) |
| `PUT /OrderSet('...')` | `ORDERSET_UPDATE_ENTITY` | `ZRC_IR_FM_UPDATE_ORDER` |
| `DELETE /OrderSet('...')` | `ORDERSET_DELETE_ENTITY` | `ZRC_IR_FM_DELETE_ORDER` |

> **Pse Deep Entity për POST?** Një porosi O2C = Header + Items në një LUW të vetme.
> `CREATE_DEEP_ENTITY` pranon një payload të vetëm dhe e delegon te `ZRC_IR_FM_ORDER_SYNC`,
> i cili bën COMMIT vetëm një herë → integritet transaksional i garantuar.

## 3. Registrimi & aktivizimi
- `/IWFND/MAINT_SERVICE` → Add Service → System Alias `LOCAL` → aktivizo `ZRC_IR_ORDER_SRV`.
- Metadata: `/sap/opu/odata/sap/ZRC_IR_ORDER_SRV/$metadata`
- Endpoint që përdor CI (përmes Cloud Connector virtual host):
  `https://<cc-virtual-host>/sap/opu/odata/sap/ZRC_IR_ORDER_SRV/OrderSet`

## 4. Shembull payload (deep create) që dërgon SAP CI → S/4
```json
{
  "CustomerId": "CUST000045",
  "Currency": "EUR",
  "TotalAmount": "1250.00",
  "Status": "N",
  "ToItems": [
    { "ItemNo": "0010", "ProductId": "MAT-100", "Quantity": "5",  "Unit": "PC", "Price": "150.00", "Currency": "EUR" },
    { "ItemNo": "0020", "ProductId": "MAT-220", "Quantity": "10", "Unit": "PC", "Price": "50.00",  "Currency": "EUR" }
  ]
}
```
