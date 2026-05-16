-- =============================================================================
-- apply_makeshop_weak_top1_strong_candidate.sql
--
-- REAL LOCAL APPLY for product_ops_test only.
-- LOCAL product_ops_test ONLY.
-- DO NOT run on Supabase, NAS PostgreSQL, or any remote/production database.
-- This script applies MakeShop weak_top1 strong_candidate rows only after all guards pass.
--
-- Inserts MakeShop weak_top1 strong_candidate rows into:
--   product_code.sku_channel_mapping
--
-- Source CSV inside Docker container:
--   /tmp/makeshop_weak_top1_strong_candidate.csv
--
-- Expected insert rows:
--   6389
--
-- Scope:
--   - channel_code is fixed to 'makeshop'
--   - only CSV rows that pass the strong_candidate rules are inserted
--   - review_required / ambiguous / manual review rows are rejected
--   - existing auto_confirm v3 rows must remain untouched
--
-- Backup / recovery note:
--   - This file performs real INSERTs and COMMITs if all checks pass.
--   - Take a local pg_dump or Docker volume snapshot before running.
--   - After COMMIT, rollback is not available through this script.
--   - Recovery requires restoring the local DB snapshot or deleting the exact
--     applied rows by the raw_payload source marker after separate approval.
--
-- Safety:
--   - product_ops_test guard prevents accidental operation DB execution.
--   - No persistent DDL. TEMP tables only for staging/checks.
--   - Any duplicate, conflict, null key, missing SKU, or rule violation aborts.
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'apply_makeshop_weak_top1_strong_candidate.sql is allowed only on local product_ops_test. Current database: %. Do not run on Supabase or NAS.',
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
  lower(COALESCE(s.review_action_blank, '')) IN ('', 'null') AS review_action_is_blank,
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
    'diagnostic_label', n.diagnostic_label,
    'review_reason', n.review_reason,
    'reason', n.reason,
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
    'score_gap_note', n.score_gap_note,
    'applied_by', 'apply_makeshop_weak_top1_strong_candidate.sql'
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
    WHEN n.analysis_status IS DISTINCT FROM 'strong_auto_candidate' THEN 'not_strong_auto_candidate'
    WHEN n.diagnostic_label IS DISTINCT FROM 'weak_unique_top1' THEN 'not_weak_unique_top1'
    WHEN NOT n.review_action_is_blank THEN 'manual_review_action_present'
    WHEN NOT n.option_no_matches_sto_id_bool THEN 'option_no_mismatch'
    WHEN NOT (n.option_partial_match_bool OR n.option_exact_match_bool) THEN 'option_text_mismatch'
    WHEN n.token_score_int < 70 OR n.token_score_int IS NULL THEN 'token_score_below_70'
    WHEN n.candidate_sku_count_int > 3 OR n.candidate_sku_count_int IS NULL THEN 'candidate_sku_count_above_3'
    ELSE 'insert_candidate'
  END AS apply_action
FROM source_normalized n
LEFT JOIN source_duplicates d ON d.channel_sku_code = n.normalized_channel_sku_code
LEFT JOIN product_code.sku_master sm ON sm.id = n.top1_candidate_sku_id_uuid
LEFT JOIN existing_makeshop_mapping existing ON existing.channel_sku_code = n.normalized_channel_sku_code;

CREATE TEMP TABLE apply_counts_before AS
SELECT
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping) AS scm_before,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE channel_code = 'makeshop') AS makeshop_before,
  (SELECT COUNT(*)
   FROM product_code.sku_channel_mapping
   WHERE channel_code = 'makeshop'
     AND raw_payload ->> 'source' = 'makeshop_auto_confirm_v3') AS auto_confirm_v3_before;

CREATE TEMP TABLE applied_keys (
  channel_code text,
  channel_sku_code text,
  sku_id uuid
);

