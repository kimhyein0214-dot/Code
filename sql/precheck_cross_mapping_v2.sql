-- =============================================================================
-- precheck_cross_mapping_v2.sql
-- 사전조사 결과 반영판 (v2).
-- 실제 테이블/컬럼명 치환 완료.
--
-- 운영 DB 변경 금지. 운영 DB 에는 staging 테이블을 만들지 마세요.
-- cross-DB JOIN 은 두 Supabase project 가 분리되어 있어 불가능.
--
-- 실행 구간:
--   * Product_code 운영 Supabase SELECT-only: STEP A, STEP A-2, STEP C-6
--   * PR_system 운영 Supabase SELECT-only: STEP A-3, STEP C-7
--   * 로컬/검증 PostgreSQL 전용: STEP B, STEP C-1 ~ STEP C-5
--
-- 운영 DB 에서 금지:
--   CREATE / ALTER / DROP / INSERT / UPDATE / DELETE / TRUNCATE / COPY 적재
--   stg_xmap.* 생성, cross-project JOIN, schema_nas_postgresql_draft.sql 실행
--
-- 매칭 가설 (사전조사 v1 결과):
--   PR_system.order_items.p_code  ==  Product_code.code_alias.code_value (WHERE code_system='selfpia_sku')
--     → code_alias.target_id (uuid) → sku_master.id (PRIMARY KEY)
--
--   PR_system distinct p_code = 2,742개
--   Product_code selfpia_sku distinct code_value = 33,287개 (1:1)
--   PR_system order_items.p_code 의 100% 가 NNN-NN 형식 (selfpia_sku 와 동일)
-- =============================================================================


-- =========================================================
-- STEP A. Product_code Supabase 에서 selfpia_sku alias 키 EXPORT
-- (이 쿼리만 실행. 결과는 CSV/JSON 으로 다운로드해 로컬로 옮김)
-- 실행 DB: Product_code (mrqoqmidnrawflwezxlm)
-- 권한/안전: SELECT-only. 실행 전 current_database(), current_schema(), project ref 확인.
-- export 파일명 권장: selfpia_sku_alias.csv
-- =========================================================
SELECT current_database() AS db, current_schema() AS schema_name, now() AS checked_at;

SELECT
  ca.code_value          AS selfpia_sku_code,        -- 예: '1258-1'
  ca.selfpia_product_code,                            -- 예: '1258'
  ca.selfpia_option_no,                               -- 예: '1'
  ca.target_id           AS sku_id,                   -- → sku_master.id
  sm.virtual_sku_code,                                -- VSKU-XXXXXXXX
  sm.product_id,
  pm.virtual_product_code,                            -- VPRD-XXXXXXXX
  sm.option_value,
  sm.sku_type,
  sm.status              AS sku_status,
  pm.product_name
FROM public.code_alias ca
JOIN public.sku_master    sm ON sm.id = ca.target_id
JOIN public.product_master pm ON pm.id = sm.product_id
WHERE ca.code_system = 'selfpia_sku';
-- 예상 row count: 33,287


-- =========================================================
-- STEP A-2. (선택) own_sku 별칭도 EXPORT — 2순위 매칭용
-- 실행 DB: Product_code (mrqoqmidnrawflwezxlm)
-- 권한/안전: SELECT-only.
-- export 파일명 권장: own_sku_alias.csv
-- =========================================================
SELECT current_database() AS db, current_schema() AS schema_name, now() AS checked_at;

SELECT
  ca.code_value          AS own_sku_code,             -- 예: 'B-1-01', 'CA-3-03_3'
  ca.parsed_part1,
  ca.parsed_part2,
  ca.selfpia_product_code AS hint_product_code,       -- own_sku 행의 힌트
  ca.selfpia_option_no    AS hint_option_no,
  ca.target_id           AS sku_id,
  ca.is_primary
FROM public.code_alias ca
WHERE ca.code_system = 'own_sku';
-- 예상 row count: 31,975 (own_sku 는 같은 code_value 가 여러 SKU 에 매핑 가능 - 18,533 distinct)


