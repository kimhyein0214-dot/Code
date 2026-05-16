-- =============================================================================
-- export_product_code_selfpia_sku_alias_select_only.sql
--
-- Purpose:
--   Export Product_code selfpia_sku alias rows for cross mapping.
--
-- Execute only on:
--   Product_code Supabase project ref: mrqoqmidnrawflwezxlm
--   DB/schema: postgres/public
--
-- Output CSV:
--   selfpia_sku_alias.csv
--
-- Safety:
--   SELECT-only. Do not run CREATE / DROP / ALTER / INSERT / UPDATE / DELETE /
--   TRUNCATE / COPY server-side / staging creation on operating Supabase DB.
-- =============================================================================

-- 1) Context check. Confirm this is Product_code before exporting.
SELECT
  current_database() AS db,
  current_schema() AS schema_name,
  current_user AS user_name,
  now() AS checked_at,
  'Product_code / mrqoqmidnrawflwezxlm' AS expected_project;

-- 2) Export this result as selfpia_sku_alias.csv.
SELECT
  ca.code_value           AS selfpia_sku_code,
  ca.selfpia_product_code AS selfpia_product_code,
  ca.selfpia_option_no    AS selfpia_option_no,
  ca.target_id            AS sku_id,
  sm.virtual_sku_code     AS virtual_sku_code,
  sm.product_id           AS product_id,
  pm.virtual_product_code AS virtual_product_code,
  sm.option_value         AS option_value,
  sm.sku_type             AS sku_type,
  sm.status               AS sku_status,
  pm.product_name         AS product_name
FROM public.code_alias ca
JOIN public.sku_master sm
  ON sm.id = ca.target_id
JOIN public.product_master pm
  ON pm.id = sm.product_id
WHERE ca.code_system = 'selfpia_sku'
  AND ca.target_type = 'SKU'
ORDER BY ca.code_value;

