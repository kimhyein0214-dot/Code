-- ============================================================
-- stage_local_data_import.sql
--
-- 목적:
--   exports/selfpia_sku_alias.csv (33,287 rows)
--   exports/own_sku_alias.csv     (31,975 rows)
--   를 로컬 Docker `product_ops_test` 의 별도 schema
--   `stg_import_v1` 에 staging 한다.
--
--   본 파일은 product_code.* 를 변경하지 않는다. staging 만 수행.
--   product_code.* INSERT 는 dryrun_local_data_import.sql 에서
--   BEGIN/ROLLBACK 안에서만 시뮬레이션한다.
--
-- 운영 Supabase / NAS 는 절대 대상이 아니다.
-- 본 파일은 stg_import_v1 영역 한정으로 CREATE / TRUNCATE / \copy 를
-- 포함한다. product_code 영역에 대한 DDL/INSERT/UPDATE/DELETE 는
-- 한 줄도 없다.
--
-- 실행 방법:
--   docker exec -i product_ops_test_postgres \
--     psql -U product_ops_tester -d product_ops_test \
--     -f /sql/stage_local_data_import.sql
--
--   호스트 psql 로도 가능:
--     psql -h localhost -p 5433 -U product_ops_tester -d product_ops_test \
--       -f sql/stage_local_data_import.sql
--   단 호스트에서 실행할 때는 \copy 의 경로를 호스트 경로로 변환해야 한다.
-- ============================================================

\pset border 2
\pset pager off
\pset format aligned

-- ------------------------------------------------------------
-- [0] context
-- ------------------------------------------------------------
\echo '== [0] context =='
SELECT
  'stage_local_data_import' AS section,
  current_database()        AS db,
  current_user              AS db_user,
  now()                     AS now_ts;

-- ------------------------------------------------------------
-- [1] stg_import_v1 schema 생성 (idempotent)
-- ------------------------------------------------------------
\echo '== [1] stg_import_v1 schema =='
CREATE SCHEMA IF NOT EXISTS stg_import_v1;

