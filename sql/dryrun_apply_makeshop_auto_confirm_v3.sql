-- =============================================================================
-- dryrun_apply_makeshop_auto_confirm_v3.sql
--
-- DRYRUN ONLY: simulate inserting MakeShop auto_confirm v3 candidates into
-- product_code.sku_channel_mapping, then ROLLBACK.
--
-- This is not the real apply SQL.
--
-- Safety:
--   - product_ops_test guard
--   - source loaded into TEMP TABLE
--   - information_schema target column inspection
--   - INSERT simulation happens inside BEGIN ... ROLLBACK
--   - no DB changes persist after this script completes
--
-- CSV input path inside Docker container:
--   /tmp/makeshop_auto_confirm_candidates_v3.csv
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'dryrun apply is allowed only on product_ops_test. Current database: %',
      current_database();
  END IF;
END
$$;

BEGIN;

CREATE TEMP TABLE stg_makeshop_auto_confirm_v3 (
  channel_code                         text,
  seller_product_code_raw              text,
  channel_sku_code                     text,
  sto_id_raw                           text,
  sto_code                             text,
  opt_value                            text,
  opt_values                           text,
  own_sku_code                         text,
  extraction_method                    text,
  regex_pattern_used                   text,
  auto_confirm_type                    text,
  matched_sku_id                       text,
  matched_virtual_sku_code             text,
  matched_option_value                 text,
  matched_product_id                   text,
  matched_product_name                 text,
  makeshop_product_name                text,
  barcode                              text,
  repeated_matched_sku_count           text,
  repeated_matched_sku_3plus_flag      text,
  v2_selected_own_sku_code             text,
  v2_selected_matched_sku_id           text,
  changed_from_v2_flag                 text,
  source_note                          text
);

\copy stg_makeshop_auto_confirm_v3 FROM '/tmp/makeshop_auto_confirm_candidates_v3.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

CREATE TEMP TABLE target_columns AS
SELECT
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
FROM information_schema.columns c
WHERE c.table_schema = 'product_code'
  AND c.table_name = 'sku_channel_mapping'
ORDER BY c.ordinal_position;

CREATE TEMP TABLE insert_column_plan (
  column_name text PRIMARY KEY,
  used boolean NOT NULL,
  source_expression text NOT NULL
);

