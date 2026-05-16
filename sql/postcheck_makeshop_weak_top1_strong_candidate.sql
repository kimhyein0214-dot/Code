-- =============================================================================
-- postcheck_makeshop_weak_top1_strong_candidate.sql
--
-- Read-only postcheck after running apply_makeshop_weak_top1_strong_candidate.sql.
--
-- local product_ops_test only.
-- LOCAL product_ops_test ONLY.
-- DO NOT run on Supabase, NAS PostgreSQL, or any remote/production database.
-- This script verifies the MakeShop weak_top1 local apply result without persistent changes.
--
-- Source CSV inside Docker container:
--   /tmp/makeshop_weak_top1_strong_candidate.csv
--
-- Target:
--   product_code.sku_channel_mapping
--
-- Expected state:
--   - weak_top1 strong_candidate applied rows: 6389
--   - existing auto_confirm v3 rows remain: 11179
--   - no duplicate/conflict/null key/missing SKU
--
-- Backup / recovery note:
--   - This postcheck is read-only and ends with ROLLBACK.
--   - It does not create backups.
--   - Before actual apply, keep a local pg_dump or Docker volume snapshot.
--   - After apply COMMIT, recovery requires local DB restore or a separately
--     approved cleanup using the raw_payload source marker.
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'postcheck_makeshop_weak_top1_strong_candidate.sql is allowed only on local product_ops_test. Current database: %. Do not run on Supabase or NAS.',
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

CREATE TEMP TABLE postcheck_counts AS
SELECT
  (SELECT COUNT(*) FROM source_normalized) AS source_rows,
  (SELECT COUNT(*)
   FROM source_normalized
   WHERE normalized_channel_sku_code IS NULL
      OR normalized_product_uid IS NULL
      OR top1_candidate_sku_id_uuid IS NULL) AS source_null_key_or_missing_sku_rows,
  (SELECT COUNT(*)
   FROM source_normalized s
   LEFT JOIN product_code.sku_master sm ON sm.id = s.top1_candidate_sku_id_uuid
   WHERE sm.id IS NULL) AS fk_missing_sku_rows,
  (SELECT COUNT(*)
   FROM source_normalized
   WHERE NOT strong_candidate_bool
      OR analysis_status IS DISTINCT FROM 'strong_auto_candidate'
      OR diagnostic_label IS DISTINCT FROM 'weak_unique_top1'
      OR NOT review_action_is_blank
      OR NOT option_no_matches_sto_id_bool
      OR NOT (option_partial_match_bool OR option_exact_match_bool)
      OR token_score_int < 70 OR token_score_int IS NULL
      OR candidate_sku_count_int > 3 OR candidate_sku_count_int IS NULL) AS source_rule_violation_rows,
  (SELECT COUNT(*)
   FROM (
     SELECT normalized_channel_sku_code
     FROM source_normalized
     WHERE normalized_channel_sku_code IS NOT NULL
     GROUP BY normalized_channel_sku_code
     HAVING COUNT(*) > 1
   ) d) AS source_duplicate_channel_sku_code_keys,
  (SELECT COUNT(*)
   FROM product_code.sku_channel_mapping
   WHERE channel_code = 'makeshop'
     AND raw_payload ->> 'source' = 'makeshop_auto_confirm_v3') AS auto_confirm_v3_rows,
  (SELECT COUNT(*)
   FROM product_code.sku_channel_mapping
   WHERE channel_code = 'makeshop'
     AND raw_payload ->> 'source' = 'weak_top1_strong_candidate') AS weak_top1_applied_rows,
  (SELECT COUNT(*)
   FROM source_normalized s
   JOIN product_code.sku_channel_mapping scm
     ON scm.channel_code = 'makeshop'
    AND scm.channel_sku_code = s.normalized_channel_sku_code
    AND scm.sku_id = s.top1_candidate_sku_id_uuid
    AND scm.raw_payload ->> 'source' = 'weak_top1_strong_candidate') AS matched_source_rows,
  (SELECT COUNT(*)
   FROM source_normalized s
   LEFT JOIN product_code.sku_channel_mapping scm
     ON scm.channel_code = 'makeshop'
    AND scm.channel_sku_code = s.normalized_channel_sku_code
    AND scm.sku_id = s.top1_candidate_sku_id_uuid
    AND scm.raw_payload ->> 'source' = 'weak_top1_strong_candidate'
   WHERE scm.id IS NULL) AS missing_mapping_rows,
  (SELECT COUNT(*)
   FROM source_normalized s
   JOIN product_code.sku_channel_mapping scm
     ON scm.channel_code = 'makeshop'
    AND scm.channel_sku_code = s.normalized_channel_sku_code
    AND scm.sku_id IS DISTINCT FROM s.top1_candidate_sku_id_uuid) AS conflict_rows,
  (SELECT COUNT(*)
   FROM (
     SELECT channel_code, channel_sku_code
     FROM product_code.sku_channel_mapping
     WHERE channel_code = 'makeshop'
     GROUP BY channel_code, channel_sku_code
     HAVING COUNT(*) > 1
   ) d) AS duplicate_channel_sku_code_keys,
  (SELECT COUNT(*)
   FROM product_code.sku_channel_mapping
   WHERE channel_code IS DISTINCT FROM 'makeshop'
     AND raw_payload ->> 'source' = 'weak_top1_strong_candidate') AS non_makeshop_weak_top1_rows,
  (SELECT COUNT(*)
   FROM product_code.sku_channel_mapping scm
   LEFT JOIN product_code.sku_master sm ON sm.id = scm.sku_id
   WHERE scm.channel_code = 'makeshop'
     AND scm.raw_payload ->> 'source' = 'weak_top1_strong_candidate'
     AND sm.id IS NULL) AS applied_fk_missing_sku_rows,
  (SELECT COUNT(*)
   FROM product_code.sku_channel_mapping
   WHERE channel_code = 'makeshop'
     AND raw_payload ->> 'source' = 'weak_top1_strong_candidate'
     AND (
       raw_payload ->> 'analysis_status' IS DISTINCT FROM 'strong_auto_candidate'
       OR raw_payload ->> 'diagnostic_label' IS DISTINCT FROM 'weak_unique_top1'
     )) AS apply_marker_status_mismatch_rows,
  (SELECT COUNT(*)
   FROM product_code.sku_channel_mapping
   WHERE channel_code = 'makeshop'
     AND raw_payload ->> 'source' = 'weak_top1_strong_candidate'
     AND COALESCE(raw_payload ->> 'review_reason', '') NOT IN ('', 'own_sku_ambiguous')) AS unexpected_review_reason_rows;

