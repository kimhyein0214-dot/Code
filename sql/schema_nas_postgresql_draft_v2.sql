-- =============================================================================
-- schema_nas_postgresql_draft_v2.sql
--
-- Target:
--   LOCAL Docker PostgreSQL first: product_ops_test
--   Later review target: Synology NAS PostgreSQL
--
-- Purpose:
--   Integration schema draft v2 reflecting local cross mapping results:
--     order_items total       = 6,169
--     selfpia_sku matched     = 6,164
--     direct match rate       = 99.92%
--     unmatched p_code count  = 5
--
-- Safety:
--   Do not run on operating Supabase.
--   Do not run on Synology NAS yet.
--   Apply/test only on local Docker PostgreSQL until reviewed.
--
-- Design notes:
--   * Product_code source stores selfpia_sku in code_alias, not as a standalone
--     source column. v2 keeps code_alias and provides a canonical read view.
--   * PR_system raw p_code is preserved as picking.order_items.raw_p_code.
--   * master linkage starts nullable. FK on sku_id is NOT VALID for early load.
--   * 5 legacy unmatched lines can be loaded with master_match_status =
--     'legacy_unmatched' without breaking migration.
-- =============================================================================

-- Local/schema prerequisites.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS product_code;
CREATE SCHEMA IF NOT EXISTS picking;
CREATE SCHEMA IF NOT EXISTS inspection;
CREATE SCHEMA IF NOT EXISTS cs;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS stg;

-- ============================================================
-- [1] product_code: Product_code master area
-- ============================================================

