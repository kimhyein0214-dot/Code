-- ============================================================
-- dryrun_local_data_import.sql
--
-- 목적:
--   stg_import_v1 에 적재된 selfpia/own staging 을 product_code.*
--   에 INSERT 했을 때의 결과를 BEGIN/ROLLBACK 트랜잭션 안에서만
--   시뮬레이션한다. 마지막은 반드시 ROLLBACK 이므로 본 파일은
--   실제 데이터를 변경하지 않는다.
--
-- 사전 요구:
--   stage_local_data_import.sql 이 실행되어 staging 이 적재됨.
--
-- 운영 Supabase / NAS 변경 금지. product_code schema DDL 금지.
-- 본 파일에는 UPDATE / DELETE / ALTER / DROP / CREATE / TRUNCATE
-- 가 없다. INSERT 만 BEGIN/ROLLBACK 안에서 수행한다.
--
-- 실행 방법:
--   docker exec -i product_ops_test_postgres \
--     psql -U product_ops_tester -d product_ops_test \
--     -f /sql/dryrun_local_data_import.sql
-- ============================================================

\pset border 2
\pset pager off
\pset format aligned

-- ------------------------------------------------------------
-- [0] context (트랜잭션 밖)
-- ------------------------------------------------------------
\echo '== [0] context =='
SELECT
  'dryrun_local_data_import' AS section,
  current_database()         AS db,
  current_user               AS db_user,
  now()                      AS now_ts;

-- ------------------------------------------------------------
-- [0-B] 적용 전 row count (트랜잭션 밖)
-- ------------------------------------------------------------
\echo '== [0-B] 적용 전 row count =='
SELECT '0b_before' AS section, 'product_master' AS rel, COUNT(*) AS rows FROM product_code.product_master
UNION ALL SELECT '0b_before', 'sku_master',      COUNT(*) FROM product_code.sku_master
UNION ALL SELECT '0b_before', 'code_alias',      COUNT(*) FROM product_code.code_alias
UNION ALL SELECT '0b_before', 'v_sku_canonical', COUNT(*) FROM product_code.v_sku_canonical
ORDER BY rel;

-- ============================================================
-- 트랜잭션 시작 — 끝에서 반드시 ROLLBACK
-- ============================================================
BEGIN;

-- ------------------------------------------------------------
-- [1] product_master 적재
--     CSV 한 행에 (product_id, virtual_product_code, product_name)
--     가 모두 있고 product 단위로 중복되므로 DISTINCT.
--     status 는 sku_status 의 의미와 다르므로 NULL 로 두고
--     source_table 만 표시.
-- ------------------------------------------------------------
INSERT INTO product_code.product_master
  (id, virtual_product_code, product_name, source_table)
SELECT DISTINCT
  s.product_id,
  s.virtual_product_code,
  s.product_name,
  'selfpia_sku_alias.csv'
FROM stg_import_v1.selfpia_sku_alias s
WHERE s.product_id IS NOT NULL
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------
-- [2] sku_master 적재
-- ------------------------------------------------------------
INSERT INTO product_code.sku_master
  (id, product_id, virtual_sku_code, option_value, sku_type, status, source_table)
SELECT
  s.sku_id,
  s.product_id,
  s.virtual_sku_code,
  s.option_value,
  s.sku_type,
  s.sku_status,
  'selfpia_sku_alias.csv'
FROM stg_import_v1.selfpia_sku_alias s
WHERE s.sku_id IS NOT NULL
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------
-- [3] code_alias selfpia_sku 적재
-- ------------------------------------------------------------
INSERT INTO product_code.code_alias
  (target_type, target_id, code_system, code_value,
   selfpia_product_code, selfpia_option_no, is_primary, source_table)
SELECT
  'SKU',
  s.sku_id,
  'selfpia_sku',
  s.selfpia_sku_code,
  s.selfpia_product_code,
  s.selfpia_option_no,
  true,
  'selfpia_sku_alias.csv'
FROM stg_import_v1.selfpia_sku_alias s
WHERE s.sku_id IS NOT NULL
  AND s.selfpia_sku_code IS NOT NULL
  AND btrim(s.selfpia_sku_code) <> ''
ON CONFLICT (code_system, code_value, target_type, target_id) DO NOTHING;

-- ------------------------------------------------------------
-- [4] code_alias own_sku 적재
--     own_sku 는 n:m. CSV 에 (own_sku_code, sku_id) 쌍이 중복일 수
--     있어 unique constraint 에 의존해 dedupe.
-- ------------------------------------------------------------
INSERT INTO product_code.code_alias
  (target_type, target_id, code_system, code_value,
   parsed_part1, parsed_part2, is_primary, source_table)
