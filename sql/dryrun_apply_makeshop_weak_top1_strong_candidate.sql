-- =============================================================================
-- dryrun_apply_makeshop_weak_top1_strong_candidate.sql
--
-- DRYRUN ONLY: simulate inserting MakeShop weak_top1 strong candidates into
-- product_code.sku_channel_mapping, then ROLLBACK.
--
-- This is not real apply SQL. It intentionally ends with ROLLBACK.
--
-- Input CSV inside Docker container:
--   /tmp/makeshop_weak_top1_strong_candidate.csv
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'dryrun_apply_makeshop_weak_top1_strong_candidate.sql is allowed only on product_ops_test. Current database: %',
      current_database();
  END IF;
END
$$;

BEGIN;

CREATE TEMP TABLE stg_makeshop_weak_top1_strong_candidate (
  analysis_status text,
  strong_candidate text,
  strong_candidate_reason text,
  review_reason text,
  option_exact_match text,
  option_partial_match text,
  selfpia_option_no_matches_sto_id text,
  extracted_selfpia_option_nos text,
  extracted_selfpia_product_aliases text,
  primary_selfpia_option_no text,
  primary_selfpia_product_alias text,
  selfpia_product_alias_matches_product_uid text,
  product_name_token_overlap text,
  product_name_group_match text,
  product_uid_group_row_count text,
  product_uid_group_matched_count text,
  product_uid_group_consistency_ratio text,
  product_uid_group_consistent text,
  channel_sku_code_duplicate_count text,
  score_gap_available text,
  score_gap_note text,
  reason text,
  diagnostic_label text,
  product_uid text,
  channel_sku_code text,
  sto_id_raw text,
  own_sku_code text,
  candidate_sku_count text,
  top1_candidate_sku_id text,
  top1_virtual_sku_code text,
  top1_option_value text,
  top1_product_name text,
  top1_selfpia_sku_aliases text,
  token_score text,
  opt_values text,
  makeshop_product_name text,
  barcode text,
  review_action_blank text
);

\copy stg_makeshop_weak_top1_strong_candidate FROM '/tmp/makeshop_weak_top1_strong_candidate.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

