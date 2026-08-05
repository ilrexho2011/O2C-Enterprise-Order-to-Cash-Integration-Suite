-- =====================================================================
-- OrderFlow O2C  -  PostgreSQL On-Premise (backup + audit)
-- Aksesohet nga SAP CI JDBC receiver permes Cloud Connector (TCP).
-- Skema: zrc_ir  |  DB: orderflow
-- =====================================================================
CREATE SCHEMA IF NOT EXISTS zrc_ir;
SET search_path TO zrc_ir;

-- ---------------------------------------------------------------------
-- 1) Backup i porosive (inbound: Fiori -> CI -> S/4, kopje ne CI)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS zrc_ir_bkp_order (
    id              BIGSERIAL       PRIMARY KEY,
    correlation_id  VARCHAR(60)     NOT NULL,
    order_id        VARCHAR(10)     NOT NULL,
    customer_id     VARCHAR(10),
    total_amount    NUMERIC(17,2)   DEFAULT 0,
    currency        VARCHAR(5),
    status          CHAR(1)         DEFAULT 'N',
    source_system   VARCHAR(10)     DEFAULT 'S4H',
    scenario_id     VARCHAR(40),
    payload_json    JSONB,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    -- idempotenca: nje porosi backup-ohet nje here per korrelacion
    CONSTRAINT uq_bkp_order UNIQUE (correlation_id, order_id)
);
CREATE INDEX IF NOT EXISTS ix_bkp_order_order   ON zrc_ir_bkp_order (order_id);
CREATE INDEX IF NOT EXISTS ix_bkp_order_created ON zrc_ir_bkp_order (created_at DESC);
CREATE INDEX IF NOT EXISTS ix_bkp_order_status  ON zrc_ir_bkp_order (status);

-- ---------------------------------------------------------------------
-- 2) Backup i eventeve (outbound: S/4 -> CI -> consumers)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS zrc_ir_bkp_order_event (
    id              BIGSERIAL       PRIMARY KEY,
    correlation_id  VARCHAR(60)     NOT NULL,
    order_id        VARCHAR(10)     NOT NULL,
    event_type      VARCHAR(30)     NOT NULL,   -- ORDER_CREATED / ORDER_UPDATED / ...
    change_seq      INTEGER         DEFAULT 1,
    payload_xml     TEXT,
    payload_json    JSONB,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_bkp_event UNIQUE (correlation_id)
);
CREATE INDEX IF NOT EXISTS ix_bkp_event_order ON zrc_ir_bkp_order_event (order_id, created_at DESC);

-- ---------------------------------------------------------------------
-- 3) Log i monitorimit (i shkruar nga FastAPI, jo nga CI - shih sistemin)
--    Mbahet ne te njejtin DB per raportim te njesuar, skema 'mon'.
-- ---------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS mon;

CREATE TABLE IF NOT EXISTS mon.message_event (
    id              BIGSERIAL       PRIMARY KEY,
    message_guid    VARCHAR(60),
    correlation_id  VARCHAR(60)     NOT NULL,
    scenario_id     VARCHAR(40)     NOT NULL,
    iflow_name      VARCHAR(80),
    step            VARCHAR(30)     NOT NULL,
    status          VARCHAR(15)     NOT NULL,   -- IN_PROGRESS/SUCCESS/PARTIAL/FAILED
    order_id        VARCHAR(10),
    error_text      TEXT,
    payload_ref     VARCHAR(255),
    event_ts        TIMESTAMPTZ     NOT NULL,
    ingested_at     TIMESTAMPTZ     NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_mon_corr    ON mon.message_event (correlation_id, event_ts);
CREATE INDEX IF NOT EXISTS ix_mon_status  ON mon.message_event (status);
CREATE INDEX IF NOT EXISTS ix_mon_scen_ts ON mon.message_event (scenario_id, event_ts DESC);

-- ---------------------------------------------------------------------
-- 4) View permbledhese per dashboard-in (nje rresht per korrelacion)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW mon.v_message_flow AS
SELECT
    correlation_id,
    max(scenario_id)                                   AS scenario_id,
    max(order_id)                                      AS order_id,
    min(event_ts)                                      AS started_at,
    max(event_ts)                                      AS last_event_at,
    count(*)                                           AS steps,
    -- statusi perfundimtar: FAILED > PARTIAL > SUCCESS > IN_PROGRESS
    CASE
      WHEN bool_or(status = 'FAILED')  THEN 'FAILED'
      WHEN bool_or(status = 'PARTIAL') THEN 'PARTIAL'
      WHEN bool_or(status = 'SUCCESS') THEN 'SUCCESS'
      ELSE 'IN_PROGRESS'
    END                                                AS overall_status
FROM mon.message_event
GROUP BY correlation_id;
