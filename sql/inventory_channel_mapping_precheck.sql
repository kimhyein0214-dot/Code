-- ============================================================
-- inventory_channel_mapping_precheck.sql
--
-- 목적:
--   메이크샵 / 에이블리 채널 매핑 작업 시작 전, 로컬 Docker
--   PostgreSQL `product_ops_test` DB 의 product_code schema 와 관련
--   테이블 구조 및 데이터 분포를 SELECT-only 로 점검한다.
--
-- 운영 Supabase / NAS 는 절대 대상이 아니다.
-- 본 파일은 SELECT-only. INSERT/UPDATE/DELETE/ALTER/DROP/CREATE/
-- TRUNCATE/COPY 가 한 줄도 없다.
--
-- 실행 예:
--   docker exec -i product_ops_test_postgres \
--     psql -U product_ops_tester -d product_ops_test \
--     -f /sql/inventory_channel_mapping_precheck.sql
--
--   또는 host 에서:
--   psql -h localhost -p 5433 -U product_ops_tester -d product_ops_test \
--     -f sql/inventory_channel_mapping_precheck.sql
--
-- 결과 회신 방식:
--   각 \echo 섹션 헤더와 함께 결과를 그대로 회신하면 다음 턴에서
--   메이크샵/에이블리 staging 설계를 확정할 수 있다.
-- ============================================================

\pset border 2
\pset pager off
\pset format aligned

-- ------------------------------------------------------------
-- [0] DB / 사용자 / 시각 확인
-- ------------------------------------------------------------
\echo '== [0] context =='
SELECT
  'context'              AS section,
  current_database()     AS db,
  current_user           AS db_user,
  current_setting('server_version') AS pg_version,
  now()                  AS now_ts;

-- ------------------------------------------------------------
-- [1] product_code schema 내 후보 테이블 존재 여부
-- ------------------------------------------------------------
\echo '== [1] product_code schema 후보 테이블 존재 여부 =='
WITH candidates(table_name) AS (
  VALUES
    ('product_master'),
    ('sku_master'),
    ('code_alias'),
    ('sku_channel_mapping'),
    ('sku_bundle_component'),
    ('channel_product'),
    ('channel_sku'),
    ('channel_template_meta'),
    ('channel_sku_review_draft'),
    ('product_image')
)
SELECT
  '1_table_exists' AS section,
  c.table_name,
  CASE WHEN t.table_name IS NULL THEN 'MISSING' ELSE 'PRESENT' END AS status
FROM candidates c
LEFT JOIN information_schema.tables t
  ON t.table_schema = 'product_code'
 AND t.table_name   = c.table_name
ORDER BY c.table_name;

-- ------------------------------------------------------------
-- [2] product_code 내 모든 base table + view 목록
-- ------------------------------------------------------------
\echo '== [2] product_code 내 모든 relation =='
SELECT
  '2_all_relations' AS section,
  table_schema,
  table_name,
  table_type
FROM information_schema.tables
WHERE table_schema = 'product_code'
ORDER BY table_type, table_name;

-- ------------------------------------------------------------
-- [3] 주요 후보 테이블 컬럼 구조
-- ------------------------------------------------------------
\echo '== [3] 주요 테이블 컬럼 구조 (information_schema.columns) =='
SELECT
  '3_columns' AS section,
  table_name,
  ordinal_position AS pos,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'product_code'
  AND table_name IN (
    'code_alias',
    'channel_product',
    'channel_sku',
    'channel_template_meta',
    'channel_sku_review_draft',
    'sku_channel_mapping'
  )
ORDER BY table_name, ordinal_position;

-- ------------------------------------------------------------
-- [4] code_alias.code_system distinct + count
-- ------------------------------------------------------------
\echo '== [4] code_alias.code_system distinct + count =='
SELECT
  '4_code_system' AS section,
  code_system,
  target_type,
  COUNT(*)                          AS rows,
  COUNT(DISTINCT code_value)        AS distinct_values,
  SUM(CASE WHEN code_value IS NULL OR btrim(code_value) = '' THEN 1 ELSE 0 END) AS null_blank_value,
  SUM(CASE WHEN target_id  IS NULL THEN 1 ELSE 0 END) AS null_target_id
FROM product_code.code_alias
GROUP BY code_system, target_type
ORDER BY code_system, target_type;

-- ------------------------------------------------------------
-- [5] channel_product.channel distinct + count (테이블이 존재할 때만)
-- ------------------------------------------------------------
\echo '== [5] channel_product.channel distinct + count =='
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'product_code' AND table_name = 'channel_product'
  ) THEN
    RAISE NOTICE 'channel_product 테이블 존재. 아래 SELECT 가 실행됩니다.';
  ELSE
    RAISE NOTICE 'channel_product 테이블 없음. 아래 SELECT 는 ERROR 가 날 수 있으며 정상입니다.';
  END IF;
END $$;

-- 테이블 없으면 ERROR 가 발생할 수 있다. ERROR 자체가 inventory 결과이므로
-- 후속 SELECT 가 멈추지 않도록 별도 파일이 아닌 경우 사용자가 결과만 회신.
SELECT
  '5_channel_product' AS section,
  channel,
  COUNT(*) AS rows
