# OrderFlow O2C — Integration Monitoring (Python + FastAPI)

Sistem monitorimi që merr telemetri nga SAP CI (skripti `postToMonitor.groovy`) në çdo hap
kritik të iFlow-ve, e ruan në DB dhe e ekspozon si REST + dashboard HTML.

## Ngritja (dev — pa Postgres, përdor SQLite)
```bash
cd 06_monitoring_fastapi
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8080
```
Hap: `http://localhost:8080/` (dashboard) · `http://localhost:8080/docs` (OpenAPI).

## Prod (Postgres On-Prem)
Kopjo `.env.example` → `.env`, vendos `ORDERFLOW_DATABASE_URL=postgresql+psycopg://...`.

## Endpoints
| Metoda | Path | Përshkrim |
|--------|------|-----------|
| POST | `/api/v1/events` | Ingest nga CI (header `X-Ingest-Token`) |
| GET | `/api/v1/events` | Filtrim: `correlationId`, `status`, `scenarioId` |
| GET | `/api/v1/flows` | Përmbledhje një-rresht për CorrelationId |
| GET | `/api/v1/stats` | Numëratorë për dashboard |
| GET | `/health` · `/health/deep` | Liveness · thellë (DB, SFTP TCP, S/4 OData) |
| GET | `/` | Dashboard HTML |

## Scenario IDs (nga iFlow-t që dërgojnë telemetri)
`INBOUND_CREATE_ORDER`, `OUTBOUND_ORDER_EVENT` (Fiori), `SALT_ORDER_INBOUND`,
`SALT_EVENT_OUTBOUND` (Salt ERP / EDI O2C). API-ja është gjenerike — pranon çdo `scenarioId`
pa ndryshim kodi; dashboard-i i grupon sipas `correlationId`.

## Test
```bash
pytest -q
```
