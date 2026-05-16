-- =============================================================================
-- precheck_product_code_inventory.sql
-- 대상: 상품코드 DB (Supabase, PostgreSQL)
-- 목적: 테이블/컬럼/PK/FK/UNIQUE/INDEX/row count 인벤토리
-- 주의: SELECT-only. CREATE/ALTER/INSERT/UPDATE/DELETE/DROP/TRUNCATE 금지.
-- 사용법:
--   1) Supabase SQL Editor 또는 psql에서 한 블록씩 실행
--   2) 각 블록 결과를 docs/db_integration_inventory.md 의 [상품코드 DB] 표에 채워넣기
-- =============================================================================

-- ============================================================
-- [P-1] DB / 세션 컨텍스트 확인 (잘못된 DB 접속 방지)
-- ============================================================
SELECT
  current_database()          AS db_name,
  current_user                AS db_user,
  inet_server_addr()::text    AS server_addr,
  version()                   AS pg_version,
  current_setting('TimeZone') AS tz,
  now()                       AS checked_at;

-- ============================================================
-- [P-2] schema 목록 (public 외에 별도 schema 있는지 확인)
-- ============================================================
SELECT nspname AS schema_name
FROM pg_namespace
WHERE nspname NOT IN ('pg_catalog','information_schema','pg_toast')
  AND nspname NOT LIKE 'pg_temp_%'
  AND nspname NOT LIKE 'pg_toast_temp_%'
ORDER BY 1;

-- ============================================================
-- [P-3] 테이블 목록 + 추정 row count (시스템 schema 제외)
-- 주: reltuples는 통계 기반 추정값. 정확값은 [P-4] 참조.
-- ============================================================
SELECT
  n.nspname                                     AS schema_name,
  c.relname                                     AS table_name,
  c.reltuples::bigint                           AS estimated_rows,
  pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN (
    'pg_catalog','information_schema','pg_toast','extensions','graphql','graphql_public',
    'auth','storage','realtime','supabase_functions','vault','pgsodium','pgsodium_masks','net'
  )
ORDER BY n.nspname, c.relname;

-- ============================================================
-- [P-4] 정확 row count (테이블이 많으면 시간 소요)
-- 결과는 psql의 NOTICE / Supabase SQL Editor의 "Messages" 탭에서 확인
-- ============================================================
DO $$
DECLARE
  r record;
  cnt bigint;
  rows_out text := '';
BEGIN
  FOR r IN
    SELECT n.nspname AS s, c.relname AS t
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r'
      AND n.nspname NOT IN (
        'pg_catalog','information_schema','pg_toast','extensions','graphql','graphql_public',
        'auth','storage','realtime','supabase_functions','vault','pgsodium','pgsodium_masks','net'
      )
    ORDER BY 1,2
  LOOP
    EXECUTE format('SELECT count(*) FROM %I.%I', r.s, r.t) INTO cnt;
    rows_out := rows_out || format('%s.%s = %s', r.s, r.t, cnt) || E'\n';
  END LOOP;
  RAISE NOTICE E'\n=== EXACT ROW COUNTS ===\n%', rows_out;
END$$;

-- ============================================================
-- [P-5] 컬럼 인벤토리 (전 schema)
-- ============================================================
SELECT
  table_schema,
  table_name,
  ordinal_position,
  column_name,
  data_type,
  COALESCE(character_maximum_length::text, '') AS max_len,
  is_nullable,
  COALESCE(column_default, '')                 AS default_value
FROM information_schema.columns
WHERE table_schema NOT IN (
  'pg_catalog','information_schema','auth','storage','realtime','supabase_functions',
  'vault','pgsodium','pgsodium_masks','net','extensions','graphql','graphql_public'
)
ORDER BY table_schema, table_name, ordinal_position;

-- ============================================================
-- [P-6] Primary Key
-- ============================================================
SELECT
  tc.table_schema,
  tc.table_name,
  tc.constraint_name,
  string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS pk_columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema    = kcu.table_schema
 AND tc.table_name      = kcu.table_name
WHERE tc.constraint_type = 'PRIMARY KEY'
  AND tc.table_schema NOT IN (
    'pg_catalog','information_schema','auth','storage','realtime','supabase_functions',
    'vault','pgsodium','pgsodium_masks','net','extensions','graphql','graphql_public'
  )
GROUP BY tc.table_schema, tc.table_name, tc.constraint_name
ORDER BY tc.table_schema, tc.table_name;