-- =========================================================
-- STEP A-3. PR_system 에서 order_items 라인 키 EXPORT
-- 실행 DB: PR_system (vgxocngpykhlkosiaeew)
-- 권한/안전: SELECT-only.
-- export 파일명 권장: order_items_xmap.csv
-- =========================================================
SELECT current_database() AS db, current_schema() AS schema_name, now() AS checked_at;

SELECT
  oi.item_no,
  oi.ord_no,
  oi.ord_date,
  oi.inv_no,
  oi.p_code,                                          -- 매칭 1순위
  NULLIF(btrim(replace(replace(oi.p_dpcode,'[',''),']','')), '') AS p_dpcode_clean, -- 매칭 2순위 (own_sku)
  NULLIF(btrim(replace(replace(oi.prod_code,'[',''),']','')), '') AS prod_code_clean,
  oi.p_option,
  oi.p_name,
  oi.qty,
  oi.o_status
FROM public.order_items oi;
-- 예상 row count: 6,169


-- =========================================================
-- STEP B. 로컬/검증 PostgreSQL 에 staging 적재 (운영 DB 가 아님!)
-- 아래는 로컬 DB 에서만 실행. CSV 파일 경로는 사용자가 치환.
-- =========================================================
-- -- 로컬 검증 DB 에서만:
-- CREATE SCHEMA IF NOT EXISTS stg_xmap;
--
-- DROP TABLE IF EXISTS stg_xmap.selfpia_sku_alias;
-- CREATE TABLE stg_xmap.selfpia_sku_alias (
--   selfpia_sku_code      text PRIMARY KEY,
--   selfpia_product_code  text,
--   selfpia_option_no     text,
--   sku_id                uuid,
--   virtual_sku_code      text,
--   product_id            uuid,
--   virtual_product_code  text,
--   option_value          text,
--   sku_type              text,
--   sku_status            text,
--   product_name          text
-- );
-- \COPY stg_xmap.selfpia_sku_alias FROM '/path/to/selfpia_sku_alias.csv' WITH (FORMAT csv, HEADER true);
--
-- DROP TABLE IF EXISTS stg_xmap.own_sku_alias;
-- CREATE TABLE stg_xmap.own_sku_alias (
--   own_sku_code          text,
--   parsed_part1          text,
--   parsed_part2          text,
--   hint_product_code     text,
--   hint_option_no        text,
--   sku_id                uuid,
--   is_primary            boolean
-- );
-- CREATE INDEX ON stg_xmap.own_sku_alias (own_sku_code);
-- \COPY stg_xmap.own_sku_alias FROM '/path/to/own_sku_alias.csv' WITH (FORMAT csv, HEADER true);
--
-- DROP TABLE IF EXISTS stg_xmap.order_items;
-- CREATE TABLE stg_xmap.order_items (
--   item_no           text PRIMARY KEY,
--   ord_no            text,
--   ord_date          date,
--   inv_no            text,
--   p_code            text,
--   p_dpcode_clean    text,
--   prod_code_clean   text,
--   p_option          text,
--   p_name            text,
--   qty               int,
--   o_status          text
-- );
-- CREATE INDEX ON stg_xmap.order_items (p_code);
-- CREATE INDEX ON stg_xmap.order_items (p_dpcode_clean);
-- \COPY stg_xmap.order_items FROM '/path/to/order_items.csv' WITH (FORMAT csv, HEADER true);


-- =========================================================
-- STEP C-1. 1순위 매칭률 (selfpia_sku_code 직결)
-- 실행 DB: 로컬 검증 DB
-- =========================================================
-- WITH base AS (
--   SELECT
--     oi.item_no,
--     oi.p_code,
--     oi.p_dpcode_clean,
--     s.sku_id              AS matched_sku_id_p1,
--     s.virtual_sku_code    AS matched_vsku_p1
--   FROM stg_xmap.order_items oi
--   LEFT JOIN stg_xmap.selfpia_sku_alias s ON s.selfpia_sku_code = oi.p_code
-- )
-- SELECT
--   count(*)                                                          AS total_lines,
--   count(matched_sku_id_p1)                                          AS matched_p1,
--   round(100.0 * count(matched_sku_id_p1) / NULLIF(count(*),0), 2)   AS match_rate_p1_pct,
--   count(*) - count(matched_sku_id_p1)                               AS unmatched_p1
-- FROM base;