INSERT INTO insert_column_plan (column_name, used, source_expression)
SELECT column_name, true, source_expression
FROM (
  VALUES
    ('sku_id', 'c.matched_sku_id_uuid'),
    ('channel_code', '''makeshop''::text'),
    ('channel_sku_code', 'c.channel_sku_code'),
    ('seller_product_code', 'c.seller_product_code_raw'),
    ('own_sku_code', 'c.own_sku_code'),
    ('is_primary', 'false'),
    ('raw_payload', 'c.raw_payload'),
    ('created_at', 'now()'),
    ('updated_at', 'now()')
) AS v(column_name, source_expression)
WHERE EXISTS (
  SELECT 1
  FROM target_columns tc
  WHERE tc.column_name = v.column_name
);

CREATE TEMP TABLE source_normalized AS
SELECT
  row_number() OVER () AS source_row_id,
  s.*,
  NULLIF(btrim(s.channel_code), '') AS source_channel_code,
  NULLIF(btrim(s.channel_sku_code), '') AS normalized_channel_sku_code,
  NULLIF(btrim(s.seller_product_code_raw), '') AS normalized_seller_product_code_raw,
  CASE
    WHEN NULLIF(btrim(s.matched_sku_id), '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN NULLIF(btrim(s.matched_sku_id), '')::uuid
    ELSE NULL
  END AS matched_sku_id_uuid,
  (lower(COALESCE(s.repeated_matched_sku_3plus_flag, '')) IN ('t', 'true', '1', 'yes')) AS repeated_matched_sku_3plus_bool,
  (lower(COALESCE(s.changed_from_v2_flag, '')) IN ('t', 'true', '1', 'yes')) AS changed_from_v2_bool
FROM stg_makeshop_auto_confirm_v3 s;

CREATE TEMP TABLE source_duplicates AS
SELECT
  normalized_channel_sku_code AS channel_sku_code,
  COUNT(*) AS duplicate_rows
FROM source_normalized
WHERE normalized_channel_sku_code IS NOT NULL
GROUP BY normalized_channel_sku_code
HAVING COUNT(*) > 1;

CREATE TEMP TABLE existing_makeshop_mapping AS
SELECT
  channel_sku_code,
  COUNT(*) AS existing_rows,
  COUNT(DISTINCT sku_id) AS existing_distinct_sku_ids,
  MIN(id) AS sample_existing_mapping_id,
  CASE
    WHEN COUNT(DISTINCT sku_id) = 1
      THEN (array_agg(DISTINCT sku_id))[1]
    ELSE NULL
  END AS single_existing_sku_id,
  array_agg(DISTINCT sku_id ORDER BY sku_id) AS existing_sku_ids
FROM product_code.sku_channel_mapping
WHERE channel_code = 'makeshop'
  AND channel_sku_code IS NOT NULL
GROUP BY channel_sku_code;

CREATE TEMP TABLE source_classified AS
SELECT
  n.*,
  sm.id AS confirmed_sku_id,
  existing.sample_existing_mapping_id AS existing_mapping_id,
  existing.single_existing_sku_id AS existing_mapped_sku_id,
  existing.existing_sku_ids,
  d.duplicate_rows,
  jsonb_strip_nulls(jsonb_build_object(
    'source', 'makeshop_auto_confirm_v3',
    'seller_product_code_raw', n.seller_product_code_raw,
    'sto_id_raw', n.sto_id_raw,
    'sto_code', n.sto_code,
    'own_sku_code', n.own_sku_code,
    'extraction_method', n.extraction_method,
    'regex_pattern_used', n.regex_pattern_used,
    'auto_confirm_type', n.auto_confirm_type,
    'matched_virtual_sku_code', n.matched_virtual_sku_code,
    'matched_option_value', n.matched_option_value,
    'matched_product_id', n.matched_product_id,
    'matched_product_name', n.matched_product_name,
    'makeshop_product_name', n.makeshop_product_name,
    'barcode', n.barcode,
    'repeated_matched_sku_count', n.repeated_matched_sku_count,
    'repeated_matched_sku_3plus_flag', n.repeated_matched_sku_3plus_bool,
    'v2_selected_own_sku_code', n.v2_selected_own_sku_code,
    'v2_selected_matched_sku_id', n.v2_selected_matched_sku_id,
    'changed_from_v2_flag', n.changed_from_v2_bool,
    'source_note', n.source_note
  )) AS raw_payload,
  CASE
    WHEN n.source_channel_code IS DISTINCT FROM 'makeshop' THEN 'invalid_channel_code'
    WHEN n.normalized_channel_sku_code IS NULL THEN 'null_channel_sku_code'
    WHEN n.matched_sku_id_uuid IS NULL THEN 'missing_matched_sku_id'
    WHEN sm.id IS NULL THEN 'matched_sku_not_found'
    WHEN d.channel_sku_code IS NOT NULL THEN 'duplicate_source_channel_sku_code'
    WHEN existing.channel_sku_code IS NOT NULL
     AND existing.existing_distinct_sku_ids = 1
     AND existing.single_existing_sku_id IS NOT DISTINCT FROM n.matched_sku_id_uuid THEN 'idempotent_existing'
    WHEN existing.channel_sku_code IS NOT NULL THEN 'conflict_existing_different_sku'
    ELSE 'insert_candidate'
  END AS dryrun_action
FROM source_normalized n
LEFT JOIN source_duplicates d
  ON d.channel_sku_code = n.normalized_channel_sku_code
LEFT JOIN product_code.sku_master sm
  ON sm.id = n.matched_sku_id_uuid
LEFT JOIN existing_makeshop_mapping existing
  ON existing.channel_sku_code = n.normalized_channel_sku_code;

CREATE TEMP TABLE dryrun_counts_before AS
SELECT
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping) AS scm_before,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE channel_code = 'makeshop') AS makeshop_before;

CREATE TEMP TABLE dryrun_inserted_keys (
  channel_code text,
  channel_sku_code text,
  sku_id uuid
);

\echo
\echo ===== [DRYRUN APPLY SUMMARY] =====
SELECT
  COUNT(*) AS source_rows,
  11179::integer AS expected_rows,
  COUNT(*) FILTER (WHERE dryrun_action = 'insert_candidate') AS insert_candidate_rows,
  COUNT(*) FILTER (WHERE dryrun_action = 'idempotent_existing') AS idempotent_existing_rows,
  COUNT(*) FILTER (WHERE dryrun_action = 'conflict_existing_different_sku') AS conflict_existing_different_sku_rows,
  COUNT(*) FILTER (WHERE dryrun_action = 'duplicate_source_channel_sku_code') AS duplicate_source_channel_sku_code,
  COUNT(*) FILTER (
    WHERE dryrun_action IN ('invalid_channel_code', 'null_channel_sku_code')
  ) AS null_required_key_rows,
  COUNT(*) FILTER (
    WHERE dryrun_action IN ('missing_matched_sku_id', 'matched_sku_not_found')
  ) AS missing_matched_sku_rows,
  COUNT(*) FILTER (WHERE auto_confirm_type = 'new_regex_candidate') AS new_regex_candidate_rows,
  COUNT(*) FILTER (WHERE changed_from_v2_bool) AS changed_from_v2_rows,
  COUNT(*) FILTER (WHERE repeated_matched_sku_3plus_bool) AS repeated_matched_sku_3plus_rows
FROM source_classified;

\echo
\echo ===== [TARGET TABLE COLUMNS] =====
SELECT
  tc.ordinal_position,
  tc.column_name,
  tc.data_type,
  tc.is_nullable,
  CASE WHEN icp.used THEN true ELSE false END AS used_for_insert,
  icp.source_expression
FROM target_columns tc
LEFT JOIN insert_column_plan icp
  ON icp.column_name = tc.column_name
ORDER BY tc.ordinal_position;

\echo
\echo ===== [DRYRUN INSERT PREVIEW] =====
SELECT
  channel_code,
  seller_product_code_raw,
  channel_sku_code,
  sto_id_raw,
  own_sku_code,
  auto_confirm_type,
  matched_sku_id,
  matched_virtual_sku_code,
  matched_option_value,
  changed_from_v2_flag,
  repeated_matched_sku_3plus_flag
FROM source_classified
WHERE dryrun_action = 'insert_candidate'
ORDER BY seller_product_code_raw, sto_id_raw, channel_sku_code
LIMIT 100;

\echo
\echo ===== [DRYRUN CONFLICTS] =====
SELECT
  channel_code,
  seller_product_code_raw,
  channel_sku_code,
  sto_id_raw,
  own_sku_code,
  matched_sku_id_uuid AS would_insert_sku_id,
  existing_mapping_id,
  existing_mapped_sku_id,
  dryrun_action
FROM source_classified
WHERE dryrun_action IN (
  'conflict_existing_different_sku',
  'duplicate_source_channel_sku_code',
  'invalid_channel_code',
  'null_channel_sku_code',
  'missing_matched_sku_id',
  'matched_sku_not_found'
)
ORDER BY dryrun_action, seller_product_code_raw, sto_id_raw
LIMIT 200;

DO $$
DECLARE
  v_cols text;
  v_exprs text;
  v_sql text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM target_columns WHERE column_name = 'sku_id')
     OR NOT EXISTS (SELECT 1 FROM target_columns WHERE column_name = 'channel_code')
     OR NOT EXISTS (SELECT 1 FROM target_columns WHERE column_name = 'channel_sku_code') THEN
    RAISE EXCEPTION 'sku_channel_mapping is missing one of required columns: sku_id, channel_code, channel_sku_code';
  END IF;

  SELECT
    string_agg(format('%I', column_name), ', ' ORDER BY
      CASE column_name
        WHEN 'sku_id' THEN 1
        WHEN 'channel_code' THEN 2
        WHEN 'channel_sku_code' THEN 3
        WHEN 'seller_product_code' THEN 4
        WHEN 'own_sku_code' THEN 5
        WHEN 'is_primary' THEN 6
        WHEN 'raw_payload' THEN 7
        WHEN 'created_at' THEN 8
        WHEN 'updated_at' THEN 9
        ELSE 100
      END),
    string_agg(source_expression, ', ' ORDER BY
      CASE column_name
        WHEN 'sku_id' THEN 1
        WHEN 'channel_code' THEN 2
        WHEN 'channel_sku_code' THEN 3
        WHEN 'seller_product_code' THEN 4
        WHEN 'own_sku_code' THEN 5
        WHEN 'is_primary' THEN 6
        WHEN 'raw_payload' THEN 7
        WHEN 'created_at' THEN 8
        WHEN 'updated_at' THEN 9
        ELSE 100
      END)
  INTO v_cols, v_exprs
  FROM insert_column_plan
  WHERE used;

  v_sql := format(
    'WITH ins AS (
       INSERT INTO product_code.sku_channel_mapping (%s)
       SELECT %s
       FROM source_classified c
       WHERE c.dryrun_action = %L
       RETURNING channel_code, channel_sku_code, sku_id
     )
     INSERT INTO dryrun_inserted_keys (channel_code, channel_sku_code, sku_id)
     SELECT channel_code, channel_sku_code, sku_id FROM ins',
    v_cols,
    v_exprs,
    'insert_candidate'
  );

  EXECUTE v_sql;
END
$$;

\echo
\echo ===== [DRYRUN POSTCHECK BEFORE ROLLBACK] =====
SELECT
  b.scm_before,
  (SELECT COUNT(*) FROM dryrun_inserted_keys) AS inserted_rows,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping) AS scm_after,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping) - b.scm_before AS delta,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE channel_code = 'makeshop') AS makeshop_rows_after,
  (
    (SELECT COUNT(*) FROM product_code.sku_channel_mapping) - b.scm_before
  ) = (SELECT COUNT(*) FROM dryrun_inserted_keys) AS expected_delta_matches
FROM dryrun_counts_before b;

\echo
\echo ===== [ROLLBACK CHECK] =====
\echo ROLLBACK is executed immediately after this section. No dryrun INSERT persists.

ROLLBACK;

\echo
\echo dryrun_apply_makeshop_auto_confirm_v3.sql complete. ROLLBACK applied. No persistent DB changes.