FROM product_code.channel_product
GROUP BY channel
ORDER BY channel;

-- ------------------------------------------------------------
-- [6] channel_sku.channel distinct + count (테이블이 존재할 때만)
-- ------------------------------------------------------------
\echo '== [6] channel_sku.channel distinct + count =='
SELECT
  '6_channel_sku' AS section,
  channel,
  COUNT(*) AS rows
FROM product_code.channel_sku
GROUP BY channel
ORDER BY channel;

-- ------------------------------------------------------------
-- [7] sku_channel_mapping 컬럼/분포
-- ------------------------------------------------------------
\echo '== [7] sku_channel_mapping channel 분포 =='
SELECT
  '7_scm_channel' AS section,
  channel_code,
  COUNT(*)                              AS rows,
  COUNT(DISTINCT sku_id)                AS distinct_sku,
  COUNT(DISTINCT channel_sku_code)      AS distinct_channel_sku,
  COUNT(DISTINCT seller_product_code)   AS distinct_seller_prod,
  SUM(CASE WHEN sku_id IS NULL THEN 1 ELSE 0 END)                    AS null_sku_id,
  SUM(CASE WHEN channel_sku_code   IS NULL OR btrim(channel_sku_code) = '' THEN 1 ELSE 0 END) AS null_channel_sku,
  SUM(CASE WHEN seller_product_code IS NULL OR btrim(seller_product_code) = '' THEN 1 ELSE 0 END) AS null_seller_prod
FROM product_code.sku_channel_mapping
GROUP BY channel_code
ORDER BY channel_code;

-- ------------------------------------------------------------
-- [8] channel_sku_review_draft 상태 분포 (존재할 때만)
-- ------------------------------------------------------------
\echo '== [8] channel_sku_review_draft 컬럼 목록 + 상태 분포 (존재 시) =='
SELECT
  '8_review_draft_columns' AS section,
  ordinal_position AS pos,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'product_code'
  AND table_name   = 'channel_sku_review_draft'
ORDER BY ordinal_position;

-- 상태 컬럼 후보들을 동적으로 알 수 없으므로 일반적으로 쓰이는 이름들을
-- 시도한다. 없는 컬럼은 ERROR 가 나므로 사용자 회신 시 ERROR 로그도 함께
-- 첨부하면 컬럼 존재 여부가 파악된다.
SELECT
  '8_review_draft_count' AS section,
  COUNT(*) AS rows
FROM product_code.channel_sku_review_draft;

-- ------------------------------------------------------------
-- [9] 메이크샵 / 에이블리 관련 값 검색 (case-insensitive, 한글 포함)
-- ------------------------------------------------------------
\echo '== [9-A] code_alias 내 makeshop/ably/메이크샵/에이블리 후보 =='
SELECT
  '9a_code_alias' AS section,
  code_system,
  target_type,
  COUNT(*) AS rows
FROM product_code.code_alias
WHERE code_system ILIKE '%makeshop%'
   OR code_system ILIKE '%make_shop%'
   OR code_system ILIKE '%메이크샵%'
   OR code_system ILIKE '%ably%'
   OR code_system ILIKE '%에이블리%'
GROUP BY code_system, target_type
ORDER BY code_system, target_type;

\echo '== [9-B] sku_channel_mapping 내 makeshop/ably/메이크샵/에이블리 후보 =='
SELECT
  '9b_scm' AS section,
  channel_code,
  COUNT(*) AS rows
FROM product_code.sku_channel_mapping
WHERE channel_code ILIKE '%makeshop%'
   OR channel_code ILIKE '%make_shop%'
   OR channel_code ILIKE '%메이크샵%'
   OR channel_code ILIKE '%ably%'
   OR channel_code ILIKE '%에이블리%'
GROUP BY channel_code
ORDER BY channel_code;

\echo '== [9-C] channel_product 내 makeshop/ably 후보 (테이블 존재 시) =='
SELECT
  '9c_channel_product' AS section,
  channel,
  COUNT(*) AS rows
FROM product_code.channel_product
WHERE channel ILIKE '%makeshop%'
   OR channel ILIKE '%make_shop%'
   OR channel ILIKE '%메이크샵%'
   OR channel ILIKE '%ably%'
   OR channel ILIKE '%에이블리%'
GROUP BY channel
ORDER BY channel;

\echo '== [9-D] channel_sku 내 makeshop/ably 후보 (테이블 존재 시) =='
SELECT
  '9d_channel_sku' AS section,
  channel,
  COUNT(*) AS rows
FROM product_code.channel_sku
WHERE channel ILIKE '%makeshop%'
   OR channel ILIKE '%make_shop%'
   OR channel ILIKE '%메이크샵%'
   OR channel ILIKE '%ably%'
   OR channel ILIKE '%에이블리%'
GROUP BY channel
ORDER BY channel;

