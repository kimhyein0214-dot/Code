-- =============================================================================
-- local_seed_sample_data.sql
--
-- LOCAL DOCKER ONLY.
-- Purpose:
--   Insert minimal LOCAL_TEST sample rows so API endpoints return actual rows.
--
-- Allowed target:
--   Local Docker PostgreSQL database: product_ops_test
--
-- Forbidden targets:
--   Operating Supabase
--   Synology NAS PostgreSQL
--
-- Notes:
--   * All sample values use LOCAL_TEST_ / TEST_ markers.
--   * This is not real operating data.
--   * Do not load full production data with this script.
-- =============================================================================

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'Local seed is allowed only on product_ops_test. Current database: %', current_database();
  END IF;
END
$$;

BEGIN;

-- Fixed UUIDs make this script idempotent and easy to inspect.
WITH constants AS (
  SELECT
    '11111111-1111-4111-8111-111111111111'::uuid AS product_id,
    '22222222-2222-4222-8222-222222222221'::uuid AS sku_id_1,
    '22222222-2222-4222-8222-222222222222'::uuid AS sku_id_2,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'::uuid AS alias_id_1,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'::uuid AS alias_id_2,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaab1'::uuid AS own_alias_id_1,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaab2'::uuid AS own_alias_id_2
)
INSERT INTO product_code.product_master (
  id,
  virtual_product_code,
  product_name,
  status,
  raw_payload,
  source_project_ref,
  source_table
)
SELECT
  product_id,
  'LOCAL_TEST_VPRD_0001',
  'LOCAL_TEST_PRODUCT API seed product',
  'LOCAL_TEST_ACTIVE',
  '{"seed": true, "purpose": "api_row_return_test"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_sample_data'
FROM constants
ON CONFLICT (id) DO UPDATE
SET
  virtual_product_code = EXCLUDED.virtual_product_code,
  product_name = EXCLUDED.product_name,
  status = EXCLUDED.status,
  raw_payload = EXCLUDED.raw_payload,
  source_project_ref = EXCLUDED.source_project_ref,
  source_table = EXCLUDED.source_table,
  updated_at = now();

WITH constants AS (
  SELECT
    '11111111-1111-4111-8111-111111111111'::uuid AS product_id,
    '22222222-2222-4222-8222-222222222221'::uuid AS sku_id_1,
    '22222222-2222-4222-8222-222222222222'::uuid AS sku_id_2
)
INSERT INTO product_code.sku_master (
  id,
  product_id,
  virtual_sku_code,
  option_value,
  sku_type,
  status,
  raw_payload,
  source_project_ref,
  source_table
)
SELECT
  sku_id_1,
  product_id,
  'LOCAL_TEST_VSKU_0001',
  'LOCAL_TEST_OPTION silver',
  'LOCAL_TEST_SINGLE',
  'LOCAL_TEST_ACTIVE',
  '{"seed": true, "sample": "matched_1"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_sample_data'
FROM constants
UNION ALL
SELECT
  sku_id_2,
  product_id,
  'LOCAL_TEST_VSKU_0002',
  'LOCAL_TEST_OPTION gold',
  'LOCAL_TEST_SINGLE',
  'LOCAL_TEST_ACTIVE',
  '{"seed": true, "sample": "matched_2"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_sample_data'
FROM constants
ON CONFLICT (id) DO UPDATE
SET
  product_id = EXCLUDED.product_id,
  virtual_sku_code = EXCLUDED.virtual_sku_code,
  option_value = EXCLUDED.option_value,
  sku_type = EXCLUDED.sku_type,
  status = EXCLUDED.status,
  raw_payload = EXCLUDED.raw_payload,
  source_project_ref = EXCLUDED.source_project_ref,
  source_table = EXCLUDED.source_table,
  updated_at = now();

WITH constants AS (
  SELECT
    '22222222-2222-4222-8222-222222222221'::uuid AS sku_id_1,
    '22222222-2222-4222-8222-222222222222'::uuid AS sku_id_2,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'::uuid AS alias_id_1,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'::uuid AS alias_id_2,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaab1'::uuid AS own_alias_id_1,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaab2'::uuid AS own_alias_id_2
)
INSERT INTO product_code.code_alias (
  id,
  target_type,
  target_id,
  code_system,
  code_value,
  selfpia_product_code,
  selfpia_option_no,
  is_primary,
  raw_payload,
  source_project_ref,
  source_table
)
SELECT
  alias_id_1,
  'SKU',
  sku_id_1,
  'selfpia_sku',
  'LOCAL_TEST_1258-1',
  'LOCAL_TEST_1258',
  '1',
  true,
  '{"seed": true, "sample": "matched_1"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_sample_data'
