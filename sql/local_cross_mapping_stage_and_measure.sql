-- =============================================================================
-- local_cross_mapping_stage_and_measure.sql
--
-- Purpose:
--   Stage Product_code/PR_system CSV exports into a local or verification
--   PostgreSQL database and measure actual cross mapping rates.
--
-- Execute only on:
--   Local Docker/verification PostgreSQL. Never run this file on operating Supabase DB.
--
-- Required CSV files:
--   /exports/selfpia_sku_alias.csv
--   /exports/own_sku_alias.csv
--   /exports/order_items_xmap.csv
--
-- Operating Supabase warning:
--   This file intentionally contains CREATE / DROP / \copy and must not be used
--   against Product_code or PR_system Supabase projects.
-- =============================================================================

-- =========================================================
-- STEP B-0. Local context check
-- =========================================================
SELECT
  current_database() AS db,
  current_schema() AS schema_name,
  current_user AS user_name,
  now() AS checked_at,
  'LOCAL_OR_VERIFICATION_DB_ONLY' AS expected_environment;

-- =========================================================
-- STEP B-1. Local staging schema and tables
-- =========================================================
CREATE SCHEMA IF NOT EXISTS stg_xmap;

DROP TABLE IF EXISTS stg_xmap.selfpia_sku_alias;
CREATE TABLE stg_xmap.selfpia_sku_alias (
  selfpia_sku_code      text PRIMARY KEY,
  selfpia_product_code  text,
  selfpia_option_no     text,
  sku_id                uuid,
  virtual_sku_code      text,
  product_id            uuid,
  virtual_product_code  text,
  option_value          text,
  sku_type              text,
  sku_status            text,
  product_name          text
);

DROP TABLE IF EXISTS stg_xmap.own_sku_alias;
CREATE TABLE stg_xmap.own_sku_alias (
  own_sku_code       text,
  parsed_part1       text,
  parsed_part2       text,
  hint_product_code  text,
  hint_option_no     text,
  sku_id             uuid,
  is_primary         boolean
);
CREATE INDEX ix_xmap_own_sku_alias_code ON stg_xmap.own_sku_alias (own_sku_code);

DROP TABLE IF EXISTS stg_xmap.order_items;
CREATE TABLE stg_xmap.order_items (
  item_no          text PRIMARY KEY,
  ord_no           text,
  ord_date         date,
  inv_no           text,
  p_code           text,
  p_dpcode_clean   text,
  prod_code_clean  text,
  p_option         text,
  p_name           text,
  qty              int,
  o_status         text
);
CREATE INDEX ix_xmap_order_items_p_code ON stg_xmap.order_items (p_code);
CREATE INDEX ix_xmap_order_items_p_dpcode_clean ON stg_xmap.order_items (p_dpcode_clean);
CREATE INDEX ix_xmap_order_items_prod_code_clean ON stg_xmap.order_items (prod_code_clean);

-- =========================================================
-- STEP B-2. Client-side CSV load
-- =========================================================
-- In psql, run these client-side \copy commands after placing the CSV files in ./exports.
-- If psql runs inside the Docker container, the files are available under /exports.
-- Do not use server-side COPY against operating Supabase DB.
--
-- \copy stg_xmap.selfpia_sku_alias FROM '/exports/selfpia_sku_alias.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy stg_xmap.own_sku_alias      FROM '/exports/own_sku_alias.csv'      WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy stg_xmap.order_items        FROM '/exports/order_items_xmap.csv'   WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- =========================================================
-- STEP B-3. Load sanity check
-- =========================================================
SELECT 'stg_xmap.selfpia_sku_alias' AS table_name, count(*) AS rows FROM stg_xmap.selfpia_sku_alias
UNION ALL
SELECT 'stg_xmap.own_sku_alias', count(*) FROM stg_xmap.own_sku_alias
UNION ALL
SELECT 'stg_xmap.order_items', count(*) FROM stg_xmap.order_items
ORDER BY table_name;

-- =========================================================
-- STEP C-1. selfpia_sku direct match rate
-- =========================================================
WITH base AS (
  SELECT
    oi.item_no,
    oi.p_code,
    oi.p_dpcode_clean,
    s.sku_id AS matched_sku_id_p1,
    s.virtual_sku_code AS matched_vsku_p1
  FROM stg_xmap.order_items oi
  LEFT JOIN stg_xmap.selfpia_sku_alias s
    ON s.selfpia_sku_code = oi.p_code
)
SELECT
  count(*) AS total_lines,
  count(matched_sku_id_p1) AS matched_p1,
  round(100.0 * count(matched_sku_id_p1) / NULLIF(count(*), 0), 2) AS match_rate_p1_pct,
  count(*) - count(matched_sku_id_p1) AS unmatched_p1,
  count(DISTINCT p_code) AS distinct_p_code,
  count(DISTINCT p_code) FILTER (WHERE matched_sku_id_p1 IS NULL) AS unmatched_distinct_p_code
FROM base;

