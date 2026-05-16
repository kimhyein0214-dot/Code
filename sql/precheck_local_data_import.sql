-- ============================================================
-- precheck_local_data_import.sql
--
-- 목적:
--   로컬 Docker `product_ops_test` 의 product_code.* 상태를 import
--   전에 SELECT-only 로 점검한다.
--
-- 운영 Supabase / NAS 는 절대 대상이 아니다.
-- 본 파일은 SELECT-only. INSERT/UPDATE/DELETE/ALTER/DROP/CREATE/
-- TRUNCATE/COPY 가 한 줄도 없다.
--
-- 필요 파일 (다음 stage_local_data_import.sql 에서 사용):
--   /exports/selfpia_sku_alias.csv  (33,287 rows, 운영 export)
--   /exports/own_sku_alias.csv      (31,975 rows, 운영 export)
--   현재 docker-compose.local-test.yml 이 ./exports:/exports 를 마운트.
--
-- 실행 예:
--   docker exec -i product_ops_test_postgres \
--     psql -U product_ops_tester -d product_ops_test \
--     -f /sql/precheck_local_data_import.sql
-- ============================================================

\pset border 2
\pset pager off
\pset format aligned

-- ------------------------------------------------------------
-- [0] context
-- ------------------------------------------------------------
\echo '== [0] context =='
SELECT
  'precheck_local_data_import' AS section,
  current_database()           AS db,
  current_user                 AS db_user,
  now()                        AS now_ts;

-- ------------------------------------------------------------
-- [1] product_code.* 현재 row count
-- ------------------------------------------------------------
\echo '== [1] product_code.* 현재 row count =='
SELECT '1_master_rows' AS section, 'product_master'      AS rel, COUNT(*) AS rows FROM product_code.product_master
UNION ALL SELECT '1_master_rows', 'sku_master',          COUNT(*) FROM product_code.sku_master
UNION ALL SELECT '1_master_rows', 'code_alias',          COUNT(*) FROM product_code.code_alias
UNION ALL SELECT '1_master_rows', 'sku_channel_mapping', COUNT(*) FROM product_code.sku_channel_mapping
UNION ALL SELECT '1_master_rows', 'sku_bundle_component',COUNT(*) FROM product_code.sku_bundle_component
UNION ALL SELECT '1_master_rows', 'v_sku_canonical',     COUNT(*) FROM product_code.v_sku_canonical
ORDER BY rel;

-- ------------------------------------------------------------
-- [2] code_alias.code_system 분포 재확인
-- ------------------------------------------------------------
\echo '== [2] code_alias.code_system 분포 =='
SELECT
  '2_code_system' AS section,
  code_system,
  target_type,
  COUNT(*)                   AS rows,
  COUNT(DISTINCT code_value) AS distinct_value,
  COUNT(DISTINCT target_id)  AS distinct_target
FROM product_code.code_alias
GROUP BY code_system, target_type
ORDER BY code_system, target_type;

-- ------------------------------------------------------------
-- [3] LOCAL_TEST seed UUID 인벤토리 (import 후 보존 확인용 baseline)
-- ------------------------------------------------------------
\echo '== [3-A] LOCAL_TEST product_master seed =='
SELECT
  '3a_local_test_pm' AS section,
  id,
  virtual_product_code,
  product_name
FROM product_code.product_master
WHERE virtual_product_code ILIKE 'LOCAL_TEST%'
   OR product_name           ILIKE '%LOCAL_TEST%'
ORDER BY virtual_product_code;

\echo '== [3-B] LOCAL_TEST sku_master seed =='
SELECT
  '3b_local_test_sm' AS section,
  id,
  product_id,
  virtual_sku_code,
  option_value,
  sku_type,
  status
FROM product_code.sku_master
WHERE virtual_sku_code ILIKE 'LOCAL_TEST%'
   OR product_id IN (SELECT id FROM product_code.product_master WHERE virtual_product_code ILIKE 'LOCAL_TEST%')
ORDER BY virtual_sku_code;