FROM constants
UNION ALL
SELECT
  alias_id_2,
  'SKU',
  sku_id_2,
  'selfpia_sku',
  'LOCAL_TEST_1258-2',
  'LOCAL_TEST_1258',
  '2',
  true,
  '{"seed": true, "sample": "matched_2"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_sample_data'
FROM constants
UNION ALL
SELECT
  own_alias_id_1,
  'SKU',
  sku_id_1,
  'own_sku',
  'LOCAL_TEST_OWN_AMBIG',
  'LOCAL_TEST_1258',
  '1',
  false,
  '{"seed": true, "sample": "ambiguous_candidate_1"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_sample_data'
FROM constants
UNION ALL
SELECT
  own_alias_id_2,
  'SKU',
  sku_id_2,
  'own_sku',
  'LOCAL_TEST_OWN_AMBIG',
  'LOCAL_TEST_1258',
  '2',
  false,
  '{"seed": true, "sample": "ambiguous_candidate_2"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_sample_data'
FROM constants
ON CONFLICT (id) DO UPDATE
SET
  target_type = EXCLUDED.target_type,
  target_id = EXCLUDED.target_id,
  code_system = EXCLUDED.code_system,
  code_value = EXCLUDED.code_value,
  selfpia_product_code = EXCLUDED.selfpia_product_code,
  selfpia_option_no = EXCLUDED.selfpia_option_no,
  is_primary = EXCLUDED.is_primary,
  raw_payload = EXCLUDED.raw_payload,
  source_project_ref = EXCLUDED.source_project_ref,
  source_table = EXCLUDED.source_table,
  updated_at = now();

INSERT INTO picking.orders (
  order_id,
  raw_ord_no,
  inv_no,
  channel_code,
  ordered_at,
  order_date,
  order_status,
  cs_status,
  buyer_name,
  raw_payload,
  source_project_ref,
  source_table
)
VALUES
  (
    'LOCAL_TEST_ORDER_0001',
    'LOCAL_TEST_ORD_0001',
    'LOCAL_TEST_INV_0001',
    'LOCAL_TEST_CHANNEL',
    now(),
    current_date,
    'LOCAL_TEST_READY',
    'LOCAL_TEST_NONE',
    'LOCAL_TEST_BUYER',
    '{"seed": true, "purpose": "api_row_return_test"}'::jsonb,
    'LOCAL_TEST',
    'local_seed_sample_data'
  )
ON CONFLICT (order_id) DO UPDATE
SET
  raw_ord_no = EXCLUDED.raw_ord_no,
  inv_no = EXCLUDED.inv_no,
  channel_code = EXCLUDED.channel_code,
  ordered_at = EXCLUDED.ordered_at,
  order_date = EXCLUDED.order_date,
  order_status = EXCLUDED.order_status,
  cs_status = EXCLUDED.cs_status,
  buyer_name = EXCLUDED.buyer_name,
  raw_payload = EXCLUDED.raw_payload,
  source_project_ref = EXCLUDED.source_project_ref,
  source_table = EXCLUDED.source_table,
  updated_at = now();

WITH constants AS (
  SELECT
    '22222222-2222-4222-8222-222222222221'::uuid AS sku_id_1,
    '22222222-2222-4222-8222-222222222222'::uuid AS sku_id_2
)
INSERT INTO picking.order_items (
  raw_item_no,
  order_id,
  raw_ord_no,
  inv_no,
  line_no,
  raw_p_code,
  raw_p_dpcode,
  raw_prod_code,
  p_dpcode_clean,
  prod_code_clean,
  p_name,
  p_option,
  qty_ordered,
  order_item_status,
  sku_id,
  selfpia_sku_code,
  master_match_status,
  master_match_note,
  matched_at,
  raw_payload,
  source_project_ref,
  source_table
)
SELECT
  'LOCAL_TEST_ITEM_MATCHED_001',
  'LOCAL_TEST_ORDER_0001',
  'LOCAL_TEST_ORD_0001',
  'LOCAL_TEST_INV_0001',
  1,
  'LOCAL_TEST_1258-1',
  '[LOCAL_TEST_OWN_001]',
  '[LOCAL_TEST_OWN_001]',
  'LOCAL_TEST_OWN_001',
  'LOCAL_TEST_OWN_001',
  'LOCAL_TEST_PRODUCT API seed product',
  'LOCAL_TEST_OPTION silver',
  1,
  'LOCAL_TEST_READY',
  sku_id_1,
  'LOCAL_TEST_1258-1',
  'matched',
  'LOCAL_TEST matched sample row 1',
  now(),
  '{"seed": true, "sample": "matched_1"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_sample_data'
