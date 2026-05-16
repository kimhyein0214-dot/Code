-- =============================================================================
-- dryrun_makeshop_select_only_v3.sql
--
-- SELECT-only MakeShop mapping dryrun v3.
--
-- v3 priority:
--   1. sto_code, when nonblank
--   2. opt_values existing bracket
--   3. opt_values 4-part bracket
--   4. opt_value existing bracket
--   5. opt_value 4-part bracket
--   6. loose 4-part regex is diagnostic-only
--
-- Safety:
--   - product_ops_test guard
--   - TEMP TABLE only
--   - SELECT / \copy only
--   - BEGIN ... ROLLBACK
--   - No persistent DB changes
--
-- CSV input path inside Docker container:
--   /tmp/makeshop_minimal_full.csv
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'dryrun v3 is allowed only on product_ops_test. Current database: %',
      current_database();
  END IF;
END
$$;

BEGIN;

CREATE TEMP TABLE mk_src (
  product_uid   text,
  sto_id        text,
  sto_code      text,
  opt_value     text,
  opt_values    text,
  barcode       text,
  product_name  text,
  status        text,
  gid           text,
  ps_num        text
);

\copy mk_src FROM '/tmp/makeshop_minimal_full.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

CREATE TEMP TABLE mk_extracted AS
WITH base AS (
  SELECT
    row_number() OVER () AS mk_row_id,
    s.product_uid,
    s.sto_id,
    s.sto_code,
    s.opt_value,
    s.opt_values,
    s.barcode,
    s.product_name,
    s.status AS source_status,
    substring(s.opt_value  FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') AS opt_value_existing_bracket,
    substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') AS opt_values_existing_bracket,
    substring(s.opt_value  FROM '\[([A-Za-z]+-[0-9]+-[0-9]+-[0-9]+)\]') AS opt_value_4part_bracket,
    substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+-[0-9]+)\]') AS opt_values_4part_bracket,
    substring(COALESCE(s.opt_value, '') || ' ' || COALESCE(s.opt_values, '')
              FROM '([A-Za-z]+-[0-9]+-[0-9]+-[0-9]+)') AS loose_4part_candidate
  FROM mk_src s
)
SELECT
  b.*,
  COALESCE(b.opt_value_existing_bracket, b.opt_value_4part_bracket) AS opt_value_any_bracket,
  COALESCE(b.opt_values_existing_bracket, b.opt_values_4part_bracket) AS opt_values_any_bracket,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> '' THEN btrim(b.sto_code)
    WHEN b.opt_value_existing_bracket IS NOT NULL THEN b.opt_value_existing_bracket
    WHEN b.opt_values_existing_bracket IS NOT NULL THEN b.opt_values_existing_bracket
    WHEN b.opt_value_4part_bracket IS NOT NULL THEN b.opt_value_4part_bracket
    WHEN b.opt_values_4part_bracket IS NOT NULL THEN b.opt_values_4part_bracket
    ELSE NULL
  END AS v2_own_sku_candidate,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> '' THEN 'sto_code'
    WHEN b.opt_value_existing_bracket IS NOT NULL THEN 'opt_value_bracket'
    WHEN b.opt_values_existing_bracket IS NOT NULL THEN 'opt_values_bracket'
    WHEN b.opt_value_4part_bracket IS NOT NULL THEN 'opt_value_4part_bracket'
    WHEN b.opt_values_4part_bracket IS NOT NULL THEN 'opt_values_4part_bracket'
    ELSE NULL
  END AS v2_extraction_method,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> '' THEN 'sto_code_exact'
    WHEN b.opt_value_existing_bracket IS NOT NULL THEN 'existing_bracket'
    WHEN b.opt_values_existing_bracket IS NOT NULL THEN 'existing_bracket'
    WHEN b.opt_value_4part_bracket IS NOT NULL THEN 'bracket_4part'
    WHEN b.opt_values_4part_bracket IS NOT NULL THEN 'bracket_4part'
    ELSE NULL
  END AS v2_regex_pattern_used,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> '' THEN 'existing'
    WHEN b.opt_value_existing_bracket IS NOT NULL THEN 'existing'
    WHEN b.opt_values_existing_bracket IS NOT NULL THEN 'existing'
    WHEN b.opt_value_4part_bracket IS NOT NULL THEN 'new_regex'
    WHEN b.opt_values_4part_bracket IS NOT NULL THEN 'new_regex'
    ELSE NULL
  END AS v2_extraction_family,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> '' THEN btrim(b.sto_code)
    WHEN b.opt_values_existing_bracket IS NOT NULL THEN b.opt_values_existing_bracket
    WHEN b.opt_values_4part_bracket IS NOT NULL THEN b.opt_values_4part_bracket
    WHEN b.opt_value_existing_bracket IS NOT NULL THEN b.opt_value_existing_bracket
    WHEN b.opt_value_4part_bracket IS NOT NULL THEN b.opt_value_4part_bracket
    ELSE NULL
  END AS own_sku_candidate,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> '' THEN 'sto_code'
    WHEN b.opt_values_existing_bracket IS NOT NULL THEN 'opt_values_bracket'
    WHEN b.opt_values_4part_bracket IS NOT NULL THEN 'opt_values_4part_bracket'
    WHEN b.opt_value_existing_bracket IS NOT NULL THEN 'opt_value_bracket'
    WHEN b.opt_value_4part_bracket IS NOT NULL THEN 'opt_value_4part_bracket'
    ELSE NULL
  END AS extraction_method,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> '' THEN 'sto_code_exact'
    WHEN b.opt_values_existing_bracket IS NOT NULL THEN 'existing_bracket'
    WHEN b.opt_values_4part_bracket IS NOT NULL THEN 'bracket_4part'
    WHEN b.opt_value_existing_bracket IS NOT NULL THEN 'existing_bracket'
    WHEN b.opt_value_4part_bracket IS NOT NULL THEN 'bracket_4part'
    ELSE NULL
  END AS regex_pattern_used,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> '' THEN 'existing'
    WHEN b.opt_values_existing_bracket IS NOT NULL THEN 'existing'
    WHEN b.opt_values_4part_bracket IS NOT NULL THEN 'new_regex'
    WHEN b.opt_value_existing_bracket IS NOT NULL THEN 'existing'
    WHEN b.opt_value_4part_bracket IS NOT NULL THEN 'new_regex'
    ELSE NULL
  END AS extraction_family,
  CASE
    WHEN b.product_uid IS NOT NULL AND btrim(b.product_uid) <> ''
     AND b.sto_id IS NOT NULL AND btrim(b.sto_id) <> ''
      THEN btrim(b.product_uid) || '-' || btrim(b.sto_id)
    ELSE NULL
  END AS channel_sku_code,
  CASE
    WHEN b.loose_4part_candidate IS NOT NULL
     AND b.opt_value_4part_bracket IS NULL
     AND b.opt_values_4part_bracket IS NULL
     AND b.opt_value_existing_bracket IS NULL
     AND b.opt_values_existing_bracket IS NULL
     AND (b.sto_code IS NULL OR btrim(b.sto_code) = '')
      THEN true
    ELSE false
  END AS loose_regex_only_flag
