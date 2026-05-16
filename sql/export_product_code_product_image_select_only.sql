-- =============================================================================
-- export_product_code_product_image_select_only.sql
--
-- Purpose:
--   SELECT-only draft for exporting product image rows from the operating source.
--
-- Safety:
--   * Read-only SELECT / \copy only.
--   * Do not run against local product_ops_test expecting data; local currently has
--     no product_code.product_image table.
--   * Do not run any write operation on operating Supabase.
--
-- Expected output:
--   outputs/product_image_export.csv
--
-- Notes:
--   Adjust table/schema names only after confirming the real operating
--   product_image structure. Keep the exported column names aligned with
--   stage_product_image_import.sql.
-- =============================================================================

\copy (
  SELECT
    NULLIF(sku_id::text, '') AS sku_id,
    NULLIF(product_id::text, '') AS product_id,
    NULLIF(selfpia_sku_code, '') AS selfpia_sku_code,
    NULLIF(selfpia_product_code, '') AS selfpia_product_code,
    image_url,
    NULLIF(thumbnail_url, '') AS thumbnail_url,
    COALESCE(sort_order, 0) AS sort_order,
    COALESCE(is_primary, false) AS is_primary,
    COALESCE(source, 'operating_product_image') AS source,
    COALESCE(raw_payload, '{}'::jsonb)::text AS raw_payload
  FROM product_code.product_image
  WHERE image_url IS NOT NULL
    AND btrim(image_url) <> ''
  ORDER BY
    COALESCE(selfpia_sku_code, ''),
    COALESCE(selfpia_product_code, ''),
    COALESCE(sort_order, 0),
    image_url
) TO 'outputs/product_image_export.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
