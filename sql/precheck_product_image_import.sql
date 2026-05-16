-- =============================================================================
-- precheck_product_image_import.sql
--
-- LOCAL DOCKER ONLY READ-ONLY CHECK.
--
-- Purpose:
--   Check local DB readiness before product_image schema/import work.
-- =============================================================================

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'product_image precheck is allowed only on product_ops_test. Current database: %', current_database();
  END IF;
END
$$;

SELECT
  current_database() AS database_name,
  to_regclass('product_code.product_image') AS product_image_table,
  to_regclass('product_code.v_sku_canonical') AS v_sku_canonical,
  to_regclass('product_code.sku_master') AS sku_master,
  to_regclass('product_code.product_master') AS product_master,
  to_regclass('product_code.code_alias') AS code_alias;

SELECT 'product_master' AS object_name, count(*) AS rows FROM product_code.product_master
UNION ALL
SELECT 'sku_master', count(*) FROM product_code.sku_master
UNION ALL
SELECT 'code_alias', count(*) FROM product_code.code_alias
UNION ALL
SELECT 'v_sku_canonical', count(*) FROM product_code.v_sku_canonical;

SELECT
  code_system,
  count(*) AS rows,
  count(DISTINCT code_value) AS distinct_code_values
FROM product_code.code_alias
WHERE code_system IN ('selfpia_sku', 'selfpia_product')
GROUP BY code_system
ORDER BY code_system;
