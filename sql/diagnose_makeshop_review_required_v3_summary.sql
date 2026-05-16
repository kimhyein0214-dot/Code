-- =============================================================================
-- diagnose_makeshop_review_required_v3_summary.sql
--
-- SELECT-only v3 review_required summary after local auto_confirm apply.
--
-- Safety:
--   - product_ops_test guard
--   - TEMP TABLE only
--   - SELECT only
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
      'review_required v3 summary is allowed only on product_ops_test. Current database: %',
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
    s.*,
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

CREATE TEMP TABLE mk_match_agg AS
SELECT
  e.*,
  COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) AS match_count,
  CASE
    WHEN COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) = 1
      THEN (array_agg(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL))[1]
    ELSE NULL
  END AS resolved_sku_id
FROM mk_extracted e
LEFT JOIN product_code.code_alias ca
  ON ca.target_type = 'SKU'
 AND ca.code_system = 'own_sku'
 AND ca.code_value = e.own_sku_candidate
 AND e.own_sku_candidate IS NOT NULL
 AND btrim(e.own_sku_candidate) <> ''
GROUP BY
  e.mk_row_id, e.product_uid, e.sto_id, e.sto_code, e.opt_value, e.opt_values,
  e.barcode, e.product_name, e.status, e.gid, e.ps_num, e.opt_value_existing_bracket,
  e.opt_values_existing_bracket, e.opt_value_4part_bracket, e.opt_values_4part_bracket,
  e.loose_4part_candidate, e.own_sku_candidate, e.extraction_method,
  e.regex_pattern_used, e.extraction_family, e.channel_sku_code,
  e.loose_regex_only_flag;

CREATE TEMP TABLE mk_classified AS
SELECT
  m.*,
  scm.id AS existing_mapping_id,
  scm.sku_id AS existing_mapped_sku_id,
  sm.status AS sku_master_status,
  CASE
    WHEN m.product_uid IS NULL OR btrim(m.product_uid) = ''
      OR m.sto_id IS NULL OR btrim(m.sto_id) = '' THEN 'null_key'
    WHEN m.own_sku_candidate IS NULL OR btrim(m.own_sku_candidate) = '' THEN
      CASE WHEN m.loose_regex_only_flag THEN 'loose_regex_only' ELSE 'pattern_unmatched' END
    WHEN m.match_count = 0 THEN 'own_sku_not_in_alias'
    WHEN m.match_count > 1 THEN 'own_sku_ambiguous'
    WHEN scm.id IS NOT NULL AND scm.sku_id IS DISTINCT FROM m.resolved_sku_id THEN 'channel_sku_conflict'
    WHEN sm.status IS NOT NULL
     AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%') THEN 'sku_inactive'
    WHEN scm.id IS NOT NULL AND scm.sku_id IS NOT DISTINCT FROM m.resolved_sku_id THEN 'already_applied_auto_confirm'
    WHEN m.match_count = 1 AND m.extraction_family IN ('existing', 'new_regex') THEN 'unapplied_auto_candidate'
    ELSE 'review_required'
  END AS reason
FROM mk_match_agg m
LEFT JOIN product_code.sku_channel_mapping scm
  ON scm.channel_code = 'makeshop'
 AND scm.channel_sku_code = m.channel_sku_code
 AND m.channel_sku_code IS NOT NULL
LEFT JOIN product_code.sku_master sm
  ON sm.id = m.resolved_sku_id;

