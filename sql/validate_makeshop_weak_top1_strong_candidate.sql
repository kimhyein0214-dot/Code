-- =============================================================================
-- validate_makeshop_weak_top1_strong_candidate.sql
--
-- Validate CSV-only weak_top1 strong candidates before any dryrun/apply design.
--
-- Input CSV inside Docker container:
--   /tmp/makeshop_weak_top1_strong_candidate.csv
--
-- Safety:
--   - product_ops_test guard
--   - BEGIN / ROLLBACK
--   - TEMP TABLE only
--   - SELECT validation only
--   - no persistent INSERT/UPDATE/DELETE/ALTER/DROP/TRUNCATE
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'validate_makeshop_weak_top1_strong_candidate.sql is allowed only on product_ops_test. Current database: %',
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
  CASE WHEN NULLIF(btrim(s.candidate_sku_count), '') ~ '^[0-9]+$' THEN NULLIF(btrim(s.candidate_sku_count), '')::integer END AS candidate_sku_count_int,
  CASE WHEN NULLIF(btrim(s.channel_sku_code_duplicate_count), '') ~ '^[0-9]+$' THEN NULLIF(btrim(s.channel_sku_code_duplicate_count), '')::integer END AS channel_sku_code_duplicate_count_int
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
  sm.id AS sku_master_id,
  d.duplicate_rows,
  existing.sample_existing_mapping_id,
  existing.single_existing_sku_id AS existing_mapped_sku_id,
  existing.existing_sku_ids,
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
    ELSE 'clean_insert_candidate'
  END AS validation_action
FROM source_normalized n
LEFT JOIN source_duplicates d ON d.channel_sku_code = n.normalized_channel_sku_code
LEFT JOIN product_code.sku_master sm ON sm.id = n.top1_candidate_sku_id_uuid
LEFT JOIN existing_makeshop_mapping existing ON existing.channel_sku_code = n.normalized_channel_sku_code;

\echo
\echo ===== [VALIDATE SUMMARY] =====
WITH counts AS (
  SELECT
    COUNT(*) AS source_rows,
    COUNT(*) FILTER (WHERE normalized_channel_sku_code IS NULL) AS blank_channel_sku_code_rows,
    COUNT(*) FILTER (WHERE normalized_product_uid IS NULL) AS blank_product_uid_rows,
    COUNT(*) FILTER (WHERE normalized_top1_candidate_sku_id IS NULL) AS blank_top1_candidate_sku_id_rows,
    COUNT(*) FILTER (WHERE top1_candidate_sku_id_uuid IS NULL) AS invalid_top1_candidate_sku_id_uuid_rows,
    COUNT(*) FILTER (WHERE sku_master_id IS NULL) AS missing_sku_master_rows,
    COUNT(*) FILTER (WHERE duplicate_rows IS NOT NULL) AS duplicate_channel_sku_code_rows,
    COUNT(*) FILTER (WHERE validation_action = 'idempotent_existing') AS idempotent_existing_rows,
    COUNT(*) FILTER (WHERE validation_action = 'conflict_existing_different_sku') AS conflict_existing_different_sku_rows,
    COUNT(*) FILTER (WHERE validation_action IN ('idempotent_existing', 'conflict_existing_different_sku')) AS already_existing_rows,
    COUNT(*) FILTER (WHERE NOT option_no_matches_sto_id_bool) AS selfpia_option_no_mismatch_rows,
    COUNT(*) FILTER (WHERE NOT (option_partial_match_bool OR option_exact_match_bool)) AS option_match_false_rows,
    COUNT(*) FILTER (WHERE token_score_int < 70 OR token_score_int IS NULL) AS token_score_below_70_rows,
    COUNT(*) FILTER (WHERE candidate_sku_count_int > 3 OR candidate_sku_count_int IS NULL) AS candidate_sku_count_above_3_rows,
    COUNT(*) FILTER (WHERE validation_action = 'clean_insert_candidate') AS clean_insert_candidate_rows
  FROM source_classified
)
SELECT
  *,
  CASE
    WHEN source_rows = 6389
     AND blank_channel_sku_code_rows = 0
     AND blank_product_uid_rows = 0
     AND blank_top1_candidate_sku_id_rows = 0
     AND invalid_top1_candidate_sku_id_uuid_rows = 0
     AND missing_sku_master_rows = 0
     AND duplicate_channel_sku_code_rows = 0
     AND already_existing_rows = 0
     AND conflict_existing_different_sku_rows = 0
     AND selfpia_option_no_mismatch_rows = 0
     AND option_match_false_rows = 0
     AND token_score_below_70_rows = 0
     AND candidate_sku_count_above_3_rows = 0
     AND clean_insert_candidate_rows = 6389
    THEN 'PASS'
    ELSE 'FAIL'
  END AS validation_verdict
FROM counts;

\echo
\echo ===== [TARGET COLUMN CHECK] =====
SELECT
  tc.ordinal_position,
  tc.column_name,
  tc.data_type,
  tc.is_nullable,
  CASE
    WHEN tc.column_name IN ('sku_id', 'channel_code', 'channel_sku_code') THEN 'required'
    WHEN tc.column_name IN ('seller_product_code', 'own_sku_code', 'is_primary', 'raw_payload', 'created_at', 'updated_at') THEN 'optional_used_if_present'
    ELSE 'not_used'
  END AS dryrun_insert_plan
FROM target_columns tc
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
  top1_candidate_sku_id_uuid AS source_sku_id,
  sample_existing_mapping_id,
  existing_mapped_sku_id,
  existing_sku_ids,
  validation_action
FROM source_classified
WHERE validation_action IN ('idempotent_existing', 'conflict_existing_different_sku')
ORDER BY validation_action, channel_sku_code
LIMIT 200;

\echo
\echo ===== [MISSING SKU CHECK] =====
SELECT
  normalized_channel_sku_code AS channel_sku_code,
  normalized_product_uid AS product_uid,
  normalized_top1_candidate_sku_id AS top1_candidate_sku_id,
  validation_action
FROM source_classified
WHERE validation_action IN ('blank_top1_candidate_sku_id', 'invalid_top1_candidate_sku_id_uuid', 'missing_sku_master')
ORDER BY validation_action, channel_sku_code
LIMIT 200;

\echo
\echo ===== [VALIDATION FAILURE SAMPLE] =====
SELECT
  source_row_id,
  normalized_channel_sku_code AS channel_sku_code,
  normalized_product_uid AS product_uid,
  sto_id_raw,
  own_sku_code,
  top1_candidate_sku_id,
  token_score,
  candidate_sku_count,
  option_exact_match,
  option_partial_match,
  selfpia_option_no_matches_sto_id,
  validation_action
FROM source_classified
WHERE validation_action <> 'clean_insert_candidate'
ORDER BY validation_action, source_row_id
LIMIT 200;

ROLLBACK;

\echo
\echo validate_makeshop_weak_top1_strong_candidate.sql complete. ROLLBACK applied. No persistent DB changes.