FROM constants
UNION ALL
SELECT
  'LOCAL_TEST_ITEM_MATCHED_002',
  'LOCAL_TEST_ORDER_0001',
  'LOCAL_TEST_ORD_0001',
  'LOCAL_TEST_INV_0001',
  2,
  'LOCAL_TEST_1258-2',
  '[LOCAL_TEST_OWN_002]',
  '[LOCAL_TEST_OWN_002]',
  'LOCAL_TEST_OWN_002',
  'LOCAL_TEST_OWN_002',
  'LOCAL_TEST_PRODUCT API seed product',
  'LOCAL_TEST_OPTION gold',
  2,
  'LOCAL_TEST_READY',
  sku_id_2,
  'LOCAL_TEST_1258-2',
  'matched',
  'LOCAL_TEST matched sample row 2',
  now(),
  '{"seed": true, "sample": "matched_2"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_sample_data'
FROM constants
UNION ALL
SELECT
  'LOCAL_TEST_ITEM_UNMATCHED_001',
  'LOCAL_TEST_ORDER_0001',
  'LOCAL_TEST_ORD_0001',
  'LOCAL_TEST_INV_0001',
  3,
  'LOCAL_TEST_NO_MASTER_001',
  '[LOCAL_TEST_NO_MASTER]',
  '[LOCAL_TEST_NO_MASTER]',
  'LOCAL_TEST_NO_MASTER',
  'LOCAL_TEST_NO_MASTER',
  'LOCAL_TEST unmatched sample product',
  'LOCAL_TEST unmatched option',
  1,
  'LOCAL_TEST_READY',
  NULL,
  NULL,
  'unmatched',
  'LOCAL_TEST no master candidate sample',
  NULL,
  '{"seed": true, "sample": "unmatched"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_sample_data'
FROM constants
UNION ALL
SELECT
  'LOCAL_TEST_ITEM_AMBIG_001',
  'LOCAL_TEST_ORDER_0001',
  'LOCAL_TEST_ORD_0001',
  'LOCAL_TEST_INV_0001',
  4,
  'LOCAL_TEST_AMBIG_001',
  '[LOCAL_TEST_OWN_AMBIG]',
  '[LOCAL_TEST_OWN_AMBIG]',
  'LOCAL_TEST_OWN_AMBIG',
  'LOCAL_TEST_OWN_AMBIG',
  'LOCAL_TEST ambiguous own_sku sample product',
  'LOCAL_TEST ambiguous option',
  1,
  'LOCAL_TEST_READY',
  NULL,
  NULL,
  'ambiguous',
  'LOCAL_TEST own_sku has multiple candidates',
  NULL,
  '{"seed": true, "sample": "ambiguous"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_sample_data'
FROM constants
UNION ALL
SELECT
  'LOCAL_TEST_ITEM_LEGACY_001',
  'LOCAL_TEST_ORDER_0001',
  'LOCAL_TEST_ORD_0001',
  'LOCAL_TEST_INV_0001',
  5,
  'LOCAL_TEST_9826-1',
  '[LOCAL_TEST_LEGACY]',
  '[LOCAL_TEST_LEGACY]',
  'LOCAL_TEST_LEGACY',
  'LOCAL_TEST_LEGACY',
  'LOCAL_TEST legacy unmatched shipped product',
  'LOCAL_TEST legacy option',
  1,
  'LOCAL_TEST_SHIPPED',
  NULL,
  NULL,
  'legacy_unmatched',
  'LOCAL_TEST historical shipped row without master',
  NULL,
  '{"seed": true, "sample": "legacy_unmatched"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_sample_data'
FROM constants
ON CONFLICT (raw_item_no) DO UPDATE
SET
  order_id = EXCLUDED.order_id,
  raw_ord_no = EXCLUDED.raw_ord_no,
  inv_no = EXCLUDED.inv_no,
  line_no = EXCLUDED.line_no,
  raw_p_code = EXCLUDED.raw_p_code,
  raw_p_dpcode = EXCLUDED.raw_p_dpcode,
  raw_prod_code = EXCLUDED.raw_prod_code,
  p_dpcode_clean = EXCLUDED.p_dpcode_clean,
  prod_code_clean = EXCLUDED.prod_code_clean,
  p_name = EXCLUDED.p_name,
  p_option = EXCLUDED.p_option,
  qty_ordered = EXCLUDED.qty_ordered,
  order_item_status = EXCLUDED.order_item_status,
  sku_id = EXCLUDED.sku_id,
  selfpia_sku_code = EXCLUDED.selfpia_sku_code,
  master_match_status = EXCLUDED.master_match_status,
  master_match_note = EXCLUDED.master_match_note,
  matched_at = EXCLUDED.matched_at,
  raw_payload = EXCLUDED.raw_payload,
  source_project_ref = EXCLUDED.source_project_ref,
  source_table = EXCLUDED.source_table,
  updated_at = now();

