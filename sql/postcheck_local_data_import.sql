-- ============================================================
-- postcheck_local_data_import.sql
--
-- 목적:
--   apply 이후 (별도 작성 / 별도 실행 / 사용자 승인 후) 검증.
--   본 파일은 SELECT-only 다. apply 실행과 무관하게 안전.
--
-- 운영 Supabase / NAS 변경 금지.
--
-- 실행 예:
--   docker exec -i product_ops_test_postgres \
--     psql -U product_ops_tester -d product_ops_test \
--     -f /sql/postcheck_local_data_import.sql
-- ============================================================

\pset border 2
\pset pager off
\pset format aligned

-- ------------------------------------------------------------
-- [0] context
-- ------------------------------------------------------------
\echo '== [0] context =='
SELECT
  'postcheck_local_data_import' AS section,
  current_database()            AS db,
  current_user                  AS db_user,
  now()                         AS now_ts;

-- ------------------------------------------------------------
-- [1] 최종 row count
-- ------------------------------------------------------------
\echo '== [1] 최종 row count =='
SELECT '1_rows' AS section, 'product_master' AS rel, COUNT(*) AS rows FROM product_code.product_master
UNION ALL SELECT '1_rows', 'sku_master',           COUNT(*) FROM product_code.sku_master
UNION ALL SELECT '1_rows', 'code_alias',           COUNT(*) FROM product_code.code_alias
UNION ALL SELECT '1_rows', 'sku_channel_mapping', COUNT(*) FROM product_code.sku_channel_mapping
UNION ALL SELECT '1_rows', 'sku_bundle_component',COUNT(*) FROM product_code.sku_bundle_component
UNION ALL SELECT '1_rows', 'v_sku_canonical',     COUNT(*) FROM product_code.v_sku_canonical
ORDER BY rel;

-- ------------------------------------------------------------
-- [2] code_alias.code_system 분포
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
-- [3] orphan / duplicate 검증
-- ------------------------------------------------------------
\echo '== [3-A] sku_master 에서 product_master 로 orphan =='
SELECT
  '3a_orphan_sku' AS section,
  COUNT(*) AS orphan_rows
FROM product_code.sku_master sm
LEFT JOIN product_code.product_master pm
  ON pm.id = sm.product_id
WHERE pm.id IS NULL;

\echo '== [3-B] code_alias (target_type=SKU) 에서 sku_master 로 orphan =='
SELECT
  '3b_orphan_alias' AS section,
  COUNT(*) AS orphan_rows
FROM product_code.code_alias ca
WHERE ca.target_type = 'SKU'
  AND NOT EXISTS (SELECT 1 FROM product_code.sku_master WHERE id = ca.target_id);

\echo '== [3-C] selfpia_sku 1:1 검증 =='
SELECT
  '3c_selfpia_1to1' AS section,
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

\echo '== [3-D] own_sku ambiguous bucket =='
SELECT
  '3d_own_ambig' AS section,
  ambig_bucket,
  COUNT(*) AS distinct_codes
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

-- ------------------------------------------------------------
-- [4] LOCAL_TEST seed 보존 확인
-- ------------------------------------------------------------
\echo '== [4-A] LOCAL_TEST product_master =='
SELECT '4a_local_pm' AS section, COUNT(*) AS rows FROM product_code.product_master WHERE virtual_product_code ILIKE 'LOCAL_TEST%';

\echo '== [4-B] LOCAL_TEST sku_master =='
SELECT '4b_local_sm' AS section, COUNT(*) AS rows FROM product_code.sku_master WHERE virtual_sku_code ILIKE 'LOCAL_TEST%';

\echo '== [4-C] LOCAL_TEST code_alias =='
SELECT
  '4c_local_ca' AS section,
  code_system,
  COUNT(*) AS rows
FROM product_code.code_alias
WHERE code_value ILIKE 'LOCAL_TEST%'
GROUP BY code_system
ORDER BY code_system;

\echo '== [4-D] LOCAL_TEST sku_channel_mapping =='
SELECT '4d_local_scm' AS section, COUNT(*) AS rows FROM product_code.sku_channel_mapping WHERE channel_code ILIKE 'LOCAL_TEST%';

-- ------------------------------------------------------------
-- [5] v_sku_canonical 동작 샘플 (운영 데이터)
-- ------------------------------------------------------------
\echo '== [5] v_sku_canonical 운영 샘플 5건 =='
SELECT
  '5_v_canon_sample' AS section,
  sku_id,
  selfpia_sku_code,
  virtual_sku_code,
  product_name,
  option_value,
  sku_status
FROM product_code.v_sku_canonical
WHERE selfpia_sku_code NOT ILIKE 'LOCAL_TEST%'
ORDER BY selfpia_sku_code
LIMIT 5;

-- ------------------------------------------------------------
-- [6] API 검증 추천 명령 (host PowerShell)
-- ------------------------------------------------------------
\echo '== [6] API 검증 추천 명령 (주석. 실제 실행은 host 에서) =='
SELECT
  '6_api_hint' AS section,
  step,
  command
FROM ( VALUES
  (1, 'curl.exe "http://localhost:8080/api/products/skus?search=피어싱&limit=5"'),
  (2, 'curl.exe "http://localhost:8080/api/products/skus?search=1258-1"'),
  (3, 'curl.exe "http://localhost:8080/api/products/skus/by-code/selfpia_sku/1258-1"'),
  (4, 'curl.exe "http://localhost:8080/api/products/skus/by-code/own_sku/B-1-01"'),
  (5, 'curl.exe "http://localhost:8080/api/products/skus?search=LOCAL_TEST_PM"  # seed 보존 확인')
) AS t(step, command)
ORDER BY step;

-- ------------------------------------------------------------
-- [7] frontend 검증 추천 URL (주석)
-- ------------------------------------------------------------
\echo '== [7] frontend 검증 추천 URL =='
SELECT
  '7_fe_hint' AS section,
  url
FROM ( VALUES
  ('http://localhost:5173/products  → 검색어 변경하여 운영 SKU 조회'),
  ('http://localhost:5173/products/aliases  → selfpia_sku=1258-1 / own_sku=B-1-01 / 검색 chip 시도'),
  ('http://localhost:5173/products/change-requests  → placeholder 유지 확인')
) AS t(url);

\echo '== postcheck_local_data_import.sql 완료 =='
