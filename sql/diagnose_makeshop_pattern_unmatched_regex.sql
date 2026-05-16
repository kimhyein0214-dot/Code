-- =============================================================================
-- diagnose_makeshop_pattern_unmatched_regex.sql
--
-- SELECT-only diagnostic for MakeShop pattern_unmatched rows.
-- Tests whether wider bracket-code regexes can recover own_sku candidates.
--
-- Safety:
--   - product_ops_test guard
--   - TEMP TABLE only
--   - SELECT / \copy FROM only
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
      'diagnostic is allowed only on product_ops_test. Current database: %',
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
  substring(s.opt_value  FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') AS opt_value_bracket,
  substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') AS opt_values_bracket,
  CASE
    WHEN s.sto_code IS NOT NULL AND btrim(s.sto_code) <> ''
      THEN btrim(s.sto_code)
    WHEN substring(s.opt_value FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') IS NOT NULL
      THEN substring(s.opt_value FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]')
    WHEN substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') IS NOT NULL
      THEN substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]')
    ELSE NULL
  END AS own_sku_candidate,
  CASE
    WHEN s.sto_code IS NOT NULL AND btrim(s.sto_code) <> ''
      THEN 'sto_code'
    WHEN substring(s.opt_value FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') IS NOT NULL
      THEN 'opt_value_bracket'
    WHEN substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+(?:_[0-9]+)?)\]') IS NOT NULL
      THEN 'opt_values_bracket'
    ELSE NULL
  END AS extraction_method,
  CASE
    WHEN s.product_uid IS NOT NULL AND btrim(s.product_uid) <> ''
     AND s.sto_id IS NOT NULL AND btrim(s.sto_id) <> ''
      THEN btrim(s.product_uid) || '-' || btrim(s.sto_id)
    ELSE NULL
  END AS channel_sku_code
FROM mk_src s;

CREATE TEMP TABLE mk_pattern_unmatched AS
SELECT *
FROM mk_extracted
WHERE (sto_code IS NULL OR btrim(sto_code) = '')
  AND ((opt_value IS NOT NULL AND btrim(opt_value) <> '')
    OR (opt_values IS NOT NULL AND btrim(opt_values) <> ''))
  AND opt_value_bracket IS NULL
  AND opt_values_bracket IS NULL;

CREATE TEMP TABLE regex_candidates AS
WITH pattern_defs AS (
  SELECT *
  FROM (VALUES
    ('bracket_hyphen_4part_1digit', '\[([A-Za-z]+-[0-9]+-[0-9]+-[0-9])\]'),
    ('bracket_hyphen_4part_2digit', '\[([A-Za-z]+-[0-9]+-[0-9]+-[0-9]{2})\]'),
    ('bracket_hyphen_4part_any',    '\[([A-Za-z]+-[0-9]+-[0-9]+-[0-9]+)\]'),
    ('bracket_underscore_suffix',   '\[([A-Za-z]+-[0-9]+-[0-9]+_[0-9]+)\]'),
    ('loose_hyphen_4part_any',      '([A-Za-z]+-[0-9]+-[0-9]+-[0-9]+)')
  ) AS p(pattern_name, regex_pattern)
),
source_values AS (
  SELECT
    mk_row_id,
    'opt_value' AS source_field,
    opt_value AS source_text
  FROM mk_pattern_unmatched
  WHERE opt_value IS NOT NULL AND btrim(opt_value) <> ''
  UNION ALL
  SELECT
    mk_row_id,
    'opt_values' AS source_field,
    opt_values AS source_text
  FROM mk_pattern_unmatched
  WHERE opt_values IS NOT NULL AND btrim(opt_values) <> ''
)
SELECT DISTINCT
  pu.mk_row_id,
  p.pattern_name,
  sv.source_field,
  substring(sv.source_text FROM p.regex_pattern) AS candidate_code
FROM mk_pattern_unmatched pu
JOIN source_values sv
  ON sv.mk_row_id = pu.mk_row_id
CROSS JOIN pattern_defs p
WHERE substring(sv.source_text FROM p.regex_pattern) IS NOT NULL;

CREATE TEMP TABLE regex_candidate_alias AS
SELECT
  rc.mk_row_id,
  rc.pattern_name,
  rc.source_field,
  rc.candidate_code,
  COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) AS distinct_target_ids,
  array_agg(DISTINCT ca.target_id ORDER BY ca.target_id)
    FILTER (WHERE ca.target_id IS NOT NULL) AS candidate_sku_ids
FROM regex_candidates rc
LEFT JOIN product_code.code_alias ca
  ON ca.target_type = 'SKU'
 AND ca.code_system = 'own_sku'
 AND ca.code_value = rc.candidate_code
GROUP BY rc.mk_row_id, rc.pattern_name, rc.source_field, rc.candidate_code;

\echo
\echo ===== [pattern_unmatched reproduced] =====
SELECT
  (SELECT COUNT(*) FROM mk_extracted) AS total_rows,
  (SELECT COUNT(*) FROM mk_pattern_unmatched) AS pattern_unmatched_rows,
  COUNT(*) FILTER (WHERE channel_sku_code IS NOT NULL) AS pattern_unmatched_nonblank_channel_sku
FROM mk_pattern_unmatched;

