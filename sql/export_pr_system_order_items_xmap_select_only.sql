-- =============================================================================
-- export_pr_system_order_items_xmap_select_only.sql
--
-- Purpose:
--   Export PR_system order_items rows used as the operating order line side of
--   cross mapping.
--
-- Execute only on:
--   PR_system Supabase project ref: vgxocngpykhlkosiaeew
--   DB/schema: postgres/public
--
-- Output CSV:
--   order_items_xmap.csv
--
-- Safety:
--   SELECT-only. Do not run CREATE / DROP / ALTER / INSERT / UPDATE / DELETE /
--   TRUNCATE / COPY server-side / staging creation on operating Supabase DB.
-- =============================================================================

-- 1) Context check. Confirm this is PR_system before exporting.
SELECT
  current_database() AS db,
  current_schema() AS schema_name,
  current_user AS user_name,
  now() AS checked_at,
  'PR_system / vgxocngpykhlkosiaeew' AS expected_project;

-- 2) Export this result as order_items_xmap.csv.
SELECT
  oi.item_no AS item_no,
  oi.ord_no AS ord_no,
  oi.ord_date AS ord_date,
  oi.inv_no AS inv_no,
  oi.p_code AS p_code,
  NULLIF(btrim(replace(replace(oi.p_dpcode, '[', ''), ']', '')), '') AS p_dpcode_clean,
  NULLIF(btrim(replace(replace(oi.prod_code, '[', ''), ']', '')), '') AS prod_code_clean,
  oi.p_option AS p_option,
  oi.p_name AS p_name,
  oi.qty AS qty,
  oi.o_status AS o_status
FROM public.order_items oi
ORDER BY oi.item_no;

