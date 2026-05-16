-- =============================================================================
-- diagnose_makeshop_ambiguous_reduction_candidates.sql
--
-- SELECT-only diagnostic for MakeShop own_sku_ambiguous reduction candidates.
-- This script does not auto-resolve anything. It only exposes comparison columns.
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
  COUNT(DISTINCT ca.target_id) FILTER (WHERE ca.target_id IS NOT NULL) AS candidate_sku_count,
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

CREATE TEMP TABLE ambiguous_rows AS
SELECT *
FROM mk_match_agg
WHERE candidate_sku_count > 1;

CREATE TEMP TABLE ambiguous_code_summary AS
SELECT
  own_sku_candidate AS own_sku_code,
  COUNT(*) AS row_count,
  COUNT(DISTINCT product_uid) AS product_uid_count,
  COUNT(DISTINCT channel_sku_code) AS channel_sku_code_count,
  MAX(candidate_sku_count) AS candidate_sku_count,
  (
    SELECT array_agg(DISTINCT ca2.target_id ORDER BY ca2.target_id)
    FROM product_code.code_alias ca2
    WHERE ca2.target_type = 'SKU'
      AND ca2.code_system = 'own_sku'
      AND ca2.code_value = ar.own_sku_candidate
      AND ca2.target_id IS NOT NULL
  ) AS candidate_sku_ids,
  COUNT(*) FILTER (WHERE extraction_method = 'opt_value_bracket') AS rows_opt_value_bracket,
  COUNT(*) FILTER (WHERE extraction_method = 'opt_values_bracket') AS rows_opt_values_bracket,
  MIN(product_uid) AS sample_product_uid,
  MIN(product_name) AS sample_makeshop_product_name,
  MIN(opt_value) AS sample_makeshop_opt_value,
  MIN(opt_values) AS sample_makeshop_opt_values,
  MIN(barcode) AS sample_barcode
FROM ambiguous_rows ar
GROUP BY own_sku_candidate;

CREATE TEMP TABLE ambiguous_candidate_detail AS
SELECT
  ar.product_uid AS seller_product_code_raw,
  ar.channel_sku_code,
  ar.sto_id AS sto_id_raw,
  ar.own_sku_candidate AS own_sku_code,
  ar.extraction_method,
  ar.candidate_sku_count,
  ar.candidate_sku_ids,
  ca.target_id AS candidate_sku_id,
  sm.virtual_sku_code,
  sm.option_value AS sku_option_value,
  sm.sku_type,
  sm.status AS sku_status,
  sm.product_id,
  pm.virtual_product_code,
  pm.product_name AS master_product_name,
  ar.product_name AS makeshop_product_name,
  ar.opt_value AS makeshop_opt_value,
  ar.opt_values AS makeshop_opt_values,
  ar.barcode,
  alias_info.selfpia_sku_codes,
  alias_info.selfpia_product_codes,
  alias_info.selfpia_option_nos,
  alias_info.other_own_sku_codes
FROM ambiguous_rows ar
JOIN product_code.code_alias ca
  ON ca.target_type = 'SKU'
 AND ca.code_system = 'own_sku'
 AND ca.code_value = ar.own_sku_candidate
JOIN product_code.sku_master sm
  ON sm.id = ca.target_id
LEFT JOIN product_code.product_master pm
  ON pm.id = sm.product_id
LEFT JOIN LATERAL (
  SELECT
    array_agg(DISTINCT ca2.code_value ORDER BY ca2.code_value)
      FILTER (WHERE ca2.code_system = 'selfpia_sku') AS selfpia_sku_codes,
    array_agg(DISTINCT ca2.selfpia_product_code ORDER BY ca2.selfpia_product_code)
      FILTER (WHERE ca2.selfpia_product_code IS NOT NULL AND btrim(ca2.selfpia_product_code) <> '') AS selfpia_product_codes,
    array_agg(DISTINCT ca2.selfpia_option_no ORDER BY ca2.selfpia_option_no)
      FILTER (WHERE ca2.selfpia_option_no IS NOT NULL AND btrim(ca2.selfpia_option_no) <> '') AS selfpia_option_nos,
    array_agg(DISTINCT ca2.code_value ORDER BY ca2.code_value)
      FILTER (WHERE ca2.code_system = 'own_sku') AS other_own_sku_codes
  FROM product_code.code_alias ca2
  WHERE ca2.target_type = 'SKU'
    AND ca2.target_id = sm.id
) alias_info ON true;

\echo
\echo ===== [ambiguous summary] =====
SELECT
  COUNT(*) AS ambiguous_rows,
  COUNT(DISTINCT own_sku_candidate) AS ambiguous_own_sku_codes,
  COUNT(DISTINCT product_uid) AS ambiguous_product_uids,
  COUNT(DISTINCT channel_sku_code) AS ambiguous_channel_sku_codes
FROM ambiguous_rows;

\echo
\echo ===== [ambiguous top 100 own_sku codes] =====
SELECT *
FROM ambiguous_code_summary
ORDER BY row_count DESC, candidate_sku_count DESC, own_sku_code
LIMIT 100;

\echo
\echo ===== [candidate SKU detail for top ambiguous codes] =====
WITH top_codes AS (
  SELECT own_sku_code
  FROM ambiguous_code_summary
  ORDER BY row_count DESC, candidate_sku_count DESC, own_sku_code
  LIMIT 20
)
SELECT
  acd.*
FROM ambiguous_candidate_detail acd
JOIN top_codes t
  ON t.own_sku_code = acd.own_sku_code
ORDER BY acd.own_sku_code, acd.channel_sku_code, acd.candidate_sku_id
LIMIT 500;

\echo
\echo ===== [same product_uid same own_sku repeats top 100] =====
SELECT
  ar.product_uid AS seller_product_code_raw,
  ar.own_sku_candidate AS own_sku_code,
  ar.extraction_method,
  COUNT(*) AS rows,
  COUNT(DISTINCT ar.sto_id) AS distinct_sto_id,
  COUNT(DISTINCT ar.channel_sku_code) AS distinct_channel_sku_code,
  MAX(ar.candidate_sku_count) AS candidate_sku_count,
  (
    SELECT array_agg(DISTINCT ca2.target_id ORDER BY ca2.target_id)
    FROM product_code.code_alias ca2
    WHERE ca2.target_type = 'SKU'
      AND ca2.code_system = 'own_sku'
      AND ca2.code_value = ar.own_sku_candidate
      AND ca2.target_id IS NOT NULL
  ) AS candidate_sku_ids,
  array_agg(DISTINCT ar.sto_id ORDER BY ar.sto_id)
    FILTER (WHERE ar.sto_id IS NOT NULL AND btrim(ar.sto_id) <> '') AS sto_ids,
  MIN(ar.product_name) AS sample_makeshop_product_name,
  MIN(ar.opt_value) AS sample_makeshop_opt_value,
  MIN(ar.opt_values) AS sample_makeshop_opt_values,
  MIN(ar.barcode) AS sample_barcode
FROM ambiguous_rows ar
GROUP BY ar.product_uid, ar.own_sku_candidate, ar.extraction_method
HAVING COUNT(*) > 1
ORDER BY rows DESC, distinct_sto_id DESC, seller_product_code_raw, own_sku_code
LIMIT 100;

ROLLBACK;

\echo
\echo diagnose_makeshop_ambiguous_reduction_candidates.sql complete. ROLLBACK applied. No persistent changes.
