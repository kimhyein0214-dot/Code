-- =============================================================================
-- precheck_picking_inventory.sql
-- 대상: 피킹시스템 DB (Supabase, PostgreSQL) -- PR_system
-- 목적: 테이블/컬럼/PK/FK/UNIQUE/INDEX/row count + 주문·피킹·검품·CS 영역 파악
-- 주의: SELECT-only. 운영 테이블 변경 금지.
--      반드시 "피킹시스템" 프로젝트에 접속한 상태에서 실행 (상품코드 DB와 헷갈리지 말 것).
-- =============================================================================

-- ============================================================
-- [K-0] 접속 DB 확인 (PR_system인지 반드시 확인)
-- ============================================================
SELECT
  current_database()          AS db_name,
  current_user                AS db_user,
  inet_server_addr()::text    AS server_addr,
  version()                   AS pg_version,
  current_setting('TimeZone') AS tz,
  now()                       AS checked_at;

-- ============================================================
-- [K-1] schema 목록
-- ============================================================
SELECT nspname AS schema_name
FROM pg_namespace
WHERE nspname NOT IN ('pg_catalog','information_schema','pg_toast')
  AND nspname NOT LIKE 'pg_temp_%'
  AND nspname NOT LIKE 'pg_toast_temp_%'
ORDER BY 1;

-- ============================================================
-- [K-2] 테이블 목록 + 추정 row count + 크기
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
-- [K-3] 정확 row count
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
-- [K-4] 컬럼 인벤토리
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
-- [K-5] PK
-- ============================================================
SELECT
  tc.table_schema, tc.table_name, tc.constraint_name,
  string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS pk_columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type = 'PRIMARY KEY'
  AND tc.table_schema NOT IN (
    'pg_catalog','information_schema','auth','storage','realtime','supabase_functions',
    'vault','pgsodium','pgsodium_masks','net','extensions','graphql','graphql_public'
  )
GROUP BY tc.table_schema, tc.table_name, tc.constraint_name
ORDER BY tc.table_schema, tc.table_name;

-- ============================================================
-- [K-6] FK
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
-- [K-7] UNIQUE
-- ============================================================
SELECT
  tc.table_schema, tc.table_name, tc.constraint_name,
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
-- [K-8] INDEX
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
-- [K-9] 주문/피킹/검품/CS 영역 추정 - 테이블명 키워드 검색
-- ============================================================
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  CASE
    WHEN c.relname ILIKE '%order%' OR c.relname ILIKE '%ord_%'        THEN 'order'
    WHEN c.relname ILIKE '%pick%'                                     THEN 'picking'
    WHEN c.relname ILIKE '%inspect%' OR c.relname ILIKE '%qc%'
      OR c.relname ILIKE '%qa%'      OR c.relname ILIKE '%check%'     THEN 'inspection'
    WHEN c.relname ILIKE '%cs_%'    OR c.relname ILIKE '%claim%'
      OR c.relname ILIKE '%return%' OR c.relname ILIKE '%exchange%'
      OR c.relname ILIKE '%refund%' OR c.relname ILIKE '%complain%'   THEN 'cs'
    WHEN c.relname ILIKE '%ship%'   OR c.relname ILIKE '%delivery%'
      OR c.relname ILIKE '%invoice%' OR c.relname ILIKE '%waybill%'   THEN 'shipping'
    WHEN c.relname ILIKE '%stock%'  OR c.relname ILIKE '%invent%'     THEN 'inventory'
    WHEN c.relname ILIKE '%user%'   OR c.relname ILIKE '%worker%'
      OR c.relname ILIKE '%staff%'  OR c.relname ILIKE '%member%'     THEN 'user'
    ELSE 'etc'
  END AS area_guess
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN (
    'pg_catalog','information_schema','pg_toast','extensions','graphql','graphql_public',
    'auth','storage','realtime','supabase_functions','vault','pgsodium','pgsodium_masks','net'
  )
ORDER BY area_guess, schema_name, table_name;

-- ============================================================
-- [K-10] 상품코드 DB와 연결될 가능성 있는 컬럼 (피킹시스템에서)
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
    OR column_name ILIKE '%mall%'
    OR column_name ILIKE '%market%'
  )
ORDER BY table_schema, table_name, column_name;

-- ============================================================
-- [K-11] 주문상품 라인 추정 테이블의 SKU 컬럼 NULL/distinct 비율
-- ([K-9], [K-10] 결과로 실제 테이블/컬럼명 치환 후 사용)
-- ============================================================
-- SELECT
--   count(*)                              AS total_rows,
--   count(selfpia_sku_code)               AS sku_not_null,
--   count(DISTINCT selfpia_sku_code)      AS sku_distinct,
--   count(channel_sku_code)               AS csku_not_null,
--   count(DISTINCT channel_sku_code)      AS csku_distinct,
--   count(seller_product_code)            AS spcode_not_null,
--   count(DISTINCT seller_product_code)   AS spcode_distinct
-- FROM public.order_items;  -- <- 실제 주문상품 테이블명으로 치환

-- ============================================================
-- [K-12] 주문 상태값 분포 (어떤 status 값이 살아있는지)
-- ([K-9] 결과로 실제 테이블/컬럼명 치환 후 사용)
-- ============================================================
-- SELECT status, count(*) AS n
-- FROM public.orders   -- <- 실제 주문 테이블명으로 치환
-- GROUP BY 1
-- ORDER BY n DESC;
