-- ============================================================
-- precheck_makeshop_channel_mapping.sql
--
-- 목적:
--   메이크샵 채널 매핑 작업의 사전조사.
--   현재 로컬 Docker `product_ops_test` DB 의 product_code schema 에
--   메이크샵 관련 데이터가 이미 있는지, 매칭에 필요한 후보 컬럼이
--   어디까지 구비되어 있는지를 SELECT-only 로 점검한다.
--
--   본 파일은 SELECT-only. INSERT/UPDATE/DELETE/ALTER/DROP/CREATE/
--   TRUNCATE/COPY 가 한 줄도 없다. dry-run / apply 와도 무관하다.
--
-- 운영 Supabase / NAS 는 절대 대상이 아니다.
--
-- 본 SELECT 들은 inventory_channel_mapping_precheck.sql 의
-- [1]/[3] 섹션과 함께 실행해 어떤 테이블/컬럼이 실재하는지를 먼저
-- 확인한 후 결과를 회신해야 한다. 일부 SELECT 는 테이블/컬럼이
-- 없으면 ERROR 가 발생할 수 있으며, 그 ERROR 자체가 inventory 결과이므로
-- 회신할 때 ERROR 메시지도 함께 회신하면 다음 턴에서 staging 설계가
-- 가능하다.
--
-- 실행 예:
--   docker exec -i product_ops_test_postgres \
--     psql -U product_ops_tester -d product_ops_test \
--     -f /sql/precheck_makeshop_channel_mapping.sql
-- ============================================================

\pset border 2
\pset pager off
\pset format aligned

-- ------------------------------------------------------------
-- [0] context
-- ------------------------------------------------------------
\echo '== [0] context =='
SELECT
  'makeshop_precheck'   AS section,
  current_database()    AS db,
  current_user          AS db_user,
  now()                 AS now_ts;

-- ------------------------------------------------------------
-- [1] 메이크샵 관련 기존 데이터: code_alias
-- ------------------------------------------------------------
\echo '== [1] code_alias 내 makeshop 변형 검색 =='
SELECT
  '1_alias_makeshop' AS section,
  code_system,
  target_type,
  COUNT(*)                   AS rows,
  COUNT(DISTINCT code_value) AS distinct_value,
  COUNT(DISTINCT target_id)  AS distinct_target
FROM product_code.code_alias
WHERE code_system ILIKE '%makeshop%'
   OR code_system ILIKE '%make_shop%'
   OR code_system ILIKE '%메이크샵%'
GROUP BY code_system, target_type
ORDER BY code_system, target_type;

\echo '== [1-B] code_alias sample rows (있다면 상위 20) =='
SELECT
  '1b_alias_sample' AS section,
  id,
  code_system,
  target_type,
  code_value,
  target_id,
  parsed_prefix,
  parsed_part1,
  parsed_part2
FROM product_code.code_alias
WHERE code_system ILIKE '%makeshop%'
   OR code_system ILIKE '%make_shop%'
   OR code_system ILIKE '%메이크샵%'
ORDER BY code_system, code_value
LIMIT 20;

-- ------------------------------------------------------------
-- [2] 메이크샵 관련 기존 데이터: sku_channel_mapping
-- ------------------------------------------------------------
\echo '== [2] sku_channel_mapping 내 makeshop 변형 검색 =='
SELECT
  '2_scm_makeshop' AS section,
  channel_code,
  COUNT(*)                                AS rows,
  COUNT(DISTINCT sku_id)                  AS distinct_sku,
  COUNT(DISTINCT channel_sku_code)        AS distinct_channel_sku,
  COUNT(DISTINCT seller_product_code)     AS distinct_seller_prod,
  SUM(CASE WHEN sku_id IS NULL THEN 1 ELSE 0 END) AS null_sku,
  SUM(CASE WHEN channel_sku_code IS NULL OR btrim(channel_sku_code) = '' THEN 1 ELSE 0 END)   AS null_channel_sku,
  SUM(CASE WHEN seller_product_code IS NULL OR btrim(seller_product_code) = '' THEN 1 ELSE 0 END) AS null_seller_prod
FROM product_code.sku_channel_mapping
WHERE channel_code ILIKE '%makeshop%'
   OR channel_code ILIKE '%make_shop%'
   OR channel_code ILIKE '%메이크샵%'
GROUP BY channel_code
ORDER BY channel_code;