FROM base b;

CREATE TEMP TABLE mk_match_v2 AS
SELECT
  e.*,
  COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) AS v2_match_count,
  CASE
    WHEN COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) = 1
      THEN (array_agg(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL))[1]
    ELSE NULL
  END AS v2_resolved_sku_id
FROM mk_extracted e
LEFT JOIN product_code.code_alias ca
  ON ca.target_type = 'SKU'
 AND ca.code_system = 'own_sku'
 AND ca.code_value = e.v2_own_sku_candidate
 AND e.v2_own_sku_candidate IS NOT NULL
 AND btrim(e.v2_own_sku_candidate) <> ''
GROUP BY
  e.mk_row_id, e.product_uid, e.sto_id, e.sto_code, e.opt_value, e.opt_values,
  e.barcode, e.product_name, e.source_status, e.opt_value_existing_bracket,
  e.opt_values_existing_bracket, e.opt_value_4part_bracket,
  e.opt_values_4part_bracket, e.loose_4part_candidate, e.opt_value_any_bracket,
  e.opt_values_any_bracket, e.v2_own_sku_candidate, e.v2_extraction_method,
  e.v2_regex_pattern_used, e.v2_extraction_family, e.own_sku_candidate,
  e.extraction_method, e.regex_pattern_used, e.extraction_family,
  e.channel_sku_code, e.loose_regex_only_flag;

