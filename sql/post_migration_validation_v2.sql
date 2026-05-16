-- =============================================================================
-- post_migration_validation_v2.sql
--
-- Purpose:
--   SELECT-only validation for schema v2 after local Docker migration/load tests.
--
-- Execute only after:
--   schema_nas_postgresql_draft_v2.sql has been applied to local Docker DB.
--
-- Safety:
--   SELECT-only. Do not run on operating Supabase. NAS execution is deferred
--   until after local validation and explicit approval.
-- =============================================================================

-- [V2-0] Context
SELECT
  current_database() AS db,
  current_user AS user_name,
  version() AS pg_version,
  now() AS checked_at;

-- [V2-1] Required schemas
SELECT nspname
FROM pg_namespace
WHERE nspname IN ('product_code', 'picking', 'inspection', 'cs', 'audit', 'stg')
ORDER BY 1;

-- [V2-2] Required tables/views
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema IN ('product_code', 'picking', 'inspection', 'cs', 'audit', 'stg')
ORDER BY table_schema, table_name;

-- [V2-3] Row count overview
SELECT 'product_code.product_master' AS object_name, count(*) AS rows FROM product_code.product_master
UNION ALL SELECT 'product_code.sku_master', count(*) FROM product_code.sku_master
UNION ALL SELECT 'product_code.code_alias', count(*) FROM product_code.code_alias
UNION ALL SELECT 'picking.orders', count(*) FROM picking.orders
UNION ALL SELECT 'picking.order_items', count(*) FROM picking.order_items
UNION ALL SELECT 'picking.picking_tasks', count(*) FROM picking.picking_tasks
UNION ALL SELECT 'picking.shortage', count(*) FROM picking.shortage
UNION ALL SELECT 'picking.hold_items', count(*) FROM picking.hold_items
UNION ALL SELECT 'inspection.inspections', count(*) FROM inspection.inspections
UNION ALL SELECT 'cs.templates', count(*) FROM cs.templates
UNION ALL SELECT 'cs.tickets', count(*) FROM cs.tickets
UNION ALL SELECT 'stg.unmatched_order_items', count(*) FROM stg.unmatched_order_items
UNION ALL SELECT 'stg.own_sku_match_candidates', count(*) FROM stg.own_sku_match_candidates
ORDER BY object_name;

-- [V2-4] Product_code selfpia_sku invariant
SELECT
  count(*) FILTER (WHERE code_system = 'selfpia_sku' AND target_type = 'SKU') AS selfpia_sku_alias_rows,
  count(DISTINCT code_value) FILTER (WHERE code_system = 'selfpia_sku' AND target_type = 'SKU') AS selfpia_sku_alias_distinct
FROM product_code.code_alias;

-- [V2-5] Canonical view health
SELECT
  count(*) AS canonical_sku_rows,
  count(*) FILTER (WHERE selfpia_sku_code IS NULL) AS missing_selfpia_sku_code,
  count(DISTINCT selfpia_sku_code) AS distinct_selfpia_sku_code
FROM product_code.v_sku_canonical;

-- [V2-6] picking.order_items master match status distribution
SELECT
  master_match_status,
  count(*) AS lines,
  count(DISTINCT raw_p_code) AS distinct_raw_p_code
FROM picking.order_items
GROUP BY master_match_status
ORDER BY master_match_status;

-- [V2-7] Matched rows with missing master linkage should be zero
SELECT count(*) AS matched_rows_missing_master_link
FROM picking.order_items
WHERE master_match_status = 'matched'
  AND (sku_id IS NULL OR selfpia_sku_code IS NULL);

-- [V2-8] Raw p_code preservation
SELECT
  count(*) AS total_order_items,
  count(*) FILTER (WHERE raw_p_code IS NULL OR btrim(raw_p_code) = '') AS missing_raw_p_code
FROM picking.order_items;

-- [V2-9] FK status for order_items -> sku_master
SELECT
  conname,
  convalidated,
  pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conname = 'fk_order_items_sku_id';

-- [V2-10] Known legacy unmatched seed rows
SELECT raw_p_code, p_name, unmatched_reason, suggested_action, order_item_status
FROM stg.unmatched_order_items
WHERE raw_p_code IN ('9826-1', '9826-3', '9826-26', '9826-31', '9826-48')
ORDER BY raw_p_code;

-- [V2-11] Ambiguous own_sku candidate view
SELECT *
FROM stg.v_ambiguous_own_sku_candidates
ORDER BY candidate_count DESC, own_sku_code
LIMIT 50;

-- [V2-12] Index inventory
SELECT schemaname, tablename, indexname
FROM pg_indexes
WHERE schemaname IN ('product_code', 'picking', 'inspection', 'cs', 'audit', 'stg')
ORDER BY schemaname, tablename, indexname;