-- ------------------------------------------------------------
-- [10] selfpia_sku / own_sku 매칭 키 분포 재확인
-- ------------------------------------------------------------
\echo '== [10-A] selfpia_sku / own_sku 매칭 키 분포 =='
SELECT
  '10a_alias_key_dist' AS section,
  code_system,
  COUNT(*)                                                                  AS rows,
  COUNT(DISTINCT code_value)                                                AS distinct_value,
  COUNT(DISTINCT target_id)                                                 AS distinct_target,
  SUM(CASE WHEN code_value IS NULL OR btrim(code_value) = '' THEN 1 ELSE 0 END) AS null_blank_value
FROM product_code.code_alias
WHERE code_system IN ('selfpia_sku', 'selfpia_product', 'own_sku', 'own_product', 'own_set')
GROUP BY code_system
ORDER BY code_system;

\echo '== [10-B] own_sku 모호성: 동일 code_value 가 여러 target_id 에 매핑되는지 =='
SELECT
  '10b_own_sku_ambig' AS section,
  ambig_bucket,
  COUNT(*) AS rows
FROM (
  SELECT
    CASE
      WHEN COUNT(DISTINCT target_id) = 1 THEN 'unique'
      WHEN COUNT(DISTINCT target_id) = 2 THEN 'ambig_2'
      WHEN COUNT(DISTINCT target_id) BETWEEN 3 AND 5 THEN 'ambig_3_to_5'
      ELSE 'ambig_6+'
    END AS ambig_bucket
  FROM product_code.code_alias
  WHERE code_system = 'own_sku'
  GROUP BY code_value
) s
GROUP BY ambig_bucket
ORDER BY ambig_bucket;

\echo '== [10-C] selfpia_sku 1:1 검증 (전체 distinct 와 row 수 일치 여부) =='
SELECT
  '10c_selfpia_sku_1to1' AS section,
  COUNT(*)                   AS rows,
  COUNT(DISTINCT code_value) AS distinct_value,
  COUNT(DISTINCT target_id)  AS distinct_target,
  CASE
    WHEN COUNT(*) = COUNT(DISTINCT code_value)
     AND COUNT(*) = COUNT(DISTINCT target_id)
    THEN 'OK_1to1'
    ELSE 'NOT_1to1'
  END AS verdict
FROM product_code.code_alias
WHERE code_system = 'selfpia_sku';

-- ------------------------------------------------------------
-- [11] code_alias / sku_channel_mapping 기본 null/blank/duplicate
-- ------------------------------------------------------------
\echo '== [11-A] code_alias 기본 null/blank 통계 =='
SELECT
  '11a_alias_basic' AS section,
  COUNT(*)                                                                  AS rows,
  SUM(CASE WHEN code_system IS NULL OR btrim(code_system) = '' THEN 1 ELSE 0 END) AS null_blank_code_system,
  SUM(CASE WHEN code_value  IS NULL OR btrim(code_value)  = '' THEN 1 ELSE 0 END) AS null_blank_code_value,
  SUM(CASE WHEN target_id   IS NULL THEN 1 ELSE 0 END)                          AS null_target_id,
  SUM(CASE WHEN target_type NOT IN ('PRODUCT','SKU','SET') THEN 1 ELSE 0 END)   AS bad_target_type
FROM product_code.code_alias;

\echo '== [11-B] code_alias 동일 (code_system, code_value) 가 여러 row 인 경우 =='
SELECT
  '11b_alias_dup' AS section,
  dup_bucket,
  COUNT(*) AS rows
FROM (
  SELECT
    CASE
      WHEN COUNT(*) = 1 THEN 'unique'
      WHEN COUNT(*) = 2 THEN 'dup_2'
      WHEN COUNT(*) BETWEEN 3 AND 5 THEN 'dup_3_to_5'
      ELSE 'dup_6+'
    END AS dup_bucket
  FROM product_code.code_alias
  GROUP BY code_system, code_value
) s
GROUP BY dup_bucket
ORDER BY dup_bucket;

\echo '== [11-C] sku_channel_mapping 기본 null/blank/duplicate =='
SELECT
  '11c_scm_basic' AS section,
  COUNT(*)                                                                              AS rows,
  SUM(CASE WHEN channel_code IS NULL OR btrim(channel_code) = '' THEN 1 ELSE 0 END)     AS null_blank_channel,
  SUM(CASE WHEN sku_id IS NULL THEN 1 ELSE 0 END)                                       AS null_sku,
  COUNT(DISTINCT (channel_code, channel_sku_code))                                      AS distinct_chan_sku
FROM product_code.sku_channel_mapping;

-- ------------------------------------------------------------
-- [12] master 측 row count (참고용)
-- ------------------------------------------------------------
\echo '== [12] master row count =='
SELECT '12_master_rows' AS section, 'product_master'      AS rel, COUNT(*) AS rows FROM product_code.product_master
UNION ALL SELECT '12_master_rows', 'sku_master',          COUNT(*) FROM product_code.sku_master
UNION ALL SELECT '12_master_rows', 'code_alias',          COUNT(*) FROM product_code.code_alias
UNION ALL SELECT '12_master_rows', 'sku_channel_mapping', COUNT(*) FROM product_code.sku_channel_mapping
ORDER BY rel;

\echo '== inventory_channel_mapping_precheck.sql 완료 =='
