-- =============================================================================
-- local_check_unmatched_duplicates.sql
--
-- LOCAL DOCKER ONLY.
-- Purpose:
--   Diagnose why GET /mapping/unmatched returns duplicate-looking 9826-* rows.
--
-- Allowed target:
--   Local Docker PostgreSQL database: product_ops_test
--
-- Forbidden targets:
--   Operating Supabase
--   Synology NAS PostgreSQL
--
-- This script is SELECT-only.
-- =============================================================================

DO $$
BEGIN
  IF current_database() <> 'product_ops_test' THEN
    RAISE EXCEPTION 'Duplicate check is allowed only on product_ops_test. Current database: %', current_database();
  END IF;
END
$$;

-- [D-1] Exact duplicate row signature check in stg.unmatched_order_items.
-- If duplicate_signature_rows > 1, duplicate rows exist in staging.
SELECT
  raw_p_code,
  raw_item_no,
  raw_ord_no,
  inv_no,
  p_name,
  unmatched_reason,
  order_item_status,
  count(*) AS duplicate_signature_rows,
  array_agg(id ORDER BY id) AS row_ids
FROM stg.unmatched_order_items
WHERE raw_p_code LIKE '9826-%'
GROUP BY
  raw_p_code,
  raw_item_no,
  raw_ord_no,
  inv_no,
  p_name,
  unmatched_reason,
  order_item_status
HAVING count(*) > 1
ORDER BY raw_p_code, raw_item_no NULLS LAST;

-- [D-2] raw_p_code-level count. Multiple rows per raw_p_code may be legitimate
-- if the endpoint is line-level and there are several historical order lines.
SELECT
  raw_p_code,
  count(*) AS line_level_rows,
  count(DISTINCT raw_item_no) AS distinct_raw_item_no,
  count(DISTINCT raw_ord_no) AS distinct_raw_ord_no,
  count(DISTINCT inv_no) AS distinct_inv_no,
  array_agg(id ORDER BY id) AS row_ids
FROM stg.unmatched_order_items
WHERE raw_p_code LIKE '9826-%'
GROUP BY raw_p_code
ORDER BY raw_p_code;

-- [D-3] Full line-level rows for visual inspection.
SELECT
  id,
  raw_item_no,
  raw_ord_no,
  inv_no,
  raw_p_code,
  p_name,
  p_option,
  qty_ordered,
  order_item_status,
  unmatched_reason,
  resolved,
  created_at
FROM stg.unmatched_order_items
WHERE raw_p_code LIKE '9826-%'
ORDER BY raw_p_code, raw_item_no NULLS LAST, id;

-- [D-4] Proposed code-level response shape for /mapping/unmatched?group_by=raw_p_code.
SELECT
  raw_p_code,
  min(p_name) AS sample_p_name,
  min(unmatched_reason) AS sample_unmatched_reason,
  count(*) AS line_count,
  count(DISTINCT raw_item_no) AS distinct_item_count,
  bool_or(resolved) AS any_resolved,
  array_agg(id ORDER BY id) AS line_ids
FROM stg.unmatched_order_items
WHERE raw_p_code LIKE '9826-%' OR raw_p_code LIKE 'LOCAL_TEST_%'
GROUP BY raw_p_code
ORDER BY raw_p_code;

