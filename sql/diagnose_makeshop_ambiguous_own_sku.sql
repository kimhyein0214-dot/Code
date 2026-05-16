-- =============================================================================
-- diagnose_makeshop_ambiguous_own_sku.sql
--
-- Read-only diagnostic for MakeShop own_sku_ambiguous causes.
-- Uses the same own_sku extraction priority as dryrun_makeshop_select_only.sql:
--   sto_code -> opt_value bracket -> opt_values bracket.
--
-- Safety: product_ops_test guard, TEMP TABLE only, BEGIN ... ROLLBACK.
-- CSV input path inside Docker container: /tmp/makeshop_minimal_full.csv
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
  s.product_uid,
  s.sto_id,
  s.sto_code,
  s.opt_value,
  s.opt_values,
  s.barcode,
  s.product_name,
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

CREATE TEMP TABLE mk_match_agg AS
SELECT
  e.product_uid,
  e.sto_id,
  e.channel_sku_code,
  e.sto_code,
  e.opt_value,
  e.opt_values,
  e.barcode,
  e.product_name,
  e.own_sku_candidate,
  e.extraction_method,
  e.opt_value_bracket,
  e.opt_values_bracket,
  COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) AS candidate_sku_id_count,
  array_agg(DISTINCT ca.target_id ORDER BY ca.target_id)
    FILTER (WHERE ca.target_id IS NOT NULL) AS candidate_sku_ids
FROM mk_extracted e
LEFT JOIN product_code.code_alias ca
  ON ca.target_type = 'SKU'
 AND ca.code_system = 'own_sku'
 AND ca.code_value = e.own_sku_candidate
 AND e.own_sku_candidate IS NOT NULL
 AND btrim(e.own_sku_candidate) <> ''
GROUP BY
  e.product_uid, e.sto_id, e.channel_sku_code, e.sto_code, e.opt_value,
  e.opt_values, e.barcode, e.product_name, e.own_sku_candidate,
  e.extraction_method, e.opt_value_bracket, e.opt_values_bracket;

CREATE TEMP TABLE ambiguous_own_sku AS
SELECT
  mma.own_sku_candidate AS own_sku_code,
  COUNT(*) AS row_count,
  COUNT(DISTINCT product_uid) AS distinct_product_uid,
  COUNT(DISTINCT channel_sku_code) AS distinct_channel_sku_code,
  MAX(candidate_sku_id_count) AS candidate_sku_id_count,
  (
    SELECT array_agg(DISTINCT ca2.target_id ORDER BY ca2.target_id)
    FROM product_code.code_alias ca2
    WHERE ca2.target_type = 'SKU'
      AND ca2.code_system = 'own_sku'
      AND ca2.code_value = mma.own_sku_candidate
      AND ca2.target_id IS NOT NULL
  ) AS candidate_sku_ids,
  COUNT(*) FILTER (WHERE extraction_method = 'sto_code') AS rows_sto_code,
  COUNT(*) FILTER (WHERE extraction_method = 'opt_value_bracket') AS rows_opt_value_bracket,
  COUNT(*) FILTER (WHERE extraction_method = 'opt_values_bracket') AS rows_opt_values_bracket,
  MIN(product_name) AS sample_product_name,
  MIN(barcode) AS sample_barcode,
  MIN(opt_value) AS sample_opt_value,
  MIN(opt_values) AS sample_opt_values
FROM mk_match_agg mma
WHERE candidate_sku_id_count > 1
GROUP BY mma.own_sku_candidate;

\echo
\echo ===== [ambiguous own_sku summary] =====
SELECT
  COUNT(*) AS ambiguous_own_sku_codes,
  COALESCE(SUM(row_count), 0) AS ambiguous_rows,
  COUNT(*) FILTER (WHERE candidate_sku_id_count = 2) AS ambig_2_codes,
  COUNT(*) FILTER (WHERE candidate_sku_id_count = 3) AS ambig_3_codes,
  COUNT(*) FILTER (WHERE candidate_sku_id_count >= 4) AS ambig_4_plus_codes,
  COALESCE(SUM(row_count) FILTER (WHERE candidate_sku_id_count = 2), 0) AS ambig_2_rows,
  COALESCE(SUM(row_count) FILTER (WHERE candidate_sku_id_count = 3), 0) AS ambig_3_rows,
  COALESCE(SUM(row_count) FILTER (WHERE candidate_sku_id_count >= 4), 0) AS ambig_4_plus_rows
FROM ambiguous_own_sku;

