-- =============================================================================
-- export_makeshop_auto_confirm_candidates_v3.sql
--
-- SELECT-only MakeShop auto_confirm candidate export v3.
-- v3 prioritizes opt_values bracket codes before opt_value bracket codes.
--
-- Output:
--   /tmp/makeshop_auto_confirm_candidates_v3.csv
--
-- Safety: product_ops_test guard, TEMP TABLE only, BEGIN ... ROLLBACK.
-- CSV input path inside Docker container: /tmp/makeshop_minimal_full.csv
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'auto_confirm export v3 is allowed only on product_ops_test. Current database: %',
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
  e.mk_row_id,
  e.v2_own_sku_candidate,
  e.v2_extraction_family,
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
GROUP BY e.mk_row_id, e.v2_own_sku_candidate, e.v2_extraction_family;

CREATE TEMP TABLE mk_classified_v2 AS
SELECT
  e.mk_row_id,
  v2.v2_own_sku_candidate,
  v2.v2_match_count,
  v2.v2_resolved_sku_id,
  CASE
    WHEN e.product_uid IS NOT NULL AND btrim(e.product_uid) <> ''
     AND e.sto_id IS NOT NULL AND btrim(e.sto_id) <> ''
     AND v2.v2_own_sku_candidate IS NOT NULL AND btrim(v2.v2_own_sku_candidate) <> ''
     AND v2.v2_match_count = 1
     AND scm.id IS NULL
     AND NOT (
       sm.status IS NOT NULL
       AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%')
     )
     AND v2.v2_extraction_family = 'existing' THEN 'auto_confirm_existing_regex'
    WHEN e.product_uid IS NOT NULL AND btrim(e.product_uid) <> ''
     AND e.sto_id IS NOT NULL AND btrim(e.sto_id) <> ''
     AND v2.v2_own_sku_candidate IS NOT NULL AND btrim(v2.v2_own_sku_candidate) <> ''
     AND v2.v2_match_count = 1
     AND scm.id IS NULL
     AND NOT (
       sm.status IS NOT NULL
       AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%')
     )
     AND v2.v2_extraction_family = 'new_regex' THEN 'auto_confirm_new_regex_candidate'
    ELSE 'review_required'
  END AS v2_classification
FROM mk_extracted e
JOIN mk_match_v2 v2
  ON v2.mk_row_id = e.mk_row_id
LEFT JOIN product_code.sku_channel_mapping scm
  ON scm.channel_code = 'makeshop'
 AND scm.channel_sku_code = e.channel_sku_code
 AND e.channel_sku_code IS NOT NULL
LEFT JOIN product_code.sku_master sm
  ON sm.id = v2.v2_resolved_sku_id;

CREATE TEMP TABLE mk_match_v3 AS
SELECT
  e.*,
  v2.v2_resolved_sku_id,
  v2.v2_classification,
  COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) AS match_count,
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
  e.channel_sku_code, e.loose_regex_only_flag,
  v2.v2_resolved_sku_id, v2.v2_classification;

CREATE TEMP TABLE mk_classified_base AS
SELECT
  m.*,
  scm.id AS existing_mapping_id,
  sm.status AS sku_master_status,
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
  COUNT(DISTINCT product_uid) AS repeated_across_product_uid_count
FROM mk_classified_base
WHERE classification = 'auto_confirm_existing_regex'
GROUP BY resolved_sku_id, own_sku_candidate;

CREATE TEMP TABLE mk_classified AS
SELECT
  c.*,
  COALESCE(rs.repeated_matched_sku_count, 0) AS repeated_matched_sku_count,
  COALESCE(rs.repeated_matched_sku_count, 0) >= 3 AS repeated_matched_sku_3plus_flag,
  (c.v2_own_sku_candidate IS DISTINCT FROM c.own_sku_candidate) AS changed_from_v2_flag,
  (c.v2_resolved_sku_id IS DISTINCT FROM c.resolved_sku_id) AS changed_matched_sku_id_from_v2_flag
FROM mk_classified_base c
LEFT JOIN auto_existing_repeat_stats rs
  ON rs.resolved_sku_id IS NOT DISTINCT FROM c.resolved_sku_id
 AND rs.own_sku_candidate IS NOT DISTINCT FROM c.own_sku_candidate;