-- =========================================================
-- STEP C-2. 2순위 매칭률 (1순위 실패 라인 한정, own_sku)
-- own_sku 는 n:m 이므로 candidate_count 와 함께 측정.
-- p_dpcode_clean 이 비어 있거나 own_sku 후보가 0건인 라인도 분모에 포함한다.
-- =========================================================
-- WITH p1 AS (
--   SELECT
--     oi.item_no,
--     oi.p_code,
--     oi.p_dpcode_clean,
--     oi.prod_code_clean,
--     s.sku_id AS matched_p1
--   FROM stg_xmap.order_items oi
--   LEFT JOIN stg_xmap.selfpia_sku_alias s ON s.selfpia_sku_code = oi.p_code
-- ),
-- p1_unmatched AS (
--   SELECT
--     item_no,
--     p_code,
--     p_dpcode_clean,
--     prod_code_clean
--   FROM p1
--   WHERE p1.matched_p1 IS NULL
-- ),
-- p2_summary AS (
--   SELECT
--     p1u.item_no,
--     p1u.p_dpcode_clean,
--     p1u.prod_code_clean,
--     count(o.sku_id) AS candidate_count,
--     bool_or(o.is_primary) AS has_primary
--   FROM p1_unmatched p1u
--   LEFT JOIN stg_xmap.own_sku_alias o
--     ON o.own_sku_code = COALESCE(p1u.p_dpcode_clean, p1u.prod_code_clean)
--   GROUP BY p1u.item_no, p1u.p_dpcode_clean, p1u.prod_code_clean
-- )
-- SELECT
--   count(*)                                           AS p1_unmatched_lines,
--   count(*) FILTER (WHERE COALESCE(p_dpcode_clean, prod_code_clean) IS NULL) AS p2_no_own_sku_key,
--   count(*) FILTER (WHERE candidate_count = 1)         AS p2_unique_match,
--   count(*) FILTER (WHERE candidate_count > 1)         AS p2_ambiguous,
--   count(*) FILTER (WHERE candidate_count = 0)         AS p2_unmatched,
--   count(*) FILTER (WHERE candidate_count > 1 AND has_primary) AS p2_ambiguous_with_primary,
--   round(100.0 * count(*) FILTER (WHERE candidate_count = 1) / NULLIF(count(*),0), 2) AS p2_unique_rate_within_p1_unmatched_pct
-- FROM p2_summary;


-- =========================================================
-- STEP C-3. 미매칭 라인 sample (1순위 실패 + 2순위 실패)
-- =========================================================
-- SELECT
--   oi.item_no,
--   oi.p_code,
--   oi.p_dpcode_clean,
--   oi.p_name,
--   oi.o_status,
--   count(*) OVER (PARTITION BY oi.p_code) AS p_code_occurrences
-- FROM stg_xmap.order_items oi
-- LEFT JOIN stg_xmap.selfpia_sku_alias s  ON s.selfpia_sku_code = oi.p_code
-- LEFT JOIN stg_xmap.own_sku_alias     o  ON o.own_sku_code     = COALESCE(oi.p_dpcode_clean, oi.prod_code_clean)
-- WHERE s.sku_id IS NULL AND o.sku_id IS NULL
-- ORDER BY p_code_occurrences DESC
-- LIMIT 100;


-- =========================================================
-- STEP C-4. 중복 매칭 sample (own_sku 가 여러 SKU 에 걸리는 경우)
-- =========================================================
-- SELECT
--   oi.item_no, oi.p_code, oi.p_dpcode_clean,
--   array_agg(o.sku_id ORDER BY o.is_primary DESC, o.sku_id) AS candidate_sku_ids
-- FROM stg_xmap.order_items oi
-- JOIN stg_xmap.own_sku_alias o ON o.own_sku_code = COALESCE(oi.p_dpcode_clean, oi.prod_code_clean)
-- WHERE NOT EXISTS (
--   SELECT 1 FROM stg_xmap.selfpia_sku_alias s WHERE s.selfpia_sku_code = oi.p_code
-- )
-- GROUP BY oi.item_no, oi.p_code, oi.p_dpcode_clean
-- HAVING count(*) > 1
-- ORDER BY count(*) DESC
-- LIMIT 50;


