-- =============================================================================
-- dryrun_product_image_import.sql
--
-- LOCAL DOCKER ONLY DRYRUN.
--
-- Purpose:
--   Simulate product_code.product_image insert from selfpia image CSV without
--   persistent writes.
--
-- Expected container CSV:
--   /tmp/selfpia_image_url.csv
--
-- No apply SQL is created or executed by this file.
-- =============================================================================

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'product_image dryrun is allowed only on product_ops_test. Current database: %', current_database();
  END IF;
END
$$;

BEGIN;

CREATE TEMP TABLE product_image_import_stage (
  p_code      text,
  image_url   text,
  updated_at  text,
  own_code    text
) ON COMMIT DROP;

\copy product_image_import_stage (p_code, image_url, updated_at, own_code) FROM '/tmp/selfpia_image_url.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

CREATE TEMP TABLE product_image_dryrun_target (
  id                    bigserial PRIMARY KEY,
  sku_id                uuid,
  product_id            uuid,
  selfpia_sku_code      text,
  selfpia_product_code  text,
  image_url             text NOT NULL,
  thumbnail_url         text,
  source                text NOT NULL DEFAULT 'selfpia_image_csv',
  is_primary            boolean NOT NULL DEFAULT true,
  sort_order            integer NOT NULL DEFAULT 0,
  updated_at            text,
  raw_payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at            timestamptz NOT NULL DEFAULT now()
) ON COMMIT DROP;

WITH normalized AS (
  SELECT
    NULLIF(btrim(p_code), '') AS p_code,
    NULLIF(btrim(image_url), '') AS image_url,
    NULLIF(btrim(updated_at), '') AS source_updated_at,
    NULLIF(btrim(own_code), '') AS own_code
  FROM product_image_import_stage
),
resolved AS (
  SELECT
    n.*,
    ca.target_id AS sku_id,
    ca.selfpia_product_code,
    v.product_id
  FROM normalized n
  LEFT JOIN product_code.code_alias ca
    ON ca.target_type = 'SKU'
   AND ca.code_system = 'selfpia_sku'
   AND ca.code_value = n.p_code
  LEFT JOIN product_code.v_sku_canonical v
    ON v.sku_id = ca.target_id
   AND v.selfpia_sku_code = ca.code_value
),
insert_candidates AS (
  SELECT
    sku_id,
    product_id,
    p_code AS selfpia_sku_code,
    selfpia_product_code,
    image_url,
    image_url AS thumbnail_url,
    'selfpia_image_csv'::text AS source,
    true AS is_primary,
    0 AS sort_order,
    source_updated_at AS updated_at,
    jsonb_build_object(
      'p_code', p_code,
      'own_code', own_code,
      'source_updated_at', source_updated_at
    ) AS raw_payload
  FROM resolved
  WHERE image_url IS NOT NULL
    AND sku_id IS NOT NULL
)
INSERT INTO product_image_dryrun_target (
  sku_id,
  product_id,
  selfpia_sku_code,
  selfpia_product_code,
  image_url,
  thumbnail_url,
  source,
  is_primary,
  sort_order,
  updated_at,
  raw_payload
)
SELECT
  sku_id,
  product_id,
  selfpia_sku_code,
  selfpia_product_code,
  image_url,
  thumbnail_url,
  source,
  is_primary,
  sort_order,
  updated_at,
  raw_payload
FROM insert_candidates;

-- no=10: overall staged/import candidate counts.
WITH normalized AS (
  SELECT
    NULLIF(btrim(p_code), '') AS p_code,
    NULLIF(btrim(image_url), '') AS image_url
  FROM product_image_import_stage
),
resolved AS (
  SELECT
    n.*,
    ca.target_id AS sku_id
  FROM normalized n
  LEFT JOIN product_code.code_alias ca
    ON ca.target_type = 'SKU'
   AND ca.code_system = 'selfpia_sku'
   AND ca.code_value = n.p_code
)
SELECT
  10 AS no,
  'DRYRUN_COUNTS' AS check_name,
  count(*) AS csv_rows,
  count(*) FILTER (WHERE image_url IS NOT NULL) AS rows_with_image_url,
  count(*) FILTER (WHERE image_url IS NULL) AS blank_image_url_rows,
  count(*) FILTER (WHERE image_url IS NOT NULL AND sku_id IS NOT NULL) AS ready_insert_rows,
  count(*) FILTER (WHERE image_url IS NOT NULL AND sku_id IS NULL) AS image_orphan_rows,
  (SELECT count(*) FROM product_image_dryrun_target) AS simulated_insert_rows
FROM resolved;

-- no=20: image rows per matched SKU.
WITH per_sku AS (
  SELECT
    sku_id,
    count(*) AS image_rows
  FROM product_image_dryrun_target
  GROUP BY sku_id
)
SELECT
  20 AS no,
  'MATCHED_SKU_IMAGE_ROWS' AS check_name,
  count(*) AS matched_skus_with_images,
  count(*) FILTER (WHERE image_rows = 1) AS skus_with_one_image,
  count(*) FILTER (WHERE image_rows > 1) AS skus_with_multiple_images,
  COALESCE(max(image_rows), 0) AS max_images_per_sku
FROM per_sku;

