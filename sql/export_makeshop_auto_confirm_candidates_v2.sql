-- =============================================================================
-- export_makeshop_auto_confirm_candidates_v2.sql
--
-- SELECT-only MakeShop auto_confirm candidate export v2.
--
-- Exports:
--   - auto_confirm_existing_regex
--   - auto_confirm_new_regex_candidate
--
-- Excludes:
--   - null_key / pattern_unmatched / own_sku_not_in_alias / own_sku_ambiguous
--   - loose_regex_only / channel_sku_conflict / sku_inactive
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
--
-- CSV output path inside Docker container:
--   /tmp/makeshop_auto_confirm_candidates_v2.csv
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'auto_confirm export v2 is allowed only on product_ops_test. Current database: %',
      current_database();
  END IF;
END
$$;

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Raw landing
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 2. Regex extraction. This intentionally mirrors dryrun_makeshop_select_only_v2.sql.
--    Loose 4-part regex remains diagnostic-only and is never auto-confirmed.
-- ---------------------------------------------------------------------------
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
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> ''
      THEN btrim(b.sto_code)
    WHEN b.opt_value_existing_bracket IS NOT NULL
      THEN b.opt_value_existing_bracket
    WHEN b.opt_values_existing_bracket IS NOT NULL
      THEN b.opt_values_existing_bracket
    WHEN b.opt_value_4part_bracket IS NOT NULL
      THEN b.opt_value_4part_bracket
    WHEN b.opt_values_4part_bracket IS NOT NULL
      THEN b.opt_values_4part_bracket
    ELSE NULL
  END AS own_sku_candidate,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> ''
      THEN 'sto_code'
    WHEN b.opt_value_existing_bracket IS NOT NULL
      THEN 'opt_value_bracket'
    WHEN b.opt_values_existing_bracket IS NOT NULL
      THEN 'opt_values_bracket'
    WHEN b.opt_value_4part_bracket IS NOT NULL
      THEN 'opt_value_4part_bracket'
    WHEN b.opt_values_4part_bracket IS NOT NULL
      THEN 'opt_values_4part_bracket'
    ELSE NULL
  END AS extraction_method,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> ''
      THEN 'sto_code_exact'
    WHEN b.opt_value_existing_bracket IS NOT NULL
      THEN 'existing_bracket'
    WHEN b.opt_values_existing_bracket IS NOT NULL
      THEN 'existing_bracket'
    WHEN b.opt_value_4part_bracket IS NOT NULL
      THEN 'bracket_4part'
    WHEN b.opt_values_4part_bracket IS NOT NULL
      THEN 'bracket_4part'
    ELSE NULL
  END AS regex_pattern_used,
  CASE
    WHEN b.sto_code IS NOT NULL AND btrim(b.sto_code) <> ''
      THEN 'existing'
    WHEN b.opt_value_existing_bracket IS NOT NULL
      THEN 'existing'
    WHEN b.opt_values_existing_bracket IS NOT NULL
      THEN 'existing'
    WHEN b.opt_value_4part_bracket IS NOT NULL
      THEN 'new_regex'
    WHEN b.opt_values_4part_bracket IS NOT NULL
      THEN 'new_regex'
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

-- ---------------------------------------------------------------------------
-- 3. Match chosen own_sku candidate against own_sku aliases.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE mk_match_agg AS
SELECT
  e.*,
  COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) AS match_count,
  array_agg(DISTINCT ca.target_id ORDER BY ca.target_id)
    FILTER (WHERE ca.target_id IS NOT NULL) AS candidate_sku_ids,
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
  e.barcode, e.product_name, e.source_status, e.opt_value_existing_bracket,
  e.opt_values_existing_bracket, e.opt_value_4part_bracket,
  e.opt_values_4part_bracket, e.loose_4part_candidate, e.own_sku_candidate,
  e.extraction_method, e.regex_pattern_used, e.extraction_family,
  e.channel_sku_code, e.loose_regex_only_flag;