-- =========================================================
-- STEP C-2. own_sku fallback for selfpia_sku unmatched lines
-- =========================================================
WITH p1 AS (
  SELECT
    oi.item_no,
    oi.p_code,
    oi.p_dpcode_clean,
    oi.prod_code_clean,
    s.sku_id AS matched_p1
  FROM stg_xmap.order_items oi
  LEFT JOIN stg_xmap.selfpia_sku_alias s
    ON s.selfpia_sku_code = oi.p_code
),
p1_unmatched AS (
  SELECT
    item_no,
    p_code,
    p_dpcode_clean,
    prod_code_clean,
    COALESCE(p_dpcode_clean, prod_code_clean) AS own_sku_key
  FROM p1
  WHERE matched_p1 IS NULL
),
p2_summary AS (
  SELECT
    p1u.item_no,
    p1u.p_code,
    p1u.own_sku_key,
    count(o.sku_id) AS candidate_count,
    bool_or(o.is_primary) AS has_primary
  FROM p1_unmatched p1u
  LEFT JOIN stg_xmap.own_sku_alias o
    ON o.own_sku_code = p1u.own_sku_key
  GROUP BY p1u.item_no, p1u.p_code, p1u.own_sku_key
)
SELECT
  count(*) AS p1_unmatched_lines,
  count(*) FILTER (WHERE own_sku_key IS NULL) AS p2_no_own_sku_key,
  count(*) FILTER (WHERE candidate_count = 1) AS p2_unique_match,
  count(*) FILTER (WHERE candidate_count > 1) AS p2_ambiguous,
  count(*) FILTER (WHERE candidate_count = 0) AS p2_unmatched,
  count(*) FILTER (WHERE candidate_count > 1 AND has_primary) AS p2_ambiguous_with_primary,
  round(100.0 * count(*) FILTER (WHERE candidate_count = 1) / NULLIF(count(*), 0), 2) AS p2_unique_rate_within_p1_unmatched_pct
FROM p2_summary;

-- =========================================================
-- STEP C-3. Final unmatched sample
-- =========================================================
SELECT
  oi.item_no,
  oi.ord_no,
  oi.inv_no,
  oi.p_code,
  oi.p_dpcode_clean,
  oi.prod_code_clean,
  oi.p_name,
  oi.p_option,
  oi.qty,
  oi.o_status,
  count(*) OVER (PARTITION BY oi.p_code) AS p_code_occurrences
FROM stg_xmap.order_items oi
LEFT JOIN stg_xmap.selfpia_sku_alias s
  ON s.selfpia_sku_code = oi.p_code
LEFT JOIN stg_xmap.own_sku_alias o
  ON o.own_sku_code = COALESCE(oi.p_dpcode_clean, oi.prod_code_clean)
WHERE s.sku_id IS NULL
  AND o.sku_id IS NULL
ORDER BY p_code_occurrences DESC, oi.p_code, oi.item_no
LIMIT 100;

-- =========================================================
-- STEP C-4. Ambiguous own_sku fallback sample
-- =========================================================
SELECT
  oi.item_no,
  oi.ord_no,
  oi.inv_no,
  oi.p_code,
  COALESCE(oi.p_dpcode_clean, oi.prod_code_clean) AS own_sku_key,
  oi.p_name,
  oi.p_option,
  count(o.sku_id) AS candidate_count,
  array_agg(o.sku_id ORDER BY o.is_primary DESC, o.sku_id) AS candidate_sku_ids
FROM stg_xmap.order_items oi
JOIN stg_xmap.own_sku_alias o
  ON o.own_sku_code = COALESCE(oi.p_dpcode_clean, oi.prod_code_clean)
WHERE NOT EXISTS (
  SELECT 1
  FROM stg_xmap.selfpia_sku_alias s
  WHERE s.selfpia_sku_code = oi.p_code
)
GROUP BY
  oi.item_no,
  oi.ord_no,
  oi.inv_no,
  oi.p_code,
  COALESCE(oi.p_dpcode_clean, oi.prod_code_clean),
  oi.p_name,
  oi.p_option
HAVING count(o.sku_id) > 1
ORDER BY candidate_count DESC, own_sku_key, oi.item_no
LIMIT 50;

-- =========================================================
-- STEP C-5. Unmatched p_code pattern distribution
-- =========================================================
SELECT
  CASE
    WHEN oi.p_code ~ '^[0-9]+-[0-9]+$' THEN 'NNN-NN'
    WHEN oi.p_code ~ '^[0-9]+$' THEN 'NNN(상품만)'
    WHEN oi.p_code IS NULL OR btrim(oi.p_code) = '' THEN 'empty'
    ELSE 'other'
  END AS pattern,
  count(*) AS unmatched_lines,
  count(DISTINCT oi.p_code) AS distinct_p_code
FROM stg_xmap.order_items oi
LEFT JOIN stg_xmap.selfpia_sku_alias s
  ON s.selfpia_sku_code = oi.p_code
WHERE s.sku_id IS NULL
GROUP BY 1
ORDER BY unmatched_lines DESC, pattern;