\echo
\echo ===== [REVIEW REQUIRED V3 SUMMARY] =====
SELECT
  COUNT(*) AS total_rows,
  COUNT(*) FILTER (WHERE reason = 'already_applied_auto_confirm') AS already_applied_makeshop_rows,
  COUNT(*) FILTER (WHERE reason NOT IN ('already_applied_auto_confirm', 'unapplied_auto_candidate')) AS review_required_rows,
  COUNT(*) FILTER (WHERE reason = 'unapplied_auto_candidate') AS unapplied_auto_candidate_rows,
  COUNT(*) FILTER (WHERE reason = 'null_key') AS null_key,
  COUNT(*) FILTER (WHERE reason = 'pattern_unmatched') AS pattern_unmatched,
  COUNT(*) FILTER (WHERE reason = 'own_sku_not_in_alias') AS own_sku_not_in_alias,
  COUNT(*) FILTER (WHERE reason = 'own_sku_ambiguous') AS own_sku_ambiguous,
  COUNT(*) FILTER (WHERE reason = 'channel_sku_conflict') AS channel_sku_conflict,
  COUNT(*) FILTER (WHERE reason = 'sku_inactive') AS sku_inactive,
  COUNT(*) FILTER (WHERE reason = 'loose_regex_only') AS loose_regex_only
FROM mk_classified;

\echo
\echo ===== [REVIEW REQUIRED V3 BY REASON] =====
SELECT
  reason,
  COUNT(*) AS rows,
  COUNT(DISTINCT product_uid) FILTER (WHERE product_uid IS NOT NULL AND btrim(product_uid) <> '') AS affected_product_uid_count,
  COUNT(DISTINCT own_sku_candidate) FILTER (WHERE own_sku_candidate IS NOT NULL AND btrim(own_sku_candidate) <> '') AS distinct_own_sku_code,
  COUNT(*) FILTER (WHERE channel_sku_code IS NOT NULL) AS channel_sku_code_nonblank,
  COUNT(*) FILTER (WHERE channel_sku_code IS NULL) AS channel_sku_code_blank
FROM mk_classified
WHERE reason NOT IN ('already_applied_auto_confirm', 'unapplied_auto_candidate')
GROUP BY reason
ORDER BY rows DESC, reason;

\echo
\echo ===== [REVIEW REQUIRED V3 BY EXTRACTION_METHOD] =====
SELECT
  COALESCE(extraction_method, '(none)') AS extraction_method,
  COALESCE(regex_pattern_used, '(none)') AS regex_pattern_used,
  reason,
  COUNT(*) AS rows,
  COUNT(DISTINCT product_uid) FILTER (WHERE product_uid IS NOT NULL AND btrim(product_uid) <> '') AS affected_product_uid_count,
  COUNT(DISTINCT own_sku_candidate) FILTER (WHERE own_sku_candidate IS NOT NULL AND btrim(own_sku_candidate) <> '') AS distinct_own_sku_code
FROM mk_classified
WHERE reason NOT IN ('already_applied_auto_confirm', 'unapplied_auto_candidate')
GROUP BY extraction_method, regex_pattern_used, reason
ORDER BY reason, rows DESC, extraction_method;

\echo
\echo ===== [APPLIED OVERLAP CHECK] =====
SELECT
  COUNT(*) FILTER (WHERE existing_mapping_id IS NOT NULL) AS rows_with_existing_makeshop_mapping,
  COUNT(*) FILTER (WHERE reason = 'already_applied_auto_confirm') AS already_applied_same_sku,
  COUNT(*) FILTER (WHERE reason = 'channel_sku_conflict') AS existing_mapping_different_sku,
  COUNT(DISTINCT channel_sku_code) FILTER (WHERE existing_mapping_id IS NOT NULL) AS distinct_mapped_channel_sku_code
FROM mk_classified;

\echo
\echo ===== [REVIEW REQUIRED SAMPLE] =====
SELECT
  reason,
  product_uid AS seller_product_code_raw,
  sto_id AS sto_id_raw,
  channel_sku_code,
  own_sku_candidate AS own_sku_code,
  extraction_method,
  match_count,
  product_name,
  opt_value,
  opt_values,
  barcode
FROM mk_classified
WHERE reason NOT IN ('already_applied_auto_confirm', 'unapplied_auto_candidate')
ORDER BY reason, product_uid, sto_id
LIMIT 200;

ROLLBACK;

\echo
\echo diagnose_makeshop_review_required_v3_summary.sql complete. ROLLBACK applied. No persistent changes.