-- ---------------------------------------------------------------------------
-- 4. Conflict/status lookup and v2 classification.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE mk_classified_base AS
SELECT
  m.*,
  scm.id AS existing_mapping_id,
  scm.sku_id AS existing_mapped_sku_id,
  scm.is_primary AS existing_is_primary,
  sm.status AS sku_master_status,
  CASE
    WHEN m.product_uid IS NULL OR btrim(m.product_uid) = ''
      OR m.sto_id IS NULL OR btrim(m.sto_id) = ''
      THEN 'review_null_key'
    WHEN m.own_sku_candidate IS NULL OR btrim(m.own_sku_candidate) = ''
      THEN CASE
        WHEN m.loose_regex_only_flag THEN 'review_loose_regex_only'
        ELSE 'review_pattern_unmatched'
      END
    WHEN m.match_count = 0
      THEN 'review_not_in_alias'
    WHEN m.match_count > 1
      THEN 'review_ambiguous'
    WHEN scm.id IS NOT NULL
      THEN 'channel_sku_conflict'
    WHEN sm.status IS NOT NULL
     AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%')
      THEN 'sku_inactive'
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
     AND m.extraction_family = 'existing'
      THEN 'auto_confirm_existing_regex'
    WHEN m.product_uid IS NOT NULL AND btrim(m.product_uid) <> ''
     AND m.sto_id IS NOT NULL AND btrim(m.sto_id) <> ''
     AND m.own_sku_candidate IS NOT NULL AND btrim(m.own_sku_candidate) <> ''
     AND m.match_count = 1
     AND scm.id IS NULL
     AND NOT (
       sm.status IS NOT NULL
       AND (sm.status ILIKE '%inactive%' OR sm.status ILIKE '%deleted%' OR sm.status ILIKE '%archive%')
     )
     AND m.extraction_family = 'new_regex'
      THEN 'auto_confirm_new_regex_candidate'
    ELSE 'review_required'
  END AS classification
FROM mk_match_agg m
LEFT JOIN product_code.sku_channel_mapping scm
  ON scm.channel_code = 'makeshop'
 AND scm.channel_sku_code = m.channel_sku_code
 AND m.channel_sku_code IS NOT NULL
LEFT JOIN product_code.sku_master sm
  ON sm.id = m.resolved_sku_id;

-- ---------------------------------------------------------------------------
-- 5. Repeated flags. These are review flags only. They intentionally mirror
--    v2 dryrun: count repeated matched SKU among existing-regex auto-confirm rows.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE auto_existing_repeat_stats AS
SELECT
  resolved_sku_id,
  own_sku_candidate,
  COUNT(*) AS repeated_matched_sku_count,
  COUNT(DISTINCT product_uid) AS repeated_across_product_uid_count,
  array_agg(channel_sku_code ORDER BY product_uid, sto_id) AS sample_channel_sku_codes,
  array_agg(DISTINCT product_name ORDER BY product_name)
    FILTER (WHERE product_name IS NOT NULL AND btrim(product_name) <> '') AS sample_product_names
FROM mk_classified_base
WHERE classification = 'auto_confirm_existing_regex'
GROUP BY resolved_sku_id, own_sku_candidate;

CREATE TEMP TABLE mk_classified AS
SELECT
  c.*,
  CASE
    WHEN c.classification = 'auto_confirm_existing_regex'
      THEN COALESCE(rs.repeated_matched_sku_count, 0)
    ELSE 0
  END AS repeated_matched_sku_count,
  CASE
    WHEN c.classification = 'auto_confirm_existing_regex'
      THEN COALESCE(rs.repeated_matched_sku_count, 0) >= 3
    ELSE false
  END AS repeated_matched_sku_3plus_flag,
  CASE
    WHEN c.classification = 'auto_confirm_existing_regex'
      THEN COALESCE(rs.repeated_matched_sku_count, 0)
    ELSE 0
  END AS repeated_own_sku_count,
  CASE
    WHEN c.classification = 'auto_confirm_existing_regex'
      THEN COALESCE(rs.repeated_across_product_uid_count, 0)
    ELSE 0
  END AS repeated_across_product_uid_count,
  rs.sample_channel_sku_codes AS repeated_sample_channel_sku_codes,
  rs.sample_product_names AS repeated_sample_product_names
