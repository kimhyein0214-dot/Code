-- =============================================================================
-- stage_product_image_import.sql
--
-- LOCAL DOCKER ONLY TEMP STAGE.
--
-- Purpose:
--   Load selfpia image CSV into a TEMP table and show normalized join readiness.
--
-- Expected container CSV:
--   /tmp/selfpia_image_url.csv
--
-- Expected CSV columns:
--   p_code,image_url,updated_at,own_code
--
-- This script uses TEMP TABLE only. It does not write persistent rows.
-- =============================================================================

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'product_image stage is allowed only on product_ops_test. Current database: %', current_database();
  END IF;
END
$$;

DROP TABLE IF EXISTS pg_temp.product_image_import_stage;

CREATE TEMP TABLE product_image_import_stage (
  p_code      text,
  image_url   text,
  updated_at  text,
  own_code    text
) ON COMMIT PRESERVE ROWS;

\copy product_image_import_stage (p_code, image_url, updated_at, own_code) FROM '/tmp/selfpia_image_url.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

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
    ca.selfpia_option_no,
    v.product_id,
    v.product_name,
    v.option_value
  FROM normalized n
  LEFT JOIN product_code.code_alias ca
    ON ca.target_type = 'SKU'
   AND ca.code_system = 'selfpia_sku'
   AND ca.code_value = n.p_code
  LEFT JOIN product_code.v_sku_canonical v
    ON v.sku_id = ca.target_id
   AND v.selfpia_sku_code = ca.code_value
)
SELECT
  count(*) AS staged_rows,
  count(*) FILTER (WHERE p_code IS NULL) AS blank_p_code_rows,
  count(*) FILTER (WHERE image_url IS NULL) AS blank_image_url_rows,
  count(*) FILTER (WHERE own_code IS NULL) AS blank_own_code_rows,
  count(*) FILTER (WHERE image_url IS NOT NULL AND sku_id IS NOT NULL) AS import_candidate_rows,
  count(*) FILTER (WHERE image_url IS NOT NULL AND sku_id IS NULL) AS image_rows_without_sku_match
FROM resolved;
