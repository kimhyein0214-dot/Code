/*
  Ably / PlayAuto local stage schema apply dryrun v1.

  Purpose:
  - Verify that the local-only product_code_stage schema draft can be applied
    inside a transaction on product_ops_test.
  - Verify tables, defaults, constraints, indexes, and traceability columns.
  - Roll back the transaction and confirm no product_code_stage objects remain.

  Safety:
  - Local product_ops_test only.
  - No source file import.
  - No file import commands.
  - No mapping apply.
  - The transaction is rolled back by this script.
*/

BEGIN;

SELECT
  'guard'::text AS section,
  current_database() AS current_database,
  current_user AS current_user,
  current_setting('transaction_read_only') AS transaction_read_only,
  CASE
    WHEN current_database() = 'product_ops_test'
      THEN 'PASS'
    ELSE 'STOP'
  END AS guard_result,
  'schema dryrun transaction started; this script ends with rollback'::text AS note;

DO $guard$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'schema dryrun blocked: current database is %, expected product_ops_test', current_database();
  END IF;
END
$guard$;

SELECT
  'pre_dryrun_existing_stage_objects'::text AS section,
  COUNT(*)::bigint AS existing_relation_count,
  COUNT(*) FILTER (WHERE n.nspname = 'product_code_stage')::bigint AS existing_schema_count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS dryrun_verdict,
  'Expected zero before first local stage schema dryrun.'::text AS note
FROM pg_namespace AS n
LEFT JOIN pg_class AS c
  ON c.relnamespace = n.oid
WHERE n.nspname = 'product_code_stage';

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

WITH expected_tables AS (
  SELECT *
  FROM (
    VALUES
      ('ably_playauto_source_file'),
      ('ably_raw'),
      ('playauto_product_raw'),
      ('playauto_sku_raw'),
      ('channel_option_evidence')
  ) AS t(table_name)
)
SELECT
  'created_table_presence'::text AS section,
  e.table_name,
  CASE WHEN c.relname IS NULL THEN 'NEEDS_REVIEW' ELSE 'PASS' END AS dryrun_verdict,
  c.relkind,
  'table should exist inside transaction before rollback'::text AS note
FROM expected_tables AS e
LEFT JOIN pg_namespace AS n
  ON n.nspname = 'product_code_stage'
LEFT JOIN pg_class AS c
  ON c.relnamespace = n.oid
 AND c.relname = e.table_name
 AND c.relkind IN ('r', 'p')
ORDER BY e.table_name;

WITH expected_columns AS (
  SELECT *
  FROM (
    VALUES
      ('ably_playauto_source_file', 'source_file_id', 'uuid'),
      ('ably_raw', 'source_file_id', 'uuid'),
      ('ably_raw', 'source_row_no', 'integer'),
      ('ably_raw', 'raw_payload', 'jsonb'),
      ('playauto_product_raw', 'source_file_id', 'uuid'),
      ('playauto_product_raw', 'source_row_no', 'integer'),
      ('playauto_product_raw', 'raw_payload', 'jsonb'),
      ('playauto_sku_raw', 'source_file_id', 'uuid'),
      ('playauto_sku_raw', 'source_row_no', 'integer'),
      ('playauto_sku_raw', 'raw_payload', 'jsonb'),
      ('channel_option_evidence', 'source_file_id', 'uuid'),
      ('channel_option_evidence', 'source_row_no', 'integer'),
      ('channel_option_evidence', 'source_option_line_no', 'integer'),
      ('channel_option_evidence', 'raw_payload', 'jsonb'),
      ('channel_option_evidence', 'reviewer_decision', 'text'),
      ('channel_option_evidence', 'export_allowed', 'boolean'),
      ('channel_option_evidence', 'channel_code', 'text')
  ) AS c(table_name, column_name, expected_data_type)
)
SELECT
  'traceability_and_payload_column_check'::text AS section,
  e.table_name,
  e.column_name,
  col.data_type,
  CASE
    WHEN col.column_name IS NULL THEN 'NEEDS_REVIEW'
    WHEN col.data_type = e.expected_data_type THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS dryrun_verdict,
  concat('expected_data_type=', e.expected_data_type) AS note
FROM expected_columns AS e
LEFT JOIN information_schema.columns AS col
  ON col.table_schema = 'product_code_stage'
 AND col.table_name = e.table_name
 AND col.column_name = e.column_name
ORDER BY e.table_name, e.column_name;

SELECT
  'default_check'::text AS section,
  table_name,
  column_name,
  column_default,
  CASE
    WHEN table_name = 'channel_option_evidence'
     AND column_name = 'reviewer_decision'
     AND column_default = '''pending''::text' THEN 'PASS'
    WHEN table_name = 'channel_option_evidence'
     AND column_name = 'export_allowed'
     AND column_default = 'false' THEN 'PASS'
    WHEN column_name = 'parse_status'
     AND column_default = '''pending''::text' THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS dryrun_verdict,
  'default must keep staged evidence pending and non-exportable'::text AS note