\echo '== [3-C] LOCAL_TEST code_alias seed =='
SELECT
  '3c_local_test_ca' AS section,
  code_system,
  code_value,
  target_type,
  target_id,
  is_primary
FROM product_code.code_alias
WHERE code_value ILIKE 'LOCAL_TEST%'
ORDER BY code_system, code_value;

\echo '== [3-D] LOCAL_TEST sku_channel_mapping seed =='
SELECT
  '3d_local_test_scm' AS section,
  id,
  sku_id,
  channel_code,
  channel_sku_code,
  seller_product_code,
  is_primary
FROM product_code.sku_channel_mapping
WHERE channel_code ILIKE 'LOCAL_TEST%'
ORDER BY channel_code, channel_sku_code;

-- ------------------------------------------------------------
-- [4] v_sku_canonical 동작 검증
-- ------------------------------------------------------------
\echo '== [4] v_sku_canonical 샘플 5건 =='
SELECT
  '4_v_canon' AS section,
  sku_id,
  selfpia_sku_code,
  virtual_sku_code,
  product_name,
  option_value,
  sku_status
FROM product_code.v_sku_canonical
ORDER BY selfpia_sku_code NULLS LAST
LIMIT 5;

-- ------------------------------------------------------------
-- [5] 참고: 기존 stg_xmap.* 의 row count (cross_mapping 분석용 stage)
--           본 import 와 무관하지만 같은 CSV 를 사용하므로 참고만.
-- ------------------------------------------------------------
\echo '== [5] stg_xmap.* row count (존재 시 참고) =='
SELECT
  '5_stg_xmap' AS section,
  table_name,
  ( xpath('/row/c/text()',
      query_to_xml(format('SELECT COUNT(*) AS c FROM stg_xmap.%I', table_name), true, false, ''))
  )[1]::text AS rows
FROM information_schema.tables
WHERE table_schema = 'stg_xmap'
ORDER BY table_name;

-- ------------------------------------------------------------
-- [6] 신규 import 대상 schema stg_import_v1 의 존재 여부
--     (없으면 stage_local_data_import.sql 단계에서 신설됨)
-- ------------------------------------------------------------
\echo '== [6] stg_import_v1 schema / table 존재 여부 =='
SELECT
  '6_stg_import_v1' AS section,
  schema_name,
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'stg_import_v1')
    THEN 'PRESENT'
    ELSE 'MISSING'
  END AS status
FROM ( VALUES ('stg_import_v1') ) AS s(schema_name);

SELECT
  '6b_stg_import_v1_tables' AS section,
  table_name,
  CASE WHEN t.table_name IS NULL THEN 'MISSING' ELSE 'PRESENT' END AS status
FROM ( VALUES ('selfpia_sku_alias'), ('own_sku_alias') ) AS c(table_name)
LEFT JOIN information_schema.tables t
  ON t.table_schema = 'stg_import_v1'
 AND t.table_name   = c.table_name
ORDER BY c.table_name;

-- ------------------------------------------------------------
-- [7] FK / unique constraint 확인 (적재 시 충돌 가능성 사전 점검)
-- ------------------------------------------------------------
\echo '== [7] product_code.* 의 unique / pk 정의 =='
SELECT
  '7_unique' AS section,
  c.table_name,
  c.constraint_type,
  c.constraint_name,
  string_agg(k.column_name, ', ' ORDER BY k.ordinal_position) AS columns
FROM information_schema.table_constraints c
JOIN information_schema.key_column_usage k
  ON k.constraint_schema = c.constraint_schema
 AND k.constraint_name   = c.constraint_name
WHERE c.table_schema = 'product_code'
  AND c.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
  AND c.table_name IN ('product_master', 'sku_master', 'code_alias', 'sku_channel_mapping')
GROUP BY c.table_name, c.constraint_type, c.constraint_name
ORDER BY c.table_name, c.constraint_type, c.constraint_name;

\echo '== precheck_local_data_import.sql 완료 =='