-- ------------------------------------------------------------
-- [2] staging table 정의 (CSV 컬럼과 1:1 매칭)
--     본 staging table 은 product_code.* 와 분리되어 있어
--     실패 시 DROP SCHEMA stg_import_v1 CASCADE 로 회수 가능.
-- ------------------------------------------------------------
\echo '== [2-A] stg_import_v1.selfpia_sku_alias 정의 =='
CREATE TABLE IF NOT EXISTS stg_import_v1.selfpia_sku_alias (
  selfpia_sku_code      text,
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

\echo '== [2-B] stg_import_v1.own_sku_alias 정의 =='
CREATE TABLE IF NOT EXISTS stg_import_v1.own_sku_alias (
  own_sku_code       text,
  parsed_part1       text,
  parsed_part2       text,
  hint_product_code  text,
  hint_option_no     text,
  sku_id             uuid,
  is_primary         boolean
);

-- ------------------------------------------------------------
-- [3] 적재 직전 TRUNCATE (재실행 가능하도록 멱등 보장)
-- ------------------------------------------------------------
\echo '== [3] staging TRUNCATE =='
TRUNCATE stg_import_v1.selfpia_sku_alias;
TRUNCATE stg_import_v1.own_sku_alias;

-- ------------------------------------------------------------
-- [4] \copy 로 CSV 적재
--
--     주의: \copy 는 psql 의 클라이언트 메타커맨드다.
--     docker exec ... psql -f /sql/stage_local_data_import.sql 로
--     실행하면 컨테이너 내부의 /exports 마운트 경로가 그대로 사용된다.
--
--     호스트에서 직접 psql 로 실행할 경우 CSV 경로를 호스트 경로로
--     변경해야 한다 (예: exports/selfpia_sku_alias.csv).
-- ------------------------------------------------------------
\echo '== [4-A] \\copy stg_import_v1.selfpia_sku_alias FROM /exports/selfpia_sku_alias.csv =='
\copy stg_import_v1.selfpia_sku_alias (selfpia_sku_code, selfpia_product_code, selfpia_option_no, sku_id, virtual_sku_code, product_id, virtual_product_code, option_value, sku_type, sku_status, product_name) FROM '/exports/selfpia_sku_alias.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '== [4-B] \\copy stg_import_v1.own_sku_alias FROM /exports/own_sku_alias.csv =='
\copy stg_import_v1.own_sku_alias (own_sku_code, parsed_part1, parsed_part2, hint_product_code, hint_option_no, sku_id, is_primary) FROM '/exports/own_sku_alias.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ------------------------------------------------------------
-- [5] 적재 후 SELECT-only 검증
-- ------------------------------------------------------------
\echo '== [5-A] staging row count =='
SELECT '5a_stg_count' AS section, 'selfpia_sku_alias' AS rel, COUNT(*) AS rows FROM stg_import_v1.selfpia_sku_alias
UNION ALL SELECT '5a_stg_count', 'own_sku_alias',     COUNT(*) FROM stg_import_v1.own_sku_alias
ORDER BY rel;

\echo '== [5-B] selfpia staging null/blank 통계 =='
SELECT
  '5b_selfpia_null' AS section,
  COUNT(*)                                                                                AS rows,
  SUM(CASE WHEN selfpia_sku_code IS NULL OR btrim(selfpia_sku_code) = '' THEN 1 ELSE 0 END) AS null_blank_selfpia_sku,
  SUM(CASE WHEN sku_id     IS NULL THEN 1 ELSE 0 END) AS null_sku_id,
  SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
  COUNT(DISTINCT sku_id)     AS distinct_sku_id,
  COUNT(DISTINCT product_id) AS distinct_product_id
FROM stg_import_v1.selfpia_sku_alias;

\echo '== [5-C] own staging null/blank 통계 =='
SELECT
  '5c_own_null' AS section,
  COUNT(*)                                                                          AS rows,
  SUM(CASE WHEN own_sku_code IS NULL OR btrim(own_sku_code) = '' THEN 1 ELSE 0 END) AS null_blank_own_sku,
  SUM(CASE WHEN sku_id IS NULL THEN 1 ELSE 0 END)                                   AS null_sku_id,
  COUNT(DISTINCT own_sku_code) AS distinct_own_sku_code,
  COUNT(DISTINCT sku_id)       AS distinct_sku_id
FROM stg_import_v1.own_sku_alias;

\echo '== [5-D] selfpia staging duplicate key 검증 =='
SELECT
  '5d_selfpia_dup' AS section,
  CASE
    WHEN COUNT(*) = COUNT(DISTINCT selfpia_sku_code) THEN 'OK_unique'
    ELSE 'DUPLICATE'
  END AS verdict_selfpia_sku_code,
  CASE
    WHEN COUNT(*) = COUNT(DISTINCT sku_id) THEN 'OK_unique'
    ELSE 'DUPLICATE'
  END AS verdict_sku_id
FROM stg_import_v1.selfpia_sku_alias;

\echo '== [5-E] own staging (code, sku_id) 분포 =='
SELECT
  '5e_own_pair' AS section,
  bucket,
  COUNT(*) AS pairs
FROM (
  SELECT
    CASE
      WHEN COUNT(*) = 1 THEN 'unique_pair'
      ELSE 'duplicate_pair'
    END AS bucket
  FROM stg_import_v1.own_sku_alias
  GROUP BY own_sku_code, sku_id
) s
GROUP BY bucket
ORDER BY bucket;

\echo '== [5-F] own staging ambiguous (동일 code -> 여러 sku) =='
SELECT
  '5f_own_ambig' AS section,
  ambig_bucket,
  COUNT(*) AS distinct_codes
FROM (
  SELECT
    CASE
      WHEN COUNT(DISTINCT sku_id) = 1 THEN 'unique'
      WHEN COUNT(DISTINCT sku_id) = 2 THEN 'ambig_2'
      WHEN COUNT(DISTINCT sku_id) BETWEEN 3 AND 5 THEN 'ambig_3_to_5'
      ELSE 'ambig_6+'
    END AS ambig_bucket
  FROM stg_import_v1.own_sku_alias
  GROUP BY own_sku_code
) s
GROUP BY ambig_bucket
ORDER BY ambig_bucket;

\echo '== [5-G] selfpia <-> own join 가능성 (own.sku_id 가 selfpia.sku_id 에 존재하는지) =='
SELECT
  '5g_join' AS section,
  COUNT(*) AS own_rows,
  SUM(CASE WHEN s.sku_id IS NOT NULL THEN 1 ELSE 0 END) AS matched_to_selfpia,
  SUM(CASE WHEN s.sku_id IS NULL THEN 1 ELSE 0 END)     AS orphan_in_selfpia
FROM stg_import_v1.own_sku_alias o
LEFT JOIN stg_import_v1.selfpia_sku_alias s
  ON s.sku_id = o.sku_id;

\echo '== [5-H] selfpia.sku_id <-> 현재 product_code.sku_master.id 충돌 여부 (있으면 ON CONFLICT 로 보존됨) =='
SELECT
  '5h_existing_conflict' AS section,
  COUNT(*)                                            AS staging_rows,
  SUM(CASE WHEN sm.id IS NOT NULL THEN 1 ELSE 0 END)  AS would_conflict_with_existing_sku,
  SUM(CASE WHEN sm.id IS NULL     THEN 1 ELSE 0 END)  AS would_insert_new
FROM stg_import_v1.selfpia_sku_alias s
LEFT JOIN product_code.sku_master sm
  ON sm.id = s.sku_id;

\echo '== [5-I] selfpia.product_id <-> 현재 product_code.product_master.id 충돌 여부 =='
SELECT
  '5i_product_conflict' AS section,
  COUNT(DISTINCT s.product_id)                                AS staging_distinct_product,
  COUNT(DISTINCT s.product_id) FILTER (WHERE pm.id IS NOT NULL) AS would_conflict_with_existing_product,
  COUNT(DISTINCT s.product_id) FILTER (WHERE pm.id IS NULL)     AS would_insert_new_product
FROM stg_import_v1.selfpia_sku_alias s
LEFT JOIN product_code.product_master pm
  ON pm.id = s.product_id;

\echo '== stage_local_data_import.sql 완료 =='