CREATE TEMP TABLE target_columns AS
SELECT c.ordinal_position, c.column_name, c.data_type, c.udt_name, c.is_nullable, c.column_default
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
    ('sku_id', 'c.top1_candidate_sku_id_uuid'),
    ('channel_code', '''makeshop''::text'),
    ('channel_sku_code', 'c.normalized_channel_sku_code'),
    ('seller_product_code', 'c.normalized_product_uid'),
    ('own_sku_code', 'c.own_sku_code'),
    ('is_primary', 'false'),
    ('raw_payload', 'c.raw_payload'),
    ('created_at', 'now()'),
    ('updated_at', 'now()')
) AS v(column_name, source_expression)
WHERE EXISTS (
  SELECT 1 FROM target_columns tc WHERE tc.column_name = v.column_name
);

CREATE TEMP TABLE source_normalized AS
SELECT
  row_number() OVER () AS source_row_id,
  s.*,
  NULLIF(btrim(s.product_uid), '') AS normalized_product_uid,
  NULLIF(btrim(s.channel_sku_code), '') AS normalized_channel_sku_code,
  NULLIF(btrim(s.top1_candidate_sku_id), '') AS normalized_top1_candidate_sku_id,
  CASE
    WHEN NULLIF(btrim(s.top1_candidate_sku_id), '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN NULLIF(btrim(s.top1_candidate_sku_id), '')::uuid
    ELSE NULL
  END AS top1_candidate_sku_id_uuid,
  lower(COALESCE(s.strong_candidate, '')) IN ('true', 't', '1', 'yes') AS strong_candidate_bool,
  lower(COALESCE(s.option_exact_match, '')) IN ('true', 't', '1', 'yes') AS option_exact_match_bool,
  lower(COALESCE(s.option_partial_match, '')) IN ('true', 't', '1', 'yes') AS option_partial_match_bool,
  lower(COALESCE(s.selfpia_option_no_matches_sto_id, '')) IN ('true', 't', '1', 'yes') AS option_no_matches_sto_id_bool,
  CASE WHEN NULLIF(btrim(s.token_score), '') ~ '^[0-9]+$' THEN NULLIF(btrim(s.token_score), '')::integer END AS token_score_int,
  CASE WHEN NULLIF(btrim(s.candidate_sku_count), '') ~ '^[0-9]+$' THEN NULLIF(btrim(s.candidate_sku_count), '')::integer END AS candidate_sku_count_int
FROM stg_makeshop_weak_top1_strong_candidate s;

CREATE TEMP TABLE source_duplicates AS
SELECT normalized_channel_sku_code AS channel_sku_code, COUNT(*) AS duplicate_rows
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
  CASE WHEN COUNT(DISTINCT sku_id) = 1 THEN (array_agg(DISTINCT sku_id))[1] ELSE NULL END AS single_existing_sku_id,
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
    'source', 'weak_top1_strong_candidate',
    'analysis_status', n.analysis_status,
    'strong_candidate_reason', n.strong_candidate_reason,
    'product_uid', n.product_uid,
    'sto_id_raw', n.sto_id_raw,
    'own_sku_code', n.own_sku_code,
    'candidate_sku_count', n.candidate_sku_count,
    'top1_candidate_sku_id', n.top1_candidate_sku_id,
    'top1_virtual_sku_code', n.top1_virtual_sku_code,
    'top1_option_value', n.top1_option_value,
    'top1_product_name', n.top1_product_name,
    'top1_selfpia_sku_aliases', n.top1_selfpia_sku_aliases,
    'token_score', n.token_score,
    'opt_values', n.opt_values,
    'makeshop_product_name', n.makeshop_product_name,
    'barcode', n.barcode,
    'option_exact_match', n.option_exact_match_bool,
    'option_partial_match', n.option_partial_match_bool,
    'selfpia_option_no_matches_sto_id', n.option_no_matches_sto_id_bool,
    'product_uid_group_consistency_ratio', n.product_uid_group_consistency_ratio,
    'product_uid_group_consistent', n.product_uid_group_consistent,
    'score_gap_available', n.score_gap_available,
    'score_gap_note', n.score_gap_note
  )) AS raw_payload,
  CASE
    WHEN n.normalized_channel_sku_code IS NULL THEN 'null_channel_sku_code'
    WHEN n.normalized_product_uid IS NULL THEN 'null_product_uid'
    WHEN n.normalized_top1_candidate_sku_id IS NULL THEN 'blank_top1_candidate_sku_id'
    WHEN n.top1_candidate_sku_id_uuid IS NULL THEN 'invalid_top1_candidate_sku_id_uuid'
    WHEN sm.id IS NULL THEN 'missing_sku_master'
    WHEN d.channel_sku_code IS NOT NULL THEN 'duplicate_source_channel_sku_code'
    WHEN existing.channel_sku_code IS NOT NULL
     AND existing.existing_distinct_sku_ids = 1
     AND existing.single_existing_sku_id IS NOT DISTINCT FROM n.top1_candidate_sku_id_uuid THEN 'idempotent_existing'
    WHEN existing.channel_sku_code IS NOT NULL THEN 'conflict_existing_different_sku'
    WHEN NOT n.strong_candidate_bool THEN 'not_strong_candidate'
    WHEN NOT n.option_no_matches_sto_id_bool THEN 'option_no_mismatch'
    WHEN NOT (n.option_partial_match_bool OR n.option_exact_match_bool) THEN 'option_text_mismatch'
    WHEN n.token_score_int < 70 OR n.token_score_int IS NULL THEN 'token_score_below_70'
    WHEN n.candidate_sku_count_int > 3 OR n.candidate_sku_count_int IS NULL THEN 'candidate_sku_count_above_3'
    ELSE 'insert_candidate'
  END AS dryrun_action
FROM source_normalized n
LEFT JOIN source_duplicates d ON d.channel_sku_code = n.normalized_channel_sku_code
LEFT JOIN product_code.sku_master sm ON sm.id = n.top1_candidate_sku_id_uuid
LEFT JOIN existing_makeshop_mapping existing ON existing.channel_sku_code = n.normalized_channel_sku_code;

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
\echo ===== [VALIDATE SUMMARY] =====
SELECT
  COUNT(*) AS source_rows,
  6389::integer AS expected_source_rows,
  COUNT(*) FILTER (WHERE dryrun_action = 'insert_candidate') AS insert_candidate_rows,
  COUNT(*) FILTER (WHERE dryrun_action = 'idempotent_existing') AS idempotent_existing_rows,
  COUNT(*) FILTER (WHERE dryrun_action = 'conflict_existing_different_sku') AS conflict_existing_different_sku_rows,
  COUNT(*) FILTER (WHERE dryrun_action = 'duplicate_source_channel_sku_code') AS duplicate_source_channel_sku_code_rows,
  COUNT(*) FILTER (WHERE dryrun_action IN ('blank_top1_candidate_sku_id', 'invalid_top1_candidate_sku_id_uuid', 'missing_sku_master')) AS missing_sku_rows,
  COUNT(*) FILTER (WHERE dryrun_action IN ('null_channel_sku_code', 'null_product_uid')) AS null_key_rows,
  COUNT(*) FILTER (WHERE dryrun_action IN ('not_strong_candidate', 'option_no_mismatch', 'option_text_mismatch', 'token_score_below_70', 'candidate_sku_count_above_3')) AS rule_violation_rows,
  CASE
    WHEN COUNT(*) = 6389
     AND COUNT(*) FILTER (WHERE dryrun_action = 'insert_candidate') = 6389
     AND COUNT(*) FILTER (WHERE dryrun_action <> 'insert_candidate') = 0
    THEN 'PASS'
    ELSE 'FAIL'
  END AS validation_verdict
FROM source_classified;

\echo
\echo ===== [TARGET COLUMN CHECK] =====
SELECT
  tc.ordinal_position,
  tc.column_name,
  tc.data_type,
  tc.is_nullable,
  CASE WHEN icp.used THEN true ELSE false END AS used_for_insert,
  icp.source_expression
FROM target_columns tc
LEFT JOIN insert_column_plan icp ON icp.column_name = tc.column_name
ORDER BY tc.ordinal_position;

\echo
\echo ===== [DUPLICATE CHECK] =====
SELECT channel_sku_code, duplicate_rows
FROM source_duplicates
ORDER BY duplicate_rows DESC, channel_sku_code
LIMIT 100;

\echo
\echo ===== [EXISTING MAPPING CHECK] =====
SELECT
  normalized_channel_sku_code AS channel_sku_code,
  normalized_product_uid AS product_uid,
  top1_candidate_sku_id_uuid AS would_insert_sku_id,
  existing_mapping_id,
  existing_mapped_sku_id,
  existing_sku_ids,
  dryrun_action
FROM source_classified
WHERE dryrun_action IN ('idempotent_existing', 'conflict_existing_different_sku')
ORDER BY dryrun_action, channel_sku_code
LIMIT 200;

\echo
\echo ===== [MISSING SKU CHECK] =====
SELECT
  normalized_channel_sku_code AS channel_sku_code,
  normalized_product_uid AS product_uid,
  normalized_top1_candidate_sku_id AS top1_candidate_sku_id,
  dryrun_action
FROM source_classified
WHERE dryrun_action IN ('blank_top1_candidate_sku_id', 'invalid_top1_candidate_sku_id_uuid', 'missing_sku_master')
ORDER BY dryrun_action, channel_sku_code
LIMIT 200;

\echo
\echo ===== [DRYRUN APPLY SUMMARY] =====
SELECT
  b.scm_before,
  b.makeshop_before,
  COUNT(*) AS source_rows,
  6389::integer AS expected_insert_candidates,
  COUNT(*) FILTER (WHERE dryrun_action = 'insert_candidate') AS insert_candidate_rows,
  COUNT(*) FILTER (WHERE dryrun_action = 'idempotent_existing') AS idempotent_existing_rows,
  COUNT(*) FILTER (WHERE dryrun_action = 'conflict_existing_different_sku') AS conflict_existing_different_sku_rows,
  COUNT(*) FILTER (WHERE dryrun_action = 'duplicate_source_channel_sku_code') AS duplicate_source_channel_sku_code_rows,
  COUNT(*) FILTER (WHERE dryrun_action IN ('blank_top1_candidate_sku_id', 'invalid_top1_candidate_sku_id_uuid', 'missing_sku_master')) AS missing_sku_rows,
  COUNT(*) FILTER (WHERE dryrun_action IN ('null_channel_sku_code', 'null_product_uid')) AS null_key_rows
FROM source_classified
CROSS JOIN dryrun_counts_before b
GROUP BY b.scm_before, b.makeshop_before;

\echo
\echo ===== [DRYRUN INSERT PREVIEW] =====
SELECT
  'makeshop'::text AS channel_code,
  normalized_product_uid AS seller_product_code,
  normalized_channel_sku_code AS channel_sku_code,
  own_sku_code,
  top1_candidate_sku_id_uuid AS sku_id,
  top1_virtual_sku_code,
  top1_option_value,
  top1_product_name,
  opt_values,
  makeshop_product_name,
  raw_payload
FROM source_classified
WHERE dryrun_action = 'insert_candidate'
ORDER BY normalized_product_uid, NULLIF(sto_id_raw, '')::integer, normalized_channel_sku_code
LIMIT 100;

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
  b.makeshop_before,
  (SELECT COUNT(*) FROM dryrun_inserted_keys) AS inserted_rows_inside_transaction,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping) AS scm_after_inside_transaction,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping) - b.scm_before AS delta_inside_transaction,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE channel_code = 'makeshop') AS makeshop_after_inside_transaction,
  ((SELECT COUNT(*) FROM product_code.sku_channel_mapping) - b.scm_before) = (SELECT COUNT(*) FROM dryrun_inserted_keys) AS expected_delta_matches
FROM dryrun_counts_before b;

\echo
\echo ===== [ROLLBACK CONFIRMATION] =====
\echo ROLLBACK is executed immediately after this section. No dryrun INSERT persists.

ROLLBACK;

\echo
\echo dryrun_apply_makeshop_weak_top1_strong_candidate.sql complete. ROLLBACK applied. No persistent DB changes.