-- =========================================================
-- STEP C-5. 미매칭 p_code 의 형식 분포 (분류용)
-- =========================================================
-- SELECT
--   CASE
--     WHEN oi.p_code ~ '^[0-9]+-[0-9]+$'      THEN 'NNN-NN'
--     WHEN oi.p_code ~ '^[0-9]+$'             THEN 'NNN(상품만)'
--     WHEN oi.p_code = '' OR oi.p_code IS NULL THEN 'empty'
--     ELSE 'other'
--   END AS pattern,
--   count(*) AS unmatched_lines,
--   count(DISTINCT oi.p_code) AS distinct_p_code
-- FROM stg_xmap.order_items oi
-- LEFT JOIN stg_xmap.selfpia_sku_alias s  ON s.selfpia_sku_code = oi.p_code
-- WHERE s.sku_id IS NULL
-- GROUP BY 1
-- ORDER BY unmatched_lines DESC;


-- =========================================================
-- STEP C-6. master 자체 무결성 (Product_code 내부 점검)
-- 실행 DB: Product_code (운영) — SELECT-only 이므로 그대로 실행 가능
-- 실행 전 current_database(), current_schema(), project ref 확인.
-- =========================================================
SELECT current_database() AS db, current_schema() AS schema_name, now() AS checked_at;

-- (a) selfpia_sku alias 중복
SELECT code_value, count(*) AS n
FROM public.code_alias
WHERE code_system = 'selfpia_sku'
GROUP BY 1
HAVING count(*) > 1
LIMIT 50;
-- 기대값: 0건 (33,287 distinct = 33,287 rows)

-- (b) own_sku 의 다중 매핑 (n:m) 상위 sample
SELECT code_value, count(*) AS n, array_agg(target_id ORDER BY is_primary DESC) AS sku_ids
FROM public.code_alias
WHERE code_system = 'own_sku'
GROUP BY 1
HAVING count(*) > 1
ORDER BY n DESC
LIMIT 20;

-- (c) sku_master 에 alias 가 없는 SKU
SELECT count(*) AS sku_without_selfpia_alias
FROM public.sku_master sm
WHERE NOT EXISTS (
  SELECT 1 FROM public.code_alias ca
  WHERE ca.target_id = sm.id AND ca.code_system = 'selfpia_sku'
);


-- =========================================================
-- STEP C-7. PR_system 운영 DB 에서 가능한 quick check
-- 실행 DB: PR_system (vgxocngpykhlkosiaeew) — SELECT-only
-- 목적: export 전 p_code/p_dpcode 형식과 채움률 재확인
-- =========================================================
SELECT current_database() AS db, current_schema() AS schema_name, now() AS checked_at;

SELECT
  count(*) AS total_lines,
  count(*) FILTER (WHERE p_code IS NOT NULL AND btrim(p_code) <> '') AS p_code_filled,
  count(DISTINCT p_code) AS distinct_p_code,
  count(*) FILTER (WHERE p_code ~ '^[0-9]+-[0-9]+$') AS p_code_nnn_dash_nn,
  count(*) FILTER (WHERE NULLIF(btrim(replace(replace(p_dpcode,'[',''),']','')), '') IS NOT NULL) AS p_dpcode_clean_filled,
  count(DISTINCT NULLIF(btrim(replace(replace(p_dpcode,'[',''),']','')), '')) AS distinct_p_dpcode_clean
FROM public.order_items;


-- =========================================================
-- 주의 (재확인):
--   * 본 파일의 STEP A, A-2, A-3, C-6, C-7 은 운영 Supabase 에서 실행 가능 (SELECT-only).
--   * STEP B 의 CREATE/INSERT/COPY 와 STEP C-1~5 의 JOIN 은 **로컬 검증 DB 에서만** 실행하세요.
--   * 운영 DB 에는 절대 stg_xmap.* 등 임시 테이블을 만들지 마세요.
-- =========================================================