-- no=30: duplicate primary image check.
WITH primary_counts AS (
  SELECT
    sku_id,
    count(*) AS primary_rows
  FROM product_image_dryrun_target
  WHERE is_primary
  GROUP BY sku_id
)
SELECT
  30 AS no,
  'DUPLICATE_PRIMARY_IMAGE' AS check_name,
  count(*) FILTER (WHERE primary_rows > 1) AS duplicate_primary_image_skus,
  COALESCE(max(primary_rows), 0) AS max_primary_rows_per_sku
FROM primary_counts;

-- no=40: same image URL reused across multiple SKUs.
WITH per_image AS (
  SELECT
    image_url,
    count(DISTINCT sku_id) AS sku_count
  FROM product_image_dryrun_target
  GROUP BY image_url
)
SELECT
  40 AS no,
  'IMAGE_URL_REUSE' AS check_name,
  count(*) AS distinct_image_urls,
  count(*) FILTER (WHERE sku_count > 1) AS reused_image_url_count,
  COALESCE(max(sku_count), 0) AS max_skus_per_image_url
FROM per_image;

-- no=50: requested sample images.
SELECT
  50 AS no,
  'REQUESTED_SAMPLE' AS check_name,
  v.selfpia_sku_code,
  v.product_name,
  v.option_value,
  img.image_url,
  img.thumbnail_url
FROM product_code.v_sku_canonical v
LEFT JOIN product_image_dryrun_target img
  ON img.sku_id = v.sku_id
WHERE v.selfpia_sku_code IN ('1258-1', '1000-1', '11258-1', 'LOCAL_TEST_PM_1258-1')
ORDER BY v.selfpia_sku_code;

-- no=60: unmatched image row sample.
WITH normalized AS (
  SELECT
    NULLIF(btrim(p_code), '') AS p_code,
    NULLIF(btrim(image_url), '') AS image_url,
    NULLIF(btrim(updated_at), '') AS source_updated_at,
    NULLIF(btrim(own_code), '') AS own_code
  FROM product_image_import_stage
),
unmatched AS (
  SELECT n.*
  FROM normalized n
  LEFT JOIN product_code.code_alias ca
    ON ca.target_type = 'SKU'
   AND ca.code_system = 'selfpia_sku'
   AND ca.code_value = n.p_code
  WHERE n.image_url IS NOT NULL
    AND ca.target_id IS NULL
)
SELECT
  60 AS no,
  'SKIPPED_ORPHAN_IMAGE_SAMPLE' AS check_name,
  p_code,
  image_url,
  source_updated_at,
  own_code
FROM unmatched
ORDER BY p_code
LIMIT 10;

-- no=70: expected skipped orphan policy.
WITH normalized AS (
  SELECT
    NULLIF(btrim(p_code), '') AS p_code,
    NULLIF(btrim(image_url), '') AS image_url
  FROM product_image_import_stage
),
skipped AS (
  SELECT n.*
  FROM normalized n
  LEFT JOIN product_code.code_alias ca
    ON ca.target_type = 'SKU'
   AND ca.code_system = 'selfpia_sku'
   AND ca.code_value = n.p_code
  WHERE n.image_url IS NOT NULL
    AND ca.target_id IS NULL
)
SELECT
  70 AS no,
  'EXPECTED_SKIP_POLICY' AS check_name,
  count(*) AS skipped_orphan_image_rows,
  string_agg(p_code, ', ' ORDER BY p_code) AS skipped_p_codes,
  CASE
    WHEN count(*) = 1 AND bool_and(p_code = '8276-2') THEN 'PASS'
    ELSE 'REVIEW'
  END AS verdict
FROM skipped;

-- no=99: overall verdict.
WITH normalized AS (
  SELECT
    NULLIF(btrim(p_code), '') AS p_code,
    NULLIF(btrim(image_url), '') AS image_url
  FROM product_image_import_stage
),
resolved AS (
  SELECT
    n.*,
    ca.target_id AS sku_id
  FROM normalized n
  LEFT JOIN product_code.code_alias ca
    ON ca.target_type = 'SKU'
   AND ca.code_system = 'selfpia_sku'
   AND ca.code_value = n.p_code
),
counts AS (
  SELECT
    count(*) FILTER (WHERE image_url IS NOT NULL AND sku_id IS NULL) AS image_orphan_rows,
    count(*) FILTER (WHERE image_url IS NOT NULL AND sku_id IS NULL AND p_code = '8276-2') AS expected_skip_rows,
    (SELECT count(*)
     FROM (
       SELECT sku_id
       FROM product_image_dryrun_target
       WHERE is_primary
       GROUP BY sku_id
       HAVING count(*) > 1
     ) dup) AS duplicate_primary_image_skus,
    (SELECT count(*) FROM product_image_dryrun_target) AS ready_insert_rows
  FROM resolved
)
SELECT
  99 AS no,
  'OVERALL' AS check_name,
  CASE
    WHEN image_orphan_rows = 1
      AND expected_skip_rows = 1
      AND duplicate_primary_image_skus = 0
      AND ready_insert_rows > 0 THEN 'PASS'
    ELSE 'REVIEW'
  END AS verdict,
  image_orphan_rows,
  expected_skip_rows AS skipped_orphan_image_rows,
  duplicate_primary_image_skus,
  ready_insert_rows
FROM counts;

ROLLBACK;
