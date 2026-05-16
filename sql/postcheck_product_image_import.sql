-- =============================================================================
-- postcheck_product_image_import.sql
--
-- LOCAL DOCKER ONLY READ-ONLY POSTCHECK.
--
-- Purpose:
--   Verify product_image after a future approved local apply.
--   Safe to run before apply; it reports missing table as 0 rows.
-- =============================================================================

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'product_image postcheck is allowed only on product_ops_test. Current database: %', current_database();
  END IF;
END
$$;

SELECT
  to_regclass('product_code.product_image') AS product_image_table;

DROP TABLE IF EXISTS pg_temp.product_image_import_stage;

CREATE TEMP TABLE product_image_import_stage (
  p_code      text,
  image_url   text,
  updated_at  text,
  own_code    text
) ON COMMIT PRESERVE ROWS;

\copy product_image_import_stage (p_code, image_url, updated_at, own_code) FROM '/tmp/selfpia_image_url.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

CREATE TEMP TABLE product_image_postcheck (
  id                    bigint,
  sku_id                uuid,
  product_id            uuid,
  selfpia_sku_code      text,
  selfpia_product_code  text,
  image_url             text,
  thumbnail_url         text,
  source                text,
  is_primary            boolean,
  sort_order            integer,
  updated_at            text,
  created_at            timestamptz
) ON COMMIT PRESERVE ROWS;

DO $$
BEGIN
  IF to_regclass('product_code.product_image') IS NULL THEN
    RAISE NOTICE 'product_code.product_image does not exist yet. Nothing to postcheck.';
  ELSE
    EXECUTE $sql$
      INSERT INTO product_image_postcheck (
        id,
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
        created_at
      )
      SELECT
        id,
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
        created_at
      FROM product_code.product_image
    $sql$;
  END IF;
END
$$;

SELECT
  10 AS no,
  'IMAGE_TABLE_COUNTS' AS check_name,
  count(*) AS image_rows,
  count(*) FILTER (WHERE is_primary) AS primary_rows,
  count(*) FILTER (WHERE thumbnail_url IS NOT NULL) AS thumbnail_rows,
  count(DISTINCT sku_id) FILTER (WHERE sku_id IS NOT NULL) AS sku_ids_with_images,
  count(DISTINCT product_id) FILTER (WHERE product_id IS NOT NULL) AS product_ids_with_images
FROM product_image_postcheck;

WITH primary_counts AS (
  SELECT
    sku_id,
    count(*) AS primary_rows
  FROM product_image_postcheck
  WHERE is_primary
  GROUP BY sku_id
)
SELECT
  20 AS no,
  'DUPLICATE_PRIMARY_IMAGE' AS check_name,
  count(*) FILTER (WHERE primary_rows > 1) AS duplicate_primary_image_skus,
  COALESCE(max(primary_rows), 0) AS max_primary_rows_per_sku
FROM primary_counts;

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
  25 AS no,
  'SKIPPED_ORPHAN_SOURCE_ROWS' AS check_name,
  count(*) AS skipped_orphan_image_rows,
  string_agg(p_code, ', ' ORDER BY p_code) AS skipped_p_codes,
  CASE
    WHEN count(*) = 1 AND bool_and(p_code = '8276-2') THEN 'PASS'
    ELSE 'REVIEW'
  END AS verdict
FROM skipped;

SELECT
  30 AS no,
  'SAMPLE_SKU_IMAGES' AS check_name,
  v.selfpia_sku_code,
  v.product_name,
  v.option_value,
  img.thumbnail_url,
  img.image_url
FROM product_code.v_sku_canonical v
LEFT JOIN LATERAL (
  SELECT
    pi.thumbnail_url,
    pi.image_url
  FROM product_image_postcheck pi
  WHERE pi.sku_id = v.sku_id
     OR pi.selfpia_sku_code = v.selfpia_sku_code
     OR pi.product_id = v.product_id
     OR pi.selfpia_product_code = v.selfpia_product_code
  ORDER BY
    (pi.sku_id = v.sku_id) DESC,
    (pi.selfpia_sku_code = v.selfpia_sku_code) DESC,
    pi.is_primary DESC,
    pi.sort_order,
    pi.id
  LIMIT 1
) img ON true
WHERE v.selfpia_sku_code IN ('1258-1', '1000-1', '11258-1', 'LOCAL_TEST_PM_1258-1')
ORDER BY v.selfpia_sku_code;

WITH sample AS (
  SELECT
    v.selfpia_sku_code,
    img.image_url
  FROM product_code.v_sku_canonical v
  LEFT JOIN LATERAL (
    SELECT
      pi.image_url
    FROM product_image_postcheck pi
    WHERE pi.sku_id = v.sku_id
       OR pi.selfpia_sku_code = v.selfpia_sku_code
    ORDER BY
      (pi.sku_id = v.sku_id) DESC,
      (pi.selfpia_sku_code = v.selfpia_sku_code) DESC,
      pi.is_primary DESC,
      pi.sort_order,
      pi.id
    LIMIT 1
  ) img ON true
  WHERE v.selfpia_sku_code IN ('1258-1', '1000-1', '11258-1', 'LOCAL_TEST_PM_1258-1')
),
summary AS (
  SELECT
    (SELECT count(*) FROM product_image_postcheck) AS image_rows,
    (SELECT count(*)
     FROM (
       SELECT sku_id
       FROM product_image_postcheck
       WHERE is_primary
       GROUP BY sku_id
       HAVING count(*) > 1
     ) dup) AS duplicate_primary_image_skus,
    count(*) FILTER (WHERE selfpia_sku_code IN ('1000-1', '1258-1') AND image_url IS NOT NULL) AS expected_present_samples,
    count(*) FILTER (WHERE selfpia_sku_code IN ('11258-1', 'LOCAL_TEST_PM_1258-1') AND image_url IS NULL) AS expected_null_samples
  FROM sample
)
SELECT
  99 AS no,
  'POSTCHECK_OVERALL' AS check_name,
  CASE
    WHEN image_rows = 19331
      AND duplicate_primary_image_skus = 0
      AND expected_present_samples = 2
      AND expected_null_samples = 2 THEN 'PASS'
    ELSE 'REVIEW'
  END AS verdict,
  image_rows,
  duplicate_primary_image_skus,
  expected_present_samples,
  expected_null_samples
FROM summary;
