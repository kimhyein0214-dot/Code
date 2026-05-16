-- =============================================================================
-- precheck_product_image_csv_coverage.sql
--
-- LOCAL DOCKER ONLY / SELECT-ONLY COVERAGE CHECK.
--
-- Purpose:
--   Load exports/selfpia_image_url.csv into a TEMP table and measure coverage
--   against product_code.code_alias(code_system='selfpia_sku').
--
-- Expected CSV columns:
--   p_code,image_url,updated_at,own_code
--
-- Usage in container:
--   psql -U product_ops_tester -d product_ops_test \
--     -v ON_ERROR_STOP=1 \
--     -v CSV_PATH="'/tmp/selfpia_image_url.csv'" \
--     -f /tmp/precheck_product_image_csv_coverage.sql
--
-- This script performs no persistent DB writes.
-- =============================================================================

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'product_image CSV coverage is allowed only on product_ops_test. Current database: %', current_database();
  END IF;
END
$$;

DROP TABLE IF EXISTS pg_temp.selfpia_image_csv_stage;

CREATE TEMP TABLE selfpia_image_csv_stage (
  p_code      text,
  image_url   text,
  updated_at  text,
  own_code    text
) ON COMMIT PRESERVE ROWS;

\copy selfpia_image_csv_stage (p_code, image_url, updated_at, own_code) FROM '/tmp/selfpia_image_url.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- 1. CSV shape and blank-value summary.
SELECT
  10 AS no,
  'CSV_ROWS' AS check_name,
  count(*) AS total_rows,
  count(DISTINCT NULLIF(btrim(p_code), '')) AS distinct_p_code,
  count(*) FILTER (WHERE NULLIF(btrim(p_code), '') IS NULL) AS blank_p_code_rows,
  count(*) FILTER (WHERE NULLIF(btrim(image_url), '') IS NULL) AS blank_image_url_rows,
  count(*) FILTER (WHERE NULLIF(btrim(own_code), '') IS NULL) AS blank_own_code_rows
FROM selfpia_image_csv_stage;

-- 2. Duplicated p_code distribution.
WITH per_p_code AS (
  SELECT
    NULLIF(btrim(p_code), '') AS p_code,
    count(*) AS rows,
    count(DISTINCT NULLIF(btrim(image_url), '')) AS distinct_image_urls
  FROM selfpia_image_csv_stage
  GROUP BY NULLIF(btrim(p_code), '')
)
SELECT
  20 AS no,
  'DUPLICATED_P_CODE' AS check_name,
  count(*) FILTER (WHERE rows > 1 AND p_code IS NOT NULL) AS duplicated_p_code_keys,
  COALESCE(sum(rows) FILTER (WHERE rows > 1 AND p_code IS NOT NULL), 0) AS duplicated_p_code_rows,
  max(rows) FILTER (WHERE p_code IS NOT NULL) AS max_rows_per_p_code,
  max(distinct_image_urls) FILTER (WHERE p_code IS NOT NULL) AS max_distinct_images_per_p_code
FROM per_p_code;

-- 3. Coverage against selfpia_sku alias.
WITH normalized AS (
  SELECT
    NULLIF(btrim(p_code), '') AS p_code,
    NULLIF(btrim(image_url), '') AS image_url,
    NULLIF(btrim(updated_at), '') AS updated_at,
    NULLIF(btrim(own_code), '') AS own_code
  FROM selfpia_image_csv_stage
),
matched AS (
  SELECT
    n.*,
    ca.target_id AS sku_id,
    ca.selfpia_product_code,
    ca.selfpia_option_no
  FROM normalized n
  LEFT JOIN product_code.code_alias ca
    ON ca.target_type = 'SKU'
   AND ca.code_system = 'selfpia_sku'
   AND ca.code_value = n.p_code
)
SELECT
  30 AS no,
  'SELFPiA_SKU_COVERAGE' AS check_name,
  count(DISTINCT p_code) FILTER (WHERE p_code IS NOT NULL) AS csv_distinct_p_code,
  count(DISTINCT p_code) FILTER (WHERE p_code IS NOT NULL AND sku_id IS NOT NULL) AS matched_distinct_p_code,
  count(DISTINCT p_code) FILTER (WHERE p_code IS NOT NULL AND sku_id IS NULL) AS unmatched_distinct_p_code,
  count(*) FILTER (WHERE image_url IS NOT NULL AND sku_id IS NOT NULL) AS rows_with_image_and_matched_sku,
  count(*) FILTER (WHERE image_url IS NOT NULL AND sku_id IS NULL) AS rows_with_image_but_unmatched_sku,
  count(*) FILTER (WHERE image_url IS NULL AND sku_id IS NOT NULL) AS blank_image_but_matched_sku
FROM matched;