CREATE TABLE IF NOT EXISTS product_code.product_master (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  virtual_product_code  text UNIQUE,
  product_name          text,
  status                text,
  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  source_project_ref    text NOT NULL DEFAULT 'mrqoqmidnrawflwezxlm',
  source_table          text NOT NULL DEFAULT 'product_master',
  source_updated_at     timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS product_code.sku_master (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id            uuid REFERENCES product_code.product_master(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  virtual_sku_code      text UNIQUE,
  option_value          text,
  sku_type              text,
  status                text,
  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  source_project_ref    text NOT NULL DEFAULT 'mrqoqmidnrawflwezxlm',
  source_table          text NOT NULL DEFAULT 'sku_master',
  source_updated_at     timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_sku_master_product_id ON product_code.sku_master(product_id);
CREATE INDEX IF NOT EXISTS ix_sku_master_status ON product_code.sku_master(status);

CREATE TABLE IF NOT EXISTS product_code.code_alias (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type           text NOT NULL CHECK (target_type IN ('PRODUCT', 'SKU', 'SET')),
  target_id             uuid NOT NULL,
  code_system           text NOT NULL,
  code_value            text NOT NULL,
  parsed_prefix         text,
  parsed_part1          text,
  parsed_part2          text,
  parsed_part3          text,
  parsed_part4          text,
  selfpia_product_code  text,
  selfpia_option_no     text,
  usage_type            text,
  is_primary            boolean NOT NULL DEFAULT false,
  memo                  text,
  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  source_project_ref    text NOT NULL DEFAULT 'mrqoqmidnrawflwezxlm',
  source_table          text NOT NULL DEFAULT 'code_alias',
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (code_system, code_value, target_type, target_id)
);

CREATE INDEX IF NOT EXISTS ix_code_alias_lookup ON product_code.code_alias(code_system, code_value);
CREATE INDEX IF NOT EXISTS ix_code_alias_target ON product_code.code_alias(target_type, target_id);
CREATE INDEX IF NOT EXISTS ix_code_alias_selfpia_product ON product_code.code_alias(selfpia_product_code);

-- Product_code selfpia_sku was measured as 33,287 rows / 33,287 distinct.
-- A partial unique index preserves that invariant without pretending every
-- alias system is globally unique.
CREATE UNIQUE INDEX IF NOT EXISTS ux_code_alias_selfpia_sku_value
  ON product_code.code_alias(code_value)
  WHERE code_system = 'selfpia_sku' AND target_type = 'SKU';

CREATE TABLE IF NOT EXISTS product_code.sku_channel_mapping (
  id                    bigserial PRIMARY KEY,
  sku_id                uuid NOT NULL REFERENCES product_code.sku_master(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  channel_code          text NOT NULL,
  channel_sku_code      text,
  seller_product_code   text,
  own_sku_code          text,
  is_primary            boolean NOT NULL DEFAULT false,
  valid_from            date,
  valid_to              date,
  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_scm_sku_id ON product_code.sku_channel_mapping(sku_id);
CREATE INDEX IF NOT EXISTS ix_scm_channel_sku ON product_code.sku_channel_mapping(channel_code, channel_sku_code);
CREATE INDEX IF NOT EXISTS ix_scm_seller_product ON product_code.sku_channel_mapping(channel_code, seller_product_code);

CREATE TABLE IF NOT EXISTS product_code.sku_bundle_component (
  bundle_sku_id     uuid NOT NULL REFERENCES product_code.sku_master(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  component_sku_id  uuid NOT NULL REFERENCES product_code.sku_master(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  quantity          integer NOT NULL CHECK (quantity > 0),
  created_at        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (bundle_sku_id, component_sku_id)
);

CREATE OR REPLACE VIEW product_code.v_sku_canonical AS
SELECT
  sm.id AS sku_id,
  selfpia.code_value AS selfpia_sku_code,
  selfpia.selfpia_product_code,
  selfpia.selfpia_option_no,
  sm.virtual_sku_code,
  sm.product_id,
  pm.virtual_product_code,
  pm.product_name,
  sm.option_value,
  sm.sku_type,
  sm.status AS sku_status
FROM product_code.sku_master sm
JOIN product_code.code_alias selfpia
  ON selfpia.target_type = 'SKU'
 AND selfpia.target_id = sm.id
 AND selfpia.code_system = 'selfpia_sku'
LEFT JOIN product_code.product_master pm
  ON pm.id = sm.product_id;

-- ============================================================
-- [2] picking: PR_system operating data
-- ============================================================

CREATE TABLE IF NOT EXISTS picking.orders (
  order_id              text PRIMARY KEY,
  raw_ord_no            text UNIQUE,
  inv_no                text,
  channel_code          text,
  ordered_at            timestamptz,
  order_date            date,
  order_status          text,
  cs_status             text,
  buyer_name            text,
  buyer_phone           text,
  buyer_address         text,
  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  source_project_ref    text NOT NULL DEFAULT 'vgxocngpykhlkosiaeew',
  source_table          text NOT NULL DEFAULT 'orders',
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_orders_inv_no ON picking.orders(inv_no);
CREATE INDEX IF NOT EXISTS ix_orders_order_date ON picking.orders(order_date);
CREATE INDEX IF NOT EXISTS ix_orders_status ON picking.orders(order_status);

CREATE TABLE IF NOT EXISTS picking.order_items (
  order_item_id         bigserial PRIMARY KEY,
  raw_item_no           text UNIQUE,
  order_id              text REFERENCES picking.orders(order_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  raw_ord_no            text,
  inv_no                text,
  line_no               integer,

  -- Raw PR_system keys. Never drop raw_p_code; it is needed for audit and
  -- for the 5 legacy unmatched historical shipped lines.
  raw_p_code            text NOT NULL,
  raw_p_dpcode          text,
  raw_prod_code         text,
  p_dpcode_clean        text,
  prod_code_clean       text,
  p_name                text,
  p_option              text,
  qty_ordered           integer CHECK (qty_ordered IS NULL OR qty_ordered > 0),
  order_item_status     text,

  -- Nullable initial master linkage.
  sku_id                uuid,
  selfpia_sku_code      text,
  master_match_status   text NOT NULL DEFAULT 'unmatched'
    CHECK (master_match_status IN ('matched', 'unmatched', 'ambiguous', 'legacy_unmatched')),
  master_match_note     text,
  matched_at            timestamptz,

  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  source_project_ref    text NOT NULL DEFAULT 'vgxocngpykhlkosiaeew',
  source_table          text NOT NULL DEFAULT 'order_items',
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT ck_order_items_match_consistency CHECK (
    (master_match_status = 'matched' AND sku_id IS NOT NULL AND selfpia_sku_code IS NOT NULL)
    OR (master_match_status <> 'matched')
  )
);
CREATE INDEX IF NOT EXISTS ix_order_items_order_id ON picking.order_items(order_id);
CREATE INDEX IF NOT EXISTS ix_order_items_raw_p_code ON picking.order_items(raw_p_code);
CREATE INDEX IF NOT EXISTS ix_order_items_sku_id ON picking.order_items(sku_id);
CREATE INDEX IF NOT EXISTS ix_order_items_match_status ON picking.order_items(master_match_status);
CREATE INDEX IF NOT EXISTS ix_order_items_inv_raw_p_code ON picking.order_items(inv_no, raw_p_code);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_order_items_sku_id'
      AND conrelid = 'picking.order_items'::regclass
  ) THEN
    ALTER TABLE picking.order_items
      ADD CONSTRAINT fk_order_items_sku_id
      FOREIGN KEY (sku_id)
      REFERENCES product_code.sku_master(id)
      ON UPDATE CASCADE
      ON DELETE RESTRICT
      NOT VALID;
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS picking.picking_tasks (
  task_id               bigserial PRIMARY KEY,
  order_item_id         bigint REFERENCES picking.order_items(order_item_id) ON DELETE RESTRICT,
  inv_no                text,
  raw_p_code            text,
  assigned_to           text,
  status                text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'in_progress', 'picked', 'exception', 'cancelled')),
  checked               boolean NOT NULL DEFAULT false,
  started_at            timestamptz,
  completed_at          timestamptz,
  exception_reason      text,
  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (inv_no, raw_p_code)
);
CREATE INDEX IF NOT EXISTS ix_picking_tasks_status ON picking.picking_tasks(status);
CREATE INDEX IF NOT EXISTS ix_picking_tasks_inv_no ON picking.picking_tasks(inv_no);

CREATE TABLE IF NOT EXISTS picking.shortage (
  shortage_id           bigserial PRIMARY KEY,
  order_item_id         bigint REFERENCES picking.order_items(order_item_id) ON DELETE SET NULL,
  inv_no                text,
  raw_p_code            text,
  status                text,
  shortage_qty          integer CHECK (shortage_qty IS NULL OR shortage_qty >= 0),
  cs_memo               text,
  memo_synced           boolean NOT NULL DEFAULT false,
  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (inv_no, raw_p_code)
);

CREATE TABLE IF NOT EXISTS picking.hold_items (
  hold_id               bigserial PRIMARY KEY,
  order_item_id         bigint REFERENCES picking.order_items(order_item_id) ON DELETE SET NULL,
  inv_no                text,
  raw_p_code            text,
  reason                text,
  resolved              boolean NOT NULL DEFAULT false,
  resolved_at           timestamptz,
  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (inv_no, raw_p_code)
);

-- ============================================================
-- [3] inspection: new design area; legacy source currently has 0 rows
-- ============================================================

CREATE TABLE IF NOT EXISTS inspection.inspections (
  inspection_id         bigserial PRIMARY KEY,
  order_item_id         bigint REFERENCES picking.order_items(order_item_id) ON DELETE RESTRICT,
  inv_no                text,
  raw_p_code            text,
  inspector             text,
  result                text NOT NULL DEFAULT 'pending'
    CHECK (result IN ('pending', 'pass', 'fail', 'hold')),
  fail_reason           text,
  inspected_at          timestamptz,
  photo_url             text,
  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_inspections_order_item ON inspection.inspections(order_item_id);
CREATE INDEX IF NOT EXISTS ix_inspections_result ON inspection.inspections(result);

-- ============================================================
-- [4] cs: new ticket design area; legacy source only has templates
-- ============================================================

CREATE TABLE IF NOT EXISTS cs.templates (
  template_id           bigserial PRIMARY KEY,
  legacy_template_id    text,
  template_name         text,
  body                  text,
  is_active             boolean NOT NULL DEFAULT true,
  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cs.tickets (
  ticket_id             bigserial PRIMARY KEY,
  order_id              text REFERENCES picking.orders(order_id) ON UPDATE CASCADE ON DELETE SET NULL,
  order_item_id         bigint REFERENCES picking.order_items(order_item_id) ON DELETE SET NULL,
  ticket_type           text NOT NULL,
  status                text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_progress', 'resolved', 'closed', 'cancelled')),
  channel_code          text,
  summary               text,
  detail                text,
  opened_at             timestamptz NOT NULL DEFAULT now(),
  resolved_at           timestamptz,
  handler               text,
  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS ix_tickets_order_id ON cs.tickets(order_id);
CREATE INDEX IF NOT EXISTS ix_tickets_status ON cs.tickets(status);

CREATE TABLE IF NOT EXISTS cs.ticket_events (
  event_id              bigserial PRIMARY KEY,
  ticket_id             bigint NOT NULL REFERENCES cs.tickets(ticket_id) ON DELETE CASCADE,
  event_type            text NOT NULL,
  actor                 text,
  payload               jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at            timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- [5] stg: ETL staging and unmatched/ambiguous review support
-- ============================================================

CREATE TABLE IF NOT EXISTS stg.unmatched_order_items (
  id                    bigserial PRIMARY KEY,
  raw_item_no           text,
  raw_ord_no            text,
  inv_no                text,
  raw_p_code            text NOT NULL,
  raw_p_dpcode          text,
  raw_prod_code         text,
  p_dpcode_clean        text,
  prod_code_clean       text,
  p_name                text,
  p_option              text,
  qty_ordered           integer,
  order_item_status     text,
  unmatched_reason      text NOT NULL,
  suggested_action      text,
  candidate_sku_ids     uuid[],
  resolved              boolean NOT NULL DEFAULT false,
  resolved_sku_id       uuid,
  resolved_by           text,
  resolved_at           timestamptz,
  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_unmatched_raw_p_code ON stg.unmatched_order_items(raw_p_code);
CREATE INDEX IF NOT EXISTS ix_unmatched_resolved ON stg.unmatched_order_items(resolved);

CREATE TABLE IF NOT EXISTS stg.own_sku_match_candidates (
  id                    bigserial PRIMARY KEY,
  raw_item_no           text,
  own_sku_code          text NOT NULL,
  candidate_sku_id      uuid NOT NULL,
  candidate_selfpia_sku_code text,
  is_primary            boolean,
  candidate_rank        integer,
  review_status         text NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'accepted', 'rejected')),
  reviewer              text,
  reviewed_at           timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_own_sku_candidates_key ON stg.own_sku_match_candidates(own_sku_code);
CREATE INDEX IF NOT EXISTS ix_own_sku_candidates_item ON stg.own_sku_match_candidates(raw_item_no);

CREATE OR REPLACE VIEW stg.v_ambiguous_own_sku_candidates AS
SELECT
  raw_item_no,
  own_sku_code,
  count(*) AS candidate_count,
  array_agg(candidate_sku_id ORDER BY candidate_rank NULLS LAST, candidate_sku_id) AS candidate_sku_ids
FROM stg.own_sku_match_candidates
WHERE review_status = 'pending'
GROUP BY raw_item_no, own_sku_code
HAVING count(*) > 1;

-- Seed known local cross mapping misses as reference rows for local validation.
-- ETL can upsert equivalent rows from real migration output.
INSERT INTO stg.unmatched_order_items (
  raw_p_code,
  p_name,
  unmatched_reason,
  suggested_action,
  order_item_status
)
VALUES
  ('9826-1',  '925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종', 'legacy_unmatched_selfpia_sku', 'preserve raw_p_code; keep as legacy_unmatched unless Product_code master is backfilled', '배송완료'),
  ('9826-3',  '925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종', 'legacy_unmatched_selfpia_sku', 'preserve raw_p_code; keep as legacy_unmatched unless Product_code master is backfilled', '배송완료'),
  ('9826-26', '925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종', 'legacy_unmatched_selfpia_sku', 'preserve raw_p_code; keep as legacy_unmatched unless Product_code master is backfilled', '배송완료'),
  ('9826-31', '925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종', 'legacy_unmatched_selfpia_sku', 'preserve raw_p_code; keep as legacy_unmatched unless Product_code master is backfilled', '배송완료'),
  ('9826-48', '925 실버 피어싱 귀걸이 원터치 미니 링피어싱 귓바퀴 93종', 'legacy_unmatched_selfpia_sku', 'preserve raw_p_code; keep as legacy_unmatched unless Product_code master is backfilled', '배송완료')
ON CONFLICT DO NOTHING;

-- ============================================================
-- [6] audit
-- ============================================================

CREATE TABLE IF NOT EXISTS audit.row_changes (
  change_id             bigserial PRIMARY KEY,
  schema_name           text NOT NULL,
  table_name            text NOT NULL,
  pk_text               text NOT NULL,
  op                    char(1) NOT NULL CHECK (op IN ('I', 'U', 'D')),
  before                jsonb,
  after                 jsonb,
  actor                 text,
  changed_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit.sync_log (
  sync_id               bigserial PRIMARY KEY,
  source_project_ref    text,
  source_table          text,
  sync_started_at       timestamptz NOT NULL DEFAULT now(),
  sync_finished_at      timestamptz,
  status                text NOT NULL DEFAULT 'started',
  row_count             bigint,
  message               text,
  payload               jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- ============================================================
-- [7] Local verification views
-- ============================================================

CREATE OR REPLACE VIEW picking.v_order_items_master_match_summary AS
SELECT
  master_match_status,
  count(*) AS lines,
  count(DISTINCT raw_p_code) AS distinct_raw_p_code
FROM picking.order_items
GROUP BY master_match_status;

CREATE OR REPLACE VIEW picking.v_order_items_unmatched AS
SELECT
  order_item_id,
  raw_item_no,
  raw_ord_no,
  inv_no,
  raw_p_code,
  p_name,
  p_option,
  qty_ordered,
  order_item_status,
  master_match_status,
  master_match_note
FROM picking.order_items
WHERE master_match_status IN ('unmatched', 'ambiguous', 'legacy_unmatched');