CREATE TEMP TABLE mk_export AS
SELECT
  'makeshop'::text AS channel_code,
  c.product_uid AS seller_product_code_raw,
  c.channel_sku_code,
  c.sto_id AS sto_id_raw,
  c.sto_code,
  c.opt_value,
  c.opt_values,
  c.own_sku_candidate AS own_sku_code,
  c.extraction_method,
  c.regex_pattern_used,
  CASE
    WHEN c.classification = 'auto_confirm_existing_regex' THEN 'existing_regex'
    WHEN c.classification = 'auto_confirm_new_regex_candidate' THEN 'new_regex_candidate'
  END AS auto_confirm_type,
  c.resolved_sku_id AS matched_sku_id,
  sm.virtual_sku_code AS matched_virtual_sku_code,
  sm.option_value AS matched_option_value,
  sm.product_id AS matched_product_id,
  pm.product_name AS matched_product_name,
  c.product_name AS makeshop_product_name,
  c.barcode,
  c.repeated_matched_sku_count,
  c.repeated_matched_sku_3plus_flag,
  c.v2_own_sku_candidate AS v2_selected_own_sku_code,
  c.v2_resolved_sku_id AS v2_selected_matched_sku_id,
  c.changed_from_v2_flag,
  'v3_opt_values_priority_from_makeshop_minimal_full.csv'::text AS source_note
FROM mk_classified c
JOIN product_code.sku_master sm
  ON sm.id = c.resolved_sku_id
LEFT JOIN product_code.product_master pm
  ON pm.id = sm.product_id
WHERE c.classification IN (
  'auto_confirm_existing_regex',
  'auto_confirm_new_regex_candidate'
);

\copy (SELECT * FROM mk_export ORDER BY seller_product_code_raw, sto_id_raw, channel_sku_code) TO '/tmp/makeshop_auto_confirm_candidates_v3.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

\echo
\echo ===== [EXPORT V3 SUMMARY] =====
SELECT
  COUNT(*) AS total_export_rows,
  COUNT(*) FILTER (WHERE auto_confirm_type = 'existing_regex') AS existing_regex_rows,
  COUNT(*) FILTER (WHERE auto_confirm_type = 'new_regex_candidate') AS new_regex_candidate_rows,
  COUNT(*) - COUNT(DISTINCT channel_sku_code) AS duplicate_channel_sku_code_count,
  COUNT(DISTINCT channel_sku_code) AS distinct_channel_sku_code,
  COUNT(*) FILTER (WHERE repeated_matched_sku_3plus_flag) AS repeated_matched_sku_3plus_rows,
  COUNT(*) FILTER (WHERE changed_from_v2_flag) AS changed_from_v2_rows,
  COUNT(*) FILTER (
    WHERE v2_selected_matched_sku_id IS DISTINCT FROM matched_sku_id
  ) AS changed_matched_sku_id_rows
FROM mk_export;

\echo
\echo ===== [EXPORT V3 CHANGED FROM V2 SAMPLE] =====
SELECT
  channel_sku_code,
  seller_product_code_raw,
  sto_id_raw,
  v2_selected_own_sku_code,
  own_sku_code AS v3_own_sku_code,
  v2_selected_matched_sku_id,
  matched_sku_id AS v3_matched_sku_id,
  auto_confirm_type,
  matched_option_value,
  opt_value,
  opt_values
FROM mk_export
WHERE changed_from_v2_flag
   OR v2_selected_matched_sku_id IS DISTINCT FROM matched_sku_id
ORDER BY seller_product_code_raw, sto_id_raw
LIMIT 100;

\echo
\echo ===== [EXPORT V3 NEW REGEX SAMPLE] =====
SELECT
  channel_sku_code,
  own_sku_code,
  regex_pattern_used,
  matched_sku_id,
  matched_option_value,
  opt_value,
  opt_values,
  makeshop_product_name AS product_name
FROM mk_export
WHERE auto_confirm_type = 'new_regex_candidate'
ORDER BY seller_product_code_raw, sto_id_raw, channel_sku_code
LIMIT 200;

\echo
\echo Exported auto_confirm v3 CSV file:
\echo /tmp/makeshop_auto_confirm_candidates_v3.csv

ROLLBACK;

\echo
\echo export_makeshop_auto_confirm_candidates_v3.sql complete. ROLLBACK applied. No persistent DB changes.
