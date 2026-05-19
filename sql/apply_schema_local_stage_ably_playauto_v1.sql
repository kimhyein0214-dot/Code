/*
  Apply Ably / PlayAuto local stage schema v1.

  Scope:
  - Local product_ops_test only.
  - Creates product_code_stage schema and five empty stage tables.
  - Creates safety constraints and indexes verified by the prior dryrun.

  Safety:
  - No source file import.
  - No stage data load.
  - No code_alias changes.
  - No sku_channel_mapping changes.
  - Not for operating Supabase.
  - Not for NAS PostgreSQL.
*/

BEGIN;

SELECT
  'guard'::text AS section,
  current_database() AS current_database,
  current_user AS current_user,
  CASE
    WHEN current_database() = 'product_ops_test'
     AND current_user = 'product_ops_tester'
    THEN 'PASS'
    ELSE 'STOP'
  END AS guard_result,
  'local stage schema apply guard'::text AS note;

DO $guard$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'blocked: current database is %, expected product_ops_test', current_database();
  END IF;

  IF current_user <> 'product_ops_tester' THEN
    RAISE EXCEPTION 'blocked: current user is %, expected product_ops_tester', current_user;
  END IF;
END
$guard$;

CREATE SCHEMA IF NOT EXISTS product_code_stage;

CREATE TABLE IF NOT EXISTS product_code_stage.ably_playauto_source_file (
  source_file_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_system        text NOT NULL CHECK (source_system IN ('ably_csv', 'playauto_xlsx')),
  source_file_name     text NOT NULL,
  source_file_hash     text,
  source_row_count     integer,
  source_column_count  integer,
  source_sheet_count   integer,
  source_note          text,
  collected_at         timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_ably_playauto_source_file_name_not_path
    CHECK (source_file_name !~ '[\\/]' )
);

CREATE TABLE IF NOT EXISTS product_code_stage.ably_raw (
  source_file_id       uuid NOT NULL REFERENCES product_code_stage.ably_playauto_source_file(source_file_id),
  source_row_no        integer NOT NULL,
  raw_product_no       text,
  raw_option_no        text,
  raw_seller_product_code text,
  raw_solution_unique_code text,
  raw_product_name     text,
  raw_option1          text,
  raw_option2          text,
  raw_full_option_name text,
  raw_stock_qty        text,
  raw_soldout_status   text,
  raw_display_status   text,
  raw_payload          jsonb NOT NULL DEFAULT '{}'::jsonb,
  raw_row_hash         text,
  parse_status         text NOT NULL DEFAULT 'pending'
    CHECK (parse_status IN ('pending', 'ok', 'warning', 'error')),
  parse_warning        text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (source_file_id, source_row_no)
);

CREATE INDEX IF NOT EXISTS ix_ably_raw_product_no
  ON product_code_stage.ably_raw(source_file_id, raw_product_no);

CREATE INDEX IF NOT EXISTS ix_ably_raw_option_no
  ON product_code_stage.ably_raw(source_file_id, raw_option_no);

CREATE TABLE IF NOT EXISTS product_code_stage.playauto_product_raw (
  source_file_id       uuid NOT NULL REFERENCES product_code_stage.ably_playauto_source_file(source_file_id),
  source_sheet_name    text NOT NULL DEFAULT 'shopping_mall_products',
  source_row_no        integer NOT NULL,
  raw_seller_management_code text,
  raw_mall_account     text,
  raw_online_product_name text,
  raw_mall_product_no  text,
  raw_product_status   text,
  raw_option_text      text,
  raw_sku_text         text,
  raw_option_extra_price text,
  raw_option_sale_qty  text,
  raw_outbound_qty     text,
  raw_option_status    text,
  raw_payload          jsonb NOT NULL DEFAULT '{}'::jsonb,
  raw_row_hash         text,
  parse_status         text NOT NULL DEFAULT 'pending'
    CHECK (parse_status IN ('pending', 'ok', 'warning', 'error')),
  parse_warning        text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (source_file_id, source_sheet_name, source_row_no)
);

CREATE INDEX IF NOT EXISTS ix_playauto_product_raw_account
  ON product_code_stage.playauto_product_raw(source_file_id, raw_mall_account);