\echo '== [2-B] sku_channel_mapping sample rows (있다면 상위 20) =='
SELECT
  '2b_scm_sample' AS section,
  id,
  channel_code,
  channel_sku_code,
  seller_product_code,
  own_sku_code,
  sku_id,
  is_primary
FROM product_code.sku_channel_mapping
WHERE channel_code ILIKE '%makeshop%'
   OR channel_code ILIKE '%make_shop%'
   OR channel_code ILIKE '%메이크샵%'
ORDER BY channel_code, channel_sku_code
LIMIT 20;

-- ------------------------------------------------------------
-- [3] channel_product / channel_sku / channel_sku_review_draft
--     (테이블이 존재하지 않으면 ERROR 발생 — 결과 자체가 inventory)
-- ------------------------------------------------------------
\echo '== [3-A] channel_product 내 makeshop 검색 (테이블 존재 시) =='
SELECT
  '3a_cp_makeshop' AS section,
  channel,
  COUNT(*) AS rows
FROM product_code.channel_product
WHERE channel ILIKE '%makeshop%'
   OR channel ILIKE '%make_shop%'
   OR channel ILIKE '%메이크샵%'
GROUP BY channel
ORDER BY channel;

\echo '== [3-B] channel_sku 내 makeshop 검색 (테이블 존재 시) =='
SELECT
  '3b_cs_makeshop' AS section,
  channel,
  COUNT(*) AS rows
FROM product_code.channel_sku
WHERE channel ILIKE '%makeshop%'
   OR channel ILIKE '%make_shop%'
   OR channel ILIKE '%메이크샵%'
GROUP BY channel
ORDER BY channel;

\echo '== [3-C] channel_sku_review_draft 내 makeshop 후보 (테이블 존재 시) =='
SELECT
  '3c_csrd_makeshop' AS section,
  COUNT(*) AS rows
FROM product_code.channel_sku_review_draft
WHERE 1 = 0
   OR COALESCE(to_jsonb(channel_sku_review_draft.*)::text, '') ILIKE '%makeshop%'
   OR COALESCE(to_jsonb(channel_sku_review_draft.*)::text, '') ILIKE '%메이크샵%';

-- ------------------------------------------------------------
-- [4] 매칭에 필요한 후보 컬럼이 어느 테이블에 실재하는지
-- ------------------------------------------------------------
\echo '== [4] 후보 키 컬럼 존재 여부 =='
WITH wanted(table_name, column_name) AS (
  VALUES
    ('channel_product',          'seller_product_code_raw'),
    ('channel_product',          'channel'),
    ('channel_product',          'internal_product_id'),
    ('channel_sku',              'channel_sku_code'),
    ('channel_sku',              'channel_sku_code_raw'),
    ('channel_sku',              'extracted_own_code'),
    ('channel_sku',              'internal_sku_id'),
    ('channel_sku',              'channel_product_id'),
    ('channel_sku',              'channel'),
    ('channel_sku_review_draft', 'status'),
    ('channel_sku_review_draft', 'review_status'),
    ('channel_sku_review_draft', 'source_channel'),
    ('channel_sku_review_draft', 'channel'),
    ('sku_channel_mapping',      'channel_code'),
    ('sku_channel_mapping',      'channel_sku_code'),
    ('sku_channel_mapping',      'seller_product_code'),
    ('sku_channel_mapping',      'own_sku_code'),
    ('sku_channel_mapping',      'sku_id'),
    ('sku_channel_mapping',      'is_primary'),
    ('sku_channel_mapping',      'raw_payload'),
    ('code_alias',               'parsed_prefix'),
    ('code_alias',               'parsed_part1'),
    ('code_alias',               'raw_payload')
)
SELECT
  '4_col_exists' AS section,
  w.table_name,
  w.column_name,
  CASE WHEN c.column_name IS NULL THEN 'MISSING' ELSE 'PRESENT' END AS status,
  c.data_type
FROM wanted w
LEFT JOIN information_schema.columns c
  ON c.table_schema = 'product_code'
 AND c.table_name   = w.table_name
 AND c.column_name  = w.column_name
ORDER BY w.table_name, w.column_name;

