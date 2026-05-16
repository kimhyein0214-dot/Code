-- =============================================================================
-- export_product_code_own_sku_alias_select_only.sql
--
-- Purpose:
--   Export Product_code own_sku alias rows for fallback candidate measurement.
--
-- Execute only on:
--   Product_code Supabase project ref: mrqoqmidnrawflwezxlm
--   DB/schema: postgres/public
--
-- Output CSV:
--   own_sku_alias.csv
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

-- 2) Export this result as own_sku_alias.csv.
SELECT
  ca.code_value            AS own_sku_code,
  ca.parsed_part1          AS parsed_part1,
  ca.parsed_part2          AS parsed_part2,
  ca.selfpia_product_code  AS hint_product_code,
  ca.selfpia_option_no     AS hint_option_no,
  ca.target_id             AS sku_id,
  ca.is_primary            AS is_primary
FROM public.code_alias ca
WHERE ca.code_system = 'own_sku'
  AND ca.target_type = 'SKU'
ORDER BY ca.code_value, ca.is_primary DESC, ca.target_id;