\echo
\echo ===== [ambiguous ratio by extraction_method] =====
SELECT
  COALESCE(extraction_method, '(none)') AS extraction_method,
  COUNT(*) AS rows,
  COUNT(*) FILTER (WHERE candidate_sku_id_count > 1) AS ambiguous_rows,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE candidate_sku_id_count > 1) / NULLIF(COUNT(*), 0),
    2
  ) AS ambiguous_pct
FROM mk_match_agg
GROUP BY extraction_method
ORDER BY 1;

\echo
\echo ===== [ambiguous bucket by extraction_method] =====
SELECT
  COALESCE(extraction_method, '(none)') AS extraction_method,
  CASE
    WHEN candidate_sku_id_count = 2 THEN 'ambig_2'
    WHEN candidate_sku_id_count = 3 THEN 'ambig_3'
    WHEN candidate_sku_id_count >= 4 THEN 'ambig_4_plus'
  END AS ambiguous_bucket,
  COUNT(*) AS rows,
  COUNT(DISTINCT own_sku_candidate) AS distinct_own_sku
FROM mk_match_agg
WHERE candidate_sku_id_count > 1
GROUP BY 1, 2
ORDER BY 1, 2;

\echo
\echo ===== [ambiguous own_sku top 100] =====
SELECT
  own_sku_code,
  row_count,
  distinct_product_uid,
  distinct_channel_sku_code,
  candidate_sku_id_count,
  candidate_sku_ids,
  rows_sto_code,
  rows_opt_value_bracket,
  rows_opt_values_bracket,
  sample_product_name,
  sample_barcode,
  sample_opt_value,
  sample_opt_values
FROM ambiguous_own_sku
ORDER BY row_count DESC, candidate_sku_id_count DESC, own_sku_code
LIMIT 100;

\echo
\echo ===== [same product_uid opt_values first bracket repeats] =====
WITH opt_values_first AS (
  SELECT
    product_uid,
    sto_id,
    channel_sku_code,
    product_name,
    opt_values,
    opt_values_bracket AS first_bracket
  FROM mk_extracted
  WHERE product_uid IS NOT NULL AND btrim(product_uid) <> ''
    AND opt_values_bracket IS NOT NULL
),
repeat_counts AS (
  SELECT
    product_uid,
    first_bracket,
    COUNT(*) AS rows,
    COUNT(DISTINCT sto_id) AS distinct_sto_id,
    COUNT(DISTINCT channel_sku_code) AS distinct_channel_sku_code,
    MIN(product_name) AS sample_product_name,
    MIN(opt_values) AS sample_opt_values
  FROM opt_values_first
  GROUP BY product_uid, first_bracket
)
SELECT
  COUNT(*) FILTER (WHERE rows > 1) AS repeated_product_first_bracket_keys,
  COALESCE(SUM(rows) FILTER (WHERE rows > 1), 0) AS repeated_product_first_bracket_rows,
  COUNT(*) FILTER (WHERE distinct_sto_id > 1) AS repeated_across_multiple_sto_id_keys,
  COALESCE(SUM(rows) FILTER (WHERE distinct_sto_id > 1), 0) AS repeated_across_multiple_sto_id_rows
FROM repeat_counts;

\echo
\echo ===== [same product_uid opt_values first bracket repeats top 50] =====
WITH opt_values_first AS (
  SELECT
    product_uid,
    sto_id,
    channel_sku_code,
    product_name,
    opt_values,
    opt_values_bracket AS first_bracket
  FROM mk_extracted
  WHERE product_uid IS NOT NULL AND btrim(product_uid) <> ''
    AND opt_values_bracket IS NOT NULL
),
repeat_counts AS (
  SELECT
    product_uid,
    first_bracket,
    COUNT(*) AS rows,
    COUNT(DISTINCT sto_id) AS distinct_sto_id,
    COUNT(DISTINCT channel_sku_code) AS distinct_channel_sku_code,
    array_agg(DISTINCT sto_id ORDER BY sto_id) FILTER (WHERE sto_id IS NOT NULL AND btrim(sto_id) <> '') AS sto_ids,
    MIN(product_name) AS sample_product_name,
    MIN(opt_values) AS sample_opt_values
  FROM opt_values_first
  GROUP BY product_uid, first_bracket
)
SELECT *
FROM repeat_counts
WHERE rows > 1
ORDER BY rows DESC, distinct_sto_id DESC, product_uid, first_bracket
LIMIT 50;

ROLLBACK;

\echo
\echo diagnose_makeshop_ambiguous_own_sku.sql complete. ROLLBACK applied. No persistent changes.