\echo
\echo ===== [APPLY PRECHECK SUMMARY] =====
SELECT
  COUNT(*) AS source_rows,
  6389::integer AS expected_rows,
  COUNT(*) FILTER (WHERE apply_action = 'insert_candidate') AS insert_candidate_rows,
  COUNT(*) FILTER (WHERE apply_action = 'idempotent_existing') AS idempotent_existing_rows,
  COUNT(*) FILTER (WHERE apply_action = 'conflict_existing_different_sku') AS conflict_existing_different_sku_rows,
  COUNT(*) FILTER (WHERE apply_action = 'duplicate_source_channel_sku_code') AS duplicate_source_channel_sku_code_rows,
  COUNT(*) FILTER (WHERE apply_action IN ('blank_top1_candidate_sku_id', 'invalid_top1_candidate_sku_id_uuid', 'missing_sku_master')) AS missing_sku_rows,
  COUNT(*) FILTER (WHERE apply_action IN ('null_channel_sku_code', 'null_product_uid')) AS null_key_rows,
  COUNT(*) FILTER (WHERE apply_action IN ('not_strong_candidate', 'not_strong_auto_candidate', 'not_weak_unique_top1', 'manual_review_action_present', 'option_no_mismatch', 'option_text_mismatch', 'token_score_below_70', 'candidate_sku_count_above_3')) AS rule_violation_rows,
  (SELECT makeshop_before FROM apply_counts_before) AS makeshop_rows_before,
  (SELECT auto_confirm_v3_before FROM apply_counts_before) AS auto_confirm_v3_rows_before,
  CASE
    WHEN COUNT(*) = 6389
     AND COUNT(*) FILTER (WHERE apply_action = 'insert_candidate') = 6389
     AND COUNT(*) FILTER (WHERE apply_action <> 'insert_candidate') = 0
     AND (SELECT auto_confirm_v3_before FROM apply_counts_before) = 11179
    THEN 'PASS'
    ELSE 'FAIL'
  END AS apply_precheck_verdict
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
LEFT JOIN insert_column_plan icp ON icp.column_name = tc.column_name
ORDER BY tc.ordinal_position;

\echo
\echo ===== [APPLY BLOCKERS PREVIEW] =====
SELECT
  normalized_channel_sku_code AS channel_sku_code,
  normalized_product_uid AS product_uid,
  sto_id_raw,
  own_sku_code,
  top1_candidate_sku_id_uuid AS would_insert_sku_id,
  existing_mapping_id,
  existing_mapped_sku_id,
  apply_action
FROM source_classified
WHERE apply_action <> 'insert_candidate'
ORDER BY apply_action, normalized_product_uid, NULLIF(sto_id_raw, '')::integer NULLS LAST, normalized_channel_sku_code
LIMIT 200;

DO $$
DECLARE
  v_source_rows integer;
  v_insert_candidates integer;
  v_blockers integer;
  v_auto_confirm_before integer;
  v_cols text;
  v_exprs text;
  v_sql text;
BEGIN
  SELECT COUNT(*) INTO v_source_rows FROM source_classified;
  SELECT COUNT(*) INTO v_insert_candidates FROM source_classified WHERE apply_action = 'insert_candidate';
  SELECT COUNT(*) INTO v_blockers FROM source_classified WHERE apply_action <> 'insert_candidate';
  SELECT auto_confirm_v3_before INTO v_auto_confirm_before FROM apply_counts_before;

  IF v_source_rows <> 6389 THEN
    RAISE EXCEPTION 'Unexpected source rows: %, expected 6389', v_source_rows;
  END IF;

  IF v_insert_candidates <> 6389 THEN
    RAISE EXCEPTION 'Unexpected insert candidates: %, expected 6389', v_insert_candidates;
  END IF;

  IF v_blockers <> 0 THEN
    RAISE EXCEPTION 'Apply blockers found: % rows are not insert_candidate', v_blockers;
  END IF;

  IF v_auto_confirm_before <> 11179 THEN
    RAISE EXCEPTION 'Existing auto_confirm v3 rows mismatch before apply: %, expected 11179', v_auto_confirm_before;
  END IF;

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
       WHERE c.apply_action = %L
       RETURNING channel_code, channel_sku_code, sku_id
     )
     INSERT INTO applied_keys (channel_code, channel_sku_code, sku_id)
     SELECT channel_code, channel_sku_code, sku_id FROM ins',
    v_cols,
    v_exprs,
    'insert_candidate'
  );

  EXECUTE v_sql;
END
$$;