WITH constants AS (
  SELECT
    '22222222-2222-4222-8222-222222222221'::uuid AS sku_id_1,
    '22222222-2222-4222-8222-222222222222'::uuid AS sku_id_2
)
INSERT INTO stg.own_sku_match_candidates (
  raw_item_no,
  own_sku_code,
  candidate_sku_id,
  candidate_selfpia_sku_code,
  is_primary,
  candidate_rank
)
SELECT
  'LOCAL_TEST_ITEM_AMBIG_001',
  'LOCAL_TEST_OWN_AMBIG',
  sku_id_1,
  'LOCAL_TEST_1258-1',
  false,
  1
FROM constants
WHERE NOT EXISTS (
  SELECT 1
  FROM stg.own_sku_match_candidates
  WHERE raw_item_no = 'LOCAL_TEST_ITEM_AMBIG_001'
    AND own_sku_code = 'LOCAL_TEST_OWN_AMBIG'
    AND candidate_sku_id = sku_id_1
)
UNION ALL
SELECT
  'LOCAL_TEST_ITEM_AMBIG_001',
  'LOCAL_TEST_OWN_AMBIG',
  sku_id_2,
  'LOCAL_TEST_1258-2',
  false,
  2
FROM constants
WHERE NOT EXISTS (
  SELECT 1
  FROM stg.own_sku_match_candidates
  WHERE raw_item_no = 'LOCAL_TEST_ITEM_AMBIG_001'
    AND own_sku_code = 'LOCAL_TEST_OWN_AMBIG'
    AND candidate_sku_id = sku_id_2
);

INSERT INTO stg.unmatched_order_items (
  raw_item_no,
  raw_ord_no,
  inv_no,
  raw_p_code,
  raw_p_dpcode,
  raw_prod_code,
  p_dpcode_clean,
  prod_code_clean,
  p_name,
  p_option,
  qty_ordered,
  order_item_status,
  unmatched_reason,
  suggested_action,
  raw_payload
)
SELECT
  'LOCAL_TEST_ITEM_UNMATCHED_001',
  'LOCAL_TEST_ORD_0001',
  'LOCAL_TEST_INV_0001',
  'LOCAL_TEST_NO_MASTER_001',
  '[LOCAL_TEST_NO_MASTER]',
  '[LOCAL_TEST_NO_MASTER]',
  'LOCAL_TEST_NO_MASTER',
  'LOCAL_TEST_NO_MASTER',
  'LOCAL_TEST unmatched sample product',
  'LOCAL_TEST unmatched option',
  1,
  'LOCAL_TEST_READY',
  'LOCAL_TEST_NO_MASTER',
  'LOCAL_TEST review or create Product_code master mapping',
  '{"seed": true, "sample": "unmatched"}'::jsonb
WHERE NOT EXISTS (
  SELECT 1
  FROM stg.unmatched_order_items
  WHERE raw_item_no = 'LOCAL_TEST_ITEM_UNMATCHED_001'
    AND raw_p_code = 'LOCAL_TEST_NO_MASTER_001'
);

COMMIT;

-- =============================================================================
-- Local reset section (destructive, local only, intentionally commented)
--
-- Run only on product_ops_test after checking current_database().
-- Never run on operating Supabase or NAS.
--
-- DELETE FROM stg.own_sku_match_candidates WHERE raw_item_no LIKE 'LOCAL_TEST_%';
-- DELETE FROM stg.unmatched_order_items WHERE raw_item_no LIKE 'LOCAL_TEST_%' OR raw_p_code LIKE 'LOCAL_TEST_%';
-- DELETE FROM picking.order_items WHERE raw_item_no LIKE 'LOCAL_TEST_%';
-- DELETE FROM picking.orders WHERE order_id LIKE 'LOCAL_TEST_%';
-- DELETE FROM product_code.code_alias WHERE source_project_ref = 'LOCAL_TEST';
-- DELETE FROM product_code.sku_master WHERE source_project_ref = 'LOCAL_TEST';
-- DELETE FROM product_code.product_master WHERE source_project_ref = 'LOCAL_TEST';
-- =============================================================================
