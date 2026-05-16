-- =============================================================================
-- diagnose_makeshop_composite_uniqueness.sql
--
-- Read-only diagnostic for MakeShop composite channel_sku_code uniqueness.
-- Composite key: product_uid || '-' || sto_id.
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
  s.*,
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

\echo
\echo ===== [composite key summary] =====
WITH composite_counts AS (
  SELECT channel_sku_code, COUNT(*) AS rows
  FROM mk_extracted
  WHERE channel_sku_code IS NOT NULL
  GROUP BY channel_sku_code
)
SELECT
  (SELECT COUNT(*) FROM mk_extracted) AS total_rows,
  (SELECT COUNT(*) FROM mk_extracted WHERE product_uid IS NOT NULL AND btrim(product_uid) <> '') AS product_uid_nonblank_rows,
  (SELECT COUNT(*) FROM mk_extracted WHERE sto_id IS NOT NULL AND btrim(sto_id) <> '') AS sto_id_nonblank_rows,
  (SELECT COUNT(*) FROM mk_extracted WHERE channel_sku_code IS NOT NULL) AS channel_sku_code_nonblank_rows,
  (SELECT COUNT(DISTINCT channel_sku_code) FROM mk_extracted WHERE channel_sku_code IS NOT NULL) AS distinct_channel_sku_code,
  (SELECT COUNT(*) FROM composite_counts WHERE rows > 1) AS duplicate_channel_sku_code_keys,
  (SELECT COALESCE(SUM(rows), 0) FROM composite_counts WHERE rows > 1) AS duplicate_channel_sku_code_rows;

\echo
\echo ===== [duplicate channel_sku_code sample top 50] =====
SELECT
  channel_sku_code,
  COUNT(*) AS rows,
  COUNT(DISTINCT product_uid) AS distinct_product_uid,
  COUNT(DISTINCT sto_id) AS distinct_sto_id,
  MIN(product_name) AS sample_product_name,
  MIN(opt_value) AS sample_opt_value,
  MIN(opt_values) AS sample_opt_values
FROM mk_extracted
WHERE channel_sku_code IS NOT NULL
GROUP BY channel_sku_code
HAVING COUNT(*) > 1
ORDER BY rows DESC, channel_sku_code
LIMIT 50;

\echo
\echo ===== [product_uid + sto_id duplicate summary] =====
WITH product_sto_counts AS (
  SELECT btrim(product_uid) AS product_uid_key, btrim(sto_id) AS sto_id_key, COUNT(*) AS rows
  FROM mk_extracted
  WHERE product_uid IS NOT NULL AND btrim(product_uid) <> ''
    AND sto_id IS NOT NULL AND btrim(sto_id) <> ''
  GROUP BY 1, 2
)
SELECT
  COUNT(*) FILTER (WHERE rows > 1) AS duplicate_product_sto_keys,
  COALESCE(SUM(rows) FILTER (WHERE rows > 1), 0) AS duplicate_product_sto_rows
FROM product_sto_counts;

\echo
\echo ===== [product_uid + sto_id duplicate sample top 50] =====
SELECT
  product_uid,
  sto_id,
  COUNT(*) AS rows,
  MIN(product_name) AS sample_product_name,
  MIN(opt_value) AS sample_opt_value,
  MIN(opt_values) AS sample_opt_values
FROM mk_extracted
WHERE product_uid IS NOT NULL AND btrim(product_uid) <> ''
  AND sto_id IS NOT NULL AND btrim(sto_id) <> ''
GROUP BY product_uid, sto_id
HAVING COUNT(*) > 1
ORDER BY rows DESC, product_uid, sto_id
LIMIT 50;

\echo
\echo ===== [same product_uid own_sku repeats summary] =====
WITH product_own_counts AS (
  SELECT
    btrim(product_uid) AS product_uid_key,
    own_sku_candidate,
    COUNT(*) AS rows,
    COUNT(DISTINCT sto_id) FILTER (WHERE sto_id IS NOT NULL AND btrim(sto_id) <> '') AS distinct_sto_id
  FROM mk_extracted
  WHERE product_uid IS NOT NULL AND btrim(product_uid) <> ''
    AND own_sku_candidate IS NOT NULL AND btrim(own_sku_candidate) <> ''
  GROUP BY 1, 2
)
SELECT
  COUNT(*) FILTER (WHERE rows > 1) AS repeated_product_own_sku_keys,
  COALESCE(SUM(rows) FILTER (WHERE rows > 1), 0) AS repeated_product_own_sku_rows,
  COUNT(*) FILTER (WHERE distinct_sto_id > 1) AS repeated_across_multiple_sto_id_keys,
  COALESCE(SUM(rows) FILTER (WHERE distinct_sto_id > 1), 0) AS repeated_across_multiple_sto_id_rows
FROM product_own_counts;

\echo
\echo ===== [same product_uid own_sku repeats sample top 50] =====
SELECT
  product_uid,
  own_sku_candidate AS own_sku_code,
  extraction_method,
  COUNT(*) AS rows,
  COUNT(DISTINCT sto_id) AS distinct_sto_id,
  array_agg(DISTINCT sto_id ORDER BY sto_id) FILTER (WHERE sto_id IS NOT NULL AND btrim(sto_id) <> '') AS sto_ids,
  MIN(product_name) AS sample_product_name
FROM mk_extracted
WHERE product_uid IS NOT NULL AND btrim(product_uid) <> ''
  AND own_sku_candidate IS NOT NULL AND btrim(own_sku_candidate) <> ''
GROUP BY product_uid, own_sku_candidate, extraction_method
HAVING COUNT(*) > 1
ORDER BY rows DESC, distinct_sto_id DESC, product_uid, own_sku_code
LIMIT 50;

\echo
\echo ===== [opt_values fallback repeated own_sku across sto_id top 50] =====
SELECT
  own_sku_candidate AS own_sku_code,
  COUNT(*) AS rows,
  COUNT(DISTINCT product_uid) AS distinct_product_uid,
  COUNT(DISTINCT channel_sku_code) AS distinct_channel_sku_code,
  COUNT(DISTINCT sto_id) AS distinct_sto_id,
  MIN(product_uid) AS sample_product_uid,
  MIN(product_name) AS sample_product_name,
  MIN(opt_values) AS sample_opt_values
FROM mk_extracted
WHERE extraction_method = 'opt_values_bracket'
  AND own_sku_candidate IS NOT NULL
GROUP BY own_sku_candidate
HAVING COUNT(DISTINCT sto_id) > 1 OR COUNT(*) > 1
ORDER BY rows DESC, distinct_product_uid DESC, own_sku_code
LIMIT 50;

ROLLBACK;

\echo
\echo diagnose_makeshop_composite_uniqueness.sql complete. ROLLBACK applied. No persistent changes.
