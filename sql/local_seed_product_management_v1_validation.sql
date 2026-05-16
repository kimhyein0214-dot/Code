-- =============================================================================
-- local_seed_product_management_v1_validation.sql
--
-- LOCAL DOCKER ONLY.
-- Purpose:
--   Validate Product Management v1 LOCAL_TEST seed rows.
--
-- Allowed target:
--   Local Docker PostgreSQL database: product_ops_test
--
-- Forbidden targets:
--   Operating Supabase
--   Synology NAS PostgreSQL
-- =============================================================================

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'Product management v1 validation is allowed only on product_ops_test. Current database: %', current_database();
  END IF;
END
$$;

-- [PMV1-1] Seed row counts
SELECT 'product_code.product_master' AS object_name, count(*) AS local_test_rows
FROM product_code.product_master
WHERE source_table = 'local_seed_product_management_v1'
UNION ALL
SELECT 'product_code.sku_master', count(*)
FROM product_code.sku_master
WHERE source_table = 'local_seed_product_management_v1'
UNION ALL
SELECT 'product_code.code_alias', count(*)
FROM product_code.code_alias
WHERE source_table = 'local_seed_product_management_v1'
UNION ALL
SELECT 'product_code.sku_channel_mapping', count(*)
FROM product_code.sku_channel_mapping
WHERE id IN (910001, 910002)
UNION ALL
SELECT 'stg.own_sku_match_candidates', count(*)
FROM stg.own_sku_match_candidates
WHERE raw_item_no = 'LOCAL_TEST_PM_ITEM_AMBIG_001'
ORDER BY object_name;

-- [PMV1-2] SKU list/search base
SELECT
  sku_id,
  selfpia_sku_code,
  selfpia_product_code,
  virtual_sku_code,
  product_name,
  option_value,
  sku_status
FROM product_code.v_sku_canonical
WHERE selfpia_sku_code LIKE 'LOCAL_TEST_PM_%'
ORDER BY selfpia_sku_code;

-- [PMV1-3] Alias coverage
SELECT
  code_system,
  code_value,
  target_type,
  target_id,
  is_primary
FROM product_code.code_alias
WHERE source_table = 'local_seed_product_management_v1'
ORDER BY code_system, code_value;

-- [PMV1-4] Channel mapping coverage
SELECT
  sku_id,
  channel_code,
  channel_sku_code,
  seller_product_code,
  own_sku_code,
  is_primary
FROM product_code.sku_channel_mapping
WHERE id IN (910001, 910002)
ORDER BY id;

-- [PMV1-5] Ambiguous own_sku candidate coverage
SELECT *
FROM stg.v_ambiguous_own_sku_candidates
WHERE own_sku_code = 'LOCAL_TEST_PM_OWN_AMBIG';

-- [PMV1-6] Expected API checks
SELECT *
FROM (
  VALUES
    ('GET /api/products/skus?search=LOCAL_TEST_PM', 'returns 2 Product Management v1 SKU rows'),
    ('GET /api/products/skus/by-code/selfpia_sku/LOCAL_TEST_PM_1258-1', 'returns SKU 1'),
    ('GET /api/products/skus/by-code/own_sku/LOCAL_TEST_PM_OWN_AMBIG', 'returns 2 ambiguous candidates'),
    ('GET /api/products/skus/by-code/smartstore_option_no/LOCAL_TEST_SMARTSTORE_OPTION_001', 'returns SKU 1'),
    ('GET /api/products/search?q=LOCAL_TEST_SMARTSTORE_OPTION_001&type=channel_code', 'returns channel mapping result'),
    ('GET /api/products/change-requests', 'returns disabled placeholder'),
    ('GET /product-code/skus?search=LOCAL_TEST_PM', 'migration alias returns Product Management v1 rows')
) AS expected(endpoint, expected_result);