SELECT
  'SKU',
  o.sku_id,
  'own_sku',
  o.own_sku_code,
  o.parsed_part1,
  o.parsed_part2,
  COALESCE(o.is_primary, false),
  'own_sku_alias.csv'
FROM stg_import_v1.own_sku_alias o
WHERE o.sku_id IS NOT NULL
  AND o.own_sku_code IS NOT NULL
  AND btrim(o.own_sku_code) <> ''
ON CONFLICT (code_system, code_value, target_type, target_id) DO NOTHING;

-- ------------------------------------------------------------
-- [5] Pass 1 검증: 트랜잭션 내부 row count
-- ------------------------------------------------------------
\echo '== [5] Pass 1: 적용 후 (트랜잭션 내) row count =='
SELECT '5_after_in_tx' AS section, 'product_master' AS rel, COUNT(*) AS rows FROM product_code.product_master
UNION ALL SELECT '5_after_in_tx', 'sku_master',     COUNT(*) FROM product_code.sku_master
UNION ALL SELECT '5_after_in_tx', 'code_alias',     COUNT(*) FROM product_code.code_alias
UNION ALL SELECT '5_after_in_tx', 'v_sku_canonical',COUNT(*) FROM product_code.v_sku_canonical
ORDER BY rel;

\echo '== [5-B] 적용 후 code_alias.code_system 분포 =='
SELECT
  '5b_after_code_system' AS section,
  code_system,
  target_type,
  COUNT(*) AS rows
FROM product_code.code_alias
GROUP BY code_system, target_type
ORDER BY code_system, target_type;

-- ------------------------------------------------------------
-- [6] Pass 2 최종 verdict (no=1..N + no=99 OVERALL)
-- ------------------------------------------------------------
\echo '== [6] Pass 2: verdict (no=99 OVERALL) =='
WITH
  cnt AS (
    SELECT
      (SELECT COUNT(*) FROM product_code.product_master)                                    AS product_master_rows,
      (SELECT COUNT(*) FROM product_code.sku_master)                                        AS sku_master_rows,
      (SELECT COUNT(*) FROM product_code.code_alias WHERE code_system='selfpia_sku')        AS selfpia_sku_rows,
      (SELECT COUNT(*) FROM product_code.code_alias WHERE code_system='own_sku')            AS own_sku_rows,
      (SELECT COUNT(*) FROM product_code.v_sku_canonical)                                   AS v_canon_rows,
      (SELECT COUNT(*) FROM product_code.sku_master sm
        LEFT JOIN product_code.product_master pm ON pm.id = sm.product_id
        WHERE pm.id IS NULL)                                                                AS orphan_sku,
      (SELECT COUNT(*) FROM product_code.code_alias ca
        WHERE ca.target_type='SKU'
          AND NOT EXISTS (SELECT 1 FROM product_code.sku_master WHERE id=ca.target_id))     AS orphan_alias,
      (SELECT COUNT(*) FROM product_code.code_alias WHERE code_system='selfpia_sku')        AS selfpia_total,
      (SELECT COUNT(DISTINCT code_value) FROM product_code.code_alias WHERE code_system='selfpia_sku') AS selfpia_distinct,
      (SELECT COUNT(*) FROM product_code.product_master
        WHERE virtual_product_code ILIKE 'LOCAL_TEST%')                                     AS local_test_product_kept,
      (SELECT COUNT(*) FROM product_code.sku_master
        WHERE virtual_sku_code ILIKE 'LOCAL_TEST%')                                         AS local_test_sku_kept,
      (SELECT COUNT(*) FROM product_code.code_alias
        WHERE code_value ILIKE 'LOCAL_TEST%')                                               AS local_test_alias_kept,
      (SELECT COUNT(*) FROM product_code.sku_channel_mapping
        WHERE channel_code ILIKE 'LOCAL_TEST%')                                             AS local_test_scm_kept
  ),
  checks AS (
    SELECT * FROM (VALUES
      (1, 'product_master_rows',     (SELECT product_master_rows::text     FROM cnt), '>= 6174',  (SELECT CASE WHEN product_master_rows     >= 6174  THEN 'PASS' ELSE 'FAIL' END FROM cnt)),
      (2, 'sku_master_rows',         (SELECT sku_master_rows::text         FROM cnt), '>= 33287', (SELECT CASE WHEN sku_master_rows         >= 33287 THEN 'PASS' ELSE 'FAIL' END FROM cnt)),
      (3, 'selfpia_sku_alias_rows',  (SELECT selfpia_sku_rows::text        FROM cnt), '>= 33287', (SELECT CASE WHEN selfpia_sku_rows        >= 33287 THEN 'PASS' ELSE 'FAIL' END FROM cnt)),
      (4, 'own_sku_alias_rows',      (SELECT own_sku_rows::text            FROM cnt), '>= 31975', (SELECT CASE WHEN own_sku_rows            >= 31975 THEN 'PASS' ELSE 'FAIL' END FROM cnt)),
      (5, 'v_sku_canonical_rows',    (SELECT v_canon_rows::text            FROM cnt), '>= 33287', (SELECT CASE WHEN v_canon_rows            >= 33287 THEN 'PASS' ELSE 'FAIL' END FROM cnt)),
      (6, 'orphan_sku',              (SELECT orphan_sku::text              FROM cnt), '= 0',      (SELECT CASE WHEN orphan_sku              = 0      THEN 'PASS' ELSE 'FAIL' END FROM cnt)),
      (7, 'orphan_alias',            (SELECT orphan_alias::text            FROM cnt), '= 0',      (SELECT CASE WHEN orphan_alias            = 0      THEN 'PASS' ELSE 'FAIL' END FROM cnt)),
      (8, 'selfpia_sku_1to1',
         (SELECT (selfpia_total = selfpia_distinct)::text FROM cnt),
         'true (1:1)',
         (SELECT CASE WHEN selfpia_total = selfpia_distinct THEN 'PASS' ELSE 'FAIL' END FROM cnt)),
      (9, 'local_test_product_kept', (SELECT local_test_product_kept::text FROM cnt), '>= 1',     (SELECT CASE WHEN local_test_product_kept >= 1     THEN 'PASS' ELSE 'FAIL' END FROM cnt)),
      (10,'local_test_sku_kept',     (SELECT local_test_sku_kept::text     FROM cnt), '>= 2',     (SELECT CASE WHEN local_test_sku_kept     >= 2     THEN 'PASS' ELSE 'FAIL' END FROM cnt)),
      (11,'local_test_alias_kept',   (SELECT local_test_alias_kept::text   FROM cnt), '>= 1',     (SELECT CASE WHEN local_test_alias_kept   >= 1     THEN 'PASS' ELSE 'FAIL' END FROM cnt)),
      (12,'local_test_scm_kept',     (SELECT local_test_scm_kept::text     FROM cnt), '>= 1',     (SELECT CASE WHEN local_test_scm_kept     >= 1     THEN 'PASS' ELSE 'FAIL' END FROM cnt))
    ) AS t(no, check_name, value, expected, verdict)
  )