FROM information_schema.columns
WHERE table_schema = 'product_code_stage'
  AND (
    (table_name = 'channel_option_evidence' AND column_name IN ('reviewer_decision', 'export_allowed', 'parse_status'))
    OR (table_name IN ('ably_raw', 'playauto_product_raw', 'playauto_sku_raw') AND column_name = 'parse_status')
  )
ORDER BY table_name, column_name;

WITH expected_constraints AS (
  SELECT *
  FROM (
    VALUES
      ('ably_playauto_source_file', 'ck_ably_playauto_source_file_name_not_path'),
      ('channel_option_evidence', 'ck_channel_option_evidence_reviewer_pending'),
      ('channel_option_evidence', 'ck_channel_option_evidence_export_blocked'),
      ('channel_option_evidence', 'ck_channel_option_evidence_not_playauto_channel')
  ) AS c(table_name, constraint_name)
)
SELECT
  'constraint_check'::text AS section,
  e.table_name,
  e.constraint_name,
  pg_get_constraintdef(con.oid) AS constraint_definition,
  CASE WHEN con.oid IS NULL THEN 'NEEDS_REVIEW' ELSE 'PASS' END AS dryrun_verdict,
  'required safety constraint should exist inside transaction'::text AS note
FROM expected_constraints AS e
LEFT JOIN pg_namespace AS n
  ON n.nspname = 'product_code_stage'
LEFT JOIN pg_class AS cls
  ON cls.relnamespace = n.oid
 AND cls.relname = e.table_name
LEFT JOIN pg_constraint AS con
  ON con.conrelid = cls.oid
 AND con.conname = e.constraint_name
ORDER BY e.table_name, e.constraint_name;

WITH expected_indexes AS (
  SELECT *
  FROM (
    VALUES
      ('ix_ably_raw_product_no'),
      ('ix_ably_raw_option_no'),
      ('ix_playauto_product_raw_account'),
      ('ix_playauto_product_raw_product_no'),
      ('ix_playauto_sku_raw_code'),
      ('ix_channel_option_evidence_source'),
      ('ix_channel_option_evidence_channel_product'),
      ('ix_channel_option_evidence_channel_option'),
      ('ix_channel_option_evidence_own_sku_candidate'),
      ('ix_channel_option_evidence_selfpia_candidate')
  ) AS i(index_name)
)
SELECT
  'index_check'::text AS section,
  e.index_name,
  CASE WHEN c.relname IS NULL THEN 'NEEDS_REVIEW' ELSE 'PASS' END AS dryrun_verdict,
  pg_get_indexdef(c.oid) AS index_definition
FROM expected_indexes AS e
LEFT JOIN pg_namespace AS n
  ON n.nspname = 'product_code_stage'
LEFT JOIN pg_class AS c
  ON c.relnamespace = n.oid
 AND c.relname = e.index_name
 AND c.relkind = 'i'
ORDER BY e.index_name;

SELECT
  'in_transaction_dryrun_verdict'::text AS section,
  CASE
    WHEN (
      SELECT COUNT(*)
      FROM pg_namespace AS n
      JOIN pg_class AS c
        ON c.relnamespace = n.oid
      WHERE n.nspname = 'product_code_stage'
        AND c.relname IN (
          'ably_playauto_source_file',
          'ably_raw',
          'playauto_product_raw',
          'playauto_sku_raw',
          'channel_option_evidence'
        )
        AND c.relkind IN ('r', 'p')
    ) = 5
    AND EXISTS (
      SELECT 1
      FROM pg_constraint AS con
      JOIN pg_class AS cls
        ON cls.oid = con.conrelid
      JOIN pg_namespace AS n
        ON n.oid = cls.relnamespace
      WHERE n.nspname = 'product_code_stage'
        AND cls.relname = 'channel_option_evidence'
        AND con.conname = 'ck_channel_option_evidence_not_playauto_channel'
    )
    THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS dryrun_verdict,
  'All required tables and playauto channel blocking constraint must exist before rollback.'::text AS note;

ROLLBACK;

SELECT
  'post_rollback_residual_check'::text AS section,
  COUNT(*)::bigint AS remaining_relation_count,
  COUNT(*) FILTER (WHERE n.nspname = 'product_code_stage')::bigint AS remaining_schema_count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'NEEDS_REVIEW' END AS dryrun_verdict,
  'Expected zero after rollback; no local stage schema objects should remain.'::text AS note
FROM pg_namespace AS n
LEFT JOIN pg_class AS c
  ON c.relnamespace = n.oid
WHERE n.nspname = 'product_code_stage';

SELECT
  'final_dryrun_verdict'::text AS section,
  CASE
    WHEN NOT EXISTS (
      SELECT 1
      FROM pg_namespace
      WHERE nspname = 'product_code_stage'
    ) THEN 'PASS'
    ELSE 'NEEDS_REVIEW'
  END AS dryrun_verdict,
  'PASS means schema draft applied inside the transaction and no stage objects remained after rollback.'::text AS note;