\echo
\echo ===== [additional regex summary by pattern] =====
SELECT
  pattern_name,
  COUNT(DISTINCT mk_row_id) AS matched_rows,
  COUNT(DISTINCT candidate_code) AS distinct_candidate_codes,
  COUNT(DISTINCT mk_row_id) FILTER (WHERE distinct_target_ids = 1) AS rows_unique_1,
  COUNT(DISTINCT mk_row_id) FILTER (WHERE distinct_target_ids > 1) AS rows_ambiguous,
  COUNT(DISTINCT mk_row_id) FILTER (WHERE distinct_target_ids = 0) AS rows_not_in_alias,
  COUNT(DISTINCT candidate_code) FILTER (WHERE distinct_target_ids = 1) AS codes_unique_1,
  COUNT(DISTINCT candidate_code) FILTER (WHERE distinct_target_ids > 1) AS codes_ambiguous,
  COUNT(DISTINCT candidate_code) FILTER (WHERE distinct_target_ids = 0) AS codes_not_in_alias
FROM regex_candidate_alias
GROUP BY pattern_name
ORDER BY matched_rows DESC, pattern_name;

\echo
\echo ===== [additional regex summary by pattern and source_field] =====
SELECT
  pattern_name,
  source_field,
  COUNT(DISTINCT mk_row_id) AS matched_rows,
  COUNT(DISTINCT candidate_code) AS distinct_candidate_codes,
  COUNT(DISTINCT mk_row_id) FILTER (WHERE distinct_target_ids = 1) AS rows_unique_1,
  COUNT(DISTINCT mk_row_id) FILTER (WHERE distinct_target_ids > 1) AS rows_ambiguous,
  COUNT(DISTINCT mk_row_id) FILTER (WHERE distinct_target_ids = 0) AS rows_not_in_alias
FROM regex_candidate_alias
GROUP BY pattern_name, source_field
ORDER BY pattern_name, source_field;

\echo
\echo ===== [estimated newly auto-confirmable rows by any additional regex] =====
WITH per_row AS (
  SELECT
    pu.mk_row_id,
    pu.channel_sku_code,
    COUNT(*) FILTER (WHERE rca.distinct_target_ids = 1) AS unique_candidate_count,
    COUNT(*) FILTER (WHERE rca.distinct_target_ids > 1) AS ambiguous_candidate_count,
    COUNT(*) FILTER (WHERE rca.distinct_target_ids = 0) AS not_in_alias_candidate_count
  FROM mk_pattern_unmatched pu
  LEFT JOIN regex_candidate_alias rca
    ON rca.mk_row_id = pu.mk_row_id
  GROUP BY pu.mk_row_id, pu.channel_sku_code
)
SELECT
  COUNT(*) FILTER (WHERE unique_candidate_count = 1 AND ambiguous_candidate_count = 0) AS possible_auto_confirm_rows_strict,
  COUNT(*) FILTER (WHERE unique_candidate_count >= 1) AS rows_with_at_least_one_unique_alias_candidate,
  COUNT(*) FILTER (WHERE unique_candidate_count > 1) AS rows_with_multiple_unique_alias_candidates,
  COUNT(*) FILTER (WHERE ambiguous_candidate_count > 0) AS rows_with_ambiguous_alias_candidate,
  COUNT(*) FILTER (WHERE not_in_alias_candidate_count > 0) AS rows_with_not_in_alias_candidate,
  COUNT(*) FILTER (WHERE channel_sku_code IS NULL) AS rows_still_null_key
FROM per_row;

\echo
\echo ===== [additional regex candidate bucket top 100 codes] =====
SELECT
  candidate_code,
  COUNT(DISTINCT mk_row_id) AS rows,
  COUNT(DISTINCT pattern_name) AS patterns_hit,
  COUNT(DISTINCT source_field) AS source_fields_hit,
  MAX(distinct_target_ids) AS distinct_target_ids,
  CASE
    WHEN MAX(distinct_target_ids) = 1 THEN 'unique_1'
    WHEN MAX(distinct_target_ids) > 1 THEN 'ambiguous'
    ELSE 'not_in_alias'
  END AS alias_bucket,
  MIN(pattern_name) AS sample_pattern_name,
  MIN(source_field) AS sample_source_field
FROM regex_candidate_alias
GROUP BY candidate_code
ORDER BY rows DESC, distinct_target_ids DESC, candidate_code
LIMIT 100;

\echo
\echo ===== [additional regex sample 100 rows] =====
SELECT
  pu.product_uid AS seller_product_code_raw,
  pu.channel_sku_code,
  pu.sto_id AS sto_id_raw,
  rca.pattern_name,
  rca.source_field,
  rca.candidate_code AS proposed_own_sku_code,
  CASE
    WHEN rca.distinct_target_ids = 1 THEN 'unique_1'
    WHEN rca.distinct_target_ids > 1 THEN 'ambiguous'
    ELSE 'not_in_alias'
  END AS alias_bucket,
  rca.distinct_target_ids,
  rca.candidate_sku_ids,
  pu.product_name,
  pu.opt_value,
  pu.opt_values,
  pu.barcode
FROM regex_candidate_alias rca
JOIN mk_pattern_unmatched pu
  ON pu.mk_row_id = rca.mk_row_id
ORDER BY
  CASE
    WHEN rca.distinct_target_ids = 1 THEN 0
    WHEN rca.distinct_target_ids > 1 THEN 1
    ELSE 2
  END,
  pu.product_uid,
  pu.sto_id,
  rca.pattern_name
LIMIT 100;

ROLLBACK;

\echo
\echo diagnose_makeshop_pattern_unmatched_regex.sql complete. ROLLBACK applied. No persistent changes.