-- 4. Image rows per SKU.
WITH normalized AS (
  SELECT
    NULLIF(btrim(p_code), '') AS p_code,
    NULLIF(btrim(image_url), '') AS image_url
  FROM selfpia_image_csv_stage
),
matched AS (
  SELECT
    n.p_code,
    n.image_url,
    ca.target_id AS sku_id
  FROM normalized n
  JOIN product_code.code_alias ca
    ON ca.target_type = 'SKU'
   AND ca.code_system = 'selfpia_sku'
   AND ca.code_value = n.p_code
  WHERE n.image_url IS NOT NULL
),
per_sku AS (
  SELECT
    sku_id,
    count(*) AS image_rows,
    count(DISTINCT image_url) AS distinct_image_urls
  FROM matched
  GROUP BY sku_id
)
SELECT
  40 AS no,
  'IMAGE_ROWS_PER_SKU' AS check_name,
  count(*) AS skus_with_images,
  count(*) FILTER (WHERE image_rows = 1) AS skus_with_one_image_row,
  count(*) FILTER (WHERE image_rows > 1) AS skus_with_multiple_image_rows,
  max(image_rows) AS max_image_rows_per_sku,
  max(distinct_image_urls) AS max_distinct_image_urls_per_sku
FROM per_sku;

-- 5. Same image_url reused by multiple SKUs.
WITH normalized AS (
  SELECT
    NULLIF(btrim(p_code), '') AS p_code,
    NULLIF(btrim(image_url), '') AS image_url
  FROM selfpia_image_csv_stage
),
matched AS (
  SELECT
    n.image_url,
    ca.target_id AS sku_id
  FROM normalized n
  JOIN product_code.code_alias ca
    ON ca.target_type = 'SKU'
   AND ca.code_system = 'selfpia_sku'
   AND ca.code_value = n.p_code
  WHERE n.image_url IS NOT NULL
),
per_image AS (
  SELECT
    image_url,
    count(DISTINCT sku_id) AS sku_count
  FROM matched
  GROUP BY image_url
)
SELECT
  50 AS no,
  'IMAGE_URL_REUSE' AS check_name,
  count(*) AS distinct_image_urls,
  count(*) FILTER (WHERE sku_count > 1) AS image_urls_used_by_multiple_skus,
  max(sku_count) AS max_skus_per_image_url
FROM per_image;

-- 6. Matched sample.
WITH normalized AS (
  SELECT
    NULLIF(btrim(p_code), '') AS p_code,
    NULLIF(btrim(image_url), '') AS image_url,
    NULLIF(btrim(updated_at), '') AS updated_at,
    NULLIF(btrim(own_code), '') AS own_code
  FROM selfpia_image_csv_stage
),
matched AS (
  SELECT
    n.p_code,
    n.image_url,
    n.updated_at,
    n.own_code,
    ca.target_id AS sku_id,
    ca.selfpia_product_code,
    ca.selfpia_option_no,
    v.product_name,
    v.option_value
  FROM normalized n
  JOIN product_code.code_alias ca
    ON ca.target_type = 'SKU'
   AND ca.code_system = 'selfpia_sku'
   AND ca.code_value = n.p_code
  LEFT JOIN product_code.v_sku_canonical v
    ON v.sku_id = ca.target_id
   AND v.selfpia_sku_code = ca.code_value
  WHERE n.image_url IS NOT NULL
)
SELECT
  60 AS no,
  'MATCHED_SAMPLE' AS sample_name,
  p_code,
  sku_id,
  selfpia_product_code,
  selfpia_option_no,
  product_name,
  option_value,
  image_url,
  updated_at,
  own_code
FROM matched
ORDER BY p_code
LIMIT 10;

-- 7. Unmatched sample.
WITH normalized AS (
  SELECT
    NULLIF(btrim(p_code), '') AS p_code,
    NULLIF(btrim(image_url), '') AS image_url,
    NULLIF(btrim(updated_at), '') AS updated_at,
    NULLIF(btrim(own_code), '') AS own_code
  FROM selfpia_image_csv_stage
),
unmatched AS (
  SELECT n.*
  FROM normalized n
  LEFT JOIN product_code.code_alias ca
    ON ca.target_type = 'SKU'
   AND ca.code_system = 'selfpia_sku'
   AND ca.code_value = n.p_code
  WHERE n.p_code IS NOT NULL
    AND ca.target_id IS NULL
)
SELECT
  70 AS no,
  'UNMATCHED_SAMPLE' AS sample_name,
  p_code,
  image_url,
  updated_at,
  own_code
FROM unmatched
ORDER BY p_code
LIMIT 10;

-- 8. Blank image_url sample.
SELECT
  80 AS no,
  'BLANK_IMAGE_URL_SAMPLE' AS sample_name,
  p_code,
  image_url,
  updated_at,
  own_code
FROM selfpia_image_csv_stage
WHERE NULLIF(btrim(image_url), '') IS NULL
ORDER BY NULLIF(btrim(p_code), '') NULLS LAST
LIMIT 10;