FROM mk_classified_base c
LEFT JOIN auto_existing_repeat_stats rs
  ON rs.resolved_sku_id IS NOT DISTINCT FROM c.resolved_sku_id
 AND rs.own_sku_candidate IS NOT DISTINCT FROM c.own_sku_candidate;

-- ---------------------------------------------------------------------------
-- 6. Export detail. This table is the exact CSV source.
-- ---------------------------------------------------------------------------
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
  c.repeated_own_sku_count,
  c.repeated_across_product_uid_count,
  'makeshop_minimal_full.csv'::text AS source_file
FROM mk_classified c
JOIN product_code.sku_master sm
  ON sm.id = c.resolved_sku_id
LEFT JOIN product_code.product_master pm
  ON pm.id = sm.product_id
WHERE c.classification IN (
  'auto_confirm_existing_regex',
  'auto_confirm_new_regex_candidate'
);

\copy (SELECT * FROM mk_export ORDER BY seller_product_code_raw, sto_id_raw, channel_sku_code) TO '/tmp/makeshop_auto_confirm_candidates_v2.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

\echo
\echo ===== [EXPORT V2 SUMMARY] =====
SELECT
  COUNT(*) AS total_export_rows,
  COUNT(*) FILTER (WHERE auto_confirm_type = 'existing_regex') AS existing_regex_rows,
  COUNT(*) FILTER (WHERE auto_confirm_type = 'new_regex_candidate') AS new_regex_candidate_rows,
  COUNT(*) FILTER (WHERE repeated_matched_sku_3plus_flag) AS repeated_matched_sku_3plus_rows,
  COUNT(DISTINCT channel_sku_code) AS distinct_channel_sku_code,
  COUNT(*) - COUNT(DISTINCT channel_sku_code) AS duplicate_channel_sku_code_count,
  COUNT(DISTINCT matched_sku_id) AS distinct_matched_sku_id,
  COUNT(DISTINCT own_sku_code) AS distinct_own_sku_code
FROM mk_export;

\echo
\echo ===== [EXPORT V2 by extraction_method] =====
SELECT
  extraction_method,
  regex_pattern_used,
  COUNT(*) AS rows,
  COUNT(DISTINCT own_sku_code) AS distinct_own_sku_code,
  COUNT(DISTINCT matched_sku_id) AS distinct_matched_sku_id
FROM mk_export
GROUP BY extraction_method, regex_pattern_used
ORDER BY extraction_method, regex_pattern_used;

\echo
\echo ===== [EXPORT V2 repeated matched_sku 3plus] =====
SELECT
  c.resolved_sku_id AS matched_sku_id,
  c.own_sku_candidate AS own_sku_code,
  c.repeated_matched_sku_count AS repeated_count,
  c.repeated_across_product_uid_count AS distinct_product_uid_count,
  c.repeated_sample_channel_sku_codes AS sample_channel_sku_codes,
  c.repeated_sample_product_names AS sample_product_names
FROM mk_classified c
WHERE c.classification = 'auto_confirm_existing_regex'
  AND c.repeated_matched_sku_3plus_flag
GROUP BY
  c.resolved_sku_id,
  c.own_sku_candidate,
  c.repeated_matched_sku_count,
  c.repeated_across_product_uid_count,
  c.repeated_sample_channel_sku_codes,
  c.repeated_sample_product_names
ORDER BY repeated_count DESC, own_sku_code
LIMIT 100;

\echo
\echo ===== [EXPORT V2 new regex candidates sample] =====
SELECT
  channel_sku_code,
  own_sku_code,
  regex_pattern_used,
  matched_sku_id,
  opt_value,
  opt_values,
  makeshop_product_name AS product_name
FROM mk_export
WHERE auto_confirm_type = 'new_regex_candidate'
ORDER BY seller_product_code_raw, sto_id_raw, channel_sku_code
LIMIT 200;

\echo
\echo Exported auto_confirm v2 CSV file:
\echo /tmp/makeshop_auto_confirm_candidates_v2.csv

ROLLBACK;

\echo
\echo export_makeshop_auto_confirm_candidates_v2.sql complete. ROLLBACK applied. No persistent DB changes.