-- ============================================================
-- [P-7] Foreign Key
-- ============================================================
SELECT
  tc.table_schema   AS src_schema,
  tc.table_name     AS src_table,
  kcu.column_name   AS src_column,
  ccu.table_schema  AS ref_schema,
  ccu.table_name    AS ref_table,
  ccu.column_name   AS ref_column,
  tc.constraint_name,
  rc.update_rule,
  rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
JOIN information_schema.referential_constraints rc
  ON tc.constraint_name = rc.constraint_name AND tc.table_schema = rc.constraint_schema
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = rc.unique_constraint_name AND ccu.table_schema = rc.unique_constraint_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema NOT IN (
    'pg_catalog','information_schema','auth','storage','realtime','supabase_functions',
    'vault','pgsodium','pgsodium_masks','net','extensions','graphql','graphql_public'
  )
ORDER BY src_schema, src_table, src_column;

-- ============================================================
-- [P-8] UNIQUE constraint
-- ============================================================
SELECT
  tc.table_schema,
  tc.table_name,
  tc.constraint_name,
  string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS unique_columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type = 'UNIQUE'
  AND tc.table_schema NOT IN (
    'pg_catalog','information_schema','auth','storage','realtime','supabase_functions',
    'vault','pgsodium','pgsodium_masks','net','extensions','graphql','graphql_public'
  )
GROUP BY tc.table_schema, tc.table_name, tc.constraint_name
ORDER BY tc.table_schema, tc.table_name;

-- ============================================================
-- [P-9] 인덱스 목록 (PK/UNIQUE 외 일반 인덱스 포함)
-- ============================================================
SELECT
  schemaname  AS schema_name,
  tablename   AS table_name,
  indexname   AS index_name,
  indexdef    AS index_def
FROM pg_indexes
WHERE schemaname NOT IN (
  'pg_catalog','information_schema','auth','storage','realtime','supabase_functions',
  'vault','pgsodium','pgsodium_masks','net','extensions','graphql','graphql_public'
)
ORDER BY schemaname, tablename, indexname;

-- ============================================================
-- [P-10] SKU/상품/채널 관련 컬럼 후보 식별
-- 통합 시 master 키로 쓸 selfpia_sku_code 등 후보 컬럼 자동 탐지
-- ============================================================
SELECT
  table_schema,
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema NOT IN (
  'pg_catalog','information_schema','auth','storage','realtime','supabase_functions',
  'vault','pgsodium','pgsodium_masks','net','extensions','graphql','graphql_public'
)
  AND (
       column_name ILIKE '%sku%'
    OR column_name ILIKE '%product_code%'
    OR column_name ILIKE '%goods_code%'
    OR column_name ILIKE '%item_code%'
    OR column_name ILIKE '%channel%'
    OR column_name ILIKE '%seller%'
    OR column_name ILIKE '%barcode%'
    OR column_name ILIKE '%option_code%'
  )
ORDER BY table_schema, table_name, column_name;

-- ============================================================
-- [P-11] 후보 master 테이블 중복 키 sample
-- (실제 테이블/컬럼명은 [P-10] 결과로 확인 후 치환)
-- ============================================================
-- SELECT
--   selfpia_sku_code,
--   selfpia_product_code,
--   virtual_sku_code,
--   channel_sku_code,
--   seller_product_code,
--   count(*) AS n
-- FROM public.sku_master   -- <- 실제 테이블명으로 치환
-- GROUP BY 1,2,3,4,5
-- HAVING count(*) > 1
-- ORDER BY n DESC
-- LIMIT 50;

-- ============================================================
-- [P-12] 각 SKU 키 별 NULL 비율 / 유니크 비율
-- (master 테이블 추정 후 사용. 테이블명 치환 필요.)
-- ============================================================
-- SELECT
--   count(*)                                AS total_rows,
--   count(selfpia_sku_code)                 AS sku_not_null,
--   count(DISTINCT selfpia_sku_code)        AS sku_distinct,
--   count(selfpia_product_code)             AS pcode_not_null,
--   count(DISTINCT selfpia_product_code)    AS pcode_distinct,
--   count(virtual_sku_code)                 AS vsku_not_null,
--   count(DISTINCT virtual_sku_code)        AS vsku_distinct,
--   count(channel_sku_code)                 AS csku_not_null,
--   count(DISTINCT channel_sku_code)        AS csku_distinct,
--   count(seller_product_code)              AS spcode_not_null,
--   count(DISTINCT seller_product_code)     AS spcode_distinct
-- FROM public.sku_master;  -- <- 실제 master 테이블명으로 치환