CREATE TEMP TABLE mk_classified_v2 AS
SELECT
  m.mk_row_id,
  m.v2_own_sku_candidate,
  m.v2_extraction_method,
  m.v2_regex_pattern_used,
  m.v2_extraction_family,
  m.v2_match_count,
  m.v2_resolved_sku_id,
  scm.id AS v2_existing_mapping_id,
  sm.status AS v2_sku_master_status,
  CASE
    WHEN m.product_uid IS NULL OR btrim(m.product_uid) = ''
      OR m.sto_id IS NULL OR btrim(m.sto_id) = '' THEN 'review_null_key'
    WHEN m.v2_own_sku_candidate IS NULL OR btrim(m.v2_own_sku_candidate) = '' THEN
      CASE WHEN m.loose_regex_only_flag THEN 'review_loose_regex_only' ELSE 'review_pattern_unmatched' END
    WHEN m.v2_match_count = 0 THEN 'review_not_in_alias'
    WHEN m.v2_match_count > 1 THEN 'review_ambiguous'
    WHEN scm.id IS NOT NULL THEN 'channel_sku_conflict'
    WHEN sm.status IS NOT NULL
     AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%') THEN 'sku_inactive'
    ELSE NULL
  END AS v2_review_reason,
  CASE
    WHEN m.product_uid IS NOT NULL AND btrim(m.product_uid) <> ''
     AND m.sto_id IS NOT NULL AND btrim(m.sto_id) <> ''
     AND m.v2_own_sku_candidate IS NOT NULL AND btrim(m.v2_own_sku_candidate) <> ''
     AND m.v2_match_count = 1
     AND scm.id IS NULL
     AND NOT (
       sm.status IS NOT NULL
       AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%')
     )
     AND m.v2_extraction_family = 'existing' THEN 'auto_confirm_existing_regex'
    WHEN m.product_uid IS NOT NULL AND btrim(m.product_uid) <> ''
     AND m.sto_id IS NOT NULL AND btrim(m.sto_id) <> ''
     AND m.v2_own_sku_candidate IS NOT NULL AND btrim(m.v2_own_sku_candidate) <> ''
     AND m.v2_match_count = 1
     AND scm.id IS NULL
     AND NOT (
       sm.status IS NOT NULL
       AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%')
     )
     AND m.v2_extraction_family = 'new_regex' THEN 'auto_confirm_new_regex_candidate'
    ELSE 'review_required'
  END AS v2_classification
FROM mk_match_v2 m
LEFT JOIN product_code.sku_channel_mapping scm
  ON scm.channel_code = 'makeshop'
 AND scm.channel_sku_code = m.channel_sku_code
 AND m.channel_sku_code IS NOT NULL
LEFT JOIN product_code.sku_master sm
  ON sm.id = m.v2_resolved_sku_id;

CREATE TEMP TABLE mk_match_v3 AS
SELECT
  e.*,
  v2.v2_match_count,
  v2.v2_resolved_sku_id,
  v2.v2_review_reason,
  v2.v2_classification,
  COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) AS match_count,
  array_agg(DISTINCT ca.target_id ORDER BY ca.target_id)
    FILTER (WHERE ca.target_id IS NOT NULL) AS candidate_sku_ids,
  CASE
    WHEN COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) = 1
      THEN (array_agg(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL))[1]
    ELSE NULL
  END AS resolved_sku_id
FROM mk_extracted e
JOIN mk_classified_v2 v2
  ON v2.mk_row_id = e.mk_row_id
LEFT JOIN product_code.code_alias ca
  ON ca.target_type = 'SKU'
 AND ca.code_system = 'own_sku'
 AND ca.code_value = e.own_sku_candidate
 AND e.own_sku_candidate IS NOT NULL
 AND btrim(e.own_sku_candidate) <> ''
GROUP BY
  e.mk_row_id, e.product_uid, e.sto_id, e.sto_code, e.opt_value, e.opt_values,
  e.barcode, e.product_name, e.source_status, e.opt_value_existing_bracket,
  e.opt_values_existing_bracket, e.opt_value_4part_bracket,
  e.opt_values_4part_bracket, e.loose_4part_candidate, e.opt_value_any_bracket,
  e.opt_values_any_bracket, e.v2_own_sku_candidate, e.v2_extraction_method,
  e.v2_regex_pattern_used, e.v2_extraction_family, e.own_sku_candidate,
  e.extraction_method, e.regex_pattern_used, e.extraction_family,
  e.channel_sku_code, e.loose_regex_only_flag, v2.v2_match_count,
  v2.v2_resolved_sku_id, v2.v2_review_reason, v2.v2_classification;

