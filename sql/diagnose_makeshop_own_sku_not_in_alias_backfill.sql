-- =============================================================================
-- diagnose_makeshop_own_sku_not_in_alias_backfill.sql
--
-- SELECT-only diagnostic for MakeShop own_sku_not_in_alias rows.
--
-- Output CSV:
--   /tmp/makeshop_own_sku_not_in_alias_backfill_candidates.csv
--
-- Safety: product_ops_test guard, TEMP TABLE only, SELECT / \copy only,
-- BEGIN ... ROLLBACK, no persistent DB changes.
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION
      'own_sku_not_in_alias diagnostic is allowed only on product_ops_test. Current database: %',
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
    substring(s.opt_values FROM '\[([A-Za-z]+-[0-9]+-[0-9]+-[0-9]+)\]') AS opt_values_4part_bracket
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
    WHEN b.product_uid IS NOT NULL AND btrim(b.product_uid) <> ''
     AND b.sto_id IS NOT NULL AND btrim(b.sto_id) <> ''
      THEN btrim(b.product_uid) || '-' || btrim(b.sto_id)
    ELSE NULL
  END AS channel_sku_code
FROM base b;

CREATE TEMP TABLE not_in_alias_rows AS
SELECT
  e.*,
  upper(regexp_replace(e.own_sku_candidate, '[^A-Za-z0-9]', '', 'g')) AS own_sku_norm
FROM mk_extracted e
LEFT JOIN product_code.code_alias ca
  ON ca.target_type = 'SKU'
 AND ca.code_system = 'own_sku'
 AND ca.code_value = e.own_sku_candidate
WHERE e.own_sku_candidate IS NOT NULL
  AND btrim(e.own_sku_candidate) <> ''
  AND ca.target_id IS NULL;

CREATE TEMP TABLE code_alias_norm AS
SELECT
  ca.code_system,
  ca.code_value,
  ca.target_id,
  upper(regexp_replace(ca.code_value, '[^A-Za-z0-9]', '', 'g')) AS code_norm
FROM product_code.code_alias ca
WHERE ca.target_type = 'SKU'
  AND ca.code_value IS NOT NULL
  AND btrim(ca.code_value) <> '';

CREATE TEMP TABLE own_sku_code_summary AS
SELECT
  r.own_sku_candidate AS own_sku_code,
  r.own_sku_norm,
  COUNT(*) AS row_count,
  COUNT(DISTINCT r.product_uid) AS distinct_product_uid,
  COUNT(DISTINCT r.channel_sku_code) AS distinct_channel_sku_code,
  MIN(r.product_uid) AS sample_product_uid,
  MIN(r.channel_sku_code) AS sample_channel_sku_code,
  MIN(r.product_name) AS sample_product_name,
  MIN(r.opt_values) AS sample_opt_values,
  MIN(r.barcode) AS sample_barcode
FROM not_in_alias_rows r
GROUP BY r.own_sku_candidate, r.own_sku_norm;

CREATE TEMP TABLE backfill_candidates AS
SELECT
  s.*,
  COUNT(DISTINCT ca_same_norm.target_id) FILTER (WHERE ca_same_norm.target_id IS NOT NULL) AS normalized_alias_candidate_sku_count,
  array_agg(DISTINCT ca_same_norm.target_id ORDER BY ca_same_norm.target_id)
    FILTER (WHERE ca_same_norm.target_id IS NOT NULL) AS normalized_alias_candidate_sku_ids,
  array_agg(DISTINCT ca_same_norm.code_system || ':' || ca_same_norm.code_value ORDER BY ca_same_norm.code_system || ':' || ca_same_norm.code_value)
    FILTER (WHERE ca_same_norm.code_value IS NOT NULL) AS normalized_alias_matches,
  CASE
    WHEN COUNT(DISTINCT ca_same_norm.target_id) FILTER (WHERE ca_same_norm.target_id IS NOT NULL) = 1
      THEN 'alias_backfill_candidate_normalized_unique'
    WHEN COUNT(DISTINCT ca_same_norm.target_id) FILTER (WHERE ca_same_norm.target_id IS NOT NULL) > 1
      THEN 'manual_review_multiple_normalized_alias_matches'
    ELSE 'manual_review_no_alias_like_match'
  END AS diagnostic_label
FROM own_sku_code_summary s
LEFT JOIN code_alias_norm ca_same_norm
  ON ca_same_norm.code_norm = s.own_sku_norm
 AND ca_same_norm.code_system <> 'own_sku'
GROUP BY
  s.own_sku_code, s.own_sku_norm, s.row_count, s.distinct_product_uid,
  s.distinct_channel_sku_code, s.sample_product_uid, s.sample_channel_sku_code,
  s.sample_product_name, s.sample_opt_values, s.sample_barcode;

\copy (SELECT * FROM backfill_candidates ORDER BY diagnostic_label, row_count DESC, own_sku_code) TO '/tmp/makeshop_own_sku_not_in_alias_backfill_candidates.csv' WITH (FORMAT CSV, HEADER true, ENCODING 'UTF8')

\echo
\echo ===== [OWN SKU NOT IN ALIAS SUMMARY] =====
SELECT
  (SELECT COUNT(*) FROM not_in_alias_rows) AS rows,
  (SELECT COUNT(*) FROM own_sku_code_summary) AS distinct_own_sku_code,
  COUNT(*) FILTER (WHERE diagnostic_label = 'alias_backfill_candidate_normalized_unique') AS alias_backfill_candidate_codes,
  COUNT(*) FILTER (WHERE diagnostic_label = 'manual_review_multiple_normalized_alias_matches') AS multiple_match_codes,
  COUNT(*) FILTER (WHERE diagnostic_label = 'manual_review_no_alias_like_match') AS no_like_match_codes
FROM backfill_candidates;

\echo
\echo ===== [OWN SKU NOT IN ALIAS TOP CODES] =====
SELECT *
FROM backfill_candidates
ORDER BY row_count DESC, own_sku_code
LIMIT 100;

\echo
\echo Exported CSV:
\echo /tmp/makeshop_own_sku_not_in_alias_backfill_candidates.csv

ROLLBACK;

\echo
\echo diagnose_makeshop_own_sku_not_in_alias_backfill.sql complete. ROLLBACK applied. No persistent changes.