SELECT no, check_name, value, expected, verdict, '' AS note FROM checks
UNION ALL
SELECT
  99 AS no,
  'OVERALL' AS check_name,
  CASE
    WHEN NOT EXISTS (SELECT 1 FROM checks WHERE verdict <> 'PASS')
    THEN 'ALL PASS — dry-run 통과. ROLLBACK 후 사용자 승인 시 apply 가능.'
    ELSE 'FAIL — 위 check 중 verdict=FAIL 항목 확인 필요.'
  END AS value,
  '-' AS expected,
  CASE
    WHEN NOT EXISTS (SELECT 1 FROM checks WHERE verdict <> 'PASS') THEN 'PASS'
    ELSE 'FAIL'
  END AS verdict,
  (SELECT COALESCE(string_agg('no='||no::text, ','), '-') FROM checks WHERE verdict='FAIL') AS note
ORDER BY no;

-- ------------------------------------------------------------
-- [7] ROLLBACK — 본 트랜잭션의 변경 사항을 모두 폐기
-- ------------------------------------------------------------
ROLLBACK;

-- ------------------------------------------------------------
-- [8] 적용 후 (ROLLBACK 후) row count 확인 — 원상 복귀 검증
-- ------------------------------------------------------------
\echo '== [8] ROLLBACK 후 row count (원상 복귀 검증) =='
SELECT '8_after_rb' AS section, 'product_master' AS rel, COUNT(*) AS rows FROM product_code.product_master
UNION ALL SELECT '8_after_rb', 'sku_master',     COUNT(*) FROM product_code.sku_master
UNION ALL SELECT '8_after_rb', 'code_alias',     COUNT(*) FROM product_code.code_alias
UNION ALL SELECT '8_after_rb', 'v_sku_canonical',COUNT(*) FROM product_code.v_sku_canonical
ORDER BY rel;

\echo '== dryrun_local_data_import.sql 완료 (ROLLBACK 됨) =='