CREATE TEMP TABLE mk_classified_base AS
SELECT
  m.*,
  scm.id AS existing_mapping_id,
  scm.sku_id AS existing_mapped_sku_id,
  scm.is_primary AS existing_is_primary,
  sm.status AS sku_master_status,
  CASE
    WHEN m.product_uid IS NULL OR btrim(m.product_uid) = ''
      OR m.sto_id IS NULL OR btrim(m.sto_id) = '' THEN 'review_null_key'
    WHEN m.own_sku_candidate IS NULL OR btrim(m.own_sku_candidate) = '' THEN
      CASE WHEN m.loose_regex_only_flag THEN 'review_loose_regex_only' ELSE 'review_pattern_unmatched' END
    WHEN m.match_count = 0 THEN 'review_not_in_alias'
    WHEN m.match_count > 1 THEN 'review_ambiguous'
    WHEN scm.id IS NOT NULL THEN 'channel_sku_conflict'
    WHEN sm.status IS NOT NULL
     AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%') THEN 'sku_inactive'
    ELSE NULL
  END AS review_reason,
  CASE
    WHEN m.product_uid IS NOT NULL AND btrim(m.product_uid) <> ''
     AND m.sto_id IS NOT NULL AND btrim(m.sto_id) <> ''
     AND m.own_sku_candidate IS NOT NULL AND btrim(m.own_sku_candidate) <> ''
     AND m.match_count = 1
     AND scm.id IS NULL
     AND NOT (
       sm.status IS NOT NULL
       AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%')
     )
     AND m.extraction_family = 'existing' THEN 'auto_confirm_existing_regex'
    WHEN m.product_uid IS NOT NULL AND btrim(m.product_uid) <> ''
     AND m.sto_id IS NOT NULL AND btrim(m.sto_id) <> ''
     AND m.own_sku_candidate IS NOT NULL AND btrim(m.own_sku_candidate) <> ''
     AND m.match_count = 1
     AND scm.id IS NULL
     AND NOT (
       sm.status IS NOT NULL
       AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%')
     )
     AND m.extraction_family = 'new_regex' THEN 'auto_confirm_new_regex_candidate'
    ELSE 'review_required'
  END AS classification
FROM mk_match_v3 m
LEFT JOIN product_code.sku_channel_mapping scm
  ON scm.channel_code = 'makeshop'
 AND scm.channel_sku_code = m.channel_sku_code
 AND m.channel_sku_code IS NOT NULL
LEFT JOIN product_code.sku_master sm
  ON sm.id = m.resolved_sku_id;

CREATE TEMP TABLE auto_existing_repeat_stats AS
SELECT
  resolved_sku_id,
  own_sku_candidate,
  COUNT(*) AS repeated_matched_sku_count,
  COUNT(DISTINCT product_uid) AS repeated_across_product_uid_count,
  array_agg(channel_sku_code ORDER BY product_uid, sto_id) AS sample_channel_sku_codes
FROM mk_classified_base
WHERE classification = 'auto_confirm_existing_regex'
GROUP BY resolved_sku_id, own_sku_candidate;

CREATE TEMP TABLE mk_classified AS
SELECT
  c.*,
  COALESCE(rs.repeated_matched_sku_count, 0) AS repeated_matched_sku_count,
  COALESCE(rs.repeated_matched_sku_count, 0) >= 3 AS repeated_matched_sku_flag,
  COALESCE(rs.repeated_across_product_uid_count, 0) AS repeated_across_product_uid_count,
  (c.v2_own_sku_candidate IS DISTINCT FROM c.own_sku_candidate) AS changed_own_sku_from_v2_flag,
  (c.v2_resolved_sku_id IS DISTINCT FROM c.resolved_sku_id) AS changed_matched_sku_id_from_v2_flag
FROM mk_classified_base c
LEFT JOIN auto_existing_repeat_stats rs
  ON rs.resolved_sku_id IS NOT DISTINCT FROM c.resolved_sku_id
 AND rs.own_sku_candidate IS NOT DISTINCT FROM c.own_sku_candidate;

\echo
\echo ===== [V3 SUMMARY] =====
SELECT
  COUNT(*) AS total_rows,
  COUNT(*) FILTER (WHERE classification = 'auto_confirm_existing_regex') AS auto_confirm_existing_regex,
  COUNT(*) FILTER (WHERE classification = 'auto_confirm_new_regex_candidate') AS auto_confirm_new_regex_candidate,
  COUNT(*) FILTER (WHERE classification = 'review_required') AS review_required,
  COUNT(*) FILTER (WHERE review_reason = 'review_null_key') AS null_key,
  COUNT(*) FILTER (WHERE review_reason = 'review_pattern_unmatched') AS pattern_unmatched,
  COUNT(*) FILTER (WHERE review_reason = 'review_not_in_alias') AS own_sku_not_in_alias,
  COUNT(*) FILTER (WHERE review_reason = 'review_ambiguous') AS own_sku_ambiguous,
  COUNT(*) FILTER (WHERE review_reason = 'channel_sku_conflict') AS channel_sku_conflict,
  COUNT(*) FILTER (WHERE review_reason = 'sku_inactive') AS sku_inactive,
  COUNT(*) FILTER (WHERE review_reason = 'review_loose_regex_only') AS loose_regex_only,
  COUNT(*) FILTER (WHERE classification = 'auto_confirm_existing_regex' AND repeated_matched_sku_flag) AS repeated_matched_sku_3plus_count
