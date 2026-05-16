-- =============================================================================
-- local_seed_product_management_v1.sql
--
-- LOCAL DOCKER ONLY.
-- Purpose:
--   Extend LOCAL_TEST sample data for Product Management v1 read-only UI/API.
--
-- Allowed target:
--   Local Docker PostgreSQL database: product_ops_test
--
-- Forbidden targets:
--   Operating Supabase
--   Synology NAS PostgreSQL
--
-- Notes:
--   * All sample business values use LOCAL_TEST_ markers.
--   * This is not real operating data.
--   * This script is idempotent.
-- =============================================================================

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'Product management v1 seed is allowed only on product_ops_test. Current database: %', current_database();
  END IF;
END
$$;

BEGIN;

WITH constants AS (
  SELECT
    '11111111-1111-4111-8111-111111111111'::uuid AS product_id,
    '22222222-2222-4222-8222-222222222221'::uuid AS sku_id_1,
    '22222222-2222-4222-8222-222222222222'::uuid AS sku_id_2
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
  'LOCAL_TEST_VPRD_PRODUCT_MGMT_V1',
  'LOCAL_TEST_PRODUCT product management v1 seed',
  'LOCAL_TEST_ACTIVE',
  '{"seed": true, "module": "product_management_v1"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_product_management_v1'
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
  'LOCAL_TEST_VSKU_PRODUCT_MGMT_001',
  'LOCAL_TEST_OPTION_PRODUCT_MGMT_SILVER',
  'LOCAL_TEST_SINGLE',
  'LOCAL_TEST_ACTIVE',
  '{"seed": true, "module": "product_management_v1", "sample": "sku_1"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_product_management_v1'
FROM constants
UNION ALL
SELECT
  sku_id_2,
  product_id,
  'LOCAL_TEST_VSKU_PRODUCT_MGMT_002',
  'LOCAL_TEST_OPTION_PRODUCT_MGMT_GOLD',
  'LOCAL_TEST_SINGLE',
  'LOCAL_TEST_ACTIVE',
  '{"seed": true, "module": "product_management_v1", "sample": "sku_2"}'::jsonb,
  'LOCAL_TEST',
  'local_seed_product_management_v1'
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
    '11111111-1111-4111-8111-111111111111'::uuid AS product_id,
    '22222222-2222-4222-8222-222222222221'::uuid AS sku_id_1,
    '22222222-2222-4222-8222-222222222222'::uuid AS sku_id_2
),
alias_rows AS (
  SELECT
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbb0001'::uuid AS id,
    'SKU'::text AS target_type,
    sku_id_1 AS target_id,
    'selfpia_sku'::text AS code_system,
    'LOCAL_TEST_PM_1258-1'::text AS code_value,
    'LOCAL_TEST_PM_1258'::text AS selfpia_product_code,
    '1'::text AS selfpia_option_no,
    true AS is_primary,
    '{"seed": true, "module": "product_management_v1", "sample": "selfpia_sku_1"}'::jsonb AS raw_payload
  FROM constants
  UNION ALL
  SELECT
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbb0002'::uuid,
    'SKU',
    sku_id_2,
    'selfpia_sku',
    'LOCAL_TEST_PM_1258-2',
    'LOCAL_TEST_PM_1258',
    '2',
    true,
    '{"seed": true, "module": "product_management_v1", "sample": "selfpia_sku_2"}'::jsonb
  FROM constants
  UNION ALL
  SELECT
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbb0003'::uuid,
    'PRODUCT',
    product_id,
    'selfpia_product',
    'LOCAL_TEST_PM_1258',
    'LOCAL_TEST_PM_1258',
    NULL,
    true,
    '{"seed": true, "module": "product_management_v1", "sample": "selfpia_product"}'::jsonb
  FROM constants
  UNION ALL
  SELECT
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbb0004'::uuid,
    'SKU',
    sku_id_1,
    'own_sku',
    'LOCAL_TEST_PM_OWN_001',
    'LOCAL_TEST_PM_1258',
    '1',
    true,
    '{"seed": true, "module": "product_management_v1", "sample": "own_sku_unique"}'::jsonb
  FROM constants
  UNION ALL
  SELECT
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbb0005'::uuid,
    'SKU',
    sku_id_1,
    'smartstore_option_no',
    'LOCAL_TEST_SMARTSTORE_OPTION_001',
    'LOCAL_TEST_PM_1258',
    '1',
    false,
    '{"seed": true, "module": "product_management_v1", "sample": "smartstore_option"}'::jsonb
  FROM constants
  UNION ALL
  SELECT
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbb0006'::uuid,
    'SKU',
    sku_id_1,
    'own_sku',
    'LOCAL_TEST_PM_OWN_AMBIG',
    'LOCAL_TEST_PM_1258',
    '1',
    false,
    '{"seed": true, "module": "product_management_v1", "sample": "ambiguous_candidate_1"}'::jsonb
  FROM constants
  UNION ALL
  SELECT
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbb0007'::uuid,
    'SKU',
    sku_id_2,
    'own_sku',
    'LOCAL_TEST_PM_OWN_AMBIG',
    'LOCAL_TEST_PM_1258',
    '2',
    false,
    '{"seed": true, "module": "product_management_v1", "sample": "ambiguous_candidate_2"}'::jsonb
  FROM constants
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
  id,
  target_type,
  target_id,
  code_system,
  code_value,
  selfpia_product_code,
  selfpia_option_no,
  is_primary,
  raw_payload,
  'LOCAL_TEST',
  'local_seed_product_management_v1'
FROM alias_rows
ON CONFLICT (code_system, code_value, target_type, target_id) DO UPDATE
SET
  selfpia_product_code = EXCLUDED.selfpia_product_code,
  selfpia_option_no = EXCLUDED.selfpia_option_no,
  is_primary = EXCLUDED.is_primary,
  raw_payload = EXCLUDED.raw_payload,
  source_project_ref = EXCLUDED.source_project_ref,
  source_table = EXCLUDED.source_table,
  updated_at = now();

WITH constants AS (
  SELECT
    '22222222-2222-4222-8222-222222222221'::uuid AS sku_id_1,
    '22222222-2222-4222-8222-222222222222'::uuid AS sku_id_2
)
INSERT INTO product_code.sku_channel_mapping (
  id,
  sku_id,
  channel_code,
  channel_sku_code,
  seller_product_code,
  own_sku_code,
  is_primary,
  raw_payload
)
SELECT
  910001,
  sku_id_1,
  'LOCAL_TEST_SMARTSTORE',
  'LOCAL_TEST_SMARTSTORE_OPTION_001',
  'LOCAL_TEST_SMARTSTORE_PRODUCT_001',
  'LOCAL_TEST_PM_OWN_001',
  true,
  '{"seed": true, "module": "product_management_v1", "sample": "channel_mapping_1"}'::jsonb
FROM constants
UNION ALL
SELECT
  910002,
  sku_id_2,
  'LOCAL_TEST_SMARTSTORE',
  'LOCAL_TEST_SMARTSTORE_OPTION_002',
  'LOCAL_TEST_SMARTSTORE_PRODUCT_001',
  'LOCAL_TEST_PM_OWN_AMBIG',
  false,
  '{"seed": true, "module": "product_management_v1", "sample": "channel_mapping_2"}'::jsonb
FROM constants
ON CONFLICT (id) DO UPDATE
SET
  sku_id = EXCLUDED.sku_id,
  channel_code = EXCLUDED.channel_code,
  channel_sku_code = EXCLUDED.channel_sku_code,
  seller_product_code = EXCLUDED.seller_product_code,
  own_sku_code = EXCLUDED.own_sku_code,
  is_primary = EXCLUDED.is_primary,
  raw_payload = EXCLUDED.raw_payload,
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
  'LOCAL_TEST_PM_ITEM_AMBIG_001',
  'LOCAL_TEST_PM_OWN_AMBIG',
  sku_id_1,
  'LOCAL_TEST_PM_1258-1',
  false,
  1
FROM constants
WHERE NOT EXISTS (
  SELECT 1
  FROM stg.own_sku_match_candidates
  WHERE raw_item_no = 'LOCAL_TEST_PM_ITEM_AMBIG_001'
    AND own_sku_code = 'LOCAL_TEST_PM_OWN_AMBIG'
    AND candidate_sku_id = sku_id_1
)
UNION ALL
SELECT
  'LOCAL_TEST_PM_ITEM_AMBIG_001',
  'LOCAL_TEST_PM_OWN_AMBIG',
  sku_id_2,
  'LOCAL_TEST_PM_1258-2',
  false,
  2
FROM constants
WHERE NOT EXISTS (
  SELECT 1
  FROM stg.own_sku_match_candidates
  WHERE raw_item_no = 'LOCAL_TEST_PM_ITEM_AMBIG_001'
    AND own_sku_code = 'LOCAL_TEST_PM_OWN_AMBIG'
    AND candidate_sku_id = sku_id_2
);

COMMIT;

-- =============================================================================
-- Local reset section (destructive, local only, intentionally commented)
--
-- Run only on product_ops_test after checking current_database().
-- Never run on operating Supabase or NAS.
--
-- DELETE FROM stg.own_sku_match_candidates WHERE raw_item_no LIKE 'LOCAL_TEST_PM_%';
-- DELETE FROM product_code.sku_channel_mapping WHERE id IN (910001, 910002);
-- DELETE FROM product_code.code_alias WHERE source_table = 'local_seed_product_management_v1';
-- DELETE FROM product_code.sku_master WHERE source_table = 'local_seed_product_management_v1';
-- DELETE FROM product_code.product_master WHERE source_table = 'local_seed_product_management_v1';
-- =============================================================================