\echo
\echo ===== [APPLY POSTCHECK BEFORE COMMIT] =====
SELECT
  b.scm_before,
  b.makeshop_before,
  b.auto_confirm_v3_before,
  (SELECT COUNT(*) FROM applied_keys) AS inserted_rows,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping) AS scm_after,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping) - b.scm_before AS delta,
  (SELECT COUNT(*) FROM product_code.sku_channel_mapping WHERE channel_code = 'makeshop') AS makeshop_rows_after,
  (SELECT COUNT(*)
   FROM product_code.sku_channel_mapping
   WHERE channel_code = 'makeshop'
     AND raw_payload ->> 'source' = 'makeshop_auto_confirm_v3') AS auto_confirm_v3_after,
  (SELECT COUNT(*)
   FROM product_code.sku_channel_mapping
   WHERE channel_code = 'makeshop'
     AND raw_payload ->> 'source' = 'weak_top1_strong_candidate') AS weak_top1_rows_after,
  ((SELECT COUNT(*) FROM product_code.sku_channel_mapping) - b.scm_before) = 6389 AS expected_delta_matches
FROM apply_counts_before b;

DO $$
DECLARE
  v_inserted integer;
  v_delta integer;
  v_conflicts integer;
  v_duplicate_keys integer;
  v_auto_confirm_after integer;
  v_weak_top1_after integer;
BEGIN
  SELECT COUNT(*) INTO v_inserted FROM applied_keys;
  SELECT COUNT(*) INTO v_conflicts
  FROM product_code.sku_channel_mapping scm
  JOIN source_classified s
    ON scm.channel_code = 'makeshop'
   AND scm.channel_sku_code = s.normalized_channel_sku_code
   AND scm.sku_id IS DISTINCT FROM s.top1_candidate_sku_id_uuid;
  SELECT COUNT(*) INTO v_duplicate_keys
  FROM (
    SELECT channel_code, channel_sku_code
    FROM product_code.sku_channel_mapping
    WHERE channel_code = 'makeshop'
    GROUP BY channel_code, channel_sku_code
    HAVING COUNT(*) > 1
  ) d;
  SELECT COUNT(*) INTO v_auto_confirm_after
  FROM product_code.sku_channel_mapping
  WHERE channel_code = 'makeshop'
    AND raw_payload ->> 'source' = 'makeshop_auto_confirm_v3';
  SELECT COUNT(*) INTO v_weak_top1_after
  FROM product_code.sku_channel_mapping
  WHERE channel_code = 'makeshop'
    AND raw_payload ->> 'source' = 'weak_top1_strong_candidate';

  SELECT
    (SELECT COUNT(*) FROM product_code.sku_channel_mapping)
    - (SELECT scm_before FROM apply_counts_before)
  INTO v_delta;

  IF v_inserted <> 6389 THEN
    RAISE EXCEPTION 'Inserted rows mismatch: %, expected 6389', v_inserted;
  END IF;

  IF v_delta <> 6389 THEN
    RAISE EXCEPTION 'sku_channel_mapping delta mismatch: %, expected 6389', v_delta;
  END IF;

  IF v_conflicts <> 0 THEN
    RAISE EXCEPTION 'Post-insert conflict rows found: %', v_conflicts;
  END IF;

  IF v_duplicate_keys <> 0 THEN
    RAISE EXCEPTION 'Post-insert duplicate makeshop channel_sku_code keys found: %', v_duplicate_keys;
  END IF;

  IF v_auto_confirm_after <> 11179 THEN
    RAISE EXCEPTION 'auto_confirm v3 row count changed: %, expected 11179', v_auto_confirm_after;
  END IF;

  IF v_weak_top1_after <> 6389 THEN
    RAISE EXCEPTION 'weak_top1 applied marker count mismatch: %, expected 6389', v_weak_top1_after;
  END IF;
END
$$;

COMMIT;

\echo
\echo ===== [FINAL APPLY VERDICT] =====
SELECT
  'OVERALL PASS' AS verdict,
  6389::integer AS expected_inserted_rows,
  (SELECT COUNT(*) FROM applied_keys) AS inserted_rows,
  11179::integer AS expected_auto_confirm_v3_rows,
  (SELECT COUNT(*)
   FROM product_code.sku_channel_mapping
   WHERE channel_code = 'makeshop'
     AND raw_payload ->> 'source' = 'makeshop_auto_confirm_v3') AS auto_confirm_v3_rows,
  (SELECT COUNT(*)
   FROM product_code.sku_channel_mapping
   WHERE channel_code = 'makeshop'
     AND raw_payload ->> 'source' = 'weak_top1_strong_candidate') AS weak_top1_rows,
  'COMMIT applied on local product_ops_test only' AS note;

\echo
\echo apply_makeshop_weak_top1_strong_candidate.sql complete. COMMIT applied. This was a real local product_ops_test DB change.