CREATE INDEX IF NOT EXISTS ix_playauto_product_raw_product_no
  ON product_code_stage.playauto_product_raw(source_file_id, raw_mall_product_no);

CREATE TABLE IF NOT EXISTS product_code_stage.playauto_sku_raw (
  source_file_id       uuid NOT NULL REFERENCES product_code_stage.ably_playauto_source_file(source_file_id),
  source_sheet_name    text NOT NULL DEFAULT 'sku_products',
  source_row_no        integer NOT NULL,
  raw_sku_code         text NOT NULL,
  raw_sku_name         text,
  raw_attribute        text,
  raw_shipping_place_code text,
  raw_payload          jsonb NOT NULL DEFAULT '{}'::jsonb,
  raw_row_hash         text,
  parse_status         text NOT NULL DEFAULT 'pending'
    CHECK (parse_status IN ('pending', 'ok', 'warning', 'error')),
  parse_warning        text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (source_file_id, source_sheet_name, source_row_no)
);

CREATE INDEX IF NOT EXISTS ix_playauto_sku_raw_code
  ON product_code_stage.playauto_sku_raw(source_file_id, raw_sku_code);

CREATE TABLE IF NOT EXISTS product_code_stage.channel_option_evidence (
  evidence_id          bigserial PRIMARY KEY,
  source_file_id       uuid NOT NULL REFERENCES product_code_stage.ably_playauto_source_file(source_file_id),
  source_system        text NOT NULL CHECK (source_system IN ('ably_csv', 'playauto_xlsx')),
  source_sheet_name    text NOT NULL,
  source_row_no        integer NOT NULL,
  source_option_line_no integer,
  channel_code         text NOT NULL,
  channel_account      text,
  channel_product_code text,
  channel_option_code  text,
  seller_product_code  text,
  channel_sku_code     text,
  own_sku_code_candidate text,
  selfpia_sku_candidate text,
  product_name         text,
  option_name          text,
  option_value         text,
  sale_status_raw      text,
  display_status_raw   text,
  option_status_raw    text,
  stock_qty_raw        text,
  normalized_sale_status text,
  normalized_display_status text,
  normalized_option_status text,
  is_active_candidate  boolean NOT NULL DEFAULT false,
  raw_payload          jsonb NOT NULL DEFAULT '{}'::jsonb,
  parse_status         text NOT NULL DEFAULT 'pending'
    CHECK (parse_status IN ('pending', 'ok', 'warning', 'error')),
  parse_warning        text,
  reviewer_decision    text NOT NULL DEFAULT 'pending',
  export_allowed       boolean NOT NULL DEFAULT false,
  created_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_channel_option_evidence_reviewer_pending
    CHECK (reviewer_decision = 'pending'),
  CONSTRAINT ck_channel_option_evidence_export_blocked
    CHECK (export_allowed = false),
  CONSTRAINT ck_channel_option_evidence_not_playauto_channel
    CHECK (channel_code <> 'playauto')
);

CREATE INDEX IF NOT EXISTS ix_channel_option_evidence_source
  ON product_code_stage.channel_option_evidence(source_file_id, source_system, source_row_no, source_option_line_no);

CREATE INDEX IF NOT EXISTS ix_channel_option_evidence_channel_product
  ON product_code_stage.channel_option_evidence(channel_code, channel_account, channel_product_code);

CREATE INDEX IF NOT EXISTS ix_channel_option_evidence_channel_option
  ON product_code_stage.channel_option_evidence(channel_code, channel_option_code);

CREATE INDEX IF NOT EXISTS ix_channel_option_evidence_own_sku_candidate
  ON product_code_stage.channel_option_evidence(own_sku_code_candidate);

CREATE INDEX IF NOT EXISTS ix_channel_option_evidence_selfpia_candidate
  ON product_code_stage.channel_option_evidence(selfpia_sku_candidate);

COMMIT;

SELECT
  'apply_complete'::text AS section,
  current_database() AS current_database,
  current_user AS current_user,
  'PASS'::text AS apply_result,
  'product_code_stage schema applied locally; stage tables are empty until a later import step'::text AS note;