-- ------------------------------------------------------------
-- [5] own_sku 매칭 풀: 메이크샵 옵션의 bracket 안 own_sku 가 매칭될
--     모집단의 분포. bracket 패턴 예: [PE-25-21], [NA-3-10_3].
--     code_alias 의 own_sku 패턴 분포를 확인한다.
-- ------------------------------------------------------------
\echo '== [5] own_sku 패턴 분포 (bracket 매칭 가능성 추정) =='
SELECT
  '5_own_sku_pattern' AS section,
  CASE
    WHEN code_value ~ '^[A-Z]+-\d+-\d+_\d+$' THEN 'XXX-NN-NN_N'
    WHEN code_value ~ '^[A-Z]+-\d+-\d+$'      THEN 'XXX-NN-NN'
    WHEN code_value ~ '^[A-Z]+\d+-\d+$'       THEN 'XXXN-NN (no dash before digits)'
    ELSE 'other'
  END AS pattern_bucket,
  COUNT(*) AS rows
FROM product_code.code_alias
WHERE code_system = 'own_sku'
GROUP BY 2
ORDER BY 2;

\echo '== [5-B] own_sku 모호성 재확인 (동일 code_value -> 여러 target_id) =='
SELECT
  '5b_own_sku_ambig' AS section,
  ambig_bucket,
  COUNT(*) AS distinct_code_values
FROM (
  SELECT
    code_value,
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

\echo '== [5-C] own_sku ambiguous 상위 샘플 (참고용) =='
SELECT
  '5c_own_sku_ambig_sample' AS section,
  code_value,
  COUNT(DISTINCT target_id) AS distinct_target
FROM product_code.code_alias
WHERE code_system = 'own_sku'
GROUP BY code_value
HAVING COUNT(DISTINCT target_id) > 1
ORDER BY 3 DESC, code_value
LIMIT 20;

-- ------------------------------------------------------------
-- [6] selfpia_sku 매칭 풀 분포 (메이크샵 코드 ↔ selfpia_sku 직접 매칭
--     시도용 — 다만 메이크샵 XML 에는 selfpia_sku 컬럼이 직접 존재하지
--     않으므로 sto_code/관리코드 가 비어있는 경우에는 1차 매칭은
--     own_sku bracket 만 가능하다.)
-- ------------------------------------------------------------
\echo '== [6] selfpia_sku 분포 재확인 =='
SELECT
  '6_selfpia_sku' AS section,
  COUNT(*)                                  AS rows,
  COUNT(DISTINCT code_value)                AS distinct_value,
  COUNT(DISTINCT target_id)                 AS distinct_target,
  COUNT(DISTINCT selfpia_product_code)      AS distinct_selfpia_product
FROM product_code.code_alias
WHERE code_system = 'selfpia_sku';

-- ------------------------------------------------------------
-- [7] 메이크샵 매칭 후보 키 가설 — 본 SELECT 자체로 확정은 아니다.
--     본 결과 + XML 구조 요약을 보고 다음 턴에서 staging 을 설계한다.
-- ------------------------------------------------------------
\echo '== [7] 매칭 후보 키 가설 (정보용 출력) =='
SELECT
  '7_hypothesis' AS section,
  hyp_no,
  source,
  target,
  note
FROM (
  VALUES
    (1, 'XML.product_uid',         'channel_product / sku_channel_mapping(seller_product_code, channel_code=makeshop)', 'MakeShop internal product id. 4923 distinct (sample inventory)'),
    (2, 'XML.sto_id',              'channel_sku / sku_channel_mapping(channel_sku_code)',                              'MakeShop option id. product_uid 와 함께 1:1 가설'),
    (3, 'XML.sto_code',            'code_alias(own_sku) or sku_channel_mapping(own_sku_code)',                          '관리코드. 실측 결과 전체 빈값 — 본 데이터에서는 사용 불가'),
    (4, 'XML.opt_value bracket',   'code_alias(own_sku) → sku_master.id 로 SKU 결정',                                   'bracket=[ALPHA-NN-NN(_N)]. own_sku 는 n:m 이라 자동 확정 금지'),
    (5, 'XML.barcode',             'code_alias 신규 system 또는 product_image / 보조 키',                                '4923 rows. selfpia 측에 매칭 풀이 있는지 추가 확인 필요'),
    (6, 'XML.gid (스타일코드)',     '확인 보류',                                                                          '39 rows 만 채워짐 — 본 매칭에는 부적합'),
    (7, 'XML.ps_num (상품제품코드)','확인 보류',                                                                          '0 rows — 사용 불가')
) AS t(hyp_no, source, target, note)
ORDER BY hyp_no;

\echo '== precheck_makeshop_channel_mapping.sql 완료 =='