FROM mk_classified;

\echo
\echo ===== [V3 COMPARE WITH V2 RISK] =====
SELECT
  COUNT(*) FILTER (
    WHERE opt_value_any_bracket IS NOT NULL
      AND opt_values_any_bracket IS NOT NULL
      AND opt_value_any_bracket <> opt_values_any_bracket
  ) AS opt_value_code_and_opt_values_code_different_rows,
  COUNT(*) FILTER (
    WHERE opt_value_any_bracket IS NOT NULL
      AND opt_values_any_bracket IS NOT NULL
      AND opt_value_any_bracket <> opt_values_any_bracket
      AND v2_own_sku_candidate IS NOT DISTINCT FROM opt_value_any_bracket
  ) AS v2_would_choose_opt_value_rows,
  COUNT(*) FILTER (
    WHERE v2_own_sku_candidate IS DISTINCT FROM own_sku_candidate
      AND own_sku_candidate IS NOT DISTINCT FROM opt_values_any_bracket
  ) AS v3_changes_to_opt_values_rows,
  COUNT(*) FILTER (
    WHERE v2_own_sku_candidate IS DISTINCT FROM own_sku_candidate
      AND own_sku_candidate IS NOT DISTINCT FROM opt_values_any_bracket
      AND match_count = 1
  ) AS changed_unique_1_rows,
  COUNT(*) FILTER (
    WHERE v2_own_sku_candidate IS DISTINCT FROM own_sku_candidate
      AND own_sku_candidate IS NOT DISTINCT FROM opt_values_any_bracket
      AND match_count > 1
  ) AS changed_ambiguous_rows,
  COUNT(*) FILTER (
    WHERE v2_own_sku_candidate IS DISTINCT FROM own_sku_candidate
      AND own_sku_candidate IS NOT DISTINCT FROM opt_values_any_bracket
      AND match_count = 0
  ) AS changed_not_in_alias_rows
FROM mk_classified;

\echo
\echo ===== [V3 CHANGED AUTO CANDIDATES SAMPLE] =====
SELECT
  channel_sku_code,
  product_uid AS seller_product_code_raw,
  sto_id AS sto_id_raw,
  v2_own_sku_candidate AS v2_own_sku_code,
  own_sku_candidate AS v3_own_sku_code,
  opt_value,
  opt_values,
  resolved_sku_id AS v3_matched_sku_id,
  classification AS v3_classification
FROM mk_classified
WHERE v2_own_sku_candidate IS DISTINCT FROM own_sku_candidate
ORDER BY product_uid, sto_id
LIMIT 100;

\echo
\echo ===== [V3 NEW/LOST AUTO SUMMARY] =====
SELECT
  COUNT(*) FILTER (
    WHERE v2_classification IN ('auto_confirm_existing_regex', 'auto_confirm_new_regex_candidate')
      AND classification = 'review_required'
  ) AS v2_auto_v3_review_rows,
  COUNT(*) FILTER (
    WHERE v2_classification = 'review_required'
      AND classification IN ('auto_confirm_existing_regex', 'auto_confirm_new_regex_candidate')
  ) AS v2_review_v3_auto_rows,
  COUNT(*) FILTER (
    WHERE v2_classification IN ('auto_confirm_existing_regex', 'auto_confirm_new_regex_candidate')
      AND classification IN ('auto_confirm_existing_regex', 'auto_confirm_new_regex_candidate')
      AND v2_resolved_sku_id IS DISTINCT FROM resolved_sku_id
  ) AS both_auto_but_matched_sku_id_changed_rows
FROM mk_classified;

\echo
\echo ===== [V3 CONFLICT] =====
SELECT
  'makeshop'::text AS channel_code,
  product_uid AS seller_product_code_raw,
  channel_sku_code,
  sto_id AS sto_id_raw,
  own_sku_candidate AS own_sku_code,
  resolved_sku_id AS would_be_sku_id,
  existing_mapping_id,
  existing_mapped_sku_id,
  existing_is_primary,
  CASE
    WHEN existing_mapped_sku_id IS NOT DISTINCT FROM resolved_sku_id THEN 'idempotent_same_sku'
    ELSE 'different_sku'
  END AS conflict_kind
FROM mk_classified
WHERE existing_mapping_id IS NOT NULL
ORDER BY product_uid, sto_id
LIMIT 200;

ROLLBACK;

\echo
\echo dryrun_makeshop_select_only_v3.sql complete. ROLLBACK applied. No persistent changes.
