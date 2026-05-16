-- =============================================================================
-- local_seed_sample_validation.sql
--
-- LOCAL DOCKER ONLY.
-- Purpose:
--   Validate LOCAL_TEST seed rows and describe expected API endpoint results.
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
    RAISE EXCEPTION 'Local seed validation is allowed only on product_ops_test. Current database: %', current_database();
  END IF;
END
$$;

-- [S-1] Seed row counts
SELECT 'product_code.product_master' AS object_name, count(*) AS local_test_rows
FROM product_code.product_master
WHERE source_project_ref = 'LOCAL_TEST'
UNION ALL
SELECT 'product_code.sku_master', count(*)
FROM product_code.sku_master
WHERE source_project_ref = 'LOCAL_TEST'
UNION ALL
SELECT 'product_code.code_alias', count(*)
FROM product_code.code_alias
WHERE source_project_ref = 'LOCAL_TEST'
UNION ALL
SELECT 'picking.orders', count(*)
FROM picking.orders
WHERE source_project_ref = 'LOCAL_TEST'
UNION ALL
SELECT 'picking.order_items', count(*)
FROM picking.order_items
WHERE source_project_ref = 'LOCAL_TEST'
UNION ALL
SELECT 'stg.unmatched_order_items', count(*)
FROM stg.unmatched_order_items
WHERE raw_item_no LIKE 'LOCAL_TEST_%' OR raw_p_code LIKE 'LOCAL_TEST_%'
UNION ALL
SELECT 'stg.own_sku_match_candidates', count(*)
FROM stg.own_sku_match_candidates
WHERE raw_item_no LIKE 'LOCAL_TEST_%'
ORDER BY object_name;

-- [S-2] product_code.v_sku_canonical should return 2 LOCAL_TEST SKU rows
SELECT
  sku_id,
  selfpia_sku_code,
  selfpia_product_code,
  virtual_sku_code,
  product_name,
  option_value,
  sku_status
FROM product_code.v_sku_canonical
WHERE selfpia_sku_code LIKE 'LOCAL_TEST_%'
ORDER BY selfpia_sku_code;

-- [S-3] picking master match summary should include matched/unmatched/ambiguous/legacy_unmatched
SELECT *
FROM picking.v_order_items_master_match_summary
WHERE master_match_status IN ('matched', 'unmatched', 'ambiguous', 'legacy_unmatched')
ORDER BY master_match_status;

-- [S-4] picking unmatched view should include LOCAL_TEST unmatched states
SELECT
  raw_item_no,
  raw_p_code,
  p_name,
  master_match_status,
  master_match_note
FROM picking.v_order_items_unmatched
WHERE raw_item_no LIKE 'LOCAL_TEST_%'
ORDER BY master_match_status, raw_item_no;

-- [S-5] ambiguous own_sku candidates should include LOCAL_TEST_OWN_AMBIG
SELECT *
FROM stg.v_ambiguous_own_sku_candidates
WHERE own_sku_code = 'LOCAL_TEST_OWN_AMBIG';

-- [S-6] Expected API endpoint checks after seed
SELECT *
FROM (
  VALUES
    ('GET /product-code/skus?search=LOCAL_TEST', 'returns 2 LOCAL_TEST SKU rows'),
    ('GET /product-code/skus/LOCAL_TEST_1258-1', 'returns matched sample SKU 1'),
    ('GET /picking/order-items?master_match_status=matched', 'returns 2 matched LOCAL_TEST order items'),
    ('GET /picking/unmatched', 'returns unmatched / ambiguous / legacy_unmatched LOCAL_TEST rows'),
    ('GET /mapping/summary', 'returns matched, unmatched, ambiguous, legacy_unmatched counts'),
    ('GET /mapping/unmatched', 'returns LOCAL_TEST_NO_MASTER_001 and existing 9826-* rows'),
    ('GET /mapping/own-sku/ambiguous', 'returns LOCAL_TEST_OWN_AMBIG with two candidates')
) AS expected(endpoint, expected_result);