\echo
\echo ===== [POSTCHECK MAKESHOP WEAK_TOP1 SUMMARY] =====
SELECT
  source_rows,
  6389::integer AS expected_source_rows,
  weak_top1_applied_rows,
  6389::integer AS expected_weak_top1_applied_rows,
  matched_source_rows,
  missing_mapping_rows,
  conflict_rows,
  duplicate_channel_sku_code_keys,
  source_duplicate_channel_sku_code_keys,
  source_null_key_or_missing_sku_rows,
  fk_missing_sku_rows,
  applied_fk_missing_sku_rows,
  source_rule_violation_rows,
  non_makeshop_weak_top1_rows,
  apply_marker_status_mismatch_rows,
  unexpected_review_reason_rows,
  auto_confirm_v3_rows,
  11179::integer AS expected_auto_confirm_v3_rows
FROM postcheck_counts;

\echo
\echo ===== [POSTCHECK DUPLICATE MAKESHOP KEYS] =====
SELECT
  channel_code,
  channel_sku_code,
  COUNT(*) AS rows,
  array_agg(sku_id ORDER BY sku_id) AS sku_ids
FROM product_code.sku_channel_mapping
WHERE channel_code = 'makeshop'
GROUP BY channel_code, channel_sku_code
HAVING COUNT(*) > 1
ORDER BY rows DESC, channel_sku_code
LIMIT 100;

\echo
\echo ===== [POSTCHECK CONFLICT SAMPLE] =====
SELECT
  s.normalized_channel_sku_code AS channel_sku_code,
  s.normalized_product_uid AS product_uid,
  s.sto_id_raw,
  s.own_sku_code,
  s.top1_candidate_sku_id_uuid AS expected_sku_id,
  scm.id AS existing_mapping_id,
  scm.sku_id AS mapped_sku_id,
  scm.raw_payload ->> 'source' AS mapped_source
FROM source_normalized s
JOIN product_code.sku_channel_mapping scm
  ON scm.channel_code = 'makeshop'
 AND scm.channel_sku_code = s.normalized_channel_sku_code
 AND scm.sku_id IS DISTINCT FROM s.top1_candidate_sku_id_uuid
ORDER BY s.normalized_product_uid, NULLIF(s.sto_id_raw, '')::integer NULLS LAST
LIMIT 100;

\echo
\echo ===== [POSTCHECK MISSING SAMPLE] =====
SELECT
  s.normalized_channel_sku_code AS channel_sku_code,
  s.normalized_product_uid AS product_uid,
  s.sto_id_raw,
  s.own_sku_code,
  s.top1_candidate_sku_id_uuid AS expected_sku_id
FROM source_normalized s
LEFT JOIN product_code.sku_channel_mapping scm
  ON scm.channel_code = 'makeshop'
 AND scm.channel_sku_code = s.normalized_channel_sku_code
 AND scm.sku_id = s.top1_candidate_sku_id_uuid
 AND scm.raw_payload ->> 'source' = 'weak_top1_strong_candidate'
WHERE scm.id IS NULL
ORDER BY s.normalized_product_uid, NULLIF(s.sto_id_raw, '')::integer NULLS LAST
LIMIT 100;

\echo
\echo ===== [POSTCHECK FINAL VERDICT] =====
SELECT
  CASE
    WHEN source_rows = 6389
     AND weak_top1_applied_rows = 6389
     AND matched_source_rows = 6389
     AND missing_mapping_rows = 0
     AND conflict_rows = 0
     AND duplicate_channel_sku_code_keys = 0
     AND source_duplicate_channel_sku_code_keys = 0
     AND source_null_key_or_missing_sku_rows = 0
     AND fk_missing_sku_rows = 0
     AND applied_fk_missing_sku_rows = 0
     AND source_rule_violation_rows = 0
     AND non_makeshop_weak_top1_rows = 0
     AND apply_marker_status_mismatch_rows = 0
     AND unexpected_review_reason_rows = 0
     AND auto_confirm_v3_rows = 11179
    THEN 'OVERALL PASS'
    ELSE 'OVERALL FAIL'
  END AS verdict,
  source_rows,
  weak_top1_applied_rows,
  matched_source_rows,
  auto_confirm_v3_rows,
  missing_mapping_rows,
  conflict_rows,
  duplicate_channel_sku_code_keys,
  source_null_key_or_missing_sku_rows,
  fk_missing_sku_rows,
  source_rule_violation_rows,
  non_makeshop_weak_top1_rows,
  apply_marker_status_mismatch_rows,
  unexpected_review_reason_rows
FROM postcheck_counts;

ROLLBACK;

\echo
\echo postcheck_makeshop_weak_top1_strong_candidate.sql complete. Read-only postcheck finished. No persistent DB changes.
