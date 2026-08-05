# SFTP On-Premise — Backup Layout & Konvencionet

Serveri SFTP On-Prem aksesohet nga **SAP CI SFTP receiver** përmes **Cloud Connector**
(protokoll SSH/SFTP, `Location ID` = `ONPREM_SFTP`). Shërben si **arkiv i pandryshueshëm**
(write-once) i çdo porosie dhe eventi — burim rikuperimi kur S/4 ose Postgres nuk janë të disponueshëm.

## Struktura e direktorive
```
/orders
├── inbound/          <- Fiori -> CI -> S/4  (kopje e porosise se krijuar)
│   └── <YYYY>/<MM>/ORD_<orderId>_<corr8>_<timestamp>.xml
├── outbound/         <- S/4 -> CI -> consumers (eventet)
│   └── <YYYY>/<MM>/EVT_<orderId>_<timestamp>.xml
└── error/            <- payload-et e deshtuara per riprocesim manual
    └── ERR_<corr>_<epochMillis>.xml
```

## Rregullat
- **Write-once:** file-t nuk mbishkruhen; timestamp me milisekonda garanton unicitet.
- **Naming:** `ORD_` për porosi, `EVT_` për evente, `ERR_` për gabime. `corr8` = 8 karaktere të para të CorrelationId.
- **Encoding:** UTF-8, XML i vlefshëm ndaj `OrderCreate.xsd` / `OrderEvent.xsd`.
- **Retention:** job On-Prem arkivon >90 ditë në `/orders/archive/` (jashtë fushës së CI).
- **Siguria:** çelës SSH i dedikuar për CI; leje `rwx` vetëm në `/orders`, jo në rrënjë.

## Monitorimi
Pas çdo shkrimi, `buildSftpFileName.groovy` vendos `payloadRef = sftp://...` që dërgohet
te FastAPI, kështu dashboard-i tregon saktësisht ku ndodhet backup-i fizik i çdo mesazhi.
